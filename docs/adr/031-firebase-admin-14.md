# ADR-031: `firebase-admin` v13 → v14 — and the honest headline is `@google-cloud/firestore` v7 → v8, on the cascade's own transaction path

- **Status:** Accepted
- **Date:** 2026-07-26 (Session 044)
- **Deciders:** session agent (undated maintenance, no product or cost decision attached; no founder input needed)
- **Related:** issue **#107** (this ADR closes it), **ADR-030** (the Node 22 bump that made this possible and deliberately declined to bundle it), ADR-019 (the resumable cascade — the most exposed surface), ADR-013/ADR-015 (the entitlement mirror and its LWW total-order property — the second), `docs/architecture.md` §2

## Context

`functions/package.json` pinned `firebase-admin` at `^13` for one stated reason, recorded in `architecture.md` §2:

> firebase-admin pinned `^13` — **v14 requires Node ≥22**

**ADR-030 moved the runtime to Node 22, so the reason became void.** ADR-030 deliberately did *not* bundle the upgrade — a dependency major inside a runtime bump turns one verifiable change into two entangled ones — and filed **#107** instead. This is that follow-up. Confirmed at the top of this session: `firebase-admin@14.2.0` declares `engines: { node: '>=22' }`, exactly the constraint that lifted.

## Decision 1 — Upgrade to `^14.2.0`, and be honest about what that actually is

The version number understates it badly. **48 packages move** in the lockfile (measured, rev 2 — the first draft listed five and called that "the real change", which was an under-statement the review caught). The ones that matter:

| Package | Before | After | Why it matters |
|---|---|---|---|
| `firebase-admin` | 13.10.0 | **14.2.0** | the nominal change |
| `firebase-functions` | 7.2.5 | **7.3.0** | **mandatory, not optional — see Decision 3** |
| **`@google-cloud/firestore`** | **7.11.6** | **8.7.0** | **the headline: a client MAJOR on the cascade's path** |
| `google-gax` | 4.6.1 | **5.0.8** | the gRPC/transport layer under Firestore |
| `proto3-json-serializer` | 2.0.2 | **3.0.4** | serialization inside google-gax |
| `jose` | 4.15.9 | **6.2.4** | **auth-token verification — skips v5 entirely** |
| `jwks-rsa` | 3.2.2 | **4.1.0** | **JWKS key fetching, the auth path** |
| `lru-cache` / `lru-memoizer` | 6.0.0 / 2.3.0 | 11.5.2 / 3.0.0 | caching under the auth path |
| `farmhash-modern` | 1.1.0 | **dropped** | a native dep leaves the tree |
| `gaxios` | 6.7.1 | **6.7.1 top-level, plus a nested 7.3.0** | the nested copy is the one the Firestore gRPC path uses |

Two corrections the review earned, recorded rather than quietly fixed: the "before" column originally read `7.11.0` for `@google-cloud/firestore`, which was the **declared range floor** paired against a **resolved** "after" — mixing two different kinds of number in one row. And `gaxios` was shown as a clean 6→7 move when in fact **the top level stays at 6.7.1** and 7.3.0 appears *nested* under `google-gax`.

**`@google-cloud/firestore` going v7 → v8 is the headline.** That is the client library every Firestore call in this codebase runs through — 22 of the 29 `firebase-admin` imports are `firebase-admin/firestore` — and, critically, it is the library that implements the **transactions and query cursors ADR-019's resumable delete cascade is built on**. A reviewer reading "firebase-admin minor-looking bump" would mis-price this change; a reviewer reading "Firestore client major on the cascade path" would price it correctly. The ADR is written for the second reader.

## Decision 2 — The deliverable is the verification, and it targets the two surfaces #107 named

Type-level agreement is necessary and nowhere near sufficient: `tsc` cannot see a changed retry policy, a changed cursor semantic, or a changed transaction abort. So the two most exposed suites were run **deliberately and their results read**, not inferred from an aggregate green:

- **ADR-019's cascade, against the real emulator** — `data-rights-handlers.test.ts` + `revenuecat-webhook-handler.test.ts`: **58 tests pass.** This is the suite that pins the *resumable* behaviour: the `deletions/{uid}` cursor being authoritative on re-drive, the detach transaction seeding the partner's cursor, kill-mid-cascade convergence per step, and `deleteUsers` idempotency. It exercises real transactions against a real Firestore, which is the only place a v8 semantic change would show.
- **ADR-013/015's entitlement core** — `entitlement-convergence.property.test.ts` + `entitlement-core.test.ts`: **109 tests pass**, including the fast-check order-independence property over a two-couple world with transfers mixed into the event multiset.
- **Whole suite: 979 tests / 50 files**, coverage 97.28% statements / 92.45% branches — both above the 80 hard / 85 target gates. `eslint`, both `tsc` projects, and the build are clean.

## Decision 3 — `firebase-functions` 7.2.5 → **7.3.0 is MANDATORY**, not a scope choice — rev 2 corrects this ADR's own framing

The first draft of this ADR said `firebase-functions` was *"again not bundled"*, presenting it as the same deliberate restraint ADR-030 exercised. **That was wrong, and the way it was found is the point.**

`npm install` accepted firebase-admin v14 happily. **`npm ci` — the command CI actually runs — refused it:**

```
npm error While resolving: firebase-functions@7.2.5
npm error Found: firebase-admin@14.2.0
npm error Could not resolve dependency:
npm error peer firebase-admin@"^11.10.0 || ^12.0.0 || ^13.0.0" from firebase-functions@7.2.5
```

**`firebase-functions@7.2.5` declares a peer range that explicitly excludes firebase-admin v14.** So the upgrade is not possible alone — and the local tree that had passed 979 tests was a tree **CI could not reproduce**. That is the S042 false-green shape in a new costume: a local state that works and a CI state that cannot exist.

`firebase-functions@7.3.0` is the first version whose peer range adds `^14.0.0` (verified with `npm view`). It is a **minor** bump, and it also clears the *"package.json indicates an outdated version of firebase-functions"* warning the deploy has been printing. `7.3.2-rc.0` currently holds the `latest` dist-tag and was **deliberately not taken** — a release candidate has no place in a runtime dependency of a special-category data path.

**The general lesson, recorded because this project keeps paying for its cousin: verify with the command CI runs, not the one that is convenient.** `npm install` resolves permissively and mutates the lockfile to fit; `npm ci` asserts the lockfile is already coherent. Only the second answers "will this work in CI".

## Consequences

**Positive:**

- A pin whose justification had already evaporated is gone, and `architecture.md` no longer carries a reason that stopped being true.
- The Firestore client is current, which matters more than the firebase-admin number: security and reliability fixes in that layer are the ones the cascade and the entitlement mirror silently depend on.

**Negative / accepted trade-offs:**

- **Verified against the emulator, not a production soak.** The emulator is a faithful-but-not-identical Firestore; a v8 behavioural change that only manifests against the real service would not appear here. Mitigated by deploying to dev and reading the deployed rollover's next sweep — the same production signal ADR-030 used.
- **The suites are strong but not exhaustive.** They cover the paths ADR-019 and ADR-013 chose to pin. A v8 change in an unpinned corner would pass. Recorded rather than papered over.
- One more dependency major (`firebase-functions`) remains deliberately undone.

## Acceptance

1. `firebase-admin` at `^14.2.0`, lockfile consistent, `engines.node` unchanged at 22.
2. eslint + both `tsc` projects + build clean; full suite green above the coverage gates.
3. The **two named suites run explicitly and their numbers written down** (Decision 2) — not inferred from the aggregate.
4. Deployed to `hayatiapp-dev` and the next scheduled `questionRollover` sweep read: a clean run summary with `failed: 0` and `seasonalCalendarUnavailable: false`. A cascade or Firestore-client regression would most plausibly surface as a sweep error, which is the cheapest production signal available and the one this project already relies on.
