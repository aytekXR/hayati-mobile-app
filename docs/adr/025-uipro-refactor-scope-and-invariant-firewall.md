# ADR-025: The UI/UX Pro Max refactor — scope, the skill's REJECTED workflow, the invariant firewall, and the eight-slice arc

- **Status:** Accepted
- **Date:** 2026-07-19 (Session 026)
- **Deciders:** session agent, per founder directive 2026-07-14 ("refactor the app's UI/UX with UI/UX Pro Max"); the copy gates inside the firewall are founder/native-reviewer-owned and are not resolved here
- **Related:** `docs/frontend-brandkit.md` (v1.0 — the visual constitution this ADR subordinates the skill to), ADR-018 (the device-privacy layer whose four lock invariants set the firewall's hardest boundary — **D3's no-dialog constraint is the gap this ADR found**), ADR-023 (the consent surface as a *guarantee* surface), ADR-016/017 (the ★ safety-gated crisis/coach copy), ADR-020 (store copy under the native-review gate), ADR-022 (the pre-frame bootstrap sentinel — the source-sentinel precedent this ADR extends), `docs/test-suite.md` §Golden harness, `docs/agent-workflows.md` W4 (the explicit golden-update flag), `docs/operator-expected.md` items 1 + ★ (the copy gates a refactor session may not silently cross)

## Context

The founder installed the **UI/UX Pro Max** tooling (`uipro` CLI v2.11.0, npm `ui-ux-pro-max-cli`, global on the dev box) and directed that the app's whole UI/UX be refactored through it. The roadmap recorded the unit as needing its own scoping ADR before any pixels move, sized as a multi-session arc. This is that ADR. **No UI code changes in this session.**

Two bodies of fact drive every decision below, and both were *produced*, not recalled: the skill was actually installed and actually run, and the app's surfaces were actually inventoried against source.

### Fact set A — what `uipro init` actually installed and actually does

`uipro init -a claude` was run at the repo root. It exited 0 and wrote **143 files / 2.8 MB into `.claude/skills/`**, across **seven** skills — not one:

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
| `--persist` wrote `design-system/hayati/MASTER.md` headed *"Global Source of Truth… strictly follow the rules below"* | brandkit v1.0 is the source of truth | Direct conflict of authority |

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

**B2 — ADR-018 D3, the single most safety-critical constraint the refactor faces, has NO mechanism.** The constraint — *nothing inside `LockScreen` or any widget it mounts may call `showDialog` / `showModalBottomSheet` / `showMenu` / `Navigator.of`, or use `Tooltip` / `Autocomplete` / `DropdownButton` / a selection-enabled field* — exists as a block comment at `lock_screen.dart:7-17` and one behavioural test that covers **only the recovery path** (`lock_screen_test.dart:319-326`). `LockScreen` sits above the app's only Navigator and has no Overlay ancestor; any such call **throws**, and on the recovery path that crash *is* the lockout. Verified by hand: of the eleven source-sentinel-style tests in `app/test`, **none scans `lock_screen.dart`**. A refactor adding a cooldown `Tooltip` or a biometric-error dialog would ship green. This is a pre-existing hole (open since M6.1), not one uipro creates — but the refactor is exactly the change that would walk into it.

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

Because B3 showed that rule resting on an unchecked hand-copy, **Slice 0 adds a token-parity test** (D5.ii). Until that test exists, no slice may proceed.

### D4 — The invariant firewall, per surface

Four classes, and every one of the 48 surfaces carries exactly one. A slice may not change a surface's class; only a new ADR can.

**Class F — FORBIDDEN to restructure (visual parity only).** `PrivacyGuard`, `PrivacyShieldCover`, `LockScreen`, `PinKeypad`.
A slice touching these may do **only** token normalization that leaves the rendered pixels byte-identical or changes them in a way declared in advance. It may **not**: add or remove a widget type, add any interaction, add any route, add any dialog/overlay/tooltip, change the `Offstage`+`TickerMode` gating shape, change `PrivacyShieldCover`'s direct `ColorTokens.night` (it must stay `night` independent of any runtime theme — ADR-018 FLUTTER-4), or un-pin the keypad's explicit `TextDirection.ltr` (numeric pads are not mirrored in RTL on any platform; the AR goldens pin 1-2-3 order).

**Class G — GUARANTEE surfaces (copy frozen, layout negotiable).** `ConsentGateScreen`, `LegalScreen`, `LegalDocumentScreen`, `ProviderActions` (both call sites), the coach help path.
The rendered *sentences* are the guarantee (ADR-023; ADR-016/017 ★). A slice may re-lay-out, re-space and re-theme them; it may **not** reword any `consent*` / `legal*` / `coach*` ARB value, may not change which sentence sits with which legal obligation, and may not break `ProviderActions`' by-construction property — the legal footer is present on *every* surface that renders sign-in buttons because they all share one widget. **Splitting `ProviderActions` per-screen is forbidden**; it would convert a structural guarantee into a convention.

**Class N — NATIVE-REVIEW-GATED copy (operator item 1).** Every remaining screen. Restructure freely; reword nothing. Any reword resets that key's native-review status and must be recorded in the session log and in `operator-expected.md` item 1 in the same diff.

**Class S — STRUCTURALLY UNREACHABLE (record, never attempt).** The system biometric prompt, the iOS alternate-icon confirmation alert, the OS share sheet, the iOS `LaunchScreen.storyboard`, the Android `launch_background.xml`, the Google and Apple sign-in sheets. A slice that "fixes" one of these is fixing something it does not own. *(The two splash surfaces are the only genuinely re-skinnable members of this class, and they are native-asset work explicitly deferred to the Mac era, item 4.)*

**Out-of-scope lookalikes** — carry the brand, are not this arc: `fastlane/metadata/**` (store listing, ADR-020), `brandkit/branding-assets/**` (master graphics + social), and the six `docs/legal/*.md` documents (their *rendering* is in scope; their *text* is frozen under the byte-drift test and the founder's review gate, item 9).

### D5 — Slice 0 is mandatory, moves no pixels, and builds the firewall before any slice runs

Three guards plus a harness rule. Each is modelled on an existing, proven pattern in this repo, and each must be **mutation-checked** (neuter it, confirm exactly its own test turns red, restore).

- **(i) The lock-screen forbidden-API source sentinel.** Modelled on `no_invalidate_sentinel_test.dart` (which strips comment lines before scanning — necessary here too, since `lock_screen.dart`'s header comment *names* the forbidden calls in prose). Scans `lock_screen.dart` **and every widget file it mounts** for `showDialog`, `showModalBottomSheet`, `showMenu`, `Navigator.of`, `Tooltip`, `Autocomplete`, `DropdownButton`. Closes B2. **This guard's absence is a live hole today, independent of the refactor** — filed as its own issue so it is not hostage to this arc.
- **(ii) The brandkit token-parity test.** Parses `brandkit/brandkit/tokens/hayati-tokens.json` and asserts every hex, type-scale entry, line-height, spacing step and radius equals its `ColorTokens`/`TypographyTokens`/`SpacingTokens`/`RadiusTokens` counterpart. Closes B3 and makes D3 enforceable. Bidirectional by construction: a brandkit edit without a Dart edit fails, and a Dart edit without a brandkit edit fails.
- **(iii) A frozen-sentence digest over the ★ and guarantee strings only.** A SHA-256 digest of the ARB values under the named ★ safety keys and the ADR-023 consent sentences, pinned in the test. Any reword turns CI red and forces a deliberate re-stamp — the W4 golden-flag pattern applied to the copy that carries safety and legal meaning. **Deliberately scoped to that named set, not to all 237 keys:** a digest over everything would tax every future copy session for little gain, and the broad native-review gate (item 1) stays what it honestly is — a *human* process with no mechanical enforcement. We do not fake a mechanism for it (ADR-024's lesson: prefer an honest gap to a fake guard).
- **(iv) The golden-set declaration rule** (D8).

**Slice 0's acceptance line:** all four land, all three guards mutation-checked, `flutter analyze` clean, full suite green, **zero golden PNGs changed** (slice 0 renders nothing differently).

### D6 — Slice 1 is the Material default floor, and it goes first because its blast radius is widest

Fill the `ColorScheme` slots M3 actually reads (`surfaceContainerHigh`, `surfaceContainerLow`, `inverseSurface`/`onInverseSurface`, `onSurfaceVariant`, `outline`) from brandkit tokens, and add the missing component sub-themes (`DialogTheme`, `SnackBarThemeData`, `CardTheme`, `BottomSheetThemeData`, `ListTileThemeData`, `DividerTheme`, `SwitchThemeData`, `TooltipTheme`, `PopupMenuThemeData`).

Rationale for ordering: this is a one-line-per-component change with an app-wide visual effect. Done first, its golden churn is absorbed in **one** declared, intentional re-baseline. Done later, it would invalidate every slice before it.

**Acceptance:** the three `AlertDialog`s and the export `SnackBar` render on brandkit surfaces (`night.raised` for dialogs/cards/sheets — never the same value as `surface`); no component still resolves a background through an unset slot; the declared golden set re-baselined; every golden outside it byte-identical.

### D7 — The arc: eight slices after slice 0, one per session, in this order

| # | Slice | Surfaces | Goldens | Class | Acceptance line |
|---|---|---|---|---|---|
| 0 | **The firewall** | — | 0 | — | Three guards land + mutation-checked; zero goldens change |
| 1 | **Material default floor** | `hayatiTheme` + `ColorScheme` | app-wide | — | D6's line |
| 2 | **The product core** — solo + paired home, question card, answer entry, partner slot, streak row, packs/coach tiles, gear overlay, invite nudge, solo-completed | 12 | 66 | N | "The reveal is the product" (brandkit §9.3) — the reveal moment measurably improved; every home state still renders every state it did |
| 3 | **Onboarding & pairing** — sign-in, phone sign-in, `ProviderActions`, profile capture, onboarding gate, invite share, partner preview | 7 | 93 | N + G | `ProviderActions` still ONE shared widget; the legal footer still present by construction on all three call sites |
| 4 | **Commerce** — paywall, pack selection, `PremiumGate` | 3 | 30 | N | Free-tier probes still byte-identical; the processing banner still reads as good news, never error colour |
| 5 | **Coach** — chat, disclaimer, help path | 3 | 27 | G + ★ | `CoachHelpCard` remains a structurally distinct widget TYPE from `CoachPersonaBubble`; the help-sticky latch still replaces the composer; zero ★ strings changed (digest green) |
| 6 | **Settings & data rights** — settings, PIN setup, PIN verify dialog, delete account, export, couple-ended notice, `SettingsErrorLine` | 7 | 55 | N | The delete confirmation still reads as irreversible and still says the shared space goes for both; `SettingsErrorLine` still shared, not forked per screen |
| 7 | **Legal & consent** — consent gate, legal hub, legal document | 3 | 18 | G | Layout only; digest green; the four consent escapes (sign out / export / delete / accept) all still reachable from the gate |
| 8 | **The lock — parity only** | 4 | 18 | **F** | The D5.i sentinel green; goldens byte-identical unless a token normalization is declared in advance; no new widget type, no new interaction |

**The arc is done** when every one of the 48 inventoried surfaces has been through a slice or is explicitly recorded here as parity-only (Class F) or unreachable (Class S). Slices 2–7 may be re-ordered by the founder; **0 and 1 may not move off the front, and 8 may not move off the back.**

### D8 — The goldens acceptance harness: declare the set BEFORE regenerating

The existing harness is the acceptance instrument and is not changed: 6 cells per state (`{tr,ar,en}` × `{ltr,rtl}`) plus 3 natural-direction cells at 130% text scale, 390×844 @1×, real Rubik/Noto fonts, **exact** pixel comparison, Linux-canonical (`cd app && flutter test --update-goldens` on Linux only — macOS renders text differently), diffs uploaded as CI artifacts, the RTL mirror-net self-test as the un-mirrored-arrow trap.

**The rule this ADR adds:** a slice **writes down the exact set of golden files it expects to change, in the PR description, before running `--update-goldens`**. After regeneration, `git status` must show changes to that set and **nothing else**. A golden outside the declared set that changed is a **defect to explain, not churn to accept** — the M4.2 and M6.2 precedent, where every non-target golden was git-verified byte-identical. This is what makes "never blind-accepted" (W4) mechanically checkable rather than aspirational.

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
6. Add `showDialog`/`Overlay`/`Tooltip`/`Navigator.of` anywhere under `LockScreen`.
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
- **Six of seven installed skills are dead weight on disk** (2.8 MB, gitignored) and are held out by a rule rather than by deletion, because the tool restores them on update.
- **The lock surfaces get almost no refactor.** Accepted: ADR-018's four invariants are worth more than visual consistency on the one screen most users see least.
- **`.claude/skills/` gitignored means a fresh machine must run `uipro init` to use the corpus ad hoc.** Mitigated by D1 — nothing binding needs it.

### Neutral

- The 332 untracked `failures/*.png` artifacts in the working tree are gitignored mismatch debris from past golden runs, not coverage. Noted so the next session does not mistake the 635-file working-tree count for the 303-file real one.
- `--stack flutter` (52 rows) is Flutter *idiom hygiene* (`const` constructors, `StatelessWidget` when possible) rather than UI/UX design intelligence; `flutter analyze` already covers most of it. It is retained in Appendix A only where it says something analyze does not.

## Appendix A — the binding per-slice checklist

Transcribed from `ui-ux-pro-max` v2.11.0's App-UI sections (its own scope notice: "App UI (iOS/Android/React Native/**Flutter**)"), adjudicated against brandkit v1.0. **Where a row cites the brandkit, the brandkit is the authority and the skill merely agrees.** Every slice's PR asserts this list.

**Visual**
- [ ] No emoji as structural icons; one icon family, one stroke weight — **Phosphor, rounded, 24dp grid, 1.75 stroke** (brandkit §5; the skill independently recommends Phosphor)
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
