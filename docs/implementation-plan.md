# Implementation Plan — Hayati

Milestones are sized in **sessions** (one session = one `resume-prompt.md` objective, per `project-rules.md`). TDD per `test-suite.md` throughout: acceptance criteria below are expressed as tests wherever possible.

**Release sequencing (iOS-first, ADR-006):** M0–M6 build the single Flutter codebase (`architecture.md` ADR-001 stands) but validate and ship on **iOS first** — simulator/integration tests, iOS goldens, App Store sandbox, TestFlight, closed beta + TR soft launch on iOS. Android build/test/release + Play-store hardening is re-sequenced into **M6.5 — Android enablement & Play release**, enabled only after the iOS MVP is validated (Gate 3). One codebase keeps the Android follow-on cheap while concentrating initial release risk on a single platform.

## M0 — Repository & CI (2 sessions) · *may run during Phase 0*

1. ✅ *(Session 001, 2026-07-08)* Flutter scaffold, flavors (dev/prod), folder layout per `architecture.md` §2; lint config (incl. RTL `start/end` lint); Riverpod + codegen wiring.
2. GitHub Actions `ci.yml` (format, analyze, test, coverage gate ≥60% rising), branch protection, PR template, ADR skeleton, Fastlane init.

**Accept:** fresh clone → `flutter test` green; pushed PR shows all checks; a deliberately failing test blocks merge.

## M1 — Auth & profile (3 sessions)

Apple/Google/phone auth via Firebase; relationship profile capture (status, language, register); locale bootstrapping (device → override); Crashlytics + App Check live.

**Accept:** unit tests on profile domain; widget tests on onboarding states (all 3 locales); emulator integration test: fresh signup lands on "invite your partner."

## M2 — Pairing (4 sessions) · *highest-risk milestone — the activation gate lives here*

Invite Function (code + deep link), WhatsApp-formatted share message, partner preview endpoint + screen (question visible, answer locked, zero-auth), transactional join with race rejection, solo mode (7 solo questions + nudges).

**Accept:** rules tests prove non-members can't read couple docs and preview never leaks answer content; integration test: two emulated devices pair via code; deep link cold-start test on iOS (Android cold-start added in M6.5).

## M3 — Daily loop & streak (4 sessions)

Question packs pipeline (`content/` JSON → validator → bundled + remote sync); rollover Function (timezone buckets, register/seasonal selection, deterministic); answer → mutual reveal → private thread; streak with grace token; pushes (daily, partner-answered, streak-at-risk) with quiet hours + discreet-text mode.

**Accept:** rollover unit tests across timezones incl. DST; **server-side reveal rule test: partner answer unreadable pre-answer**; streak property tests (grace, gaps, timezone edges); goldens: question card TR/AR/EN × LTR/RTL.

## M4 — Paywall & entitlements (3 sessions)

RevenueCat products (TR/SAR/USD tiers, trial, annual-first paywall, gift flow); webhook Function → couple entitlement mirror; free-tier gating.

**Accept:** sandbox purchases on the App Store in TR + SA storefronts (Play Billing sandbox in M6.5); unit tests: one purchase entitles both partners, expiry downgrades both; paywall goldens per locale.

## M5 — AI Coach v0 (3 sessions)

`coach_proxy` Function: persona + register system prompts, crisis-lexicon pre-filter (TR/AR/EN) → localized professional-help response path, post-filter, per-user daily + per-couple monthly caps (Remote Config); chat UI with disclaimer.

**Accept:** contract tests with recorded LLM fixtures; safety tests: seeded crisis phrases in all 3 languages route to help path, never to persona; cap-exhaustion path tested; no coach text in analytics payloads (asserted).

## M6 — Privacy, polish, launch hardening (3 sessions)

PIN/biometric lock; discreet alternate icon (iOS; Android in M6.5); KVKK/PDPL export + cascade-delete Functions (with partner notification); settings; App Store metadata TR/EN via Fastlane; performance pass (cold start <2s on an iOS reference device; the mid-range Android <2s pass is validated in M6.5); crash-free instrumentation; closed-beta build.

**Accept:** delete cascade integration test (couple data gone, partner notified, entitlement handled); lock bypass attempts covered by widget tests; `release.yml` produces signed builds to TestFlight (Play internal track added in M6.5).

## M6.5 — Android enablement & Play release (follow-on) · *gated on iOS MVP validation (Gate 3) per ADR-006*

Android build/test/release hardening, kept cheap by the single Flutter codebase (`architecture.md` ADR-001). Play app signing + `release.yml` Play-internal track; Play Console store metadata TR/EN via Fastlane; discreet alternate icon on Android; Play Billing sandbox purchases (TR + SA storefronts) via RevenueCat; Android deep-link cold-start; mid-range Android performance pass.

**Accept:** deep link cold-start test on Android; sandbox purchases on the Play Store in TR + SA storefronts; cold start <2s on mid-range Android reference device; `release.yml` produces signed builds to Play internal; goldens re-baselined for Android render (TR/AR/EN × LTR/RTL).

## M7 — Post-Gate-2/3 (scheduled by `roadmap.md`, not pre-planned in detail)

v1.5 features enter as fresh milestone specs written *at that time* — pre-speccing them now would violate the feature-freeze discipline of Phases 2–3.

## Cross-cutting rules

- Every milestone ends with docs sync (`architecture.md`, ADRs) — rule #8.
- Content bank authoring (non-code) proceeds in parallel; the pack validator (M3) is the only code dependency.
- Gate instrumentation events (`architecture.md` §7) are implemented *with* their features, never retrofitted.
