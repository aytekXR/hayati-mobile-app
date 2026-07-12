# ADR-015: `TRANSFER` events, and what "gift your partner" actually is

- **Status:** Accepted
- **Date:** 2026-07-12
- **Deciders:** Session 017 (M4.3; `docs/resume-prompt.md` "decide + document" mandates)
- **Related:** [ADR-013](013-revenuecat-webhook-entitlement-mirror.md) (**this ADR supersedes its Decision-2 `TRANSFER` row**, which is factually wrong — see Finding 0); [ADR-014](014-paywall-purchases-seam-and-premium-gating.md) (the paywall this decision mounts on); [ADR-003](003-revenuecat-for-entitlements.md); [ADR-005](005-couple-scoped-data-model.md); `docs/prd.md` F4; `docs/architecture.md` §3/§4; `docs/test-suite.md` §1

## Context

M4.3 is the last M4 engineering slice. Two things came due, and RevenueCat's
own documentation (re-read live on 2026-07-12) decided both of them against
the plan we had written:

1. **`TRANSFER`** — ADR-013 parked it as "a logged no-op until the M4.3 gift
   flow". It is not a no-op; it is not even reachable (Finding 0).
2. **PRD F4's "gift-your-partner purchase flow"** — the assumption was that
   gifting is a store feature we would wire up. It is not (Decision 6).

The founder's RevenueCat account + App Store Connect record (operator item 0)
still do not exist, so this session is emulator-only by design — the same
posture as M4.1. Every claim below that *can* only be settled against a live
RC project is listed in "Open questions for the live-sandbox session".

## Finding 0 — today a real `TRANSFER` is a **400**, not a logged no-op

ADR-013 Decision 2's table routes `TRANSFER` into the unknown-type bucket:
"logged no-op, **200**". **That row is unreachable in production.**

RC's `TRANSFER` payload does **not** carry `app_user_id` — the subscriber
*identity* field group (`app_user_id`, `original_app_user_id`, `aliases`)
does not list Transfer among its applicable events, and RC's own sample event
confirms it. The whole body is:

```json
{ "api_version": "1.0",
  "event": { "type": "TRANSFER", "id": "CD489E0E-…", "event_timestamp_ms": 78789789798798,
             "transferred_from": ["00005A1C-…"], "transferred_to": ["4BEDB450-…"],
             "store": "APP_STORE", "environment": "PRODUCTION", "app_id": "1234567890" } }
```

`parseRcEvent` hard-requires a non-empty `app_user_id` on **every** envelope,
so a genuine `TRANSFER` is classified `malformed` → the shell answers **400** →
RC retries 5× over ~155 minutes → **drops the event permanently**. Not a
no-op: a burned retry budget and a lost event.

No test caught this because every `TRANSFER` test built a *post-parse*
`RcEvent`, and both raw-envelope builders (`rawBody`, `envelope`) inject
`app_user_id` unconditionally. The envelope contract had never seen a real
transfer body. **Even the "do nothing" outcome for M4.3 requires a parser
change** — which is what makes the rest of this ADR unavoidable rather than
speculative.

## The two facts that constrain every decision below

**Fact 1 — `TRANSFER` is a bare pointer event.** It carries
`{type, id, event_timestamp_ms, transferred_from[], transferred_to[]}` plus
*sometimes* `store`/`environment`. There is **no `product_id`, no
`expiration_at_ms`, no `entitlement_ids`, no `period_type`** — and RC sends
**exactly one webhook** for a transfer (delivered for the destination
subscriber; the body is identical for both sides), with **no follow-up
`EXPIRATION` for the loser** (RC staff state this explicitly; the docs are
silent, so we depend on neither the presence *nor* the absence of a second
event).

**Fact 2 — the gain half is therefore structurally unprojectable.** A lane
needs an entitled-until. The only values available for a gainer are a
fabrication or `null` — and in this codebase `null` means *non-expiring*,
never *unknown* (`LaneProjection.expiresAtMs`). Minting
`{entitled: true, expiresAtMs: null}` for a gainer is **permanent free
premium**: the exact bug class ADR-013's pre-code review already killed once
(the null-grace `BILLING_ISSUE` find).

## Decision 1 — A `TRANSFER` may never create or entitle a gainer's lane

Full stop, binding on every future consumer. A gainer becomes premium only via
a *subsequent* lifecycle event carrying real facts (RC: "only that user will
receive subsequent events"), or via the RC-REST reconciliation that ADR-013
already parked for the deploy era.

**Cost, named:** a couple that *receives* a transferred subscription stays free
until the subscription's next event — for an annual plan, up to a year. This is
the single biggest accepted cost of M4.3. It is bounded by reconciliation and
it fails **closed** (free), never open.

## Decision 2 — Revoke only on positive evidence; every ambiguity holds

The damage is asymmetric, and that asymmetry decides every ambiguous case:

| | cost |
|---|---|
| **Revoke when we shouldn't** | a **paying couple instantly loses premium** — unrecoverable without a manual grant we cannot issue (no RC account). |
| **Fail to revoke when we should** | one couple keeps premium for the tail of a period **someone actually paid for**. Self-retires: `isPremium` is `entitled && unexpired`, so a stale lane stops granting on its own clock. |

> **Standing rule: revoke the loser's lane iff the destination is FULLY KNOWN
> and does not include the loser's couple. Otherwise hold.**

(The one place the leak is *unbounded* is a lane with `expiresAtMs == null` —
the non-expiring shape a `NON_RENEWING_PURCHASE` admits. We ship no such
product; if we ever do, this rule must be revisited.)

## Decision 3 — Identity resolution for `TRANSFER` is per-id, not a chain

`resolveCouple` walks ONE customer's alias chain and hard-stops at the first
existing `users/{uid}` doc — correct there, because later entries are *older*
aliases of the same person. `TRANSFER` has no chain: RC documents the arrays
only as "App User ID(s)" and **never commits** to whether an array is one
customer's alias set or several distinct customers. So each element is resolved
**independently**, three-valued:

```
unknown  — no users/{id} doc            → an identifier we cannot place
unpaired — users/{id} exists, no coupleId
couple   — users/{id}.coupleId = C      → lane key = id, mirror = subscriptions/C
```

**The two sides treat an RC anonymous id (`$RCAnonymousID:…`) differently, and
the asymmetry is deliberate:**

- On the **`from`** side an anon id is **filtered out**: it is never a Firebase
  uid, so it can be neither a lane key nor evidence of a couple. Dropping it
  costs nothing.
- On the **`to`** side an anon id is **an unplaceable destination ⇒ hold**. It
  may be *the loser themselves* mid-reinstall. Filtering it away and then
  declaring the remaining destination "fully known" would revoke on
  `to = [$RCAnonymousID:…, uidB]` — contradicting Decision 2's standing rule
  ("revoke iff the destination is **FULLY KNOWN**") and landing on the
  false-downgrade side, which is the one thing this design refuses to do. The
  ADR does **not** get to assume an anon element is merely an alias of a listed
  known id: Decision 3's founding premise is that RC never commits to what the
  arrays contain, and that premise must cut both ways.

**Pipeline (the cap is a PRE-READ gate — this is what actually bounds the read
fan-out; every step below happens before any Firestore read):**

0. `transferred_from`/`transferred_to` absent or not arrays → `unprojectable`
   (200 counted skip — per-type schema drift, never a 400).
1. Dedupe both arrays.
2. `to` empty, **or containing any anon id** → `hold('ambiguous-destination')`.
3. `from` ← deduped `from` minus anon ids.
4. Either surviving array longer than **`MAX_TRANSFER_IDS = 10`** →
   `hold('oversized')`, **zero reads**.
5. `from` empty → `hold('no-loser')`, zero reads.

Anon-filtering and deduping are pure in-memory operations, so running them
*before* the cap is free — and it matters: capping the **raw** array would hold
on routine anonymous-alias accretion (this app mints a fresh RC anonymous id on
every sign-out, via `PurchasesIdentitySync`'s `logOut`), making the revoke path
inert for exactly the identity-churning accounts that generate transfers. This
ordering bounds reads at **≤20** without that cost.

Only then are the surviving ids resolved (one `users/{id}` read each,
independently), and the planner is a **pure function** of the two resolved
lists:

```ts
type TransferPlan =
  | { kind: 'revoke'; targets: Array<{ coupleId: string; uid: string }> }   // ≥1
  | { kind: 'hold'; reason: 'internal' | 'ambiguous-destination' | 'no-loser' | 'oversized' };
```

1. Any `to`-id `unknown` → `hold('ambiguous-destination')`.
2. `toCoupleIds` = the coupleIds among the `to` results (may be empty — an
   all-`unpaired` destination is *known*, just couple-less).
3. `targets` = every `from`-id resolving to a couple **not in `toCoupleIds`**.
4. No `from`-id resolved to a couple → `hold('no-loser')`; every loser's couple
   is in `toCoupleIds` → `hold('internal')`.
5. Else `revoke(targets)`.

**Named cost of the `to`-side anon rule:** if RC populates `transferred_to`
with the destination's *anonymous* original id (plausible — see Open question
1), then **every** transfer holds and the revoke path is inert in production.
That is the "safe but inert" outcome, and it is the correct place to sit until a
real payload settles Open question 1. We do not trade a possible false
downgrade of a paying couple for a revoke path we cannot yet prove fires
correctly.

### The case table

X = loser's couple, Y = gainer's couple. "untouched" = zero writes; the doc is
not even created.

| # | Case | Plan | Effect | Why |
|---|---|---|---|---|
| (a) | **Within one couple** — the shared-Apple-ID restore: A buys, B restores on the same device | `hold('internal')` | X byte-unchanged | The couple's entitlement did not move — only *which RC subscriber holds it*. The mirror is **couple-scoped, not subscriber-scoped**: which lane carries the fact is bookkeeping, and the summary is `OR` over lanes. Revoking A's lane while being unable (Fact 2) to project B's would **downgrade a paying couple instantly**. |
| (b) | **Cross-couple** — A re-paired / signed into a new account, restores on the same Apple ID | `revoke([{X, uidA}])` | X: tombstone → summary re-derived. **Y untouched, not created** | The only case with positive evidence the entitlement left the couple (`transferred_from` = "entitlements are *taken from*"), and it is the sole notification. Y gains nothing (Decision 1). |
| (b′) | (b) where X has a **second entitled lane** (both partners bought) | `revoke([{X, uidA}])` | X stays entitled off the sibling lane | Lane isolation — exactly what lanes exist for. |
| (c) | **Loser resolves, destination unplaceable** — a `to`-id with no user doc, **or any anon id anywhere in `to`**, or an empty `to` | `hold('ambiguous-destination')` | nothing | **The false-downgrade trap.** The reinstall flow (app deleted → RC mints `$RCAnonymousID:…` → store auto-restores → *then* `Purchases.logIn(uid)`) can plausibly emit a transfer whose destination is **the same human's anonymous id**. Revoking there strips premium from a paying couple on a reinstall. RC's restore-behavior page says anonymous ids are *aliased* rather than transferred — but it never mentions the TRANSFER webhook at all, so we take the conservative reading. |
| (c′) | Loser → X; destination is a **known-but-unpaired** user | `revoke([{X, uidL}])` | X tombstoned | The destination *is* known (a real Hayati user in no couple). No ambiguity, and the entitlement demonstrably left X. |
| (d) | **Gainer resolves, loser does not** | `hold('no-loser')` | nothing | Nothing to revoke and nothing honest to grant (Decision 1). |
| (e) | Neither resolves | `hold('no-loser')` | nothing | Loud counted skip, 200. |
| (f) | **Multiple / anonymous ids** | per the pipeline above | anon **filtered from `from`**, anon **in `to` ⇒ hold**; ids deduped; each surviving array capped at 10 (pre-read); multiple resolving `from`-ids ⇒ multiple targets, possibly on different couple docs | Under **both** readings of the array (one customer's alias set *or* several customers) every listed `from` id lost the entitlement, so revoking all resolving from-ids is correct either way. The `to` side is used ONLY to answer "did it stay in the couple?" and to detect ambiguity — it is never written. |

## Decision 4 — The tombstone is a pure projection of the event alone

```ts
export function revokedLane(event: RcEvent): LaneProjection {
  return {
    entitled: false,
    productId: null,
    periodType: null,
    expiresAtMs: event.eventTimestampMs,  // entitled UNTIL the transfer instant:
                                          // honest, non-null, never the non-expiring sentinel
    willRenew: false,                     // renewals belong to the gainer now
    store: event.store,                   // "Sometimes" present → may be null
    environment: event.environment,
    entitlementIds: null,
  };
}
```

Two properties are load-bearing and each is mutation-tested:

- **It must not copy the loser's previous lane facts.** The most tempting
  mistake, and it is fatal: a lane value derived from *another lane value*
  stops being a pure projection of the total-order-maximal event, and the
  mirror stops converging under reordering. This is also why we reject the
  intuitive "**move** the lane" design — in-order `[PURCHASE, TRANSFER]` would
  hand the gainer the purchase's facts, while the reordered `[TRANSFER,
  PURCHASE]` would find nothing to move and then stale-skip the purchase:
  **two arrangements of one event multiset, two different mirrors**, one of
  which silently drops a paying couple to free. Pure-from-the-event, or
  nothing.
- **It must write a tombstone even when the loser has no lane yet** (creating
  `subscriptions/{X}` if absent — an `entitled: false` doc reads as the free
  tier). Otherwise a late-arriving `INITIAL_PURCHASE` (older `ts`) resurrects
  an entitlement the transfer already moved away.

`revokeLane(lanes, uid, event, updatedAtMs)` is `applyLane`'s twin: same
`decide()` guard against that lane's own `(lastEventTimestampMs, lastEventId)`
key, same same-reference-on-skip contract. So the convergence invariant of
ADR-013 Decision 4 survives intact — **every lane remains a last-writer-wins
register over the total order `(event_timestamp_ms, event.id)`**, with
`TRANSFER` simply contributing a second projection (`revokedLane`) and a
resolution-derived *target set*.

## Decision 5 — One transaction per target couple doc, sequentially

A transfer touches ≤ N lanes across ≤ N *different* `subscriptions/{coupleId}`
docs (N = resolving from-ids; 1 in practice). We keep the existing single-doc
transaction primitive and run **one transaction per target couple**, rather
than a cross-document transaction:

- The couple doc is the aggregate boundary — no invariant spans two couples, so
  cross-couple atomicity buys nothing while enlarging the read set.
- **Partial application is already safe by idempotence**: every write is guarded
  by that lane's own key with the same `event.id`. If the Function dies between
  couple X and couple Z, the shell 500s, RC retries, X **replay-skips** (equal
  key) and Z applies. Idempotence — not atomicity — is what makes this correct,
  and the lane model already has it.
- Identity reads (`users/{id}`) stay outside the transactions, as they are
  today.

Hazards, and how the model answers each:

| Hazard | Outcome |
|---|---|
| Duplicate delivery (RC guarantees at-least-once) | `replay-skip` on every target lane; zero writes |
| A stale `TRANSFER` replayed **after** a newer `RENEWAL` on the loser's lane | `stale-skip` — the lane stays entitled, no re-revocation |
| A `TRANSFER` arriving **before** the purchase it moves | tombstone written at the transfer's key; the late (older-`ts`) purchase **stale-skips** — the loser never becomes entitled. *This is what the tombstone-when-no-lane-exists rule buys.* |
| Hostile/oversized arrays | `hold('oversized')` at the pre-read gate — **zero** reads (an accepted transfer costs ≤20) |

New typed outcomes (the shell maps `transfer-revoked` → 200 `processed`,
`transfer-hold` → 200 `skipped`):

```ts
| { decision: 'transfer-revoked'; targets: Array<{ coupleId: string; uid: string }> }
| { decision: 'transfer-hold'; reason: 'internal' | 'ambiguous-destination' | 'no-loser' | 'oversized' }
```

**PII:** `logProjection` stays the only log surface, **with no shape change** —
`LogFields` remains exactly `{type, id, environment, decision, coupleId?}`. A
revoke emits **one `logProjection(event, 'transfer-revoked', coupleId)` line per
target**, which needs no new field; a hold emits one line whose `decision`
carries the reason (`transfer-hold:internal`, …). `transferred_from` /
`transferred_to` contents are user identifiers and are **never logged** — not
as a list, not as a count that could be joined against one. RC also ships
`subscriber_attributes` on transfers ("for the destination subscriber"), which
the ADR-013 rule that the raw body is never logged already contains.

**Envelope contract (the Finding-0 fix):** the identity contract becomes
**per-type**, because RC's own field tables are per-type — `app_user_id` stays
**required and non-empty for every type except `TRANSFER`** (a lifecycle event
without it is still a 400). A `TRANSFER` whose `transferred_*` fields are
absent or not arrays is **`unprojectable` → 200 counted skip**, not a 400: it
authenticated as RC and its envelope *is* an RC envelope, so it is per-type
schema drift — never mutate on doubt, never burn the retry budget on a
deterministic parse failure (the ADR-013 philosophy, unchanged).

## Decision 6 — "Gift your partner" is not a payments feature. It is the entitlement model, and it already shipped.

**Gifting an auto-renewable subscription is not an App Store feature in 2026.**
There is no StoreKit gifting API and no App Store Connect "giftable" toggle for
subscriptions; Apple's consumer gifting covers apps and media, and for
subscriptions Apple's own prescribed path is a gift-card balance top-up so that
**the recipient buys it themselves**. (The 2018 "Apple allows gifting IAPs"
change was a *guideline* permission to build your own mechanics — it shipped
zero platform plumbing.)

And App Store Review Guideline **3.1.1** settles the model we already have,
verbatim:

> "Apps may enable gifting of items that are eligible for in-app purchase to
> others. Such gifts may only be refunded to the original purchaser and may not
> be exchanged."

> "Apps may not use their own mechanisms to unlock content or functionality,
> such as license keys, augmented reality markers, QR codes, cryptocurrencies…"

**"A pays via IAP, B gets premium" is permitted by name.** The single binding
rule is that the money moves through IAP — which it does. Our couple-scoped
mirror is not a loophole; it is the sanctioned shape.

> **Therefore: PRD F4's "gift-your-partner purchase flow" is re-scoped from
> plumbing to framing. One IAP → `subscriptions/{coupleId}` → both partners
> premium (ADR-013 Decision 4, the M4.1 accept line) IS the gift, and the
> paywall already says so in three places** (`paywallPitch` — "One
> subscription. Premium for both of you."; `paywallProcessing` — "unlocking for
> both of you…"; `paywallEntitledBody` — "Premium is active for both of you.").
> **No new gift UI ships.** A "Gift Premium" button would imply a gift SKU that
> cannot exist, and any "gift someone" entry point is precisely the thing that
> would need a paywall without a `coupleId` — reopening the purchase-before-
> pairing gap ADR-014 structurally closed.

What ships instead of UI: this decision, the PRD F4 rewrite, and an app-side
regression test that **pins the promise** — the non-purchasing partner's app
flips to premium off their partner's purchase, through the real mirror, without
ever touching the paywall.

**Rejected mechanisms, each recorded so it is never re-litigated:**

| Mechanism | Verdict |
|---|---|
| **Apple Family Sharing** | **DO NOT ENABLE.** Requires both partners in the *same Apple Family group* (shared organizer + payment method) — a heavy ask a large fraction of couples fail; and it creates a **second entitlement source our mirror does not own**. Decisively: the App Store Connect toggle is **irreversible** ("once you turn on Family Sharing for an In-App Purchase, you can't turn it off"). A one-way door, recorded **before** the ASC records exist — operator item 0 must create the products with Family Sharing **OFF**. |
| **Offer codes as gift certificates** | **NOT NOW.** Developer-minted only (a user can never generate one); batches ≥500, ≤6-month expiry ⇒ a code-inventory service. Worse: an offer code on an *auto-renewable* subscription **auto-bills the recipient's Apple Account at full price** after the offer period — a "gift" that silently starts charging your partner. If ever needed, the correct instrument is a **non-renewing subscription** SKU. |
| **RevenueCat promotional entitlements** | **Not a product spine.** No receipt, no renewal, excluded from revenue metrics; it is a support/comp tool (and needs an RC secret key we do not have). |
| **Web / Stripe gift link** | **No.** Adds a payment stack, and 3.1.1 forbids the in-app CTA outside the US storefront. Solves a problem we do not have. |
| **Apple Group Purchases** (WWDC26, "this winter") | **Track, don't build.** A 2-seat group *is* a couple, and it is the sanctioned buyer≠beneficiary road — but it has **no RevenueCat support yet**. Revisit at RC GA; this is the only development that would reopen this decision. |

**The one gap the couple model does not close:** a *third-party* giver (a friend
or parent buying premium for the couple). Out of scope for M4; if it ever
becomes a requirement, offer codes on a **non-renewing subscription** are the
tool.

**Named follow-up (not built here, deliberately):** the "gift" has an emotional
moment we currently drop — the non-purchasing partner just silently stops
seeing a lock. Attributing it ("*Aytek unlocked Premium for you both*") needs
one new server field (`entitledByUid`, the already-selected winning lane's uid)
and a line of copy. It is a *product* idea, not a payments one, so per the
scope guard it goes to the issue tracker rather than into this diff
(`gh issue` — F4 follow-up), and it is named here so it is not lost.

## Consequences

- **A real `TRANSFER` stops being a 400.** The envelope contract is per-type, so
  RC's actual transfer body parses, and the webhook answers 200 on every path.
- The convergence invariant of ADR-013 Decision 4 is **preserved, not weakened**:
  lanes remain per-uid LWW registers over `(event_timestamp_ms, event.id)`; the
  property test is extended to a **two-couple world** with transfers in the
  generated event multiset, asserting that any permutation (with duplicates)
  lands on identical lanes *and* identical summaries on both couples.
- **Accepted costs, all named, none silent:**
  1. **A `TRANSFER` never entitles anyone** (Decision 1) — a receiving couple
     waits for its next lifecycle event.
  2. **Every ambiguity holds** (Decision 2) — an entitlement that genuinely left
     to a stranger keeps the ex-couple premium for the tail of the paid period.
  3. **Within-couple transfers leave stale lane attribution** (case (a)) — and if
     a refund/early expiry then lands on the *gainer's* new lane, the loser's
     stale entitled lane keeps granting premium until its old `expiresAtMs`.
  4. All three are closed by the same thing: **RC-REST reconciliation**, which
     needs an RC secret key and therefore rides operator item 0 + the deploy era
     (already parked in ADR-013; re-affirmed here, not dropped).
- The gift decision **removes** a planned feature from M4 rather than adding one,
  and records an irreversible App Store Connect setting (Family Sharing OFF)
  that the founder must honor when creating the products.

## Open questions for the live-sandbox session (only answerable with a real RC account)

1. **What identifiers actually populate `transferred_from` / `transferred_to`?**
   Firebase uids? `original_app_user_id` (often the first-launch anonymous id)?
   The full alias set? **This decides whether the revoke path ever fires in
   production at all** — if RC sends only an anonymous original id, every
   transfer holds (safe, but inert). Capture a real payload from the RC
   dashboard's webhook log during a sandbox restore.
2. Is the array cardinality ever > 1, and under what flow?
3. Confirm the project's transfer behavior is the default ("Transfer to new App
   User ID"), and that it is what fires the `TRANSFER` webhook (the
   restore-behavior docs never mention the webhook).
4. Does the loser really receive **no** follow-up `EXPIRATION`? (Staff-stated,
   doc-silent. Our design depends on neither answer — but it sizes the leak.)
5. **The reinstall sequence** (delete app → anonymous id → auto-restore →
   `logIn(uid)`): does it emit a `TRANSFER` to an *anonymous* destination — the
   case case-(c)'s hold exists to survive? Highest-value observation of the
   sandbox session.
6. Are `store` / `environment` really present on real transfers (the field table
   says *Sometimes*)?
7. Does a sandbox / StoreKit-configuration restore emit a `TRANSFER` at all?
8. **RC-REST reconciliation feasibility** — confirm `GET /v1/subscribers/{id}`
   returns entitlement + expiry for a gainer, and that a secret key can live as
   a Function secret. This is the fix for accepted costs 1–3.
9. **Gift:** confirm the IAP products are created with **Family Sharing OFF**
   (irreversible). Re-check Apple **Group Purchases** + RC support at GA.
