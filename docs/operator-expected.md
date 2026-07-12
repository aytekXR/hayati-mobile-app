# Operator Expected — what Hayati needs from you (the founder)

> **Canonical, committed** operator checklist (founder request, Session 009): the
> single place to see what is expected from you, refreshed at every session
> close. It replaces the two untracked root scratch files (`FOUNDER-ACTIONS.md`,
> `OPERATOR-EXPECTED.md`), whose content was consolidated here on 2026-07-09.
> Sessions update this file with docs-with-code discipline (rule #8); check it
> after every merge to `main`.

_Last refreshed: 2026-07-12, Session 020 close (M6.1 — the device-privacy
layer: app lock + discreet icon + snapshot shield + your first settings
screen; **on plan, 19/22 units, 86%**). The TestFlight runbook lives below._

## Expected from you right now: **NOTHING IS BLOCKING THIS SESSION'S WORK — no action was required and none was taken on your behalf.** Two decisions remain open and neither blocked Session 020: **item 6 (pick the AI provider — now OVERDUE, it is the only thing between the coach and its first live conversation)** and item 7 (should coach chats ever be saved?). Item 6 unblocks M5.3, which jumps to the front of the queue the moment you answer.

**Session 020 needed nothing from you mid-flight.** It built the app lock —
the feature your PRD calls a headline, not a setting — and it is the last
piece the privacy story was missing.

**What you should know from this session:**

**1. The app now locks. The whole app, not parts of it.** Set a 6-digit PIN
in the new Settings screen (reach it via the gear on your home screen) and
Hayati asks for it on every cold start, and again whenever you come back
after being away for more than a minute. Everything sits behind it — the
daily question, the reveal, the coach, even a partner's invite link tapped
while the phone is locked. Face ID works too, but only as a shortcut (see 3).

**2. Two things you should know because they will surprise you otherwise:**
- **Deleting and reinstalling the app does NOT remove the lock.** This is
  deliberate, and it is the single most important design decision in the
  feature. Your sign-in session already survives a reinstall (Apple stores
  it in the Keychain) — so if the lock did *not* survive, anyone could delete
  the app, reinstall it, and walk straight into your still-signed-in account.
  The lock now shares fate with the thing it protects. If you genuinely
  forget the PIN, the escape is "Forgot PIN? Sign out" on the lock screen —
  it signs you out and clears the lock; your data is safe on the server and
  comes back when you sign in again.
- **The discreet icon changes the icon picture, not the name under it.**
  iOS gives apps no way to change their home-screen name at runtime. So the
  app still reads "Hayati App" under the innocuous icon. The app tells you
  this honestly in Settings rather than letting you believe you are hidden
  when you are not. If you want the *name* to be less identifying, that is a
  product decision about what we publish to the App Store — tell a session
  and it becomes part of the store-metadata work (M6.3).

**3. Face ID is a shortcut, and we made it revoke itself.** On a shared
phone, whoever's face or fingerprint is enrolled can pass Face ID — the
phone cannot tell us *whose* face it was. So: Face ID is off by default,
turning it on shows you an explicit warning saying exactly that, and — the
part that matters — **if the phone's Face ID enrollment ever changes after
you turn it on, Hayati automatically switches it off and demands the PIN.**
Someone adding their face to your phone later gains nothing.

**4. What the lock honestly does and does not protect against.** It blocks
casual and silent access: someone picking up your phone cannot read your
answers or your coach chats. It does **not** stop someone who holds your SIM
or your Apple ID from forcing their way in through the "forgot PIN" path —
no app can prevent that, and we would rather say so than pretend. But that
path is **destructive and visible**: it signs you out and wipes your PIN, so
you would know it happened. The app switcher is also covered now — the
preview card iOS shows when you swipe between apps is a blank panel, not
your conversation (and deliberately not our logo either, so it does not
give the app away).

**5. Nothing changed for the daily loop.** If you never set a PIN, the app
behaves exactly as it did — proven by tests that would fail if it didn't.

## ★ NEW (Session 018): native review of the CRISIS content — the one gate before the coach runs on your phones

- **What:** the crisis word-lists (TR / AR incl. Arabizi / EN), the
  professional-help response, the "not therapy" disclaimer, and — NEW since
  Session 019 — **the safety lines of the coach's system-prompt preamble**
  (the "you are not therapy / no medical or legal advice / never claim to be
  human" instructions, written out in TR/AR/EN) are AI-drafted and marked
  `nativeReview: PENDING`. **This review BLOCKS the coach's first run on a
  real device** — an under-reading crisis filter is a safety failure, and
  only native speakers can judge the lists. TR: you two (~15 minutes of
  reading). AR incl. Arabizi: your Gulf reviewer.
- **Also in this gate:** crisis-hotline phone numbers are deliberately NOT
  in the app — a wrong number is dangerous. When you review, choose the
  TR/SA numbers you trust and a session wires them in. (A CI test now fails
  if anyone adds a phone-number-shaped string to the coach copy without
  going through this gate.)
- **Where:** `functions/src/coach/crisis-lexicon.ts` +
  `functions/src/coach/help-content.ts` (help response) +
  `functions/src/coach/persona-prompts.ts` (preamble safety lines); the
  disclaimer moved in Session 019 to its single home in the app copy files
  (`app/lib/core/l10n/arb/app_{tr,ar,en}.arb`, key `coachDisclaimerBody` —
  same strings, new address). Or just send corrections to a session.
- **When:** blocking the first on-device coach use — which rides item 4's
  timeline anyway.

## 6. **DUE NOW** (raised Session 018; due since Session 019): LLM provider decision + API key — M5.3 is waiting on exactly this

- **What:** pick the AI provider for the coach and create an API key. The
  server seam is provider-agnostic; nothing in the code commits to anyone,
  and the choice is reversible.
- **The numbers (published prices per million tokens in/out; ≈ cost per
  coach message at realistic sizes):** Anthropic Claude — Haiku 4.5 $1/$5
  (≈$0.005/msg); Sonnet $3/$15 (≈$0.014/msg; Sonnet 5 intro $2/$10 through
  2026-08-31); Opus 4.8 $5/$25 (≈$0.023/msg). The shipped caps (30/day per
  person, 1,000/month per couple) bound worst-case spend to ≈$14/mo/couple
  at Sonnet pricing. Quality in Gulf Arabic + Turkish is the differentiator;
  OpenAI/Gemini are viable behind the same seam (their prices get pulled
  fresh when you decide — not quoted from memory).
- **When:** **now-ish.** The chat UI is done (Session 019); M5.3 — the first
  live coach conversation — is blocked on this decision alone and was
  SKIPPED in the session ordering because of it (Session 020 builds the app
  lock instead; M5.3 jumps back to the front the moment you answer). Until
  then everything runs on recorded fixtures. The key goes into Secret
  Manager at deploy (like the RC webhook token) — never into the repo.

## 7. NEW (Session 019): should coach conversations ever be SAVED? — the private-thread retention decision

- **What:** today, coach chats are deliberately ephemeral: nothing is stored
  on the server (since M5.1) or on the phone (Session 019 — a fresh app
  start is a fresh conversation; signing out wipes instantly). That is the
  most protective posture for a product that serves people in difficult
  relationships: a saved thread on a shared phone is readable by whoever
  holds it, and the app's device lock doesn't exist yet (it's next session).
  Whether to KEEP it that way is a privacy stance only you can set.
- **The options, honestly:** (a) **ephemeral forever** — simplest, safest,
  zero data anywhere; the cost is that a couple loses coach context whenever
  the app restarts. (b) **a saved private thread per person**
  (`coach_sessions`, auto-deleted after ~30 days) — more useful, but it
  needs: your call on the retention window, rules guaranteeing a partner can
  NEVER read the other's thread, inclusion in the M6 data-export and
  delete-everything flows, and it should not ship before the device lock
  exists. No engineering waits on this — ephemeral works fine indefinitely.
- **When:** whenever you have a view; a session folds it in with rules +
  tests in a day. Until then: ephemeral.

## ★ NEW (2026-07-12, Session 018): you have the iPhone 17 + Mac — the TestFlight runbook

You told Session 018 you now have an **iPhone 17 and a Mac**, and that you will
**register the app on TestFlight and physically test it on your iPhone**. That
changes the posture of item 4 (the Mac was the missing hardware; now the only
gate is your Apple Developer enrollment, promised 2026-07-08) — and it means
you can personally close **half of item 0** (the App Store Connect app record
is Phase B below). Here is the complete runbook, verified against this repo's
actual configuration (bundle id `com.hayati.app`, Sign in with Apple
entitlement already declared, flavor entrypoints `lib/main_dev.dart` /
`lib/main_prod.dart`, fastlane's TestFlight lane deliberately not implemented
until M6 — so your first upload goes through Xcode/Transporter by hand).

### Phase 0 — prerequisites (once)

1. **Verify the enrollment is ACTIVE:** developer.apple.com → Account → your
   membership must say **Apple Developer Program** (paid, $99/yr), not just
   "Apple Developer" (free). Nothing below works on the free tier — TestFlight
   requires the paid program.
2. **Mac:** install **Xcode** from the Mac App Store (latest stable — you need
   a version new enough for the iPhone 17 / current iOS SDK). Launch it once,
   accept the license, let components install. Then Xcode → Settings →
   Accounts → **+** → sign in with your enrolled Apple ID; your team should
   appear.
3. **Mac:** install **Flutter** (stable channel), clone this repo, run
   `flutter doctor` and clear any iOS-section complaints. Then
   `cd app && flutter pub get`. (No CocoaPods needed — this project is
   SwiftPM-first, there is no Podfile.)
4. **iPhone 17:** install the **TestFlight** app from the App Store, signed in
   with the Apple ID you'll invite (using your own enrolled Apple ID is
   simplest).

### Phase A — register the bundle ID (once)

1. developer.apple.com → Certificates, Identifiers & Profiles →
   **Identifiers** → **+** → App IDs → type **App**.
2. Description: `Hayati`. Bundle ID: **Explicit**, exactly **`com.hayati.app`**
   (it is pinned in the Xcode project and `fastlane/Appfile` — a different
   string will not build).
3. Capabilities: tick **Sign in with Apple** (the app's entitlements file
   already declares it — a build without this capability fails validation).
   Push Notifications and App Attest can be added later by editing the App ID
   (that's allowed; Xcode regenerates profiles automatically).
   - Shortcut: if you skip this phase, Xcode's automatic signing (Phase C)
     can register the App ID for you — but doing it in the portal makes the
     capability state explicit, and you need the identifier to exist for
     Phase B anyway.

### Phase B — create the App Store Connect app record (once — this IS half of item 0)

1. appstoreconnect.apple.com → **My Apps** → **+** → **New App**.
2. Platform **iOS** · Name **Hayati** (this is the public/TestFlight display
   name; if Apple says it's taken, pick a variant — it can be changed before
   launch) · Primary language **Turkish** (or English — your call) · Bundle ID
   **com.hayati.app** (appears in the dropdown after Phase A) · SKU
   `hayati-ios` (internal only, never shown) · Full Access.
3. **Do NOT create subscription products yet** unless a session specs them
   with you — and when you do, remember the **irreversible** rule from item 0:
   **leave "Family Sharing" OFF** (ADR-015, one-way door).

### Phase C — build the signed app on the Mac

1. Open `app/ios/Runner.xcworkspace` in Xcode → select the **Runner** target →
   **Signing & Capabilities** → tick **Automatically manage signing** → Team:
   your team. Xcode mints the certificate + provisioning profile itself.
2. Build the **prod** flavor for TestFlight (dev points at `hayatiapp-dev`;
   TestFlight builds should carry prod config):

   ```sh
   cd app
   flutter build ipa --release -t lib/main_prod.dart
   ```

   Leave `REVENUECAT_IOS_API_KEY` out until item 0's RevenueCat account
   exists — without it the paywall shows the honest "store unavailable" state
   **by design** (fail-closed), everything else works.
3. Output lands at `app/build/ios/ipa/*.ipa`. Version is pubspec's
   `version: 0.1.0+1` — every later upload needs the build number after the
   `+` bumped (`+2`, `+3`, …).

### Phase D — upload to TestFlight

1. Easiest: install Apple's **Transporter** app (free, Mac App Store) → sign
   in → drag the `.ipa` in → **Deliver**. Alternative: `flutter build ipa`
   also produced `app/build/ios/archive/Runner.xcarchive` — open it in Xcode
   (Window → Organizer) → **Distribute App** → App Store Connect → Upload.
2. First upload asks the **export compliance** question: Hayati uses only
   standard TLS/HTTPS — answer that it uses **only exempt/standard
   encryption**. (Ask a session to add `ITSAppUsesNonExemptEncryption=false`
   to Info.plist so the question never comes back.)
3. Processing takes ~5–30 minutes; the build then appears in App Store
   Connect → Hayati → **TestFlight** tab (answer the "Missing Compliance"
   prompt there if it asks again).

### Phase E — install on your iPhone 17

1. TestFlight tab → **Internal Testing** → **+** → create a group (e.g.
   `Founders`) → add yourself as tester. Internal groups get builds
   **instantly, no Beta App Review**, up to 100 testers.
2. Your partner: App Store Connect → Users and Access → invite her Apple ID
   with any modest role, then add her to the internal group. (External
   groups exist too, but they require a Beta App Review pass — internal is
   the right lane for the founder couple.)
3. On the iPhone: open **TestFlight** → the build appears (or accept the
   email invite) → **Install**. Done — Hayati is on your phone.

### What that physical test can honestly prove today — and what it can't yet

- **Works immediately:** app launch, onboarding/brand UI, localization
  (TR/AR/EN, RTL), the solo question flow UI, deep-link delivery
  (`hayati://invite/<code>` — an item-4 checkbox), Sign in with Apple's
  full-name capture (another item-4 checkbox) — **after** you enable the
  Apple sign-in provider in the Firebase console (**item 3, ~5 minutes —
  do it before the first launch or sign-in will fail**).
- **Needs item 2 (Blaze + first deploy) first:** pairing, the daily loop,
  reveal, streaks, entitlements — all six Cloud Functions have **never been
  deployed** (Spark plan). A session scripts the first deploy the moment you
  flip Blaze; without it the app on your phone is a beautiful shell around a
  missing backend.
- **Needs item 0:** any real paywall content and the sandbox purchase (M4's
  accept line). TestFlight builds hit the sandbox store automatically once
  RevenueCat + the subscription products exist.
- **Won't fire yet regardless:** push notifications (APNs + the app-side
  token capture are the item-4 device slice, not built into this binary).

**Recommended order:** Phases 0–B now (registration needs only the
enrollment); flip Blaze (item 2) + enable providers (item 3) next; then let a
session run the first deploy; then Phases C–E for the physical test. If you
want, the next session can be re-pointed at the deploy + TestFlight slice
instead of M5.2 — say so and it will be re-scoped.

## 0. **BLOCKING — the only thing left in M4:** RevenueCat account + App Store Connect app record

- **What:** (a) create a free **RevenueCat account** (revenuecat.com — takes
  minutes, just an email; name the project Hayati and note the **iOS API
  key**); (b) once your **Apple Developer enrollment** (promised 2026-07-08)
  lands, create the **App Store Connect app record** for `com.hayati.app` and
  the subscription products (the session will spec the TR/SAR/USD tiers with
  you). **The app-record half is now step-by-step Phase A+B of the TestFlight
  runbook above** — you can do it yourself the day the enrollment lands.
- **Why it is now BLOCKING (changed at the Session 017 close):** the paywall,
  the purchase plumbing, the entitlement server, and now the transfer handling
  are **all done and waiting**. M4.3 shipped the last of the engineering. There
  is **nothing left to build** toward M4's acceptance line — *a real sandbox
  purchase in TR + SA flipping Premium on both phones* — and no session can
  advance it without these two accounts. M4 is marked "engineering complete,
  sandbox proof pending item 0". The next session moves on to the AI coach (M5)
  and will keep moving on until you unblock this.
- **How the app plugs in (no commitment needed from you to understand it):**
  the iOS API key is passed at build time (`REVENUECAT_IOS_API_KEY`
  dart-define — it is a publishable key, but nothing is committed until you
  decide); without it the app fails closed to the honest "store unavailable"
  state.
- **One security note for later (ADR-013):** when the RC *webhook* is
  eventually configured (that's a deploy-time item, see item 2), its
  `Authorization` token must be a **long random string (≥256-bit)** — it is
  the only thing authenticating RevenueCat to our server. The session will
  generate one with you; don't reuse a human password.
- **⚠️ NEW, and IRREVERSIBLE — when you create the subscription products,
  leave "Family Sharing" OFF** (Session 017 / ADR-015). Apple's own
  documentation is explicit: *once you turn on Family Sharing for an in-app
  purchase, you can't turn it off.* We do not want it: it would require both
  of you to be in the same Apple Family group (shared organizer + payment
  method), and it would create a **second source of entitlement that our
  server does not control** — while our own model already gives both partners
  Premium from one purchase. This is a one-way door, so it is written down
  **before** the products exist. If a session ever helps you create them, it
  will re-check this with you.

## 1. Native review of the solo question content (before public launch)

- **What:** the first shippable content — 7 solo reflection questions ×
  TR/AR/EN — is AI-drafted and marked `reviewedBy: PENDING…`. Per the binding
  authoring rules (`content/README.md`, W9): **native register-owner review is
  mandatory before any public launch — TR by you two, AR by a Gulf-dialect
  reviewer.**
- **Where:** the packs live at **`content/packs/solo_{tr,ar,en}.json`** (the
  single authoring home). Edit there, set `reviewedBy` to the reviewer's name,
  then run `dart content/validator/validate.dart --sync` and commit both
  trees — or just send the edits to a session and it will do the mechanics.
  CI validates every change (the reviewedBy `PENDING` warning disappears once
  set).
- **When needed:** NOT blocking personal use or any engineering session
  (ADR-007 personal-use-first). Becomes a hard gate before TestFlight
  beta/soft launch (M6). Reviewing the TR pack is ~10 minutes of reading; the
  AR pack needs your Gulf reviewer contact.
- **Extra weight since M3.2:** these same 7 questions are the **couple**
  question bank placeholder too (`packConfig` absent → `solo_tr`, ADR-011)
  until the W9 couple packs are authored — your own paired daily loop serves
  them, so edits pay off twice.
- **NEW since M4.2 (same review gate, different text):** the paywall and
  pack-screen copy (~28 strings × TR/AR/EN — "One subscription. Premium for
  both of you.", trial lines, etc.) is AI-drafted in the brandkit voice and
  needs the same native pass before any public launch: TR by you two, AR by
  your Gulf reviewer. It lives in `app/lib/core/l10n/arb/app_{tr,ar}.arb`
  (keys starting `paywall`/`packs`/`packSelection`); edits regenerate on
  `flutter pub get`, or just send corrections to a session. One AR grammar
  fix already landed via review (`تجري المزامنة`); the rest read well but are
  unreviewed by a native.
- **NEW since M5.1 — the CRISIS-content review is tracked separately (the ★
  item near the top) because it is a SAFETY gate, not a polish gate:** the
  crisis word-lists, help response, disclaimer, and (since M5.2) the
  prompt-preamble safety lines block the coach's first on-device run, while
  everything in this item blocks only public launch.
- **NEW since M5.2 (standard gate):** the coach chat copy — 27 strings ×
  TR/AR/EN in `app/lib/core/l10n/arb/` (keys starting `coach`): persona
  names (incl. the Perisi/ملهم naming call), chat labels, quota captions,
  every error message, and the paused-conversation copy — plus the persona
  and register TONE blocks of the system prompts in
  `functions/src/coach/persona-prompts.ts` (their SAFETY lines are in the ★
  gate above). AI-drafted in the brandkit voice; same TR-by-you-two /
  AR-by-your-Gulf-reviewer pass before public launch.
- **NEW since M6.1 (standard gate, but read the two flagged ones):** the lock
  and settings copy — 41 strings × TR/AR/EN in `app/lib/core/l10n/arb/` (keys
  starting `lock`/`settings`). Two of these carry **safety meaning**, not just
  tone, and are worth your eyes even before launch: **(a) the Face ID warning**
  ("anyone whose face or fingerprint is saved on this phone can unlock
  Hayati") — it must land as a plain factual caution, not an accusation, in
  both languages; **(b) the "Forgot PIN?" copy**, which must make clear that
  recovery signs you out rather than quietly letting someone in. The rest
  (cooldown lines, the discreet-icon bound, error states) is standard tone
  review. AI-drafted; TR by you two, AR by your Gulf reviewer.

## 2. Blaze plan decision — **last call, optional bonus otherwise**

- **What:** upgrading `hayatiapp-dev`/`hayatiapp-prod` from Spark (free) to
  **Blaze** (pay-as-you-go) — deploying Cloud Functions requires it.
- **Status:** six Functions now (`createInvite`, `invitePreview`,
  `joinInvite`, the scheduled `questionRollover`, the Firestore-triggered
  `answerReveal`, and since M4.1 the **`revenueCatWebhook`**), all
  emulator-proven; **nothing deployed yet.** Deploy-verified-only pieces: the
  rollover's *schedule trigger* (Cloud Scheduler), `answerReveal`'s
  production retry (Eventarc redelivery), and now the webhook's **Secret
  Manager binding** (`RC_WEBHOOK_TOKEN`) + its public URL for the RC
  dashboard. All handler/service logic is fully proven in-process.
- **When needed:** the optional first deploy + real-device pairing test (which
  also needs your Mac, so on-device stays a bonus either way). Hard requirement
  at latest before the first TestFlight build (M6) — and the RC webhook can
  only be configured against a deployed URL, so the live entitlement loop
  (real sandbox purchase → both phones premium) waits on this too.
- **Cost posture:** couple-scoped workload ≈ near-zero at dev scale — the
  hourly sweep reads O(couples) docs and the webhook is O(1) per event
  (`architecture.md` §10); budget alerts at $ thresholds.

## 3. Enable Apple + Phone sign-in providers (open since M1.3)

- **What:** Firebase console → Authentication → Sign-in method → enable
  **Apple** and **Phone** on **both** projects (`hayatiapp-dev`,
  `hayatiapp-prod`).
- **Why manual:** free-tier Auth provider init is console-only (M1.2 finding) —
  no API/CLI path exists.
- **When needed:** only for **real-device** sign-in; CI/emulator sessions run
  without it. ~5 minutes.

## 4. The Mac / Apple Developer slice (enrollment promised 2026-07-08)

**Update 2026-07-12 (Session 018): the Mac and the iPhone 17 are now in hand —
the only remaining gate on this whole slice is the enrollment itself. The
TestFlight runbook above covers the registration + first-install path; the
checkboxes below remain the on-device verification backlog.**

Everything here needs your Mac and/or the Apple Developer enrollment:

- **App Attest**: entitlement + console registration, then on-device
  verification. **App Check enforcement stays OFF in both consoles until
  attestation is verified on-device** (current posture in all Functions).
- **APNs** setup (push): **the M3.4 notification logic is done and waiting on
  exactly this** — nudge/reveal/streak-at-risk sends, quiet hours, and
  discreet mode all ship emulator-proven behind a mocked send seam; the
  device half (APNs registration + the app-side `fcmTokens` capture, which
  was deliberately deferred to this slice) is what turns them into real
  pushes on your phones.
- **App Store Connect app record** — now doubly needed: TestFlight (M6) and
  the M4.2/M4.3 subscription products (item 0).
- **dSYM upload** for prod Crashlytics symbolication.
- **Issue #15**: capture the native crash log for the phone-auth emulator
  suite on the iOS simulator.
- On-device confirmation that Apple's first-authorization full name reaches
  `displayName`.
- **Deep-link delivery test** (M2.2/M2.3): `hayati://invite/<code>` cold + warm
  OS→app delivery can only be proven on a device/simulator.
- **NEW (M6.1, ADR-018) — the device-privacy layer's on-device half.** All of
  it is emulator-proven and CI-compiled, but four things can only be seen on a
  real iPhone. When you do the TestFlight install, please check:
  1. **The Keychain round-trip** — set a PIN, force-quit, relaunch: it must ask
     for the PIN. Then **delete the app, reinstall, and launch**: it must STILL
     ask for the PIN (that is the reinstall-bypass defence working; if it opens
     straight into the app, tell a session immediately — that is a real hole).
  2. **The Face ID prompt** — turn it on in Settings, lock the app, unlock with
     Face ID. Then change/add a face in iOS Settings and reopen Hayati: it must
     have switched Face ID **off** by itself and be demanding the PIN.
  3. **The discreet icon** — flip it in Settings. iOS shows its own alert
     ("You have changed the icon for Hayati App") — that is Apple's, expected,
     and not suppressible. Confirm the home-screen icon actually changes, and
     confirm what we told you: the *name* under it does not.
  4. **The app-switcher snapshot** — open the coach or a revealed answer, swipe
     up to the app switcher: the Hayati card must show a **blank panel**, never
     your content. (If any content shows through, there is a known fix — a
     native SceneDelegate cover — recorded in ADR-018 Decision 5.)
- **Universal links** (decision, not urgent): needs enrollment + a hosted
  `apple-app-site-association` → a domain choice. Custom scheme shipped in
  M2.2; upgrade path documented in `architecture.md` §4.
- First **real-device pairing test** (pairs with item 2: deploy first).

## Parked (cross-project): Unhooked panic-button verification (reported 2026-07-11)

> Not a Hayati item — parked here because this is the checklist you read.
> The **unhooked** iOS panic-control fix sits UNCOMMITTED on your Mac
> (intents moved into the app target + warm-launch gate; unit 151/151,
> snapshot 17/17, status DONE_WITH_CONCERNS). Needed from you, on the Mac /
> iPhone: (1) cold test — app closed, tap Control Center Panic → app must
> launch straight into the panic flow; (2) warm test — app open on the
> dashboard, tap Panic → panic sheet over the dashboard; (3) decide whether
> the swipe-dismissible warm sheet should become a hard cover (the
> celebration screen has no dismiss button — a full cover would trap you);
> (4) let an unhooked Mac session commit via its ritual + run the UI-test
> lane. Optional: gstack 1.39 → 1.60 (`/gstack-upgrade`).

## 5. Slack webhook rotation (from Session 005, still open)

The local branch `chore/slack-notifications` holds commit `13f1e6d` with a
**live incoming-webhook URL**; GitHub push protection rejects it. Rotate the
webhook in Slack (treat it as leaked), store the new one as a **repository
secret**, then rework/land the branch.

## Progress & readiness snapshot (as of Session 020 close)

- **Plan progress:** M0 ✅ · M1 ✅ · M2 ✅ · M3 ✅ · **M4 engineering ✅ (sandbox
  accept line open on item 0)** · **M5: 2/3 (spine + chat UI; M5.3 live
  adapter is founder-blocked on item 6)** · **M6: 1/3 (M6.1 device-privacy
  layer ✅)** — **19/22 session-units (86%) in 20 sessions; 3 planned
  session-units left to the MVP** (M5: 1, blocked · M6: 2; M6.5 Android sits
  outside the 22-unit MVP count). On track; no plan or scope changes in
  Session 020 (M1's +1 session remains the only slippage ever). Next session:
  **M6.2 — KVKK/PDPL export + cascade delete + partner notification**, unless
  you answer item 6, in which case **M5.3 (the coach going live) takes
  precedence** and M6.2 slides one session.
- **Readiness: pre-MVP, emulator/CI-proven, nothing deployed, nothing on a
  phone.** Working and proven against emulators + CI: auth, profile + rules,
  the whole pairing loop, the unpaired solo week, the content pipeline, the
  FULL daily loop (server assignment → answer → server-gated mutual reveal →
  streak with grace), the notification *logic*, the **entitlement backbone**
  (RC webhook → couple mirror → app premium decision, replay/out-of-order/
  transfer-proven), the **paywall + premium gating** (annual-first paywall
  over a fully-faked store, the reusable premium gate, free tier
  assertion-protected), the **coach safety spine** (crisis detector
  TR/AR/Arabizi/EN proven against engineered evasions; `coachProxy` with
  server-side premium gate, transactional caps, fail-closed provider seam),
  the **coach chat UI** (premium-only surface with three personas, the
  help-sticky pause enforced app-side, per-device "not therapy" consent,
  honest states for every server outcome, conversations ephemeral by design
  and wiped on sign-out), and now the **device-privacy layer** (the whole app
  behind a PIN at the root — cold start, background-return, deep links and
  pushed routes all gated and test-pinned; the PIN in the Keychain so a
  delete-and-reinstall cannot shed the lock while the sign-in session it
  guards survives; attempt-bounding with escalating cooldowns that survive a
  force-quit; Face ID as a self-revoking shortcut; the app-switcher card
  blanked; the discreet iOS icon — 1,206 app tests / 773 server tests green).
  **What "production-ready" is still missing, honestly:** no deploy has ever
  happened (Spark plan — item 2), the app has never run on a real device
  (Mac/enrollment — item 4), no real purchase has ever been made (item 0),
  push notifications have no device half (APNs — item 4), the coach has no
  live AI provider (item 6 — the ONLY gap left in M5), and the privacy
  layer's four on-device checks (item 4's new sub-list) are unverified on
  real hardware. KVKK export/delete lands next (M6.2). Call it **~86% of the
  MVP's engineering, 0% of its operational proof.**
  Deferred loudly (nothing silent): seasonal question windows (issue #29), the
  schedule trigger + Eventarc retry + webhook Secret Manager binding
  (deploy-verified at first Blaze deploy), `users.fcmTokens` capture + APNs
  (item 4), **RC-REST reconciliation** (rides item 0 + the deploy era), the
  RC identity-sync retry hardening (first live-key session), the private
  thread (item 7 — founder retention decision; ephemeral until then), the
  coach's live provider adapter + `LLM_API_KEY` (item 6 — DUE), the
  crisis-content native review + hotline numbers (★ — blocks coach-on-device
  only), Remote Config cap binding (deploy era), the coach rate limiter's
  per-instance scope (deploy hardening), a pre-first-message quota meter
  (needs the `coachUsage` watch), `invitePreview.questionText` (W9), Apple
  **Group Purchases** (WWDC26; no RevenueCat support yet), and two
  quarantined tests (ci-debt #36 reveal round-trip listener race, #15
  phone-auth simulator crash — at the >2-forces-stabilization threshold, not
  over it). **New from M6.1:** the per-user neutral-notification override
  (M6.2 — AR-locale users already get discreet pushes by default; TR/EN needs
  a `users` field + a settings Function), the device-privacy layer's four
  on-device verifications (item 4), a native SceneDelegate snapshot cover
  (only if the on-device check finds the pure-Dart shield leaves a gap — the
  fix is pre-recorded in ADR-018 D5), Android's lock + activity-alias icon
  (M6.5), and a change-PIN flow (today: turn off, turn on — both verify
  first, so it is a convenience gap, not a hole).
  **Closed this session:** the OS app-switcher snapshot obscuring (was
  deferred from ADR-017) — shipped as an always-on neutral cover.
