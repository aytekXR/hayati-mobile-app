# ADR-025: The UI/UX Pro Max refactor — scope, the skill's REJECTED workflow, the invariant firewall, and the eight-slice arc

- **Status:** Accepted (**rev 2** — rev 2 folds the pre-code adversarial review's 1 blocking + 7 serious + 7 minor, all 15 of which survived double verification by a refuting skeptic and a governing-docs adjudicator out of 26 raised; plus one defect the review missed and the author's own verification caught, the Phosphor divergence. Rev 1 is in git history; the review is recorded in `past-prompts.md` Session 026)
- **Slice 0 shipped in Session 027** with two implementation notes recorded here rather than smuggled, neither reversing a decision: **(1) D5.i's scan set is DERIVED, not hand-maintained.** The review judged "every widget file it mounts" uncomputable and this ADR settled for an explicit two-file list, recording the gap as an accepted negative. It turned out to be computable after all — the transitive closure of *relative* imports from `lock_screen.dart`, filtered to files declaring a widget, yields exactly those two files today and picks up a shared widget added tomorrow. The explicit list survives as the sentinel-of-the-sentinel. That accepted negative is therefore **closed**, not merely tolerated. **(2) `ScaffoldMessenger.of` was added to the forbidden list** beyond ADR-018 D3's written enumeration: `LockScreen` provides its own `Material` and has no `Scaffold` ancestor, so a snackbar throws for exactly the same reason as a dialog. Same failure, same class, absent from D3's list — recorded here so the addition is traceable to a decision rather than to an implementer's taste.
- **Slice 2 (the product core) shipped in Session 029** — the reveal, "the product" (brandkit §9.3). Recorded here rather than smuggled, and pre-code adversarially reviewed (28 raised → 5 real defects, all fixed before the first line of code; the review is in `past-prompts.md` Session 029):
  **(1) The reveal finally has its signature interaction (brandkit §6).** The reveal moment rendered with NO motion at all — §6 names it "*the* signature interaction — budget polish here first" (soft unfold + gentle haptic), and it was absent. Slice 2 adds a soft unfold (fade + a gentle vertical rise) plus a gentle `HapticFeedback.lightImpact`. **This is transient — no golden captures it (the S028 lesson: a fix on a transient surface needs a widget test), so it is proven by `paired_home_screen_test`'s reveal group, not the golden matrix.**
  **(2) Motion is a §6 RULE, not a token — and the stopping condition did NOT fire.** The resume-prompt stopping condition is "a colour, a motion token or a type step *the brandkit does not define*." §6 DOES define the reveal motion (character + a 150–300ms band + ease-out entering); `hayati-tokens.json` simply has no motion key. So — exactly like `typography.minimumBodySize`/`dynamicTypeMax` (D5.ii, the JSON entries with no Dart counterpart) — it is realised as code constants (`MotionTokens`) enforced by **review**, with `motion_tokens_test.dart` pinning the duration inside the §6 band as its checked, citable home. It is deliberately NOT added to `brandkit_token_parity_test` (that would assert a token the brandkit JSON does not carry). This is categorically different from slice 1's regression, which invented `onSurfaceVariant`/`outline` COLOURS the brandkit has no value for at all (→ #67).
  **(3) Own and partner answers render at EQUAL weight (brandkit §9.1, "two people, one screen state").** The reveal's specialness is the unfold + grouping (the two answers tightened to x4 so they read as one shared moment), NOT primacy of one voice. This is also forced structurally: the state-ladder tests assert `Icons.favorite` is present ONLY in `revealed_streak` and absent elsewhere, so an accent icon on the partner card would break them — the equality ethos and the test net agree.
  **(4) The haptic host is `_PairedQuestionViewState.didUpdateWidget`, guarded to at-most-once per instance.** `_RevealUnfold` mounts fresh on every revealed-group mount, so it cannot host the haptic; the persisting State (re-keyed per dayKey) does, on `oldWidget.slot is PartnerSlotWaiting && widget.slot is PartnerSlotRevealed`, gated by a `_revealHapticFired` flag. **Honest bound discovered in testing (recorded, not papered over):** cold-open-into-revealed ALSO settles Locked→Waiting→Revealed even when both answers already exist, so there is no cheap client signal separating "the user was watching Waiting" from "the app just loaded a revealed day" — both are genuinely waiting→revealed. The original "never on cold-open" was therefore not achievable without a timing heuristic or a persisted per-day flag; we chose the simple, §6-consistent behaviour — one gentle buzz the first time the reveal LANDS (live or on cold-open settle), bounded to once per instance (once per dayKey per session). App RESUME does not re-fire (the State + flag survive; a resumed revealed day is revealed→revealed). The permission-denial self-heal (locked→revealed) is silent. The motion, by contrast, plays on any revealed-group mount.
  **(5) Golden delta = the x4 grouping only, + one new dynamic-type probe.** The sole settled-pixel change is own→partner gap x6→x4 (12 goldens: `revealed` + `revealed_streak` × 6). `_RevealUnfold` is pixel-neutral at rest (`Opacity(1)`+`Transform.translate(Offset.zero)` hit Flutter's no-op fast paths — the review's own skeptic confirmed this). SPACER-A + `_PartnerSlotCard` moved into the non-revealed `else` branch so locked/waiting/no_day stay byte-identical. Slice 2 is the first structural change to the revealed layout, so `revealed_streak_scale130 ×3` was added (busiest reveal state, superset) to keep Appendix A's 130% check honest for the new grouped column. Declared set: 15 files.
- **Slice 3 (onboarding & pairing) shipped in Session 030** — the first slice carrying a Class-G surface (`ProviderActions`). The audit (6 parallel auditors reading code + LOOKING at goldens, then a governing-docs adjudicator) found the 7 surfaces already token-clean and rhythm-coherent (built well at M1–M2), so the slice is deliberately restrained — **3 changes, 15 settled goldens, 72 byte-identical** (the "87" in D7 is the surface-set size, not a change quota — same lesson as slice 2's 15-of-66). Pre-code adversarially reviewed (17th consecutive pass: 4 raised → 3 refinements applied, none challenging the core design; the two highest-risk lenses — Class-G footer preservation and the bottom-bar composition — found nothing). Recorded here rather than smuggled:
  **(1) The pairing activation moment finally unfolds (brandkit §6/§9.3).** `_ValidPreview` (the invitee's first sight of *who* invited them — "Aylin invited you", the code's own "activation moment") appeared flat after the loading spinner. It is the onboarding flow's structural sibling of the daily reveal slice 2 polished, so it gets the same §6 soft-unfold (fade + a gentle vertical rise). Realised as a NEW shared widget `core/widgets/soft_unfold_reveal.dart` reusing `MotionTokens` (revealUnfold/enter/revealSlide) — **not** an extraction of slice 2's file-local `_RevealUnfold` (touching `paired_home_screen.dart` would risk its goldens; the two can be DRYed later without pixel risk — the ~15 shared lines are recorded as issue #74, not smuggled). Transient → **no golden captures it** (settles pixel-neutral: `Opacity(1)`+`Transform.translate(Offset.zero)` no-op fast paths), so it is proven by `soft_unfold_reveal_test.dart`, which asserts BOTH halves — the fade climbs AND the child rises exactly `MotionTokens.revealSlide` from below to a zero rest (the pre-code review's finding M1: an opacity-only test would leave the rise unproven and miss a sign-inversion or zero-slide bug) — plus reduce-motion→instant and `alwaysIncludeSemantics` (no mid-unfold a11y gap). **No haptic:** slice 2's reveal has the §6 haptic; adding a *second* to the pairing reveal is a §6 rule decision (founder-owned), not a layout decision, so this slice adds motion only.
  **(2) profile_capture's sole CTA is pinned to the viewport bottom (brandkit §4 "one primary action per screen" spatial authority; §9.5 restraint).** The Continue button was the last child of a `ListView` (which wraps its children, not the viewport), so it floated at 40–65% of screen height over a 35–60% dark void. Moved to `Scaffold.bottomNavigationBar` (`SafeArea`+gutter padding, the in-flight spinner riding above it); the save guard and `_save` call are byte-identical (behaviour frozen), `_SaveErrorView` stays in the `ListView`. Also more robust at 130% (the CTA can no longer be scrolled away). 9 goldens: `fresh` ×6 + `fresh_scale130` ×3. `onboarding_gate` error ×6 byte-identical (different widget branch).
  **(3) phone_sign_in `_SmsCodeEntry` Verify↔Resend gap x2→x4 (brandkit §4).** The single-primary-then-single-subordinate arrangement uses x4 on both invite_share (Share→x4→"Have a code?", TryAgain→x4→"Sign out") and partner_preview `_JoinActions` (Accept→x4→"Not now"); `_SmsCodeEntry`'s Verify→Resend was the x2 outlier, reading as attached rather than subordinate. 6 goldens: `code_sent` ×6 (`entry` unaffected — no secondary there). **Explicit carve-out (the pre-code review's finding F1):** `ProviderActions`' Apple/Google/Phone stack is NOT a counter-example — it is a *homogeneous 3-item list* where every consecutive gap is x3 (including the FilledButton→FilledButton Apple→Google gap); x3 is internally consistent there and x4 would be wrong. The rule is "single-primary-then-single-subordinate = x4", not "every FilledButton→TextButton gap = x4" — recorded so a future Class-G session (slice 5 coach, slice 7 consent, both render `ProviderActions`) does not "normalise" that x3 and churn 12 undeclared sign-in goldens (D10.11).
  **(4) Dropped, recorded not smuggled:** the adjudicator ACCEPTED a fourth change — sign_in `_ErrorView` title↔detail x2→x3 — and the session OVERRULED it. The cross-cutting auditor called x2 "the single title↔body outlier", but that conflates two *different* structural relationships: hero-headline→supporting-body (invite/preview, x3) vs. **error-title→error-detail**, which uses x2 in BOTH sign_in `_ErrorView` AND profile_capture `_SaveErrorView`. x2 is the consistent tight-alert convention; changing only sign_in's would CREATE inconsistency. Two other candidates dropped: a resend-spinner `SizedBox(16,16)`→token name-alias (code-style, zero pixel/UX value — "a refactor slice is not a linting session") and an invite_share subordinate-button gap bump (taste, no rule). Class-G `ProviderActions` stays one shared widget; the three slice-0 guards green and unweakened; #67/#63/#71 untouched.
- **Slice 4 (commerce) shipped in Session 031** — paywall, pack selection, `PremiumGate`. A 3-auditor + governing-docs-adjudicator design pass found the commerce surfaces **already token-clean and brandkit-compliant**: the processing banner already reads as good news (`surfaceContainerHighest` + a `tertiary`/sage hourglass, explicitly never the error colour — ADR-014 D3), gold is already restrained (exactly two elements: the entitled premium mark + the annual best-value badge), the paywall hierarchy/rhythm/RTL/130% are sound, and `PremiumGate` is a correct minimal shared wrapper (one `isPremiumProvider` decision, three call sites, no fork). So the slice is the smallest of the arc — **ONE change, 9 goldens, 21 byte-identical**:
  **(1) The gated pitch drops from h1 to h2.** `pack_selection` `_GatedView`'s pitch (`packSelectionGatedTitle`, "Unlock every pack") was `headlineMedium` — the SAME role as the screen title (`packSelectionTitle`, "Question packs", also `headlineMedium`), stacking two h1s and erasing the h1/h2 distinction brandkit §3's 24/20 scale exists to carry. Downgraded to `titleLarge` (h2), which also aligns it with `_UnlockedView` — whose section header (`packSelectionCurrentTitle`) is already `titleLarge` under the same screen title. Verified in the regenerated goldens: the screen title now clearly leads and the pitch reads as a subordinate-but-still-prominent (20/w600) headline, at 1× and 130%. 9 goldens: `gated` ×6 + `gated_scale130` ×3; the 21 others (`paywall` entitled/loaded/loaded_scale130, `pack_selection` unlocked) byte-identical.
  **(2) The free-tier-byte-identity acceptance (D7 row 4) is a leak-check, not an absolute freeze — settled in review.** The gated view IS a free-tier surface, so change (1) moves free-tier probe goldens. The review's governing-docs adjudicator ruled CHANGE-PERMITTED: D7's "free-tier probes still byte-identical" is qualified by the resume-prompt's "must not move *unless declared*" — the invariant guards against the entitled/paywall path inadvertently shifting the free appearance, and a deliberate, declared, rationale-backed improvement to the free surface itself is exactly the "unless declared" case (the D8 discipline). The other free-tier probes (`paywall` loaded/loaded_scale130) are byte-identical, confirming no leak.
  **(3) No motion — the restraint discriminant, recorded.** The paywall "You're Premium" entitled view is a positive moment, but it is a *deliberately-navigated confirmation* (re-opened by already-premium couples), not a *surprise reveal*; §9.3's motion budget is for THE daily reveal, and slice 3's `SoftUnfoldReveal` earned its place on the pairing activation precisely because that WAS a surprise ("who invited you"). A soft-unfold on the entitled view would be motion-for-motion's-sake, so it is correctly absent. The good-news processing banner, gold restraint, and the `PremiumGate` wrapper are preserved untouched; the three slice-0 guards green and unweakened; #67/#63/#71 untouched.
- **Slice 5 (coach) shipped in Session 032 as a ZERO-CHANGE review slice** — chat, disclaimer, help path (Class **G + ★**). Two parallel auditors (the chat surface; the panels) each reading the full `coach_screen.dart` + the goldens, then a governing-docs adjudicator, found the coach **already token-clean and brandkit-compliant** — the deepest-so-far confirmation of the arc's thesis (the screens were built well; the work is the Material floor + composition, and here there was neither to do). Verified and recorded rather than assumed:
  **(1) Zero code changes, zero golden updates** — all 27 coach goldens byte-identical. Every spacing value traces to a `SpacingTokens` constant; every colour reads from `colorScheme` (no hardcoded literals, no gold, and — correctly — no `onSurfaceVariant`/`outline`, the #67-stopped absence a chat is most tempted to break with a muted timestamp or a message divider); the typography roles descend cleanly (headlineMedium titles, titleMedium help-card header, bodyMedium body/bubbles, bodySmall persona-label + quota caption); Material icons throughout (#63).
  **(2) The Class-G + ★ guarantees hold BY PROOF, not assertion.** The frozen-sentence digest is green (no `coachDisclaimer*`/`coachHelp*`/`coachPaused*` reword — no coach string touched at all); `CoachHelpCard` stays a structurally DISTINCT widget TYPE from `CoachPersonaBubble` (full-width + error-border + `Icons.favorite` header vs. partial-width + no-border + start-aligned raised bubble — the `find.byType` pinning in `coach_screen_test.dart` is safe); the help-sticky latch (`CoachPausedPanel` replaces `_CoachComposer`) is untouched. The three slice-0 guards were RE-RUN green as the slice's proof.
  **(3) The one motion candidate REJECTED by the S031 discriminant.** A `SoftUnfoldReveal` on the `_CoachDisclaimerView` column was considered and rejected: the disclaimer is an *expected safety gate the user deliberately navigates to* (they pressed "Coach"), not a *surprise reveal* — structurally unlike slice 2's daily reveal or slice 3's "who invited you". §6 ("motion conveys cause and effect, never decoration") and §9.5 ("restraint reads premium — 240ms on a gate tapped through in seconds is decoration") both cut against it. Both auditors and the candidate's own self-assessment reached DROP. **A zero-change slice is the honest outcome when a surface is already right — the arc's completion criterion is "every surface goes THROUGH a slice", not "every slice moves a pixel" (slice 0's precedent).**
- **Slice 6 (settings & data rights) shipped in Session 033 as a ZERO-CHANGE, #67-BLOCKED review slice** — 7 surfaces (settings, PIN setup, PIN-verify dialog, delete account, export, couple-ended notice, the shared `SettingsErrorLine`), the largest golden set of the arc (55). Three parallel auditors + a governing-docs adjudicator found every surface already token-clean and brandkit-compliant, and — the load-bearing finding — the ONE surface with a genuine improvement available (`SettingsScreen`) is **permanently #67-blocked**:
  **(1) Settings is the app's densest secondary-text/toggle/divider surface, and every meaningful improvement on it needs a slot the brandkit does not define.** The `ListTile`/`SwitchListTile` subtitles currently fall through to Material's DEFAULT `onSurfaceVariant` (a desaturated grey — functional but off-brand); giving them a brand muted tone, or adding a `Divider`/section-separator between the lock / privacy / data-rights clusters, requires `onSurfaceVariant` and/or `outline` — the two slots **S028 proved dim the Switches** and deferred to **#67**. Adding section-header COPY is equally forbidden (Class N). So the settings surface cannot be polished until #67 is decided. This is the S028 stopping condition confirmed from the other direction: slice 1 hit #67 setting the tokens; slice 6 hits it wanting to USE them. **#67 is now the gate on the ONE remaining piece of settings polish** — recorded for the founder in `operator-expected.md`.
  **(2) The safety-weighted surfaces already meet their acceptance BY CONSTRUCTION.** The delete confirmation keeps "This can't be undone." in `titleMedium` (prominent, immediately under the app bar) and the "both sides of every answer" clause in the first `bodyMedium` paragraph; the destructive `FilledButton` is `colorScheme.error`/`onError` (alert-on-night 4.94:1, §8 danger semantic) — no layout softens the irreversibility. `SettingsErrorLine` stays ONE shared widget across `SettingsScreen`/`ConsentGateScreen`/`LegalScreen` (no fork). The two dialogs (`PinVerifyDialog`, `_BiometricWarningDialog`) correctly mount above the golden matrix (S028 lesson — a golden does not capture them).
  **(3) Zero code, zero goldens — proven, not assumed.** All 55 slice-6 goldens byte-identical; the settings/delete state-ladders, the `SettingsErrorLine` sharing, and the three slice-0 guards (token parity, lock sentinel, frozen digest) RE-RUN green as the deliverable's proof (106 targeted tests). No motion (all 7 are deliberately-navigated destinations — S031's discriminant). **The arc advances by proof of compliance, and here by naming precisely what #67 is gating.**
- **Date:** 2026-07-19 (Session 026)
- **Deciders:** session agent, per founder directive 2026-07-14 ("refactor the app's UI/UX with UI/UX Pro Max"); the copy gates inside the firewall are founder/native-reviewer-owned and are not resolved here
- **Related:** `docs/frontend-brandkit.md` (v1.0 — the visual constitution this ADR subordinates the skill to), ADR-018 (the device-privacy layer whose four lock invariants set the firewall's hardest boundary — **D3's no-dialog constraint is the gap this ADR found**), ADR-023 (the consent surface as a *guarantee* surface), ADR-016/017 (the ★ safety-gated crisis/coach copy), ADR-020 (store copy under the native-review gate), ADR-022 (the pre-frame bootstrap sentinel — the source-sentinel precedent this ADR extends), `docs/test-suite.md` §Golden harness, `docs/agent-workflows.md` W4 (the explicit golden-update flag), `docs/operator-expected.md` items 1 + ★ (the copy gates a refactor session may not silently cross)

## Context

The founder installed the **UI/UX Pro Max** tooling (`uipro` CLI v2.11.0, npm `ui-ux-pro-max-cli`, global on the dev box) and directed that the app's whole UI/UX be refactored through it. The roadmap recorded the unit as needing its own scoping ADR before any pixels move, sized as a multi-session arc. This is that ADR. **No UI code changes in this session.**

Two bodies of fact drive every decision below, and both were *produced*, not recalled: the skill was actually installed and actually run, and the app's surfaces were actually inventoried against source.

### Fact set A — what `uipro init` actually installed and actually does

`uipro init -a claude` was run at the repo root. It exited 0 and wrote **143 files / 2.8 MB into `.claude/skills/`**, across **seven** skills — not one. *(Re-counting after running the corpus's `search.py` gives 145 / 2.9 MB — Python writes two `__pycache__/*.pyc` files. 143 is what `init` wrote; the pre-code review flagged the discrepancy and this parenthetical is why it exists.)*

| Skill | What it is | Usable here? |
|---|---|---|
| `ui-ux-pro-max` | The design-intelligence corpus + a `search.py` CLI. 22 stack CSVs (**one of them Flutter**, 52 rows), `ux-guidelines.csv` (98), `app-interface.csv` (29), `motion.csv` (16), `ui-reasoning.csv` (161), `colors.csv` (192), `google-fonts.csv` (1,923), plus a ~200-rule HIG/Material-cited taxonomy in `SKILL.md` | **Partly** — see D2 |
| `ui-styling` | shadcn/ui + Radix + Tailwind | **No** — structurally inapplicable to Flutter |
| `design-system` | Three-layer CSS-variable token architecture + slide generation | **No** — CSS/web delivery model |
| `design` | Logo/CIP/icon/social generation via Gemini | **No** — needs an external image API key, and see D9 |
| `banner-design` | Social/ad banners | **No** — marketing surface, out of scope (ADR-007) |
| `brand` | Brand voice / visual identity / messaging frameworks | **No** — Hayati already has brandkit v1.0 |
| `slides` | HTML presentations with Chart.js | **No** |

`init` has **no version-pin flag** (`--version` does not exist; only `versions`/`update` do), so a future machine running `uipro init` gets whatever is latest *then*, not v2.11.0. That single fact makes any citation *into* the corpus non-reproducible, and it drives D3 and D9.

The scripts are Python-3-stdlib-only and ran offline without credentials — no Mac, no network, no key. **The stopping condition in the session brief did not fire.** Three skills (`design`, `banner-design`, `design-system/fetch-background.py`) do reach for external image-generation APIs, but nothing this ADR adopts touches them.

**What the tool produced when actually asked about this product** — the load-bearing result. Running the skill's own **Step 2 (marked REQUIRED)** with an accurate description of Hayati:

```
python3 scripts/search.py "intimate couples relationship reflection app, warm, calm,
  Turkish and Arabic, RTL" --design-system --project-name Hayati --stack flutter --persist
```

it classified the product correctly ("Couple & Relationship App") and then proposed:

| Generator output | brandkit v1.0 says | Verdict |
|---|---|---|
| Background `#FDF2F8`, primary `#BE185D` ("Romance rose + love red") — a **light** palette | **Dark-first**; `night` `#231A33`, `pomegranate` `#C04A5A` (§2, "evening is the couple's app moment; discretion likes dark screens") | Contradiction |
| Heading **Noto Naskh Arabic** / body **Noto Sans Arabic** | **Rubik** is the single dual-script family; Noto is the *fallback* (§3) | Contradiction |
| Pattern: **"App Store Style Landing"** (hero + screenshots carousel + download CTAs) | Hayati has no landing page in scope; this is an in-app refactor | Category error |
| Delivery: Google Fonts `@import` + `--color-*` CSS variables | Flutter bundles fonts; tokens are Dart constants | Wrong runtime |
| `--persist` wrote `design-system/hayati/MASTER.md`, which the CLI announces as the *"Global Source of Truth"* and whose body instructs the reader to *"strictly follow the rules below"* | brandkit v1.0 is the source of truth | Direct conflict of authority |

And in the workflow the skill instructs an agent to follow, `SKILL.md:346` states verbatim:

> - **Stack**: React Native (this project's only tech stack)

That line is a hardcoded template error. Any session that follows the skill's Step 1 is told, by the skill, the wrong stack for this repo.

**Honest conclusion:** the *generator* is wrong for Hayati and the *corpus* is useful. The corpus's App-UI sections (`SKILL.md` "Common Rules for Professional UI" and "Pre-Delivery Checklist", both explicitly scoped by the tool itself to "App UI (iOS/Android/React Native/**Flutter**)") are a genuinely good mobile review checklist, and they independently converge with brandkit §5 (both specify **Phosphor** icons) and with brandkit §8 (both specify ≥44pt touch targets, WCAG AA). The general `--domain` corpora carry sound guidelines wrapped in Tailwind code examples; the guideline text transfers, the code does not.

### Fact set B — what the app actually is

Inventoried against source (not docs) by 16 agents over 655 tool calls, then the load-bearing claims re-verified by hand:

- **48 UI surfaces** across 10 features + the shared core: 19 screens, 25 sub-widgets/shared components, 3 private `AlertDialog`s, 1 inline `SnackBar`.
- **303 golden PNGs** in 21 directories (git-verified: `git ls-files app/test | grep -c '\.png$'` = 303). *A working-tree count of 635 is misleading — 332 of those are untracked, gitignored `failures/` mismatch artifacts from past runs.*
- **237 ARB keys** × TR/AR/EN. **Every prefix is under at least one copy gate.** There is no prefix a refactor session may freely reword.
- Risk classification of the 48: **4 forbidden · 22 high · 16 medium · 5 low · 1 uninventoried-until-the-critic-found-it** (`settings_error_line.dart`, shared by three screens).

**The three findings that changed this ADR's shape:**

**B1 — The codebase is already token-disciplined; the Material defaults underneath it are not.** Feature code contains **0** hardcoded `TextStyle`, **0** `EdgeInsets` magic numbers, and **2** raw `Colors.*` references (both `Colors.transparent` sentinels). The refactor's work-list is therefore *not* token adoption — that job is done. But `hayatiTheme()` overrides only **six** component sub-themes (AppBar, FilledButton, TextButton, InputDecoration, Chip, ProgressIndicator) and assembles a **partial** `ColorScheme`. Material 3's defaults for everything else resolve through slots the theme never set, and Flutter falls those back to `surface`/`onSurface`:

| Component | M3 default reads | Theme sets it? | Resolves to |
|---|---|---|---|
| `AlertDialog` background | `surfaceContainerHigh` | **No** (the theme sets `surfaceContainer**Highest**` — one word apart) | `night` `#231A33` — *identical to the page behind it* |
| `Card` color | `surfaceContainerLow` | No | `night` — no separation |
| `BottomSheet` background | `surfaceContainerLow` | No | `night` — no separation |
| `SnackBar` background | `inverseSurface` → `?? onSurface` | No | **`sand` `#F3E7D7`** — a cream slab in a dark-first app |

Verified against the installed SDK (`color_scheme.dart:1254,1272,1316`; `dialog.dart:1979`; `card.dart`; `bottom_sheet.dart:1496`; `snack_bar.dart:949`). brandkit §4 assigns `night.raised` `#2E2344` to "Cards, sheets" — so the three surfaces that carry the app's most consequential confirmations (**the biometric shared-device warning, the irreversible-delete confirmation, and the consent-withdrawal dialog**) currently render flat, unseparated, on the wrong token; and the export screen's confirmation `SnackBar` is a light-mode intrusion. The skill's own checklist names both defects ("Surface readability — keep cards/surfaces clearly separated from background"; "Scrim and modal legibility"). This is the arc's first real work.

**B2 — ADR-018 D3, the single most safety-critical constraint the refactor faces, has NO mechanism.** The constraint — *nothing inside `LockScreen` or any widget it mounts may call `showDialog` / `showModalBottomSheet` / `showMenu` / `Navigator.of`, or use `Tooltip` / `Autocomplete` / `DropdownButton` / a text-selection-enabled field* — exists as a block comment at `lock_screen.dart:1-20` (the forbidden-call list itself at `:7-9`) and one behavioural test that covers **only the recovery path** (`lock_screen_test.dart:307-327`). `LockScreen` sits above the app's only Navigator and has no Overlay ancestor; any such call **throws**, and on the recovery path that crash *is* the lockout. Verified by hand: of the eleven source-sentinel-style tests in `app/test`, **none scans `lock_screen.dart`**. A refactor adding a cooldown `Tooltip` or a biometric-error dialog would ship green. This is a pre-existing hole (open since M6.1), not one uipro creates — but the refactor is exactly the change that would walk into it.

**B3 — "the brandkit decides" is, today, a claim with no mechanism either.** `brandkit/brandkit/tokens/hayati-tokens.json` was **transcribed by hand** into `app/lib/core/design_system/*.dart`. There is no codegen and **no drift test** — verified: nothing under `app/test` reads `brandkit/` at all. The values match today by care, not by construction. An ADR whose central rule is "the refactor is expressed through brandkit tokens" cannot rest that rule on a hand-copy nobody checks.

## Decision

### D1 — The skill is an INPUT to this ADR, not a dependency of the arc

`uipro` is recorded as run, with its real output above, including its failure modes. From here the arc depends on **this document**, not on the tool: the binding per-slice checklist is transcribed into Appendix A. A slice can be executed on a machine with no `uipro` installed. Rationale: `init` cannot pin a version (Fact set A), so a citation into the corpus is not reproducible, and a governing rule that can silently change under a future `uipro update` is not a governing rule.

Sessions **may** still run `search.py --domain <d>` / `--stack flutter` ad hoc for ideas. Nothing binding may come from that without landing in a repo-owned doc first.

### D2 — The skill's own prescribed workflow is REJECTED; only Steps 3–4 are used

**Not run in this repo, ever:** Step 1 (it declares the wrong stack), **Step 2 `--design-system` (which the skill marks REQUIRED)**, Step 2b `--persist`, Step 2c's dials (`--motion` emits GSAP; `--density` rewrites CSS variables).

**Used:** Step 3 (`--domain ux|style|typography|color`) and Step 4 (`--stack flutter`), and only as a **review lens** — a source of questions to ask a surface, never a source of answers to apply.

The reason is not that the generator is low quality; it is that its output is a *competing constitution*. `--persist` writes a file that calls itself "Global Source of Truth" and instructs future readers to "strictly follow" it. Two documents cannot both be the source of truth, and brandkit v1.0 already is. **`--persist` must never be run inside this repository** (unqualified, it writes `design-system/<name>/MASTER.md` relative to CWD — i.e. into the repo root).

### D3 — brandkit v1.0 remains the visual constitution, and this ADR gives that claim its first mechanism

The skill proposes; brandkit's tokens and assets decide; the refactor is expressed **through** brandkit tokens and does not replace them. Where the skill and the brandkit agree (Phosphor icons, ≥44pt targets, WCAG AA, 4/8dp rhythm, 150–300ms micro-interactions), the agreement is *confirmation* and the brandkit remains the citation. Where they disagree, **the brandkit wins without discussion** — the four contradictions tabulated in Fact set A are closed, not open questions.

Because B3 showed that rule resting on an unchecked hand-copy, **Slice 0 adds a token-parity test** (D5.ii, **issue #62**). Until that test exists, no slice may proceed.

**One brandkit rule the code does not follow today, recorded rather than assumed:** §5 and `iconography.*` specify **Phosphor** icons; the app ships **28 Material `Icons.*` call sites** and Phosphor is not a dependency. This ADR does not quietly "fix" that inside a refactor slice — the migration would rework the RTL mirror-net's premise (Material's `arrow_back` auto-mirrors; a Phosphor glyph does not) and add a second icon font to both the golden harness and the size budget. It is a founder decision, tracked in **issue #63**, and until it is made the token-parity test does not assert `iconography.*` and Appendix A states the rule the code can pass. This is what "the brandkit decides" looks like when the brandkit and the code disagree: the disagreement is written down, not resolved by whichever side is easier to edit.

### D4 — The invariant firewall, per surface

Four classes, and every one of the 48 surfaces carries exactly one. A slice may not change a surface's class; only a new ADR can.

**Class F — FORBIDDEN to restructure (visual parity only).** `PrivacyGuard`, `PrivacyShieldCover`, `LockScreen`, `PinKeypad`.
A slice touching these may do **only** token normalization that leaves the rendered pixels byte-identical or changes them in a way declared in advance. It may **not**: add or remove a widget type, add any interaction, add any route, add any dialog/overlay/tooltip, change the `Offstage`+`TickerMode` gating shape, change `PrivacyShieldCover`'s direct `ColorTokens.night` (it must stay `night` independent of any runtime theme — ADR-018 FLUTTER-4), or un-pin the keypad's explicit `TextDirection.ltr` (numeric pads are not mirrored in RTL on any platform; the AR goldens pin 1-2-3 order).

**Class G — GUARANTEE surfaces (copy frozen, layout negotiable).** `ConsentGateScreen`, `LegalScreen`, `LegalDocumentScreen`, `ProviderActions` (three call sites: sign_in `_SignedOutView`, sign_in `_ErrorView`, partner_preview `_JoinActions` — the M2.3 site was live before this ADR was drafted; the count was "both" until the S030 post-diff review, D7 already said "all three"), the coach help path.
The rendered *sentences* are the guarantee (ADR-023; ADR-016/017 ★). A slice may re-lay-out, re-space and re-theme them; it may **not** reword any `consent*` / `legal*` / `coach*` ARB value, may not change which sentence sits with which legal obligation, and may not break `ProviderActions`' by-construction property — the legal footer is present on *every* surface that renders sign-in buttons because they all share one widget. **Splitting `ProviderActions` per-screen is forbidden**; it would convert a structural guarantee into a convention.

**Class N — NATIVE-REVIEW-GATED copy (operator item 1).** Every remaining screen. Restructure freely; reword nothing. Any reword resets that key's native-review status and must be recorded in the session log and in `operator-expected.md` item 1 in the same diff.

**Class S — STRUCTURALLY UNREACHABLE (record, never attempt).** The system biometric prompt, the iOS alternate-icon confirmation alert, the OS share sheet, the iOS `LaunchScreen.storyboard`, the Android `launch_background.xml`, the Google and Apple sign-in sheets. A slice that "fixes" one of these is fixing something it does not own. *(The two splash surfaces are the only genuinely re-skinnable members of this class, and they are native-asset work explicitly deferred to the Mac era, item 4.)*

**Out-of-scope lookalikes** — carry the brand, are not this arc: `fastlane/metadata/**` (store listing, ADR-020), `brandkit/branding-assets/**` (master graphics + social), and the six `docs/legal/*.md` documents (their *rendering* is in scope; their *text* is frozen under the byte-drift test and the founder's review gate, item 9).

### D5 — Slice 0 is mandatory, moves no pixels, and builds the firewall before any slice runs

Three guards plus a harness rule. Each is modelled on an existing, proven pattern in this repo, and each must be **mutation-checked** (neuter it, confirm exactly its own test turns red, restore).

- **(i) The lock-screen forbidden-API source sentinel.** Modelled on `no_invalidate_sentinel_test.dart` (which strips comment lines before scanning — necessary here too, since `lock_screen.dart`'s header comment *names* the forbidden calls in prose). Closes B2. **This guard's absence is a live hole today, independent of the refactor** — filed as **issue #61** so it is not hostage to this arc.

  **Scan set — an explicit list, because "every widget file it mounts" is not computable by a test** (the pre-code review's finding; the phrase implied structural coverage the implementation cannot deliver):

  ```
  lib/features/privacy_lock/presentation/lock_screen.dart
  lib/features/privacy_lock/presentation/widgets/pin_keypad.dart
  ```

  The list is maintained by hand. Two things make that honest rather than rotting: a `// SENTINEL SCAN SET` comment in both files stating that any new widget file mounted by `LockScreen` must be added here, and a **sentinel-of-the-sentinel** assertion that the list still contains both paths and that both files still exist — so the scan set cannot silently shrink to nothing and stay green.

  **Forbidden strings — the list is ADR-018 D3's, in full:** `showDialog`, `showModalBottomSheet`, `showMenu`, `Navigator.of`, `Tooltip`, `Autocomplete`, `DropdownButton`, and — the review's two catches — **`tooltip:`** (lowercase, the *parameter* form: `IconButton`, `PopupMenuButton` and friends build a `Tooltip` internally, so scanning only for the class name misses the most natural way to introduce one) and the **text-selection** family `SelectableText`, `TextField`, `TextFormField`, `EditableText` (ADR-018 D3 names "a text-selection-enabled field" co-equally with the rest — `lock_screen.dart:9` — and a first draft of this decision dropped it). `IconButton` is forbidden outright in the scan set: its only safe uses are already served by `TextButton.icon` or a bare `InkWell`, and permitting it means relying on the `tooltip:` scan catching every future call site.

  **Mutation-check note:** the mutation must be run once per forbidden string, including `tooltip:` in its parameter form. A mutation that only inserts `showDialog` proves the sentinel scans, not that its list is complete.
- **(ii) The brandkit token-parity test.** Parses `brandkit/brandkit/tokens/hayati-tokens.json` and asserts each JSON entry equals its Dart counterpart. Closes B3 and makes D3 enforceable. **The correspondence is NOT 1:1 and the mapping is specified here**, because "assert every entry" would fail on first write against entries that have no Dart counterpart (the pre-code review's finding):

  | JSON | Dart | Asserted? |
  |---|---|---|
  | `color.*` (9 entries) | `ColorTokens.{night,nightRaised,pomegranate,pomegranateDeep,sand,gold,sage,clay,alert}` | **Yes** — hex equality |
  | `typography.family` + `fallback[]` | `TypographyTokens.family` / `.fallback` | **Yes** |
  | `typography.{display,h1,h2,body,caption}.{size,weight}` | the corresponding `TextTheme` entries built by `textThemeFor` | **Yes** |
  | `typography.body.lineHeight.{latin,arabic}` | `TypographyTokens.bodyHeight{Latin,Arabic}` | **Yes** |
  | `spacing.grid` · `screenGutter` · `cardPadding` | `SpacingTokens.x1` · `.screenGutter` · `.cardPadding` | **Yes** |
  | `radius.card` · `sheet` · `chip: "full"` | `RadiusTokens.card` · `.sheet` · `.stadium` | **Yes** (`chip: "full"` ⇒ `StadiumBorder`, asserted as a type, not a number) |
  | `typography.minimumBodySize: 14` | *(none)* | **No** — a brandkit *rule*, not a token the theme emits; enforced by review, not by the theme |
  | `typography.dynamicTypeMax: "130%"` | *(none)* | **No** — realised as the goldens' scale-130 cells, not as a constant |
  | `iconography.*` | *(none — the app ships Material icons)* | **No** — see the recorded divergence in D3 and **issue #63**; asserting it would fail on first write |
  | `rules[]` | *(prose)* | **No** |
  | — | `SpacingTokens.x2..x8` | **Derived**, asserted as exact multiples of `spacing.grid` — so a hand-edit of `x3` from 12 to 14 still fails |

  Bidirectional over the asserted set: a brandkit edit without a Dart edit fails, and a Dart edit without a brandkit edit fails. The four **No** rows are the honest bound — recorded here rather than quietly skipped in the test.
- **(iii) A frozen-sentence digest over the ★ and guarantee strings — and the exact key set is enumerated HERE, not left to the implementer.** A SHA-256 over `UTF-8(sorted("<locale>.<key>=<value>\n"))` for exactly the keys below, across all three locales, pinned as a literal in the test. Any reword turns CI red and forces a deliberate re-stamp — the W4 golden-flag pattern applied to the copy that carries safety and legal meaning.

  **The set (the pre-code review's blocking finding — "the named ★ safety keys" named nothing, and two implementers would have pinned different hashes):**

  | Group | Keys | Why |
  |---|---|---|
  | ★ safety (ADR-016/017, operator ★ gate) | `coachDisclaimerTitle`, `coachDisclaimerBody`, `coachDisclaimerCta`, `coachHelpTitle`, `coachPausedBody` | The not-therapy disclaimer and the crisis/help path copy — the strings the ★ gate exists to protect |
  | Consent (ADR-023) | every key matching `consent*` | The consent sentences the user acts on |
  | Legal (ADR-023) | every key matching `legal*` | **Included deliberately** — D10.1 promises `legal*` protection, and a first draft of this decision did not deliver it. The consent-withdrawal dialog (`legalWithdrawDialogBody`) is a legal guarantee surface; leaving it out would have made D10.1 a false promise, which is the exact guarantee-vs-mechanism defect this ADR was written to prevent |

  **Today that resolves to (5 + 9 + 18) × 3 locales = 96 key/value pairs** — verified against the ARB files at the time of writing, so slice 0 has a number to check its implementation against rather than a category to interpret. A key added under `consent*` or `legal*` is picked up by the prefix automatically (and legitimately changes the count); a **new** ★ key must be added to the list above by the session that introduces it, and the test asserts the five ★ keys still exist by name — a rename must be deliberate, not silent.

  **Deliberately scoped to that set, not to all 237 keys:** a digest over everything would tax every future copy session for little gain, and the broad native-review gate (item 1) stays what it honestly is — a *human* process with no mechanical enforcement. We do not fake a mechanism for it (ADR-024's lesson: prefer an honest gap to a fake guard).
- **(iv) The golden-set declaration rule** (D8) — a PR-review discipline, not a CI gate; see D8 for why that distinction is stated rather than papered over.

**Slice 0's acceptance line:** all four land, all three guards mutation-checked, `flutter analyze` clean, full suite green, **zero golden PNGs changed** (slice 0 renders nothing differently).

### D6 — Slice 1 is the Material default floor, and it goes first because its blast radius is widest

Fill the `ColorScheme` slots M3 actually reads (`surfaceContainerHigh`, `surfaceContainerLow`, `inverseSurface`/`onInverseSurface`, `onSurfaceVariant`, `outline`) from brandkit tokens, and add the missing component sub-themes (`DialogTheme`, `SnackBarThemeData`, `CardTheme`, `BottomSheetThemeData`, `ListTileThemeData`, `DividerTheme`, `SwitchThemeData`, `TooltipTheme`, `PopupMenuThemeData`).

Rationale for ordering: this is a one-line-per-component change with an app-wide visual effect. Done first, its golden churn is absorbed in **one** declared, intentional re-baseline. Done later, it would invalidate every slice before it.

**Acceptance:** the three `AlertDialog`s and the export `SnackBar` render on brandkit surfaces (`night.raised` for dialogs/cards/sheets — never the same value as `surface`); no component still resolves a background through an unset slot; the declared golden set re-baselined; every golden outside it byte-identical.

**Class F carve-out — the trap the pre-code review found.** `hayatiTheme()` is built *above* `PrivacyGuard` (`app.dart:111-121`), and `LockScreen` reads `Theme.of(context)` even though it has no `Scaffold` ancestor. So slice 1's app-wide change **reaches the Class F surfaces**, and "app-wide re-baseline" would quietly launder a lock-screen pixel change past the Class F rule — after which slice 8's "byte-identical" line would be true against an already-drifted baseline and the change would never get its Class F review.

Therefore slice 1 carries an extra, explicit acceptance line: **`lock_screen`, `pin_setup_screen` and the two `probe` goldens are expected BYTE-IDENTICAL after slice 1.** If any of them changes, slice 1 stops and the change gets the full Class F treatment (declared in advance, justified against ADR-018, reviewed as a lock change) — it is never absorbed into the app-wide set. The plausible culprits are named so they are checked rather than discovered: `CircularProgressIndicator` track colour (M3 reads `secondaryContainer`), `InkWell` focus/hover overlays on `_PinKey` (`onSurfaceVariant`), and anything newly resolving through `outline`.

### D7 — The arc: eight slices after slice 0, one per session, in this order

| # | Slice | Surfaces | Goldens | Class | Acceptance line |
|---|---|---|---|---|---|
| 0 | **The firewall** | — | 0 | — | Three guards land + mutation-checked; zero goldens change |
| 1 | **Material default floor** | `hayatiTheme` + `ColorScheme` | app-wide | — | D6's line |
| 2 | **The product core** — solo + paired home, question card, answer entry, partner slot, streak row, packs/coach tiles, gear overlay, invite nudge, solo-completed | 12 | 66 | N | "The reveal is the product" (brandkit §9.3) — the reveal moment measurably improved; every home state still renders every state it did |
| 3 | **Onboarding & pairing** — sign-in, phone sign-in, `ProviderActions`, profile capture, onboarding gate, invite share, partner preview | 7 | 87 | N + G | `ProviderActions` still ONE shared widget; the legal footer still present by construction on all three call sites |
| 4 | **Commerce** — paywall, pack selection, `PremiumGate` | 3 | 30 | N | Free-tier probes still byte-identical; the processing banner still reads as good news, never error colour |
| 5 | **Coach** — chat, disclaimer, help path | 3 | 27 | G + ★ | `CoachHelpCard` remains a structurally distinct widget TYPE from `CoachPersonaBubble`; the help-sticky latch still replaces the composer; zero ★ strings changed (digest green) |
| 6 | **Settings & data rights** — settings, PIN setup, PIN verify dialog, delete account, export, couple-ended notice, `SettingsErrorLine` | 7 | 55 | N | The delete confirmation still reads as irreversible and still says the shared space goes for both; `SettingsErrorLine` still shared, not forked per screen |
| 7 | **Legal & consent** — consent gate, legal hub, legal document | 3 | 18 | G | Layout only; digest green; the four consent escapes (sign out / export / delete / accept) all still reachable from the gate |
| 8 | **The lock — parity only** | 4 | 18 | **F** | The D5.i sentinel green; goldens byte-identical unless a token normalization is declared in advance; no new widget type, no new interaction |

Slice golden counts sum to **301**; the remaining 2 of the 303 are the `app/test/support/golden/goldens/probe` pair (the RTL mirror-net's `back_arrow` mirrored/unmirrored probes). **Those two are Class F for the entire arc and belong to no slice's re-baseline set** — they are a structural self-test, not a screen, and a change to either means the mirror net itself moved, which is a defect in any slice. *(A first draft of this table said 93 for slice 3 and summed to 307; the pre-code review caught both.)*

**The arc is done** when every one of the 48 inventoried surfaces has been through a slice or is explicitly recorded here as parity-only (Class F) or unreachable (Class S). Slices 2–7 may be re-ordered by the founder; **0 and 1 may not move off the front, and 8 may not move off the back.**

**Not in the arc, recorded rather than assumed:** the brandkit's **Phosphor** icon system (§5, and `iconography.*` in the tokens JSON) is **not what the app ships** — 28 Material `Icons.*` call sites, and Phosphor is not a dependency. Migrating is not a package swap: `Icons.arrow_back`'s Material auto-mirroring is what the RTL mirror-net self-test is built on, and a second icon font joins both the test harness and the size budget. It is deferred to a founder decision — migrate as its own slice 1.5, or amend the brandkit to record Material outline as the shipped system the way §10 already records the `sand`-on-`pomegranate` contrast exception — tracked in **issue #63**. Until then Appendix A states the rule the code can actually pass.

### D8 — The goldens acceptance harness: declare the set BEFORE regenerating

The existing harness is the acceptance instrument and is not changed: 6 cells per state (`{tr,ar,en}` × `{ltr,rtl}`) plus 3 natural-direction cells at 130% text scale, 390×844 @1×, real Rubik/Noto fonts, **exact** pixel comparison, Linux-canonical (`cd app && flutter test --update-goldens` on Linux only — macOS renders text differently), diffs uploaded as CI artifacts, the RTL mirror-net self-test as the un-mirrored-arrow trap.

**The rule this ADR adds:** a slice **writes down the exact set of golden files it expects to change, in the PR description, before running `--update-goldens`**. After regeneration it pastes the actual `git status --porcelain -- 'app/test/**/*.png'` output beside the declaration. A golden outside the declared set that changed is a **defect to explain, not churn to accept** — the M4.2 and M6.2 precedent, where every non-target golden was git-verified byte-identical.

**This is a PR-review discipline, not a CI gate, and the distinction is stated rather than papered over.** No workflow step reads the PR body; nothing turns red if a session declares 66 files and commits 71. A first draft of this decision claimed the rule made W4 "mechanically checkable" — it does not, and the pre-code review was right to call that false reliance on a critical process gate. What the rule actually buys is that both numbers are *in the PR record*, so the discrepancy is visible to any later reader instead of being invisible. `git` itself is the mechanism; the declaration is what gives `git`'s output something to be compared against.

The recorded upgrade path, if the discipline proves insufficient during the arc: a committed golden manifest (path + SHA-256 for all 303) under a test, so any un-restamped change is red. It is deliberately **not** built now — it largely duplicates what `git diff` already shows, and ADR-024's lesson applies (an honest gap beats a guard that mostly restates version control).

Because the rule now binds every session and not only this arc, **`agent-workflows.md` W4 is updated in the same diff** to carry it — a governing procedure that lives only inside an arc ADR is a procedure the next unrelated session will not read (the pre-code review's finding).

Slices 2–8 additionally may not *reduce* golden coverage: a state that had cells keeps them. New states get the full 6-cell matrix; new scale-130 variants follow the existing per-screen precedent.

### D9 — Repo posture: `.claude/skills/` is gitignored, and only ONE of the seven skills may be invoked here

`.claude/skills/` is added to `.gitignore` — machine-local, like `.codegraph/`, with a one-line install instruction. Reasons: 143 vendored third-party files (Apache-2.0 + MIT) that are not this project's source; `init` cannot pin a version anyway, so committing buys reproducibility it cannot actually deliver; and D1 already moved everything binding into repo-owned docs. `.claude/settings.json` stays tracked, untouched.

**Only `ui-ux-pro-max` may be invoked in this repository.** The other six are forbidden — not merely unused. `brand`, `design` and `banner-design` exist to *generate brand identity, logos and marketing assets*; brandkit v1.0 is final and is the constitution, and a generated logo or a regenerated voice framework would violate it while looking like progress. `ui-styling`, `design-system` and `slides` target a web runtime this app does not have. `uipro uninstall` is all-or-nothing per assistant type and `uipro update` restores anything hand-deleted, so this boundary is a **rule**, not a file operation — which is exactly why it is written here.

### D10 — What a refactor session may never do, in one list

1. Reword any ARB value under `consent*`, `legal*`, or the ★ safety keys (D5.iii turns it red).
2. Reword any other ARB value without recording the native-review reset in the same diff (item 1).
3. Edit `app/assets/legal/*.md` (byte-pinned to `docs/legal/` — and the text is founder/lawyer-gated, item 9).
4. Bump the legal version, or touch any one leg of the three-way sentinel alone.
5. Add a phone-number-shaped digit run to any `coach*` string.
6. Add `showDialog` / `showModalBottomSheet` / `showMenu` / `Navigator.of` / `Tooltip` (including a `tooltip:` parameter, and therefore `IconButton`) / `Autocomplete` / `DropdownButton` / any text-selection-enabled field (`SelectableText`, `TextField`, `TextFormField`, `EditableText`) anywhere under `LockScreen`.
7. Call `ref.invalidate(privacyLockControllerProvider)` anywhere at all.
8. Change `biometricOnly: true`, or the `Offstage`+`TickerMode` gating shape, or `PrivacyShieldCover`'s `night`.
9. Split `ProviderActions`, or fork `SettingsErrorLine` per screen.
10. Run `--persist`, or adopt any palette, font, pattern or spacing scale from `--design-system`.
11. Accept a golden diff outside the slice's declared set.
12. Touch `fastlane/metadata/**` or `brandkit/**` under the banner of "UI refactor".

## Consequences

### Positive

- The refactor now has a **written, per-surface boundary** backed by tests rather than intentions — and building it surfaced two real pre-existing holes (B2, B3), one of them on the app's most safety-critical screen.
- The arc has an evidence-based **thesis and ordering**: the screens are already token-clean, so the work is the Material floor beneath them plus composition/hierarchy — and slice 1 absorbs the wide golden churn once instead of repeatedly.
- brandkit v1.0's authority stops being a doc claim and becomes a **test** (D5.ii).
- The skill was **actually run** and is recorded with its real failure modes, including the wrong-stack line in its own workflow — so no later session mistakes its generator for guidance.
- The arc is **portable**: it does not depend on a tool whose corpus can change under it.

### Negative / accepted trade-offs

- **Slice 0 delivers no visible improvement** and must ship before anything visible does. Accepted: it is the only point at which the firewall is cheaper than the damage it prevents.
- **Slice 1 will churn a large number of goldens at once.** Accepted deliberately — the alternative is churning them repeatedly.
- **The digest (D5.iii) taxes any future session that rewords a ★ or consent string**, forcing a deliberate re-stamp. Accepted: that is precisely the set where a silent reword is a safety or legal event.
- **The broad native-review gate stays mechanically unenforced.** We record this rather than fake it. A session can still silently reword `paywall*` or `solo*` copy and ship green; the only defence is D10.2 and review discipline.
- **D8's golden declaration is discipline, not enforcement** (D8 says so plainly). A session that ignores it produces a green pipeline.
- **D5.i's scan set is a hand-maintained list**, not structural coverage. A future widget mounted by `LockScreen` and not added to the list is unguarded; the sentinel-of-the-sentinel keeps the list from shrinking, but cannot know what it should grow to include.
- **The app does not use the brandkit's specified icon family**, and this ADR defers rather than resolves that (issue #63). Appendix A therefore asserts a weaker icon rule than the brandkit states.
- **Six of seven installed skills are dead weight on disk** (2.8 MB, gitignored) and are held out by a rule rather than by deletion, because the tool restores them on update.
- **The lock surfaces get almost no refactor.** Accepted: ADR-018's four invariants are worth more than visual consistency on the one screen most users see least.
- **`.claude/skills/` gitignored means a fresh machine must run `uipro init` to use the corpus ad hoc.** Mitigated by D1 — nothing binding needs it.

### Neutral

- The 332 untracked `failures/*.png` artifacts in the working tree are gitignored mismatch debris from past golden runs, not coverage. Noted so the next session does not mistake the 635-file working-tree count for the 303-file real one.
- `--stack flutter` (52 rows) is Flutter *idiom hygiene* (`const` constructors, `StatelessWidget` when possible) rather than UI/UX design intelligence; `flutter analyze` already covers most of it. It is retained in Appendix A only where it says something analyze does not.

## Appendix A — the binding per-slice checklist

Transcribed from `ui-ux-pro-max` v2.11.0's App-UI sections (its own scope notice: "App UI (iOS/Android/React Native/**Flutter**)"), adjudicated against brandkit v1.0. **Where a row cites the brandkit, the brandkit is the authority and the skill merely agrees.** Every slice's PR asserts this list.

**Visual**
- [ ] No emoji as structural icons; **one** icon family at one weight, and no slice mixes families. Today that family is **Material outline** at 24dp. The brandkit's **Phosphor** specification (§5, `iconography.*`; the skill independently recommends Phosphor) is a **recorded, unimplemented divergence** — 28 Material call sites, Phosphor not a dependency, and `Icons.arrow_back`'s auto-mirroring is what the RTL mirror net is built on. Tracked in **issue #63**; do not assert Phosphor compliance until it is resolved
- [ ] Semantic tokens only — no ad-hoc colour, size or spacing literals in feature code (already true; keep it true)
- [ ] Surfaces are visibly separated from their background — cards/sheets/dialogs on `night.raised`, never the same value as `surface` (brandkit §4; this is B1)
- [ ] Pressed states change colour/opacity/elevation, never layout bounds
- [ ] Elevation via subtle plum-tinted shadows, not gray (brandkit §4)

**Interaction**
- [ ] Every tappable element gives feedback within ~100ms
- [ ] Touch targets ≥44dp with ≥8dp separation (brandkit §8)
- [ ] Micro-interactions 150–300ms, ease-out entering / ease-in exiting; exit ~60–70% of enter
- [ ] Motion conveys cause and effect, never decoration; ≤1–2 animated elements per view; reduce-motion respected (brandkit §6)
- [ ] Disabled states visually clear and non-interactive
- [ ] One primary action per screen (brandkit §4)

**Layout & RTL**
- [ ] `start`/`end` only — never `left`/`right` (brandkit §4; the RTL lint enforces it)
- [ ] 4pt grid; screen gutter 20; card padding 16; radius 16 card / 24 sheet / full chip (brandkit §4)
- [ ] Safe areas respected; scroll content never hidden behind fixed bars
- [ ] Directional assets ship mirrored variants; the mirror-net self-test stays green
- [ ] No horizontal scroll; layout survives 130% text scale without truncation

**Typography & colour**
- [ ] Rubik with Noto fallback; scale 32/24/20/16/13 (brandkit §3)
- [ ] Body line-height **1.5 Latin / 1.7 Arabic** — Arabic needs air (brandkit §3)
- [ ] All text pairs ≥4.5:1 against their actual surface (brandkit §2; the recorded `sand`-on-`pomegranate` 3.94:1 exception stays recorded, not silently widened)
- [ ] `gold` never for body UI; `alert` never decorative (brandkit §2)
- [ ] Colour is never the sole signal — streak states carry icon + label (brandkit §8)

**Accessibility**
- [ ] Every icon-only control has a localized semantic label, in all three languages (brandkit §8)
- [ ] Screen-reader order matches visual order
- [ ] Dynamic type to 130% verified in goldens (brandkit §3/§8)
- [ ] Error messages state cause and recovery, near the field

**Firewall (every slice, non-negotiable)**
- [ ] D10's twelve prohibitions all hold
- [ ] The declared golden set changed and nothing outside it (D8)
- [ ] Slice-0 guards green, none weakened
