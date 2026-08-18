# ADR-057: the funnel has two emitters, and one of them is not the app

- **Status:** Accepted
- **Date:** 2026-08-18 (Session 081)
- **Deciders:** session agent (the instrumentation is autonomous; the vendor token is an operator dependency, and this ADR is built so it does not block)
- **Related:** **ADR-016** (the binding `logCoachEvent` shape), **ADR-013** (the RevenueCat webhook is the entitlement truth), **ADR-025 D8** (declaration is not enforcement), `docs/architecture.md` §7 (the event list) and §8 (*"excluded from analytics payloads"*), issue **#239**, issue **#226** (the privacy policy's collection list is already wrong)

> Written and committed **before** the implementation, and reviewed **twice** —
> `session-context.md` §5 items 1 and 3.

## Context — measured, not inferred from the issue

`app/lib/core/analytics/` **exists and contains one file: an empty `.gitkeep`**,
created 2026-07-11. Nothing in the app emits an event. So Gates 2 and 3 are not
under-measured; they are **unmeasurable**, and have been since the folder was
reserved.

The contract, though, is not undefined — it has been written the whole time:

* **`architecture.md` §7** enumerates the funnel:
  `install → signup → invite_sent → paired → q_answered{solo|mutual} →
  reveal_viewed → streak_day → trial_start → paid → churn`, plus
  `share_card_created`, `coach_msg`, and locale/register/storefront dimensions on
  every event.
* **`architecture.md` §8** binds the payloads: relationship content is
  *"**excluded from analytics payloads** (event names carry no answer text,
  ever)"*.
* **ADR-016** binds one event's shape, and it is the one most easily got wrong.

## Decision 1 — The funnel splits across TWO emitters, because three events are not the app's to observe

`architecture.md` §7 lists twelve events as one stream. Three of them —
**`trial_start`, `paid`, `churn`** — are not client events, and treating them as
such would be a lie about when they happened.

Entitlement truth arrives at `functions/src/entitlements/revenuecat-webhook.ts`
(ADR-013: *"RC signs nothing — the verbatim `Authorization` string is the entire
anti-forgery boundary"*). The **app learns about entitlement from a mirror**,
asynchronously and possibly much later; a client `paid` event would timestamp the
moment the phone noticed, not the moment money moved, and would be **missing
entirely** for a user who never reopens the app after purchasing.

So:

| emitter | events |
|---|---|
| **client** | `install`, `signup`, `invite_sent`, `paired`, `q_answered{solo,mutual}`, `reveal_viewed`, `streak_day`, `share_card_created`, `coach_msg` |
| **server** (RC webhook) | `trial_start`, `paid`, `churn` |

**This slice implements the client half only**, and the sentinel of Decision 4
names the server three as deliberately absent rather than letting them read as
forgotten.

## Decision 2 — A port, with a real sink, because a port with only a no-op is dead configuration

The app already has this exact idiom one folder over: `crash_reporter.dart` is a
port, with `noop_crash_reporter.dart` and `crashlytics_crash_reporter.dart`
behind it. Analytics takes the same shape.

**And it ships with a sink that actually runs.** ADR-025 D8's rule — a
declaration nothing enforces reads as coverage — applies here directly: a port
whose only implementation is a no-op is instrumentation that cannot be observed
failing. The debug sink writes through the existing observability layer, so in
dev the events are visible, orderable and assertable **today**, without a vendor
SDK and without the operator's token.

**No vendor dependency is added in this slice.** Mixpanel needs a project token
the founder must supply, and Firebase Analytics would be a new package; both
belong behind the port, and neither is a reason to delay the seam. **What this
buys is instrumentability, not measurement** — and that distinction is stated
here rather than left for someone to discover when they look for a funnel.

## Decision 3 — The event type carries dimensions; it cannot carry content

A single sealed event type with the §7 dimensions (locale, register, storefront)
attached centrally rather than at each call site — because a dimension that each
emitter must remember is a dimension that will be missing from exactly the event
someone needs.

**Content is structurally excluded, not carefully omitted.** §8 promises event
names carry no answer text *ever*, and a promise kept by author discipline is one
that breaks the first time someone adds a helpful field. The payload type admits
only primitives from a closed set of keys; there is no free-form map for a caller
to put a reflection into.

## Decision 4 — `coach_msg` mirrors `logCoachEvent`, crisis-stripping included

ADR-016 is binding and specific: the emitter *"MUST take the `logCoachEvent`
typed-fields shape — no message-text field exists on the type, no uid, and crisis
outcomes are never joined to `coupleId`"*.

The server builder (`functions/src/coach/coach-core.ts`) enforces this by
**dropping** `coupleId`, `personaId`, both caps and `errorCode` whenever the
outcome is in `CRISIS_OUTCOMES`. The client emitter reproduces that rule, and
**the test asserts the stripping in both directions** — a crisis outcome carries
none of those fields, and a non-crisis outcome still carries them. Asserting only
the first is satisfied by an emitter that sends nothing at all.

## Decision 5 — The sentinel asserts the LIST, not the emitters

*"Each screen emits an event"* is satisfied by twelve hand-written call sites that
drift apart, which is ADR-052's lesson in another costume. So the test is a
**source sentinel** over `architecture.md` §7: every event named there is either
implemented by the client emitter or explicitly listed as server-side.

The point is that **adding a thirteenth event to the architecture doc turns the
suite red**, so the doc and the code cannot silently disagree — the failure this
repo keeps finding, one layer up.

## Consequences

**What this buys.** The funnel becomes emittable, with content structurally
excluded and the crisis rule enforced rather than remembered.

**What it does not buy, stated plainly.** **A measurable funnel.** Nothing here
ships events to a tool anyone can build a Gate 2/3 funnel in. That needs a vendor
adapter and the founder's token, and the honest status after this slice is
*"instrumented, not yet measured"*.

**⚠️ This slice widens what the product collects, and the privacy policy is
already wrong about collection.** #226 records that the policy's *"what we
collect"* list is inaccurate about push and is founder/lawyer-blocked because any
revision re-prompts every user for consent. **Analytics events are collection.**
This ADR does not touch the legal texts and does not ship a vendor sink, so it
adds no new third-party processor — but the moment an adapter sends events off
the device, `docs/legal/` and `docs/dpa-inventory.md`'s processor register both
need a row, and that is a founder decision, not a follow-up commit. Recorded here
so the next session cannot land the adapter believing the paperwork is done.
