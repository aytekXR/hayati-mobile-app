# ADR-018: Device-privacy layer — root lock gate (PIN + biometric), always-on snapshot shield, discreet alternate icon, first settings surface

- **Status:** Accepted
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
tier: content is not one tap away (the lock), the app does not advertise
itself on the home screen (the discreet icon), and the OS app switcher does
not replay the last screen (the shield). Protections this layer deliberately
does NOT claim: resistance to device forensics, jailbreak, or an adversary
who knows/coerces the PIN. Those bounds are recorded honestly below.

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
  (a partner can add their face/finger on a shared device — iOS invalidates
  biometric Keychain items on enrollment change only when using access
  control flags, and local_auth cannot distinguish whose biometric passed).
  The PIN is the root credential; biometric is an accelerator (Decision 1).

## Decision 1 — The lock model: 6-digit PIN is the credential; biometric is an optional accelerator; the lock is device-scoped and dies with the session

- **Credential:** a fixed-length **6-digit numeric PIN** (iOS passcode
  convention; 10⁶ space is the ceiling any app-level PIN offers — honesty
  about that bound is in Decision 2). Entered on a custom in-app keypad
  (Western digits in all locales, v1 — the iOS AR passcode pad precedent is
  mixed; native review may overrule; dots-only echo).
- **Biometric (Face ID / Touch ID) is an accelerator, never the credential:**
  it can be enabled only after a PIN exists, unlocks the same gate, and ANY
  biometric failure/cancel/unavailability falls back to the PIN keypad
  silently (no error taxonomy leaked to the lock screen beyond "use PIN").
  Rationale: enrollment mutability (Context) and local_auth's inability to
  bind "which enrolled human" — the PIN stays the thing we verify.
- **Setup happens in settings, signed-in and unlocked only:** enable → enter
  PIN → confirm PIN → written to the Keychain record (Decision 2). Disable →
  verify current PIN → record cleared. No separate change-PIN flow in v1
  (disable→enable covers it; recorded as an accepted gap — a dedicated flow
  is a later nicety, not a security hole, because both paths verify first).
- **The lock is device-scoped, not account-scoped — and it is wiped on
  sign-out.** `AuthSignedOut` (manual or remote) clears the whole lock
  record via a root listener (the `coachTranscriptProvider` invalidation
  idiom, mounted beside it in `app.dart`). Rationale: a signed-out app shows
  only the sign-in screen (nothing to protect), a next user must not inherit
  the previous user's PIN (lock-out foot-gun), and "forgot PIN → sign out"
  (Decision 4) stays coherent — sign-out IS the lock reset, one mechanism.
  **Deliberate asymmetry with the coach listener:** the coach invalidates on
  any `next is! AuthSignedIn` (fail-closed = content gone); the lock wipes
  ONLY on `AuthSignedOut` (fail-closed = protection stays). An `AuthError`
  from a failed manual op (e.g. sign-out that threw) must NOT silently
  disable a lock the user believes is on — the DV posture governs (S018
  rule: the governing doc decides): protection persists through error
  states, content does not.
- **The lock is auth-agnostic at render time:** the overlay shows whenever
  state is `locked`, regardless of auth (a wipe failure or race can leave a
  locked record with no session; the recovery action on the lock screen is
  idempotent — Decision 4 — so that state is escapable, never a brick).

## Decision 2 — Storage posture: Keychain via flutter_secure_storage, one versioned record, salted hash + constant-time compare, bootstrap-awaited snapshot

- **Where:** the iOS **Keychain** via `flutter_secure_storage` (^10.x),
  `KeychainAccessibility.unlocked_this_device` — the strictest option that
  works for us (the app only reads at foreground launch, when the device is
  necessarily unlocked; `this_device` keeps the record out of iCloud/device
  backups so a PIN never migrates to another phone). Fallback if device
  testing surfaces an access issue: `first_unlock_this_device` (recorded
  here so the relaxation, if ever needed, is a documented one-step).
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
  `{version: 1, salt, pinHash, biometricEnabled, wrongCount, lockoutUntilMs}`.
  One key so reads/writes are atomic at the Keychain-item level and the
  bootstrap read is a single round-trip. `version` gates future migration.
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
  override an `initialLockRecordProvider` by value. The lock controller
  seeds `locked`/`disabled` from that snapshot synchronously; no spinner, no
  flash. Widget tests override the same provider with fixture records.
- **Seam:** `PinLockStore` (`core/storage/pin_lock_store.dart`):
  `Future<PinLockRecord?> read()` / `Future<void> write(PinLockRecord)` /
  `Future<void> clear()`. Real impl `SecureStoragePinLockStore` wraps
  `flutter_secure_storage`; tests use an in-memory `FakePinLockStore`
  (recorder-style, failure knobs). The real adapter is constructed only in
  the entrypoints — `flutter test` never touches the plugin channel (the
  M2.2/M4.2 seam precedent).
- **Bootstrap read failure fails OPEN, loudly:** if the Keychain read throws
  at boot (no known path; device-storage fault), the snapshot is `null` →
  lock disabled + a no-content breadcrumb to the crash reporter. Fail-closed
  here would brick the app behind a lock screen that can verify nothing —
  and the user's escape (delete/reinstall) doesn't even clear the Keychain,
  so the brick would be permanent. An attacker cannot induce a Keychain read
  failure without device-level compromise (out of threat model). Accepted
  trade-off, recorded.
- **No-content rule:** `PinLockRecord.toString()` renders field PRESENCE
  only (`PinLockRecord(set: true, biometric: false, wrongCount: 3)` — never
  salt/hash bytes); no PIN digit ever appears in any exception, breadcrumb,
  or state `toString()` (the `CoachTranscriptState` COUNT-not-content
  precedent). Pinned by a sentinel test.

## Decision 3 — The gate mounts in `MaterialApp.builder`: one Stack, Offstage + TickerMode, grace window on the app-wide clock

- **Placement:** `MaterialApp.builder` (where the theme wrapper already
  sits) is the single point above `home` AND every `Navigator.push` route —
  the scout-verified bypass inventory (all event-driven navigations are
  pops; all pushes are user taps) means nothing can route around it. The
  builder composes:

  ```
  Theme(
    child: Stack([
      TickerMode(enabled: !locked,
        child: Offstage(offstage: locked, child: appChild)),   // the Navigator
      if (locked) const LockScreen(),                          // Decision 4 UI
      if (shieldOn) const PrivacyShieldCover(),                // Decision 5
    ]),
  )
  ```

- **Offstage, not just paint-over:** while locked the app subtree is
  `Offstage` — it keeps ALL state (Navigator stack, form fields, providers)
  but does not paint and cannot be hit-tested. Not painting matters twice:
  the locked screen itself can be snapshotted by the OS, and an opaque
  overlay above a painted subtree still rasterizes the content beneath it.
  `TickerMode(enabled: false)` freezes animations below (also keeps
  `pumpAndSettle` from hanging on spinners behind the lock in every widget
  test that boots locked). Deep links while locked still land in
  `pendingInviteProvider` (state, not navigation) and render offstage —
  captured, invisible, untappable; `flutter_test`'s default
  `skipOffstage: true` makes the bypass assertions read naturally
  (`findsNothing` while locked).
- **When it locks:**
  - **Cold start:** bootstrap snapshot says enabled → first frame is the
    lock screen. Grace state is in-memory only, so cold start ALWAYS locks.
  - **Background return:** a root-level lifecycle observer (the app's first
    beyond `PairedHomeScreen`'s `.resumed` rebuild) records `backgroundedAt`
    on `AppLifecycleState.paused` **or** `.hidden` (hidden fires before
    paused on iOS; either alone is enough) and on `.resumed` re-locks iff
    `now − backgroundedAt > 60s`, `now` from `soloClockProvider` (the app's
    one clock seam — tests pin it). **`.inactive` does NOT start the grace
    clock:** control-center pulls, notification-shade peeks, permission
    dialogs, and the biometric prompt itself all pass through inactive;
    locking on it would fight the user (and the biometric flow). Inactive
    only raises the shield (Decision 5).
  - **60 seconds, fixed:** long enough for an app switch (share sheet,
    copying an invite code), short enough that a phone left on a table
    re-arms. Not user-configurable in v1 — a config surface on a security
    timing is scope without evidence; revisit on founder feedback.
- **Wall-clock caveat, recorded:** the grace comparison uses wall time; a
  phone holder who changes the device clock can stretch the window. They
  hold an *unlocked* phone inside the grace window by definition — the lock
  they are stretching is not yet re-armed — so the exposure is bounded and
  accepted (monotonic time does not survive process death; no persisted
  grace exists to attack).
- **Lock state is a keepAlive Riverpod controller**
  (`privacy_lock_controller.dart`): states `PrivacyLockDisabled` /
  `PrivacyLocked{lockoutUntilMs?}` / `PrivacyLockUnlocked`. Manual-op
  discipline per the repo idiom: re-entrant ops dropped while one is in
  flight, `ref.mounted` after every await. The root `app.dart` listeners
  gain: the sign-out wipe (Decision 1) and the lifecycle observer wiring.

## Decision 4 — Attempt bounding + recovery: persisted counter, escalating cooldown, sign-out as the only PIN escape

- **Counter and cooldown live IN the Keychain record** (`wrongCount`,
  `lockoutUntilMs`) — killing and relaunching the app does not reset them
  (an in-memory counter would be "unlimited attempts, 5 per restart").
- **Schedule:** attempts 1–4 free; 5th wrong → 30s cooldown; 6th → 1 min;
  7th and beyond → 5 min each. Cumulative until a successful unlock resets
  `wrongCount` to 0. During cooldown the keypad is disabled with honest
  copy ("Too many attempts — try again in about a minute"); no data is ever
  destroyed by failed attempts (a wipe-after-N would hand a destruction
  button to exactly the wrong person in a DV context).
- **Worst-case brute force with the app:** ~10 attempts/hour at the 5-min
  tier ≈ years for 10⁶ — the online control does the work the hash cannot
  (Decision 2). Cooldown timestamps use wall clock; clock rollback is the
  same bounded, accepted exposure as Decision 3 (an attacker patient enough
  to toggle the clock 10⁶ times has physical possession for days — at that
  point the threat model has already failed upstream).
- **Recovery — "Forgot PIN? Sign out":** always visible on the lock screen.
  Confirmation dialog (rendered inside the lock screen itself — the overlay
  sits above the app Navigator, so it uses a local dialog, not a pushed
  route), then: wipe the lock record + sign out. Data is server-side; the
  coach transcripts are already torn down by the existing root listener on
  sign-out; signing back in re-proves identity to Firebase. **Never a
  bypass:** no "enter your Apple password" side door, no support unlock —
  identity re-proof through the real auth stack is the only path. The
  action is idempotent and works when already signed out (Decision 1's
  orphaned-record edge): it wipes and lands on the sign-in screen either way.

## Decision 5 — Snapshot shield: always-on, pure Dart, in the same Stack — closing the ADR-017 deferral

- **What:** an opaque brand cover (`PrivacyShieldCover`: night background +
  brand mark, no content) rendered as the TOP Stack layer whenever the
  lifecycle is `inactive`, `hidden`, or `paused`. Shown via the same root
  lifecycle observer as the grace clock; hidden on `resumed`.
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
- **Scope honesty:** the shield covers the OS snapshot exposure. It does NOT
  scrub process memory (ADR-017's recorded residue stands) and does not
  claim anything about screenshots taken by the user themselves (iOS offers
  no app-side screenshot block; screen-capture detection is out of scope).

## Decision 6 — Discreet alternate icon: the app's first platform channel, behind a seam; asset-catalog alternate icons; the notification override stays server-side and deferred

- **Dart seam:** `AppIconSwitcher` (`features/settings/domain/`):
  `Future<bool> supportsAlternateIcons()` / `Future<bool> isDiscreet()` /
  `Future<void> setDiscreet(bool)`. Real impl `ChannelAppIconSwitcher` over
  the app's FIRST MethodChannel, `hayati/app_icon` (methods
  `supportsAlternateIcons` / `getAlternateIconName` / `setAlternateIconName`);
  `FakeAppIconSwitcher` for tests (recorder + failure knobs). Provider
  overridden in the entrypoints (both, lockstep), unimplemented at base —
  the repository-seam discipline.
- **Native half (Swift, ~40 lines):** channel registered in
  `didInitializeImplicitFlutterEngine` via
  `engineBridge.pluginRegistry.registrar(forPlugin:)`'s messenger; handler
  calls `UIApplication.shared.setAlternateIconName(_:completionHandler:)`
  on the main thread, returns the error message (name only, no content
  concerns here) through the channel result. iOS shows its own system alert
  on icon change — expected, user-initiated, not suppressed (no private
  API — App Store safety).
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
- **CI-safe by construction, device-verified later:** `flutter build ios
  --no-codesign` compiles the Swift and runs actool over the new icon set —
  the compile/asset surface is CI-gated. What CI cannot prove (the icon
  actually swapping on a home screen, the system alert copy) joins operator
  item 4's on-device checklist.
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
  pushes by default (shipped); TR/EN users get the override with M6.2.
  Recorded here, in the implementation plan, and in operator-expected.

## Decision 7 — The settings surface: one screen, four rows, gear entry on both homes

- **`SettingsScreen`** (`features/settings/presentation/`), pushed via the
  exported-helper convention (`showSettings(context, uid:)`), one screen:
  1. **App lock** — off: "Set up PIN" → `PinSetupScreen` (enter → confirm →
     enabled); on: "Turn off" → PIN verify (local dialog) → cleared.
  2. **Unlock with Face ID / Touch ID** — visible only when the lock is on
     AND `BiometricAuthenticator.isAvailable()`; toggles `biometricEnabled`
     in the record.
  3. **Discreet app icon** — visible only when `supportsAlternateIcons()`;
     switch drives `AppIconSwitcher.setDiscreet`; on channel failure the
     switch reverts with honest error copy (never over-claim a state the OS
     refused).
  4. **Sign out** — the existing controller action; settings is its natural
     home (today it exists only on the invite-share screen, which keeps its
     copy).
- **Biometric seam:** `BiometricAuthenticator`
  (`features/privacy_lock/domain/`): `Future<bool> isAvailable()` /
  `Future<bool> authenticate({required String reason})`. Real impl wraps
  `local_auth` (^3.x; `NSFaceIDUsageDescription` added to Info.plist —
  EN-only string in v1, Info.plist localization rides the M6.3 store-metadata
  pass); every failure mode returns `false` (fail to PIN, Decision 1). Fake
  is scripted per test.
- **Entry point:** a gear `IconButton` top-trailing (`Align` inside the
  existing `SafeArea`, logical direction — RTL mirrors free) on BOTH homes
  — solo users' reflections are as private as paired content, and the lock
  must be reachable before pairing. Home goldens churn intentionally (W4
  flag). Settings itself sits under the builder gate like everything else.
- **Explicitly NOT in settings (v1):** theme toggle (MVP OUT-list), the
  notification-privacy override (Decision 6 deferral), KVKK export/delete
  (M6.2 — this screen is their future home, noted so M6.2 extends rather
  than invents), change-PIN (Decision 1), hotline/safety content (★ gate,
  founder-blocked).
- **ARB:** new keys prefixed `settings*` / `lock*` ×3 locales; a
  `privacy_arb_guard_test` clones the coach guard's key-set-parity check for
  both prefixes (the digit-run rule stays coach-scoped — lock copy
  legitimately references "6-digit"; guard is `\d{3,}` and "6" passes
  anyway, but scoping keeps intent clear).

## Decision 8 — Fail-direction rules (the table reviewers check first)

| Failure | Direction | Why |
|---|---|---|
| Keychain read throws at boot | fail OPEN + breadcrumb | un-verifiable lock = permanent brick (reinstall doesn't clear Keychain); not attacker-inducible (Decision 2) |
| Auth hits `AuthError` while lock enabled | lock STAYS | protection persists through error states; only `AuthSignedOut` wipes (Decision 1) |
| Biometric fails / cancels / unavailable | fall back to PIN keypad | PIN is the credential; biometric is an accelerator (Decision 1) |
| Icon channel fails | toggle reverts + honest copy | never display a state the OS refused (Decision 7) |
| Lock record write fails on enable | setup reports failure, lock NOT shown as on | never claim protection that didn't persist |
| Sign-out wipe write fails | overlay still lock-state-driven; recovery idempotent | orphaned record is escapable, not a brick (Decisions 1, 4) |
| App killed during cooldown | cooldown persists (Keychain) | restart is not a retry reset (Decision 4) |

## Test commitments (pinned, not inferred)

- **Bypass suite (the M6 accept line), all via full-app boots
  (`HayatiApp` + overrides) with a locked bootstrap snapshot:**
  - cold start signed-in + lock enabled → lock screen visible; NO home
    content findable (default `skipOffstage`) or hit-testable;
  - background return past grace (clock-pinned via `soloClockProvider`,
    `handleAppLifecycleStateChanged` hidden→paused→resumed) → re-locked;
    within grace → NOT re-locked;
  - cold-start deep link (`FakeDeepLinkSource(initialUri: hayati://invite/…)`)
    while locked → code captured in state, `PartnerPreviewScreen` NOT
    findable/tappable until unlock, THEN renders;
  - pushed-route surfaces unreachable while locked (no tappable affordance
    exists offstage — asserted by attempting the taps).
- **Wrong-PIN bounding:** 4 free attempts, 5th starts cooldown with keypad
  disabled + honest copy; counter/cooldown survive a simulated relaunch
  (fresh container, same `FakePinLockStore` contents); success resets.
- **Recovery:** lock-screen sign-out confirm → record wiped + auth signed
  out + (existing pin) coach transcripts fresh; idempotent when already
  signed out.
- **Shield:** inactive/hidden/paused → cover on top; resumed → gone;
  inactive alone does NOT start the grace clock.
- **Free tier + daily loop untouched:** boot with NO lock record → no lock
  UI anywhere, homes/paywall/coach flows behave byte-identically (probe
  assertions, the M5.2 precedent); `flutter_secure_storage`/`local_auth`
  channels never touched under `flutter test` (fakes by construction).
- **No-content sentinel:** `PinLockRecord`/lock-state `toString()`s carry no
  salt/hash/PIN digits; grep-style assertion over thrown errors in the
  controller test.
- **Goldens:** `lock_screen` (locked, cooldown), `settings_screen` (lock
  off, lock on), `pin_setup_screen` (enter, confirm) — six-cell each +
  scale-130 naturals for lock + settings (acceptance line). Home-screen
  goldens re-rendered intentionally for the gear (W4).
- **ARB parity:** `settings*`/`lock*` key sets ×3 locales exactly equal
  (guard test).
- **Unit:** salted-hash round-trip + constant-time compare, record
  (de)serialization incl. unknown-version → null, cooldown schedule math,
  grace-window boundary (59s/60s/61s).
- **Functions:** untouched — suite stays green at gate 80 (spot lint/typecheck
  only if anything under `functions/` moves; nothing should).

## Docs-with-code checklist (this session's pass)

- architecture §2 (privacy_lock/settings populated; `core/storage/` gains
  `PinLockStore`; first platform channel noted), §4 (lock-gate flow bullet),
  §8 (posture: Keychain record, salted-hash honesty, attempt bounding,
  shield shipped, snapshot line flips to "shipped M6.1, device-verified
  half on operator item 4").
- test-suite §1 (new fakes, lifecycle-simulation precedent, bypass suite,
  goldens list).
- implementation-plan: M6.1 entry (M6's first written sub-slice).
- resume-prompt regenerated (next objective); operator-expected refreshed
  (item 4 checklist grows: alternate-icon render + system alert, biometric
  prompt, snapshot obscuring in the real switcher; item 1 gains the
  settings/lock copy for native review; Decision 6's M6.2 deferral noted).

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
- Honest security writing: the 10⁶ bound, the KDF refusal, the wall-clock
  caveats, and the fail-direction table are in the record — no future
  session can mistake this layer for forensic-grade protection.

**Negative (accepted trade-offs)**

- The shield flashes behind system sheets (share sheet, permission dialogs)
  — a cosmetic cost of always-on; banking-app precedent.
- No change-PIN flow (disable→enable), no grace-window setting, Western
  keypad digits in AR — v1 minimalism, each individually cheap to add later.
- The discreet toggle controls the icon only until M6.2 wires the per-user
  notification override through the settings-Function path — PRD F6 is
  split across two sessions, loudly.
- Reinstalling the app does not clear the lock (Keychain persistence) —
  correct for the threat model, but a support-surprise; recorded in
  operator-expected so the founders learn it on purpose, not by accident.
- The lock's real strength is attempt bounding; a device-clock manipulator
  gets slack in cooldowns and grace — bounded, documented, out of scope to
  fix (no persistent monotonic clock exists).
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
