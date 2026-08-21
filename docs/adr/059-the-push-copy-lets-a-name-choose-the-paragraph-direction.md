# ADR-059: the push copy lets a name choose the paragraph direction — in a branch nothing calls

- **Status:** Accepted — **revision 3** (2026-08-21, after the built-diff review)
- **Date:** 2026-08-21 (Session 083)
- **Deciders:** session agent (the fix is device-independent; the isolate question that is *not* stays blocked and is re-filed rather than guessed)
- **Related:** **ADR-033** (bidi isolation at the content-text seam; **D10** filed this as #136 rather than fixing it), **ADR-053** (the generated strong-bidi ranges), **ADR-012 / ADR-042 D4 / ADR-045** (the push kinds, the recipients, the hours), **ADR-058** (S082's legal draft, which this ADR corrects), issues **#136** (this one), **#133** (the app-side twin, closed by ADR-033)

> **Review status.** Revision 1 was written and committed **before** the fix
> (`session-context.md` §5 item 1, lesson 111). **The design pass has now run** —
> 4 lenses × 2 independent verifiers + a completeness critic, **25 agents, 0
> errored, 0 empty results**, 15 findings, 9 surfaced + 4 critic, **5 dropped
> unverified and listed at the end**. **Revision 2 is what it produced**, and one
> of its findings inverted the ADR's own severity claim.
>
> **The built-diff pass has now run too** — 4 lenses × 2 verifiers + a critic,
> **23 agents, 0 errored, 0 empty results, 9 findings, NOTHING dropped**, 5
> surfaced + 2 critic. **Revision 3 is what it produced**, and four of its
> findings were defects in the shipped code and test rather than in the prose.

> ⚠️ **This ADR does not do what `resume-prompt.md` told S083 to do, and that is
> stated plainly rather than absorbed.** The assigned objective was *"reorder the
> Arabic copy so a partner name never sits beside a bidi-neutral."* Measurement
> showed that is **impossible** — the neutral is inside the name — and that the
> severe defect is in a different locale. A deviation from an assigned objective
> is the session's to justify, not to quietly perform; the justification is
> Findings A and B, and the deviation is itself a finding the design review
> raised.

## Context — measured with the reference implementation

### The instrument, and its control

There is no Flutter here — the renderer is the OS notification shade — so
ADR-033's evidence and its instrument do not transfer. `tool/bidi_visual.py`
drives **FriBidi** (the reference Unicode bidi implementation, present as
`libfribidi.so.0`) through `ctypes` and returns the **visual** reordering of a
logical string.

**Its control is #133 itself** — the defect ADR-033 exists to fix, whose rendered
form the app-side doc records. Fed that string, the harness returns
`.Kahvaltıda birlikte gülmemiz :ﻚﻜﻳﺮﺷ ﺔﺑﺎﺟﺇ` — the recorded defect verbatim, on a
case whose answer was already known. Every measurement below comes from it.

### Finding 0 — the branch this is all about is UNREACHABLE, and #136 does not know that

**`partnerName` is supplied by no caller.** Both production call sites omit it:

```ts
// reveal-service.ts:341        // sweep-push.ts:80
composePush({ kind, language,   composePush({ kind, language,
  discreet });                    discreet, streakCount });
```

`grep -rn partnerName` over the whole repository returns `payload-policy.ts` and
its own unit tests, and nothing else; `git log -S` finds no call site that ever
passed one. So **every `partnerAnswered` push ever composed has used the
name-free copy** — *"Your partner answered"*, *"Partnerin cevapladı"*,
*"أجاب شريكك"*.

Issue #136 calls the defect **LATENT**, meaning *"no current notification
mis-renders, and it becomes live the first time a display name ends in
punctuation."* That is not the situation. It becomes live the first time
**a caller passes a name at all**, which has never happened. The issue's severity
paragraph, and revision 1 of this ADR which inherited it, both describe a defect
one step less remote than it is.

Two consequences, and revision 1 got the second one wrong:

* The fix below is **pre-emptive**, not remedial. It is still worth doing — the
  branch is live, tested code that is one argument away from being reached, and
  the measurement is cheap now and expensive after it ships — but it fixes
  nothing any user is experiencing.
* **Revision 1's Consequences claimed *"a user whose partner has an Arabic name
  stops receiving backwards notifications."* That is false.** No user receives a
  name at all. The claim is deleted rather than softened, because it asserted a
  user-visible benefit that cannot exist.

**And it makes a sentence in ADR-058's legal draft wrong.** That draft — merged
one session ago — tells Arabic users *"in its ordinary form a notification can
show your partner's name."* With no caller supplying one, it cannot. **The same
class of error S082 existed to correct, committed by S082, in the direction of
over-disclosure.** Corrected here (Decision 5).

### Finding A — where the severe defect would be, and it is not Arabic

`partnerAnsweredNormal` puts `${name}` **first** in the TR and EN strings. A
first-strong renderer takes the paragraph direction from the first strong
character — which, when the placeholder leads, is *the name's script*:

```
logical : أيلين answered today's question. Open ikimiz to add yours.
visual  : .answered today's question. Open ikimiz to add yours ﻦﻴﻠﻳﺃ
```

The whole English sentence laid out right-to-left, its final stop at the head of
the line. Not a stray mark beside a name — the entire notification backwards, for
an English- or Turkish-reading user, because of who their partner is.

**The Arabic copy is immune**, because `أجاب ${name}` opens with a verb. Revision
1 called that *"by accident rather than by design"*; the review pushed back and is
right — Arabic is VSO, so verb-first is the natural construction, not a lucky
one. What is accidental is only that nobody checked whether the property held in
the other two languages, where it does not.

**Honest bound (Finding C below):** this depends on the shade using first-strong
detection. Under a shade that forces the UI locale's direction it does not occur.
That dependency is real and is why the word *"severe"* belongs to the failure
mode, not to a measured field incidence.

### Finding B — the Arabic defect is real, and reordering CANNOT fix it

```
أجاب Aylin Y.  →  .Aylin Y ﺏﺎﺟﺃ          أجاب Aylin!  →  !Aylin ﺏﺎﺟﺃ
```

The #133 shape: the name's own trailing punctuation resolves to the paragraph
direction and detaches to the far side of the Latin run. The body breaks the same
way. **The neutral is inside the name**, so no arrangement of *our* words helps.
#136's step 3 addresses a neutral *our copy* contributes — sound for that case,
insufficient for the one the issue names.

**Brackets: matched are safe, unmatched are not.** Revision 1 tested only
`Ayşe (Y)` (correct — Unicode N0/BD16 resolves a *matched* pair to the enclosed
text) and generalised to all brackets. The review measured the rest:

```
أجاب Aylin (  →  ) Aylin ﺏﺎﺟﺃ        أجاب Aylin)  →  (Aylin ﺏﺎﺟﺃ
```

An unmatched bracket is an ordinary neutral and jumps exactly like a period —
and it mirrors on the way, so `(` arrives as `)`. Emoticon-suffixed names
(`Sarah :)`) are the realistic case.

### Finding C — the two defects have different dependencies

Finding A reproduces under **first-strong** detection and not under a
forced-locale shade. Finding B reproduces under **both**. Neither of the fixes
below depends on the answer to #136's step 1 (does the shade honour
`U+2068`/`U+2069`), which remains a device question nobody can answer from here.

## Decision 1 — Put a strong copy-language word before the placeholder, in TR and EN

The named variants become the name-free variants with the name inserted after the
opening word — which is what the copy already said without it:

| | before | after |
|---|---|---|
| EN title | `${name} answered` | `Your partner ${name} answered` |
| EN body | `${name} answered today's question. …` | `Your partner ${name} answered today's question. …` |
| TR title | `${name} cevapladı` | `Partnerin ${name} cevapladı` |
| TR body | `${name} bugünün sorusunu cevapladı. …` | `Partnerin ${name} bugünün sorusunu cevapladı. …` |

Measured with an Arabic name, correct under auto-detect **and** forced-LTR:
`Your partner ﻦﻴﻠﻳﺃ answered today's question. Open ikimiz to add yours.` ·
`Partnerin ﻦﻴﻠﻳﺃ cevapladı`.

Paragraph direction is decided by the *first strong character*, which is a
property of the sentence we author. That is why reordering is the right
instrument here and the wrong one for Finding B. The Arabic is unchanged: it
already satisfies the rule.

## Decision 2 — Strip leading/trailing NEUTRALS from the name, in the RTL copy only

`sanitizePushName(name, language)` in `functions/src/notifications/`, called from
**`partnerAnsweredNormal`** — the one function that interpolates a name — before
either string is built. That call site is named here because revision 1 specified
the function and not its caller, which the completeness critic caught.

The rule, corrected on three counts:

* **Neutrals only — never "weak".** Revision 1 said *"neutral or weak"*. In
  Unicode TR9 the weak types include **EN (European Number)**, so a literal
  implementation would strip digits and turn `Aylin 2` into `Aylin`. Digits are
  measured harmless (`أجاب John 3` → `John 3 ﺏﺎﺟﺃ`). The set is the ON/WS/S/B
  neutrals — `.` `!` `?` `…` `:` `،` `-` and kin.
* **Unmatched brackets ARE stripped; matched pairs are not.** Finding B.
* **Applied only when the copy's paragraph is RTL** — i.e. `ar`. Measured: in an
  LTR paragraph a trailing neutral causes no defect at all
  (`Aylin Y. answered today's question.` is byte-identical logical-to-visual), so
  trimming it in EN/TR would remove a character from someone's name **for no
  rendering benefit**. Revision 1 applied it to all three languages and cited
  ADR-052's single-definition argument for doing so; the review refuted both —
  ADR-052 is about `BoxDecoration` values and says nothing that transfers, and
  the symmetry it was invoked to justify is a cost with no return. **One rule,
  conditioned on the thing that actually varies: the paragraph's direction.**
* If nothing strong remains — a name that is entirely punctuation — return
  `undefined`, so the existing, already-tested name-free copy is used.

**The cost, stated rather than buried:** in Arabic, `Aylin Y.` displays as
`Aylin Y`. A person's name loses a trailing full stop on a lock screen. That is
the lesser of two evils — the alternative is the same name with its period on the
wrong side — and it is recorded so a native reviewer can overturn it in one
sentence.

## Decision 3 — No `U+2068`/`U+2069` enters a push payload

Not because the payload is *"persisted, exported or shared"* — revision 1 said
that and the review was right that it is a stretch. ADR-033 D4 names those three
seams concretely (Firestore documents, the data-rights export, the invite share
string) and a push payload is none of them. The real reasons are narrower and
sufficient:

* **ADR-033's general principle** is *"isolate for rendering, never for outgoing
  text"*, and a push payload is outgoing text — handed to FCM and APNs, both of
  which log and store it, and to a notification database on the device.
* **Whether the shade honours them is unmeasurable from here**, and #136 says so:
  *"do not assume it works — measure on a device, and if it cannot be measured,
  say so rather than shipping invisible control characters into a push payload on
  faith."*
* **Decisions 1 and 2 need neither answer.**

Step 1 of #136 stays open and **device-blocked**. If a device ever shows the
isolates working, that is an improvement on this fix — it would let a name keep
its own punctuation — not a correction of it.

## Decision 4 — The test asserts the rule, and the rule is about the first STRONG character

FriBidi does not run in the Node suite, so the measurement is done once, here,
and what ships is the invariant it established:

1. **The first STRONG character of every composed string must come from the
   copy, not from the name.** Revision 1 wrote *"must not begin with the name"*,
   which is weaker in a way the review demonstrated: a copy that opened with a
   neutral (`• ${name} answered`, or a quote) would pass while the defect
   remained, because P2 skips neutrals when resolving paragraph direction. The
   assertion composes each `(kind × language)` with a known-RTL name and requires
   the first character of bidi class L or R to be one the copy contributed.
   *(This also disposes of the `streakAtRisk` Turkish string, which opens with
   `${count}`: digits are **weak**, so they never set paragraph direction, and the
   first strong character is still Turkish.)*
2. **The sanitiser's contract, by value** — an input/output table, because a
   behavioural test of a trimming rule cannot see *which* characters it trims
   (lesson **117**). Including `Aylin Y.` → `Aylin Y`, `Ayşe (Y)` → unchanged,
   `Aylin (` → `Aylin`, `Aylin 2` → unchanged, `...` → `undefined`, and every
   case unchanged under `en`/`tr`.
3. **The fallback is reached**, not merely available: an all-punctuation name
   produces the byte-identical name-free payload.
4. **A floor on the input** (lesson **110**): the number of `(kind, language)`
   pairs the sweep examined is asserted, so a matcher that matched nothing cannot
   report a clean zero.

`tool/bidi_visual.py` ships with the fix. It is a **tool, not a gate** — nothing
in CI runs it — and it exists so a later session can re-derive the rule, or
answer step 1 the day a device exists, without rebuilding the instrument.

## Decision 5 — Correct ADR-058's legal draft in the same diff

`docs/legal/proposed/privacy-policy.{en,tr,ar}.md` says a notification *"can show
your partner's name"*. Finding 0 makes that untrue. The sentence is corrected to
describe what the system does today — notifications name no one — while keeping
the discreet-mode explanation, which is about what *would* be shown and remains
the honest bound.

This is not scope creep: it is a correction to a document this project merged one
session ago, of exactly the defect class that document exists to remove, found by
the next session's measurement. Leaving it for the founder's lawyer to trip over
would be the worse choice.

## Consequences

* **No user-visible change today.** The branch is unreachable; this is the
  specification being made correct before it is wired. Revision 1's claim of a
  user-visible win is withdrawn.
* **The wiring gap is filed** rather than fixed here: `partnerAnswered` is
  supposed to name the partner and does not, which is a product gap needing a
  server-side display-name lookup — a feature, not this fix.
* **#136 stays open** for step 1, the device question. Its severity is now
  recorded accurately: unreachable today; on wiring, a wrong-way period in
  Arabic and a reversed paragraph in TR/EN.
* **Four `partnerAnswered` strings changed**, so any native review of them is
  stale. `operator-expected.md` item 13 already covers native review of
  user-visible strings; these four join it.
* **`docs/test-suite.md` gains the new assertions**, which revision 1 omitted
  from its document list.
* **This does not repeal ADR-033**, which governs the app-side render seam. Two
  seams, two mechanisms — and ADR-033 **D10 filed this as #136** rather than
  fixing it. *(Revision 1 said D10 "predicted the split"; it did not predict
  anything, it deferred work under the scope guard. Corrected.)*
* **The sanitiser is a display transformation only.** No stored name is altered;
  the profile, the export and the app are untouched.

## What the design pass changed, and what it dropped

**Surfaced and acted on:** Finding 0 (unreachable, not latent — and revision 1's
false user-benefit claim) · unmatched brackets · *"neutral or weak"* including
digits · EN/TR trimming having no benefit · the ADR-052 miscitation · the
*"plausibly all three"* stretch of ADR-033 · the test's first-character vs
first-strong-character gap · the sanitiser's unspecified call site ·
`test-suite.md` missing from the document list · the unacknowledged deviation
from the assigned objective · *"D10 predicted"* · *"by accident"*.

**Dropped UNVERIFIED at the cap of 10 — listed because an unverified finding is
not a refuted one** (`session-context.md` §5 item 6): *"D10 predicted the split
mischaracterises D10"* · *"#136 scope mismatch: filed for Arabic, fix changes
EN/TR"* · *"`Aylin Y.` may not be a realistic display name — source untraced"* ·
*"Finding C's independence claim obscures that Decision 1 addresses a defect that
may not exist"* · *"by accident rather than by design understates Arabic word
order"*. Two of the five were cheap enough to act on anyway (D10, *"by
accident"*); the other three are recorded here and not adjudicated. Notably the
third — where display names actually come from — is **subsumed by Finding 0**:
no name reaches this code from anywhere, so the question of which names are
realistic has no answer to measure yet.

## What the built-diff pass changed (revision 2 → revision 3)

**23 agents, 0 errored, 0 empty results, 9 findings, none dropped**, 5 surfaced +
2 from the critic. Unlike the design pass, most of what it found was **in the
code**, and three of the four were caught by measuring cases the implementation's
own examples did not contain.

| # | severity | what the implementation got wrong |
|---|---|---|
| 1 | major | **Improperly nested brackets were called matched.** The matcher used `open.splice(i, 1)`, removing only the partner; Unicode N0/BD16 discards **every** bracket opened after it. So `(A [B)]` was fully "matched" and kept — and measured, that trailing `]` jumps to the head of the line and **mirrors into a `[`**, which is the exact defect the function exists to prevent. One character: `open.length = i` |
| 2 | major | **A matched pair may WRAP the whole name, and then its contents are at the edge.** `Ayşe (Y)` — the only bracket example revision 2 had — contains no neutral to detach. `(Aylin Y.)` does: measured, it renders `(.Aylin Y)`, the period landing *inside* the bracket. The brackets being safe does not make what they contain safe. The trim is now **recursive** through a wrapping pair |
| 3 | major | **The test's own RTL predicate was broken, in a way that reads as fine.** `/[֐-ࣿיִ-﷿ﹰ-﻿]/u` — the Hebrew point in that class is **two codepoints** (U+05D9 + U+05B4), so it parsed as a range **U+05B4–U+FDFF**: 63,000 codepoints, calling Devanagari, Thai, Hiragana and Han "RTL". A test whose direction predicate is wrong agrees with whatever it is shown. Replaced with `\p{Script=…}` — and the lesson is one this repo already paid for, which is why **ADR-053's app-side table is GENERATED** rather than hand-written |
| 4 | major | **The Arabic legal example used the FEMININE verb** (`أجابت أيلين`) while the code emits the masculine default (`أجاب`), which `payload-policy.ts` states in a comment. Inherited from S082's draft. The EN and TR examples matched their templates exactly; only the Arabic did not — a locale saying something the others do not, which `docs/legal/README.md` forbids |
| 5 | minor | `tool/bidi_visual.py`'s `PUSH_SAMPLES` claimed *"every shipped push string that interpolates something"* and **omitted the Turkish body**. Added, along with the two bracket names findings 1 and 2 turned up |

**Re-mutation-checked after the fixes** (two more, on top of the original four):
restore the `splice`, and disable the wrapper recursion. Each reddens exactly its
own case; control green; tree restored byte-identical.

**Refuted by both verifiers and recorded rather than silently kept:**

* *"Combining marks at a leading edge are mishandled."* Requires defectively
  combined input (a mark with no base); in valid Unicode the mark follows its
  base and is never at the edge alone.
* *"`firstStrong` misses Greek and Cyrillic."* True of the first version and
  fixed in passing by finding 3's rewrite; both verifiers held it was not a
  defect anyway, since it is a test utility exercising Latin and Arabic copy.
* *"The commit message's emulator claim is unverifiable."* `session-rules.md` §2
  sets the bar at *"all tests green **locally**"*, with CI as the post-push check.
* *"The TR body was never measured, only the TR title."* Both share the same
  first strong character, which is the whole property.

**Not fixed here, and named rather than left implicit:** ADR-059 is not in
`docs/adr/README.md`'s index — but neither are ADRs 049–058, and that whole
backlog is issue **#248**. Adding one row would deepen the gap rather than close
it.
