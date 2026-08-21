# ADR-060: the three money events are emitted where the decision is made, not where the state lands

- **Status:** Accepted — **revision 3** (2026-08-21, after the built-diff review)
- **Date:** 2026-08-21 (Session 084)
- **Deciders:** session agent (the *port decision* is autonomous and #242 says so; the vendor sink is an operator dependency and nothing here builds one)
- **Related:** **ADR-057 D1/D2** (the three-way funnel partition; the port whose default is silence), **ADR-013** (the RevenueCat webhook is the entitlement truth; the bearer-token boundary), **ADR-019** (the deletion cascade), **ADR-014/015**, `docs/architecture.md` §7, issues **#242** (this one), **#243** (the join key), **#226** / **#247** (nothing may leave a device until the legal revision lands), **#115** (the webhook is not invocable in prod)

> **Review status.** Revision 1 was written and committed **before** anything
> else (`session-context.md` §5 item 1, lesson 111). **The design pass has now
> run** — 4 lenses × 2 independent verifiers + a completeness critic, **25 agents,
> 0 errored, 0 empty results**, 14 findings, 6 surfaced + 4 critic, **4 dropped
> unverified and listed at the end**. **Revision 2 is what it produced**, and one
> of its blockers made revision 1's central classification unimplementable at the
> seam revision 1 chose for it.
>
> **The built-diff pass has now run too** — 3 lenses × 2 verifiers + a critic,
> **20 agents, 0 errored, 0 empty results**, 11 findings, 2 surfaced + 4 critic,
> 3 dropped unverified. **Revision 3 is what it produced.**

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

A trigger has only the *mirror*. Revision 1 said the event type *"cannot be
recovered"* from it, and the review was right that this is too strong: a
before/after diff **does** separate some transitions — `CANCELLATION` sets
`willRenew: false` where `UNCANCELLATION` sets it true, so those two are
distinguishable. **The accurate statement is narrower and still sufficient:** a
diff recovers the transitions that changed a *stored field*, and the
classification below needs one that often does not — a trial converting to paid
is a `RENEWAL` that moves `periodType` and nothing else, and is indistinguishable
from a paid renewal that also re-writes `expiresAtMs` unless the previous
`periodType` is compared. Which is precisely the state Decision 1 has to go and
fetch anyway (below), and the trigger would have to fetch it from the same
place.

## Decision 1 — The emitter hangs off the `applied` outcome in `entitlement-service.ts`

Not the HTTP handler, and not a trigger. The `applied` branch is the **single
point at which this system decides that a real billing fact changed the world**.

⚠️ **The emit happens AFTER `db.runTransaction` returns, beside `logOutcome` —
never inside the callback.** Firestore **retries a transaction callback on
contention**, so an emit inside it fires once per attempt. Revision 1 said the
outcome is returned *"from inside `db.runTransaction`"*, which is true of where
the value is constructed and dangerously wrong as a description of where the
side effect belongs. `logOutcome(event, outcome)` already sits in the right
place and is the precedent to copy.

⚠️ **`ProcessOutcome`'s `applied` variant must GROW, and Decision 2 does not work
until it does.** It carries `summary` — the **new** state — and the previous
lane state never leaves the transaction callback. See Decision 2.

Everything #242's acceptance list asks then falls out of the taxonomy rather than
needing new machinery:

| question | answer, and where it comes from |
|---|---|
| **What fires on a replay?** | **Nothing.** `replay-skip` is a distinct outcome; the emitter never sees it |
| **What fires on an out-of-order delivery?** | **Nothing.** `stale-skip`, likewise |
| **Can an event be emitted twice?** | No — **provided the emit is outside the transaction**, on the returned outcome. See the warning above; inside the callback it fires once per retry |
| **What fires on a TEST event, or an RC type we do not know?** | **Nothing.** `noop-type` — the `PROJECTING_WILL_RENEW` membership test |
| **What fires on account deletion?** | **Nothing**, by construction: deletion does not produce an RC event |
| **What fires on a TRANSFER?** | **Nothing** — see Decision 2 |
| **What fires on a SANDBOX purchase?** | **Nothing** — see Decision 2a |

## Decision 2 — The three events are classified from the RC type and `periodType`, and `CANCELLATION` is NOT churn

| event | condition |
|---|---|
| `trial_start` | an `applied` `INITIAL_PURCHASE` whose `periodType` is the **trial** value |
| `paid` | an `applied` event that leaves the lane entitled on a **known non-trial** `periodType`, **where the previous lane state was absent, unentitled, or in trial** |
| `churn` | an `applied` **`EXPIRATION`** where the **PREVIOUS** lane state was entitled on a known non-trial period |

### ⚠️ The `paid` rule needs the PREVIOUS state, and the outcome does not carry it

This is the blocker the design pass found, and it is a defect in revision 1
rather than a subtlety: `paid` is defined over a **transition**, and Decision 1
put the emitter somewhere that can only see the destination.

`processRevenueCatEvent` reads `lanes` (previous) inside the transaction,
computes `nextLanes`, and returns `summary = deriveSummary(nextLanes)` — the new
state alone. **The previous state never leaves the callback.** And the RC event
cannot stand in for it: a trial converting to paid arrives as a `RENEWAL` with
`periodType: NORMAL`, which is *the same event shape* as an ordinary paid
renewal. Without the previous `periodType` the two are indistinguishable, and
`paid` would fire on **every renewal for the life of the subscription** — turning
Gate 3's *"trial→paid ≥30%"* into a number that grows without bound.

**So the implementation must extend `ProcessOutcome`'s `applied` variant** with
the minimum the classification needs — the previous lane's `entitled` and
`periodType`, or a `previousSummary` — computed inside the transaction and
returned with the outcome. That is a real code change, it is small, and naming
it here is the difference between the eventual implementation being transcription
and being a redesign at the worst moment.

Revision 1's Decision 5 claimed *"the classification table is written so the
eventual implementation is transcription rather than re-derivation."* **That was
false for `paid`**, and it is corrected rather than softened.

### ⚠️ A trial that lapses is NOT churn

Revision 1's churn rule fired on any `applied` `EXPIRATION`, with no `periodType`
guard, while both other rules had one. So a **free trial that ended without
converting** would have been counted as a churned customer.

That conflates two different things and corrupts the pair of numbers Gate 3 is
made of: a failed trial conversion is *already* measured as the absence of a
`paid` after a `trial_start`, and counting it again as `churn` both inflates
churn and double-penalises the same user. **Churn is the loss of someone who was
paying.** A trial lapse is not in §7's twelve events at all, and this ADR does
not add a thirteenth for it — it is recorded here so a later reader knows the gap
is deliberate.

**The guard reads the PREVIOUS state, not the event's `periodType`, and that is
deliberate.** Revision 2 wrote it as *"an `EXPIRATION` whose `periodType` is a
known non-trial value"*, which makes churn depend on RevenueCat sending
`period_type` on an expiry — a **vendor shape this repo has not verified**, and
whose absence would make churn silently unmeasurable rather than merely wrong.
The standing rule here is that **only the vendor can refute a vendor API shape**,
and no session can ask one. Keying off the previous lane state removes the
dependency altogether, and that state is in hand anyway because blocker 1 already
forced the outcome to carry it — one field fixing two rules.

⚠️ **`CANCELLATION` must not emit `churn`,** and it is the mistake this table
exists to prevent. RC's `CANCELLATION` means *auto-renew was switched off*; the
subscriber **stays entitled until expiry**, which is why
`PROJECTING_WILL_RENEW.CANCELLATION` is `false` while
`projectEvent` still sets `entitled: true`. Emitting churn there would report
churn **early**, and then again at `EXPIRATION` — a metric that both leads
reality and double-counts. *(Whether a "cancelled but still entitled" signal is
worth its own event is a product question, not this one; it is not in §7's
twelve and this ADR does not add a thirteenth — see the consequences.)*

### ⚠️ TRANSFER revokes entitlement too, and emits nothing

Revision 1 quoted `entitlement-core.ts` calling `EXPIRATION` *"the ONLY revoking
event"*. That comment is **true inside `PROJECTING_WILL_RENEW`** and false of the
system: `processTransferEvent` calls `revokeLane`, which sets `entitled: false`,
and returns `transfer-revoked`. A couple can lose entitlement without any
`EXPIRATION`.

**It emits nothing, deliberately.** A transfer moves a subscription *between
accounts*; nobody stopped paying, and the receiving side is not a new purchase.
Emitting `churn` on the losing side would report a customer loss that did not
happen, and pairing it with a `paid` on the receiving side would invent a
conversion. `transfer-hold` likewise. **The reason this is spelled out is that
the naive reading of the comment — *"churn = entitled went false"* — walks
straight into it**, which is the same shape as Measurement 2 one path over.

## Decision 2a — PRODUCTION only; sandbox purchases emit nothing

The RC event carries `environment`, and nothing in revision 1 looked at it. Every
TestFlight purchase, every founder test, and every sandbox run of the paywall
would otherwise land in the funnel that Gate 3 reads — and this project has been
buying test subscriptions in sandbox since M4.2.

**The emitter fires only for `PRODUCTION`.** Sandbox events are dropped — and
**the mechanism that makes that observable already exists**, which revision 2
promised without ever saying: `logOutcome` runs on every event and its
`logProjection` already carries `environment`. So a debugging session tells *"no
events at all"* from *"no production events"* by reading the log the webhook
already writes, and **the emitter adds no counter of its own**. Revision 2 said
sandbox events *"are counted"* — present tense, of code that does not exist, via
a mechanism it never named — and the built-diff review was right that this was a
promise with nothing behind it. Raised by the completeness critic; nobody else
looked at the environment field at all.

⚠️ **`periodType` is an OPEN vocabulary.** The type is `string | null`; our tests
have only ever seen `TRIAL` and `NORMAL`; RevenueCat also documents `INTRO` and
`PROMOTIONAL`. So the classification is written as **"trial" vs "not trial"**,
with anything unrecognised treated as **not a trial** and — critically — a
`periodType` we have never seen must not silently become a `paid`. The rule is:
`trial_start` requires a *positive* match on the trial value; `paid` requires a
positive match on a known non-trial value; anything else emits **nothing** and is
counted. A funnel that quietly invents `paid` events from a vocabulary change is
worse than one with a gap in it.

## Decision 3 — The emitter sits where both identifiers are in hand, and carries NEITHER

ADR-057 D3 says, of the funnel payloads: **"No payload carries a uid or a
`coupleId`, on any event, ever."** Its reasoning is not incidental — it is a
domestic-violence-aware product, and §8's own argument about coach *metadata*
applies to a funnel keyed to a couple just as well.

**The `applied` outcome carries `coupleId` AND `uid`.** This ADR places the
emitter at the one point in the entire system where both are already in scope,
and revision 1 said nothing about it. Two verifiers split on whether D3's *"any
event, ever"* is client-scoped (D7 back-references it as *"no uid, ever, on a
client event"*, and #243 describes it as forbidding them *"on any client
event"*) or literal. **That split is the point:** it is exactly the question
#243 exists to answer, and it is not this ADR's to close.

**So the conservative reading holds until #243 decides otherwise: the server
events carry neither identifier.** Concretely:

* If D3 is literal, this is simply obeying it.
* If D3 is client-scoped, then whether a server event may carry an identity is a
  **privacy decision that rides #226** — #243 says so in as many words — and a
  decision made silently, in an ADR about *which surface emits*, would be the
  worst possible place to make it.
* The cost is stated rather than hidden: **without a shared identity, Gate 3's
  `install→paid` remains uncomputable**, which is precisely what #243 is open
  about. This ADR does not make that worse, and it does not quietly make it
  better either.

An emitter written at this seam will have both values in a local variable. The
implementation must therefore make the payload type *unable* to hold them — the
ADR-057 D3 idiom, where the guarantee is the type signature rather than author
discipline.

## Decision 4 — The port is the same shape as the client's, and its default is silence

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

## Decision 5 — `storefront` is finally real, and only on these three

§7 asks for a `storefront` dimension on every event; ADR-057 D3 recorded that
the client can supply it on **none** — no storefront source exists in the app.
The RC event carries `store`, so these three events carry the dimension the
other nine cannot. That asymmetry is recorded rather than papered over: §7's
"dimensions on every event" is, and will remain, **partially met**, and the half
that is met is the half Gate 3 needs.

## Decision 6 — This ADR ships NO emitter

Only the decision, `architecture.md` §7's sentence updated to name the surface,
and this record. #242's own framing — *"there is no reason to build a server
emitter before there is somewhere for it to emit"* — is accepted.

**What that costs, stated plainly:** a decision recorded and not built is a
decision that can rot. The mitigation is that #242 stays **open**, **its body is
updated to point here by the session that merges this**, and the classification
table above is written so the eventual
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
  and neither is a lapsed trial. If a later session wants either, that is a §7
  change with a sentinel to satisfy, not a quiet addition here.
* **This ADR optimises for event-correctness over metric-usefulness**, and says
  so. A product person watching churn probably wants the *cancel* signal, not the
  expiry six weeks later; a `paid` that excludes renewals is a conversion count,
  not a revenue count. Those are legitimate wants and they are **different
  events**, not different definitions of these three. §7 owns the vocabulary.

## What the design pass changed (revision 1 → revision 2)

**25 agents, 0 errored, 0 empty results, 14 findings, 6 surfaced + 4 critic, 4
dropped unverified.**

| # | severity | what revision 1 got wrong |
|---|---|---|
| 1 | **blocker** | **`paid` is defined over a transition and the emitter could only see the destination.** The previous lane state never leaves the transaction callback, and the RC event cannot substitute — a trial conversion is a `RENEWAL` with `periodType: NORMAL`, identical in shape to an ordinary renewal. Uncorrected, `paid` would have fired on **every renewal for the life of every subscription**, and Gate 3's trial→paid would have grown without bound. `ProcessOutcome` must grow; Decision 2 now says so |
| 2 | **blocker** | **ADR-057 D3's *"no uid or `coupleId`, on any event, ever"* was unaddressed**, at the one seam in the system where both are in scope. Now Decision 3, resolved conservatively and explicitly handed to #243 rather than closed here |
| 3 | major | **A lapsed trial was counted as churn.** The churn rule had no `periodType` guard while both others did — so a failed conversion would have been counted twice against the same user, once as a missing `paid` and once as churn |
| 4 | major | **`TRANSFER` also revokes entitlement.** *"EXPIRATION is the ONLY revoking event"* is true inside `PROJECTING_WILL_RENEW` and false of the system — `revokeLane` sets `entitled: false` on `transfer-revoked`. It now emits nothing, with the reason written down, because the naive *"churn = entitled went false"* reading walks straight into it |
| 5 | major | **The trigger-indistinguishability claim was too strong.** `CANCELLATION` and `UNCANCELLATION` *are* separable by `willRenew`. Narrowed to the accurate version, which still holds for the transition the classification actually needs |
| 6 | major *(critic)* | **Sandbox purchases would have entered the funnel.** `environment` was on the event and nobody looked at it. Now Decision 2a — and this project has been buying sandbox subscriptions since M4.2 |
| 7 | minor | *"from inside `db.runTransaction`"* described the idempotency guarantee in a way that, followed literally, breaks it: Firestore retries the callback. The emit is now explicitly **after** the transaction, beside `logOutcome` |

**Dropped UNVERIFIED at the cap of 10 — listed because unverified is not
refuted** (`session-context.md` §5 item 6): *"INTRO and PROMOTIONAL periodTypes
are silently dropped"* (largely answered by the open-vocabulary rule, which
requires a positive match and emits nothing otherwise) · *"server event
dimensions are incompletely specified beyond storefront"* · *"the ADR optimises
for event-correctness over metric-usefulness and does not say so"* (acted on
anyway, in the consequence above) · *"#242's 'survives a webhook rewrite'
advantage is not addressed by the measurements"* — which is fair, and the honest
answer is that it **is** a real advantage of the trigger, just a much smaller one
than the two the measurements removed.

**Attacked and NOT changed:** that #115 undermines the choice (both verifiers:
the ADR argues option 2's *advertised advantage* is illusory, which holds
whatever #115's state) · that `EXPIRATION` is not the only revoking event *within
its table* (true as scoped; the system-wide case is finding 4) · that the
ADR-013 citation obscures the log-vs-emit distinction (operational logging and
analytics payloads are different rules) · that `summary.store` may differ from
`event.store` in a two-lane couple (the ADR sources the dimension from the
**event**, which is correct).

## What the built-diff pass changed (revision 2 → revision 3)

**20 agents, 0 errored, 0 empty results, 11 findings, 2 surfaced + 4 critic, 3
dropped unverified.** A smaller pass than the design one, and the right size: the
diff is documentation, so what it could find was contradiction rather than
behaviour.

| # | severity | what revision 2 got wrong |
|---|---|---|
| 1 | major | **The §7 addendum said the mirror's *"sole writer"* is the webhook — contradicting ADR-060's own Measurement 1 (*"exactly two writers"*) and, worse, `architecture.md`'s OWN §3, which already draws the distinction: *"the deleteAccount cascade is the second admin writer, but it only ever deletes the doc WHOLE — the webhook stays the sole CONTENT writer."* The file had the precise vocabulary and the addendum ignored it |
| 2 | major | **Decision 2a promised sandbox events *"are counted"* and named no mechanism.** Present tense, of code that does not exist. The honest version turns out to be better: `logOutcome` already carries `environment` on every event, so nothing new is needed and the emitter adds no counter |
| 3 | minor *(critic)* | *"its body now points here"* — present tense for an issue update this diff cannot perform. Now stated as an obligation on the merging session, and discharged there |
| 4 | minor | The §7 addendum bundled Decision 2a in with the *"four traps"*. It is a separate decision, not a trap |

**Changed without a finding, from the session's own reading:** the churn guard now
keys off the **previous lane state** rather than the event's `periodType`.
Revision 2's version made churn depend on RevenueCat sending `period_type` on an
expiry — an unverified vendor shape whose absence would make churn silently
unmeasurable. Both verifiers refuted the concern (the general "positive match or
nothing" rule covers it), and they were right that it is covered; it is still
better not to depend on the vendor shape at all when the previous state is
already in hand for `paid`.

**Attacked and NOT changed:** that the trial-to-`RENEWAL` claim is an unsourced
assumption (both verifiers refuted; it is RevenueCat's documented behaviour and
the linchpin of blocker 1) · that Decision 3 evades the identifier question (both
refuted: the ADR *does* decide — neither identifier — and hands only the
*relaxation* to #243) · that Decision 6 shipping nothing leaves the ADR
incomplete (both refuted) · that Decision 2a's observability needs the emitter to
exist (refuted, and finding 2 above is the better version of the same point).

**Dropped UNVERIFIED at the cap of 8** (`session-context.md` §5 item 6): *"the
churn guard may have introduced a symmetric undercount"* — which the
previous-state change above addresses incidentally · *"the addendum bundles
Decision 2a as one of the four traps"* — acted on anyway · *"the commit claims 60
analytics tests pass but cites Flutter tests a reviewer cannot run"* — true, and
the claim stands: `flutter test test/core/analytics/` is reproducible by anyone
with the toolchain, and CI runs it.

**Not fixed here:** ADR-060 is not in `docs/adr/README.md`'s index — and neither
are 049–059. That whole backlog is **#248**; adding one row would deepen the gap
rather than close it.
