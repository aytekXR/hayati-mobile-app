# ADR-057: the funnel has two emitters, one of them is not the app, and one event has nothing to emit from

- **Status:** Accepted — **revision 2** (2026-08-18, Session 081), after the design review
- **Date:** 2026-08-18 (Session 081)
- **Deciders:** session agent (the instrumentation is autonomous; the vendor token is an operator dependency, and this ADR is built so it does not block)
- **Related:** **ADR-016** (the binding `logCoachEvent` shape), **ADR-013** (the RevenueCat webhook is the entitlement truth), **ADR-017** (the client coach seam), **ADR-022 D5 / `BootTrace`** (instrumentation pays nothing in release), **ADR-025 D8** (declaration is not enforcement), **ADR-039 D1** (fail-open), **ADR-051 D1** (the reveal's one-shot fire point), `docs/architecture.md` §7 (the event list) and §8 (*"excluded from analytics payloads"*), `docs/mvp.md` item 11 + the OUT list + the Gate 2/3 thresholds, issue **#239**, its two filed remainders **#242** (the server emitter has no port) and **#243** (the two emitters share no identity), issue **#226** (the privacy policy's collection list is already wrong)

> **Review status, stated prospectively rather than claimed.** Written and
> committed **before** the implementation (`session-context.md` §5 item 1). The
> **design pass ran against revision 1** — 5 lenses × 2 independent verifiers,
> 29 agents, 0 errors, 20 findings, 11 surfaced. **Revision 2 is what that pass
> produced.** The built-diff pass (§5 item 3) has **not** run at the time of
> writing; `past-prompts.md` records what it found.
>
> *Revision 1 carried the sentence "reviewed **twice**" in the past tense, in a
> commit made before either review existed. That is the over-claim shape
> `past-prompts.md` has now recorded five times (the `62,408` figure, the
> miscited §5.1, "every clause is false", "a lock that cannot be installed
> frozen never reaches `main`"). It is corrected here rather than quietly
> deleted, because the correction is the point.*

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

And the funnel exists to answer two specific questions, which is what makes the
decisions below decidable rather than a matter of taste (`mvp.md`):

> Gate 2: **pairing ≥40% of signups ≤7d**; D7 couple retention ≥25%; crash-free ≥99.5%.
> Gate 3: **trial→paid ≥30%**; **install→paid ≥2%**.

## Decision 1 — The funnel splits THREE ways, not two

Revision 1 drew a client/server line. The design review found the line is real
but incomplete: one event's **feature does not exist and is not in the MVP**.

`architecture.md` §7 lists twelve event names. They partition as:

| emitter | events | count |
|---|---|---|
| **client** | `install`, `signup`, `invite_sent`, `paired`, `q_answered`, `reveal_viewed`, `streak_day`, `coach_msg` | 8 |
| **server** (RC webhook, **not built** — see below) | `trial_start`, `paid`, `churn` | 3 |
| **no feature to emit from** | `share_card_created` | 1 |

**8 + 3 + 1 = 12.** The sentinel of Decision 6 asserts that arithmetic against
the document, so the partition cannot silently stop being total.

**`q_answered{solo|mutual}` is ONE event name with a closed `mode` dimension**,
not two names. The brace is alternation over a dimension, and reading it as two
event names would put a value into a name — the thing Decision 3 exists to stop.

### Why `trial_start` / `paid` / `churn` are not the app's to observe

Entitlement truth arrives at `functions/src/entitlements/revenuecat-webhook.ts`
(ADR-013). The **app learns about entitlement from a mirror**, asynchronously and
possibly much later; a client `paid` event would timestamp the moment the phone
noticed, not the moment money moved, and would be **missing entirely** for a user
who never reopens the app after purchasing.

The webhook already carries the facts: `PROJECTING_WILL_RENEW` in
`entitlement-core.ts` classifies every RC type, `periodType` distinguishes a
trial from a paid period, `EXPIRATION` is *"the ONLY revoking event"*, and
`store` is the storefront dimension the client does not have.

**But the server emitter does not exist, and "deferred" is doing real work in
that sentence.** `functions/src/` contains no analytics emission of any kind;
`revenuecat-webhook.ts` imports `logProjection` for PII-safe logging and nothing
else; ADR-013's scope does not include analytics. Building it needs a decision
this ADR does not make — a port on the webhook, or a separate Firestore-triggered
function over `subscriptions/{coupleId}` — and it lands with the vendor adapter,
not before. **Filed as #242 rather than left in prose** (a remainder deferred into
prose is a remainder that gets lost — `session-lessons.md`, standing).

### Why `share_card_created` gets a row of its own

`mvp.md`'s OUT list: *"**Quizzes & shareable result cards (v1.5)**"*.
`roadmap.md` line 108 puts share cards in the post-MVP phase.
`grep -rln 'shareCard\|share_card\|ShareCard' app/lib` returns **nothing**.

So `share_card_created` is not deferred work, not a missing call site, and not a
server event: it is an event for a feature the MVP deliberately does not build.
Revision 1 listed it as a client event, which would have produced a typed event
nothing could ever emit — instrumentation for a screen that does not exist,
reading as an unwired funnel step forever.

It is named in the third row **so that its absence is a recorded decision rather
than a gap**, and Decision 6's call-site sentinel excludes exactly this one name,
citing `mvp.md`. Adding a second unwired event turns that test red.

## Decision 2 — A port whose default is silence, and a debug sink that reaches nothing but the console

The app has this idiom one folder over: `crash_reporter.dart` is a port with
`noop_crash_reporter.dart` and `crashlytics_crash_reporter.dart` behind it.
Analytics takes the same shape, with three decisions revision 1 left open.

**(a) The debug sink writes to `debugPrint` and to nothing else.** Revision 1
said it *"writes through the existing observability layer"*, which the review
correctly refused to accept as a specification: `core/observability/` holds
exactly two candidates and both are wrong. `CrashReporter.log` is a **Crashlytics
breadcrumb** — collection is ON in prod, so routing events there would put
product telemetry into crash reports and hand an existing processor a data
category `docs/dpa-inventory.md` does not list for it. `BootTrace` has a closed
six-constant stage vocabulary and is not an event bus. The analytics sink is
**its own file**, it calls `debugPrint`, and a test asserts it holds no reference
to `CrashReporter`.

**(b) It is a NO-OP under `kReleaseMode`, and it is wired in `main_dev` only.**
Both gates, deliberately, because they fail differently: the `kReleaseMode` guard
is `BootTrace`'s discipline (*"prod pays nothing"*, ADR-022 D5) and survives
someone wiring the sink into the wrong entrypoint; the entrypoint wiring survives
someone deleting the guard. **Prod ships the no-op** until a vendor adapter and
the founder's token exist.

**(c) The base provider returns the NO-OP — it does not throw.** This
deliberately departs from the `authRepositoryProvider` idiom the review proposed,
and the reason is written down because the departure will look like an oversight:
those seams throw because a missing repository is a bug that must be loud. **This
is telemetry.** The precedent is `PushDiagnosticRecorder` — *"implementations
never throw; a failure is a logged no-op"* — and `NoopCrashReporter`, which
exists so *"a reporting failure degrades reporting ONLY — never the boot"*
(ADR-039 D1). A throwing base would also take every widget test that renders an
instrumented screen red, which is the exact trap
`push_diagnostic_recorder_provider.dart` records having already been sprung once:
*"an unguarded resolve here would take 60 unrelated widget tests red"*.

**No vendor dependency is added in this slice.** Mixpanel needs a project token
the founder must supply, and Firebase Analytics would be a new package; both
belong behind the port. **What this buys is instrumentability, not measurement.**

## Decision 3 — Dimensions are attached centrally, and two of the three are honestly absent for part of the funnel

A closed dimension set attached in one place rather than at each call site —
because a dimension every emitter must remember is a dimension that will be
missing from exactly the event someone needs.

`architecture.md` §7 asks for **locale/register/storefront on every event**. The
review established that the app cannot supply all three, and that revision 1's
silence about it was the design's largest hole: `install` fires at first launch
(no user, no profile) and `signup` at auth completion (user, but the profile is
captured *after*), while locale and register live on `RelationshipProfile`.

| dimension | source | when absent |
|---|---|---|
| **locale** | `resolveContentLanguage(profile:, deviceLanguageCode:)` — the **existing** precedence contract: a saved profile always beats the device locale, the bootstrap only fills the gap | **never null.** Pre-profile events carry the device-derived language, which is what a locale dimension means before a user has chosen one |
| **register** | `RelationshipProfile.register` | **null before profile capture** — `install` and `signup` carry no register, because the user has not had the choice yet. A default here would be a fabricated value, and Turkish is the one language where the split is product-meaningful |
| **storefront** | *nothing on the client* | **null on every client event, today.** `grep -rn storefront app/lib` returns one comment. The supported locales are language-only, so the resolved locale's `countryCode` is always null. RevenueCat knows the storefront but is configured only when the dart-define key is present. **The server half already carries it** (`store`, off the RC event) — which is where the dimension was always going to come from |

**Storefront-on-every-event is therefore an obligation this slice does not meet,
and says so** rather than shipping a fabricated region. It becomes meetable when
RC is keyed or the server emitter lands; the sentinel of Decision 6 does not
assert dimensions, so nothing green will claim otherwise.

**Content is structurally excluded, not carefully omitted.** §8 promises event
names carry no answer text *ever*, and a promise kept by author discipline is one
that breaks the first time someone adds a helpful field. The event type is a
**sealed class with one `final` subclass per event name** (the `AuthState` /
`PartnerSlot` idiom), each declaring only fixed typed fields from the closed set
below. **There is no free-form map, and no `String` payload field, anywhere on
the type** — so there is no place to put a reflection.

**No event carries a uid or a `coupleId`, on any event, ever.** This is stronger
than ADR-016 requires (which forbids uid, and forbids `coupleId` only on crisis
outcomes) and it is deliberate: this is a domestic-violence-aware product, and
§8's own reasoning about coach *metadata* — *"who tripped the crisis detector;
how often a partner uses the coach"* — applies to a funnel keyed to a couple just
as well. The cost is stated in Decision 7 rather than hidden.

## Decision 4 — Once-only semantics are part of the event definition, not the call site's problem

The largest silent-wrongness risk in client funnel instrumentation is not what an
event carries but **how many times it fires**. An `install` that fires on every
cold boot is not an install; a `paired` that fires on every profile-stream tick
is not a pairing. Revision 1 said nothing about this at all.

Every client event therefore declares its own idempotency key, enforced in the
emitter, using the app's existing sticky-flag seam (`LocalFlagStore` — set-once,
never cleared, already wired by value in both entrypoints and already used for
`ritualPreviewSeenKey`, `nameCaptureDoneKey`, `coachDisclaimerAckKey`).

| event | fires | key |
|---|---|---|
| `install` | once per **device** | `analytics.install` |
| `signup` | once per **uid, per device** | `analytics.signup.<uid>` |
| `invite_sent` | **per action** (each share) | — |
| `paired` | once per **uid+coupleId, per device** | `analytics.paired.<uid>.<coupleId>` |
| `q_answered` | once per **uid+dayKey+mode, per device** | `analytics.q.<uid>.<dayKey>.<mode>` |
| `reveal_viewed` | once per **uid+dayKey, per device** | `analytics.reveal.<uid>.<dayKey>` |
| `streak_day` | once per **uid+lastMutualDate, per device** | `analytics.streak.<uid>.<date>` |
| `coach_msg` | **per send** | — |

**`LocalFlagStore` resolution is guarded.** Its base provider throws when
unoverridden, so the emitter resolves it inside a `try` and, on failure, **emits
without deduplication rather than not emitting** — the `PushTokenSync` guard
precedent. Losing a de-dup is a counting error; losing the event is blindness.

**Two of these are couple-level facts emitted by two devices, and that is
deliberate.** `paired` and `streak_day` are keyed by **uid**, so each partner
emits their own. They therefore count **users paired** and **user-streak-days**,
never couples. This is the right shape for the gate that pays for it — Gate 2 is
*"pairing ≥40% of **signups**"*, a per-user rate — and it is written here so that
nobody later reads `paired` as a couple count and halves it.

**The honest bound: these keys are per-device.** A reinstall re-emits `install`
and can re-emit `signup`; a second device emits its own. `SharedPreferences` does
not survive app deletion (the same fact ADR-018 leans on in the other direction
for the Keychain). Correcting that needs server-side identity, which is Decision
7's problem, not a flag's.

## Decision 5 — `coach_msg` mirrors `logCoachEvent`, crisis-stripping included

ADR-016 is binding and specific: the emitter *"MUST take the `logCoachEvent`
typed-fields shape — no message-text field exists on the type, no uid, and crisis
outcomes are never joined to `coupleId`"*.

The server builder (`coach-core.ts`) enforces this by **dropping** `coupleId`,
`personaId`, both cap counts and `errorCode` whenever the outcome is in
`CRISIS_OUTCOMES` (`crisis`, `help-path`); only `outcome`, `language` and
`latencyMs` survive. The client emitter reproduces the rule **over the fields it
has**, and the two differences are recorded rather than glossed:

* **The client's vocabulary is coarser and cannot be otherwise.** The wire
  response carries `kind: reply | help` (ADR-016 D1's frozen discriminator),
  where the server logs `crisis` (pre-scan) and `help-path` (post-filter) as
  distinct outcomes. The client cannot tell those two apart — the pre-scan case
  never reaches a provider — so it emits **one** crisis outcome. Acceptable
  because the stripping rule is identical for both, and stated so that a future
  reader does not go looking for a distinction the wire does not carry.
* **`personaId` is the only field there is to strip**, because Decision 3 already
  removed `coupleId` and uid from every event. On `help`, `personaId` is dropped.
* **`remaining` and `category` are never carried at all.** The response *does*
  return `remaining` on the post-filter help path (ADR-016 D2), so an emitter
  that forwarded what it was given would ship cap counts on a crisis event. And
  `category` (`selfHarm` / `violence`) is display-only and never enters the
  server's log shape either.

**The test asserts the stripping in both directions** — a crisis outcome carries
no `personaId`, and a non-crisis outcome still does. Asserting only the first is
satisfied by an emitter that sends nothing at all.

## Decision 6 — TWO sentinels, because a list is not a call site

*"Each screen emits an event"* is satisfied by hand-written call sites that drift
apart, which is ADR-052's lesson in another costume. But revision 1's answer — a
list sentinel — has the mirror-image defect, and the review named it correctly:
**a vocabulary check proves the event TYPE exists, not that anything calls it.**
That is ADR-025 D8's error (*a declaration nothing enforces reads as coverage*)
committed by the very decision citing it, and `card_surface_sentinel_test.dart`
already says so in its own header: *"WHY IT IS NOT 'each screen has a shadow'"*.

So there are two, and neither is claimed to do the other's job.

**Sentinel A — vocabulary parity with `architecture.md` §7.**

* **Set equality, both directions.** Revision 1 asserted only doc ⊆ code
  (*"adding a thirteenth event turns the suite red"*). An event **deleted** from
  §7 while the emitter keeps it would have passed. The parity tests this repo
  already has (`schema_enum_parity`, `push_diagnostic_vocabulary_parity`) compare
  sets; this one does too, over `client ∪ server ∪ notBuilt`.
* **A floor assertion before the comparison** — lesson **110**: *a scan whose
  glob matches nothing reports the same clean zero as a scan that passed.* If the
  §7 heading is renamed or the paragraph reworded, the parser finds nothing and
  a naive test compares ∅ to ∅ and passes green. The test asserts it parsed **at
  least 12** names, with a reason that says the anchor moved rather than the tree
  is clean — the `card_surface_sentinel` (`> 50` files) and `schema_enum_parity`
  (`existsSync`) precedent.
* **An explicit parse grammar, not a backtick scan.** §7's prose contains
  backticked identifiers that are **not** events — `logCoachEvent`, `coupleId`.
  The parser reads the arrow chain and the `plus`-list from the first sentence
  only, expands `q_answered{solo|mutual}` to the single name `q_answered`, and
  **stops at the first sentence boundary**; a name is `[a-z][a-z_]*`. The floor
  assertion is what catches a §7 rewrite that breaks the grammar.

**Sentinel B — call-site coverage.** For every event in the **client** row, at
least one call site exists under `app/lib/features/` (or `app/lib/app.dart`), by
scanning source for the event constructor — the `card_surface_sentinel` idiom of
scanning the tree rather than trusting a list. The exclusion list is **exactly**
`{share_card_created}`, asserted to have length 1 and justified against
`mvp.md`'s OUT list, so a tenth unwired event is red rather than invisible.

**What sentinel B still cannot see**, recorded rather than left to be discovered:
that the call site is on the **right** path — an `invite_sent` emitted in an
error branch satisfies it. Per-call-site behaviour is covered by ordinary unit
tests, not by the sentinel.

## Decision 7 — The two emitters do not share an identity, and Gate 3's headline metric needs one

This is the consequence of Decision 1 that revision 1 did not state at all, and
it is the one a later session is most likely to discover the expensive way.

`mvp.md`: **`install→paid ≥2%`**. `install` is a client event, fired before any
account exists. `paid` is a server event, keyed to a `coupleId` the webhook
resolves from an RC subscriber id. **There is no key that joins them**, and
Decision 3 removed the obvious candidate on purpose (no uid, ever, on a client
event).

So, plainly: **after this slice, Gate 3's `install→paid` remains uncomputable,
and not because analytics is unbuilt — because the funnel has two emitters and no
join.** `trial→paid` is unaffected (both are server-side). Gate 2's
`pairing / signups` is unaffected (both are client-side, and Decision 4 keys them
per user).

Closing it needs a **distinct id** — a device-scoped identifier minted at install
and later aliased to the account — and that is a **privacy decision, not a
plumbing one**: a persistent device id is collection, it interacts with
`PrivacyInfo.xcprivacy`'s `NSPrivacyTracking=false` declaration and its
linked-types list, and it lands in the same paperwork #226 is already blocked on.
It is deliberately **not** invented here. Filed as **#243**.

## Consequences

**What this buys.** The funnel becomes emittable **and emitted**: the seam
exists, the dimensions are attached in one place, the once-only semantics are
part of the event rather than the call site's problem, content is structurally
excluded, the crisis rule is enforced rather than remembered, and every client
event whose feature exists has a call site that a test will keep honest.

**What it does not buy, stated plainly.**

* **A measurable funnel.** Nothing here ships events to a tool anyone can build a
  Gate 2/3 funnel in. Prod ships the no-op sink. The honest status after this
  slice is *"instrumented and emitting, into a debug sink, in dev only"*.
* **Gate 3's `install→paid`** — Decision 7, and it needs a decision the founder
  is part of.
* **The `storefront` dimension** — Decision 3, null on every client event.
* **The server three** — Decision 1, unbuilt, with no port to build them on (#242).
* **`share_card_created`** — no feature, by MVP decision.

**⚠️ This slice widens what the product collects, and the privacy policy is
already wrong about collection.** #226 records that the policy's *"what we
collect"* list is inaccurate about push and is founder/lawyer-blocked because any
revision re-prompts every user for consent. **Analytics events are collection.**
What keeps this slice inside the existing paperwork is narrow and worth naming
precisely: **prod emits nothing** (Decision 2b), the debug sink reaches only the
device console (2a), and **no new processor is added** — so nothing leaves the
device and `docs/dpa-inventory.md`'s register is unchanged *today*. The moment an
adapter sends events off the device, `docs/legal/` and that register both need a
row, and that is a founder decision, not a follow-up commit.

**The residual risk this leaves is temporal, and no test closes it:** the seam is
now easy to point at a vendor, and the paperwork gate lives in this paragraph
rather than in CI. Recorded here so the next session cannot land the adapter
believing the paperwork is done.
