# ADR-046: nobody has ever received a notification, every layer is verified working, and the four ways it can fail on the device are indistinguishable from each other and from success

- **Status:** Accepted
- **Date:** 2026-08-16 (Session 069)
- **Deciders:** session agent (this **removes** an operator dependency rather than adding one — the founder is currently the only instrument, and that is the defect)
- **Related:** **ADR-042** (D1 the callable contract, D2 the port seam, D6 where the prompt lives — all three preserved), **ADR-044** (the bounded capture retry this makes *repeatable*), **ADR-039** (D1 fail-open, D2 bounded waits — what makes the retry legal), **ADR-018 D6** (the app's one platform channel, which this extends rather than duplicates), **ADR-022** (nothing added to the launch critical path), issues **#188**, **#219**, lessons **65**, **69**, **90**, **91**, **100**, **101**

## Context — measured 2026-08-16, not inherited

Five independent lenses were run over the whole notification chain, and every
blocker/major finding was adversarially verified. The result is unusually clean:

| Link | State | How it was measured |
|---|---|---|
| Cloud Scheduler → sweep | **working** | `prod_pulse.py --from-firebase-cli` → exit 0, last sweep 26m ago |
| the sweep finds the couple | **working** | `couples/MePthR3YmialfjPpmMDq`, `Europe/Istanbul`, two member uids |
| the sweep composes a push | **working** | 2026-08-16T06:00:03Z `checked:1 skippedNoToken:2 sent:0`, both recipient uids named |
| payload shape | **working** | `fcm-adapter.ts` sends `notification:{title,body}` — not data-only, so iOS will display it |
| quiet window vs the two hours | **working** | `isQuietLocalHour` is `>=23 || <8`; 09:00 and 22:00 are both legal |
| `registerPushToken` reachable | **working** | Cloud Run `getIamPolicy` → `roles/run.invoker: [allUsers]` on `registerpushtoken` **and** `unregisterpushtoken` |
| `aps-environment` | **present** | `Runner.entitlements`, `production`, since 2a12a07 (2026-08-07) |
| entitlements wired to the build | **present** | `CODE_SIGN_ENTITLEMENTS` in Debug, Release **and** Profile |
| build 119 carries both fixes | **yes** | 16be0e4 (ADR-044) and 3550368 (#215) are both ancestors of the 119 tag |
| **a device registering a token** | **has never happened** | `users/*` — 4 docs, `fcmTokens` absent on all 4; Cloud Logging shows **zero HTTP requests** ever reaching the function |

So the chain is whole and the last link has never been attempted. The two
hypotheses that would have been engineering bugs — the callable unreachable at
the serving layer (the shape that cost 37 hours in #219, and the shape that is
still live on `revenuecatWebhook`, #115), and a signing/entitlement gap — were
both **refuted by measurement**, not by reasoning.

### The actual defect is that we cannot tell which of four things happened

The device path can fail in four ways, and **all four produce byte-identical
evidence: nothing.**

1. **build 119 was never installed** — nothing to observe anywhere;
2. **the prompt was declined** — on 115/116/117 or on 119. iOS shows its dialog
   **once per install**; thereafter `requestPermission()` returns the standing
   `denied` without interrupting anyone. **No rebuild recovers this. Only the iOS
   Settings app does**, and the app has never said so;
3. **permission was granted and capture still produced nothing** — ADR-044's
   bounded retry gives up after 6 attempts (~7.5s) and never tries again for the
   life of the process;
4. **`registerPushToken` was called and threw** — `FunctionsPushTokenRepository`
   catches everything by design (ADR-042: a failed registration must never cost a
   frame).

Every one of those four ends in `debugPrint`, and **`debugPrint` on a TestFlight
release build goes nowhere any human or any session can read**:

| Where the silence is | file:line *(as of `c2cfd8e`, the tree this ADR replaces — do not expect these to resolve afterwards)* |
|---|---|
| permission declined | `push_token_sync.dart:147` |
| capture exhausted after 6 attempts | `push_token_sync.dart:230` |
| a capture attempt threw | `push_token_sync.dart:219` |
| registration threw | `push_token_sync.dart:245` |
| the callable itself failed | `functions_push_token_repository.dart:51` |

This is the repo's recurring shape 1 (*a green signal that measured nothing*) and
lesson **69** (*an UNREAD failure is the bug*) at the one place it has cost the
most: the founder has been told for five sessions that one tap is all that stands
in the way, and there has never been a way to check whether the tap happened, or
what it did.

### Why "just ask the founder again" is the wrong fix

Lesson **90** is that the instrument should not need the founder. Here it is
stronger than that: **the founder cannot answer question 2 or 3 either.** A
person who declined the dialog eleven days ago on build 116 has no memory of it
and no screen anywhere that reports it. The only surface that can distinguish
these states is the app itself, on the phone, at the moment someone looks.

## Decision 1 — Permission state is READ, not inferred from having prompted

`PushTokenSource` gains one method:

```dart
Future<PushPermission> permissionStatus();   // notDetermined | denied | granted
```

`FcmPushTokenSource` implements it thinly — `getNotificationSettings()`, mapped —
so ADR-042 D2's trade is preserved exactly: the adapter stays branch-free and
untested, and everything that *decides* anything stays above the seam and is
proven on Linux with a fake.

**This is a read, not a request.** `getNotificationSettings()` never shows a
dialog, so it is safe to call on every mount, on every resume, and from a
settings screen — none of which may be allowed to consume iOS's one-shot prompt.
That distinction is the whole reason it is a separate method from
`ensurePermission()` rather than a flag on it.

`provisional` maps to `granted`, matching `ensurePermission()`; the two must not
disagree about what "we have permission" means.

## Decision 2 — `PushTokenSync` publishes a diagnostic STATE, not a token

The notifier's value changes from `String?` (the token) to a
`PushRegistration` record carrying **both** the token and one of five states:

| state | what it means | who can fix it |
|---|---|---|
| `unknown` | not measured yet — signed out, or no source wired | nobody; it is not a failure |
| `notDetermined` | iOS has never shown the dialog for this install | the app, by prompting |
| `denied` | the user said no, and iOS will not ask again | **the iOS Settings app, and nothing else** |
| `awaitingDeviceToken` | permission is held; no token captured yet | a retry, or time |
| `registered` | the server holds this device's address | nobody; this is success |

**The token stays in the state object rather than being replaced by it.** The
sign-out removal path is a privacy control (ADR-042: a token that outlives a
sign-out delivers the next user's pushes to the previous user's phone) and it
removes *the token it registered*, so that value must not be lost in a refactor
that was about display.

Those five names are chosen so that **each one indicts a different link.** A
state of `awaitingDeviceToken` that persists is exactly the signature of the one
runtime link ADR-042 left UNVERIFIED (Decision 5); `denied` is the one no build
can fix; `notDetermined` on a paired device means the prompt never ran at all.

### Two rules the implementation forced, recorded because they are decisions

**(a) When the capture loop gives up, it ASKS the OS rather than assuming.** The
loop's own log line names two different failures in one sentence — *"the device
has no APNs registration yet, **or** permission was declined"* — and it genuinely
cannot tell them apart. The first implementation emitted `awaitingDeviceToken`
unconditionally, which labels a **declined** phone *"allowed, just not finished
yet"* and offers it a **Try again** button that can never work. That is this
ADR's own defect, reintroduced one level down: a confident wrong label is harder
to doubt than the silence it replaced. One extra `permissionStatus()` read is the
price, and it is also what makes the settled state independent of ordering — a
concurrent `refresh()` that already wrote `denied` is no longer overwritten by
the loop finishing a moment later.

**(b) A late failure never demotes a success.** Two captures can be in flight,
deliberately: `promptForPermissionAndRegister` starts a FRESH run rather than
joining the boot one, because joining would spend the user's tap on a run that
began before the grant and may be on its last attempt. So the boot run can finish
empty *after* the prompt's run succeeded. Every non-success transition therefore
goes through one guard — **if a token is registered, do not emit** — rather than
four call sites each remembering to check. The token is the evidence; nothing
that failed produced better.

## Decision 3 — The state is SHOWN, in Settings, and it is actionable

A `Notifications` row lands in `settings_screen.dart`, directly above the
existing discreet-notifications switch — which is the row it makes sense of. A
"hide notification content" toggle sitting above a phone that receives no
notifications is precisely the kind of confident-but-inert surface this ADR
exists to remove.

The row renders the Decision 2 state in the user's own terms and offers exactly
one action, chosen by state:

* `notDetermined` → **Turn on** (runs the ordinary prompt path);
* `denied` → **Open Settings** (Decision 4) — with copy that says plainly that
  iOS will not ask again, because a button that silently does nothing is how we
  got here;
* `awaitingDeviceToken` → **Try again** (a fresh bounded capture, Decision 5);
* `registered` → no action, and it says so. **Success is stated, not implied by
  the absence of a warning** (lesson 65: absence of evidence is not evidence).

Settings is reachable from the paired home's gear overlay, so this needs no new
route and no new navigation decision.

## Decision 4 — Opening iOS Settings goes through the app's ONE platform channel

ADR-018 D6 established `hayati/device_privacy` as the app's single platform
channel with a single registration site. This adds one method to it —
`openNotificationSettings` → `UIApplication.openSettingsURLString` — rather than
adding a dependency.

**A new package was the obvious alternative and it is the wrong trade.**
`permission_handler`, `app_settings` and `url_launcher` each add a transitive
dependency surface, an advisory-audit obligation (ADR-034) and a plugin
registration, all to wrap one `UIApplication` call this repo already has a
channel for. The channel method is nine lines of Swift, is compiled by
`ios-build-smoke`, and reaches Dart through the same seam
(`ChannelAppIconSwitcher`'s mold) that keeps `flutter test` off the channel
entirely.

The Dart side follows that mold's **fail-direction discipline**: this method
throws on failure so the row can say the OS refused, rather than degrading to
`false` and rendering a button that did nothing.

## Decision 5 — The retry stays BOUNDED, and becomes REPEATABLE

ADR-039 D2 requires every wait on the launch→paired path to be bounded, and
ADR-044 D2's 6-attempt / linear-backoff loop satisfies it. That does not change,
and the worst case stays under 8 seconds, `unawaited`, off the frame path.

What changes is that **exhausting the loop is no longer terminal for the process.**
A fresh bounded attempt may be started by:

* the paired home screen on **resume** — the dominant path back after a user has
  been to iOS Settings, and the screen already observes it for the dayKey
  recompute, so this costs no new observer;
* an explicit **Try again** tap in Settings.

The `_promptInFlight` re-entrancy guard stays exactly as ADR-044 D3 left it: it
stops two **prompts** running at once, and nothing more. Re-asking iOS is cheap —
after the first install-time dialog, `requestPermission()` is a read of the
standing answer.

⚠️ **It must not also guard the capture, however tidy that looks.** Merging the
two into one lock ships a phone that **never shows the dialog**: the boot capture
runs for up to ~7.5s, the paired home mounts inside that window, and a shared
lock makes its `promptForPermissionAndRegister()` return early on every cold
start. Two concurrent captures are merely wasteful; a skipped prompt is the whole
feature. `refresh()` has its own separate guard, and a second `refresh()` JOINS an
in-flight capture rather than starting a duplicate.

**Rejected: an unbounded background retry loop.** It converts a bounded, provable
cost into a timer that outlives every screen, for a device that may genuinely
never produce a token — and ADR-039 D2 exists to forbid exactly that.

## Decision 6 — The APNs device token is forwarded EXPLICITLY, not only by swizzling

`AppDelegate.swift` overrides
`application(_:didRegisterForRemoteNotificationsWithDeviceToken:)` and assigns
`Messaging.messaging().apnsToken` itself, then calls `super`.

**This is the one link in the chain that has never been observed working**, and
ADR-042 named it: this app configures Firebase from **pure-Dart
`FirebaseOptions` with no `GoogleService-Info.plist`**, on a **scene-based
`FlutterImplicitEngineDelegate`** app delegate, and relies entirely on
FirebaseCore's method swizzling to route the APNs callback into
`firebase_messaging`. If that swizzling does not land, `getAPNSToken()` returns
null forever, `isReadyForToken()` is never true, all six attempts fail, and the
observable result is **exactly what production shows today**.

Swizzling is *probably* fine — `FIRAppDelegateProxy` swizzles the delegate class
directly rather than depending on Flutter's plugin forwarding. But "probably"
against a link with a 100%-silent failure mode and a measured zero is not a
posture this repo accepts. The explicit assignment is idempotent with the
swizzled one, costs nothing when swizzling works, and **removes the dependency
entirely when it does not.** It is guarded on `FirebaseApp.app() != nil` so it
cannot fault before Dart has configured Firebase.

`ios-build-smoke` compiles it, which is the honest limit of what this machine can
verify — stated here rather than discovered later.

## Decision 7 — Nothing about background delivery changes

`UIBackgroundModes: remote-notification` stays **absent**. Token capture needs
none of it; only background *delivery* does, and SEC-3 (a locked-device
background read of an `unlocked_this_device` Keychain item) must be decided
first. `signing_sentinel_test` still reddens if it is added.

No new push kind, no change to the hours (ADR-045), no change to the callable
contract or the `fcmTokens` freeze (ADR-042 D1). This ADR touches what the
**device** can see and do about its own registration, and nothing else.

## Consequences

**What this buys.** The four indistinguishable failures become four named,
on-screen states, three of which the person holding the phone can now fix
themselves. If the founder opens build 120 and Settings says *"Notifications are
off — iOS will not ask again"*, that is the answer to a question five sessions
have been unable to ask.

**What it does not buy, stated plainly.** None of this is readable from a
session: the state lives on the device, and no server-visible breadcrumb is added
here. Making the *outcome* of a registration attempt legible to `push_delivery_probe.py`
needs a client-writable diagnostic field, a rules change and a cascade-delete
review (ADR-019), which is a slice of its own and is **filed as an issue rather
than left in prose**. The instrument that already exists —
`push_delivery_probe.py --from-firebase-cli` — still answers the only question
that ultimately matters, *did a device register*, and it answers it without the
founder.

**The APNs `.p8` remains the one unverifiable link.** Google exposes no read-only
API for it (six endpoints tried, 2026-08-11). It is not in this ADR's scope
because it cannot be: it fails only at the moment of a first real send, and
`push_delivery_probe.py --send-test` already names it when it does.
