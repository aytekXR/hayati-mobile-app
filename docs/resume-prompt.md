# Resume Prompt

> This file contains ONE and only ONE objective. Every session executes ONLY this file. (See `project-rules.md` #1, `session-rules.md`.)
>
> **Standing de-gating note (ADR-007):** engineering milestones M1→M6 proceed without content-ops preconditions. Gates 1–3 are decision instruments for marketing/spend/launch posture, not build blockers. TikTok/content-ops work is out of session scope unless the founder re-activates it. First release target: the founder couple's own devices (personal-use-first).
>
> **Standing sequencing note (ADR-006):** iOS-first — milestones validate and ship on iOS first; Android work is re-sequenced into M6.5.
>
> **Standing tooling note (CodeGraph, founder directive 2026-07-09):** orient with CodeGraph at session start and use it for symbol/call-path/impact navigation throughout — `codegraph_explore`/`codegraph_node` MCP tools (CLI fallback `codegraph explore|node|callers`); sub-agents and workflow agents use the same tools via ToolSearch. Before the session ends, `codegraph sync` after the merge (session-rules §1 step 4 / §3 step 5). The index is machine-local (`.codegraph/`, gitignored).

## Objective — Session 006: M1.4 — brandkit application, goldens six-cell matrix, coverage ratchet to 62% (closes M1)

Final slice of M1 (`implementation-plan.md`). M1.1 landed the auth domain + Google; M1.2 landed provisioning + l10n + profile capture; M1.3 landed Apple + phone providers, Crashlytics + App Check, and the `integration-emulator` CI job (PR #14). Every auth/onboarding surface is still **deliberately unstyled beyond theme defaults** — that debt was always parked here. This session closes M1:

1. **Apply the brand kit** (`brandkit/` at the repo root, v1.0 — the founder directive says all design/UI work uses its tokens and assets). Extend `core/design_system/` beyond `ColorTokens`: typography scale, spacing, radii, and the Arabic font fallback + line-height rule that `architecture.md` §6 promises. Restyle the M1 surfaces: `SignInScreen` (Apple/Google/phone actions), `PhoneSignInScreen` (number + code entry), `OnboardingGate`, `ProfileCaptureScreen`, and the shared error views. Layout stays logical-direction only (RTL lint is already enforced).
2. **Stand up golden infrastructure — it does not exist yet.** This is the session's real risk: pick and wire the harness (plain `matchesGoldenFile` vs `golden_toolkit`/`alchemist`), pin a deterministic font loading strategy (real Arabic/Latin fonts, not Ahem, or goldens will lie about line height), and make CI reproducible — goldens rendered on macOS vs ubuntu differ, so decide **which job owns goldens** and record the trade-off. `flutter test --update-goldens` output is committed; W4 requires golden churn to be intentional and flagged in the PR.
3. **The six-cell matrix** (`test-suite.md` §1): each key M1 screen × {TR, AR, EN} × {LTR, RTL-where-applicable}, plus the dynamic-type 130% variant for onboarding. An un-mirrored arrow must fail the build.
4. **Ratchet the coverage gate 60% → 62%** in `ci.yml` (`test-suite.md` §3: +2%/milestone, never lowered). Current actual is 87.59%, so the ratchet is free headroom — but ratchet the *gate*, not the goal.
5. **Close M1 in the docs:** `implementation-plan.md` M1 checkbox + acceptance evidence, `architecture.md` §6 (font fallback/line-height now real, not promised), `roadmap.md` if it tracks milestone state.

**Acceptance criteria:** goldens exist and pass for every M1 screen across the six-cell matrix (+ the 130% onboarding variant); a deliberately mirrored/un-mirrored widget fails the golden check (prove the net catches something — don't just assert green); brandkit tokens are the single source of colour/type/spacing on M1 surfaces (no stray literals); `flutter analyze`/format/RTL lint clean; **coverage gate raised to 62% and passing**; both flavors boot; the `integration-emulator` job stays green (it is main-only — fire it on the branch with `gh workflow run ci.yml --ref <branch>` if you touch anything it exercises).

**External dependencies (founder):** none blocking. Still open from M1.3, needed only for **real-device** sign-in (not for CI or the emulator suites): enable the **Apple** and **Phone** providers on `hayatiapp-dev` + `hayatiapp-prod` (free-tier Auth provider init is console-only).

**Files likely to change:** `app/lib/core/design_system/**` (new token files), `app/lib/features/auth/presentation/**`, `app/lib/features/profile/presentation/**`, `app/test/**/goldens/**` (new), `app/test/support/**` (golden harness + font loading), `app/pubspec.yaml` (golden package + font assets), `.github/workflows/ci.yml` (coverage 62%, possibly a goldens job), `docs/architecture.md`, `docs/implementation-plan.md`, `docs/test-suite.md` (record the chosen harness), `docs/past-prompts.md`, this file.

**Validation steps:** full local gate sequence (`dart format` → `flutter analyze` → `dart tool/rtl_lint.dart app/lib` → `flutter test --coverage` → `dart tool/coverage_gate.dart --min 62 app/coverage/lcov.info`); push PR; `gh pr checks --watch`; squash-merge; `gh run watch` on main.

**Complexity:** medium-high (golden infra is new and font/platform determinism is where it bites). **Estimated duration:** one session (1–3 h) — if it overflows, land the design-system tokens + restyle + goldens for `SignInScreen` and slice the remaining screens' goldens to the next prompt per session-rules §1.4.

**Stopping conditions:** if goldens prove non-reproducible between the local box and the CI runner inside a 30-min timebox, pin goldens to a single platform (document which, and why, in `test-suite.md`) rather than fighting cross-platform rendering; if the brandkit lacks a token the UI needs, choose a defensible value, record it as a brandkit gap, and move on — do not redesign.

**Explicitly out of scope this session:** issue #15 (phone emulator suite crashes the app natively in `verifyPhoneNumber` on the iOS simulator — needs a Mac to capture the crash log; the suite is quarantined with a warning annotation and the flow is covered by VM unit tests); issue #13 (Android instant verification, M6.5); on-device App Attest / APNs / dSYM upload (all need the Mac — optional founder smoke, never acceptance-blocking per the automation directive); pairing/invite (M2); content packs & validator (M3); paywall (M4).

On completion, follow `session-rules.md` §3: append to `past-prompts.md`, regenerate this file with the next single objective (expected: M2.1 — invite Function + pairing code, the highest-risk milestone), commit, push, verify CI via `gh run watch`, then `codegraph sync`.
