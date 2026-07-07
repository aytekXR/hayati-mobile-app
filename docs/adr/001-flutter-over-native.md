# ADR-001: Flutter over a native Swift/Kotlin pair

- **Status:** Accepted
- **Date:** 2026-07-08
- **Deciders:** Founder
- **Related:** [ADR-006](006-ios-first-release-sequencing.md) (iOS-first sequencing — deliberately retains this single codebase); `architecture.md` §1 (stack table), §2 (module layout)

## Context

> Backfilled at M0.2 (Session 002) from `architecture.md` §11 as a short record. The decision itself dates to project genesis (Session 000).

A solo founder must serve two asymmetric markets — Android-heavy Turkey and iOS-heavy GCC — and reach both platforms eventually, on a near-zero ops budget. Hard requirements: first-class RTL, a golden/widget-test culture that fits the TDD mandate, and one product to maintain rather than two.

The alternative considered was a **native pair**: Swift on iOS + Kotlin on Android, two codebases, two feature timelines.

## Decision

Single **Flutter** (stable channel) codebase in Dart; Riverpod (+ codegen) for state. Domain layer is pure Dart (no Flutter imports).

## Consequences

**Positive**

- One codebase serves both target platforms — a solo founder ships one product, not two, on one timeline.
- First-class RTL via `Directionality` plus golden tests fit the LTR/RTL golden mandate (`test-suite.md`).
- Widget-test culture and a Flutter-free domain layer make the coverage targets cheap.

**Negative / accepted trade-offs**

- Not truly native: platform-channel work is still needed for discreet mode (iOS alternate icons / Android activity-alias) and store plumbing.
- Dependent on the Flutter plugin ecosystem for Firebase and RevenueCat — mitigated because both are first-party supported.
- Some per-platform native polish is traded for cross-platform velocity — an accepted exchange for this product and team size.

**Neutral**

- iOS-first release sequencing ([ADR-006](006-ios-first-release-sequencing.md)) keeps this single codebase precisely so the Android follow-on (M6.5) is hardening, not a second product build.
