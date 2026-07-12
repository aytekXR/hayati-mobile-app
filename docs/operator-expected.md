# Operator Expected — what Hayati needs from you (the founder)

> **Canonical, committed** operator checklist (founder request, Session 009): the
> single place to see what is expected from you, refreshed at every session
> close. It replaces the two untracked root scratch files (`FOUNDER-ACTIONS.md`,
> `OPERATOR-EXPECTED.md`), whose content was consolidated here on 2026-07-09.
> Sessions update this file with docs-with-code discipline (rule #8); check it
> after every merge to `main`.

_Last refreshed: 2026-07-12, Session 018 close (M5.1 — the AI coach's crisis
safety spine + `coachProxy` server seam; **on plan, 17/22 units, 77%**). The
TestFlight runbook you asked for mid-session is merged and lives below._

## Expected from you right now: **nothing was blocked this session. Two NEW items exist (★ and 6 below); neither blocks the next session.**

**Session 018 needed nothing from you mid-flight.** Per plan it built the
first slice of the AI coach — the part that keeps a couple in crisis SAFE —
entirely on recorded fixtures: no AI provider account, no API key, no cost.
It also delivered your TestFlight runbook request the same hour you asked
(merged separately as PR #43 so it reached `main` immediately).

**What you should know from this session:**

**1. The coach's safety net is built and aggressively proven.** If either of
you ever types something that signals a crisis — self-harm, violence — in
Turkish, Gulf Arabic, Arabizi (Arabic typed in Latin letters), or English,
the coach will NEVER answer with its AI persona: it returns a warm, human
help message urging real-world support, and the AI is never even called —
regardless of paywall or usage limits. This was tested against every evasion
we could engineer (missing Turkish accents, Arabic spelling variants,
l33t-speak, spaced-out letters, lookalike characters, phrases split across
messages) — the server suite is now 772 tests, built so that WEAKENING any
protection turns CI red.

**2. Privacy went a step further than planned.** The pre-code adversarial
review (4th session in a row it caught real design flaws before code) found
that the usage counters would have let each partner see how often the OTHER
uses the coach — surveillance fuel in a product that explicitly serves
people in difficult relationships. Per-person counters are now readable only
by that person. Also by construction and tested: no message text, no user
id, and no "this couple hit the crisis filter" record ever appears in any
log.

**3. Until you pick an AI provider (new item 6), the coach honestly says
it's unavailable.** Crisis protection works even in that state. The
engineering never waits on your account decision — that's deliberate.

## ★ NEW (Session 018): native review of the CRISIS content — the one gate before the coach runs on your phones

- **What:** the crisis word-lists (TR / AR incl. Arabizi / EN), the
  professional-help response, and the "not therapy" disclaimer are
  AI-drafted and marked `nativeReview: PENDING`. **This review BLOCKS the
  coach's first run on a real device** — an under-reading crisis filter is a
  safety failure, and only native speakers can judge the lists. TR: you two
  (~15 minutes of reading). AR incl. Arabizi: your Gulf reviewer.
- **Also in this gate:** crisis-hotline phone numbers are deliberately NOT
  in the app — a wrong number is dangerous. When you review, choose the
  TR/SA numbers you trust and a session wires them in.
- **Where:** `functions/src/coach/crisis-lexicon.ts` +
  `functions/src/coach/help-content.ts` — or just send corrections to a
  session and it does the mechanics.
- **When:** NOT blocking M5.2 (chat UI, still fixture-driven). Blocking the
  first on-device coach use — which rides item 4's timeline anyway.

## 6. NEW (Session 018): LLM provider decision + API key — becomes due at M5.2/M5.3

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
- **When:** the first LIVE coach call (M5.2 or M5.3). Until then everything
  runs on recorded fixtures. The key goes into Secret Manager at deploy
  (like the RC webhook token) — never into the repo.

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
  crisis word-lists, help response, and disclaimer block the coach's first
  on-device run, while everything in this item blocks only public launch.

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

## Progress & readiness snapshot (as of Session 018 close)

- **Plan progress:** M0 ✅ · M1 ✅ · M2 ✅ · M3 ✅ · **M4 engineering ✅ (sandbox
  accept line open on item 0)** · **M5: 1/3 (the safety spine)** · M6 pending —
  **17/22 session-units (77%) in 18 sessions; 5 planned session-units left to
  the MVP** (M5: 2 · M6: 3; M6.5 Android sits outside the 22-unit MVP count).
  On track; no plan or scope changes in Session 018 (M1's +1 session remains
  the only slippage ever).
- **Readiness: pre-MVP, emulator/CI-proven, nothing deployed, nothing on a
  phone.** Working and proven against emulators + CI: auth, profile + rules, the
  whole pairing loop, the unpaired solo week, the content pipeline, the FULL
  daily loop (server assignment → answer → server-gated mutual reveal → streak
  with grace), the notification *logic*, the **entitlement backbone** (RC
  webhook → couple mirror → app premium decision, replay/out-of-order/
  transfer-proven), the **paywall + premium gating** (annual-first paywall
  over a fully-faked store, the reusable premium gate, free tier
  assertion-protected), and now the **coach safety spine** (crisis detector
  TR/AR/Arabizi/EN proven against engineered evasions; `coachProxy` with
  server-side premium gate, transactional caps, and a fail-closed provider
  seam — zero live AI calls by design). **What "production-ready" is still
  missing, honestly:** no deploy has ever happened (Spark plan — item 2), the
  app has never run on a real device (Mac/enrollment — item 4), no real
  purchase has ever been made (item 0), push notifications have no device
  half (APNs — item 4), the coach has no chat UI and no live AI provider yet
  (M5.2/M5.3 + item 6), and privacy/launch hardening (M6) is not built. Call
  it **~77% of the MVP's engineering, 0% of its operational proof.**
  Deferred loudly (nothing silent): seasonal question windows (issue #29), the
  schedule trigger + Eventarc retry + webhook Secret Manager binding
  (deploy-verified at first Blaze deploy), `users.fcmTokens` capture + APNs
  (item 4), **RC-REST reconciliation** (the fix for three named transfer costs
  *and* for webhooks dropped past RC's ~155-min retry budget — rides item 0 +
  the deploy era), the RC identity-sync retry hardening (first live-key
  session), private thread (M5.2 scope decision, with `coach_sessions`
  persistence), the coach's live provider adapter + `LLM_API_KEY` (item 6),
  the crisis-content native review + hotline numbers (★ item — blocks
  coach-on-device only), Remote Config cap binding (deploy era; constants +
  injectable seam today), the coach rate limiter's per-instance scope
  (revisit at deploy hardening), `invitePreview.questionText`
  (W9), Apple **Group Purchases** (WWDC26; no RevenueCat support yet — the only
  thing that would reopen the gift decision), and two quarantined tests
  (ci-debt #36 reveal round-trip listener race, #15 phone-auth simulator
  crash — at the >2-forces-stabilization threshold, not over it).
