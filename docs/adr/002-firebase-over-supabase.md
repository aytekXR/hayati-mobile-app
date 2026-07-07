# ADR-002: Firebase over Supabase

- **Status:** Accepted
- **Date:** 2026-07-08
- **Deciders:** Founder
- **Related:** [ADR-004](004-eu-firestore-region.md) (the EU region choice is a Firestore parameter of this decision); `architecture.md` §1 (stack), §3 (data model)

## Context

> Backfilled at M0.2 (Session 002) from `architecture.md` §11 as a short record. The decision itself dates to project genesis (Session 000).

The backend must provide auth, an offline-capable datastore, serverless functions, push (FCM), remote feature flags for the GCC regional strategy, crash reporting, and app attestation — on a solo-founder ops budget ≈ zero.

The alternative considered was **Supabase**: Postgres with relational queries and joins, row-level security, and stronger SQL ergonomics.

## Decision

**Firebase**: Auth, Cloud Firestore, Cloud Functions (TypeScript), FCM, Remote Config, Crashlytics, App Check.

## Consequences

**Positive**

- Offline persistence is built in — the offline answer-queue/reveal-on-sync flow is native, not hand-rolled.
- FCM + Remote Config + Crashlytics + App Check are one integrated first-party suite; Remote Config gives the regional feature flags the GCC strategy requires.
- Fully managed, zero-ops backend fits the solo founder.

**Negative / accepted trade-offs**

- Vendor lock-in to Firebase/Google.
- No relational queries or joins; document-model fan-out must be modeled by hand — acceptable given the couple-scoped shape ([ADR-005](005-couple-scoped-data-model.md)).
- Supabase's Postgres/SQL ergonomics are forgone; complex reporting (search, poll aggregation) is a v2 problem isolated behind repositories.
- The datastore region is constrained to Firestore's fixed location options, driving [ADR-004](004-eu-firestore-region.md).
