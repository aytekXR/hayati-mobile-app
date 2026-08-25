# ADR-061: "delete my account" and the local flags it cannot reach

- **Status:** Proposed
- **Date:** 2026-08-21 (Session 085) · **Revision 2, 2026-08-26** — the consumer
  inventory in revision 1 was wrong, and the shape of the fix changed with it
- **Deciders:** session agent (device-local behaviour; no operator dependency)
- **Related:** **ADR-019** (the M6.2 deletion cascade), **ADR-017 D3/D4** (the app-root teardown; the `LocalFlagStore` seam and why it is set-once), **ADR-057 D4** (once-only funnel keys and the reinstall bound), **ADR-018** (the PIN store, which cites the sticky contract as a reason for its own design), **ADR-058** (S082's legal draft, which states what happens to these markers), **ADR-052** (one definition, not a re-derivation per call site), issues **#246** (this one), **#250** (Android backup), **#258** (the legal draft's sentence, filed rather than folded)

> **Review status, stated prospectively.** Revision 1 was written and committed
> **before** the fix (`session-context.md` §5 item 1, lesson 111). **Revision 2 is
> also pre-code**: it corrects findings the session's own orientation grep turned
> up, before either review pass ran and before a line of implementation existed.

## Revision 2 — what revision 1 got wrong, and why it mattered

Revision 1 said `LocalFlagStore` has **three** consumers and that
`analytics.install` is *"the only one with no uid"*. Both are false, and one
grep says so:

* there are **six** consumers and **eleven** key shapes, not three;
* **two** of them are device-scoped, not one — `ritualPreviewSeen` is set
  **before any uid exists** (the pre-sign-in preview), so it is the second flag
  that must never be cleared, and revision 1 did not know it existed.

That matters beyond bookkeeping: revision 1's Decision 2 was a **prefix list**
built from the flags it had enumerated, and a prefix list is complete only for
the flags its author happened to know about. The corrected inventory is the
argument against that shape — the very first attempt at the list was already
missing half of it.

## Context — five things measured before deciding anything

#246 says the once-only analytics markers survive account deletion. True.

### 1. The defect is not analytics-specific — it is every uid-keyed local flag

Measured by grepping `localFlagStoreProvider` across `app/lib` (2026-08-26):

| key | written by | account- or device-scoped |
|---|---|---|
| `analytics.install` | `Analytics.install` | **device** — this phone installed the app |
| `analytics.signup.<uid>` | `Analytics.signup` | account |
| `analytics.paired.<uid>.<coupleId>` | `Analytics.paired` | account |
| `analytics.q.<uid>.<dayKey>.<mode>` | `Analytics.qAnswered` | account |
| `analytics.reveal.<uid>.<dayKey>` | `Analytics.revealViewed` | account |
| `analytics.streak.<uid>.<lastMutualDate>` | `Analytics.streakDay` | account |
| `coachDisclaimerAck.<uid>` | the coach disclaimer gate (ADR-017 D4) | account |
| `coupleEndedSeen.<uid>.<atMs>` | the couple-ended notice (ADR-019) | account |
| `nameCaptureDone.<uid>` | the name-capture step (redesign QW-6) | account |
| `privacySpotlightSeen.<uid>` | the privacy spotlight card (redesign M-6) | account |
| `ritualPreviewSeen` | the pre-sign-in ritual preview (redesign M-5) | **device** — set before a uid exists |

#246 names five of the nine account-scoped shapes. Fixing only the ones it names
would leave the same defect, in the same store, behind the same seam — and the
next reader would have no reason to think the other four were considered. **The
issue's scope is narrower than the defect's.**

`SharedPreferences` is the only local surface this reaches. The PIN lives in the
Keychain and is already wiped on `AuthSignedOut` by the app-root listener
(ADR-018); nothing else in `app/lib` opens `SharedPreferences` at all.

### 2. Clearing them changes NO counts, because the uid is already in the key

The `resume-prompt.md` that assigned this session said clearing the markers
*"makes a later re-signup re-emit once-only events — a counting change to a
funnel, traded for a data-rights improvement."* **That is wrong, and it was my own
sentence.**

`analytics.signup.<uid>` contains the uid. A deleted account's replacement has a
**different uid**, so it gets a **different key**, so it re-emits `signup`
already — cleared or not. The same holds for every other account-scoped row in
the table. **For every uid-keyed flag, clearing is behaviourally invisible**; its
only effect is that stale personal data stops sitting on the device.

So there is no trade to weigh here. The trade I wrote into the resume prompt did
not exist, and the reason it looked real is that I reasoned about the *flag*
rather than about the *key*.

### 3. The two device-scoped flags must NOT be cleared, and for two different reasons

`analytics.install` is device state rather than account state: this phone did
install the app once, and that stays true across an account deletion. Clearing it
would make a re-signup emit a **second `install`** from one device — a real
counting error, and the only one available in this whole change. It also carries
**no identifier**, so the data-rights argument that motivates the others does not
apply to it.

`ritualPreviewSeen` is stronger still: the 15-second pitch runs **before
sign-in**, so there is no uid to key it by and no account it could belong to.
Clearing it would re-show a first-launch pitch to someone who has already seen
it, and would delete nothing personal, because there is nothing personal in it.

Both point the same way, which is why this ADR can be decisive rather than
balancing — and both are covered **by construction** under Decision 2 rather than
by an exemption list, which is the point of choosing that shape.

### 4. The app-root listener CANNOT tell a deletion from a sign-out

`app.dart` already distinguishes two teardown depths, deliberately (ADR-017 D3):

```dart
if (next is! AuthSignedIn) { ref.invalidate(coachTranscriptProvider); }
if (next is AuthSignedOut) { ref.read(privacyLockControllerProvider.notifier).wipe(); }
```

**Both a deletion and an ordinary sign-out end in `AuthSignedOut`.** So hooking
the clearing there would clear on *every* sign-out — and for
`coachDisclaimerAck.<uid>` that is a visible regression: signing out and back in
as the same user would re-show the coach disclaimer they already acknowledged.
`nameCaptureDone.<uid>` and `privacySpotlightSeen.<uid>` regress the same way.

This is the finding that decides the shape of the fix. **The clearing belongs to
the delete flow, not to the auth teardown**, because only the delete flow knows
which of the two happened. #246's own "possible fix" proposed that listener; it
is the one place the fix must not go.

### 5. `localFlagStoreProvider` THROWS when unoverridden

The base provider is a `StateError` by design — the flavor entrypoints override
it by value, and a widget test that does not wire storage gets the throw.
`Analytics._claimOnce` already guards its read for exactly this reason. Any new
reader on the delete path inherits that constraint: an unguarded `ref.read` there
would turn a successful deletion into a thrown `StateError` in every existing
delete test.

## Decision 1 — Clear every account-scoped local flag, on deletion only

In `AuthController.deleteAccount`, **after the server cascade succeeds and before
the session teardown** — the one place in the app that knows a *deletion*
occurred rather than a sign-out.

The uid is read from `authRepository.currentUser` **before** phase 1 runs, not
after: the session identity is what phase 2 signs out, and reading it up front
means the cascade cannot invalidate it underneath us. `state` would also work and
was considered; it was rejected because it is the value the *UI* renders from,
and the flags belong to the session, not to the view.

**Before** rather than after phase 2, because a phase-2 sign-out failure
(`AuthError`) still leaves an account that the server has already deleted. The
markers should go with it either way.

## Decision 2 — The store removes by **uid**, not by a prefix list

The seam is documented as **"one-way STICKY flags (set-once, never cleared)"**
(ADR-017 D4), and `pin_lock_store.dart` cites that contract as a reason for its
*own* design — so widening it is not a local change. It gains exactly one method,
`removeAccountScoped(String uid)`, and one shared predicate that decides what
that means:

```dart
bool localFlagKeyBelongsTo(String key, String uid) =>
    uid.isNotEmpty && '.$key.'.contains('.$uid.');
```

A key belongs to a uid when the uid is one of its **dot-delimited segments**.
Every account-scoped row in the table above satisfies that; neither device-scoped
row can.

**Why not the prefix list revision 1 chose:**

* It is complete only by hand. Revision 1's own list was missing four of the nine
  account-scoped shapes on its first attempt, and a miss is **silent** — which is
  the exact failure #246 is.
* It would put the list somewhere. The delete path lives in `features/auth`; the
  key builders live in `core/analytics`, `features/coach`, `features/data_rights`,
  `features/profile` and `features/settings`. Assembling nine prefixes there means
  the auth controller imports a settings widget's key function.
* It makes the device-scoped exemption a **list entry** rather than a property.
  Under the uid rule, `analytics.install` and `ritualPreviewSeen` are exempt
  because they contain no uid — and so is every device-scoped flag written after
  this ADR, by an author who never reads it.
* Substring matching would be simpler still and is **wrong**: with test uids `u1`
  and `u12`, deleting `u1` would take `u12`'s flags. The dot-boundary wrap is what
  makes cross-account removal safe on a shared device, and it is also why the
  predicate is written as one expression in one place (ADR-052's idiom) rather
  than re-derived in each implementation.

The sticky contract is **re-stated rather than deleted**: flags are still never
cleared by the code that sets them. The only thing that removes one is an account
deletion — the single event that removes everything else too.

## Decision 3 — A local-cleanup failure never fails the deletion

The read is guarded (finding 5) and the removal is wrapped. A `SharedPreferences`
failure, or an unoverridden provider in a test, degrades to **flags left behind**,
never to a deletion that reports failure to a user whose account the server has
already destroyed. That is the same asymmetry ADR-019 D7 draws for phase 2, and
the opposite of `Analytics._claimOnce`'s (which degrades toward *emitting*,
because there the risk is blindness).

A **null or empty uid** takes the same path: nothing is removed, and nothing
throws. It cannot happen from the delete screen, and the predicate's
`uid.isNotEmpty` guard means that if it ever does, the failure is a no-op rather
than a wildcard that matches an empty segment.

## Decision 4 — An inventory sentinel, because the classification is the thing that rots

Decision 2 is complete for every key that puts the uid in a segment. What it
cannot see is a **future** consumer that keys by uid some other way — or one whose
author never considered the question. So the guard is not "the predicate works"
(a unit test covers that); it is **"every consumer has been classified"**:

* a source scan over `app/lib` for `localFlagStoreProvider`, whose file set must
  equal a declared inventory — adding a consumer reddens the suite until its key
  is declared account- or device-scoped, in the `funnel_call_site_sentinel_test`
  idiom (ADR-057 D6) and with the same non-empty control (lesson 110);
* and a parity assertion that every declared **account-scoped** key builder,
  called with a test uid, satisfies the predicate — and every declared
  **device-scoped** key does not.

## Decision 5 — The legal draft is checked, survives, and gets a note rather than an edit

`docs/legal/proposed/` says the markers *"go when you remove the app"* and that we
never receive them. Both stay true: removing the app still clears them, and this
change adds a second way they go. The notice ends up promising **less** than the
app does, which is the safe direction and the opposite of #226's subject.

So the draft is **not** re-opened. But the sentence sits in the paragraph a user
reads to learn what happens to their data, and *"they go when you remove the app"*
invites the inference that deleting the account does not — an inference this
change makes wrong. That is a substance question for the lawyer who already has
the document open, so it goes where #249 went: a note in
`docs/legal/proposed/README.md` under the section that exists for exactly this,
plus issue **#258**. Widening a revision the founder is about to review is scope
creep (`session-rules.md` §2); telling them what changed underneath it is not.

## Consequences

* **`#246` closes**; the four account-scoped flags it did not name are covered by
  the same change, and so are flags written after it.
* **Nothing measurable changes in the funnel** (finding 2). If that were wrong,
  the counting error would be silent — which is why finding 3 states the
  `install` case explicitly instead of leaving it to the predicate to imply.
* **The sticky contract is now conditional**, and a later author reading
  `LocalFlagStore` must see that in the seam rather than discover it in a cascade.
  The doc comment on the method is the mitigation, and it is the whole reason the
  method takes a **uid** rather than a key.
* **The removal reaches one device — the one performing the deletion.** A second
  phone that the same account signed into keeps its flags until the app is
  removed there. The server cascade has always been the only thing that reaches
  every device, and it cannot reach `SharedPreferences` on any of them. Recorded,
  not fixed: a device that never runs the delete flow has nothing to run it with.
* **`removeAccountScoped` sees every `SharedPreferences` key on the device**, not
  only this seam's — `getKeys()` is plugin-wide. A foreign key would have to carry
  the uid as a dot-segment to be caught, which nothing on this device does today.
  Named because it is the kind of bound that is cheap to state and expensive to
  rediscover.
* **`#250` (Android auto-backup) is untouched and still binds**: on a platform
  where backup restores prefs, a cleared flag can come back. The fix removes what
  is on the device; it cannot reach a copy Google or Apple already took.
