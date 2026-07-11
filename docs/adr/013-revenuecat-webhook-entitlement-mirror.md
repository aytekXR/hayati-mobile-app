# ADR-013: RevenueCat webhook → couple entitlement mirror

- **Status:** Accepted
- **Date:** 2026-07-11
- **Deciders:** Session 015 (per `docs/resume-prompt.md` M4.1 "decide + document" mandates; design hardened by a three-lens adversarial review before implementation)
- **Related:** [ADR-003](003-revenuecat-for-entitlements.md) (RevenueCat pre-decided; RC = source of truth, Firestore holds a projection); [ADR-005](005-couple-scoped-data-model.md); `docs/architecture.md` §3 (`subscriptions/{coupleId}` shape), §4 (entitlements flow), §8; `docs/prd.md` F4 (paywall & subscription); `docs/test-suite.md` §1

## Context

M4.1 builds the server truth the paywall (M4.2) and live purchases (M4.3) will
sit on: a `revenueCatWebhook` HTTP Function that projects RevenueCat webhook
events onto `subscriptions/{coupleId}`, so that **one purchase entitles both
partners and expiry downgrades both** (the M4 accept lines). This session is
emulator-only by design — events are mocked from RC's documented webhook
schema (verified against the 2026 docs: envelope, per-type fields, retry
policy); there is no RC account yet (operator item, due at M4.2).

Decision clusters that came due:

1. **Webhook authentication** and how the shared secret reaches the Function
   (the repo has *no* existing env/config/secret seam — this is the first).
2. **Event model**: which RC event types mutate the mirror, and what each
   means for access (RC's own semantics: `CANCELLATION` is *not* access
   loss; only `EXPIRATION` is).
3. **`app_user_id` → couple resolution**: how an RC subscriber maps to a
   `coupleId`.
4. **Idempotency + out-of-order guard**: RC documents duplicate delivery
   (retries reuse the same event `id`) and gives **no ordering guarantee**;
   replayed and stale events must never regress the mirror.
5. **Grace/billing-retry mapping** and the mirror **doc shape** the app and
   rules consume.

## Decision 1 — Auth: verbatim `Authorization` string, env-seam, fail-closed

RC sends the dashboard-configured string **verbatim** in the `Authorization`
header — no `Bearer` prefix, no HMAC/signature; the shared secret is the only
built-in auth. The webhook therefore:

- **exact-string-compares** the incoming header against the expected token
  using a constant-time comparison (`crypto.timingSafeEqual` after a length
  check); mismatch or absence → **401** `{error: 'unauthorized'}`.
- resolves the expected token through the repo's handler-factory DI style:
  `makeRevenueCatWebhookHandler({ expectedToken?, ... })` with the production
  default reading **`process.env.RC_WEBHOOK_TOKEN` at request time**. This
  single read path covers every runtime: at deploy the function declares
  `secrets: ['RC_WEBHOOK_TOKEN']` and Cloud Secret Manager binds the value
  into the process env (deploy posture — verified at the first Blaze deploy,
  same posture as the rollover's schedule trigger); the functions emulator
  inherits its env; in-process tests inject a literal through the seam.
- **fails closed**: if the configured token is absent/empty, every request
  gets **503** `{error: 'unconfigured'}` — an unset secret must never mean
  "accept everything".
- the real token is **never committed**. The emulator e2e suite gets a
  test-only value through **`functions/.env.demo-hayati`** (committed, loudly
  commented): the functions emulator loads `.env.<projectId>` dotenv files
  into the runtime env, and this one binds only when the emulator runs as
  `demo-hayati` — real project ids (`hayatiapp-dev`/`-prod`) never read it,
  so the canonical `emulators:exec` command and CI stay unchanged and no
  real secret material can hide in it by construction. (If firebase-tools'
  dotenv loading regresses, the fallback is exporting the variable in the
  exec environment — recorded here so the e2e suite's loud
  missing-token error has a documented fix.)

**Security boundary, stated honestly (review findings):**

- **Token secrecy is the entire anti-forgery boundary.** The Decision 4
  guard makes *exact replays* of captured requests no-ops; it does nothing
  against an attacker holding the token who mints novel event ids. When the
  real token is created (M4.2, RC dashboard), it MUST be high-entropy
  (≥256-bit random) — recorded in `operator-expected.md` alongside the RC
  account item.
- **No rate limiter, deliberately** (the zero-auth `invitePreview` has one;
  this authed endpoint does not): a 429 to RevenueCat is a non-200, and RC
  retries non-200s only 5 times before **permanently dropping the event** —
  rate-limiting the legitimate sender risks silently losing real
  entitlement events to protect against a forger who, by premise, already
  holds the only credential. The 401 path costs O(1). Infra-grade limiting
  (Cloud Armor) is the documented path if a public-scale surface ever needs
  it.
- **The 503 fail-closed window is finite.** RC's retry budget is
  5+10+20+40+80 ≈ 155 minutes per event: a misconfigured secret self-heals
  only for events younger than that; older ones are permanently dropped,
  and **M4.1 has no reconciliation path** (RC REST API backfill is an M4.2+
  item, noted in Consequences).

## Decision 2 — Event model: project absolute facts; revoke only on EXPIRATION

The body is parsed as RC's documented envelope `{api_version, event}` (fields
live **inside** `event`). Handled types, their access effect, and the
`willRenew` each projects (pinned per type — review finding — since RC events
carry no uniform renewal flag):

| Event | Entitled until | willRenew |
|---|---|---|
| `INITIAL_PURCHASE`, `RENEWAL` | `expiration_at_ms` (null = non-expiring) | true |
| `NON_RENEWING_PURCHASE` | `expiration_at_ms` (null = non-expiring) | **false** |
| `PRODUCT_CHANGE` | `expiration_at_ms`; product = `new_product_id ?? product_id` (the field is omitted-when-null; falling back keeps the current product instead of dropping it) | true |
| `UNCANCELLATION` | `expiration_at_ms` | true |
| `CANCELLATION` | `expiration_at_ms` (**still entitled** — auto-renew OFF; RC: "don't revoke access on this event") | false |
| `BILLING_ISSUE` | **`grace_period_expiration_at_ms ?? expiration_at_ms`** — the grace field is always *present* on this type but **can be `null`** (no grace period configured); a null grace MUST NOT collapse into the non-expiring sentinel (review finding: that would mint permanent free premium on a failed card) | true (billing retry in progress — renewal still being attempted) |
| `SUBSCRIPTION_PAUSED` | `expiration_at_ms` (Play-only; irrelevant until M6.5, mapped for completeness) | false |
| `SUBSCRIPTION_EXTENDED` | the new `expiration_at_ms` | true |
| `EXPIRATION` | **entitled = false** — the ONLY revoking event | false |
| `TEST` | logged no-op (RC dashboard "send test event"; never persisted) | — |
| anything else (`TRANSFER`, `INVOICE_ISSUED`, future types) | logged no-op, **200** (unknown types must never retry-loop) | — |

`TRANSFER` (a subscription moving between RC subscribers) is deliberately in
the no-op bucket this session: within a couple both uids resolve to the same
mirror anyway, and cross-couple transfers have no product story before the
M4.3 gift flow — recorded there as the event to revisit.

Structural choices:

- **Every applied event projects from its own payload alone** (all
  entitled-until candidates are absolute timestamps in the event; the
  `??`-fallbacks above stay event-local). The projection of the
  total-order-maximal event *is* the mirror state — this is what makes the
  out-of-order guard (Decision 4) convergent by construction.
- **Entitlement granularity is pinned to the simplest couple-scoped mapping**
  (resume-prompt stopping condition): one `premium` entitlement concept. The
  mirror stores `productId` and the raw `entitlementIds` for
  forward-compatibility, but the entitled/free decision is
  entitlement-id-agnostic this session. Revisited at M4.2 with real RC
  product config.
- The mirror stores `environment` (`SANDBOX`/`PRODUCTION`) verbatim. No
  filtering: dev and prod are separate Firebase projects and will be
  separate RC projects, so cross-environment leakage is structural, not
  filtered.

**Request-body contract (review finding — the 4xx boundary made precise):**

- Syntactically invalid JSON never reaches the handler: the functions
  framework's body parser rejects it with its own **400** (framework-owned;
  acknowledged, not interceptable — still 4xx, satisfying the accept line).
- Valid JSON that is **not structurally an RC webhook** (no `event` object,
  or `event.type`/`event.id` not strings, or `event_timestamp_ms` not a
  number, or `app_user_id` not a string) → **400** `{error: 'malformed'}`,
  decided by explicit validation — a shape surprise must never fall through
  to a thrown error's 500-retry-loop.
- A **known type whose per-type projection fields are missing/invalid**
  (e.g. an `INITIAL_PURCHASE` with a non-numeric `expiration_at_ms`) →
  **200 + counted loud skip** (`unprojectable`) with **no mirror write**:
  it authenticated as RC, so it may be schema drift — never mutate on
  doubt, never burn RC's retry budget on a deterministic parse failure.

**Log projection (review finding — PII):** RC events carry
`subscriber_attributes` (commonly `$email`, `$phoneNumber`). The webhook
logs **only** `{type, id, environment, decision, coupleId?}` through a single
log-projection helper — **never the raw body, never `subscriber_attributes`,
never alias lists** — the `invitePreview` prefix-only logging discipline
carried onto this endpoint.

## Decision 3 — Identity: `app_user_id` = Firebase uid → `users/{uid}.coupleId`

The M4.2 client will call `Purchases.logIn(firebaseUid)` before any purchase,
so RC's subscriber identity is the Firebase uid. Resolution scans the event's
identity candidates in order — `app_user_id`, `original_app_user_id`, then
`aliases[]` — skipping RC anonymous ids (`$RCAnonymousID:` prefix; a
pre-login purchase can leave the uid only in `aliases`), with one **hard
stop** (review finding): **if a candidate resolves to an existing
`users/{uid}` doc, the scan ends there** — its `coupleId` (or the lack of
one) is the answer. Falling *past* a real-but-unpaired user into older
aliases could resolve a previous relationship's uid and mirror the purchase
onto an ex-partner's couple; a real user doc without `coupleId` is the
unpaired-skip case, never a license to keep hunting. The couple doc is *not*
read — `coupleId` on the user doc is already the authorization anchor
everywhere else (ADR-005).

**Unresolvable events** (all candidates anonymous or without user docs, or
the resolved user has no `coupleId`) are **counted loud skips returning
200**: RC would re-deliver a non-200 five times and then drop it permanently
anyway, so a retry buys nothing an unpaired user's later pairing wouldn't
invalidate. The gap this leaves — purchase-then-pair never reaches the
mirror — is recorded as an accepted M4.1 limitation; M4.2's paywall flow
(which gates purchase behind pairing) is what closes it for real users.

## Decision 4 — Idempotency + ordering: per-subscriber lanes, last-writer-wins over a total order

RC's guarantees: event `id` is the idempotency key (retries reuse `id` and
`event_timestamp_ms`); **no cross-event ordering guarantee** (cancellations
have been observed hours late). Ordering by `event_timestamp_ms` is only
meaningful **within one RC subscriber** — both partners purchasing (both are
allowed to; they're a couple) are two independent RC subscribers whose event
timelines must not clobber each other on the shared couple mirror. The
mirror therefore keeps **one lane per originating uid**, and each lane is a
**last-writer-wins register over the total order
`(event_timestamp_ms, event.id)`** (lexicographic; the id — a UUID — breaks
timestamp ties deterministically):

- **Guard:** apply the event iff
  `(event_timestamp_ms, id) > (lane.lastEventTimestampMs, lane.lastEventId)`;
  otherwise skip (`replay-skip` when equal, `stale-skip` when older).
- **Apply:** the lane state becomes the pure projection of *this event
  alone* (Decision 2) plus the advanced order key.

This single rule subsumes replay and out-of-order safety with **O(1) lane
state** (an earlier draft carried a bounded processed-ids FIFO; the
adversarial review showed equal-timestamp distinct events made both the FIFO
and a strict-timestamp guard order-dependent, and the total order eliminates
the FIFO entirely): a retry reuses `(ts, id)` → equal → skip; an older event
→ strictly less → skip; equal-`ts`-different-`id` pairs (same-millisecond
store bursts are real) resolve to the same winner **regardless of arrival
order**. The lane always equals the projection of the total-order-maximal
event seen, so **any interleaving of replays, reorders, and duplicates
converges to clean-in-order delivery** — proven by a fast-check property
test whose generator **deliberately draws colliding timestamps** (the M3.4
streak-engine pattern), plus targeted replay/out-of-order cases in-process
against the emulator. (Where RC itself defines no order — the equal-`ts`
case — the `id` tie-break is *deterministic* rather than semantically
meaningful; that is the strongest claim an unordered source permits.)

The couple-level summary (what the app reads) is derived in the same
transaction: **entitled if any lane is entitled** (this is literally
"one purchase entitles both"; when the only active lane expires, the couple
downgrades — "expiry downgrades both"). The winning lane (for display
fields) is chosen deterministically: entitled lanes first, then latest
`expiresAtMs` (null = non-expiring ranks highest), then the lane's
`(lastEventTimestampMs, lastEventId)` order key as the final tie-break.

Each webhook event is processed in **one Firestore transaction** (read
mirror → guard → project → write lane + summary), the M3.4 latch
discipline: the read set includes the lane's order key, so concurrent
deliveries — same lane or sibling lanes on the same doc — serialize and the
guards are race-safe.

## Decision 5 — Doc shape, rules, and the app seam

```
subscriptions/{coupleId}:
  entitled: bool                    # derived: any lane entitled
  productId: string|null            # winning lane's product
  periodType: string|null           # NORMAL | TRIAL | INTRO | ...
  expiresAtMs: number|null          # winning lane's entitled-until (null = non-expiring)
  willRenew: bool                   # winning lane's auto-renew state
  store: string|null                # APP_STORE | PLAY_STORE | ...
  environment: string|null          # SANDBOX | PRODUCTION
  lanes: { <uid>: { entitled, productId, periodType, expiresAtMs, willRenew,
                    store, environment, entitlementIds,
                    lastEventId, lastEventTimestampMs, updatedAtMs } }
  updatedAt: serverTimestamp
```

- **Rules:** member-only read (`get()` of `couples/{coupleId}` — the doc id
  *is* the coupleId, the M3.2 `days` membership pattern), **all client
  writes denied** (the webhook's admin SDK is the sole writer), delete
  included (removal is the M6 cascade). Mutation-tested both ways.
- **App seam:** `EntitlementRepository.watchEntitlement(coupleId)` →
  `Stream<CoupleEntitlement?>` behind the usual throw-until-overridden
  provider; **absent doc = the free tier** (every couple is free until the
  webhook writes otherwise — no backfill). The domain model reads the
  summary fields only (lanes are server bookkeeping). The gating decision
  point is a single derived provider: premium iff `entitled` AND
  (`expiresAt` null OR in the future vs the app's clock seam). No UI flips
  this session (nothing to gate until the paywall exists).
- **`entitled` is never sufficient alone** (review finding, binding on
  every future consumer, server-side included): a delayed `EXPIRATION`
  leaves the mirror `entitled: true` with a past `expiresAtMs` for hours.
  Any consumer of the mirror — the app's premium provider today, any M4.2+
  Function tomorrow — must pair the boolean with the `expiresAtMs`
  future-check. The raw boolean is a projection artifact, not a grant.

## Consequences

- The paywall (M4.2) lands on server truth: RC stays the source of truth
  (ADR-003), Firestore holds a convergent projection, and the app's
  entitled/free read is one watched doc + one pure derivation.
- The lane model makes the double-purchase edge (both partners buy) safe by
  construction instead of last-writer-wins corruption across subscribers;
  the cost is a slightly wider doc, invisible to the app which reads the
  summary.
- The first env/secret seam enters the codebase with a fail-closed posture
  and zero committed secret material; actual Secret Manager binding is
  deploy-verified at first Blaze deploy (operator item 2).
- Replay/out-of-order safety is transactional truth proven in-process
  (property test with colliding timestamps + emulator suites), not
  best-effort — the same bar as the M3.4 reveal latch.
- **Belt-and-braces coverage is asymmetric** (review finding): the app's
  expiry check auto-downgrades on a *missed revocation*, but a missed
  `INITIAL_PURCHASE`/`RENEWAL` (e.g. dropped past RC's ~155-minute retry
  budget) leaves a paying couple downgraded at the stale expiry with **no
  M4.1 recovery path**. RC REST-API reconciliation/backfill is recorded as
  the M4.2+ item that closes this; until then the exposure window is
  bounded by RC's retry budget and the founder-couple-only usage.
- Known accepted gaps, all recorded: purchase-before-pairing events skip
  loudly (closed structurally by M4.2's flow); entitlement-id granularity
  deferred to real RC config (M4.2); `TRANSFER` no-op until the M4.3 gift
  flow; RC's 60s response budget respected by one bounded transaction per
  event.
