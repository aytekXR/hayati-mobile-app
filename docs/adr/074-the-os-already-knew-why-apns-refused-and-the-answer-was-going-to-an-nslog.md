# ADR-074: The OS already knew why APNs refused, and the answer was going to an `NSLog`

- **Status:** Accepted — **and it does not make push work.** It makes the reason
  for push not working *nameable*, which is the thing four sessions and six builds
  could not obtain. The distinction is stated in D5 rather than left for a reader
  to discover.
- **Date:** 2026-09-06 (Session 101)
- **Deciders:** session agent, on the founder's instruction to fix the
  notification problem. **Nothing is deployed and no release is dispatched** — this
  lands on `main` and rides the next build.
- **Related:** **ADR-049** (the device self-report this extends — D2's vocabulary,
  D9's cross-language parity), **ADR-044** (the bounded capture whose exhaustion
  this splits in two), **ADR-046 D6** (the success twin of the callback added
  here), **ADR-042 D2** (the port seam), **ADR-018 D6** (the one platform
  channel), **ADR-039 D1** (fail-open: a diagnostic must never cost a frame),
  issues **#219**, lessons **65**, **78**, **135**

## Context — measured 2026-09-06, in production, with the founder's own phone

Build 120 reached TestFlight on 2026-09-04. On 2026-09-06 the founder installed
it, granted the notification permission, answered the day's question, and their
partner answered ninety seconds later. **The backend did everything correctly and
nobody's phone made a sound.**

```
13:26:10Z  answer_reveal  decision=one-answer  push={kind:partnerAnswered, status:no-tokens, sentCount:0}
13:27:56Z  answer_reveal  decision=revealed  streakApplied=true
                          push={kind:reveal,          status:no-tokens, sentCount:0}
```

`registerPushToken`: **"No log entries found."** The callable has never been
invoked, by anyone, ever. `push_delivery_probe.py`: **0/4 accounts have
registered a device.** And ADR-049's diagnostic — shipped in build 120, produced
here for the **first time in its life** — carried the founder's phone's own
account of itself:

```
lvny6fJr…: awaitingDeviceToken / captureExhausted — 2026-09-06T13:24:56.356Z
```

So: **the tap worked**, permission is held, and ADR-044's bounded capture ran to
its end with no token. APNs did not hand this app an address.

### What was ELIMINATED, so the next reader does not re-derive it

Each of these was measured today, not inherited from a comment:

| suspect | measurement | verdict |
|---|---|---|
| the App ID lacks Push Notifications | `appid-capabilities.yml`, run 34038316432: `ok PUSH_NOTIFICATIONS` | **ticked** |
| `aps-environment` is not declared | `Runner.entitlements` carries `production`; build 120 **codesigned**, which it could not have done against a profile lacking the entitlement | **declared** |
| FCM auto-init is off, so nothing ever calls `registerForRemoteNotifications` | no `FirebaseMessagingAutoInitEnabled` and no `FirebaseDataCollectionDefaultEnabled` in `Info.plist` (both default YES); `FLTFirebaseMessagingPlugin.m` calls it at plugin init under `isAutoInitEnabled` | **on** |
| the APNs `.p8` was never uploaded to Firebase | — | **not implicated here**, see D4 |

### The defect, and it is one line of vendor code

`registerForRemoteNotifications` has **two** outcomes, and iOS reports them on
two different delegate callbacks. This project implements one of them.
`AppDelegate.swift` has carried `didRegisterForRemoteNotificationsWithDeviceToken`
since ADR-046 D6 — deliberately, with a page of reasoning about swizzling. Its
sibling, `didFailToRegisterForRemoteNotificationsWithError`, **appears nowhere in
this repository**; `grep` across `docs/` and `app/` returns nothing.

The only handler in the process is the plugin's, at
`FLTFirebaseMessagingPlugin.m` (firebase_messaging 16.5.0):

```objc
- (void)application:(UIApplication *)application
    didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
  NSLog(@"%@", error.localizedDescription);
}
```

**An `NSLog` on a TestFlight build reaches nobody.** It is not a crash report,
not a Crashlytics record, and not readable from any machine a session can touch.

So the single most useful fact about a dead notification chain — *did APNs say
**no**, or did it say **nothing***? — was being computed by the operating system,
handed to the application, and discarded. Both outcomes then collapsed into
ADR-049's `captureExhausted`, which reports "the loop ended with no token"
honestly and **cannot tell them apart.** Their remedies are opposite: a silence
means wait and retry; a refusal means the signed entitlement is wrong and no tap,
reinstall or retry will ever repair it.

⚠️ **This is recurring shape 1 wearing its other face.** The repo's usual defect
is a green signal that measured nothing. Here the signal was accurate and
*insufficiently resolved* — `captureExhausted` was never wrong, it was one bit
short, and that missing bit is the difference between "wait" and "ship a build".

## Decision 1 — `PushDiagnosticDetail` gains a fifth member, and `captureExhausted` narrows

`apnsRegistrationRefused`: permission is held and **iOS actively refused** —
`didFailToRegisterForRemoteNotificationsWithError` fired.

It **outranks** `captureExhausted` wherever both could apply, on the rule ADR-049
already set for `permissionUnreadable`: *a refusal is a statement; an exhausted
loop is the absence of one, and the sharper statement wins.*

`captureExhausted` keeps its name and loses half its territory. It now means what
it always should have: **APNs was asked and stayed silent.** The vocabulary is
closed and lives in three places — the Dart enum, `firestore.rules`, and the
enumeration inside `firestore-rules.test.ts`. ADR-049 D9's parity test holds the
first two equal; **nothing held the third**, so a member added to both guarded
copies would have been a rule nobody ever proved a client could write. All three
are updated and that gap is now recorded rather than rediscovered.

## Decision 2 — The enum travels to the server; the OS's sentence stays on the device

`error.localizedDescription` is the actionable half — the classic value is
`no valid 'aps-environment' entitlement string found for application`, which
names the fault outright. It is **not written to Firestore.**

The stored vocabulary is closed by construction (ADR-049 D9) and an arbitrary OS
string is not a member of it; widening `pushDiagnostic` to carry free text would
mean a new rules clause, a new export projection, and a field whose contents no
test can pin. So the string is `debugPrint`ed — reachable by anyone with the
phone attached, which is exactly who can act on an entitlement fault — and the
**enum** carries the part a session can read remotely.

**One bit crosses the wire and the sentence stays home.** That is the smallest
change that makes the failure nameable, and D5 is honest about what it costs.

## Decision 3 — The refusal is read ONLY on the granted branch, and it has its own guard

Two rules, both of which are corrections waiting to happen:

**(a) Only when permission is held.** ADR-049 attached `captureExhausted`
exclusively to the granted branch because a declined phone's exhausted loop
merely restates the refusal — and a boot capture finishing a second late would
overwrite a stored `denied + permissionRequestRefused`, the single most valuable
fact the field can hold. The same argument applies unchanged to the new member,
so the read lives inside `case PushPermission.granted:` and a declined phone
never even **asks**. Pinned by a test that asserts the call count is zero.

**(b) A throw here must not be blamed on the permission seam.** The enclosing
`try` in `_stateForCurrentPermission` maps any escape to `permissionUnreadable`
— a claim about a link two hops away. A missing native half (an older binary, a
test harness with no platform) would therefore report a broken permission read.
`_apnsRefusal` has its own guard and degrades to the honest `captureExhausted`.
**That is ADR-049's own defect one level down, and it is pinned by a test.**

The `switch` **expression** became a `switch` **statement** to make room for the
await. Exhaustiveness is preserved deliberately: a sixth `PushPermission` must
break this file rather than fall through to a `default` nobody wrote.

## Decision 4 — The probe stops pointing at the `.p8`, because that suspect was wrong

`push_delivery_probe.py` glossed `captureExhausted` as *"Suspect the .p8 upload
or the swizzling ADR-046 D6 hardened."* **The `.p8` half is a misdirection and
this ADR removes it.**

The APNs *device* token is minted by Apple **to the device** in response to
`registerForRemoteNotifications`. Firebase's APNs Authentication Key governs
whether FCM's **servers** may talk to APNs on our behalf; it has no part in
whether a phone gets an address. A missing `.p8` surfaces at **send** time as
`THIRD_PARTY_AUTH_ERROR` — which this same tool already maps correctly, one
dictionary up.

⚠️ **The tool's own text sent the next reader to the wrong link**, and it was
about to send this session there too. Recorded because a diagnostic that
misdiagnoses is worse than one that says nothing (lesson 65's cousin): it spends
the reader's confidence.

## Decision 5 — What this does NOT do

**It does not deliver a notification.** No line here makes APNs answer. If the
refusal is an entitlement fault, this change tells us so and the fix is a
separate build; if APNs is merely silent, this change says that too and the
remedy is unchanged.

That is the whole trade and it is worth stating plainly, because "fix the
notification problem" was the instruction and this is not a fix in the sense the
sentence invites. **What it removes is the loop the project has been stuck in
since build 115:** ship, tap, nothing, guess, ship. The next build either names
the fault or eliminates a suspect — and either outcome is progress that the
previous six builds could not produce.

⚠️ **It is also unverifiable from here.** No Mac, no device, no `flutter` on this
box. Swift correctness rests on `ios-build-smoke` compiling this file on every PR
(ADR-046 D6's stated reason a Swift change is safe from Linux), and `super` is
called on evidence rather than habit: `FlutterAppDelegate.mm:107` implements this
selector and forwards it through `FlutterPluginAppLifeCycleDelegate` to every
registered plugin — read from the engine source, not assumed from the sibling.

## Consequences

**Positive**

- *"Nothing arrived"* stops being one symptom with four causes; the two that
  present identically at the device are now distinguishable **remotely**, which
  is the constraint that made this expensive.
- ADR-049's instrument produced its first real report and immediately earned its
  extension — the vocabulary was one member short, and only a live failure could
  have shown which member.
- A third, unguarded copy of the closed vocabulary is found and fixed.
- The probe stops naming a suspect that cannot cause the symptom it is attached
  to.
- Four candidate causes are eliminated **by measurement** and written down, so
  the next session inherits a narrowed field instead of the full one.

**Negative / accepted trade-offs**

- **The OS's sentence does not leave the device.** A session reading the report
  learns *that* APNs refused, not *why*, and the why needs someone with the phone
  and Console.app. Accepted over widening a closed vocabulary; revisit only if a
  refusal is observed and the enum proves insufficient.
- **Nothing here is verified against a device.** Every claim about APNs behaviour
  is read from vendor source or from Apple's documented contract. The first real
  exercise is, again, a release.
- **A refusal that clears itself is reported as a refusal until the app relaunches
  or APNs answers.** The success twin clears the flag, but a phone that refuses
  and then never registers keeps the stale-free state only because the value is
  never persisted across launches.
- **The founder's phone is still not reachable**, and item 4 does not close. What
  closes is the ambiguity about why.
