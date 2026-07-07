# ADR-003: RevenueCat for cross-store entitlements

- **Status:** Accepted
- **Date:** 2026-07-08
- **Deciders:** Founder
- **Related:** `architecture.md` §1 (stack), §3 (`subscriptions/{coupleId}` mirror), §4 (entitlements flow); `prd.md` F4 (paywall & subscription)

## Context

> Backfilled at M0.2 (Session 002) from `architecture.md` §11 as a short record. The decision itself dates to project genesis (Session 000).

Payments must span both stores (App Store + Play), support the one-purchase-covers-both-partners entitlement model, drive both partners' unlock from a single event, allow pricing experiments, and be sandbox-testable across TR/SAR/USD storefronts — without a solo founder running receipt-validation infrastructure.

The alternative considered was **direct billing**: StoreKit (iOS) + Play Billing (Android) integrated per-platform, with self-hosted receipt validation.

## Decision

**RevenueCat** as the entitlement layer. RC is the source of truth; an RC webhook → Cloud Function → `subscriptions/{coupleId}` mirror unlocks both partners.

## Consequences

**Positive**

- Cross-store entitlements, webhooks, and pricing experiments out of the box — the industry default for this app category.
- One purchase unlocks both partners via a single webhook-driven Function; no bespoke receipt-validation server.
- Sandbox and pricing experiments across storefronts without custom infrastructure.

**Negative / accepted trade-offs**

- A third-party dependency sits in the payment path, with RC's pricing (a % of tracked revenue above the free tier).
- The entitlement source of truth lives off-Firebase; Firestore holds a mirror only — reconciliation risk is handled by treating the RC webhook as authoritative.
- Direct-billing flexibility is forgone; new store-billing features arrive on RC's SDK cadence (e.g. Play Billing lands with the Android follow-on, M6.5, per [ADR-006](006-ios-first-release-sequencing.md)).
