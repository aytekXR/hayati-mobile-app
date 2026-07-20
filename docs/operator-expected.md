# Operator Expected — what Hayati needs from you (the founder)

> **Canonical, committed** operator checklist (founder request, Session 009): the
> single place to see what is expected from you, refreshed at every session
> close. It replaces the two untracked root scratch files (`FOUNDER-ACTIONS.md`,
> `OPERATOR-EXPECTED.md`), whose content was consolidated here on 2026-07-09.
> Sessions update this file with docs-with-code discipline (rule #8); check it
> after every merge to `main`.

_Last refreshed: 2026-07-20, **Session 028 close** (the UI/UX refactor's first
visual fix). **Nothing is required from you to keep going.** Two design
questions are now waiting whenever you want them — item 10 (Phosphor vs
Material icons) and **new item 12 (two missing brand colours)** — and neither
blocks the next session._

_**Session 028 in one paragraph:** it fixed a real visual defect you would have
seen the first time you used the app on a phone. **Your three most important
confirmation pop-ups — the Face ID warning, the "delete everything"
confirmation, and the consent-withdrawal dialog — were rendering on exactly the
same colour as the page behind them**, with no visual separation at all; and
the "copied to clipboard" bar was a **cream-coloured slab** in an otherwise
dark app. Both were caused by the same thing: Flutter needs to be told several
specific colour slots, and the app had set only one of them — the one almost
nothing reads. Fixed, and now protected by a test. **The session also stopped
itself**: a second part of the planned change turned out to need two colours
the brand kit does not define, the invented values made the settings switches
visibly dimmer, and rather than ship a plausible guess it was dropped and
written up as item 12 for you._

_**Session 027 in one paragraph:** it built the three automated checks that
Session 026 said had to exist before any redesign starts — and two of them
close gaps that were already in the app. **The lock screen now has a real
guard**: the rule that certain common UI elements would crash it (and lock you
out of your own app on the "forgot my PIN" path) was previously just a written
note; now a test enforces it, and it enforces the two spellings a written note
would have missed. **The brand colours are now checked against the brand kit
automatically**, so neither side can drift from the other unnoticed — they
match today. And **the sentences that carry safety or legal meaning are now
frozen**: 96 strings across all three languages, including the consent and
withdrawal wording, cannot be silently reworded — any change turns the build
red and forces a deliberate decision. Nothing you can see changed: zero screen
snapshots moved, which was the session's own success condition._

_**Still the one thing worth doing: item 5 — rotate the leaked Slack webhook**
(a security action, open since Session 005). Ten minutes, four steps, and it
also switches your CI notifications on._

_**What Session 026 did, in one paragraph:** it planned the UI/UX refactor
rather than starting it — deliberately, because the refactor has to be told in
writing which parts of the app it may not touch before anyone moves a pixel.
It installed and actually ran the UI/UX Pro Max tool you asked for, catalogued
all 48 screens and components against their tests, and wrote the plan down as
ADR-025. Three things came out of it that are worth your knowing about, in
item 11 below — including **two real safety/consistency gaps that already
existed in the app** and are now the next session's work._

_Nothing about the product changed this session — no app code was touched.
Session 024's summary (the hardening sweep: the change-PIN flow, the iOS
privacy manifest, a de-quarantined test, CI runtime bumps) and Session 023's
before it (the consent surface + legal bundle) both stand:_

_Session 023 close (mvp item 12 — **the legal
bundle's buildable half: the consent screen, the privacy policy and terms in
three languages, and the processor inventory**: the app now asks each of you
for one clear consent before the reflective features, the legal documents
exist and are readable inside the app itself, and every company that touches
your data is written down in one table — **every line of MVP engineering
that can be built without your input is now DONE; M5.3 is the only planned
unit left and it waits on item 6 alone**). The TestFlight runbook lives
below._

## Expected from you right now: **nothing BLOCKS the next engineering session — but item 5 is a SECURITY action that has been open since Session 005 and is still not done.**

**Do this one first (10 minutes): item 5 — rotate the leaked Slack webhook.** A
live webhook URL is sitting in plain text inside a commit on an old local
branch. It never reached GitHub, but a credential in a git commit is a leaked
credential, and it has been sitting there for roughly twenty sessions because
the checklist entry describing it was **wrong** — it told you to "land the
branch," i.e. to push the credential. That entry is now rewritten as four
concrete steps (revoke → mint a fresh webhook → one `gh secret set` command →
confirm). Doing it also switches your new CI notifications on.

The finish line is still yours: **item 6 (pick the AI provider — OVERDUE since
Session 019; M5.3 is the ONLY planned session-unit left, and it waits on this
alone)** and **item 4 (the Apple Developer enrollment — the release lane is
BUILT and waiting)**. Item 9 (the legal bundle — six documents, three blanks,
three lawyer questions, one KVKK filing) stays open before public launch, and
items 7 (coach-chat retention), 8 (store-listing decisions) and now 10 (the
icon question) stay open, non-blocking. **Both of your 2026-07-14 directives
are now handled:** Slack→CI shipped in Session 025; the **UI/UX Pro Max
refactor** is now fully scoped in ADR-025 (Session 026) and its first slice is
the next session's work.

**Session 023 needed nothing from you mid-flight.** It built the consent
screen, wrote the privacy policy and terms in Turkish, Arabic, and English,
and produced the processor inventory — and recorded precisely what only you
and a lawyer can finish.

**What you should know from this session:**

**0.a. The app now asks for consent — once, honestly, with every exit open.**
Before the daily questions and the coach, each signed-in person sees one
screen: what Hayati stores (your reflections and shared answers — in the EU),
what it only processes in the moment (coach messages — never saved), why
consent is required (this content IS the service), and one clear button. No
pre-ticked boxes, no bundled extras — there is nothing else to consent to,
because analytics and marketing simply don't exist in the app. Anyone who
declines can still sign out, download their data, or delete their account
from that same screen. You two will see it once on your next sign-in — one
tap, then everything is as before. The consent is recorded on the server
with a version and timestamp (that's what makes it provable under KVKK),
it appears in your data export, and it dies with your account.

**0.b. The privacy policy and terms now EXIST — drafted, honest, and waiting
for review (item 9).** They live in the app itself (Settings → Privacy &
Terms, also linked from the sign-in screen and the paywall), which satisfies
Apple's in-app requirement with no website needed yet. Every sentence was
written against what the code actually does and then adversarially reviewed
against it — including catching and fixing a draft line that claimed coach
messages are stored (they are not; the fixed text says "processed in the
moment, without being saved"). The store's URL field stays honestly empty
until you host these texts (item 8(c) — the missing content now exists).

**0.c. Withdrawing consent does NOT delete your data — deliberately, and the
app says so.** Withdrawal (Settings → Privacy & Terms) stops the reflective
features; your stored reflections stay until YOU delete them, with the
delete button offered right there. The reasoning is the same domestic-violence
doctrine as the lock: a one-confirm action must never destroy data — an
auto-erasing withdraw would hand a destruction button to whoever briefly
holds the phone. Whether the law requires more than this is lawyer question
C in item 9.

**0.d. Two review passes, eleven-for-eleven.** The design review before any
code found 10 real defects (including two blocking: consent needed a
server-side enforcement mechanism, not just a screen; and a decliner would
have been trapped without delete/export). The post-build review found 6 more
(including the gate's own safety-net state re-creating the trap it guarded
against, and the coach-storage over-claim above). All fixed before merge.
Tests now: 1,390 app-side / 870 server-side, all green.

**(Retained from the Session 022 close — still current:)**

**0.1. The App Store listing text now exists — and it needs your eyes (TR) before launch.** `fastlane/metadata/` holds the store name, subtitle, description, and keywords in Turkish and English, written in the brand voice and deliberately claiming nothing the app can't do (the privacy paragraph uses the settings screen's own honest wording). It joins item 1's native-review gate. Two decisions inside it are provisional and YOURS (see item 8): the store name "Hayati" (trademark check pending) and whether the on-device label stays "Hayati App".

**0.2. The release pipeline exists, is honest about what it can't do yet — and has now PROVEN it.** Pushing a version tag runs: metadata lint → the full emulator integration suite → a real release build with a size report → and then a signing step that **deliberately fails with a clear message** telling you exactly which secrets are missing and where they go. The proof run happened at session close: every pre-signing stage green on the first real execution, then the honest red at exactly the signing gate, naming the three missing secrets and pointing at item 4. The moment your enrollment lands and you add the three App Store Connect keys, the same pipeline signs and uploads to TestFlight. Nothing pretends; nothing silently skips. First real measurement from that run: **the app is 64 MB uncompressed** — comfortably small.

**0.3. The app starts faster, provably.** The startup path was audited step by step: a timezone-database parse moved off the critical path, two pairs of independent reads now run simultaneously, and a test now pins the exact set of things allowed to run before the first frame — so no future change can quietly slow the boot. First measured numbers (CI simulator, debug build — diagnostics, not the real thing): app boot work ~435 ms, first frame at ~874 ms. What did NOT change: the privacy lock still decides the very first frame (that is a security guarantee, not an optimization target). The honest cold-start numbers still need a real device — that check is on item 4's on-device list.

**0.4. Two small bugs were caught and fixed in the same session, both by the proof runs, not by luck:** a test broken since yesterday's merge (it predates this session and had gone unnoticed — main is green again), and a size-checker that would have silently passed any app size (it now refuses to pass anything it cannot actually measure).

**1. "Delete my account" now exists, and it means it.** Settings → Delete
account & data. It asks twice (and for your PIN if the lock is on), tells you
plainly that it is irreversible, and then deletes everything: your profile,
your solo reflections, your account — and the **entire shared space, both
sides of every answer**. Your partner keeps what was always theirs alone
(their own profile and solo reflections) and loses the shared thread, same
as you. This was the hardest call of the session and it is yours to overturn:
the alternative — each partner keeps their own half of the thread — is
written out in ADR-019 with the honest costs of both options. We chose whole-
thread deletion because the shared conversation is *about both of you* (a
"deleted" relationship record that leaves one side readable has been
redacted, not erased), and because for someone deleting to *escape* a
relationship, nothing they wrote should survive anywhere the partner can
read. One honest bound, stated in the app's own copy: deletion removes the
server's copies — it cannot un-see what a partner already read or
screenshot.

**2. The partner is told honestly — but deliberately NOT pinged.** No push
notification fires when a deletion happens. The other partner learns from a
calm, non-blaming notice the next time they open Hayati ("your shared space
has been closed and its content permanently deleted; your own reflections
are untouched; you can pair again whenever you choose"). The review's
reasoning, recorded in full: a real-time "your space was closed" alert to a
possibly-abusive partner at the exact moment a victim cuts ties is a safety
risk nothing in the spec requires. If you ever want a push, it is one
decision away, with the analysis already written.

**3. Deleting does NOT cancel a subscription — Apple does not let us.** If
either of you has an active subscription, deletion removes Premium from the
(now gone) couple, but Apple keeps billing until the payer cancels in their
App Store settings. Both the deleter's confirmation screen and the partner's
notice say this in plain words. No app can do this part for you, and we would
rather say so than pretend.

**4. "Download my data" exists too, free for everyone.** Settings → Download
my data produces a JSON document of everything that is YOURS — your profile,
your solo answers, your own halves of the shared answers, your own coach-
usage counts — and deliberately nothing your partner wrote (their answers
are their data, even the ones you can read in the app; a durable exported
copy is a different thing from reading together, and we chose the protective
side). Delivered in-app with copy-to-clipboard — no email involved, which
also means no email provider to set up.

**5. Discreet notifications are now a real setting.** Settings has a new
toggle: when on, every notification shows only "Hayati" and a neutral line,
never what happened. Arabic-language users have had this by default since
M3.4 and still do; the toggle lets anyone opt in (and an Arabic user who
turns it on explicitly keeps the protection even if they later switch the
app's content language).

**6. Nothing changed for the daily loop or the lock** — proven by the same
kind of tests as always (1,300 app-side now, 848 server-side, all green,
both review passes run and their findings fixed before merge).

## 9. NEW (Session 023): the legal bundle — your review, three blanks, three lawyer questions, one filing

The six documents at `docs/legal/` (privacy policy + terms, each in TR/AR/EN
— also readable in the app under Settings → Privacy & Terms) are AI-drafted
against the shipped code and marked **review-PENDING**. Before public launch:

- **(a) Native + legal review of the six documents.** TR: you two (the
  policy is ~5 minutes of reading; it doubles as the KVKK aydınlatma metni).
  AR: your Gulf reviewer. Legal: your lawyer, against the code if they wish —
  every sentence was written to be checkable. Edits go to `docs/legal/` (a
  session handles the mechanics; the app copies are byte-synced under a CI
  test, and a MATERIAL change means a version bump that re-asks everyone's
  consent — also session mechanics).
- **(b) Three blanks only you can fill** (bracketed in every document):
  the controller's legal identity (your name or a company), a contact
  address, and the governing law (your lawyer's call).
- **(c) Three recorded lawyer questions** (written out in
  `docs/legal/README.md` and ADR-023): **A** — is the relationship-content
  processing special-category under KVKK Art 6 / PDPL (we implemented the
  conservative YES)? **B** — may the one consent be required to use the
  reflective features (we implemented the careful version: required, but
  with sign-out/export/delete always open)? **C** — must consent withdrawal
  erase the stored reflections, or does stop-collecting + self-serve
  deletion suffice (we implemented the latter, for the DV reason in 0.c)?
- **(d) One real legal action — the KVKK data-transfer filing.** Hosting TR
  users' data on Google's EU servers is a cross-border transfer under the
  amended Art 9. The compliant path: sign Google's Kurul-approved standard
  contract and **file it with the Kurum within 5 business days of signing**
  (missing the filing window carries its own fine band). This is a
  founder/lawyer action a session cannot do; the evidence and links are in
  `docs/dpa-inventory.md`. Needed before PUBLIC launch, not for TestFlight.
- **(e) Also recorded there, none urgent:** the Kurul "adequate measures"
  question for special-category data (whether our minimization-first posture
  suffices or key-management/audit-logging must be added at the deploy era);
  the seven PDPL items that bind only before the first Saudi user; a GDPR
  flag for the Phase-4 EU-diaspora channel; İYS registration before any
  promotional push ever fires (rides item 4's APNs).
- **Hosting (item 8(c)) is unchanged but now unblocked from the content
  side:** the policy text exists; the day you pick a domain and host it, a
  session drops the store lint's `--allow-empty-urls` flag and the gap can
  never reopen.

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
2. ~~First upload asks the **export compliance** question~~ — **already
   handled (Session 022):** `ITSAppUsesNonExemptEncryption=false` now ships in
   Info.plist (Hayati uses only standard TLS/HTTPS), so Apple will NOT show
   the export-compliance prompt at upload. If it appears anyway, answer
   "only exempt/standard encryption" and tell a session.
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
  reveal, streaks, entitlements — all **eleven** Cloud Functions have **never
  been deployed** (Spark plan). A session scripts the first deploy the moment
  you flip Blaze; without it the app on your phone is a beautiful shell
  around a missing backend. **(That bound holds for the TestFlight/prod lane
  only — the ★ direct-install recipe below runs most of the product on your
  phone today against the Mac's emulators, as a dev rig with nothing
  deployed; its two honest bounds and the one-session lever that lifts them
  are recorded there.)**
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

## ★ NEW (2026-07-13, operator interlude): test Hayati on your iPhone TODAY — the direct-install recipe (iPhone on iOS 26 + Mac on macOS 26 / Xcode 26; cable; no TestFlight, no enrollment, no deploy)

You asked for the recipe to test on the physical iPhone with the Mac. The
TestFlight runbook above is the *distribution* lane and waits on the
enrollment; **this is the *developer* lane — Xcode installs the app straight
onto your own phone over a cable, and it works before the enrollment lands.**
Verified against this repo's actual configuration: the app already ships a
LAN host override built for exactly this (`AUTH_EMULATOR_HOST` in
`app/lib/core/firebase/firebase_bootstrap.dart` — one IP steers all three
emulators), automatic signing with no team pinned, entrypoint flavors
(`lib/main_dev.dart` / `lib/main_prod.dart`, no `--flavor` schemes), and no
Podfile (SwiftPM — skip anything the internet tells you about `pod install`).

**Two modes — use Mode 1.**
- **Mode 1, the emulator rig (recommended):** dev flavor on the phone, the
  Firebase **emulators running on the Mac**, phone → Mac over your home
  Wi-Fi. This runs MOST of the product on real hardware — sign-in, the
  consent screen, the whole solo week, invite creation + deep-link
  delivery, the lock layer, export and the delete cascade, the in-app
  legal documents — with **two honest, code-pinned bounds** (the final
  join step and the couple daily loop — spelled out in Phase 7 #3, with
  the one-session lever that lifts both if you want it). It is a dev rig:
  the data is throwaway and evaporates when you stop the emulators. It is
  NOT the production proof (items 2/3/4 still own that).
- **Mode 2, the prod shell:** `lib/main_prod.dart`, no emulators. Honest
  bound: sign-in FAILS until you enable the providers (item 3), and behind
  sign-in there is no backend until the first deploy (item 2). Only useful
  for eyeballing the prod boot/branding.

### Phase 1 — Mac setup (once)

1. **Xcode 26** (Mac App Store). Launch once, accept the license, let
   components install. Xcode → Settings → Accounts → **+** → your Apple ID.
2. **Flutter** (stable channel) + this repo cloned; `cd app && flutter pub
   get`; `flutter doctor` and clear any iOS-section complaint.
3. **The emulator toolchain:** Node (`brew install node` — the functions
   declare Node 20; a newer local Node only prints an engine warning in this
   rig), a **Java 21+** runtime on PATH (`brew install openjdk@21`, then the
   one `sudo ln -sfn` line brew prints; check `java -version`), and
   `npm install -g firebase-tools@15.22.4` (the exact version every emulator
   proof in this repo ran on). Then `firebase login` once — the rig runs the
   emulators under the real dev project id (Phase 4 explains why), and a
   logged-in CLI keeps that fully offline.
4. Build the functions once per pull (the emulator never compiles TS):
   `cd functions && npm ci && npm run build`.

### Phase 2 — iPhone prep (once)

1. Cable the iPhone to the Mac → tap **Trust** on the phone.
2. Settings → Privacy & Security → **Developer Mode** → on → restart. (If
   the toggle isn't visible, open Xcode → Window → Devices and Simulators
   with the phone attached, then look again.)

### Phase 3 — signing (the one fork in the road)

- **If the enrollment is ACTIVE:** open `app/ios/Runner.xcworkspace` →
  Runner target → Signing & Capabilities → tick **Automatically manage
  signing** → Team: your paid team. Done — everything below works,
  including the Apple sign-in button.
- **If the enrollment has NOT landed yet:** a **free personal team** (just
  your Apple ID in Xcode) can still install on your own phone, with three
  honest costs: **(a)** Sign in with Apple is a paid-program capability —
  Xcode will refuse to sign until you remove it: delete the
  `com.apple.developer.applesignin` key+array from
  `app/ios/Runner/Runner.entitlements` **locally**, and revert before
  anything is committed (`git checkout -- app/ios/Runner/Runner.entitlements`).
  The phone-number sign-in lane below never touches it. **(b)** The install
  expires after **7 days** — re-run from the Mac to renew. **(c)** First
  launch: approve yourself under Settings → General → VPN & Device
  Management on the phone.

### Phase 4 — the emulator rig (each test day, ~2 minutes)

1. **Local, throwaway edit** so the phone can reach the emulators: in
   `firebase.json`, change all three `"host": "127.0.0.1"` entries (auth,
   firestore, functions) to `"0.0.0.0"`. **Never commit this** — revert in
   Phase 8.
2. From the repo root:
   `firebase emulators:start --only auth,firestore,functions --project hayatiapp-dev`.
   **The project id matters and it is NOT the CI one:** the functions
   emulator serves callables only under its `--project` id, and the app you
   installed carries `hayatiapp-dev` baked into its dev config — started
   under CI's `demo-hayati`, every callable (consent, invites, join,
   export, delete) would 404 and the rig would die at the consent screen
   (this repo's own PR-#23 lesson; the adversarial review of this recipe
   caught it before you did). Expect one harmless startup warning about
   `RC_WEBHOOK_TOKEN` (the webhook isn't part of this rig and fail-closes).
   macOS will ask to allow `java`/`node` to accept incoming connections —
   **Allow**. Keep this terminal visible: **the phone sign-in codes print
   here** (the emulator UI is disabled in this repo's config).
3. The Mac's Wi-Fi IP: `ipconfig getifaddr en0`. Phone and Mac must be on
   the **same Wi-Fi**.

### Phase 5 — install and run

```sh
cd app
flutter run --release -t lib/main_dev.dart \
  --dart-define=USE_AUTH_EMULATOR=true \
  --dart-define=USE_FIRESTORE_EMULATOR=true \
  --dart-define=USE_FUNCTIONS_EMULATOR=true \
  --dart-define=AUTH_EMULATOR_HOST=<the-IP-from-Phase-4>
```

(If Flutter lists several devices: `flutter devices`, then add `-d <id>`.)
`--release` gives the honest feel and leaves the app installed — afterwards
it relaunches from the home-screen icon with the same defines baked in. Drop
`--release` when you want hot reload instead. On first backend contact iOS
should ask for **Local Network** permission — **Allow**. _(Updated Session
024: the `NSLocalNetworkUsageDescription` purpose string now ships in the
app permanently, localized ×3 — issue #55's rider — so the prompt appears
properly under iOS 26's strict LAN privacy and you never edit
`Info.plist` locally.)_ If the prompt never appears and the app can't reach
the Mac, check Settings → Privacy & Security → Local Network → Hayati App
and flip it on.

### Phase 6 — the partner is the Mac

Your second tester is the iOS **Simulator** on the Mac (`open -a Simulator`,
ships with Xcode): run the same command with **no** `--release` and **no**
`AUTH_EMULATOR_HOST` line (the simulator reaches the emulators on localhost),
`-d` the simulator. Sign the simulator user in with **Google** — phone
sign-in on the *simulator* is the known issue-#15 native crash (phone is for
the real phone), and Apple sign-in is off on the free-team path (Phase 3).
Create the invite there, then on the iPhone open
**`hayati://invite/<CODE>`** typed into Safari's address bar. Do it twice:
once with Hayati running (warm) and once after force-quitting it (cold) —
**the OS→app delivery pair is an item-4 checkbox**, and it is proven the
moment the preview screen mounts holding your code. **Honest bound: the
join itself stops there on this rig** — the preview card will show its
retry/error state, because the zero-auth preview URL is code-pinned to the
CI project id while this rig (necessarily — Phase 4) runs under
`hayatiapp-dev`. Lifting that is the dev-rig slice below.

### Phase 7 — what to test (in rough order of value)

1. **Phone sign-in:** any test number (e.g. `+90 555 000 00 01`); the
   6-digit code prints in the emulator terminal — no real SMS, no APNs
   needed (the emulator disables app verification). If sign-in crashes
   natively, you've just reproduced issue #15 on real hardware — capture
   the log (Xcode → Window → Devices → Open Console); that's an item-4
   checkbox with a bounty on it.
2. **The consent screen (Session 023)** — you two are the first humans to
   see it live: one clear button, and the three escapes (sign out /
   export / delete) all reachable from a decline.
3. **The loop, with its two honest bounds:** the solo week runs end to end
   (bundled questions, consent-gated answers, history). Invite creation +
   the share sheet + deep-link **delivery** run (Phase 6). What this rig
   canNOT honestly run — both caught by the adversarial review of this
   very recipe, both code-level, neither a bug: **(a) the final join tap**
   (the joiner's preview URL is code-pinned to the CI project id — the
   preview card errors on this rig, and the join CTA lives behind it);
   **(b) the couple daily loop** (the day's question doc is written ONLY
   by the scheduled `questionRollover`, and the emulator never fires
   schedules — the repo's own recorded deploy-verified-only bound; with
   no day doc, couple-answer writes fail closed at the rules). Both lift
   together with the **dev-rig slice** below, or with the first real
   deploy (item 2).
4. **The four M6.1 lock checks** from item 4's sub-list (Keychain
   reinstall persistence, Face ID self-revocation, discreet icon,
   app-switcher blank card) — they were built FOR this moment. Note for
   the reinstall check on a free team: "reinstall" = re-run from the Mac.
5. **Settings → Privacy & Terms** (the six Session-023 documents render
   in-app), **Download my data**, and the **delete-account cascade** —
   emulator data is throwaway, so delete fearlessly.
6. **TR/AR/EN + RTL** rendering on real hardware.
7. **Honest non-features on this rig — don't chase these as bugs:** pushes
   can't fire (APNs is item 4); the paywall shows "store unavailable" (no
   RevenueCat key — fail-closed by design, item 0), which also keeps the
   coach behind its premium gate (and even with premium it would answer
   with the honest "not configured" state — item 6); the Apple sign-in
   button needs the paid team (Phase 3). And the item-4 **cold-start
   stopwatch** number should NOT be taken from this rig — that measurement
   belongs to the prod TestFlight build.

### Phase 8 — teardown ritual (IMPORTANT)

Ctrl-C stops the emulators (the test data evaporates — expected). Then, in
the Mac clone, `git status` must come back **clean**: revert the local
edits if they show (`git checkout -- firebase.json
app/ios/Runner/Runner.entitlements`). Neither may ever reach a commit —
one opens the emulator hosts to the network, the other strips a shipping
entitlement. _(The Info.plist local edit is gone from this ritual: the
Local-Network key ships in the app since Session 024.)_

### Want the FULL couple loop on this rig? It is one small session away.

The two Phase-7 bounds share one lever, recorded here as the **dev-rig
slice**: a session adds a `lib/main_demo.dart` entrypoint that boots the
app with the CI project's options (`demo-hayati` — the exact bootstrap the
repo's own integration tests already prove on the iOS simulator every
merge, which aligns the callables, the preview URL, and the Firestore
triggers under one project id) plus a tiny seeding tool that plays the
scheduled rollover's role on demand. With those two files, the join, the
couple daily loop, the mutual reveal, and the streak all run on your phone
against the Mac — still throwaway data, still no deploy. **Say "build the
dev-rig slice" and the next session folds it in or re-scopes to it.**

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
- **NEW since M6.2 (standard gate, but three strings carry legal/safety
  weight):** the data-rights copy — `dataRights*`/`coupleEnded*`/
  `settingsNotificationPrivacy*` keys × TR/AR/EN in `app/lib/core/l10n/arb/`.
  Worth your eyes specifically: **(a) the deletion confirmation** (it must
  read as genuinely irreversible and say the shared space goes for BOTH of
  you — an under-translated warning here is a legal problem, not a tone
  problem); **(b) the partner's "shared space closed" notice** (it must stay
  calm and non-blaming in TR and AR — it deliberately never says who did it);
  **(c) the "does not cancel your subscription" line** (users will act on
  this sentence with money involved). The rest (export screen, toggle
  captions, error states) is standard tone review.

## 2. Blaze plan decision — **last call, optional bonus otherwise**

- **What:** upgrading `hayatiapp-dev`/`hayatiapp-prod` from Spark (free) to
  **Blaze** (pay-as-you-go) — deploying Cloud Functions requires it.
- **Status:** eleven Functions now — the five loop/invite units
  (`createInvite`, `invitePreview`, `joinInvite`, the scheduled
  `questionRollover`, the Firestore-triggered `answerReveal`), since M4.1
  the **`revenueCatWebhook`**, since M5.1 the **`coachProxy`**, and since
  M6.2/S023 the four data-rights callables (**`deleteAccount`**,
  **`exportData`**, **`updateNotificationPrivacy`**, **`recordConsent`**) —
  all emulator-proven; **nothing deployed yet.** (The count was recorded as
  "six" here for three sessions — the 2026-07-13 interlude review corrected
  it against `functions/src/index.ts`.) Deploy-verified-only pieces: the
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

**Update 2026-07-13 (Session 022): the automated release lane now exists and
waits on exactly this item.** The day the enrollment lands:

1. **Create one App Store Connect API key** (App Store Connect → Users and
   Access → Integrations → Keys → generate; role App Manager is enough) and
   put its three values into GitHub: repo **Settings → Environments →
   `release`** (the environment already exists/auto-creates) → add secrets
   **`ASC_KEY_ID`**, **`ASC_ISSUER_ID`**, **`ASC_API_KEY_P8`** (the .p8 file's
   full text). They must go in the `release` ENVIRONMENT, not the plain
   repository secrets — the pipeline reads only the environment (ADR-021).
2. From then on, a session (or you) pushing a tag `vX.Y.Z` that matches
   `app/pubspec.yaml`'s version produces a signed TestFlight build
   automatically. Until then the pipeline's signing step fails with a clear
   message — that red is expected and honest.
3. **First-real-run checklist (recorded, expected to need one Mac-era fix):**
   the likeliest fixes a session may need are the automatic-signing
   `DEVELOPMENT_TEAM` build setting (no secret carries your team id yet) —
   and after the first `deliver` metadata push, eyeball the App Store Connect
   URL fields (the empty privacy/support URLs must not have clobbered
   anything; item 8 owns filling them).
4. **NEW on-device check (Session 022):** the cold-start stopwatch — time a
   cold launch of the prod build on the iPhone 17 (airplane-mode and normal
   runs). CI deliberately does not assert the <2s number (a shared debug
   simulator would produce theater); your phone is where the honest number
   comes from.

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

## 8. NEW (Session 022): four store-listing decisions + the missing web pages — none blocking, all pre-submission

- **(a) The store name "Hayati" is provisional.** The brandkit records a
  known collision risk (an unrelated vape brand uses "Hayati" in some
  markets). Before public launch: run the trademark/store-name search you
  already planned; if it fails, the vetted alternates are in the brandkit and
  ADR-020 (İkimiz, Baynana, Mawadda, Roohi) and the rename costs one metadata
  line. Apple may also reject the name as taken at Phase B — same fallback.
- **(b) The label under the discreet icon — your call, deliberately not made
  for you (ADR-020 D2).** The home-screen label is "Hayati App" today and the
  discreet icon cannot change it (that honest bound ships in the app's own
  settings copy). Options, all drafted: keep "Hayati App" (current), rename
  to "Hayati" (cleaner, equally identifying), or a genuinely neutral label
  (a real product-identity decision with store-review risk — not drafted as
  a default). Whichever you pick, the session that changes it must re-audit
  the discreet-icon copy in the same commit.
- **(c) Privacy policy + support page URLs do not exist** — the store
  listing ships EMPTY URL fields behind a loud CI warning (never a fake URL).
  Apple requires both at submission. Needs: your domain choice (the same
  decision universal links have been waiting on) + hosting. **The policy
  TEXT now exists (Session 023 — see item 9)**; the in-app requirement is
  already satisfied by the in-app documents, so only the store's URL fields
  wait on your domain. When the URLs exist, a session drops the lint's
  `--allow-empty-urls` flag and the gap can never reopen.
- **(d) Age rating: verify at first submission.** Spice mode is out of the
  MVP precisely to keep the rating standard-tier, but whether Apple's
  questionnaire treats the AI coach chat as a maturity factor is only
  provable in App Store Connect. If it forces a higher tier, the choice
  (constrain the surface vs accept the tier) is yours — the honest answer
  either way is the guardrail description (server-side crisis spine,
  not-therapy disclaimer, premium-gated).
- **(e) NEW (Session 024): the privacy manifest shipped — four recorded
  checks when you answer the App Privacy questionnaire at submission.** The
  app now carries `app/ios/Runner/PrivacyInfo.xcprivacy` (issue #55; CI
  asserts it lands in every build). Judgment calls deliberately RECORDED,
  not resolved — resolve them against the questionnaire with your
  lawyer-adjacent hat on: **(i)** the App Privacy label answers you give in
  App Store Connect must match the manifest's declared types (contact info,
  User ID, Other User Content, Purchase History, Crash Data — all
  non-tracking); **(ii)** whether couples' free-text + coach content
  warrants Apple's **"Sensitive Info"** category — the manifest deliberately
  omits it with the reasoning in an XML comment (ADR-023 takes the KVKK
  special-category-conservative stance, but Apple's label taxonomy is a
  separate regime); **(iii)** Crash Data is declared **not linked** to
  identity (Crashlytics installation IDs, content-free by the sentinel-pinned
  logging rules) — confirm against the questionnaire's linking definition;
  **(iv)** the **Local Network purpose string** ships in the prod binary for
  the dev rig (prod makes no LAN connections, so iOS never prompts) — at
  submission, decide whether to keep, reword, or strip it (an unused
  permission declaration is a plausible App-Review question). Full
  validation (Xcode privacy report, ASC ingestion) is Mac-era and rides
  item 4.
- **Also in item 1's native-review gate since this session:** the full store
  listing copy ×2 locales (`fastlane/metadata/{tr,en-US}` — name, subtitle,
  description, keywords, promotional text) and the localized Face ID
  purpose string (`app/ios/Runner/{en,tr,ar}.lproj/InfoPlist.strings`).
  _Session 024 added to the same files:_ the localized **Local Network**
  purpose string (the on-device emulator-rig prompt, issue #55's rider) —
  same AI-drafted / native-review-PENDING status.

## 10. NEW (Session 026): one small question — which icon set does Hayati actually use? (not blocking anything)

The brand kit says the app uses **Phosphor** icons (a specific icon family,
rounded, at a set weight). The app actually ships **Material** icons — 28 of
them — and Phosphor was never added. Nobody did anything wrong; the brand kit
was written before the screens were, and the gap was never noticed until this
session catalogued every surface.

It matters only because the refactor is about to assert "one consistent icon
family" as a quality check, and right now that check would fail on a
technicality against a rule the code has never followed. So rather than
silently swapping icons mid-refactor, it is written down as your call:

- **(a) Switch to Phosphor.** The right answer if the brand kit's icon look
  matters to you. Real cost: a new dependency, all 28 icons re-drawn, a
  measurable size increase, and one genuinely fiddly piece — Material's back
  arrow flips itself automatically in Arabic, and a Phosphor icon would not,
  so every directional icon needs a hand-made mirrored twin (the app has an
  automated test that exists purely to catch un-flipped arrows).
- **(b) Update the brand kit to say Material.** Cheapest, and honest: Material
  outline icons at the same size read perfectly well with the brand, and the
  brand kit already records one similar "here is what we actually shipped and
  why" exception. **This is the recommendation** unless you have a view.

Tracked as issue #63. Either answer is fine; no session is waiting on it.

## 12. NEW (Session 028): two brand colours that don't exist yet — a design decision, not a bug

The brand kit defines nine colours, and all nine are **full strength**. Real
interfaces also need two *quieter* roles that nothing in the brand kit covers:

- **Secondary text** — the smaller grey-ish line under a settings row title,
  the caption under a heading. Right now those use Flutter's own default
  rather than a Hayati colour.
- **Lines and borders** — the thin separators between settings rows, and the
  outline of a switch when it's off. Same situation.

Session 028 tried to fill both by simply fading `sand` (the cream text
colour). It then **looked at the result** and found the settings **toggles had
become noticeably dimmer** — because a switch borrows those exact two colours
for its "off" look, so fading them made *working* controls look half-disabled.
That is a worse interface, and it is the kind of thing you only catch by
looking. So the change was reverted rather than shipped.

**Your options (issue #67), none obviously right:**
- **(a) Add two named colours to the brand kit** — a "muted text" tone and a
  "line" tone, picked so that switches and buttons still read clearly as
  active. Cleanest, and makes every colour in the app yours.
- **(b) Use faded `sand` for both, but with the exact fade levels chosen and
  the contrast measured** against both backgrounds (the brand kit already has
  one note in this style, for the input-hint colour).
- **(c) Leave them as Flutter's defaults and say so deliberately.** Cheapest,
  and it is what ships today — the cost is that two colour roles in your app
  are not chosen by you.

There is an accessibility angle worth knowing: the accepted standard asks for
a lower contrast bar on controls than on text (3:1 rather than 4.5:1), but
"quieter" must still never look like "disabled" — which is exactly what went
wrong in the attempt.

**Nothing waits on this.** The next few sessions work on screen layout, not
these two colours. Whichever session needs them first will stop and ask.

## 11. What Session 026 found while planning the refactor (FYI — no action)

**(a) The tool you installed is genuinely useful, but not the way it advertises.**
UI/UX Pro Max was installed and actually run against a real description of
Hayati. Its *checklist* is good and has been copied into the plan. Its
*automatic design generator* is not usable here: asked about Hayati, it
proposed a light pink palette, a different font, and a marketing landing-page
layout — and wrote a file declaring itself the "single source of truth" for
the design. Hayati's brand kit is the source of truth, so the generator is
deliberately switched off and only the checklist is kept. (Its instructions
also state, in writing, that the project is built in "React Native" — it
isn't; it's Flutter.) Nothing was adopted from it without being checked
against the brand kit first.

**(b) Two real gaps in the existing app were found — and BOTH ARE NOW FIXED
(Session 027).** Neither was a bug you would ever have seen; they were missing
*safety nets*, not broken features:
  1. **The lock screen had a rule that nothing was enforcing.** Because the
     lock sits above everything else in the app, certain common UI elements
     (a pop-up dialog, a tooltip, selectable text, a "copied!" bar) would
     *crash* it if anyone ever added one — and on the "forgot my PIN" path,
     that crash would mean being locked out of your own app. The rule was
     written in a comment; nothing checked it, so a future change could have
     shipped that crash with every test passing. **Now enforced by an
     automatic check** (issue #61, closed) — including two cases the written
     rule would have missed: the common shorthand for adding a tooltip to a
     button, and the "copied to clipboard" bar.
  2. **The brand colours were copied into the app by hand, and nothing checked
     they still matched.** They did match — verified. But if the brand kit
     were ever updated, or a colour edited during the redesign, nothing would
     have noticed, in either direction. **Now checked automatically** (issue
     #62, closed).

  A third net was added at the same time: **the sentences that carry safety or
  legal meaning are frozen.** 96 strings — the "this is not therapy" wording,
  the crisis-support text, and every consent and withdrawal sentence, in all
  three languages — now have a fingerprint recorded in the tests. Any reword,
  in any language, turns the build red. That does not block the change; it
  forces it to be a decision rather than an accident, which matters because a
  material change to the consent wording legally requires re-asking both of
  you for consent.

**(c) The refactor's actual job turned out to be different than expected.** The
app's own screens are already well-disciplined about using brand colours and
spacing. What is *not* branded is the layer underneath: pop-up dialogs, cards
and confirmation bars fall back to Flutter's built-in defaults. Concretely,
your three most important confirmation dialogs — the Face ID warning, the
"delete everything" confirmation, and the consent-withdrawal dialog — currently
render on exactly the same colour as the page behind them, with no visual
separation; and the "copied to clipboard" bar renders on a **cream** background
in an otherwise dark app. That is the first thing the refactor fixes.

**(d) The plan is eight sessions, and the lock screen goes last and barely
changes.** That is a deliberate trade: the lock's safety guarantees are worth
more than visual consistency on the one screen you will see least.

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

## 5. **ACTION NEEDED (Session 025): rotate the leaked Slack webhook, then turn CI notifications on with one command**

You asked Session 025 to wire Slack into CI (modelled on ams-pulse). **The
wiring is built, tested and merged — and it is deliberately SILENT until you
do the four steps below.** It will never spam you, never warn, and never turn
a build red while the secret is missing; a repo with no webhook is simply a
repo with no webhook.

**First, the security part — this has been open since Session 005 and is still
not done.** The local branch `chore/slack-notifications` (commit `13f1e6d`)
has a **live Slack webhook URL written in plain text inside a workflow file**.
It never reached GitHub (push protection blocked it), but a credential sitting
in a git commit is a leaked credential. Anyone holding that URL can post
messages into your Slack channel.

1. **Revoke the old webhook** in Slack: api.slack.com/apps → the app that owns
   it → *Incoming Webhooks* → remove that webhook. **Do not push, merge, or
   "finish" the `chore/slack-notifications` branch** — Session 025 shipped what
   it was for, correctly, and its old instruction to "land the branch" was
   wrong and is now deleted. (A session did not delete the branch for you: it
   is the evidence of *which* webhook to revoke, and it is not ours to destroy.
   Once you've revoked, `git branch -D chore/slack-notifications` is safe.)
2. **Create a fresh Incoming Webhook.** api.slack.com/apps → *Create New App*
   (if you have none) → *From scratch* → name it e.g. `Hayati CI` → pick your
   workspace → *Create App*. Then **Features → Incoming Webhooks → toggle
   Activate ON → Add New Webhook to Workspace** → choose the channel → *Allow*
   → copy the URL (it looks like `https://hooks.slack.com/services/T…/B…/…`).
   **It must be an *Incoming Webhook*, NOT a Workflow-Builder webhook** — the
   latter validates the body against its own schema and would reject our
   messages with a silent 400.
3. **Store it — as a REPOSITORY secret. This is the one place it is easy to go
   wrong:**

   ```sh
   gh secret set SLACK_WEBHOOK_URL --body 'https://hooks.slack.com/services/…'
   ```

   **Do NOT put it in the `release` environment.** The only other secrets in
   this repo (the three `ASC_*` signing keys, item 4) *do* live there, so the
   natural instinct is to copy that — but the notifier deliberately has no
   environment binding (it has to be able to report a *failing* signing job,
   which would be circular). An environment secret would be **invisible** to
   it, and the failure looks exactly like "no webhook configured": silence,
   forever, with nothing red to tell you why.
4. **Confirm it worked.** The next push to `main` posts the first message. If
   it doesn't, open that run's `slack-notify` job log: it says why in one line
   — `notification delivered` (working), a `::notice::` (the secret isn't
   visible → you're in step 3's trap), or a `::warning::` (the webhook was
   rejected → likely a Workflow-Builder webhook, step 2).

**What you'll get, and what you won't** (the noise policy is deliberate — a
channel that pings for everything gets muted, and a muted channel swallows the
one message that matters): **failures always**, on PRs and on `main`.
**Successes only on `main`, on a manual re-run, and on releases** — never for
the routine PR pushes a session makes, because the session is already watching
those itself. The message carries the branch, commit, actor, run link and a
per-job line (`quality ✅ · integration-emulator ⏭`), and **never any log
content**.

**Why this matters more than it sounds:** the one CI event in this project with
**no reader at all** is a failing `integration-emulator` on `main` — it runs
only *after* a merge (macOS minutes bill at 10×, so it can't run on every PR),
which is after the session has moved on. That is the message this exists to
deliver. Session 025 also found and fixed a bug where that run was being
*cancelled* by the session's own closing commit — so the verdict was being
destroyed before anyone could read it.

## Progress & readiness snapshot (as of Session 026 close)

**The one-paragraph version.** Every line of MVP engineering that can be built
**without you** is done. **One planned MVP unit remains — M5.3, the live AI
coach — and it waits on item 6 alone.** Engineering is ~95% of the MVP;
**operational proof is still 0%**: nothing has ever been deployed (item 2), the
app has never run on a real phone against a real backend (items 3+4), and no
real purchase has ever happened (item 0). That gap is not an engineering gap —
it is four account/billing decisions that only you can make. The last four
sessions were **hardening and planning**, not features: S024 shipped the
change-PIN flow, the iOS privacy manifest and CI runtime bumps; S025 shipped
CI→Slack notifications and fixed a CI bug that was silently destroying the
post-merge test verdict; **S026 scoped the UI/UX refactor (ADR-025) without
touching a pixel**, finding two pre-existing safety/consistency gaps on the
way; **S027 closed both of them and froze the safety/legal wording**; **S028 shipped
the refactor's first visual fix** — the three confirmation dialogs and the
"copied" bar, all of which were rendering on the wrong colour — and stopped
itself when the rest of the planned change needed two colours the brand kit
does not define (item 12). **Next session: ADR-025 slice 2 — the product core**
(the daily question, the answer, the partner's side, the reveal). The brand kit
calls the reveal "the product", so it is where the polish budget goes.

**A note on how the refactor is sequenced, since it is now a multi-session
arc:** slice 0 (the safety nets) → slice 1 (the un-branded Flutter defaults
under every screen) → the product screens, outward → **the lock screen last,
and barely touched**. Each slice is one session with its own acceptance line,
and each one regenerates its screen snapshots deliberately rather than
accepting whatever changed. You can re-order the middle slices by saying so;
the first and last are fixed for safety reasons.

### The older detail (as of Session 023 close, still accurate for the product itself)

- **Plan progress:** M0 ✅ · M1 ✅ · M2 ✅ · M3 ✅ · **M4 engineering ✅ (sandbox
  accept line open on item 0)** · **M5: 2/3 (spine + chat UI; M5.3 live
  adapter is founder-blocked on item 6)** · **M6: 3/3 ✅** · **mvp item 12
  legal bundle: buildable half ✅ (Session 023 — consent surface + legal
  drafts + DPA inventory; the founder/legal review half is item 9)** —
  **21/22 session-units + the item-12 buildable half, in 23 sessions; ONE
  planned session-unit left to the MVP: M5.3, blocked on item 6 alone.
  Every line of MVP engineering that can be built without your input is now
  DONE.** (M6.5 Android sits outside the 22-unit count; its timing is your
  Gate-3 call.) On track; the only scope change in Session 023 was
  review-adjudicated: the iOS privacy manifest moved OUT to issue #55 — and it
  **shipped in Session 024**, alongside the change-PIN flow, the de-quarantined
  reveal test (#36) and the CI runtime bumps (#39). **Session 025 shipped
  CI→Slack (your directive) and fixed the concurrency bug that was cancelling
  the post-merge verdict.** Next session: **the UI/UX Pro Max refactor SCOPING
  ADR** (your other 2026-07-14 directive — design only; the roadmap places it
  ahead of the remaining backlog, e.g. seasonal windows #29), unless you answer
  item 6 (**M5.3 preempts — and it carries a recorded re-consent trigger: the
  consent version bumps and everyone re-consents to a notice naming the
  provider**), flip Blaze (**the first-deploy slice preempts**), green-light
  Android timing (**M6.5**), report an on-device defect from the ★ recipe
  (**triage preempts**), or say **"build the dev-rig slice"** — which would let
  the **full couple loop** (join → daily question → mutual reveal → streak) run
  on your iPhone against the Mac, with nothing deployed.
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
  blanked; the discreet iOS icon), and now the **data-rights layer** (M6.2,
  ADR-019: self-serve in-app JSON export of strictly-your-own data; the hard
  cascade delete — idempotent, resumable, kill-tested at every step,
  concurrency-tested across both partners deleting at once; the partner's
  honest in-app notice with deliberately no push; the entitlement mirror
  dying with the couple; the per-user discreet-notification override — 1,300
  app tests / 848 server tests green, both adversarial review passes run and
  every confirmed finding fixed before merge), and now the **release
  readiness layer** (M6.3, ADR-020/021/022: the App Store listing TR/EN in
  `fastlane/metadata` under a CI lint that enforces Apple's limits; the
  tag-triggered `release.yml` — metadata lint → the full emulator integration
  suite → a real prod release build with a 200 MB size cap → a signing step
  that fails CLOSED with a message naming exactly the missing secrets;
  export-compliance pre-answered in Info.plist; the store's language row
  fixed to TR/AR/EN with the Face ID prompt localized; the cold-start path
  audited and shortened with the pre-frame bootstrap shape pinned by a
  mutation-checked test), and now the **consent & legal layer** (Session 023,
  ADR-023: one explicit, server-recorded, version-stamped consent gating the
  reflective features — provable, exportable, erasable, withdrawable, and
  enforced at the database rules on the answer writes; the privacy policy
  (doubling as the KVKK aydınlatma metni) + terms in TR/AR/EN readable inside
  the app with no website needed; the notice on every sign-in surface
  including the invite deep-link path; paywall Terms/Privacy links per
  Apple's subscription rules; the processor inventory at
  `docs/dpa-inventory.md` with honest per-service regions — **1,390 app
  tests / 870 server tests green**, both adversarial review passes run
  (eleven-for-eleven), every confirmed finding fixed before merge).
  **What "production-ready" is still missing, honestly:** no deploy has ever
  happened (Spark plan — item 2), the app has never run on a real device
  (Mac/enrollment — item 4), no real purchase has ever been made (item 0),
  push notifications have no device half (APNs — item 4), the coach has no
  live AI provider (item 6 — the ONLY gap left in M5, and the only planned
  MVP unit left at all), the privacy layer's four on-device checks (item 4's
  sub-list) are unverified on real hardware, and the signed-build/TestFlight
  half of the release lane waits on item 4's enrollment + secrets. Call it
  **~95% of the MVP's engineering, 0% of its operational proof.**
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
  over it). **Still open from M6.1:** the device-privacy layer's four
  on-device verifications (item 4), a native SceneDelegate snapshot cover
  (only if the on-device check finds the pure-Dart shield leaves a gap — the
  fix is pre-recorded in ADR-018 D5), Android's lock + activity-alias icon
  (M6.5), and a change-PIN flow (today: turn off, turn on — both verify
  first, so it is a convenience gap, not a hole). **New from M6.2
  (ADR-019):** backup-retention alignment with the erasure right (the first
  deploy session inherits it — no backups exist today, so "deleted" is
  currently literal), export rate-limiting (deploy hardening, rides the
  existing limiter note), the AR discreet-default opt-out (a recorded product
  decision — the enum leaves the door open), `coach_sessions` export/cascade
  coverage (contingent on your item 7). **The mvp item-12 consent screens +
  DPA inventory shipped in Session 023** — what remains of the legal bundle
  is YOURS (item 9: the six-document review, three placeholders, lawyer
  questions A/B/C, the SCC + 5-day Kurum filing) plus hosting (item 8(c)).
  **New from S023 (ADR-023), deferred loudly:** the Kurul adequate-measures
  question (key-management/audit-logging — lawyer, deploy era), İYS
  registration before any promotional push (rides item 4's APNs), the PDPL
  seven-item set (binds before the first KSA user), the GDPR forward flag
  (Phase-4 diaspora), the privacy manifest (issue #55, next hardening
  sweep), and the M5.3 re-consent trigger (binding: the live LLM bumps the
  legal version and re-gates everyone). **New from M6.3 (ADR-020/021/022):** the store-listing E2E
  matrix enters `release.yml` when the E2E scenarios can honestly run
  (sandbox = items 0+4; recorded in test-suite.md), the `Gemfile.lock` debt
  survives until the signing job first runs bundler, the 200 MB size cap
  ratchets once real measurements exist, the `--allow-empty-urls` lint flag
  drops when item 8(c)'s URLs exist, screenshots are Mac-era, and the
  first-real-run signing checklist (item 4's update) carries the two
  recorded likely fixes.
  **Closed this session (023):** mvp item 12's buildable half — the consent
  surface (gate + server record + rules enforcement), the six legal-document
  drafts TR/AR/EN (review-PENDING, item 9), the DPA inventory, and the
  architecture honesty flip from "unbuilt" to shipped. Previously closed
  (022): the M6 milestone itself — store metadata TR/EN drafted + CI-linted,
  the release lane built and proven fail-closed at its secrets boundary, the
  performance pass, and ADR-018 D7's Info.plist localization deferral.
  **Interlude (2026-07-13, docs-only, after the 023 close):** the ★
  direct-install on-device recipe added above at the founder's request — no
  code changed, no session-unit consumed, Session 024's objective unchanged;
  the founder's on-device findings (the four M6.1 checks, the deep-link
  delivery pair, a possible #15 crash log) become triage input for the next
  session. The recipe itself went through the standing adversarial-review
  discipline (5 lenses × refuting skeptics — the TWELFTH consecutive pass
  to find real defects): 2 BLOCKING (the emulator project-id 404 trap; the
  couple-daily-loop over-claim against the schedule-never-fires bound) + 1
  SERIOUS (the missing `NSLocalNetworkUsageDescription` risk) + 2 MINOR
  (the Functions count — eleven, not seven; Google-not-phone for the
  simulator partner) — all folded in before merge. Two new small items now
  recorded: the **dev-rig slice** (founder-triggered, see the recipe) and
  the `NSLocalNetworkUsageDescription` key riding the next hardening
  sweep's Info.plist work.
