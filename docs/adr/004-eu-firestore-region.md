# ADR-004: EU (europe-west multi-region) Firestore region

- **Status:** Accepted
- **Date:** 2026-07-08
- **Deciders:** Founder
- **Related:** [ADR-002](002-firebase-over-supabase.md) (this is the region parameter of the Firebase choice); `architecture.md` §1 (region note)

## Context

> Backfilled at M0.2 (Session 002) from `architecture.md` §11 as a short record. The decision itself dates to project genesis (Session 000).

The two user centers are Istanbul and Riyadh, under KVKK (Turkey) and PDPL (KSA) cross-border rules. A Firestore location is chosen once at project creation and is effectively immutable, so the choice must balance latency for both markets against a defensible compliance posture.

Alternatives considered: **me-central** (Gulf-proximate, lowest Riyadh latency) and **us** (default, cheapest, best global tooling).

## Decision

**europe-west, multi-region EU.**

## Consequences

**Positive**

- Defensible latency for both Istanbul and Riyadh — EU sits between the two markets; neither is disadvantaged.
- A conservative posture for KVKK/PDPL cross-border data flows, versus a US region.
- Multi-region durability.

**Negative / accepted trade-offs**

- Not in-country for KSA. **Revisit clause:** if PDPL data-residency guidance tightens, a region migration is required — the repository pattern (`architecture.md` §2, §10) is kept precisely to make that migration survivable rather than catastrophic.
- `me-central` would give the lowest Gulf latency but worse Turkey latency and, at genesis, thinner regional maturity; rejected for the split-market balance.
- Multi-region EU costs more than a single-region or `us` deployment — accepted for the latency + compliance balance.
