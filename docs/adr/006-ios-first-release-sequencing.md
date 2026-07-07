# ADR-006: iOS-first release & validation sequencing

- **Status:** Accepted
- **Date:** 2026-07-08
- **Deciders:** Founder
- **Related:** ADR-001 (Flutter over native pair — reaffirmed); `mvp.md` header + Scope-change log (2026-07-08); `roadmap.md` Phase 1, Phase 2, Phase 3 unlock, and the Android enablement follow-on (M6.5); `implementation-plan.md` sequencing anchor + M2/M4/M6 + M6.5

## Context

The MVP was scoped for a simultaneous iOS + Android launch on a single Flutter codebase (`mvp.md`; `architecture.md` ADR-001). A founder directive (2026-07-08) re-sequences delivery to **iOS-first**: build and validate on iOS first, then follow with Android ("after successful completion we will continue with androids").

Two facts frame the decision:

- **The stack is not in question.** ADR-001 (Flutter — one codebase for Android-heavy TR + iOS-heavy GCC, first-class RTL, widget-test culture) stands. iOS-first is a release/validation *sequencing* choice, not a native Swift rewrite. The single codebase is kept precisely so the later Android follow-on is cheap.
- **The markets are asymmetric.** Turkey — the first soft-launch market — is Android-heavy, while the GCC is iOS-heavy. `mvp.md` previously noted that "shipping one platform would blind one gate." Shipping iOS first therefore has a real, non-cosmetic consequence for the first Gate 2 read, which must be surfaced rather than papered over.

## Decision

1. **Validate iOS-first.** Milestones M1–M6 express their acceptance criteria against iOS: simulator/integration tests, iOS goldens, App Store sandbox purchases (TR + SA/SAR storefronts), TestFlight distribution, the 20-couple closed beta, and the Turkey soft launch all run on iOS first.
2. **Ship iOS-first.** iOS is the first shipping platform: closed beta on TestFlight, TR soft launch on the App Store TR storefront (`roadmap.md` Phases 1–2).
3. **Retain the single Flutter codebase.** No native rewrite; ADR-001 stands. The shared codebase is kept so the Android follow-on is platform hardening, not a second product build.
4. **Re-sequence Android into a follow-on milestone — M6.5 "Android enablement & Play release" — gated on iOS MVP validation (Gate 3).** M6.5 covers Play app signing + `release.yml` Play-internal/production track, Play Console metadata (TR/EN), the Android discreet alternate icon, Play Billing sandbox purchases via RevenueCat, Android deep-link cold-start, the mid-range Android performance pass (cold start <2s), and Android re-entry into the CI E2E emulator matrix and the physical-device smoke gate.
5. **Do not change gates, pricing, scope, or content.** Gate 1/2/3 thresholds, TR/SAR/USD price points, the `mvp.md` IN/OUT fence, and the content strategy are all unchanged. This ADR changes *when* and *on which platform* existing work is validated — nothing else.

## Consequences

**Positive**

- Initial release risk concentrates on a single platform; less surface to stabilize before the first real user cohort.
- The GCC (iOS-heavy, the margin market) is served natively by the first shipping build.
- Because the codebase is shared, Android enablement (M6.5) is hardening rather than rebuilding — the follow-on stays cheap, which is the whole point of keeping Flutter.

**Negative / accepted trade-offs**

- **Gate 2 caveat (the honest one).** Turkey is Android-heavy, but the TR soft launch ships on iOS first — so the *initial* Gate 2 read (pairing ≥40% ≤7d; D7 couple retention ≥25%; crash-free ≥99.5%) comes from the **TR iOS cohort only**, a minority-platform slice of the Turkish market. The Gate 2 thresholds are unchanged; this first read is treated as **directional**, and the representative TR read arrives once M6.5 ships and the Android-heavy majority is un-blinded. This caveat is recorded canonically in the `mvp.md` Scope-change log and at `roadmap.md` Phase 2; it is surfaced deliberately, not papered over.
- The harshest cold-start case (mid-range Android reference device) is not exercised until M6.5, after the iOS soft launch. The `prd.md` §8 / `architecture.md` §5 mid-range-Android <2s target is preserved and re-sequenced, not dropped.
- Work that assumed both stores at MVP (Play internal track, Play Console metadata, Android alternate icon, Play Billing sandbox, Android cold-start smoke, Android emulator E2E matrix) is deferred to M6.5 and must not be silently skipped.

**Neutral**

- Reference points that now cite this ADR: `mvp.md` (header + Scope-change log), `roadmap.md` (Phases 1–3 + the M6.5 follow-on section), `implementation-plan.md` (sequencing anchor + M2/M4/M6 + M6.5), `architecture.md` §9 and §11, `test-suite.md` §1 smoke + §2 CI, `prd.md` §10, and `agent-workflows.md` W7.
- The Session 001 / M0.1 scaffold is platform-neutral Flutter and is unaffected in substance by this decision.
