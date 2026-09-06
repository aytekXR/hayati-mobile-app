# ADR-076: Nothing in this project had ever ASKED APNs for an address

- **Status:** Accepted — **a candidate fix, and it is named as one.** Unlike
  ADR-074 (which makes a failure audible) and ADR-075 (which eliminated a
  suspect), this one could actually deliver a notification. Whether it does is
  unknown until a build reaches a phone, and D3 says so rather than implying
  otherwise.
- **Date:** 2026-09-06 (Session 101)
- **Deciders:** session agent. **Nothing deployed, no release dispatched.**
- **Related:** **ADR-046 D6** (the same argument, one link later — this is its
  twin), **ADR-074** (the refusal callback), **ADR-075** (the entitlement chain,
  proven intact), **ADR-044 D1** (the bounded capture this hooks into),
  **ADR-042 D2** (the adapter this lives in), lessons **65**, **78**

## Context — what is left after two links were exonerated

By the end of ADR-075 the chain looked like this:

| link | status |
|---|---|
| the backend sends | **proven** — `answer_reveal` fired twice, resolved the partner, applied the streak |
| the binary claims `aps-environment` | **proven** — `Runner.entitlements`, in git |
| the App ID permits it | **proven** — run 34038316432 |
| the profile grants it | **proven** — run 34040358971, `ACTIVE`, `production` |
| the device has an address | **NO**, twice, **78 minutes apart** |

Two independent captures — 13:24:56Z and 14:42:56Z — both ended
`awaitingDeviceToken / captureExhausted`. **This is not the ADR-044 window.** A
timing race does not survive an hour and a fresh app launch.

So the question narrowed to one thing, and it is embarrassing when written down:
**who asks APNs for an address?**

Nobody in this repository. `grep` for `registerForRemoteNotifications` across
`app/` returns only the *result* callbacks in `AppDelegate.swift`, never the
request. The request comes entirely from `firebase_messaging`, at
`FLTFirebaseMessagingPlugin.m` (16.5.0):

```objc
// in setupNotificationHandlingWithRemoteNotification:actionIdentifier:
if ([FIRMessaging messaging].isAutoInitEnabled) {
  [self registerForRemoteNotifications];
}
```

That method is reached from the launch notification or from
`scene:willConnectToSession:`. **Three properties of this app meet there badly:**

1. it has a **SceneDelegate** (`UIApplicationSceneManifest` in `Info.plist`);
2. it configures Firebase from **pure-Dart `FirebaseOptions`** with **no
   `GoogleService-Info.plist`** — so there is no `FirebaseApp` at all until
   Dart's `main()` reaches `Firebase.initializeApp`;
3. the guard above touches `[FIRMessaging messaging]` — a **default-app**
   accessor — at plugin-setup time.

**Whether that guard runs before or after Dart configures Firebase is an
ordering this project does not control and cannot observe from Linux.** If it
lands early, the branch is not taken, nothing ever asks APNs,
`getAPNSToken()` is nil for the life of the install, and the symptom is exactly
what production shows: permission granted, no address, no error, forever.

⚠️ **This ADR does not claim that is what happens.** It claims the app depends
on an ordering it neither controls nor measures, on the one call the entire
feature rests on. That is the dependency worth removing whether or not it is
today's bug.

## Decision 1 — Ask APNs ourselves, on the same argument ADR-046 D6 already won

ADR-046 D6 stopped depending on FirebaseCore's swizzling to *deliver* the APNs
token, and assigned `Messaging.messaging().apnsToken` in `AppDelegate` explicitly.
Its reasoning, verbatim: *"Swizzling is probably fine… But 'probably' against a
link whose only failure mode is silence, and a measured zero, is not a posture
worth keeping."*

**Every word of that applies one link earlier**, to the request rather than the
delivery — and D6 hardened the half that only matters *after* the half this ADR
hardens has succeeded. A seventh method on the one platform channel (ADR-018 D6)
calls `UIApplication.shared.registerForRemoteNotifications()`.

**Apple documents the call as idempotent**: a repeat re-delivers the existing
token to `didRegisterForRemoteNotificationsWithDeviceToken`. So this is free when
the plugin already succeeded, and it is the whole feature when it did not.

## Decision 2 — It fires from `isReadyForToken`, when the answer is "no address"

Not from `ensurePermission`, and the difference matters.

`ensurePermission` runs **once per grant**, so a phone that was granted in an
earlier session — every warm start — would never reach it. `isReadyForToken` is
called by ADR-044's bounded capture on **every** attempt, on **every** path that
can register: sign-in, `refresh()` from the Settings row, a token rotation. The
request is issued exactly when the app has observed that it has no address, which
is the only moment it is worth anything.

It is **fire-and-forget** (`unawaited`): the readiness answer must not come to
depend on a channel round-trip, and the loop will ask again in half a second
regardless (ADR-044 D1). It swallows everything, because a missing native half
must not turn a readiness probe into a throw the caller would log against the
wrong link (ADR-049's rule, applied here).

⚠️ **The repeat is the point, not a cost.** Six attempts issue up to six
requests, and iOS answers each by re-delivering the same token. The alternative —
a "have we asked yet" flag — is state that can be wrong, guarding a call Apple
says is safe to repeat.

## Decision 3 — What this is, and what it is not

**It is a candidate fix.** ADR-074 made a failure audible; ADR-075 eliminated a
suspect; this one could actually make a notification arrive.

**It is not a diagnosis.** If APNs is refusing for some other reason, this
changes nothing except that ADR-074's callback now definitely gets its chance —
because a callback that fires only in response to a request nobody made cannot
fire at all. **The two decisions are complements**: without D1, ADR-074's
instrument may have been shipped into a build where the OS was never asked
anything and therefore had nothing to say.

That is the sharpest version of this session's finding: *the reason the failure
was silent may be that the question was never asked.*

## Consequences

**Positive**

- The one call the entire feature rests on stops depending on an initialisation
  ordering this project does not control, cannot observe, and did not choose.
- ADR-074's instrument is guaranteed a request to report on.
- Zero cost when the plugin already works — Apple's idempotence contract.
- No port change, so no fake, no test and no seam moves: the call lives in the
  deliberately-thin adapter (ADR-042 D2) where a platform call with no branches
  belongs.

**Negative / accepted trade-offs**

- **Unverified against a device, like everything else in this session.** Format,
  analyze and 78 tests pass locally; the Swift rests on `ios-build-smoke`. The
  first real exercise is a build.
- **If this IS the bug, the previous six builds were undone by a vendor ordering
  and nobody could have seen it from the outside** — which is an uncomfortable
  thing to write and the reason it is written.
- Up to six redundant `registerForRemoteNotifications` calls per capture. Bounded,
  idempotent, and cheaper than a flag that could be wrong.
- The plugin may change its ordering in a future release and make this
  redundant. It stays anyway: ADR-046 D6's assignment is redundant when swizzling
  works, and it is kept for the same reason.
