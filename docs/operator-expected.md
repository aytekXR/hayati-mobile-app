# Operator Expected — what Hayati needs from you (the founder)

> **Canonical, committed** operator checklist (founder request, Session 009): the
> single place to see what is expected from you, refreshed at every session
> close. It replaces the two untracked root scratch files (`FOUNDER-ACTIONS.md`,
> `OPERATOR-EXPECTED.md`), whose content was consolidated here on 2026-07-09.
> Sessions update this file with docs-with-code discipline (rule #8); check it
> after every merge to `main`.

_Last refreshed: 2026-07-12, Session 017 start (M4.3 — gift flow + `TRANSFER`
handling; **M4 3/3 engineering**). Previous refresh: Session 016 close._

## Session 017 operator check (2026-07-12, at session start)

**No operator action is required for this session to proceed.** The session
checked item 0 first (as its own plan mandated): there is still **no
RevenueCat account and no App Store Connect app record** — no RC key material
exists on the machine and nothing changed since the Session 016 close. Session
017 therefore takes the planned fork and runs **autonomously on the
engineering half** (`TRANSFER` event handling + the gift-flow decision + M4
close bookkeeping).

**What that costs you:** nothing today — but **M4's final accept line (a real
sandbox purchase in the TR + SA storefronts flipping Premium on both phones)
cannot be proven until item 0 exists.** M4 will be marked honestly as
"engineering complete, sandbox proof pending operator item 0", not silently
closed. Item 0 is unchanged and still the single highest-value thing you can
do.

## Expected from you right now: **nothing blocking — but item 0 is the LAST thing standing between the app and a real test purchase.**

Session 016 built the surface that sells: the app now has a real **paywall**
(annual-first, 7-day-trial messaging, "one subscription — Premium for both of
you", prices rendered exactly as the store localizes them) and the first
**premium gate** — a "Question packs" entry on your daily screen that unlocks
with Premium while **the daily question and streak stay free forever, proven
by tests, with zero paywall interruptions in the daily loop**. Everything runs
against mocked store data because there is no RevenueCat account yet (item 0):
the paywall honestly shows "store unavailable" on a real device until the key
exists. Nothing was needed from you this session. The design was adversarially
reviewed *before* implementation (the blocking catch this time: a returning
user's app-start would silently skip the RevenueCat sign-in, which would have
blocked every purchase on the most common path) and the after-implementation
review confirmed five small findings, all fixed the same session.

## 0. NOW DUE: RevenueCat account + App Store Connect app record (M4.3 hard-requires it)

- **What:** (a) create a free **RevenueCat account** (revenuecat.com — takes
  minutes, just an email; name the project Hayati and note the **iOS API
  key**); (b) once your **Apple Developer enrollment** (promised 2026-07-08)
  lands, create the **App Store Connect app record** for `com.hayati.app` and
  the subscription products (the session will spec the TR/SAR/USD tiers with
  you).
- **Why NOW:** the paywall + purchase plumbing is DONE and waiting. The next
  session (M4.3) forks on this item: with it, the session wires the live
  store and proves a real sandbox purchase flipping Premium — **the M4
  accept line**; without it, M4.3 ships the remaining engineering
  (gift/transfer handling) and M4 stays honestly marked "sandbox proof
  pending" until you create these two accounts.
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

## Progress & readiness snapshot (as of Session 016 close)

- **Plan progress:** M0 ✅ · M1 ✅ · M2 ✅ · M3 ✅ · **M4 2/3** · M5–M6
  pending — **15/22 session-units (68%) in 16 sessions; 7 planned
  session-units left to the MVP** (M4: 1 · M5: 3 · M6: 3; M6.5 Android
  follow-on sits outside the 22-unit MVP count, timed by Gate 3). On track,
  no plan or scope changes in Session 016 (M1's +1 session remains the only
  slippage ever). Note: M4's final accept line (a sandbox purchase in TR +
  SA storefronts) is founder-gated on item 0 — the engineering can finish
  next session either way, but the proof waits for your two accounts.
- **Readiness:** pre-MVP, emulator/CI-proven. Auth, profile+rules, the whole
  pairing loop, the unpaired solo week, the content pipeline, the FULL daily
  loop (server assignment → answer → server-gated mutual reveal → streak
  with grace), the notification logic, the **entitlement backbone**
  (RC webhook → couple mirror → app premium decision point, replay/
  out-of-order-proven), and now the **paywall + premium gating** (annual-first
  paywall over a fully-faked store seam, the reusable premium gate, the
  packs surface locked/unlocked purely on the mirror, free tier
  assertion-protected) are green against emulators and CI. Nothing deployed
  (Spark), nothing on-device (Mac/enrollment pending) — items 0–4 above +
  M4.3–M6 are the path to "runs on your phones with a working paywall".
  Deferred loudly: seasonal question windows (issue #29), the schedule
  trigger + Eventarc retry + webhook Secret Manager binding
  (deploy-verified at first Blaze deploy), `users.fcmTokens` capture + APNs
  (item 4), RC-API reconciliation/backfill for webhooks dropped past RC's
  ~155-minute retry budget (ADR-013; scheduled with the deploy era),
  the RC identity-sync retry hardening (lands with the first live-key
  session, ADR-014), private thread (M5 scope selection),
  `invitePreview.questionText` (W9), gift flow + `TRANSFER` events (M4.3),
  and two quarantined tests (ci-debt #36 reveal round-trip listener race,
  #15 phone-auth simulator crash — at the >2-forces-stabilization
  threshold, not over it).
