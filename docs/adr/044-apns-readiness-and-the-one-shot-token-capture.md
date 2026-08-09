# ADR-044: the notification feature is complete on every side except one racy call — iOS cannot mint an FCM token until APNs answers, and we asked exactly once

- **Status:** Accepted
- **Date:** 2026-08-09 (Session 066)
- **Deciders:** session agent (no founder input; this **removes** an operator dependency's ambiguity rather than adding one)
- **Related:** **ADR-042** (the token lifecycle this amends — D2's seam, D6's prompt placement), **ADR-039** (fail-open boot, bounded waits — D2 is what makes the retry legal), issue **#188**, `docs/architecture.md` §9

## Context — the server half is proven working, to the last inch

The daily-question push has been "built and waiting on the founder" for four
sessions. It is not. **Production was measured on 2026-08-09**, at the only hour
where the counters mean anything — 05:00 UTC, which is 08:00 local for the one
couple, whose stored zone is UTC+3:

```
question_rollover: sweep complete            existing:1  buckets:1  assigned:0
W: sweep push skipped, no fcm tokens   recipientUid=lvny6fJ…  kind=dailyQuestion
W: sweep push skipped, no fcm tokens   recipientUid=ZCBj6Hq…  kind=dailyQuestion
question_rollover: daily-question sweep complete
        checked:1  sent:0  skippedNoToken:2  skippedNoDay:0  suppressedQuiet:0  failed:0
```

The sweep fires at exactly the right local hour, finds the couple, resolves
**both** members as non-answerers, and composes a push for each. It stops at the
last inch: **neither member has an FCM token.** Everything upstream of the token
lookup is verified working in production.

### The counter everyone was reading was the wrong one

`operator-expected.md` and four resume prompts asserted:

> `daily-question sweep — couples checked for push: 0` (every hourly pass).
> `0` means no phone has ever handed over a token.

**That inference is invalid.** `runDailyQuestion` opens with
`if (hour !== DAILY_QUESTION_LOCAL_HOUR) continue;` — the pass evaluates only
buckets whose *couple-local* hour is 8. So `checked: 0` is the **expected**
reading for 23 of every 24 sweeps, whatever the token state is, and the sweeps
that were sampled (21:00Z, 22:00Z) were exactly those. The honest instrument is
`skippedNoToken` at the couple's own hour-8 sweep — which says **2**, and which
also names the two recipient uids.

This is the repo's recurring shape 3 (*an inherited premise nobody re-measured*)
and it had a cost: the founder was told for four sessions that one tap was all
that stood in the way.

## The defect

`FcmPushTokenSource.currentToken()` is one line: `_messaging.getToken()`.

On iOS **FCM cannot mint a registration token until APNs has handed the app a
device token**, and that handoff is asynchronous — it completes *after*
`requestPermission()` returns. Called before it, `getToken()` does not return
null; it **throws** `[firebase_messaging/apns-token-not-set]`.

`PushTokenSync.promptForPermissionAndRegister()` does exactly this:

```dart
final granted = await source.ensurePermission();   // user taps Allow
if (!granted) return false;
await _captureAndRegister(...);                    // -> getToken() -> THROWS
```

`_captureAndRegister` catches, `debugPrint`s, and returns. **There is no retry.**
And `_promptedForPermission` is set *before* the attempt, so the prompt path
never runs again for the life of the process. The single capture attempt is
issued inside the precise window in which iOS guarantees it can fail.

The only remaining recovery is `onTokenRefresh`, which fires when FCM *generates*
a token — reliable for a first-ever generation, **not** guaranteed for a token
that already exists and is merely waiting on its APNs mapping. Recovery is
therefore timing-dependent, and the observed outcome across builds 115, 116 and
117 is that `registerPushToken` **has never once been invoked by a device**.

### The port's own contract already said this was wrong

`PushTokenSource.currentToken()` documents: *"Never throws for an ordinary
absence: a device without a token is the normal state before permission."* The
FCM adapter's own comment admits it does exactly that — *"On iOS, getToken()
throws rather than returning null when APNs has not registered"* — and the
compensation was pushed up into a catch. **An adapter that violates its port's
contract and documents the violation is a defect with a comment on it**, not a
design.

Worse, `push_token_sync_test.dart` asserts the swallow is correct
(`currentTokenThrows = Exception('no APNs token')` → expect a no-op). The test
blessed the defect, which is why nothing ever went red.

## Decision 1 — Ask the platform whether it is ready, and keep that decision ABOVE the port

The port gains one method:

```dart
/// Whether the platform has delivered everything FCM needs before it can mint
/// a token. iOS: an APNs device token. Everywhere else: trivially true.
Future<bool> isReadyForToken();
```

`FcmPushTokenSource` implements it thinly (`getAPNSToken() != null`), preserving
ADR-042 D2's trade: the adapter stays branch-free and untested, and **everything
that decides anything stays above the seam and is proven on Linux with a fake.**

The rejected alternative was putting the wait inside the adapter. It is fewer
lines and it is untestable on this machine — the same reasoning ADR-042 D2 used
to put the lifecycle above the port in the first place, applied to the one piece
that was left below it.

## Decision 2 — A BOUNDED retry, off the critical path

`PushTokenSync` retries capture while the platform is not ready, with a bounded
attempt count and linear backoff, and treats a throw from `currentToken()` as
"not yet" rather than "never".

ADR-039 D2 requires every wait on the launch→paired path to be **bounded**, and
this one is: at most 6 attempts with 0.5s × n backoff — under 8 seconds
worst-case, issued `unawaited` from a post-frame callback, so it can never delay
a frame or block the tree. A device that is genuinely never going to produce a
token (permission declined, no APNs) costs those 8 seconds once, in the
background, and then stops.

The attempt count and backoff are `@visibleForTesting` so the retry itself is
provable in milliseconds rather than asserted.

## Decision 3 — The prompt guard moves AFTER the outcome is known

`_promptedForPermission = true` is currently set before permission is even
requested, so a failed capture is permanent for the process. It now guards only
what iOS actually rations — the **dialog** — while a *granted* permission whose
capture failed remains retryable on the next paired-home mount. iOS shows its
dialog once per install regardless, so re-entering `ensurePermission()` on a
later mount is a cheap read of the standing answer, not a second interruption.

## Decision 4 — This is a behaviour change to a shipped path, so it is mutation-checked

The existing test that asserts a `currentToken()` throw is a silent no-op is
**wrong and is replaced**, not deleted quietly: the new assertion is that a
throw is *retried* and that a token appearing on a later attempt **is
registered**. A test that blesses the defect is worse than no test, because it
converts a bug into a specification.

## Consequences

* The founder's remaining action is unchanged in words — install a build, tap
  Allow — but it now has a chance of working. Before this, a granted permission
  had a real chance of registering nothing, silently, forever.
* **It stays diagnosable without the founder** (lesson 90): the same production
  instrument that found this — `skippedNoToken` at the couple's hour-8 sweep,
  and `registerPushToken`'s invocation log — moves the moment a token lands.
* `operator-expected.md`'s reading of `checked: 0` is corrected in the same diff.
  A wrong instrument in a founder-facing document is how four sessions of "just
  tap Allow" happened.
* Issue **#188** is the device half and this is the last of it.
