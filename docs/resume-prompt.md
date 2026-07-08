# Resume Prompt

> This file contains ONE and only ONE objective. Every session executes ONLY this file. (See `project-rules.md` #1, `session-rules.md`.)
>
> **Standing de-gating note (ADR-007):** engineering milestones M1→M6 proceed without content-ops preconditions. Gates 1–3 are decision instruments for marketing/spend/launch posture, not build blockers. TikTok/content-ops work is out of session scope unless the founder re-activates it. First release target: the founder couple's own devices (personal-use-first).
>
> **Standing sequencing note (ADR-006):** iOS-first — milestones validate and ship on iOS first; Android work is re-sequenced into M6.5.

## Objective — Session 005: M1.3 — Apple + phone providers, Crashlytics + App Check, emulator leg in CI

Third slice of M1 (`implementation-plan.md`: Apple/Google/phone auth, profile capture, locale bootstrapping, Crashlytics + App Check). M1.1 landed the auth domain + Google provider (emulator-backed); M1.2 landed real provisioning + l10n + profile capture (PR #10, squash `9a0d0fb`). This session:

1. **Sign in with Apple, emulator-first (paid Apple Developer membership confirmed 2026-07-08):** extend the auth data layer with an Apple gateway alongside `GoogleSignInAuthGateway` (`sign_in_with_apple` package vs `firebase_auth` `OAuthProvider` — verify resolved package sources first, per W2, before designing); fake-backed unit tests; Auth-emulator integration coverage via `signInWithIdp` with an unsigned apple.com token (same mechanism M1.1 validated for Google). Apple portal Service-ID/key config is needed only for real-device flows — defer loudly to the on-device slice if the emulator leg doesn't require it.
2. **Phone auth, emulator-first:** repository + controller support for the verify→code→sign-in flow; unit tests with fakes; emulator integration coverage (the Auth emulator issues fake SMS codes). On-device iOS APNs/reCAPTCHA wiring is explicitly the on-device follow-up, not this session's gate.
3. **Crashlytics:** `firebase_crashlytics` wired in `runHayati` error zones (Flutter fatal + non-fatal hooks) behind a VM-testable seam (record-errors interface, faked in tests); per-flavor collection policy decided and recorded in `architecture.md` (docs-with-code) — suggested: dev off (noise), prod on.
4. **App Check:** `firebase_app_check` activated with the debug provider in dev and App Attest declared for prod; verified as far as Linux allows (unit seam + emulator tolerance); on-device attestation deferred loudly if it needs the Mac.
5. **ci-debt #6 — emulator integration leg in CI:** macOS job (or fold into `ios-build-smoke` to reuse toolchain setup — cost note in #6): boot iOS simulator, start auth+firestore emulators (Java 21+ on the runner), run `integration_test` with the emulator dart-defines. Main-push-only trigger is acceptable if the 10× minute cost bites (issue #6 cost note; billing incident, past-prompts Session 004).

**Acceptance criteria:** unit tests green for both new provider paths and the Crashlytics/App Check seams (fakes); emulator integration test extended to Apple + phone, green locally (device/desktop-runnable like the M1.1/M1.2 legs); #6 CI leg green on this PR (or a documented cost-driven main-only trigger); `flutter analyze`/format/RTL lint clean; coverage ≥60% maintained; both flavors boot.

**External dependencies (founder, at session start):** two console clicks — enable the **Apple** and **Phone** sign-in providers on `hayatiapp-dev` + `hayatiapp-prod` (free-tier Auth provider init is console-only, M1.2 finding). GitHub Actions billing must be healthy (Session 004 incident) — the macOS-heavy #6 work burns 10× minutes.

**Files likely to change:** `app/lib/features/auth/data/**` (Apple/phone gateways), `app/lib/features/auth/presentation/**` (provider buttons + phone code entry), `app/lib/core/firebase/**` (Crashlytics/App Check init), `app/integration_test/**`, `.github/workflows/ci.yml` (#6 leg), `app/pubspec.yaml`, `app/ios/Runner/**` (Apple capability/entitlements), `docs/architecture.md`, `docs/past-prompts.md`, this file.

**Validation steps:** full local gate sequence (`dart format` → `flutter analyze` → `dart tool/rtl_lint.dart app/lib` → `flutter test --coverage` → `dart tool/coverage_gate.dart --min 60 app/coverage/lcov.info`); push PR; `gh pr checks --watch`; squash-merge; `gh run watch` on main.

**Complexity:** high (two providers + two Firebase services + a CI leg on a 10×-billed runner). **Estimated duration:** one session (1–3 h) — if it overflows, land Apple + Crashlytics + #6 and slice phone auth + App Check to the next prompt per session-rules §1.4.

**Stopping conditions:** if the #6 CI leg fights the macOS runner beyond a 30-min timebox, land it as main-push-only (documented in ci.yml) or re-file #6 with findings; if App Attest requires Mac-side steps, ship the debug provider + a loud deferral note; if `sign_in_with_apple` fights the emulator, fall back to the `firebase_auth` `OAuthProvider` flow and record the trade-off.

**Explicitly out of scope this session:** brandkit visual application + goldens six-cell matrix + coverage ratchet to 62% (final M1 slice, next); on-device APNs/App Attest verification (needs the Mac — optional founder smoke, never acceptance-blocking per the automation directive); pairing/invite (M2); content packs & validator (M3); paywall (M4).

On completion, follow `session-rules.md` §3: append to `past-prompts.md`, regenerate this file with the next single objective (expected: M1.4 — brandkit application + goldens matrix + 62% coverage ratchet, closing M1), commit, push, verify CI via `gh run watch`.
