# Resume Prompt

> This file contains ONE and only ONE objective. Every session executes ONLY this file. (See `project-rules.md` #1, `session-rules.md`.)
>
> **Standing de-gating note (ADR-007):** engineering milestones M1→M6 proceed without content-ops preconditions. Gates 1–3 are decision instruments for marketing/spend/launch posture, not build blockers. TikTok/content-ops work is out of session scope unless the founder re-activates it. First release target: the founder couple's own devices (personal-use-first).
>
> **Standing sequencing note (ADR-006):** iOS-first — milestones validate and ship on iOS first; Android work is re-sequenced into M6.5.

## Objective — Session 003: M1.1 — Firebase foundation + Auth domain

> Supersedes the unexecuted Session-003 objective "content pack validator v1" (written at Session 002 close under the old standing gate note; retired by ADR-007 before any work started — the validator returns to its original home, M3).

First slice of M1 (`implementation-plan.md`: Apple/Google/phone auth, profile capture, locale bootstrapping, Crashlytics + App Check — 3 sessions). This session:

1. **Firebase projects + FlutterFire wiring.** Create `hayati-dev` and `hayati-prod` Firebase projects (founder runs `! firebase login` at session start — see External dependencies); `flutterfire configure` per flavor; `firebase_core` initialized in both entrypoints (`main_dev.dart`/`main_prod.dart`) via `appConfigProvider`; generated options files committed per flavor; **no secrets in repo** (Firebase iOS/Android config files are not secrets; API-key restrictions noted in a comment).
2. **Auth domain, TDD-first (mandatory — domain logic):** `AuthUser` entity + `AuthRepository` interface in `features/auth/domain/`, fake-backed unit tests for the auth state machine (signed-out → signing-in → signed-in → error), then `data/` implementation over `firebase_auth`.
3. **One provider end-to-end: Google Sign-In** (Apple provider needs the paid Apple Developer entitlement — lands in M1.2 once the founder confirms account status; phone auth needs APNs — also deferred). Working against the **Firebase Auth emulator** in tests; manual smoke against the real dev project.
4. **Auth presentation shell:** minimal sign-in screen states (loading/error/content) with widget tests; no visual polish (brandkit application is a later M1 slice); RTL-safe from the start (`start`/`end` only).
5. **Docs-with-code:** `architecture.md` §-additions if wiring deviates from plan; `app/README.md` run instructions (emulator + dev project).

**Acceptance criteria:** unit tests green on the auth domain (fake repository); auth flow test green against the Firebase Auth emulator in CI-runnable form (emulator step may be local-only this session — CI wiring may defer to M1.2 with a `ci-debt` note if the emulator-in-Actions setup exceeds the timebox); `flutter analyze`/format/RTL lint clean; coverage ≥60% maintained; app boots on both flavors with Firebase initialized (widget smoke updated); manual: founder can sign in with Google on the iOS simulator against `hayati-dev`.

**External dependencies (founder, at session start):** (a) run `! firebase login` (or `npx firebase-tools login`) so the session can create/configure the Firebase projects — alternatively create two projects in the console and provide their IDs; (b) answer: is there a **paid Apple Developer Program** membership? (Determines when Sign in with Apple + push land; not needed this session.) If (a) is unavailable, the session falls back to emulator-only and defers project provisioning with a note.

**Files likely to change:** `app/lib/features/auth/**` (new), `app/lib/core/config/**`, `app/lib/main_dev.dart`, `app/lib/main_prod.dart`, `app/test/**`, `app/ios/**` (FlutterFire config), `app/pubspec.yaml`, `firebase.json`/`.firebaserc` (new), `docs/architecture.md` (if deviations), `docs/past-prompts.md`, this file.

**Validation steps:** full local gate sequence (`dart format` → `flutter analyze` → `dart tool/rtl_lint.dart app/lib` → `flutter test --coverage` → `dart tool/coverage_gate.dart --min 60 app/coverage/lcov.info`); auth emulator test run; push PR; `gh pr checks --watch`; squash-merge; `gh run watch` on main.

**Complexity:** medium (FlutterFire iOS build-settings churn is the classic risk). **Estimated duration:** one session (1–3 h).

**Stopping conditions:** if `flutterfire configure` breaks the iOS CI build for >30 min, pin the working config manually and file a `ci-debt` issue; if founder login is unavailable, go emulator-only and defer provisioning (documented, not silent); if Google Sign-In on iOS needs URL-scheme fiddling beyond the timebox, land domain+emulator work and push provider wiring to M1.2.

**Explicitly out of scope this session:** Apple/phone providers (M1.2+); profile capture & relationship metadata (M1.2); Crashlytics + App Check (M1.3); any pairing/invite logic (M2); content packs & validator (M3); TikTok/content-ops anything (ADR-007); paywall/RevenueCat (M4).

On completion, follow `session-rules.md` §3: append to `past-prompts.md`, regenerate this file with the next single objective (expected: M1.2 — profile capture + remaining auth providers per Apple-account status), commit, push, verify CI via `gh run watch`.
