# ADR-039: The boot always ends in a frame, every wait is bounded, and the invite link points at a host that answers

- **Status:** Accepted
- **Date:** 2026-07-29 (Session 056)
- **Deciders:** founder (the report: *"there is a bug after sign in with apple, loading screen is always on"*, and *"make people invite others with the link"*); session agent (fail-open over fail-silent, the host switch, invite-only publishing)
- **Related:** **ADR-022** (the pre-frame bootstrap this makes fail-open, and the sentinel that still pins it), **ADR-036** (the universal links this repoints), **ADR-023** (the placeholder gate this decouples from invites, without weakening it), **ADR-018 D3** (the lock overlay, audited and left alone), **ADR-014 D2** (RevenueCat's unconfigured mode, which is why its failure has somewhere to land)

## Context

The founder reported a **permanent loading screen** and, separately, that the
invite link was not producing invites. The two are not related, but they share a
shape worth naming: **in both cases the product's failure mode was silence.**

There was no single defect to find. What the audit found instead was a class:
**every blocking wait on the path from launch to paired was unbounded, and every
blocking screen on that path was a dead end.** Any one of them could produce
"the loading screen is always on", and none of them could produce a report a
session could act on.

## Decision 1 — A bootstrap failure produces a screen, never a launch image

`main()` awaits four things before `runHayati` (ADR-022 D1). None of them was
guarded. If any threw — a `Firebase.initializeApp` that will not initialize, a
Pigeon channel that is not up, an App Attest challenge the device refuses — the
throwable escaped `main()`, **`runApp` was never called, and iOS held the launch
storyboard forever**: a centred wordmark on white, no frame, no error, no crash
report (the reporter is *itself* one of the four awaits), and no way out but a
force-quit that starts the same sequence again.

To the person holding the phone that is not a crash. It is *"the loading screen
is always on"* — which is exactly how it was reported, and exactly why it is
unactionable.

Two layers now:

* **The three steps with a meaningful degraded mode fail open where they are.**
  App Check, Crashlytics and RevenueCat each already had a defined
  "unconfigured" behaviour; they now reach it on failure instead of aborting the
  boot. For App Check this is not a judgement call: App Check is a **server-side
  enforcement signal**, so a client that blocks its own boot on token failure
  protects nobody and merely converts *"some requests may be refused"* into
  *"the app never starts"*. Crashlytics downgrades to a `NoopCrashReporter` that
  still **presents** framework errors to the console — a silent no-op would make
  errors vanish from the log on precisely the boots that already went wrong.
* **Whatever is left renders `BootFailureApp`** — honest copy, a retry, and the
  raw throwable behind a collapsed expander. The error is platform text, never
  user content, so the no-content rule is untouched by showing it; showing it is
  the difference between a tester reporting *"it does not open"* and a tester
  reporting something a session can fix. Retry re-runs `main()`, which is safe
  because every step is idempotent by construction.

**ADR-022's sentinel is untouched and still passes.** A `try` block adds no
`await`, so the four pre-frame awaits are still exactly four, still in order,
and still byte-identical between the two entrypoints. The friction ADR-022 D2
built stays built.

## Decision 2 — Every blocking screen carries an exit, and the threshold is not a feel

`SlowLoadEscape` keeps the bare spinner for **8 seconds**, then — *without
removing the spinner* — reveals honest copy and the caller's actions. The
spinner stays because the load has not failed and the app must not claim it has.

Eight seconds is chosen against what it guards, not against a feel: the loads
behind it are a Firestore document listen and an HTTPS GET, both of which land
in well under a second on a working connection, and neither of which gets more
likely to land between second eight and second sixty.

The screen that made this necessary is **`OnboardingGate`** — the first screen
after sign-in. `profileStream` is a Firestore **document** listener, and a
document listener whose target is not in the local cache **raises no event at
all** until the server answers: not an empty snapshot, not an error. So a first
sign-in that cannot reach Firestore left `isLoading` true indefinitely behind a
spinner with no retry, no error and no sign-out.

It now offers retry **and sign-out**. Retry alone assumes the fault is
transient; a user whose session is somehow unusable needs the door too, and
every other blocking surface in this app already has one.

## Decision 3 — The interactive sign-in is bounded, and a late success is not lost

`AuthSigningIn` was only ever left by the sign-in future completing, and that
future crosses a native authorization sheet and a Firebase credential exchange —
neither guaranteed to call back. Worse, while it was in flight the manual-op gate
**suppressed the repository stream**, so nothing else could rescue the state
either.

Bounded at **two minutes**, because the clock covers a *human*: reading the
sheet, typing an Apple ID password, waiting for a 2FA code on another device.
Any bound short enough to feel responsive would cancel real sign-ins. The bound
exists to end an infinity, not to be prompt.

The timeout is typed **`AuthNetworkException`**, so the error view says *"Check
your connection and try again"* rather than the generic line — a sign-in that ran
two minutes without a verdict is overwhelmingly connectivity, and that is the one
piece of advice that is both honest and actionable.

**The load-bearing half:** the timeout does not cancel the sign-in, it releases
the manual-op gate. If the session lands after the deadline, the now-unsuppressed
stream puts the user straight into the app from under the error view, with no
second tap. That claim has a test.

## Decision 4 — The one request in the app with no deadline gets one

The zero-auth invite preview is a plain `package:http` GET, and `package:http`
applies **no timeout of its own** (the callables get one from the Cloud Functions
SDK). A **stalled** connection — a captive portal, a half-dead cellular handover
— raises neither `SocketException` nor `ClientException`; the future simply never
completes. That spinner is the **invitee's first screen**, and its AsyncValue has
auto-retry disabled, so it stayed up until the app was killed. Bounded at 15s and
mapped to the network taxonomy, which lands the user on the retry view that
already existed.

## Decision 5 — Invites are built on a host that answers, and every host we serve is parsed

Measured, not assumed:

```
ikimiz.beyondkaira.com  ->  161.97.172.146   (the founder's VPS; TLS cert covers
                                              the apex only -> certificate error)
ikimiz.web.app/i/<code> ->  404              (Hosting site exists, live channel
                                              never deployed)
AASA                    ->  served nowhere   (so universal links are inert)
```

**Every invite link the app has ever emitted lands on a browser security
interstitial.** That is worse than no link: a red warning screen is what the
invitee sees at the exact moment they are deciding whether to trust the product
their partner just recommended.

So links are now built on **`ikimiz.web.app`** — Firebase Hosting's default
domain for the *same site*, with the same content, the same AASA and the same
`/i/**` rewrite. TLS is issued and renewed by Google and it needs no DNS record
from anybody. A working link on a plainer host converts an invite; a prettier
host that throws a certificate warning does not.

The custom domain is **not abandoned** — it stays a first-class *parsed* host, as
does `ikimiz.firebaseapp.com`, so links already sent keep working and the DNS
cutover is one boolean (`kInviteLinkUsesCustomDomain`) rather than a migration.
The parsed set stays **closed**: any site can serve the `/i/<code>` path shape,
so membership in that set — not the path — is what makes a URL an invite. The
entitlement claims both hosts, mirroring it.

## Decision 6 — `--invite-only` decouples publishing invites from a legal blank, without weakening the gate

The site builder refused to publish anything while a legal document still read
*"to be completed by the founder"*. Correct — and it had a cost nobody had
priced: **the invite link in every shared message resolves to that site**, so a
blank about the founder's legal name was silently holding the product's entire
word-of-mouth loop hostage.

`--invite-only` is **not an exception to the gate**. The gate's rule is "do not
PUBLISH a legal document that still has a blank in it"; an invite-only build
publishes no legal document at all — invite page, AASA, index, 404, and nothing
under `/privacy` or `/terms`. The rule is satisfied by construction, and the
placeholder check is not consulted because there is nothing to check. The two
flags are refused together, because `--allow-placeholders` would have nothing to
allow.

Unlike `--allow-placeholders`, it is deliberately **not gated on the channel**.
Going live with the invite surface while the blanks are open is the *point*.

Two details the same reasoning forced: the index and page footer stop linking
`/privacy` and `/terms` in this mode (a 404 reached from the site's own
navigation reads as a broken product), and the invite page's **`Get ikimiz`
button is conditional on the App Store id being real** — while the app is
TestFlight-only, `id0000000000` is a 404, and a dead button on the one page an
invitee ever sees is worse than no button. An unset id renders honest beta copy
instead.

## Decision 7 — Memoize `hayatiTheme`

Not a micro-optimisation. The app root calls it from `MaterialApp.builder`, which
sits **above the Navigator** and therefore rebuilds on every route push and pop.
Each call built a fresh `ThemeData` — a large graph including a full `TextTheme`
— and handed that **new instance** to the `Theme` wrapping the whole app.
`Theme` notifies dependents on instance inequality, so every widget that had ever
called `Theme.of(context)` — nearly all of them — was rebuilt by a push that
changed nothing about the theme. The cache is bounded by construction: the keys
are resolved locale language codes, of which there are three.

## What was deliberately NOT done

* **The App Attest entitlement was not added.** Prod activates
  `AppleAppAttestProvider` while `Runner.entitlements` deliberately omits
  `com.apple.developer.devicecheck.appattest-environment`, so prod attestation
  cannot succeed today. That is a real inconsistency — but adding an entitlement
  changes what the provisioning profile must contain, and `match` runs readonly
  (ADR-032), so a wrong guess turns a signing failure into the *next* mystery.
  Decision 1 makes the current state harmless (activation failure no longer
  blocks the boot); the entitlement is an operator-coupled change and is recorded
  in `operator-expected.md` next to the Associated Domains item it would share a
  portal visit with.
* **The shield overlay was audited and left alone.** `PrivacyGuard` raises an
  opaque cover on `inactive` and drops it on `resumed`, which is a stuck-cover
  risk if iOS ever skips `resumed`. It is not this bug — the cover is a plain
  dark fill with no spinner, which nobody would call a loading screen — and
  ADR-018 D3's lifecycle reasoning should not be edited on a hunch.
* **Nothing was deployed.** Every change here is code. Publishing the site and
  moving DNS are outward-facing actions and stay the founder's call.
