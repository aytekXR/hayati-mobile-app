# ADR-053: the bidi seam stops asking `intl` which way a string leans

- **Status:** Accepted
- **Date:** 2026-08-17 (Session 076)
- **Deciders:** session agent (no operator dependency; adds no package, and removes `intl` from this seam without removing it from `pubspec` — see Decision 5)
- **Related:** **ADR-033** (bidi isolation at the string boundary — this fixes the limitation D2 recorded, and D2 is annotated accordingly), issue **#137**, issue **#133** (the original defect)

## ⚠️ Procedural note: this ADR was written after the code, and that was wrong

`session-rules` §5.1 requires the ADR to be written and committed **before** the
implementation, because the ADR is where the design is decided rather than
described. This session inverted that: the measurement and the code came first,
and this document was written against a working tree.

It is recorded rather than quietly corrected because the inversion **cost
something specific and visible in this diff**. Three claims were written into
source comments and the generator's own docstring during implementation and
survived until this ADR forced them to be re-derived:

| claim as written during implementation | re-measured |
|---|---|
| "62,408 code points `intl` calls RTL are not strong-RTL" | **322**. The figure corresponded to nothing; it was never a measurement. |
| the table is "a strict superset of `intl`'s RTL class" (generator docstring, and an assertion in the first draft of the test) | **false** — `intl`'s RTL class contains 322 code points that are not strong-RTL, so no correct table can be a superset of it |
| the generator writes `strong_rtl_ranges.dart` | stale filename; the file had been superseded mid-session by `strong_bidi_ranges.dart` |

An ADR-first session would have had to state those numbers before there was any
code to make green, and the first two would have been caught by arithmetic
rather than by a late re-read. The lesson is the one this repo keeps
relearning — **a number written next to working code inherits the code's
credibility** — and it is filed as such in `session-lessons.md`.

## Context — what `intl` actually does, measured

`isolateWithin` decided whether to emit FSI/PDI by asking `intl` for a string's
first-strong direction:

```dart
if (Bidi.startsWithRtl(text)) return ambientIsRtl ? text : isolate(text);
if (Bidi.startsWithLtr(text)) return ambientIsRtl ? isolate(text) : text;
return text;
```

`intl` 0.20.2 (the pinned version) classifies with two hand-written character
classes and a UTF-16 regex:

```
_RTL_CHARS = ֑-߿יִ-﷽ﹰ-ﻼ
_LTR_CHARS = A-Za-zÀ-ÖØ-öø-ʸ̀-֐
             ࠀ-῿Ⰰ-﬜﷾-﹯﻽-￿
```

with a comment at the constant itself: *"not completely correct according to the
Unicode standard. They are simplified for performance and small code size."*

Measured exhaustively over all 1,114,112 code points against Python's
`unicodedata` (Unicode 15.0.0):

| | count |
|---|---|
| code points `intl` calls strong-**LTR** that are strong-**RTL** | **150** ← issue #137 |
| strong-RTL code points its RTL class does not reach at all | **1,783** |
| code points in its RTL class that are **not** strong-RTL | **322** |
| code points in its LTR class that are **not** strong-LTR | **3,308** |

### The bug is wider than #137 describes

#137 names Arabic Extended-A. The 150 misclassified code points all lie in a
single **stretch** of the code space, `U+0800–U+08C9`, spanning **five** blocks.
They are not contiguous *within* it — combining marks (`NSM`) and unassigned
points interleave, which is why the table below has gaps. Ten generated ranges
intersect this stretch — nine of them start inside it, and the tenth is the
`0x07FE, 0x0815` range that matters to the mutation note below:

```
U+0800..U+0815, U+081A, U+0824, U+0828, U+0830..U+083E   Samaritan          (40)
U+0840..U+0858, U+085E                                    Mandaic            (26)
U+0860..U+086A                                            Syriac Supplement  (11)
U+0870..U+088E                                            Arabic Extended-B  (31)
U+08A0..U+08C9                                            Arabic Extended-A  (42)
```

Arabic Extended-A is the last of the five, not the whole of it.

### And #137's own table understates it

The issue records `U+1E900` ADLAM CAPITAL LETTER ALIF as matching *neither* of
`intl`'s classes. That is true of the **code point** and false of the
**behaviour**: `intl` matches with a UTF-16 regex, so an astral character is
tested through its surrogates, and **all 1,024 high surrogates** `U+D800–U+DBFF`
sit inside `_LTR_CHARS` (`Ⰰ-﬜`). So `Bidi.startsWithLtr('\u{1E900}')`
returns **true**, and every astral RTL script — Adlam, Cypriot, Old Hungarian,
Kharoshthi; **1,632** strong-RTL code points, more than half of the 2,962 that
exist — read as strong-LTR. So does an emoji.

This is a second, independent defect. It is not a gap in a range table; it is
the wrong iteration unit. Widening the ranges would not have touched it, and the
first draft of this work widened the ranges and shipped the surrogate bug
forward.

### Why it was silent

The asymmetry #137 identified, restated: in RTL chrome the seam misreads the
content as LTR and isolates it, and `FSI` then resolves by the *real* first
strong character — which is RTL, matching the paragraph — so the isolate is
inert and the render is correct **by accident**. In LTR chrome the seam believes
content and paragraph agree, emits nothing, and #133's defect survives with
nothing going red.

## Decision 1 — Stop asking `intl`; derive both classes from Unicode

Not "widen the RTL table". The seam needs a **three-way** answer — RTL, LTR, or
*no direction at all* — and both of `intl`'s classes are loose, so the third
answer was being decided by whichever loose test happened to fire first.

`strongRtlRanges` (Bidi_Class `R` or `AL`; 2,962 code points in 132 ranges) and
`strongLtrRanges` (Bidi_Class `L`; 277,231 in 741) replace both. `intl` is no
longer imported by this library at all.

**Two tables, not one table and an `else`.** `isStrongRtl(r) ? rtl : ltr` would
be a two-way answer wearing a three-way signature, and it would classify every
digit, space, emoji and full stop as strong-LTR. The neutral case is the one
this seam most depends on: a string with no strong character *has* no direction
and must inherit the paragraph's. Forcing it to LTR is actively wrong in Arabic
chrome, which is the product's second language.

## Decision 2 — Iterate runes

```dart
for (final rune in text.runes) {
  if (isStrongRtl(rune)) return TextDirection.rtl;
  if (isStrongLtr(rune)) return TextDirection.ltr;
}
return null;
```

`String.runes` yields code points; iterating `codeUnits` would reproduce
`intl`'s surrogate defect against a correct table. This is asserted by a mutant
(`runes` → `codeUnits`), not by inspection.

## Decision 3 — The table is generated, and CI proves it is current

`tool/gen_bidi_rtl_ranges.py` emits the Dart file from `unicodedata`. 873 ranges
cannot be reviewed by eye — nobody checks `0x10AEB` against the UCD — so a typo
would be a silent wrong answer at the seam ADR-033 exists to make correct. The
table is therefore **derived, never edited**, and
`python3 tool/gen_bidi_rtl_ranges.py --check` runs in CI so the committed file
cannot drift from the generator. `tool/gen_bidi_rtl_ranges_test.py` proves the
generator itself, to the repo's usual convention.

**A generated file committed into a formatted tree has a trap, and this hit it.**
CI runs `dart format --set-exit-if-changed` over `app/lib`, which includes this
file. When the generator emitted anything the formatter would reflow — one line
that ran to **82 columns** on a long Unicode name, and every uncommented pair,
which `dart format` splits
one-per-line — the two gates contradicted each other **permanently**: format
rewrites the file, then `--check` calls the rewrite stale, and no edit satisfies
both. The generator now reproduces `dart format`'s own choices (long names
elided, uncommented values one per line), and a self-test pins that. Worth
naming because the symptom is a CI deadlock with two green-looking tools, each
correctly reporting the other's output as wrong.

**And the two failure modes of `--check` must not print the same sentence.** A
stale table is somebody's mistake; a Unicode version bump is news. The check
reads the version out of the committed file's header, compares it to the
interpreter's, and says which of the two happened — because the failure will
first fire on a runner-image upgrade nobody is expecting, and "the table is
stale" would invite someone to "fix" a correct table. A self-test asserts the
two messages are distinguishable.

**⚠️ The output is pinned to a Unicode version, which is pinned to a *Python*
version.** `unicodedata.unidata_version` is whatever the interpreter shipped
with; a CI runner on a newer Python emits a different table and `--check` fails
correctly but confusingly. The failure means *"Unicode moved"*, and the fix is
to run the generator and read the diff as a changelog. The emitted header states
the version on its second line so the diff says so itself. This is a real
maintenance edge and is written down rather than discovered.

## Decision 4 — The test asserts DISJOINTNESS, not agreement with `intl`

The obvious assertion — *"our RTL table is a superset of `intl`'s"* — is **false
and was written anyway** in the first draft (see the procedural note). `intl`'s
RTL class holds 322 code points that are not strong-RTL; a correct table cannot
contain them. An assertion phrased against a known-wrong oracle is worse than no
assertion, because it forces the wrong answer to stay wrong.

What is asserted instead is the property the implementation actually depends on:

- both tables sorted, non-overlapping, even-length — the binary search requires it;
- a **floor** on each table's size, because a table that has quietly become empty
  is the greenest possible input to every other test here;
- the two classes **disjoint**, scanned over all 1,114,112 code points. A code
  point in both would make `firstStrongDirection` order-dependent — the answer
  would depend on which `if` came first, which is precisely the accident that
  made `intl` usable at all and wrong at the edges;
- the specific characters #137 named **plus** the four blocks it did not, each
  paired with a live `Bidi.startsWithLtr` call proving `intl` still gets it
  wrong. When `intl` eventually fixes this, those assertions fail and say so.

## Decision 5 — Not upstreamed to `intl` (the issue's option 3)

#137 lists upstreaming as an option. Declined: `intl`'s classes are documented as
a deliberate size/performance trade, not a bug, and this seam needs a three-way
answer `Bidi` does not expose in any form. A correct fix upstream is a different
API, not a wider constant — and the product would still carry the defect for
however long the round trip took. The generator is 112 lines and adds no package.

**To be exact about what "`intl` is gone" means:** `intl` remains a `pubspec`
dependency and must — Flutter's generated localizations import it. What changed
is that after this ADR **no hand-written file under `app/lib/` imports it**; the
only four importers left are the generated `app_localizations*.dart`. The claim
is about this seam, not about the dependency graph.

## Verification

- **Red-first, at the render seam, in the issue's own words** — #137 asks for
  *"a red-first test for a `U+08A0`-leading string in LTR chrome"* using the
  existing geometry harness. Added to `content_text_test.dart`, measuring
  `RenderParagraph` box positions rather than the string, so it cannot be
  satisfied by the fix's own output.
- **Mutation-checked, three mutants, all caught:** `runes`→`codeUnits`; the two
  strong tests swapped in order; and the table ranges covering `U+0800–U+08C9`
  deleted, reintroducing `intl`'s exact gap — which reddens *both* the unit test
  and the geometry test.

  **The third mutant had to be built twice, and the first version overstated
  itself.** Deleting every range whose *start* falls in `U+0800–U+08C9` removes
  **nine** ranges and leaves **22** of the 150 code points still covered, because
  the generated table contains `0x07FE, 0x0815` — a single range that **spans
  `intl`'s class boundary**. `U+07FE`–`U+07FF` (NKO) are inside `intl`'s RTL
  class and `U+0800`–`U+0815` (Samaritan) are not, but Unicode assigns them all
  `R`, so the coalescer emits one range across the seam. The tests still went red
  (their fixtures live in Arabic Extended-A, which *was* removed), so the mutant
  did its job while the sentence describing it — *"reintroduces `intl`'s exact
  gap"* — was false. Rebuilt to split the range at `U+07FF` first; verified
  **0** strong-RTL code points remain covered in `U+0800–U+08C9`; both tests red.

  Worth keeping because the trap is general: **a mutation described by its intent
  rather than its measured effect is a claim about a test that was never made.**
- **Corpus measurement for the golden declaration (W4).** Every string in all
  three ARB files and all three content packs — **894** strings — was classified
  under both the old `intl` logic (emulated on UTF-16 code units, as `intl`
  matches) and the new one. **Zero change answer.** So the declared expectation
  is that **no golden moves**, and any golden that does move is a defect to
  explain rather than a diff to accept.

  *The first run of that scan examined 200 strings and reported zero changes.*
  Its ARB glob pointed at `app/lib/l10n/` and the files live in
  `app/lib/core/l10n/arb/`, so it had classified **no localized string at all**
  and printed the same reassuring zero. The rerun asserts a floor on the corpus
  before believing the result — the sentinel-of-the-sentinel shape ADR-052 used,
  needed here for the same reason: *a scan over an empty set is this repo's most
  familiar green.*

- **Result: `flutter test` — 1,743 tests, all passing; `git status --porcelain
  -- 'app/test/**/*.png'` empty.** The declared zero held.

## Consequences

**What this buys.** The seam is correct by construction rather than by luck, for
every script rather than the two the product ships. #133's defect can no longer
survive silently in the mirror direction. `intl` leaves the seam entirely.

**What it costs.** 23 KB of generated Dart (1,647 lines) and a binary search over
132 or 741 ranges per character until the first strong one — typically the first
character, at most a handful. The previous implementation ran two regexes over
the whole string.

**What is NOT fixed.** This is first-strong classification only. The Unicode
Bidirectional Algorithm proper — resolving embedding levels, mirroring,
reordering — remains the platform's job, which ADR-033 already decided and this
does not change. `Bidi_Paired_Bracket` and explicit-directional-formatting
characters embedded *inside* content are not considered.

**What no test here can prove.** That Unicode 15.0.0 is the right version to pin.
It is the version this repo's Python ships; a future runner will move it, and
Decision 3 describes what that failure looks like so it is read as news rather
than as breakage.
