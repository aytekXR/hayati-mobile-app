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

`{name}` is a partner's display name — arbitrary script — interpolated **into the middle of a localized Arabic sentence** (`partner_preview_screen.dart:306` and `:427`). A `Directionality` ancestor or a `Text(textDirection:)` override sets the direction of the **whole paragraph**; it cannot isolate one run inside a sentence whose remainder must stay Arabic. Only an inline isolate can.

Three further reasons, in descending weight:

1. **It needs no `TextDirection` literal.** `tool/rtl_lint.dart:23` bans `\bTextDirection\.(ltr|rtl)\b` across `app/lib`. The widget-level fix would have required an `// rtl-ok` escape on every site — weakening a firewall guard to fix a bug the firewall was never aimed at. FSI/PDI are ordinary characters.
2. **It preserves block alignment.** Probe A3 shows the widget-level fix left-aligns the paragraph inside a right-aligned card, putting a right-aligned caption over a left-aligned body. FSI fixes the punctuation and leaves the block where the chrome puts it.
3. **It composes.** Isolates nest; a paragraph direction override does not.

### What we are explicitly NOT using

`intl` **does not expose FSI/PDI at all**. `bidi.dart:25-38` offers only the deprecated *embedding* controls (`LRE`/`RLE`/`PDF`), and `BidiFormatter.wrapWithUnicode` emits those. The constants are therefore defined locally.

More importantly, **`Bidi.detectRtlDirectionality` is not first-strong** — it is a majority-of-strong-characters heuristic, and it disagrees with FSI. Measured:

| String | `Bidi.startsWithRtl` | `Bidi.detectRtlDirectionality` |
|---|---|---|
| `العربية is a beautiful language indeed.` | **true** | **false** |
| `Ayşe قالت شيئًا جميلًا جدًا اليوم هنا.` | **false** | **true** |

Both rows disagree. A future session reaching for `detectRtlDirectionality` because the issue text said "Flutter exposes this as `Bidi.…` helpers" would get *different* behaviour from the isolate this ADR specifies. We do not call either: we emit `U+2068`/`U+2069` and let the platform's Unicode Bidi implementation resolve first-strong — the same rule HTML `dir="auto"` uses.

## Decision 2 — The seam is one pure function plus one widget

`app/lib/core/l10n/bidi_isolate.dart`

- `String isolate(String text)` → `'⁨$text⁩'`, the **first-strong isolate**. Returns `text` unchanged when it is empty or contains no character at all, so we never emit two invisible controls around nothing.
- Exported constants `firstStrongIsolate` / `popDirectionalIsolate` so tests and call sites never re-spell the code points.

`app/lib/core/widgets/content_text.dart`

- `ContentText` — the ergonomic seam for "this whole `Text` is content". It renders `Text(isolate(data), semanticsLabel: data, …)` and forwards the style/align/maxLines/overflow arguments the call sites already use.
- **`semanticsLabel` carries the PRISTINE string.** Flutter's `Text` replaces the subtree's semantics when `semanticsLabel` is non-null (`text.dart:802-807`), so the accessibility tree never sees the control characters even though the paragraph does. This is strictly better than the status quo, where the a11y label is whatever `data` happens to be.

For interpolation into a localized sentence, call sites pass an isolated *argument*: `l10n.invitePreviewInvitedBy(isolate(name))`. There is no widget for this and there should not be — the unit being isolated is a run, not a paragraph.

## Decision 3 — The boundary: isolate **content**, never **chrome**

**Isolated** — the string's script is not guaranteed to match the ambient direction:

| Site | What |
|---|---|
| `paired_home_screen.dart:391` → `_QuestionCard` | the daily question (pack language ≠ UI locale) |
| `paired_home_screen.dart:408`, `:417`, `:736`, `:809` (`_AnswerCard`) | both partners' answers — free text |
| `solo_home_screen.dart:199` | the solo question |
| `coach_screen.dart:432`, `:486`, `:533` | the user's typed message, the model's reply, the help-card body |
| `partner_preview_screen.dart:306`, `:427` | the partner's display name, interpolated into l10n |
| `partner_preview_screen.dart:402` | the invite's question hook |
| `invite_share_screen.dart:81` | the invite code — LTR by nature in any chrome |
| `paywall_screen.dart:401`, `:411` | store-supplied price strings |

**Not isolated**, with the reason stated rather than left implicit:

- **Localized chrome.** The app derives text direction from the UI locale, so in production chrome script *always* matches the paragraph direction. The `tr.rtl` / `en.rtl` / `ar.ltr` golden cells that show the defect on chrome are **synthetic**: they force a direction no production build can produce (the six-cell contract decouples them on purpose, `golden_harness.dart:21-32`). Isolating chrome would be a production no-op that churns roughly a hundred goldens and buys nothing. **This is the biggest scoping judgement in this ADR and it is the one to attack first.**
- **Legal document bodies** (`legal_renderer.dart:119-133`) — loaded from a per-locale asset (`<doc>.<locale>.md`), so the body's script matches the resolved locale by construction, exactly like chrome.
- **The data export** (`export_screen.dart:89`, the only `SelectableText` in the app) — machine-readable JSON that the user copies to the clipboard. `SelectableRegion._copy` puts `plainText` on the clipboard verbatim; isolating it would ship invisible control characters into a file the user may parse. Never isolate what leaves the app.
- **The share-sheet message** (`inviteShareMessage`, sent to the partner over WhatsApp/SMS). Same rule: **isolate for rendering, never for outgoing text.**

## Decision 4 — Isolation is applied at RENDER only

Nothing is isolated at rest. Firestore documents, the export payload, ARB values, and the share string all stay pristine. Two consequences worth naming:

1. ADR-025 **D5.iii's frozen-sentence digest** hashes ARB `locale.key=value` pairs. Because no ARB value changes, the digest is untouched and must stay green — if it goes red, this diff did something it did not intend.
2. `LengthLimitingTextInputFormatter` (`paired_home_screen.dart:433`, `solo_home_screen.dart:216`) caps *input*, not render. Character budgets are unaffected.

## Decision 5 — The mirror case is in scope

Probe **B2**: Arabic content inside Turkish/English LTR chrome puts its terminator at the run's right edge instead of its left — the same defect, mirrored. #133 does not mention it; it is real and reachable today (`contentLanguage: ar` with a `tr` interface). The same isolate fixes it (probe B3), and the tests assert **both** directions so a future one-directional regression is caught.

No existing golden covers it: the golden fixtures render `solo_tr` content, so no cell pairs Arabic *content* with LTR chrome. The new test — not a golden — is what covers it.

## Decision 6 — What first-strong gets WRONG, written down

The session brief asked for the mixed cases the choice mishandles. There are some, and pretending otherwise would be the failure mode:

- **`"Netflix أفضل من التلفاز."`** — an Arabic sentence opening with a Latin brand name. First strong character is Latin, so the isolate resolves **LTR**, the Arabic body renders as an RTL run inside an LTR block, and the period binds to the *sentence-as-LTR*. An Arabic reader would want RTL. This is wrong, and it is the exact case where a majority heuristic would be right.
- The symmetric case — **`"العربية is a beautiful language indeed."`** — is one a majority heuristic gets wrong and first-strong gets right.
- Neither rule is correct on both. We take first-strong because it is what Unicode specifies for `FSI`, what `dir="auto"` does on the web, and — decisively — because it needs no language detection at all, so it cannot drift as a heuristic's thresholds change under us.
- **Strings with no strong character** (a bare `"2026"`, `"…"`, an emoji-only reply) have no first-strong to find; the isolate resolves to the paragraph direction, which is the pre-existing behaviour. No regression, no improvement.

## Decision 7 — The failing test asserts geometry, not the mechanism

`app/test/core/l10n/bidi_isolate_test.dart` (helper) and the widget assertion:

> The terminator must bind to the **trailing side of its own run**: for LTR content, `terminatorBox.left >= lastLetterBox.right`; for RTL content, `terminatorBox.right <= lastLetterBox.left`.

Stated this way the assertion is **alignment-independent** — it does not encode "the period is at x=306", which would break the moment a card's padding changes — and it is **not self-referential** (addendum 43): it reads `RenderParagraph.getBoxesForSelection`, a framework API, and never calls `isolate()`. Deleting the isolate from production code moves the box and turns it red. Measured red/green from the probes: A1 `.left=194` vs `z.right=320` (red) → A2 `.left=306` vs `z.right=306` (green).

**MUTATION-CHECK, both directions** (addendum 43/47): remove the isolate → red; isolate only the leading side → red; keep the isolate but assert the LTR rule against RTL content → red. Run the neighbouring DTO/widget tests after, since a new guard can make old rows vacuous.

## Decision 8 — `find.text` breakage is accepted, and made visible

Measured: `find.text('Kahvaltıda birlikte gülmemiz.')` returns **0** matches against an isolated `Text`; `find.textContaining` still returns 1. Roughly 17 assertions across `paired_home_screen_test.dart` and `invite_share_screen_test.dart` match content strings exactly.

They move to `find.text(isolate('…'))`. This is deliberate: after this diff, **a test that still matches the raw string is a test rendering un-isolated content**, which is exactly the signal we want. The alternative — keeping the string pristine via `Text(textDirection:)` — was rejected in Decision 1 for reasons that outrank test churn.

## Decision 9 — The declared golden set (ADR-025 D8)

Declared **before** running `--update-goldens`, with one sharp falsifiable prediction:

> **No `*.ltr.png` golden changes. Zero. Every changed file ends in `.rtl.png`.**

Because the isolate is a provable no-op when the content's first-strong direction already equals the paragraph direction (probe C1/C2: byte-identical boxes), and every LTR cell renders Latin content in an LTR paragraph. An LTR golden that moves is a **defect to explain, not churn to accept**.

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

## Decision 10 — The Functions-side twin is filed, not fixed here

`functions/src/notifications/payload-policy.ts` interpolates a partner's display name into Arabic push-notification bodies (`أجاب ${name} عن سؤال اليوم…`) — the same class of defect in a runtime with no Flutter, no goldens, and a different test suite. Fixing it here would be a drive-by refactor wearing a helmet (`session-rules.md` §2). It gets an issue.

Its severity is honestly **latent, not live**, and so is the ARB `{name}` case in Decision 1: for the copy that ships today, `{name}` is never adjacent to a bidi-neutral character, so no *current* string mis-renders. It is a guarantee-vs-mechanism gap — the isolate makes the sentence correct **for any name**, including the first one that ends in a full stop.

## Consequences

- One new pure function, one new widget, and a mechanical edit at 13 call sites. A new screen rendering content inherits the fix by using `ContentText`.
- ~48 RTL goldens re-baselined; zero LTR goldens; three slice-0 firewall guards must stay green.
- The a11y tree gets *cleaner* (pristine `semanticsLabel`), not dirtier.
- A residual we are not fixing: nothing *enforces* that a future content-render site uses `ContentText`. `rtl_lint` cannot tell content from chrome. This is recorded as the honest gap it is rather than papered over with a guard that would mostly restate `grep` (ADR-024's lesson).
