# ADR-033: Bidi isolation belongs at the STRING boundary, not the widget seam — and it applies to content, not chrome

- **Status:** Accepted
- **Date:** 2026-07-27 (Session 051)
- **Deciders:** session agent (no founder input needed — a rendering defect with no product, cost, or live-system decision attached)
- **Related:** issue **#133** (this ADR closes it), ADR-025 (the slice-0 invariant firewall and the **D8 golden re-baseline protocol** this diff must obey; **D5.iii** the frozen-sentence digest this diff must NOT trip), ADR-011 (the pack-source seam that makes UI-locale ≠ content-language a shipped configuration), ADR-026 (the seasonal vocabulary, unrelated but adjacent in the same reader), `tool/rtl_lint.dart` (the physical-direction firewall a widget-level fix would have had to escape), `docs/frontend-brandkit.md` §4, `docs/test-suite.md`

## Context

`app/test/features/daily_question/presentation/goldens/paired_home_screen/revealed_streak.ar.rtl.png` — a **committed** golden — renders three strings with their terminating punctuation on the wrong end:

| Should read | Actually renders |
|---|---|
| `…küçük bir şey ne?` | `…küçük bir` / **`?şey ne`** |
| `Kahvaltıda birlikte gülmemiz.` | **`.Kahvaltıda birlikte gülmemiz`** |
| `Sabah çayını birlikte içmemiz.` | **`.Sabah çayını birlikte içmemiz`** |

Unicode bidi is behaving **correctly** for the input it was given. A bidi-neutral character (`.` `?` `!` `…`) at the boundary of an LTR run inside an RTL paragraph takes the *paragraph* direction unless it is isolated. There is no Flutter bug to work around; there is a missing isolate at our seam.

### Why this is not a cosmetic edge case

`RelationshipProfile.contentLanguage` is a **separate field from the UI locale** (`app/lib/features/profile/domain/relationship_profile.dart:77`; chosen on the profile-capture screen at `profile_capture_screen.dart:46`, labelled "Question language"). A user picks their questions' language independently of their interface language. Arabic chrome around Turkish content is a **shipped configuration**, not a hypothetical.

It is also the *current default*: ADR-011 keeps the couple bank on `solo_tr` as a placeholder until W9, so **every Arabic-UI couple sees Turkish questions today**.

And the two things the defect mangles — the daily question and the answers each partner writes — are the two things the product is about.

### Measured, not assumed

Every claim below was measured with throwaway probes against Flutter 3.44.5 / `intl` 0.20.2, reading `RenderParagraph.getBoxesForSelection`, before any of this was written. Addendum 44: test the tool against a realistic artefact rather than reasoning about its flags.

| Probe | Input | Terminator box (paragraph is 320 px wide) |
|---|---|---|
| A1 | `Kahvaltıda birlikte gülmemiz.` in an RTL paragraph | `.` at **194–208**, `dir=rtl` — *the defect* |
| A2 | same, wrapped in `U+2068 … U+2069` | `.` at **306–320**, `dir=ltr` — *fixed* |
| A3 | same, pristine + `Text(textDirection: ltr)` | `.` at **112–126** — punctuation fixed, **block flipped to left-aligned** |
| B1 | `أجبتما كلاكما اليوم.` in an RTL paragraph | `.` at 40–54 — correct, control |
| **B2** | **`أجبتما كلاكما اليوم.` in an LTR paragraph** | **`.` at 266–280 — the MIRROR defect, not mentioned in #133** |
| B3 | same, FSI-wrapped | `.` at 0–14, `dir=rtl` — fixed |
| C1/C2 | `قالت Ayşe شيئًا جميلًا.` in RTL, without / with FSI | **26–40 in both** — FSI is a no-op when the first strong character already matches |
| E1 | `ABC-234-XYZ.` in an RTL paragraph | `.` at 152–166 — identifier-shaped strings are affected too |

## Decision 1 — Isolate at the **string boundary** (FSI/PDI), not at the widget

`#133` and the session brief both flagged this as the question deserving adversarial attention. The answer is decided by a case a widget-level fix **structurally cannot reach**:

```
app_ar.arb  invitePreviewInvitedBy        : "دعاك {name}"
app_ar.arb  invitePreviewCreatorAnswered  : "إجابة {name} جاهزة — تنكشف عندما تكتب إجابتك."
```

`{name}` is a partner's display name — arbitrary script — interpolated **into the middle of a localized Arabic sentence** (`partner_preview_screen.dart:312` and `:435`). A `Directionality` ancestor or a `Text(textDirection:)` override sets the direction of the **whole paragraph**; it cannot isolate one run inside a sentence whose remainder must stay Arabic. Only an inline isolate can.

Three further reasons, in descending weight:

1. **It needs no `TextDirection` literal at any call site.** `tool/rtl_lint.dart:23` bans `\bTextDirection\.(ltr|rtl)\b` across `app/lib`. The widget-level fix would have required an `// rtl-ok` escape on **every one of the eleven sites** — weakening a firewall guard, at scale, to fix a bug the firewall was never aimed at.

   **Stated honestly after implementation: this argument survives in reduced form, not intact.** D9's golden reconciliation forced the seam to become *conditional* (isolate only when the directions actually differ), and the predicate needs the ambient direction — so there is now exactly **one** `// rtl-ok`, in `bidi_isolate.dart`, in the single function whose whole job is to reason about direction. One escape in the seam is a different thing from twelve escapes across the feature tree, but it is not zero, and the first draft of this decision claimed zero.
2. **It preserves block alignment.** Probe A3 shows the widget-level fix left-aligns the paragraph inside a right-aligned card, putting a right-aligned caption over a left-aligned body. FSI fixes the punctuation and leaves the block where the chrome puts it.
3. **It composes.** Isolates nest; a paragraph direction override does not.

### What we are explicitly NOT using

`intl` **does not expose FSI/PDI at all**. `bidi.dart:25-38` offers only the deprecated *embedding* controls (`LRE`/`RLE`/`PDF`), and `BidiFormatter.wrapWithUnicode` emits those. The constants are therefore defined locally.

More importantly, **`Bidi.detectRtlDirectionality` is not first-strong** — it is a majority-of-strong-characters heuristic, and it disagrees with FSI. Measured:

| String | `Bidi.startsWithRtl` | `Bidi.detectRtlDirectionality` |
|---|---|---|
| `العربية is a beautiful language indeed.` | **true** | **false** |
| `Ayşe قالت شيئًا جميلًا جدًا اليوم هنا.` | **false** | **true** |

Both rows disagree. A future session reaching for `detectRtlDirectionality` because the issue text said "Flutter exposes this as `Bidi.…` helpers" would get *different* behaviour from the isolate this ADR specifies.

**Precisely what we do and do not call, since D9's conditional rewrite made the first draft of this paragraph imprecise:**

- We **never** call `detectRtlDirectionality` or `estimateDirectionOfText`. Those are the majority heuristics, and they are the trap.
- The **direction that governs rendering** is still resolved by the platform: we emit `U+2068`/`U+2069` and let Flutter's Unicode Bidi implementation pick first-strong — the same rule HTML `dir="auto"` uses.
- We **do** call `Bidi.startsWithRtl`/`startsWithLtr`, but only to decide **whether emitting the controls would change anything at all**. Those two are genuine first-strong tests (read the source: skip everything that is not the opposite strong class, then require a strong character of the target class), so they agree with the isolate rather than competing with it. Their one weakness is range coverage, recorded as the `// DEBT:` in D2 and as **#137** — ✅ resolved by **ADR-053**, which replaced both `intl` calls with generated Unicode tables. The reasoning here (that first-strong agrees with `FSI` rather than competing with it) is unchanged; only the source of the classification moved.

## Decision 2 — The seam is two pure functions plus one widget

`app/lib/core/l10n/bidi_isolate.dart`

- `String isolate(String text)` → `'⁨$text⁩'`, the **unconditional primitive**. Returns `text` unchanged when empty, so we never emit two invisible controls around nothing.
- **`String isolateWithin(String text, TextDirection ambient)` — this is what call sites actually use.** It applies `isolate` only when `text`'s own first-strong direction differs from `ambient`; otherwise it returns `text` untouched. D9 explains why the conditional form is load-bearing rather than an optimisation: unconditional isolation is semantically inert but *not pixel-neutral*, and it churned 27 goldens.
- Exported constants `firstStrongIsolate` / `popDirectionalIsolate` so tests and call sites never re-spell the code points.

**Known limitation, recorded rather than hidden (rule 9)** — ✅ **RESOLVED by ADR-053 (Session 076, issue #137).** The seam no longer consults `intl` at all; it classifies runes against generated Unicode `Bidi_Class` tables. The measurement below stands as written and was found to *understate* the defect twice: the misclassified region is `U+0800–U+08C9` across **five** blocks rather than Arabic Extended-A alone, and Adlam does not "match neither class" in practice — `intl` matches UTF-16 code units, every high surrogate sits inside its LTR class, so `startsWithLtr` returns **true** for all 1,632 astral strong-RTL code points, and for emoji. The original text follows unedited.

`isolateWithin` gets first-strong from `Bidi.startsWithRtl`/`startsWithLtr`, whose character classes are `֑-߿`, `יִ-﷽`, `ﹰ-ﻼ`. **Arabic Extended-A (U+08A0–U+08FF) is not in the RTL class — and worse, intl's LTR class matches it.** Measured: `U+08A0` is Bidi_Class **AL** (strong RTL), yet `startsWithLtr` returns `true` for it. Adlam (U+1E900) matches *neither* class. Consequence: content beginning with such a character, rendered in **LTR** chrome, is silently left un-isolated and the mirror defect survives. Bounded and low-risk for this product — Gulf Arabic and Turkish both sit inside the covered ranges — but it is a **silent** failure, so it carries a `// DEBT:` comment at the seam and an issue.

`app/lib/core/widgets/content_text.dart`

- `ContentText` — the ergonomic seam for "this whole `Text` is content". It renders `Text(isolateWithin(data, Directionality.of(context)), semanticsLabel: data, …)` and forwards the style/align/maxLines/overflow arguments the call sites already use.
- **`semanticsLabel` carries the PRISTINE string.** Flutter's `Text` replaces the subtree's semantics when `semanticsLabel` is non-null (`text.dart:802-807`), so the accessibility tree never sees the control characters even though the paragraph does. This is strictly better than the status quo, where the a11y label is whatever `data` happens to be.

For interpolation into a localized sentence, call sites pass an isolated *argument*: `l10n.invitePreviewInvitedBy(isolateWithin(name, Directionality.of(context)))`. There is no widget for this and there should not be — the unit being isolated is a run, not a paragraph.

## Decision 3 — The boundary: isolate **content**, never **chrome**

**Isolated** — the string's script is not guaranteed to match the ambient direction. Line numbers are the **render** sites as built, not the construction sites: `_AnswerCard` is built from three places (`:407`, `:416`, `:738`) and renders once, which is why the count below is 11 and not the 14 rows a construction-site listing would produce.

| Render site | What |
|---|---|
| `paired_home_screen.dart:678` (`_QuestionCard`) | the daily question (pack language ≠ UI locale) |
| `paired_home_screen.dart:814` (`_AnswerCard`) | both partners' answers — free text |
| `solo_home_screen.dart:203` | the solo question |
| `coach_screen.dart:434`, `:489`, `:537` | the user's turn, the model's reply, the help-card body |
| `partner_preview_screen.dart:409` | the invite's question hook |
| `paywall_screen.dart:404` | the store-formatted price |
| `partner_preview_screen.dart:312`, `:435` | the partner's display name, isolated as an **argument** into the localized sentence |
| `paywall_screen.dart:419` | the per-month price, same argument shape |

**8 `ContentText` + 3 isolated arguments = 11.**

**Deliberately NOT on this list, after measurement: the invite code** (`invite_share_screen.dart:81`). A first draft of this ADR included it, generalising from probe E1 (`ABC-234-XYZ.`). That fixture was wrong for the real string:

- `INVITE_CODE_ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'` (`functions/src/invites/invite-code.ts:9`) — the code **cannot contain a bidi-neutral character**, so there is nothing whose placement could be wrong.
- Isolating it would be an active **regression**. `invite_share_screen.dart:84` carries the only `letterSpacing` in all of `app/lib`, and Flutter applies letter-spacing after the zero-width isolate controls too. Measured intrinsic width at `letterSpacing: 4`: `ABCD2345` = **144.0 px**, isolated = **152.0 px** — a centred block 8 px wider and 4 px displaced, for no benefit.

This is why `isolate()`'s doc comment carries the letter-spacing consequence: the next site that pairs the seam with `letterSpacing` inherits the same 2 × spacing widening.

**Not isolated**, with the reason stated rather than left implicit:

- **Localized chrome.** The app derives text direction from the UI locale — verified: `app.dart:97-113` has no `localeResolutionCallback`, no `Localizations.override`, and no root `Directionality`, so the framework resolves direction from the resolved locale. The `tr.rtl` / `en.rtl` / `ar.ltr` golden cells that show the defect on chrome are therefore **synthetic**: they force a direction no production build can produce (the six-cell contract decouples them on purpose, `golden_harness.dart:21-32`).

  **The precise reason chrome is safe is NOT that chrome is single-script — it is not** (see the pre-code review outcome below). It is that a chrome sentence's **first-strong direction equals the paragraph direction**, so its bidi-neutrals resolve to the direction they already belong to, *including* when the sentence embeds an opposite-direction run. Measured on the four Arabic chrome strings that embed Latin brand names next to a neutral: whole-string isolation is **byte-identical geometry**, against a Latin-sentence control that correctly DIFFERS. Isolating chrome would churn roughly a hundred goldens and change nothing.
- **Legal document bodies** (`legal_renderer.dart:119-133`) — loaded from a per-locale asset (`<doc>.<locale>.md`), so the body's *sentence* direction matches the resolved locale. Same measurement, same result: an Arabic legal sentence carrying `Claude API.`, `Google Cloud Firestore.` and `Anthropic،` is byte-identical isolated or not.
- **The data export** (`export_screen.dart:89`, the only `SelectableText` in the app) — machine-readable JSON that the user copies to the clipboard. `SelectableRegion._copy` puts `plainText` on the clipboard verbatim; isolating it would ship invisible control characters into a file the user may parse. Never isolate what leaves the app.
- **The share-sheet message** (`inviteShareMessage`, sent to the partner over WhatsApp/SMS). Same rule: **isolate for rendering, never for outgoing text.**

## Decision 4 — Isolation is applied at RENDER only

Nothing is isolated at rest. Firestore documents, the export payload, ARB values, and the share string all stay pristine. Two consequences worth naming:

1. ADR-025 **D5.iii's frozen-sentence digest** hashes ARB `locale.key=value` pairs. Because no ARB value changes, the digest is untouched and must stay green — if it goes red, this diff did something it did not intend.
2. `LengthLimitingTextInputFormatter` (`paired_home_screen.dart:433`, `solo_home_screen.dart:216`) caps *input*, not render. Character budgets are unaffected.

## Decision 5 — The mirror case is in scope

Probe **B2**: Arabic content inside Turkish/English LTR chrome puts its terminator at the run's right edge instead of its left — the same defect, mirrored. #133 does not mention it; it is real and reachable today (`contentLanguage: ar` with a `tr` interface). The same isolate fixes it (probe B3), and the tests assert **both** directions so a future one-directional regression is caught.

> ~~No existing golden covers it: the golden fixtures render `solo_tr` content, so no cell pairs Arabic *content* with LTR chrome.~~
>
> **Struck 2026-07-27, same session — this was false, and the golden suite is what caught it.** I generalised from `paired_home_screen`, whose fixtures *are* Turkish in every locale (ADR-011's `solo_tr` placeholder). But `coach_screen_golden_test.dart:45-58`, `solo_home_screen_golden_test.dart:47` and `partner_preview_screen_golden_test.dart:158-161` all key their content fixtures to **the cell's locale**, so every `ar.*` cell renders genuinely Arabic content — and `conversation.ar.ltr` is Arabic content in an LTR paragraph. The mirror case was sitting in the committed goldens the whole time. Three `*.ar.ltr` cells moved when this fix landed; see D9.

The new test covers the mirror case *deliberately* rather than incidentally, which the goldens did not.

## Decision 6 — What first-strong gets WRONG, written down

The session brief asked for the mixed cases the choice mishandles. There are some, and pretending otherwise would be the failure mode:

- **`"Netflix أفضل من التلفاز."`** — an Arabic sentence opening with a Latin brand name. First strong character is Latin, so the isolate resolves **LTR**, the Arabic body renders as an RTL run inside an LTR block, and the period binds to the *sentence-as-LTR*. An Arabic reader would want RTL. This is wrong, and it is the exact case where a majority heuristic would be right.
- The symmetric case — **`"العربية is a beautiful language indeed."`** — is one a majority heuristic gets wrong and first-strong gets right.
- Neither rule is correct on both. We take first-strong because it is what Unicode specifies for `FSI`, what `dir="auto"` does on the web, and — decisively — because it needs no language detection at all, so it cannot drift as a heuristic's thresholds change under us.
- **Strings with no strong character** (a bare `"2026"`, `"…"`, an emoji-only reply) have no first-strong to find; the isolate resolves to the paragraph direction, which is the pre-existing behaviour. No regression, no improvement.

## Decision 7 — The failing test asserts geometry, not the mechanism

`app/test/core/widgets/content_text_test.dart` — the geometry assertion, the `ContentText` contract, and the `isolate()` unit rows all live in the one file (the seam is small enough that splitting it would separate the guard from the thing it guards):

> The terminator must bind to the **trailing side of its own run**: for LTR content, `terminatorBox.left >= lastLetterBox.right`; for RTL content, `terminatorBox.right <= lastLetterBox.left`.

Stated this way the assertion is **alignment-independent** — it does not encode "the period is at x=306", which would break the moment a card's padding changes — and it is **not self-referential** (addendum 43): it reads `RenderParagraph.getBoxesForSelection`, a framework API, and never calls `isolate()`. Deleting the isolate from production code moves the box and turns it red. Measured red/green from the probes: A1 `.left=194` vs `z.right=320` (red) → A2 `.left=306` vs `z.right=306` (green).

**MUTATION-CHECK, both directions** (addendum 43/47): remove the isolate → red; isolate only the leading side → red; keep the isolate but assert the LTR rule against RTL content → red. Run the neighbouring DTO/widget tests after, since a new guard can make old rows vacuous.

## Decision 8 — `find.text` breakage is accepted, and made visible

Measured: `find.text('Kahvaltıda birlikte gülmemiz.')` returns **0** matches against an isolated `Text`; `find.textContaining` still returns 1. Roughly 17 assertions across `paired_home_screen_test.dart` and `invite_share_screen_test.dart` match content strings exactly.

They move to `find.text(isolate('…'))`. This is deliberate: after this diff, **a test that still matches the raw string is a test rendering un-isolated content**, which is exactly the signal we want. The alternative — keeping the string pristine via `Text(textDirection:)` — was rejected in Decision 1 for reasons that outrank test churn.

**The dangerous half is `findsNothing`, not `findsOneWidget`** — addendum 47's "a new rule can make old rows vacuous", and the pre-code review's most useful catch. These four assertions:

| Site | Assertion |
|---|---|
| `paired_home_screen_test.dart:248`, `:510` | `expect(find.text('EN paired question 1'), findsNothing)` |
| `coach_screen_test.dart:314`, `:326` | `expect(find.text('Coach message.'), findsNothing)` |

go **green either way** after isolation: the raw string stops matching whether the content is genuinely absent *or* present-and-isolated. A `findsOneWidget` row fails loudly and gets fixed; a `findsNothing` row passes silently and stops testing anything. Every one of them must move to the isolated query in the same commit, and the migration is not complete until `findsNothing` rows are audited specifically.

**As built, the migration was FOUR assertions, not seventeen** — the conditional seam of D9 leaves `tr`/`en` cells pristine, so only the `ar` rows moved, which are exactly the defect cases. The four `findsNothing` rows moved to `find.textContaining`, which matches through the isolate and so can still fail.

**The build-diff review's fair objection, answered rather than dismissed:** those four migrated rows now build their expected string with `isolateWithin(...)` — the same function the production code calls. That *is* the self-referential shape addendum 43 warns about, and if `isolateWithin` were wrong those rows would agree with it. It is accepted here because of a division of labour that must survive future edits: **the migrated rows are LOCATORS, not behaviour assertions.** What the seam actually does is proven by `content_text_test.dart`'s geometry rows, which never call `isolate` or `isolateWithin` and measure the framework's layout output instead. Delete or weaken those geometry rows and this compromise stops being safe.

## Decision 9 — The declared golden set (ADR-025 D8)

> ### The first declaration was WRONG, and the suite is what said so
>
> The original declaration below (*"no `*.ltr.png` golden changes, zero"*) was made before any golden ran. The suite falsified it: **37 LTR cells moved.** Both causes were mine, and neither was churn-to-accept:
>
> **(a) I claimed no golden covers the mirror case. False.** `coach_screen_golden_test.dart:45-58`, `solo_home_screen_golden_test.dart:47` and `partner_preview_screen_golden_test.dart:158-161` all key their **content fixtures to the cell's locale**, so the `ar.*` cells render genuinely Arabic content. `conversation.ar.ltr` is therefore Arabic content in an LTR paragraph — the mirror case — and it moved because the fix **correctly repairs it**. D5's "no golden covers it" is struck.
>
> **(b) `tr.ltr`/`en.ltr` moved for no reason at all.** Latin content in an LTR paragraph needs no isolate, but an unconditional seam emitted one anyway. Measured: ~0.8% of pixels, mean delta 27/255, **no reflow and no size change** — the isolate controls split the shaping run and the glyphs re-rasterise. Semantically inert, visually noise, and 27 goldens' worth of it.
>
> (b) is what ADR-025 D8 means by *churn to accept*, so it was **fixed rather than declared**: `isolateWithin()` now emits the controls only when the content's first-strong direction actually differs from the paragraph's. Those cells are byte-identical again.

**Re-declared before `--update-goldens`, from the fixture reasoning above rather than from a golden run:**

| Cell | Content it renders | Expected |
|---|---|---|
| `tr.ltr`, `en.ltr` | Latin content, LTR paragraph — directions agree | **byte-identical** |
| `tr.rtl`, `en.rtl` | Latin content, RTL paragraph | **changes** |
| `ar.rtl` — `paired_home_screen` | Turkish (`solo_tr`, the ADR-011 placeholder) in RTL | **changes** |
| `ar.rtl` — `solo_home_screen`, `coach_screen`, `partner_preview` | Arabic content in RTL — directions agree | **byte-identical** |
| `ar.ltr` — `solo_home_screen`, `coach_screen`, `partner_preview` | Arabic content in LTR — the mirror case | **changes** |
| `ar.ltr` — `paired_home_screen` | Turkish content in LTR — directions agree | **byte-identical** |
| every `invite_share_screen` cell | the invite code, deliberately not isolated | **byte-identical** |
| `paywall_screen` | a TRY storefront price string — **UNKNOWN**, and stated as such: whether it changes depends on whether the fixture carries a strong LTR letter or is digits-and-symbols only (no strong character → never isolated). Not guessed. | resolved by the run |

A golden that moves **outside** this table is a defect to explain, not churn to accept.

### Actual: **34 files**, all inside the declaration — and three cells declared-to-change that did not

`git status --porcelain -- 'app/test/**/*.png'` after `--update-goldens`: **34 modified, 0 added, 0 deleted.** Of those, **31 are `*.rtl.png`** and **3 are `*.ar.ltr.png`** (`conversation`, `help_path`, `valid_question_hook` — the mirror-case repairs). **Zero `tr.ltr`, zero `en.ltr`, zero `goldens/probe/` (Class F intact).**

Three cells the table said would change did **not**, all in the safe direction, and the reason is one fact worth carrying:

> **Arabic punctuation is not bidi-neutral.** `؟` U+061F ARABIC QUESTION MARK has Bidi_Class **AL — a strong character.** It cannot float, so Arabic content terminated with it has nothing to misplace and needs no isolate to sit correctly.

- **`solo_home_screen` `*.ar.ltr` — unchanged.** All **7** `solo_ar.json` questions end in `؟`. Verified by decoding every terminator: `AL` in all seven.
- **`coach_screen` `*.ar.ltr` — changed, and now for a precise reason.** The Arabic *reply* fixture ends `…وقهوة تحبّانها.` — a **Western full stop, U+002E, class CS, neutral.** That is the character that moved. The Arabic *question* fixture ends in `؟` and did not.
- **`partner_preview` `valid.ar.*` — unchanged.** That state renders only the Latin name `Aylin`; in `ar.ltr` the directions agree, so no isolate. (`valid_question_hook.ar.ltr` *did* change — it renders the Arabic hook question.)

**The operational consequence is a content-authoring one, not a code one.** Arabic copy written with Arabic punctuation is immune to this defect; Arabic copy written with Western punctuation is not — and our AI-drafted copy currently mixes the two within a single screen. That is worth putting in front of the Gulf-dialect reviewer at operator item 1, because it is invisible in the source and only shows up rendered.

**But be exact about WHY, because the obvious reason is false.** A first draft of this decision said the isolate is "a provable no-op in LTR cells". It is not. Measured across 19 candidate strings in an LTR paragraph, comparing every character box: **16 identical, 2 probe artefacts, and 1 real difference** —

| String | Isolated in an LTR paragraph |
|---|---|
| `العربية is a beautiful language.` | **layout changes** — first strong character is RTL, so FSI resolves the whole string RTL |

The no-op holds only when the content's first-strong direction **already equals** the paragraph direction. The prediction above therefore rests on a **fixture fact, not a proof**: no golden today pairs RTL-first content with an LTR cell, because every content fixture is Turkish (`solo_tr`). The day someone adds an Arabic answer fixture to an LTR cell, that cell will legitimately move and this declaration must be re-derived rather than quoted.

Expected changed cells — the RTL cells of screens that render in-scope content:

| Screen | States expected to move (× `tr.rtl`, `ar.rtl`, `en.rtl`) |
|---|---|
| `paired_home_screen` | `locked`, `waiting`, `revealed`, `revealed_streak`, `revealed_mercy` + `locked_scale130.ar.rtl`, `revealed_streak_scale130.ar.rtl` |
| `solo_home_screen` | `day1_unanswered`, `day3_answered`, `privacy_spotlight` + `day1_unanswered_scale130.ar.rtl` |
| `coach_screen` | `conversation`, `help_path` + their `_scale130.ar.rtl` |
| `partner_preview_screen` | `valid`, `valid_question_hook` |
| `invite_share_screen` | `has_code` |
| `paywall_screen` | `loaded` + `loaded_scale130.ar.rtl` |

`no_day_yet`, `completed`, `loading`, `error`, `empty`, `unavailable`, `disclaimer`, `entitled` and every `pack_selection_screen` cell render chrome only and are expected **byte-identical**.

`app/test/support/golden/goldens/probe/*.png` are **Class F** (ADR-025 D7) — the RTL mirror net's own self-test. If either moves, the net moved, and that is a defect in this slice.

The actual `git status --porcelain -- 'app/test/**/*.png'` is pasted beside this table in the PR.

## Decision 10 — The Functions-side twin is filed as **#136**, not fixed here

`functions/src/notifications/payload-policy.ts` interpolates a partner's display name into Arabic push-notification bodies (`أجاب ${name} عن سؤال اليوم…`) — the same class of defect in a runtime with no Flutter, no goldens, and a different test suite. Fixing it here would be a drive-by refactor wearing a helmet (`session-rules.md` §2). It gets an issue.

Its severity is honestly **latent, not live**, and so is the ARB `{name}` case in Decision 1: for the copy that ships today, `{name}` is never adjacent to a bidi-neutral character, so no *current* string mis-renders. It is a guarantee-vs-mechanism gap — the isolate makes the sentence correct **for any name**, including the first one that ends in a full stop.

## Pre-code review outcome (2026-07-27, the 27th consecutive pre-code pass)

Five adversarial lenses × two independent verifiers (a refuting skeptic and a governing-docs adjudicator) plus a completeness critic. **12/12 agents completed, 0 errored, 0 returned empty** — checked before trusting the verdict distribution (addendum, S041: an empty verdict is *unverified*, and the tooling renders it as the opposite).

**Two findings survived aggregation, and measurement refuted both — but they earned the sharpest correction in this ADR.** Both claimed D3 was wrong to exclude chrome, on the ground that Arabic chrome embeds Latin brand names next to bidi-neutrals (`… إعدادات App Store.`, `عبر Apple. المدرّب`, `Anthropic، التي`, and the same shape throughout `privacy-policy.ar.md`). **That premise is correct and my original wording — "chrome script always matches the paragraph direction" — was false.** The conclusion still holds, for a different reason: whole-string isolation of all four strings plus a legal-document sentence is **byte-identical geometry**, against a Latin-sentence control that correctly DIFFERS. D3 now states the true reason.

Getting there needed a second attempt, and the **control is what caught the first one**: an initial probe isolated only the Latin *letters*, leaving the terminator outside the isolate — so the known-broken control came back "identical" too. A probe whose control passes is a broken probe, not a clean result.

**Three findings were refuted by both verifiers, and I am overriding two of them**, because I measured what the verifiers only reasoned about:

- `letter-spacing-fsi-untested` — ruled not-real by both. It **is** real: 144.0 → 152.0 px. It removed a site from D3.
- `finds-nothing-false-pass` — ruled not-real by both. It **is** real, and it is the exact addendum-47 shape. It is now the second half of D8.
- `d8-undercount` (39 affected assertions, not ~17) — a counting correction, verified during implementation rather than taken on trust from either side.

The lesson worth carrying: **the verifier panel was wrong in both directions here.** It let two refuted findings through and killed two real ones. Verdicts are an input to judgement, not a substitute for measuring.

The completeness critic returned **zero findings** but settled the open guarantee question in D4: it traced the answer round-trip (`Firestore → controller → Firestore`) and confirmed the TextField reads and writes pristine text, so "isolation applies at render only" is **safe by construction**, not merely by convention.

## Consequences

- Two new pure functions, one new widget, and a mechanical edit at **11 call sites** (8 `ContentText`, 3 isolated arguments — counted from the tree, not from the D3 table, whose rows name *construction* sites where several funnel into one `Text`). A new screen rendering content inherits the fix by using `ContentText`.
- ~48 RTL goldens re-baselined; zero LTR goldens; three slice-0 firewall guards must stay green.
- The a11y tree gets *cleaner* (pristine `semanticsLabel`), not dirtier.
- A residual we are not fixing: nothing *enforces* that a future content-render site uses `ContentText`. `rtl_lint` cannot tell content from chrome. This is recorded as the honest gap it is rather than papered over with a guard that would mostly restate `grep` (ADR-024's lesson).
