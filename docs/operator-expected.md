# Operator Expected — what Hayati needs from you (the founder)

> **Canonical, committed** operator checklist (founder request, Session 009): the
> single place to see what is expected from you, refreshed at every session
> close. Check it after every merge to `main`.
>
> **This file lists ONLY open, actionable items.** Closed items and the
> session-by-session narrative history live in `docs/past-prompts.md`; the
> engineering decisions live in `docs/adr/`. Trimmed to open-items-only on
> 2026-07-24 (Session 036), and a full **Apple registration + TestFlight
> roadmap** added at your request.

_Last refreshed: 2026-07-24, **Session 036 close**. Autonomous engineering has
reached its operator-dependency boundary — the whole MVP is built, tested and
merged (M1–M6.3, the consent/legal layer, CI, and the entire UI/UX redesign),
and every remaining item below needs **you**. Nothing here is blocked on more
code; it is blocked on accounts, keys, an enrollment, and a few reviews._

---

## TL;DR — the whole remaining product is a handful of your decisions

| # | What | Blocks | Effort |
|---|---|---|---|
| **6** | Pick the AI provider + make an API key | the live coach (M5.3) | ~15 min + a billing acct |
| **2** | Turn on Firebase **Blaze** billing | the first backend deploy | ~5 min |
| **4** | **Apple Developer enrollment** → TestFlight (see the Apple roadmap ↓) | on-device / signed builds | enrollment + setup |
| **0** | RevenueCat account + App Store Connect subscription products | the real sandbox purchase | ~30 min |
| **3** | Enable Apple + Phone sign-in in the Firebase console | real-device sign-in | ~5 min |
| **5** | **Security:** rotate the leaked Slack webhook | (also switches CI alerts on) | ~10 min |

**Before PUBLIC launch (not blocking TestFlight/on-device):** native content
review (**1**), the crisis-content safety review (**★**), the legal bundle
(**9**), and the store-listing decisions (**8**). **Non-blocking decisions:**
coach retention (**7**) and the two/three design questions (**#67 / #63 / #71**).

**The single most important next move for you right now, since you're doing
TestFlight:** finish the **Apple enrollment**, then walk the roadmap below.

---

# 🍎 Register Hayati with Apple & ship it to TestFlight — the detailed roadmap

This is the end-to-end path from "I have an Apple ID" to "Hayati is installed on
my iPhone via TestFlight." It is verified against this repo's actual config:
bundle id **`com.hayati.app`** (pinned in the Xcode project and
`fastlane/Appfile`), **Sign in with Apple** entitlement already declared,
flavor entrypoints **`lib/main_dev.dart` / `lib/main_prod.dart`** (no `--flavor`
schemes), **SwiftPM-first (no Podfile — ignore any `pod install` advice)**,
export-compliance pre-answered in Info.plist, and app version **`0.1.0+1`** in
`app/pubspec.yaml`.

**You need:** the Mac + the iPhone 17 (you have both), and the **paid Apple
Developer Program** ($99/yr). There are two build paths — do **Path A** for your
very first TestFlight build (fastest, all on the Mac), and set up **Path B** (the
CI secrets) so every later build is a one-line tag push.

---

## Step 0 — Enroll in the Apple Developer Program (the one gate on everything Apple)

1. Go to **developer.apple.com** → **Account** → enroll in the **Apple Developer
   Program** (individual is fine; $99/yr). Enrollment can take anywhere from a
   few hours to a couple of days for Apple to approve.
2. **Verify it is ACTIVE before doing anything else:** developer.apple.com →
   Account → your membership must read **"Apple Developer Program"** (paid), not
   just **"Apple Developer"** (free). **Nothing below works on the free tier —
   TestFlight and Sign in with Apple both require the paid program.**
3. On the Mac: install **Xcode** (latest stable from the Mac App Store — new
   enough for the iPhone 17 / current iOS SDK). Launch it once, accept the
   license, let components finish. Then **Xcode → Settings → Accounts → `+`** →
   sign in with your enrolled Apple ID; your **Team** should appear.
4. On the Mac: install **Flutter** (stable), clone this repo, run
   `flutter doctor` and clear any iOS-section complaints, then
   `cd app && flutter pub get`.
5. On the iPhone: install the **TestFlight** app (App Store), signed in with the
   Apple ID you'll invite (using your own enrolled Apple ID is simplest).

## Step 1 — Register the bundle ID (once)

1. developer.apple.com → **Certificates, Identifiers & Profiles** →
   **Identifiers** → **`+`** → **App IDs** → type **App**.
2. **Description:** `Hayati`. **Bundle ID: Explicit**, exactly **`com.hayati.app`**
   (any other string will not build — it is pinned in the Xcode project and
   `fastlane/Appfile`).
3. **Capabilities:** tick **Sign in with Apple** (the entitlements file already
   declares it — a build without this capability fails validation). Push
   Notifications and App Attest can be added later by editing the App ID (Xcode
   regenerates profiles automatically).
   - *Shortcut:* Xcode's automatic signing (Step 5) can register the App ID for
     you, but doing it here makes the capability state explicit — and you need
     the identifier to exist for Step 2 anyway.

## Step 2 — Create the App Store Connect app record (once — this is half of item 0)

1. **appstoreconnect.apple.com** → **My Apps** → **`+`** → **New App**.
2. **Platform** iOS · **Name** `Hayati` (the public/TestFlight display name — if
   Apple says it's taken, pick a variant; it can change before launch — see item
   8(a)) · **Primary language** Turkish or English (your call) · **Bundle ID**
   `com.hayati.app` (appears in the dropdown after Step 1) · **SKU** `hayati-ios`
   (internal, never shown) · **Full Access**.
3. **Do NOT create subscription products yet** unless a session specs the tiers
   with you (item 0). ⚠️ **When you do: leave "Family Sharing" OFF — this is
   IRREVERSIBLE** (ADR-015; Apple can't turn it off once on, and it would create
   a second entitlement source our server doesn't control).

## Step 3 — Create the App Store Connect API key → the three CI secrets (enables Path B)

This is what lets CI sign and upload builds for you (Path B). Do it once.

1. appstoreconnect.apple.com → **Users and Access** → **Integrations** → **Keys**
   → generate a key. **Role: App Manager** is enough. Download the **`.p8`** file
   (Apple lets you download it **once** — keep it safe) and note the **Key ID**
   and **Issuer ID** shown on that page.
2. Put the three values into GitHub as **environment** secrets (NOT plain repo
   secrets — the release pipeline reads only the environment, ADR-021):
   - GitHub repo → **Settings → Environments → `release`** (it exists / auto-creates) → add:
     - **`ASC_KEY_ID`** = the Key ID
     - **`ASC_ISSUER_ID`** = the Issuer ID
     - **`ASC_API_KEY_P8`** = the **full text** of the `.p8` file (open it in a
       text editor, paste everything including the `-----BEGIN/END-----` lines)
3. That's it. Until these three exist, the release pipeline's signing step
   **fails closed with a message naming exactly what's missing** — that red is
   expected and honest, not a bug.

## Step 4 — Enable the sign-in providers in Firebase (item 3, ~5 min — do this BEFORE first launch)

Firebase console → **Authentication → Sign-in method** → enable **Apple** and
**Phone** on **both** projects (`hayatiapp-dev`, `hayatiapp-prod`). Free-tier
auth provider init is console-only (no CLI path). **If you skip this, sign-in
fails on the device.**

## Step 5 — Build & upload to TestFlight

### Path A — the manual first build (fastest; all on the Mac, no CI secrets needed)

1. Open `app/ios/Runner.xcworkspace` in Xcode → **Runner** target → **Signing &
   Capabilities** → tick **Automatically manage signing** → **Team:** your team.
   Xcode mints the certificate + provisioning profile itself.
2. Build the **prod** flavor (TestFlight builds carry prod config):
   ```sh
   cd app
   flutter build ipa --release -t lib/main_prod.dart
   ```
   Leave `REVENUECAT_IOS_API_KEY` out until item 0's account exists — the paywall
   then shows the honest "store unavailable" state **by design**; everything else
   works.
3. Output: `app/build/ios/ipa/*.ipa` (and `app/build/ios/archive/Runner.xcarchive`).
   Version is pubspec's `0.1.0+1`; **every later upload needs the build number
   after `+` bumped** (`+2`, `+3`, …).
4. **Upload:** install Apple's **Transporter** (free, Mac App Store) → sign in →
   drag the `.ipa` in → **Deliver**. *(Alternative: open the `.xcarchive` in
   Xcode → Window → Organizer → Distribute App → App Store Connect → Upload.)*
5. **Export compliance is pre-answered** (`ITSAppUsesNonExemptEncryption=false`
   ships in Info.plist — Hayati uses only standard TLS), so Apple should NOT
   prompt. If it appears anyway, answer "only exempt/standard encryption."
6. Processing takes ~5–30 min; the build then appears in App Store Connect →
   Hayati → **TestFlight** tab.

### Path B — the automated release lane (every build after the first, hands-free)

Once the three `ASC_*` secrets exist (Step 3), pushing a git tag
**`vX.Y.Z`** that matches `app/pubspec.yaml`'s version runs `release.yml`:
metadata lint → the full emulator integration suite → a real prod release build
(200 MB size cap) → **sign & upload to TestFlight**. A session (or you) tags a
release; no per-build Mac work. *(The first automated run may need one Mac-era
fix — the automatic-signing `DEVELOPMENT_TEAM` build setting, since no secret
carries your team id yet; a session handles it when you're ready.)*

## Step 6 — Install on your iPhone (and add your partner)

1. App Store Connect → Hayati → **TestFlight** → **Internal Testing** → **`+`** →
   create a group (e.g. `Founders`) → add yourself. **Internal groups get builds
   instantly, no Beta App Review**, up to 100 testers.
2. Your partner: **Users and Access** → invite her Apple ID (any modest role) →
   add her to the internal group. *(External groups exist but require a Beta App
   Review pass — internal is the right lane for the founder couple.)*
3. On the iPhone: open **TestFlight** → the build appears (or accept the email) →
   **Install**. Done — Hayati is on your phone.

## What the TestFlight build can prove today — and what still waits on other items

- **Works immediately:** launch, onboarding/brand UI, localization (TR/AR/EN,
  RTL), the solo-question UI, deep-link delivery (`hayati://invite/<code>`),
  Sign in with Apple's full-name capture — **after** Step 4 enables the provider.
- **Needs item 2 (Blaze + first deploy):** pairing, the daily loop, reveal,
  streaks, entitlements — all **eleven** Cloud Functions have never been deployed
  (Spark plan). Without the deploy, the TestFlight app is a beautiful shell over
  a missing backend. *(To run most of the product on your phone TODAY without a
  deploy, see the cable/dev-rig appendix at the very bottom.)*
- **Needs item 0:** real paywall content + the sandbox purchase. TestFlight
  builds hit the sandbox store automatically once RevenueCat + the subscription
  products exist.
- **Needs item 6:** the coach answers with the honest "not configured" state
  until the LLM key exists.
- **Won't fire yet regardless:** push notifications (APNs + the app-side token
  capture are the item-4 device half, not in this binary).

## On-device verification backlog (item 4 — these can ONLY be checked on the real iPhone)

Built and emulator-proven; please eyeball each on the TestFlight build:

1. **Keychain round-trip** — set a PIN, force-quit, relaunch → must ask for the
   PIN. Then **delete the app, reinstall, launch → it must STILL ask for the
   PIN** (the reinstall-bypass defence; if it opens straight in, that's a real
   hole — tell a session immediately).
2. **Face ID self-revoke** — turn it on, lock, unlock with Face ID. Then
   change/add a face in iOS Settings and reopen Hayati → it must have switched
   Face ID **off** by itself and demand the PIN.
3. **Discreet icon** — flip it in Settings. iOS shows its own "you changed the
   icon" alert (Apple's, expected, unsuppressible). Confirm the icon changes and
   the **name under it does not**.
4. **App-switcher snapshot** — open the coach or a revealed answer, swipe to the
   app switcher → the Hayati card must show a **blank panel**, never your content.
5. **Cold-start stopwatch** — time a cold launch of the **prod** build
   (airplane-mode + normal). CI deliberately doesn't assert the <2s number; your
   phone is where the honest number comes from.
6. **Issue #15** — if phone-auth sign-in crashes natively, capture the log
   (Xcode → Window → Devices → Open Console) — that's a bountied item-4 checkbox.
7. Also: Apple first-authorization full name reaching `displayName`; deep-link
   cold+warm OS→app delivery; the real-device pairing test (pairs with item 2).

**Recommended order:** Step 0 (enroll) → Steps 1–2 (register + app record) →
Step 4 (providers) → **Step 5 Path A** (first TestFlight build) + Step 6 (install)
→ Step 3 (CI secrets, for Path B) → flip Blaze (item 2) so a session runs the
first deploy and the loop comes alive on the phone.

---

# The gates that block remaining engineering

## 6. **DUE NOW** — LLM provider decision + API key (the live coach, M5.3, waits on this alone)

- **What:** pick the AI provider for the coach and create an API key. The server
  seam is provider-agnostic; nothing in the code commits to anyone, and the
  choice is reversible. The key goes into **Secret Manager at deploy** (like the
  RC webhook token) — never into the repo.
- **The numbers** (published $/M tokens in/out; ≈ cost per coach message):
  Anthropic Claude — Haiku 4.5 $1/$5 (≈$0.005/msg); Sonnet $3/$15 (≈$0.014/msg);
  Opus 4.8 $5/$25 (≈$0.023/msg). The shipped caps (30/day per person, 1,000/month
  per couple) bound worst-case spend to ≈$14/mo/couple at Sonnet pricing. Quality
  in Gulf Arabic + Turkish is the differentiator; OpenAI/Gemini are viable behind
  the same seam.
- **Note (S023 handoff):** M5.3 is a recorded **re-consent trigger** — its ADR
  bumps the legal version, names the provider in the notice/policy, re-gates
  every user, and adds the provider row to `docs/dpa-inventory.md`.

## 2. Blaze plan decision — deploying Cloud Functions requires it

- **What:** upgrade `hayatiapp-dev`/`hayatiapp-prod` from Spark (free) to **Blaze**
  (pay-as-you-go).
- **Status:** eleven Functions — the five loop/invite units (`createInvite`,
  `invitePreview`, `joinInvite`, scheduled `questionRollover`, triggered
  `answerReveal`), `revenueCatWebhook`, `coachProxy`, and the four data-rights
  callables (`deleteAccount`, `exportData`, `updateNotificationPrivacy`,
  `recordConsent`) — all emulator-proven; **nothing deployed yet.** Deploy-verified
  only: the rollover's Cloud Scheduler trigger, `answerReveal`'s Eventarc retry,
  and the webhook's `RC_WEBHOOK_TOKEN` Secret Manager binding + public URL.
- **When needed:** the first deploy + real-device pairing test; hard requirement
  before the first TestFlight of the live loop. The RC webhook can only be
  configured against a deployed URL, so the live entitlement loop waits on this.
- **Cost:** couple-scoped workload ≈ near-zero at dev scale; set budget alerts.

## 4. Apple Developer enrollment — **see the Apple roadmap above**

The Mac + iPhone 17 are in hand; the only remaining gate is the enrollment
itself. The release lane is BUILT and fails-closed until the three `ASC_*`
secrets land (roadmap Step 3). Also riding this item: **App Attest** (App Check
enforcement stays OFF in both consoles until on-device attestation is verified),
**APNs** (the M3.4 notification logic is done and waiting on the device half —
APNs registration + `users.fcmTokens` capture), **dSYM upload** for Crashlytics,
and **Universal links** (a domain decision, not urgent — custom scheme ships).

## 0. RevenueCat account + subscription products (the real sandbox purchase)

- **What:** (a) create a free **RevenueCat account** (revenuecat.com — minutes;
  name the project Hayati, note the **iOS API key**); (b) once enrolled, create
  the **subscription products** in App Store Connect (a session specs the
  TR/SAR/USD tiers with you). The app-record half is Steps 1–2 of the Apple
  roadmap — you can do it yourself.
- **Why it matters:** the paywall, purchase plumbing, entitlement server and
  transfer handling are **all done and waiting**. M4's acceptance line — *a real
  sandbox purchase in TR + SA flipping Premium on both phones* — cannot advance
  without these two accounts.
- **How it plugs in:** the iOS API key is a publishable key passed at build time
  (`REVENUECAT_IOS_API_KEY` dart-define); without it the app fails closed to the
  honest "store unavailable" state.
- **Security (ADR-013):** when the RC *webhook* is configured at deploy, its
  `Authorization` token must be a **long random string (≥256-bit)** — a session
  generates it with you; don't reuse a password.
- ⚠️ **IRREVERSIBLE:** leave **"Family Sharing" OFF** on every subscription
  product (ADR-015 — one-way door).

## 3. Enable Apple + Phone sign-in providers — **see roadmap Step 4** (~5 min)

## 5. **SECURITY — rotate the leaked Slack webhook, then CI alerts turn on** (~10 min, open since S005)

The local branch `chore/slack-notifications` (commit `13f1e6d`) has a **live
Slack webhook URL in plaintext** inside a workflow file. It never reached GitHub
(push protection blocked it), but a credential in a git commit is a leaked
credential. The CI→Slack wiring is built, tested and merged, and stays **silent
until you do these four steps** (it never spams, never warns, never reddens a
build for a missing secret):

1. **Revoke the old webhook** in Slack: api.slack.com/apps → the owning app →
   *Incoming Webhooks* → remove it. **Do NOT push/merge the
   `chore/slack-notifications` branch** — it's just the evidence of which webhook
   to revoke. After revoking, `git branch -D chore/slack-notifications` is safe.
2. **Create a fresh Incoming Webhook:** api.slack.com/apps → *Create New App →
   From scratch* → name `Hayati CI` → your workspace → *Create App* → **Features →
   Incoming Webhooks → Activate ON → Add New Webhook to Workspace** → choose the
   channel → *Allow* → copy the URL. **It must be an *Incoming Webhook*, NOT a
   Workflow-Builder webhook** (the latter silently 400s our messages).
3. **Store it as a REPOSITORY secret** (NOT the `release` environment — the
   notifier has no environment binding so it can report a *failing* signing job;
   an environment secret would be invisible and fail silently):
   ```sh
   gh secret set SLACK_WEBHOOK_URL --body 'https://hooks.slack.com/services/…'
   ```
4. **Confirm:** the next push to `main` posts the first message. If not, read the
   run's `slack-notify` job log — one line says why.

**What you get:** failures always (PRs + main); successes only on main/manual
re-run/release; branch, commit, actor, run link and a per-job line — **never any
log content**. The one CI event with *no other reader* is a failing
`integration-emulator` on `main` (runs only after merge, when the session has
moved on) — that's the message this exists to deliver.

---

# Before PUBLIC launch (none of these block TestFlight or on-device testing)

## 1. Native review of the app content (TR by you two, AR by a Gulf-dialect reviewer)

AI-drafted, marked review-PENDING; native review is mandatory before any public
launch (`content/README.md`, W9). All editable in place, or send corrections to a
session:

- **Solo questions** (7 × TR/AR/EN) — `content/packs/solo_{tr,ar,en}.json`; run
  `dart content/validator/validate.dart --sync`. These double as the **couple**
  question bank placeholder, so edits pay off twice.
- **Paywall / pack copy** (~28 strings × TR/AR/EN) — `app/lib/core/l10n/arb/`
  (keys `paywall`/`packs`/`packSelection`).
- **Coach chat copy** (27 strings × TR/AR/EN) — keys `coach*`, plus persona/register
  TONE blocks in `functions/src/coach/persona-prompts.ts` (safety lines are the ★
  gate). Includes the Perisi/ملهم persona-naming call.
- **Lock & settings copy** (41 strings) — keys `lock*`/`settings*`. Two carry
  **safety** meaning worth your eyes: the **Face ID warning** (factual caution,
  not accusation) and the **"Forgot PIN?"** copy (recovery signs you out, doesn't
  quietly let someone in).
- **Data-rights copy** — keys `dataRights*`/`coupleEnded*`/`settingsNotificationPrivacy*`.
  Three carry legal/safety weight: the **deletion confirmation** (irreversible;
  "both of you"), the partner's **"shared space closed" notice** (calm,
  non-blaming, never names who), and the **"does not cancel your subscription"**
  line (users act on it with money involved).
- **Store listing** (`fastlane/metadata/{tr,en-US}`) + the localized **Face ID**
  and **Local Network** purpose strings (`app/ios/Runner/{en,tr,ar}.lproj/InfoPlist.strings`).

## ★ Crisis-content safety review — **the one gate before the coach runs on a real device**

The crisis word-lists (TR / AR incl. Arabizi / EN), the professional-help
response, the "not therapy" disclaimer, and the safety lines of the coach's
system-prompt preamble are AI-drafted and marked `nativeReview: PENDING`. **An
under-reading crisis filter is a safety failure — only native speakers can judge
the lists.** TR: you two (~15 min). AR incl. Arabizi: your Gulf reviewer.

- **Also here:** crisis-hotline numbers are deliberately NOT in the app (a wrong
  number is dangerous) — choose the TR/SA numbers you trust and a session wires
  them in. (A CI test fails if a phone-number-shaped string is added to coach
  copy without going through this gate.)
- **Where:** `functions/src/coach/crisis-lexicon.ts`,
  `functions/src/coach/help-content.ts`, `functions/src/coach/persona-prompts.ts`,
  and `coachDisclaimerBody` in `app/lib/core/l10n/arb/`.
- **When:** blocks the first on-device coach use (rides item 4's timeline).

## 9. The legal bundle — your review, three blanks, three lawyer questions, one filing

The six documents at `docs/legal/` (privacy policy + terms × TR/AR/EN — also in
the app under Settings → Privacy & Terms) are AI-drafted against the shipped code
and marked review-PENDING. Before public launch:

- **(a) Native + legal review** of the six docs. TR: you two (~5 min; the policy
  doubles as the KVKK aydınlatma metni). AR: your Gulf reviewer. Legal: your
  lawyer. A material change bumps the version and re-asks everyone's consent
  (session mechanics).
- **(b) Three blanks only you can fill** (bracketed in every doc): the
  controller's legal identity (your name or a company), a contact address, and
  the governing law.
- **(c) Three recorded lawyer questions** (in `docs/legal/README.md` + ADR-023):
  **A** — is relationship-content processing special-category under KVKK Art 6 /
  PDPL (we implemented conservative YES)? **B** — may the one consent be required
  to use the reflective features (required, but sign-out/export/delete always
  open)? **C** — must consent withdrawal *erase* stored reflections, or does
  stop-collecting + self-serve deletion suffice (we implemented the latter, for
  the DV reason)?
- **(d) One real legal action — the KVKK data-transfer filing.** Hosting TR
  users' data on Google's EU servers is a cross-border transfer under amended
  Art 9: sign Google's Kurul-approved standard contract and **file it with the
  Kurum within 5 business days of signing**. Evidence/links in
  `docs/dpa-inventory.md`. Needed before PUBLIC launch, not for TestFlight.
- **(e) Also recorded, none urgent:** the Kurul "adequate measures" question;
  the seven PDPL items before the first Saudi user; a GDPR flag for the Phase-4
  EU-diaspora channel; İYS registration before any promotional push.

## 8. Store-listing decisions + the missing web pages (pre-submission, none blocking)

- **(a) The name "Hayati" is provisional** (a known vape-brand collision in some
  markets). Run the trademark/store-name search; vetted alternates (İkimiz,
  Baynana, Mawadda, Roohi) are in the brandkit + ADR-020; a rename costs one
  metadata line. Apple may also reject the name as taken at Step 2 — same fallback.
- **(b) The home-screen label** is "Hayati App" today; the discreet icon can't
  change it (an honest bound in the app's own copy). Keep it, rename to "Hayati",
  or pick a neutral label — your call (ADR-020 D2). The session that changes it
  re-audits the discreet-icon copy in the same commit.
- **(c) Privacy-policy + support-page URLs don't exist** — the store listing
  ships EMPTY URL fields behind a loud CI warning (never a fake URL). Apple
  requires both at submission; the in-app requirement is already met by the
  in-app documents. Needs a **domain choice + hosting**; the policy TEXT exists
  (item 9). When hosted, a session drops the lint's `--allow-empty-urls` flag.
- **(d) Age rating:** verify at first submission — whether Apple's questionnaire
  treats the AI coach as a maturity factor is only provable in App Store Connect.
  If it forces a higher tier, the choice (constrain vs accept) is yours.
- **(e) App Privacy questionnaire** — the manifest ships
  (`app/ios/Runner/PrivacyInfo.xcprivacy`). Four recorded judgment calls to
  resolve against the questionnaire: (i) the App Privacy labels must match the
  declared types (contact info, User ID, Other User Content, Purchase History,
  Crash Data — all non-tracking); (ii) whether couples' free-text + coach content
  warrants Apple's **"Sensitive Info"** category (the manifest omits it — Apple's
  taxonomy ≠ KVKK's); (iii) Crash Data declared **not linked** to identity —
  confirm; (iv) the **Local Network** purpose string ships in prod for the dev
  rig (prod makes no LAN connections) — decide keep/reword/strip at submission.

---

# Non-blocking decisions (nothing waits on these)

## 7. Should coach conversations ever be SAVED? — the private-thread retention decision

Today coach chats are **ephemeral** (nothing on the server or the phone; a fresh
start is a fresh conversation; sign-out wipes instantly) — the most protective
posture. Options: **(a) ephemeral forever** (simplest, safest); **(b) a saved
private thread per person** (`coach_sessions`, ~30-day auto-delete — needs your
retention window, rules guaranteeing a partner can never read the other's thread,
and inclusion in export/delete). No engineering waits on this; ephemeral works
indefinitely.

## #67 — two brand colours that don't exist yet (the gate on a final Settings polish)

The brand kit's nine colours are all full-strength; real UIs also need two
*quieter* roles: **secondary text** (the grey line under a settings-row title)
and **lines/borders** (row separators, an off-switch outline). Both use Flutter's
defaults today. Session 028 tried fading `sand` and found it **dimmed the
toggles** (a switch borrows those exact colours for its "off" look), so it was
reverted. Options: **(a)** add two named brand colours (a "muted text" tone + a
"line" tone, picked so switches still read active — cleanest); **(b)** faded
`sand` with fade levels chosen + contrast measured; **(c)** keep Flutter's
defaults and say so. Your answer unblocks a short Settings-polish follow-up
(subtitle tone + section dividers).

## #63 — Phosphor vs Material icons

The brand kit names **Phosphor** icons; the app ships **28 Material** icons and
Phosphor was never added. Options: **(a)** switch to Phosphor (new dependency, 28
icons re-drawn, a size increase, and hand-mirrored twins for every directional
icon since Phosphor won't auto-flip in Arabic); **(b)** update the brand kit to
say Material (cheapest, honest — Material outline reads well with the brand;
**the recommendation** unless you have a view). Either is fine; a Phosphor switch
would be its own "slice 1.5" session.

## #71 — a motion token in the brand kit

Motion is defined in brand-kit §6 prose (150–300ms, ease-out) but has no token in
`hayati-tokens.json`; the app realises it as `MotionTokens` (review-enforced). A
brandkit-revision decision, parallel to #67 — add a `motion` block to the tokens
JSON and the parity test could check it mechanically. Non-blocking.

---

# Current state snapshot (Session 036 close)

- **Plan progress:** M0–M4 engineering ✅ · M5: 2/3 (spine + chat UI; **M5.3 live
  adapter blocked on item 6**) · M6.1–M6.3 ✅ · consent/legal buildable half ✅
  (ADR-023) · CI→Slack ✅ (ADR-024) · **the entire UI/UX Pro Max redesign ✅**
  (ADR-025, slices 0–8, plus the #74 DRY tidy in S036). **M6.5 Android** sits
  outside the MVP count; its timing is your Gate-3 call (ADR-006).
- **Readiness: engineering ~95%, operational proof 0%.** Everything is
  emulator/CI-proven; **nothing has ever been deployed** (item 2), the app has
  **never run on a real phone against a real backend** (items 3+4), and **no real
  purchase has ever happened** (item 0). That gap is not engineering — it is the
  account/billing/enrollment decisions on this page.
- **What's built and waiting:** auth, profile + rules, the whole pairing loop,
  the solo week, the content pipeline, the full daily loop (assignment → answer →
  server-gated reveal → streak), the notification *logic*, the entitlement
  backbone (RC webhook → couple mirror → premium decision), the paywall + premium
  gating, the coach safety spine + chat UI (ephemeral, fail-closed provider seam),
  the device-privacy layer (PIN at root, Keychain-persisted, Face ID self-revoke,
  discreet icon, app-switcher blank), the data-rights layer (export + hard
  cascade delete), the release-readiness layer (tag-triggered `release.yml`,
  fail-closed signing), and the consent & legal layer (server-recorded
  version-stamped consent + TR/AR/EN policy/terms in-app).
- **Autonomous engineering is at its operator-dependency boundary.** Until you
  unblock item 6, 2, or 4, sessions will correctly find no engineering work and
  say so rather than invent busywork — that is the design, not a stall.

---

# Appendix — test Hayati on your iPhone TODAY, over a cable, before the enrollment lands

The TestFlight path above is the *distribution* lane and needs the enrollment.
This is the *developer* lane — Xcode installs the app straight onto your own
phone over a cable, and most of the product runs against the **Firebase
emulators on the Mac** (a dev rig; throwaway data; nothing deployed). Verified
against this repo (the app ships a LAN host override for exactly this;
SwiftPM — no `pod install`).

1. **Mac (once):** Xcode 26 + Flutter + `cd app && flutter pub get`; the emulator
   toolchain — Node, a **Java 21+** runtime on PATH, `firebase-tools@15.22.4`,
   then `firebase login`; build the functions once per pull
   (`cd functions && npm ci && npm run build`).
2. **iPhone (once):** cable → **Trust**; Settings → Privacy & Security →
   **Developer Mode** → on → restart.
3. **Signing:** if the paid enrollment is active, use Xcode automatic signing
   with your team. **If not**, a **free personal team** still installs on your own
   phone, with three costs: **(a)** delete the `com.apple.developer.applesignin`
   key/array from `app/ios/Runner/Runner.entitlements` **locally** and
   `git checkout` it before any commit (Sign in with Apple is paid-only; the
   phone-number lane doesn't touch it); **(b)** the install expires after **7
   days** (re-run to renew); **(c)** approve yourself under Settings → General →
   VPN & Device Management.
4. **Emulator rig (each test day):** locally change all three `"host": "127.0.0.1"`
   in `firebase.json` to `"0.0.0.0"` (**never commit — revert after**), then
   `firebase emulators:start --only auth,firestore,functions --project hayatiapp-dev`
   (**the project id must be `hayatiapp-dev`, not the CI `demo-hayati`** — the app
   carries `hayatiapp-dev` baked in, and CI's id would 404 every callable). The
   phone sign-in codes print in this terminal. Get the Mac's IP:
   `ipconfig getifaddr en0` (phone + Mac on the same Wi-Fi).
5. **Install & run:**
   ```sh
   cd app
   flutter run --release -t lib/main_dev.dart \
     --dart-define=USE_AUTH_EMULATOR=true \
     --dart-define=USE_FIRESTORE_EMULATOR=true \
     --dart-define=USE_FUNCTIONS_EMULATOR=true \
     --dart-define=AUTH_EMULATOR_HOST=<the-Mac-IP>
   ```
   Allow **Local Network** when iOS asks. The **partner** is the iOS Simulator on
   the Mac (same command, no `--release`, no `AUTH_EMULATOR_HOST`); sign it in
   with **Google**.
6. **What runs:** phone sign-in, the consent screen, the whole solo week, invite
   creation + deep-link delivery (type `hayati://invite/<CODE>` in Safari, warm +
   cold), the lock layer, export + delete cascade, the in-app legal docs, TR/AR/EN
   + RTL, and the four M6.1 lock checks. **Two honest bounds** (neither a bug):
   the **final join tap** and the **couple daily loop** don't run on this rig (the
   preview URL is code-pinned to the CI project id, and the day's question doc is
   written only by the scheduled `questionRollover`, which the emulator never
   fires). Both lift with the **dev-rig slice** (say "build the dev-rig slice") or
   the first real deploy (item 2).
7. **Teardown (IMPORTANT):** Ctrl-C the emulators; then `git status` must be
   **clean** — revert any local edits
   (`git checkout -- firebase.json app/ios/Runner/Runner.entitlements`). Neither
   may ever reach a commit.
