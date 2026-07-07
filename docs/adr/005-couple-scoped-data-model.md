# ADR-005: Couple-scoped data model (no global social graph)

- **Status:** Accepted
- **Date:** 2026-07-08
- **Deciders:** Founder
- **Related:** `prd.md` §6 (social-layer decision record — "the couple IS the network"); `architecture.md` §3 (data model), §10 (scalability)

## Context

> Backfilled at M0.2 (Session 002) from `architecture.md` §11 as a short record. The decision itself dates to project genesis (Session 000).

The product decision in `prd.md` §6 is that the couple is the network: no public profiles, no feed, no stranger interaction. The data model follows the product — all relationship content is scoped under `couples/{coupleId}`.

The alternative considered was a **global social graph / community feed** (user-follows-user edges, cross-couple feeds) as in mainstream social apps.

## Decision

A **couple-scoped** Firestore model: `couples/{coupleId}` with a `days` sub-collection whose per-day docs hold the answers and the reveal `thread[]` array (`architecture.md` §3); no global feed and no cross-couple edges. The only extra-couple surfaces are outbound share cards and (v2) anonymous aggregate polls (`prd.md` F12).

## Consequences

**Positive**

- Firestore fan-out is trivial — couple-scoped docs, no global feeds — and scales to 100K couples comfortably (`architecture.md` §10).
- Security rules are simple and strong: a user reads/writes only their own couple's docs (`architecture.md` §3 invariants).
- Matches the positioning: discretion and trust are the GCC purchase drivers, and there is no stranger surface for a solo founder to moderate.

**Negative / accepted trade-offs**

- v2 community features (F12 anonymous polls, aggregation, any cross-couple analytics) need net-new aggregation work — they do not fall out of this model for free.
- No social-graph virality; growth leans on invites and content, not a feed — accepted per `prd.md` §6.
- **Mitigation:** the v2 rework (search, community-poll aggregation) is isolated behind repositories (`architecture.md` §10) so the couple-scoped core is not disturbed.
