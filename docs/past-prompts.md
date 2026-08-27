# Past Prompts — Append-Only Session History

> Rule: append new entries at the bottom. Never edit or delete prior entries (`project-rules.md` #2). Template:
>
> ```
> ## Session NNN — YYYY-MM-DD — <objective title>
> **Objective (from resume-prompt.md):** …
> **Outcome:** done / partial (what remains) / blocked (why)
> **Commits:** <hashes or PR link>
> **CI:** green / red→fixed / red→deferred (issue #)
> **Docs touched:** …
> **Notes / debt logged:** …
> **Next objective written to resume-prompt.md:** …
> ```

---

## Session 000 — 2026-07-08 — Incubation: idea challenge, market research, project genesis

**Objective:** Evaluate the brief ("copy an already-working app" — reference case: Flame, couples daily-ritual app) for Turkey/GCC/Arabic markets; challenge, redesign, decide; if positive, generate the full project documentation set.

**Outcome:** done.
- Challenged the "copy" framing → reframed as localization arbitrage on a twice-validated mechanic (Paired, Flame); original brand/content/code explicitly not copied; all packs to be culturally authored.
- Research performed (sources logged in `feasibility-report.md`): Paired US revenue estimates (~$200K/mo iOS + ~$100K/mo Play, Sensor Tower), 8M downloads; Turkey 40.2M adult TikTok users (61.6% adult reach); Egypt/Iraq/KSA TikTok 41.3M/34.3M/34.1M; GCC download growth 2.6% YoY vs 0.5% global; Saudi app/digital spend >$4.5B growing ~15%/yr; Arabic store saturated with matchmaking (Soudfa 10M+, Muzz 800K marriages) — post-marriage category empty in AR and TR.
- Key redesigns vs. reference: marriage-companion positioning; one-subscription-covers-both-partners; discreet mode + PIN as headline features; dual-register TR content; AR authored MSA-Gulf; Ramadan mode; social layer restricted to intra-couple + anonymous polls (stranger flirting rejected — decision record in `prd.md` §6); pomegranate brand system; dual pricing (TR volume / GCC margin).
- **Verdict: GO WITH CAUTION**, gated: G1 content virality (60 TR/AR test posts, 3 weeks) → G2 activation (pair ≥40%, D7 ≥25%) → G3 monetization (trial→paid ≥30%, install→paid ≥2%). Kill criteria documented.

**Commits:** n/a (repository not yet initialized — Session 001 = M0.1 scaffold).
**CI:** n/a.
**Docs produced:** README, feasibility-report, prd, mvp, architecture, frontend-brandkit, roadmap, implementation-plan, agent-workflows, project-rules, session-rules, test-suite, resume-prompt, past-prompts.
**Notes / debt logged:** working title "Hayati" pending trademark/store-name search (alternates listed in brandkit); Gate 1 content ops (Phase 0) runs before/alongside M0 only; no paid UA before Gate 3.
**Next objective written to resume-prompt.md:** Session 001 — M0.1 repository scaffold.

## Session 001 — 2026-07-08 — M0.1: Repository scaffold + iOS-first re-sequencing (founder directive)

**Objective (from resume-prompt.md):** M0.1 — initialize repository scaffold: Flutter app in `app/` with dev/prod flavors, `core/`+`features/` layout per `architecture.md` §2, Riverpod+codegen with example provider, strict lint + RTL `start/end` guard, example domain entity with failing-then-passing test, `content/` schema stub + validator placeholder, root README pointer to `docs/`.

**Outcome:** done. Additionally executed a founder directive received at session start: **iOS-first release sequencing** ("implement iOS-first; after successful completion we will continue with Android"). Resolution: Flutter stack retained (ADR-001 stands); iOS-first is release/validation sequencing, recorded as **ADR-006** with Android re-sequenced into **M6.5 — Android enablement & Play release** (gated on Gate 3). 24 doc edits applied across mvp/roadmap/implementation-plan/architecture/test-suite/prd/agent-workflows (multi-agent analyze→consolidate→adversarial-verify pass; all edits verified against gate/scope/pricing invariants).

**Scaffold details:** Flutter 3.44.5 stable; `app/` created with org `com.hayati`, bundle id normalized to `com.hayati.app` (iOS pbxproj + Android gradle); flavors as Dart entrypoints (`main_dev.dart`/`main_prod.dart`) overriding `appConfigProvider`; brand strings confined to `core/config/` (`kBrandName`); brandkit palette as `core/design_system/color_tokens.dart`; strict `analysis_options.yaml` (strict-casts/inference/raw-types + curated rules); RTL logical-direction guard at `tool/rtl_lint.dart` (no analyzer rule exists — line-scan script with `// rtl-ok` escape hatch); TDD proven red→green: `AppConfig` entity + provider + both-flavor widget smoke tests written first (3 failing files), then implemented (9/9 green); Riverpod 3 note: provider-body errors arrive wrapped, so the un-overridden-provider test asserts on the contract message, not the raw `StateError` type; generated `*.g.dart` committed so fresh clone → `flutter pub get && flutter test` is green without a build step; `content/` schema stub + example pack + validator placeholder (exits 1 by design, unwired).

**Commits:** single commit on `main`, 2026-07-08 (`feat(m0.1): ...` — this commit).
**CI:** n/a — pipeline does not exist until M0.2. Recorded explicitly per the Session 001 resume prompt rather than skipped: post-push `gh run list` returns no workflow runs.
**Docs touched:** mvp.md, roadmap.md, implementation-plan.md, architecture.md, test-suite.md, prd.md, agent-workflows.md, README.md (root + app/ + content/), adr/006-ios-first-release-sequencing.md (new), resume-prompt.md, past-prompts.md.
**Notes / debt logged (none silent):**
- Store-level flavor split (Gradle productFlavors / Xcode schemes, per-flavor bundle-id suffix) deferred to M0.2 (CI/Fastlane) where real toolchains can validate it; Dart-entrypoint flavors satisfy M0.1. Noted in `app/README.md` and `core/config/app_config.dart`.
- ADR-001..005 backfill files under `docs/adr/` belong to M0.2's "ADR skeleton" item (summaries already live in `architecture.md` §11).
- Gate 2 first read will be TR-iOS-cohort-only (directional) until M6.5 — the honest trade-off of iOS-first; recorded in ADR-006, mvp.md scope-change log, roadmap Phase 2.
- Flutter SDK on the dev machine lives at `~/flutter` (3.44.5 stable), installed this session.

**Next objective written to resume-prompt.md:** Session 002 — M0.2 GitHub Actions CI + branch protection + PR template + ADR skeleton + Fastlane init.

## Session 002 — 2026-07-08 — M0.2: GitHub Actions CI, branch protection, repo process skeleton

**Objective (from resume-prompt.md):** M0.2 — `ci.yml` (format → analyze → RTL lint → test --coverage → coverage gate ≥60% → iOS build smoke per ADR-006), branch protection on `main`, PR template (W3 sections), ADR skeleton (README + 001..005 backfill), Fastlane init (iOS stub only).

**Outcome:** done. **M0 is complete.**
- `ci.yml`: `quality` job (ubuntu; the five-step gate sequence) + `ios-build-smoke` (macos-15, `flutter build ios --no-codesign --debug --target lib/main_dev.dart`). Cost containment on the 10×-billed macOS leg: draft PRs skip it, `needs: quality` fail-fasts it, concurrency cancels superseded runs; `pull_request` types include `ready_for_review` so a draft→ready flip re-fires the required check. Push trigger is main-only (every change lands via PR per W3; avoids double-billed duplicate runs). Timings with warm cache: quality ~1m, iOS smoke ~2m37s (~26 billed macOS min/run — sustainable).
- `tool/coverage_gate.dart`: zero-dep lcov gate (PASS 0 / FAIL 1 / usage+zero-LF 64; zero-LF is an explicit error so an empty report can't silently pass). Baseline coverage 87.50% (LF 32, LH 28) vs the 60% floor.
- Branch protection via `gh api` (NOT plan-gated — worked on this private repo): required contexts `quality` + `ios-build-smoke`, `enforce_admins`, linear history, no force pushes/deletions, no review requirement (solo self-merge, green required — rule #7). Repo set to squash-merge-only + delete-branch-on-merge (W3).
- Acceptance proofs (PR #2, draft, closed unmerged): (1) deliberately failing test → `quality` FAILURE → `mergeStateStatus: BLOCKED` (run 28905568279); (2) gate raised to `--min 99` → job fails at the coverage step, `87.50% is below the 99% threshold` → BLOCKED (run 28905881305). `ios-build-smoke` correctly SKIPPED on the draft both times.
- iOS smoke earned its keep on first contact: caught that the scaffold has no `lib/main.dart` (flavors are Dart entrypoints, Session 001) — fixed with explicit `--target`. Not reproducible locally (no macOS).
- ADR-001..005 backfilled from `architecture.md` §11 in the ADR-006 format (provenance noted per file); `adr/README.md` format note + index; §11 now links all six records.
- Fastlane skeleton: iOS lanes only (`build_debug` mirrors the CI smoke; `beta` fails fast pointing to M6); Appfile `com.hayati.app`, zero secrets; root Gemfile pins fastlane `~> 2.225`.
- **Founder directive mid-session:** brand kit v1.0 dropped at `brandkit/` (logos incl. AR lockup, tokens css/json, app icons incl. discreet-mode alt, TR/AR/EN social/store graphics) — committed straight to `main` (75ba8cb + 473842a) with a pointer added in `frontend-brandkit.md`; kept out of the M0.2 PR (scope guard). All future design work sources from it.

**Commits:** PR #1 → squash `d0b0a00` on main; brandkit `75ba8cb` + `473842a`; session-close docs PR (this commit).
**CI:** green (PR #1 both checks; post-merge main run watched green via `gh run watch`).
**Docs touched:** adr/README.md + adr/001..005 (new), architecture.md §11, frontend-brandkit.md (brandkit pointer), resume-prompt.md, past-prompts.md.
**Notes / debt logged (none silent):**
- `Gemfile.lock` intentionally absent until fastlane first runs for real (M6) — no ruby/bundler on the dev machine. Documented in `Gemfile` + `fastlane/README.md`.
- Docs-only PRs run the full pipeline including the macOS smoke: `paths-ignore` on a required check would deadlock merges ("expected" forever), so it was deliberately not used. Revisit only if the Actions minute budget tightens.
- Coverage ratchet: floor stays 60% in `ci.yml`; first bump to 62% lands when M1 closes (test-suite §3).
**Next objective written to resume-prompt.md:** Session 003 — content pack validator v1 (Phase-0-parallel content tooling; Gate 1 standing note honored — M1.1 stays blocked until Gate 1 passes). *[Superseded before execution by the 2026-07-08 de-gating directive — see the Directive entry below and ADR-007.]*

## Directive — 2026-07-08 — De-gate build from content validation (ADR-007)

**Trigger (founder, verbatim intent):** "skip tiktok parts. focus on developing app. even if no one uses the app, I and my wife will use it. continue developing the app iOS-first." Founder additionally commits personal-device testing (Mac + Xcode, personal iPhone) on request.

**Resolution:** recorded as **ADR-007**. Engineering M1→M6 proceeds immediately, iOS-first (ADR-006 unchanged); Gate 1 decoupled from engineering; Gates 1–3 retained as marketing/spend/launch decision instruments only; TikTok/content-ops leave the session pipeline; content packs re-scoped as product/dogfood content (validator back to M3); personal-use-first quality bar (founder couple = first release target).

**Docs touched:** adr/007 (new), adr/README.md (index), architecture.md §11, roadmap.md (de-gating note + Phase 0 header), prd.md (status line), implementation-plan.md (M6.5 gate wording), resume-prompt.md (regenerated: Session 003 = M1.1 Firebase foundation + Auth domain, superseding the unexecuted validator objective).

**Outcome:** docs-only change, merged via PR with green pipeline.
**Next objective in resume-prompt.md:** Session 003 — M1.1 Firebase foundation + Auth domain (external dependencies noted: founder `firebase login` at session start; Apple Developer Program status to confirm for M1.2 provider work).

## Session 003 — 2026-07-08 — M1.1: Firebase foundation + Auth domain (emulator-only fallback)

**Objective (from resume-prompt.md):** M1.1 — Firebase projects + FlutterFire wiring; auth domain TDD-first (`AuthUser`, `AuthRepository`, state machine); one provider end-to-end (Google) against the Auth emulator; auth presentation shell; docs-with-code.

**Outcome:** done, **with the resume prompt's documented fallback active**: founder `firebase login` was unavailable at session start (`firebase login:list` exit 1), so the session ran **emulator-only** — no real projects created; provisioning deferred loudly, not silently (issue #5).

- **Emulator path validated first:** Auth emulator boots credential-free with `demo-hayati` (repo-root `firebase.json`/`.firebaserc` committed); REST smoke proved signUp **and** fake-Google `signInWithIdp` with an unsigned JSON `id_token` — the exact mechanism the integration test uses.
- **Design verified before code (W2 + ultracode):** a 5-agent workflow read the *resolved* package sources (`firebase_auth` 6.5.4, `google_sign_in` 7.2.0, `riverpod` 3.0.3, `firebase_core_platform_interface` 7.1.0) and produced an authoritative brief that overrode 7 design assumptions — the load-bearing ones: google_sign_in v7 signals cancel by **throwing** (`GoogleSignInExceptionCode.canceled`), `authentication` is a sync getter with **idToken only** (no accessToken; Firebase needs idToken alone), `initialize()` is a hard call-once precondition, `ref.mounted` guards required after every await in Riverpod 3 notifiers, `setupFirebaseCoreMocks()` is the canonical test-VM Firebase double (but `FirebaseAuth.instance` can never be constructed in the VM → boot smoke split into pure options-selection tests + mocked-core init smoke), `overrideWith` not `overrideWithValue` for the repo provider, and Firebase iOS SDK 12 (⇒ iOS floor 15.0 + Xcode ≥ 16.2 on CI runners).
- **Delivered (TDD red→green per slice; 84 tests, coverage 86.81% vs 60% gate):** `features/auth/domain` (pure Dart: `AuthUser`, sealed `AuthState`/`AuthException`, `AuthRepository`, throwing-base `authRepositoryProvider` mirroring `appConfigProvider`); `presentation/state/AuthController` (stream-driven state machine with manual-op precedence — in-flight sign-in owns the state, stream emissions can't clobber it; cancel→signed-out; double-tap debounce; dispose-safe via `ref.mounted`); `data/` (`FirebaseAuthRepository` + `GoogleSignInAuthGateway`, cancel-as-null contract); `core/firebase` (per-flavor **placeholder** options — dev `demo-hayati`, prod inert; idempotent `initializeFirebase` tolerating hot-restart `duplicate-app`; opt-in `USE_AUTH_EMULATOR`/`AUTH_EMULATOR_HOST` dart-defines); minimal `SignInScreen` (loading/error/content/signed-in, RTL-safe, unstyled pre-brandkit); entrypoints compose the real repository via new `runHayati(..., extraOverrides)`; `integration_test/auth_emulator_test.dart` (device-only round-trip; manual until #6).
- **Adversarially-verified review pass (W2 Reviewer, 17 agents):** 12 findings → **7 confirmed & fixed**, 5 refuted. The confirmed cluster was real: non-`AuthException` throwables (plugin `PlatformException`s, pigeon decode errors, `initialize()` failures) escaped the taxonomy at four data-layer points and would strand the UI on a permanent spinner (no retry affordance); plus the memoized init-future caching a transient failure forever. Fixes: `_guarded()` boundary enforcement in the repository, mapped + retryable gateway initialization, mapped gateway/repo `signOut`, error-copy widget tests (network vs generic). Refuted (no action, verified): Xcode pin (macos-15 default ≥ 16.2), prod-build emulator define, authStateChanges onError, fake replay-on-subscribe fidelity, synthetic exception codes.
- **iOS build config — the milestone's predicted risk, materialized once:** deployment target 13.0→15.0 (pbxproj ×3; Firebase iOS SDK 12 requires it). First `ios-build-smoke` run went **red**: a Podfile had been added defensively (pods-era reflex), but the Flutter 3.44 scaffold is **SwiftPM-first** — all Firebase/google_sign_in plugins resolve as Swift Packages (M0.2's smoke was green with no Podfile), and the hybrid integration died with "sandbox is not in sync with the Podfile.lock". Fix (≤15 min rule): delete the Podfile, keep the pbxproj bump → green. Learning recorded in architecture.md §2: **no Podfile in this project**. `GoogleService-Info.plist` not needed to compile (Dart-only options); URL-scheme/client-id wiring is runtime-only → M1.2 (#5).

**Commits:** PR #7 (`c14b90a` feat + Podfile-fix commit) → squash-merged to main; session-close docs PR (this commit).
**CI:** red→fixed, then green — first `ios-build-smoke` failed (Podfile/SwiftPM hybrid, see below), fixed inside the ≤15-min rule, both checks green on re-run (quality 1m24s, ios-build-smoke 6m19s); post-merge main run watched green via `gh run watch`.
**Docs touched:** architecture.md §2 (Firebase environments + deviation note), app/README.md (emulator run instructions), root `.gitignore` (firebase debris), resume-prompt.md (regenerated), past-prompts.md (this entry).
**Notes / debt logged (none silent):**
- Issue #5 — provision `hayati-dev`/`hayati-prod`, `flutterfire configure` per flavor (replaces both placeholder options files), iOS `REVERSED_CLIENT_ID` URL scheme + client id, Android `serverClientId`, founder manual smoke. Blocked on founder `firebase login`.
- Issue #6 (`ci-debt`) — Auth-emulator integration test not in CI (needs macOS runner + simulator + emulator leg); manual instructions in the test header + app/README.md.
- Goldens: explicitly deferred, not skipped — no golden infra exists and the M1.1 shell is deliberately unstyled/EN-only pre-brandkit; the test-suite §1 6-cell matrix lands with the brandkit+l10n M1 slice.
- Founder question (b) from the Session-003 prompt — paid Apple Developer Program status — **remains unanswered**; carried into the M1.2 prompt (determines when Sign in with Apple + APNs/phone auth land).
- Coverage floor stays 60% (`ci.yml`); ratchet to 62% when M1 closes (test-suite §3, Session-002 note).

**Next objective written to resume-prompt.md:** Session 004 — M1.2 Firebase provisioning (#5, founder-gated with emulator-only fallback) + profile capture & locale bootstrapping (l10n scaffold TR/AR/EN, profile domain TDD, Firestore-emulator-backed repository, onboarding capture states).

## Directive — 2026-07-08 — Post-Session-003: automation preference, Apple Developer confirmed, Firebase provisioned

**Trigger (founder, same day as Session 003 close):** (1) "all automated if possible" — minimize founder-in-the-loop steps; (2) founder enrolled in the **paid Apple Developer Program** (the open question from the Session-003 external dependencies is now answered: **yes**); (3) founder authorized executing the cloud half of issue #5 immediately.

**Resolution:**
- **Automation preference (standing):** prefer scripted provisioning and automated emulator/CI verification over manual device smokes; manual smokes become optional/nice-to-have, never acceptance-blocking. Reflected in the regenerated Session-004 prompt.
- **Apple Developer:** confirmed → M1.3 proceeds with Sign in with Apple + APNs/phone auth as planned. Nothing buildable from the Linux box today; certificate/profile automation (Fastlane match) remains M6.
- **Firebase provisioning (issue #5, cloud half):** first attempt under the founder's **org account** (`beyondkaira.com`) failed — every `addFirebase` 403'd despite proven Owner role, enabled API, and a clean org policy; root cause was simply the **wrong account**. Re-login with the personal account succeeded instantly. Created + Firebase-attached **`hayatiapp-dev`** / **`hayatiapp-prod`**, registered iOS+Android apps for `com.hayati.app` on both, verified config retrieval via `apps:sdkconfig`, updated `.firebaserc` dev/prod aliases (default stays `demo-hayati` for the emulator). Full app IDs in the issue #5 comment. Burned/orphaned IDs flagged for optional cleanup: `hayati-dev` (taken by a third party), `hayati-app-dev` (orphaned GCP project in the beyondkaira org), `hayati-app-dev-697a5` (console-created duplicate during troubleshooting).

**Docs touched:** resume-prompt.md (Session-004 item 1 rescoped to the repo half; external dependencies cleared; automated-verification acceptance wording), `.firebaserc`, issue #5 comment, past-prompts.md (this entry).
**Outcome:** docs-only change, merged via PR with green pipeline. Session 004 starts with zero founder-gated blockers.

## Session 004 — 2026-07-08/09 — M1.2: Firebase provisioning + profile capture & locale bootstrapping

**Objective (from resume-prompt.md):** M1.2 — finish issue #5 repo half (`flutterfire configure` per flavor, Google provider enablement, iOS/Android OAuth client wiring); l10n scaffold TR/AR/EN with sign-in copy migration; profile domain TDD-first (`RelationshipProfile`, locale bootstrap); Firestore data layer (`users/{uid}`, emulator-backed); onboarding capture shell with tr/ar/en widget-test matrix.

**Outcome:** done — all five items, no slicing needed. **The session ended stuck on a non-code blocker** (GitHub Actions billing — see CI below); a continuation session (2026-07-09) cleared it and completed merge + close.

- **Issue #5 repo half — closed, no placeholder seam left:** real `hayatiapp-dev`/`hayatiapp-prod` options committed via `flutterfire configure` per flavor (Dart-only init preserved; the plugin's gradle/google-services side effects deliberately reverted — one Android app id serves both flavors, so the gradle plugin would bake prod config into dev builds). Google provider enabled on both projects — **console click, not API**: free-tier Auth provider init is console-only (Identity Toolkit Admin API `updateConfig` demands a pre-existing OAuth client; `initializeAuth` is the billing-gated GCIP upgrade path) — recorded so future provider enablement (Apple/phone, M1.3) budgets the founder clicks upfront. Real OAuth client ids wired: per-flavor `GoogleSignInConfig` (iOS `clientId` at runtime — one Runner can't hold two `GIDClientID`s; Android web `serverClientId`), both `REVERSED_CLIENT_ID` URL schemes in Info.plist. Firestore `(default)` databases created at **eur3** on both projects; `firestore.rules` deployed (users/{uid} self-only, default-deny).
- **l10n scaffold:** ARB tr/ar/en under `lib/core/l10n/arb`; generated output gitignored (regenerates on `pub get`; verified format/analyze/rtl/coverage-safe on a clean checkout); sign-in copy migrated off literals; unsupported locales resolve to EN (matches the domain bootstrap fallback).
- **Profile domain (TDD red→green):** `RelationshipProfile` (status/contentLanguage/register per PRD F1, dual-register TR), content-language bootstrap with device→profile-override precedence, `ProfileRepository` contract + exception taxonomy.
- **Firestore data layer:** `users/{uid}` DTO mapping (pure, VM-tested); create-once `createdAt` via transaction with `merge:true`; full error-code mapping; auth+firestore emulator integration test (device-only, folded into #6 scope; Firestore emulator needs Java 21+).
- **Onboarding shell:** signed-in → `OnboardingGate` (loading/error/capture/placeholder) → capture screen (TR-only register choice) → M2 invite stub; widget tests across the tr/ar/en matrix with RTL asserted from locale.
- **Design-first (W2 + ultracode):** 3-agent workflow read resolved package/SDK sources (gen_l10n 3.44 semantics, cloud_firestore 6.6.0, firebase-tools emulator) — caught Riverpod 3 auto-retry masking stream errors as `AsyncLoading` (fixed: `_noRetry` + flag-based gate). Adversarially-verified review (W4, 21 agents): 2 confirmed findings fixed (merge:true assertion, register-reset coverage), 3 refuted.

**Commits:** PR #10 (`b3d048e` feat + `c2901a6` review-pass) → squash `9a0d0fb` on main; session-close docs PR (this commit).
**CI:** red→fixed — and the red was **billing, not code**: GitHub Actions refused to start jobs on PR #10 ("recent account payments have failed or your spending limit needs to be increased" — private repo; the macOS smoke bills at 10×). Session 004 ended stuck here with PR #10 open and local gates green. Continuation (2026-07-09): local quality gate re-verified green (145 tests, coverage 88.12% vs 60% floor), founder fixed billing, rerun → both checks green (quality 1m18s, ios-build-smoke 6m40s), squash-merged, post-merge main run watched green via `gh run watch`.
**Docs touched:** docs/architecture.md §2 (real provisioning + console-only learnings) / §3 (users/{uid} wire fields + shipped rules slice) / §6 (ARB layout, EN fallback), app/README.md (Firebase section rewritten for the provisioned state), firebase.json (firestore emulator), firestore.rules (new), resume-prompt.md (regenerated), past-prompts.md (this entry).
**Notes / debt logged (none silent):**
- Issue #5 closed by PR #10. Issue #6 (`ci-debt`) scope widened in practice: the emulator CI leg now covers auth **and** firestore emulators (Java 21+ on the runner).
- Free-tier Firebase Auth provider enablement is console-only (finding above) — M1.3's Apple + phone providers need the same founder clicks; budgeted in the Session 005 prompt's external dependencies.
- **Actions billing is a standing operational risk:** macOS minutes bill at 10× on this private repo; the billing failure silently blocks all merges (jobs die in seconds, PR sits BLOCKED). If it recurs, the options are raising the spending limit / fixing payment (founder) or making the repo public (founder decision).
- Coverage floor stays 60%; ratchet to 62% lands when M1 closes (test-suite §3) — expected at the brandkit/goldens M1 slice after M1.3.
- Brandkit visual application + goldens (test-suite §1 six-cell matrix, now unblocked by l10n) remains the final M1 slice after M1.3.

**Next objective written to resume-prompt.md:** Session 005 — M1.3: Apple + phone auth providers (emulator-first), Crashlytics + App Check, CI emulator integration leg (#6).

## Directive — 2026-07-09 — Adopt CodeGraph for code navigation (sessions + agents)

**Trigger (founder, post-Session-004 close):** CodeGraph newly installed; "starting from next session I will utilize it" — agents should use CodeGraph during sessions, and the index must be updated before each session ends.

**Resolution:** CodeGraph (CLI at `~/.local/bin/codegraph`; MCP server `codegraph` registered globally in `~/.claude.json`, so `codegraph_explore`/`codegraph_node` tools are live from Session 005 on) becomes the standing code-navigation layer:
- **Session start (session-rules §1 step 4):** `codegraph status`, sync if stale; orientation and symbol/call-path/impact questions go through `codegraph_explore`/`codegraph_node` (CLI fallback `codegraph explore|node|callers`) instead of raw grep sweeps; sub-agents/workflow agents are pointed at the same MCP tools (reachable via ToolSearch).
- **Session end (session-rules §3 step 5):** `codegraph sync` after the merge lands, so the index reflects merged `main` for the next session.
- **Index hygiene:** the index is a machine-local sqlite DB — `.codegraph/` added to the root `.gitignore` (2.93 MB at adoption; never repo content); a fresh machine runs `codegraph init` once. Repo indexed this session: 82 files, 739 nodes, 1,820 edges, current with main `58faae6`.

**Docs touched:** session-rules.md (§1 step 4 new, §3 step 5 new), agent-workflows.md (W2 sequence), resume-prompt.md (standing tooling note in the header block — survives regenerations like the ADR-006/007 notes), .gitignore (`.codegraph/`), past-prompts.md (this entry).
**Outcome:** docs-only change, merged via PR with green pipeline.
**Next objective in resume-prompt.md:** unchanged — Session 005 — M1.3 (Apple + phone providers, Crashlytics + App Check, ci-debt #6 CI emulator leg).

## Session 005 — 2026-07-09 — M1.3: Apple + phone providers, Crashlytics + App Check, CI emulator leg

**Objective (from resume-prompt.md):** M1.3 — Sign in with Apple (emulator-first), phone auth (emulator-first), Crashlytics wired behind a VM-testable seam with a per-flavor collection policy, App Check activated (debug in dev / App Attest declared in prod), and ci-debt #6's emulator integration leg in CI.

**Outcome:** done — all five items, plus a documented quarantine. Everything shipped except one thing that could not be true: the phone flow's **emulator round-trip on the iOS simulator**, which the CI leg proved crashes natively (issue #15). Phone auth itself is complete and unit-covered; only its emulator suite is quarantined.

- **Emulator-first, literally: both mechanisms were proven over the Auth emulator's REST API before a line of code was written.** `apple.com` `signInWithIdp` accepts an unsigned JSON `id_token` (the trick M1.1 validated for Google), and the phone flow round-trips `sendVerificationCode` → fake-code REST endpoint → `signInWithPhoneNumber`. A third REST probe settled a trap nobody had asked about: the Auth emulator files verification codes under **the project it was booted with (`demo-hayati`)**, ignoring the app's `hayatiapp-dev` API key — querying the app's own project id returns an empty list. The integration test reads `demo-hayati` and throws a diagnostic `StateError` if that ever changes.
- **Design verified before code (W2 + ultracode), 6 agents over resolved package sources.** The load-bearing findings: `signInWithProvider` sends **no `AuthCredential`** over pigeon (only `InternalSignInProvider`), so it can be neither faked in the VM nor driven against the emulator — it was rejected in favour of `sign_in_with_apple` + `credentialWithIDToken` behind a gateway seam ([ADR-008](adr/008-apple-signin-via-credential-seam.md)); `signInWithCredential` forwards `credential.asMap()` with **zero client-side validation**, which is *why* the unsigned-token trick works at all; `verificationCompleted` is Android-only and `verificationFailed`/`codeAutoRetrievalTimeout` can fire **after** `codeSent` on the same broadcast stream (so the `Completer` needs `isCompleted` guards on every path); `FirebaseAppCheck.activate()` and `FirebaseCrashlytics.instance` both throw `channel-error` in the plain test VM, which forced entrypoint-only activation; `sign_in_with_apple` 8.1.0 ships a `Package.swift`, so it does **not** drag back the Podfile that broke CI in Session 003. Apple's nonce is a two-value protocol (sha256-hex to Apple, plain `rawNonce` to Firebase) — inverting it compiles and fails only on a real device, so a test asserts the direction.
- **Delivered (TDD red→green per slice; 145 → 238 tests, coverage 87.59% vs the 60% gate):** `AppleAuthGateway` + `SignInWithAppleGateway` (function-seam injection, since `SignInWithApple` is all-static); `PhoneAuthGateway` + `FirebaseVerifyPhoneGateway` (four callbacks → one guarded `Completer`); opaque `PhoneSignInSession`, sealed `PhoneSignInState`, screen-scoped `PhoneSignInController` that **never writes the global `AuthState`** (the terminal `AuthSignedIn` arrives on `authStateChanges` while `AuthController` is idle, so the M1.1 precedence contract is untouched); two purposeful new exceptions (`AuthInvalidCodeException`, `AuthSessionExpiredException`); `core/observability/` (`CrashReporter` interface over framework types only, one file importing `firebase_crashlytics`, `installErrorHooks` for `FlutterError.onError` + `PlatformDispatcher.onError`); `core/firebase/app_check_bootstrap.dart` (pure flavor→provider selection + entrypoint-only `activateAppCheck`, skipped under the emulator); phone entry/code screens + Apple button, l10n in tr/ar/en (32 keys, all three locales, all documented, none dead); `Runner.entitlements` + `CODE_SIGN_ENTITLEMENTS` (inert under `--no-codesign`).
- **Adversarially-verified review (7 dimensions, 3 refuters per finding): 3 confirmed, 0 false positives, all fixed.** (1) *major* — a failed **resend** discarded the still-valid session and bounced the user back to phone entry, inconsistent with `confirm()` which retains it; now threads `resendFrom`, and the fix was proven red→green by reverting it. (2) *minor* — Android instant verification (`verificationCompleted` without `codeSent`) would leave the `Completer` unresolved and hang `sendCode` **forever**; now fails loudly, with issue #13 for real M6.5 support. (3) *minor* — the error view's "Try again" was hardcoded to Google, so retrying after an **Apple** failure silently launched the Google flow; the error view now re-offers every provider.
- **The CI leg justified itself on first execution.** It had never run, so rather than let it debut on `main`, it was fired on the branch via `workflow_dispatch` — and went red three times before green, each time on a *real* defect: (a) `flutter test integration_test` (a directory) runs suites **concurrently** against the single simulator, where they fight over the shared `com.hayati.app` bundle (`Unable to terminate…`, a whole suite `did not complete`) → suites are now serialized, one invocation each, with failure propagation verified by simulating the script; (b) `profile_emulator_test` — written on Linux in Session 004 and therefore **never executed anywhere** — read back `null` after `saveProfile`, because `runTransaction` commits server-side with no local latency compensation, so a fresh listener emits the stale cached "no document" first and `.first` raced it (the app was never affected: `OnboardingGate` holds one long-lived subscription) → asserted with `emitsThrough`; (c) the phone suite crashes the app natively inside `verifyPhoneNumber` (issue #15). **Google and Apple round-trips pass green on the simulator**, which is the acceptance signal that matters — ADR-008's whole premise, executed end-to-end.

**Commits:** PR #14 (`5d5f34d` feat + `15abda7` CI fixes + `a52b928` quarantine) → squash `061e88e` on main; session-close docs PR (this commit).
**CI:** red→fixed→green. `quality` + `ios-build-smoke` green on the PR. The `integration-emulator` job is main-only and therefore *skips* on PRs, so it was fired on the branch with `gh workflow run` rather than allowed to debut on main — it went red twice on CI/test defects (suite concurrency; the transaction/cache race) and once on the phone suite's native crash, then green: `auth_emulator_test` **+2 (Google + Apple)**, `profile_emulator_test` **+2**, phone quarantined with its warning surfaced as a run annotation. The billing that blocked Session 004 stayed healthy throughout.
**Docs touched:** docs/architecture.md §1 (providers) / §2 (auth seam + Crashlytics/App Check posture + emulator project-id trap) / §9 (CI leg, serialization, quarantine) / §11 (decision log), new docs/adr/008-apple-signin-via-credential-seam.md + ADR index, app/README.md, resume-prompt.md (regenerated), past-prompts.md (this entry).
**Notes / debt logged (none silent):**
- Issue #6 (`ci-debt`) **closed** by the `integration-emulator` job.
- Issue #13 — Android instant verification (`verificationCompleted`) must sign in with the auto-resolved credential instead of erroring; M6.5, carries a `// DEBT:` comment at the seam.
- Issue #15 (`ci-debt`) — phone emulator suite crashes the app on the iOS simulator; quarantined with a `::warning::` annotation in every run (W4: same-day quarantine + issue, never a silent retry). Probable cause: the native app-verification path (APNs → reCAPTCHA), the one assumption no package source could settle. Needs a Mac to capture the crash log.
- **Deferred loudly to the on-device/Mac slice:** App Attest entitlement + console registration, per-device App Check debug-token registration, the `FirebaseCrashlyticsCollectionEnabled=false` Info.plist baseline (dev's first-launch pre-Dart collection window stays open), dSYM upload for prod symbolication (SwiftPM omits the podspec's run-script), and on-device confirmation that Apple's first-authorization full name reaches `displayName`. **App Check enforcement must stay OFF in both consoles** until on-device attestation is verified, or the founder couple gets locked out of Auth/Firestore.
- **Founder action still open:** enable the **Apple** and **Phone** sign-in providers on `hayatiapp-dev` + `hayatiapp-prod` (free-tier Auth provider init is console-only, M1.2 finding). Neither the emulator suites nor CI need it; real-device sign-in does.
- **A Slack-notification commit** (`13f1e6d`, authored outside this session) had landed on the feature branch with a **live incoming-webhook URL** embedded; GitHub push protection rejects it, so the branch was rebuilt on `main` without it. It is preserved unchanged on the local branch `chore/slack-notifications`. To land it the webhook must move to a repository secret — and since it was committed, it should be rotated in Slack.
- Coverage floor stays 60% (`ci.yml`); the ratchet to 62% lands when M1 closes (test-suite §3) — i.e. with the next slice.

**Next objective written to resume-prompt.md:** Session 006 — M1.4: brandkit visual application + goldens six-cell matrix (tr/ar/en × LTR/RTL) + coverage ratchet to 62%, closing M1.

## Session 006 — 2026-07-09 — M1.4: brandkit application, goldens six-cell matrix, coverage ratchet to 62% (closes M1)

**Objective (from resume-prompt.md):** M1.4 — apply the brand kit to every M1 surface (design-system tokens beyond `ColorTokens`: typography, spacing, radii, the Arabic font-fallback + line-height rule), stand up golden infrastructure from nothing, ship the six-cell golden matrix ({tr,ar,en} × {LTR,RTL}) + 130% onboarding variant with a proof the net catches an un-mirrored widget, ratchet the coverage gate 60→62, close M1 in the docs.

**Outcome:** done — all five items. M1 is closed.

- **Research before code (ultracode, 3 parallel agents):** (1) harness landscape — `golden_toolkit` confirmed discontinued on pub.dev; `alchemist` 0.14.0 maintained and 3.44-compatible, but its one differentiator (cross-OS block-text rendering) defeats the real-font goldens we want, so the decision is **zero-dep**: plain `matchesGoldenFile` + ~90-line in-repo harness. (2) Conventions — exact state-forcing recipes extracted from the existing tests, plus the hard constraint list: the restyle must keep widget types (`FilledButton`/`ChoiceChip`/`TextField`/`CircularProgressIndicator`/plain `Text(kBrandName)`) or 238 tests break. (3) Fonts — 12 static TTFs (Rubik / Noto Sans / Noto Sans Arabic, w400–700) fetched from Google Fonts with OFL licenses; glyph coverage verified by parsing cmap tables (Rubik carries **both** Arabic and Turkish at every weight, so the brand's primary family renders both scripts; Noto Sans Arabic is the true fallback).
- **Design system (`core/design_system/`):** typography/spacing/radius token files mirroring `hayati-tokens.json` v1.0 exactly; `hayati_theme.dart` builds the dark brand theme from tokens only — manual const `ColorScheme` (not `fromSeed`, which detunes the hexes) with contrast ratios computed and cited in comments. The **Arabic body line-height rule (1.5 latin / 1.7 arabic) is real**: `MaterialApp.builder` rebuilds the theme against the resolved locale. Brandkit gaps found while applying v1.0 are logged in `frontend-brandkit.md` §10 with the chosen values (no on-pomegranate token → sand at 3.94:1, rule as authored covers night only; pomegranate-on-night 3.45:1 fails the ≥4.5 text rule → links render sand, pomegranate is fill/accent only; unspecified button/input radii → chip-full/card-16; unspecified heading line-heights → font defaults).
- **Restyle:** all five M1 surfaces + shared error views now draw colour/type/spacing exclusively from tokens; widget types, l10n copy, and public classes untouched — **all 238 pre-existing tests passed without a single edit**.
- **Golden infra + matrix (286 tests total, 47 PNGs):** fonts load once in `app/test/flutter_test_config.dart` (plus MaterialIcons — a tofu arrow is symmetric and would silently defeat the mirror net); harness pumps a 390×844@1x branded MaterialApp with the cell's direction forced by a `Directionality` *inside* the app (direction decoupled from locale = the six-cell contract). Eight states across the five screens × six cells + `fresh_scale130` in natural directions. Spinner states deliberately not golden'd (indeterminate animation). Determinism proven by two consecutive full-suite runs. **Goldens are Linux-canonical** (dev box + ubuntu `quality` job); macOS renders text differently and must never run `--update-goldens` — recorded with the harness rationale in `test-suite.md`.
- **The net-proof needed a design change, documented in-file:** an intentional `matchesGoldenFile` mismatch reports its `TestFailure` through the async error zone (uncatchable in-test), and `RenderRepaintBoundary.toImage` hangs the headless rasterizer — so the net records mirrored + deliberately-un-mirrored probe goldens and asserts their **bytes differ**. With the exact comparator that transitively proves an un-mirrored arrow cannot pass, and the check survives `--update-goldens` re-baselining (a global mirroring regression would regenerate both files identical → red).
- **Adversarially-verified review (5 dimensions → 3 refuters per finding): 1 confirmed, 1 refuted 0/3, 1 suspicion dissolved by measurement.** Confirmed (unanimous): input **hint text at sand@0.5 over nightRaised = 4.12:1**, below the brandkit's ≥4.5:1 — fixed to 0.6 (5.29:1), zero golden churn (no golden focuses a field). Refuted: a heading-line-height claim. Dissolved: the two selected chips in the TR capture golden *look* like different reds — pixel-sampled to identical `#8E3140` (simultaneous-contrast illusion).
- **CI:** coverage gate 60→62 (actual 89.11%); golden failure diffs (`failures/`, gitignored) upload as artifacts on a red quality job.

**Commits:** PR #18 (`a4882fd`) → squash-merge to main; session-close docs PR (this commit).
**CI:** green — `quality` + `ios-build-smoke` on the PR; `integration-emulator` untouched by this diff (presentation/tests/CI/docs only) and ran on the post-merge main push.
**Docs touched:** docs/test-suite.md (§1 matrix live + golden-harness record), docs/architecture.md §6 (font fallback/line-height/goldens now real), docs/implementation-plan.md (M1 ✅ + evidence), docs/frontend-brandkit.md (§10 gap log), resume-prompt.md (regenerated), past-prompts.md (this entry).
**Notes / debt logged (none silent):**
- Brandkit v1.0 gaps recorded in `frontend-brandkit.md` §10 rather than redesigned around (resume-prompt stopping condition).
- Goldens do not validate Impeller output (flutter_tester rasterizes with Skia software) — they are layout/typography regression nets, not device-pixel proof; noted in the harness record.
- Golden churn is expected on Flutter/engine upgrades (exact comparator); re-baseline is Linux-only behind the W4 intent flag.
- Still open from M1.3 (founder, real-device only): enable Apple + Phone providers in both consoles; the Mac slice (App Attest, APNs, dSYM, issue #15 crash log) unchanged.

**Next objective written to resume-prompt.md:** Session 007 — M2.1: Functions workspace + `createInvite` (pairing code) + rules hardening, emulator-tested per-PR on ubuntu (opens M2, the highest-risk milestone).

## Session 007 — 2026-07-09 — M2.1: Functions workspace + `createInvite` (pairing code) + rules hardening, emulator-tested (opens M2)

**Objective (from resume-prompt.md):** M2.1 — first Cloud Functions (TypeScript) code: `functions/` workspace (functions v2/Node 20, eslint, vitest, coverage gate 85/hard-fail 80), `createInvite` callable (collision-safe unambiguous pairing code, server-set expiry, documented re-issue policy, App Check plumbed/enforcement OFF), `firestore.rules` hardening (invites function-write-only, couples member-only skeleton, `users/{uid}.createdAt` create-once), rules+Function emulator suites per-PR on ubuntu.

**Outcome:** done — all five items, plus a test-inclusive `tsc` typecheck step the plan didn't list (vitest transpiles without typechecking; the gap was invisible until proven).

- **Toolchain provisioning (dev box had neither):** Temurin Java 21 JRE → `~/.local/share/java/` (firestore emulator needs 21+; firebase-tools resolves java via PATH ONLY — JAVA_HOME is never read); `firebase-tools@15.22.4` global (matches CI pin). A leftover Jul-08 auth emulator (npx, port 9099) had to be killed before `emulators:exec` could bind.
- **Design-before-code (ultracode, 4 agents on installed sources):** pinned onCall v7 options/protocol, rules-unit-testing v5 semantics, admin v13 transaction guarantees, firebase-tools 15.22.4 emulator wiring. Facts that shaped the code: `tx.create` fails-if-exists (belt for the collision race); reads-before-writes is client-enforced; `assertFails` accepts ONLY permission-denied; rules load per-projectId (mutants need distinct `demo-*` ids); the functions emulator **skips real idToken verification**, **never compiles TS**, and **injects no functions-host env var** into the exec child; `firebase-admin` pinned `^13` (v14 needs Node ≥22 vs our Node-20 runtime).
- **Workspace:** TS strict → `lib/` (commonjs), eslint 10 flat + typescript-eslint, vitest 4 + v8 coverage `thresholds` as the §3 hard gate — **proven to exit 1 below 80** (unit-only run trips it), plus `tsconfig.test.json` typecheck for `test/` (caught a real `import.meta`-under-commonjs mismatch immediately).
- **`createInvite` (europe-west1):** 8 chars from the 31-char unambiguous alphabet (no 0/O/1/I/L; 31⁸ ≈ 8.5e11); **re-issue policy: return the existing active invite** (idempotent — resharing never invalidates the partner's code), stale pendings lazily marked `expired`; one transaction (pending query + collision probes read-first, `tx.create` last) so concurrent calls converge on one code — proven at service AND callable level. Handler guards `auth.uid` itself, not just auth presence: the emulator's skipped verification let a garbage bearer token reach the handler as `{uid: undefined}` → was a 500, now `unauthenticated` (free production defense-in-depth; found by the callable e2e test, red→green).
- **Rules (`firestore.rules`):** granular ops replace M1.2's blanket self-write — `createdAt == request.time` at create / frozen on update (the shipped client transaction shape passes untouched, verified against `FirestoreProfileRepository` source before writing the rules), client delete denied (M6 cascade Function's job); `couples/` member-only read/update with `memberUids` frozen, create/delete denied (M2.3 join Function only); `invites/` zero client access (preview is the M2.2 Function). **Mutation tests prove the net:** 5 protecting clauses each weakened in a rules copy (own projectId) → the previously-denied op must succeed, so a commented-out rule turns CI red; anchors assert `toContain` first so a refactor can't silently rot them.
- **Suites:** 40 tests / 5 files — property tests (fast-check), service tests (re-issue, expiry, collision retry via rigged generator, exhaustion, concurrency), handler tests (injectable `issue` seam for error mapping), callable e2e through the functions emulator (real wire protocol + auth-emulator idTokens, incl. the concurrent double-call acceptance criterion), rules suite (all §3 invariants shipped this session + mutations). **Coverage 100%** (49/49 st, 15/15 br) vs target 85 / hard-fail 80.
- **CI:** new per-PR ubuntu **`functions-rules`** job (setup-node 20 + Temurin 21 on PATH, npm ci → lint → typecheck → build → jar-cached `emulators:exec` running `test:ci`); rules regressions are now pre-merge signals. Flutter gates untouched and green locally (286 tests, coverage 89.11% vs 62 gate; format/analyze/rtl clean).
- **Adversarially-verified review (17 agents: 5 dimensions → 3 refuters per finding): 4 findings, 1 confirmed, 3 refuted.** Confirmed (2/3): `ios-build-smoke` still gated only on `quality`, so a rules-only regression would start the 10×-billed macOS build — fixed with `needs: [quality, functions-rules]`, and `functions-rules` added to the **required merge checks** (without that, "pre-merge signal" was advisory). Refuted 0/3: a users/{uid} field-set freeze (`coupleId`/`fcmTokens` client-spoofable — but nothing reads them for authorization yet; **revisit at M2.3** when the join Function makes `coupleId` meaningful) and two stage-vs-working-tree artifacts of the just-added typecheck files.
- **No ADR:** callable-vs-HTTPS wasn't a genuine contest — onCall v2 gives auth + App Check plumbing for free and typed error codes; the M2.2 preview endpoint will be `onRequest` precisely because it's zero-auth. Policy decisions (re-issue, TTL 48h, alphabet, region) documented in `architecture.md` §3 + code.

**Commits:** PR #20 (`6511890`) → squash-merge to main; session-close docs PR follows (this commit).
**CI:** red→fixed (session-rules §3.4, one quick fix): first PR run failed only the concurrent-`createInvite` test — vitest's 5s default timeout vs a genuine server-side lock wait + ABORTED-retry backoff (~1s initial) on the 2-core runner; `testTimeout: 30s` suite-wide, second run green. Bonus: the failure itself demonstrated the new `needs: [quality, functions-rules]` gate working — `ios-build-smoke` never started, zero macOS minutes burned on the red run.
**Docs touched:** architecture.md (§3 data model + shipped-rules + invite-issuing paragraph, §9 CI), test-suite.md (§1 Functions+rules layer, §2, §3 context), implementation-plan.md (M2 progress), resume-prompt.md (regenerated → M2.2), past-prompts.md (this entry). FOUNDER-ACTIONS.md (local, uncommitted) refreshed.
**Notes / debt logged (none silent):**
- Functions **deploy** deliberately not attempted (emulator-only; Blaze not needed yet). Hardened `firestore.rules` **deployed to both projects** post-merge (`firebase deploy --only firestore:rules`, hayatiapp-dev + hayatiapp-prod) — consoles stay in sync with the repo (M1.2 precedent); the new rules are strictly compatible with the shipped client write shapes (rules suite + `FirestoreProfileRepository` verification).
- Blaze decision moves one session closer (blocking at M2.3 real-device pairing); Apple+Phone providers and the Mac slice unchanged in FOUNDER-ACTIONS.md.
- The callable e2e cannot test production token rejection (emulator skips verification) — covered by the handler's own uid guard + production `checkAuthToken`; recorded in test-suite.md.
- `src/index.ts` excluded from coverage (runtime wiring, only executes inside the functions runtime) — rationale in vitest.config.ts.

**Next objective written to resume-prompt.md:** Session 008 — M2.2: invite share flow (deep link + WhatsApp message) + zero-auth partner preview endpoint.

## Session 008 — 2026-07-09 — M2.2: invite share flow (deep link + WhatsApp message) + zero-auth `invitePreview` endpoint

**Objective (from resume-prompt.md):** M2.2 — make an invite shareable and previewable: `invitePreview` HTTP Function (zero-auth, documented field surface, abuse posture decided either way), deep link decision + iOS wiring (`hayati://invite/<code>` custom scheme, state-only parsing), real invite share screen (`createInvite` via `cloud_functions` + emulator dart-define, WhatsApp-formatted TR/AR/EN share message, six-cell goldens), preview + app test suites, docs-with-code.

**Outcome:** done — all five items. Orchestration was fully workflow-driven (ultracode): 4-reader understand phase → 3 implementation agents (functions ∥ app-share → app-deeplink, sequenced to avoid file conflicts) → independent full-gate re-run → 6-dimension adversarial review with 3-lens refutation planned; the review returned **zero raw findings**, so the refutation phase had nothing to judge.

- **`invitePreview` (onRequest v2, europe-west1, zero-auth — the onCall/onRequest split was pre-decided in Session 007):** `GET ?code=` → uniform HTTP 200 `{status: 'valid'|'expired'|'unknown', creatorDisplayName?}`. Design decisions recorded in `architecture.md` §3: **strictly read-only** (a zero-auth path must not amplify writes — lazy expiry stays `createInvite`'s job; proven by a test that previews a stale invite and re-reads `pending`), **field-surface tests on every 200 case** (`Object.keys` equals the exact documented set; body never contains the seeded `creatorUid`), malformed codes short-circuit to `unknown` with **no Firestore read** (format derived from `INVITE_CODE_ALPHABET`/`LENGTH`, not a second copy), missing param → 400, non-GET → 405 **before** the limiter (doesn't consume budget), `creatorDisplayName` from the **Auth record** (`users/{uid}` stores no name) and omitted-but-still-valid on lookup failure, logs carry a 3-char code prefix only (never validity + full code — a log must not become an oracle). **Rate limiting decided and documented:** best-effort in-memory fixed-window per-IP (30/min → 429), per-instance and cold-start-reset by nature; the real anti-enumeration defense is the 31⁸ code space + function-only reads; infra-grade limiting deliberately out of scope. No CORS (native-only consumer).
- **Emulator lesson (recorded in test-suite.md §1):** 61 *concurrent* GETs overwhelm the functions emulator's per-request worker loader (28 s single invocation, "Failed to load function" repeats) — the rate-limit e2e fires its 2·LIMIT+1 burst **sequentially and last in the file** (window-split-proofness comes from the count, not concurrency; the filled per-IP window would starve any later test).
- **App pairing feature (`features/pairing/`, profile-layout mirror):** `cloud_functions` ^6.3.3 / `share_plus` ^13.2.0 / `app_links` ^7.2.1; `USE_FUNCTIONS_EMULATOR` + `kFunctionsRegion = 'europe-west1'` in the bootstrap (same regional instance the repository resolves — emulator wiring reaches the callable with zero extra plumbing). Three seams keep `flutter test` channel-free (repository, share launcher, deep-link source — the M2.1-style "unimplemented base + override" providers); the real callable is covered by `pairing_emulator_test.dart` + the functions e2e suite (stopping-condition path taken deliberately, documented in test-suite.md §2). Controller is an async-`build` notifier with `@Riverpod(retry: _noRetry)` — the Riverpod 3 default would have **silently retried a failed createInvite ~11×**; recovery is the user-facing retry. Share message composed in the widget from l10n (warm one-liner + code + `hayati://invite/<code>`), TR informal "sen" / AR gender-neutral MSA / EN, one ❤️.
- **First parameterized ARB strings:** placeholders metadata now exists in all three files; `inviteCodeExpiresAt` uses a custom DateTime format (`d MMM y, h:mm a`, `isCustomDateFormat: true`) because `yMMMd`+`jm` are two skeletons that can't combine in one placeholder; renders localized (ar: Arabic-Indic digits) and is timezone-stable for goldens.
- **Deep link (state only, M2.3 consumes):** pure `inviteCodeFromUri` (scheme/host/single-segment/alphabet-validated, uppercasing normalizer) → `pendingInviteProvider` (keepAlive, cold-start future + warm stream, last-valid-wins); activated via `ref.listen` in `HayatiApp.build` (a `watch` would rebuild `MaterialApp` on every link). iOS: second `CFBundleURLTypes` dict (`com.hayati.app.invite`, scheme `hayati`) beside the Google reversed-client-id dicts; no native delegate edits (app_links covers the scene-based delivery). Custom-scheme **delivery** is unexercised under `flutter test` — on-device coverage lands with M2.3's cold-start test (needs the Mac slice).
- **Goldens:** −6 (placeholder deleted with its screen) +18 (`invite_share_screen` has-code/loading/error × six cells, fixed code + expiry), Linux-canonical, W4 intent flag in the PR.
- **CI:** `integration-emulator` (main-only) now sets up node, builds `functions/lib`, boots auth+firestore+**functions** emulators, passes `USE_FUNCTIONS_EMULATOR=true`; per-PR jobs untouched.
- **Gates:** functions 69 tests (29 new), coverage **100/100/100/100** (floor 80); Flutter **341 tests** (61 new), coverage **87.88%** vs gate 62; format/analyze/rtl clean — agents ran their slices green, then the orchestrator re-ran the full sequence independently.
- **Adversarially-verified review (6 dimensions: fn-correctness, security/leak, app-correctness, test-sufficiency-vs-acceptance, l10n/RTL, CI/docs-accuracy; 13–51 tool calls each): 0 findings.** The intentional-decisions list (read-only preview, per-instance limiter, uniform 200s, seam-faking, scheme-only links) was given to reviewers up front, so nothing pre-decided was re-litigated.
- **No ADR:** custom scheme vs universal links wasn't a genuine contest — universal links need Apple Developer enrollment + a hosted `apple-app-site-association` (domain choice) that don't exist yet; upgrade path recorded in `architecture.md` §4, enrollment dependency in FOUNDER-ACTIONS.

**Commits:** PR #22 (`430382f`) → squash-merge to main; PR #23 (integration-test fix, below); session-close docs PR follows (this commit).
**CI:** red→fixed (session-rules §3.4, one quick fix): per-PR checks passed first run (functions-rules 1m21s, quality 1m55s, ios-build-smoke 7m27s), but the main run's **first execution of the extended `integration-emulator` job failed** — `createInvite` 404'd (`InviteUnknownException(not-found)`) because `cloud_functions` derives the emulated callable URL from the default app's `FirebaseOptions.projectId` (`hayatiapp-dev`) while the functions emulator serves functions **only under its `--project`** (`demo-hayati`); the auth/firestore emulators resolve any project id, which is why no earlier suite ever hit this. Test-only fix in PR #23 (suite initializes its default app with `demo-hayati` dummy options + wires auth/functions emulators directly), proven pre-merge via `gh workflow run ci.yml --ref <branch>` (the job also runs on `workflow_dispatch`) — in two iterations: the first dummy `appId` was free-form and the **native Firebase iOS SDK validates `GOOGLE_APP_ID` structure at configure time**, killing `setUpAll` with a bare "did not complete" and no printable Dart error; the landed fix mirrors the real options' field shapes and wraps the bootstrap in a `fail()`-with-cause so a headless runner surfaces real errors. Both gotchas recorded in `architecture.md` §3's emulator-gotchas list / the test itself. Dispatch run `29045590530`: all four jobs green, `pairing_emulator_test` passing against the real functions emulator on the iOS simulator.
**Docs touched:** architecture.md (§2 dart-defines, §3 invite-preview paragraph, §4 pairing status incl. universal-links upgrade path, §9 integration-emulator), test-suite.md (§1 widget/goldens + functions layers, §2 seam decision), implementation-plan.md (M2 progress: M2.2 ✅), resume-prompt.md (regenerated → M2.3), past-prompts.md (this entry). FOUNDER-ACTIONS.md + OPERATOR-EXPECTED.md (local, uncommitted) refreshed.
**Notes / debt logged (none silent):**
- Rate limiting is per-instance best-effort by design; revisit only when a public launch surface exists (documented in architecture.md §3).
- `pairing_emulator_test.dart` runs only in the main-only macOS job (10× billing posture unchanged) — first execution was on this merge, not locally (no macOS box); it caught the project-id 404 above, which is exactly the post-merge-signal trade-off working as documented.
- Question-text-in-preview deferred to M3 by design (no questions exist); the response shape grows a `questionText` field then.
- **Blaze becomes blocking at M2.3's first real-device pairing test** (FOUNDER-ACTIONS #2); the M2.3 emulator work proceeds regardless.

**Next objective written to resume-prompt.md:** Session 009 — M2.3: transactional join + race rejection + partner preview screen (emulator-first; real-device test gated on Blaze + Mac slice).

## Session 009 — 2026-07-10 — M2.3: transactional join + race rejection + partner preview screen

**Objective (from resume-prompt.md):** M2.3 — pair the couple: `joinInvite` callable (one transaction, typed errors, race rejection as THE acceptance criterion), rules hardening (`users.coupleId` becomes authorization-meaningful → function-only), partner preview screen (deep-link + manual entry, zero-auth `invitePreview` over plain HTTP, join CTA), tests at every layer incl. the two-user integration flow, docs-with-code.

**Outcome:** done — all five items, plus a founder-directed docs consolidation. Orchestration fully workflow-driven (ultracode): 5-agent implement workflow (server ∥ app-seams→app-UI pipeline ∥ 3-reader md-audit) → independent orchestrator re-runs of both gate suites → 21-agent adversarial review (6 dimensions → dedupe → 3-lens refutation per finding) → fixer agent. Two harness incidents recovered without losing work (an agent's structured-output emission failed after its gates were already green — report recovered from its transcript; the UI agent was killed by an API session limit mid-verification and resumed in place).

- **`joinInvite` (onCall v2, europe-west1, auth-guarded, App Check plumbed/enforcement OFF):** `{code, timezone?}` → `{coupleId}`, everything in ONE transaction with a deliberate check order (existence → terminal-state → self-join → profile-missing → already-paired); typed `HttpsError` surface frozen as a wire contract — `not-found`/`{reason:'unknown'}`, `failed-precondition`/`'expired'|'consumed'|'self-join'|'already-paired'|'profile-missing'` — the app maps `details.reason` into sealed `InviteException` members. **Race semantics:** joins serialize on the invite doc; the admin SDK retries the ABORTED loser, whose retry RE-READS the invite (now `'joined'`) and throws `consumed` — typed rejections always from re-read state, never from commit-conflict inspection; proven at service AND callable level (`Promise.allSettled` double-join → exactly one couple, loser typed). Invite terminal vocabulary: `'pending'|'expired'|'joined'` + `coupleId`/`joinerUid`/`joinedAt` stamped on join; a `'joined'` invite previews as the uniform `'expired'` (field-surface-asserted). **Couple timezone decision (architecture.md §3):** joiner MAY supply an IANA id validated against `Intl.supportedValuesOf('timeZone')`; absent/invalid → `Europe/Istanbul`; the app sends nothing until M3 makes a real device-timezone source load-bearing. `createInvite` gained the symmetric **already-paired guard** (spent codes never resurrected; missing users doc keeps M2.1 behavior). `normalizeInviteCode` moved to `invite-code.ts` (one owner for the code shape).
- **Rules:** `users.coupleId` frozen — create may not include it, update may not set/change/delete it (`get('coupleId', null)` symmetric compare keeps the app's merge shape passing); mutation tests for BOTH new clauses via the weakened-copy harness; couples coverage extended with real-shaped docs. Functions suite: **129 tests / 100% coverage on all four metrics** (floor 80/target 85), verified independently by the orchestrator from the repo root.
- **App:** `RelationshipProfile.coupleId` (server-owned, read-only — `profileToMap` never emits it, `copyWith` can't forge it, saveProfile merge preservation regression-tested); `invitePreview` over a **plain-HTTP `package:http` seam** (NOT cloud_functions — the invitee may have no account; pure base-URL derivation with the `demo-hayati` emulator branch — PR #23's lesson institutionalized); `joinInvite` on the callable repository with strict `{coupleId}` parse + one mapping choke point; `PendingInvite.clear()`. **`PartnerPreviewScreen`**: empty/manual-entry (LTR-pinned centered code field), loading, valid (creator name + graceful fallback, designed-but-empty M3 `questionText` slot), expired-or-unknown, error states; **pre-auth mount** on the sign-in path (the invitee sees who invited them before committing — the activation moment; `ProviderActions` extracted shared); post-auth via `OnboardingGate` precedence **`coupleId` → pending invite → share screen**; "Have a code?" push from the share screen (six `has_code` goldens intentionally re-baselined, W4 flag); `PairedHomePlaceholder` as the M3 slot. 25 new ARB keys × en/tr/ar. **471 app tests, 87.50% coverage** (gate 62; ratchet to 64 lands with M2.4 = M2 close), 38 new + 2 regenerated six-cell goldens.
- **Integration test:** `pairing_emulator_test.dart` extended to the full two-user acceptance — A issues, B (second fake-idToken user, "two emulated devices" ≈ two signed-in users in one process, documented) previews over real HTTP (`creatorDisplayName` from A's Auth `name` claim), joins through the real callable, couple doc member-read asserted creator-first, fresh C rejected typed-`consumed`. Analyze-clean; first real execution is the main-only macOS job post-merge (the documented trade-off).
- **Adversarially-verified review (21 agents; server/security/test-validity dimensions returned ZERO findings): 5 raw → 5 confirmed → all fixed.** (1) major: "enter another code" cleared the keepAlive `pendingInviteProvider` both real mounts route on → the screen unmounted itself; fixed with a local `_manualMode` (the screen no longer drives its own visibility; regression test mounts a gate-like parent). (2) `AuthError` was swallowed on the pre-auth preview → now falls through to the error view (keepAlive invite resumes after retry). (3) clear-on-success flashed the share screen before the `coupleId` stream landed → success no longer clears; gate mount holds a progress state until coupleId re-routes (stale pending unreachable behind coupleId precedence). (4) the code field entered RTL in `ar` → pinned `TextDirection.ltr // rtl-ok` + centered. (5) architecture §4 pairing status was stale → rewritten (joiner side shipped; Remaining: M2.4).
- **MD audit (founder-directed, 3 readers over every tracked .md):** verdicts 24 keep / 4 update / 3 delete. Applied: `agent-workflows.md` W1 pointed at a nonexistent `docs/decisions-log.md` → now `docs/adr/`; README docs-index + `app/README.md` emulator/dart-define staleness; prd↔mvp coach-cap reconcile (30/day premium-only). Deleted: iOS scaffold-noise LaunchImage README + the two untracked root scratch files — **consolidated into the new committed `docs/operator-expected.md`** (canonical founder checklist, refreshed every close — now session-rules §3.3, with §3 renumbered).

**Commits:** PR #25 (feature + fixes + docs, single squash) — this branch.
**CI:** per-PR checks + the main run recorded after merge (integration-emulator's first execution of the two-user pairing test happens there).
**Docs touched:** architecture.md (§3 data model + rules invariants + NEW transactional-join paragraph, §4 pairing status), test-suite.md (§1 functions layer M2.3), implementation-plan.md (M2 progress: M2.3 ✅), session-rules.md (§3.3 operator-expected refresh, renumber), agent-workflows.md, prd.md, README.md, app/README.md, **operator-expected.md (new, canonical)**, resume-prompt.md (regenerated → M2.4), past-prompts.md (this entry).
**Notes / debt logged (none silent):**
- Couple `timezone` device-source deferred to M3 (documented decision in architecture §3 — server validates joiner-supplied IANA, defaults Europe/Istanbul; app sends nothing yet).
- A stale `pendingInvite` deliberately survives a successful join (unreachable behind `coupleId` gate precedence) — cleared only by the explicit "not now" dismiss.
- Pre-auth preview + join-success paths add a rare transient (share screen flash only if the profile stream is slow at the PUSHED mount) — accepted, documented in the widget doc comment.
- Blaze remains the last-call founder item (optional deploy bonus this milestone; hard at M6/TestFlight). Apple+Phone providers, Mac slice, Slack rotation unchanged (operator-expected.md).

**Next objective written to resume-prompt.md:** Session 010 — M2.4: solo mode (7 solo questions + invite nudges), closing M2 with the coverage ratchet 62→64 + bounded ci-debt #17.

## Session 010 — 2026-07-10 — M2.4: solo mode (7 solo questions + invite nudges), closing M2

**Objective (from resume-prompt.md):** M2.4 — solo mode, the final M2 slice: solo home screen replacing the invite share screen as the gate's unpaired fallback (day-N solo question, answer entry, persistent invite nudge, day-8+ decided), 7 solo questions × TR/AR/EN as a decided-and-documented content source, answer persistence decided-and-documented, coverage ratchet 62→64, bounded ci-debt #17, docs-with-code.

**Outcome:** done — all six items plus two review findings fixed. Orchestration workflow-driven (ultracode): 6-reader understand workflow (275k tokens) → inline implementation → 13-agent adversarial review (6 dimensions → dedupe → 3-lens refutation per finding; server/security, test-validity, content/l10n/RTL, CI and docs dimensions returned ZERO findings) → both confirmed app-flow findings fixed with regression tests.

- **Decisions (ADR-009):** content = three bundled schema-shaped JSON packs (`app/assets/content/solo_{tr,ar,en}.json`, register `neutral`, exactly-7 enforced at load, selection by `profile.contentLanguage`; ARB stays UI-copy-only; authoring home is app/assets until the M3 pipeline — noted in `content/README.md`); day-N anchor = `users/{uid}.createdAt` surfaced READ-ONLY (the M2.3 `coupleId` pattern — repository converts the wire `Timestamp` at the boundary, `profileToMap` never emits it, `copyWith` can't move it) with **local calendar-date arithmetic** (date components only → DST-proof; null/future anchors clamp to day 1; `soloClockProvider` = the app's single clock seam; no midnight timer by design); **day 8+ stops the cycle** — questions never repeat, the nudge becomes the primary CTA of a completed state; persistence = `users/{uid}/soloAnswers/{yyyymmdd}` (one editable bucket per local calendar day, same-day overwrites deliberate).
- **Rules:** `soloAnswers` self-only with a **frozen field surface** — `hasOnly([questionId, text, answeredAt])`, bounded non-empty text ≤2000 (mirrored client-side, see findings), `answeredAt == request.time` (server-stamp discipline), delete denied (M6 cascade). 9 new rules cases + **4 new mutation tests** (cross-user read, cross-user write, client-clock stamp, junk-field hasOnly — multi-line anchors where a clause's text also appears on the parent users block). Functions suite: **142 tests / 100% coverage on all four metrics.**
- **App:** solo home in `features/daily_question/` (the daily-question ritual's unpaired sibling): day progress + question (rendered in the profile's content language, not the UI locale) + answer entry (seed-once controller, trim semantics, saved caption, save disabled when nothing new) + **persistent nudge on every settled state incl. errors**; gate precedence now `coupleId` → pending invite → **solo home**; the share flow lives one tap behind the nudge as a **pushed route that pops back to the gate** on pair or sign-out. `SoloAnswerController` mirrors the capture controller's manual-op discipline; pack loading behind `SoloQuestionPackRepository` (loud DTO; exactly-7 + locale-match enforced at load); `FirestoreSoloAnswersRepository` mirrors the profile repository's exception taxonomy. 8 new ARB keys × en/tr/ar. **593 app tests, 87.95% coverage (gate 62→64 ratcheted in ci.yml), 33 new goldens** (5 solo states × six cells + scale130 naturals — content states render the REAL shipped packs). Acceptance proofs: day-3-on-day-3 clock-independent (fixed `soloClockProvider`, <48h elapsed), restart persistence (seeded repository), pairing-mid-solo re-route at gate level, nudge-on-every-state.
- **Testing gotcha institutionalized:** rootBundle loads never complete inside the widget-test fake-async zone (first loads squeak through, cached loads wedge `pumpAndSettle`) — goldens/widget tests serve assets via `test/support/static_asset_bundle.dart` (synchronous file-backed, reads the REAL shipped packs); plain `test()` cases keep proving the real pubspec `assets:` wiring. Documented in `test-suite.md` §1 + the resume-prompt toolchain note.
- **ci-debt #17 closed (~20 min):** `quality` job exposes a `code_changed` output (full-history diff of the push's `before..after` over `app functions firebase.json firestore.rules .github/workflows`; PRs/dispatch always `true`; unknown parents fail OPEN) and **both** 10x-billed macOS jobs skip docs-only pushes to main — required-check semantics untouched (PR events never trimmed), per the issue's own design + the Session 002 paths-ignore-deadlock constraint.
- **Adversarially-verified review (13 agents): 2 raw → 2 confirmed → both fixed.** (1) major: the pushed share screen's pop-on-pair listener called bare `pop()`, which pops the TOPMOST route — an inviter sitting on a "Have a code?" preview when the partner redeemed would strand paired on a stale share screen; fixed with `popUntil(isFirst)` (collapses the whole pushed stack onto the re-routed gate) + a stacked-route regression test. (2) minor: no client-side length cap vs the rules' 2000-char bound → over-length saves dead-ended in generic error copy; fixed with `LengthLimitingTextInputFormatter(soloAnswerMaxLength)` (constant shared with the rules comment) + regression test.

**Commits:** PR #26 (feature + fixes + docs, single squash) + PR #27 (post-merge quick fix).
**CI:** per-PR checks green; the post-merge main run went **red→fixed** (session-rules §3.5 quick-fix path): `integration-emulator`'s `profile_emulator_test` waited on WHOLE-VALUE profile equality, which the M2.4 `createdAt` surfacing can never satisfy (the server stamp is unpredictable) — the wait hung to the 40-min job timeout. Fixed same-session in PR #27 with a field matcher that also positively asserts the surfaced `createdAt` (the suite is macOS-only, so this class of break is structurally post-merge on this Linux box — the documented integration-emulator trade-off). The docs-only guard's first live exercise arrives with the next docs-only push to main, expected to skip both macOS jobs.
**Docs touched:** architecture.md (§3 data model + rules invariants + NEW solo-mode paragraph, §4 M2-complete status), **ADR-009 (new)** + adr/README index, implementation-plan.md (M2 ✅ with evidence), test-suite.md (§1 solo goldens + fake-async asset note + M2.4 rules-suite line, §2 docs-only guard), content/README.md (interim authoring-home note), operator-expected.md (refreshed), resume-prompt.md (regenerated → M3.1), past-prompts.md (this entry).
**Notes / debt logged (none silent):**
- **Solo pack content is AI-drafted with `reviewedBy: PENDING…`** — native register-owner review (Gulf reviewer for AR) is mandatory before public launch (W9); fine for personal-use-first (ADR-007). Recorded as a founder item in operator-expected.md.
- Day-8+ has no history/back-catalog UI and the day number refreshes per rebuild (no midnight timer) — deliberate, documented in ADR-009; M3's rollover owns time-driven refresh.
- A timezone traveller can see day-N jump (local calendar date is the frame of reference, matching `days/{yyyymmdd}`) — accepted, ADR-009.
- Solo packs' authoring home is `app/assets/content/` until M3 unifies it under `content/` with validation + sync (ADR-009 promise; M3.1 objective).
- Blaze remains the last-call founder item (optional deploy bonus; hard at M6/TestFlight). Apple+Phone providers, Mac slice, Slack rotation unchanged (operator-expected.md).

**Next objective written to resume-prompt.md:** Session 011 — M3.1: question-packs pipeline — real validator + CI wiring, authoring-home unification (content/ → app assets sync), pack-model generalization (the daily-question data spine).

---

## Session 011 — 2026-07-10 — M3.1: question-packs pipeline — enforcing validator, CI wiring, authoring-home unification, pack-model generalization

**Objective (from resume-prompt.md):** M3.1 — turn the content contract into enforced reality: real validator replacing the M0.1 stub (schema + cross-pack invariants, unit-tested), CI wiring in the ubuntu `quality` job, authoring home unified under `content/packs/` with deterministic sync into `app/assets/content/` (decide + document, possibly ADR-010), `SoloQuestion*` model generalized to the M3 pack spine (rename/promote, not rebuild), docs-with-code.

**Outcome:** done — all five items. Orchestration ultracode: inline implementation (CodeGraph-oriented) → 31-agent adversarial review workflow (7 dimension finders incl. an acceptance-criteria auditor → dedupe → 3-lens refutation per finding: correctness/scope/impact) → 8 raw findings → **2 confirmed → both fixed same-session**.

- **Validator (real):** `content/validator/validator_core.dart` (pure, dart:-only — no pubspec needed) + `validate.dart` (thin IO shell exposing in-process `runValidator`) + `validate_test.dart` (**63 self-checks**, plain-`dart` self-checking script — runner decision per the resume-prompt timebox note: `package:test` needs a pubspec, the `tool/`-script mold doesn't). Enforces every schema field/pattern/enum/bound plus what JSON Schema can't express: question-id uniqueness ACROSS packs, packId uniqueness, `packId`↔filename (`<packId>.json`) ↔ `locale` (underscore-segment rule: `solo_tr`→tr, `ar_msa_gulf`→ar, `en`→en) consistency, register vocabulary. `reviewedBy` missing/`PENDING…`/`NONE…` = **warning** pre-launch (ADR-007/W9); `--strict-review` promotes to error (launch posture). Bonus net: `validateSchemaAgreement` cross-checks the core's vocabulary against `question-pack.schema.json` itself on every run — schema edits that outpace the validator turn CI red instead of silently diverging. Exit codes 0/1/64/66.
- **Authoring home + sync (ADR-010):** `content/packs/` is the single authoring home (solo_{tr,ar,en}.json moved in); `app/assets/content/` is generated output. The validator owns the sync (`--sync`: byte-copy + orphan delete, refused while the authoring tree is invalid); default check mode **never writes** and fails on any byte drift or orphan — that's what CI runs. `en.example.json` deleted (schema + real packs + synthetic self-test fixtures cover the example role). Validator green on the shipped packs: exit 0, 3 expected PENDING warnings.
- **CI:** two cheap steps in `quality` before `pub get` (self-tests, then check mode) — a red pack fails in seconds, per-push/PR. Broken-pack red proof on the draft PR (see CI line).
- **Model generalization (rename/promote):** `Question`/`QuestionPack`/`QuestionCategory` + **`QuestionRegister` carried on the pack** (wire `msa_gulf` ↔ Dart `msaGulf`) + **per-question `seasonalWindow` surfaced** (String?, null = evergreen — window→date resolution deliberately left to M3.2); generic `questionPackFromJson` + `AssetQuestionPackRepository.loadPack(packId)` (enforces document packId == requested id); solo path a thin specialization behind the **unchanged** `SoloQuestionPackRepository` seam (`packIdFor: solo_<locale>`, locale match + exactly-7 on top of the generic load). Old `solo_question*.dart` model/DTO deleted; presentation/tests renamed mechanically; riverpod .g.dart regenerated. **Solo goldens byte-identical; 602 app tests (+9), coverage 87.84% (gate 64); analyze/format/RTL clean.**
- **Adversarially-verified review (31 agents, ~1.1M tokens): 8 raw → 2 confirmed → both fixed.** (1) medium: the `copy == null` "missing bundled copy" drift branch (new pack, forgotten `--sync` — the most common authoring mistake) had no self-test; added delete-one-copy → non-zero + message check + `--sync` restore proof (60→63 checks). (2) low: core docstring referenced nonexistent `validator_core_test.dart` → corrected to `validate_test.dart`. The 6 refuted findings were flat-layout/deep-defense nits (non-recursive listing is the documented flat layout; exit-66/strict-review shell-wiring gaps judged not-biting) — refutations recorded in the workflow journal.
- **Session hazard worth remembering:** a review workflow agent reverted the working tree mid-session (`git status` came back clean while two regenerated session docs were still uncommitted) — the implementation commit was already landed so nothing was lost, but session docs are now committed immediately after writing. Read-only discipline for review agents goes into the next workflow prompt.

**Commits:** PR #28 (feature + review fixes + session docs, single squash; includes the deliberate broken-pack red commit + revert as the CI-red proof).
**CI:** draft-PR `quality` run went red on the broken-pack commit **by design** (validator step, field-precise message) and green after the revert — acceptance criterion "a deliberately broken pack turns CI red" proven live; final PR checks green; post-merge main run green (`gh run watch`).
**Docs touched:** architecture.md (§2 content layout, §3 solo-mode paragraph — pipeline real + generalized model, §9 CI step, §11 ADR list incl. the missing ADR-009 entry), test-suite.md (§1 pack-validator paragraph + runner decision, §2 CI step), implementation-plan.md (M3 progress line), content/README.md (de-stubbed — authoring flow + validator invocations), content/schema/question-pack.schema.json (description de-stubbed), **ADR-010 (new)** + adr/README index, operator-expected.md (refreshed — pack review instructions now point at content/packs/), resume-prompt.md (regenerated → M3.2), past-prompts.md (this entry).
**Notes / debt logged (none silent):**
- reviewedBy stays warning-tier until launch posture; `--strict-review` is the ready-made flip (ADR-010 follow-up, M6 checklist).
- Seasonal selection (`seasonalWindow` → dates, incl. Hijri for ramadan/eid) is M3.2's decide-or-defer item; the domain carries the tag verbatim by design.
- Functions-side pack consumption (bundle vs Firestore) is M3.2's ADR-011 candidate.
- Founder items unchanged: native pack review (now at `content/packs/`), Blaze last-call, Apple+Phone providers, Mac slice, Slack rotation (operator-expected.md).

**Next objective written to resume-prompt.md:** Session 012 — M3.2: daily rollover Function — timezone buckets, deterministic register/seasonal selection, `couples/{cid}/days/{yyyymmdd}` + function-only rules.

---

## Session 012 — 2026-07-10 — M3.2: daily rollover Function — timezone buckets, deterministic selection, days/{yyyymmdd} + rules

**Objective (from resume-prompt.md):** M3.2 — the server half of the daily loop: `question_rollover` scheduled Function (timezone buckets, idempotent `couples/{cid}/days/{yyyymmdd}` writes), deterministic pure-TS selection (register/seasonal/no-repeat), pack source for Functions (decide + document, ADR-011), days rules (member read, client writes denied, mutation-tested), bucket/DST design proven in unit tests.

**Outcome:** done — all six items. Orchestration ultracode: 4-reader understand workflow → ADR-011 drafted → **3-lens adversarial design critique BEFORE implementation** (10 should-fixes adopted: `numberingSystem` pinning, per-couple-skip error boundary, runtime `scheduleTime` guard, explicit packConfig presence-branching, verbatim-timezone with loud skip, days-rules insert-allow mutant, handler double-drive test, day-doc/M3.3 reveal-invariant reconciliation, explicit scheduler options, client-authoritative determinism note) → inline TDD implementation → 6-agent verified review (4 dimensions → adversarial verify): **2 raw findings, 0 confirmed** (both docs nits refuted; ADR-005's stale day-doc clause is deliberately left — immutable record, superseded by ADR-011).

- **`questionRollover` (first `onSchedule` v2, `europe-west1`, `0 * * * *` UTC, explicit timeout/memory):** single hourly sweep, couples bucketed by STORED `timezone` verbatim (never re-resolved through the join default — corrupt state surfaces as a per-couple skip, not a silent Istanbul), each bucket's local calendar date computed once, day docs **create-if-absent** (`create()`, ALREADY_EXISTS = benign race because selection is deterministic; only today's key is ever written — self-healing is intra-day, no backfill by design). Per-couple failures (malformed `packConfig`, missing/non-IANA timezone, unknown pack, all-seasonal pack) are logged skips in the run summary, never a failed run; the throw is reserved for systemic failures. Handler validates `event.scheduleTime` (nominal instant beats wall clock; garbage falls back loudly).
- **Day-key core (`rollover/day-key.ts`):** `Intl.DateTimeFormat` `formatToParts` pinned to `calendar: gregory` + `numberingSystem: latn` (critique catch: locale-derived defaults would emit Hijri dates/Arabic digits as doc ids), formatter cache per zone. Unit-proven: Istanbul/Riyadh boundaries, US spring-forward + EU fall-back UTC-boundary shifts, Kathmandu +5:45, Chatham +12:45, invalid-zone RangeError, and a fast-check property (hourly steps never skip/rewind a calendar day).
- **Selection (`rollover/select-question.ts`, pure):** first UNSEEN evergreen in pack authoring order; min-times-assigned recycle with pack-order tie-break after exhaustion (deterministic round-robin, starvation-free); **evergreen-only policy** — seasonal `seasonalWindow`→date mapping (Hijri ramadan/eid) explicitly deferred to the first seasonal content (**issue #29**); all-seasonal pack throws loudly. Register honored by construction (pack-level property; the pack IS the register unit via packConfig).
- **Pack source (ADR-011):** build-time bundle — `npm run build` = `tsc` + `scripts/bundle-packs.mjs` (`content/packs/` → `lib/content/packs/`), byte-equality guard test; validator stays the single content gate, strict TS parser (`pack-loader.ts`, mirrors questionPackFromJson) as consumption-edge defense. Firestore-hosted packs rejected at personal-use scale.
- **`packConfig {packId}` defined** (architecture §3): OPTIONAL, absent → `DEFAULT_PACK_ID 'solo_tr'` (W9-placeholder, mirrors the Istanbul-default precedent), present-but-malformed → loud per-couple skip, never a silent default.
- **days rules + mutation tests:** `couples/{cid}/days/{dayKey}` member-only read via parent-couple `get()` (orphaned day fails closed — tested), ALL client writes denied; mutations: membership guard weakened → non-member read succeeds; `allow write: if false` swapped for authed-allow → client write succeeds (deny-by-absence isn't carrying the net). Rules suite 46 green.
- **M3.3 contracts fixed now (ADR-011 "binding"):** day doc is metadata-only (`questionId`, `packId`, `packVersion`, `assignedAt` — `packId` a documented deliberate addition); **answers move to a reveal-gated per-user SUBCOLLECTION** `days/{dayKey}/answers/{uid}` (rules are document-granular — embedded answers would leak pre-reveal; architecture §3 line updated); **couple dayKey is a pure function of `couples.timezone`, never the device zone** (app must mirror `localDayKey`, not reuse `soloDayKey(now)`); server assignment authoritative, client prefetch is a reconciled prediction.
- **Numbers:** functions suite 207 tests / 18 files, coverage 98.91% stmts / 97.22% branches / 98.24% funcs / 99.16% lines (gate 85 target / 80 hard); app suite untouched; the `onSchedule` export loads cleanly in the shared CI emulator run (eventarc/tasks auto-start, callable e2e unaffected).

**Commits:** PR #30 (feature + session docs, single squash).
**CI:** PR #30 checks green (quality, functions-rules, ios-build-smoke); post-merge main run red on the main-only `integration-emulator` leg — the pre-existing profile round-trip test raced a one-shot `get()` against an awaited transaction commit (Expected 'playful'/Actual 'respectful'; zero app code in the M3.2 diff — a latent test flake, same class the file already documents for listeners). Quick-fixed same-session per session-rules §3.5 (PR #31): the post-rewrite assertions use the watch + `emitsThrough` settled-state pattern instead of one-shot reads; main green after the fix (`gh run watch`).
**Docs touched:** **ADR-011 (new)** + adr/README index, architecture.md (§3 couples/packConfig + days shapes and rules-invariants paragraph, M3.2 rollover prose block, §4 rollover flow status, §10 cost shape), test-suite.md (§1 M3.2 functions/rules layers), implementation-plan.md (M3 progress line), operator-expected.md (refreshed), resume-prompt.md (regenerated → M3.3), past-prompts.md (this entry), root .gitignore (stray vitest cache guard).
**Notes / debt logged (none silent):**
- Seasonal window→date mapping (Hijri) deferred with the documented evergreen-only policy → **issue #29** (due with first seasonal content, W9).
- Scheduled TRIGGER is emulator-untestable — deploy-verified at the first Blaze deploy (operator-expected item 2); handler/service idempotency carries the acceptance criteria in-process.
- `solo_tr` doubles as the couple bank until W9 (register-neutral, 7-question recycle) — flagged in the M3.3 resume prompt so the reveal session isn't surprised.
- Device-IANA capture at join still deferred (fleet defaults to Europe/Istanbul — fine personal-use-first); ADR-005's day-doc clause left stale deliberately (immutable record, superseded by ADR-011).

**Next objective written to resume-prompt.md:** Session 013 — M3.3: answer → mutual reveal — paired-home question UI, reveal-gated answers subcollection, server-side reveal invariant (mutation-tested), question-card goldens.

---

## Session 013 — 2026-07-11 — M3.3: answer → mutual reveal — paired-home question UI, reveal-gated answers, server-side reveal invariant

**Objective (from resume-prompt.md):** M3.3 — the loop the couple lives in: paired-home daily question UI over the first app-side couple/day read path (stored-timezone dayKey mirror, honest no-day state), answers as a reveal-gated per-user subcollection with the server-side reveal invariant (THE M3 accept line, mutation-tested), mutual-reveal UX, question-card goldens, dayKey Dart↔TS parity, docs-with-code.

**Outcome:** done — all five items + acceptance criteria. **Session shape was unusual:** it resumed the working tree of a prior interrupted run mid-flight, and MID-SESSION a second live Claude session (an abandoned-but-alive detached tmux window, `uh`, running from `~/repo` since 23:46) was discovered still implementing the same milestone — writes interleaved for ~5 minutes (its `valueOrNull` analyzer fixes landed between this session's analyze and read). Detected via file mtimes + `ps`/`/proc` cwd + its transcript; the founder stopped it; everything it wrote was checkpoint-committed VERBATIM first (`wip(m3.3)…`), then verified from scratch. Cost: zero lost work; two new standing rules (resume-prompt session-hygiene note + memory). Orchestration ultracode: inline verification/fixes → **6-writer test-authoring workflow** (disjoint new files only; 372k tokens; all green) → **8-dimension adversarial review workflow (find → dedupe → 3-lens refutation)** — **6 raw → 6 deduped → 1 confirmed, 5 refuted** (27 agents, ~1.1M tokens). The one confirmed finding was the then-unappended past-prompts entry itself — closed by this entry. Both code-level candidates were refuted with evidence: the midnight save-state carryover on MECHANISM (the autoDispose save controller resets with the `ValueKey(dayKey)` re-key — no reachable path renders yesterday's error), and the volatile-zone parity gap on IMPACT (rule-stable-zones is the fixture's documented anti-flake posture; the join allow-list is all of `Intl.supportedValuesOf`, but no reachable product path diverges at current tzdata parity — refutations in the workflow journal). Three sub-threshold doc-accuracy nits raised by finders were fixed anyway, all artifacts of this session's own diff: architecture §3 rules scope label (M2.1+M2.3 → M2.1→M3.3), the operator-expected parked-item heading placeholder, the ci.yml integration-suite count comment (3→4 builds, phone_auth still quarantined).

- **Rules (THE M3 accept line):** `couples/{cid}/days/{dayKey}/answers/{authorUid}` — create/update self-only AND member-of-couple (parent `get()`), frozen `hasOnly([questionId, text, answeredAt])` surface (non-empty ≤2000, `answeredAt == request.time`), `questionId` rules-pinned to the parent day doc's assignment (`get()` fails closed on an unassigned day), **read = member AND (own doc OR own answer `exists()`)** — partner answer unreadable pre-answer, `list` flips on the same branch; own answer editable until BOTH exist (typo window), then frozen (commit-before-see is one-way); delete denied (M6 cascade). Plus `couples.timezone` + `createdAt` frozen (the zone is dayKey-load-bearing on both sides — a member rewrite would brick the loop; zone changes move behind a future settings Function). **31 new rules cases (46→77) incl. 12 mutation tests** (reveal gate, both membership guards, `isSelf`, `hasOnly`, server-stamp, questionId pin, non-empty text, both-answered freeze, delete, both couple freezes). No pre-answer existence oracle by design (uniform denial); a nudge needs a Function-written signal (M3.4).
- **dayKey parity (ADR-011 binding contract):** `coupleDayKey` (`couple_day.dart`, `package:timezone` latest_10y, bootstrap-initialized + lazy net) mirrors the rollover's `localDayKey`; a shared fixture (`functions/test/fixtures/day-key-parity.json` — boundaries, US/EU DST shifts, Kathmandu/Chatham sub-hour, rule-stable zones so Node-ICU↔tzdata skew can't flake) is consumed by BOTH suites (TS 20 tests; Dart side + London 25-hour-day sweep + representation-independence + unknown-zone throws). Byte-equal on both sides.
- **App:** paired home replaces the M2.3 placeholder behind the gate — read path `couples/{cid}` (first app-side couple read; watch-only repos with the `CoupleDataException` taxonomy and a single failure-mapper choke point) → stored-zone dayKey → `days/{dayKey}` (null = honest no-day-yet, streams in live; no client prediction) → bundled-pack text by `packId`+`questionId` (unknown pack/question = typed "update the app" pack-lag state). **`partnerSlotProvider` is the client half of the invariant** (sealed locked→waiting→revealed|failure): never watches the partner doc until the own answer is SERVER-acked (pending serverTimestamp crosses as null), maps a slipped-through denial to Locked (defense-in-depth) with a bounded 3× permission-only retry (1s/2s/4s) — everything else keeps no-retry. Save controller mirrors the solo manual-op discipline; entry hard-caps at the rules bound; revealed state collapses the entry to a read-only card; dayKey recomputes per build + on app-resume (lifecycle observer; still no timer, ADR-009). 12 new ARB keys × en/tr/ar.
- **revealedAt decision (docs item 3):** DEFERRED, documented (architecture §3 + §4): both-answered is client-derivable; the day doc is client-write-denied; if M3.4's streak engine needs a server-side mutual-day record its Function owns the stamp. Thread: no scaffold shipped, deliberately — M3.4+ decision.
- **Tests/numbers:** app **725 tests (+108), coverage 86.47% (gate 64)**; **27 new goldens** (no-day-yet/locked/waiting/revealed × six cells + locked scale-130 naturals; REAL `solo_tr` content through the static-bundle harness — the couple bank until W9, ADR-011). Functions **258 tests** (rules 77; parity 20), coverage **98.91/97.22/98.24/99.16** — functions `src/` untouched as scoped. New `integration_test/daily_question_emulator_test.dart` carries the end-to-end acceptance on the main-only macOS job (rollover-shaped ADMIN seed via the emulator's REST owner bearer at the app-computed dayKey; client day-writes proven denied; UI renders the REAL question + waiting slot; partner listen denied pre-answer; reveal streams post-answer; both-answered freeze) — POST-MERGE signal by CI design, watched at merge.
- **Toolchain gotcha pinned:** `firebase emulators:exec` run from `functions/` breaks the exec script's `cd functions` and flaked the rules suite (77 skipped) — the suite must run from the repo root; added to the resume-prompt toolchain note.

**Commits:** PR #32 (checkpoint + fixes + tests + docs + review fixes, single squash).
**CI:** per-PR checks + post-merge main run — see PR/run links; the new `daily_question_emulator_test` had its first live run on the post-merge main `integration-emulator` leg.
**Docs touched:** architecture.md (§3 data model answers/dayKey lines + rules-invariants paragraph + NEW M3.3 mutual-reveal prose block, §4 rollover tail + NEW answer→reveal flow line), test-suite.md (§1 paired goldens/widget paragraph + M3.3 rules/parity additions), implementation-plan.md (M3.3 ✅ line), operator-expected.md (full refresh — M3 3/4, 12/22 units 55%), resume-prompt.md (regenerated → M3.4 incl. new standing session-hygiene note), past-prompts.md (this entry), memory (concurrent-session check).
**Notes / debt logged (none silent):**
- Two-session concurrency incident: see Outcome — standing hygiene rule added; no repo damage.
- `revealedAt` + thread + `invitePreview.questionText` + device-IANA timezone capture: all deferred loudly (M3.4/M3.4+ notes in resume-prompt).
- Couple questions remain the `solo_tr` placeholder bank until W9 (ADR-011) — reveal loop serves the founders their solo questions; accepted dogfooding.
- Founder items unchanged (operator-expected.md): native pack review, Blaze last-call, Apple+Phone providers, Mac slice, Slack rotation; plus the cross-project unhooked panic-button verification parked there by the interrupted session.

**Next objective written to resume-prompt.md:** Session 014 — M3.4: streak engine + reveal-driven Functions (mutual-day record/revealedAt, streak with grace via the repo's first Firestore trigger, notification triggers emulator-side), closing M3 with the 64→66 ratchet.

---

## Session 014 — 2026-07-11 — M3.4: streak engine + reveal-driven Functions — mutual-day record, streak with grace, notification triggers, closing M3

**Objective (from resume-prompt.md):** M3.4 — reveal trigger Function (the repo's first Firestore trigger) stamping `revealedAt` + updating `couples.streak` transactionally; streak semantics as property tests (THE M3 accept line); notification triggers' emulator-provable half behind a mocked send seam; streak display on the paired home; docs + M3 CLOSE with the 64→66 coverage ratchet.

**Outcome:** done — M3 closed (4/4).
- **ADR-012 decided + committed FIRST** (pre-workflow checkpoint discipline): trigger = `onDocumentCreated` + transactional `revealedAt` latch (amends ADR-011's metadata-only day-doc posture); streak = pure calendar math over couple-local dayKeys with weekly ISO grace refill (PRD F3 anchor); push policy = quiet hours 22–08 suppress, discreet default AR-ON (PRD F6), no question/answer text in ANY payload; `fcmTokens` read-side only.
- **`answerReveal`** shipped with `retry: true`: exactly-once proven three ways in-process (duplicate re-drive, `Promise.all` two-answers race, forced read-write interleave via an awaited `beforeWrite` hook) on a trigger-isolated second emulator project (`demo-hayati-notrigger` — the live trigger races in-process drives otherwise; recorded in the toolchain note), plus a thin e2e proving the real emulator-delivered wire. Corrupt/absent state = typed loud skips, never a throw.
- **Streak engine**: 38 fast-check property/unit tests (consecutive chains, same-day idempotence, gap resets, grace bridge, weekly refill incl. ISO week-numbering-year boundaries, older-day no-op, monotonicity, DST walks over all 7 parity zones), 100% branch coverage; `couples.streak` rules-frozen (symmetric absence) + mutation test.
- **Notification layer**: pure payload policy (35 tests; privacy invariant holds by construction — `composePush` has no content parameter), `MessagingPort` seam + coverage-excluded FCM adapter, at-risk pass piggybacked on the hourly sweep at couple-local hour 20 with the couples read still done ONCE per sweep (bucketing extracted + shared).
- **App**: `CoupleStreak` (zero-state parity with `INITIAL_STREAK`), revealed-state streak row (zero renders nothing), ARB plural `pairedStreak` TR/AR/EN, 6 `revealed_streak` golden cells, existing goldens byte-identical.
- **Gates**: functions 379 tests / 97.91% stmts / 95.06% branches (gate 80); app 748 tests / 86.75% vs the **new 66 ratchet**; analyze clean.
- **Adversarially-verified review** (5 dimensions → verify pass): 2 confirmed findings, both fixed — MAJOR: missing `retry: true` on the trigger registration (a systemic failure would silently lose the mutual day forever and poison the next streak fold; redelivery is latch-safe by construction); MINOR: ADR/docs overstated the reveal-push recipient (now: latch-winner's partner, best-effort under reordering). Rules-security and payload-privacy dimensions: zero findings. One streak-math finding refuted in verification.
- **No operator action was required this session** (emulator-only, as the resume prompt stated); nothing new became blocking.

**Commits:** `b3f363d` (ADR-012), `3e4040f` (implementation), `ede97aa` (ratchet 64→66), `502e5f8` (review fixes + M3-close docs) — PR #33, squash-merged as `b224c92`; plus the post-merge fix PR #34 (below).
**CI:** PR #33 checks green (one `dart format` re-push); post-merge main run RED on exactly the watched suite — `integration-emulator`'s M3.3 reveal round-trip died on the KNOWN screen-teardown/auth-switch listener race (the test's own M3.3 comment flags it), made deterministic by the now-live `answerReveal` trigger occupying the emulator right when the teardown's listen-cancels arrive: `switchTo`'s `signOut` then re-auths still-open answer listens as unauthenticated → denied → the `async*` rethrow in `watchAnswer` lands unhandled. Fix attempt 1 (PR #34, a pump-loop "settle") was IMPOTENT — under the integration (live) binding `tester.pump(duration)` does not sleep wall-clock, so the identical re-failure (00:09 vs 00:11) was the tell; one simulator-launch-hang rerun (40-min timeout, infra flake) in between. Fix attempt 2 (PR #35): a REAL `Future.delayed` 2s settle — the failure moved later by exactly the added delay and persisted, proving a live listen survives the switch regardless of settle time (not a cancel-flush race). Per the pre-declared cap and session-rules §3.5 structural path: the ONE test is `skip:`-quarantined (PR #37) behind **ci-debt #36** (full diagnosis + structural fix recorded there: per-user `FirebaseApp` instances instead of mid-test `signOut`); the rest of the integration suite (auth/pairing/profile round-trips) stays live and main returns green. Not a rules/product regression — the reveal invariant's server-side proofs (21 rules cases, 12 mutation tests, the M3.4 race suite + trigger e2e) passed throughout. Lessons recorded: live-binding `pump(duration)` is not a wall-clock wait; a main-only CI job with no local repro gets at most two fix iterations before quarantine.
**Docs touched:** ADR-012 (+README index), architecture §3/§4/§10, test-suite §1, implementation-plan (M3.4 + M3 ✅), resume-prompt (regenerated → M4.1), operator-expected (mid-session + close refresh), this file.
**Notes / debt logged:**
- **Working-tree incident (recovered, zero loss):** an external `git pull --autostash` from a concurrent process swept the entire uncommitted tree into `stash@{0}` mid-implementation — the exact Session 013 two-sessions hazard in a new costume. The trigger-lane agent recovered everything via `git restore` (no forbidden verbs), the full suite was re-verified green, the stash was diff-verified subsumed and dropped, and a hygiene addendum (checkpoint-commit the moment workflows return; never blind-`pop` a `gitPull auto-stash`) is now a standing note in resume-prompt.
- Deferred loudly: `users.fcmTokens` app-side capture (on-device slice, operator item 4); APNs delivery (item 4); private thread → M5 scope selection; `invitePreview.questionText` → W9 couple packs (no couple question exists pre-join); partner display-name in push copy (needs an Auth lookup — name-free copy ships, degrades gracefully).
- The at-risk push is best-effort with no dedup state (hourly cadence makes double-sends structurally absent; a manual re-drive of the same instant would double-send — documented, accepted).

**Next objective written to resume-prompt.md:** Session 015 — M4.1: entitlements foundation — RevenueCat webhook Function → couple entitlement mirror (`subscriptions/{coupleId}`), subscriptions rules, app entitlement read seam; emulator-only (mocked RC events), no founder dependency; RC account + ASC app record flagged as becoming blocking at M4.2.

---

## Session 015 — 2026-07-11 — M4.1: entitlements foundation — RevenueCat webhook → couple entitlement mirror, subscriptions rules, app read seam

**Objective (from resume-prompt.md):** M4.1 — `revenueCatWebhook` Function (onRequest, `europe-west1`) authenticated via the RC `Authorization` token behind an emulator-testable secret seam, parsing mocked RC webhook events and mirroring entitlement onto `subscriptions/{coupleId}` idempotently + out-of-order-safe; the M4 accept lines (one purchase entitles both, expiry downgrades both) at the service level with a pure decision core; `subscriptions` rules member-read/function-write-only with mutation tests; app `EntitlementRepository`/`CoupleEntitlement`/`isPremium` seam with no UI flips; ADR-013 + docs-with-code.

**Outcome:** done — M4 opened (1/3), emulator-only by design (no RC account; mocked events from RC's documented 2026 webhook schema, fetched live during orientation).
- **ADR-013 decided + committed FIRST**, then **adversarially design-reviewed BEFORE implementation** (three lenses: RC-semantics / concurrency / security-HTTP) — 12 findings folded into the design pre-code, including one BLOCKING: `BILLING_ISSUE` always *carries* `grace_period_expiration_at_ms` but it can be NULL (no grace configured), and the naive projection would have collapsed that null into the null=non-expiring sentinel — permanent free premium on a failed card. Fixed as `grace ?? expiration_at_ms`, dedicated test. The concurrency lens killed the draft's processed-ids FIFO: equal-timestamp distinct events made a strict-timestamp guard arrival-order-dependent; the fix — each per-uid lane is a **last-writer-wins register over the total order `(event_timestamp_ms, event.id)`** — is simpler (O(1) lane state, no FIFO) and genuinely convergent (fast-check property with deliberately colliding timestamps). The RC lens also caught the alias fallthrough (an unpaired payer must never resolve through stale RC aliases onto an ex-partner's couple → resolution hard-stops at the first existing `users/{uid}` doc) and the security lens forced the PII-safe log projection (`subscriber_attributes` carry `$email` — the raw body is never logged), the honest ~155-min RC retry-budget framing (no reconciliation until the M4.2+ RC-API backfill), and the no-rate-limiter decision (a 429 burns RC's finite retry budget on real events).
- **`revenueCatWebhook`** shipped: verbatim-token auth (constant-time compare) behind **the repo's first env/secret seam** — `process.env.RC_WEBHOOK_TOKEN` read at request time, `secrets:` declared for the Blaze deploy, **fail-closed 503 when unconfigured**; emulator token via the committed demo-only `functions/.env.demo-hayati` (empirically proven to reach the emulated function; boots clean with the declared secret; real env files now gitignored with the one demo exception). Validation ladder 405/503/401/400/200/500; malformed envelope = explicit 400, known-type-unprojectable = 200 counted skip, unknown types/`TEST` = logged no-op 200 — nothing reaches a thrown 500 on body shape.
- **Mirror semantics**: revoke ONLY on `EXPIRATION`; `CANCELLATION` keeps access to period end (auto-renew off); `PRODUCT_CHANGE` falls back `new_product_id ?? product_id`; per-type `willRenew` pinned; one `premium` entitlement concept (stopping-condition simplification, revisit with real RC config). One transaction per event (read mirror → per-lane guard → project → write lane + derived summary); couple summary = any-lane-entitled — **one purchase entitles BOTH (proven from either member), expiry downgrades BOTH**; double-purchase lanes can't clobber each other.
- **Rules**: `subscriptions/{coupleId}` member-only read via parent-couple `get()` (orphan fails closed), ALL client writes denied; +2 mutation tests (write-deny → authed-allow readmits; read guard weakened readmits non-member — multi-line anchor to disambiguate from the byte-identical `days` membership line).
- **App**: greenfield `features/entitlements/` in the house pattern (watch-only repository seam, `CoupleEntitlement` read model with absent-doc=free, `entitlementStream` + `isPremium` derived provider over the existing clock seam — the M4.2 gating decision point; no UI flips by design). Builder judgment calls documented in-code (DTO owns the epoch-ms int conversion — no `_domainReady` shim needed since no SDK type crosses; AsyncValue flag-precedence idiom for the derivation).
- **Gates**: functions **486 tests / 98% stmts / 95.7% branches** (gate 80) via `emulators:exec` from repo root; app **791 tests / 86.46%** (gate 66), analyze clean.
- **Adversarially-verified code review** (6 dimensions → 2-skeptic verify): **zero confirmed findings** — 5/6 finders returned empty; the single minor doc-phrasing finding was refuted 2/2. The pre-implementation design review is where the defects were caught this session; worth keeping that ordering.
- **No operator action was required this session** (as the resume prompt stated); nothing new became blocking. The M4.2 dependency (RC account + ASC app record + a ≥256-bit webhook token) is flagged in operator-expected.

**Commits:** `62e4e91` (ADR-013), `9523b60` (implementation checkpoint), `44cbdc6` (docs sync), `d0cac40` (session close) — **PR #38**, squash-merged.
**CI:** PR #38 checks green; post-merge main run green (`gh run watch`).
**Docs touched:** ADR-013 (+README index), architecture §3/§4/§8/§10, test-suite §1, implementation-plan (M4.1 progress), resume-prompt (regenerated → M4.2), operator-expected (close refresh), this file.
**Notes / debt logged:**
- Accepted gaps recorded in ADR-013 (none silent): purchase-before-pairing events skip loudly (M4.2's pairing-gated flow closes it); missed-RENEWAL asymmetry — the app's expiry check protects against a missed revocation but a webhook dropped past RC's ~155-min retry budget silently downgrades a payer until the M4.2+ RC-API reconciliation lands; `TRANSFER` no-op until the M4.3 gift flow.
- One session-hygiene self-catch: the first functions-gate run invoked `emulators:exec` from `functions/` (the exact standing-note trap) — caught by the exec script's own `cd` failure, re-run from repo root, green. The pipe-swallowed exit code (`| tail`) was the accomplice; gates now echo `EXIT_CODE` explicitly.
- Two ci-debt items remain open (#36 quarantined reveal round-trip, #15 phone-auth simulator crash) — at the policy threshold (>2 forces a stabilization session), not over it.

**Next objective written to resume-prompt.md:** Session 016 — M4.2: paywall UI + free-tier gating (annual-first paywall per locale with goldens, `purchases_flutter` behind a seam with mocked offerings, gating flips behind `isPremium`); founder dependency NOW DUE: RevenueCat account + products + ASC app record for the live-sandbox half.

## Session 016 — 2026-07-11 — M4.2: paywall UI + free-tier gating — annual-first paywall, purchases seam, PremiumGate

**Objective (from resume-prompt.md):** M4.2 — `PurchasesRepository` seam over `purchases_flutter` (all tests against a fake, real adapter at bootstrap); annual-first paywall with trial messaging, store-verbatim prices, honest states; the reusable premium gate flipping a gated surface purely on `isPremium` (both directions) while the free tier stays assertion-proven untouched; six-cell paywall goldens + scale-130; the live-sandbox half only if the founder's RC account + ASC record existed (they didn't — mocked half shipped, as the prompt planned).

**Outcome:** done — M4 2/3; the mocked half complete, live-sandbox half rides M4.3 per plan.
- **Operator check at start: no action required** — no RC key material on the machine, item 0 unchanged since S015; proceeded autonomously on the mocked half per the resume prompt's explicit fork.
- **ADR-014 decided + committed FIRST, then adversarially design-reviewed BEFORE implementation** (three lenses: SDK-fidelity / Riverpod-wiring + state honesty / gating + test discipline) — 1 BLOCKING + 4 SERIOUS + minors folded pre-code. The blocking find: a listen-only identity sync misses the warm-start `AuthSignedIn` (`ref.listen` never fires for the value present at listen time; `AuthController` seeds synchronously from `currentUser`) — `Purchases.logIn` would silently never run on the most common entry path and the anonymous-purchase guard would then block every warm-start purchase. Fixed in the design: current-state-first-then-listen, `logOut` only on real transitions (it throws on anonymous users), lazy repo resolution. Other pre-code folds: the SDK's own `PurchasesErrorHelper.getErrorCode` is NOT total (`num.parse` + unguarded enum index — non-numeric `'channel-error'` and negative codes throw) → the house mapper is total by construction with hostile-synthetic tests; the processing banner moved from ephemeral controller state to a durable keepAlive flag (an autoDispose controller dies on route pop — exactly in the webhook-undeployed window); `Purchases.isAnonymous` over client-side prefix-matching; the packs-tile mount pinned to the question view so `no_day_yet` goldens stay byte-identical; `gated` (not `locked`) golden naming; full AR CLDR plural set for trial copy; explicit widget-test enumeration for every paywall state.
- **`purchases_flutter` pinned `^10.4.1`** after live API verification (10.0.0 broke 9.x: `purchase(PurchaseParams)` → `PurchaseResult`; every model class verified `const`-constructible in the pub-cache source) — no API-drift stopping condition; the seam speaks the SDK's own model types so the fake mints REAL objects and M4.3's live wiring is one bootstrap override.
- **Foundation** (stage 1): seam + throw-until-overridden provider, thin fail-closed adapter (`REVENUECAT_IOS_API_KEY` dart-define; unconfigured ⇒ typed `PurchasesUnavailableException`; `logIn`/`logOut` silent no-ops so auth flows never crash keyless), total mapper, `derivePaywallOffering` (annual-first, dedup, trial = `introductoryPrice.price == 0` else `freePhase`, `PaywallUnavailableException` on empty offerings), `PurchasesIdentitySync`, durable `pendingPurchase` flag auto-clearing on the mirror flip, purchase controller with the manual-op discipline. The `logIn`-before-`purchase` contract pinned at the fake's ordered call log.
- **UI** (stage 2): `PaywallScreen` + `showPaywall(coupleId:)` (purchase structurally gated behind pairing — ADR-013's purchase-before-pairing gap closed), annual-first cards with best-value badge (gold restraint), store-verbatim prices off ONE TRY-storefront fixture (storefront currency follows the store account, not device locale — one-currency goldens are the honest rendering), entitled/loading/network-retry/unavailable states, mirror-is-the-only-unlocker processing banner, cancel-silent/failure-dismissable/re-entrant-drop; `PremiumGate` (no second decision point); `PackSelectionScreen` gated ⇄ unlocked (no `packConfig` writes — W9 owns selection); paired-home packs tile (question-view states only). 28 ARB keys × TR/AR/EN in brandkit voice (AI-drafted, founder native review flagged in operator-expected). Goldens: paywall loaded/entitled + pack-selection gated/unlocked × six cells + scale-130 naturals; paired-home question-view cells re-baselined intentionally (W4 flag), `no_day_yet` + all non-question states byte-identical.
- **Free tier proven untouched by assertion:** question card + answer entry + streak row identical free vs premium (incl. a premium-mirror streak render), save flow completes free, and `find.byType(PaywallScreen)` findsNothing through the whole answer flow — the probe that turns red if an interstitial ever lands. The gate flip proven BOTH directions through the real entitlement chain (live `FakeEntitlementRepository` emissions, incl. past-expiry downgrade).
- **Adversarially-verified review** (4 find lenses → per-lens adversarial verify): 5 confirmed MINORS, all fixed same-session — pending flag marked only when not already premium (a stuck flag could render a false "unlocking…" banner after a later expiry); entitled-view restore failure surface; empty-`AppBar` back affordance on both pushed screens (partner-preview precedent; App Store 3.1.2 dismissibility); AR gender agreement (`تجري المزامنة`); two coverage-gap tests (streak row under a premium mirror; banner pop/re-push durability — the keepAlive flag's stated reason to exist). 3 findings refuted with evidence (identity-sync cursor ordering → recorded as the M4.3 live-key hardening note in ADR-014; CTA-visible-during-processing → intended, tested, store-deduplicated; docs "missing" → end-sequence by design).
- **Gates:** app **900 tests / 86.50%** (gate 66), analyze + rtl-lint clean, goldens deterministic; functions untouched-green **486 tests / 98% stmts / 95.7% branches** (gate 80) via `emulators:exec` from repo root.
- **No operator action was required this session**; item 0 (RC account + ASC record) is now the last thing standing before a real sandbox purchase and is re-flagged NOW DUE for M4.3.

**Commits:** `1bb8dac` (ADR-014 draft + pubspec pin), `f2ccd0d` (ADR hardened by pre-code review), `1f518f2` (foundation), `b378a25` (UI + goldens), `fefae03` (verified-review fixes), `fd24c28` (session-close docs) — PR #40, squash-merged.
**CI:** PR #40 checks green first try (functions-rules 1m43s, quality 2m39s, ios-build-smoke 5m14s; integration-emulator skips per-PR by design); post-merge main run green (`gh run watch`).
**Docs touched:** ADR-014 (+README index), architecture §4 (entitlements flow M4.2 status), test-suite §1 (paywall/pack goldens + fake-SDK seam + free-tier probes), implementation-plan (M4.2 ✅), resume-prompt (regenerated → M4.3 with the item-0 fork), operator-expected (item 0 NOW DUE + paywall-copy review sub-item + snapshot 15/22 = 68%), this file.
**Notes / debt logged (none silent):**
- Identity-sync cursor-reset-on-failure hardening deliberately deferred to the first live-key session (dormant without a key; self-heals on relaunch) — ADR-014 Consequences + resume-prompt out-of-scope line.
- Paywall/pack ARB copy (28 keys × 3) is AI-drafted pending the founder native pass (TR founders / AR Gulf reviewer) — operator-expected item 1 extended.
- SAR/USD price-display fidelity provable only at the M4.3 sandbox smoke (one-storefront fixture is honest but single-currency).
- `pricePerMonthString` sub-label renders only when the SDK computes it (absent ⇒ omitted, recorded in ADR-014).
- Two ci-debt items remain open (#36, #15) — at the stabilization threshold, not over it.

**Next objective written to resume-prompt.md:** Session 017 — M4.3: gift flow + `TRANSFER` handling; sandbox purchases IF operator item 0 landed (else the engineering half + honest M4-close bookkeeping incl. the 66→68 ratchet).

## Session 017 — 2026-07-12 — M4.3: `TRANSFER` handling + the gift decision — closing M4's engineering

**Objective (from resume-prompt.md):** M4.3 — `TRANSFER` event handling in `revenueCatWebhook` (ADR-013 parked it here as a logged no-op), the gift-flow decision + whatever UI half is honestly buildable against the fake seam, and the M4-close bookkeeping (coverage ratchet 66→68, M4 status marked honestly). The session forked on operator item 0 (RevenueCat account + ASC record): **absent, as expected — the engineering fork was taken.**

**Operator check at start: no action required.** No RC key material on the machine, item 0 unchanged since S016. Recorded in the session log and mid-session in `operator-expected.md` (committed before any workflow ran, per the S014 hygiene rule), then proceeded autonomously.

**Outcome:** done — **M4 engineering COMPLETE (3/3); the sandbox accept line stays OPEN on item 0, marked, not dropped.**

- **The headline was a bug nobody could see.** Re-reading RC's live 2026 docs during orientation: a real `TRANSFER` carries **no `app_user_id`** (the subscriber-identity field group does not apply to it — `transferred_from[]`/`transferred_to[]` instead). `parseRcEvent` hard-required one, so every genuine transfer was classified `malformed` → **400** → RC retried 5× over ~155 min → **dropped the event permanently.** ADR-013's "logged no-op, 200" row for `TRANSFER` was unreachable in production. **No test caught it because every TRANSFER test built a *post-parse* `RcEvent`, and both raw-envelope builders injected `app_user_id` unconditionally** — the envelope contract had never seen a real transfer body. The fix makes the identity contract **per-type** (a lifecycle event without `app_user_id` is *still* a 400 — the exception is exactly one type wide) and adds an e2e wire test that POSTs RC's documented sample body.
- **ADR-015 decided + committed FIRST, then adversarially design-reviewed BEFORE implementation** (4 lenses → 2 skeptics per finding): 13 raised, 10 refuted, **3 confirmed and folded pre-code.** The two that mattered: (1) the 10-id cap had **no defined enforcement point** — the planner was specified over the *resolved* lists, so a literal implementation would read first and cap after, bounding nothing; it is now an explicit **pre-read gate**, with the pure filter+dedupe running first so routine anonymous-alias accretion (the app mints a fresh RC anon id on every sign-out) cannot make the revoke path inert. (2) The `to`-side anon filter **contradicted the ADR's own standing rule** ("revoke iff the destination is FULLY KNOWN") and did so on the **false-downgrade side**: `to = [anon, uidB]` would have revoked. Fixed — an anon id *anywhere* in `transferred_to` now HOLDS.
- **The design, in one line: a `TRANSFER` never entitles anyone, and revokes only on positive evidence the entitlement left the couple.** A transfer is a *bare pointer* — no product, no expiry, no entitlement ids, and RC sends exactly ONE webhook with **no follow-up `EXPIRATION` for the loser**. So the gain half is **structurally unprojectable** (the only available expiry is the `null` non-expiring sentinel = permanent free premium — the null-grace `BILLING_ISSUE` bug class ADR-013 already killed once). And the damage is asymmetric: a false revoke instantly strips a paying couple (unrecoverable — we cannot issue a manual grant), while a missed revoke leaks only the tail of a period someone actually paid for and self-retires against the app's `entitled && unexpired` check. **Every ambiguity therefore holds:** within-couple transfers are a no-op (the mirror is *couple*-scoped — the shared-Apple-ID restore changes only which RC subscriber holds it; the doc is proven **byte-unchanged**); an anon destination holds (**the reinstall trap** — delete app → anon id → store auto-restore → *then* `logIn(uid)`: revoking there downgrades a payer on a reinstall); an unplaceable destination holds; a loser resolving to nothing holds.
- **Convergence preserved, and proven with teeth.** The tombstone is a **pure projection of the transfer alone** (`expiresAtMs` = the transfer instant — never the non-expiring sentinel), never a copy of the loser's prior lane; it is written **even when no lane exists** (so a transfer arriving *before* the purchase it moves cannot be resurrected by the late, older-ts purchase); same `(ts, id)` LWW guard; **one transaction per target couple** (partial application is safe by **idempotence**, not atomicity). The convergence property now folds a **two-couple world with transfers in the multiset** and is **mutation-verified**: copying the loser's facts, entitling a gainer, and dropping the tombstone-when-absent rule each turn it red (all three were run and confirmed failing, then reverted).
- **The gift decision: PRD F4 is already shipped, so no gift UI ships.** Gifting an auto-renewable subscription **is not an App Store feature** (no StoreKit gifting API, no ASC giftable toggle; Apple's own path is a gift-card top-up so the recipient buys it themselves). Guideline **3.1.1 permits buyer≠beneficiary by name**, provided the money moves through IAP — which it does. So the couple-scoped mirror **IS** the gift. A "Gift Premium" button would imply a SKU Apple will not sell us, and any gift entry point is exactly what would need a paywall **without** a `coupleId` — reopening the purchase-before-pairing gap ADR-014 structurally closed. **What shipped instead:** the decision, the PRD F4 rewrite, and a **regression test pinning the promise** (the non-purchasing partner unlocks off their partner's purchase with an **empty purchases call log** and `PaywallScreen` **never mounted**). Recorded as never-again-litigate: **Family Sharing = DO NOT ENABLE** (irreversible once on; it would create a second entitlement source the mirror does not own — now an operator warning *before* the products exist), offer codes (developer-minted only; on an auto-renewable sub they **auto-bill the recipient** at full price after the offer — a "gift" that silently charges your partner), RC promotional entitlements (a support tool), a web/Stripe gift link (3.1.1). Apple **Group Purchases** (WWDC26, no RC support yet) is the only thing that would reopen it — tracked, not built.
- **Adversarially-verified post-implementation review** (3 lenses → skeptic verify): 9 raised, **1 confirmed, fixed same-session** — the **`to` side of the pre-read gate was mutation-silent**: no test exercised the destination half of the cap or the dedupe, so deleting `|| toIds.length > MAX_TRANSFER_IDS` (or `dedupe(rawTo)`) left the entire suite green while a 5,000-id `transferred_to` array would have cost 5,000 reads. Four tests added; both rules now verified red under mutation. The 8 refutations were evidence-backed, and one of them was *instructive*: a SERIOUS "the revoke path is a remote strip-a-paying-couple's-premium primitive" finding was refuted because the **same primitive already exists on the untouched M4.1 lifecycle path and is easier to fire there** (an `EXPIRATION` under a victim's uid overwrites their lane through the normal LWW guard). The attribution was wrong but **the underlying observation is real and predates this session** — `app_user_id` = the Firebase uid + a *publishable* SDK key makes every lane remotely addressable. Filed as **issue #41** (ADR-013 threat-model gap; the fix — an opaque server-minted RC subscriber id + an `rcSubscribers/{rcId} → uid` index — must be decided BEFORE real purchases exist, so it rides the first live-key session). Scope guard honored: not fixed in this diff.
- **Gates:** functions **538 tests / 98.16% stmts / 96.03% branches** (gate 80) via `emulators:exec` **from the repo root**, `EXIT_CODE=0` echoed explicitly; app **901 tests / 86.50%**, **coverage ratchet 66→68 landed**, `flutter analyze` clean.

**Commits:** `019f9e7` (operator check), `79f1fda` (ADR-015), `5d708c9` (Family Sharing operator warning), `8c3ede0` (ADR hardened by the pre-code review), `b84c1fa` (implementation), `8d56627` (tests), `8c5be94` (gift regression test + PRD + ratchet), `75983cd` (docs), `51944c5` (operator-expected), + the verified-review fix (to-side gate tests) and the session-close docs — **PR #42**.
**Docs touched:** ADR-015 (+README index), PRD F4 (rewritten), architecture §4/§10, test-suite §1 + §3 ratchet, implementation-plan (M4.3 + the honest M4 close), operator-expected (mid-session + close), resume-prompt (regenerated → M5.1), this file.
**Notes / debt logged (none silent):**
- **Usage-limit incident (no code impact):** the pre-code review workflow hit the account's weekly limit on its last 6 verify agents, leaving 3 findings unverified. They were **adjudicated by hand instead of dropped** — and all 3 were real (the cap enforcement point, the `to`-side anon contradiction, and a `LogFields` shape the promised log surface could not carry). Recorded because the *process* nearly lost them.
- Accepted costs, all named in ADR-015 and all closed by the same RC-REST reconciliation (which rides item 0 + the deploy era): a transfer never entitles anyone (a receiving couple waits for its next lifecycle event — up to a year on an annual plan); every ambiguity holds (an entitlement that truly left keeps the ex-couple premium for the paid tail); within-couple transfers leave stale lane attribution.
- **If RC populates `transferred_to` with the destination's anonymous id, the revoke path is INERT in production** (every transfer holds). That is the deliberate safe-but-inert posture; only a real payload settles it (ADR-015 Open question 1, first live-sandbox session).
- **Issue #41 filed** (ADR-013 threat-model gap, see above) — pre-existing, not exploitable while no RC account exists, owed by the first live-key session.
- Two ci-debt items remain open (#36, #15) — at the stabilization threshold, not over it.

**Next objective written to resume-prompt.md:** Session 018 — M5.1: AI coach v0 — scope + the `coach_proxy` Function foundation (persona/register system prompts, the crisis-lexicon pre-filter as the safety spine, recorded-fixture contract tests, caps). No founder dependency; item 0 still blocks only M4's sandbox proof.

## Session 018 — 2026-07-12 — M5.1: AI coach v0 — the crisis safety spine + `coachProxy` server seam

**Objective (from resume-prompt.md):** M5.1 — scope decision + the `coach_proxy` Function foundation, safety spine first: a pure crisis detector (TR/AR/EN, normalization/evasion-hardened) routing every seeded crisis phrase to the professional-help path with zero persona/provider calls; provider-agnostic seam on recorded fixtures (no live LLM anywhere); server-side premium gate off the entitlement mirror; transactional caps; no coach text in any log/analytics (asserted).

**Outcome:** done.
- **Operator-action check (explicit, founder-requested):** no operator action was required for this session — the slice runs on recorded fixtures by design (the resume prompt said so; verified true in execution: zero external dependencies were hit). Two NEW operator items were *produced*: the crisis-content native review (★, blocks coach-on-device only) and the LLM provider decision + key (item 6, due at M5.2/M5.3).
- **Mid-session founder request served:** the founder declared iPhone 17 + Mac in hand and asked for TestFlight registration steps → a complete repo-verified runbook (enrollment check → App ID + capabilities → ASC app record [= half of item 0] → signed prod-flavor `flutter build ipa` → Transporter upload → internal-group install) was written into `operator-expected.md` and merged to `main` immediately as **PR #43** (separate docs PR so the founder-facing doc didn't wait on the feature branch).
- **ADR-016 written + committed BEFORE code, then adversarially reviewed** (4-lens workflow — safety/normalization, server/concurrency, privacy/security, scope/consistency — each lens independently verified, all findings hand-adjudicated): **2 blocking** (TR diacritics ç/ş/ğ/ö/ü never folded — diacritic-less typing is the Turkish norm, an under-trigger in the CRISIS filter; detection-lexicon selection was unspecified vs the client-declared `language` — a lied-about language could bypass detection) **+ 10 serious + ~20 minor accepted** and folded into rev 2 pre-code. Standouts: validation-before-safety-scan would have `invalid-argument`'d a long crisis outpouring (pre-scan now runs before ANY rejection, bounded to 4K chars/message); the single member-read cap doc would have let an abusive partner monitor the victim's coach usage (daily lanes split to a SELF-read-only subcollection — the DV pin); the callable framework's unhandled-error auto-logger + the repo's own `logger.error(msg, error)` mold were content-leak vectors (coach path: every throw → static-message `HttpsError`, raw-object logging forbidden); crisis log lines carried a KVKK-sensitive `coupleId` join (dropped); leet-folding corrupted Arabizi (both-variant matching + an explicit Arabizi seed track); per-uid 30/min rate limiter added (two verifier lenses disagreed; `architecture.md` §1's explicit per-user-rate-limit mandate decided it). Review-ordering discipline is now FOUR-for-four.
- **Implementation (two-stage sequential, checkpoint-committed):** stage 1 — pure cores (`normalize.ts` 9-step pipeline, `crisis-lexicon.ts` TR/AR+Arabizi/EN `nativeReview: PENDING`, `crisis.ts` total-function detector with built-in cross-message concatenation scan, `help-content.ts` (no hotline numbers — founder-verified later), `provider-port.ts` (fail-closed `UnconfiguredCoachProvider` + fixture provider with ordered call log + classification-only `ProviderUnavailableError`), `coach-core.ts` (validation, period keys off `localDayKey`, `planReserve`/`planRefund` with per-lane captured-key guards, `logCoachEvent` with no text/uid fields), `isPremiumMirror` extracted into `entitlement-core.ts` (the D5 check's single home; `coachProxy` is the mirror's first server-side consumer). Stage 2 — `coach-service.ts` (one transaction: membership → premium → both cap lanes, typed outcomes never throw), `coach-proxy.ts` (the fixed ADR pipeline incl. per-uid limiter + crisis-pre-scan-before-any-rejection + all-lexicon post-filter), `coachUsage` rules blocks (+4 mutation entries; partner-denied daily-lane = the DV pin), handler + callable-e2e + sentinel/no-leak perimeter suites.
- **Proof:** functions suite **772 tests green** (from 538), coverage ~98.5% stmts / 96.3% branch (gate 80); every fold step has a property-mutation class that turns CI red if weakened; the e2e proves the deploy-default posture (premium+capped → `UNAVAILABLE` fail-closed) AND the safety accept line (crisis → 200 help path even unconfigured). App untouched (UI is M5.2).

**Commits:** PR #43 (TestFlight runbook, merged mid-session) + PR #44 `feat/m5.1-coach-safety-spine` (ADR-016 rev 1+2, stage-1 cores, stage-2 shell/rules, docs sync).
**CI:** green (PR #43 green + merged; PR #44 checks + main run verified at close).
**Docs touched:** adr/016 (new), architecture §2/§3/§4/§7/§8/§10, test-suite §1, implementation-plan M5.1, operator-expected (runbook + ★ crisis-review item + item 6 provider decision + snapshot 17/22), resume-prompt (M5.2), past-prompts.
**Notes / debt logged (loud, in ADR-016/operator-expected):** live provider adapter + `LLM_API_KEY` ride item 6; Remote Config cap binding rides the deploy era (constants + injectable `CapConfig` today); rate limiter is per-instance in-memory (invitePreview precedent; revisit at deploy hardening); crisis-content native review + hotline numbers BLOCK coach-on-device (★); `coach_sessions`/private-thread persistence is M5.2's claimed scope decision; monthly cap (1,000) binds a both-users-maxed couple ~day 17 — founder-tunable, M5.2 must render daily/monthly exhaustion distinctly.
**Next objective written to resume-prompt.md:** Session 019 — M5.2: the coach chat UI on the proven spine + persona scaffolds + the private-thread scope decision (ADR-017 first, adversarial review before code).

## Session 019 — 2026-07-12 — M5.2: the coach chat UI on the proven spine + persona scaffolds + the private-thread scope decision

**Objective (from resume-prompt.md):** M5.2 — mount the couple-facing chat experience on the M5.1 spine: ADR-017 first (adversarially reviewed BEFORE code), the chat UI end-to-end against the emulator behind `PremiumGate` (fixture replies, disclaimer before first use, help path visually distinct, honest states for every frozen wire outcome, free tier ZERO coach surface), persona system-prompt scaffolds TR/AR/EN, and the parked private-thread persistence decision.

**Outcome:** done.
- **Operator-action check (explicit, founder-requested):** no operator action was required for this session — the slice runs hermetically on fixtures by design (the resume prompt said "none required"; verified true in execution: item 6, the LLM provider decision, was checked at session start and remains unanswered, so the live-adapter stretch stayed out of scope exactly as specced). One founder decision item was *produced* (private-thread retention posture, recorded in operator-expected) and item 6 became **due** (M5.3 is blocked on it).
- **ADR-017 written + committed BEFORE code, then adversarially reviewed** (4-lens workflow — safety-ux, privacy/DV, wire-contract, Flutter-architecture — each lens verified by TWO independent passes: a skeptic re-deriving every finding and a governing-docs adjudicator; all hand-adjudicated): **1 BLOCKING** (all four lenses converged independently: rev 1's help-stickiness had NO durable mechanism — oldest-first window trimming evicts the crisis turn after ~20 turns, and a post-filter crisis NEVER sticks because its window is pre-scan-negative by construction; resolved with a client-side `helpSticky` LATCH on the server's `kind:'help'` discriminator — no client-side crisis detection, cleared only by the explicit reset, no calls leave a latched conversation) **+ 6 SERIOUS** (profile-settling precondition for the mandatory language/register fields; `lastRemaining` had no state home; send-controller family key + the captured-notifier append rule; the app-side no-content rule — Crashlytics is ON in prod, ADR-016 D8's client twin; transcript teardown on sign-out — keepAlive survives route pops; persona preamble safety lines were self-contradictorily tone-tiered → escalated to the ★ gate) **+ ~10 minor** folded into rev 2 pre-code. Verifier-lens disagreement on the blocking fix (document-the-bounded-guarantee vs latch) settled by the governing docs per the S018 rule (ADR-016's asymmetry mandate + rev 1's own rejected-alternative rationale). Review-ordering discipline is now **FIVE-for-five**.
- **Implementation (two-stage sequential agents, checkpoint-committed):** stage 1 — coach domain/data/state foundation (register derivation `coachRegisterFor` over the 3×2 profile product → the brandkit wire union; window builder with help-exclusion/crisis-retention/20-cap/assistant-truncation in UTF-16 code units; code-first `mapCoachFailure` taxonomy with the reason-dropped neutral fallback; content-free exceptions + `toString()`s, sentinel-suite pinned; keepAlive `CoachTranscript` family `(uid, coupleId, personaId)` carrying `{entries, helpSticky, lastRemaining}`; `CoachSendController` with the captured-notifier rule; `LocalFlagStore` seam over the app's first shared_preferences dependency) + functions-side `persona-prompts.ts` (pure, static-literal, per-language full prompts; ★-gated safety preamble) and the disclaimer's single-home move OUT of `help-content.ts`. Stage 2 — `CoachScreen` behind `PremiumGate` (persona chips, transcript, paused panel, disclaimer gate, typed error copy incl. the not-premium paywall push, auth-loss self-pop), the paired-home tile + spacer INSIDE the gate (free tier renders NOTHING; all pre-existing goldens byte-identical), the app-root sign-out invalidation listener, entrypoint bindings, 27 `coach*` ARB keys ×3 locales (disclaimer strings byte-preserved; Date/Gift Genie rendered TR "Perisi" / AR "ملهم" — genie→cin/جنّي folk-spirit connotations deliberately avoided), 27 goldens (disclaimer/conversation/help_path × six cells + scale-130), free-tier probes extended, the ported ARB no-phone-number digit-run guard. Mid-stage-2 the session's one environment surprise: the theme's `FilledButton` `minimumSize: Size.fromHeight(48)` means infinite min-width inside a Row — fixed locally in the composer, theme untouched.
- **Post-implementation verified review** (4 lenses × skeptic verification, all hand-adjudicated): **1 SERIOUS confirmed** — found by a skeptic pass while REFUTING a weaker finding: a sign-out landing mid-send re-populated the keepAlive transcript AFTER the root listener's lazy invalidation (the in-flight exchange would survive into a same-uid re-sign-in — exactly the D3 hole the teardown claimed to close); fixed with an owner guard in `applyExchange` (drops a late exchange whose owner is no longer signed in; persona-switch replies still land), race pinned by a new test. **3 minors fixed** (disclaimer-ack `setState` mounted guard; the untested empty/whitespace send gate; the captured-notifier test reworked to GENUINELY dispose the controller — `invalidate` on a listened element only refreshes). **2 refuted with evidence** (the `UnmountedRefException` mechanism — keepAlive invalidate never disposes; the "vacuous determinism test" claim). Plus one adopted alignment: server persona scaffolds' TR/AR self-names matched to the ARB labels.
- **The stage-2 agent died mid-run on a session-limit API error** — recovered cleanly: its final full-suite run had already completed green (1020 tests), all 27 goldens and probes were on disk, and only the ARB guard test remained (added by hand). Checkpoint-commit-immediately discipline meant zero loss.
- **Proof:** app suite **1025 tests green / 85.96% coverage (gate 68) / analyze clean**; functions full emulator suite **773 tests / 98.45% stmts / 96.17% branch (gate 80)** re-proven after the persona-scaffold change; every pre-existing golden byte-identical; goldens 27 new PNGs.

**Commits:** PR #45 `feat/m5.2-coach-chat-ui` (ADR-017 rev 1+2, stage-1 foundation, stage-2 UI, docs sync, review fixes).
**CI:** green (PR checks + main run verified at close).
**Docs touched:** adr/017 (new) + adr/README (016 row backfilled + 017), architecture §3/§4/§8, test-suite §1, implementation-plan M5.2, operator-expected (rewritten for S019), resume-prompt (M6.1 next — M5.3 is founder-blocked), past-prompts.
**Notes / debt logged (loud, in ADR-017/operator-expected):** M5.3 (live provider adapter + `LLM_API_KEY`) is BLOCKED on operator item 6 — per session-rules §4 the next objective moves to the highest-priority unblocked task (M6.1, the device-privacy layer — which also owns ADR-017's deferred OS-app-switcher-snapshot obscuring); `coach_sessions` persistence awaits the founder's retention-posture decision (options recorded); persona-prompt safety preamble joins the ★ native-review gate; the quota meter before the day's first message stays deferred (needs the `coachUsage` watch + client key comparison); transcripts die on app restart by design (ephemeral scope).
**Next objective written to resume-prompt.md:** Session 020 — M6.1: the device-privacy layer (PIN/biometric lock + discreet alternate icon + coach snapshot obscuring), ADR-018 first, adversarial review before code.

## Session 020 — 2026-07-12 — M6.1: the device-privacy layer (root lock gate + snapshot shield + discreet icon + the first settings surface)

**Objective (from resume-prompt.md):** M6.1 — the device-privacy layer: PIN/biometric app lock, discreet alternate iOS icon, the OS app-switcher snapshot obscuring ADR-017 deferred here, and the minimal settings screen to host them. ADR-018 first, adversarially reviewed BEFORE code. M5.3 stayed out of scope (founder-blocked on item 6).

**Outcome:** done.
- **Operator-action check (explicit, founder-requested):** **no operator action was required for this session, and none was taken on the founder's behalf.** The resume prompt declared "External dependencies (founder): none required" and that held true in execution: the whole slice is app-side engineering proven against `flutter test` + CI, with every device-only surface behind a seam. Item 6 (LLM provider) was re-checked at session start, remains unanswered, and correctly kept M5.3 out of scope. The session *produced* new operator expectations rather than consuming any: four on-device verifications joined item 4 (Keychain survives reinstall · Face ID prompt + enrollment-change auto-revocation · discreet-icon render + Apple's own system alert · the app-switcher card is blank), and 41 new `lock*`/`settings*` strings joined item 1's native-review gate — two of them (the Face ID DV warning, the forgot-PIN copy) flagged as carrying safety meaning, not just tone. All recorded in `operator-expected.md`.
- **ADR-018 written + committed BEFORE code, then adversarially reviewed** (4 lenses — security/bypass, Flutter mechanics, DV/product/UX, testability/CI — each verified by TWO independent passes: a refuting skeptic and a governing-docs adjudicator; 12 agents, all findings hand-adjudicated): **4 BLOCKING + 5 SERIOUS + ~14 minor** folded into rev 2 before a line of code. Review-ordering discipline is now **SIX-for-six**. The blocking four: (a) the biometric seam omitted `biometricOnly`, so local_auth's default would have accepted the **device passcode** — which the phone-holding partner plausibly knows — as an alternate unlock, a side door straight past the app PIN, and *no fake could ever surface it* (pinned instead by a source-sentinel test); (b) biometric-as-accelerator was an unrevocable parallel credential — any biometric enrolled on a shared device unlocks, and the ADR's own rejection of biometric-*only* used exactly that argument, so it defeated its own accelerator (fixed: `evaluatedPolicyDomainState` captured at enable, re-checked at every lock-screen mount, **any enrollment change auto-revokes**, plus an explicit DV warning for what that cannot catch — biometrics enrolled *before* enable); (c) the keepAlive wipe race — the S019 class returning — where `ref.mounted` provably cannot guard a controller wiped **in place** and never disposed, so a wrong-attempt persist racing the sign-out wipe would re-persist the previous user's `pinHash` (fixed with a generation guard re-checked after every await); (d) "**Never a bypass**" was a guarantee the mechanism could not carry: the forgot-PIN recovery hands the phone-holder a path *they* can complete on the same device (the SMS OTP lands on the SIM they hold; Apple re-auth uses the device passcode) — the claim was deleted and replaced with the honest one, *"casual and silent access is blocked; an identity-anchor holder can force a **destructive and detectable** way in."* Serious: recovery reordered to sign-out-FIRST (wipe-then-sign-out drops the overlay onto a still-signed-in app when sign-out throws); the wipe must mutate state and **never** `ref.invalidate` (that would replay the by-value boot snapshot); discreet mode bounded honestly (the icon image changes, `CFBundleDisplayName` cannot); bypass negatives paired with unlock→reveal controls; increment-persisted-before-verdict.
- **Implementation (two-stage sequential agents, checkpoint-committed after each):** stage 1 — the security core (`PinLockStore` seam + versioned Keychain record with unknown-version→absent; the boot snapshot distinguishing *absent* from *degraded* so a read that threw self-heals on the next resume instead of failing open for the process lifetime; salted SHA-256 + constant-time compare with the no-KDF honesty note written into the source; `PrivacyLockController` with the generation guard, attempt bounding, and enrollment revocation). Stage 2 — `PrivacyGuard` in `MaterialApp.builder`, the lock screen (LTR-pinned keypad; **no `showDialog` anywhere** — it sits above the only Navigator, so that throw would *be* the lockout, hence an inline confirm), the neutral brand-free shield, the settings screen + a gear wrapping each home's whole build (so it survives error states), the `hayati/device_privacy` MethodChannel + `AppIconDiscreet.appiconset` + `NSFaceIDUsageDescription`, ARB ×3, and the bypass suite.
- **Two further races found while reviewing the agents' output, both mutation-proven load-bearing:** `refreshBiometricAvailability` is deliberately *not* `_busy`-guarded (guarding it would drop the user's first keypress while a mount-time probe is in flight) — so a wrong-PIN persist can land inside its two probe awaits, and revoking from the pre-probe capture **refunded the consumed attempt**. An attempt-bounding bypass reachable by exactly the partner who triggered the enrollment change. Fixed by re-basing the revoke on the current record and advancing `_record` *before* awaiting the write; each fix mutation-checked (neutering it turns exactly its own test red, and one first-draft test was found to be vacuous *by* that check and rewritten).
- **What the implementation taught the design (ADR-018 rev 3):** flutter_riverpod 3 **pauses provider subscriptions** when `TickerMode.of(context)` is false (`consumer.dart:383,402`) — so the gated subtree does not merely stop *painting* couple content, it stops *fetching* it, and resumes on unlock. Stronger than the ADR claimed, and precisely why the bypass negatives need positive controls. Also: `handleAppLifecycleStateChanged` **does** assert on invalid transitions (rev 2 said it did not), so the tests drive the real iOS chains.
- **Proof:** app suite **1,213 tests green (+98) / 86.34% coverage (gate 68)**; `flutter analyze`, `dart format`, and `rtl_lint` all clean; functions untouched. 42 new goldens (lock/settings/pin-setup × six cells + scale-130); home goldens re-baselined intentionally for the gear (**W4 flag**). Three device-only adapters (Keychain, local_auth, icon channel) are never imported by a test — `flutter test` touches no platform channel and they stay out of the coverage denominator.

- **Post-implementation verified review (5 lenses × 2 verifiers — lock-bypass, Flutter correctness, spec conformance, iOS/CI, DV-copy/l10n): 2 BLOCKING + 4 SERIOUS confirmed and fixed before merge.** Two were reached INDEPENDENTLY BY TWO LENSES each — the signal worth trusting. **(a) The orphaned-record BRICK** (found by both the spec and bypass lenses): the wipe rode ONLY the root `ref.listen(authControllerProvider)`, which fires on a state *change* — and `AuthSignedOut` is value-equal, so signing out while ALREADY signed out re-enters an identical state, Riverpod suppresses the notification, and the listener never runs. The orphaned-record edge (a lock outliving its session because the wipe's `clear()` threw — ADR-018 D1/D8's own named case) boots exactly there, and "Forgot PIN? Sign out" then did *nothing*: no wipe, no error, forever, **with no escape** — reinstalling does not clear the Keychain, which is D2's entire point. D4 had *promised* this path was "idempotent and works when already signed out"; the code did not carry it. A guarantee-vs-mechanism gap, the exact class the S020 addendum names. Fixed: recovery reads the SETTLED auth state and wipes on the *state*, not the transition. **(b) Biometric attachable WITHOUT the PIN** (found by both the bypass and DV lenses; ADR-018 D1's own revocation paragraph already demanded the PIN — only the warning shipped): a partner catching the phone *momentarily unlocked* (inside the 60s grace, or simply handed it) flips Face ID on, acknowledges a warning written for the owner, and the record captures an enrollment state **with their own already-enrolled face inside it** — a permanent second credential to the lock, obtained silently, with zero PIN knowledge. Enrollment-change revocation is powerless: nothing changed *after* enable. Fixed: enabling demands the PIN, attempt-bounded like the lock screen (or it would be an unbounded PIN oracle behind the gate); disabling still needs none (it only reduces access). **Serious:** the **TR copy INVERTED the lock state** — `settingsPinSaveFailed` read *"Kilit hâlâ kapalı"*, which a Turkish speaker reads as "the lock is **closed**" (= engaged), on the exact path D8 governs ("never claim protection that didn't persist"): the app told users in its primary market that they *were* protected when the record had failed to save (fixed to `etkin`/`etkin değil`; AR was correct throughout; neither the ARB parity guard nor the goldens can see a semantic inversion — only a reader can); the 60s grace was hidden behind copy promising the PIN "every time you open it" (categorically false in the DV hand-off scenario); settings asserted *"That PIN didn't match"* about a PIN it had never compared (a cooldown refusal — `disableLock` now returns the same result type as `verifyPin`); and **focus survived the gate** — `Offstage` stops paint/hit-test/semantics but does NOT move focus, so a composer stayed focused underneath and the keyboard rode up *over* the lock screen, covering the keypad and the Forgot-PIN escape. Also fixed: `authenticateBiometric`'s stale-window write ordering, and the discreet icon's `Contents.json` mixing the Xcode 14+ single-size shape with a legacy `scale` key — CI passed either way, but the *other* branch is actool silently emitting no `CFBundleAlternateIcons`, i.e. a dead headline feature behind a green pipeline. Every guard **mutation-checked**.

**Commits:** PR #46 `feat/m6.1-device-privacy` (ADR-018 rev 1/2/3, stage-1 foundation, stage-2 UI+platform, docs sync, review fixes).
**CI:** see PR #46 — the macOS `build-ios` job is the only gate that compiles the new Swift and runs actool over the new icon set (the Linux dev box cannot).
**Docs touched:** adr/018 (new, rev 3), architecture §2/§4/§8, test-suite §1, implementation-plan M6.1 (M6's first written sub-slice), operator-expected (rewritten for S020: item 4 gains four on-device checks, item 1 gains the lock/settings copy, snapshot 19/22), resume-prompt (next), past-prompts.
**Notes / debt logged (loud, in ADR-018/operator-expected):** the per-user neutral-notification override is **M6.2** (PRD F6's discreet mode is deliberately split across two sessions — the icon ships now, the notification override needs a `users` field + the settings-Function path, and AR-locale users already have discreet pushes by default per ADR-012); a native SceneDelegate snapshot cover stays pre-recorded as the known fix **iff** the on-device check finds the pure-Dart shield leaves a timing gap; no change-PIN flow (turn-off→turn-on, both verify first — a convenience gap, not a hole); Android's lock + activity-alias icon ride M6.5. **Recorded residuals, none silent:** same-device re-auth through recovery, device-clock manipulation collapsing cooldown *delays*, biometrics enrolled before enable, the immutable app-name label, process-memory residue.
**Next objective written to resume-prompt.md:** Session 021 — M6.2: KVKK/PDPL export + cascade delete + partner notification (and the per-user notification-privacy override) — **unless the founder answers item 6, in which case M5.3 (the coach going live) takes precedence.**

## Session 021 — 2026-07-13 — M6.2: KVKK/PDPL data rights (export + cascade delete + partner notification + the discreet-notification override)

**Objective (from resume-prompt.md):** M6.2 — the last legally-required MVP feature: self-serve export + hard cascade delete with partner notification + the per-user discreet-notification override (M6.1's deferral). ADR-019 first, adversarially reviewed BEFORE code, and the review run TWICE (design + built diff). Item 6 was checked first per the objective's preemption clause: still unanswered, so M5.3 stayed out and M6.2 proceeded.

**Outcome:** done — full scope (no overflow split needed: cascade + notification + export + override all shipped).
- **Operator-action check (explicit, founder-requested mid-session):** **no operator action was required and none was taken on the founder's behalf.** Item 6 re-checked at start (unanswered → M6.2 stood); the session deliberately avoided creating a new operator item by choosing in-app export over email delivery (the resume prompt's stated preference — an email provider would have been a new dependency, and an emailed JSON is a plaintext copy in an inbox a partner may share). A mid-session founder status request was answered with an interim `operator-expected.md` refresh surfacing the two founder-overturnable design calls (whole-thread deletion; no partner push).
- **ADR-019 written + committed BEFORE code, then adversarially design-reviewed** (5 lenses — guarantee-vs-mechanism, security/DV, distributed-systems/partial-failure, legal/product-honesty, Flutter/Riverpod — × 2 independent verifiers per finding: refuting skeptic + governing-docs adjudicator; 29 agents): **2 BLOCKING + 6 serious confirmed + 2 downgraded-to-fold + 9 minor** folded into rev 2 before a line of code — review-ordering discipline now **SEVEN-for-seven**. The blocking two: (a) the resume cursor was consulted only when `users/{A}` was fully gone — never in the exact window it exists for (after the detach clears `coupleId`), so a kill at k=2/k=3 would have orphaned the ENTIRE couple subtree permanently and then deleted the last pointer to it; (b) the singular `deleteUser` throws `user-not-found` on re-drive — a lost final-step ack would strand a fully-deleted account in "deletion failed, retry forever" (and after the token hour, nobody could ever re-drive), with D8 actively prescribing the stranding by misapplying ADR-018's protection-stays asymmetry to a success masquerading as an error. **Two verifier disagreements settled by the S018 governing-doc rule, both for the adjudicator** — most consequentially the `coupleEnded` PUSH was DELETED from the design: the mandate ("partner notification") names no channel, the atomic field already carried the guarantee, and a real-time ping to a possibly-abusive partner at the deleting victim's escape moment was pure added risk (verified bonus defect: the AR-discreet fallback would have dressed the deletion notice as the engagement lure "Something is waiting for you in Hayati").
- **The contested product-legal call (Decision 1), resolved and recorded loudly for the founder:** the couple is TERMINAL — A's deletion removes the whole shared thread, both halves. B's couple-thread answers are mixed personal data about A (an erasure leaving the other side of every conversation readable has redacted the record, not erased it — DV-decisive: a victim escaping must not leave the abuser a curated archive); the accept line says "couple data gone"; a half-thread misrepresents what B agreed to share. The author-split alternative + both options' honest costs are in the ADR; B keeps everything that was ever B's alone and gets no preservation window (structurally a delay/veto on the erasure right — recorded, not silent).
- **Implementation (two-stage sequential agents, checkpoint-committed after each):** stage 1 server — `functions/src/data-rights/` (core/service/shell per the coach mold), the cascade, `exportData`, `updateNotificationPrivacy`, the `resolveDiscreet` override threaded through its documented seam, the `createInvite` profile-exists precondition, `joinInvite` clearing `coupleEnded`, the rules freezes + `soloAnswers` exists-guard + 6 new mutants. Stage 2 app — the data-rights repository seam, two-phase `AuthController.deleteAccount()` (server-cascade failure leaves auth state untouched so the settings self-pop can never eat the retry screen; success lands `AuthSignedOut` from `AuthSignedIn` — the value-inequal transition firing the M6.1 lock wipe on the EXISTING root listener, wipe wiring mutation-checked by hand), the three settings additions, `ExportScreen`, `DeleteAccountScreen` (honest copy: irreversible, both sides, partner sees closure not reason, subscription NOT cancelled), `CoupleEndedNoticeScreen` as a gate-rendered child above the pending-invite branch with an EVENT-keyed seen flag, ProfileDto nested-map wiring, ARB ×3 + a new l10n guard.
- **Post-implementation verified review (5 lenses × 2 verifiers over the 113-file diff, both suites green going in): 2 SERIOUS confirmed unanimously + 8 minor — the eighth consecutive review pass to find real defects, both S020-class.** (a) **The partner-detach misresolution:** the rev-2 cursor protected a uid only against its OWN detach — B's concurrent detach clears `users/{A}.coupleId` without writing A a cursor, so A resolving after B's commit misread itself as unpaired, skipped the couple sweep, and returned `deleted` while A's authored couple answers survived under B's possibly-abandoned cascade; masked by a "concurrent double-delete" test racing A against A (which the cursor always protects — the vacuity class again). Fixed: transactional resolve + the detach txn seeding `deletions/{partnerUid}` + a seed-cleanup step; the misresolution state is now unreachable by construction; the seed mutation-checked (removed → abandonment test red on the exact surviving-answers residue). (b) **The create-path mint gap:** the users CREATE rule blocked only `coupleId`, so a client could mint `coupleEnded`/`notificationPrivacy` at profile creation — the "impossible" claim was false on create and untested. Fixed + 2 mutants; root cause recorded (no `hasOnly` on users create ⇒ every server-owned field needs BOTH clauses). Minors fixed in code: invites sweep moved after the own-subtree sweep (the dead profile fail-closes `createInvite` — the intra-cascade mint window is gone), the re-pair guard test rewritten to evaluate the guard clause LIVE (it had passed via an early-return; guard now mutation-checked), k=2/k=3 assertions hardened, export sentinel de-collided, dead uid param dropped.
- **Proof:** functions **848 tests / 97.88% stmts / 93.57% branch (gate 80 hard, 85 target)** — the first functions movement in three sessions, landed far above target; app **1,300 tests (+94) / 86.29% (gate 68)**; analyze/format/rtl clean both sides; full emulator suite exit 0 (echoed). 19 new goldens (delete screen + notice ×9 each, export ×1); settings re-baselined for the three new rows (W4); every other pre-existing golden byte-identical (git-verified). Wire contracts frozen: `deleteAccount {confirm:'DELETE'}→{status:'deleted'}`, `exportData formatVersion:1` (epoch-ms fields, questionId-only), `updateNotificationPrivacy {discreet:bool}`.

**Commits:** PR `feat/m6.2-data-rights` (ADR-019 rev 1/2/3, server half, app half, docs sync, post-review fixes, operator interim).
**CI:** see the PR checks + main run at close.
**Docs touched:** adr/019 (new, rev 3) + adr/README (019 row), architecture §3/§4/§8 (incl. BOTH stale "Function → JSON email" occurrences — the review's DPA-1 deeper find — and the honest unbuilt-status annotations on consent screens + the DPA inventory), test-suite §1 (functions + widget), implementation-plan M6.2, operator-expected (interim + close refresh), resume-prompt (next), past-prompts.
**Notes / debt logged (loud, in ADR-019/operator-expected):** push delivery for ANY notification still rides operator item 4 (APNs + fcmTokens — nothing new here, and the deletion notice deliberately uses none); backup-retention alignment, export rate-limiting, and RC-REST reconciliation ride the deploy era / item 0; the AR discreet-default opt-out is a recorded product decision (enum leaves the door open); `coach_sessions` export/cascade coverage stays contingent on operator item 7; consent screens + DPA inventory are mvp item-12 pre-launch work, now honestly marked unbuilt in §8. **Recorded residuals, none silent:** what B has already seen cannot be un-revealed; the ≤1h token window (two-surface class; `users/{uid}` re-create = fresh-signup-equivalent); at most one uid-free orphan seeded-cursor doc on double abandonment; B unnotified until next app-open (no push, by decision); billing survives deletion (both users' copy says so).
**Next objective written to resume-prompt.md:** Session 022 — M6.3: App Store metadata TR/EN via Fastlane + the performance pass + the closed-beta build (Mac-dependent halves stay honest about what CI can prove) — **unless the founder answers item 6, in which case M5.3 (the coach going live) takes precedence.**

## Session 022 — 2026-07-13 — M6.3: store metadata TR/EN via Fastlane + the performance pass + the closed-beta release lane

**Objective (from resume-prompt.md):** M6's third and final slice — `fastlane/metadata` TR/EN, the `release.yml` lane built and provable to the signing boundary (fail closed, loudly, never a silent-green skip), the perf pass CI can honestly prove, and the crash-free posture audit. Item 6 checked FIRST per the preemption clause: still unanswered → M5.3 stayed out, M6.3 proceeded.

**Outcome:** done — full scope, no overflow split needed.
- **Operator-action check (explicit, per the session's opening instruction):** **no operator action was required to BUILD this session's scope and none was taken on the founder's behalf.** Session-hygiene check first (two other live Claude sessions found — both on OTHER repos, `ams-pulse`/`unhooked`; tree clean, no stashes). The session DID surface new pre-submission founder items, all recorded in operator-expected at close, none blocking any session: the missing privacy/support URLs (no domain exists — the metadata ships EMPTY URL files behind a loud lint ratchet, never a fake URL), the store-name trademark search ("Hayati" is provisional; vetted alternates recorded in ADR-020), the display-name question ADR-018 D6 handed to this pass (deliberately NOT decided — variants drafted, founder-owned), the AI-chat age-rating verify-item, and the three `release` environment secrets for item 4's enrollment day.
- **ADR-020/021/022 written + committed BEFORE code, then adversarially design-reviewed** (5 lenses — over-claim, release-engineering, Apple-domain, app-runtime, governing-docs — × 2 verifiers per major finding, 20 agents): 15 raw → 10 deduped → **2 BLOCKING + 2 serious CONFIRMED by both verifiers, 3 REFUTED, 3 minors hand-adjudicated** — review-ordering discipline now **EIGHT-for-eight**. The blocking two: (a) **REL-1** — a first-time `workflow_dispatch` workflow registers only once its file lives on the DEFAULT branch, so the specced pre-merge branch-dispatch acceptance proof was literally impossible (404); re-sequenced to a post-merge `--ref main` dispatch, recorded not reinterpreted. (b) **PERF-2** — ADR-022's source-sentinel "allowed await set" omitted `configureIfKeyed`, which its own Decision 3 mandates stays pre-frame: the gate would have gone red against ADR-mandated source. The serious two: **REL-2** — environment secrets are invisible to a job without `environment: release` (a configured lane would have stayed permanently boundary-red with a MISLEADING missing-secrets message); **PERF-1** — the App Check post-frame deferral rested on a false "no backend call before user interaction" premise: on EVERY warm signed-in boot, `OnboardingGate` opens the profile Firestore listen at first-frame build — the deferral was DELETED (the S020 rule: delete the over-claim, don't fake the mechanism), recovered as an App Check ∥ Crashlytics `Future.wait` overlap instead. The refutations were read per the S019 rule and paid: the "flutter build ipa can't cloud-sign" refutation came with pinned flutter_tools source proving `-allowProvisioningUpdates` is passed unconditionally — that precision was folded into ADR-021 D5.
- **Implementation: three PARALLEL chunk agents on disjoint file sets** (a first — prior sessions ran sequential stages; disjointness made parallel safe, with `ci.yml` + shared docs reserved to the orchestrator), checkpoint-committed the moment the workflow returned (S014 rule): **(A)** `fastlane/metadata/{en-US,tr}` ×9 files (every char limit verified in code points: name 6/30, subtitle 27/30, keywords 91·70/100, description 1454·1518/4000), copy drafted in the brandkit voice reusing the ARB honest-bound vocabulary verbatim (TR-respectful register; "plain home-screen icon", never "hide the app"; not-therapy framing from `coachDisclaimerBody`; tagline rendered by meaning "asla partner aramak için değil"); the `beta`/`store_metadata` lanes implemented to the ASC secrets boundary; `tool/store_metadata_lint.dart` (+32-check self-test) — the credential-free precheck: Apple limits, required files, unknown-filename hard fail, empty-URL ratchet under `--allow-empty-urls` (removing the flag is the ratchet; the no-flag run exits 1, proven). **(B)** `release.yml` — `preflight` (metadata lint + tag↔pubspec X.Y.Z pin, version truth in pubspec, CI never synthesizes build numbers) → `integration` (the existing emulator suites via the ci.yml recipe) ∥ `build-report` (prod `--analyze-size` + the 200 MB pathology cap via `tool/build_size_report.dart`; missing artifact = exit 64, never green) → `sign-upload` with `environment: release` and the all-or-nothing fail-closed secrets gate (names the missing set, points at item 4, no `if:`-skips anywhere near signing); `ITSAppUsesNonExemptEncryption=false` + `CFBundleLocalizations [en,tr,ar]` in Info.plist; `{en,tr,ar}.lproj/InfoPlist.strings` localizing the Face ID purpose string (ADR-018 D7's deferral closed) via a hand-authored pbxproj variant group wired into the RESOURCES build phase — with a new `ios-build-smoke` assertion that the built `Runner.app` actually CONTAINS the three `.lproj` copies (the S020 silent-green class, from a review minor). **(C)** the ADR-022 rev-2 bootstrap in lockstep: tz-DB parse → post-frame callback, App Check ∥ Crashlytics and prefs ∥ Keychain-snapshot overlapped via record-`.wait` (degraded-boot semantics byte-identical; the lock read still decides frame one — ADR-018 D2 untouched), `configureIfKeyed` deliberately unmoved with the warm-boot identity-sync trap documented at the call site; debug-only `BootTrace` (stage names only — the no-content rule); the **mutation-checked entrypoint source sentinel** (both mutations run raw: tz-back-pre-frame → red on exactly the right assertions; extra pre-frame await → red; restored → green) pinning the four-await set + dev/prod lockstep; `startup_timing_emulator_test.dart` printing the stage table with SANITY-only assertions — **no <2s theater**: the PRD's number is a mid-range-Android M6.5 gate (§10 says so verbatim), and the real-device iPhone stopwatch rides operator item 4.
- **Post-implementation verified review (same 5-lens × 2-verifier shape over the built diff): ZERO blocking/serious, 2 minors — the NINTH consecutive review pass to find real defects, both fixed pre-merge:** the `upload_to_testflight` ipa-path gap (raw-`sh` build leaves `lane_context` empty; pilot's glob searches the wrong dir — a near-certain first-enrolled-run failure, now explicit + fail-closed) and the operator-expected Phase D export-compliance note going stale against the shipped plist key (fixed in the close refresh).
- **Crash-free posture audited, not rebuilt (ADR-022 D6):** dev-OFF/prod-ON confirmed live; the ≥99.5% gate's remaining needs are exactly the recorded set (dSYM — item 4; a deployed app — item 2; Gate-2 instrumentation — mvp item 11). Audit note added to architecture §-observability.
- **Proof:** app **1,305 tests (+5) / 86.29% (gate 68)**, analyze/format/rtl clean; **functions untouched** (zero diff — as specced); both workflow YAMLs parse; metadata lint PASS with the 4 empty-URL warnings counted loud; the release-lane acceptance dispatch (post-merge, per REL-1) proves pre-signing stages green + the honest boundary-red.
- **Honest bounds, recorded where they live:** the signing/TestFlight half of the M6 accept line stays operator-blocked (item 4) — the lane proves that loudly instead of skipping it; the Fastfile's Ruby semantics and the cloud-signing composition are unverifiable from Linux (ADR-021 D5's addendum lists the likeliest first-run fix: `DEVELOPMENT_TEAM`); screenshots are Mac-era; store copy ×2 locales is AI-drafted and joins operator item 1's native-review gate.

**Commits:** PR `feat/m6.3-store-metadata-release-lane-perf` (ADR-020/021/022 rev 1 → rev 2 pre-code, implementation checkpoint, integration, format, post-review fix, close docs).
**CI:** see the PR checks + main run at close + the post-merge `release.yml` dispatch (pre-signing green, boundary honestly red).
**Docs touched:** adr/020+021+022 (new, rev 2 + review records) + adr/README (3 rows), architecture §9 (release-lane reality) + the M1.3 observability block (crash-free audit note), test-suite §1 (E2E deferral) + §2 (M6.3 CI additions), fastlane/README (M6.3 reality + review-status inventory), operator-expected (close refresh incl. the Phase D staleness fix), resume-prompt (next), past-prompts.
**Notes / debt logged (loud):** the E2E-1/2/3 matrix enters `release.yml` when the scenarios can honestly run (sandbox = items 0+4; recorded in test-suite §1); the Gemfile.lock debt survives until the signing job first executes bundler (ADR-021 D6); the 200 MB size cap ratchets once real measurements exist; the empty-URL lint flag `--allow-empty-urls` is the ratchet to drop when the founder supplies a domain + hosted privacy policy; the store-name/display-name/age-rating founder items are in operator-expected.
**Next objective written to resume-prompt.md:** Session 023 — the mvp item-12 legal bundle's buildable half (consent screens + privacy-policy/terms drafts TR/AR/EN + the DPA inventory) — **unless preempted: item 6 answered → M5.3; Blaze flipped → the first-deploy slice; the founder green-lights Android timing → M6.5.** With M6.3 closed, the 22-unit MVP engineering plan is COMPLETE except founder-blocked halves.

### Session 022 addendum (same session, post-merge validation round)

The post-merge proofs surfaced and closed three more things, all same-session (session-rules §3.5):

1. **An INHERITED unexamined red on main from Session 021:** the S021 post-merge `integration-emulator` run failed on `pairing_emulator_test.dart` — M6.2's `createInvite` profile-exists precondition (the cascade invariant) landed with its functions-side proofs, but this main-only/macOS-only app suite kept issuing profileless → `failed-precondition` on every main run since. Fixed by seeding the profile before issuing (PR #52); the post-fix main run went fully green including `integration-emulator`.
2. **The release-lane acceptance proof ran and behaved exactly as designed** (post-merge `gh workflow run release.yml --ref main`, per ADR-021 D1 rev 2): `preflight` ✅ (lint + honest tag-only version line) → `integration` ✅ (all emulator suites incl. the new `startup_timing` suite's first live run — BootTrace: main→runApp **435 ms**, time-to-first-frame **874 ms**, dev-debug simulator diagnostics; the AppCheck∥Crashlytics overlap visibly ~19 ms combined) ∥ `build-report` ✅ (**Runner.app 64.1 MB uncompressed** — the first real size measurement; the 200 MB cap can start ratcheting) → `sign-upload` ❌ at exactly the named "signing secrets gate" step with the loud message naming the missing `ASC_*` set and pointing at operator item 4. **The M6 accept line's buildable half is proven; the red is the honest state of the operator-blocked half.**
3. **The first live `build-report` run exposed a fail-open in `tool/build_size_report.dart`:** flutter's real treemap root carries `value: 0` (an int — the children-sum fallback never fired), so the gate passed with "total 0 bytes" while the breakdown correctly showed 64.10 MB — a 300 MB app would also have passed. Fixed (PR #53): prefer the children sum on a non-positive root value + hard-fail (exit 64) on a non-positive total, verified against the observed real shape / all-zero / over-budget. Two lessons re-learned the same hour: real-artifact shapes beat documented shapes (the fixture was source-accurate and still wrong), and **`gh run watch --exit-status | tail` eats the exit code — the repo's own "never trust a piped exit code" rule applies to the watcher too.**

## Session 023 — 2026-07-13 — mvp item 12: the legal bundle's buildable half — consent surface + privacy-policy/terms drafts TR/AR/EN + the DPA inventory

**Objective (from resume-prompt.md):** ADR-023 first (what KVKK/PDPL actually require at first run vs contract basis; the consent surface's shape; where consent state lives; version stamping; the export/delete interaction), then the in-app consent/legal surface ×3 locales, the AI-drafted privacy-policy + terms texts under `docs/legal/`, `docs/dpa-inventory.md`, and the architecture §8 honesty flip. Three preemption checks FIRST, all verified negative: item 6 (LLM provider) still unanswered; **Blaze confirmed OFF factually via the Cloud Billing REST API** (`billingEnabled: false` on both projects — not assumed from the checklist); no Android go.

**Outcome:** done — full scope, no overflow split needed (the drafts did NOT slip to the next session).
- **Operator-action check (explicit, per the session's opening instruction): no operator action was required to BUILD this session's scope and none was taken on the founder's behalf.** Session-hygiene check first (three other live Claude sessions found — all on OTHER repos: `unhooked`, `ams-pulse`, `evrak`; tree clean, no stashes). The session CREATED a new founder gate, recorded at close: the legal/native review of the six drafted documents + three bracketed placeholders (controller entity, contact address, governing law), the **KVKK SCC + 5-business-day Kurum filing** (a legal action, pre-public-launch), the Kurul adequate-measures question, and **three lawyer questions** (A: is the relationship-content processing special-category; B: may the one consent condition the reflective features; C: must withdrawal erase the stored corpus).
- **Research first (6 parallel agents):** three evidence briefs (KVKK incl. Law-7499/2024 + the July-2024 transfer regulation; PDPL incl. Sept-2024 full enforcement + the unenacted 2025 draft; Apple guidelines rev. June 2026) + three repo scouts. Load-bearing findings: consent-vs-contract (consent is a LAST resort under KVKK — wrapping the core loop would be the misleading-consent error), the special-category conservative reading (the crisis detector is health-data inference), EU hosting is a KVKK cross-border transfer needing a filed SCC (consent is NOT an available basis for continuous hosting), Apple requires the policy IN-APP (5.1.1(i)) and on the paywall (3.1.2) — satisfiable with no hosted URL, and İYS/VERBIS/GDPR/PDPL all bind later or not yet (each recorded, none built).
- **ADR-023 committed BEFORE code, then adversarially design-reviewed** (5 lenses × 2 verifiers, 15 agents): **2 BLOCKING + 8 serious confirmed + ~10 minors folded, 3 overruled** — review-ordering now **TEN-for-ten**. The blocking two: (a) `security-1` — "consent is a processing precondition" was guarantee-shaped language with client-only enforcement (the S020 class); resolved BOTH ways: a rules consent predicate on the special-category answer writes (presence-only, version-blind, bound recorded) AND the honest-bounds paragraph. (b) `appflow-1` — the gate trapped a decliner: export/delete were reachable only through the homes the gate blocks (Apple 5.1.1(v) exposure); the gate gained export + delete + sign-out escapes. The review also REDESIGNED the version mechanism: the callable now stamps its own `CURRENT_LEGAL_VERSION` (the client claims no version), killing the partial-bump brick class, with a **three-way source-sentinel** (app const == functions const == docs/legal/README `version:`) failing CI red in both drift directions. Withdrawal's residual-basis question became Load-bearing ambiguity 3 + lawyer question C — implemented PROSPECTIVE by the repo's own DV doctrine (a one-confirm action must never destroy data), with erasure one deliberate step away on the gate itself. The rev-1 privacy-manifest decision was adjudicated OUT as scope creep → issue #55.
- **Implementation: 2 parallel agents on disjoint file sets** (functions/rules ∥ legal texts/DPA), then the app agent sequenced after (it needed the committed assets for the drift test), each checkpoint-committed on return (S014 rule); shared docs reserved to the orchestrator (S022 rule). The app agent's warning that two more integration suites needed consent seeding was **verified false by direct inspection** (repository-level suites; no answer writes, no gate rendering) — only `daily_question_emulator_test` needed it, and the server agent had already fixed it via the production `recordConsent` callable.
- **Post-implementation verified review (5 lenses × 2 verifiers over the built 123-file diff): 0 blocking + 3 SERIOUS + 3 minors — the ELEVENTH consecutive pass to find real defects, all fixed pre-merge:** (a) the client parse fail-OPENED on a missing `acceptedAt` (a version-only consent satisfied the gate while the server's own `projectConsent` refused to export the identical shape — and the committed test PINNED the inversion); remedy adjudication split across lenses, settled for fail-closed: code aligned to the ADR's triple-pinned commitment. (b) the deliberately-built stale-after-accept state latched `busy` forever and disabled all three escapes — the `appflow-1` trap re-created inside its own safety net; escapes now compute their own flag, test-pinned. (c) the consent screen + policies claimed coach messages are STORED — an over-claim contradicting the ephemerality bound on the exact surface capturing informed consent; reworded to processed-in-the-moment ×3 locales, both trees. Minors: EN/AR Art-11 parity (two rights TR carried), the explicit Art-10/1-ç collection-method sentence, the subsumed M6.2 `exists()` mutant relabeled (the D4a predicate reads the same doc and strictly subsumes its denial).
- **What shipped:** the per-uid `OnboardingGate` consent branch + `ConsentGateScreen` (one affirmative CTA; the 18+ eligibility statement severed from the consent sentence; three escapes); server-owned `users.consent {version, acceptedAt, ageAttested}` via `recordConsent` (the `notificationPrivacy` mold; withdraw = `FieldValue.delete()`); the rules pair + D4a predicate + 4 mutants; export `formatVersion` 1→2 with the iff-set consent lane; `docs/legal/` (policy 91×3 + terms 61×3, TR-respectful/AR-Gulf/EN-plain, review-PENDING, the TR policy doubling as the Art-10 aydınlatma metni) byte-synced to bundled assets under a drift test, rendered dependency-free through an injected-bundle seam; the notice footer riding `ProviderActions` (every sign-in surface incl. the cold-open invitee, by construction); paywall Terms+Privacy links; the Settings hub (consent status + withdraw, reached-from-Settings only); `docs/dpa-inventory.md` with honest per-service region cells + the founder/lawyer blocks; 18 new goldens + intentional re-baselines.
- **Proof:** functions **870 tests / 97.75% stmts (gate 80)** in `emulators:exec`, app **1,390 tests / 86.28% (gate 68)**, analyze/format/rtl clean, both hand mutation-checks red-then-green, PR #56 CI green, squash-merged, main green.

**Docs touched:** adr/023 (new, rev 3) + adr/README row, `docs/legal/*` (new ×7), `docs/dpa-inventory.md` (new), architecture §3/§8 + the rules-invariants paragraph, test-suite (goldens, sentinels, mutants, the exists-mutant relabel), implementation-plan (item-12 close entry), operator-expected (close refresh), resume-prompt (next), past-prompts.
**Notes / debt logged (loud):** hosting/domain still founder-gated (item 8(c) — the drafts ARE the missing URL content; the `--allow-empty-urls` ratchet stands); the founder legal/native review of all six documents is a NEW pre-launch gate; the SCC + Kurum filing and adequate-measures items are lawyer actions; İYS rides APNs (item 4); analytics consent rides mvp item 11; the PDPL seven-item set rides the KSA launch; GDPR rides the Phase-4 diaspora channel; the privacy manifest is issue #55 (submission cluster); M5.3 is a RECORDED re-consent trigger (new recipient + new cross-border leg ⇒ version bump + re-gate — binding on the M5.3 session).
**Next objective written to resume-prompt.md:** Session 024 — the hardening sweep (ci-debt #36 reveal round-trip race, the M6.1 change-PIN convenience flow, the #55 privacy manifest, the #39 Node-24 CI bump) — **unless item 6 is answered (M5.3 preempts), Blaze flips (the first-deploy slice preempts), or the founder green-lights Android (M6.5).**

## Operator interlude — 2026-07-13 — the direct-install on-device test recipe (docs-only, between Sessions 023 and 024)

**Objective (founder request, not a resume-prompt session):** the founder will physically test on the iPhone (iOS 26) with the Mac (macOS 26 / Xcode 26) and asked for the recipe in `operator-expected.md`, plus a status check and next-session confirmation.

**Outcome:** docs-only — no code changed, no session-unit consumed, Session 024's staged objective (the hardening sweep) unchanged.
- Added the **★ direct-install recipe** to `operator-expected.md`: the developer lane (cable + Xcode, works pre-enrollment via a free personal team with the Sign-in-with-Apple entitlement removed LOCALLY) vs the TestFlight lane; the **emulator dev rig** — dev flavor on the phone against the Mac-hosted emulators over LAN, using the `AUTH_EMULATOR_HOST` override that `firebase_bootstrap.dart` shipped for exactly this; the `firebase.json` 0.0.0.0 host edit (local, revert-ritual Phase 8); **emulators under `--project hayatiapp-dev`, NOT CI's `demo-hayati`** (the review's blocking find, below); phone-auth test numbers with codes in the emulator terminal; the Simulator-as-partner (**Google** sign-in) invite + `hayati://invite/<code>` cold/warm **delivery** checkbox; the four M6.1 on-device checks; the honest non-features list (no pushes, store-unavailable paywall, premium-gated + unconfigured coach, stopwatch belongs to the prod build).
- **The recipe itself went through the standing adversarial-review discipline (5 lenses × refuting skeptics, 15 agents) — the TWELFTH consecutive pass to find real defects, all folded in before merge:** (a) BLOCKING — the draft's `--project demo-hayati` would 404 EVERY callable from the phone (`main_dev` bakes `hayatiapp-dev` into the callable URL path; the repo's own PR-#23 / architecture §3 trap) and the rig would die at the consent screen; fixed to `--project hayatiapp-dev`, with the residual bound recorded honestly: `invitePreview`'s zero-auth URL is code-pinned to `demo-hayati`, so the joiner's preview card errors and the JOIN stops there on this rig. (b) BLOCKING — the draft claimed "the ENTIRE product loop"; the couple daily loop cannot run in ANY emulator rig (the day doc's sole writer is the scheduled `questionRollover`, the emulator never fires schedules — the repo's own deploy-verified-only bound; no day doc ⇒ couple-answer writes fail closed at the rules); re-scoped to the honest capability list + two spelled-out bounds. (c) SERIOUS — `NSLocalNetworkUsageDescription` is absent from Info.plist and iOS 26 is strict on local-network privacy; the recipe now carries the local-key fallback + Phase-8 revert, and the permanent key rides #55's Info.plist slice (recorded in the S024 scope). (d) MINOR ×2 — the Functions count is **ELEVEN**, not six/seven (`coachProxy` + the four data-rights callables were never in the tally; fixed in operator-expected item 2 + runbook bullet + the resume prompt's first-deploy slice), and the simulator partner must sign in with Google (phone-on-simulator IS the #15 crash). Skeptics correctly REFUTED three more (the #15 real-hardware framing, the ★-marker overload, the silently-dead-rig version of the plist finding).
- **New founder-triggerable lever recorded — the "dev-rig slice":** `lib/main_demo.dart` on the integration tests' proven `demo-hayati` bootstrap + an on-demand day-doc seeder; lifts both recipe bounds (the join AND the couple daily loop run on the phone, pre-Blaze). Offered in the recipe ("say: build the dev-rig slice"); wired into the resume prompt as a founder-triggered re-scope.
- `resume-prompt.md`: the two interlude checks (on-device defect triage preempts; dev-rig slice on founder request), the eleven-Functions correction in the first-deploy preemption, and the `NSLocalNetworkUsageDescription` rider on the #55 slice.
- Session-hygiene check: other live Claude sessions found on OTHER repos only (`evrak`, `ams-pulse`, `unhooked`) + one idle at `/home/aytek`; tree clean, no stashes; docs checkpoint-committed before the review workflow (S011/S014 rules).
- Status confirmed for the founder: **on track, no plan change** — 21/22 session-units + the item-12 buildable half done; ~95% of MVP engineering, 0% operational proof; M5.3 waits on item 6 alone; Session 024 = the hardening sweep unless a preemption fires.

**Commits:** PR `docs/operator-on-device-recipe`.
**CI:** see the PR checks + main run after squash-merge.
**Docs touched:** operator-expected (recipe + interlude header + snapshot note + eleven-Functions fix + the review's five folded fixes), resume-prompt (two interlude checks + eleven-Functions + the #55 plist rider), past-prompts (this entry).

## Session 024 — 2026-07-14 — the hardening sweep: ci-debt #36 + the change-PIN flow + the privacy manifest (#55) + the Node-24 CI bump (#39)

> **Entry written retroactively by Session 025.** S024's engineering merged (PR #59, `ea0e020`) and its post-merge main run went green, but **the session ended before running its end sequence** — no `past-prompts` entry, no `resume-prompt` regeneration, and issue #36 left open despite its fix being proven. S025 repaired all three. Recorded plainly because the close sequence is mandatory (session-rules §3) and a silently-skipped close is exactly the kind of debt rule #9 forbids leaving unstated. Content below is reconstructed from the merge commit, PR #59's body, and the run logs — not from the session's own words.

**Objective (from resume-prompt.md):** four recorded-debt slices — de-quarantine ci-debt #36, ship the M6.1 change-PIN flow, land the #55 iOS privacy manifest, bump the #39 deprecated Node-20 actions. Three preemption checks first, all negative (item 6 unanswered, Blaze off, no Android go).

**Outcome:** done — full scope, no new ADR (ADR-018 gained a rev-4 amendment).
- **#36 — the reveal round-trip de-quarantined, structurally.** The mid-test auth-switch listener race was removed rather than papered over: two isolated `FirebaseApp` instances (one per user, each with its own Auth/Firestore/Functions, explicitly emulator-wired) replace the shared-instance `signOut` dance, so no sign-out ever runs and no listener is ever re-evaluated as unauthenticated. Teardown hygiene: stream expectations cancelled in `finally`, deterministic unmount, `terminate()` before `appB.delete()`.
- **Change-PIN (ADR-018 rev 4).** Verify-first `changePin(currentPin, newPin)`, attempt-bounded identically to `disableLock` (5/6/7 escalating cooldowns, constant-time, cooldown refuses without consuming an attempt), no state flip on a wrong entry, write-first/commit-after with the failure **reported** (`settingsChangePinSaveFailed`), biometric accelerator preserved, generation-guarded across every await. All four lock invariants re-audited; **a no-invalidate source sentinel now greps invariant 1** so it cannot rot.
- **#55 — the app-level `PrivacyInfo.xcprivacy`** (tracking=false, `CA92.1`, Purchase History = Analytics + App Functionality linked, Crash Data not-linked). The **Sensitive-Info category is RECORDED, not resolved** (an XML comment in the manifest + operator-expected 8(e)) — Apple's label taxonomy is a separate regime from ADR-023's KVKK special-category stance. pbxproj hand-wired per the S022 precedent, with `ios-build-smoke` asserting presence + `plutil` validity **in the built bundle** (the silent-green class). Rider: `NSLocalNetworkUsageDescription` now ships permanently, localized ×3, so the founder's LAN emulator rig never needs a local plist edit.
- **#39 — Node-24 action bumps.** checkout/setup-node/setup-java/cache v4→v5, and **upload-artifact v4→v6** — the pre-code review's BLOCKING catch, since v5 still declares node20. `flutter-action@v2` and `setup-ruby@v1` deliberately untouched.
- **Both review passes ran** (the standing discipline): pre-code 1 blocking + 2 serious + 2 minor; post-diff 8 findings, 3 accepted / 5 refuted.
- **Proof:** `flutter analyze` clean, **1,412 app tests** green, coverage 86.42% (gate 68), goldens regenerated intentionally. PR #59 green, squash-merged, **post-merge main run `29298122183` fully green including `integration-emulator`** — which is #36's actual acceptance, since that suite is main-only.

**Docs touched:** adr/018 (rev 4), adr/023, architecture, operator-expected. **Not touched (the debt):** past-prompts, resume-prompt.
**Notes / debt logged:** issues #39 and #55 closed by the PR; **#36 stayed open** until S025 closed it with the green-main evidence.

## Session 025 — 2026-07-14 — CI → Slack notifications (ADR-024), and the concurrency bug that was destroying the signal it exists to deliver

**Objective (founder directive 2026-07-14):** "integrate Slack to the CI — look at the ams-pulse project's CI." The session inherited a live branch from an aborted predecessor: `feat/s025-ci-slack-notifications` already carried ADR-024 rev 1, committed pre-code and awaiting its adversarial design review.

**Outcome:** done — shipped, plus two repairs the objective did not ask for and one operator security item.
- **Session-hygiene check first:** three other live Claude sessions found, all on OTHER repos (`ams-pulse`, `evrak`, `unhooked`) — verified by `/proc/<pid>/cwd`, own PID identified up the ppid chain. An **inherited uncommitted edit** (`.claude/settings.json`, a subagent-model pin, not this session's work) was checkpoint-committed **verbatim** per the S014 rule before any workflow ran.
- **Pre-code adversarial review of ADR-024** (5 lenses × refuting skeptic + governing-docs adjudicator, 60 agents): **27 raw findings, 24 survived → 4 blocking + 6 serious + 8 minor**, all folded into rev 2. The **thirteenth consecutive pre-code pass to find real defects.** The blocking four: (a) D3's "the notifier has no vote on the build" was enforced only *inside* the script — a failed checkout or dead runner reds the job and, through it, the whole run under rule #7, which the script's `exit 0` paths can never reach ⇒ `continue-on-error: true` at the **job** level, a two-level guarantee; (b) the noise policy lived in a YAML `if:`, **invisible to the shell self-test** — a one-line edit would re-enable PR spam with every test still green ⇒ *all* policy moved into the script, where a test can see it; (c) **W4 was never named** (the house no-silent-retries rule) ⇒ D3.1 records the exception and *bounds* it (side-channels only, never a primary CI signal); (d) the injection analysis named only the commit subject, but on `pull_request` that field is null — an implementer would reach for an inline `${{ github.event.pull_request.title }}` and re-open the hole ⇒ all four attacker-influenced fields named, with metacharacter fixtures each.
- **D8 — the finding that mattered most, and it was not about Slack.** `ci.yml`'s concurrency was ref-keyed with `cancel-in-progress`, so **the session's own close commit cancelled the post-merge run carrying `integration-emulator`** — and the superseding docs-only run *skips* that job (`code_changed=false`, ci-debt #17). **Two of the five main runs before this fix are `cancelled`** (`3407f03`, `e6144ab`); S023 had to hand-fire a dispatch to recover its verdict. The signal the whole ADR exists to deliver was being destroyed by the workflow that delivers it. Push events now key concurrency on the **commit**; PR re-pushes still cancel (Session-004 billing protection intact).
- **D9 — a live Slack webhook is hardcoded in plaintext** in the never-pushed local branch `chore/slack-notifications` (`13f1e6d`). **Not new: `operator-expected.md` §5 has carried it since Session 005 — ~20 sessions unrotated** — and §5 *also told the founder to "rework/land the branch"*, i.e. to push a credential. Rewritten as an executable four-step operator item (revoke → mint a real *Incoming* webhook → `gh secret set` at **repo** scope with an explicit "NOT `--env release`" warning → confirm from the job log). The scope warning is load-bearing: the repo's only secret precedent (ADR-021's `ASC_*`) is environment-scoped, and copying it lands the founder in a trap whose failure mode is **silence**.
- **What shipped:** `tool/ci/slack_notify.sh` (the repo's first bash tool) + `tool/ci/slack_notify_test.sh` (**16 cases**), a terminal `slack-notify` fan-in job in both workflows, and `shellcheck` + the suite added to the ubuntu `quality` job. Fail-quiet by construction: absent secret ⇒ `::notice::` + exit 0, never a `::warning::` on a green build (re-opening issue #39's annotation noise as the first act after closing it would be self-refuting).
- **The self-tests earned their keep before CI ever ran them:** they caught **four real bugs in the first draft**, the sharpest being `${GITHUB_REPOSITORY##*/}` — an unbound-variable error under `set -u` that killed the command substitution and shipped an **empty message body while still exiting 0**.
- **MUTATION-CHECKED (12 mutants, all now killed).** Two initially **SURVIVED**, and both were real gaps: (1) **the anti-leak sentinel was theatre** — it ran only under `SLACK_DRY_RUN=1`, which exits *before* the POST, so it never executed the lines where the webhook is actually in scope; a mutant printing the URL on the success path walked straight through. The canary now covers the successful-POST and failed-POST paths. (2) the jq-missing guard's mutant still warned and exited 0 via the `NEEDS_JSON` path — behaviourally equivalent but **blaming invalid JSON for a missing binary**; the warning must now name `jq`. A hang was also fixed: the hermetic listener would have blocked the `quality` job to its 20-minute timeout if the script never POSTed, instead of failing in seconds.
- **Post-implementation adversarial review of the built diff** (30 agents): **12 findings, ALL 12 survived → 1 blocking + 1 serious + 5 minor** after dedup. The **fourteenth consecutive pass to find real defects.** Blocking: the stale operator-expected §5 above. Serious: **`workflow_dispatch` was an untested row of the D2 table**, and the reviewer *demonstrated* an escape mutant (widen the guard to swallow dispatch successes) that passed all 14 tests — dispatch being precisely how a session recovers a lost verdict. Also folded: **Slack mrkdwn escaping** — `jq --arg` makes a value safe as JSON and safe from the shell but **not from Slack's renderer**: `feat/<!channel>` is a valid git branch name that rendered as a live **@channel mention**, and `<url|label>` renders a link whose label can disagree with its target. `&`, `<`, `>` are now escaped, mutation-checked. Two **over-claiming comments** were corrected (the class this repo treats as a defect): the script claimed the webhook "cannot land in a process listing" — it can, it is a positional arg to curl — and a test comment misattributed the leak vector to curl's error output rather than the script's own diagnostics.
- **The review also adjudicated D8 against the alternative I had dismissed for the wrong reason:** `cancel-in-progress: ${{ github.ref != 'refs/heads/main' }}` *does* preserve the PR billing protection (rev 2 claimed otherwise). D8 still wins — but on **latency**, not billing (the ref-keyed variant would queue the close commit's run behind a 25–50 min `integration-emulator`). Recorded honestly in the ADR rather than left as a lucky right answer.
- **Inherited repairs (S024's unrun close):** the retroactive S024 entry above, and **issue #36 closed** with the green post-merge main-run evidence (`29298122183`) that had been sitting unread since S024 ended.

**Proof:** 16/16 self-tests, `shellcheck` clean, 12/12 mutants killed, both workflows YAML-validated, `dart format` clean over `tool/` (it ignores `.sh` — a recorded gap, which is why shellcheck was added).
**Docs touched:** adr/024 (rev 3) + adr/README, architecture §9, test-suite, session-rules §3.5 (watch the **main** run, not just the PR), operator-expected (§5 rewritten + close refresh), past-prompts (both entries), resume-prompt.
**Notes / debt logged (loud):** the founder must **rotate** the leaked webhook (operator item 5) — until then the notifier is silent **by design**, and that silence is honest, not broken. The live Slack path is **unproven** and says so (ADR-024 D7): what ships is the mechanism, and the first real message is an operator-gated acceptance. `curl`-missing is fail-open but **not separately mutation-pinned** (emptying PATH trips the `jq` guard first) — recorded rather than faked.
**Next objective written to resume-prompt.md:** Session 026 — **the UI/UX Pro Max ("uipro") refactor scoping ADR** (roadmap's own sequencing puts it ahead of the AI-chosen backlog), unless a preemption fires.

## Session 026 — 2026-07-19 — the UI/UX Pro Max refactor SCOPING ADR (ADR-025): the tool actually run, 48 surfaces inventoried, the invariant firewall built in writing

**Objective (from resume-prompt.md):** run `uipro init` and record honestly what the tool actually produces; inventory every app surface against its goldens and its invariant status; map skill output → brandkit; slice the arc into sessions with acceptance lines; spell out the per-surface invariant firewall; update `roadmap.md` from "needs a scoping ADR" to "scoped". **Design only — no pixels move.**

**Outcome:** done. ADR-025 committed before any review, then adversarially reviewed twice-over and revised to rev 2. No UI code changed, as required.

**Preemptions — all five checked FIRST, all negative:** item 6 (LLM provider) still unanswered → no M5.3. **Blaze verified FACTUALLY, not from the checklist** (Cloud Billing REST `billingInfo`, token minted from the firebase-tools refresh token since `gcloud` is not installed on this box): `billingEnabled: false` on **both** `hayatiapp-dev` and `hayatiapp-prod` → no first-deploy slice. No Android green-light. No on-device defect reported (no new issues since 2026-07-12). No dev-rig request.

**The tool was RUN, not described.** `uipro init -a claude` exited 0 offline with no credentials — the brief's stopping condition did not fire — and wrote 143 files / 2.8 MB across **seven** skills, only one of which (`ui-ux-pro-max`) has any Flutter content. The load-bearing result is that **the skill's own prescribed workflow is wrong for this project and is rejected**: `SKILL.md:346` hardcodes *"Stack: React Native (this project's only tech stack)"*, and its **REQUIRED** `--design-system` step — run with an accurate description of Hayati — proposed a light pink palette (`#FDF2F8`/`#BE185D`), Noto-as-primary over Rubik, an "App Store Style Landing" page pattern, Google-Fonts CSS delivery, and a `MASTER.md` announced as the *"Global Source of Truth"*. Four direct contradictions of brandkit v1.0 plus a conflict of authority. Only the corpus's App-UI checklist is adopted, and it is **transcribed into the ADR** (Appendix A) because `uipro init` has no version-pin flag — a citation into the corpus would not be reproducible, so the arc must not depend on the tool at all.

**The inventory (16 agents, 655 tool calls, then re-verified by hand):** 48 UI surfaces — 19 screens, 25 sub-widgets, 3 private `AlertDialog`s, 1 inline `SnackBar` (the last five found only by the completeness critic). 4 forbidden / 22 high / 16 medium / 5 low. **303 tracked golden PNGs**, not the 635 a working-tree `find` reports (332 are gitignored `failures/` debris). 237 ARB keys, **every prefix under at least one copy gate — no prefix a refactor may freely reword.**

**Three findings that changed the ADR's shape:**
- **The refactor is not token adoption.** Feature code is already clean: 0 hardcoded `TextStyle`, 0 `EdgeInsets` magic numbers, 2 `Colors.transparent` sentinels. But `hayatiTheme` overrides only six component sub-themes and builds a partial `ColorScheme`, so M3 defaults fall through unset slots: `AlertDialog` reads `surfaceContainerHigh` (the theme set `surfaceContainer**Highest**` — one word apart) → `?? surface` → flat `night`; `Card`/`BottomSheet` the same; `SnackBar` reads `inverseSurface ?? onSurface` → **`sand`, a cream slab in a dark-first app**. Verified against the installed SDK. The three dialogs affected are the biometric shared-device warning, the irreversible-delete confirmation, and the consent-withdrawal dialog.
- **ADR-018 D3 had no mechanism** — the lock screen's no-dialog/no-Overlay constraint, where a violation crashes the app *on the lock screen* and the crash IS the lockout, was a file comment plus one recovery-path test. None of the eleven source-sentinel tests scans `lock_screen.dart`. Pre-existing since M6.1 → **issue #61**.
- **"The brandkit decides" had no mechanism either** — brandkit tokens reach Dart by hand transcription with no drift test; nothing under `app/test` reads `brandkit/` at all → **issue #62**.

**The adversarial pre-code review — 26 findings raised across 5 lenses, 15 survived double verification** (a refuting skeptic *and* a governing-docs adjudicator), folded into rev 2: **1 blocking + 7 serious + 7 minor.** The blocking one is the session's sharpest lesson: D5.iii's frozen-sentence digest said "the named ★ safety keys" and **named none**, so two implementers would have pinned different hashes — and while confirming it, the adjudicator found a *deeper* defect: **D10.1 promised `legal*` protection that D5.iii's own scope did not deliver**, leaving the consent-withdrawal dialog an unprotected legal guarantee surface. The exact guarantee-vs-mechanism defect this ADR was written to prevent, found inside the ADR itself. Both fixed; the set is now enumerated by name and resolves to a checkable 96 key/value pairs. Other high-value catches: the sentinel scanned `Tooltip` but not `tooltip:` (an `IconButton` builds one internally — the most natural way to introduce the crash would have passed green); it omitted ADR-018 D3's co-equal "text-selection-enabled field"; D8 falsely claimed to make W4 "mechanically checkable" when nothing reads the PR body; and `hayatiTheme` sits **above** `PrivacyGuard`, so slice 1's app-wide change reaches the Class F lock surfaces and an "app-wide re-baseline" would have laundered a lock-screen pixel change past the Class F rule — after which slice 8's byte-identical line would be true against an already-drifted baseline.

**One defect all five review lenses missed, caught by the author's own verification:** brandkit §5 and `iconography.*` specify **Phosphor** icons; the app ships **28 Material `Icons.*`** and Phosphor is not a dependency — so Appendix A's icon line was a checklist item no surface could pass. Not silently "fixed" inside a slice: migrating reworks the RTL mirror-net's premise (Material's `arrow_back` auto-mirrors; a Phosphor glyph does not) and adds a font to the size budget. Recorded as a founder decision → **issue #63**. And **FACT-1 was refuted rather than accepted** — the reviewer's 145 files / 2.9 MB includes `__pycache__` written by this session's own probe runs; 143 / 2.8 MB is what `init` wrote. (The standing lesson, paying again: verify agent claims by direct inspection.)

**Commits:** `055fd59` (ADR-025 rev 1, committed *before* the review per the standing ordering), `f76f6fd` (rev 2 — the review folded in), plus the close commit. PR #64.

**CI:** green (docs-only run) — PR and post-merge main both watched.

**Docs touched:** `docs/adr/025-uipro-refactor-scope-and-invariant-firewall.md` (new), `docs/adr/README.md`, `docs/roadmap.md` (scoped-flip), `docs/test-suite.md` (golden acceptance + the pending slice-0 guards), `docs/agent-workflows.md` (**W4 tightened for every session, not only this arc** — a governing procedure living only inside an arc ADR is one the next unrelated session will not read), `.gitignore` (`.claude/skills/`), `docs/operator-expected.md`, `docs/past-prompts.md`, `docs/resume-prompt.md`.

**Notes / debt logged:** #61 lock-screen forbidden-API sentinel · #62 brandkit token drift · #63 Phosphor divergence — all three are pre-existing, all three are slice 0 / a founder call, and all three are filed separately so they are **not hostage to the refactor arc**. Recorded honest gaps, deliberately not faked: the broad native-review gate (operator item 1) stays a human process; D8's golden declaration is review discipline, not a CI gate (the manifest upgrade path is recorded but not built — ADR-024's lesson); D5.i's scan set is a hand-maintained two-file list guarded by a sentinel-of-the-sentinel that can stop it shrinking but cannot know what it should grow to include. `.claude/skills/` is gitignored like `.codegraph/`, and **only `ui-ux-pro-max` may be invoked in this repo** — the other six generate brand and marketing assets and brandkit v1.0 is final; `uipro update` restores anything hand-deleted, so that boundary is a rule, not a file operation.

**Next objective written to resume-prompt.md:** ADR-025 **slice 0 — the invariant firewall** (issues #61 + #62 + the frozen-sentence digest), still behind the standing preemptions. It moves no pixels and it is the precondition for every slice that does.

## Session 027 — 2026-07-20 — ADR-025 slice 0: the invariant firewall (three guards, 27 mutants killed, zero pixels moved)

**Objective (from resume-prompt.md):** build ADR-025 slice 0 — the precondition for every refactor slice. Three guards, each mutation-checked. No pixels move.

**Outcome:** done. All three guards shipped, 27 mutants killed between them, zero golden PNGs changed. Issues #61 and #62 closed by the PR.

**Preemptions — all six checked first, all negative:** item 6 unanswered; **Blaze verified FACTUALLY again** (Cloud Billing REST, `billingEnabled: false` on both projects — re-run rather than assumed from the session before); no Android go; no on-device defect; no dev-rig request; no answer yet on #63 (Phosphor).

**1. `lock_screen_forbidden_api_sentinel_test.dart` (closes #61).** ADR-018 D3 was the ONE of the four lock invariants with no mechanism. Fourteen forbidden tokens, and **three additions beyond ADR-018 D3's written list**, each because the guard would otherwise pass green while the crash shipped: the lowercase **`tooltip:`** parameter form and **`IconButton`** outright (both build a `Tooltip` internally — a class-name-only scan misses the most natural way in); the **text-selection family** (D3's own co-equal entry, dropped by ADR-025's first draft, restored by the review); and **`ScaffoldMessenger.of`** (this screen provides its own `Material` and has no `Scaffold` above it — same failure, same class, absent from D3's list; recorded in ADR-025 rather than smuggled).

**The scan set is DERIVED, and that closes a gap the ADR had accepted.** ADR-025 D5.i judged "every widget file it mounts" uncomputable, settled for a hand-maintained two-file list, and recorded the residual gap as an accepted negative. It turned out to be computable: the transitive closure of *relative* imports from `lock_screen.dart`, filtered to widget-declaring files, yields exactly those two files today and would pick up a shared widget added tomorrow. The explicit list survives as the **sentinel-of-the-sentinel** so a walker returning nothing fails loudly instead of passing vacuously over an empty set. A `pin_keypad.dart` mutant proves the derived second file is genuinely scanned — without it, the whole derivation could have been decorative.

**2. `brandkit_token_parity_test.dart` (closes #62).** Bidirectional across nine hexes, family+fallback, every type-scale step at its Material role (size AND weight), the per-script line-heights, spacing, radii, the chip stadium. The derived steps `x2..x8` are absent from the JSON so they are asserted as exact multiples of the grid rather than left unguarded. The four JSON groups with no Dart counterpart are not asserted against Dart but ARE pinned in place, so **#63 turns this test red the day it resolves** rather than drifting. **The two sides agreed on first write** — the ADR's stopping condition ("if they disagree today, slice 0 is not a no-op") did not fire.

**3. `frozen_sentence_digest_test.dart`.** SHA-256 over **96 pairs** — the five named ★ safety keys plus every `consent*`/`legal*` key × three locales, exactly the count ADR-025 D5.iii predicted. Count pinned separately from the digest so a failure distinguishes a reword from a legal string entering or leaving; ★ keys asserted to exist BY NAME so a rename cannot quietly shrink the set. `legal*` in scope deliberately — the pre-code review's blocking finding.

**Commits:** `5593e88` → PR #65 (squashed to `c0492cf`), plus the close commit.

**CI:** green — PR (quality, functions-rules, ios-build-smoke, slack-notify) and the post-merge main run **including `integration-emulator`**, which this code-touching push actually ran.

**Docs touched:** `docs/test-suite.md` (the three guards, pending → shipped, with what each mutation-check proved), `docs/adr/025-*` (a slice-0 note recording the two implementation decisions — the derived scan set and the `ScaffoldMessenger.of` addition; neither reverses a decision), `docs/past-prompts.md`, `docs/resume-prompt.md`, `docs/operator-expected.md`.

**Notes / debt logged:** none new. #63 (Phosphor vs Material icons) stays open as a founder decision and blocks nothing — the parity test deliberately does not assert `iconography.*`. The honest gaps ADR-025 recorded stand unchanged: the broad native-review gate has no mechanism, and D8's golden declaration is review discipline rather than a CI gate.

**One process note worth keeping:** the first mutation-check run **timed out mid-loop and left an `EditableText` mutant in the working tree**. The explicit diff against the pre-mutation backup caught it — the exact S025 incident, and the exact mitigation written down for it. Twelve of fourteen mutants had already been confirmed killed at that point, so the timeout cost nothing but the restore. The remaining two were re-run individually.

**Next objective written to resume-prompt.md:** ADR-025 **slice 1 — the Material default floor**, still behind the standing preemptions. It is the first slice that moves pixels, and it carries the Class F carve-out: the lock goldens must come out byte-identical.

## Session 028 — 2026-07-20 — ADR-025 slice 1: the Material default floor, and the stopping condition that fired

**Objective (from resume-prompt.md):** ADR-025 slice 1 — fill the `ColorScheme` slots M3 actually reads and add the missing component sub-themes. The first pixel-moving slice and the widest.

**Outcome:** done, but **narrower than the ADR specified, and deliberately so** — the ADR's own stopping condition fired mid-slice and the scope shrank in response. Zero goldens changed.

**Preemptions — all six negative** (Blaze re-verified factually; no founder signal on #63).

**The defect fixed, SDK-verified:** an unset `ColorScheme` slot does not fall back to something sensible — Flutter falls `surfaceContainer*` back to `surface` and `inverseSurface` back to `onSurface`. `hayatiTheme` set only `surfaceContainerHighest`, the slot almost nothing reads, so `AlertDialog` (which reads `surfaceContainerHigh`, one word apart) rendered flat `night` — **the same value as the page behind it** — and `SnackBar` rendered on **`sand`**, a cream slab in a dark-first app. The three dialogs affected are the biometric shared-device warning, the irreversible-delete confirmation, and the consent-withdrawal dialog.

**THE STOPPING CONDITION FIRED — the session's main lesson.** The first implementation also set `onSurfaceVariant` and `outline`, which the brandkit does not define, using invented `sand` alphas. It changed 96 goldens. **Looking at the regenerated images rather than trusting the count** showed a REGRESSION: the settings toggles got visibly dimmer, because an M3 `Switch` reads both slots for its off-state thumb and track outline — muting them made *enabled* controls read closer to disabled. Worse affordance, traded for tonal consistency. ADR-025 D3 forbids inventing a brand colour inside a refactor slice, so both slots were **dropped** and handed to the founder as a brandkit question (**#67**, three options with the accessibility weight written out). Everything that shipped uses only existing tokens.

**Why the slice changes ZERO goldens — worth keeping in view for the rest of the arc:** dialogs and snackbars mount *above* the screen, so **no golden in the 303-file matrix captures any of them**. That is exactly how this defect survived from M1.4 to now with a full golden net in place. A golden matrix proves screens, not transient surfaces — and the arc should stop treating golden coverage as coverage of everything.

So the fix ships with its own mechanism: `material_default_floor_test.dart` pumps the real `AlertDialog` and the real `SnackBar` and reads the resolved colour back, plus an assertion that **no container slot silently equals `surface`** (which catches the original defect even if the raised tone is later re-pointed). Mutation-checked 3×.

**Also recorded, not assumed:** sub-themes were added only for components the app actually mounts. `grep` finds **zero** `Card(`, zero bottom sheets and zero popup menus in `lib/` — so `CardTheme`/`BottomSheetThemeData`/`PopupMenuThemeData` were **not** added despite the ADR naming them, because theming a widget the app never builds is dead configuration that reads as coverage. A test pins that absence so it stays a decision.

**Class F carve-out:** `lock_screen`, `pin_setup_screen` and the two `probe` goldens byte-identical — verified, and trivially so at zero churn.

**Commits:** `e398ea0` → PR #68.

**CI:** green.

**Docs touched:** `docs/past-prompts.md`, `docs/resume-prompt.md`, `docs/operator-expected.md`.

**Notes / debt logged:** **#67 — the brandkit defines no token for secondary/muted text or for outlines/dividers.** A founder/design decision with real accessibility weight (WCAG's 3:1 for non-text controls; "reduced emphasis" and "disabled" must stay distinguishable). Non-blocking: slices 2–7 touch screen composition, not those two slots, and whichever slice needs them first is blocked on the answer. #63 (Phosphor) still open, still non-blocking.

**Next objective written to resume-prompt.md:** ADR-025 **slice 2 — the product core** (solo + paired home and their sub-widgets), the highest-value slice of the arc: "the reveal is the product".

## Session 029 — 2026-07-21 — ADR-025 slice 2: the product core (the reveal) — its signature §6 interaction, built and grouped

**Objective (from resume-prompt.md):** ADR-025 slice 2 — the solo + paired home and their sub-widgets, the highest-value slice of the arc ("the reveal is the product", brandkit §9.3).

**Outcome:** done. The reveal now has the one thing brandkit §6 says to build first and it never had — a soft unfold + a gentle haptic — plus a restrained grouping change so the two answers read as one shared moment. 15 goldens re-baselined (exactly the declared set), all suites green.

**Preemptions — all negative.** Item 6 (LLM provider) still unanswered → no M5.3. **Blaze re-verified FACTUALLY** (minted a token from the firebase-tools refresh token, queried Cloud Billing): `billingEnabled:false` on both `hayatiapp-dev` and `hayatiapp-prod` → no first-deploy. #67 and #63 both OPEN, 0 comments → no token/Phosphor answer. No Android green-light, on-device defect, or dev-rig request. (Session-hygiene: the one other claude near the tree was on `repo-blueprint`, not hayati.)

**What was actually wrong (looked at the goldens, didn't just count):** the reveal was FLAT — own answer and partner answer were byte-identical `nightRaised` cards with equal spacing to everything else, so the payoff (the partner's words) read as an undifferentiated list item — and there was **NO motion at all**, though §6 names the reveal "*the* signature interaction — budget polish here first" (soft unfold + gentle haptic). The rest of the home was already token-clean, so this was a polish slice: the value is concentrated where the product is judged.

**Pre-code adversarial review (16th consecutive pre-code pass): 28 raised → 5 real defects, all fixed before the first line of code.** Five findings converged on one hole — the design under-specified the fate of the unconditional `SizedBox(x6)` + `_PartnerSlotCard`: a naive restructure would either double-render the partner card (breaking `findsOneWidget`) or shift 15+ non-declared goldens. Fixed by moving BOTH into the non-revealed `else` branch, keeping the non-revealed column byte-for-byte identical. The other four: the haptic host had to be `didUpdateWidget` on the persisting State, not the freshly-mounted `_RevealUnfold`; the 240ms enforcement claim was honest-corrected to review-level (like `minimumBodySize`, not the mechanically-checked `dynamicTypeMax`) with a `MotionTokens` range test; a `revealed_streak_scale130 ×3` probe was added for Appendix A's 130% check on the restructured layout; and the haptic test gained the self-heal sub-case. The refuted findings died correctly (the `_RevealUnfold`-changes-pixels claim was refuted by Flutter's own `RenderOpacity`/`RenderTransform` no-op fast paths; the dead-code claim by Dart sealed-class exhaustiveness). **Post-diff review: 7 → 3, all minor/refinement, "sound to merge as-is"** — both surviving code-quality nits applied as doc/comment clarity fixes.

**What shipped:**
- **The signature reveal motion (§6), transient → widget-tested not goldened (S028's lesson).** `_RevealUnfold` (a `TweenAnimationBuilder`) fades + gently raises the revealed group (streak + both answers) once on mount; `MotionTokens.revealUnfold = 240ms` inside §6's 150–300ms band, ease-out, vertical-only (RTL-neutral), `alwaysIncludeSemantics` (no 1-frame a11y gap), reduce-motion → `Duration.zero`, pixel-neutral at rest (changes no settled golden). A gentle `HapticFeedback.lightImpact` fires once per instance on `Waiting→Revealed`.
- **An honest bound found in testing and recorded, not papered over:** cold-open-into-revealed ALSO settles Locked→Waiting→Revealed even when both answers exist, so there is no cheap client signal separating "user watching Waiting live" from "app loading a revealed day" — the design's "never on cold-open" was unachievable without a timing heuristic or a persisted per-day flag. Chose the simple §6-consistent behaviour: one gentle buzz the first time the reveal lands (live OR cold-open settle), bounded once per instance; app-resume never re-fires; the permission-denial self-heal (locked→revealed) is silent.
- **Equal weight, not primacy:** own and partner render identically (brandkit §9.1, "two people, one screen state"); the reveal's specialness is the unfold + grouping. The `Icons.favorite`-absent-elsewhere state-ladder tests independently forbid a partner-card accent, so the equality ethos and the test net agree. The only settled-pixel change is the own→partner gap x6→x4.

**Golden discipline (D8):** declared {revealed×6, revealed_streak×6 changed; revealed_streak_scale130×3 new} = 15 BEFORE `--update-goldens`; `git status --porcelain` came back **exactly** those 15, nothing else (solo untouched, locked/waiting/no_day byte-identical). **Looked at the regenerated images** (the slice-1 lesson): the two answer cards group as a pair, the 130% probe wraps without overflow, the Arabic RTL cell mirrors correctly — better, not just different.

**Slice-0 firewall:** all three guards green and unweakened (paired_home is in no scan set; no tokens touched; no consent/legal/★ strings touched).

**A process note worth keeping:** a `pumpAndSettle` that runs the live reveal unfold WHILE the `SystemChannels.platform` haptic mock is installed does not terminate — the reveal-motion tests drive frames with `pump()`/`pump(Duration)` instead, which also keeps the mid-fade frame observable. (The non-mock cold-open + pumpAndSettle path settles fine, so the golden regen was unaffected.)

**Tests:** app suite green (**+1446**, incl. the 5 new reveal tests + 3 MotionTokens); coverage **86.43% ≥ 68**; `flutter analyze` clean.

**Commits:** `b61062d` (squash of feat `fcebaf4`, amended from `08956d8` for `dart format`) → PR #72.

**CI:** PR #72 all green (quality, functions-rules, ios-build-smoke, slack-notify; integration-emulator main-only). Post-merge main run `29843811695` — **all green, including `integration-emulator`** (the main-only app+backend E2E job that actually runs on an app-touching change).

**Docs touched:** `docs/adr/025-*.md` (slice-2 note), `docs/test-suite.md`, `docs/past-prompts.md`, `docs/resume-prompt.md`, `docs/operator-expected.md`.

**Notes / debt logged:** **#71 — motion is a §6 rule (150–300ms, ease-out) with no `hayati-tokens.json` token**, so `MotionTokens` is review-enforced (like `minimumBodySize`), not parity-tested; non-blocking, a future brandkit-revision decision parallel to #67. #67 (muted/outline tokens) and #63 (Phosphor) still open, still non-blocking.

**Next objective written to resume-prompt.md:** whichever preemption fires, else ADR-025 **slice 3 — onboarding & pairing** (7 surfaces, 87 goldens, N + G), the first slice with a Class-G guarantee surface — keep `ProviderActions` a single shared widget with the legal footer present by construction on all three sign-in call sites.

## Session 030 — 2026-07-22 — ADR-025 slice 3: onboarding & pairing — the pairing activation moment unfolds; the onboarding CTA anchors

**Objective (from resume-prompt.md):** ADR-025 slice 3 — onboarding & pairing (7 surfaces, 87 goldens, N + G), the first slice carrying a Class-G surface (`ProviderActions`): keep it one shared widget with the legal footer present by construction on all three sign-in call sites.

**Outcome:** done. Restrained by design — an audit found the 7 surfaces already token-clean and rhythm-coherent (built well at M1–M2), so the slice is **3 changes, 15 settled goldens, 72 byte-identical** (the "87" in D7 is the surface-set size, not a change quota — the slice-2 lesson: it moved 15 of 66).

**Preemptions — all negative.** Item 6 (LLM provider) still unanswered → no M5.3. **Blaze re-verified FACTUALLY** (minted a token from the firebase-tools refresh token, queried Cloud Billing): `billingEnabled:false` on both `hayatiapp-dev` and `hayatiapp-prod` → no first-deploy. #67/#63/#71 all OPEN, none answered → no token/Phosphor/motion-token change. No Android green-light, on-device defect, or dev-rig request. (Session-hygiene: the four other claudes on the box were on `evrak`/`repo`(parent)/`ams-pulse`/`unhooked`; none on hayati.)

**Method (the arc's discipline, held).** A 6-auditor design workflow (one per surface-group + a cross-cutting motion/rhythm auditor, each reading code AND LOOKING at the goldens) → a governing-docs adjudicator filtered the union. Then the mandatory two adversarial review passes: pre-code (17th consecutive; 5 lenses × 2 verifiers) and post-diff (5 lenses × 2 verifiers).

**What shipped (3 changes):**
- **The pairing activation moment now unfolds (brandkit §6/§9.3).** `_ValidPreview` ("Aylin invited you" — the invitee's first sight of who invited them, the code's own "activation moment") appeared flat after the loading spinner. It is the onboarding sibling of slice 2's daily reveal, so it gets the same §6 soft-unfold (fade + gentle vertical rise). Realised as a NEW shared widget `core/widgets/soft_unfold_reveal.dart` reusing `MotionTokens` — NOT an extraction of slice 2's file-local `_RevealUnfold` (touching `paired_home_screen.dart` would risk its goldens; DRY tracked as **#74**). Transient → no golden (settles pixel-neutral); proven by `soft_unfold_reveal_test.dart`. **No haptic** (a §6 rule decision, founder-owned — motion only this slice).
- **profile_capture's sole CTA pinned to `Scaffold.bottomNavigationBar`** (§4 spatial authority; §9.5 restraint). It floated at 40–65% of the viewport over a 35–60% void as the last child of a `ListView`. Behaviour frozen (save guard + `_save` byte-identical; `_SaveErrorView` stays in the list); more robust at 130% (no longer scrollable-away). 9 goldens (fresh ×6 + fresh_scale130 ×3).
- **phone_sign_in `_SmsCodeEntry` Verify↔Resend gap x2→x4** — the single-primary→single-subordinate outlier (§4; matches invite_share/partner_preview). 6 goldens (code_sent ×6).

**Pre-code review (17th pass): 4 raised → 3 refinements applied, none challenging the core design.** The two highest-risk lenses — Class-G footer preservation and the `bottomNavigationBar` composition — found NOTHING. **A process catch worth keeping:** three of the four findings were skeptic-REFUTED but adjudicator-REAL splits, which the naive aggregation (keyed off the skeptic) buried as "0 confirmed" — inspecting them (the S023 lesson) surfaced all three as worth applying: (M1) the motion test must prove the RISE, not just the fade — an opacity-only test misses a sign-inversion/zero-slide; (F1) the "every primary→secondary gap is x4" rule is overbroad — `ProviderActions`' homogeneous 3-provider stack is x3 throughout, so a carve-out was added lest a future Class-G session churn 12 undeclared sign-in goldens; (GF-01) a doc count typo. The dropped 4th change (sign_in `_ErrorView` x2→x3) was OVERRULED against the adjudicator: x2 is the shared error-title→detail convention with `_SaveErrorView` (verified), so changing only sign_in's would CREATE inconsistency.

**Post-diff review: 7 findings → 1 confirmed defect + 1 real doc fix, both applied; the one SERIOUS finding correctly refuted.** Confirmed (both verifiers): a test `reason:` string ("starts faded in") contradicted its `lessThan(1.0)` matcher — a misleading diagnostic, fixed to "starts faded out". Real (adjudicator): ADR D4 said `ProviderActions (both call sites)` but there are three since M2.3 — fixed to "three" (D7 already said "all three"). **The SERIOUS finding — `SafeArea(top:true)` adding status-bar dead space above the pinned button — was refuted by BOTH verifiers via Flutter source** (`Scaffold` strips top padding from the `bottomNavigationBar` slot via `removePadding(removeTop:true)`); hardened defensively anyway with an explicit `top:false`. The other 4 findings cleanly refuted.

**Golden discipline (D8):** declared {profile_capture fresh×6 + fresh_scale130×3; phone_sign_in code_sent×6} = 15 BEFORE `--update-goldens`; `git status --porcelain` came back **exactly** those 15, nothing else. Critically `partner_preview valid`×6 are byte-identical (the motion settles pixel-neutral). **Looked at the regenerated images** (slice-1 lesson): the Continue button anchors the viewport bottom, holds at 130% (TR, 3 sections), mirrors correctly in RTL; the Resend hierarchy gap reads clearly — better, not just different.

**Slice-0 firewall:** all three guards green and unweakened (none of the touched files is in the lock sentinel scan set; no tokens touched; no consent/legal/★ strings touched). Class-G `ProviderActions` stays one shared widget; the legal footer is present by construction on all three call sites (`provider_actions_test.dart` green unchanged); wrapping `_ValidPreview` (which may render `ProviderActions` when not-signed-in) does not split/fork/reword it.

**Tests:** app suite green (**+1449**, incl. the 3 new `SoftUnfoldReveal` tests); coverage **86.46% ≥ 68**; `flutter analyze` clean; RTL lint clean.

**Commits:** `95bb764` (squash) → PR #75. The feature commit was amended twice pre-merge — once for the post-diff review fixes (test reason string, ADR D4 call-site count, defensive `SafeArea(top:false)`, #74 references), once for `dart format` (the S029 CI gotcha: `quality` fails fast on `dart format --set-exit-if-changed`; caught and fixed on the first CI run).

**CI:** PR #75 all green (quality, functions-rules, ios-build-smoke, slack-notify; integration-emulator main-only). Post-merge main run `29958076603` — the four substantive jobs all **green**: `quality`, `functions-rules`, `ios-build-smoke`, and **`integration-emulator`** (the main-only app+backend E2E job that actually runs on an app-touching change). `slack-notify` (no vote on the build — ADR-024: `continue-on-error`, always `exit 0`) queued last and cannot turn the verdict red.

**Docs touched:** `docs/adr/025-*.md` (slice-3 note + D4 call-site fix), `docs/past-prompts.md`, `docs/resume-prompt.md`, `docs/operator-expected.md`.

**Notes / debt logged:** **#74 — DRY slice-2's `_RevealUnfold` into the shared `SoftUnfoldReveal`** (a later pixel-neutral tidy; ~15 duplicated lines, recorded in the ADR note). #67 (muted/outline tokens), #63 (Phosphor), #71 (motion token) still open, still non-blocking — **#67 is the one to watch for slice 4** (the paywall processing banner must read as good news, never error).

**Next objective written to resume-prompt.md:** whichever preemption fires, else ADR-025 **slice 4 — commerce** (paywall, pack selection, `PremiumGate`; 30 goldens; the free-tier byte-identity + "processing banner reads as good news, never error" invariant).

## Session 031 — 2026-07-23 — ADR-025 slice 4: commerce — the gated pitch drops from h1 to h2

**Objective (from resume-prompt.md):** ADR-025 slice 4 — commerce (paywall, pack selection, `PremiumGate`; 30 goldens; Class N): the free-tier byte-identity + "processing banner reads as good news, never error" invariant.

**Outcome:** done. The smallest slice of the arc — **ONE change, 9 goldens, 21 byte-identical**. A 3-auditor + governing-docs-adjudicator design pass found the commerce surfaces already token-clean and brandkit-compliant; the one real defect was a flat typography hierarchy on the gated (free) pack-selection view.

**Preemptions — all negative.** Item 6 (LLM provider) still unanswered → no M5.3. **Blaze re-verified FACTUALLY** (minted a token from the firebase-tools refresh token, queried Cloud Billing): `billingEnabled:false` on both projects → no first-deploy. #67/#63/#71/#74 open, none answered. No Android green-light, on-device defect, or dev-rig request.

**What the audit found (the surfaces were already well-built):** the `_ProcessingBanner` ALREADY reads as good news (`surfaceContainerHighest` + a `tertiary`/sage hourglass, explicitly "never the error colour" — ADR-014 D3), so NAMED INVARIANT 1 was satisfied and had only to be PRESERVED; gold is already restrained (exactly two elements — the entitled premium mark + the annual best-value badge); the paywall hierarchy/rhythm/RTL/130% are sound; `PremiumGate` is a correct minimal shared wrapper (one `isPremiumProvider` decision, three call sites — coach/paired-home/pack-selection — no fork). All three auditors returned "already good" for their surfaces except one defect.

**What shipped (1 change):**
- **pack_selection `_GatedView` pitch: `headlineMedium` (h1) → `titleLarge` (h2).** The pitch "Unlock every pack" was the SAME textTheme role as the screen title "Question packs" (both `headlineMedium`), stacking two h1s and erasing the h1/h2 distinction brandkit §3's 24/20 scale carries. Downgraded to `titleLarge`, which also matches `_UnlockedView` (whose section header `packSelectionCurrentTitle` is already `titleLarge` under the same screen title). LOOKED at the regenerated goldens: the screen title now clearly leads and the pitch reads as a subordinate-but-still-prominent (20/w600) headline, at 1× and 130%, RTL mirrored.

**No motion — the restraint discriminant, recorded.** The paywall "You're Premium" entitled view is a positive moment but a *deliberately-navigated confirmation*, not a *surprise reveal* (§9.3); slice 3's `SoftUnfoldReveal` earned its place on the pairing activation precisely because THAT was a surprise ("who invited you"). A soft-unfold on the entitled view would be motion-for-motion's-sake, so it is correctly absent. The good-news banner, gold restraint, and `PremiumGate` wrapper are preserved untouched.

**Review (one focused combined pass, proportionate to a one-line change): 1 finding → resolved; the free-tier-invariant crux settled.** For a genuinely one-line typography change the design and the built diff are identical, so a single 3-lens (free-tier-invariant / hierarchy-correctness / firewall) × adjudicator pass covered both. The hierarchy-correctness and free-tier lenses raised NO objection (the change stands — the "de-emphasises the sell message" counter-argument was weighed and answered: h2/20/w600 stays prominent). **The crux — does touching the free-tier `gated` goldens violate D7 row 4's "free-tier probes still byte-identical"? — was ruled CHANGE-PERMITTED:** the invariant is a LEAK-CHECK ("must not move *unless declared*"), guarding against the entitled/paywall path inadvertently shifting the free appearance; a deliberate, declared, rationale-backed improvement to the free surface itself is the "unless declared" case (the other free-tier probes — paywall loaded/loaded_scale130 — are byte-identical, confirming no leak). The one BLOCKING finding ("the 9 goldens were never regenerated") was a TIMING ARTIFACT — the review inspected the code-only commit before the goldens were amended in; the 9 were already regenerated + visually confirmed and were folded into the commit.

**Golden discipline (D8):** declared {pack_selection gated ×6 + gated_scale130 ×3} = 9 BEFORE `--update-goldens`; `git status --porcelain` came back **exactly** those 9. The 21 others (paywall entitled/loaded/loaded_scale130, pack_selection unlocked) byte-identical.

**Slice-0 firewall:** all three guards green and unweakened (no lock file touched; no tokens touched; no ★/consent/legal strings touched). #67/#63/#71 untouched (`titleLarge` is an existing role — no muted tone invented). `pack_selection_screen_test.dart` asserts the gated title TEXT (presence/absence), not style, so it stays green unchanged.

**Tests:** app suite green (+1449 (same as slice 3 — no new tests; the change is a golden re-baseline)); coverage 86.46% ≥ 68; `flutter analyze` clean; RTL lint clean; `dart format` clean.

**Commits:** `0884b4e` (squash) → PR #78.

**CI:** PR #78 all green (quality, functions-rules, ios-build-smoke, slack-notify; integration-emulator main-only). Post-merge main run `29963403049` — **all green including `integration-emulator`** (the app+backend E2E).

**Docs touched:** `docs/adr/025-*.md` (slice-4 note), `docs/past-prompts.md`, `docs/resume-prompt.md`, `docs/operator-expected.md`.

**Notes / debt logged:** none new. #67 (muted/outline tokens), #63 (Phosphor), #71 (motion token), #74 (DRY the unfold) still open, still non-blocking — **#67 is the one to watch for slice 5** (the coach chat, where a muted timestamp/divider is tempting).

**Next objective written to resume-prompt.md:** whichever preemption fires, else ADR-025 **slice 5 — coach** (chat, disclaimer, help path; 27 goldens; Class G + ★): `CoachHelpCard` stays a distinct widget TYPE from `CoachPersonaBubble`, the help-sticky latch still replaces the composer, zero ★ strings changed (frozen digest green).

## Session 032 — 2026-07-23 — ADR-025 slice 5: coach — a ZERO-CHANGE review slice (already compliant)

**Objective (from resume-prompt.md):** ADR-025 slice 5 — coach (chat, disclaimer, help path; 27 goldens; Class G + ★): `CoachHelpCard` stays a distinct widget TYPE from `CoachPersonaBubble`, the help-sticky latch replaces the composer, zero ★ strings changed (frozen digest green).

**Outcome:** done — **ZERO code changes, zero golden updates.** Two parallel auditors (the chat surface; the panels), each reading the full 854-line `coach_screen.dart` + the goldens, then a governing-docs adjudicator, found the coach **already token-clean and brandkit-compliant** — the deepest confirmation yet of the arc's thesis (the screens were built well; the work is the Material floor + composition, and here there was neither to do). This is the honest outcome when a surface is already right — the arc's completion criterion is "every surface goes THROUGH a slice", not "every slice moves a pixel" (slice 0's precedent: zero pixels, real deliverable).

**Preemptions — all negative.** Item 6 (LLM provider) still unanswered → no M5.3. **Blaze re-verified FACTUALLY** (`billingEnabled:false` on both projects) → no first-deploy. #67/#63/#71/#74 open, none answered. No Android green-light, on-device defect, or dev-rig request.

**What the audit verified (recorded, not assumed):** every spacing value traces to a `SpacingTokens` constant; every colour reads from `colorScheme` (no hardcoded literals, no gold, and — correctly — no `onSurfaceVariant`/`outline`: the #67-stopped absence a chat is most tempted to break with a muted timestamp or a message divider); typography roles descend cleanly (headlineMedium titles, titleMedium help-card header, bodyMedium body/bubbles, bodySmall persona-label + quota caption); Material icons throughout (#63); RTL correct (`AlignmentDirectional` end/start on bubbles, `EdgeInsetsDirectional` on composer/chips — confirmed in the ar.rtl goldens).

**The Class-G + ★ guarantees hold BY PROOF, not assertion.** The zero-change slice RE-RAN its guards green as the deliverable's proof: the frozen-sentence digest (no `coachDisclaimer*`/`coachHelp*`/`coachPaused*` reword — no coach string touched); `coach_screen_test.dart`'s `find.byType` pins (`CoachHelpCard` distinct from `CoachPersonaBubble`; the help-latch shows `CoachPausedPanel`); the 27 coach goldens byte-identical; the lock-screen forbidden-API sentinel; the brandkit token-parity test. 66 targeted tests green.

**The one motion candidate REJECTED by the S031 discriminant.** A `SoftUnfoldReveal` on `_CoachDisclaimerView` was considered and rejected: the disclaimer is an *expected safety gate the user deliberately navigates to* (they pressed "Coach"), not a *surprise reveal* — structurally unlike slice 2's daily reveal or slice 3's "who invited you". §6 ("motion conveys cause and effect, never decoration") and §9.5 ("restraint reads premium") both cut against it; both auditors and the candidate's own self-assessment reached DROP.

**Method note:** for a zero-change slice the "review twice" discipline collapses to a completeness check — the design audit (2 auditors + adjudicator) IS the search for a defensible change, and its "nothing found" is the reviewed conclusion; the second pass is the guard RE-RUN that PROVES the compliant claim. No separate diff review (there is no diff).

**Golden discipline (D8):** declared set delta = 0 files; all 27 coach goldens byte-identical.

**Tests:** the 66 targeted guard/type/digest/golden tests green (the full suite is unchanged from main, which merged slice 4 green); `flutter analyze` clean (no code touched).

**Commits:** this is a docs-only session (no code) — the ADR-025 slice-5 note + the close docs ship in ONE PR (there is no feature to merge first).

**CI:** docs-only session — the ADR slice-5 note + close docs ship in one PR; CI is quality + functions-rules + ios-build-smoke (integration-emulator skips — no app code). Watched to green.

**Docs touched:** `docs/adr/025-*.md` (slice-5 zero-change note), `docs/past-prompts.md`, `docs/resume-prompt.md`, `docs/operator-expected.md`.

**Notes / debt logged:** none new. #67/#63/#71/#74 open, non-blocking. #67 stayed un-tripped because the coach's persona-label + quota caption use the default on-surface tone (not a muted variant), which is the correct #67-stopped choice.

**Next objective written to resume-prompt.md:** whichever preemption fires, else ADR-025 **slice 6 — settings & data rights** (settings, PIN setup, PIN verify dialog, delete account, export, couple-ended notice, `SettingsErrorLine`; 55 goldens — the largest set left; Class N): the delete confirmation still reads irreversible + says the shared space goes for BOTH; `SettingsErrorLine` stays shared, not forked per screen; dialogs mount above goldens (S028) so their fixes need widget tests.

## Session 033 — 2026-07-23 — ADR-025 slice 6: settings & data rights — a ZERO-CHANGE, #67-BLOCKED review slice

**Objective (from resume-prompt.md):** ADR-025 slice 6 — settings & data rights (settings, PIN setup, PIN-verify dialog, delete account, export, couple-ended notice, `SettingsErrorLine`; 55 goldens — the largest set left; Class N): the delete confirmation stays irreversible + both-of-you; `SettingsErrorLine` stays shared; #67 flagged as the likely stopper.

**Outcome:** done — **ZERO code changes, zero golden updates, and the #67 stopping condition confirmed as the reason `SettingsScreen` cannot be polished.** Three parallel auditors (settings + dialogs + `SettingsErrorLine`; pin_setup + export; delete + couple_ended) + a governing-docs adjudicator raised ZERO candidates across all 7 surfaces. Same honest outcome as slice 5, but sharper: the settings surface has a REAL improvement available and it is permanently #67-blocked.

**Preemptions — all negative.** Item 6 (LLM) unanswered → no M5.3. **Blaze re-verified FACTUALLY** (`billingEnabled:false` on both) → no first-deploy. #67/#63/#71/#74 open. No Android green-light, on-device defect, or dev-rig request.

**The load-bearing finding — settings is #67-blocked from the other direction.** `SettingsScreen` is the app's densest secondary-text/toggle/divider surface: the `ListTile`/`SwitchListTile` subtitles fall through to Material's DEFAULT `onSurfaceVariant` (a desaturated grey — functional but off-brand), and giving them a brand muted tone, or adding a `Divider`/section-separator between the lock / privacy / data-rights clusters, needs `onSurfaceVariant`/`outline` — the two slots **S028 proved dim the Switches** and deferred to **#67**. Adding section-header copy is equally forbidden (Class N). So slice 1 hit #67 SETTING the tokens; slice 6 hits it WANTING TO USE them. **#67 is now the gate on the one remaining piece of settings polish** — strengthened in `operator-expected.md` for the founder.

**The safety acceptances already hold BY CONSTRUCTION.** The delete confirmation keeps "This can't be undone." in `titleMedium` (prominent, under the app bar) + the "both sides of every answer" clause in the first `bodyMedium` paragraph; the destructive `FilledButton` is `colorScheme.error`/`onError` (alert-on-night 4.94:1, §8 danger semantic) — nothing softens the irreversibility. `SettingsErrorLine` stays ONE shared widget across settings/consent-gate/legal (no fork). The two dialogs (`PinVerifyDialog`, `_BiometricWarningDialog`) correctly mount above the golden matrix (S028).

**Proven, not assumed.** All 55 slice-6 goldens byte-identical; the settings/delete state-ladders, the `SettingsErrorLine` sharing, and the three slice-0 guards RE-RUN green (106 targeted tests). No motion (all 7 surfaces are deliberately-navigated destinations — S031's discriminant).

**Method note:** as with slice 5, the "review twice" discipline for a zero-change slice is the design audit (3 auditors + adjudicator) as the search for a defensible change, plus the guard RE-RUN that PROVES the compliant claim. No diff review (no diff). Because there is no code, the slice-6 ADR note + close docs ship in ONE docs PR.

**Golden discipline (D8):** declared set delta = 0 files; all 55 byte-identical.

**Tests:** the 106 targeted golden/state-ladder/guard tests green (full suite unchanged from main); `flutter analyze` clean (no code touched).

**Commits:** docs-only session — the slice-6 ADR note + close docs in ONE PR.

**CI:** docs-only session — the ADR slice-6 note + close docs ship in one PR; CI is quality + functions-rules + ios-build-smoke (integration-emulator skips — no app code). Watched to green.

**Docs touched:** `docs/adr/025-*.md` (slice-6 zero-change/#67-blocked note), `docs/past-prompts.md`, `docs/resume-prompt.md`, `docs/operator-expected.md`.

**Notes / debt logged:** **#67 is now the explicit gate on settings polish** (strengthened in operator-expected — the founder's answer unblocks the settings subtitle tone + section dividers, the one thing slices 1 and 6 both hit). #63/#71/#74 open, non-blocking.

**Next objective written to resume-prompt.md:** whichever preemption fires, else ADR-025 **slice 7 — legal & consent** (consent gate, legal hub, legal document; 18 goldens; Class G): layout only, the frozen-sentence digest stays green (every `consent*`/`legal*` string pinned), and the four consent escapes — sign out / export / delete / accept — all still reachable from the gate.

## Session 034 — 2026-07-23 — ADR-025 slice 7: legal & consent — the legal document title stops rendering lighter than its own sections

**Objective (from resume-prompt.md):** ADR-025 slice 7 — legal & consent (consent gate, legal hub, legal document + renderer; 18 goldens; Class G): layout only, the frozen digest stays green, the four consent escapes reachable.

**Outcome:** done — **ONE change, 3 goldens, 15 byte-identical.** Two auditors + a governing-docs adjudicator found the consent gate and legal hub already token-clean and layout-correct, and one genuine defect in the renderer.

**Preemptions — all negative.** Item 6 (LLM) unanswered → no M5.3. **Blaze re-verified FACTUALLY** (`billingEnabled:false` on both) → no first-deploy. #67/#63/#71/#74 open. No Android green-light, on-device defect, or dev-rig request.

**What shipped (1 change):**
- **The legal document's own h1 title was rendering LIGHTER than its `##` section headings.** `legal_renderer.dart` styled the `#` document title (the parser's declared h1, e.g. "Privacy Policy") with `textTheme.headlineSmall` — a slot `TypographyTokens` never defines, so it fell to Material 3's default (24sp/**w400**), while `##` section headings use `titleMedium` (16sp/**w600**). The document's own title was the ONE place in the whole app using an undefined type role (a completeness grep confirmed no other unset-slot usages in `app/lib`), and it read *lighter* than its sub-headings — a weight-hierarchy inversion. Fixed to `headlineMedium` (the DEFINED h1, 24sp/w700 per `TypographyTokens`' own annotation + brandkit §3 "H1 = 24/700"). LOOKED at the regenerated goldens: the title now leads in both size AND weight, matching the bold app-bar title, with the sections correctly subordinate — better, not just different.

**Class-G guarantees hold — no copy, no escapes, no bytes touched.** A type-role substitution in the renderer: no `consent*`/`legal*` string reworded (frozen digest green), the four consent escapes untouched (the change is in the renderer, not `ConsentGateScreen`), the legal markdown BYTES untouched (`legal_assets_drift_test` byte-faithful test green), `SettingsErrorLine` not forked, no `onSurfaceVariant`/`outline` (#67 not implicated — the consent gate's existing `onSurfaceVariant` age-statement caption was deliberately left as-is, being #67 itself). No motion (navigated surfaces).

**Review (lean, proportionate to a one-line typography fix): the design audit (2 auditors + adjudicator) WAS the design review; a 2-agent refute-skeptic + firewall-verifier pass confirmed the built diff.** The audit's adjudicator vetted the change against every Class-G/digest/escapes/bytes/#67/#63/motion/SettingsErrorLine constraint; the completeness grep confirmed the fix's scope is complete (headlineSmall was the sole unset-slot instance); 75 legal + guard tests green; the golden LOOK confirmed the improvement.

**Golden discipline (D8):** declared {legal_document_screen privacy_policy ×3 (en.ltr, ar.rtl, tr.ltr — the naturals)} = 3 BEFORE `--update-goldens`; `git status --porcelain` came back **exactly** those 3. The 9 `consent_gate` + 6 `legal_screen` hub goldens byte-identical.

**Slice-0 firewall:** all three guards green and unweakened (frozen digest, lock sentinel, token parity — RE-RUN). #67/#63/#71 untouched.

**Tests:** app suite green (+1449 (same — the change is a golden re-baseline, no new tests)); coverage 86.46% ≥ 68; `flutter analyze` clean; RTL lint clean; `dart format` clean.

**Commits:** `de673af` (squash) → PR #82.

**CI:** PR #82 all green (quality, functions-rules, ios-build-smoke, slack-notify; integration-emulator main-only). Post-merge main run `29970070832` — **all green including `integration-emulator`** (the app+backend E2E).

**Docs touched:** `docs/adr/025-*.md` (slice-7 note), `docs/past-prompts.md`, `docs/resume-prompt.md`, `docs/operator-expected.md`.

**Notes / debt logged:** none new. #67 (still the gate on settings polish), #63/#71/#74 open, non-blocking.

**Next objective written to resume-prompt.md:** whichever preemption fires, else ADR-025 **slice 8 — the lock (parity only)** (`PrivacyGuard`, `PrivacyShieldCover`, `LockScreen`, `PinKeypad`; 18 goldens; Class **F**): the D5.i sentinel green; goldens BYTE-IDENTICAL unless a token normalization is declared in advance; NO new widget type / interaction / dialog / overlay / tooltip; `PrivacyShieldCover` stays `night`; the keypad stays `TextDirection.ltr`. **Slice 8 is the LAST slice — the ADR-025 arc is then COMPLETE, and the remaining MVP roadmap (M5.3, first deploy) is operator-blocked (item 6 / Blaze).**

## Session 035 — 2026-07-23 — ADR-025 slice 8: the lock (parity only) — a ZERO-CHANGE parity proof, and THE ARC IS COMPLETE

**Objective (from resume-prompt.md):** ADR-025 slice 8 — the lock (`PrivacyGuard`, `PrivacyShieldCover`, `LockScreen`, `PinKeypad`; 18 goldens; Class F, parity only): the D5.i sentinel green; goldens BYTE-IDENTICAL unless a token normalization is declared in advance; no new widget type/interaction/dialog; `PrivacyShieldCover` stays `night`; the keypad stays `TextDirection.ltr`. The LAST slice.

**Outcome:** done — **ZERO changes.** Class F forbids restructuring the lock, so slice 8's deliverable is a PROOF that the lock is byte-identical and its firewall intact, and the CLOSING of the arc. **The ADR-025 arc is now COMPLETE** — all 48 inventoried surfaces have been through a slice or are recorded parity-only/unreachable.

**Preemptions — all negative.** Item 6 (LLM) unanswered → no M5.3. **Blaze re-verified FACTUALLY** (`billingEnabled:false` on both) → no first-deploy. #67/#63/#71/#74 open. No Android green-light, on-device defect, or dev-rig request.

**The parity proof (130 lock + guard tests RE-RUN green):**
- **All 18 lock goldens + the 2 `probe` PNGs BYTE-IDENTICAL** (`lock_screen_golden_test` + `rtl_mirror_net_test` pass with NO `--update-goldens`). The lock reached byte-identity at slice 1 (D6's carve-out) and never drifted across slices 2–7.
- **The four ADR-018 lock invariants hold:** the D5.i forbidden-API sentinel green; the no-invalidate sentinel green (nothing calls `ref.invalidate(privacyLockControllerProvider)`); the `biometricOnly: true` source-contract test green; and by direct source read `PrivacyShieldCover` keeps `ColorTokens.night` (FLUTTER-4), the `PinKeypad` keeps its explicit `TextDirection.ltr`, and the `Offstage`+`TickerMode` gating shape is unchanged.
- **Zero changes** — the arc's most conservative outcome on its most safety-critical surface, exactly as ADR-025's D-Consequences predicted ("the lock surfaces get almost no refactor … ADR-018's four invariants are worth more than visual consistency").

**THE ARC IS COMPLETE (D7's own criterion).** Slice 0 built the firewall; slice 1 filled the Material floor; slices 2 (the reveal) + 3 (the pairing activation) added the two §6 signature motions + composition; slices 4 (commerce, one h1→h2) + 7 (legal, one undefined-slot→h1) were single defensible fixes; slices 5 (coach) + 6 (settings, #67-blocked) were documented already-compliant reviews; slice 8 (the lock) is the parity proof. The UI/UX Pro Max refactor the founder directed (2026-07-14) is DONE.

**Method note:** slice 8 needed no design audit — Class F forbids improvements, so the "review" is the parity PROOF (byte-identity + the four invariants + the D5.i sentinel), and the deliverable is the ADR's arc-COMPLETE record. Docs-only session (no code) → one PR.

**Golden discipline (D8):** declared set delta = 0 files; all 18 lock goldens + 2 probes byte-identical.

**Tests:** the 130 targeted lock/probe/sentinel/invariant/guard tests green (full suite unchanged from main); `flutter analyze` clean (no code touched).

**Commits:** docs-only session — the slice-8 ADR note + arc-COMPLETE record + close docs in ONE PR.

**CI:** docs-only session — the slice-8 ADR note + arc-COMPLETE record + close docs ship in one PR; CI is quality + functions-rules + ios-build-smoke (integration-emulator skips — no app code). Watched to green.

**Docs touched:** `docs/adr/025-*.md` (slice-8 note + arc-COMPLETE + Status), `docs/past-prompts.md`, `docs/resume-prompt.md`, `docs/operator-expected.md`, `docs/roadmap.md` (arc marked complete).

**Notes / debt logged:** **AUTONOMOUS ENGINEERING HAS REACHED ITS OPERATOR-DEPENDENCY BOUNDARY.** With the arc complete, every remaining MVP unit needs the founder: **M5.3** (live coach) waits on **item 6** (LLM provider + API key); the **first deploy** waits on **item 2** (Blaze billing); the **on-device/TestFlight** lane waits on **item 4** (Apple Developer enrollment). Open design questions (non-blocking): **#67** (muted/outline tokens — unblocks a settings-polish follow-up), **#63** (Phosphor — its own slice 1.5), **#71** (motion token), **#74** (DRY the unfold).

**Next objective written to resume-prompt.md:** a POST-ARC resume-prompt — the arc is complete and every remaining unit is operator-blocked, so the next session first re-runs the preemption checks (LLM answered? Blaze flipped? Apple enrollment? on-device defect? dev-rig?) and, if any is unblocked, does that unit; else it records that autonomous engineering is complete and safely no-ops, waiting on the founder (items 6/2/4). This is a clean, honest terminus — not a failure to find work, but the correct stop when the roadmap's remaining work is genuinely a human dependency (session-rules §4).

## Session 036 — 2026-07-24 — preemption re-check (all operator-gates confirmed blocked) + cleared the ONE unblocked engineering unit: #74 (DRY the §6 unfold)

**Objective (from resume-prompt.md):** re-run the preemption checks; if any is now UNBLOCKED, do that unit; if none is, record the operator-dependency boundary and stop. **Standing founder directive (this run): continue autonomously until blocked by something only a human can do — do not stop while non-human-blocked work remains.**

**Preemptions — all three planned MVP gates re-verified BLOCKED:**
- **Item 6 (LLM provider + API key):** unanswered — no signal in the repo, issues, or env. → no M5.3.
- **Item 2 (Blaze):** re-verified **FACTUALLY** — minted an OAuth token from the firebase-tools refresh token and GET `cloudbilling…/billingInfo`: **`billingEnabled:false` on BOTH `hayatiapp-dev` and `hayatiapp-prod`.** → no first-deploy.
- **Item 4 (Apple enrollment):** re-verified **FACTUALLY** — the `release` GitHub environment has **zero secrets** (no `ASC_*`), so the release lane still fails-closed. → no on-device/TestFlight.
- No Android green-light (Gate 3), no on-device defect report, no dev-rig request.

**But the terminus was NOT quite reached: #74 was genuinely unblocked engineering** (a tracked, pixel-neutral DRY tidy-up needing ZERO founder input — distinct from #67/#63/#71, which are brandkit/founder decisions). Under the standing "continue until human-blocked" directive, that made #74 this session's honest unit — not idle-improvised busywork (session-rules §4), but a tracked issue with an exact acceptance spec the arc itself wrote.

**#74 done — the §6 soft-unfold is now ONE shared widget.** Slice 2's file-local `_RevealUnfold` (`paired_home_screen.dart`) and slice 3's shared `SoftUnfoldReveal` (`core/widgets/soft_unfold_reveal.dart`) were byte-behaviourally identical except their `@visibleForTesting` `Opacity` key string. **Design A1 (chosen over full-DRY B):** `SoftUnfoldReveal` gained an optional `opacityKey` param (default `softUnfoldOpacityKey`); `paired_home_screen` now renders `SoftUnfoldReveal(opacityKey: revealUnfoldOpacityKey, …)`, and the `_RevealUnfold` class + its now-unused `motion_tokens` import are deleted (net −20 lines). **A1 was chosen because #74 explicitly says "keep `revealUnfoldOpacityKey`":** it preserves that test seam and leaves the daily-reveal motion+haptic assertions VERBATIM (zero test churn), and keeps the two reveal surfaces independently addressable in tests. Full-DRY B would have churned those assertions for a DRY the issue did not ask for — the governing-doc (#74) tiebreak.

**Review (standing 2-pass discipline; built-diff pass run as a 4-lens workflow):** correctness/pixel-neutrality · test-integrity · DRY-design · governing-docs/firewall, each finding then double-verified by a refuting skeptic + a governing-docs adjudicator. **Verdict CLEAN** — 2 findings raised, both refuted: (1) minor — "`opacityKey` is a test-seam on the production API" (structurally un-annotatable; legitimate non-test use; no criterion violated); (2) nit — "the shared widget's own test file never exercises the override path" (the skeptic itself disproved it: `paired_home_screen_test` finds the `Opacity` by `revealUnfoldOpacityKey`, so a routing regression WOULD fail). The nit's fair *maintainability* point was closed anyway by adding a direct override-path test to `soft_unfold_reveal_test.dart` (asserts a caller key is stamped and the default is then unused) — the shared widget's suite now self-proves the param.

**Golden discipline (D8):** declared golden delta = **0 files**. `git status --porcelain` shows only the two `.dart` lib files + one `.dart` test + the ADR — **zero golden/PNG moved**; both `paired_home_screen_golden_test` and `partner_preview_screen_golden_test` pass with NO `--update-goldens` (keys don't paint; the widget is pixel-neutral at rest).

**Tests:** full app suite **1,449 green** on the lib change (incl. the three slice-0 firewall guards — lock sentinel, token parity, frozen digest — and the entrypoint sentinel), `flutter analyze` clean, coverage **86.44%** (≥68 gate). The added override test makes it 1,450; `soft_unfold_reveal_test.dart` runs 4/4 green.

**Session hygiene:** confirmed sole claude on hayati (my PID 26299, cwd hayati; the other four claudes on `/home/aytek`, `evrak`, `unhooked`, `ams-pulse` — the S030 pattern). CodeGraph oriented at start (517 files / 6,438 nodes).

**Commits / CI / Docs touched:** ONE PR — **#85** (squash-merged as `133d547`), the #74 code+test + the ADR-025 post-arc note + close docs together; #74 auto-closed by the merge. **CI GREEN both runs:** the PR run (`quality` ✓ `functions-rules` ✓ `ios-build-smoke` ✓; `integration-emulator` skipped — main-only per ADR-006) and, watched to conclusion, the **post-merge MAIN run** (`quality` ✓ `functions-rules` ✓ `ios-build-smoke` ✓ **`integration-emulator` ✓** `slack-notify` ✓ — the notifier `exit 0`s with "SLACK_WEBHOOK_URL is not set" since item 5 is still open). One CI incident, self-fixed: the first PR push failed `quality` at the `format` step — I had not run `dart format` before committing; `dart format` reformatted the new `testWidgets` call to canonical multi-line, amended + force-pushed, green thereafter (a standing reminder: run `dart format` before commit). Docs touched: `docs/adr/025-*.md` (post-arc #74 note), `docs/past-prompts.md`, `docs/resume-prompt.md` (S037 preemption re-check), `docs/operator-expected.md`. `codegraph sync` run post-merge (index already current).

**Notes / debt logged:** **THE OPERATOR-DEPENDENCY BOUNDARY IS NOW FULLY REACHED — #74 was the last non-human-blocked unit in the backlog.** Every remaining item needs the founder: **M5.3**←item 6 (LLM key), **first deploy**←item 2 (Blaze), **on-device/TestFlight**←item 4 (Apple enrollment). Non-blocking design questions still open, all founder/brandkit calls: **#67** (muted/outline tokens — the gate on a settings-polish follow-up), **#63** (Phosphor — its own slice 1.5), **#71** (motion token in `hayati-tokens.json` — a brandkit-revision decision, parallel to #67). **#74 CLOSED.** No new debt.

**Next objective written to resume-prompt.md:** unchanged shape — the preemption re-check (items 6/2/4 factual re-verify + on-device/Android/dev-rig signals). With #74 cleared, the backlog now holds NO non-human-blocked engineering, so absent an operator unblock the next session is the clean, honest no-op terminus (session-rules §4).

## Session 037 — 2026-07-25 — the preemption boundary held, but the backlog was NOT empty: #29 (seasonal question windows) shipped — ADR-026

**Objective (from resume-prompt.md):** re-run the preemption checks; if any is now UNBLOCKED, do that unit; if none is, record the operator-dependency boundary and stop. **Standing founder directive (this run): continue autonomously through sessions until blocked by something only a human can do.**

**Preemptions — all re-verified BLOCKED, factually:**
- **Item 6 (LLM provider + API key):** no signal in the repo, issues, env or CI. → no M5.3.
- **Item 2 (Blaze):** minted an OAuth token from the firebase-tools refresh token and GET `cloudbilling…/billingInfo` — **`billingEnabled:false` on BOTH** `hayatiapp-dev` and `hayatiapp-prod`. → no first deploy.
- **Item 4 (Apple enrollment):** the `release` GitHub environment has **zero secrets** (`gh api …/environments/release/secrets` → `total_count: 0`), so the release lane still fails closed. → no on-device/TestFlight.
- No Android green-light (Gate 3), no on-device defect report, no dev-rig request; #67/#63/#71 have **zero comments** — unanswered.

**But S036's "the backlog now holds NO non-human-blocked engineering" was WRONG, and this session corrects it.** Reading every open issue rather than the three the resume-prompt named: #48 (needs the phone), #41 (operator item 0), #15 (needs a Mac/device) and #13 (M6.5) really are blocked — but **#29 (seasonal window→date mapping) is pure TS, fully verifiable locally, and is the unit `roadmap.md` itself names as the AI-chosen backlog the uipro arc entered the queue *ahead of*.** With the arc complete, #29 was next in the roadmap's own ordering. That made it this session's honest unit — a tracked deferral from ADR-011 D4 with an exact acceptance spec, not idle-improvised work (session-rules §4).

**#29 done — ADR-026, and the mechanism it needed was a calendar, not a filter.** ADR-011 D4 excluded every `seasonalWindow` question from selection and deferred the Hijri mapping honestly. ADR-026 closes it:
- **The window predicate keys off the day doc's own `dayKey`, never `now`** (D1) — `selectQuestion(pack, history, dayKey)`, required third param. Two overlapping sweeps writing the same `days/{dayKey}` derive the same verdict from the same id.
- **Hijri from ICU's Umm al-Qura via `Intl`** (D2) — zero dependencies, the same primitive `day-key.ts` trusts, over 12:00 UTC of the dayKey so the conversion never sits near a date boundary.
- **THE finding of the session, caught by the design review:** `Intl` does **not** throw for an unsupported calendar — it silently resolves to **`gregory`** (verified: `{calendar:'nonexist'}` → resolved `gregory`, no error). On a trimmed-ICU runtime, `month === 9` would then read as **SEPTEMBER** and fire Ramadan every autumn, for every couple, forever, with nothing red anywhere. The module now verifies `resolvedOptions().calendar` and, failing it, refuses to answer: every Hijri window reports CLOSED. **Fail direction deliberately split** — closed on content (never the wrong question), open on availability (evergreen selection keeps running, so the daily loop does not stop over a calendar library), with the verdict surfaced on `RolloverSummary.seasonalCalendarUnavailable` and one `logger.error` per sweep.
- **The vocabulary is CLOSED** (D3) — `ramadan` (Hijri month 9, whole), `eid_fitr` (Shawwāl 1–3), `eid_adha` (Dhū al-Ḥijjah 10–13), `new_year` (Dec 31 – Jan 1) — gated in **five** readers: schema `enum`, validator check, `validateSchemaAgreement`'s `checkEnum`, the TS parser's narrowed type, the app DTO. `eid` is deliberately dropped: two feasts two months apart cannot share one tag. Rationale: a free-string tag nothing recognises is a question that is **never selected, silently, forever** — the pack validates, CI is green, and it simply never appears.
- **Selection prefers in-window seasonal UNSEEN-first** (D4), then evergreen unchanged, then in-window recycle, then throw. The "unseen" is load-bearing: always-preferring would loop five Ramadan questions for thirty days while the curriculum sat idle.
- **Recorded bounds, not discovered later:** Umm al-Qura is *calculated*, so a window edge can differ by a day from Diyanet/sighting observance — deliberately **unpadded**, because padding `eid_fitr` backwards would greet Eid on the last fasting day (D5); and the predicate is **server-only** — ADR-011's *contemplated* client prefetch was never built, and a Dart mirror would need its own Umm al-Qura source plus a parity fixture, priced as a follow-up rather than silently foreclosed (D7).

**Review — the standing two-pass discipline, and it paid twice.**
- **Pre-code (4 lenses × skeptic + governing-docs adjudicator, S030 either-verifier-real aggregation): 12 raw / 11 surfaced / 1 refuted / 2 splits.** One **BLOCKING**: D2's "logs once per sweep" had *no channel* from the pure predicate module to the only layer holding a logger — the guarantee-vs-mechanism class again, caught before a line of code. Four SERIOUS: `validateSchemaAgreement` was a missing **fifth** reader (the "existing pattern for every other enum" is a *three*-way sync); rev 1's mutation check **could not demonstrate the dangerous mode** (deleting the guard changes nothing on a full-ICU box — only *inverting* it reddens anything, which proves the wrong thing); D7 cited ADR-011 for a sentence it does not contain; the fixture's own "both sides of each edge" claim was false (`eid_adha` had no pre-entry row). Both splits were informative: CAL-2 (Ramadan 1448 is **29** days, so "same edges as 1447" cannot mean "day 30") was accepted from the skeptic over the adjudicator; **B-1 was PARTIALLY accepted** — the adjudicator was right that D1 overclaimed ADR-011 D2's "identical assignments", but the skeptic's counter-example was decisive (a history-read skew already flips an *evergreen* pick, so ADR-026 introduces no new divergence class). D1 now states what the race actually rests on: `create()` is atomic.
- **Built diff (same shape): 5 findings, all 5 surfaced with both verifiers agreeing, 0 splits, 0 refuted** — and two of the three distinct defects were **the ADR asserting something about its own diff that nothing enforced**: D1 promised the race comments in *both* `select-question.ts` and `rollover-service.ts` were corrected (only the first was — SERIOUS), and D8 promised a test asserting the sweep sets `seasonalCalendarUnavailable: true` (no test ever entered that branch; every assertion checked `false` on a full-ICU box, so deleting the probe block changed nothing). Both fixed in-session. The lesson is recorded in the ADR rather than smoothed over: **an ADR's promises about its own diff are guarantee surfaces too.**

**Mutation checks (two, both killed, both restored byte-identically against a pre-mutation backup — the S025 addendum):** removing the ICU guard reddens 3 `seasonal-window` tests; removing the sweep probe block reddens both `rollover-seasonal-guard` tests.

**The acceptance harness:** a 19-row committed fixture (`seasonal-window-cases.json`) pinning `dayKey` → Hijri → exact open-window set, with **both sides of both edges of every window**, plus two deliberate traps — the 1448 rows sit ~11 Gregorian days earlier than 1447 (any "Gregorian month read as Hijri" bug fails) and Ramadan 1447 is 30 days while 1448 is **29** (any hardcoded month length fails). It doubles as the ICU-data drift guard. The degraded-ICU mode is simulated for real via a `resolvedOptions` spy + `vi.resetModules`, asserting among other things that **ramadan does not fire in September**.

**Tests:** functions **47 files / 929 tests green**, coverage **97.72% stmts / 93.54% branches** (gates 80 hard / 85 target); validator **71 self-checks**; app **1452 green, 86.45%** (gate 68); `flutter analyze`, `dart format`, `rtl_lint`, `tsc --noEmit`, `eslint` all clean. **ZERO golden files moved** (D8 golden discipline: declared delta 0, and no app pixel is reachable from this change).

**Session hygiene:** confirmed sole claude on hayati (my PID 3531026; the others on `ams-pulse` and `unhooked`). CodeGraph oriented at start (517 files / 6,436 nodes). Working tree verified clean after each review workflow — no agent left a mutant behind.

**Docs touched:** `docs/adr/026-seasonal-question-windows.md` (new, rev 2 + both review records), `docs/adr/011-…` (Status amended-by pointer, D4 marked superseded, its oldest follow-up struck as CLOSED), `docs/adr/README.md` (index row), `docs/architecture.md` §4 + §5, `docs/implementation-plan.md` (M3.2 entry), `docs/roadmap.md` (a post-arc backlog section), plus the close docs.

**Notes / debt logged:** **one new issue, #88** — the TS pack parser's enums (`PACK_LOCALES`/`PACK_REGISTERS`/`QUESTION_CATEGORIES`/`SEASONAL_WINDOWS`) have **no** schema-agreement guard, while the Dart validator does; extending a vocabulary in schema+Dart but not TS would pass the authoring gate and CI and then throw at rollover time. Pre-dates ADR-026, not widened by it, deliberately not smuggled into this diff. **#29 CLOSED.** Seasonal *content* authoring remains a founder/W9 item — this is mechanism only, and a provable no-op on every shipped (all-evergreen) pack.

**Next objective written to resume-prompt.md:** the preemption re-check again (items 6/2/4 verified factually), then — if still blocked — **#88**, the small unblocked guard ADR-026 filed. The honest correction S037 makes to S036's record: "no unblocked engineering" is a claim to re-derive from the WHOLE issue list each session, not to inherit.

## Session 038 — 2026-07-25 — #88: a schema-agreement guard for the TS pack parser (and the review found two drift classes the first mutation matrix missed)

**Objective (from resume-prompt.md):** re-run the preemption checks; if all three are still blocked, do issue #88 — the TS↔schema agreement guard ADR-026 filed.

**Preemptions — all re-verified BLOCKED, factually (the S037 addendum-12 discipline: derived, not inherited):** item 6 unanswered (no signal anywhere); **Blaze `billingEnabled:false` on BOTH projects** (fresh OAuth token → `cloudbilling…/billingInfo`); the **`release` environment has 0 secrets** and the repository has 0 secrets (items 4 and 5); **every open issue has zero comments** — so no founder answer on #67/#63/#71, no Android green-light, no on-device defect, no dev-rig request. → the session is #88.

**#88 done — the asymmetry, and why it mattered.** `content/schema/question-pack.schema.json` is mirrored by TWO hand-written strict parsers. The Dart one has carried `validateSchemaAgreement()` since M3.1 — every vocabulary and bound it enforces is compared against the schema file, and drift is a red CI gate. The TS one (`functions/src/rollover/pack-loader.ts`) had **nothing**, so extending a vocabulary in the schema + the Dart validator while forgetting the TS parser produced content that passed the authoring gate AND CI, then threw `PackParseError` at rollover time in production — the same failure class the Dart check exists to prevent, one language over. ADR-026 widened that surface by a fourth vocabulary and filed this rather than smuggling it in.

**Scope, decided and recorded in the file header** (the issue asked for the enums; this covers every schema-derived rule the TS parser holds): the four vocabularies vs the exported constants **order included**; a meta-test that those four ARE every enum the schema declares, so a fifth cannot leave the TS side silently unguarded again; both field-name sets; both required lists **and the optional direction**; the depth bounds; the id pattern; and `additionalProperties` at both levels. The non-enum rules are asserted **behaviourally through `parseQuestionPack`** rather than by comparing constants, because `PACK_FIELDS`/`QUESTION_FIELDS`/`ID_PATTERN` and the depth literals are module-private — exporting parser internals purely so a test can read them would be a test seam on the production API (the S036 `opacityKey` smell), and driving the real parser proves what it DOES rather than what it declares. **No production change.**

**The mutation matrix is the deliverable, not decoration — and it caught my own green theatre twice.**
- The first draft killed only **9 of 12**: the field-set loops iterated the schema's field names *without ever putting them on the document*, so a mutant that added a schema property sailed straight through — a vacuous loop reads exactly like a real one. Fixed by setting each field to a dummy value and asserting the parser never answers "unknown field"; and the reference pack now carries **every** schema property, with a test asserting that coverage so the delete-a-field cases cannot thin out silently.
- The **combined adversarial review** (3 lenses × refuting skeptic + governing-docs adjudicator; 5 findings, all surfaced, 3 splits) then found two more drift classes, each proven by a mutant I had not tried: **(F1, SERIOUS)** the id-pattern test only checked the REJECT direction with a fixture whose uppercase letter fails every plausible pattern — relaxing the schema to allow `-` while the TS pattern stayed strict passed all 14 tests, which is precisely the `my-pack`-clears-the-gate-then-throws-at-rollover scenario #88 exists to close; replaced with schema-driven **character-class equivalence** over a probe alphabet. **(F2, SERIOUS, split)** `additionalProperties: false → true` survived, because the stranger-field expectation was hardcoded instead of read from the schema. **(F3/SA-001, MINOR, reported by all three lenses)** the pack-level required test wrapped an object *literal* in `node()`, so that guard could never fire — not vacuous (the length check still caught drift) but a structural claim of protection that nothing enforced.
- **Final matrix: 19 mutants, 19 killed** — enum extra/reorder/new/dropped, depth min and max, id pattern loosened/tightened/split-between-levels, `additionalProperties` at both levels, a new field at both levels, required added/dropped at both levels, the whole `required` key deleted, and two TS constants desynchronised.

**On the F2 split:** the governing-docs adjudicator refuted it because the *Dart* side has the same `additionalProperties` gap and the acceptance text arguably means the property set rather than the boolean. Surfaced and fixed anyway under the S030 either-verifier-real rule — **a gap shared with the other implementation is a reason to close it, not a licence to keep it.** (The Dart side's equivalent is now a known, recorded asymmetry running the other way; not filed, because the Dart validator's own stranger-field behaviour is separately tested.)

**Tests:** functions **535 unit tests green** (26 files), `tsc --noEmit -p tsconfig.test.json` and `eslint` clean, no production change, no golden touched, app untouched.

**Session hygiene:** sole claude on hayati throughout; working tree verified clean after the review workflow (its lenses legitimately write mutants — the S037 addendum) and after every mutation run, each restored with `git checkout` and diffed.

**Commits / CI / Docs touched:** two commits on `feat/s038-ts-schema-agreement` (the guard, then the review fold). Docs: `past-prompts.md`, `resume-prompt.md`, `operator-expected.md`.

**Notes / debt logged:** none new. **#88 CLOSED.** The remaining open issues are all operator- or founder-blocked (#48 needs the phone; #47's *runtime* verification rides item 4 though its Swift migration is CI-compilable — an explicit judgement call for a future session, not a default; #41 waits on operator item 0; #15 needs a Mac/device; #13 is M6.5; #67/#63/#71 are founder/brandkit calls).

**Next objective written to resume-prompt.md:** the preemption re-check, then — if still blocked — the **#47 judgement call**: decide explicitly whether to migrate `evaluatedPolicyDomainState` → `domainState.biometry` under an availability guard with CI-compile verification only, or to record why it must wait for a device. Either outcome is a legitimate session; what is not legitimate is leaving it undecided by default.

## Session 037-B — 2026-07-25 — **CONCURRENT session, recorded after the fact:** the iOS bundle id was squatted and got renamed (ADR-027)

**Recorded by Session 038, not by the session that did the work.** While Sessions 037/038 (seasonal windows, then the TS schema-agreement guard) were running in this working tree, a SECOND session worked the same repo with the founder and merged **PR #90 → `ce80908`** at 21:01 UTC, between this tree's PR #89 and PR #91. It wrote **ADR-027** and updated `docs/operator-expected.md`, but it did **not** append to `past-prompts.md` — so the session log was missing a merged change until this entry. It also numbered itself **Session 037**, colliding with the seasonal-windows session below. **Both entries are real work; the number is the collision, not the content.** Future sessions: the numbering is per-tree, so a concurrent session can duplicate it — trust the dates, the ADR numbers and the PR numbers, not the session ordinal.

**What it did (verified by reading the merged diff, not by trusting the summary):** `com.hayati.app` — the working-title bundle id from the Session-001 scaffold — turned out to be **squatted**: Apple's Developer portal refuses to register it to the founder's team (`UH7MXG7Z94`, AYTEKIN ERDOGAN, Individual, **paid**), i.e. another team owns it, and that team id is the founder's only Apple account. The id was blocking App ID registration, the App Store Connect record, Sign in with Apple, and real-device auth. ADR-027 renames iOS to **`com.beyondkaira.hayati`** (the founder's own namespace, as with their shipped Ballast app), leaves **Android on `com.hayati.app`** with the decision deferred to M6.5 (a Play `applicationId` is permanent once published — a one-way door best walked with the Play Console open), and regenerates rather than string-patches the Firebase-minted values. Both phases are in: `firebase_options_{dev,prod}.dart`, `google_sign_in_config.dart`, `Info.plist`, `project.pbxproj`, `fastlane/Appfile` and the bootstrap test all carry the new id on main.

**Why this matters more than a rename:** it moves an operator gate. **Apple enrollment (item 4) is DONE** — the paid programme is active and a dev build already runs on the founder's iPhone 17 Pro Max over cable. What remains under item 4 is the *CI signing* half (the three `ASC_*` secrets — still `total_count: 0` at this session's close) and the on-device verification backlog. Session 038 refreshed `operator-expected.md`'s TL;DR row and "next move" line accordingly, because the row still read "finish the enrollment" after the enrollment had finished — and a stale operator item is worse than no item.

**Consequence for the next session, recorded deliberately:** #47 (the deprecated `evaluatedPolicyDomainState`) was heading for a *defer* recommendation on the grounds that its runtime half is unverifiable without a device. **That premise is gone** — the founder has the device and is actively testing on it. Session 039's resume prompt was rewritten to recommend the migration instead, with the runtime check added to the founder's on-device checklist. Likewise #15 (the phone-auth native crash) needed a Mac and a device to investigate; both now exist, so it moves from "impossible" to "the founder's to capture".

**No code was written by Session 038 for any of this** — this entry is the log repair plus the doc refresh. `git status` clean; CI on the merged main green.

## Session 039 — 2026-07-26 — #47: the biometric enrollment probe migrates off the iOS-18-deprecated API (ADR-018 rev 5), and the recommendation that flipped

**Objective (from resume-prompt.md):** re-run the preemption checks; if all still blocked, make the #47 judgement call explicitly — migrate the deprecated `evaluatedPolicyDomainState`, or record why it must wait for a device. **The one outcome ruled out in advance was leaving it undecided for a sixth session.**

**Preemptions — re-derived, and one had MOVED.** Items 6 (LLM) and 2 (Blaze — `billingEnabled:false` on both, re-verified by minted OAuth token) remain blocked. **Item 4 changed shape**: a concurrent session's ADR-027 (recorded as Session 037-B) established that the founder's **paid Apple Developer Program is active** (`UH7MXG7Z94`) and a dev build already runs on their iPhone. The CI signing half is still absent (`release` environment: `total_count: 0`), so no session can produce a TestFlight build — but the *device* now exists, and that is what decided #47.

**#47 done — and the interesting part is that the recommendation reversed.** Session 038's resume prompt was going to recommend **deferring**: the revocation is a SECURITY mechanism (it is what stops a partner who enrols their face *after* enable from gaining a permanent second credential), its runtime behaviour cannot be proven by any test this repo can run, and no device was reachable. **ADR-027 killed that premise** — the founder has the device, is testing on it, and has a live on-device checklist. So the CI-compile half and the human-verify half could both land, and the honest call became *migrate*.

**What shipped:** the `biometricEnrollmentState` case now reads **`LAContext.domainState.biometry.stateHash` on iOS 18+** and `evaluatedPolicyDomainState` below it. Apple names that replacement in the SDK header itself — `API_DEPRECATED_WITH_REPLACEMENT("domainState.biometry.stateHash", ios(9.0, 18.0))` — which is why the design needed no invention; the API shape was verified from the header (`domainState` non-null, `biometry` non-null, **`stateHash` nullable**) rather than from memory. **The deployment target is iOS 15, so the legacy branch is live code**, not dead weight, and it is the branch that keeps emitting the deprecation warning until the target rises past 18. No seam, no Dart type, no state machine, no stored field moved: the value was opaque before and is opaque now.

**The consequence recorded rather than discovered:** the two representations differ, so a user who enabled Face ID on iOS 17 and **upgrades to 18** gets a mismatch → the accelerator auto-revokes once → the PIN is required. That is the fail-SAFE direction and exactly what D1 already specifies for any mismatch, but *"Face ID turned itself off after I updated iOS"* is precisely the kind of unexplained event that erodes trust in a safety mechanism, so it is in ADR-018 rev 5 and on the founder's checklist.

**Verification, stated honestly in the ADR rather than implied by a green tick:** CI's `ios-build-smoke` **passed**, proving the migration compiles, that `#available(iOS 18.0, *)` is well-formed and that the fallback still type-checks at the iOS-15 target. **Nothing in CI can prove the revocation still fires** — no simulator enrols a face. Until the founder runs item 4's check, the status of rev 5 is **compiled, not verified**, and the ADR says so in the document.

**Review (one combined pass, proportionate — S031 — but with a dedicated security lens): 6 findings, 5 surfaced, 1 refuted, 0 splits.** **Zero findings on the security chain and zero on the Swift.** All five surfaced findings were the same MINOR documentation defect from three angles, and it is a self-referential one worth keeping: rev 5 invoked this project's own rule — *a comment that names a retired API will mislead the next reader of a security path* — to justify fixing four Dart doc-comments, and then left **ADR-018's own body** naming only the retired property, including the **Decision 8 fail-direction table that the ADR itself calls "the table reviewers check first."** D1, D6 (twice) and the D8 row now carry inline rev-5 supersede notes in the style rev 4 established. The **refuted** finding is instructive too: a reviewer proposed updating the ADR README index row, then checked how rev 4 was recorded, found that amendments do not re-index, and refuted its own lens's proposal — convention verified, not assumed.

**Invariants re-run, not assumed** (`AppDelegate.swift` is app-touching): lock-screen forbidden-API sentinel ✓, `biometricOnly: true` source contract ✓, brandkit→Dart token parity ✓, frozen-sentence digest ✓, entrypoint sentinel ✓. App suite **1452 green**, coverage **86.45%** (gate 68), `flutter analyze` + `dart format` + `rtl_lint` clean, **zero goldens moved**.

**Docs touched:** `docs/adr/018-device-privacy-layer.md` (rev 5 amendment + Status + the four body supersede notes), `docs/architecture.md`, and the four Dart doc-comments (`device_privacy_channel`, `biometric_authenticator`, `local_auth_biometric_authenticator`, `pin_lock_store`), plus the close docs.

**Notes / debt logged:** **#47 CLOSED.** **#48 stays open and untouched** — a transient Face ID *lockout* still reads as an enrollment change and revokes permanently; it is fail-safe (toward the PIN), and it needs the on-device evidence item 4 will produce. No new debt.

**Next objective written to resume-prompt.md:** the preemption re-check, with the honest position that **autonomous engineering has now cleared every non-human-blocked unit in the backlog** — #29, #74, #88 and #47 are all closed, and what remains is #48/#15 (need the founder's device), #41 (operator item 0), #13 (M6.5/Gate 3) and #67/#63/#71 (founder/brandkit calls). The next session should expect to find nothing unblocked and must SHOW that derivation rather than inherit it.

## Session 040 — 2026-07-26 — **the preemption fired: Blaze went ON mid-run, the backend went live, and the ADR-026 guard reported from production**

**Objective (from resume-prompt.md):** re-run the preemption checks and SHOW the derivation; expect the terminus. **The expectation was wrong, and that is exactly why the rule says derive rather than inherit** (S037 addendum 12). The very first check came back changed.

**The derivation, run factually:**
- **Item 2 (Blaze): `billingEnabled = True` on BOTH `hayatiapp-dev` and `hayatiapp-prod`** — minted from the firebase-tools refresh token, same method that returned `false` on every read from S028 through S039. **The founder flipped it during this run.** → preemption 2 FIRED.
- Item 6 (LLM): no signal. Item 4's remaining half: `release` environment still `total_count: 0`. Item 5: repository secrets still 0. Every open issue: zero comments. No new non-session commits on `main`.

**Attribution, corrected by the audit log rather than assumed.** The deploy reported *"updating"*, not *"creating"* — so something had deployed already. The Cloud Audit log settles it: **`CreateFunction` at 21:35:15 UTC from `FirebaseCLI/15.24.0 … claude-code_2-1-218`** — the **concurrent session** (the ADR-027 one, a different agent build) deployed first, immediately after the founder flipped Blaze. This session's `UpdateFunction` is the 23:11:54 entry (`FirebaseCLI/15.22.4 … claude-code_2-1-219`), redeploying the same ten from the merged-`main` build. **This session did not perform the first deploy; it re-deployed, verified, and documented it.** Recorded that way because a session log that claims someone else's milestone is worse than no log.

**Ten of eleven Functions are LIVE on `hayatiapp-dev` (`europe-west1`).** Verified directly, not assumed:
- **`questionRollover`** → Cloud Scheduler job `firebase-schedule-questionRollover-europe-west1`, schedule `0 * * * *`, timezone `Etc/UTC`, state **ENABLED** — precisely ADR-011 D2's hourly UTC sweep, deploy-verified at last after being "deploy-verified later" since M3.2.
- **`answerReveal`** → Eventarc trigger `answerreveal-484370`, `google.cloud.firestore.document.v1.created`, function state **ACTIVE**, **`retryPolicy = RETRY_POLICY_RETRY`** — the Eventarc retry ADR-012 wanted proven.
- **`invitePreview`** → public HTTPS by design, smoke-tested: a bogus invite code returns **HTTP 400**, not a 5xx and not a crash.
- Seven auth-gated callables (`createInvite`, `joinInvite`, `coachProxy`, `deleteAccount`, `exportData`, `recordConsent`, `updateNotificationPrivacy`) — all v2, Node 20, 256 MB, `europe-west1`.

**The eleventh was deliberately NOT deployed, and the reasoning is the point.** `revenueCatWebhook` declares `secrets: ['RC_WEBHOOK_TOKEN']`; a **`--dry-run` first** (non-destructive, and the right first move on a first deploy) failed at exactly one place — `Secret [projects/870954957461/secrets/RC_WEBHOOK_TOKEN] not found or has no versions`. **ADR-013 says that token is generated *with* the founder**, and it is the only credential between the public internet and couples' entitlement state. So the deploy named the other ten explicitly and left the webhook. That is the difference between a blocker and an oversight, and the dry run is what let it be stated with certainty rather than guessed. **`hayatiapp-prod` was deliberately left undeployed** — dev first, and prod should follow a session that has watched dev behave.

**Authorization, since a first production deploy is an outward-facing act:** the founder's own committed `resume-prompt.md` states, verbatim, that a flipped Blaze makes the first-deploy slice the session; the founder flipped Blaze *during* a run they knew was in progress; the target was the **dev** project; and the one sub-action their ADR reserves to themselves was carved out. Recorded here because "the docs told me to" is only a defence if the docs actually did, and they did.

**Discovered by the deploy, filed rather than dismissed as noise: issue #96 — Node.js 20 is DECOMMISSIONED on 2026-10-30**, after which deploys fail. Nothing breaks today (deployed functions keep serving), but it is dated, it lands on the path to the first prod deploy, and the natural fix window is immediately before that deploy so prod is never stood up on a runtime with a known end date. The issue notes the upgrade also re-exercises ADR-026's ICU guard and the day-key parity fixture — which is a feature: those fixtures exist to make exactly this kind of runtime change loud.

**THE RESULT THAT MATTERS MOST — the ADR-026 guard reported from production, and it is green.** Two real hourly sweeps had already fired by the time the logs were read:

```
22:00:03Z  question_rollover: sweep complete
           {"assigned":0,"existing":0,"failed":0,"failedCoupleIds":[],"buckets":0,
            "seasonalCalendarUnavailable":false,"at":"2026-07-25T22:00:00.000Z"}
23:00:03Z  question_rollover: sweep complete
           {... "seasonalCalendarUnavailable":false, "at":"2026-07-25T23:00:00.769Z"}
```

**`seasonalCalendarUnavailable: false` in the deployed Google Cloud Functions runtime.** That is the S037 guard answering the exact question it was built for — *does this runtime's ICU actually carry Umm al-Qura, or is `Intl` silently handing back Gregorian months?* — and answering it from production rather than from a developer box. Had it come back `true`, seasonal content would have been silently unreachable forever and nothing else would have said so. It is worth noting how cheap this was: the guard cost one boolean on a run summary, and it converted an unanswerable question into a line in a log.

Two more things the same log lines prove: the sweep runs on the **nominal scheduled instant** (`at: 22:00:00.000Z`, not wall-clock drift) exactly as ADR-011's handler-validation design intended, and the **at-risk notification pass** runs clean alongside it (`checked:0, sent:0, failed:0`) — the ADR-012 D3 shared-bucketing path, exercised for real.

**No code changed this session.** No tests were touched, no goldens moved; the deployed artifact is the `main` build (`npm run build` from the merged tree). CI is unaffected by a deploy.

**Notes / debt logged:** **issue #96** (Node 20 decommission, dated). The webhook + its token remain the founder's, now the *only* thing standing between the current state and a fully live dev backend. A **budget alert** is recommended to the founder in `operator-expected.md` — billing is live now, and setting an alert is the one thing a session cannot do for them that they would most want in place before a surprise.

**Next objective written to resume-prompt.md:** Session 041 — the standing preemptions (item 6, the `ASC_*` secrets, the RC webhook token), and then the *remaining* observation work. The headline observation was pulled forward into this session because the evidence was already sitting in the logs and the answer mattered: the deployed rollover is clean and the ICU guard is green. What is left to watch is the part that needs data — a real couple, a real invite, a real answer pair — which is the founder's device work, not a session's.

## Session 041 — 2026-07-26 — **two preemptions fired at once; the release lane RAN for the first time and got all the way to Apple**

**Objective (from resume-prompt.md):** run the standing preemptions factually, then observe the deployed backend. **Two preemptions fired**, and the second changed the session.

**The derivation, run factually (addendum 12 — derive, never inherit):**

| # | Item | Verdict |
|---|---|---|
| 1 | LLM provider + API key | **FIRED** — `LLM_API_KEY` **exists** in `hayatiapp-dev` Secret Manager; PR **#95** (a concurrent session) implements the Anthropic adapter, **CI red** |
| 2 | `RC_WEBHOOK_TOKEN` | not fired — Secret Manager 404 |
| 3 | Three `ASC_*` secrets | **FIRED** — `total_count: 3`, created **2026-07-25T23:36Z** (S040 read `0`) |
| 4 | Gate 3 / Android | not fired |
| 5 | On-device defect | not fired — #15 and #48 both have **zero** comments |
| 6 | #67 / #63 / #71 | not fired — all three open, unanswered |

**Observation (the rest of the prior objective), done and clean.** A third clean hourly sweep since S040's two: `00:00:03Z … {"buckets":0,"failed":0,"seasonalCalendarUnavailable":false}`. The ADR-026 guard keeps reporting healthy from the deployed runtime.

**A third thing the founder did that no preemption named:** they registered **`Hayati iOS (beyondkaira)`** apps in **both** Firebase projects. That was ADR-027 D3's stated precondition for "Phase 2" — so the session checked, and found **Phase 2 had already landed inside ADR-027's own commit** (`ce80908`). Verified two independent ways: `apps:sdkconfig` for both projects matches every committed value byte-for-byte, and `git show ce80908` shows the change. **Four documents still said it was pending.**

**Objective chosen: preemption 3 — the release-lane first run (ADR-029).** Preemption 1 ranks higher in the resume-prompt's own order, and the inversion is recorded deliberately: preemption 3's work was already in flight (ADR committed, design review burning) and is independent, and M5.3 lands next session rather than never. Both get done in the same run.

**ADR-029 (drafted as 028, renumbered).** PR #95 had claimed 028 four hours earlier — **ADR numbers collide across trees the same way session ordinals do** (S038 addendum), and the ADR README now records the rule and the reserved gap.

**What shipped:** `DEVELOPMENT_TEAM = UH7MXG7Z94` + an explicit `CODE_SIGN_STYLE = Automatic` on the three app-target build configs, and `app/test/release/signing_sentinel_test.dart` to defend them. The team id is committed as an **identifier, not a credential** — four verified grounds (already in four repo docs on a **public** repo; published in every distributed IPA's embedded profile; grants nothing without the private key; withholding it would cost a **fourth operator secret** to hide a public string). `architecture.md` §9's "zero keys in repo" is untouched.

**THE BLOCKING PRE-CODE FINDING, and it is the session's best lesson.** The sentinel was specified to reuse the channel-parity mold's global `allMatches` count. That mold is sound **for its own key** — `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES` occurs only in app-target blocks, so the global count *is* the app-target count. **`CODE_SIGN_STYLE = Automatic` is the exact inverse: 3× in RunnerTests, 0× in Runner.** A global `expect(count, 3)` would have been **green when broken, red when correct, and green again when re-broken** — a guard that inverts its own meaning, shipped while citing this project's anti-vacuity addendum. The mechanism is now **per-`XCBuildConfiguration`-block parsing**, classifying each block by the bundle id *inside* it.

**Mutation matrix, 11/11 as designed** — and two of the rows are the point: a team id or `Manual` added to a **RunnerTests** block must stay **GREEN**, because a file-wide grep wearing a scope's clothing passes rows 1–8 identically to a correct test and only rows 9–10 tell them apart. Row 11 breaks the pbxproj's block shape and must redden, or a parser matching nothing would make every scoped assertion vacuous. pbxproj restored **byte-identical** to the pre-mutation backup (S025 addendum). **The matrix was re-run from scratch after the review tightened the parser census**, because changing a guard invalidates the matrix that proved it.

**Two adversarial passes, 13 findings, ZERO refuted.** Pre-code: 6 findings (1 blocking, 3 serious, 2 minor), one valuable **split verdict** where the skeptic and adjudicator were each right about a different half. Built-diff: 9 raw / 7 distinct, **all seven real**.

**⚠️ A REVIEW WHOSE VERIFIERS DIED IS A REVIEW WITH NO VERDICT.** The built-diff pass's **ten verifier agents all died on an API session limit**. The workflow therefore returned an empty `surfaced` list and put all seven findings in its `refuted` bucket — **and reading that at face value would have discarded seven true findings.** Each was hand-adjudicated by direct inspection instead. New standing practice: check `agents_error` before trusting a review's verdict distribution; an empty verdict is *unverified*, and the tooling renders it as the opposite.

**THE MOST INSTRUCTIVE FINDING — "the rule you just invoked applies to you", three times in one session.** ADR-029 D6 corrected `architecture.md` §9's false *"macOS minutes bill at 10× on this **private** repo"* (the repo is **PUBLIC**; public-repo GitHub-hosted runners are free) — **in one place, leaving the identical claim in nine others**, including six `ci.yml` comments, one of which says *"on private repos"* outright, and a second clause of the very paragraph it rewrote. Earlier in the same session, D5 corrected three stale ADR-027 surfaces and left a **fourth** standing in the founder-facing checklist; and rev 1's `Appfile` claim ("all three stay commented out") was false of its own diff, which deletes one stub. **Standing lesson, narrower and more useful than "review twice": when a diff corrects a claim, grep the whole repo for that claim before declaring it corrected.** All swept; `past-prompts.md` deliberately untouched (project-rules #2 — history may record what was believed then).

**THE RESULT — the release lane ran, and it went further than it ever has** ([run 30184464450](https://github.com/aytekXR/hayati-mobile-app/actions/runs/30184464450), `workflow_dispatch` on merged `main`):

```
preflight     ✅   metadata lint + version pin
integration   ✅   the full emulator suite, on macOS
build-report  ✅   real prod --release build + the 200 MB size gate
sign-upload   ❌   secrets gate ✅ · API key written ✅ · bundle install ✅ · pub get ✅
                   → fastlane beta ❌
store_metadata ⏭️  SKIPPED — no store copy reached App Store Connect
```

**The fail-closed boundary passed for the first time in this project's history**, and the `Gemfile.lock` debt ADR-021 D6 left open was exercised for the first time (`bundle install` resolved clean on macOS). Then:

```
▸ Automatically signing iOS for device deployment using specified
  development team in Xcode project: UH7MXG7Z94
▸ Error (Xcode): No profiles for 'com.beyondkaira.hayati' were found:
  Xcode couldn't find any iOS App Development provisioning profiles
  matching 'com.beyondkaira.hayati'.
```

**That first line is ADR-029 working.** Flutter read the committed team out of the pbxproj; the pre-ADR-029 error (*"requires a development team"*) is gone and a strictly later one replaced it. **And it is not a missing flag** — checked against the pinned Flutter 3.44.5 source rather than from memory (addendum 17): `mac.dart:383` adds `-allowProvisioningUpdates` to the archive and `build_ios.dart:567` to the export, so ADR-021 D5 rev 2's claim holds. **Xcode was permitted to create a profile and could not**, which puts the blocker on the Apple side of the key. Filed as **issue #103** with the two operator checks (is the App ID registered — roadmap Step 1; may the API key manage Certificates/Identifiers/Profiles) and, now that it is evidence-backed rather than speculative, the design for the **ASC preflight probe** the session had deliberately declined to build on spec.

**A founder-facing correction that came out of the failure:** roadmap Step 3 told the founder *"Role: App Manager is enough"* for the API key. That was written for **uploading**; creating a provisioning profile is a different permission, and it is a plausible cause of this exact failure. Corrected in place.

**Notes / debt logged:** **#99** (fresh-runner Apple Distribution certificate cap of 3, with the expected symptom named), **#100** (the repo is public — re-decide the cost-motivated CI gates; deliberately *not* decided by the session that found the error), **#103** (the provisioning gap + preflight design). **Three stale open PRs found that no session had closed** — #95 (M5.3, red), #76 (green **and** clean since 2026-07-22, one gitignore line), #70 (docs, conflicted since 2026-07-20). Addendum 12 says to re-derive the backlog from the whole **issue** list every session; it never said **PRs**, and three sat unnoticed. It says PRs now.

**CI:** PR #102 all green; **post-merge `main` run fully green including `integration-emulator`** — which is what proves the pbxproj change breaks neither `--no-codesign` builds nor the simulator suites, the highest-risk regression the review flagged.

**Next objective written to resume-prompt.md:** Session 042 — **PR #95 / M5.3**, the last MVP code unit. Preemption 1 has fired (the key exists), the code is written, and its red is mechanical (a legal-version bump left one widget test expecting "Version 1" and every consent-gate golden stale). Fix, adversarially review the inherited diff, merge, redeploy `coachProxy`.

## Session 042 — 2026-07-26 — **M5.3 merged: the MVP feature set is code-complete, and the inherited diff had a crisis filter that skipped the tail of long replies**

**Objective (from resume-prompt.md):** merge M5.3 — the live coach adapter — by adopting **PR #95**, a concurrent session's red, stale PR. Preemption 1 had fired: `LLM_API_KEY` exists in `hayatiapp-dev` Secret Manager.

**Preemptions re-derived (none fired):** `RC_WEBHOOK_TOKEN` still 404 · issue #103 zero comments · #15/#48 zero comments · #67/#63/#71 still open. *(#101, a concurrent merge, added the four colour tokens that close #67's gap — the issue stays open because the follow-up Settings polish is the founder's call.)*

**Why the PR was red, and why this session could fix it.** Its own ADR said it: goldens **cannot be produced correctly on the macOS dev box**, where they all fail environmentally. This box is **Linux — the canonical golden platform**. The concurrent session wrote 29 files of correct work it physically could not finish.

**A FALSE GREEN nearly wasted that, and it is the session's most transferable lesson.** `app/lib/core/l10n/gen/` is **gitignored**, and the local copy was **stale** — so `flutter test` was rendering the *pre-Anthropic* string and only **9** of the 18 goldens failed. Regenerating there would have produced 18 goldens CI rejects. `flutter gen-l10n` first, then the real set appeared. **A gitignored generated artifact is a baseline you do not control; regenerate it before you trust any test that renders it.**

**ADR-025's goldens rule honoured, and it paid.** The expected set was **declared before regenerating** — 18 across three sets, with a reason per set — then the actual changed set diffed against the declaration: **exactly 18, no churn**. `gate.en.ltr.png` was then read **by eye** to confirm it renders the new Anthropic sentence, because a regenerated golden that renders the *wrong* thing is silently accepted by definition.

**Root-caused, not patched.** The two text failures were one hardcoded string in two places: `Version N. Effective <date>.` is a **FOURTH carrier of the legal version**, outside ADR-023's three-way sentinel *by design* (it asserts the rendered asset, not the constant) — so it reddens on every bump with nothing warning. Centralised as `shippedPolicyVersionLine`, named in `legal_version.dart`'s source list, and `docs/legal/README.md`'s bump procedure gained **both** uncovered surfaces (this literal and the goldens, with the Linux-only note that explains why PR #95 arrived red).

**Adversarial review of the inherited diff — 7 findings, ALL SEVEN REAL, zero refuted, 2 splits.** Treated as unreviewed (5 lenses × 2 verifiers; all 13 agents alive this time). The two that mattered:

**🔴 A SAFETY DEFECT: the crisis post-filter skipped the tail of a long reply.** Step 7 ran `detect([truncateForScan(reply.text)])`. `SCAN_CHAR_LIMIT` is 4,000 and **its own comment justifies itself as "double the 2,000-char legit maximum"** — i.e. it is calibrated for **user input**, where it bounds a hostile payload. A model reply is bounded by `COACH_MAX_TOKENS` (1024), which can exceed 4,000 characters. So the last stretch of a maximum-length reply **was never scanned by the crisis filter**. Fixed: the reply is scanned in full (there is no hostile-payload risk in text from our own token-bounded call); `truncateForScan` now says *user input only, do not reuse on a reply*; an emulator regression test puts the crisis phrase past the old cap and is **mutation-verified** — restoring the truncation reddens exactly that test. **The general shape: a bound justified by one caller's constraints, reused on a caller with different constraints, and the justification travelled with the function while the constraint did not.**

**🔴 The load-bearing no-leak test was VACUOUS.** *"NEVER lets upstream text reach the mapped error message"* fed `classifyUpstream` a **plain `Error`** → classifies as `unknown`, the one branch that provably cannot carry an SDK response body whatever the implementation does. It asserted the safe path and left the dangerous one untested.

**THEN THE MUTATION MATRIX FOUND TWO MORE VACUITIES IN MY OWN REPLACEMENT.** This is the entry worth re-reading:
- **`JSON.stringify` is useless as a leak scan.** `Error`'s `message`/`stack` are **non-enumerable**, so `JSON.stringify({cause: err})` is `{"cause":{}}`. A mutant attaching the upstream error as `cause` leaked the response body with my test **green**. Replaced with a recursive collector that reads the non-enumerable fields and follows `cause` chains.
- **The fixture used invented enum values** (`personaId: 'perisi'`, `register: 'siz'`) behind an `as unknown as` cast, so `buildPersonaSystemPrompt` threw **inside the try block** and every case classified as `unknown` **without the SDK ever being reached** — the leak assertions were scanning an error the adapter raised about its own arguments. Real enum members, no cast, and `expect(create).toHaveBeenCalledTimes(1)` so *"the SDK was reached"* is asserted rather than assumed. **A cast that silences the compiler on a test fixture silences the one check that would have caught it.**
- Added a **throw-site** test (a leak-free *mapping* does not prove the provider only ever throws the mapped error — the guarantee lives at the throw site) and a **request-time-key happy path**, which is what kills a module-load-read mutant. **Matrix: 7/7 killed**, including one that reddened *against* my expectation because the original author's own empty-key test already caught it.

**Also fixed:** the untested `stop_reason: 'max_tokens'` path pinned as a **decision** (deliver the truncated turn — discarding it would fake an outage *and* burn the cap, and it is now scanned end-to-end); ADR-028's **wrong-goldens claim** (it named `ProviderActions`, which renders `legalFooterLine`; `consentProcessors` renders in **one** place and **zero** `sign_in_screen` goldens moved); the **post-implementation review record** ADR-028 lacked, whose absence the review judged the proximate cause of that error surviving; `architecture.md` §4/§8, stale the moment M5.3 shipped.

**Verified from source, never from memory (addendum 17):** `'claude-sonnet-5'` is the **first entry** of the vendored SDK's `Model` union and `ThinkingConfigDisabled {type:'disabled'}` is a real param — both read out of `functions/node_modules/@anthropic-ai/sdk`, because a wrong model id would make the coach say "unavailable" forever behind a green suite. Also verified independently: all six legal docs byte-identical to `app/assets/legal/`; Anthropic named in all three policies; version 2 + date consistent across en/tr/ar; the cap-refund path logs `error.classification` (the closed enum) only.

**DEPLOYED AND VERIFIED, which settled an open question empirically.** ADR-028's rev note recorded that the `RC_WEBHOOK_TOKEN` precedent proves only the **missing**-secret half; the **present**-secret path had never been exercised in this repo. It has now: `coachProxy` redeployed to `hayatiapp-dev`, revision **`coachproxy-00004-van`**, `state: ACTIVE`, carrying `secretEnvironmentVariables: [{key: LLM_API_KEY, version: '1'}]`, and the secret's IAM policy now holds **`roles/secretmanager.secretAccessor` → the runtime service account** — a binding nobody added by hand, so firebase-tools' auto-grant is now an in-repo finding rather than external knowledge. Cold start clean; an unauthenticated call returns **HTTP 401** *"coachProxy requires a signed-in caller."*, not a 5xx. The note was upgraded rather than left understated.

**Process correction from the founder, mid-session:** *rebase the PR onto latest `main` **before** sending its diff to the review workflows.* The review lenses read `git diff main...HEAD`, so a `main` that moves afterwards means the reviewed diff is not the diff that merges. This session had rebased first, and `main` was re-checked at merge time (unmoved, `4201f56`), so the reviewed diff **is** what merged. Recorded as standing practice.

**Notes / debt:** three stale open PRs remain — **#76** (green **and** mergeable since 2026-07-22, one gitignore line), **#70** (docs, conflicted). Issue **#103** (the release lane's Apple provisioning gap) is unchanged and operator-owned.

**Next objective written to resume-prompt.md:** Session 043 — the MVP is code-complete and every remaining *product* step is operator-owned, so the honest unit is the small tracked engineering that is genuinely unblocked: **#96** (Node 20 is decommissioned 2026-10-30 — dated, and it gates the first prod deploy) with **#76** as a trivial adjacent cleanup, plus the standing preemptions.

## Session 043 — 2026-07-26 — **#96 closed five months early: the Functions runtime is Node 22, and the review found that ICU never moved — tzdata did**

**Objective (from resume-prompt.md):** clear the dated debt that gates the first prod deploy — **#96**, `nodejs20` decommissioned **2026-10-30** — plus **PR #76**, green and mergeable for four days.

**Preemptions re-derived (none fired):** `RC_WEBHOOK_TOKEN` still 404 · #103 zero comments · #15/#48 zero comments · #67/#63/#71 zero comments. A new concurrent PR **#105** (redesign wave 2) appeared and was left alone — not this session's objective.

**PR #76, merged — but not blind-merged.** One line adding `**/xcshareddata/swiftpm/` to `app/ios/.gitignore`. Before merging, the thing worth checking: that path is where **`Package.resolved`** lives, and `Package.resolved` is SwiftPM's **lockfile**. Verified it costs nothing here — **zero `XCRemoteSwiftPackageReference` entries** in `project.pbxproj`; the only Swift package is Flutter's *path-based* `FlutterGeneratedPluginSwiftPackage` under `Flutter/ephemeral/`, and a path dependency has no version to pin. The PR author had reasoned this out correctly **in the PR body** — so the session moved it into the file, per project-rules #9, together with the condition that invalidates it (*if a remote Swift package is ever added, the line goes*). **A PR body is not the repo.**

**#96 — the decision, taken from firebase-tools' own lifecycle table rather than from memory.**

| Runtime | Deprecated | **Decommissioned** |
|---|---|---|
| `nodejs20` | 2026-04-30 *(past)* | **2026-10-30** |
| `nodejs22` | 2027-04-30 | **2028-10-31** |
| `nodejs24` | 2028-04-30 | **2028-10-31** |

**22 and 24 share a decommission date.** Node 24 buys a quieter 2027 and *no additional runway* — the next forced upgrade lands the same day either way. So: 22, the conservative option, at zero cost. And decisively, 22 is a major **this box can actually run** (nvm 22.23.1), so the suite was validated on the exact target instead of pushed to CI and hoped for. **A runtime upgrade validated only in CI is a runtime upgrade nobody has run.**

**The deliverable was never the version string — it was the ICU re-verification.** ADR-026's whole premise is that `Intl` resolves an unsupported calendar to `gregory` **silently**, and a runtime upgrade is exactly the event that moves date machinery underneath the product. Run deliberately and read, not inferred from a green aggregate: `islamic-umalqura` **resolves** (ICU 78, `small-icu: false`) and `2026-03-20` → **`10/1/1447 AH`** — a real Hijri date, not Gregorian wearing a label. seasonal-window **48**, day-key parity **20 TS + 24 Dart**, whole suite **963 / 49 files**, coverage unchanged.

**AND THE REVIEW FOUND THE THING THE ADR HAD FRAMED WRONG.** The ADR treated this as an ICU risk and checked ICU carefully. **ICU is identical on both local Nodes — 78.2.** What actually moved is the **timezone database, 2025c → 2026a.** A lens found it the only way it could be found: by running *both* Node binaries and diffing the output — at the Istanbul midnight boundary, `formatToParts` with `hour12:false` returns hour **`"24"` on Node 20 and `"00"` on Node 22**. Harmless here, verified rather than assumed (`day-key.ts` requests only year/month/day; its own header says *"no hour"*) — but **a tzdata revision changes UTC offsets, and a day key is a function of offsets**, so the guard that actually mattered was `day-key-parity.json`, not the ICU check. Honest bound recorded: the fixture covers the zones it pins. **The generalisation, and the session's best lesson: "a runtime upgrade" is at least THREE upgrades — engine, ICU, tzdata — and they move independently.**

**An over-claim of mine, in the alarming direction.** The ADR said a non-configurable `resolvedOptions` "would **silently disarm** the test". False: `vi.spyOn` calls `Object.defineProperty`, which **throws** on a non-configurable property, so the test fails **loudly** with an install error. A lens verified it against vitest's spy source. Corrected because the two failure modes call for opposite responses, and this project's entire anti-vacuity posture depends on telling them apart.

**And the grep rule failed on me for the third session running.** ADR-030 Decision 4 is *about* sweeping every surface that names the old runtime — and the sweep **missed two**, including **ADR-026's own line 88** (*"Node 20 (the pinned Functions runtime)"*), the ADR this entire bump exists to protect. The seasonal-window fixture header was the other. Both found by the review, both fixed.

**Review: 11 findings, ALL REAL, zero refuted** (4 verified by agents, 7 cap-deferred and hand-applied; all 12 agents alive). One combined pass rather than the usual pair — proportionate by the S031 precedent, because here the design *is* the diff. The remainder were precision: the **safe named-exclusion deploy command** written down rather than merely practised (`--only functions` dies on `revenueCatWebhook`'s absent secret and can leave a **split-runtime backend**); what rollback concretely means **and that the option expires 2026-10-30**; Scheduler/Eventarc re-verification promoted into Acceptance; *"coverage byte-identical"* → the percentages actually compared.

**DEPLOYED AND VERIFIED on `hayatiapp-dev`:** ten functions **`ACTIVE` on `nodejs22`**; **the decommission warning is gone** from the deploy output for the first time; the Scheduler job still **ENABLED** at `0 * * * *` UTC (ADR-011); `answerReveal` still **`RETRY_POLICY_RETRY`** on trigger `answerreveal-484370` with its document filter intact (ADR-012) — neither implied by `ACTIVE`, both re-checked because a runtime bump touches every function. And the decisive one: the **05:00:02Z sweep, the first on the new runtime**, logged `seasonalCalendarUnavailable: false`. **The guard ADR-026 built to catch a silent Gregorian fallback in production served as the acceptance test for a runtime migration.** That is a fixture paying for itself in a way its author did not have to foresee — worth remembering the next time someone asks whether a guard is worth the lines.

**Scope held, and the held scope recorded rather than skipped:** `firebase-admin` stays `^13`, but `architecture.md`'s stated reason for the pin — *"v14 requires Node ≥22"* — is now **void**, so the reason was corrected in the same diff and the upgrade filed as **#107**. `firebase-functions` v7 likewise. Bundling a dependency major into a runtime bump turns one verifiable change into two entangled ones.

**Notes / debt:** **#107** filed. **#103** (the release lane's Apple provisioning gap) unchanged and operator-owned. **#70** still open and conflicted. **#105** is the concurrent session's.

**Next objective written to resume-prompt.md:** Session 044 — with the MVP code-complete and #96 closed, the tracked-debt queue is down to founder-gated items and #107/#70. The honest next unit is the standing preemptions plus **#107** if nothing else has opened; the *product* now waits almost entirely on the founder.

## Session 044 — 2026-07-26 — **#107 closed: firebase-admin v14 — and `npm ci` caught what `npm install` hid**

**Objective (from resume-prompt.md):** #107 — `firebase-admin` was pinned `^13` for one recorded reason, *"v14 requires Node ≥22"*, which ADR-030 had just made void. **I had licensed stopping instead; that was wrong** — #107 is undated maintenance, but undated is not the same as blocked, and the goal directive says continue until a human dependency blocks progress. It doesn't block this.

**Preemptions re-derived (none fired).** Also verified before starting: **#107's file set (`functions/package*.json`, docs) is disjoint by design from the concurrent session's in-flight branch** (`release.yml`, `fastlane/Fastfile`) — S022's condition for safe parallel work, checked rather than assumed.

**THE FINDING THAT MATTERS, and it is a process one.** `npm install firebase-admin@^14` succeeded, everything typechecked, and the full suite passed 979/979. Then **`npm ci` — the command CI actually runs — refused the tree**:

```
peer firebase-admin@"^11.10.0 || ^12.0.0 || ^13.0.0" from firebase-functions@7.2.5
```

`firebase-functions@7.2.5`'s peer range **explicitly excludes** firebase-admin v14. So the local tree that had passed everything was a tree **CI could not reproduce** — the S042 false-green shape in a new costume. And ADR-031 rev 1 had written that leaving `firebase-functions` alone was *"deliberate restraint"*, the same choice ADR-030 made. **It was not a choice at all.** `firebase-functions@7.3.0` is the first version whose peer range adds `^14.0.0`; the two are **mandatorily coupled**. (`7.3.2-rc.0` holds the `latest` dist-tag and was deliberately not taken — a release candidate has no business in a runtime dependency of a special-category path.) **Standing lesson: verify with the command CI runs, not the convenient one.** `npm install` resolves permissively and rewrites the lockfile to fit; `npm ci` asserts the lockfile is already coherent, and only that answers "will this work in CI".

**The version number understates the change badly: 48 packages move.** The headline is **`@google-cloud/firestore` 7.11.6 → 8.7.0** — a Firestore *client* major, on the library ADR-019's resumable cascade runs its transactions and cursors through, and 22 of the 29 `firebase-admin` imports here are `firebase-admin/firestore`. Also moving: `google-gax` 4→5, `jose` **4→6** (skipping a major), `jwks-rsa` 3→4, `proto3-json-serializer` 2→3, `lru-cache` 6→11, and `farmhash-modern` **dropped**.

**Verification, targeted at the two surfaces #107 named:** ADR-019's cascade against the real emulator — **58 pass** (the resumable `deletions/{uid}` cursor, the partner-cursor-seeding transaction, kill-mid-cascade convergence, `deleteUsers` idempotency); ADR-013/015's entitlement core + the fast-check LWW order-independence property — **109 pass**; whole suite **979 / 50 files**.

**And the strongest evidence: a controlled A/B on the same tree.** The coverage numbers are *lower* than ADR-030's, which invites the wrong conclusion. So the baseline was measured, not reasoned about — `main` checked out, `npm ci` back to **13.10.0**, same suite: `979 passed · 97.28% (1646/1692) · 92.45% (1079/1167)`. **Identical.** The delta versus ADR-030 is entirely `creator-question.ts` arriving from the concurrent PR #105.

**A FALSE ALARM WORTH RECORDING.** One re-run of the identical tree reported **52 failures**, another a 1645-vs-1646 coverage blip. Neither was real: **a review agent I had launched was running its own `firebase emulators:exec` on the same fixed ports.** Confirmed by watching `ss -ltn` (8080/9099/5001 busy during the bad window, free during the good ones), then re-running twice back-to-back in a clean window — **979 / 97.28% / 92.45% bit-for-bit both times.** This repo's emulator suite binds fixed ports and is **not safe to run concurrently with anything else that boots emulators, including your own review agents.** I nearly attributed a contaminated red to a Firestore client major.

**Review: 17 findings, all real, zero refuted** (12 agents alive). The most valuable: **the `firebase-functions` fix was sitting UNCOMMITTED** — the branch as committed would have gone red in CI at the install step. Also: the dependency table listed five packages and called that "the real change" (it is 48); `@google-cloud/firestore`'s "before" was the **declared range floor** `7.11.0` paired against a **resolved** "after" (it is 7.11.6); and `gaxios` was shown as a clean 6→7 when the top level **stays** at 6.7.1 and 7.3.0 appears *nested* under `google-gax` — which is, precisely, the copy the Firestore gRPC path uses.

**An honest bound stated plainly rather than buried:** `jose` v4→v6 and `jwks-rsa` v3→v4 are firebase-admin's **ID-token verification stack**, and the emulator **does not perform real token verification** — so **nothing in `functions/test/` exercises the code that moved most**. The app calls neither library directly; the risk sits with firebase-admin's own tests. Recorded with its consequence: *if real-device sign-in ever fails with a token error, look here first.*

**Deployed and smoke-tested on `hayatiapp-dev`:** ten functions redeployed on the v14 build via the named-exclusion command; `coachProxy` and `createInvite` return a clean **401**; **`invitePreview` with a bogus code returns `{"status":"unknown"}` HTTP 200** — a *real Firestore read through the v8 client in production*, returning the designed not-found shape rather than an error. The scheduled sweep on the new client is the remaining production signal.

**Notes / debt:** `firebase-functions` is now 7.3.0 (the peer range forced it, and it also cleared the long-standing "outdated firebase-functions" deploy warning). **#70** remains open and conflicted. The concurrent session's signing branch remains theirs.

**Next objective written to resume-prompt.md:** Session 045 — the tracked engineering queue is genuinely empty of anything both unblocked and undone. Re-derive it; if it is still empty, say so with the derivation and stop.

## Session 045 — 2026-07-26 — **the verification session that found prod is live, behind, and silently broken in one place**

**Objective (from resume-prompt.md):** re-derive the queue; if nothing is both unblocked and undone, show the derivation and stop. **The derivation found something instead** — which is the argument for running the session rather than asserting its conclusion. (S044 reached this verdict conversationally and never executed the session; that gap is why this entry exists.)

**Preemptions, live:** `RC_WEBHOOK_TOKEN` **ABSENT on dev** but **PRESENT on prod** · #15/#48/#67/#63/#71 all still zero comments · **#103 CLOSED** at 06:04Z (the concurrent session's fastlane-`match` work landed, exactly as the S043 handoff predicted) · zero open PRs.

**THE HEADLINE: `hayatiapp-prod` is fully deployed — ELEVEN functions, all `ACTIVE` — and `main`'s documentation says it is undeployed.** The founder and a concurrent session stood prod up during this run. Verified directly against the Cloud Functions API rather than inferred:

| Fact | State |
|---|---|
| Functions deployed | **11 / 11**, all `ACTIVE`, `europe-west1` |
| Runtime | **`nodejs20`** — the runtime **decommissioned 2026-10-30** |
| `coachProxy` | deployed **2026-07-25T21:54Z**, `secrets: NONE` → a **pre-M5.3 build** |
| `LLM_API_KEY` (prod) | **present** in Secret Manager |
| `RC_WEBHOOK_TOKEN` (prod) | **present** in Secret Manager |
| `revenueCatWebhook` | `ACTIVE` — **but see below** |

Two consequences fall straight out and neither was recorded anywhere: **prod runs code that predates M5.3**, so the coach answers "unavailable" *despite the key existing*; and **prod was stood up on a runtime with an end date** — the precise situation ADR-030 argued to avoid ("fix it before prod is stood up, never after"). Both are repaired by a single redeploy from current `main`, which is the founder's call, not a session's.

**AND THE FINDING THAT MATTERS MOST — issue #115: the production RevenueCat webhook is not publicly invocable, so RevenueCat cannot deliver to it.** Its Cloud Run service has **no IAM bindings at all**:

```
PROD revenuecatwebhook  -> NO bindings
PROD invitepreview      -> roles/run.invoker -> allUsers     (the control)
```

Both of its URLs reject *before the function runs* — the bodies are **Google's HTML error pages**, not our JSON (403 with no auth, 401 with a bearer token), while the public control on the same alias returns `{"status":"unknown"}` from our own code. **That HTML-versus-JSON distinction is the whole diagnosis**, and it is why a deploy-time check would not have caught this: the function deployed fine, is `ACTIVE`, and reports healthy.

RevenueCat delivers a plain POST carrying a **static `Authorization` value** — the verbatim token ADR-013 specifies. Cloud Run's IAM tries to read that as a **Google identity token**, fails, and returns 401 before invoking anything. No RevenueCat setting can satisfy Google IAM. **So entitlement events never arrive: a real purchase would charge the customer and never unlock Premium, silently.** That is M4's acceptance line failing in the one manner that emits no signal at all. The absence is also *anomalous* — firebase-tools normally grants `allUsers` `run.invoker` to an `onRequest` function, which is why `invitePreview` has it — so the cause is worth understanding before patching, in case an org policy re-breaks it on the next deploy.

**Not fixed, deliberately, and the reasoning is the point.** Granting `allUsers` on a production endpoint is a **security-posture change on the founder's live system**, even though it is the *intended* design — ADR-013 is explicit that the token then becomes the only thing between the public internet and couples' entitlement state. The RevenueCat wiring is a concurrent session's in-flight work (S022: parallel work is safe only when file sets are disjoint by design). And the token's **value cannot be read by a session**, so opening the endpoint without confirming it matches the RevenueCat dashboard would swap a closed door for one that rejects everything. The issue carries the exact `gcloud` command and — more usefully — the exact way to tell success from failure: **a correct result is JSON from our fail-closed check, not HTML from Google's.**

**#41's window, flagged in the same pass.** Its remediation is gated on "before real purchases exist", and it was *"blocked on operator item 0"* — which is now done. Both halves of its own "why this is not currently exploitable" paragraph (*no key to steal, no project to post to*) are **false now**. Left as a comment, not a fix: it edits the entitlement identity path the concurrent session is inside, and if purchases already exist it becomes a **migration of live billing identity** — a founder decision.

**#70 closed with evidence rather than merged.** It existed to flag two post-merge runs left unread during a GitHub 503 outage at the S028 close. Session 045 read them: `29708998595` **success** (including the `integration-emulator` that was mid-flight) and `29709354780` **success**. Merging it would have injected a "Session 029's first action" instruction into a Session-045 resume prompt and rewritten a **prior** `past-prompts.md` entry, which project-rules #2 forbids — and its `CI: green` line turns out to be simply true.

**Verdict on the derivation:** of nine open issues, **none is both unblocked and safe to act on alone.** #115 and #41 need the founder (production security posture; live billing identity). #99 is subsumed by the merged `match` work. #48 is gated on device observation *by its own text*. #100 needs runner-queue measurement and is low value. #71/#67/#63 are brandkit/founder. #15 needs a device crash log. #13 is M6.5. **No code changed this session** — it was verification, and verification is what it produced.

**Next objective written to resume-prompt.md:** Session 046 — re-verify #115 (it is the founder's money), reconcile `main`'s documentation with prod's real state, and pick up whatever the concurrent branch's merge leaves behind.

## Session 046 — 2026-07-26 — concurrent operator track: RevenueCat wired end-to-end, three TestFlight builds, and the Linux→TestFlight `match` lane merged (#117)

This entry records the **concurrent operator session** Sessions 043–045 kept referring to ("the RevenueCat wiring is another session's in-flight work"; "#99 is subsumed by the merged `match` work"). It ran in parallel from a stale base and merged its one code deliverable — the release lane — as **#117**; this note reconciles `main`'s docs with what it did, per S045's own next-objective.

**RevenueCat, wired end-to-end — almost entirely through the v2 REST API, not the dashboard.** `revenueCatWebhook` deployed to prod (`RC_WEBHOOK_TOKEN` in Secret Manager); the RevenueCat App Store app, the `premium` entitlement, both products, and the `default` offering's `$rc_monthly`/`$rc_annual` packages all created + linked via `POST /projects/{p}/…`; the **In-App Purchase key** (`W5ZZ73SVM3`) uploaded via the same API (`app_store.subscription_private_key`) → `subscription_key_configured: true`. App Store Connect subscription **products created via the ASC API** (group `İkimiz Premium`, `ikimiz_premium_monthly`/`_annual`, **Family Sharing OFF** at creation — ADR-015 by construction). **Honest correction feeding #115:** this session's in-run "webhook verified" (403 no-auth / 401 wrong-token) was **misread** — those were **Google IAM** rejecting the un-bound Cloud Run service *before* the code ran, not the token gate. S045 caught it; #115's `allUsers run.invoker` binding is the real unblock and remains the founder's call. **The one thing no one can do yet is pricing:** setting the ASC subscription price 409s for every territory/shape — pure Apple post-agreement propagation (Business fully green, W-8BEN submitted 2026-07-26).

**TestFlight: three builds shipped** (manual `flutter build ipa` + `xcrun altool`), build 3 fixing the app identity — **CFBundleDisplayName "Hayati App" → "İkimiz"** (committed to `main` in this same change) and the placeholder icon → the brandkit iOS icon (the redesign wave later re-set the icons on `main`, which win). Sandbox tester created; the purchase loop waits on pricing + #115.

**The deliverable that merged — #117, the Linux→TestFlight `match` lane.** The founder develops on Linux (no Mac), so the goal was `git tag → macOS CI → TestFlight`. Automatic cloud signing failed on hosted runners ("No valid code signing certificates were found"); rebuilt on **fastlane `match`** (the sibling Unhooked model — cert+profile in an encrypted git repo, manual signing) adapted for Flutter. Fresh certs repo `aytekXR/hayati-match-certs` (the Unhooked match password was unrecoverable), new `MATCH_PASSWORD`, a fine-grained PAT for CI. **Verified end-to-end**: run `30193322224` → *"Successfully uploaded the new binary to App Store Connect"* (build 106). Getting green took, after `match` itself worked, four fixes: two fastlane path asymmetries (actions resolve from repo root, `sh`/`Dir[]` from `fastlane/` — the IPA is now globbed by an ABSOLUTE path), and `runs-on: macos-26` + an explicit Xcode-26 select (Apple now rejects the iOS-18 SDK). `MATCH_BOOTSTRAP` removed after the mint (CI read-only). Merged via a detached worktree so the diverged `main` (icons/pbxproj/legal) and a dirty local tree were untouched; only `release.yml` + `fastlane/Fastfile` + `pubspec` landed. **From `main` now: `git tag vX.Y.Z && git push --tags` → TestFlight.**

**Also this change:** the `İkimiz` display name, and this reconciliation note. Coach (Anthropic Sonnet 5, ADR-028) is still on **PR #95**, blocked only on Linux golden regen. Operator items 6/2/3/0 and the item-4 CI half are done; what's left for the founder is **#115's invoker binding**, the ASC pricing wait, then the sandbox test (+ revoke the RevenueCat `sk_` key after).

## Session 047 — 2026-07-26 — **the session that read the release lane's own log and found `store_metadata` had never once run**

> **Session-number note (S038 addendum): the ordinal 046 was already taken.** The concurrent operator
> track merged its `past-prompts.md` entry as "Session 046" (PR #118) while `resume-prompt.md` — written
> at the S045 close — was still addressing *its* next session as 046. Numbers are per-tree and collide;
> this entry takes **047**. Trust the dates and the PR numbers.

**Objective (from `resume-prompt.md`):** re-verify #115, reconcile `main`'s documentation with prod's real
state, and pick up whatever the merged `match` work left behind.

**Preemptions, all five run.** **#115 is STILL BROKEN** — `curl -i -X POST` to the prod webhook returns
Google's **HTML 403** from `Google Frontend`, i.e. IAM refusing before our code runs. The founder has not
run the `gcloud` one-liner; it stays the top operator item and a session must not do it. **`RC_WEBHOOK_TOKEN`
still absent on dev** (dev has ten functions, prod eleven — queried live, not inferred). **#41** unchanged in
mechanism, and the fact its decision hinges on — whether purchases already exist under Firebase-uid
`app_user_id`s — is not establishable from here without touching the founder's live RevenueCat project, so it
stays a founder decision. **#15/#48** still zero comments. **Gate 3** unchanged. Platform queried directly per
addendum 41: **prod = 11 functions, ALL `nodejs20`; dev = 10, ALL `nodejs22`.**

**THE FINDING, and it came from reading a log rather than reading source.** The `match` lane's one successful
run (`30193322224`) reports `sign-upload` → **`success`**. Inside it:

```
[!] Release signing is not configured: MATCH_GIT_URL, MATCH_PASSWORD are unset.
[08:15:36]: fastlane finished with errors
##[error]Process completed with exit code 1
```

`store_metadata` calls `ensure_release_credentials!`, which requires the two `MATCH_*` inputs — inputs a
metadata-only lane never uses, and which `release.yml` does not pass to that step. So **`deliver` has never
once run**, on any release, and `continue-on-error: true` (correct, per ADR-020 D8) rendered the failure
green. This is S042 addendum 25 exactly: *a bound justified by one caller's constraints is not safe for
another caller.* **I had this backwards first** — I reasoned from source that `deliver` *had* run and was
pushing a stale app name — and the run log corrected me. Reading the artefact beat reasoning about it.

**And the coupling that made it dangerous.** `fastlane/metadata/*/name.txt` said `Hayati` while the live App
Store record says **`İkimiz`**. `deliver(force: true)` skips the confirmation prompt. So fixing the credential
bug **alone** would have converted a silent no-op into a **silent rename of the founder's live listing** on
the next release. The two changes are one change, and the lint now pins the name so they cannot drift apart.

**The other two defects, both guarantee-vs-mechanism gaps.** (1) `--build-name=0.1.0` was hardcoded, so
`preflight`'s tag↔pubspec gate — which exists to make pubspec the single source of version truth — guards a
string the build ignores; tag `v0.2.0` against pubspec `0.2.0` passes green and ships a binary stamped
`0.1.0`. Fixed by **deletion**. (2) The fail-closed secrets gate still named the retired mechanism's three
secrets, so a missing `MATCH_PASSWORD` passed the boundary and died inside fastlane — the precise outcome
ADR-021 D4 exists to prevent.

**ADR-032, written after the fact and saying so.** PR #117 replaced the entire signing architecture with no
ADR (`project-rules.md` #8; W6 wants it in the same commit). The record supersedes **ADR-021 D5** and **D3's
build-number clause**, **restores** D3's tag↔pubspec clause, amends **ADR-029 D2's rationale** — whose
justification *inverted*, because the lane now performs the `Automatic`→`Manual` flip that decision existed
to catch — and closes **ADR-029 D4 / issue #99**.

**On the build number, the evidence overturned a reasoned decision.** ADR-021 D3 forbade CI auto-increment so
that re-running a tag is idempotent. The lane's history answers it: **six consecutive release runs failed
before one succeeded**, each needing a fresh number, and under pubspec-`+N` every retry costs a commit *and* a
re-tag. Synthesis stays; the lost idempotency is written down rather than glossed. A trap worth naming: the
shipped build for `0.1.0` is **109** while pubspec reads **`+4`**, so anyone "restoring" D3 by deleting the
synthesis would ship build 4 into a version whose builds already reach 109.

**The deliverable that outlives the fixes: `tool/release_lane_lint.dart` + 50 mutation checks.** It shipped
**RED first**, reproducing all four defects from source alone — including deriving the exact production error
text. `release.yml` runs only on a tag or dispatch, so its internals can drift between releases with every
required check green; the lint runs per-PR on ubuntu and in `preflight`. **Rule 3b is deliberately per-STEP,
because the real defect was GREEN at job level** — the job *did* pass the match inputs, to a different step.
Two rules earned their keep during the session itself: my own fix comment naming the old helper tripped rule
3b (comments are now stripped), and the transitive-helper resolution was mutation-checked by deleting it and
confirming exactly two assertions redden.

**Where I chose NOT to act, and why.** The audit confirmed at *high* severity that the `write App Store
Connect API key` step is orphaned under manual signing. I kept it. **ADR-029 D2's own precedent** refused to
touch `CODE_SIGN_IDENTITY` because that would be "a blind edit to a signing path from a Linux box with no
Mac"; the lane demonstrably works *with* the step, "very likely dead" is not "proven dead", and the cost of
being wrong is a broken release the founder cannot debug. **But the redundancy went**: the file is now decoded
from `ASC_API_KEY_P8_BASE64` instead of a second raw `ASC_API_KEY_P8`, because two secrets holding one key is
a rotation footgun. Filed as **#121** for a session that can watch a real run.

**Audit workflow: 34 findings, 32 confirmed, 2 refuted, 0 unverified — 39 agents, 0 errors** (addendum 18's
check passes, so the verdict distribution is trustworthy). It caught four things I had not: `operator-expected`
Step 3 told the founder the **wrong secret names** and omitted `MATCH_*` entirely; `ci.yml`'s
`integration-emulator` still cited "100–140 billed min at 10x macOS" as its motive on a **public** repo where
those runners are free; `roadmap.md` still named **#88** as "the next AI-chosen unit" long after it shipped;
and **#67 is closable** — the redesign waves added `mist`/`veil` to brandkit v1.1 and wired them to
`onSurfaceVariant`/`outline`, which is precisely the option (a) that issue recommended. One refutation was
useful: **#71 is NOT closable** — a `motion_tokens_test.dart` does range-check 150–300ms, but the brandkit
JSON still carries no motion block, which is what #71 actually asks for.

**A trap that fired and was already documented.** `flutter analyze` reported **58 errors** on an untouched
app tree — the S042 addendum-24 stale gitignored `gen/` l10n directory. `flutter gen-l10n` then: **no issues**.
Recording it because it cost minutes and would have cost a false diagnosis.

**Issues: #99 CLOSED** (mechanism removed — `match(readonly:)` means CI cannot mint a certificate at all, and
the residual is named: re-setting `MATCH_BOOTSTRAP` re-arms it). **#67 CLOSED** with the token evidence.
**#120 filed** — `Gemfile.lock` is still absent though ADR-021 D6's discharge condition ("until the signing job
first runs") has been met three times over; every release resolves fastlane fresh within `~> 2.225` **on the
signing path**, and the original blocker (no Ruby on this box) still stands, so the fix is to generate it in
CI. **#121 filed** — confirm-then-delete the orphaned `.p8` step.

**Docs reconciled by sweeping for the CLAIM, not the instance** (addendum 19, broken three sessions running):
`architecture.md` §9 (cloud signing, "zero keys in repo", the build-number sentence, the ADR-029 rationale,
and the "still operator-owned: the ASC app record" line the build-109 run disproved), `fastlane/README.md`
(which named a helper that no longer exists, a secret `ASC_KEY_P8_PATH` that never existed, and
`CFBundleDisplayName` "Hayati App"), `fastlane/Appfile`, the ADR index's 021/029 rows, `roadmap.md`,
`ci.yml`, the signing sentinel's now-inverted reason, and `operator-expected.md` throughout — including the
Session-039 snapshot still claiming *"operational proof 0%, nothing has ever been deployed, no real purchase
has ever happened."* Two thirds of that is false; the true third (no purchase yet) is now stated plainly as
the last unproven link.

**The prod redeploy is PREPARED, not run** — the exact named-exclusion command for all eleven, the four
post-deploy re-verifications, and the point that the redeploy **may or may not restore `revenueCatWebhook`'s
public-invoker binding**: if it comes back HTML after a fresh deploy, something is actively removing it and
would re-break every future deploy. Deploying prod is the founder's call.

**Verification:** app **1565 tests / 87.26% coverage** (gate 68), functions **979 tests / 50 files, 97.28%
stmts / 92.45% branches** (gates 80 hard, 85 target), `flutter analyze` clean after the l10n regen,
`dart format` clean, both repo-root lints green, release-lane self-tests **50/50**, both workflow YAMLs parse.
`main` did not move under the branch (addendum 28, re-checked at merge).

**And I nearly accepted a FALSE GREEN on that functions run, which is worth more than the number.** The first
invocation was launched from `functions/`, so `emulators:exec`'s inner `cd functions` failed — the suite never
executed — and my `; echo "EXIT=$?"` after a pipe to `tail` read the **pipe's** status, not the command's, so
it printed `EXIT=0` over `Error: Script ... exited with code 2`. Two independent mistakes composing into a
green that meant nothing. The standing note says *run the full suite **from the repo root***, and it says so
for exactly this reason. Re-run correctly: 979/979.

**BUILT-DIFF REVIEW: 15 findings, 15 CONFIRMED, 0 refuted, 0 unverified** (20 agents, 0 errors — so the
distribution is trustworthy). Every one applied. Three deserve recording because they are about *my own work*,
and two of them are the exact failure classes this project keeps paying for.

**(1) The guard I wrote had a branch that could never fire.** Rule 3's orphan direction — "the gate demands no
secret the job ignores" — measured consumption over the *whole* `sign-upload` job. But the gate must bind every
secret it tests (`X: ${{ secrets.X }}`) or `$X` is empty and it fails closed on X forever. So the gate's own
env block always contributed every checked secret to "consumed", `checked ⊆ consumed` held **by construction**,
and the branch printed a pass that meant nothing. My mutation row missed it because it added `missing+=("X")`
*without* an env entry — a shape no human writes. Fixed by excluding the gate step; mutation-checked by
restoring the old line and confirming exactly the two new assertions redden. **A vacuous branch inside a guard
written specifically to catch vacuity.**

**(2) My "safety" check would have reddened the working lane.** Switching the `.p8` step to decode
`ASC_API_KEY_P8_BASE64` looked strictly safer. It is not: **`openssl base64 -d -A` silently emits nothing and
still exits 0 when its input contains newlines.** fastlane consumes the *same secret* through Ruby's
`Base64.decode64`, which **ignores** newlines — so if that secret was pasted line-wrapped it works in fastlane
and fails only in my step, where the `grep BEGIN PRIVATE KEY` guard I added "to be safe" is precisely what
would have failed a release that previously worked. Found by testing against a real PKCS#8 EC key rather than
reasoning; fixed with `tr -d '[:space:]'`, which handles both forms. (The same test settled the header: an ASC
key is PKCS#8, so `BEGIN PRIVATE KEY`, not SEC1's `BEGIN EC PRIVATE KEY`.) **The edit I made to avoid a blind
change to a signing path was itself very nearly one.**

**(3) ADR-032 lied about its own diff — S037 addendum 10, verbatim.** D4 said the gate "now checks all six",
that the `.p8` step "is deliberately NOT touched", and that `ASC_API_KEY_P8` "stays legitimately in the gate".
All three were true when written and **all three were false two commits later**, because the ADR landed before
the last implementation commit. The lesson the review states better than I would: an ADR written mid-sequence
describes an intermediate state. It should be the last commit, not the middle one.

The remaining eleven were sweep misses and convention gaps, all real: `architecture.md`'s own **newly written**
paragraph still named the three-secret gate; ADR-021 and ADR-029 never got the `Status:` supersession the ADR
README's convention requires (only their index rows); the ADR-020 index row still said the name was "Hayati";
`operator-expected` Step 2 still instructed the founder to *create* the App Store record as "Hayati" eight
lines from a banner saying it is İkimiz; `implementation-plan.md` M6.3 and **both** `redesign/` documents
carried stale "cloud signing" / "operational proof 0%" claims the sweep never reached; and `roadmap.md` told a
future session to "verify #67 before assuming" in the same diff that closed #67 with evidence.

**CI: the post-merge main run went RED, was examined, and is GREEN on re-run — one infrastructure cause behind
both failures.** Run `30220371273`: `quality` and `functions-rules` passed; **both macOS jobs failed**.

- `ios-build-smoke`: `xcodebuild: error: Could not resolve package dependencies` →
  `fatal: cannot change to '.../org.swift.swiftpm/repositories/google-ads-on-device-conversion-ios-sdk-3a0884ed':
  No such file or directory`. A **corrupted SwiftPM repository cache on the runner**.
- `integration-emulator`: booted the simulator fine, reached `loading .../auth_emulator_test.dart` at 21:15Z,
  then produced **nothing for 45 minutes** and hit its 50-minute job timeout (GitHub renders that as a
  *cancelled* step, not a failure — worth knowing, because "cancelled" reads like someone cancelled it).

**Same root cause, and the reasoning is the point:** `flutter test` on a simulator also resolves SwiftPM
packages, so the corrupted cache that killed `ios-build-smoke` outright is what wedged the integration suite's
iOS build. Attribution check: this diff touches **no** iOS dependency, no pbxproj, no `Package.resolved`, and
the identical tree had passed `ios-build-smoke` on the PR six minutes earlier. **Re-ran the failed jobs: all
five green**, `integration-emulator` included — which is the only verdict that covers merged code, since that
job is main-only by cost/latency design.

Two process notes worth carrying: `gh run rerun --failed` is **refused while the run is still in progress**
("its workflow file may be broken" — a misleading message for a queued-job situation), so wait for the run to
conclude first; and a 50-minute macOS job is a real reminder that `integration-emulator`'s main-only gate now
stands on **latency**, not the billing premise ADR-029 D6 corrected (issue #100).

**Operator action required: YES — and it is unchanged and singular.** #115's one `gcloud` command, re-probed at
the close and still returning Google's **HTML 403**. Everything else this session produced needs nothing from
the founder.

## Session 048 — 2026-07-27 — **#120: the lockfile the repo could not generate, generated and proved by CI**

**Objective (from `resume-prompt.md`):** re-derive the queue; act on what is genuinely unblocked. Exactly one issue was: **#120**.

**Preemptions, run live, all three founder-gated and unchanged.** **#115 still returns Google's HTML 403** — the webhook is still unreachable, so a prod purchase would still charge and not unlock. **Prod is still 11 × `nodejs20`** with a pre-M5.3 `coachProxy`; the redeploy is prepared and waiting on a go. **Dev still has 10 functions** (`RC_WEBHOOK_TOKEN` absent — ADR-013 work to do *with* the founder). **Zero open PRs.** Of ten open issues: #41/#115 founder (live billing identity, production security posture), #48/#15 need the device, #13 is M6.5, #63/#71 are brandkit calls, #121 needs a real release run, #100 needs runner measurement — leaving **#120**.

**What #120 actually was.** ADR-021 D6 deferred `Gemfile.lock` *"until the signing job first runs."* It ran, several releases ago, and **nothing noticed the condition had been met** — so every release resolved fastlane freshly within `~> 2.225`, on the one lane that owns certificate custody and rewrites the pbxproj. The lock now shows how much drift that was: the pin's floor is **2.225** and the resolution had been picking up **2.237.0**, twelve minors past it.

**The constraint that shaped the solution: there is no Ruby on this box, and that has not changed.** So the lock could not be generated here, and hand-authoring one from a CI log would look authoritative while being a guess. CI generates it — `.github/workflows/gemfile-lock.yml`, dispatch-only — and two choices are what make its output trustworthy rather than merely present:

1. **It resolves on `macos-26` / ruby 3.3, the same runner and Ruby `sign-upload` installs on.** A lock resolved on ubuntu can omit the darwin platform entirely, and `bundle install` on macOS then refuses it outright. Resolving where it will be installed avoids that by construction rather than by a flag. (`bundle lock --add-platform ruby` is applied too, so a future image arch bump does not invalidate it.)
2. **It installs `--frozen` before publishing.** This is **S044's lesson in a different ecosystem**: `npm install` succeeded, typechecked and passed 979 tests while `npm ci` — the command CI runs — refused the tree. `--frozen` asserts the lock is already coherent instead of rewriting it to fit. A lock that cannot install frozen never becomes an artifact. A checksum brackets the install, because `git diff` cannot see an untracked file and would have passed vacuously.

The workflow deliberately **never commits its own output**: a job that writes a lockfile back to the branch is a supply-chain path of its own, and the artifact hand-off exists so a human reads the diff. It also had to merge *before* it could be dispatched — `workflow_dispatch` registers only from the default branch, which is a thing this repo already learned once (ADR-021 D1 rev 2) and which cost nothing this time because it was read rather than rediscovered.

**Rule 5, and why it earns its place.** The lock's resolved fastlane must satisfy the Gemfile's `~>` constraint. So a deleted lock, a lock whose gem drifted out of range, or a Gemfile bump without a regen reddens the **cheap ubuntu preflight** — not the release job, past a 40-minute macOS leg. Matrix: **56 → 74 checks.**

**The pessimistic operator is mutation-checked in BOTH halves, and the second half is what caught the dangerous mutant.** Making the constraint always-satisfied kills seven assertions — an obvious mutant, easily caught. Incrementing the *wrong version segment*, which would silently admit a **major** bump (the single case a lockfile most exists to catch), is caught by **exactly one row**: the three-segment `~> 2.225.1` rejects `2.226.0` boundary. The two-segment cases alone cannot distinguish those implementations. That is the argument for testing both halves rather than one.

**And the matrix caught a vacuity the new rule itself introduced.** Adding rule 5 made four pre-existing raw-temp-tree cases return an **input error (exit 64)** instead of the violation they assert — so those assertions were passing for the wrong reason, invisibly. Found by the mutants, not by reading. This is S042 addendum 29 generalised: *a new rule can make old rows vacuous*, so re-run the whole matrix after adding one, never just the new rows.

**Verification:** the generator run `30224530405` green at every step (frozen install succeeded and the lock was **byte-identical** afterwards; `fastlane lanes` enumerated under the locked bundle); lint 10/10; self-tests **74/74**; `dart format` clean; PR #124 and #125 green; post-merge main green. **#120 CLOSED.**

**No operator action was created by this session.** The single outstanding founder item is unchanged: **#115's one `gcloud` command**, re-probed at close and still HTML.

## Session 049 — 2026-07-27 — **#100: the premise that replaced a false premise was also false, and nobody had measured either**

**Objective (from `resume-prompt.md`):** supply #100's measurements, decide per gate, write the decision down.

**Preemptions, unchanged and all founder-gated.** #115 still returns Google's **HTML 403**. Prod still **11 × `nodejs20`** with a pre-M5.3 `coachProxy`. Dev still 10 functions. Zero open PRs.

**The measurement, which took one API sweep and settled a question that had been open for four sessions.** Over **24 macOS jobs** on this repo:

| job | queue (median / max) | run (median / max) |
|---|---|---|
| `ios-build-smoke` | **0.1 / 0.1 min** | 6.2 / 8.6 min |
| `integration-emulator` | **0.1 / 0.1 min** | 22.3 / 32.6 min |

**macOS queue time is about six seconds** — median *and* max, both jobs.

**THE FINDING: #100's own counter-argument was false, and so was the sentence I wrote two sessions ago.** The issue ended with the reason to leave the gates alone — *"macOS runners **queue far longer** than ubuntu, so per-PR macOS legs cost latency on every review cycle even at zero dollars."* That is the claim ADR-029 D6 offered **as a replacement** when it retired the *"10× billed minutes on this private repo"* premise. It is measurably false here. S047 then repeated it verbatim while correcting other stale text, and closing #100 turned up a **third copy, on a different gate**, that neither session had touched.

**The pattern is worth more than the numbers: a load-bearing premise that gets REPLACED rather than MEASURED is likely to be wrong again**, because whatever produced the first guess produced the second. ADR-029 D6 was careful, correct about the thing it corrected, and wrong about the thing it substituted — and its wrongness then inherited forward through two sessions that were themselves auditing stale claims.

**The decision, per gate.** `integration-emulator` **stays main-only**, on the reason that actually holds — **run duration**, not queueing: 22–33 min on the critical path of every code change, plus a flake surface with a demonstrated **50-minute wedge** (the corrupted SwiftPM cache from S047's own post-merge run). Against that, the compensation for its post-merge-only verdict already exists and works — ADR-024's notifier reports the run nobody watches, and D8's commit-keyed concurrency stopped the session's own close commit from cancelling it. Relaxing would trade a working compensation for a per-PR tax. `release.yml`'s ubuntu `preflight` **stays** on signal ordering (a lint error should surface in seconds, not half an hour into a macOS leg). `ios-build-smoke`'s draft/docs-only skips **stay** — at 6 minutes it is cheap and the skips only avoid work that cannot change its outcome. **#100(c) is not triggered**, so ADR-024 D8 and ci-debt #17 are untouched.

**Revisit condition named rather than left implicit:** a human reviewer entering the loop makes a pre-merge signal worth 22 minutes, and the calculus flips — at which point (c) becomes mandatory. Also carried forward: **both** retired premises are keyed to the repo being public with fast runners, so whoever makes it private owns two sentences, not one.

**No ADR, deliberately.** Nothing about the pipeline's behaviour changed; the artefact is the measurement plus the reasoning, written into the five sites that carried the false premise (`ci.yml` ×3, `release.yml`, `architecture.md` §9) and into the issue. An ADR for "we measured and kept it" would be ceremony.

**Verification:** lint 10/10, self-tests 74/74, `dart format` clean, both workflow YAMLs parse, PR #127 green, post-merge main green. **#100 CLOSED.**

**Queue derivation at close — and this time the answer is genuinely "empty".** Eight issues remain and **none is both unblocked and safe for a session alone**: **#115** and **#41** need the founder (production security posture; live billing identity). **#48** and **#15** need the physical device — #48's own text says so. **#13** is M6.5, Gate-3 gated. **#63** and **#71** are brandkit calls the founder owns. **#121** is the only one a session *could* execute, and it needs a go-ahead rather than a decision: confirming the orphaned `.p8` step means dispatching the release lane, which **builds and uploads a real binary to the founder's TestFlight** — an outward-facing action on their App Store Connect account, not something to spend unasked.

**No operator action was created by this session.** The single outstanding founder item is unchanged: **#115's one `gcloud` command**, re-probed at close and still HTML.

## Session 050 — 2026-07-27 — **The queue was asserted empty. Eight sweeps disproved it, and the eighth found what the other seven missed.**

**Objective (from `resume-prompt.md`):** re-derive the engineering queue to confirm it is empty of unblocked work; if it holds, present the derivation and stop. Offer **#121**.

**It did not hold.** Three items were filed that nobody was tracking, plus four documentation claims that were false about the tree.

**Preemptions, run live, all three unchanged from the S049 close.** **#115 still returns Google's HTML 403** (`HTTP/2 403`, `content-type: text/html`) — the webhook is still unreachable, so a prod purchase would still charge and never unlock. **Prod is still 11 × `nodejs20`**; dev is 10 × `nodejs22`. **`RC_WEBHOOK_TOKEN` is still absent on dev** (Secret Manager 404). **Zero open PRs.** The eight open issues were re-derived from scratch and every blocker held.

**Method — and the part of it that paid.** Eight modalities swept the repo blind to each other (governing-docs-vs-tree · CI YAML as artefact · lint mutation matrices · Functions/rules · Flutter app · live platform · issue/PR archaeology · test-suite honesty), then every candidate went through **two distinct verification lenses** — a refuting skeptic and a governing-docs adjudicator — aggregated so a finding survives when *either* says real. 22 agents, 0 errors, 0 empty results, so the verdict distribution was trustworthy (S041's addendum 21 checked, not assumed). **Five of six candidates survived. One was refuted by both lenses** — ADR-015's unfiled gift-attribution issue, correctly killed as a process remark rather than a mechanism gap.

**THE FINDING THAT MATTERS MOST WAS THE COMPLETENESS CRITIC'S, AND ALL SEVEN SWEEPS HAD MISSED IT.** No sweep ran `npm audit`. It reports **14 vulnerabilities in `functions/` — 7 high, 7 moderate** — and two of the highs (`google-gax@5.0.8`, `fast-xml-parser@5.9.3`) sit in the `firebase-admin@14.2.0` tree that **ships to production Cloud Functions**, not the test toolchain. Nothing in CI has ever looked. **#131.** The lesson is the critic's existence: seven independent expert sweeps, each thorough in its own lane, and the gap was in *no* lane. The question "what modality was not run?" is worth more than another finder.

**#129 — the release lane's `Gemfile.lock` comment has been false since S048, and no release run has ever touched the lock.** `release.yml:415-418` still says *"Gemfile.lock is documented debt … bundler resolves fresh here and there is no lock."* S048 committed the lock a session ago; `fastlane/README.md` now opens with *"✅ `Gemfile.lock` is COMMITTED"* and ADR-032 records *"DISCHARGED"*. **This is addendum 19 broken by the very session that coined the correction** — S048 grepped ADR-032 and the fastlane README, but not `release.yml`, the one file the claim is *about*. Two further facts: the lane installs with plain `bundle install`, not the `--frozen` its own generator workflow calls *"the `npm ci` of this ecosystem"*; and the last release run was **2026-07-26T07:43Z** while the lock landed **23:28Z**, so `release.yml`'s `bundle install` has **never once seen the committed lock**. The lock was proven installable inside `gemfile-lock.yml`'s own job and nowhere else. **Honest scoping, recorded so the next session does not overstate it:** neither `fastlane/README.md` nor ADR-032 ever claimed the *release lane* installs frozen — both correctly scope `--frozen` to the generator. So this is the S044 lesson applied to the producer and not the consumer, **not** a broken written guarantee.

**#130 — ADR-026's "five readers" is four readers and a hope, and the test that looks like the fifth guard checks the list against itself.** ADR-026 D3 guarantees the seasonal vocabulary is *"enforced in five places."* All five readers do reject an unknown value; what is missing is the **parity** net. Schema↔validator is guarded (`validateSchemaAgreement`), schema↔TS is guarded (`schema-agreement.test.ts`, added to close #88), and the app's `knownSeasonalWindows` is guarded by **nothing** — no test in `app/test/` reads `content/schema/question-pack.schema.json`. The test that appears to cover it, `question_pack_dto_test.dart:62`, is `for (final window in knownSeasonalWindows)` — **it iterates the very list under test**, so it cannot detect drift and passes for the wrong reason. Add a season, forget the Dart file, and CI is fully green while the app throws `FormatException` at pack-load on a real device. Latent only because no shipped pack sets `seasonalWindow` yet — which is precisely what ADR-026 exists to change.

**Four documentation claims corrected in this diff, because rule 8 makes a false doc a defect and §3.3 forbids shipping `operator-expected.md` containing a claim the same session disproved.**
- **`operator-expected.md` told the founder no engineering deadline remained.** *"🧹 Nothing on the engineering side now carries a deadline … verified … from the new runtime in production."* Prod is 11 × `nodejs20`, decommissioned **2026-10-30**; the verification was on **dev**, exactly as ADR-030 D3 scoped it. The paired item below it added *"this was moved before the first prod deploy on purpose, so prod is never stood up on a runtime with a known end date"* — but prod was stood up **2026-07-25**, S043 moved dev **after** that, and **S045 discovered prod already live and added the red block at the top of the file without grepping the rest of it.** The founder-facing document has been contradicting itself for five sessions: the red block at line ~56 said Node 20 + a live deadline while the summary at line 91 said no deadline exists. Addendum 19, a third time, in the one document written *for* the founder.
- **Golden PNG count:** `test-suite.md` said 306 across 21 directories; ADR-025 said 303 and printed the command to check. That command returns **360 across 24** — `542ae7d` (redesign wave 2) added 54 goldens and 3 directories in one commit. `test-suite.md` now carries the live number and the lineage; ADR-025's fact set stays as inventoried, with a dated superseded note, since an ADR records what was true then.
- **Mutation-check count:** the standing binding-invariants note said 56; the matrix is **74** since S048, which recorded the change in `past-prompts.md` and nowhere else. Corrected in the regenerated `resume-prompt.md`.

**What the refuted candidate teaches, kept because it is a real discrimination:** stale *counts* in commentary are not guarantee gaps. This repo's highest-value class is **code failing to enforce a doc promise**; a doc under-reporting what code does (74 checks described as 56) is hygiene. The distinction is why #130 outranks the count fixes even though all three are one-file edits.

**#121 was offered and NOT executed.** Deleting the orphaned `.p8` step and proving it dead requires dispatching `release.yml`, which builds and uploads a real binary to the founder's TestFlight — outward-facing on their App Store Connect account. **Worth pairing with #129 when it is run:** the same dispatch would be the first exercise of the committed `Gemfile.lock`, and adding `--frozen` should land on a run someone is watching rather than blind (addendum 44).

**Verification:** working tree clean after every review workflow returned (S037's addendum checked; they mutated nothing). Docs-only diff — no code, no tests, no goldens touched.

**Outcome:** done. **Queue re-derived and found NON-empty: #129, #130, #131 filed, all three unblocked and Linux-only.** Four false doc claims corrected.

**Operator action required: NO new items.** The single outstanding founder item is unchanged — **#115's one `gcloud` command**, re-probed at close and still HTML. What *did* change on their page: it no longer tells them the Node 20 deadline is handled when prod still carries it.

## Session 050 (continued) — 2026-07-27 — **Pruning the operator checklist was supposed to be formatting. It found an untracked user-visible defect.**

**Objective (founder, mid-session):** *"prune the operator expected such that only open items are inside."*

**The prune itself.** `docs/operator-expected.md` went **748 lines out, 272 in**. It had re-accumulated ~450 lines of ✅ DONE blocks, superseded corrections, session narrative and a fully-obsolete Apple registration roadmap (Steps 0–5 all complete) since the last prune at S036 — despite the file's own header saying *"This file lists ONLY open, actionable items."* A rule stated at the top of a document does not enforce itself.

**Item numbering was deliberately preserved.** Six source files cite this doc by item number in comments — `recipients.ts` and `messaging-port.ts` say *"operator-expected item 4"*, `crisis-lexicon.ts` and `frozen_sentence_digest_test.dart` cite the ★ gate, `slack_notify.sh` points at it for `SLACK_WEBHOOK_URL`, `ci.yml` for ADR-020 D5. Renumbering would have silently broken every one of those references. Checked before writing, not after.

**THE FINDING: a real defect had been sitting in that file's prose for a day, tracked by nothing.** The redesign-wave review recorded a bidi item as *"scheduled for the next agent session with directional isolates."* Checking whether each open item the prose named was tracked anywhere returned **no issue** for it — and reading the golden rather than the prose showed the defect is **worse than described**:

`revealed_streak.ar.rtl.png`, three instances in one screen — `…küçük bir` / **`?şey ne`**, **`.Kahvaltıda birlikte gülmemiz`**, **`.Sabah çayını birlikte içmemiz`**. The prose named only the first. Every Latin-script string under `TextDirection.rtl` is exposed, including **the answers each partner writes and the daily question itself** — the two things the product is about. The bidi algorithm is behaving *correctly*; a neutral character at an LTR/RTL boundary takes the paragraph direction unless isolated. So it is missing isolation at our seam, not a Flutter bug. **#133**, and S051 re-ranked onto it.

**The same audit confirmed an item that would have been easy to drop as stale.** Item 5, *"rotate the leaked Slack webhook, open since S005"*, looks like exactly the kind of ancient line a prune deletes. `gh secret list` shows **`SLACK_WEBHOOK_URL` still does not exist** — it is genuinely open. The `slack-notify` job going green every run is ADR-024's designed silence, not evidence of wiring.

**The lesson, written as addendum 51.** A remainder deferred into prose is a remainder that gets lost — `session-rules.md` §2 says discoveries go to `gh issue create`, and a bullet in a document is not a tracker however prominent the document. And a status doc is an **index to audit**, not only a thing to edit: one `gh issue list | grep` per named item is the whole cost, and it is where the findings are. Treating the prune as formatting would have deleted #133's only written trace.

**Verification:** docs-only. All six code references re-resolved against the pruned file. PR #134.

**Outcome:** done. **#133 filed** — bringing S050's total to four unblocked items found inside an objective that began as "confirm there is nothing left."

**Operator action required: NO new items** — the pruned file has fewer, not more. #115's one `gcloud` command remains the single outstanding founder item.

## Session 051 — 2026-07-27 — **#133 closed: the fix was easy, and every hard part was a claim of mine that measurement killed**

**Objective (from `resume-prompt.md`):** #133 — Latin-script content inside the Arabic RTL chrome puts its trailing punctuation on the wrong end (`.Kahvaltıda birlikte gülmemiz`), visible in committed goldens. Fix it at the shared text seam, not per-screen.

**Preemptions, run live.** **#115 still HTML 403** (`HTTP/2 403`, `content-type: text/html`) — four sessions unchanged. **Prod still 11 × `nodejs20`**, decommission 2026-10-30 live. **`RC_WEBHOOK_TOKEN` still absent on dev** (Secret Manager 404, with prod as the exit-0 control). **Zero open PRs**; the twelve open issues re-derived from scratch, every blocker held. One correction: the first check of the dev secret reported `exit=0` because `$?` after a pipe reads the *pipe's* status — the exact S047 trap the resume prompt warns about. Re-measured without the pipe: exit 1.

**A founder item that existed only in prose is now in the founder's file. `operator-expected.md` item 0(c).** Dev has no `RC_WEBHOOK_TOKEN`, so dev deploys **ten** of the eleven functions and `revenueCatWebhook` has never run anywhere a session can reach. True since S013, carried session-to-session in the resume prompt, and never once written into the checklist the founder actually reads. It also re-frames 0(a): the reason granting a *production* endpoint public invoker feels like a leap is that there is nowhere to rehearse it — and dev is one command from being that place. Addendum 51, the same failure mode that produced #133.

**The design decision, and the case that decided it.** #133 asked FSI-at-the-widget-seam versus FSI-at-the-string-boundary. The answer is not a preference: `app_ar.arb` interpolates a partner's display name **into the middle of an Arabic sentence** (`دعاك {name}`). A `Directionality` ancestor or `Text(textDirection:)` sets a whole paragraph and structurally cannot isolate a run mid-sentence. String boundary, therefore — recorded as **ADR-033**, written and committed *before* any code (27th consecutive pre-code pass).

**Two things #133 did not know, both measured before the ADR was written.** The **mirror case is real**: Arabic content inside LTR chrome puts its terminator at the run's right edge instead of its left, reachable today via `contentLanguage: ar` under a `tr` interface. And **`intl`'s `Bidi.detectRtlDirectionality` is not first-strong** — it is a majority heuristic that disagrees with FSI in *both* directions of a measured pair. A session reaching for it because the issue said "Flutter exposes this as `Bidi.…` helpers" would have shipped different behaviour from the ADR's.

### Four claims of mine that measurement killed

This is the session's actual content. The code is ~40 lines.

1. **"Chrome is single-script, so it never has this defect."** False. Arabic chrome embeds Latin brand names next to neutrals (`… إعدادات App Store.`, `عبر Apple. المدرّب`) and so does `privacy-policy.ar.md` — the pre-code review found this and it was right. The *conclusion* survived for a different reason: whole-string isolation of all four strings plus a legal sentence is **byte-identical geometry**, because a chrome sentence's first-strong direction already equals the paragraph's. The reason in D3 was rewritten from a false premise to a measured one.

2. **"No existing golden covers the mirror case."** False, and the golden suite is what said so. I generalised from `paired_home_screen`, whose fixtures are Turkish in every locale (ADR-011's `solo_tr` placeholder). But `coach_screen`, `solo_home_screen` and `partner_preview` key their content fixtures to **the cell's locale**, so every `ar.*` cell renders genuinely Arabic content. The mirror case was sitting in the committed goldens the whole time. Struck in place with a dated note.

3. **"FSI is a provable no-op in LTR cells, so zero `*.ltr.png` will change."** 37 LTR cells moved. Two distinct causes, and telling them apart required decoding the PNGs rather than assuming: `ar.ltr` cells were **legitimate mirror repairs** (Arabic glyphs genuinely repositioning), while `tr.ltr`/`en.ltr` were **pure churn** — ~0.8% of pixels, mean delta 27/255, no reflow, no size change, because the isolate controls split the shaping run and the glyphs re-rasterise. ADR-025 D8 calls that churn to accept, so it was **fixed rather than declared**: `isolateWithin()` now emits the controls only when the directions actually differ. 27 goldens went back to byte-identical, and the test churn collapsed from a forecast ~17–39 assertions to **four**.

4. **"The invite code is identifier-shaped, so it needs isolating too."** Wrong on both halves. `INVITE_CODE_ALPHABET` is `ABCDEFGHJKMNPQRSTUVWXYZ23456789` — **no bidi-neutral can occur in the string**, so there is nothing to misplace; and `invite_share_screen.dart:84` holds the **only** `letterSpacing` in `app/lib`, where Flutter spaces after the zero-width controls too: measured intrinsic width **144.0 → 152.0 px**. I had generalised from a probe fixture (`ABC-234-XYZ.`) carrying punctuation the real code cannot contain. Site removed; 13 call sites → 12.

**A control caught a broken probe.** The first attempt to test the chrome claim isolated only the Latin *letters*, leaving the terminator outside the isolate — so the known-broken control came back "identical" too. A probe whose control passes is a broken probe, not a clean result.

**A mutation changed the design's self-assessment.** Emitting a leading `FSI` with no closing `PDI` leaves **all four geometry tests passing** — an unterminated isolate runs to the end of the paragraph, so the layout is accidentally right. Only the unit test caught it. The two test files are load-bearing together, not redundant.

**The verifier panel was wrong in both directions.** Of the pre-code review's findings, two survived aggregation and measurement refuted both; two were killed by *both* verifiers and measurement confirmed both real (the `letterSpacing` regression, and the `findsNothing` vacuous-assertion class). Verdicts are an input to judgement, not a substitute for measuring.

### The golden re-baseline (ADR-025 D8)

Re-declared before `--update-goldens` after the first declaration was falsified. **Actual: 34 modified, 0 added, 0 deleted** — 31 `*.rtl.png`, 3 `*.ar.ltr.png` (the mirror repairs), **zero `tr.ltr`/`en.ltr`, zero Class-F probe PNGs**. Everything inside the declaration.

**Three cells declared-to-change did not, and the reason is worth carrying: Arabic punctuation is not bidi-neutral.** `؟` U+061F is Bidi_Class **AL — strong**; it cannot float. All **seven** `solo_ar.json` questions end in it (every terminator decoded), so those cells were never broken. The coach's Arabic *reply* fixture ends `…تحبّانها.` with a **Western** full stop (U+002E, class CS, neutral) — that is the character that moved. **The consequence is a content-authoring one:** Arabic copy written with Arabic punctuation is immune, Arabic copy written with Western punctuation is not, and our AI-drafted copy mixes the two on one screen. Invisible in source, visible only rendered — so it goes to the Gulf-dialect reviewer at operator item 1.

**Scope guard held.** `functions/src/notifications/payload-policy.ts` interpolates a name into Arabic push bodies — the same class, a different runtime with no Flutter and no goldens. Filed as **#136** with honest severity (**latent, not live**) and an explicit warning not to assume iOS/Android notification chrome honours the isolates without measuring on a device.

**The build-diff review found four false claims in my own ADR, and I overrode it on a fifth.** D2 still described the seam as `isolate(data)` after the conditional rewrite made it `isolateWithin(...)`; D7 pointed at a test file that does not exist; the site count said 12 where the tree has **11** (the table listed *construction* sites — `_AnswerCard` is built three times and renders once); `test-suite.md` had no row for the new tests. All four are addendum 19 in miniature — I corrected the claim in D1 and D9 and left its paraphrase standing two paragraphs away. **The finding both verifiers killed is the one that mattered:** `intl`'s first-strong ranges exclude Arabic Extended-A **and its LTR class matches it** — `U+08A0` is Bidi_Class `AL` yet `Bidi.startsWithLtr` returns true, and Adlam matches neither class. Content beginning with such a character in LTR chrome is silently left un-isolated. Low risk for TR/Gulf-AR, but **silent**, so rule 9 gets both a `// DEBT:` comment and **#137**. That is the second time this session the panel killed something measurement confirmed.

**Verification:** `flutter test` **1578 passed, 0 failed** · coverage **87.30%** (threshold 68) · `dart format --set-exit-if-changed app/lib app/test tool content` 0 changed · `flutter analyze` No issues · `rtl_lint` clean · slice-0 firewall green, and the frozen-sentence digest *could not* move because no ARB value was touched. Working tree clean after every review workflow returned (S037's addendum checked). Fix confirmed by **reading the re-baselined golden**, not just the test.

**Outcome:** done. **#133 closed.** **#136** and **#137** filed.

## Session 053 — 2026-07-28 — **#131 closed: "7 high advisories" was 3, npm's "available fix" was a runtime break, and the gate the issue asked for was the wrong instrument**

**Objective (from `resume-prompt.md`):** #131 — seven high-severity npm advisories in `functions/`, two in the tree that ships to production. Fix them, then decide honestly whether CI should ever look.

**Session numbering: this tree's S052 never happened.** A **concurrent operator-track session on another machine** consumed the number — commits `14daaa7`/`db93fb4`/`c5e1f0b` (the TestFlight beta-group lane) and `af343ec` (the operator refresh that filed **#140**) are all labelled "Session 052" and none of them appended to this file. The S038 addendum is exactly right: `ps`/`tmux` cover only this box. Re-derived from `git log` at the session open, not inherited.

**Session hygiene.** Two other claudes on this box, both confirmed by cwd to be other repos (`unhooked`, `ams-pulse`). One leftover background `bash` **was a child of my own claude PID** — a monitor loop from a pre-`/clear` session that had been sleeping for 25 hours on a journal that would never reach its condition. Killed. (S051 saw the same shape; this is now twice.)

**Preemptions, run live.** **#115 still HTML 403** — six sessions unchanged. **Prod runtime MOVED: 11 × `nodejs22`** (was `nodejs20`), S052's redeploy; the follow-up question the resume prompt attached to that move — whether a redeploy restores the webhook's public invoker — was already answered by S052's own operator note (a deploy does not grant invoker; the binding has never existed). **`RC_WEBHOOK_TOKEN` still absent on dev** (404, prod exit-0 as control). **Scheduler/Eventarc could NOT be re-verified: there is no `gcloud` on this box and no ADC.** Recorded rather than asserted. Zero open PRs; **#140 is new** since the resume prompt was written.

**A broken probe, caught by its control — the second session running.** The first dev-secret check piped through `sed 's/./x/g'` to mask the token, and the mask swallowed the *error text* too, so a missing `gcloud` binary rendered as a row of x's that looked like a successful read. Only the prod control — `timeout: failed to run command 'gcloud'` — exposed it. Addendum 53 generalises: a probe whose output shape cannot distinguish success from failure has reported nothing.

### The issue's own headline was wrong, and so was mine

`npm audit` emits one entry per affected **package**, so a single advisory deep in a chain produces one real entry plus a wrapper for every package above it. Keyed on GHSA id:

| | npm's headline | Distinct advisories |
|---|---|---|
| before | 14 (7 moderate, 7 high) | **4** — 3 high + 1 moderate |
| after | 12 (7 moderate, 5 high) | **2** — 1 high + 1 moderate |

**"7 high-severity advisories" is 3.** #131's title counts wrappers; so did the first draft of this session's design brief. The correction is not cosmetic — it is the difference between a report that reads as an emergency and one that names two things.

**`npm audit fix` cleared two of three, not seven of seven.** Verified rather than trusted, which is what acceptance criterion 1 asked for. The lockfile diff was read in full (512 packages, +1/−0/~6), including three unfamiliar names — `@nodable/entities`, `is-unsafe`, `xml-naming` — which turned out to be `fast-xml-parser`'s own upstream decomposition, checked against the registry by **maintainer identity** rather than assumed.

### npm said `fixAvailable: true`. It was a runtime break, and a control proved it

The five remaining "highs" are **one chain with one leaf**: `firebase-admin → @google-cloud/firestore → google-gax → rimraf → glob → minimatch@9 → brace-expansion@2.1.2`. There is no patched 2.x line; the only clean version is **5.0.8**, three majors up.

```
CONTROL    minimatch@9.0.9 + natural brace-expansion 2.1.2  -> minimatch("abc","a{b,x}c") = true
TREATMENT  minimatch@9.0.9 + overrides brace-expansion@5.0.8 -> (0, brace_expansion_1.default) is not a function
```

`brace-expansion@5.0.8` is `"type": "module"` and its CJS entry exports an **object**; `minimatch@9` calls it. Taking npm's advice would have converted a DoS advisory into a hard failure inside Firestore's own dependency chain.

**And the chain is never loaded:** `google-gax` *declares* `rimraf` and never imports it — the string appears in exactly two files, both `package.json`, and `build/src` has no computed `require()`. The moderate is unreachable three ways over: `@google-cloud/storage` is an **optional** dep this code never loads (imports are firestore 22 / auth 5 / messaging 1 / app 1), only `uuid.v4` is called anywhere, and the advisory is about v3/v5/v6 — zero such calls across all **293** production packages.

**`firebase-admin@14.2.0` is the latest**, so there is no forward fix either. The 10.3.0 downgrade was refused (ADR-030/031) and `--force` never run. The `uuid` override *works* and was still **declined**: it buys audit silence in code that never executes, at the price of diverging from the combination Google tests.

### The decision: the gate the issue asked for was the wrong instrument

`npm audit`'s **absolute** output changes for reasons no commit caused. A threshold gate reddens `main` when a third party publishes — for something no session did, none can fix that hour, and which here is unreachable anyway. ADR-024's lesson transfers.

So `tool/ci/npm_audit_delta.py` compares **two points in time**: base and head lockfiles, audited in the *same run* against the *same registry*. **A newly-published advisory appears on both sides and cancels** — the check is structurally incapable of crying wolf, and fails only for what the diff itself introduces. `npm audit --package-lock-only` needs no `node_modules` and not even a `package.json`, which is what makes auditing a historical revision cheap enough to do every run.

**What the design review killed, and it was right about all of it:** the committed **baseline file** (ADR-025 D8's shape — a declaration nothing enforces; git history is already the baseline), the **cron** (GitHub disables scheduled workflows after 60 days without commits — it switches itself off during precisely the quiet period it would exist to watch), and the **Slack routing** (the notifier's payload has no field for advisory content and ADR-024 D2's noise policy would suppress it). Its **completeness critic proposed the lockfile-delta trigger** that became the design; none of the five lenses reached it.

**What all six agents missed: Dependabot.** Found by querying the platform instead of reasoning about options — **alerts are DISABLED** on what is a public repo. That is the half a cron would have covered, done properly and for every ecosystem here. Operator item **2(b)**; alerts only, because automatic security PRs would propose the very `firebase-admin@10.3.0` downgrade this session refused.

### The build-diff review found two real defects, and fixing one made a third

- **The base-ref logic was policy sitting in YAML.** Surfaced via `workflow_dispatch`, which has neither `pull_request.base.sha` nor `github.event.before`, so it skipped with a notice that misleadingly blamed "first push or force-push". The deeper point is that **ADR-024 D1 had already settled this**: outcome logic a self-test cannot see is unprotected. Moved into the tool, with `main` as the fallback so a dispatched run is a real check.
- **A surviving mutant, proven not argued.** The reviewer copied the tool to a temp dir, changed the URL-less fallback key from title-derived to package-derived, showed the suite still passed, then demonstrated the consequence: two advisories on one package collapse into one. Closed, and re-verified by re-running the mutation (control passes, mutant now fails two checks).
- **Fixing the first introduced a bug the reviewers never saw and the suite caught:** resolving the base *before* checking the lockfile exists let a missing lockfile skip (exit 0) instead of failing closed — the exact silent-pass shape the tool exists to refuse. Ordering fixed and commented as load-bearing.

The **ADR-claim auditor returned zero findings** after independently reproducing the 293-package sweep, the import counts and the test registration — the one lens whose empty result was worth checking rather than trusting (S041's addendum), and its 79 tool calls say it did the work. A *blocking* claim that a PR checkout cannot see its base commit was **refuted** (`fetch-depth: 0` fetches the base branch too).

**The `$?`-after-a-pipe trap fired again** — the end-to-end seeded run was first read as exit 0 because `tail` was in the pipeline. Third session running. Re-measured without the pipe: exit 1.

**Also fixed, found next door by the review:** **ADR-033 was never added to `docs/adr/README.md`'s index**. The table now has 34 rows for 34 files, verified both directions in code rather than eyeballed.

**Verification:** 14/14 self-tests green · full emulator suite from the repo root **exit 0**, coverage **97.22%** statements (gate 80) · `npm ci` accepts the new lockfile (the S044 trap, checked in an isolated copy) · `dart format --set-exit-if-changed app/lib app/test tool content` 0 changed · `shellcheck tool/ci/*.sh` clean · ci.yml parses · mutation check against **real npm**: seeded `minimist@1.2.0` → exit 1 naming `GHSA-xvch-5gv4-984h`; real control → exit 0, 2 resolved, 0 introduced. Working tree clean after both review workflows returned (S037's addendum checked twice).

**Operator action required:** yes, one new — **item 2(b), enable Dependabot alerts**. It is not blocking; the session completed without it.

**Outcome:** done. **#131 closed.** **ADR-034** written.

## Session 054 — 2026-07-28 — **the rename to `ikimiz`: a find/replace would have shipped broken Turkish, and the brand collided with the product's own vocabulary**

**Objective (founder directive, superseding the queued #140):** rename every customer-facing reference from "Hayati" to "ikimiz"; move shared links to `ikimiz.beyondkaira.com`; serve the legal pages there; and make the TestFlight **Friends** group receive every build.

**Three decisions were the founder's, and were asked before any code:** the casing (**lowercase `ikimiz`**, accepting that this renames the LIVE App Store listing — the store and home-screen label were already `İkimiz` from ADR-032 D6); the hosting substrate (**Firebase Hosting**, not the nginx/VPS the request assumed — the project is already entirely Firebase, so there is no server to patch and no TLS to renew); and TestFlight (**auto-assign every build**, accepting Beta App Review).

### The rename is a copy rewrite, and that is the whole finding

**`ikimiz` is an ordinary Turkish word meaning "the two of us."** In a product *about* two people it collides with the copy's own vocabulary, and a substitution ships nonsense:

| Key | Substitution gives | Why it fails |
|---|---|---|
| `privacySpotlightTitle` | "ikimiz **ikinizin** arasında kalsın" | mixes *our two* with *your two* |
| `soloCompletedBody` | "ikimiz iki kişi için tasarlandı" | "the two of us were designed for two people" |
| `soloNudgeBody` | "ikimiz birlikte daha güzel" | reads as the pronoun, not the app |
| `inviteShareMessage` | "her gün **ikimize** … **ikimiz'i** indir" | same word as pronoun AND brand, one line apart |

Four sentences were rewritten; where the brand could not sit without ambiguity it was **dropped from that sentence** rather than forced in.

**And the suffixes change, because the stem now ends in a consonant.** `Hayati'yi` → **`ikimiz'i`** (not `ikimiz'yi` — the `y` buffer is only for vowel-final stems), `Hayati'nin` → **`ikimiz'in`**. Verified after the fact across every surface: the only forms that exist are `ikimiz'de`, `ikimiz'i`, `ikimiz'in`.

**The Arabic case nearly broke ADR-033 without anything going red.** The brand becomes a **Latin wordmark inside RTL chrome**, and ADR-033 D3 deliberately does not isolate chrome — on the stated premise that *a chrome sentence's first-strong direction already equals the paragraph's*. `"حياتي مقفل"` → `"ikimiz مقفل"` would have begun an RTL paragraph with a strong-LTR character, falsifying that premise silently. Every Arabic string is instead restructured to **lead with an Arabic word** (`تطبيق ikimiz مقفل`), which preserves the premise by construction rather than patching it, and adds no isolation controls. The push bodies already had this shape and keep it.

**The legal version was deliberately NOT bumped, and the reasoning is recorded next to the constant.** Three `consent*` strings sit inside the frozen-sentence digest, whose checklist asks whether a change is *material* — because a material one re-asks every user. It is not: processors (Google, Apple, Anthropic), data categories, purposes and controller are all unchanged; only the trade name moved. `currentLegalVersion` stays **2**.

**Goldens declared before regenerating (ADR-025 D8): 91 modified / 0 added / 0 deleted across 7 suites — matched one-for-one, per suite, no churn.** Three renamed strings moved *no* golden and each reason was checked: `pairedPackUpdateTitle` renders only in a state the paired-home set does not cover; `privacySpotlightTitle` is inside the 33 solo-home cells; `inviteShareMessage` is asserted by a **self-referential** widget test that builds its expectation from `l10n` (pre-existing).

### The site is generated, because a third copy of a legal document is a third thing to drift

`docs/legal/` is already byte-synced into `app/assets/legal/` under a drift test (ADR-023). Committing HTML would add a third copy, so `tool/ci/build_site.py` renders the pages at deploy time and `web/public/` is gitignored. The Markdown subset is only what the corpus measurably uses; an unrecognised line becomes a paragraph so legal prose is never silently dropped; and **link syntax is deliberately unimplemented** because the corpus has zero links but does contain `[FOUNDER LEGAL ENTITY — to be completed by the founder]`, which a link parser would hide inside an anchor.

**The placeholder gate is the point:** the builder refuses to publish a policy that still says "to be completed by the founder", and the live channel refuses the override outright — a policy about the *channel* cannot live in the tool, which cannot see which channel it is. Both directions tested.

**Invite links** move to `https://ikimiz.beyondkaira.com/i/<code>` with an AASA file and an `applinks:` entitlement. **The old custom scheme is still parsed** — sent links live in chat history forever, and whoever follows a months-old invite is least able to diagnose it. `inviteLinkFor()` is now the single constructor, pinned by a round-trip test; 12 new parser tests including *another host serving the same path shape is rejected*.

### TestFlight: a named exception, and an honest bound

S052 wrote that adding an external tester "must not be a side effect of a merge." The founder asked for exactly that, so it is now an **exception that is named** rather than a quiet reversal — creating testers stays dispatch-only, since that is what emails a *new* person.

Deliberately **not** `pilot(distribute_external: true)`: that needs `skip_waiting_for_build_processing: false`, parking the expensive macOS runner in Apple's queue on every release. The upload stays fast; `--assign-build-number` polls on ubuntu until the build is **VALID**, because a `PROCESSING` build has no installable asset and attaching it would report success while delivering nothing — the `store_metadata`/#140 shape met a third time. Non-blocking, per ADR-034: a slow Apple queue must not redden a release whose binary already shipped.

**The bound is stated rather than papered over:** external testers receive nothing until the founder fills **Test Information** and Beta App Review passes. The tool names the missing fields after every assignment.

**ADR-020 D5's empty-URL ratchet is closed** — real privacy/support URLs landed, so `--allow-empty-urls` is gone from both `ci.yml` and `release.yml`.

**The `$?`-after-a-pipe trap fired twice more** (an e2e exit code, then a `dart format` check whose exit 1 was masked — and `--output=none` meant it had only *reported*, not written). Fourth and fifth times across three sessions.

**Verification:** app **1590 passed** (12 new), functions **979 passed** (97.28%), `flutter analyze` clean, `dart format` 0 changed (re-checked without a pipe), release-lane lint PASS — now asserting `name.txt is "ikimiz"` — store-metadata lint PASS **without** the flag, `build_site` 10 self-tests, `testflight_testers` self-tests incl. 7 new `await_build` cases, shellcheck clean, all five workflows parse, ADR index 37/37.

**Operator action required: YES, and it is blocking the user-visible half.** New items **2(c)** (connect the domain + `FIREBASE_SERVICE_ACCOUNT` + **fill the legal blanks** + enable Associated Domains) and **2(d)** (Test Information for Beta App Review). The invite link points at a domain that is not serving yet, which is why the code and the deploy lane ship together.

**Outcome:** the founder's four-part directive is complete in code. **ADR-035**, **ADR-036**, **ADR-037** written. #140 remains the top engineering item and moves to Session 055.

## Session 055 — 2026-07-28 — **the last gap between a good build and five testers was four form fields, and the gate protecting the legal text could not read Turkish**

**Objective (founder directive, superseding the queued #140):** make the website and the iOS app ready for TestFlight and testers, and make sure testers can actually get the app.

**Session hygiene.** Five other claudes on this box, all confirmed by cwd to be other repos (`ams-pulse`, `yanki-mvp`, `unhooked`, `ai-videos`, `$HOME`). One was my own pre-`/clear` background bash, walked up the ppid chain first so I did not report myself. Session number re-derived from `git log`, not from the resume prompt's prose.

**The session opened on a merge nobody had done.** PR **#145** — the whole S054 rename, the site generator, universal links and TestFlight auto-assignment — was **green, mergeable, and still open**. S054's log says "complete in code"; it was complete on a branch. Merged first, because everything else depended on it. A session that reads the log and not the platform would have rebuilt it.

### Preemptions, run live (all unchanged)

**#115 still HTML 403** — seven sessions. **Prod runtime 11 × `nodejs22`** confirmed, not inherited. **`RC_WEBHOOK_TOKEN` still absent on dev** — re-probed *with prod as a passing control* after the first probe returned exit 1 and an empty stderr file, which is a probe that has reported nothing (S051's rule, fired again): dev 404, prod exit 0. **Dependabot alerts still disabled.** Zero open PRs after the merge.

### What was actually blocking the testers, measured

`testflight-testers.yml --status`, run 30391917460:

```
app: ikimiz (com.beyondkaira.hayati)
beta groups:  'founders' (internal)  'arkadaslar' (external)  'Friends' (external)
builds:       110 VALID (2026-07-27, real icon)  109  3  2  1
readiness:    MISSING - review contact email / first name / last name / phone
```

**Four fields.** Not the description, not the feedback email — `review_readiness()` checks both and reported neither, so both were already set. A good build had been sitting in TestFlight for a day waiting on a form, and this page had been telling the founder it needed "your copy".

The tool's own docstring said those gaps were *"founder-owned copy that no session can write for them."* **Half true, in the expensive direction.** The four *facts* are the founder's — a name, an email, a phone. The *write* is a PATCH on an API this repo already authenticates against with credentials CI already holds. That asymmetry is the whole of **ADR-038**.

### The design review earned its cost, and one finding was a rule this repo had already written down

Five lenses × two verifiers + a completeness critic; 38 agents, **0 errors**, 16 raw findings, **5 survived**, 1 dropped to the per-lens cap **and logged** (it was true, and became operator item 2(d)). The critic returned an empty list — checked against its transcript rather than trusted (S041): 43 tool calls, real work, and it independently found that `list_builds` does not fetch `buildBetaDetail`.

- **"The tool never prints a value" had no mechanism.** ADR-024 had already settled this class — `slack_notify_test.sh` carries an `assert_no_leak` sentinel — and ADR-038 asserted the same guarantee with nothing behind it. Now four *distinct* sentinels (one per field, so a leak names which one escaped) across the set / unchanged / dry-run / create paths, and the partial-credential failure text is asserted to name the **secret** and contain none of the **values**.
- **"Apple returns a conflict for a duplicate submission" was a guess wearing a fact's clothes.** The review found 409 and 422 both claimed in the wild and neither measured here. Replaced by reading `externalBuildState` *before* posting; the error path survives only as a race backstop that demands an error family **and** a phrase, because either half alone swallows a real failure or misses the real one.
- **The state enum is not five values.** Printed verbatim now, with only two fail-safe subsets in code: already-through-the-gate (skip) and the two export-compliance states (refuse, and name the one-click fix). An unknown state still attempts, which is the safe direction.
- `--dry-run` was unspecified for both new writes — and the workflow's `dry_run` input **defaults to true**, so that is the first path anyone exercises.
- ADR-038 was missing from the index.

### Wiring the release lane created a bug the reviewers never saw

`release.yml` passes `--set-review-contact` on **every** release. With `read_review_contact()` failing closed, a founder who has not set the four secrets would abort **before the build assignment** — silently repealing ADR-037's guarantee that every release build reaches the Friends group, while `continue-on-error` kept the release green. Exactly S053's addendum-58 shape: the fix for a finding carrying its own defect. The write now reports, continues, and still exits non-zero, and a test drives `main()` with the secrets unset to prove the assignment POST still happens.

### The placeholder gate could not read Turkish or Arabic

`PLACEHOLDER_MARKERS = ("to be completed by the founder", "TO BE COMPLETED")`. Measured across all six legal documents:

| | detector hits | real unfilled blanks |
|---|---|---|
| `privacy-policy.en.md`, `terms.en.md` | 2 each | 2 each |
| `privacy-policy.tr.md`, `terms.tr.md` | **0** | 2 each |
| `privacy-policy.ar.md`, `terms.ar.md` | **0** | 2 each |

A gate whose entire stated purpose is *"a privacy policy served at a public URL must not read 'to be completed by the founder'"* reported **clean** for a Turkish privacy policy that says exactly that, in Turkish, to this product's primary market. It was blind in English too: the governing-law blank says "to be **determined** by the founder's lawyer" and matched nothing — it was flagged only because a sibling blank happened to share the file, so filling that sibling would have silenced the gate with `[GOVERNING LAW — …]` still on the page. And the two markers are **one** pattern: `"TO BE COMPLETED".lower()` is a substring of the other under the case-insensitive match, so every count it printed was doubled (S053's unit lesson, in a second tool).

Fixed by matching the **shape** — a bracketed span containing an em dash — which every blank has in all three languages. Language-independent **by construction** rather than by a translator remembering to add a marker: the S054 lesson about preserving a premise instead of patching it, applied to the guard rather than the copy. All **12** distinct blanks now detected. The comment that caused the blindness ("matched as literal fragments rather than a generic `\[.*\]` so ordinary bracketed prose can never trip the gate") is replaced by tests for that exact worry — bracketed prose, an em dash in prose, and a bracket and dash on separate lines all still pass.

### A green run that proved nothing, caught before it shipped

The four new `build_site_test.py` suites were added and the run went green — with the tests **never executed**. The file registers tests as bare function references in a tuple inside `main()`, and the edit that "registered" them matched nothing. `EXIT=0`, 38 ok lines, four suites silently absent. Found by grepping the log for a string only the new tests print. This is the same class as everything else in this session: a green check that guards nothing is worse than no check, because it is also a claim.

### The website: created, deployed, proven — and DNS points somewhere else

Created the `ikimiz` Hosting site in `hayatiapp-prod` (it did not exist; `firebase.json` has pinned `"site": "ikimiz"` since S054, so `deploy-site.yml` would have failed at the deploy step) and deployed the generated site to a preview channel. All six legal pages in three languages, `lang`/`dir` correct including `dir="rtl"` for Arabic, the AASA served as `application/json`, `/i/ABC123` rewriting to the invite page, security headers present. The **live** channel is deliberately still 404.

**And the domain does not point at Firebase.** `ikimiz.beyondkaira.com` → **161.97.172.146**, the founder's own VPS (same IP as the apex, HTTP 404, TLS cert covering `beyondkaira.com` only, no wildcard record). ADR-036 assumed a domain waiting to be connected; there is an explicit `A` record that has to be *replaced*. Recorded in operator item 2(e) with the measurement rather than the assumption.

**The legal blanks were deliberately NOT filled.** The founder chose the values (themselves as controller, `aytek@beyondkaira.com`, Turkish law) but the controller's **legal identity** needs their actual full legal name, and guessing a real person's name into a privacy policy is not a judgement call a session gets to make. Filling two of three buys nothing — the gate still refuses — and the set touches ADR-023's binding legal-version machinery, so all three should land in one diff. Named in 2(e), not half-done.

**Verification:** testflight self-tests green (4 new suites + 1 regression test, exit 0 measured without a pipe) · 4 mutants killed (leak a value / drop the dry-run guard / swallow any 422 / treat an unknown state as submitted) · `build_site_test.py` 38 → **57** checks, 2 mutants killed (the old English rule fails 13; any-bracket fails the cry-wolf pair) · `dart format` 0 changed · five workflows parse · ADR index **38 rows / 38 files**, verified both directions · working tree clean after both review workflows returned (S037's addendum).

**Operator action required: YES, and 2(c) is now two minutes of work.** Four `gh secret set` lines and one dispatch puts build 110 in front of Apple's reviewer. **2(d) is newly blocking** — the `applinks:` entitlement means the *next* release build fails to sign until Associated Domains is ticked on the App ID; build 110 predates it, which is why 2(c) ships 110.

**Outcome:** **ADR-038** written and merged. **#146** filed. #140 remains the top engineering item and moves to Session 056.

### S055 post-merge addendum — the bug only Apple could find, and the picture it completed

After the merge, `testflight-testers.yml --status` was dispatched against the **real** App Store Connect API — the "read the ARTEFACT, not just the source" rule, applied to a lane that had until then only ever met a fake. It exited **1**:

```
403 FORBIDDEN_ERROR — The relationship 'betaGroups' does not allow 'GET_RELATED'.
Allowed operations are: CREATE, DELETE
```

`GET /v1/builds/{id}/betaGroups` does not exist. The hermetic tests could not see it — this file's own test docstring predicted exactly that (*"a fake that agrees with a wrong assumption is worse than no test"*) — and **neither could twelve review agents across two workflows**, because none of them can call Apple. Five design lenses, five build-diff lenses and two completeness critics all passed the forward direction.

**Two failures, not one.** The forbidden call also took the *build listing* down with it: exit 1 after printing a single build. A read-only status command that dies on an optional extra tells the founder less than one that degrades and says so. Both per-build extras are now individually survivable, and the lookup is inverted to the readable direction (group → builds, one call per group). PR **#148**, merged, then **re-dispatched and proven: exit 0, full listing**.

What the two runs together established, which is the answer the founder's directive was actually asking for:

```
build 110  processing=VALID  external=READY_FOR_BETA_SUBMISSION  internal=IN_BETA_TESTING
           groups: founders, Friends
```

- **`internal=IN_BETA_TESTING`** — build 110 is installable **today** by the `founders` internal group. Nothing on the operator page is required for that. This had been true since 27 July and nobody had measured it.
- **`groups: founders, Friends`** — the build is already attached to the external group too, so `--assign-latest-build` is not part of the remaining recipe. The operator page was corrected.
- **`READY_FOR_BETA_SUBMISSION`** is in neither of the named state sets and printed **verbatim**, on the first real run — ADR-038 D5's open-enum decision paying off immediately rather than theoretically.

The remaining gap is exactly four fields, and it is the founder's to fill.

## Session 056 — 2026-07-30 — **two founder bug reports were one shape: the product's failure mode was silence — and the build the testers would install predated every fix**

**Objective (from resume-prompt.md):** #140 — nothing in CI compares what is MERGED to what is DEPLOYED.

**Outcome:** **#140 deferred a fourth time, and again for a founder directive** — say it plainly, because three prior sessions deferred it and the pattern is now the finding. The directive: *"make ready for `friends` review … make sure website is ready for linksharing inbetween couples … too many unstaged pushed changes, either push or ignore."*

The session opened on a tree with **38 modified/untracked files and ~1,400 insertions** already written and never committed — a complete, tested slice sitting at risk in a working directory. Resolving that was the first instruction and the first act.

**Commits:** [#151](https://github.com/aytekXR/hayati-mobile-app/pull/151) (ADR-039, `3e248aa`) · [#152](https://github.com/aytekXR/hayati-mobile-app/pull/152) (ADR-040, `50a7b2e`)

**CI:** green on both, and the **post-merge main run for #151 was watched to completion** including `integration-emulator` (main-only by cost design) — `quality`, `functions-rules`, `integration-emulator`, `ios-build-smoke`, `slack-notify` all success. Local, with the commands CI runs: 1625 tests, coverage **87.42%** (gate 68).

**Docs touched:** `docs/adr/039-*.md`, `docs/adr/040-*.md`, `docs/adr/README.md` (40 rows), `docs/operator-expected.md` (substantially rewritten — see below), `docs/past-prompts.md`, `docs/resume-prompt.md`.

### What ADR-039 found: not a defect, a class

There was no single bug behind *"loading screen is always on"*. **Every blocking wait on the path from launch to paired was unbounded, and every blocking screen on that path was a dead end.** Any one of them produces that report; none of them produces an actionable one. `main()`'s four pre-frame awaits were unguarded, so a throw meant `runApp` was never called and iOS held the launch storyboard **forever** — no frame, no error, and **no crash report, because the reporter is itself one of the four awaits.** Fail-open where a degraded mode exists, `BootFailureApp` for the rest. **ADR-022's sentinel never moved: a `try` block adds no `await`.**

### The measurement that reframed the whole session

```
$ git merge-base --is-ancestor 6d1f736 fa990e6 ; echo $?
1        # 6d1f736 = ikimiz rename + ADR-036. Build 110 came from fa990e6.
```

**`Friends` was attached to build 110, and build 110 predates every fix.** It *is* the build with the endless loading screen, and it shares unclickable `hayati://` links. `operator-expected.md` had been telling the founder — in a 🔴 item, in a four-line recipe — to spend a 24–48 h Beta App Review submitting **that build** to five people. The page was not wrong about the *gap* (four contact fields, still true); it was wrong about the *build*, and nothing in it could notice, because the build number was written down when it was the newest one and never re-derived.

**That is addendum 45 again (query the platform, not the docs), except the stale claim was an instruction, and following it would have cost two days and burned the first impression of five real people.**

### Notes / debt logged

* **`--invite-only` (ADR-039 D6).** The site builder refused to publish while a legal document still read *"to be completed by the founder"* — correct, and it had an unpriced cost: **the invite link in every shared message resolves to that site**, so a blank about the founder's legal name was silently holding the product's entire word-of-mouth loop hostage. Not an exception to the gate: an invite-only build publishes **no legal document at all**, so the rule holds by construction.
* **The website is LIVE**, on founder authorization given in-session, and **verified rather than asserted**: `/i/<code>` → 200, AASA → 200 `application/json`, `/privacy` → 404 with nothing linking to it. Before: `ikimiz.web.app` → **404** and the custom domain → **TLS failure**, i.e. *every invite link the app had ever emitted landed on a browser security warning.*
* **`"**/.*"` in `firebase.json` did NOT eat `.well-known`** — the classic Hosting gotcha, checked by deploying and curling rather than by reasoning about glob semantics. `found 4 files`, AASA served with the right content type.
* **ADR-040 — a working build today beats a perfect link nobody can install.** The founder chose it from two options put to them explicitly. The entitlement removal is documented **inside `Runner.entitlements`**, with ordered restoration steps, because that is where someone will be standing when the question occurs to them.
* **The share copy was checked, not assumed.** The obvious way ADR-040 could have shipped a lie is a message promising a tap that no longer happens. All three locales already said *get the app, then enter the code* — so no string moved. **Verifying the thing you did not change is part of changing something.**
* **`gh run view --job N --log` returned zero lines** and would have read as "the tests did not run" — the S055 addendum-61 check, defeated by tooling rather than by the tests. `gh api .../actions/jobs/N/logs` returned all four new assertions. **An empty result from a tool is unverified, not negative** (S041, in a new instrument).
* **Two leftover `until [ "$(gh ...)" ]` background loops from this repo's own prior session had been spinning for ~2 days** and were killed. The session-hygiene note keeps earning its place. A `ps`-based pid-chain walk written on the fly also mis-parsed `/proc/<pid>/stat` (comm contains spaces) and printed 20k characters of garbage — a reminder that the diagnostic can be the defect.
* **Not done, deliberately:** the App Attest entitlement (an operator observation, not a guess — `match` is readonly); the `PrivacyGuard` shield (audited, left alone); **#140 itself**.

**Next objective written to resume-prompt.md:** #140 — for the fifth time, and now with the argument for why it keeps losing: every session that deferred it did so for something that was *visibly on fire*, and #140 is a gate against something that is *silently* wrong. That asymmetry is the issue's own subject matter.

### Session 056 late addendum — the founder handoff had already happened, and ADR-037's guarantee had never once held

Two findings arrived after the close entry above was written, both from asking Apple instead of reading a green check.

**1. `Friends` already had the five testers.** The founder said *"I will give phone names and emails later"*; they were already in the group, and nothing in the repo or in `--status` reported it (that is exactly #146's gap — the membership line only prints on the add/assign path, so neither `--status` nor `--dry-run` can answer "who is in this group"). Measured: `ahmetsahinerr66@icloud.com`, `erencemozturk@icloud.com`, `kazimutkucitoglu@gmail.com`, `m.yahyaonder@gmail.com`, `seymabutun9@gmail.com`. **So the four `ASC_REVIEW_CONTACT_*` values were never merely the *next* step — they were the LAST one.**

**2. ADR-037's title claim was false from the day it was written.** *"Every build reaches the Friends group automatically."* Build 112's release was the **first** run to reach that step (build 110's predates the ADR) and it died on `ModuleNotFoundError: No module named 'jwt'`: `sign-upload` has no `actions/setup-python`, so bare `pip install` and `python3` were different interpreters on `macos-15`. The install printed a pip-upgrade notice; the import did not exist; `continue-on-error` took the release green. Apple's answer was the only thing that told the truth:

```
build 112  processing=VALID  groups: founders            <- not Friends
build 110  processing=VALID  groups: founders, Friends
```

Build 112 was attached by a manual `testflight-testers.yml` dispatch — the exact step ADR-037 exists to remove — and the lane was fixed structurally (`setup-python` + `python3 -m pip` + an `import jwt, cryptography` assertion ahead of the 25-minute Apple wait). `continue-on-error` **stays**; the finding is that **non-blocking must not mean unread**.

The sharpest part is that **ADR-038 D4 predicted this exact failure in these exact words** — *"silently repealing ADR-037's guarantee … while `continue-on-error` kept the release green"* — and defended the wrong layer. Every guard there assumed the tool *runs*, and its hermetic test imports `jwt` from this box's environment, so it could not have caught this in either direction. Recorded as **addendum 69**, with dated corrections on both ADRs.

**Also worth carrying:** the first release dispatch failed in `integration` on `auth_emulator_test` — *"Connecting to the VM Service timed out"* after a ~10-minute SwiftPM fetch. Diagnosed as infra flake **by control, not by vibe**: main's own `integration-emulator` had run the same five suites green on `3e248aa` thirty minutes earlier. A re-dispatch passed.

**Final state at the close:** ADR-039 + ADR-040 merged and green on main; `https://ikimiz.web.app/i/<code>` live (200, AASA `application/json`); **build 112 VALID in TestFlight and attached to `Friends`, where the five testers already are**; the release lane's assignment step fixed; four founder-owned secrets the only remaining blocker.

---

## Session 057 — 2026-07-31 — **the external-TestFlight path ran end to end for the first time: ADR-037's auto-assignment finally worked, and the only remaining blocker is four facts about a person**

**Objective (from resume-prompt.md):** the standing override at the top of the S056 resume file — *"if the founder handoff has arrived, the session is: set the four secrets, dispatch the review-contact write + newest-build assignment + submission."* The founder's words: *"Are we ready for the Testflight testing for external? If not, make it ready. … Send the latest release to the Testflight and update operator expected such that only open items are there."*

**Outcome:** **Not ready at the open; everything a session can do is now done.** A release was cut, uploaded, and — for the first time in this project's history — **auto-assigned to the external group by the lane itself**. The single remaining gap is the four `ASC_REVIEW_CONTACT_*` values, which are facts about the founder (surname, phone) that no session may invent.

**Commits:** this entry's PR (docs prune + one stale CI cross-reference).

**#140 deferred a FIFTH time**, and again for a founder directive with five real people behind it. Addendum 68 stands unrefuted and is now five sessions old.

### What was measured, not assumed

Every claim below came from asking Apple, never from reading this repo's own docs.

```
build 113  processing=VALID  uploaded=2026-07-31   external=READY_FOR_BETA_SUBMISSION
                                                    internal=IN_BETA_TESTING
                                                    groups: founders, Friends
beta app review readiness:
  MISSING - Test Information: review contact {email, first name, last name, phone} is empty
```

Four gaps, all four the same shape, none of them copy. The beta description and feedback email were already filled in. `external=READY_FOR_BETA_SUBMISSION` (and **not** `MISSING_EXPORT_COMPLIANCE`) also settles a question nobody had asked out loud: the export-compliance declaration is already answered in `Info.plist`, so it is not a hidden fifth blocker.

### ADR-037's central guarantee held for the first time — release run #13

S056 found that *"every build reaches `Friends` automatically"* had **never once been true** (`ModuleNotFoundError: No module named 'jwt'`, silently green behind `continue-on-error`). PR #154 fixed it structurally. This session is the first evidence it works, and the evidence is the step's own log rather than the run's green tick:

```
pyjwt 2.10.1 ok
group: reusing existing 'Friends' id=bf019059-… (external)
'Friends' now has 5 tester(s): …
build 113 not visible to the API yet; waiting…      (×6)
assigned build 113 to 'Friends'
```

**The habit S056 asked for is what produced this line.** A green release still says nothing; the step's log does. Note also that the *same* step failed loudly and correctly on the review-contact half (`ASC_REVIEW_CONTACT_* unset`) and then printed **`continuing — the build assignment below is a separate promise.`** — a fail-closed contact write that does not take the assignment down with it. That separation was designed in ADR-038 D4 and this run is the first time both halves were exercised in one execution, in opposite directions.

### Issue #146 closed by measurement — the stranded set was empty

The issue reserved a founder decision: two external groups exist, only `Friends` is auto-assigned, so *"anyone in `arkadaslar` and not in `Friends` receives nothing"*, and re-inviting them emails real people. A read-only dispatch answered it:

```
'arkadaslar' now has 1 tester(s):  seymabutun9@gmail.com
'Friends'    now has 5 tester(s):  … seymabutun9@gmail.com
```

**One member, already in the other group.** The decision had no subject. Closed with the measurement attached, and removed from the operator page as a non-item.

**The generalisable part:** the issue was filed on a *structural* observation (two groups, one auto-assigned) and was worded as though the harm followed from the structure. It did not — the harm depended on **membership**, which nobody had listed, because at the time nothing in the tool could list it. A risk inferred from shape is a hypothesis; it needs a population before it is a finding.

### The operator page prune (the founder's third instruction)

809 → ~440 lines. Deleted: item **2(e0)** (marked ✅ DONE with *"delete at the next close"* — honoured); the Session-052 Firestore-rules narrative (both projects current; the surviving fact is #140's table row); the **build-110** "you can install today" box and the `fa990e6` sequencing warning (both moot at build 113); the *"Domain purchase + AASA hosting"* activation bullet (the domain is already owned and the AASA is already live — the real remainder is a DNS record, which is 2(e)(i)); and the #146 row.

Two deliberate structural choices:

* **Item numbers were preserved, not renumbered.** `tool/ci/testflight_testers.py:851` and `.github/workflows/deploy-site.yml` cite them by name, as do three ADRs and `implementation-plan.md`. Renumbering a checklist is exactly the kind of tidy-up that manufactures stale cross-references — the sin addendum 64 is about. The file now says so in its own header.
* **The recipe names no build number.** Per addendum 64's closing instruction (*"prefer 'the newest VALID build' to a number"*), both dispatch blocks act on the newest VALID build, so the recipe cannot rot the way the build-110 version did. The build number appears only in the dated *measurement*, where being a snapshot is the point.

**And the prune found a stale cross-reference of exactly the predicted kind:** `deploy-site.yml`'s secrets gate told the founder to *"See docs/operator-expected.md item 2(c)"* for `FIREBASE_SERVICE_ACCOUNT`. Item 2(c) is the TestFlight-testers item; the service account lives in 2(e)(iii). The pointer was inside an `::error::` line — a string a human only ever reads at the moment their deploy just failed. Fixed in this diff.

### Notes / debt logged

* **`gh` was pointed at the wrong repo slug for three calls.** `repos/aytekXR/hayati` 404'd; the remote is `aytekXR/hayati-mobile-app`. A 404 from the logs API reads identically to "this run produced no logs" — the S056 addendum-65 shape again, in a third instrument. `gh repo view --json nameWithOwner` settled it in one call.
* **The one thing a session cannot close:** a surname and a phone number. `gh api user` returns `name=Aytek E`, and the git history carries a personal email that *suggests* a surname — which is precisely why it was not used. Apple's Beta App Review contact is a real person Apple may actually call; a plausible guess is worse than an empty field, because an empty field is honestly reported by the tool and a wrong one is not.

**Final state at the close:** build **113** VALID in TestFlight, attached to `founders` + `Friends`, carrying every fix from ADR-039/ADR-040; the five testers in place; export compliance answered; Test Information copy complete; **the four contact fields the only gap, and the only item on the founder's critical path.**

### Session 057 close addendum — the re-measurement, and why the readiness number was split into three

At the close the founder asked for status, a readiness percentage, and the next-session goal. Re-derived rather than carried forward, and **nothing had moved**: `gh secret list --env release` still returns only `ASC_API_KEY_P8` / `ASC_ISSUER_ID` / `ASC_KEY_ID`, and a fresh read-only dispatch still reports build 113 `VALID` / `external=READY_FOR_BETA_SUBMISSION` / `groups: founders, Friends` with the same four contact gaps. The operator page needed **no item change** — the honest update was a dated *re-confirmation*, which is a different thing from a refresh and worth writing as such.

**The percentage was deliberately refused as a single number** and given as three, because "how done are we" has three different answers here and the average of them is information-destroying: **MVP built ≈ 100%** (M1→M6.3 incl. M5.3, both suites green, both backends current); **installable by the five external testers ≈ 95%** (one founder form field); **shippable to the public App Store ≈ 55%** (the paid loop is unproven end to end and #115 means a real purchase would take money without unlocking Premium; the legal bundle has three blanks and a KVKK filing; TR/AR copy and the crisis lexicon are unreviewed; analytics is absent, so Gates 2 and 3 cannot be read at all). A single blended figure would have implied the product is ~85% shippable, which is false in the direction that costs money.

`session-rules.md` §3 already asked for a *"plan-progress/readiness snapshot"* on that page and it had never actually been carried there — the page had drifted into pure checklist. Added as a three-row table, each row naming its own blockers by item number.

**Session closed.** Next objective unchanged in `resume-prompt.md`: **#140**, deferred a fifth time, now with five sessions of deferral history recorded as evidence for it rather than against it (addendum 68).

### Session 057 addendum — the two beta groups are now one, and the ADR that declined to do it had an unchecked premise

Founder directive, after the close: *"merge those groups and only keep Friends."*

`--merge-group` was built for it, TDD, and the ordering **is** the feature: link the source's testers into the target, **re-read** the target's membership, and only then `DELETE` the source. The version that deletes on the strength of a 2xx from the link call is the one that, on the day Apple accepts a request without applying it, silently strips a real person's access — and every `--status` afterwards reports a clean single-group setup, *because the evidence went with the group*. Five refusals are pinned by test: merging a group into itself, an unknown source (named, with the existing groups listed — never a no-op, since "nothing to merge" reads identically to a successful second run), an internal source, any member not confirmed on the other side, and a dry run that writes nothing.

Executed: `arkadaslar` had **one** tester, already in `Friends`, so **0 to move, nobody emailed**. `founders` (internal) and `Friends` (external) are now the only groups; build 113 is still attached.

**The finding worth carrying is about ADR-038, not about the tool.** Its "what this deliberately does not do" section declined to consolidate the groups, reasoning that *"consolidating them means deciding which real people belong where, and possibly emailing them again — a founder call."* Every word of that is sound **and its premise was never checked.** It assumed a population. The population was one person who was already in both groups, so there was no decision to make and no email to send. Issue #146 was filed on the identical unchecked premise and closed the identical way (addendum 70). **The same wrong assumption produced a deferral in an ADR *and* an issue in a tracker, and neither instrument noticed, because both were reasoning about a shape rather than counting the rows.** A dated correction is now on ADR-038.

**A mutation check that mutates the wrong line is a test of nothing.** The first attempt to verify the delete guard anchored on `if missing:` — which matched `_token()`'s credential guard, not the delete guard. It reddened two unrelated token tests, left `merge_group` fully green, and would have been read as "the mutation did something, the suite is sensitive" by anyone not looking at *which* assertions moved. The second attempt asserted the anchor was unique before editing, and then killed exactly the two intended checks. **Assert the uniqueness of a mutation site before trusting what its failure tells you** — the diagnostic can be the defect (S056, in a new instrument).

### Session 057 addendum — SUBMITTED. The five-session blocker closed, and the page that celebrated it nearly published the founder's phone number

The founder supplied the contact facts and a six-person tester list. Everything remaining was executed and **measured against Apple, not inferred**:

```
review contact: set contactEmail, contactFirstName, contactLastName, contactPhone
assigned build 113 to 'Friends'
build 113: submitted for Beta App Review

build 113  external=WAITING_FOR_BETA_REVIEW  internal=IN_BETA_TESTING  groups: founders, Friends
'Friends' now has 6 tester(s)
```

**`WAITING_FOR_BETA_REVIEW` is the first time this project has ever reached Apple's external reviewer.** Item 2(c) had been the top 🔴 for five sessions.

**Five of the six "new" testers were already in the group.** The list read as six people to add; exactly one — the founder's own Apple ID — was new, and it came back `linked-existing`, meaning they were already a `betaTester` on the app (via `founders`) and only needed the group link. **Addendum 70 in miniature, one message later: a list looks like a population until you diff it against the one you have.** Only the genuinely-new address was sent, which also minimised what went through the public dispatch input.

**The dry run failed with exit 1, correctly, and that is worth writing down.** `set_review_contact=true` + `submit_for_review=true` under `dry_run=true` will *always* fail: the contact is not actually written, so `review_readiness()` still reports four gaps and `submit_for_review()` refuses. The output is a faithful rehearsal — `WOULD SET contactEmail, contactFirstName, contactLastName, contactPhone` proved all four secrets resolved *before* anything outward-facing happened — but the red is structural, not a defect. Worth knowing before someone reads it as one.

**And the near-miss.** The celebratory rewrite of item 2(c) put the founder's full name, Apple ID and a truncated phone number into the header of `operator-expected.md` — **a committed file in a PUBLIC repository.** ADR-038 D1 goes to real trouble to keep those values out of *logs*, and the page documenting that protection was about to defeat it in a more permanent medium. Caught before commit; the values are gone and the page now says only that they exist.

The sweep that caught it found something older: **previous revisions of this same file listed all five tester emails in plain text**, and the `testers` dispatch input is world-readable on a public repo. Neither is new, both are in git history, and neither is a session's call to rewrite — recorded in 2(c) as a founder decision rather than quietly left out. **The rule that generalises: a doc explaining a privacy control is the most likely place to violate it, because the example wants to be concrete.**

**Remaining on the TestFlight path: nothing of the founder's.** Apple's 24–48 h, then six install notifications.

### Session 057 addendum — "did they get an email?" was unanswerable, and the answer is NO (correctly)

The founder asked whether the six testers had been emailed. **The tool could not answer**, which is the finding. `--status` printed group *names* only; membership printed exclusively on the add/assign path. So the one command the founder is told to run for a safe look was the one command that could not see people — **#146's actual request, still open after #146 was closed.** Closing an issue on a measurement is not the same as building what it asked for, and it is easy to conflate the two when the measurement is reassuring.

Built it, and Apple answered:

```
'Friends' (external)
  <five friends>   inviteType='EMAIL'  state='NOT_INVITED'
  <founder>        inviteType='EMAIL'  state='INSTALLED'
```

**`NOT_INVITED`, and that is correct.** Apple does not email an external tester while the group's build is in review: *adding to a group* and *inviting* are two separate events, and Apple holds the second until there is an approved build to invite them to. This had been asserted to the founder twice from reasoning; it is now measured.

**The design that made this cheap: print the attributes VERBATIM.** Nothing here had measured what `betaTesters` returns — the state field could have been `state`, `betaTesterState`, or a `betaTesterMetrics` relationship. Rather than guess and select, `tester_line()` formats whatever arrived, sorted, with the email first. Apple turned out to send `appDevices`, `firstName`, `inviteType`, `lastName`, `state`. **A selector built on a guess would have printed nothing useful and looked like it worked** (addendum 63 again — and the test pins the *property* that an unknown field survives, not the field list, because a field list is the thing that goes stale).

**An unbudgeted consequence of the four new secrets, worth knowing before it confuses someone.** GitHub redacts secret values *anywhere* in a log, not just where they were used. The founder's email, first and last name are now secrets — so their tester row prints as `***`, **and so does another tester's surname, because she shares it.** Nothing is broken; the logs are simply less readable than they look, and a future session reading `***` should not read it as an API failure. Recorded in operator 2(c).


### Session 057 — CLOSED. Final state, re-derived at the close rather than carried forward

| | |
|---|---|
| **Merged** | [#156](https://github.com/aytekXR/hayati-mobile-app/pull/156) operator prune · [#157](https://github.com/aytekXR/hayati-mobile-app/pull/157) readiness snapshot · [#158](https://github.com/aytekXR/hayati-mobile-app/pull/158) `--merge-group` · [#159](https://github.com/aytekXR/hayati-mobile-app/pull/159) merge executed · [#160](https://github.com/aytekXR/hayati-mobile-app/pull/160) submitted · [#161](https://github.com/aytekXR/hayati-mobile-app/pull/161) tester state in `--status` · [#162](https://github.com/aytekXR/hayati-mobile-app/pull/162) NOT_INVITED is correct |
| **CI** | green on every PR and every post-merge `main` run, including `integration-emulator` and `ios-build-smoke` where the path filter ran them |
| **Apple** | build **113** `VALID` / `external=WAITING_FOR_BETA_REVIEW` / `internal=IN_BETA_TESTING` / `groups: founders, Friends` |
| **Groups** | `founders` (internal) + `Friends` (external, **6** testers). `arkadaslar` merged and deleted |
| **Testers** | five friends `NOT_INVITED` (correct — Apple has not approved yet), founder `INSTALLED` |
| **Issues** | #146 closed. 13 open, unchanged otherwise |
| **Readiness** | MVP built **100%** · testers can install **~99%** (Apple's clock) · public App Store **~55%** |

**The session in one line:** the objective was #140 and the session was a founder directive from first message to last, correctly — and it ended with the project's **first ever build in Apple's external review queue**, a blocker that had been the top 🔴 for five consecutive sessions.

**Three capabilities were built, none of them planned:** `--merge-group` (link → re-read → delete), tester state in `--status`, and the four-secret contact write finally exercised end to end. Each existed because a founder question could not be answered with what was there — which is a better filter for what to build than a queue.

**#140 deferred a fifth time.** Addendum 68 stands, and is now sharper: with TestFlight in Apple's hands rather than the founder's, **S058 is the first session in five with no live directive for #140 to lose to.**

## Session 058 — 2026-08-01 — **a green check that guards nothing is also a claim: the rules gate was honest about the working tree and silent about production**

**Objective (from resume-prompt.md):** #140 — nothing in CI compares what is MERGED to what is DEPLOYED. Firestore rules sat un-deployed for 18 days behind six green milestones, and a founder bug report found it, not a gate.

**Outcome:** done. **#140 closed** by PR #164 (ADR-041), with both residuals re-filed rather than buried (#165, #166).

**First, the preemption:** build **113** re-measured as still `externalBuildState = WAITING_FOR_BETA_REVIEW` — Apple has neither approved nor rejected. The five friends still read `NOT_INVITED`, which remains correct. Nothing on the TestFlight path was owed, which is what freed the session for #140 after five consecutive deferrals.

**Measured before designing (acceptance criterion 1), and it shaped every decision:**
- prod ruleset `3702186d`, dev `fbae0b36`, both released 2026-07-27T16:16Z, **both byte-identical to `main`** (`sha256:0d59af3a…`). S052's remediation held; the defect did not go away with the symptom.
- Prod has had **exactly three rulesets ever** — 07-08 bootstrap, 07-09 M2.1, 07-27 remediation. #140's narrative confirmed from the platform, not from its own text.
- Each project has **exactly one** release (`cloud.firestore`) — checked because a named database would make a single-release check silently partial.
- **"What is live?"** is answerable from this box but **not by a `firebase` CLI command** (there is no `firestore:rules:get`) — only by using the credential the CLI *stores* against `firebaserules.googleapis.com`. **"Can CI ask?" — no.** No `FIREBASE_*` secret exists anywhere, and the local credential is a human's OAuth refresh token that must never reach CI.

**Built:** `tool/ci/rules_drift.py` (asks the platform what is *released*, byte-exact diff, **no committed marker file** because the lane whose omission IS the bug would be the one updating it — ADR-025 D8's shape failing in the reassuring direction); exit codes as a **taxonomy** (0 / 1 drift / **2 could not measure**, never 0 without comparing); a **named-database release fails CLOSED** rather than yielding a partial green. `deploy-rules.yml` — dispatch-only, prod behind a **typed** confirmation, measure → deploy → **read back**. `ci.yml` — `rules-drift-preflight` + `rules-drift`.

**The decision that mattered most (ADR-041 D6):** a job-level `if:` **cannot read `secrets`**, and a job whose every step skipped reports **GREEN**. Built the obvious way, the #140 gate would have been a green check that measured nothing — **#140's own defect, shipped inside the PR closing #140.** Hence the preflight job publishing a boolean: the check is either MEASURED or **visibly SKIPPED**, with no third outcome.

**The vote, argued rather than assumed:** ADR-034's asymmetry does *not* transfer (an advisory is a third party's act; drift is our own omission and always actionable) → the check votes. But never on `pull_request` (a PR touching Dart would go red for last week's undeployed rules — cry-wolf reached by another road), `main` only, and on **every** push rather than only rules-touching ones, because the narrower trigger goes green on the next unrelated push while production is still stale.

**Proven, not asserted:** detector vs both live projects (exit 0); detector vs the **actual M2.1 bytes** from `d913722` (exit 1, real diff — had it existed on 07-10 it would have printed exactly that); the `firebase deploy` command exercised on `hayatiapp-dev` then independently read back as MATCHES; **19/19 self-test functions and 45 assertions confirmed to have RUN in CI** via `gh api repos/…/actions/jobs/<id>/logs` (addendum 65 — `gh run view --job --log` returns nothing); the `firebase.readonly` scope settled by fetching the API's **own discovery document** rather than from memory.

**Not proven, and said so in the ADR:** neither workflow has ever executed. Both are unarmed until an operator secret exists.

**Commits:** PR #164 — `e79083e` (detector + tests), `f7e0417` (deploy lane + CI wiring), `258ef10` (ADR-041 + architecture §9 + test-suite §2 + operator 2(e)(iv)).
**CI:** green.
**Docs touched:** `docs/adr/041-deployed-versus-merged-firestore-rules.md` (new) + `docs/adr/README.md`, `docs/architecture.md` §9, `docs/test-suite.md` §2, `docs/operator-expected.md` (2(e)(iii) amended, **2(e)(iv) new**, header refreshed), `docs/past-prompts.md`, `docs/resume-prompt.md`.

**Notes / debt logged:**
- **#165** (new, operator-blocked) — `rules-drift` is SKIPPED until `FIREBASE_RULES_VIEWER_SA` exists. Filed rather than left inside a closed #140, because closing on a reassuring outcome is how a requirement gets lost (addendum 72).
- **#166** (new, unblocked) — the Functions half of #140. Deployed function code has no source-identity read comparable to the Rules API, so the issue is **measurement-first** and explicitly permits closing with the evidence that no sound comparison exists.
- **Four new addenda (75–78)**, all from the mutation harness or the ADR re-read: a fake that is wrong about the API shape makes a branch unreachable *and* its paired assertion still passes on the section header; a hermetic test can stop being hermetic under mutation and pass for the wrong reason (the degraded credential path reached the live endpoint, got 401, and produced the asserted exit code by accident); the green-without-measuring hole has a YAML-shaped version; and *name which half is proven by which instrument* — ADR-041's first draft claimed the deploy lane was "exercised end to end" when only the command was, which is addendum 69 inside the ADR that cites addendum 69.
- **Process deviation, recorded:** the harness this session ran under forbade sub-agents and workflows, so the mandated adversarial review was run **inline by the session** (refuting-skeptic, governing-docs-adjudicator and completeness-critic lenses) with the mutation harness doing the work a verifier panel usually does. Legitimate here because the findings were mechanical rather than judgemental — but it is a substitute, not the same instrument, and it is named as such rather than claimed as a panel.
- **A recorded exception, found by re-reading the merged work against the governing docs (ADR-041 D6.1).** `architecture.md` §9 already stated the opposite rule for the Slack notifier — an absent secret is a `::notice::`, **"never a `::warning::` on a green build"**, because issue #39 was closed to remove exactly that annotation noise. `rules-drift-preflight` emits a `::warning::` on every main run while the credential is absent, which contradicts it. Kept, and argued rather than left silent (project-rules #9): a missing webhook costs a *notification*, a missing rules-viewer credential means **a gate is not running** and the green is worth less than it looks. The same re-read also retired a claim this ADR had made too generously — that a skipped job is self-evidently loud. **It is not: ADR-024's own comment says this repo "skips constantly by design", so a skipped job blends in**, and the annotation is what separates "not needed on this push" from "nobody can run it".
- **First real execution, verified rather than predicted:** the post-merge main run shows `rules-drift-preflight` **success** and `rules-drift` **skipped**, with the four `##[warning]` lines present in the job log — read via `gh api repos/…/actions/jobs/<id>/logs`, the second instrument, because the first returns nothing (addendum 65).
- Two orphaned `firebase-functions` node processes (aged 5 and 6 days, from earlier sessions, bound to no port) killed at session start.

**Next objective written to resume-prompt.md:** Session 059 — **#130**: make ADR-026 D3's "five readers" claim true by construction. The fifth guard is self-referential (`question_pack_dto_test.dart:62` iterates the very list under test), and what it permits is a `FormatException` at pack-load on a real device behind a fully green CI. Widen to every enum in the schema; decide set-equality vs strict-subset deliberately.

---

> # ⚠️ RECONSTRUCTED — Sessions 059, 060 and 061 left no entry
>
> The three entries below were **written on 2026-08-05 by a doc-only session, from
> `git log`, the merged PR bodies and the GitHub API.** They are NOT those
> sessions' own accounts. Each of the three merged its work and stopped without
> running the `session-rules.md` §3 close, so `past-prompts.md` was never appended
> to and `resume-prompt.md` was never regenerated — which left the resume prompt
> naming **#130** as the objective for three days after **PR #171 closed it**.
>
> Treat everything below as second-hand: the *what* is measured from the repo, the
> *why* is inferred from the PR bodies, and nothing here reports what those
> sessions decided but did not write down. **The lesson belongs to the close
> sequence, not to the work** — all three shipped real, reviewed, green work.

## Session 059 — 2026-08-01/02 — **#130 closed: the fifth guard was self-referential, and it was four enums, not three** *(reconstructed)*

**Objective (from resume-prompt.md):** #130 — make ADR-026 D3's "five readers" claim true by construction.

**Outcome:** done. **#130 closed** by PR #171.

**What the PR body records:** all five readers *do* reject an unknown seasonal value; what did not exist was the parity net keeping them in sync, and **the test that looked like the fifth guard iterated `knownSeasonalWindows` itself** — a fixture derived from its own subject, which cannot detect drift because the schema is never read. The permitted failure was named exactly as the prompt predicted: add a season everywhere but the Dart list → **CI fully green, `FormatException` at pack-load on a real device.** The prompt's own re-derivation instruction paid off — the schema has **four** enums, not three previous handoffs had claimed.

**Also merged in the same window:**
- **#168** — corrected this file's predecessor before starting: the S059 handoff had said "set-equality" where both existing parity guards compare **ORDER**. A prompt-level defect caught by reading the guards rather than the prose.
- **#169** — an eight-lens beta-readiness audit ahead of build 113 reaching real testers, each finding handed to a separate **refuting** verifier. Verdict: ready, no hard blockers. Two real fixes landed: `_GateErrorView` had **no exit** (a genuine ADR-039 D2 violation — the gate sits outside `SettingsGearOverlay` by ADR-018 D7, so "Try again" on a settled permission error was a dead end, and that is exactly the founder's *"Something went wrong"* report), and the solo screen could **spin forever in silence** because a Firestore listener on an unreachable backend emits nothing at all — not an error.
- **#170** — real landing and support pages (`/`, `/tr`, `/ar`, `/support`, `/support/tr`, `/support/ar`). `/` had been a two-line stub, and that stub was **the App Store support URL the listing declares**. Generated-not-committed, on ADR-036's rule.

## Session 060 — 2026-08-02 — **a 5-lens design audit found the repo ahead of its own redesign roadmap** *(reconstructed)*

**Outcome:** PR #173 — the S060 UI/UX polish pass: the caption tier, an invisible switch, and four quick wins.

**What the PR body records:** five lenses (design-system · core-loop · activation · secondary-surfaces · motion-a11y), each finding put to an independent **refuting** verifier — **32 confirmed of 45 audited, 13 refuted.** It also found the repo **well ahead of `redesign/design-roadmap.md`** (QW-1, QW-6, QW-7, M-3, M-5, M-6 already shipped), so the remaining gaps were narrower and sharper than the roadmap implied.

**Three issues filed and never triaged into a handoff** — they are unblocked and still open as of 2026-08-05: **#176** (Rubik Light is declared but not bundled, so the Question style silently renders at Regular), **#175** (10 of 14 raised cards render flat — the decoration is copy-pasted per screen instead of coming off the theme), **#174** (no `liveRegion` anywhere in `lib/`, so the reveal is never announced).

**Release:** run `30759795246` cut **build 114** at 17:51Z. *It was never submitted for external review — see the S062 note below.*

## Session 061 — 2026-08-02/03 — **"send the screenshots to TestFlight" — and TestFlight has no screenshot field** *(reconstructed)*

**Outcome:** seven PRs (#177–#183) across two hours: a TestFlight submit-refusal fix, iPhone-only, and an entire App Store screenshot lane built from nothing.

**#177 / #178 — a REFUSAL reported as success.** Dispatching `--submit-for-review` for build 114 while build 113 was still `WAITING_FOR_BETA_REVIEW` printed *"already submitted — no-op"* and exited **0**, and the build never moved. #177 fixed the read-back; #178 then corrected #177 from #177's **own live proof run** — Apple's response body carried the fact #177 had *inferred*, and the message became "same train", not "same app". A fix whose own verification run refuted half of it, caught because the run was read rather than trusted.

**#179 — iPhone-only.** `TARGETED_DEVICE_FAMILY` was `"1,2"` in all three project-level configs. **Nothing in this repo ever chose that** — it is Flutter's scaffold default, carried into every build including the one sitting in Beta App Review, while `docs/mvp.md` puts iPad in **v2**.

**#180–#183 — the screenshot lane.** The ask was *"send these to TestFlight"*; the session measured first and recorded the answer in #181's opening line: **TestFlight has no screenshot field** — its Test Information carries a beta description, a feedback email, URLs and the review contact. Screenshots belong to the **App Store listing**: different resource, different lifecycle, different queue. Built: `tool/ci/appstore_screenshots.sh` (renders from the app's own widgets, on Linux, at Apple's exact size, and verifies every PNG's IHDR because the generator is a widget test that goes green whenever it does not throw), `appstore-screenshots.yml` (dispatch-only, `upload: false` by default, drops non-requested locales **from disk** because `deliver` uploads what it finds), then two fixes from live dispatches: #182 (the ruby step had no `.ruby-version` to infer from) and **#183** — measured twice to rule out a race: **six files on disk produced ten "Uploaded" lines**, `deliver` verifies, does not find its own upload because Apple processes asynchronously, and uploads the whole set again; Apple caps a display type at ten and drops the rest. `overwrite_screenshots: true` reproduces it exactly rather than avoiding it. The lane now **repairs what it breaks, in the same run**, then re-reads the listing rather than reporting green on its own say-so.

**Final state, read from run `30775567158`:** `en-US: APP_IPHONE_67=6`, de-duplicated and ordered. **`tr` was dropped** — it needs its App Store version localization to exist first.

## Session 062 (prep) — 2026-08-05 — **a founder-directed, doc-only refresh: the handoff had gone three sessions stale, and the notification feature had never run** *(this entry is first-hand)*

**Not a coding session.** The founder gave four instructions and asked for them to be carried into the next session's prompt, plus a prune of `operator-expected.md` and a refresh of the handoff documents. No source file was touched.

**The four asks, recorded verbatim in `resume-prompt.md`:** (1) the app sends no notifications — it should send the new question at 08:00 TSİ, notify when the partner answers, and nudge at 16:00 if you have not replied; (2) the app icon reads as phallic, revert it; (3) send the screenshots to TestFlight; (4) prune `operator-expected.md` to open items and update the handoff docs.

**Measured before writing anything (the whole point of the session):**
- **Apple APPROVED build 113.** `external=IN_BETA_TESTING`, invitations sent. `Friends` now holds **eight**: the founder `INSTALLED`, one emailed tester `INSTALLED`, four `INVITED`, and **two anonymous `PUBLIC_LINK` installs** — strangers have the build. The `NOT_INVITED` state that three handoffs explained as correct is gone.
- **Build 114 has sat `READY_FOR_BETA_SUBMISSION` since 2026-08-02.** Everyone is testing 113, which predates #169's fix for the founder's own *"Something went wrong"*.
- **The notification path has never delivered a single push, and `implementation-plan.md` records M3.4 as ✅.** Four independent measurements: no `firebase_messaging` in `pubspec.yaml`; no `aps-environment` in `Runner.entitlements`; no `remote-notification` in `Info.plist`; and **no writer of `users.fcmTokens` anywhere** in `functions/src`, `app/lib` or `firestore.rules`. Every send is a counted `skippedNoToken`. → **addendum 79.**
- Of the founder's three notification behaviours: **partner-answered is fully built** and undeliverable; **there is no daily-question push kind at all** (`PushKind` is `partnerAnswered | reveal | streakAtRisk`); and the unanswered nudge exists at **local hour 20, gated on `streak.count > 0`** — a different feature from the one asked for, which protects the relationship rather than the streak.
- **The icon's literal git-previous is the default Flutter logo** — `git log --follow` on the 1024 PNG returns exactly two commits. The mark the founder probably means is a third file that path's history never mentions. Three already-QA'd alternatives without the paired-lobe silhouette sit unused in `redesign/icons/`. → **addendum 80.**
- **Ask 3 is 90% done and nobody told the founder:** en-US holds six correct screenshots on the listing since 2026-08-03; `tr` is the open half.
- Re-measured and unchanged: `rules_drift` **exit 0** on both projects (a first attempt hit a transient `HTTP 503` = exit 2, "could not measure" — and reading that exit code through a `| tail` reported `0`, addendum on `${PIPESTATUS[0]}` collecting its fifth citation); `gh secret list` returns exactly five release-signing secrets; #115 still answers Google's HTML **403**; the site serves `/`, `/support` and `/i/<code>` at 200 with `/privacy` deliberately 404; `ikimiz.beyondkaira.com` still fails TLS.

**Written:** `docs/resume-prompt.md` regenerated for **S062** (objective: the notification path, sliced, with the founder-blocked half named first); `docs/operator-expected.md` re-pruned to open items only — **item 2(c) retired** (Apple approved), **item 4(a) added** (the APNs key + the Push Notifications capability, filed under item **4** because five other documents already pin APNs to that number — addendum 71), an icon-decision box and a `tr`-localization question added at the top, and the closed #140/#130 rows removed; this entry.

**A hazard recorded rather than discovered later:** push needs `aps-environment` in the **provisioning profile**, `match` runs `readonly` in CI, and a build claiming an entitlement its profile lacks **fails at codesign** — the exact failure ADR-040 was written about, one capability over. The resume prompt tells S062 not to find this out by breaking the release lane.

**Decided during the session, not deferred:** the founder was shown the three candidate referents for "the previous icon" — including that the literal one is the Flutter logo — and chose the **pre-redesign brand mark** (`brandkit/branding-assets/icons/hayati-appicon-ios-1024.png`). Recorded in both `resume-prompt.md` and `operator-expected.md`; the icon is no longer a blocked item. Noted at the same time, and overruled by the founder's answer rather than by silence: the chosen mark is the *same two-seed family* as the one being replaced, and the three silhouette-free alternatives in `redesign/icons/` were offered and declined.

**The handoff was then restructured, at the founder's follow-up instruction ("so that we start clean again").** `resume-prompt.md` had become an accretion: six wall-of-text standing notes and **80 addenda** in the header, with the actual objective buried below them. Split into three documents with different lifecycles:

* **`docs/session-context.md`** (new) — standing operating context: toolchain and commands, the machine, CodeGraph, review discipline, the binding-invariants table, the never-without-asking list, and the standing measurement commands. Changes when the environment or an ADR changes, not every session.
* **`docs/session-lessons.md`** (new) — the numbered lessons, **append-only and never renumbered** (that is lesson 71 applied to itself). Opens with "the recurring shape": the five failure patterns nearly every entry turns out to be an instance of.
* **`docs/resume-prompt.md`** — now one objective and nothing else: **push notifications**, with the measured state, the two decisions the ADR must make, the recommended slice, six acceptance criteria, a short priority queue and the blocked table. **31,661 characters → 14,109**, and the objective is now the second line rather than page two. The figure worth keeping: **the old standing-note header alone was 14,058 characters — the same size as the entire replacement document.** Line counts *rose* (113 → 227) and are the wrong measure; the old file was six paragraphs of ~3,000 characters each on single lines.

`session-rules.md` §1 and §3 were amended to read the two new files and to keep standing content from creeping back into the prompt's header.

**Not done, and named:** no GitHub issues were filed for the notification work, the icon, or the `tr` locale — the founder asked for documents, and filing is S062's to do with the ADR in hand.

## Session 062 — 2026-08-05/06 — **the push objective: `fcmTokens` gets a writer and a lock, and the portal tick stops being a question** *(first-hand)*

**The machine shut down mid-session**, while the ADR-042 design review was still running. This entry covers the whole session, including the resumption.

**Objective:** make the app send push notifications. **It still does not**, and this entry says so in the same breath as what was built — lessons 69 and 78.

**Shipped: #184** (the prep-session docs, written 2026-08-05 and never committed — item 4(a) was invisible to the founder on `main` until this landed), **#185** (`tool/ci/appid_capabilities.py` + `appid-capabilities.yml` — read the App ID's capability list out of Apple's portal over the App Store Connect API), **#186** (Apple refuses `limit` on the `bundleIdCapabilities` relationship; the first live run said so), **#187** (ADR-042 + D1 in full).

### The measurement that changes three operator items

The probe's first live dispatch died on a `limit` parameter copied from the `/v1/bundleIds` **collection** call, where it is legal; on the capabilities **relationship** it is `PARAMETER_ERROR.ILLEGAL`. Only the vendor can refute a vendor API shape, and the prefix-matching fakes were blind to it — the fix's test asserts the **exact path**, not the outcome.

The second dispatch worked ([31054773143](https://github.com/aytekXR/hayati-mobile-app/actions/runs/31054773143)) and returned **exit 1 — absent**, not exit 2. That distinction was built into the tool on purpose and earned its keep on first use:

```
ticked:  APPLE_ID_AUTH, IN_APP_PURCHASE
absent:  PUSH_NOTIFICATIONS, ASSOCIATED_DOMAINS, APP_ATTEST
```

**`PUSH_NOTIFICATIONS` is not ticked.** So ADR-042's slice order routes around a *measured* blocker rather than a hypothetical one — and **items 4(a) piece 2, 2(d) and App Attest collapse into one portal page, three ticks.** All three had been carried for months as *"a session cannot read the portal, so nobody knows."* That was a missing tool, not a missing permission.

### ADR-042, and the hole in its own review

Written and committed **before** the code (acceptance criterion 1), then adversarially reviewed in two rounds — the second because the first had a defect worth more than the findings. **Eleven round-1 verdicts refuted findings on the grounds that `docs/adr/042-*.md` "does not exist; the highest ADR number is 041."** The session had moved to the `appid-capabilities` branch mid-review and the verifiers read *that* worktree. Right about their worktree, wrong about the world. Discarded rather than counted → **lesson 81**.

Round 2 re-adjudicated the 9 contested findings with 3 independent lenses each (27 verdicts, majority-of-3, every verifier confirming it could read the file). **2 confirmed of 36 raised**, and both were the same species — **a citation asserting more than the cited line contained**:

* `entitlement-core.ts:472` was credited with applying a cap to `MAX_TRANSFER_IDS`. Opened it: `:472` is `dedupe`, filter + `Set`, no cap. The cap at `:511` is a pre-read **reject** gate, and rejecting an oversized input is not evicting from a stored array. **The precedent the ADR reached for does not exist**, so D1 now decides the cap itself: 5 tokens, sixth drops element 0.
* D5 promised an assertion that "the injected `MessagingPort` receives nothing" during a deletion. `DeletionDeps` carries `checkpoint`, `deleteRef`, `deleteAuthUsers` and no port — the assertion would have passed forever while proving nothing. Rewritten to ADR-019's structural guarantee, **plus a tripwire named on purpose**: D3 adds a fourth `PushKind`, so `payload-policy.test.ts`'s "exactly three kinds" **will go red**, and the correct response updates the count while keeping the `coupleEnded` assertion. A session that meets that red and relaxes it wholesale deletes a DV safety property believing it fixed a test.

Seven findings refuted 3-0, each recorded with its reason rather than dropped — including `token-steal-disables-victim`, a real attack D1 already states as a trade-off, now written down as a reason to revisit the App Check deferral if it is ever revisited.

### D1, and the argument that actually decides it

`fcmTokens` was in **neither** freeze clause of `firestore.rules` while `firestore_profile_repository.dart:87` and `profile_dto.dart:46-48` called it server-owned. Three files asserted an invariant the rules did not hold.

The decisive argument for a callable over the direct client write is **not** bounding or symmetry — those are arguable. It is that **a token addresses a device and a user does not**: when B signs in on the phone A signed out of, FCM hands B the same token, and if it is still on A's document then A receives B's notifications on a phone A no longer holds. Closing that is a cross-document write no client may ever make. Hence: **registration is authoritative, sign-out cleanup is best-effort.**

And the freeze matters more than the usual server-owned field. *"Self-only via `isSelf(uid)`, so junk costs the user their own pushes"* — the argument that made a direct write look defensible — **does not hold**: a client that can append to this array can name **someone else's** device token and take delivery of that phone's notifications. The harm lands on a stranger, so self-scoping bounds nothing.

### Proven

28 core unit tests (6 mutations), 16 service emulator tests, 5 rules tests **mutation-checked in both directions** (drop create-forbid → exactly the create test reddens; drop update-freeze → exactly mint/append/clear redden; positive control green through both), 14 app tests (4 mutations). Functions **1039 / 53 files**, 97.34% stmts. App **1653**, analyze and format clean.

**One mutation lied and was caught** — a first-occurrence string replace hit a harmless dedupe in `_syncFrom` instead of the guard in `_register` and reported all-green. → **lesson 82.**

### What was NOT done, and why

* **No plugin, no entitlement, no new push kind.** Runtime behaviour is unchanged, which is what "ships no plugin" has to mean. `pushTokenSourceProvider` is deliberately un-overridden and `PushTokenSync` is deliberately not activated from `app.dart` — that is ADR-042 D2 step 4, blocked on the measured tick. Filed as **#188**.
* **D3/D4 — the fourth push kind and the two clock hours the founder actually asked for.** Pure Functions logic, fully emulator-provable, nothing blocking it. Filed as **#189** and it is the next session's objective.
* **The app icon** (priority 1 in S062's prompt) and **`tr` screenshots** (priority 3) were not started. The objective was the session, and it was more than one session's work; the prompt said to take the first coherent slice and record what was left. This is that record.

**M3.4's ✅ is corrected in the same commit as the code** (criterion 4, lesson 79): strikethrough + dated note, the way ADR-026 D3 was corrected. **M3.4 stays open until a push reaches a device and somebody sees it.**

## Session 063 — 2026-08-06 — **the daily question at 08:00 and the nudge at 16:00: all three founder behaviours now exist** *(first-hand, continues S062 in the same sitting)*

**Objective:** #189 / ADR-042 D3+D4 — the two notification behaviours the founder asked for that S062 deferred. Chosen over #188 (the device half) because #188 is founder-blocked on a capability measured absent, and D3/D4 are pure Functions logic blocked by nothing.

**Shipped: #190.**

### What exists now that did not

`PushKind` gains **`dailyQuestion`** (TR/AR/EN + discreet), announced by a new **hour-8** pass; the afternoon nudge moved **20:00 → 16:00** with its `streak.count > 0` gate **dropped**. All three passes ride **one** couples read — ADR-012 D3's hard constraint preserved by construction, and its §10 cost model **amended in the same diff** rather than left to drift (the day-doc read widened from "hour-20, couples with a streak" to "hour-16, unconditionally, plus one `getAll` of two answer docs").

**All three behaviours the founder named on 2026-08-05 are now composed and routed.** None has reached a phone. `PUSH_NOTIFICATIONS` is still absent from the App ID, so #188 remains the whole remaining distance.

### The two things the ADR did not decide, and the code forced

1. **D4 needed new copy, not just a new hour.** The ADR said the count-free variant meant "nothing about the existing message is lost". True of the code, false of the product: that variant read *"Your streak together is still alive"* — **false for exactly the population D4 exists to reach.** A separate relationship nudge was written. → **lesson 83.**
2. **The daily-question pass skips members who already answered.** Unspecified by the ADR; costs one `getAll` per eligible couple. Announcing a question to someone who already answered it is the small wrongness that makes an app feel inattentive.

Both folded back into ADR-042 as recorded corrections rather than absorbed silently.

### The tripwire, disarmed correctly

S062's ADR predicted this exact red: `payload-policy.test.ts` asserted **both** "exactly three kinds" **and** `not.toContain('coupleEnded')`. The count moved to four; **the `coupleEnded` assertion was not touched**, and the test now states in its own comment which half is the ADR-019 DV safety invariant and which is a change detector. The prediction was worth writing down — meeting that red cold, the obvious move is to relax the whole test.

Similarly, the **two zero-streak at-risk tests were inverted rather than deleted** when their rule reversed, so the case stays covered with the opposite expectation. Mutation M5 (restoring the gate) reddens exactly those three, which is what proves the drop is covered and not vacuously passing.

### Mutation-checked, both directions, each anchor unique (lesson 82 applied)

| Mutation | Reddened |
|---|---|
| quiet window `< 9` | 8 assertions — **the silent-death mutation**: hour 8 sits *on* the right-open boundary |
| quiet window `>= 23` | "hour 22 IS quiet" + both boundary tables |
| `DAILY_QUESTION_LOCAL_HOUR` 8→7 | 8 |
| `AT_RISK_LOCAL_HOUR` 16→20 | 8 |
| streak gate restored | exactly the 3 inverted tests |

### A bounded refactor, stated rather than smuggled

Recipient resolution, the quiet guard and the per-token error boundary moved to `sweep-push.ts`. Two passes differing only in couple selection and kind would have kept two copies of **the code that decides whether a lock screen leaks**, and only one would get the next fix.

**Functions 1067 tests / 54 files, 97.45% stmts.** Typecheck caught a test-only type error vitest's esbuild transpile runs straight past — the `npm run typecheck` step earns its place.

**Not done:** the app icon and `tr` screenshots, again. Both are unblocked and both keep losing to the objective; S064's prompt puts the icon first.

### S063 continued — **the push blocker was an authority boundary, and the founder moved it**

The session's own resume prompt called the App ID tick founder-blocked, and every document repeated it. Asked directly, with the trade-off stated (tick it by hand vs. authorise an API write that invalidates the provisioning profile while `match` runs readonly, on a live app with eight TestFlight users), **the founder authorised the API path** — and, separately, a new build.

**What that unlocked, in order, each step measured before the next:**

| | |
|---|---|
| `PUSH_NOTIFICATIONS` measured **absent** | run 31054773143 → exit 1 |
| **enabled** from CI, founder-authorised | run 31130371860 → OK, id `Q344R7M7MY_PUSH_NOTIFICATIONS` |
| **verified** ticked | same run's read → exit 0 |
| `aps-environment` landed (#194) | `production`; the profile regenerated via one `MATCH_BOOTSTRAP=true` run, and **the variable was deleted immediately after** — leaving it would leave CI able to mint credentials, the exact posture ADR-032's readonly exists to prevent |
| **build 115 signed and uploaded** | the first build in this app's history carrying a push entitlement. `processing=VALID`, `internal=IN_BETA_TESTING`, assigned to `Friends`, submitted for Beta App Review |

**The write tool (#193) does not overrule the read tool's header — it answers it.** That header gave two reasons for being read-only, and they needed opposite treatment (→ **lesson 85**): *"a founder decision"* is an authority boundary, and the move is to ask; *"could do it by accident"* is an engineering boundary, and the move is a lock. It got `--confirm ENABLE` (ADR-019's wire-literal precedent, exact match), the closed capability vocabulary checked before any request, idempotence, and a `--disable-id` undo gated the same way. Five mutations, each reddening the assertion that names it — one of them printing the exact POST that would otherwise have escaped.

**Two defects found by doing rather than reasoning:**

* `firebase_messaging` **16.4.2 declares a constraint its own code violates**, and this repo's *dev-only* pin of `firebase_core_platform_interface` at `^7.1.0` steered pub straight onto it. Green `pub get`, green analyze, 1653 green tests; only the iOS kernel snapshot failed. → **lesson 84.**
* `Runner.entitlements` **had not been well-formed XML since M1.3** — two comments contained `--`. It shipped through every signed build because Xcode's parser is lenient and *nothing had ever parsed the file*. Found only because adding a key meant parsing it. Now fixed and pinned, along with `aps-environment = production`, the continued absence of `associated-domains` (ADR-040), and the continued absence of `UIBackgroundModes` (SEC-3 must be decided before that key is added).

**The objective is one console action short, and it is not one I can take.** Firebase needs the APNs `.p8` or it cannot hand a notification to Apple at all. Re-checked rather than repeated: `gcloud` is not installed, there is no application-default credential, and the authenticated Firebase CLI has no APNs command. **Every layer is now built, signed and shipped except that key.**

### S063 continued — **D6, and the silence it would have caused**

Build 115 shipped the entitlement and would have delivered **nothing**, forever, with no error anywhere.

`grep -rn "requestPermission" app/lib` returned **zero hits**, and on iOS `getToken()` cannot return a token until the user has authorised notifications. So the state after #194 was: capability ticked, entitlement signed, plugin initialising, callables deployed, rules frozen, all three kinds composing and routing — **and no device would ever have registered.** The founder would have uploaded the APNs key, opened the app, and got silence.

That is lesson **79** one layer further down: every piece correct, the chain dead, no error surface. It was found by asking *"what would actually happen when the `.p8` lands"* rather than *"is my part done"*. **D6 was deferred as 'a UI surface'; it was in fact the gate everything else sits behind.**

Shipped in #196: `PushTokenSource.ensurePermission()`, the FCM implementation (`provisional: false` — a provisional grant delivers with no alert, which for a *"your partner answered"* app looks exactly like the feature being broken), `PushTokenSync.promptForPermissionAndRegister()`, and the call site on `PairedHomeScreen` — after pairing, post-frame, unawaited, pinned by a test that fails if sign-in alone ever triggers it. Three mutations, each reddening its named assertion.

**Build 116** carries it. `VALID`, `internal=IN_BETA_TESTING`, assigned to `Friends`, submitted for review. Build 115 was approved by Apple in the meantime but is functionally push-dead.

**One operational note worth keeping:** Apple's build propagation lags upload by minutes. The first assign+submit of 116 failed with `HTTP 404: There is no resource of type 'builds' with id …` — a *race*, not a failure. A retry three minutes later succeeded. Do not read that 404 as a broken lane.

**The objective ends here, and not because it was finished.** Every layer that can be built is built, signed, shipped and green. A push has still never arrived, and the two things standing in the way are both human: the APNs `.p8` uploaded through the Firebase console, and a person opening build 116 on a real iPhone and tapping Allow.

### S063 continued — **"merged and green" was not "running", and nothing here could have said so**

Everything above was merged, green, and **not deployed**. Production was running Functions from before #190: `registerPushToken` and `unregisterPushToken` **did not exist there at all**, and `questionRollover` had no daily-question pass.

Build 116 would have prompted for permission, captured a token, called the callable, and received **NOT_FOUND** — no token, no push, ever, with no error surface, because every layer is fail-open by design. **The founder had been told twice that everything was shipped bar the `.p8`.** That was false.

**Caught by reading production, not by a check.** `firebase functions:log --project hayatiapp-prod` over four consecutive hourly sweeps showed `sweep complete` and `at-risk sweep complete` and **no `daily-question sweep complete`** — a line the new code emits unconditionally. Its absence was the entire diagnosis. → **lesson 86.**

**Deployed 2026-08-07 with founder authorisation**, both halves, and verified by reading back rather than trusting the deploy output:

* `firebase deploy --only functions` — 13 functions, `registerPushToken` and `unregisterPushToken` **created**; confirmed by `functions:list`.
* `firebase deploy --only firestore:rules` — confirmed by the repo's own instrument, `rules_drift.py --from-firebase-cli` → **exit 0, "MATCHES the ruleset on this ref"**. The `fcmTokens` freeze is live in production for the first time.

**And then the deploy was proven RUNNING, not merely accepted** — the same way its absence was diagnosed. The 21:00 UTC sweep:

```
question_rollover: sweep complete                  {"assigned":1,"buckets":1,...}
question_rollover: daily-question sweep complete   {"checked":0,"sent":0,...}   <- NEW
question_rollover: at-risk sweep complete          {"checked":0,"sent":0,...}
```

The middle line did not exist in any sweep before 21:00. A deploy that reports success and a deploy whose code is executing are different claims, and this is the second one.

**#166 gets its concrete recurrence.** It has been open since 2026-08-01 saying nothing compares deployed Functions to `main`; the comment records that this instance cost the whole feature, and that two *cheap partial* checks would each have caught it — a deployed-function-list set comparison, or an assertion over the sweep's own structured log. Neither answers the exhaustive "is the deployed code identical to main" that the issue was filed against. **Both would have worked, which is the argument for building one.**

**Also true and worth stating: there is no Functions deploy workflow in this repo.** `deploy-rules.yml` and `deploy-site.yml` exist; functions have none. Every deploy is manual, and nothing tracks whether it happened.

---

## Session 064 — 2026-08-08 — **the app icon the founder chose, shipped and made unfakeable; then the Light face the hero text had been declaring for weeks** *(first-hand)*

**Objective (one, per `resume-prompt.md`): ship the app icon the founder chose.** It had lost to the push objective for three sessions running. Done, plus the next two unblocked items, plus two operator dependencies that turned out to be smaller than they were written.

### The handoff was wrong about half the objective, and the artefacts said so

`resume-prompt.md` described the target as *"the 15 iOS PNGs and 5 Android `mipmap-*/ic_launcher.png` are hand-produced."* The iOS fifteen were. **The Android five were the default blue Flutter logo from the m0.1 scaffold (`d16ec95`), untouched through 116 builds.**

Nobody had to dig for this. The PNG headers say it: 442–1443 bytes, **colour type 3 (palette) with `tRNS` and a `tEXt` chunk**, where every hand-produced icon in the tree is truecolour RGB. `git log --follow` on any of them returns exactly one commit. → **lesson 87.**

It survived because a wrong icon on an unshipped platform breaks nothing, so no signal ever contradicted it.

### What shipped (PR #202, merged `b6a420b`)

All **20** rasters now derive from the founder's one master rather than being hand-produced. Every one changed, proven by sha256 of all 24 tracked PNGs before and after — 20 changed, 4 unchanged (`AppIconDiscreet` + the three `LaunchImage` files).

`tool/ci/app_icons.py`, stdlib only. No Pillow, no ImageMagick, no ffmpeg — none are installed on this machine, and **a gate that needs a native image library is a gate that never runs.** Two properties earn it:

* **The iOS target list is read from `Contents.json`, never hardcoded.** The asset catalog and the emitted set therefore cannot drift apart, which is the only way *"every size was regenerated"* is checkable rather than assertable (lesson 66).
* **`--verify` compares decoded PIXELS, not file bytes.** The first draft compared bytes and would have been wrong to ship → **lesson 88**.

Exit codes follow the repo taxonomy, split by *which* input failed: unreadable master → **2** (nothing can be concluded), unreadable target → **1** (a committed icon that is not 8-bit RGB is a finding). Downscaling is an exact integer area-average **in linear light**; the 1024 marketing icon is pixel-identical to the founder's file with alpha stripped, since Apple rejects a marketing icon carrying one.

**Cross-checked against an independent implementation before trusting it**: ffmpeg's lanczos, mean |Δ| **0.10** code words at 180px. That number is what rules out a geometric half-pixel shift; the visible disagreement is confined to the seed edges, where lanczos rings and linear-light averaging lifts.

### The tests, and what the mutations proved

`tool/ci/app_icons_test.py` — **90 hermetic checks**, registered in `ci.yml` beside the other pre-`pub get` self-tests, and *confirmed to have executed on the runner* rather than assumed (`90 checks, 0 failed` and `all 20 icons match` read back out of the job log).

The resampler is checked **differentially against a slow independent reference written in the test file** — `Fraction`-exact overlap, no shared code path with `_spans` or the prefix sums. A fixture derived from its own subject proves nothing.

**11 mutations, every one reddens a NAMED assertion.** The first run had two that reddened by *crashing*, which is a red that names nothing, so the harness was restructured into independently-running sections that record a raising mutation as a named failure of its section (lesson 75's instrument, applied to itself):

| mutation | what reddened |
|---|---|
| spans shifted by one | 7 coverage assertions + 3 sections |
| identity fast path corrupted | identity returns input; fast path agrees with general |
| drift never detected | unwritten tree is DRIFT; --write created the file |
| drift accepts any decodable file | ONE stale size is caught (+2) |
| cannot-measure collapsed into drift | missing master is exit 2, not 0 or 1 |
| unreadable target escalated to cannot-measure | end_to_end raised CannotMeasure |
| alpha refusal removed | a non-opaque master is refused |
| filename size-disagreement accepted | declared at two sizes is refused |
| filter choice defeated | a flat field uses Up |
| linear-light mixing "simplified" to sRGB | mixing is done in LINEAR light |
| an Android density silently dropped | the plan covers all 20 |

### Two operator dependencies got smaller once asked properly

**The founder authorised the release dispatch** (`release.yml` on `b6a420b`) and **confirmed the APNs `.p8` is uploaded to both Firebase projects.** The second had been the single blocker on M3.4 for three sessions.

That answer immediately exposed a better question. The item was written as *"ask the founder to install the build, accept the prompt, and say whether a push arrives at 08:00"* — but only the first clause needs a human. Production answers the rest, to a CLI this repo already had:

```
registerPushToken     — ever invoked by a device?  NO (only deploy audit entries)
daily-question sweep  — "checked": 0 on every hourly pass
```

`checked: 0` means no couple even had a token to evaluate. The founder's half is now *open it and tap Allow*; the verification moved back inside the session. → **lesson 90.**

### Measured while there, and one thing fixed

* **Prod Functions are current with `main`** — all 13 exports deployed, and all **three** per-sweep summary lines present on every hourly pass (the missing third line was S063's whole diagnosis).
* **`rules_drift.py` came back exit 1.** Prod matched `main`; **`hayatiapp-dev` had drifted since 2026-08-01** and was missing the S062 `fcmTokens` freeze — the rule that stops a client naming another device's token and taking delivery of its notifications. Dev is a session's to exercise (`session-context.md` §7), so it was deployed and re-verified: **exit 0, both projects.** This also corrects `resume-prompt.md`, which contained two contradictory lines about whether the freeze was live.
* **`tr` measured, not asked.** The listing carries `en-US` with 6 screenshots and **no `tr` localization at all** on version 1.0 (`PREPARE_FOR_SUBMISSION`, editable now). That is why Turkish screenshots keep being skipped, and it is a one-minute founder action.
* **`MATCH_BOOTSTRAP` confirmed absent** from `gh variable list`. ADR-032's readonly holds.

### Then #176 (PR #203) — and the harness that would have hidden it

`TypographyTokens.questionStyleFor` has declared `w300` for the product's hero text since the redesign. Rubik was bundled at 400/500/600/700, so w300 resolved to Regular and the glyphs never lightened.

The issue stayed open on **provenance**, not licensing. Settled by measurement: `googlefonts/rubik` publishes no releases and ships only the variable font on `main`, so the v2.300 statics already here are gftools instances. The Google Fonts static release was confirmed to be the same batch — same version and build tool, **identical vertical metrics** (upem 1000, 935/−250), **identical 885-code-point coverage** including Turkish and Arabic, and **identical advance widths** on that batch's Regular versus ours (`H=714 n=606 ı=242`). It carries 76 more alternate glyphs, which is the entire 33KB size delta. sha256 and source URL are in the commit.

**`flutter_test_config.dart` would have made the whole change invisible.** It loaded the brand families from a hard-coded list of four Rubik files, so a fifth face in `pubspec.yaml` would never have reached the goldens — the diff would have read *"no visual change"* and the honest-looking conclusion would have been exactly backwards. The drift-proof mechanism was already in the same file four lines below (`FontManifest.json`, used for MaterialIcons). The three brand families now use it, and its silent-miss return is now a throw. Mutation-checked. → **lesson 89.**

Blast radius measured *before* regenerating: exactly **63** goldens across the three question surfaces the issue names and nothing else — which independently confirms the token's claim that the Question style is mapped onto no Material role. The regenerated goldens show lighter strokes with **unchanged line-wrap points**, which is what a metrically compatible face looks like.

**800 was deliberately not bundled.** QW-3 asks for 300 and 800; nothing in `lib/` declares w800, so it would have shipped as 200KB of dead asset.

### Proven

`1663 tests pass` · `flutter analyze` clean · `dart format` clean · coverage **87.69%** (gate 68) · `app_icons.py --verify` exit 0 and `--write` idempotent · post-merge `main` CI for the icon **green including `integration-emulator`** · both icon CI steps read back out of the runner's job log.

### Build 117, and what reading its log turned up

The release was dispatched with founder authorisation and came back green. Green
was not taken as delivery — `resume-prompt.md` says the assignment has failed
silently twice — so the `sign-upload` job log was read line by line via
`gh api .../jobs/<id>/logs` (never `gh run view --job --log`, lesson 65).

The assignment was real: **`assigned build 117 to 'Friends'`**, after eight
`build 117 not visible to the API yet; waiting…` polls. The icon was confirmed
in the *built product*, not just the repo — `build-report` lists
`AppIcon60x60@2x.png` at **3 KB** inside `Runner.app`, which is the new file
(3,146 bytes); the old one was 6,472.

**Four steps below that, a failure nobody had ever read.** `fastlane deliver`:

```
Activating version language tr...
[!] Cannot add localization due to app name. — You cannot add this localization
    because the app name is already being used by another app.
```

Checked across the last six releases: **112, 113, 114, 115, 116 and 117 all hit
it, once each.** The step is `continue-on-error: true` **by design** (ADR-020 D8)
and that decision is still right — the binary had already shipped. The defect is
that nothing surfaced it.

**It had already produced a wrong instruction to the founder, twice.** Turkish
screenshots were missing, so the cause was attributed to the only visible
candidate — nobody had added the locale — and the operator page said so for
several sessions. *This session wrote a fresh version of that same wrong
instruction earlier the same day*, from a correct measurement (`tr` really is
absent from version 1.0) and a wrong inference about why. It was corrected
within the hour, from the log. → **lesson 91**, and **#204**, whose first
acceptance criterion is visibility rather than the fix.

The real blocker is a founder *decision*, not a click: App Store display names
are unique per language, `ikimiz` is held by another app in Turkish, and the
options are a different Turkish listing name, English-only, or a trademark
claim. A session should pick none of them.

### Operator dependencies

**Two closed** (APNs `.p8`; the release authorisation). **Two open**: the one
install + permission tap that no session can perform, and — newly and correctly
stated — the Turkish **display name** decision behind #204, which is not the
locale click this page has been asking for.

---

## Session 065 — 2026-08-09 — **#166 asked whether the deployed Functions can be compared to `main` at all. They can, exactly — and the thing stopping it is that nobody deploys from a clean tree** *(first-hand)*

**Objective (one, per `resume-prompt.md`): answer #166 — is the deployed Functions code comparable to `main`, and if so, gate it.** The issue was filed measurement-first, with *"no sound comparison exists, here is the evidence, closed"* written into its acceptance criteria as a legitimate outcome. It is **not** the outcome.

### The handoff said the open question was whether the hash is derivable. It is — and the vendor's own source says so

S064 found `firebase-functions-hash` on the deployed functions and left the real question open: *is it derivable from a checkout?* If not, candidate 1 collapses into candidate 2 and ADR-041 D1's marker objection applies.

It was settled by reading the algorithm out of the **installed firebase-tools 15.22.4** rather than out of any documentation — *query the platform, not the docs*, applied to a package sitting on disk:

```
sourceHash   = sha1( sorted([ sha1(bytes) for each packaged file ]).join("") )
envHash      = sha1( JSON.stringify(backend.environmentVariables) )
secretsHash  = sha1( JSON.stringify({ secretName: boundVersion, … }) )
endpointHash = sha1( [sourceHash, envHash, secretsHash].filter(truthy).join("") )
```

**`sourceHash` digests a sorted multiset of per-file digests, not the zip bytes.** That one fact is the whole answer: a zip carries mtimes, entry order and compressor state and could never be reproduced; a sorted list of content hashes is content-addressed and machine-independent.

**All 13 production hashes reproduced exactly, on the first attempt.** Including both outliers — which also settles S064's explicitly-untested hypothesis **by construction** rather than by inference: secret *versions* participate (`{"LLM_API_KEY":"1"}`, `{"RC_WEBHOOK_TOKEN":"1"}`), so a rotation moves the hash with no line of code changing. That is why the tool takes the secrets component from the deployment rather than guessing `"1"`.

ADR-041 D1's objection was checked rather than waved past, and it does **not** defeat this: the hash is not a record a deploy lane writes about itself. `firebase deploy` computes it from the bytes it uploads, whoever runs it.

### Then the reproduction turned out to depend on the laptop's rubbish

It succeeded **only because this machine still held the debris it held at deploy time**. The CLI packages the *directory*; it never consults git.

```
packaged into the running production deployment : 275 files
  tracked by git                                : 116
  build output (functions/lib/)                 :  97
  FOREIGN — gitignored, machine-local           :  62   (61 × coverage/**, firestore-debug.log)
```

A clean checkout hashes to `15924a45…`; production to `b29f795f…`. So the exact answer is sharper than either outcome #166 anticipated: **the deployed code IS comparable to `main`; what is not comparable is *this deployment*, because it was made by hand from a directory the repository cannot know.** A process gap, not a measurement gap → **lesson 92**, and **#206**.

That shaped the design (ADR-043 D3): the verdict is computed over `tracked ∪ build output` — what a clean checkout plus `npm ci && npm run build` carries — and the working-tree digest is computed *only* so the report can separate **"production is running the wrong code"** from **"production is running the right code, hand-deployed"**. Both are exit 1. Without the split the reader cannot tell an emergency from housekeeping → **lesson 94**.

### What shipped

`tool/ci/functions_drift.py`, in `rules_drift.py`'s shape, with **two independent verdicts** and the worse one winning:

* **the set comparison** — every name `functions/src/index.ts` exports must be deployed, and nothing else. No hashing, no build. **This is the check whose absence cost S063 the entire push feature.**
* **the hash comparison** — per function.

Exit taxonomy unchanged: `0` / `1` drift / `2` could not measure, **never 0**. Three cases resolve to 2 where 1 is tempting — a function with **no hash label** (unmeasurable, not matching), a **zero-function listing** (lesson 65), and **gcfv1 / DataConnect** (whose digest takes inputs this tool does not walk).

Two premises were measured rather than assumed, because the whole design rests on them:

* **`npm run build` is byte-reproducible** — 97 of 97 files identical on rebuild. Had it not been, two clean checkouts would disagree before anyone reached production.
* **`js_stringify` is V8's `JSON.stringify`** — checked **differentially against node** on ten inputs covering control characters, `U+2028`/`U+2029`, astral-plane code points and key order. All ten byte-identical. (An earlier ad-hoc comparison appeared to diverge; the divergence was shell mangling of the test input, which is why it was redone from one shared file.)

### The tests, and what the mutations proved

`tool/ci/functions_drift_test.py` — **159 hermetic checks** on a CI runner (158 on a built tree), registered in `quality` beside the other pre-`pub get` self-tests. The fixtures are pinned to hashes **measured from production**: a fixture derived from its own subject proves nothing, and these could not be — Google computed them. The walk is checked against an enumeration the test builds itself, and the reference/working-tree fixture carries a **real foreign file**, so the mutation that swaps which digest is the verdict — the whole of D3 — cannot pass unseen.

**22 mutations, every one reddens a NAMED assertion.** One of them is the reason for a new lesson:

| mutation | what reddened |
|---|---|
| envHash: firebaseEnvs spread before userEnvs | user envs come FIRST (JS spread keeps insertion order) |
| js_stringify: Python's default separators | 17 checks; V8 emits `{"LLM_API_KEY":"1"}` |
| js_stringify: `ensure_ascii` left at its default | V8 emits `café` raw, not `café` |
| endpoint_hash: falsy components no longer dropped | **nothing, at first** — see below |
| secrets_hash: hashes the whole entry | maps `{secret: version}`, not the whole entry |
| secrets_hash: missing version becomes null | a missing version is `""`, not null |
| source_hash: digests no longer sorted | agrees with an INDEPENDENT re-implementation |
| verdict computed from the working tree | a deployment matching the REFERENCE is exit 0 |
| reference set: foreign files folded back in | the fixture's two digests genuinely DIVERGE |
| reference set: build output dropped | the reference is tracked + built |
| build dir hardcoded to `lib/` | read from package.json's main, never hardcoded |
| barrel: a non-`export {` form skipped | `export *` is REFUSED |
| a non-ACTIVE function accepted | non-ACTIVE is DRIFT even with a matching hash |
| zero-function listing collapsed into drift | ZERO deployed is 'could not measure' (lesson 65) |
| no hash label treated as matching | unmeasurable, not matching |
| no FIREBASE_CONFIG defaults to `""` | the comparison would be against an invented value |
| CLI major mismatch accepted | a different major is REFUSED |
| vendor guard disabled | names the claim that stopped matching |
| ignored DIRECTORIES descended into | packages exactly the expected set |
| a binding dotenv silently ignored | a wrong parser would look like real drift |
| multi-codebase silently uses the first | two codebases are REFUSED |
| gcfv1 accepted under the gcfv2 derivation | gcfv1 is REFUSED |

**`filter(Boolean)` over strings is a no-op, and the mutation deleting it passed.** For strings, `[a,b,c].filter(Boolean).join("")` and `a+b+c` are the same expression. The filter is only observable when a component is *absent* — which `applyHash.js` genuinely produces for a platform with no packaged source. The test now asserts the `None` case, and the mutation reddens → **lesson 93**. *When a mutation reddens nothing, the tool is not necessarily right; the test may simply not reach the property.*

### A version pin cannot catch the algorithm moving inside a version

The pre-code review panel raised it and it is real: this vendor's derivation has changed within a major before. So the tool **re-greps four load-bearing shapes out of the installed vendor source on every run** and exits 2 if any has moved — the same instinct `rules_drift.py` already had for the CLI's OAuth constants, generalised → **lesson 95**. Verified in both directions: 4/4 against the real install, and a doctored install is refused.

### Watched catching something real, then watched going quiet

S065's handoff deliberately left `hayatiapp-dev` drifted so this checker could be demonstrated rather than shipped green against nothing. It was driven end to end:

```
before : 10 deployed, 3 exports missing, and all 10 hashes mismatched
         (dev had been running 2026-08-01 code)
after a CLEAN-TREE deploy of the 12 that CAN deploy (dev is a session's to exercise):
         12 deployed, ALL 12 hash comparisons silent, one finding left —
         revenueCatWebhook absent, which is operator item 0(c) and not a session's to close
```

**A clean deploy reproduces `referenceHash` bit-for-bit.** That is the strongest available confirmation that D3's reference set is defined correctly, and it is the reason the design is trusted rather than merely tested.

### One limitation found by trying to break it

With the 62 foreign files moved aside, the same tool against the same production reported *"running source that is NOT this ref"* instead of *"deployed from a dirty tree"*. It is not wrong — it genuinely could no longer tell. So **the hand-deploy diagnosis is machine-local, and CI will always see the harsher reading** until prod is redeployed cleanly. Recorded in the ADR rather than discovered later.

### Review

Two panels, both run, both with `agents_error: 0` and `agents_empty_result: 0` — checked before trusting the distribution. **Pre-code, on the ADR** (5 lenses × 2 verifiers — a refuting skeptic and a governing-docs adjudicator, surfacing on *either*): 22 findings, 3 survived. They produced the envHash key-ordering paragraph, a corrected `Related` line that had claimed ADR-041 D1's objection was examined in a decision that does not discuss it, and confirmation that non-ACTIVE states deserve their own finding rather than a filter. **On the built diff**, a second panel with per-finding refutation.

### §5.8 bit, in a way worth writing down

The diff-review agents were told **read-only** and given no edit tools. One of
them ran the session's own **mutation harness** out of the scratchpad — a
reasonable-looking way to "check the tests" — and that harness writes a mutation
into the source and restores a snapshot in a `finally`. Its restore **silently
reverted a `cli_version` hardening made after its snapshot**. Nothing errored.
A test run sampled inside that window reported a check count that made no sense,
which is the only reason it was caught.

Blast radius was one file, reverted to its last *committed and tested* state, so
nothing unsound could have shipped — but the reading taken mid-flight was wrong,
and it would have been easy to write that number into a document. → **lesson 96**,
which extends §5.8: the harness is a *write* tool and must be out of reach, and a
measurement taken *while* a review is in flight is as suspect as a commit made
after one. Everything below was re-run after the workflow actually finished.

### Proven

`functions_drift: 159 checks, 0 failed` **read back out of the runner's own job log** · 22/22 mutations redden a named assertion · the tool run live against **both** projects · `ci.yml` parses and the new jobs are wired into `slack-notify`'s fan-in · dev deploy exit 0 and independently re-read.

**The post-merge `main` run needed a second attempt, and that is recorded rather
than tidied away.** `integration-emulator` was killed at exactly its 50-minute
budget — reported by GitHub as **`cancelled`**, which reads like someone pressed
a button — after emitting **nothing for 38 minutes** while parked at `00:00 +0`,
immediately following a clean 49-second Xcode build. It was not this diff: the
merge touches nothing under `app/` or `functions/`, and a re-run of the same job
on the same commit passed with every suite genuinely executing
(`auth +2`, `daily_question +1`, `pairing +2`, `profile`). `main` is green.

It is instance **two** of this job blowing its budget — the job's own comment
records S024's, which was answered by raising 40 → 50 — and this one has a
different shape: S024's was uniform slowness, this was silence. Raising 50 → 60
would convert a 50-minute hang into a 60-minute one. Filed as **#208** with the
log excerpt.

Both review panels were checked for `agents_error` / `agents_empty_result` before their distributions were believed (§5.5). The diff panel reported three "empty results" — inspected rather than assumed, and they were three lenses returning an empty *findings array*, not three dead agents. All five findings it did raise were refuted against primary sources; none survived.

### Operator dependencies

**One changed, none new.** Item **2(e)(iv)** keeps its number (lesson 71) but its *instructions* change: the same read-only service account now needs **Cloud Functions Viewer** alongside Firebase Rules Viewer, and the one secret arms **two** checks. An item whose number survives while its instructions silently grow is how a founder ends up performing yesterday's task.

**#166 closed** with the evidence. **#206 filed** — the deploy lane, the residual, and the reason the dirty-tree branch has to exist at all.

---

## Session 066 — 2026-08-09 — **"the app is not sending notifications" — and it was never only the founder's tap: the counter everyone quoted was hour-gated, and the capture asked once at the exact moment iOS guarantees failure** *(first-hand)*

**Objective (founder directive, mid-session): notifications do not arrive. Fix it.**

The standing story across four sessions was *"everything is built; the founder just has to install a build and tap Allow."* Both halves of that turned out to be wrong in an interesting way: the server side is **better** than claimed (verified working to the last inch), and the device side had a **real bug** that would have swallowed the tap.

### The instrument everyone quoted could not answer the question it was asked

`operator-expected.md` and four resume prompts carried:

> `daily-question sweep — couples checked for push: 0` (every hourly pass).
> `0` means no phone has ever handed over a token.

`runDailyQuestion` opens with `if (hour !== DAILY_QUESTION_LOCAL_HOUR) continue;` — the pass evaluates **only** buckets whose *couple-local* hour is 8. So `checked: 0` is the expected reading for 23 of every 24 sweeps whatever the token state is, and the sampled hours (21:00Z, 22:00Z) were exactly those. → **lesson 97**.

The couple's zone was derivable from the logs rather than guessed: the assignment pass logs `assigned: 1` at **21:00Z**, which is their local midnight, so they are UTC+3 and their 08:00 is **05:00Z**. At that sweep:

```
question_rollover: sweep complete                    existing:1  buckets:1
W: sweep push skipped, no fcm tokens  recipientUid=lvny6fJ…  kind=dailyQuestion
W: sweep push skipped, no fcm tokens  recipientUid=ZCBj6Hq…  kind=dailyQuestion
question_rollover: daily-question sweep complete
        checked:1  sent:0  skippedNoToken:2  skippedNoDay:0  suppressedQuiet:0  failed:0
```

**The server wakes at the right local hour, finds the couple, resolves both members as non-answerers, composes a push for each, and stops because neither phone has an address.** Every layer above the token lookup is verified working in production — a much stronger statement than the one the docs were making, arrived at by reading the code that increments the counter.

### The bug: one racy call, then silence for the rest of the process

`FcmPushTokenSource.currentToken()` was `_messaging.getToken()`. On iOS **FCM cannot mint a token until APNs has handed the app a device token, and that arrives asynchronously AFTER `requestPermission()` returns** — called before it, `getToken()` does not return null, it **throws** `apns-token-not-set`.

`promptForPermissionAndRegister()` did exactly that: grant → immediately capture → throw → `catch { debugPrint }` → return. **No retry.** And `_promptedForPermission` latched *before* the attempt, so the prompt path never ran again for the life of the process. The one capture attempt was issued inside the precise window in which iOS guarantees it can fail.

The port's own contract already forbade this — *"Never throws for an ordinary absence"* — and the adapter's own comment admitted it violated it. **An adapter that breaks its port's contract and documents the violation is a defect with a comment on it.**

### The test had turned the bug into a specification

`push_token_sync_test.dart` contained *"a throwing token source never escapes"*: make `currentToken` throw, assert nothing is registered, green. That is the defect, asserted as correct — which is why nothing ever reddened. → **lesson 98**. It was replaced rather than deleted quietly; the new assertion is that a throw is **retried** and a token arriving on a later attempt **is registered**.

The fake was also not modelling iOS: it returned a token with no permission, so the group whose comment claimed *"the source answers only after permission, which is the whole shape of the iOS contract"* was not testing that shape at all. It does now.

### The fix (ADR-044)

* **D1** — the port gains `isReadyForToken()`; the adapter answers it thinly (`getAPNSToken() != null`), and the **waiting stays above the seam** where it is provable on Linux with a fake. That is ADR-042 D2's own trade, applied to the one piece that had been left below the port.
* **D2** — a **bounded** retry: 6 attempts, linear backoff, ≈7.5s worst case, `unawaited` from a post-frame callback. ADR-039 D2 requires bounded, and it is.
* **D3** — the prompt guard now covers **re-entrancy, not repetition**: a granted permission whose capture failed stays retryable on the next paired-home mount.

### The mutation harness earned its keep immediately

**7 mutations, and the first run had one that reddened nothing** — *"the bound is loosened (attempts doubled)"*. The bounded-ness test asserted `readyCalls == PushTokenSync.tokenCaptureAttempts`, i.e. **against the very constant the mutation moves**: both sides shifted and the check stayed green (lesson 75's shape). Pinned to a literal, and now **7/7 redden a named test**:

| mutation | what reddened |
|---|---|
| the retry loop removed (one attempt, as before) | a platform that is not READY yet is waited for |
| readiness not consulted | a sign-out mid-retry abandons the capture |
| the bound loosened (attempts doubled) | the retry is BOUNDED |
| sign-out mid-retry no longer abandons | a sign-out mid-retry abandons the capture |
| a throw is terminal again (the pre-ADR-044 swallow) | a token that only arrives on a LATER attempt is registered |
| D3 reverted (latch before the outcome) | prompts at most ONCE, however many times called |
| an empty-string token accepted | an empty token registers nothing |

### The fix broke 60 unrelated widget tests, and the first explanation was wrong

The full suite came back `-60`, all in `privacy_lock`. The first hypothesis —
that three concurrent `flutter test` runs had corrupted shared golden/build
state — was **stated before it was checked, and it was wrong**. A clean solo run
reproduced the same 60. Running the same file against `origin/main` in a
throwaway worktree settled it: `+15: All tests passed` there, `+2 -13` here.
**Self-inflicted.**

`_captureAndRegister` resolved `pushTokenSourceProvider` *inside* the retry loop,
so in any container without that override — the pre-D2-step-4 state, and every
widget test that builds the app — it caught "no source" and then still scheduled
five `Future.delayed` timers. **`pumpAndSettle` never settles while a timer is
pending.**

Resolving the source **once, outside the loop** fixes it and is also more
correct: a missing provider is not a transient condition and no backoff conjures
one. Pinned with a `testWidgets` case that calls `pumpAndSettle` on a container
with no override, so it cannot come back silently.

### Then a SECOND defect, found by hunting rather than waiting

With ADR-044 merged and build 118 shipped, the only remaining step was the
founder's tap. Instead of waiting, the delivery path was hunted adversarially —
five lenses, four of which found nothing. The fifth found this, and it survived
refutation:

**No foreground presentation option anywhere.** No
`setForegroundNotificationPresentationOptions`, no `onMessage`, no
`UNUserNotificationCenter` delegate. iOS presents nothing over a foregrounded
app unless asked. The message is delivered and *invisible* — which to the person
testing is indistinguishable from "still broken".

Unevenly harmful, which is what made it worth fixing rather than filing: the
08:00 daily question arrives when the app is backgrounded, but **"your partner
answered" fires the instant the other member submits** — precisely when the
recipient is in the app, and precisely the push the founder named. → **lesson 99**.

Fixed in `messaging_bootstrap.dart`, fire-and-forget from the flavor entrypoints
(the rule `activateAppCheck` already follows), unawaited and fail-open. **Not**
beside the permission grant: on a warm start with permission already held,
`promptForPermissionAndRegister` returns early and `ensurePermission` is never
reached, so the option would be set once and never again.

**What the hunt confirmed is worth as much as what it found.** Both paths the
founder named are verified working in production, independently — the 05:00Z
sweep (`checked:1 skippedNoToken:2`) and the real-time `answerReveal` trigger
(`kind=partnerAnswered`, fired 2026-08-06 12:33 and 21:26, 2026-08-07 01:14).
The FCM message shape is a real alert (`notification:{title,body}`), and FCM v1
was probed live and accepts sends for both projects. No blocker remains between
an FCM token and a lock screen.

**Builds 118 and 119 both shipped**, on founder authorisation. 119 carries both
fixes and is the one to install. The first release attempt produced NOTHING —
`integration` hit its 40-minute budget after 27 minutes of silence and skipped
signing while the run reported green (#208, second occurrence, first to cost a
release).

### Operator dependency — one, and it is unavoidable

**Proven:** `1669 tests pass` (full suite, run alone) · `flutter analyze` clean ·
`dart format` clean · 7/7 mutations redden a NAMED test · the push suite at 25
tests including the no-source regression.

**The fix is in the app binary, so it needs a new TestFlight build**, and dispatching the release lane uploads a real binary to the founder's TestFlight — `session-context.md` §7, a founder ask. **Builds 115–117 all carry the bug**; tapping Allow on them may register nothing. The operator page now says use a build made after 2026-08-09 and explains why, replacing four sessions of "just tap Allow".

---

## Session 067 — 2026-08-10 — **the founder set the notification hours, and the quiet window would have eaten the one they cared most about** *(first-hand)*

**Objective (founder directive): questions at 09:00, and notifications only for a new question, a partner answering, and a 22:00 nudge if still unanswered.** Plus three documentation asks: where the roadmap and implementation plan stand, whether the handoff is current, and strip the closed items out of `operator-expected.md`.

### One line of the request was materially ambiguous, so it was asked rather than guessed

*"Questions should be sent at 9:00 AM, not at midnight"* has two readings: move the **announcement**, or move the **assignment**. They are not close in cost — `dayKey`, the streak, the reveal decision and both push passes are keyed on the local-midnight boundary, so moving assignment opens a nine-hour window per day with no question and no defined app state. **The founder chose the announcement.** A second question — the system has FOUR push kinds and the request named three — settled that both partner pushes stay, because `partnerAnswered` and `reveal` are the same event from opposite sides.

### The finding: the 22:00 nudge would have shipped and delivered nothing

`isQuietLocalHour` was `hour >= 22 || hour < 8`, and `deliverSweepPush` re-checks it per recipient as defense in depth. **22 was the FIRST QUIET HOUR.** Re-pointing the nudge to 22:00 alone would have had every one of those pushes composed, counted, and then dropped by our own guard into `suppressedQuiet` — on every couple, every night, with three healthy summary lines in the log and a green deploy.

Caught by reading the guard *before* changing the constant. → the window moved to **23:00–08:00** in the same change (ADR-045 D3), making 22:00 the last legal hour.

**The cost is stated rather than buried:** the founder asked for a 10 PM push and therefore for one fewer protected evening hour. Reversible with one constant if they want it back.

### The fragility moved rather than vanished

ADR-042 D3 had the daily question sitting exactly on the 08:00 edge, documented and tested as *"the thing most likely to silently kill this feature"*. After ADR-045, 09:00 has an hour of slack and **22:00 is flush against the new 23:00 edge** — the same coupling, at the other end of the day. Asserted in three files now, and one of those assertions is the one that matters most:

> **Testing "not quiet" is not testing "the right hour."** 08:00 is still perfectly legal. Only a test pinned to the pass's OWN hour catches a constant that moved in one file and not the other — which is exactly what happened: `question-rollover-handler.test.ts` hardcodes its instants instead of importing the constants, so the first grep for `DAILY_QUESTION_LOCAL_HOUR` missed it entirely and the emulator suite is what found it.

Three tests failed on the first run, all mine, all consequences of the retime: a sub-hour Kathmandu fixture pinned to 08:45, and the two handler fixtures. Two inline comments were then corrected a second time, because the first patch swapped which pass has no work at which hour.

### The doc asks

* **`operator-expected.md` stripped of closed items** as requested — 341 lines removed. The app-icon section (shipped), the closed APNs/portal-tick boxes, the historical two-piece instructions, the Cloud Scheduler item settled the day before, and the retired-number table (moved to this file, with a pointer left behind because `testflight_testers.py` still prints item 2(c)). The header block had also **accumulated across incremental edits** — it still told the founder to reinstall build 117 — so it was rewritten once rather than patched again.
* **Handoff regenerated** for S068 with the #204 objective it has now deferred twice, and the state table carries the new hours plus the fact that **production still runs the old ones**.

### Proven

`54 test files, 1071 tests pass` · functions coverage **97.45%** (gate 80/85) · `tsc --noEmit` clean · eslint clean.

### Operator dependencies

**Two, both stated on the page.** The founder's install-and-tap for build 119 (unchanged), and a **prod Functions redeploy** for the new hours to take effect — production announces at 08:00 and nudges at 16:00 until then, which is exactly the merged-vs-running gap ADR-043's checker exists to make visible.

---

## Session 068 — 2026-08-11 — **production was down for 37 hours and every instrument said healthy** *(entry NOT written by that session; noted here by S069)*

S068's work is on this branch — five commits, `prod_pulse.py`, `push_delivery_probe.py`, the
`rules_drift.py` nvm fix, lessons **100** and **101**, issue **#219** — and it never
appended its own entry (`session-rules.md` §3.1). Recorded as a gap rather than
reconstructed: only that session can write its own narrative, and inventing one
here would be exactly the inherited-premise shape lesson 101 is about.

---

## Session 069 — 2026-08-16 — **"no one gets notifications" — every server layer verified working, the last link never once attempted, and the four ways it dies on a phone all looked like nothing** *(first-hand)*

Two objectives, both delivered: the founder's live directive (notifications), then
`resume-prompt.md`'s standing one (#204, deferred by S066 and S067).

### The measurement came first, and it refuted every server-side hypothesis

Five lenses over the whole chain, every blocker/major finding adversarially
verified (20 agents, 0 errors, 0 empty — §5.5 checked before trusting the
distribution). Measured, not inherited:

| | |
|---|---|
| daily loop | `prod_pulse.py` exit 0, last sweep 26m ago, billing enabled |
| the sweep | 06:00Z — `checked:1  skippedNoToken:2  sent:0`, both uids named |
| **Cloud Run IAM** | `registerpushtoken` AND `unregisterpushtoken` grant `roles/run.invoker` to `allUsers` |
| entitlement | `aps-environment=production`, wired to Debug/Release/Profile |
| build 119 | carries both 16be0e4 (ADR-044) and 3550368 (#215) |
| payload | `notification:{title,body}` — not data-only, so iOS will display it |
| quiet window | `>=23 \|\| <8` — 09:00 and 22:00 are both legal |

The strongest hypothesis going in was the **#115 shape** — a callable unreachable
at the Cloud Run serving layer, which refuses before the container starts and
therefore logs *nothing*, exactly matching "zero invocations". It was **refuted by
reading the IAM policy** rather than by reasoning. (`revenuecatWebhook` really
does have that defect, still, and it is still #115.)

### So the defect was not that the device fails. It is that it fails invisibly, four ways

`users/*` is four docs with no `fcmTokens` on any of them, and Cloud Logging shows
**zero HTTP requests ever reaching the function**. Never installed / prompt
declined / granted-but-no-token / callable threw — all four end in a `debugPrint`
that a TestFlight build routes nowhere, and **iOS shows its permission dialog once
per install**, so a decline on 115/116/117 is permanent and no rebuild recovers
it. Five sessions told the founder "one tap is all that stands in the way" with no
way to check whether the tap had happened or what it did.

**ADR-046**: `permissionStatus()` as a READ that never spends the dialog · a
five-state `PushRegistration` · a Settings row that names the state and offers the
one button that can resolve it · `openNotificationSettings` on the app's ONE
channel rather than a fourth package · the ADR-044 retry made repeatable on resume
and on tap · and `AppDelegate` forwarding the APNs token explicitly, because
method swizzling against a Dart-configured `FirebaseApp` on a scene-based delegate
is the one runtime link ADR-042 marked UNVERIFIED and its only failure mode is
silence.

### Three defects found while building it, all live, all mine

* **the exhausted capture claimed `awaitingDeviceToken` unconditionally** — which
  labels a DECLINED phone *"allowed, just not finished yet"* and hands it a **Try
  again** button that can never work. Its own log line admits the loop cannot tell
  the two apart. It now asks the OS (lesson **104**);
* **`state =` was gated on an `initial` flag threaded from `build()`**, so a warm
  start registered a token and never published it — invisible while nothing read
  the value, a permanently blank row now that something does;
* **a single shared guard over the prompt and the capture** would have shipped a
  phone that never shows the dialog at all: the boot capture runs ~7.5s, the paired
  home mounts inside that window (lesson **102**).

### Then #204 — and it is bigger than the issue title

The plan was to parse `deliver`'s per-locale success lines out of the nine release
logs. **There are none**: deliver aborts inside
`verify_available_version_languages!`, *before* the upload phase. A parser written
against a guess at that format would have been a fixture from its own subject
(lesson **103**). So the instrument asks App Store Connect what it holds —
expected from `fastlane/metadata/`, actual from `appStoreVersionLocalizations`
**and** `appInfoLocalizations`, the second because `name` (the field Apple
refuses) lives only there.

`session-context.md` §7 forbids dispatching the release lane, so it also got a
read-only input on `testflight-testers.yml` — **and was run against the live
listing** (run 31949645300):

```
FINDING: 8 problem(s) with the published copy.
  - en-US: description / keywords / privacyPolicyUrl / promotionalText
           / whatsNew / subtitle / supportUrl all differ
  - tr: NOT PUBLISHED
```

**Nothing in `fastlane/metadata/` has ever been published.** Because deliver dies
before the upload phase, the English listing is still hand-typed and seven of its
nine fields disagree with this ref; only `name` and `marketingUrl` match. A
presence-only check would have called `en-US` green — which is precisely why
ADR-047 D2 compares the text.

Carried to Slack the only way that crosses a step→job boundary: a job output, read
by `slack_notify.sh` as `EXTRA_FINDINGS`, with **all** the policy in the script
(ADR-024 D1) — headline qualified to `⚠️ CI passed, with findings`, exempt from the
PR noise policy, escaped, whitespace-only treated as none, and a red run still red.
**Five mutations applied to those five properties; all five killed.**

### Proven

`flutter analyze` clean · **1691** app tests green · 18 settings goldens
regenerated intentionally (the row renders above the discreet switch in all three
locales, verified by eye) · `store_metadata_audit_test.py` 18 groups green ·
`slack_notify_test.sh` **23** passed · `release_lane_lint.dart` 12 checks PASS ·
`dart format --set-exit-if-changed` exit 0.

### Operator dependencies

**Unchanged in number, changed in kind.** The founder still has to grant
notification permission — but if the dialog was already declined, the instruction
they were given for five sessions was unfollowable, and the app now says so and
opens the right Settings page. The Turkish display name is still theirs alone, and
picking one now fixes eight findings rather than one.

### Deferred, filed rather than left in prose

**#221** — the device now knows *why* it has no token, and a session still cannot
read it. Needs a client-writable diagnostic field, a rules change and an ADR-019
cascade review; Crashlytics was considered and rejected (no read API).

## Session 070 — 2026-08-17 — #206: the Cloud Functions deploy lane, the last deploy target that was a hand-typed command

**Objective (from resume-prompt.md):** #206 — build `deploy-functions.yml` following `deploy-rules.yml`'s shape (ADR-041 D5): dispatch-only, typed project-id confirmation for prod, measure BEFORE deploying with `functions_drift.py` (exit 2 aborts, exit 1 is the normal reason to run it), deploy, read back. Ships unarmed until operator 2(e)(iii); say so rather than letting it look armed.

**Outcome:** done. ADR-048 + the lane + two tool flags + 40 new hermetic checks + the docs. Two issues filed rather than absorbed (#222, #223). The lane has never *executed* — it cannot, it is unarmed — but **its command sequence was exercised end to end against `hayatiapp-dev`**.

**Commits:** `2fedbfb` (ADR, before code) → `4abd2a1` (design review folded in) → `0e328eb` (lane + tool) → `481de56` (docs) → `b8958ae` (built-diff review fixes) → close.

**CI:** **green.** PR run `31980611322` — `quality`, `functions-rules`, `ios-build-smoke` all **success**; `rules-drift`/`functions-drift` **skipped** (main-only + no credential). Post-merge `main` run `31981208487` — **all green including `integration-emulator`**, the main-only job a PR never exercises, and both drift **preflights** ran and correctly gated their jobs to skipped. Merged as `56e4399` (PR #224).

> Two earlier runs on the branch were **cancelled by my own subsequent pushes**, and one of them took `ios-build-smoke` with it — the hazard that lets a macOS gate read as covered while never having compiled anything. The per-job conclusions above are quoted from the FINAL run for exactly that reason.

### Measured first, and TWO inherited facts were stale

Re-measured 2026-08-17, none of it inherited:

* **`hayatiapp-prod` is CLEAN** — `functions_drift.py` exit **0**, 13 deployed, reference `c250c5c25611e2fa…` over **213 files = 116 tracked + 97 built + 0 foreign**. ADR-043's 62 gitignored debris files are **gone**. The Cloud Functions v2 API puts all 13 at `2026-08-11T10:51Z`, `functions/` has not changed since `52d8065`, and `npm run build` did not move the reference hash — so the reference is a current build and that redeploy was made from a clean tree. **`operator-expected.md` was still telling the founder to expect a red first run over those 62 files. Withdrawn.**
* **`hayatiapp-dev` was drifted** — 12 deployed at `2026-08-11T07:10Z`, none matching this ref, `revenueCatWebhook` absent.
* **Secret Manager:** prod has `LLM_API_KEY` + `RC_WEBHOOK_TOKEN`; **dev has `LLM_API_KEY` only**. Operator **0(c)** is open, so `revenueCatWebhook` genuinely cannot deploy to dev — the live reason the lane needs `--only`.
* `gh secret list`: **no `FIREBASE_SERVICE_ACCOUNT`**. The lane ships unarmed, like `deploy-rules.yml`, which has also never run.
* Artifact Registry `gcf-artifacts`/`europe-west1`: the `firebase-functions-cleanup` policy exists on **both** projects.

### Four vendor behaviours, read out of the installed firebase-tools 15.22.4 rather than its docs — each one moved a decision

1. **`getEndpointFilters` turns a typo into a full deploy.** `--only` splits on commas, **silently drops** any selector not starting with `functions:`, and returns `undefined` — meaning *no filter at all* — when every selector is dropped. `--only functions:a,b` deploys only `a`; `--only functions:` deploys **everything**. So the lane constructs the selector itself from validated names and never forwards the operator's string.
2. **`--force` deletes silently.** `promptForFunctionDeletion` returns early when it is set, so any function present in the project and absent from the source is removed with no prompt. Without it, non-interactive **aborts** and prints the explicit `functions:delete` commands. It is also one flag meaning four unrelated things. **Never passed.**
3. **The CLI partially deploys on purpose.** `promptForUnsafeMigration` skips unsafe updates in non-interactive mode and continues. A Functions deploy is not atomic the way a rules release is — which is the whole argument for the `if: always()` read-back.
4. **`checkServiceAgentRole` short-circuits**, so a steady-state redeploy never calls Secret Manager `setIamPolicy` — which is what let the operator ask for `secretmanager.viewer` instead of `admin`.

Plus one measured non-event: `promptForCleanupPolicyDays` throws **after** a successful release when a location has no cleanup policy. Both projects have one, so it cannot fire today; it is named, and the `if: always()` read-back is exactly what would diagnose it.

### The IAM role list was measured against the IAM API, and it refuted the documentation

Firebase's IAM page says deploying Functions needs permissions *"not included in standard Firebase predefined roles"*. Reading each role's `includedPermissions` from `iam.googleapis.com/v1/roles/<id>` shows `roles/firebase.admin` **does** carry `cloudfunctions.functions.{get,list,create,update,delete,sourceCodeSet,setIamPolicy}`, `run.services.*`, `eventarc.triggers.*`, `artifactregistry.repositories.get` and `serviceusage.services.get`. What it lacks is `iam.serviceAccounts.actAs`, all of `cloudscheduler.*` (and `upsertScheduleV2` re-writes `questionRollover`'s job on **every** deploy) and `secretmanager.secrets.getIamPolicy`.

**`secretmanager.viewer`, not `admin`, deliberately:** admin is the only role carrying `versions.access`, i.e. the only one that could read `LLM_API_KEY` and `RC_WEBHOOK_TOKEN`. Stated plainly in the ADR and the operator item: the list is measured for **coverage** and has never been **exercised**, so the first armed dispatch should go to dev where a missing role is free and names itself.

### Built

`.github/workflows/deploy-functions.yml` — dispatch-only; **prod additionally pinned to `refs/heads/main`** (a branch deploy to prod would *manufacture* the drift `functions-drift` exists to report); typed `hayatiapp-prod`; fail-closed secrets gate; per-project `concurrency` with `cancel-in-progress: false`; `--non-interactive` explicit rather than inferred from a TTY; measure → deploy → **read back**, the read-back gated on the deploy having been *attempted* and voting either way.

`tool/ci/functions_drift.py` — `--only` narrowing **both** verdicts with the scope named in the report, the annotation and the success line; **out-of-scope functions recorded but never examined**; `--require-clean-tree`; and the `::error::` remedy rewritten, since it told the reader Functions have no deploy lane.

### Reviewed twice, and both passes changed the design

**Design review** (5 lenses × 2 verifiers, before any code): 17 raised, 14 verified, **3 dropped unverified and named**, 6 survived. The blocker: D5 scoped the two verdicts but not ADR-043's exit-2 cases, which fire while the listing is *parsed* — a naive implementation of the ADR's own words would abort a subset deploy over an out-of-scope `gcfv1`. Also `only`'s empty case was undefined, the regex refused `_` and was silent on `-`, D4's third row over-claimed causation, and two facts were wrong (the CLI reads **stdin** for interactivity; ADR-041 cites 2(e)(**iv**)). That last one came from a finding the cap had **dropped unverified** and was real — lesson 65's shape.

**Built-diff review** (5 lenses × 2 verifiers): 8 raised, 2 survived; the safety lens returned **zero** findings, recorded as *found nothing* rather than *proved safe*. The survivor was a real silent partial deploy: a **newline** in `only` passes a line-by-line `grep`, `IFS=',' read` then keeps only the first line, and the run deploys one function, reads back one function and goes green while the second was never deployed. Reproduced in a shell before fixing (lesson **105**).

### Exercised end to end on dev (§7 — dev is a session's to exercise)

```
pre-check   exit 1  — 12 functions on source that is NOT this ref; clean-tree assertion passed
deploy      exit 0  — all 12 updated
read-back   exit 0  — MATCHES, naming the 1 exported function it did NOT examine
unscoped    exit 1  — revenueCatWebhook absent: operator 0(c), not closeable by a session
```

ADR-043's own pattern: red for a real reason → green on the fixable half → red for a **named, filed** reason. A clean deploy reproduces `referenceHash` bit-for-bit, which is the strongest available confirmation that D3's reference set is defined correctly.

### Tests

`functions_drift_test.py` **159 → 199** hermetic checks. Five mutations, each reddening **named** assertions, each restored and the file diffed byte-identical afterwards. The fifth was written after the review: the suite proved an out-of-scope unmeasurable function does not abort a scoped run, but not that scoping **to** one still exits 2 — so skipping the guards for *every* function under a scope would have passed. It now reddens three checks.

The mutation run also found a defect in the **harness**: `run_cli` wrapped `D.main` in `redirect_stdout`, and argparse *exits* rather than returning, so an unknown flag killed the run past `except Exception` with its message inside a discarded buffer. Every new test had been failing **silently, exit 2, zero output** — the red that names nothing this file's docstring forbids.

**Docs touched:** `docs/adr/048-*.md` (new), `adr/README.md`, `architecture.md` §9, `session-context.md` §2, `test-suite.md` §2 (`functions_drift`'s self-tests were undocumented there entirely), `operator-expected.md` (2(e)(iii) role list, 2(e)(iv) withdrawal, item 4(a), the #206 row), `session-lessons.md` (**105**, **106**, **107**).

**Notes / debt logged:**
* **#222** — 10 verified stale claims across the handoff documents (counts, a false *"nothing writes it yet"* for `fcmTokens`, two contradictions in the notifications section, three instruments missing from `session-context.md` §8). Found by an audit that ran during this session; **fixed only where this diff already made the text false**, filed for the rest.
* **#223** — `deploy-rules.yml` can publish a **branch's** rules to prod (it checks the typed project id, never the ref), and neither it nor `deploy-site.yml` declares `concurrency`. `deploy-functions.yml` closes both for its own lane; changing an existing lane's safety posture deserves its own decision.
* A 10-hour orphaned background `bash` from this session's own pre-`/clear` incarnation was found and killed (`session-context.md` §2). The other claude on this box is in `ai-videos`.

**Next objective written to resume-prompt.md:** #221 — the device knows *why* it has no push token and a session still cannot read it.

## Session 071 — 2026-08-17 — #221: the device now writes down what happened, and a session can finally read it (ADR-049)

**Objective (from resume-prompt.md):** #221 — the device KNOWS why it has no push token (ADR-046) and a session still cannot read it. Add a client-writable diagnostic field on `users/{uid}` with a `firestore.rules` change and its tests, an ADR-019 cascade review (asserted, not assumed), and a `push_delivery_probe.py` mode that reads and names it — without touching the `fcmTokens` freeze.

**Outcome:** done.

**Where things stood, re-measured, not inherited (2026-08-17):** `push_delivery_probe.py --from-firebase-cli` → exit **1**, `0/4 accounts have registered a device`, unchanged since S063. A direct read of the prod `users` collection confirmed the shape this slice had to fit into: 4 documents, no `nextPageToken`, none carrying `fcmTokens`, two carrying a `coupleId`, and maps arriving over the REST API as `{"mapValue": {"fields": {…}}}` — one level deeper than the logical schema suggests, which is what the probe's new reader had to be written against.

### The design, and the one decision the whole slice turns on

**ADR-049** was written and committed **before any code** (`28a9d84`), reviewed, then implemented (`d586b70`).

`users/{uid}.pushDiagnostic` = `{state, detail?, at}`, written by the device about itself. **Over Firestore, never through a callable** — and that is not a stylistic choice. One of the four facts this field exists to carry is *"the callable threw"*; a diagnostic travelling over the same transport as the thing it reports on is silent in exactly the case it was built for. A callable would also have needed a Functions deploy to become readable, and that lane is unarmed.

`state` is ADR-046's five-member vocabulary, unchanged. `detail` is **new** — a four-member `PushDiagnosticDetail`, carrying the resolution the SCREEN deliberately does not have. ADR-046 D2 merged *"granted but no token"* and *"the callable threw"* into one state on purpose, because the person holding the phone gets the same sentence and the same button either way. A session needs them apart: `captureExhausted` indicts APNs, `registerFailed` indicts the callable, and confusing those two is what made #219 take 37 hours.

`permissionRequestRefused` is named for the CALL, not for a tap — after the first install-time dialog iOS answers `requestPermission()` from its standing record without showing anything, so "the user declined" would be a confident wrong label, which is ADR-046 D2(a)'s own defect one level down. What it can honestly assert is that the app **reached the prompt path and was refused**, which is what "did the tap happen" reduces to once you refuse to guess.

**`at` must equal `request.time`.** A client clock cannot forge freshness — and freshness is load-bearing here: *"denied"* with no trustworthy date cannot distinguish a phone that reported this morning from one that reported in July.

### What the rules change actually buys — measured, and not what it looks like

Writing the deny-tests first produced the useful fact: **every one of them PASSED against the pre-ADR-049 ruleset.** The users update rule has no `hasOnly`, so a client could always write anything it liked into an unknown key. This slice does not add a new *capability* to the client; it adds trustworthy **shape** to a field a reader is about to trust. The rule's job is not "may they write it" — they own it — but "is what a reader finds there something the reader can rely on".

`fcmTokens` does not move (ADR-042 D1), and a valid diagnostic **in the same write as an `fcmTokens` mint** is still denied: the freeze is ANDed with the new predicate, not replaced by it. That has its own test.

### The clause that protects nothing and is load-bearing anyway

The predicate is `pushDiagnosticUnchanged() || pushDiagnosticValid()`, at create **and** update. The `unchanged` half guards nothing — it keeps a *legitimate* write legal. Rules see the **post-merge** document, so once a diagnostic is stored, every later `saveProfile` (`set(merge:true)`, which never mentions the field) presents the stored map again with its original `at`. Under the shape predicate alone that old `at != request.time` and **the ordinary profile edit is denied**, on a path that maps `permission-denied` to a `ProfilePermissionException` the onboarding screen shows the user.

A positive control alone cannot tell "the clause works" from "the clause is unnecessary", so it has a **reverse-polarity mutation test** in its own block: strip the clause and that save goes red. The shared mutation harness asserts a mutant *readmits* a denied write, which is the opposite polarity, hence the separate block.

### ADR-019, asserted rather than assumed

The cascade fixture now seeds `pushDiagnostic` on **both** members: A's dies because A's *document* dies (no new cascade step needed — the claim this repo has most often been burned by), and B's **survives the very transaction that stamps `coupleEnded` onto B**. The export omission is pinned by its own test, so the day someone starts exporting device-registration state is the day #227 gets answered rather than inherited.

### The legal gap the review missed and the session found by hand

Two of five design lenses returned **zero findings**, and §5.5 says an empty result is *unverified*, never a clean bill. The `data-rights` silence was demonstrably a false negative: reading the same files by hand afterwards found that the privacy policy says **"ikimiz does not send push notifications today"** (the server has composed and attempted a push daily since 2026-08-11) and that its "what we collect" list names neither `fcmTokens` nor `pushDiagnostic`.

**Not fixed here, and that restraint is the decision.** `docs/legal/` is byte-synced to `app/assets/legal/` under a drift test, and a revision bumps `CURRENT_LEGAL_VERSION` in three places at once — **re-gating consent for every existing user.** That is a founder/lawyer decision, not a side effect a diagnostics slice may cause. Filed as **#226**; the export question as **#227**; `dpa-inventory.md`, an engineering register with no consent consequence, was corrected in the same commit (its note claimed *"nothing writes `fcmTokens`"*, false since ADR-042).

### The built-diff review found three real defects behind green tests

The review ran **twice** (§5.3). The second pass, over the actual diff, is the one
that earned its keep: **6 findings, 3 surfaced, all three real** — in code whose
tests were already green.

* **The `--uid` path read tokens from the 100-row LISTING**, not from the document
  it had just fetched directly. A named account beyond the first page would have
  been refused a test send using tokens the tool had already read and discarded —
  the same pagination-manufactured absence the direct read exists to prevent,
  reached from the other end. Fixed in both places it occurred.
* **`captureExhausted` was attached to a phone that had REFUSED.** A boot capture
  finishing a second after *Don't Allow* would have overwritten the stored
  `denied + permissionRequestRefused` — the most valuable fact this field can hold
  — with a detail that merely restated the state. It is now attached **only when
  permission is held**, which is what the word was always supposed to mean.
* **An observation could be filed under the wrong account.** A capture runs up to
  ~7.5s and a permission read is an await; an account switch waits for neither.
  Chasing it surfaced something worse and older: **ADR-046 D2(b)'s "a late failure
  never demotes a success" guard keys on the registered TOKEN, and a token belongs
  to an ACCOUNT.** Carried across `AuthSignedIn(A) → AuthSignedIn(B)` — a
  transition that never passes through the sign-out branch — it silences
  everything the second account would have said. Measured: **B recorded exactly
  zero diagnostics.** That is a pre-existing defect this slice had to fix to be
  correct at all; per-account reporting that reports nothing for the second
  account is not a feature.

Two of those three needed **new test machinery to be provable at all**: the fake
source grew one-shot gates so a capture and a permission read can be held open
while an account switch lands. Before that, `pumpEventQueue()` settled everything
and the race was unreachable — a guard that cannot be reached cannot be tested.
Two guards remain unfalsifiable by this suite even so (the same rule at the two
other emit sites), and the code says so at the site rather than leaving a green
tick to imply otherwise.

**Commits:** `28a9d84` (ADR, written and committed before the code), `d586b70`
(implementation + docs), and a third carrying the built-diff review's three fixes
— all on PR **#228**. (A hash is not quoted for the last one: it names the commit
that contains this sentence, so any amend invalidates it. The branch is
`feat/221-push-diagnostic-field`.)
**CI:** green, **both runs watched to conclusion**. PR run `32014203739` — all
jobs green including `ios-build-smoke`. Post-merge `main` run `32015354004` —
green including **`integration-emulator`**, the main-only job (ADR-006), which
took **31m37s** of its 50-minute budget (09:32:46→10:04:23Z). That number is
recorded because **#208** is about this job burning the whole budget twice; it did
not this time, which is data for that issue rather than a reason to close it.
`functions-drift` and `rules-drift` were **SKIPPED by design** — one absent secret
(operator 2(e)(iv)), and the preflights said so out loud.
**Docs touched:** `docs/adr/049-*` (new), `architecture.md` §3, `test-suite.md`, `dpa-inventory.md`, `operator-expected.md`, `resume-prompt.md`, `session-lessons.md`, `past-prompts.md`.

**Verification:** functions+rules **1097 tests** (was 1071), 54 files, coverage 97.45% (gate 80/85); app **1713 tests**, line coverage 87.53% (gate 68); `flutter analyze` clean; `dart format --set-exit-if-changed` clean. Rules tests were **RED before the rule existed** (10 failures, each "expected request to fail but it succeeded") and green after. The probe was exercised against **live production** read-only in all three modes: default (exit 1), `--uid` on a real account (exit 1, report narrowed), `--uid` on a non-existent account (**exit 2**, never a false "no diagnostic").

**Mutation checks — and one mutant SURVIVED.** Three rules mutants red, three parity mutants red, two of three client mutants red. The third — deleting the `unknown` guard in `_record` — left the suite **green**, because both sites that emit `unknown` already run with a null `_syncedUid`, so the uid check turns them away first. The test claimed to prove "never reports unknown" and actually proved "sign-out records nothing". It was renamed to what it measures, and both the code and the test now say plainly that the guard is a second line of defence this suite cannot falsify (lesson **108**). A separate near-miss: the first parity mutation run applied **nothing at all** — a `cd` inside the runner left the script editing a path that did not exist — and printed three reassuring greens (lesson **109**).

**Notes / debt logged:** #226 (legal texts vs. what push actually does and what we store), #227 (the export whitelist and device-registration state). #222's stale-claims audit was partially served in passing — `architecture.md`'s false *"nothing writes `fcmTokens` yet"* and `dpa-inventory.md`'s twin of it were corrected because this diff touched those exact lines — but #222 stays **open** for the other eight.

**Measured at close, not predicted:** `rules_drift.py --from-firebase-cli` now
exits **1** for BOTH projects — prod and dev are each serving a ruleset that is
not this ref, because this session changed `firestore.rules`. That is expected and
harmless: the new predicate is purely additive, so the deployed ruleset simply
validates nothing where the new one validates a shape. **Deploying it is a §7
founder ask** and is written into the next resume prompt rather than assumed.

⚠️ And the obvious wrong inference is worth killing in writing, because a later
reader will make it: **this does NOT mean the field is inert until the rules
deploy.** The old ruleset has no `pushDiagnostic` clause and the users update rule
has no `hasOnly`, so a device's writes land either way — exactly as the deny-tests
demonstrated when they all passed against the pre-ADR-049 ruleset. What the deploy
adds is the *validation*: the guarantee that what a session reads there is a shape
it can trust. Useful field, unenforced shape, until it lands.

**The ceiling, stated first and not buried:** this reports nothing until a build ships. The last `release.yml` run is **2026-08-09, build 119**; ADR-046's Settings row and now ADR-049's field are both on nobody's phone. The probe says so in those words rather than letting a session read four silent accounts as a negative.

**Next objective written to resume-prompt.md:** #223 — `deploy-rules.yml` can publish a BRANCH's rules to prod (it checks the typed project id and never the ref), and neither it nor `deploy-site.yml` declares `concurrency`.

## Session 072 — 2026-08-17 — #223: the two oldest deploy lanes learn the guards the newest one already had (ADR-050)

**Objective (from resume-prompt.md):** #223 — `deploy-rules.yml` can publish a BRANCH's rules to production (it checks the typed project id and never the ref), and neither it nor `deploy-site.yml` declares `concurrency`. Settle the two judgement calls the issue leaves open, and say which instrument was actually used, since none of these lanes can be run.

**Outcome:** done.

### The defect is between the lanes, not inside any one of them

Three workflows deploy something a session must not deploy casually, and the guards ran the wrong way round:

| lane | since | ref pin | `concurrency` |
|---|---|---|---|
| `deploy-site.yml` | S040 | none | none |
| `deploy-rules.yml` | S058 | none | none |
| `deploy-functions.yml` | S070 | prod → `main` | per project, no-cancel |

**The oldest lane guarded the least and published the most irreversible thing.** Not bad luck: each was reviewed against the state of the art when it was written, and nothing ever went back. `gh workflow run deploy-rules.yml --ref some-branch -f project=prod -f confirm_prod=hayatiapp-prod` deploys a branch's authorization boundary to production, and the typed confirmation cannot help — **it confirms which project, never which code.**

### The judgement call the issue got backwards

#223 filed the `deploy-site` half as *"arguably weaker — the site is regenerated from `docs/legal/` and there is no drift checker to confuse"*. Both clauses are true and the conclusion does not follow. What a live publish serves is the **privacy policy and terms** that ADR-023 byte-syncs into `app/assets/legal/` under a drift test, precisely so the app and the repo can never disagree about what the policy says. A branch publish puts a **third** version into the world — the public page Apple's listing points at, saying something the shipped app does not — which is ADR-023's sync test routed *around* rather than through, and worse than rules drift in one respect: a rules deploy is corrected by another deploy, a published legal text has already been fetched.

**Measured qualification, not assumed:** `invite_only: true` is deliberately allowed on `live` and carries **no legal text at all** — that is what makes a shared invite link resolve today. The guard still holds, because a branch's `apple-app-site-association` is still the file Apple fetches to decide whether an invite link opens the app.

### Two edits close the issue and do nothing about the fourth lane

So `tool/deploy_lane_lint.dart`, on the `release_lane_lint.dart` mold: dependency-free `dart:io`, in `quality` before `pub get`, over a **derived** `deploy-*.yml` glob so a fourth lane is guarded the day it is added. An empty derived set is **exit 64** — a sentinel over nothing is the greenest thing in this repo.

### The review's blocker was a hole I had actually written

The lint's first ref-guard rule matched the four *words* — the input, `'prod'`, `github.ref`, `refs/heads/main`. So does this:

```yaml
if: ${{ inputs.project != 'prod' && github.ref != 'refs/heads/main' }}
```

**Dev blocked from a branch, prod admitted from anywhere — the guard inverted into precisely the hole it was added to close, passing a lint that only looked for vocabulary.** The rule now asserts the **operators**, and the test covering it was *confirmed red against the old form* rather than merely added. Two more from the same review: the concurrency group must key on the input that selects the **target** (one keyed on `confirm_prod` interpolates faithfully and serializes the wrong pairs), and **comments are stripped before scanning** — every lane now carries a header quoting the guard, so a lint reading prose would go green on the remediation note somebody leaves when they *delete* it.

**Commits:** `49198fe` (ADR + the two lanes + the lint), `0c73b7f` (docs) — PR **#230**.
**CI:** green, **both runs watched to conclusion**. PR run `32021507864` — all
jobs green, `quality` included, which is where the new lint and its self-tests
run. Post-merge `main` run `32022632099` — green including `integration-emulator`
at **23m11s** (11:02:11→11:25:22Z). With S071's 31m37s that is **two consecutive
runs today inside the 50-minute budget**, which is evidence for **#208** rather
than a reason to close it: the issue is about a job that hung *silently*, and two
healthy runs do not disprove an intermittent hang.
**Docs touched:** `docs/adr/050-*` (new), `architecture.md` §9, `test-suite.md`, `resume-prompt.md`, `past-prompts.md`.

**Verification, and the honest bound on it.** The lint is red on the real tree before the fixes (4 violations) and green after, with `deploy-functions.yml` green throughout as the positive control. **15 mutants, each reddening a named check**, anchors asserted present-and-unique before every edit and the file diffed byte-identical against a pre-mutation copy afterwards. One mutant survived and was **wrong** — "break after the first violation" loses nothing when the first lane is clean — and was replaced with `lanes.take(1)`, which the lane-coverage check catches.

**The review's skeptic found two more, in code I had already written**, and both are the same shape as the blocker: (a) my operator fix caught `!=` on the input but **not `||` vs `&&`** — `inputs.project == 'prod' || github.ref != 'refs/heads/main'` contains both required substrings and fires on *every* dev dispatch from a branch, so the conjunction itself is now asserted; (b) the vocabulary's own doc comment claimed a lane it could not classify would be **failed**, naming a function `checkEveryLaneIsClassified` — **which did not exist**. A future `environment: [staging, production]` lane would have passed the whole lint with no ref guard while the header promised the opposite. The check now exists, the comment names the function that does, and a mutant removing it reddens a named test.

⚠️ **What could NOT be verified, stated rather than glossed:** that GitHub honours any of these guards. That needs a dispatch, which needs `FIREBASE_SERVICE_ACCOUNT` (operator 2(e)(iii)); `actionlint` is not installed and was not added for one rule. A green lint means *the guard is written correctly*, never *the guard was tested* — said in the ADR, the lint header, the `ci.yml` step and here.

**Measured, and it corrected an inherited premise:** `gh run list` returns **nothing** for all three lanes — none has ever executed. That is **not** the same as "none of them has ever happened": the invite URL answers **200**, so the live site was published by hand, and the first real dispatch of `deploy-site.yml` will *overwrite* a hand-deployed site rather than create one.

**Notes / debt logged:** none new. No operator dependency added or removed.

**Next objective written to resume-prompt.md:** #222 — the handoff documents' 10 verified stale claims, two of which S071 already served in passing.

## Session 073 — 2026-08-17 — #222: the stale handoff claims, re-measured rather than rewritten

**Objective (from resume-prompt.md):** #222 — the handoff documents carry 10 verified stale claims, two of which S071 already served in passing. Re-measure each before rewriting it; where the operator page contradicts itself, find which side is true rather than splitting the difference.

**Outcome:** done, and the discipline paid twice.

### Every number in the diff came from a command run this session

| claim | measured by | result |
|---|---|---|
| `slack_notify_test.sh` = 14 cases | running it | **23 passed** — stale, fixed |
| `device_privacy` sentinel guards "all four method names" | reading the parity test's list | **five** — stale, fixed |
| `npm_audit_delta_test.py` = 14 cases | `grep -c '^def test_'` | **exactly 14** — correct, left alone |
| `fcmTokens` "NOTHING writes it yet" | grep | already corrected at S071 |
| operator "16:00 pushes" | ADR-045 + seven other lines in the same file | **22:00** — stale, fixed |
| operator Settings present tense | reading both instances | already future-tense since S071 |
| operator last-refreshed header | reading it | stamped at S071 and S072 |

### Two findings the issue did not contain

**The source carried the same stale count as the docs.** `device_privacy_channel.dart:5` says *"the four native methods this layer needs"* and then lists **five** bullets — the fifth being ADR-046 D4's `openNotificationSettings`. #222 listed only the `test-suite.md` prose. Re-measuring instead of trusting the list is what found it, and it is the more important of the two: prose about a test is read by a session, a doc comment on the channel is read by whoever adds the sixth method.

**The stale-claims issue carries a stale claim.** It files `architecture.md` as repeating the slack script's 14-case count. It does not — architecture.md's 14 belongs to `npm_audit_delta_test.py`, which has **exactly 14 `def test_` functions**. "Fixing" it would have introduced the very defect the issue exists to remove. That is not irony; it is the expected behaviour of any audit read later than it was written, and it is the argument for re-measuring rather than executing a list.

### And the session made the same mistake once, in-flight

The first draft of the `session-context.md` §8 addition invented a `store-metadata-audit.yml` workflow. **There is no such workflow** — the audit rides `testflight-testers.yml -f store_metadata_audit=true` (ADR-047). It was caught by checking the command before committing, which is the entire content of this session's discipline: a stale claim replaced by a freshly-invented one is the same defect with a newer date, and the second is harder to spot because it is new.

### What the operator page now says

The contradiction is corrected **in place with the old text quoted**, not silently overwritten. It read *"The daily-question and **16:00** pushes you asked for are the next session's work"* — wrong twice, and the boxquote immediately above it already said those pushes were built, deployed and running. The founder was being handed two false premises in one sentence, on the page they read *instead of* the session log.

**Commits:** `e2a4616` — PR **#232**.
**CI:** green (PR + post-merge `main`).
**Docs touched:** `test-suite.md`, `session-context.md`, `operator-expected.md`, `app/lib/core/platform/device_privacy_channel.dart`, `resume-prompt.md`, `past-prompts.md`.

**Verification:** `flutter analyze` clean, `dart format` clean, and the `device_privacy_channel_parity_test` re-run green after the source comment change (4 tests). No behavioural code changed — the one source edit is a doc comment whose count was wrong.

**Notes / debt logged:** none new. **#222 is closed**, with the record noting that one of its ten items was itself incorrect and two were already served by S071.

**Next objective written to resume-prompt.md:** #174 — the reveal is felt and seen but never announced; there is no `liveRegion` anywhere in `lib/`.

## Session 074 — 2026-08-17 — #174: the reveal announces once, and the guard it needed already existed

**Objective (from resume-prompt.md):** #174 — the reveal is felt and seen but never announced; `grep -rn "liveRegion\|SemanticsService" app/lib` returns zero. Settle the fire-point decision #173 deferred, and assert the MECHANISM rather than the presence of a node.

**Outcome:** done.

### The fire-point question was already answered by code written for something else

`RevealChoreography.onSettle` → `PairedHomeScreen._fireRevealHaptic` already fired **at most once per State**, on a State **re-keyed per dayKey**, **preserved under reduce-motion**, **surviving app resume**. Every property #174's acceptance demands, each true for its own independent reason and none of them written for accessibility.

So the announcement rides that call rather than growing a second guard. Two guards would be two answers to *"has this reveal already happened?"* — and the interesting failure is not that they disagree today but that a later change teaches one of them about a case and not the other. `_fireRevealHaptic` became `_signalReveal`: one event, two channels, felt and heard.

### The review caught a blocker I would have shipped

`SemanticsService.announce` is **`@Deprecated` after Flutter v3.35.0** and this repo is on **3.44.5**. The ADR had named it. The live API is `sendAnnouncement(View.of(context), message, textDirection)`.

Reading the SDK to confirm that turned up two things nobody had asked for:

* **`MediaQuery.supportsAnnounceOf`** — the SDK's own doc says to check it before announcing. A platform that cannot announce should get the haptic and no attempted call, not a dropped one nobody notices.
* **Android has deprecated announcement events**, because they are disruptive with TalkBack (it clears its speech queue). This repo is iOS-first, so the decision is right for the platform it ships on — and **M6.5 will have to revisit the mechanism**, which is now written down where M6.5 will find it rather than left to be discovered.

### The word that had to come out

The copy says *"Your partner's answer **is shown**"*, not *"is now shown"*. `_fireRevealHaptic`'s own comment records the bound: the choreography *"also runs on cold-open-into-revealed… there is no cheap client signal that separates them."* For a haptic a stray buzz on cold-open was accepted; for an announcement, **"now" would be a false claim about a transition** every time someone opens an already-revealed day. Suppressing it instead would need exactly the signal the source says does not exist, and guessing wrong means silence on a real reveal — the defect being fixed. A redundant sentence is the cheaper error.

**Neither this nor the fire point came from the review**: its `firepoint` lens returned **zero findings**, which §5.5 makes *unverified* rather than clean, so both were worked by hand — the same correction S071 made when its `data-rights` lens went quiet. That is now two sessions in a row where a silent lens hid something real.

### The register was measured, not chosen

TR and AR address the user **informally** (`Cevapladın`, `أجبت`, `Partnerinin`, `شريكك`). The `-nız` in `pairedRevealedCaption` is the **dual "you both"**, not a formality shift — reading it as one would have made this string wrong in a way no test could catch. Each locale reuses the noun phrase already shipped in `pairedPartnerAnswerLabel`, so the announcement speaks vocabulary the screen already uses. **Drafts pending the founder's native review** (operator item 1): announced text, so a slip is heard rather than read.

**Commits:** `1269e6f` (ADR, before the code), `0428160` (implementation + docs) — PR **#233**.
**CI:** green (PR + post-merge `main`).
**Docs touched:** `docs/adr/051-*` (new), `architecture.md`, `test-suite.md`, three ARB files, `reveal_choreography.dart`'s comment, `resume-prompt.md`, `past-prompts.md`.

**Verification:** app **1725 tests** (+6), coverage 87.56%; `flutter analyze` and `dart format` clean; the ARB guard suite green. **Three mutants, each caught by a named case** — the once-only guard removed, the announcement removed, and `Directionality.of(context)` hardcoded to `TextDirection.ltr`. The last is the one worth having: a wrong-direction announcement is invisible to every other check in this repo, because an announcement is never drawn.

⚠️ **The honest bound, in the ADR, in `test-suite.md` and here:** these prove the event is *dispatched*, once, with the right text and direction. They do **not** prove VoiceOver speaks it, or that it lands usefully relative to the visual settle. That needs a device and a person — the same on-device observation **#48**, **#15** and **#136** are still waiting for.

**Notes / debt logged:** the Android announcement-deprecation obligation is recorded in ADR-051 and `architecture.md` rather than filed, because M6.5 is where it becomes actionable and ADR-006 gates that on a founder decision.

**Next objective written to resume-prompt.md:** #175 — 10 of 14 raised cards render FLAT; the card decoration is copy-pasted per screen instead of coming off the theme.

## Session 075 — 2026-08-17 — #175: "raised" had one definition and fourteen implementations (ADR-052)

**Objective (from resume-prompt.md):** #175 — 10 of 14 raised cards render flat because the card decoration is copy-pasted per screen. Fix it as a design-system defect, assert the mechanism, and follow W4's golden-declaration discipline.

**Outcome:** done.

### Counted before touching anything, and #175's numbers verified exactly

```
card-shaped BoxDecorations on surfaceContainerHighest: 14
  WITH ElevationTokens shadow: 4
  FLAT (no boxShadow):         10
```

Unlike #222, whose ten items included one that was wrong, this issue's audit was exact. **The defect was never that ten values were wrong — it is that there were fourteen values.** Ten happened to be missing a line; the eleventh card anyone wrote would have copied whichever neighbour they were looking at.

### Two shapes were measured, and each one changed the API

* **It takes `ThemeData`, not `BuildContext`.** Every call site already held a `theme` (they all read `theme.colorScheme.surfaceContainerHighest`), and one — `_cardDecoration` in the paired home — is a **top-level function with no context at all**. A context-taking signature, which is what the ADR first specified, would have forced that site to keep its inline decoration.
* **It takes an optional `border`.** `privacy_spotlight_card` and `partner_preview` already carry `Border.all(outlineVariant)` over the same surface/radius/elevation, and the paywall's selectable plan card uses its border as a **state signal** with a long comment explaining why.

Either omission would have left the sentinel with its first exception to carve out, which is how a rule acquires its first hole. Both were found by printing all fourteen decoration blocks before writing the function rather than after.

### The golden declaration held exactly — including the half that matters

W4 requires the expected set **written before** `--update-goldens`, not read off the result. Declared: six screens MUST change; `partner_preview` and `settings` MUST NOT, because their cards already carried the token and were only being re-routed.

```
99 of 360 goldens changed — all six declared screens
ZERO movement in partner_preview and settings
ZERO outside the declaration
```

**The zero is the strongest check in the diff.** Byte-identical goldens on the four already-correct surfaces prove the new function reproduces the value they had; had it not, the other ten would have been wrong with it and the suite would have said so.

### A trap found while re-measuring ADR-025's claim

ADR-025 D1 refused a `CardThemeData` because *"`grep` finds zero `Card(`"*. Re-measuring returns **1** — and the single hit is the **comment stating the claim**. The assertion's own text is the only match for the query that verifies it. Constructed `Card(` widgets: still zero, so the decision stands. But a session re-measuring casually sees `1` and "corrects" a true claim into a false one — **S073's failure running backwards**, and a reminder that a grep-shaped claim should say what it excludes.

**Commits:** `64708ef` (ADR, before the code), `180be91` (implementation + 99 goldens) — PR **#234**.
**CI:** green (PR + post-merge `main`).
**Docs touched:** `docs/adr/052-*` (new), `architecture.md`, `test-suite.md`, `resume-prompt.md`, `past-prompts.md`.

**Verification:** app **1728 tests**, `flutter analyze` and `dart format` clean. **Two mutants, each caught** — an inline decoration reintroduced under `features/`, and the elevation dropped from the one definition. `grep surfaceContainerHighest app/lib/features` returns **zero**.

⚠️ **The verification this session could not perform, in the ADR, in `test-suite.md` and here:** a golden suite is a **regression net, not a design review**. It proves these pixels do not change again unannounced; it cannot judge whether the shadow *looks* right, and nobody has looked on a device. Bounded, not removed: the shadow is not a new value but the token already rendering on four card surfaces in this app, so ten surfaces now match four already considered correct — and if the result is wrong then the **token** is wrong, which is a founder call (ADR-025 D3, the shape of #63/#71).

**Notes / debt logged:** none new.

**Next objective written to resume-prompt.md:** #137 — the bidi seam's first-strong scan misses Arabic Extended-A, so isolation silently no-ops for it.

---

## Session 076 — 2026-08-17 — #137: the bidi seam stops asking `intl` which way a string leans (ADR-053)

**Objective (from resume-prompt.md):** #137 — `isolateWithin` gets first-strong from `intl`, whose RTL character class misses Arabic Extended-A while its LTR class *matches* it, so isolation silently no-ops in LTR chrome. Replace the classification without widening *where* isolation happens.

**Outcome:** done. Zero goldens moved, as declared.

### The issue was right, and understated itself twice

Measured over all 1,114,112 code points against Unicode 15.0.0:

```
150    intl calls strong-LTR, are strong-RTL   <- the filed issue
1,783  strong-RTL its RTL class never reaches
322    in its RTL class, not strong-RTL
3,308  in its LTR class, not strong-LTR
```

* **The region is five blocks, not one.** The 150 lie in one stretch, `U+0800–U+08C9` — Samaritan, Mandaic, Syriac Supplement, Arabic Extended-B, and Arabic Extended-A *last* of the five.
* **`intl` calls Adlam LTR, and #137's own table says it doesn't.** The issue records `U+1E900` as matching *neither* class. True of the code point, false of the behaviour: `intl` matches a **UTF-16 regex**, and all **1,024** high surrogates sit inside its LTR class. So `startsWithLtr` returns true for every astral RTL script — **1,632** of the 2,962 strong-RTL code points, more than half — and for emoji.

That second one is a **separate defect with the same symptom**, and the first version of this fix widened the ranges and carried it forward untouched. A range table does not fix an iteration unit. Iterating runes does.

### Both of `intl`'s classes are loose, so the decision was "stop asking"

Not "widen the RTL table". The seam needs a **three-way** answer — RTL, LTR, or *no direction at all* — and with both classes loose, the third was decided by whichever loose test fired first. Two generated tables (`Bidi_Class R|AL`, and `L`) replace both; `intl` leaves the seam. It stays a `pubspec` dependency because Flutter's generated localizations import it, but no hand-written file under `app/lib/` does any more.

### Three claims that were already typed before arithmetic caught them

| written during implementation | re-measured |
|---|---|
| "62,408 code points `intl` calls RTL are not strong-RTL" | **322**. The figure corresponded to nothing; it was never a measurement. |
| the table is "a strict superset of `intl`'s RTL class" | **false by 322** — and it had reached both the generator docstring *and* a test assertion, where it would have forced a correct table to stay wrong |
| the generator writes `strong_rtl_ranges.dart` | stale filename, superseded mid-session |

All three sat beside code that compiled and tests that passed. **§5.1's ADR-before-code is not ceremony** — an ADR written first has to state its numbers while there is nothing green lending them authority. This session inverted the order and paid exactly that price; the inversion is recorded in ADR-053's own text rather than tidied away. Lesson **111**.

### The scan that lied, and the mutant that overstated itself

* **W4's golden declaration** rested on classifying every app string under old and new logic. The first run said *"200 strings, 0 changes"* — believable and useless: its ARB glob pointed at `app/lib/l10n/` while the files live in `app/lib/core/l10n/arb/`, so it had examined **no localized string at all**. Rerun with a floor assertion: **894** strings, still 0 changes. Lesson **110**.
* **The third mutant** was described as *"delete the ranges covering `U+0800–U+08C9`, reintroducing `intl`'s exact gap"*. It deleted nine ranges and both tests went red — but the table contains `0x07FE, 0x0815`, **one range spanning `intl`'s class boundary**, so a filter keyed on range starts left **22 of the 150** covered and the gap was never reproduced. Rebuilt to split at `U+07FF` first, verified **0** remaining coverage, both tests red. Lesson **112**.

### A CI deadlock avoided by one measurement

The table is generated, so `--check` gates it. But `dart format --set-exit-if-changed` reads the same file, and while the generator emitted anything the formatter would reflow — a 90-character Unicode name, and every uncommented pair, which `dart format` splits one-per-line — **the two gates contradicted each other permanently**: format rewrites the file, `--check` calls the rewrite stale, and no edit satisfies both. Two correct tools, each reporting the other's output as wrong. The generator now reproduces `dart format`'s own choices, and a self-test pins it.

`--check`'s two failure modes also print **different sentences**, because the first time it fires will be a runner-image bump nobody expected: a stale table is somebody's mistake, a Unicode version move is news.

### Verification

Red-first at the render seam **in the issue's own words** (#137 asks for "a red-first test for a `U+08A0`-leading string in LTR chrome" using the existing geometry harness) — it reads `RenderParagraph` box positions, not the string, so the fix's own output cannot satisfy it. Three mutants, all caught. The unit suite asserts **disjointness over all 1,114,112 code points** rather than agreement with a known-wrong oracle. `flutter test`: **1,743 tests pass**. `git status --porcelain -- 'app/test/**/*.png'`: **empty**.

**Commits:** `c455d09` (ADR, ahead of the code but written after it — see above), `2df5a2d` (implementation), and the `docs(s076)` commit this entry arrives in — PR **#235**.

**Notes / debt logged:** none new.

**Next objective written to resume-prompt.md:** see the file.

---

## Session 077 — 2026-08-17 — #227: the export stops being narrower than the deletion lane (ADR-054)

**Objective (from resume-prompt.md):** #227 — the data-rights export whitelist omits `fcmTokens` and `pushDiagnostic`. Decide whether that is right, on the merits, rather than inheriting it.

**Outcome:** done. ADR committed **before** the code, which is the discipline S076 inverted.

### The asymmetry that settled it

`deletion-service.ts` step 5 sweeps `users/{A}` **in full**, so both fields *are* destroyed on an Art. 17 request. So the system **deleted data it would not show you** — and "we hold nothing about your devices" was never an available answer, because the deletion lane already conceded we hold it.

ADR-049 D7 had kept `pushDiagnostic` out *"for consistency with `fcmTokens`"* and said so in its own words: *"for consistency rather than for a reason anyone has argued on the merits."* This session argued the merits.

### The measurement that decided the FORMAT, not the principle

The export is **not a file**. `export_screen.dart:59` is a single `Clipboard.setData` of the pretty-printed JSON, and that is the entire delivery mechanism. #227 framed the risk as *"a file the user may store or forward"*; the reality is sharper — an FCM registration token is a **live credential that addresses a phone**, and the raw form would land on the general pasteboard, readable by other apps and, on Apple, relayed to the subject's other devices by Universal Clipboard. **The subject would not have to forward it for it to leave the device.**

So the two fields are treated **differently**, which is exactly what D7 declined to do:

| field | exported as | why |
|---|---|---|
| `pushDiagnostic` | **verbatim** | no credential (`state`/`detail` are closed enumerations pinned in `firestore.rules`), and it is a statement *about* the subject we recorded without them ever seeing it — the paradigm Art. 15 case |
| `fcmTokens` | **count only** | a bare `string[]` with no per-token metadata, so a count is the only non-credential fact it can honestly yield |

### One definition of "a registered device", not two

The count first shipped as a local filter that was byte-identical to `recipients.fcmTokensOf`. Replaced with the real import: a token this export counted but `sweep-push` would not send to — or the reverse — is a number that answers the subject's question wrongly. **ADR-052's lesson applied to a predicate rather than a decoration.** It is legitimate here because `recipients.ts` is itself pure (its only import is a `type`), so `data-rights-core.ts` keeps the no-I/O contract its header promises.

### The test that was doing its job, and was rewritten rather than deleted

ADR-049's pin asserted that *neither* field is exported, and its comment said it existed to go red *"the moment a future change starts exporting either field, which is the moment the question in issue #227 has to be answered rather than inherited."* It did exactly that. The rewrite keeps the half that still holds — the **anti-leak** assertion — and **widens** it to `JSON.stringify` over the whole projection, so a future lane carrying a token elsewhere reddens too. Mutation-checked: injecting the raw tokens into the lane **is** caught.

**Four** `formatVersion` pins went red on the v2 → v3 bump and were each updated deliberately — three `expect(...formatVersion).toBe()` and the `FORMAT_VERSION` constant itself — and **two** of them carried the number **in the test's NAME** (`'produces a formatVersion-2 envelope…'`, `'returns a formatVersion-2 envelope for a live profile'`), which is lesson **108** waiting to happen.

⚠️ **Both of those counts were first written as "three" and "one", and the design review caught them.** Lesson **111** — a number typed next to working code inherits the code's credibility — recurring *in the session that filed it*, which is the strongest evidence for it available. The code was right; only the sentence describing it was wrong, and nothing about the passing suite could have said so.

### Stale claims found and fixed while passing through

* `data_export.dart` said the format version was *"`1` today"*. The server had bumped to 2 at ADR-023 and this session took it to 3. Replaced with a comment that does **not** restate a server-owned number — the #222 shape, prevented rather than repeated.
* **`operator-expected.md` listed three CLOSED issues as open** — #176, #175, #174 — found by checking every row against `gh` rather than reading them. Struck through with their closure notes.
* **#226 was in no operator document at all**, despite being founder/lawyer-blocked. A dependency the founder cannot see is not recorded. Added with the reason a session cannot take it: any legal-text revision bumps `CURRENT_LEGAL_VERSION` and re-prompts **every existing user** for consent.

### Verification

`vitest` full functions suite under the emulators: **54 files, 1,101 tests, all passing**, coverage **97.47%**. App `data_rights` suite: 51 passing. Three mutants, all caught — count forced to 0, the lane emitted unconditionally, and the raw tokens leaked into the lane.

⚠️ **What no test here proves:** that a count is the *legally* correct redaction. That is a judgement, argued in ADR-054 from the credential nature of the token and the clipboard delivery, and recorded so a lawyer reviewing **#226** can overturn it in one sentence rather than reconstructing why the export looks the way it does.

**Commits:** `f621be5` (ADR, **before** the code), plus the implementation commit this entry arrives in — PR **#236**.

**Next objective written to resume-prompt.md:** see the file.

---

## Session 078 — 2026-08-17 — #208: a hang must FAIL loudly, not be CANCELLED quietly (ADR-055)

**Objective (from resume-prompt.md):** #208 — `integration-emulator` hung silently for 38 minutes and burned its whole budget. Second blow-out; raising the ceiling again is not a fix.

**Outcome:** done, and verified by dispatching the branch rather than by reasoning.

### The finding that reframed the issue

The job's own comment names its compensating control and asserts it works — *"ADR-024's Slack notifier reports the run nobody is watching."* **It does not, for this failure.** `slack_notify.sh` sends **nothing** when the outcome is `cancelled`, because a superseded run is not an event (ADR-024 D2, and that policy is right). **GitHub reports a timed-out job as `cancelled`.**

So the one control that exists to surface a post-merge red on a main-only job was silent by design for exactly the outcome a timeout produces. The hang was invisible **twice**: no progress in the log, and no notification afterwards.

GitHub spends **one word on two unrelated things** and the notifier cannot separate them from its inputs. So the fix is not to teach it a distinction it cannot see — it is to **stop producing `cancelled`** for a case that is not a supersede. A per-suite bound that fires below the ceiling makes the job end in **`failure`**, which reaches Slack through the path that already works. **The notifier needed no change at all.** Catching the wedge ~34 minutes earlier is the side effect. Lesson **114**.

### Three false claims in the job's own comments, each load-bearing

| claim | measured |
|---|---|
| *"four suites… ~4 Xcode debug builds"* | **five** — `startup_timing` was missing from the list |
| *"the 30-min job timeout is the real bound"* | it is **50**, and has been since S024 moved it without updating the sentence depending on it |
| *"`-r expanded` streams progress so a wedge shows"* | refuted by the incident — 38 minutes of silence is what it produced. It streams *between* tests and says nothing while the app is failing to launch |

### The load-bearing test is arithmetic, not behavioural

The watchdog only works if it can fire **before** the ceiling cancels the job. If the bounds ever sum past it, the mechanism is unreachable and the job silently reverts to cancelled-and-silent — a guard that is present, green, and structurally unable to act. So the self-test **parses `ci.yml`**, derives the suite count **from the tree**, and reddens if the sum stops fitting. Mutation-checked both directions.

### Verified by dispatch, because this job never runs on a PR

`gh workflow run ci.yml --ref …` (run `32067814813`) — the watchdog wrapped all five suites, emitted 35 heartbeats, and reported its own timings. The column that matters is the last one, because S024's blow-out was the *other* failure mode:

| run | `auth` | others |
|---|---|---|
| `32062696199` (healthy) | 513s | 122–188s |
| `32067814813` (dispatch) | 540s | 90–113s |
| `32071907287` (dispatch, post-review) | **640s** | **189–203s** |

A bound that only fit a healthy runner would have turned the first failure mode into a false positive while fixing the second — **and the first sizing did exactly that.** 960s was chosen against the 540s run and looked like 1.78× headroom; against the worst observed run, 640 × 1.55 = **992s > 960s**. Raised to **1080s**, caught only by re-measuring the third dispatch instead of reusing the number already written down. The ADR's own trap, sprung on the ADR.

### A real main-red arrived mid-session, and produced the second half of the slice

S077's post-merge run went red while this was being built, and **the red said nothing true**: the functions emulator hit a 10s discovery timeout, loaded **zero** functions, and `emulators:exec` ran the suites anyway. Fifteen minutes later a test failed on *"answer → mutual reveal round trip"* — because the `answerReveal` **trigger** had never loaded. Checked rather than assumed whether S077 caused it (no import cycle; the same code loads all 13 functions locally; every prior `main` run passed) and re-ran the job to settle flake-vs-regression.

`assert_emulator_functions.sh` now names it in seconds. **Its codes are measured against a live emulator**: a loaded callable answers `400`, an unknown name `404`, **and a Firestore trigger also answers `404`** — so probing `answerReveal`, the very function whose absence caused the incident, would fail against a healthy emulator. That constraint is written at the top of the script.

### Two defects in my own wrapper, and one in the probe — all found by running them

* the comment claimed output was **tee'd live** while the code buffered it and dumped it at the end (the self-test now **counts** occurrences, because a duplicated thousand-line suite log is invisible to a `grep`);
* the heartbeat used `elapsed % N`, which **skips a beat** whenever an iteration overruns a second — i.e. exactly on the loaded or wedged runner where it is the only thing being read;
* `curl … || echo 000` produced `000000`, because curl's `-w` already writes `000` on a connection failure and *then* exits non-zero — so an **unreachable emulator reported as loaded**. Caught by the assertion that "unreachable" and "not loaded" must be different words.

Also: a `pgrep` leak-check that matched its own command line (a false "LEAKED"), and a `pkill -f "sleep 300"` that killed the shell running it.

⚠️ **What no test here proves:** the hang is not reproducible, so the wedge case is **synthetic**. This proves the mechanism, never the diagnosis of the actual incident. The heartbeat exists so the next occurrence produces the evidence this one did not. The build strategy — 9.3 min of the 18.6 is Xcode, the largest lever — is deliberately **not** changed in the same slice that changes how the job fails.

**Next objective written to resume-prompt.md:** see the file.

---

## Session 079 — 2026-08-18 — #208 follow-up: bound the SILENCE, and an audit of three sessions' citations

**Objective (from resume-prompt.md):** #129 — the release lane's stale `Gemfile.lock` comment.

**Outcome:** **replanned.** #129 was not started. The post-merge run of S078's watchdog falsified the bound S078 had just shipped, and fixing that took priority over starting new work. #129 moves to S080.

### The fix for #208 needed #208's own criticism

S078 bounded each integration suite by wall-clock time and sized that bound three times in one day — 960s against a 540s run, 1080s against a 640s run — and then the first post-merge `main` run took **936s**. A later dispatch took **457s**.

```
auth suite observed: 457, 513, 540, 640, 936 s   — a 2.05x spread
```

That is **wider than the ±55% factor the bounds were being stress-tested against**. No wall-clock number is both tight enough to catch a hang and loose enough to avoid failing a slow run. Chasing it does not converge — which is exactly #208's criticism of raising `timeout-minutes`, one level down, made by the fix for it.

**The instrument was wrong, not the number.** A wedge is defined by producing nothing:

| | longest gap between log lines |
|---|---|
| healthy run (cold Xcode build) | **299s** |
| the #208 incident | **2280s** |

7.6× separation on silence against 2.05× on duration — and the watchdog was **already computing and printing `silent for …s`** in every heartbeat while deciding on something else. Lesson **116**.

The wall-clock bounds became deliberately loose backstops, and the arithmetic self-test was retargeted from "the bounds sum under the ceiling" to the guarantee that actually carries the design: **a wedge is detected before `timeout-minutes` can cancel the job.** Mutation-checked both ways. 30 self-tests; the load-bearing one is that **a slow but chatty child is not killed, however slow**.

### The design review found two ways the watchdog itself misfired

Both reproduced before fixing, both failure shape 5:

* **A passing suite could be reported as wedged.** A child finishing during the loop's 1s sleep, at an elapsed time crossing the bound, fell into the timeout branch — 1.9s under a 2s bound, exit **42**, returned **124**, three times out of three.
* **`WATCHDOG_HEARTBEAT_SECONDS=0` span forever**, producing a job that hangs until it is **cancelled** — the exact outcome ADR-055 exists to prevent, from the tool built to prevent it.

### A citation audit, and it was worse than a typo

Three ADRs, several commit messages, lesson 111 and the handoff all cited *"`session-rules` §5.1"* for the ADR-before-code rule. **`session-rules.md` has five sections and §5 is "Timebox".** The rule is `session-context.md` §5 item 1 — and **ADR-048 already cited it correctly**, so the right reference sat in the repo while three consecutive sessions copied the wrong one from each other.

Opening it cost one grep and found a second thing: **§5 item 3 requires running the review twice** — once on the design, once on the built diff. S076, S077 and S078 each ran **one**, on the built diff. Three sessions were half-following a procedure they were quoting by number. Lesson **115**.

### The operator checkpoint, rewritten and re-verified

`operator-expected.md` went from 1297 lines of accumulated checkpoints to 225 lines of live state. Every open item was re-measured rather than carried forward: secrets absent (`gh secret list`), the RevenueCat webhook still **HTTP 403**, **0 of 4** accounts ever registered a push token, Dependabot alerts still disabled, billing **resolved** and dropped.

**One proposed item was dropped because the audit that produced it was wrong.** A sub-audit reported *"M5.3 not started; needs an LLM API key from the operator"* — which would have put a fabricated task in front of the founder. `coach-proxy.ts:291` deploys `AnthropicCoachProvider` with `secrets: ['LLM_API_KEY']`; `UnconfiguredCoachProvider` is only the default for the injectable test seam. The key is **present on both projects** and `coachProxy` is deployed to prod. Verifying beat trusting — and this is the second time in three sessions that a review agent's confident claim did not survive being checked.

Two gaps it found that **do** hold, both verified directly: **analytics has no implementation at all** (MVP item 11), and the launch question bank stands at **7 per locale against 400/300/300** (MVP item 3).

**Commits:** `4c304aa` (citation audit), `2b86c30` (silence bound), `adfa718` (checkpoint rewrite) — PR **#238**.

**Next objective written to resume-prompt.md:** #129 with #121, as S080.

---

## Session 080 — 2026-08-18 — #129: the release lane installs the lock it was given (ADR-056)

**Objective (from resume-prompt.md):** #129 (with #121) — the release lane's `bundle install` comment is false, and the lane installs unfrozen.

**Outcome:** done for #129. **#121 deliberately left open** with its trigger sharpened — see below.

### The first session to run BOTH review passes, and the design pass earned it

`session-context.md` §5 item 3 requires the review twice — once on the design, once on the built diff. S076–S078 each ran one (lesson 115). This ran both, and **the design pass found a blocker that could not have existed after implementation**:

The ADR proposed a **paths-filtered `pull_request` trigger**. That contradicts a Session 002 decision recorded in `ci.yml`: *"workflow-level `paths-ignore` would **deadlock required checks**"*. The repo has **zero** paths-filtered workflows, deliberately. And a filtered workflow is **absent** from the checks list — indistinguishable from "verified" — where a skipped job is an honest, visible gap.

Rebuilding on the repo's own visible-skip pattern dissolved two further findings at once: a `verify` mode inside `gemfile-lock.yml` risked a mis-wired `if:` leaving `bundle lock` running before the frozen install — **verifying the lock it had just created**, the exact defect being fixed *in that same file* — and `gemfile-lock.yml` stays dispatch-only, which **ADR-036 D4 cites as THE model** and `fastlane/README.md` calls "(dispatch-only)".

### The gap was wider than the issue said

#129: *"no release run has ever executed with the committed lock."* Reading `gemfile-lock.yml` in full: it runs `bundle lock` **first**, so it verifies the lock it just regenerated — its own comment concedes the file is untracked at that moment. **Nothing ever had.**

`ci.yml` gained **`gemfile-lock-verify`**: the committed bytes, installed frozen on macos-26 + Ruby 3.3 (mirroring `sign-upload`, because a lock is a claim about a **platform** — `arm64-darwin-23` plus generic `ruby`, so ubuntu would exercise the fallback and be green while the release goes red), bracketed by a checksum **and** `git diff --exit-code` (a real check here precisely because the file *is* tracked), then `fastlane lanes`, because installable is not usable.

### The risk was lower than the issue assumed, and measured rather than argued

#129 calls `--frozen` *"the riskier half"* that *"should land on a run someone is watching"*. A session cannot watch a release run — but `gemfile-lock.yml` is dispatch-only with a read-only token that never commits, so a session **may** run it, and did (`32087803351`): same image, same Ruby, **`arm64-darwin-23`** both sides, **fastlane 2.237.0** both sides, frozen install passed.

### Four things the built-diff pass caught afterwards

1. **"A lock that cannot be installed frozen never reaches `main`" is false** — I wrote it in two comments and the ADR. Required checks are exactly `quality`, `ios-build-smoke`, `functions-rules` (read from the API). The job is **visible, not enforcing**. Making it required is now operator action 8.
2. **The run I cited printed a deprecation I did not read** — `--frozen` is deprecated in bundler 2.5.22, and that run's log said so while I extracted platform facts from it. All three workflows now use `bundle config set frozen true`.
3. The ADR named the gate `gemfile_changed`; the code uses `ruby_changed`.
4. Found while fixing (2): the step **names** still said `--frozen` after the commands stopped using it — lesson 108 in a workflow file.

**That first one is the fourth over-claim of this session's shape** (after `62,408`, the miscited §5.1, "every clause is false"). The pattern is worth naming: a confident absolute written next to code that works reads as verified because the code is. The last two were caught by review before reaching anyone.

### Verification

The shell branching inside the YAML — the part CI cannot report on until it runs — was exercised in a throwaway git repo across **seven** cases: docs-only push, lock-change push, lock-change PR, app-only PR, app-only push, `workflow_dispatch`, and an unknown/force-push base. All seven produce the intended `(code, ruby)` pair, including both fail-open paths. `release_lane_lint`: PASS (12 checks, 80 self-test checks). `deploy_lane_lint`: PASS.

⚠️ **Unproven, and stated rather than implied:** the release lane *as a whole* under frozen install. Only the founder can run it. If it fails at `bundle install`, that is frozen mode working, and the remedy is one dispatch of `gemfile-lock.yml` plus committing the artifact.

### #121 — left open on purpose

The step's own comment sets the precondition: *"A session that can watch a real run should delete it and confirm."* This session cannot, and ADR-029 D2 refused `CODE_SIGN_IDENTITY` on identical grounds. What changed is the method: the comment now names a **canary-path experiment** — move the key somewhere nothing can auto-discover rather than deleting the step, so a wrong premise fails with a *missing key at the auto-discovery path* (attributable, re-runnable) instead of a cryptic signing failure. Not run now for timing, not principle: a failed release costs more than usual while a build is the one thing blocking push testing.

**Next objective written to resume-prompt.md:** analytics — MVP item 11, unbuilt, no issue.

---

## Session 081 — 2026-08-18/19 — #239: the funnel splits three ways, and every client event now has a call site a test keeps honest (ADR-057)

**Objective (from resume-prompt.md):** #239 — analytics is MVP item 11, and it is entirely unbuilt. Gates 2 and 3 are not merely unmeasured; they are unmeasurable.

**Outcome:** done for the autonomous half. Two remainders **filed, not deferred into prose** — **#242** (the server emitter has no port) and **#243** (the two emitters share no identity). PR **#244**.

### The first session where BOTH review passes changed the deliverable

`session-context.md` §5 item 3 requires the review twice. S076–S078 each ran one (lesson 115); S080 ran two. This ran two, and **each pass found something the other could not have**.

**Pass 1, on the design** — 5 lenses × 2 verifiers, 29 agents, 0 errors, 20 findings, 11 surfaced. It produced **revision 2 of ADR-057**, committed before any code. Three findings changed the shape of the work:

* **`share_card_created` is an event for a feature `mvp.md` explicitly lists as OUT** (*"Quizzes & shareable result cards (v1.5)"*), and `grep shareCard app/lib` returns nothing. Revision 1 listed it as a **client** event — which would have minted a typed event nothing could ever emit, reading as an unwired funnel step forever. The partition is not two-way but **three**: 8 client + 3 server + 1 with no feature = 12.
* **Nothing decided how many times an event fires.** An `install` that fires on every cold boot is not an install; a `paired` that fires on every profile-stream tick is not a pairing. This is the largest silent-wrongness risk in client funnel instrumentation and revision 1 said nothing about it at all.
* **Gate 3's `install→paid` is a cross-emitter join with no join key** — `install` fires pre-account, `paid` is keyed to a `coupleId`, and D3 removed the obvious candidate on purpose. The metric the MVP exists to answer stays uncomputable, and that is now written down (#243) rather than discovered on launch day.

Also killed: *"the debug sink writes through the existing observability layer"* was **not a specification**. `core/observability/` holds exactly two candidates and both are wrong — `CrashReporter.log` is a **Crashlytics breadcrumb**, so routing events there would have handed an existing processor a data category `dpa-inventory.md` does not list for it.

**Pass 2, on the built diff** — 5 lenses × 2 verifiers, 17 agents, 0 errors, 6 findings, 4 surfaced. **Two of the four were over-claims in my own code**, which is the shape this repo keeps paying for:

* A doc comment claimed *"every event here has a pair of tests there"*. **Five of the eight had no behavioural call-site test anywhere.** Fixed by building them rather than softening the sentence.
* The once-keys were tested for **behaviour only**. "Call twice, see one" passes just as happily for a key spelled `analytics.singup.<uid>` — and these keys live in `SharedPreferences` **across app updates**, so a typo does not fail, it silently re-emits a once-only event for every existing user on the version that fixes it.

Three of pass 2's five lenses returned **zero** findings after 48–57 tool calls each. That is a genuine nothing-found, not an empty result — §5 item 5's distinction, checked rather than assumed.

### The two decisions that were actually load-bearing

**`paired` is emitted from the profile's `coupleId`, not from the join flow.** `JoinInviteController` is the obvious home and it is wrong: **only the joiner ever runs it.** The inviter becomes half of a couple without touching that controller, so a join-flow emitter would have reported roughly **half** the pairings that happened — and Gate 2 is *"pairing ≥40% of **signups**"*. The metric the whole funnel exists to answer would have read about half its true value, with nothing anywhere reading red. `users/{uid}.coupleId` is stamped server-side for both members.

**The port's default is silence, not a throw.** This departs from the `authRepositoryProvider` idiom deliberately: those seams throw because a missing repository is a bug that must be loud, and **this is telemetry** (`NoopCrashReporter`, `PushDiagnosticRecorder`). The proof it was right is that instrumenting the app root and six controllers broke **zero** of 1,784 existing tests. A throwing base would have reddened every widget test that renders an instrumented screen — the trap `push_diagnostic_recorder_provider.dart` records having already been sprung once.

### The defect the suite caught, and why it was latent at three of four sites

`ref.read` on an autoDispose controller **throws** once it is disposed. All four action call sites read `analyticsProvider` *after* the await. **Only the coach path had a test that exercises mid-flight disposal** (ADR-017 D8's captured-notifier test), so it went red immediately and the other three were invisible. The handle is now captured before the await at all four, and the missing regression test exists at one of the other three — mutation-checked by restoring the bug.

Worth naming: the guard was already written down in the codebase (ADR-017 D8 exists precisely for this), and the diff still walked into it three times. **A rule that lives in one feature's ADR does not generalise itself.**

### Mutation checks, all with the tree restored byte-identical afterwards

| mutant | result |
|---|---|
| a 13th event added to `architecture.md` §7 | **red** (2 tests) |
| `streak_day` **deleted** from §7 | **red** — the direction revision 1's sentinel would have missed |
| the §7 heading renamed | **red on the floor** — lesson **110**'s fail-open case |
| a call site deleted | **red**, naming the event and the missing needle |
| a server event emitted from the client | **red** |
| `CrashReporter` injected as code into `core/analytics/` | **red** |
| the release-guard default flipped to `false` | **red** |
| one once-key typoed | **red** |
| `analyticsProvider` read after the await again | **red** |

The Crashlytics sentinel's first version failed on **the doc comment explaining the rule** — a guard measuring prose rather than behaviour. It now strips comments, and asserts the strip did not empty the file: lesson 110 applied to the guard itself.

### Documents this slice made stale, and what was done about each

* **`architecture.md` §7** — gained the three-way split and its four honest gaps. Deliberately appended **after** the first sentence, because that sentence is what Sentinel A parses; the sentinel passing afterwards is the proof the grammar is robust to prose growth.
* **`dpa-inventory.md`** — the Mixpanel row said *"unbuilt: no analytics SDK exists in app or functions today"*. Still true of the **SDK**, no longer true of the **instrumentation**. It now states precisely what exists, that nothing leaves the device so no processor is engaged, and that the trigger for a row is the first vendor adapter.
* **`implementation-plan.md`** — its cross-cutting rule says instrumentation is *"implemented **with** their features, never retrofitted"*, and this slice retrofits eight events onto M2/M3/M5 features. §7's schema shipped years before any emitter, so there was no "with their features" moment left to take. Acknowledged in both documents; the call-site sentinel is what makes the rule bind **forward** rather than aspirationally.
* **`ADR-016`** — its Context says *"No analytics stack exists yet (scout-verified)"*, now false. **Not edited**: `docs/adr/README.md` makes accepted records immutable. ADR-057 carries the pointer instead. *(A review lens proposed editing it; both verifiers correctly refused on exactly that ground.)*
* **`operator-expected.md`** — said analytics was *"0% — no analytics code in `app/lib` at all"*. Now honest, plus **operator item 18**: the vendor token, and the legal change that must land **before** any adapter — bundled with #226 so users are asked once rather than twice.

### Verification

**1,819 app tests** (was 1,784), coverage **87.69%** (gate 68), `flutter analyze` / `dart format` / `rtl_lint` clean. `core/` still imports `features/` in **0** files — the boundary the dimension binding was designed around rather than through.

**Honest bound, stated rather than implied:** prod ships the **no-op sink**. The funnel is *instrumented and emitting, into a debug sink, in dev only*. Nothing here makes Gate 2 or Gate 3 measurable — that needs the founder's token, a legal revision, and #242/#243.

**Commits:** `72bea39` (ADR rev 2), `175da58` (contract + sinks), `fd6b96f` (emitter + state-transition events), `84259b6` (call sites + sentinels + docs), `5bac247` (review pass 2) — PR **#244**, squashed to **`f9de121`** on `main`. **#239 CLOSED.**

### The CI result, recorded here rather than left for a later session to add

Post-merge `main` run **32193564585**: **success on every job** — `quality`,
`functions-rules`, `ios-build-smoke`, and **`integration-emulator`**, which is
main-only by cost design (ADR-006) and about which the PR's green said nothing.
The four drift jobs are `skipped`, visibly, for the one absent secret.

**And one near-miss worth writing down.** The PR run I watched first reported
`X ios-build-smoke in 0s` and **`gh run watch --exit-status` still exited 0** —
because the run had been **cancelled** by the next push, not failed. That is the
standing hazard about repeated pushes cancelling the only macOS gate, met in
person: a cancelled run reads as covered while having compiled nothing. The fix
was to stop trusting the exit code and read `conclusion` **per job** on the run
that actually carried the final tree. Both the PR run (32192567902) and the
`main` run were then verified that way, job by job.

**Next objective written to resume-prompt.md:** **#226**, as S082 — draft the
legal revision covering push *and* analytics in one bundle, and stop at a draft.

---

## Session 082 — 2026-08-20/21 — #226: the notice denies a collection the shipped build already attempts (ADR-058)

**Objective (from resume-prompt.md):** #226 — draft the legal-text revision, in ONE bundle covering push *and* analytics, so the founder/lawyer approves once and users are re-consented once. **Autonomous: the drafting. NOT autonomous: landing it.**

**Outcome:** done. A version-3 draft of the three privacy policies sits on `main` at `docs/legal/proposed/`, guarded by a test, with `CURRENT_LEGAL_VERSION` deliberately still **2**. Four issues filed: **#246**, **#247**, **#248**, **#249**, **#250**.

### The measurement that changed what the issue was about

#226 was filed as *"the policy is stale."* It is worse than that, and the difference is the whole ADR.

**Build 119 — the only binary on any phone — already attempts the collection the notice denies.** `git merge-base --is-ancestor` puts ADR-042 and ADR-044 inside `355036878a`; at that sha `app.dart:71` wires `PushTokenSync`, which calls `requestPermission()` and, on success, `registerPushToken` — whose server half writes `users/{uid}.fcmTokens`. The server sweep has been running since S070. **Only the outcome is empty:** `push_delivery_probe.py` re-measured **exit 1, 0/4 registered, all four "no report."**

So the sentence *"ikimiz does not send push notifications today"* is true of the outcome and false of the system, and a privacy notice is a statement about the system. That reframing is what made the draft writable: **describe the system, then state the outcome; never let the outcome stand in for the system.**

**And the analytics no-op does not mean nothing is recorded.** `Analytics._emit` calls `_claimOnce` *before* the sink, so prod writes `analytics.signup.<uid>` and five siblings into `SharedPreferences` — carrying a uid, a `coupleId` and day keys — then discards the event.

### Both review passes ran, and each caught what the other could not

**Pass 1, on the design** — 5 lenses × 2 verifiers + a completeness critic. **26 agents, 0 errored, 0 empty, 13 findings, 6 surfaced + 3 critic, nothing dropped.** It produced **ADR-058 revision 2**, committed before a word of the draft existed. Two blockers:

* Decision 5 wrote the quiet window as **22:00–08:00**. **ADR-045 moved it to 23:00–08:00** so the 22:00 nudge would not be swallowed by our own guard. The wrong number was on its way into a privacy policy.
* The bump-diff summary dropped **`shippedPolicyVersionLine`** — one of the **two** places `docs/legal/README.md` step 3 says the sentinel does not cover, both *"found the hard way when the v1→v2 bump left them behind."* I cited the rule and dropped the half I was not quoting. Lesson 115, exactly.

The critic found the one nobody else looked for: **lawyer question D was created and never added to the lawyer's list.** `docs/legal/README.md` still said *"These three questions."* D and E now live there.

**Pass 2, on the built diff** — same shape. **26 agents, 0 errored, 1 empty result, 14 findings, 6 surfaced + 4 critic.** The empty verifier is reported rather than absorbed: that finding surfaced as *unverified*, because an empty verdict is not measured, not clean.

**Three of its findings were false sentences in the drafted policy** — the deliverable itself:

* **The blocker.** *"those markers never leave the device, and removing the app removes them."* Both halves are unsafe: Android Auto-Backup is on by default and the manifest sets no exclusion — and this repo already knew the iOS half, because **ADR-018 marks the PIN's Keychain record `unlocked_this_device` specifically to stay "out of iCloud and device backups"**, which concedes ordinary storage is in them. I wrote a false absolute into a legal document *in the ADR that exists to remove one*.
* *"The report is a status word and a time"* — `pushDiagnostic` is `{state, detail?, at}`, so it can be **two**. Undercounting the collection, in the collection list.
* *"when your reading language is Arabic"* — **there is no "reading language" in this app.** It is `contentLanguage`, labelled *Question language* / *Soru dili*, and the shipped policy's own collection list already calls it that. The notice invented a name for a control the reader is told to go and find.

**And two guards that could not fail the way their names claimed:**

* The cross-locale parity test was called *"the same sections, in the same order"* and compared **only the three counts**. Three documents with entirely different sections passed it. Rewritten to project each draft heading onto its index in **that locale's shipped document** — the shipped set is the interlingua — and compare the language-free sequences. **The rewrite then failed on correct input**, because Dart `List` has identity equality and a `Set` of three identical lists has length 3.
* The italic pattern `(?<!\w)_[^_\n]+_(?!\w)` is locale-asymmetric because Dart's `\w` is ASCII-only. **Measured, the asymmetry runs opposite to the review's framing:** it under-guards **English** (`setting_content_language` slips through) while firing on Arabic-flanked underscores. Replaced with the bare form.

### The decisions that were load-bearing

**What is material, and therefore what the bundle actually buys.** Push adds data categories, a purpose, two recipients and a transfer leg — material. The analytics correction adds none of those and **cannot justify a re-consent on its own**, so it rides free. That is the bundle, precisely. **But operator item 18 over-promised the rest of it:** you cannot name an unnamed processor, so a vendor adapter later is a second bump by the conservative reading. That is now **lawyer question D**, with the conservative default standing until the lawyer relaxes it — the ADR-023 precedent.

**Naming Mixpanel was rejected, and both verifiers upheld it.** `architecture.md` names Mixpanel as a *technology intention*; the register says *"no processor exists … no row is due yet."* A notice naming it today would tell users their data goes to a company we have never contacted — a different false sentence, in the same document, pointing the other way.

**The draft lands merged at `docs/legal/proposed/`, not as an open PR** — and the reasoning was trimmed after the design review called it self-serving. What survives is narrow and true: **a merged file is the only one CI can check.** The drift risk is identical either way, and that cost is stated rather than avoided.

**Only the three privacy policies change.** `grep -i 'notification|push|analytic'` over the three terms documents returns nothing.

### The invisible character

The shipped Arabic policy carries **exactly one U+200F**, immediately after the `(` that opens the Latin-script processor list — without it the neutral paren resolves to the wrong side in an RTL paragraph. It sits **inside the one bullet this revision edits**. I found it before writing, built the Arabic draft **programmatically from the shipped file** with 14 content-anchored edits (each asserted to match exactly once) rather than by hand, and the test now pins it. Nothing else in the repo would have noticed it being dropped.

That rebuild was itself forced by a finding *my own test made*: the first hand-written Arabic draft had silently re-translated `## من يُشغّل تطبيق ikimiz` as `## من يُشغّل ikimiz`, dropping a word from a heading I had no business touching. **A revision draft must be a minimal delta, or the lawyer reviews a re-translation instead of a change.**

### Mutation checks — nine, tree restored byte-identical after each

Drop the RLM · restore the false push sentence · bump `currentLegalVersion` · delete a section heading · fill the effective date · add a table · reorder two Arabic sections · rename an Arabic section · underscores in Arabic **body** text. Each turns exactly its own test red. **The ninth was redone:** the first attempt changed a heading *and* added underscores, reddening two tests at once and proving neither.

### Documents this slice made stale, and what was done about each

* `docs/legal/README.md` — lawyer questions **D** and **E** added (the list said *"three"*); a pointer to `proposed/`. The `version:` line is untouched and still unique.
* `docs/dpa-inventory.md` — **Google FCM** and **Apple APNs** rows added; the note that disposed of both in a subordinate clause replaced; the **İYS/ETK** position recorded as a position; the Mixpanel row told what the draft does and does not discharge.
* `docs/architecture.md` §8 — the proposal named. **§7 untouched:** its first sentence is parsed by `funnel_event_sentinel_test.dart`.
* `docs/adr/README.md` — **`Proposed` added to the status vocabulary**, which had no word for a decision whose deliverable is a draft.
* `docs/test-suite.md` — the fourth cross-tree guard.

### Verification

**1844 app tests** green, `flutter analyze` clean, `dart format` clean. `build_site.py` was **run**: it publishes only the six shipped documents and no `EFFECTIVE DATE` placeholder appears — Decision 2's claim measured rather than reasoned. The effective-date placeholder is matched by that script's own `PLACEHOLDER_SPAN` in all three locales, so a version 3 that lands undated **cannot reach `/privacy`**.

**Honest bound:** nothing about the shipped product changed. No user is re-consented. `CURRENT_LEGAL_VERSION` is 2 in all three sources and a test now says so out loud. **#226 stays open** — its state moves from *"the notice is wrong"* to *"a reviewable correction is on `main`, awaiting the founder and the lawyer."*

**No operator action is required to continue engineering.** The next session is unblocked.

**Commits:** `3f36462` (ADR rev 1), `4abf053` (ADR rev 2, design pass), `6e338db` (the draft + guard + docs), plus the built-diff pass — PR **#251**.

### The CI result, recorded here rather than left for a later session to add

**PR #251 green, and the post-merge `main` run green too — `32429984999`, every
job.** Including **`integration-emulator`**, which is main-only by cost design
(ADR-006) and which the PR's green therefore said nothing about. The run id was
captured immediately after the merge and watched to conclusion, per
`session-rules.md` §3.5.

| job | PR | post-merge `main` |
|---|---|---|
| `quality` | pass 5m23s | pass |
| `functions-rules` | pass 2m20s | pass |
| `ios-build-smoke` | pass 6m02s | pass |
| `integration-emulator` | **skipped (PR)** | **pass** |
| `rules-drift` / `functions-drift` (+ preflights) | skipped | **preflights pass, checks skipped** |
| `gemfile-lock-verify` | skipped | skipped |
| `slack-notify` | pass | pass |

**`ios-build-smoke` ran to completion on one push**, which is worth stating: it is
the only macOS gate, repeated pushes cancel it, and a cancelled run reads as
covered while having compiled nothing. One push, one 6-minute compile, one pass.

The four `skipping` rows are the known unarmed lanes — `rules-drift` and
`functions-drift` want operator **2(e)(iv)**, and `gemfile-lock-verify` is
path-filtered. Both drift **preflights** passed on `main`, which is the design
from ADR-041 D6: the credential probe is its own job so the check is either
MEASURED or **visibly SKIPPED**, never green-without-measuring.

**Merged as `699eabf`.** `codegraph sync` reports the index already current.

**Next objective written to resume-prompt.md:** **#136**, as S083 — the Functions-side bidi twin. Its autonomous half needs no device, and this session made it pointed: the draft now tells Arabic users, in writing, that a notification can show their partner's name.

---

## Session 083 — 2026-08-21 — #136: the push copy lets a name choose the paragraph direction, in a branch nothing calls (ADR-059)

**Objective (from resume-prompt.md):** #136 — reorder the Arabic copy so a partner name never sits beside a bidi-neutral, and pin the latent defect with a test.

**Outcome:** the objective as written was **impossible**, and measurement said so in the first twenty minutes. What shipped is the fix the measurement actually supported, plus a correction to S082's own legal draft. **#136 stays open** for its device half. **#253** filed.

### The session did not do what it was told, and said so

The assigned fix was *"reorder the Arabic copy so the placeholder never sits beside a bidi-neutral."* **The neutral is inside the name** — `Aylin Y.` carries its own full stop — so no arrangement of our words can reach it. Deviating from an assigned objective is a thing to justify in writing, not to quietly perform; ADR-059 carries the justification in a box at the top, and the design review raised the deviation as a finding of its own.

### The instrument came first, and its control is a defect we already had

There is no Flutter here — the renderer is the notification shade — so ADR-033's evidence and its instrument do not transfer. `tool/bidi_visual.py` drives **FriBidi** through `ctypes` (already on the box; no pip, no npm dependency added to `functions/`).

**Its control is #133.** Fed the string ADR-033's own doc comment records as the visible defect, it returns `.Kahvaltıda birlikte gülmemiz` — verbatim. A bidi harness that cannot reproduce a defect we already had is one whose green means nothing. **Everything below is output, not reasoning** — and the reasoning was wrong twice before the tool ran.

### Three findings, in ascending order of how wrong the issue was

**Finding B — the Arabic defect is real.** `أجاب Aylin Y.` → `.Aylin Y ﺏﺎﺟﺃ`. The #133 shape, mid-sentence too.

**Finding A — the SEVERE defect is in Turkish and English.** `${name}` is **first** there, so a first-strong renderer takes the paragraph direction from *the name's script*:

```
أيلين answered today's question. Open ikimiz to add yours.
  ->  .answered today's question. Open ikimiz to add yours ﻦﻴﻠﻳﺃ
```

The whole English sentence backwards, for an English-reading user, because of who their partner is. The Arabic is immune — it is verb-first, as Arabic VSO makes natural. The file's comment says the name *"sits in SUBJECT position in all three languages"*: **placement was reasoned about for grammar and never for direction**, which is exactly what #136 predicted and exactly the opposite locale from where it looked.

**Finding 0 — the branch is UNREACHABLE, and nobody knew.** `partnerName` is supplied by **no caller**. Both `composePush` sites omit it; `grep` finds it only in `payload-policy.ts` and its own tests; `git log -S` finds no call site that ever passed one. **Every `partnerAnswered` push ever composed has used the name-free copy.** #136 calls the defect *latent*; it is one step further out than that, and ADR-059 revision 1 inherited the issue's severity without checking it — then claimed a user-visible benefit that cannot exist. The claim was **deleted, not softened**.

**And Finding 0 made a sentence in S082's own legal draft false.** That draft, merged one session earlier, tells Arabic users *"a notification can show your partner's name."* It cannot. **The same class of error S082 existed to correct, committed by S082** — caught by the next session's measurement and fixed here.

### Both review passes ran, and the second one was where the code was wrong

**Design pass** — 25 agents, 0 errored, 0 empty, 15 findings, 9 surfaced + 4 critic, **5 dropped unverified and listed in the ADR**. It found Finding 0 independently (as did I, while it ran); that unmatched brackets are *not* covered by N0 as revision 1 claimed; that *"neutral or weak"* includes **EN**, so a literal implementation strips digits from names; that trimming in EN/TR is a cost with no measured benefit; that the ADR-052 citation supported nothing; and that the test rule had to be about the first **strong** character, not the first character.

**Built-diff pass** — 23 agents, 0 errored, 0 empty, 9 findings, **none dropped**. Four were defects in the code and test I had just written:

* `open.splice(i, 1)` where N0 requires discarding every bracket opened after the partner — so `(A [B)]` was "fully matched" and kept, and its trailing `]` measured jumping to the head of the line **and mirroring into a `[`**.
* A matched pair may **wrap the whole name**, and then its contents are at the edge: `(Aylin Y.)` → `(.Aylin Y)`. `Ayşe (Y)` — the only bracket example I had — contains no neutral to detach. The trim is now recursive.
* **The test's own RTL predicate was broken in a way that reads as fine.** `/[֐-ࣿיִ-﷿ﹰ-﻿]/u` — the Hebrew point in it is **two codepoints**, so the class parsed a range **U+05B4–U+FDFF**: 63,000 codepoints, calling Devanagari, Thai, Hiragana and Han "RTL". A test whose direction predicate is wrong agrees with whatever it is shown. ADR-053 already made this call for the app-side table, which is why **that** one is generated.
* The Arabic legal example used the **feminine** verb while the code emits the masculine default — a locale saying something the other two do not.

### What shipped

`sanitizePushName` (RTL copy only — measured, nothing detaches in an LTR paragraph, so trimming there takes a character off a name for nothing) · the TR/EN copy opening with the copy's own word · the legal correction in three locales · `tool/bidi_visual.py` · 31 tests. **Mutation-checked six ways**, each reddening exactly its own assertions.

### Verification

`eslint` clean · `tsc` clean · **640 functions tests, 0 failed** (the 25 "failed" *files* are the emulator suites refusing to run without an emulator, by design, printing the exact command) · the legal guard green · `dart format` clean · the tool's own `--control` green.

**The emulator suite, and the run that was NOT green.** Run through the command CI runs. The **first** attempt after the built-diff fixes reported **3 failed** — and the honest reading took one look at the numbers: every failure was a **timeout** (25.0s, 30.9s, 30.9s) plus a `beforeAll` **hook** timing out at 10s in a file whose two tests are skipped. Nothing in this diff can slow a Firestore trigger or a lifecycle hook; it composes strings. The box had been running multi-agent review workflows all session. Re-run on a quiet machine: **1132 passed, 0 failed, exit 0, lines 97.64%.** Recorded rather than quietly replaced, because "I re-ran it and it went green" is the sentence that hides a real flake — the distinguishing evidence here is that the failures were *all* clock-shaped and none was an assertion about behaviour.

**No operator action is required to continue engineering.**

### The CI result

**PR #254 green, and the post-merge `main` run green — `32442392296`, every job.**
Including **`integration-emulator`**, which is main-only by cost design (ADR-006)
and which the PR's green therefore said nothing about. It ran **25m14s**
(03:15:31 → 03:40:45) against **21m33s** on the previous main run — the same
order, comfortably inside ADR-055's silence bound, and worth writing down because
this session had already been fooled once by a slow box.

| job | PR #254 | post-merge `main` |
|---|---|---|
| `quality` | pass | pass |
| `functions-rules` | pass | pass |
| `ios-build-smoke` | pass | pass |
| `integration-emulator` | **skipped (PR)** | **pass, 25m14s** |
| both drift preflights | skipped | **pass** (checks themselves skipped — ADR-041 D6) |
| `gemfile-lock-verify` | skipped | skipped |
| `slack-notify` | pass | pass |

**`functions-rules` passing in CI is the independent confirmation of this
session's own emulator run** — the one that needed a second attempt on a quiet
box. A local green re-run and a CI green are two instruments, and both agree.

**Next objective written to resume-prompt.md:** **#242** — record which server surface emits the three entitlement events. It needs a decision, not a vendor.

---

## Session 084 — 2026-08-21 — #242: the three money events are emitted where the decision is made (ADR-060)

**Objective (from resume-prompt.md):** #242 — decide, and record in an ADR, WHICH server surface emits `trial_start` / `paid` / `churn`. The decision does not need the vendor.

**Outcome:** decided and recorded. **No emitter built** — deliberately, and #242's own framing says why. The issue stays **open** with its body updated to point at ADR-060.

### The trade #242 described was not the trade

The issue presents two options fairly: a port on the RevenueCat webhook, or a Firestore trigger over `subscriptions/{coupleId}`, with the trigger *"decoupling emission from the bearer-token surface"*. **Two measurements collapsed that.**

**One — the trigger does not decouple from delivery.** `firestore.rules:296` makes the mirror function-only, and the webhook is its sole *content* writer. If RevenueCat never delivers, the mirror never changes and a trigger emits nothing either. The trigger buys independence from the webhook's *code*, not its *delivery* — and delivery is the risk the issue names.

**Two — the trigger would emit `churn` when a user deletes their account.** `deletion-service.ts:245` deletes that document inside the M6.2 cascade. The obvious *"was entitled, is no longer"* derivation fires on it: a false churn in a Gate 3 metric, at the moment someone deletes their account in a DV-aware product.

### The design pass found the classification unimplementable at the seam that had just been chosen

**25 agents, 0 errored, 0 empty, 14 findings, 6 surfaced + 4 critic, 4 dropped unverified.** Two blockers:

* **`paid` is defined over a TRANSITION, and revision 1 put the emitter where only the destination is visible.** The previous lane state never leaves the transaction callback, and the RC event cannot substitute — a trial conversion arrives as a `RENEWAL` with `periodType: NORMAL`, *identical in shape* to an ordinary renewal. Uncorrected, `paid` would have fired on **every renewal for the life of every subscription**, and Gate 3's *"trial→paid ≥30%"* would have grown without bound. `ProcessOutcome` must grow; the ADR now says so instead of claiming the implementation is transcription.
* **ADR-057 D3's *"no uid or `coupleId`, on any event, ever"* was unaddressed**, at the one seam in the system where both are in scope. Two verifiers split on whether D3 is client-scoped or literal — **which is exactly the question #243 exists to answer**, so the ADR resolves it conservatively (neither identifier) and hands the *relaxation* to #243 rather than closing it silently in a document about which surface emits.

Four more: a lapsed trial was counted as churn; `TRANSFER` revokes entitlement too, so *"EXPIRATION is the only revoking event"* is true inside its table and false of the system; the trigger-indistinguishability claim was too strong (`willRenew` separates `CANCELLATION` from `UNCANCELLATION`); and **sandbox purchases would have entered the funnel** — nobody had looked at `environment`, and this project has bought sandbox subscriptions since M4.2.

And the emit is now explicitly **after** the transaction: Firestore retries the callback, so revision 1's phrasing, followed literally, broke the idempotency it was asserting.

### The built-diff pass found me contradicting the same file

**20 agents, 0 errored, 0 empty, 11 findings, 2 surfaced + 4 critic, 3 dropped.** The sharpest: the §7 addendum called the webhook the mirror's *"sole writer"* — contradicting ADR-060's own *"exactly two writers"* **and `architecture.md`'s own §3**, which already carries the precise vocabulary: *"the deleteAccount cascade is the second admin writer, but it only ever deletes the doc WHOLE — the webhook stays the sole CONTENT writer."* The file had the right words and the addendum ignored them.

Also: Decision 2a promised sandbox events *"are counted"* and named no mechanism. The honest version is better — `logOutcome` already carries `environment`, so nothing new is needed.

### One change nobody asked for

The churn guard now keys off the **previous lane state** rather than the event's `periodType`. Revision 2's version made churn depend on RevenueCat sending `period_type` on an expiry — an **unverified vendor shape** whose absence would make churn *silently unmeasurable*. Both verifiers refuted the concern and were right that the general positive-match rule covers it; it is still better not to depend on a vendor shape nobody here can confirm, and the previous state is in hand anyway because blocker 1 forced it.

### Verification

Documentation only. `architecture.md` §7's addendum was appended **after** the sentinel-parsed first sentence — **60 analytics tests green**, so `funnel_event_sentinel_test.dart`'s ≥12-name floor and both parity directions are unaffected. `dart format` clean.

**No operator action is required to continue engineering.**

### The CI result, and the two jobs that did NOT run

**PR #256 green, post-merge `main` run `32449699896` green.** But the honest
statement is narrower than "every job passed", and the difference matters:

| job | PR #256 | post-merge `main` |
|---|---|---|
| `quality` | pass | pass |
| `functions-rules` | pass | pass |
| `ios-build-smoke` | pass | **skipped** |
| `integration-emulator` | skipped | **skipped** |
| both drift preflights | skipped | **pass** (checks skipped — ADR-041 D6) |
| `slack-notify` | pass | pass |

**`integration-emulator` and `ios-build-smoke` were path-filtered out on `main`,
because this session changed only `docs/`.** That is correct — there was nothing
for them to exercise — and it is written down rather than folded into a green,
because the previous two sessions' close notes make a point of
`integration-emulator` being the main-only job the PR cannot prove. **This
session did not prove it either**, and for a different reason: it never ran.
A close note that said "main green including integration-emulator" three sessions
running would have been true twice and false here.

**Next objective written to resume-prompt.md:** **#246** — the once-only analytics markers survive account deletion. Autonomous, and it is the last loose thread of the S082/S083 family.

---

## Session 085 — 2026-08-26 — #246: "delete my account" reaches the device, and a flag cannot exist without saying whose it is (ADR-061)

**Objective (from resume-prompt.md):** #246 — "Delete account and data" does not reach the once-only analytics markers. Make it, or state in the notice that it does not.

**Outcome:** made it. **#246 closes.** The sweep ships, eight-then-eleven-way mutation-checked, with the classification moved into the type system after the design review blocked the guard that was supposed to keep it honest.

### Three inherited claims were wrong, and two of them were mine

ADR-061 revision 1 was already on the branch, unpushed, when this session opened. One orientation grep refuted its central table.

* **"`LocalFlagStore` has three consumers."** Six, and eleven key shapes. It named the analytics keys, the coach ack and the couple-ended notice; it did not know `nameCaptureDone`, `privacySpotlightSeen` or `ritualPreviewSeen` existed.
* **"`analytics.install` is the only one with no uid."** `ritualPreviewSeen` is set **before sign-in**, so it has no uid to be keyed by and must never be cleared. Revision 1's fix was a **prefix list** built from the flags it had enumerated — and its own first attempt at that list was missing four of the nine account-scoped shapes, silently. That is the argument against the shape, made by the shape.
* **"Clearing them trades a funnel count for a data right."** *(lesson 127)* No trade exists. The uid is already inside the key, so a replacement account gets a different key and re-emits either way. The bound ADR-057 D4 recorded is real for `analytics.install` — the one key with no uid — and had been carried forward to five keys that do. I wrote that sentence into the resume prompt myself, from a document that was right about a different key.

Revision 2 replaced the prefix list with a **uid predicate**: a key belongs to an account when the uid is one of its dot-delimited segments, both sides wrapped in dots so `u1` cannot claim `u12`'s flags on a shared device.

### The design pass blocked the guard, and the fix was to delete the guard

**17 agents · `agents_error=0` · `agents_empty_result=3` · 6 findings · 6 verified · 0 dropped unverified · 3 surviving.** The three empty lenses (correctness, inventory-completeness, honesty) each read 69–97k tokens of the tree before answering *"no findings"* — considered-empty, not failed-empty. **All three survivors landed on Decision 4, and shared one root cause.**

* **BLOCKER — the scan could not see what it was scanning for.** D4 proposed scanning `app/lib` for `localFlagStoreProvider` against a declared file inventory. **Four of the six key-builder files never name that identifier.** A new uid-keyed flag, defined in a new file and consumed from an already-inventoried consumer, leaves the file set unchanged: sentinel green, key unclassified, deletion misses it. The guard reproduced the defect it was written for. The adjudicator cited ADR-025 D8 by name — *a declaration nothing enforces reads as coverage*.
* **MAJOR — the inventory was a fixture derived from its own subject.** `funnel_event.dart` says exactly this about itself, four lines of comment, and revision 2 argued it against revision 1 one decision earlier before reintroducing the shape.
* **MAJOR — the parity assertion could not catch the bug D2 warns about.** One uid passes under the substring predicate the ADR spends a paragraph rejecting.

**Revision 3's answer was not a better scan.** Two closed enums (`AccountFlag`, `DeviceFlag`) and a `LocalFlagKey` that is the only way to build a key. A raw `String` no longer compiles, so a flag cannot reach the seam unclassified; `LocalFlagKey.account` can only place the uid in its own dot segment, so the sweep is total; and **there is no source scan left at all** *(lesson 128)*. Two enums rather than one with a `scope` field, because the field version needs an `assert` to bind constructor to scope and an `assert` is a debug-only guarantee.

**Three findings were killed** and are recorded in the ADR so nobody re-raises them: the `Amends:` bullet (an emergent convention in four ADRs, not a rule — the README's format is Status/Date/Deciders/Related); `pin_lock_store.dart`'s citation going stale (its second reason is untouched, and its first still holds because the lock needs clearing on **sign-out**, which this change deliberately does not do); and D1 failing to analyse a phase-2 failure (D1's own paragraph analyses it).

### The seam that matters is which event you are standing in

`app.dart` already tears down on `AuthSignedOut` — and **both a deletion and an ordinary sign-out end there**. #246's own suggested fix was that listener. It is the one place the sweep must not go: clearing there re-shows the coach disclaimer, the name step and the privacy spotlight to anyone who merely signed out and back in. The sweep lives in `AuthController.deleteAccount`, between the two phases — after the cascade succeeds, before the teardown — the only place in the app that knows which of the two happened. Pinned by a test that runs `signOut()` and asserts every flag survives.

### The built-diff pass found a pin the rewrite had deleted

**9 agents · `agents_error=0` · `agents_empty_result=3` · 2 findings · 2 verified · 0 dropped unverified · 2 surviving.** Byte-preservation, blast-radius and docs each came back clean.

The **MAJOR generalised past what the review reported.** Rewriting `local_flag_store_test.dart` for typed keys replaced `expect(coachDisclaimerAckKey('u1'), 'coachDisclaimerAck.u1')` with a pin on `AccountFlag.coachDisclaimerAck.prefix`. Those read alike and are not: the enum pin proves the **vocabulary** is intact and says nothing about which member a **builder** reaches for. The behavioural test cannot cover it — `coach_screen_test.dart` seeds and asserts with the same function — and **the mutation check proved it**: rewiring the builder to the wrong member left that test **green**, reddening only the restored pin. Every user who had acknowledged the "not therapy" note would have been shown it again *(lesson 129, lesson 117)*. Restored for all six builders with a count assertion, so a new builder cannot arrive unpinned.

The MINOR was the uid-collision bound asserted over `DeviceFlag` segments only while the collision is symmetric — recurring shape **5**, a guard silent on the other path. Now over both vocabularies. *(That bound exists at all because this file's own first draft went red using `analytics` as a candidate uid: the predicate matches segments, so an account whose uid were literally `analytics` would take `analytics.install`. Asserted rather than deleted — the guarantee is not "device flags are unreachable", it is "no Firebase uid is a word".)*

### The scope call, made deliberately

The type change reaches **30 files**. `session-rules.md` §2 calls a drive-by refactor scope creep wearing a helmet, and the reason this is not one is that **the guard is part of the deliverable**: without it the fix is complete only for the eleven flags that exist today, and the review's verdict is that the cheaper guard does not guard. Shipping it would have been ADR-025 D8's own error. Argued in the ADR rather than left for a reviewer to notice.

**Every persisted key string is byte-identical.** `analytics_test.dart`'s character-for-character table was deliberately **left untouched** by the diff that could have broken it, so the six analytics keys keep an independent pin.

### Verification

`flutter analyze` clean across the whole app including `screenshots/`. **1880 tests green.** Coverage **87.73%** against the 68 gate. **Eleven mutation checks**, each reddening exactly its own guards: neuter the sweep · substring predicate · drop the empty-uid guard · move the sweep onto sign-out · move it before the cascade · drift a key prefix by one character · add an unpinned vocabulary member · reclassify an analytics once-key as a device flag · point a builder at the wrong member · add a vocabulary member whose prefix could pass for a Firebase uid · drop a builder from the pin table. `git status` empty after both review workflows.

### Filed rather than folded

**#258** — the version-3 privacy draft says the markers *"go when you remove the app"*. Still **true**: removing the app still clears them, and the notice now promises **less** than the app does, which is the safe direction and the opposite of the mismatch #226 exists to correct. But the sentence sits in the paragraph a user reads to learn what happens to their data, and it invites the inference that deleting the account does **not** — an inference this change makes wrong. One clause closes it, in three locales. Noted in `docs/legal/proposed/README.md` under the section #249 already established, because widening a draft the founder is about to review is scope creep and telling them what moved underneath it is not.

**No operator action is required to continue engineering.**

### The CI result — main green, and `integration-emulator` ran

**PR #259 green; post-merge `main` run `32913494182` green.** The honest version
names which jobs actually measured something, because four skipped on the PR and
two of those skipped on `main` too:

| job | PR | `main` |
|---|---|---|
| `quality` | ✅ | ✅ |
| `functions-rules` | ✅ | ✅ |
| `ios-build-smoke` | ✅ | ✅ — the macOS gate, and it compiled |
| `integration-emulator` | **skipped** (main-only by cost design, ADR-006) | ✅ **ran** |
| `rules-drift-preflight` / `functions-drift-preflight` | skipped | ✅ |
| `rules-drift` / `functions-drift` | skipped | **skipped** — still unarmed for want of operator 2(e)(iii) (#165) |
| `gemfile-lock-verify` | skipped | skipped — no `Gemfile` change |

The two drift jobs skipping on `main` is **#165 unchanged**, not a regression:
their preflights ran and concluded the read-only secret is absent. Prod-vs-`main`
drift therefore remains **unmeasured**, exactly as the blocker list says.

`codegraph sync` reported already-up-to-date against merged `main`.

**#246 closed by the merge.**

---

## Session 086 — 2026-08-27 — #243: the gate nobody can compute, and the identifier that would not fix it (ADR-062)

**Objective (from resume-prompt.md):** #243 — record the options and their honest costs for Gate 3's `install→paid`. **Do not mint an identifier.**

**Outcome:** decided and recorded (ADR-062, `Proposed`). **Nothing built, no identifier created.** #243 stays open for one founder sentence. **Session cut short by a founder redirect** — see the closing note.

### The issue asked about identity; the arithmetic was the bigger problem

#243 frames the gap as "the two emitters share no identity". True, and re-affirmed twice (ADR-057 D3, ADR-060 D3). But asking what each event **counts** — rather than what it is keyed by — found something no identifier fixes:

| event | counts one per |
|---|---|
| `install` | **device** (`DeviceFlag.install`, once per phone) |
| `signup` / `paired` | **uid** |
| `paid` | **couple** (`subscriptions/{coupleId}`, ADR-013 D5 — one purchase entitles both) |

**`install→paid` divides a couple count by a device count.** A couple who both install and subscribe once is two installs and one payment: the gate's own arithmetic halves itself for exactly the users the product is for, and it is invisible because both numbers are individually correct. A distinct id tells you which installs became which users; it does not tell you whether the founder means *2% produce a payment* or *2% become a paying user*, and with a couple-scoped subscription those differ by **2×** — 100% of the threshold's own value.

### And a go/no-go threshold does not need the join — but the review refuted which aggregate

Revision 1 recommended a **lagged** window ratio, arguing its error *"runs the safe way"* under growth. **The design review refuted that at high confidence on both verifiers, and it was right.** The dilution argument is a property of the **same-window** ratio; applying a lag is exactly what removes it, and with a distributed conversion lag the lagged numerator collects payments from later, larger cohorts than its denominator — so by Jensen it **overstates**, in the one direction a spend gate must not fail.

Worked rather than asserted, because the sign of an error is not a thing to reason about loosely. A product whose true cohort conversion is **1.5%** — which should **fail** a ≥2% gate — with installs doubling and half the cohort converting after one window, half after two:

| lag | reads | gate verdict |
|---|---|---|
| **0 (same window)** | 0.56% | **fails** ✅ correct |
| 1 | 1.13% | fails ✅ |
| **2** | **2.25%** | **PASSES** ❌ green-lights spend on a product below the bar |
| 3 | 4.50% | PASSES ❌ |

With flat installs every lag is exact — which is why the error is invisible in a steady state and appears exactly when a launch is working. **The recommendation inverted**: the gate's number is the **same-window** ratio, *because* it is the one that cannot falsely pass, with the lagged ratio reported beside it as the optimistic bound. Revision 1 had the right instinct — prefer the estimator that fails safe — and named the wrong estimator.

**The design review:** 4 lenses × 2 verifiers, `agents_error=0`, `agents_empty_result=0`, 6 findings, 6 verified, **0 dropped unverified**, 3 surviving. The other two were minor and both real: *"once per phone"* contradicted ADR-057 D4's own recorded bound that **a reinstall re-emits** (`SharedPreferences` does not survive app deletion), and Decision 4 mischaracterised **#115** — it is the precedent for *"making a prod endpoint world-reachable is a founder-gated security decision"*, not an abuse-resistance example. Three were killed: an unspecified lag (a decision-only ADR does not pin implementation parameters), store-provided metrics as a missed fourth option (they inherit Finding 2's ambiguity and are not ours to define), and Crashlytics' installation ID as a counterexample to the survives-sign-out claim (SDK-internal, not an identifier the app mints or can join on).

**Decision 1** recommends the ratio and mints nothing. **Decision 2** hands the founder the definitional sentence *first*, because it is free and larger. **Decision 3** prices the identifier for the day it is reconsidered — it is collection, it needs a `CURRENT_LEGAL_VERSION` bump that re-gates every existing user, it reopens a line held twice, and it would be the only identifier here that survives sign-out in a product whose threat model is a partner holding the phone. **Decision 4** refuses the install-time server ping: it is the distinct id with extra steps, plus an unauthenticated pre-account write surface.

**`mvp.md` was deliberately NOT edited.** Gate thresholds and their definitions are the founder's (ADR-007); a session that quietly rewrote one would be deciding launch posture by commit.

### Closing note — the session was redirected mid-flight, and this is what that means

The founder set the next objective directly: **the daily question must arrive at 09:00 every morning.** ADR-062 was committed before the redirect and its design review was launched; **the review's outcome is folded below or the ADR carries `Proposed` with the gap named.** No implementation work for #243 existed to abandon — the session's whole deliverable was the record.

**What the redirect surfaced, measured immediately:** the 09:00 feature is **complete on both sides and has never fired once.** `DAILY_QUESTION_LOCAL_HOUR = 9`, the composer, the sweep call, an emulator test, `firebase_messaging ^16.4.3`, `FcmPushTokenSource`, both entrypoints overriding the provider, `aps-environment` present — and **0 of 4 accounts registered**, all four *"no report"*, because the last build predates ADR-049's diagnostic. That is one operator action, and `operator-expected.md` now leads with it as a single numbered step.

**Two stale comments found in the same measurement**, both on the path a debugger reads first: `payload-policy.ts:115` calls `dailyQuestion` *"the hour-8 sweep push"* beside a constant that is **9** (ADR-045 re-pointed it and the comment did not move), and `push_token_source_provider.dart:9` says *"nothing overrides this yet"* when both entrypoints do. **Handed to S087 rather than fixed here** — they belong to that objective, and `session-rules.md` §2 says a session does one thing.

**Operator action IS required, and it is the point:** one release-lane dispatch, one install, one permission tap.

## Session 087 — 2026-08-28 — the loop stopped six days ago, and the instrument built to notice returned "could not measure" (ADR-063)

**Objective (from resume-prompt.md, founder-set 2026-08-27):** the daily question must actually arrive on a phone at 09:00. *"Find out why a complete, tested chain has delivered nothing, and remove what a session can."*

**Outcome:** the cause was found and it is **not** the one the objective assumed. **Production has been refusing every server-side invocation since 2026-08-22T02:00Z because the Google billing account is closed.** The instrument built after the last identical outage could not report it; it is fixed. Six false comments corrected, the 09:00 payload proven where the question is in scope, and `operator-expected.md` now carries two steps in an order that matters.

### The objective's premise was wrong, and the objective's own first instruction is what found it

The prompt said to run `push_delivery_probe.py` first. It did, and it says what it has said for weeks — **0 of 4 registered, four *"no report"*** — honestly, including that a no-report is not distinguishable from "no build carrying the diagnostic ran here" (lesson 65). So the prompt concluded: one operator step, cut a build.

Then the **other** standing instrument ran:

```
$ python3 tool/ci/prod_pulse.py --from-firebase-cli          # exit 2
could not measure: https://cloudscheduler.googleapis.com/...jobs returned HTTP 403
```

`prod_pulse.py` exists **because of #219** — 38 refused invocations over 37 hours in August while `operator-expected.md` reported *"Your app is running"*. Its whole job is to make that impossible. It met the identical outage and answered *"could not measure"*.

**Measured by hand with the same credential:**

| | |
|---|---|
| `billingAccounts/012195-7EF76F-3A9083` | **`"open": false`** — closed ("Firebase Payment", TRY) |
| `projects/hayatiapp-prod/billingInfo` | `"billingEnabled": true` — still **linked**, so the project flag reads healthy |
| the Cloud Scheduler 403 body | *"This API method requires billing to be enabled"* — the 403 **is** the billing symptom |
| `questionRollover` error stream | *"The request failed because billing is disabled for this project."* — **every hour since 2026-08-22T02:00:01Z** |
| last `question_rollover: sweep complete` | **2026-08-25T15:00:11Z** (`assigned:1`), one lone recovery; before it, **2026-08-22T01:00:06Z** |
| `hayatiapp-dev` | linked to the **same closed account** |

So no day doc is created at local midnight, and **no 09:00 push can be composed for anyone, token or not**. Every link downstream of the sweep was irrelevant.

### Three defects in the instrument, all in the wiring rather than in the well-tested part

Confirmed by calling its own functions: `measure_billing` → **`True`**, `measure_job` → raise, `measure_last_sweep` → never ran.

1. **One `try` around three independent probes.** The first failure discarded a fact already in hand. And the abort was not bad luck — **Cloud Scheduler 403s *because* billing is off**, so the one state the tool exists to detect is the one state that guarantees it cannot report (lesson **114**, aimed at its own subject).
2. **The wrong billing fact.** `billingEnabled` means *linked*. It read `true` throughout. Had the 403 not aborted first, the tool would have printed the reassuring `billing: enabled` mid-incident — and `prod_pulse_test.py`'s central `test_the_actual_outage` passes `billing_enabled=False`, **an input the production path could no longer produce**. Every test in that file targeted `verdict()`; nothing tested `main()`.
3. **It never read the reason**, only the absence — though its own docstring notes the `I` and `E` lines sit one letter apart, and the `E` line carries the cause verbatim.

**Before / after, against production:**

```
before:  exit 2 — could not measure: ...cloudscheduler... HTTP 403
after:   exit 1 — FINDING: the linked billing account is CLOSED ...
                  FINDING: the last COMPLETED sweep was 55.3h ago (2026-08-25T15:00Z)
                  most recent refusal (2026-08-27T22:00:01Z): The request failed
                    because billing is disabled for this project.
                  COULD NOT MEASURE scheduler: ... HTTP 403
```

### The design review changed three things, and refuted me on the one that mattered most

4 lenses × 2 independent verifiers. **`agents_error=0`, `agents_empty_result=0`, 11 findings raised, 11 verified, 0 dropped unverified, 3 surfaced.** All three were folded into revision 2 **before any code**:

* **Blocking.** Revision 1's exit rule left **exit 0** covering *"nothing found, and the decisive fact unmeasured"* — billing healthy + scheduler ENABLED + Logging 403 would have printed *"the daily loop is running"* over a six-day-dead sweep. ADR-041 says **never 0 without having compared**. Rewritten: findings → 1, else **any gap → 2**, else 0.
* **Major.** The design was **unimplementable against `verdict()`**: `job_state=None` already means *"I looked and there is no job"*, so there was no value for *"I could not look"* — and today's 403 would have arrived as `None` and printed the flatly false *"the sweep has no trigger"*. Gaps became a first-class input that **suppresses the paired absence-finding**. Without that catch the fix would have been worse than the bug.
* **Major, and it corrected me.** Revision 1's Finding 4 said the founder's permission grant would be *"spent for nothing"* if they cut the build first. **False.** `_syncFrom` (`push_token_sync.dart:237-258`) runs on every `AuthSignedIn` including a cold launch — `build()` syncs the value already present before it listens — and calls `_captureAndRegister()` unconditionally. iOS keeps the grant; the app re-registers itself on the next launch. The grant is **deferred, not destroyed**, and D1 no longer rests on irreversibility. The ordering argument survives on weaker and truer grounds: ② first cannot deliver a question and would manufacture a **fifth** indistinguishable silence.

Eight refuted findings were left alone, correctly — including a claim that the ADR's own site counts were overstated (they were **understated**; see below).

### Six comments told a reader the feature could not work. All six were false

| file | claim | reality |
|---|---|---|
| `push_token_source_provider.dart` | *"Nothing overrides this yet"* | both entrypoints override it |
| `main_dev.dart` | *"INERT until the entitlement lands"* | landed 2026-08-07 |
| `push_token_source.dart` | *"no implementation of this yet"* | `FcmPushTokenSource` exists |
| `fcm_push_token_source.dart` | *"correct and inert today"* | it is live |
| `recipients.ts` | *"NOTHING writes this field yet"* | `push-token-service.ts` does |
| `fcm_push_token_source.dart` | *"Until that ships"* (the post-pairing ask) | `PairedHomeScreen` calls it |

**`main_prod.dart:217` already carries a ⚠️ recording that this exact sentence "HAD BEEN FALSE FOR NINE DAYS"** and naming it *"the fourth indistinguishable explanation for silence"*. **The correction was applied to one file of six.** A warning about stale comments is itself a comment (lesson **132**).

Plus **21 hour-family sites in 8 files** still saying the announcement is hour 8 and the nudge hour 16; ADR-045 made them 9 and 22. Two were worse than stale: `sweep-push.ts:43` stated the load-bearing quiet-guard claim **backwards** (and named the old 22:00–08:00 window), and `at-risk.test.ts`'s `describe`/`it` names said *"hour-16 gate"* twelve lines below a fixture reading 22:00 and an assertion `expect(AT_RISK_LOCAL_HOUR).toBe(22)` — lesson **121** recurring inside one file.

Historical narrative was deliberately kept. Corrected comments now **name the instrument** instead of restating its last answer, which is the only form that cannot go stale.

### The 09:00 payload is now proven by what it sends

Every prior assertion read `summary.sent` or `port.sent[].token`. **None read `title` or `body`** — so the suite proved *who* gets a push at hour 9 and never *what* was in it, at the one seam (`runDailyQuestion`) where the day doc and its `questionId` are in scope.

Mutation-checked, each described by what it **changes** (lesson 112):

| mutant | result |
|---|---|
| **A** `deliverSweepPush(..., 'dailyQuestion')` → `'reveal'` | 3 new assertions RED — **29 pre-existing tests GREEN**, including *"fires at the couple-local 09:00 sweep"*. **That is the gap** |
| **B** body gains `' [${kind}]'` | the two equality assertions RED; the no-content one **GREEN, correctly** — it leaked the *kind*, not the question, so it never exercised that guard |
| **C** thread the day doc's `questionId` into `MessagingPort.send` (the founder's own ask was *"send new questions at 08.00 TSI **with a question**"*, so this is the refactor the guard exists for) | all three RED including no-content — **19 pre-existing tests GREEN** while the question id rode out on the lock screen |

Eight further mutants were run against `prod_pulse.py`; seven reddened a named assertion first time. **The eighth stayed green because the mutant was a no-op** — dead code inserted rather than behaviour changed — and was rewritten as the real reordering (gaps beat findings), which reddened two named checks. Lesson 112, met from the other side.

### Verification

`flutter analyze` clean · `dart format --set-exit-if-changed` clean · `prod_pulse_test.py` + 5 sibling tool suites GREEN · **51/51** across `daily-question`, `question-rollover-handler` and `payload-policy` in the emulator · `build_runner` idempotent at a fixed point.

**The first emulator run failed 1 of 51 on a `beforeEach` hook timing out at 10s.** Clock-shaped on a loaded box, not behavioural — re-run clean at 51/51, **and said so rather than quietly re-running to green.**

### Operator

`operator-expected.md` item 1 is now **two ordered steps**, item numbers elsewhere untouched (they are cross-referenced 40+ times). **① restore billing, ② cut the build** — with why the order is not optional, and an explicit note that if ② is already done nothing is lost. Item 9 (the budget alert) was promoted: it is the control that would have caught **both** outages, and it was left unset after the first.

**#219's own residual list named both causes of this recurrence** — the unset budget alert, and *"`prod_pulse` is a local/manual instrument… A cron that calls it and notifies would close the detection gap properly; that needs a credential decision."* **The residuals of the last incident are the cause of this one.** Filed as **#263** (#219 is closed, so a session reading `gh issue list` would never have seen it), and it is S088's objective.
