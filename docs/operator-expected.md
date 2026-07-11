# Operator Expected — what Hayati needs from you (the founder)

> **Canonical, committed** operator checklist (founder request, Session 009): the
> single place to see what is expected from you, refreshed at every session
> close. It replaces the two untracked root scratch files (`FOUNDER-ACTIONS.md`,
> `OPERATOR-EXPECTED.md`), whose content was consolidated here on 2026-07-09.
> Sessions update this file with docs-with-code discipline (rule #8); check it
> after every merge to `main`.

_Last refreshed: 2026-07-11, Session 015 close (M4.1 — entitlements
foundation; **M4 opened, 1/3**)._

## Expected from you right now: **nothing is blocking — but the next session can use item 0.**

Session 015 built the money plumbing's server half, entirely emulator-side:
a webhook Function now translates RevenueCat's purchase/renewal/cancellation/
expiry events into a couple-scoped entitlement record — **one purchase will
unlock premium for BOTH of you, and an expiry downgrades both** — proven
against replayed, duplicated, and out-of-order events (payments infrastructure
is where event chaos actually happens). The app can now ask "is this couple
premium?" through one provider; nothing in the UI changes yet because there
is no paywall to show — that's the next session. Nothing was needed from you
this session. The design was adversarially reviewed *before* implementation
(it caught a genuine would-have-been-costly bug: a failed credit card with no
grace period configured would have minted permanent free premium) and the
code review after implementation confirmed zero findings.

## 0. NEW and now useful: RevenueCat account + App Store Connect app record (M4.2 wants it, M4.3 needs it)

- **What:** (a) create a free **RevenueCat account** (revenuecat.com — takes
  minutes, just an email; name the project Hayati and note the iOS API key);
  (b) once your **Apple Developer enrollment** (promised 2026-07-08) lands,
  create the **App Store Connect app record** for `com.hayati.app` and the
  subscription products (the session will spec the TR/SAR/USD tiers with you).
- **Why:** Session 016 (M4.2, the paywall) builds UI + purchase plumbing
  against mocked store data and **does not block on this** — but the
  live-sandbox proof (a real test purchase flipping premium on both phones)
  needs both, and M4.3 (gift flow + sandbox accept lines) hard-requires them.
- **One security note for later (ADR-013):** when the RC *webhook* is
  eventually configured (that's a deploy-time item, see item 2), its
  `Authorization` token must be a **long random string (≥256-bit)** — it is
  the only thing authenticating RevenueCat to our server. The session will
  generate one with you; don't reuse a human password.

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

## Progress & readiness snapshot (as of Session 015 close)

- **Plan progress:** M0 ✅ · M1 ✅ · M2 ✅ · M3 ✅ · **M4 1/3** · M5–M6
  pending — **14/22 session-units (64%) in 15 sessions; 8 planned
  session-units left to the MVP** (M4: 2 · M5: 3 · M6: 3; M6.5 Android
  follow-on sits outside the 22-unit MVP count, timed by Gate 3). On track,
  no plan or scope changes in Session 015 (M1's +1 session remains the only
  slippage ever).
- **Readiness:** pre-MVP, emulator/CI-proven. Auth, profile+rules, the whole
  pairing loop, the unpaired solo week, the content pipeline, the FULL daily
  loop (server assignment → answer → server-gated mutual reveal → streak
  with grace), the notification logic, and now the **entitlement backbone**
  (RC webhook → couple mirror → app premium decision point, replay/
  out-of-order-proven) are green against emulators and CI. Nothing deployed
  (Spark), nothing on-device (Mac/enrollment pending) — items 0–4 above +
  M4.2–M6 are the path to "runs on your phones with a working paywall".
  Deferred loudly: seasonal question windows (issue #29), the schedule
  trigger + Eventarc retry + webhook Secret Manager binding
  (deploy-verified at first Blaze deploy), `users.fcmTokens` capture + APNs
  (item 4), RC-API reconciliation/backfill for webhooks dropped past RC's
  ~155-minute retry budget (ADR-013; scheduled with the deploy era),
  private thread (M5 scope selection), `invitePreview.questionText` (W9),
  gift flow + `TRANSFER` events (M4.3), and two quarantined tests (ci-debt
  #36 reveal round-trip listener race, #15 phone-auth simulator crash — at
  the >2-forces-stabilization threshold, not over it).
