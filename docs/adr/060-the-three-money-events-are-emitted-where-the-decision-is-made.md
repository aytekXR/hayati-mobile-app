# ADR-060: the three money events are emitted where the decision is made, not where the state lands

- **Status:** Accepted
- **Date:** 2026-08-21 (Session 084)
- **Deciders:** session agent (the *port decision* is autonomous and #242 says so; the vendor sink is an operator dependency and nothing here builds one)
- **Related:** **ADR-057 D1/D2** (the three-way funnel partition; the port whose default is silence), **ADR-013** (the RevenueCat webhook is the entitlement truth; the bearer-token boundary), **ADR-019** (the deletion cascade), **ADR-014/015**, `docs/architecture.md` §7, issues **#242** (this one), **#243** (the join key), **#226** / **#247** (nothing may leave a device until the legal revision lands), **#115** (the webhook is not invocable in prod)

> **Review status, stated prospectively.** Written and committed **before**
> anything else (`session-context.md` §5 item 1, lesson 111). Neither review pass
> has run at the time of this commit.

## Context

`architecture.md` §7 assigns three of the twelve funnel events — `trial_start`,
`paid`, `churn` — to a **server** emitter, and ADR-057 D1 explains why they are
not the app's to observe: the app learns entitlement from a mirror, so a client
`paid` would timestamp the moment the phone *noticed*, and would be missing
entirely for a user who never reopens the app after buying.

**These three are Gate 3.** *"Trial→paid ≥30%, install→paid ≥2%."* There is no
version of Gate 3 that does not need them.

#242 asks which of two surfaces emits them, and says — correctly — that the
decision can be made without a vendor. It presents the two options as a
genuine trade:

> (2) decouples emission from the bearer-token surface and survives a webhook
> rewrite; (1) is closer to the event and avoids a second read of the same fact.

**Two measurements collapse that trade**, and both were made this session.

### Measurement 1 — option 2 does not decouple from delivery, because the webhook is the mirror's only writer

`firestore.rules:296`:

```
allow write: if false; // subscriptions: function-only (revenueCatWebhook, admin SDK)
```

The document a trigger would watch has exactly two writers in the whole system:
`entitlement-service.ts` (the webhook path) and `deletion-service.ts` (which
deletes it). **If RevenueCat never delivers, the mirror never changes, and a
trigger on it emits nothing either.**

So option 2 buys independence from the webhook's *code*, not from its
*delivery* — and delivery is the risk #242 names. The one real advantage claimed
for the trigger is not an advantage it has.

### Measurement 2 — a trigger would emit `churn` when a user deletes their account

`deletion-service.ts:245`, inside the M6.2 cascade:

```ts
await deleteRef(db.collection('subscriptions').doc(coupleId));
```

A Firestore trigger on `subscriptions/{coupleId}` sees that delete. The obvious
derivation of churn from a before/after diff — *was entitled, is no longer* —
**fires on it.** That would be a false `churn` in the metric Gate 3 is partly
made of, and it would fire at the exact moment a person in a
domestic-violence-aware product deletes their account. An analytics event is the
last thing that should happen there.

It is avoidable — a trigger can special-case a delete — but it is a trap the
other option does not have, in a code path (ADR-019's cascade) that no future
author of an analytics emitter has any reason to be reading.

### What the webhook path already knows, and a trigger would have to re-derive

`entitlement-service.ts` returns a **decision taxonomy**:

```ts
| { decision: 'applied'; coupleId; uid; summary }
| { decision: 'replay-skip' } | { decision: 'stale-skip' }
| { decision: 'noop-type' }   | { decision: 'unprojectable' }
| { decision: 'unresolvable' } | { decision: 'transfer-revoked' } | ...
```

and it has the RC event itself: `type`, `periodType`, `store`, `environment`.
A trigger has the *mirror*, from which the event type cannot be recovered — a
`RENEWAL` and an `UNCANCELLATION` both leave `entitled: true`.

## Decision 1 — The emitter hangs off the `applied` outcome in `entitlement-service.ts`

Not the HTTP handler, and not a trigger. The `applied` branch is the **single
point at which this system decides that a real billing fact changed the world**,
and it is inside the transaction's result rather than beside it.

Everything #242's acceptance list asks then falls out of the taxonomy rather than
needing new machinery:

| question | answer, and where it comes from |
|---|---|
| **What fires on a replay?** | **Nothing.** `replay-skip` is a distinct outcome; the emitter never sees it |
| **What fires on an out-of-order delivery?** | **Nothing.** `stale-skip`, likewise |
| **Can an event be emitted twice?** | No: `applied` is returned once per accepted event, from inside `db.runTransaction` |
| **What fires on a TEST event, or an RC type we do not know?** | **Nothing.** `noop-type` — the `PROJECTING_WILL_RENEW` membership test |
| **What fires on account deletion?** | **Nothing**, by construction: deletion does not produce an RC event |

## Decision 2 — The three events are classified from the RC type and `periodType`, and `CANCELLATION` is NOT churn

| event | condition |
|---|---|
| `trial_start` | an `applied` `INITIAL_PURCHASE` whose `periodType` is the trial value |
| `paid` | an `applied` event that leaves the lane entitled on a **non-trial** `periodType`, where the previous lane state was absent, unentitled, or in trial |
| `churn` | an `applied` **`EXPIRATION`** — `entitlement-core.ts` documents it as *"the ONLY revoking event (entitled → false)"* |

⚠️ **`CANCELLATION` must not emit `churn`,** and it is the mistake this table
exists to prevent. RC's `CANCELLATION` means *auto-renew was switched off*; the
subscriber **stays entitled until expiry**, which is why
`PROJECTING_WILL_RENEW.CANCELLATION` is `false` while
`projectEvent` still sets `entitled: true`. Emitting churn there would report
churn **early**, and then again at `EXPIRATION` — a metric that both leads
reality and double-counts. *(Whether a "cancelled but still entitled" signal is
worth its own event is a product question, not this one; it is not in §7's
twelve and this ADR does not add a thirteenth — see the consequences.)*

⚠️ **`periodType` is an OPEN vocabulary.** The type is `string | null`; our tests
have only ever seen `TRIAL` and `NORMAL`; RevenueCat also documents `INTRO` and
`PROMOTIONAL`. So the classification is written as **"trial" vs "not trial"**,
with anything unrecognised treated as **not a trial** and — critically — a
`periodType` we have never seen must not silently become a `paid`. The rule is:
`trial_start` requires a *positive* match on the trial value; `paid` requires a
positive match on a known non-trial value; anything else emits **nothing** and is
counted. A funnel that quietly invents `paid` events from a vocabulary change is
worse than one with a gap in it.

## Decision 3 — The port is the same shape as the client's, and its default is silence

A `ServerAnalyticsSink` in `functions/src/`, mirroring ADR-057 D2: one method, a
typed event, **a no-op default**, and nothing wired in production. The reasons
are the same and one is new:

* **Nothing may leave a device or a server until the legal revision lands.**
  #226's draft is written and unapproved; #247 tracks that the gate is a
  paragraph, not a check. A server emitter that *emits* would walk straight
  through it.
* **A telemetry failure must never fail a webhook.** The webhook's contract with
  RevenueCat is an HTTP status; if analytics throws, RC retries a delivery that
  already applied. The emitter is wrapped and its failures are swallowed — the
  ADR-057 D2 rule, load-bearing here for a different reason.

## Decision 4 — `storefront` is finally real, and only on these three

§7 asks for a `storefront` dimension on every event; ADR-057 D3 recorded that
the client can supply it on **none** — no storefront source exists in the app.
The RC event carries `store`, so these three events carry the dimension the
other nine cannot. That asymmetry is recorded rather than papered over: §7's
"dimensions on every event" is, and will remain, **partially met**, and the half
that is met is the half Gate 3 needs.

## Decision 5 — This ADR ships NO emitter

Only the decision, `architecture.md` §7's sentence updated to name the surface,
and this record. #242's own framing — *"there is no reason to build a server
emitter before there is somewhere for it to emit"* — is accepted.

**What that costs, stated plainly:** a decision recorded and not built is a
decision that can rot. The mitigation is that #242 stays **open**, its body now
points here, and the classification table above is written so the eventual
implementation is transcription rather than re-derivation.

## Consequences

* **Gate 3 remains unmeasurable**, and this ADR does not change that. It removes
  the *design* question from the critical path, so the remaining blockers are the
  legal revision (#226), the join key (#243) and a vendor sink.
* **#243 is untouched and still binds.** `install→paid` is a cross-emitter join
  and the two halves still share no identity. This ADR decides *where* the server
  half comes from, not *how* it joins the client's.
* **A future author must not move this to a trigger** without re-reading
  Measurement 2. The account-deletion delete is the trap.
* **§7's first sentence is parsed by `funnel_event_sentinel_test.dart`** behind a
  ≥12-name floor. This ADR changes prose *after* that sentence only; the
  partition itself is unchanged, because the three events were already assigned
  to "the RevenueCat webhook" — what changes is that the surface is now *decided*
  rather than *assumed*.
* **No thirteenth event is added.** `CANCELLATION` is deliberately not given one,
  and if a later session wants "cancelled but still entitled", that is a §7
  change with a sentinel to satisfy, not a quiet addition here.
