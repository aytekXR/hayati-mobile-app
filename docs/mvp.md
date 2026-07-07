# MVP — Strict Scope

**Rule: if it is not listed under IN, it is OUT. Scope additions require editing this file first, with a written justification appended below. The MVP exists to answer Gates 2 and 3 — nothing else.**

**Target: 6 build-weeks after Gate 1 passes. Platforms: iOS-first, then Android — single Flutter codebase retained so the Android follow-on stays cheap (Turkey is Android-heavy, GCC is iOS-heavy). iOS ships first; see the Scope-change log (2026-07-08) and ADR-006 for the iOS-first sequencing and its Gate 2 read caveat.**

## IN

1. Auth: Sign in with Apple, Google, phone OTP.
2. Couple pairing: 6-digit code + deep link; WhatsApp-optimized invite message; partner preview screen (see question + locked answer pre-signup); solo mode = 7 solo questions + invite nudges.
3. Daily question engine: 1/day/couple, TR (2 registers) + AR (MSA-Gulf) + EN packs, launch bank 400/300/300, timezone-correct rollover, category tags.
4. Mutual reveal + private thread (text + emoji reactions only).
5. Couple streak with weekly grace token; pomegranate-seed visual.
6. Paywall: RevenueCat; free tier = daily question + streak; premium unlocks packs + AI coach; **one purchase covers both partners**; 7-day trial; annual-first; TR/SAR/USD price points from `feasibility-report.md` §6; gift-purchase flow.
7. AI Coach v0: 3 personas (Coach, Date Genie, Gift Genie), server-side proxy, premium-only, 30 msgs/day cap, guardrails (non-therapy disclaimer, crisis redirect, register-aware tone).
8. Privacy pack: PIN/biometric lock; discreet icon; private notification text (default ON for AR locale).
9. Localization: TR/AR/EN UI, full RTL, localized store listings.
10. Push notifications: daily question, partner-answered, streak-at-risk (respect quiet hours; Ramadan window config flag pre-built).
11. Analytics: Mixpanel + Firebase; full gate instrumentation (funnel events enumerated in `architecture.md` §7).
12. Legal: privacy policy TR/AR/EN, KVKK/PDPL self-serve delete + export, terms, AI disclaimer.

## OUT (postponed — do not build, do not "quickly add")

Quizzes & shareable result cards (v1.5) · Spice mode (v1.5 — keeps MVP store rating simple) · Bucket list & memories timeline (v1.5) · Ramadan mode (v1.5, but before first Ramadan) · Community polls (v2) · Expert marketplace (v2) · B2B (v2) · Widgets/watch/iPad (v2) · Voice/photo answers (v2) · Web app (v2) · Referral rewards program (v1.5) · Dialect packs beyond MSA-Gulf (v1.5+) · Dark-mode toggle (MVP ships dark-first only, single theme).

## MVP success = Gate 2 then Gate 3

Gate 2 (weeks 1–4 of TR soft launch): pairing ≥40% of signups ≤7d; D7 couple retention ≥25%; crash-free ≥99.5%.
Gate 3 (paywall weeks 1–4): trial→paid ≥30%; install→paid ≥2%.
Both green → execute GCC phase per `roadmap.md`. Either red → fix loop before any new feature; consult `feasibility-report.md` §10 kill criteria.

## Scope-change log

### 2026-07-08 — iOS-first release sequencing (founder directive)

Justification: Platform target changed from simultaneous iOS + Android to **iOS-first** — a release/validation sequencing change, not a stack change. Milestones M1–M6 validate against iOS (simulator tests, iOS goldens, TestFlight); iOS is the first shipping platform (closed beta + TR soft launch on iOS); Android build/test/release + Play-store hardening becomes a follow-on milestone (**M6.5 — Android enablement & Play release**) after the iOS MVP is validated (Gate 3). The Flutter single codebase (`architecture.md` ADR-001) is retained specifically so the Android follow-on stays cheap. Accepted trade-off: Turkey is Android-heavy, so the initial Gate 2 read comes from the TR iOS cohort only — treat it as directional; Android confirms on the follow-on. Gate thresholds, pricing, and IN/OUT scope are unchanged. Decision recorded in ADR-006.
