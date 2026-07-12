# ADR-018: Device-privacy layer — root lock gate (PIN + biometric), always-on snapshot shield, discreet alternate icon, first settings surface

- **Status:** Accepted (rev 2 — pre-code adversarial review folded in; see the
  review record at the end)
- **Date:** 2026-07-12 (Session 020)
- **Deciders:** engineering session, per PRD F6 + implementation-plan M6
- **Related:** ADR-016 (coach safety spine — DV posture precedent), ADR-017
  (coach chat UI — the snapshot-obscuring deferral this ADR closes; the
  `LocalFlagStore` seam precedent), ADR-012 (discreet push payloads — the
  notification half of discreet mode), ADR-014 (gate-widget precedent),
  ADR-009 (the clock seam the grace window reuses), ADR-006 (iOS-first —
  Android halves ride M6.5)

## Context

**The product spec.** PRD F6: *"PIN/biometric app lock; discreet mode
(alternate innocuous icon + neutral notification text); notification privacy
defaults ON in AR locale. This is a headline feature, not a setting."* The
notification-text half shipped in M3.4 (locale-derived, ADR-012); this ADR
delivers the lock, the icon, and the settings surface — plus the app-switcher
snapshot obscuring that ADR-017 Decision 3 explicitly deferred here.

**The threat model is a partner holding the phone.** This is a DV-aware
product on shared devices (ADR-016 D7, ADR-017 Context). The adversary is not
a forensic lab: it is a person with physical access, the user's trust, and
possibly knowledge of the user's habits. The protections that matter at this
tier: couple content is not one glance away (the lock + the shield), and the
app's home-screen *icon* can be made innocuous (the discreet icon — the
home-screen NAME label cannot be changed at runtime; that bound is recorded
in Decision 6). Protections this layer deliberately does NOT claim:
resistance to device forensics, jailbreak, an adversary who knows/coerces the
PIN — **or an adversary who can re-authenticate as the user on this same
device** (Decision 4 records that residual honestly). Those bounds are stated
where they arise.

**What the codebase gives us (session 020 scout findings):**

- `HayatiApp` (`app/lib/app.dart`) is the only always-mounted widget: one
  `MaterialApp`, `home: SignInScreen()`, no route table. Signed-in routing is
  a synchronous widget swap (`SignInScreen` → `OnboardingGate` → homes), and
  every screen beyond that is an imperative `Navigator.push`. **Every
  background-event navigation in the app is a POP** (auth-loss `popUntil`,
  join-success pop) — nothing ever pushes a route from a listener or timer.
  So a single overlay above the Navigator covers the entire surface: `home`,
  pushed routes, and whatever a deep link renders.
- The cold-start deep link (`hayati://invite/<code>`) never navigates: it
  lands in `pendingInviteProvider` state and `SignInScreen`/`OnboardingGate`
  *render* `PartnerPreviewScreen` reactively. Behind a root overlay, that
  render happens underneath the lock — exactly what we want, provided the
  overlay actually prevents paint and hit-testing (Decision 3).
- `LocalFlagStore` (ADR-017 D4) is one-way STICKY by contract (set-once,
  never cleared) — the lock-enabled state must be clearable, so it does NOT
  fit that seam. A new storage seam is warranted.
- **The reinstall asymmetry (load-bearing):** Firebase Auth persists its
  session in the iOS **Keychain**, which survives app deletion + reinstall.
  `SharedPreferences` does not. A lock-enabled flag in prefs would therefore
  be a delete-and-reinstall bypass: reinstall wipes the flag, the Keychain
  restores the signed-in session, and the app opens unlocked into couple
  content. **The lock record must live in the same persistence domain as the
  session it guards** — the Keychain.
- The app's one clock seam is `soloClockProvider` (misnamed but documented as
  app-wide, ADR-009/M2.4) — the grace window reuses it; tests pin it.
- No platform channel exists anywhere in the app yet; the iOS Runner uses the
  implicit-engine API (`FlutterImplicitEngineDelegate`) + `FlutterSceneDelegate`.
  CI's `flutter build ios --no-codesign` compiles Swift and runs actool, so
  native additions are compile-validated per push; runtime behavior is not
  (no signed device in CI) — those halves go to operator item 4.
- brandkit ships `branding-assets/icons/hayati-appicon-discreet-1024.png`
  (1024², RGBA — icons must be flattened to opaque for actool/App Store).
- The no-content rule (arch §8, ADR-017 D5): Crashlytics is ON in prod and
  the global hooks forward `toString()`s — nothing in the lock layer may put
  a PIN, salt, hash, or attempt detail in an exception message, breadcrumb,
  or `toString()`.

**Alternatives weighed at the top level:**

- *Per-feature gating (lock only coach/answers).* Rejected: the whole app is
  couple-intimate content (PRD positioning); per-feature gates multiply the
  bypass surface and re-litigate "is this screen sensitive" forever. The M5.2
  handoff is explicit: the gate wraps the root.
- *A lock package (e.g. flutter_app_lock, secure_application).* Rejected:
  tiny dependency surface for security-posture code we must be able to
  reason about line-by-line; none fits the Offstage/TickerMode + Riverpod
  shape below; the repo's seam discipline already gives us the test story.
- *Biometric-only lock (no PIN).* Rejected: biometrics are enrollment-mutable
  (a partner can add their face/finger on a shared device) and local_auth
  cannot distinguish whose biometric passed. The PIN is the root credential;
  biometric is an accelerator — and because the SAME enrollment-mutability
  argument applies to the accelerator, enabling it carries an
  enrollment-state invalidation mechanism and an explicit DV warning
  (Decision 1; review finding DVUX-1).

## Decision 1 — The lock model: 6-digit PIN is the credential; biometric is an opt-in accelerator with enrollment-change revocation; the lock is device-scoped and dies with the session

- **Credential:** a fixed-length **6-digit numeric PIN** (iOS passcode
  convention; 10⁶ space is the ceiling any app-level PIN offers — honesty
  about that bound is in Decision 2). Entered on a custom in-app keypad
  (Western digits in all locales, v1 — the iOS AR passcode pad precedent is
  mixed; native review may overrule; dots-only echo). **The keypad is pinned
  `Directionality.ltr` explicitly** — numeric pads are NOT mirrored in RTL
  on any platform; the repo's "logical direction, RTL mirrors free" reflex
  must not reach it (review finding DVUX-6; pinned by the AR golden).
- **Biometric (Face ID / Touch ID) is an accelerator, never the credential —
  and it is a *revocable* accelerator:**
  - It can be enabled only after a PIN exists, from settings, and enabling
    it first shows an explicit **DV warning** the user must acknowledge:
    *"Anyone whose face or fingerprint is saved on this phone can unlock
    Hayati."* This is honest: at enable time the app cannot know whose
    biometrics are enrolled (review finding DVUX-1's recorded residual).
  - **The seam contract pins `biometricOnly: true`** — the authenticate call
    must map to `deviceOwnerAuthenticationWithBiometrics`, never plain
    `deviceOwnerAuthentication`, because the latter offers the **device
    passcode** as a fallback and the phone-holding partner plausibly knows
    the device passcode. A device-passcode side door would defeat the app
    PIN entirely (review finding TEST-1, blocking). The fake cannot surface
    this — the contract line in the seam's doc comment and the real
    adapter's test-pinned argument carry it.
  - **Enrollment-change revocation:** at enable time the app captures the
    platform's opaque biometric enrollment state
    (`LAContext.evaluatedPolicyDomainState`, exposed as bytes through the
    device-privacy channel, Decision 6) and stores it in the lock record.
    On every lock-screen mount, before biometric is offered or auto-prompted,
    the current enrollment state is compared to the stored one; **any
    mismatch (or unavailability) auto-revokes `biometricEnabled`** — the
    record is rewritten with biometric off, the lock screen shows the honest
    one-liner *"Face ID changed on this phone — enter your PIN"*, and
    re-enabling requires the PIN plus the warning again. A partner who adds
    their face/finger AFTER the user enabled biometric therefore gains
    nothing (review finding DVUX-1). What this cannot catch — biometrics
    already enrolled at enable time — is exactly what the warning copy
    carries. Recorded in Decision 8.
  - ANY biometric failure/cancel/unavailability falls back to the PIN keypad
    silently. local_auth 3.x **throws** (`LocalAuthException`) for most
    failures rather than returning false — the real adapter wraps every
    call in try/catch and maps all failures to `false` (review finding
    TEST-4); the seam's bool contract is an adapter obligation, not free
    plugin behavior.
- **Setup happens in settings, signed-in and unlocked only:** enable → enter
  PIN → confirm PIN → written to the Keychain record (Decision 2). Disable →
  verify current PIN → record cleared. No separate change-PIN flow in v1
  (disable→enable covers it; recorded as an accepted gap — a dedicated flow
  is a later nicety, not a security hole, because both paths verify first).
- **The lock is device-scoped, not account-scoped — and it is wiped on
  sign-out.** `AuthSignedOut` (manual or remote) clears the lock via a root
  listener mounted beside the coach teardown in `app.dart`. **The wipe
  mechanism is `store.clear()` plus an in-place state mutation to
  `disabled` — NEVER `ref.invalidate` on the controller** (review finding
  FLUTTER-2): the controller is keepAlive and seeded from the by-value boot
  snapshot, so invalidation would re-run `build()` against the STALE boot
  override and resurrect the boot-time state (re-lock after wipe, or —
  worse — silently revert a just-enabled lock to the boot-time `null`).
  This is a deliberate asymmetry with the coach listener's
  `ref.invalidate(coachTranscriptProvider)`: that family's `build()` returns
  a safe empty state; this controller's `build()` replays boot. No code path
  may invalidate the lock controller.
  Rationale for wipe-on-sign-out: a signed-out app shows only the sign-in
  screen (nothing to protect), a next user must not inherit the previous
  user's PIN (lock-out foot-gun), and "forgot PIN → sign out" (Decision 4)
  stays coherent — sign-out IS the lock reset, one mechanism.
- **Deliberate asymmetry with the coach listener on the trigger too:** the
  coach invalidates on any `next is! AuthSignedIn` (fail-closed = content
  gone); the lock wipes ONLY on `AuthSignedOut` (fail-closed = protection
  stays). An `AuthError` from a failed manual op (e.g. sign-out that threw)
  must NOT silently disable a lock the user believes is on — the DV posture
  governs (S018 rule: the governing doc decides): protection persists
  through error states, content does not.
- **The OWNER/generation guard (the S019 race class, binding M5.2 handoff —
  review finding FLUTTER-3, blocking):** the controller keeps a
  monotonically increasing generation token; `wipe()` bumps it BEFORE
  clearing the store. **Every mutating operation (verify-attempt persist,
  enable, disable, biometric toggle/revoke) captures the generation when it
  starts and re-checks it after EVERY await — before every store write and
  before every state assignment; on mismatch it aborts without writing.**
  `ref.mounted` cannot carry this: the keepAlive controller is wiped in
  place, never disposed, so `ref.mounted` stays true while a
  wrong-PIN-attempt write races the sign-out wipe — without the guard, that
  write re-persists the previous user's `pinHash` after the clear,
  violating the no-inheritance guarantee. Same shape as the coach OWNER
  guard; pinned by a dedicated race test.
- **The lock is auth-agnostic at render time:** the overlay shows whenever
  state is `locked`, regardless of auth (a wipe failure or race can leave a
  locked record with no session; the recovery action on the lock screen is
  idempotent — Decision 4 — so that state is escapable, never a brick).

## Decision 2 — Storage posture: Keychain via flutter_secure_storage, one versioned record, salted hash + constant-time compare, bootstrap-awaited snapshot

- **Where:** the iOS **Keychain** via `flutter_secure_storage` (^10.3.1 —
  verified current, SwiftPM `Package.swift` present, resolves on this SDK),
  `KeychainAccessibility.unlocked_this_device` — the strictest option that
  works for us (the app only reads at foreground launch, when the device is
  necessarily unlocked; `this_device` keeps the record out of iCloud/device
  backups so a PIN never migrates to another phone). Fallback if device
  testing surfaces an access issue: `first_unlock_this_device` (recorded
  here so the relaxation, if ever needed, is a documented one-step). **When
  a background launch mode ever arrives (APNs era, M6.2+), this decision
  must be revisited: a locked-device background read of an
  `unlocked_this_device` item fails and would hit the fail-open path** —
  recorded so M6.2 inherits the check, not the surprise (review finding
  SEC-3). No Keychain Sharing entitlement is needed for the app's own
  default access group on iOS; a device-side Keychain write/read round-trip
  joins operator item 4's checklist anyway (review finding TEST-2).
  Android maps to encrypted-shared-prefs and rides M6.5 with everything else.
- **Why not hashed-in-prefs:** two independent kills — (a) the reinstall
  bypass (Context: prefs die on reinstall, the Firebase session does not, so
  a prefs-resident lock evaporates while the content session survives);
  (b) prefs are plaintext-at-rest inside the app sandbox and land in
  unencrypted local backups, and the acceptance line is explicit: *"no
  secret in prefs plaintext."* The Keychain record survives reinstall
  exactly like the session it guards — the lock and the thing it protects
  now share fate. (Consequence: deleting + reinstalling the app does NOT
  shed the lock. That is the point.)
- **What (one record, one key, versioned):** `privacy_lock.v1` → JSON
  `{version: 1, salt, pinHash, biometricEnabled, biometricEnrollmentState,
  wrongCount, lockoutUntilMs}`. One key so reads/writes are atomic at the
  Keychain-item level and the bootstrap read is a single round-trip.
  `version` gates future migration; an unknown version deserializes to null
  (treated as absent, recorded honestly by a test).
- **Hash honesty:** `pinHash = SHA-256(salt ‖ pin)` with a per-device random
  128-bit salt (`Random.secure()`), compared in constant time (XOR-fold over
  both digests). We deliberately do NOT run an iterated KDF: against an
  attacker who has extracted the Keychain record, a 10⁶ PIN space falls to
  any offline search regardless of iteration count — a KDF here is security
  theater, and we do not claim otherwise. The hash exists so the raw PIN is
  never at rest anywhere (defense against casual disclosure: storage dumps,
  debug tooling, our own future code touching the record). The REAL online
  control is attempt bounding (Decision 4); the real at-rest control is the
  Keychain itself. All of this is stated so nobody later "hardens" the hash
  and believes they changed the threat model.
- **The bootstrap snapshot (synchronous first frame):** `flutter_secure_storage`
  reads are platform-channel async, but the gate must decide the FIRST frame
  (a flash of couple content before an async lock check is a real leak —
  the app-switcher snapshot of that flash doubly so). So the entrypoints
  (`main_dev.dart` / `main_prod.dart`, edited in lockstep) await one read
  before `runHayati` — the `SharedPreferences.getInstance()` idiom — and
  override an `initialLockSnapshotProvider` by value. The lock controller
  seeds `locked`/`disabled` from that snapshot synchronously; no spinner, no
  flash. Widget tests override the same provider with fixture snapshots.
- **The snapshot distinguishes `absent` from `readFailed`** (review finding
  SEC-3): a clean null (no record) seeds `disabled` and is final; a read
  that THREW seeds `disabled` (fail open, below) but marks the snapshot
  degraded — **on the first `resumed` after a degraded boot, the controller
  re-reads the store once and, if an enabled record surfaces, locks
  immediately.** The fail-open is thereby a one-launch exposure that
  self-heals, not a process-lifetime hole.
- **Bootstrap read failure fails OPEN, loudly:** if the Keychain read throws
  at boot (no known path today; device-storage fault), the snapshot is
  degraded-null → lock disabled + a no-content breadcrumb to the crash
  reporter + the resume reconcile above. Fail-closed here would brick the
  app behind a lock screen that can verify nothing — and the user's escape
  (delete/reinstall) doesn't even clear the Keychain, so the brick would be
  permanent. An attacker cannot induce a Keychain read failure without
  device-level compromise (out of threat model). Accepted trade-off,
  recorded.
- **Seam:** `PinLockStore` (`core/storage/pin_lock_store.dart` — interface
  and record only): `Future<PinLockRecord?> read()` /
  `Future<void> write(PinLockRecord)` / `Future<void> clear()`. The real
  impl lives in a **separate file** (`secure_storage_pin_lock_store.dart`,
  the `LocalFlagStore` file-split precedent) so the device-only adapter
  never enters the coverage denominator (review finding TEST-5); tests use
  an in-memory `FakePinLockStore` (recorder-style, failure knobs). The real
  adapter is constructed only in the entrypoints — `flutter test` never
  touches the plugin channel (the M2.2/M4.2 seam precedent).
- **No-content rule:** `PinLockRecord.toString()` renders field PRESENCE
  only (`PinLockRecord(set: true, biometric: false, wrongCount: 3)` — never
  salt/hash/enrollment bytes); no PIN digit ever appears in any exception,
  breadcrumb, or state `toString()` (the `CoachTranscriptState`
  COUNT-not-content precedent). Pinned by a sentinel test.

## Decision 3 — The gate mounts in `MaterialApp.builder`: one Stack, Offstage + TickerMode, grace window on the app-wide clock

- **Placement:** `MaterialApp.builder` (where the theme wrapper already
  sits) is the single point above `home` AND every `Navigator.push` route —
  the scout-verified bypass inventory (all event-driven navigations are
  pops; all pushes are user taps) means nothing can route around it. The
  builder composes:

  ```
  Theme(
    child: PrivacyGuard(          // ConsumerStatefulWidget — owns the
      child: appChild,            // WidgetsBindingObserver (see below)
    ),
  )
  // PrivacyGuard.build:
  Stack(fit: StackFit.expand, [
    TickerMode(enabled: !locked,
      child: Offstage(offstage: locked, child: child)),        // the Navigator
    if (locked) const SizedBox.expand(child: LockScreen()),
    if (shieldOn) const SizedBox.expand(child: PrivacyShieldCover()),
  ])
  ```

  **Full-bleed is pinned, not assumed** (review finding FLUTTER-4): the
  Stack is `fit: StackFit.expand` and both covers are `SizedBox.expand`-ed —
  a loose Stack with a content-sized cover would leave painted app content
  visible around it during `inactive` (when the subtree is NOT offstage),
  leaking into the OS snapshot. A golden/probe test pins the shield
  covering the full 390×844 surface.
- **The lifecycle owner is named** (review finding FLUTTER-6): `HayatiApp`
  is a stateless `ConsumerWidget` and cannot host an observer; the
  builder-mounted **`PrivacyGuard` (ConsumerStatefulWidget) owns the
  `WidgetsBindingObserver`** — always mounted, disposed with the app,
  drivable in tests via `tester.binding.handleAppLifecycleStateChanged`
  (which imposes no transition-validity assertions, so test sequences like
  hidden→paused→resumed are fine). It forwards lifecycle events to the lock
  controller and owns the shield visibility as local widget state.
- **Lock-screen UI hard constraint** (review findings SEC-7/FLUTTER-1): the
  `LockScreen` (and the shield) sit ABOVE the app's only Navigator — they
  have **no Navigator or Overlay ancestor**. Therefore NO
  `showDialog`/`showModalBottomSheet`/`Tooltip`/`Autocomplete`/text-selection
  API anywhere in the lock UI — each would throw, and on the recovery path
  that crash IS the lockout. The recovery confirmation is an **inline
  two-phase widget state** (the keypad column swaps for a confirm panel —
  scrim + card drawn by the LockScreen itself). This is distinct from the
  settings screen's PIN-verify dialog, which is pushed INSIDE the Navigator
  and may use `showDialog` normally (Decision 7).
- **Offstage, not just paint-over:** while locked the app subtree is
  `Offstage` — it keeps ALL state (Navigator stack, form fields, providers)
  but does not paint and cannot be hit-tested. Not painting matters twice:
  the locked screen itself can be snapshotted by the OS, and an opaque
  overlay above a painted subtree still rasterizes the content beneath it.
  (Offstage also drops the subtree from the semantics tree, closing
  VoiceOver readback of gated content — a bypass a paint-over cover would
  have left open.) `TickerMode(enabled: false)` freezes animations below
  (also keeps `pumpAndSettle` from hanging on spinners behind the lock in
  every widget test that boots locked). Deep links while locked still land
  in `pendingInviteProvider` (state, not navigation) and render offstage —
  captured, invisible, untappable; `flutter_test`'s default
  `skipOffstage: true` makes the bypass assertions read naturally
  (`findsNothing` while locked), and the commitments pair every such
  negative with an unlock→reveal positive control so the assertion can
  never pass vacuously (review finding TEST-3).
- **When it locks:**
  - **Cold start:** bootstrap snapshot says enabled → first frame is the
    lock screen. Grace state is in-memory only, so cold start ALWAYS locks.
  - **Background return:** `PrivacyGuard` records `backgroundedAt` on
    `AppLifecycleState.paused` **or** `.hidden` (hidden fires before paused
    on iOS; either alone is enough) and on `.resumed` re-locks iff
    `now − backgroundedAt > 60s`, `now` from `soloClockProvider` (the app's
    one clock seam — tests pin it). **`.inactive` does NOT start the grace
    clock:** control-center pulls, notification-shade peeks, permission
    dialogs, the share sheet, and the biometric prompt itself all pass
    through inactive without leaving the app; locking on it would fight the
    user (and the biometric flow). Inactive only raises the shield
    (Decision 5).
  - **60 seconds, fixed:** sized for the real paused flow — switching to
    Messages/WhatsApp to paste an invite code or reply, then returning.
    (The share sheet does NOT need grace at all: it presents in-app and
    only reaches `.inactive` — review finding SEC-5.) Long enough for an
    app switch, short enough that a phone left on a table re-arms. Not
    user-configurable in v1 — a config surface on a security timing is
    scope without evidence; revisit on founder feedback.
- **Wall-clock caveat, recorded honestly:** the grace comparison and the
  cooldown deadline (Decision 4) use wall time. A phone holder who changes
  the device clock **forward** does not merely stretch the exposure — a
  forward jump *elapses* any grace or cooldown immediately (review finding
  SEC-4). For grace this is bounded (they hold a phone whose lock has not
  yet re-armed); for cooldowns see Decision 4's honesty note. No persistent
  monotonic clock exists across process death; accepted and stated.
- **Lock state is a keepAlive Riverpod controller**
  (`privacy_lock_controller.dart`): states `PrivacyLockDisabled` /
  `PrivacyLocked{lockoutUntilMs?, biometricRevoked?}` / `PrivacyLockUnlocked`.
  Manual-op discipline per the repo idiom (re-entrant ops dropped,
  `ref.mounted` after every await) PLUS the generation guard from Decision 1
  (which `ref.mounted` cannot replace on a keepAlive controller). The root
  `app.dart` listeners gain: the sign-out wipe (Decision 1); the lifecycle
  wiring lives in `PrivacyGuard`.

## Decision 4 — Attempt bounding + recovery: persisted counter, escalating cooldown, sign-out-first recovery that never drops the lock early

- **Counter and cooldown live IN the Keychain record** (`wrongCount`,
  `lockoutUntilMs`) — killing and relaunching the app does not reset them
  (an in-memory counter would be "unlimited attempts, 5 per restart").
- **Write ordering is pinned** (review finding SEC-4B): on a wrong attempt
  the incremented record is **persisted FIRST — awaited — and only then is
  the verdict shown**; a kill in the window between keypress and
  acknowledgment therefore lands on the incremented side, never the free
  side. (Generation-guard check before the write, per Decision 1.)
- **Schedule:** attempts 1–4 free; 5th wrong → 30s cooldown; 6th → 1 min;
  7th and beyond → 5 min each. Cumulative until a successful unlock resets
  `wrongCount` to 0. During cooldown the keypad is disabled with
  **tier-accurate copy** — "about 30 seconds" / "about a minute" / "about
  5 minutes" as three distinct ARB strings (a single "about a minute" would
  understate the 5-minute tier 5×, an over-claim the honest-states rule
  forbids — review finding DVUX-5). No data is ever destroyed by failed
  attempts (a wipe-after-N would hand a destruction button to exactly the
  wrong person in a DV context).
- **Cooldown honesty:** against a holder who never touches the clock,
  ~10 attempts/hour at the 5-min tier ≈ years for 10⁶. Against a holder who
  sets the clock forward, **the cooldown delay is nullified** (each jump
  elapses the deadline) and the bound degrades to manual entry speed on a
  keypad with no automation surface — ~10⁶ hand-typed entries, i.e. days of
  uninterrupted physical possession, at which point the threat model has
  already failed upstream. Stated plainly so nobody reads the cooldown as
  clock-tamper-proof (review finding SEC-4A).
- **Recovery — "Forgot PIN? Sign out" — signs out FIRST and never drops the
  lock on hope** (review finding DVUX-3): always visible on the lock
  screen; inline confirm (Decision 3's no-dialog constraint), then the flow
  is strictly:
  1. call `signOut()` **while the overlay stays `locked`**;
  2. the root listener observes `AuthSignedOut` → wipes the record
     (generation bump + `store.clear()`) → state `disabled` → the overlay
     drops onto the sign-in screen.
  If sign-out THROWS (offline, plugin error → `AuthError`), nothing was
  wiped, the overlay is still locked, and the lock screen shows the honest
  retry line ("Couldn't sign out — check your connection and try again").
  The previous rev's wipe-then-sign-out ordering had a real hole — wipe
  succeeds, sign-out throws, overlay drops on a still-signed-in app =
  couple content painted; the reversed ordering plus Decision 1's
  wipe-only-on-`AuthSignedOut` rule closes it, and it also removes the
  success-path flash (the overlay never comes down before the auth state
  actually changes.)
  Data is server-side; the coach transcripts are already torn down by the
  existing root listener on sign-out; signing back in re-proves identity to
  Firebase. The action is idempotent and works when already signed out
  (Decision 1's orphaned-record edge): it wipes and lands on the sign-in
  screen either way.
- **The recovery residual, recorded honestly (review finding SEC-1 — the
  over-claim this rev deletes):** rev 1 claimed recovery is "never a
  bypass" because identity re-proof through the real auth stack is the only
  path. The narrow claim stands — there is no side door, no support unlock —
  but on THIS threat model it must not be read as protection: **the
  phone-holding partner can complete same-device re-auth themselves** (the
  SMS OTP arrives on the very SIM they hold and iOS auto-fills it; the
  device's Apple ID re-auths with the device passcode they may know). App-
  level friction cannot close this — any recovery that keeps the rightful
  user un-bricked is exactly as available to whoever holds their unlocked
  identity anchors. What the design DOES guarantee: recovery is
  **destructive and detectable** — it signs the session out and wipes the
  PIN, so the owner discovers it at next use (a signed-out app + a lock
  that is gone), unlike a silent snoop. The lock's honest promise is
  therefore: *casual/opportunistic access is blocked; identity-anchor
  holders can force their way in, but not silently.* Recorded in Decision 8
  and the Consequences; the settings copy must not promise more.

## Decision 5 — Snapshot shield: always-on, pure Dart, NEUTRAL cover, in the same Stack — closing the ADR-017 deferral

- **What:** an opaque **neutral** cover (`PrivacyShieldCover`: the plain
  night background color, NO brand mark, no content) rendered full-bleed as
  the TOP Stack layer whenever the lifecycle is `inactive`, `hidden`, or
  `paused`. Shown by `PrivacyGuard`; hidden on `resumed`. The cover is
  deliberately brand-free (review finding DVUX-4): the app-switcher card is
  a surface a snooping partner scans, and painting the Hayati brand mark
  there would re-identify the app for a user who chose the discreet icon —
  content-hiding must not trade for identity-leaking. (iOS switcher chrome
  shows the app name beside the card regardless — recorded in Decision 6's
  honesty bound; the shield just avoids ADDING identification.)
- **Why pure Dart, no platform channel:** on iOS, Flutter keeps rendering
  through `inactive` (rendering stops at paused/hidden) — a cover raised on
  `willResignActive`→`inactive` is painted before the system images the view
  for the app switcher, and the switcher's live card during the swipe
  gesture shows the cover too. This is the established pure-Dart approach;
  it is fully widget-testable (`handleAppLifecycleStateChanged`), it costs
  zero native code, and it carries to Android/M6.5 unchanged. A native
  belt-and-suspenders (`sceneWillResignActive` UIView cover in
  `SceneDelegate`) is deliberately NOT shipped in v1: it duplicates the
  mechanism behind an untestable seam, and its trigger fires at the same
  lifecycle moment. **The escalation path is recorded:** if the operator
  item-4 device check ever catches app content in the switcher (a timing
  gap between the engine's last presented frame and the snapshot), the
  SceneDelegate cover is the known fix, filed as debt then — not silently.
- **Why ALWAYS-ON (not a toggle, not per-surface):** ADR-017 asked for the
  coach surface "ideally any content surface" — but every surface past
  sign-in is couple-intimate (the daily answer on the paired home is exactly
  as sensitive as a coach reply), a per-surface list re-litigates forever,
  and a toggle is a way to have it off. Always-on costs one visual: the
  cover flashes behind system sheets that drive the app inactive (the share
  sheet on the invite flow, permission prompts, the biometric dialog). The
  banking-app precedent says users read that flash as "private app working
  as intended"; accepted trade-off, recorded. No settings entry for it.
  (This is universal lifecycle behavior for ALL users including free tier —
  the "free tier untouched" acceptance claim is scoped to foreground flows
  and behavior, which are unchanged; the carve-out is stated in the test
  commitments so the claim stays exactly true — review finding DVUX-8.)
- **Scope honesty:** the shield covers the OS snapshot exposure. It does NOT
  scrub process memory (ADR-017's recorded residue stands) and does not
  claim anything about screenshots taken by the user themselves (iOS offers
  no app-side screenshot block; screen-capture detection is out of scope).

## Decision 6 — Discreet alternate icon: the app's first platform channel, behind a seam; asset-catalog alternate icons; honest bounds; the notification override stays server-side and deferred

- **Dart seam:** `AppIconSwitcher` (`features/settings/domain/`):
  `Future<bool> supportsAlternateIcons()` / `Future<bool> isDiscreet()` /
  `Future<void> setDiscreet(bool)`. Real impl `ChannelAppIconSwitcher` (in
  its own `data/` file, coverage-separated per Decision 2's precedent) over
  the app's FIRST MethodChannel — **one channel, `hayati/device_privacy`**,
  carrying all four native methods this layer needs:
  `supportsAlternateIcons` / `getAlternateIconName` /
  `setAlternateIconName` / `biometricEnrollmentState` (Decision 1's
  revocation input). One channel = one native registration site, one seam
  discipline. `FakeAppIconSwitcher` + `FakeBiometricAuthenticator` for
  tests (recorder + failure knobs). Providers overridden in the entrypoints
  (both, lockstep), unimplemented at base — the repository-seam discipline.
- **Native half (Swift, ~50 lines):** channel registered in
  `didInitializeImplicitFlutterEngine` via
  `engineBridge.pluginRegistry.registrar(forPlugin:)`'s messenger (verified
  compilable surface; CI compiles it); icon methods call
  `UIApplication.shared.setAlternateIconName(_:completionHandler:)` on the
  main thread and return the error message through the channel result;
  `biometricEnrollmentState` returns
  `LAContext.evaluatedPolicyDomainState` bytes (after a
  `canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics)` probe) or
  null. iOS shows its own system alert on icon change — expected,
  user-initiated, not suppressed (no private API — App Store safety).
- **Assets:** a second icon set `AppIconDiscreet.appiconset` in
  `Assets.xcassets` — single-size 1024 (Xcode 14+ single-size icons; CI
  pins Xcode 16.4), flattened to opaque RGB from
  `brandkit/branding-assets/icons/hayati-appicon-discreet-1024.png` (the
  source is RGBA; icons must not carry alpha). Wired with
  `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES = AppIconDiscreet` in all
  three build configs (asset-catalog alternate icons are supported since
  Xcode 13 — actool emits the `CFBundleIcons` plumbing into the built
  product; the hand-written source Info.plist stays untouched). Primary
  `AppIcon` untouched. **Fallback recorded (the resume-prompt stopping
  condition):** if CI's actool rejects this shape, ship the seam + toggle
  with the asset half deferred loudly to the Mac slice — the Dart/settings
  code does not change either way.
- **Honest bounds of discreet mode, recorded (review finding DVUX-2):**
  `setAlternateIconName` changes the icon IMAGE only. **The home-screen
  name label — `CFBundleDisplayName`, currently "Hayati App" — has no
  runtime API and does not change**; it also appears in Settings, Spotlight,
  the app switcher chrome, and the icon-change system alert itself. The
  settings row is therefore honestly labeled "Discreet app icon" (never
  "hide the app"), and the enable flow's subtitle carries the bound ("the
  app's name still appears under the icon"). Whether the *shipped* display
  name should itself be less identifying is a founder/product call that
  belongs to the M6.3 store-metadata pass — flagged in operator-expected,
  not decided here. Two further inherent leaks, recorded: the icon-change
  system alert momentarily names the app to anyone watching, and the
  settings row's on-state is itself evidence of deliberate concealment to
  someone already past the lock.
- **CI-safe by construction, device-verified later:** `flutter build ios
  --no-codesign` compiles the Swift and runs actool over the new icon set —
  the compile/asset surface is CI-gated. What CI cannot prove (the icon
  actually swapping on a home screen, the system alert copy, the Keychain
  round-trip, `evaluatedPolicyDomainState` behavior across enrollment
  changes) joins operator item 4's on-device checklist.
- **The notification-text override is DEFERRED to M6.2, loudly.** PRD F6's
  discreet mode includes neutral push text; M3.4 shipped it locale-derived
  (`resolveDiscreet = contentLanguage == 'ar'`) with a documented server
  seam for a per-user override (`recipients.ts`). Wiring a per-user setting
  end-to-end needs a `users/{uid}` field + the settings-Function path that
  architecture §3 reserves for such fields + `resolveDiscreet` reading it —
  a functions change in a session whose functions posture is
  untouched-green, for a notification system that has no device half yet
  (APNs is item 4). It lands in M6.2 beside the other Functions work. Until
  then the icon toggle controls the icon; AR-locale users keep discreet
  pushes by default (shipped; and per ADR-012 D3 no payload in ANY mode
  ever contains question/answer text — the non-discreet TR/EN exposure is
  partner-name + event kind, not content). Recorded here, in the
  implementation plan, and in operator-expected.

## Decision 7 — The settings surface: one screen, four rows, a state-independent gear on both homes

- **`SettingsScreen`** (`features/settings/presentation/`), pushed via the
  exported-helper convention (`showSettings(context, uid:)`), one screen:
  1. **App lock** — off: "Set up PIN" → `PinSetupScreen` (enter → confirm →
     enabled); on: "Turn off" → PIN verify → cleared. (These dialogs live
     INSIDE the pushed settings route, below the Navigator — `showDialog`
     is legitimate here, unlike on the lock screen; Decision 3.)
  2. **Unlock with Face ID / Touch ID** — visible only when the lock is on
     AND `BiometricAuthenticator.isAvailable()`; enabling shows the DV
     warning (Decision 1), captures the enrollment state, then toggles
     `biometricEnabled` in the record. Auto-revocation (Decision 1) is
     reflected here honestly (toggle shows off after a revoke).
  3. **Discreet app icon** — visible only when `supportsAlternateIcons()`;
     switch drives `AppIconSwitcher.setDiscreet`; on channel failure the
     switch reverts with honest error copy (never over-claim a state the OS
     refused). Subtitle carries the name-label bound (Decision 6).
  4. **Sign out** — the existing controller action; settings is its natural
     home (today it exists only on the invite-share screen, which keeps its
     copy).
- **Biometric seam:** `BiometricAuthenticator`
  (`features/privacy_lock/domain/`): `Future<bool> isAvailable()` /
  `Future<bool> authenticate({required String reason})` /
  `Future<String?> enrollmentState()`. The real impl (own `data/` file)
  wraps `local_auth` (^3.0.2 — verified current, SwiftPM-ready, throws
  `LocalAuthException` which the adapter maps wholesale to `false`) for
  `authenticate` — **with `biometricOnly: true` pinned in the call and in
  the seam's doc contract (Decision 1; blocking review finding TEST-1)** —
  and the `hayati/device_privacy` channel for `enrollmentState`.
  `NSFaceIDUsageDescription` added to Info.plist (EN-only string in v1;
  Info.plist localization rides the M6.3 store-metadata pass). Every
  failure mode returns `false` (fail to PIN, Decision 1). Fake is scripted
  per test.
- **Entry point — a state-independent host** (review finding DVUX-7): both
  home screens return DIFFERENT Scaffolds per state (loading/error/question/
  completed), so "put a gear in the SafeArea" names no single place. Each
  home's `build` return is wrapped once in a small `SettingsGearOverlay`
  widget — `Stack[ <the per-state scaffold>, SafeArea(Align(topTrailing:
  gear)) ]` — so the gear exists in EVERY state including error (a user
  whose couple stream is erroring must still be able to reach the lock).
  Logical alignment (start/end) so RTL mirrors free. The gear goes on the
  two homes only (solo users' reflections are as private as paired content,
  and the lock must be reachable before pairing) — not on capture/preview.
  Home goldens churn intentionally (W4 flag). Settings itself sits under
  the builder gate like everything else.
- **Explicitly NOT in settings (v1):** theme toggle (MVP OUT-list), the
  notification-privacy override (Decision 6 deferral), KVKK export/delete
  (M6.2 — this screen is their future home, noted so M6.2 extends rather
  than invents), change-PIN (Decision 1), hotline/safety content (★ gate,
  founder-blocked).
- **ARB:** new keys prefixed `settings*` / `lock*` ×3 locales; a
  `privacy_arb_guard_test` clones the coach guard's key-set-parity check for
  both prefixes (the digit-run rule stays coach-scoped — it is an ADR-016
  hotline obligation, not a lock-copy one; lock copy legitimately says
  "6-digit").

## Decision 8 — Fail-direction rules (the table reviewers check first)

| Failure / vector | Direction | Why |
|---|---|---|
| Keychain read throws at boot | fail OPEN + breadcrumb + **one-shot re-read on next resume** | un-verifiable lock = permanent brick (reinstall doesn't clear Keychain); not attacker-inducible today; self-heals next foreground (D2) |
| Auth hits `AuthError` while lock enabled | lock STAYS | protection persists through error states; only `AuthSignedOut` wipes (D1) |
| Recovery sign-out THROWS | overlay stays LOCKED + honest retry copy | sign-out-first ordering; the lock never drops on an unconfirmed sign-out (D4) |
| Same-device re-auth after recovery (partner completes SMS-OTP / Apple re-auth on the held phone) | **recorded residual — not preventable at app level** | recovery is destructive + detectable (owner finds a signed-out app, lock gone); the lock blocks silent/casual access, not identity-anchor holders (D4) |
| Biometric passes for a partner enrolled BEFORE enable | recorded residual — carried by the enable-time DV warning | the app cannot enumerate whose biometrics exist (D1) |
| Biometric enrollment CHANGES after enable | biometric auto-REVOKED at next lock-screen mount; PIN required; honest copy | `evaluatedPolicyDomainState` mismatch (D1) |
| Biometric fails / cancels / throws / unavailable | fall back to PIN keypad (adapter maps `LocalAuthException` → false) | PIN is the credential; biometric is an accelerator (D1) |
| Wrong-attempt write races the sign-out wipe | write ABORTED by the generation guard | `ref.mounted` cannot catch an in-place wipe on a keepAlive controller (D1) |
| Icon channel fails | toggle reverts + honest copy | never display a state the OS refused (D7) |
| Lock record write fails on enable | setup reports failure, lock NOT shown as on | never claim protection that didn't persist |
| Sign-out wipe write fails | overlay still lock-state-driven; recovery idempotent | orphaned record is escapable, not a brick (D1, D4) |
| App killed between wrong attempt and verdict | attempt already persisted (increment-before-verdict) | restart is not a retry reset (D4) |
| Device clock set FORWARD | grace + cooldown deadlines elapse — bound degrades to manual-entry speed | no persistent monotonic clock; stated, not hidden (D3, D4) |

## Test commitments (pinned, not inferred)

- **Bypass suite (the M6 accept line), all via full-app boots
  (`HayatiApp` + overrides) with a locked bootstrap snapshot — every
  `findsNothing`-while-locked assertion is paired with an unlock→reveal
  positive control so it cannot pass vacuously (review finding TEST-3):**
  - cold start signed-in + lock enabled → lock screen visible; NO home
    content findable (default `skipOffstage`) or hit-testable; **then a
    correct PIN → the same home content renders** (the reveal control);
  - background return past grace (clock-pinned via `soloClockProvider`,
    `handleAppLifecycleStateChanged` hidden→paused→resumed) → re-locked;
    within grace → NOT re-locked;
  - cold-start deep link (`FakeDeepLinkSource(initialUri: hayati://invite/…)`)
    while locked → code captured in state, `PartnerPreviewScreen` NOT
    findable/tappable until unlock, THEN renders;
  - pushed-route surfaces: unlock, push a route (coach/paywall path), relock
    via background-return → pushed route not findable/tappable while
    locked, still on the stack after unlock (Offstage keeps the Navigator).
- **Wrong-PIN bounding:** 4 free attempts, 5th starts cooldown with keypad
  disabled + tier-accurate copy per tier (30s/1m/5m strings); counter and
  cooldown survive a simulated relaunch (fresh container, same
  `FakePinLockStore` contents); the increment is persisted BEFORE the
  verdict renders (store write observed first); success resets.
- **The generation-guard race (the S019 class):** a wrong-attempt persist
  in flight when the sign-out wipe fires → the attempt write is dropped,
  the store stays cleared, no `pinHash` resurrection (fake store with a
  gated write knob).
- **Recovery ordering:** tap recovery → sign-out succeeds → overlay stays
  locked until `AuthSignedOut` propagates, then record wiped + sign-in
  screen (no frame of home content in between — pump-by-frame assertion);
  sign-out FAILS (fake auth throws) → still locked + honest retry copy +
  record intact; idempotent when already signed out.
- **Biometric:** enable flow shows the DV warning before any toggle write;
  `authenticate` is invoked with the seam's biometric-only contract (fake
  records the call); enrollment-state mismatch at lock-screen mount →
  `biometricEnabled` auto-revoked + PIN-only + honest copy; every
  `LocalAuthException`-shaped failure falls back to PIN.
- **Shield:** inactive/hidden/paused → full-bleed cover on top (covers the
  whole 390×844 surface — probe), brand-free (golden); resumed → gone;
  inactive alone does NOT start the grace clock.
- **Free tier + daily loop untouched (foreground behavior):** boot with NO
  lock record → no lock UI anywhere, homes/paywall/coach FLOWS behave
  identically (probe assertions, the M5.2 precedent) — the always-on shield
  is the one deliberate universal addition and is asserted separately
  (review finding DVUX-8); `flutter_secure_storage`/`local_auth` channels
  never touched under `flutter test` (fakes by construction).
- **No-content sentinel:** `PinLockRecord`/lock-state `toString()`s carry no
  salt/hash/enrollment/PIN digits; grep-style assertion over thrown errors
  in the controller test.
- **Goldens:** `lock_screen` (locked, cooldown), `settings_screen` (lock
  off, lock on), `pin_setup_screen` (enter, confirm) — six-cell each +
  scale-130 naturals for lock + settings (acceptance line). **The keypad
  digit rows assert 1-2-3 order in the AR/RTL cells** (Decision 1's LTR
  pin). Home-screen goldens re-rendered intentionally for the gear (W4).
- **ARB parity:** `settings*`/`lock*` key sets ×3 locales exactly equal
  (guard test).
- **Unit:** salted-hash round-trip + constant-time compare, record
  (de)serialization incl. unknown-version → null, cooldown schedule math,
  grace-window boundary (59s/60s/61s), degraded-snapshot resume reconcile.
- **Functions:** untouched — suite stays green at gate 80 (spot lint/typecheck
  only if anything under `functions/` moves; nothing should).

## Docs-with-code checklist (this session's pass)

- architecture §2 (privacy_lock/settings populated; `core/storage/` gains
  `PinLockStore`; first platform channel noted), §4 (lock-gate flow bullet),
  §8 (posture: Keychain record, salted-hash honesty, attempt bounding,
  biometric revocation + residuals, shield shipped, snapshot line flips to
  "shipped M6.1, device-verified half on operator item 4").
- test-suite §1 (new fakes, lifecycle-simulation precedent, bypass suite,
  goldens list).
- implementation-plan: M6.1 entry (M6's first written sub-slice).
- resume-prompt regenerated (next objective); operator-expected refreshed
  (item 4 checklist grows: alternate-icon render + system alert, biometric
  prompt + enrollment-change revocation, Keychain round-trip, snapshot
  obscuring in the real switcher; item 1 gains the settings/lock copy for
  native review; Decision 6's M6.2 deferral + the display-name product
  question noted).

## Consequences

**Positive**

- The whole app — including every pushed route, the coach, and whatever a
  deep link renders — sits behind one gate with one state machine; the
  bypass surface is structural (builder-wrapped), not per-screen vigilance.
- The Keychain posture survives the reinstall bypass that would have
  gutted a prefs-based lock on exactly the device-sharing threat model this
  product serves; the lock and the session it guards now share fate.
- ADR-017's snapshot deferral is closed for every surface, not just the
  coach — testable in CI, escalation path recorded for the device check.
- The three new seams (`PinLockStore`, `BiometricAuthenticator`,
  `AppIconSwitcher`) keep `flutter test` hermetic and make the
  device-verified halves an explicit, enumerated operator checklist rather
  than an implicit hope.
- Honest security writing: the 10⁶ bound, the KDF refusal, the clock
  caveats, the same-device re-auth residual, the biometric enrollment
  bounds, the display-name bound, and the fail-direction table are in the
  record — no future session can mistake this layer for forensic-grade
  protection, and no settings copy can over-claim it.

**Negative (accepted trade-offs)**

- The shield flashes behind system sheets (share sheet, permission dialogs)
  — a cosmetic cost of always-on; banking-app precedent.
- No change-PIN flow (disable→enable), no grace-window setting, Western
  keypad digits in AR — v1 minimalism, each individually cheap to add later.
- The discreet toggle controls the icon only until M6.2 wires the per-user
  notification override through the settings-Function path — PRD F6 is
  split across two sessions, loudly. And discreet mode is bounded by the
  platform: the icon changes, the "Hayati App" name label does not.
- Reinstalling the app does not clear the lock (Keychain persistence) —
  correct for the threat model, but a support-surprise; recorded in
  operator-expected so the founders learn it on purpose, not by accident.
- The lock's honest promise is bounded: it blocks casual/silent access;
  a holder of the user's identity anchors (SIM, device passcode/Apple ID)
  can force a *detectable, destructive* way in via recovery, and a
  clock-manipulator collapses cooldown delays to manual-entry speed. All
  recorded, none fixable at app level.
- ~2 new plugin dependencies (`flutter_secure_storage`, `local_auth`) and
  the app's first native Swift beyond the template — SwiftPM-first CI
  compiles it, but the maintenance surface grew.

**Neutral**

- E2E-3 ("PIN lock + discreet icon behavior", Patrol, release-gated)
  already reserved the on-device slot this feature will fill at M6.3.
- The settings screen exists now; M6.2's export/delete rows extend it
  rather than inventing a surface.
- `coach_sessions` persistence (operator item 7) was explicitly waiting on
  "the device lock exists" — that precondition is now met; the retention
  decision remains the founder's.

## Pre-code adversarial review record (Session 020 — six-for-six)

Four lenses (security-bypass, flutter-mechanics, dv-product-ux,
testability-ci) × one finder + two independent verifiers each (refuting
skeptic + governing-docs adjudicator); hand-adjudicated. 27 raw findings →
**4 blocking, 5 serious, ~14 minor confirmed** (rest refuted/out-of-scope),
ALL folded into this rev before any code:

- **Blocking:** TEST-1 (`biometricOnly: true` or the device passcode is an
  app-PIN side door — D1/D7); DVUX-1 (biometric = parallel credential for
  any enrolled biometric → enrollment-state revocation + DV warning — D1);
  FLUTTER-3 (keepAlive wipe race needs the S019 generation/OWNER guard,
  `ref.mounted` provably insufficient — D1); SEC-1 ("never a bypass" was an
  over-claim against same-device re-auth → residual recorded, claim
  reframed as destructive-and-detectable — D4/D8).
- **Serious:** DVUX-3 (recovery reordered: sign-out first, lock held until
  `AuthSignedOut` observed — D4); FLUTTER-2 (wipe = `store.clear()` + state
  mutation, NEVER `ref.invalidate` — D1); DVUX-2 (discreet-mode honesty
  bound: icon image only, name label immutable — D6); TEST-3 (bypass
  negatives paired with unlock→reveal controls — commitments); SEC-4B
  (increment-persisted-before-verdict — D4).
- **Minor (folded):** neutral brand-free shield cover (DVUX-4); full-bleed
  pinned via `StackFit.expand`/`SizedBox.expand` (FLUTTER-4); keypad pinned
  LTR + AR golden (DVUX-6); tier-accurate cooldown copy (DVUX-5);
  state-independent gear host (DVUX-7); degraded-boot resume reconcile +
  M6.2 background-launch caveat (SEC-3); clock-FORWARD honesty (SEC-4A);
  grace rationale corrected — share sheet is `.inactive` (SEC-5); D8 rows
  for the new residuals (SEC-6); lock-UI no-Navigator/Overlay hard
  constraint + inline confirm named (SEC-7/FLUTTER-1/VA-1); lifecycle owner
  named — `PrivacyGuard` (FLUTTER-6); `LocalAuthException`→false adapter
  obligation (TEST-4); adapter file separation for coverage neutrality
  (TEST-5); operator item-4 Keychain round-trip line (TEST-2); free-tier
  claim carve-out wording (DVUX-8).
- **Notable refutations (read carefully per the S019 rule):** plugin majors
  verified real (10.3.1/3.0.2, SwiftPM-ready); no Keychain Sharing
  entitlement needed for iOS default access group; lock-screen notification
  previews carry no couple content by ADR-012 D3 (payloads are
  content-free in every mode); Offstage additionally closes the VoiceOver
  readback channel (recorded as a positive in D3).
