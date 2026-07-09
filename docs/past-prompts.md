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
