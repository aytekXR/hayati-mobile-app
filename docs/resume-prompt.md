# Resume Prompt

> This file contains ONE and only ONE objective. Every session executes ONLY this file. (See `project-rules.md` #1, `session-rules.md`.)
>
> **Standing de-gating note (ADR-007):** engineering milestones M1→M6 proceed without content-ops preconditions. Gates 1–3 are decision instruments for marketing/spend/launch posture, not build blockers. TikTok/content-ops work is out of session scope unless the founder re-activates it. First release target: the founder couple's own devices (personal-use-first).
>
> **Standing sequencing note (ADR-006):** iOS-first — milestones validate and ship on iOS first; Android work is re-sequenced into M6.5.

## Objective — Session 004: M1.2 — Firebase provisioning + profile capture & locale bootstrapping

Second slice of M1 (`implementation-plan.md`: Apple/Google/phone auth, profile capture, locale bootstrapping, Crashlytics + App Check — 3 sessions). M1.1 landed the auth domain + Google provider emulator-only (PR #7); this session:

1. **Finish issue #5 — repo half (cloud half already done).** Projects exist and are Firebase-attached under the founder's personal account (`aaytekinerdogan@gmail.com`, CLI already logged in): **`hayatiapp-dev`** / **`hayatiapp-prod`**, iOS+Android apps registered for `com.hayati.app`, `.firebaserc` aliases updated (see issue #5 comment for app IDs; done 2026-07-08 post-Session-003). Remaining: `flutterfire configure` per flavor replacing both placeholder options files wholesale; enable the **Google provider** in Firebase Auth on both projects (Identity Toolkit Admin API preferred — console click only as fallback, per the automation directive); iOS `GoogleService-Info.plist`/`GIDClientID` + `CFBundleURLTypes` `REVERSED_CLIENT_ID` in `app/ios/Runner/Info.plist`; Android `serverClientId` into the existing `GoogleSignInAuthGateway` seam.
2. **l10n scaffold:** ARB-based localization (`architecture.md` §6) with minimal TR/AR/EN bundles; migrate the sign-in screen's literal copy; RTL stays lint-enforced.
3. **Profile domain, TDD-first (mandatory):** `RelationshipProfile` entity (relationship status, content language, register — dual-register TR per `prd.md`), locale bootstrapping logic (device locale → profile override; pure Dart) in `features/profile/domain/`; fake-backed unit tests first.
4. **Profile data layer over Firestore:** `cloud_firestore` dependency enters here; `users/{uid}` document mapping (`architecture.md` §3); tests against the **Firestore emulator** (extend `firebase.json`; plain-VM tests use fakes — the emulator leg is device/desktop-runnable like M1.1's auth leg).
5. **Onboarding capture shell:** post-sign-in routing — fresh signup → profile capture screen (status/language/register selection) → placeholder "invite your partner" stub (full pairing is M2); widget tests for loading/error/content in all three locales (M1 accept criterion).

**Acceptance criteria:** profile domain unit tests green (fakes); capture-screen widget tests green in tr/AR/en; locale bootstrap unit-tested (device→override precedence); `flutter analyze`/format/RTL lint clean; coverage ≥60% maintained; both flavors boot; automated verification is the gate (per the automation directive, past-prompts 2026-07-08): emulator-backed tests + CI green — the founder on-device smoke against real `hayatiapp-dev` is optional/nice-to-have whenever the founder is at the Mac, not acceptance-blocking.

**External dependencies (founder, at session start):** none blocking — both Session-003 asks resolved 2026-07-08: (a) Firebase CLI logged in (personal account; org account was the root cause of the provisioning 403s); (b) **paid Apple Developer Program membership CONFIRMED** → M1.3 proceeds with Sign in with Apple + APNs/phone auth as planned.

**Files likely to change:** `app/lib/features/profile/**` (new), `app/lib/l10n/**` + `l10n.yaml` (new), `app/lib/features/auth/presentation/**` (routing + copy migration), `app/lib/core/firebase/**` (real options if #5 runs), `app/ios/Runner/Info.plist` (if #5 runs), `firebase.json` (firestore emulator), `app/pubspec.yaml`, `app/test/**`, `docs/architecture.md` (if deviations), `docs/past-prompts.md`, this file.

**Validation steps:** full local gate sequence (`dart format` → `flutter analyze` → `dart tool/rtl_lint.dart app/lib` → `flutter test --coverage` → `dart tool/coverage_gate.dart --min 60 app/coverage/lcov.info`); push PR; `gh pr checks --watch`; squash-merge; `gh run watch` on main.

**Complexity:** medium-high (Firestore enters the stack; l10n scaffolding touches every screen string). **Estimated duration:** one session (1–3 h) — if it overflows, land #5 + l10n + profile domain and slice the Firestore data layer into M1.3 per session-rules §1.4.

**Stopping conditions:** if `flutterfire configure` breaks the iOS CI build >30 min, pin config manually and file `ci-debt`; if Google-provider enablement resists the Admin API beyond a short timebox, fall back to the one console click and note it; if l10n tooling fights the timebox, land TR/EN and file the AR bundle as an explicit next-slice item (never ship silent partial RTL).

**Explicitly out of scope this session:** Apple/phone providers + Crashlytics + App Check + emulator-in-CI #6 (M1.3); pairing/invite logic beyond the placeholder stub (M2); content packs & validator (M3); TikTok/content-ops (ADR-007); paywall (M4); brandkit visual application + goldens (later M1 slice, with l10n now unblocking the 6-cell matrix).

On completion, follow `session-rules.md` §3: append to `past-prompts.md`, regenerate this file with the next single objective (expected: M1.3 — remaining providers per Apple-account status + Crashlytics + App Check + ci-debt #6), commit, push, verify CI via `gh run watch`.
