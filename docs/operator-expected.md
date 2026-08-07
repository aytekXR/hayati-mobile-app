# Operator Expected — what İkimiz needs from you (the founder)

> **Canonical, committed** operator checklist (founder request, Session 009): the
> single place to see what is expected from you, refreshed at every session
> close. Check it after every merge to `main`.
>
> **This file lists ONLY open, actionable items.** Nothing that is finished
> appears here. Closed items and the session-by-session narrative live in
> `docs/past-prompts.md`; engineering decisions live in `docs/adr/`; tracked
> engineering work lives in GitHub issues.
>
> **The item numbers are stable identifiers, not an order.** `tool/ci/testflight_testers.py`,
> `tool/ci/rules_drift.py`, `.github/workflows/{deploy-site,deploy-rules,ci}.yml`
> and several ADRs cite them by name, so a surviving item keeps its number even
> when the list around it shrinks. Read top-to-bottom for priority. Numbers that
> have closed but are still cited by code are listed at the very bottom.

_Last refreshed: **2026-08-06** (Sessions 062–063). The 2026-08-05 refresh re-measured
every line against Apple, GitHub, Google and your live site; S062 added the one
thing that refresh could only ask you to report._

> ### 🔔 ONE THING now stands between you and a notification: the APNs key
>
> **Install build 116** (TestFlight — already available to you, no review wait).
> It is the first build in this app's history that can receive a notification at
> all, and the first that will ever ASK you for permission — the prompt appears
> on the paired home screen, once. Say yes.
>
> Then do the `.p8` below. Then tell me whether anything arrives at 08:00.
>
> **Correction, recorded because you were told otherwise.** On 2026-08-06 you were
> told everything was built and shipped bar the `.p8`. That was wrong: the server
> code had been merged but **never deployed**, so the two functions the app calls
> to register your phone did not exist in production at all. Your phone would have
> asked for permission, got a token, tried to hand it over, and been told there is
> no such function — silently, because every layer is built to fail quietly rather
> than alarm you. Deployed on 2026-08-07 with your authorisation, and verified by
> reading production back rather than trusting the deploy. The security rules that
> lock that field went out at the same time.
>
> You authorised the API path on 2026-08-06 and **Push Notifications is now
> ticked** on `com.beyondkaira.hayati` (measured before: absent; enabled; measured
> after: present). The entitlement shipped in **build 115** (and 116), which signed, uploaded
> and is **installable by you right now** — you are an internal tester, so it needs
> no review.
>
> **What is left is piece 1, and only you can do it.** Firebase needs Apple's APNs
> key or it cannot hand a notification to Apple at all:
>
> 1. Apple Developer portal → **Keys** → **+** → tick **Apple Push Notifications
>    service (APNs)** → Continue → Register → **download the `.p8`** (once only).
>    Note the **Key ID** on that page; your **Team ID** is `UH7MXG7Z94`.
> 2. Firebase console → **`hayatiapp-prod`** → ⚙ Project settings → **Cloud
>    Messaging** → **Apple app configuration** → upload the `.p8` with those two ids.
> 3. **Do the same for `hayatiapp-dev`** — the same key works for both.
>
> Unlike the tick, this one genuinely cannot be measured or done from a session:
> Firebase's Cloud Messaging settings are console-only. Checked again on
> 2026-08-06 — `gcloud` is not installed, there is no application-default
> credential, and the Firebase CLI has no APNs command at all. So please just say
> when it is done.
>
> **Still untickled, still one page, still yours if you want them:**
> `ASSOCIATED_DOMAINS` (item **2(d)**) and `APP_ATTEST`. Neither blocks
> notifications; both are the same Identifiers page you no longer have to visit
> for push.

> **What changed since the last refresh (2026-08-01):**
>
> * ✅ **Apple approved build 113**, and **builds 115 and 116 have since shipped** —
>   116 on 2026-08-07, carrying the whole notification stack. Your testers are no
>   longer three weeks behind. Item 2(c) is closed and gone from this page.
> * ✅ **The portal tick is done** (2026-08-06, with your authorisation, over the
>   API rather than by hand). Only the APNs **key** is left — the box at the top.
> * 🔴 **The icon decision is still open** — the box below. It has now waited three
>   sessions behind the notification work.

**Where things stand in one line:** the MVP is code-complete, both backends run
current code and current rules, the invite site is live, **build 113 is approved
and installed on four people's phones, with four more invited** — and the two things you noticed this week (no
notifications, the icon) are both real, both now written down, and both need one
decision from you before a session can finish them.

## Readiness snapshot — three different questions, three different answers

| Question | Where it stands | What is left |
|---|---|---|
| **Is the MVP built?** | **~98%** — M1→M6.3 all merged. All three notifications you asked for are built, deployed and **running in production**, and **build 116 is the first that can actually receive one** — it is the first that asks you for permission, without which iOS never issues a token. (115 has the entitlement but not the prompt, so it cannot work; install 116.) **No notification has still ever been delivered**, because Firebase has no APNs key to hand it to Apple with. The plan's ✅ on M3.4 stays struck through until one actually arrives. | **4(a) piece 1** — the `.p8`. Nothing else. |
| **Can people install it?** | **100%** — done. Build 113 is approved and live. `Friends` holds eight: you `INSTALLED`, **two anonymous public-link installs**, one emailed tester `INSTALLED`, four `INVITED` (emailed, not yet opened). | Nothing. Ship **114+** so they stop testing three-week-old code. |
| **Could this go on the public App Store?** | **~55%** — the honest number. The build is ready; the business and legal surface around it is not. | **0(a)** (purchases take money and do not unlock Premium), **0(b)** (the paid loop has never been run end to end), **9** (legal: three blanks, unreviewed, one KVKK filing), **1** and **★** (native TR/AR review — the biggest quality risk, and the crisis lexicon is a safety gate), **8(c)/(d)/(e)**, and **analytics** (Gates 2 and 3 are unfalsifiable without it). |

---

# 🔵 Two answers a session is waiting on right now

Neither takes more than a minute. Both are blocking work that is otherwise ready.

## (A) ✅ The app icon — ANSWERED 2026-08-05, no longer blocking

You said the current icon reads as phallic and asked to revert to the previous
one. **"The previous one" had three possible meanings and one of them would have
shipped the default blue Flutter logo** (the literal previous commit is the m0.1
scaffold), so you were asked to pick rather than guessed at.

**Your answer: the pre-redesign brand mark** —
`brandkit/branding-assets/icons/hayati-appicon-ios-1024.png`, the smaller,
centred seeds with a pale dot that shipped before PR #94. A session swaps every
size (15 iOS, 5 Android, plus the 1024 store icon) and it ships in the next
build. Nothing further is needed from you.

> **One thing that was flagged before you chose, recorded so nobody re-opens it.**
> The mark you picked is the *same two-seed family* as the one you are objecting
> to — smaller and centred, but the same paired-lobe shape. Three alternatives
> without that silhouette are already drawn and QA'd in `redesign/icons/` (preview
> at `redesign/icons/icon-preview.html`): **Whole Pomegranate** (*"reads as fruit
> first, love second — the most glance-proof romantic option for phones checked by
> family"*), **The Unfold** (*"fully non-romantic at a glance"*), and **Lit
> Lattice** (held for v2). **Your call stands and the session will execute it** —
> this note exists only so that if the smaller mark still reads wrong on the home
> screen, you know three finished options are already sitting there.

*The discreet grey icon stays exactly as it is — different job, deliberately.*

## (B) Does your App Store listing have a **Turkish** localization?

Your **English** screenshots are done and live — six of them, correct order, on
the listing since 2026-08-03. **Turkish was skipped**, because screenshots can
only upload into a locale that already exists on the listing. If `tr` is not
there, add it in App Store Connect (App Store → the version → **+** next to the
language list) and say so; the upload is then one dispatch.

---

# 🔴 4(a). The APNs key + the Push Notifications capability — **nothing can notify anyone until this exists**

**This is why the app never notifies you.** It is not a bug in the notification
logic — that logic is written, tested and correct. It is that the phone was never
given the plumbing to receive a push, and Firebase was never given the key it
needs to talk to Apple. Two pieces, both yours:

**1. An APNs Authentication Key (~3 min).** Apple Developer portal →
Certificates, Identifiers & Profiles → **Keys** → **+** → tick **Apple Push
Notifications service (APNs)** → Continue → Register → **Download the `.p8`**
(you can only download it once). Note the **Key ID** shown on that page and your
**Team ID** (`UH7MXG7Z94`). Then Firebase console → `hayatiapp-prod` → ⚙ Project
settings → **Cloud Messaging** → **Apple app configuration** → upload the `.p8`
with the Key ID and Team ID. **Do the same for `hayatiapp-dev`** — the same key
works for both.

**2. Tick Push Notifications on the App ID (~1 min).** Apple Developer portal →
**Identifiers** → `com.beyondkaira.hayati` → tick **Push Notifications** → Save.

> ### ✅ DONE 2026-08-06 — ticked, and the entitlement is already in a shipped build
>
> You authorised the API path; `PUSH_NOTIFICATIONS` was enabled from CI
> ([run 31130371860](https://github.com/aytekXR/hayati-mobile-app/actions/runs/31130371860))
> and the verification read in the same run returned exit 0. `aps-environment`
> then landed, the provisioning profile regenerated, and **build 115 signed and
> uploaded** — the first build in this app's history to carry a push entitlement.
>
> Undo handle, if it is ever needed: capability id
> `Q344R7M7MY_PUSH_NOTIFICATIONS`.
>
> <details><summary>The measurement that stood here before (kept, because it is what made the fix safe)</summary>
>
> The probe ran green against Apple's portal
> ([run 31054773143](https://github.com/aytekXR/hayati-mobile-app/actions/runs/31054773143))
> and reported **exit 1 — capability absent**. Not exit 2, so this is a real
> read-out and not a permissions failure: the API key *can* see the App ID, and
> what it saw was this.
>
> ```
> capabilities ticked on com.beyondkaira.hayati (the portal's own list):
>   - APPLE_ID_AUTH
>   - IN_APP_PURCHASE
>
> requested and ABSENT:
>   MISSING PUSH_NOTIFICATIONS     <- this item
>   MISSING ASSOCIATED_DOMAINS     <- item 2(d)
>   MISSING APP_ATTEST
> ```
>
> **All three are one visit and one tick each**, on the same portal page. You are
> already going there for Push Notifications; ticking the other two while you are
> in there costs nothing and closes item 2(d) at the same time.
>
> This also retired the last of the *"a session cannot read the portal, so nobody
> knows"* bullets.
>
> </details>

**Why the second one matters more than it looks.** The app has to declare a push
entitlement, and that entitlement must also exist in the **provisioning
profile**. Our release lane fetches profiles **read-only on purpose** (so CI can
never mint credentials), which means it cannot add the capability itself — a
build that claims push without the capability **fails to sign**. That is exactly
what happened with universal links and cost a release (ADR-040). So a session
will not add the entitlement until the tick is confirmed.

> ### ✅ You no longer have to *report* piece 2 — a session can now measure it
>
> Session 062 built `appid-capabilities.yml`, which reads the App ID's capability
> list straight out of Apple's portal over the App Store Connect API, using the
> same key the release lane already holds. **Just do the tick; nobody needs to
> ask you whether you did.**
>
> ```sh
> gh workflow run appid-capabilities.yml
> ```
>
> The same one dispatch also answers the two questions that used to ride along
> with this item — **Associated Domains** (item 2(d)) and **App Attest** — so
> those bullets are gone from your list too. They had been recorded as *"a
> session cannot read the portal, so nobody knows"* for months, and that turned
> out to be a missing tool rather than a missing permission.
>
> If the workflow reports **could not measure** (exit 2), that means our API key
> is not allowed to read Certificates & Identifiers — **not** that the capability
> is off. That distinction is built into the tool on purpose, because reporting
> "not ticked" when nobody actually looked would send a session off to build
> around a blocker that may not exist.

**Piece 1 — the APNs `.p8` — is the ONLY remaining blocker, and it is genuinely yours.**
Firebase's Cloud Messaging settings are console-only: there is no API a session
can read them from, `gcloud` is not installed on the session machine and there is
no application-default credential. So this one is reported, not verified — please
say when it is uploaded to **both** projects.

### The order matters, and it is not reorderable

From ADR-042 D2. A build that claims the entitlement before the capability exists
does not fail in CI — it fails in the **macOS release job**, the most expensive
place in the system to find out, because our iOS CI check builds
`--no-codesign` and cannot see the problem coming.

1. you tick **Push Notifications** and upload the `.p8` to both projects;
2. `gh workflow run appid-capabilities.yml` returns **exit 0** — measured, not reported;
3. the provisioning profile regenerates and `match` picks it up;
4. **only then** does a session add the plugin and the entitlement, in one commit.

**What you get once it is done:** a question every morning at 08:00, a nudge when
your partner answers, and a reminder at 16:00 if you have not. Those are the three
you asked for.

> ### ✅ All three are now BUILT — they are waiting on this checkbox and nothing else
>
> As of 2026-08-06 the server composes and routes all three: the 08:00 question, the
> partner-answered nudge, and the 16:00 reminder. The 16:00 one deliberately fires
> **even if you have no streak** — you asked for it so your partner does not get
> angry, not to protect a counter.
>
> **There is no engineering left between you and a notification.** The app knows
> which phone to notify and only the server can write that. The Firebase
> notification plugin is now **installed and building** (2026-08-06), so what is
> missing is exactly two things from you — the tick above and the key below — plus
> **one line** we add the moment the tick exists.
>
> That one line is an entitlement claiming push. We cannot add it early: a build
> that claims push before the App ID allows it **fails to sign**, and it fails in
> the release step rather than in the checks, which is the expensive place to find
> out. That is not caution — it happened once already, on a different capability.

**What already exists while you do it.** The server composes the "your partner
answered" push correctly today and hands it to the send seam — that half has been
built and tested since M3.4. What never existed is anything to send it *to*: no
device had ever registered a push token, because nothing in the app or the server
could write one.

**Session 062 built that.** The app can now record which phone belongs to which
account, and — this is the part that needed care — **only the server can write it.**
A phone's push token is effectively an address for that phone, so if the app itself
could edit that list, a modified app could put someone else's phone on it and start
receiving their notifications. It is now locked in the security rules in both
directions, and the lock is tested by trying to break it.

**Two things are still missing, and neither is engineering.** The plugin and the
entitlement (step 4 above) wait on your portal tick. The daily-question and
16:00 pushes you asked for are the next session's work and are not blocked by
anything.

---

# 🔴 0(a). Grant the prod RevenueCat webhook its public invoker — **issue #115**

**A purchase on production today would take your customer's money and not unlock
Premium.** `revenueCatWebhook` is deployed and `ACTIVE` on `hayatiapp-prod`, but
its Cloud Run service has **no public-invoker permission**, so Google rejects
RevenueCat's calls *before* your code runs. RevenueCat can never report a
subscription, renewal or cancellation. The charge goes through, Premium never
turns on, and **nothing anywhere reports an error**.

**Re-probed 2026-08-05: still Google's HTML 403.** A deploy does not grant
public-invoker permission, so the honest reading remains that the binding has
never existed — nothing is fighting you, and the command below is the only thing
that will create it.

```sh
gcloud run services add-iam-policy-binding revenuecatwebhook \
  --region=europe-west1 --project=hayatiapp-prod \
  --member=allUsers --role=roles/run.invoker
```

**How to tell it worked** — POST to the webhook with no token:

```sh
curl -i -X POST https://revenuecatwebhook-mzym2uw5gq-ew.a.run.app \
  -H 'Content-Type: application/json' -d '{}'
```

A **JSON** refusal is correct — that is your own code turning it away. **HTML is
still broken.** Then replay an event from the RevenueCat dashboard.

**For the people testing right now this costs you nothing** — the free tier
is the whole product, and the coach (the only Premium feature) is behind the
paywall, so nobody can reach it. **Just tell them not to tap Subscribe.** Fix it
before anyone outside that group.

**Why a session will not do this for you:** making a production endpoint publicly
reachable is a security decision on your live system, and a session cannot read
your webhook token to confirm it matches what RevenueCat sends. Opening the
endpoint without that confirmation replaces a closed door with a door that
rejects everything.

## 0(b). Apple's pricing propagation → then the sandbox purchase test

The RevenueCat project, the `premium` entitlement, both products, the `default`
offering and the In-App Purchase key are wired, and the App Store subscription
products exist. Pricing has been 409-ing purely on Apple's post-agreement
propagation (Business is green) — **Apple's clock, not yours**.

When it clears: run the **sandbox purchase test** (TR + SA, Premium must flip on
both phones — this is M4's acceptance line and the last unproven link in the
product), then **revoke the RevenueCat `sk_` v2 key**.

⚠️ **If you ever add another subscription product: leave "Family Sharing" OFF.**
It is **IRREVERSIBLE** — Apple cannot turn it off once on, and it would create a
second entitlement source the server does not control (ADR-015).

## 0(c). Put `RC_WEBHOOK_TOKEN` on **dev** — the only safe place to rehearse 0(a)

**Dev is missing the shared secret, so dev runs ten of the eleven functions.**
`revenueCatWebhook` never deploys there. Measured with prod as the control:

```
$ firebase functions:secrets:access RC_WEBHOOK_TOKEN --project hayatiapp-dev
Error: … HTTP Error: 404, Secret […/RC_WEBHOOK_TOKEN] not found or has no versions.

$ firebase functions:secrets:access RC_WEBHOOK_TOKEN --project hayatiapp-prod
(exit 0 — prod has it)
```

Why this is yours: the value must be **the same token you configure in the
RevenueCat dashboard**, and a session cannot read your dashboard.

```sh
printf '%s' '<the token from RevenueCat>' | \
  firebase functions:secrets:set RC_WEBHOOK_TOKEN --project hayatiapp-dev --data-file=-
```

**Why do it before 0(a).** 0(a) asks you to make a *production* endpoint
world-reachable. Doing that with no rehearsal anywhere is what makes it a
security decision rather than a chore. With the token on dev, a session can
deploy the eleventh function there, prove the token check refuses an unsigned
POST with **JSON** rather than Google's HTML, and hand you a verified procedure
instead of a leap.

---

# Console and portal items

## 2(a). Set a Firebase budget alert

Billing is live on both projects. The workload is couple-scoped and near-zero at
current scale, but a budget alert is **the one thing a session cannot do for
you**, and the one thing you would want already in place before a surprise.

## 2(b). Turn on Dependabot **alerts** (~1 min, one click) — issue #131's other half

CI already fails a PR that **introduces** a new dependency advisory into
`functions/`. What it deliberately does *not* do is fire when a new advisory is
published against dependencies **nobody touched** — a gate that reddens `main`
for a third party's action, on something no session can fix that hour, is a build
that cries wolf, so it was rejected on purpose (ADR-034).

That other half is a GitHub feature this repo has switched off:

```
$ gh api repos/:owner/:repo/dependabot/alerts
Dependabot alerts are disabled for this repository. (HTTP 403)
```

**Settings → Advanced Security → Dependabot alerts → Enable.** The repo is
**public**, so it is free. It watches **every** ecosystem here — `functions/` npm,
the app's `pubspec.lock`, `Gemfile.lock` and the GitHub Actions versions — not
just the one lockfile CI reads, and unlike a scheduled job it cannot rot.

⚠️ **Alerts, yes. "Dependabot security updates" (automatic PRs), no** — at least
not yet. This repo carries two open advisories whose only npm-offered fix is
downgrading `firebase-admin` to 10.3.0, which would undo ADR-031 and conflict
with ADR-030. Automatic PRs would propose exactly that, repeatedly.

**Why this is yours:** it changes repository settings and starts sending mail to
you. Neither is a session's call, even though the account has the permission.

**What you will see:** the two open advisories (`brace-expansion`, `uuid`) appear
immediately. Both were measured **unreachable** — one hangs off a `rimraf` that
`google-gax` declares and never imports, the other sits under an optional Google
Cloud Storage package these Functions never load. Recorded in ADR-034, not
forgotten.

## 🟡 2(d). Enable **Associated Domains** on the App ID — invite links open the app instead of the browser

Apple Developer portal → Certificates, Identifiers & Profiles → **Identifiers** →
`com.beyondkaira.hayati` → tick **Associated Domains** → Save.
*(Same page as **4(a)**'s Push Notifications tick — do both in one visit.)*

> **Measured 2026-08-06: `ASSOCIATED_DOMAINS` is absent.** Confirmed by the same
> read-out as 4(a) — see the box there for the portal's full capability list.
> This item had been carried for months as *"nobody can see the portal"*; that is
> no longer true in either direction.

**Not blocking** (ADR-040). It *was*: the entitlement must exist in the
**provisioning profile** as well as in `Runner.entitlements`, and `match` fetches
profiles **readonly** (ADR-032) precisely so CI can never mint credentials, so
signing would have failed with an entitlement mismatch. Rather than hold every
release behind a portal visit, the entitlement was **removed** and working builds
ship without it.

**What you lose until you tick it:** an invite link opens the **web page** rather
than jumping straight into the app. The page shows the code with a copy button,
and the invitee enters it via "Have a code?" — one extra step, for the invitee
only. Nothing is broken; it is one tap less direct.

**What ticking it buys:** the next build after it re-adds the entitlement (ordered
steps are written inside `app/ios/Runner/Runner.entitlements`), and from then on a
tapped invite lands in the app. The `apple-app-site-association` file is **already
live and verified** at `https://ikimiz.web.app/.well-known/apple-app-site-association`,
so nothing else is needed on the web side.

**~~Say what you see either way. A session cannot read the portal, so nobody
knows whether this capability is already enabled~~** — **no longer true as of
Session 062.** `gh workflow run appid-capabilities.yml` reads the App ID's
capability list out of Apple's portal and prints it, so this question and the App
Attest one below are both answered by one dispatch and neither needs you to
report anything. See item **4(a)**. *(What remains true: no build has ever been
signed with this entitlement, so the capability has never been exercised even if
it is enabled.)*

> **The third capability question, same page (ADR-039).** The prod App Check
> provider is **App Attest**, but `Runner.entitlements` deliberately does *not*
> declare `com.apple.developer.devicecheck.appattest-environment` — so prod
> attestation cannot currently succeed. Harmless today (App Check activation
> fails open instead of blocking the boot, and enforcement is off), but it will
> hard-break the day enforcement is switched on. A session did not add the
> entitlement blind, for the same signing reason as above. ~~**Check whether App
> Attest appears in the capability list and say what you see**~~ — **you do not
> need to look.** `gh workflow run appid-capabilities.yml` prints the entire
> capability list, App Attest included (item **4(a)**).

## 2(e). The website — the invite half is LIVE; the pretty domain and the legal pages need you

Measured 2026-08-05: `https://ikimiz.web.app` serves `/` **200**, `/support`
**200**, `/i/<code>` **200**, AASA **200**. `/privacy` **404** — deliberately, see
(ii). Nothing below blocks invites, TestFlight, or the app.

### (i) The DNS record points somewhere else — measured, not assumed

```
ikimiz.beyondkaira.com  ->  161.97.172.146   (your own VPS; TLS handshake fails
beyondkaira.com         ->  161.97.172.146    outright — the cert covers the apex only)
```

There is an explicit `A` record for `ikimiz` pointing at your server, not a
wildcard. Firebase Hosting needs it pointed at Firebase instead:

Firebase console → `hayatiapp-prod` → **Hosting** → the **`ikimiz`** site → **Add
custom domain** → `ikimiz.beyondkaira.com`. Firebase gives you a `TXT` record to
prove ownership and then the `A` records to replace `161.97.172.146` with. TLS is
issued automatically. **Nothing else on this page depends on it.**

Until then, invite links are emitted on `ikimiz.web.app` (Google-issued TLS, no
DNS record from anybody). The custom domain is still **parsed** by the app, so
nothing already sent breaks and moving over later is a one-line change.

### (ii) One legal blank is still open, and it is the one only you can fill

You chose (Session 055): **you personally as the data controller, contact
aytek@beyondkaira.com, governed by Turkish law.** Two of those three are ready to
write. The third — the controller's **legal identity as it should appear in a
privacy policy** — needs your actual full legal name, which no session should
guess. Send it and all three land in all six documents in one diff.

Until then the builder **refuses** to publish the legal documents, which is the
point: a policy Apple's listing points at must not say "to be completed by the
founder". The invite-only publish is not a loophole — it publishes **no policy at
all**, so it cannot publish an unfinished one.

⚠️ **This is also why your App Store privacy URL does not resolve.** The listing
declares `https://ikimiz.beyondkaira.com/privacy`; that host fails TLS, and
`ikimiz.web.app/privacy` 404s. The in-app legal documents are bundled and
reachable, which is what **consent** actually depends on, so the app itself is
fine — but this **will** block App Store submission. The chain is: your legal
name → the legal pages publish → `/privacy` resolves. One fact unblocks all of it.

### (iii) Optional — let CI deploy the site **and the firestore rules**

Today the site is deployed with the local `firebase` CLI, logged in as you.
`FIREBASE_SERVICE_ACCOUNT` is **unset** (re-confirmed 2026-08-05), so CI cannot.
Worth fixing so the site does not depend on one laptop's login:

```sh
gh secret set FIREBASE_SERVICE_ACCOUNT < service-account.json   # Firebase Hosting Admin, hayatiapp-prod
gh workflow run deploy-site.yml -f channel=live -f invite_only=true
```

Drop `invite_only` once (ii) is filled and the full site — six legal documents in
three languages — publishes.

The same secret also powers `deploy-rules.yml`, the dispatch-only lane that
publishes `firestore.rules` (ADR-041, issue #140). For that half the service
account additionally needs **Firebase Rules Admin** on whichever project you want
CI able to deploy to. Grant it on `hayatiapp-dev` freely; grant it on
`hayatiapp-prod` only if you want CI to be *able* to change production's
authorization rules — the lane still requires a manual dispatch and requires
typing `hayatiapp-prod` into a confirmation box, and **no session will fire it at
prod without asking you first.**

### (iv) One read-only secret arms the check that catches silent rule drift — issue #165

Read-only, one command, closes a real hole.

For eighteen days both projects served the rules from **2026-07-09** while six
milestones of newer rules sat merged in the repo and never deployed. That is what
made "Invite Your Partner" show *Something went wrong* on your build — not the
invite code, but the phone being denied permission to read its own answers. Every
CI check was green throughout, because the only thing testing the rules was an
emulator loading the file from the repo, never the one Firebase was enforcing.

The check exists now (`rules-drift` in `ci.yml`). **It cannot run without a
credential, and rather than pretend to pass it shows as SKIPPED on every run.**
*(Both projects are in sync today — re-measured 2026-08-05, exit 0. The gap is
that nothing is watching.)* To arm it:

1. Firebase console → ⚙ → **Users and permissions** → **Service accounts** tab →
   Google Cloud console → **Create service account**, name it `ci-rules-viewer`.
2. Grant it the role **Firebase Rules Viewer** — on **both** `hayatiapp-prod` and
   `hayatiapp-dev`. It is read-only: this account cannot change anything, which is
   deliberate, so the job that runs on every merge can never itself cause the
   drift it is looking for.
3. Create a **JSON key** for it and download the file.
4. ```sh
   gh secret set FIREBASE_RULES_VIEWER_SA < ci-rules-viewer.json
   ```
5. Delete the downloaded file. Confirm with `gh secret list`; the run after that
   shows `rules-drift` as a real green check instead of a skipped one.

---

# 5. SECURITY — rotate the leaked Slack webhook (~10 min, open since S005)

**Verified still open 2026-08-05:** `gh secret list` returns five secrets, all
release-signing (`ASC_API_KEY_P8_BASE64`, `ASC_ISSUER_ID`, `ASC_KEY_ID`,
`MATCH_GIT_URL`, `MATCH_PASSWORD`) — **`SLACK_WEBHOOK_URL` does not exist.** The
local `chore/slack-notifications` branch still exists too, so the webhook to
revoke is still identifiable.

That branch (commit `13f1e6d`) has a **live Slack webhook URL in plaintext**
inside a workflow file. It never reached GitHub (push protection blocked it), but
a credential in a git commit is a leaked credential.

The CI→Slack wiring is built, tested and merged, and stays **silent** until you do
these four steps — it never spams, never warns, and never reddens a build for a
missing secret.

1. **Revoke the old webhook** in Slack: api.slack.com/apps → the owning app →
   *Incoming Webhooks* → remove it. **Do NOT push/merge the
   `chore/slack-notifications` branch** — it is only the evidence of which webhook
   to revoke. After revoking, `git branch -D chore/slack-notifications` is safe.
2. **Create a fresh Incoming Webhook:** api.slack.com/apps → *Create New App → From
   scratch* → name `Hayati CI` → your workspace → *Create App* → **Features →
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
`integration-emulator` on `main` (it runs only after merge, when the session has
moved on) — that is the message this exists to deliver.

---

# 4. On-device verification — the checks only your iPhone can settle

**4(a) is above** and gates the whole notification feature. The rest of this item
is observation.

Your release ritual, from `main`, on Linux — no Mac, no Xcode, no manual upload:

```sh
gh workflow run release.yml --ref main      # or: git tag v0.1.0 && git push --tags
```

Build numbers are automatic (`100 + the CI run number`); the *version* (`0.1.0`)
comes from `app/pubspec.yaml` and must match the tag, and CI stops you loudly if
they disagree.

✅ **Resolved 2026-08-06/07.** Build 114 was never submitted, and rather than
submit a stale binary, **115 and then 116 were built and submitted** — 116 carries
the post-sign-in dead-end fix (the "Something went wrong" you reported), the real
support page, the UI polish pass, the iPhone-only change AND the entire
notification stack. **Install 116.** The dispatch below is kept for the next time:

```sh
gh workflow run testflight-testers.yml \
  -f dry_run=false -f assign_latest_build=true -f submit_for_review=true
```

⚠️ **After any release, read the `assign the new build to the Friends group`
step's log, or run `-f status_only=true`. Do not infer delivery from a green
release.** That step is `continue-on-error` on purpose — Apple's processing queue
is a third party's schedule and should not redden a release — but non-blocking
must not mean unread. It failed silently on its first two attempts.

⚠️ **Keep your `MATCH_PASSWORD` safe.** It decrypts the certificates repo
(`aytekXR/hayati-match-certs`). Lose it and the stored signing identity is
unreadable — recoverable (a session can re-bootstrap) but annoying, and Apple
caps distribution certificates at 3.

Please eyeball each of these on a TestFlight build:

1. **Keychain round-trip** — set a PIN, force-quit, relaunch → must ask for the
   PIN. Then **delete the app, reinstall, launch → it must STILL ask for the PIN**
   (the reinstall-bypass defence; if it opens straight in, that is a real hole —
   tell a session immediately).
2. **Face ID self-revoke** — turn it on, lock, unlock with Face ID. Then change or
   add a face in iOS Settings and reopen the app → it must have switched Face ID
   **off** by itself and demand the PIN.
3. **Discreet icon** — flip it in Settings. iOS shows its own "you changed the
   icon" alert (Apple's, expected, unsuppressible). Confirm the icon changes and
   the **name under it does not**.
4. **App-switcher snapshot** — open the coach or a revealed answer, swipe to the
   app switcher → the card must show a **blank panel**, never your content.
5. **Cold-start stopwatch** — time a cold launch of the **prod** build (airplane
   mode + normal). CI deliberately does not assert the <2s number; your phone is
   where the honest number comes from.
6. **Invite round-trip** — send an invite from one phone, open the link on the
   other. It should land on `https://ikimiz.web.app/i/<code>` with a copy button
   (not the app — that is 2(d)), then "Have a code?" should pair you.
7. **Issue #15** — if phone-auth sign-in crashes natively, capture the log
   (Xcode → Window → Devices → Open Console). That log is the whole blocker.
8. **Issue #48** — a transient Face ID lockout (too many failed attempts)
   currently appears to revoke the biometric accelerator permanently. The issue
   defers to your observation of what actually happens on the device.
9. Also: Apple first-authorization full name reaching `displayName`; deep-link
   cold+warm OS→app delivery; the real-device pairing test.

**Also riding this item:** **dSYM upload** for Crashlytics, **App Attest** (App
Check enforcement stays OFF in both consoles until on-device attestation is
verified), and **Universal links** (2(d)).

> **One thing nobody can settle from a laptop:** whether the hourly rollover job
> is actually **enabled** in Cloud Scheduler. `gcloud` is not installed here and
> there is no application-default credential, so this has never been verified —
> it is recorded as unknown rather than assumed. It matters more now than it did:
> the 08:00 question push will ride that same hourly sweep. Google Cloud console →
> Cloud Scheduler → `hayatiapp-prod` → confirm the job is `ENABLED` on `0 * * * *`.

---

# Activation infrastructure — still unbought, still gating the funnel

None of these block TestFlight or on-device testing. All of them block a real
launch, and each is a purchase or a decision only you can make.

- [ ] **Analytics wiring decision** — `app/lib/core/analytics/` is empty. **Gate 2
      and Gate 3 are unfalsifiable without it**: activation and monetization
      cannot be measured, so the gates cannot be passed or failed honestly.
- [ ] **The Gate 1 content bank** — the TikTok/content-ops track, dormant by
      ADR-007 unless you re-activate it.
- [ ] **The ADR-027 trademark decision** — worth doing before public launch, not
      blocking anything now.

---

# Content and copy decisions

## The couple questions are the Turkish SOLO pack — a known placeholder

Not a bug, and recorded in the code (`rollover-service.ts:29`: *"Placeholder
couple bank until W9 authors the real couple packs"*). `content/packs/` holds
`solo_tr`, `solo_ar`, `solo_en` and no couple packs, so a paired couple falls back
to `solo_tr`.

For Turkish-speaking testers the *language* is right. What they will notice is
that the questions are **the same ones they already answered during solo week**.
If the beta is meant to test the couple ritual rather than the plumbing,
authoring one real couple pack (W9, `content/README.md`) is the highest-value
content work available — and it needs you, not a session.

## Two words differ between your App Store listing and your app — your call

A brand decision rather than a bug, so nothing was changed in either place:

| Thing | Your App Store description says | Your app says |
|---|---|---|
| the streak unit | **nar tanesi** / pomegranate seed | **tohum** / seed (`app_tr.arb:86`) |
| the weekly grace day | **hoşgörü günü** | **Merhamet günü** (`app_tr.arb:88`) |

A Turkish user reads one word in the listing and sees another in the app. The
website follows the **app**, on the reasoning that the site describes what someone
is about to see — but if you prefer the listing's words, the app is the side to
change, and a session can do it in one diff. **Tell us which.**

---

# Before PUBLIC launch (none of these block TestFlight or on-device testing)

## 1. Native review of the app content — **the biggest quality risk in the product**

Every TR/AR string is an AI draft marked review-PENDING. The redesign waves added
more, all flagged "native register review pending" per commit. TR: you two. AR:
your Gulf-dialect reviewer. Mandatory before any public launch
(`content/README.md`, W9). All editable in place, or send corrections to a session.

> **⚠️ One concrete thing to watch for in the ARABIC copy.** Arabic punctuation and
> Western punctuation are **not interchangeable** in a right-to-left layout. `؟`
> (the Arabic question mark, U+061F) is a *strong* character — it always sits where
> it should. A Western `.` or `?` is *neutral*, and next to Latin text it can jump
> to the wrong end of the line. All seven Arabic solo questions correctly end with
> `؟`; some of the AI-drafted **coach** copy ends Arabic sentences with a Western
> `.` instead. The app compensates automatically, so nothing is broken — but **if
> you are editing Arabic copy, prefer `؟` and `،` over `?` and `,`**. It is
> invisible in the text file and only shows up on screen.

- **Solo questions** (7 × TR/AR/EN) — `content/packs/solo_{tr,ar,en}.json`; run
  `dart content/validator/validate.dart --sync`. These double as the **couple**
  question-bank placeholder, so edits pay off twice. *A question may carry
  `"seasonalWindow"` — exactly one of `ramadan`, `eid_fitr`, `eid_adha`,
  `new_year` — and is then offered only inside that window. Anything else is a
  loud validation error by design. Ramadan/Eid dates follow the Saudi Umm al-Qura
  calendar, which can differ by a day from Diyanet or local sighting; we chose not
  to fudge the edges — say the word if you want it padded.*
- **Paywall / pack copy** (~28 strings × TR/AR/EN) — `app/lib/core/l10n/arb/`
  (keys `paywall`/`packs`/`packSelection`).
- **Coach chat copy** (27 strings × TR/AR/EN) — keys `coach*`, plus persona/register
  TONE blocks in `functions/src/coach/persona-prompts.ts` (safety lines are the ★
  gate below). Includes the Perisi/ملهم persona-naming call.
- **Lock & settings copy** (41 strings) — keys `lock*`/`settings*`. Two carry
  **safety** meaning worth your eyes: the **Face ID warning** (factual caution, not
  accusation) and the **"Forgot PIN?"** copy (recovery signs you out, does not
  quietly let someone in).
- **Data-rights copy** — keys `dataRights*`/`coupleEnded*`/`settingsNotificationPrivacy*`.
  Three carry legal or safety weight: the **deletion confirmation** (irreversible;
  "both of you"), the partner's **"shared space closed" notice** (calm, non-blaming,
  never names who), and the **"does not cancel your subscription"** line (users act
  on it with money involved).
- **Store listing** (`fastlane/metadata/{tr,en-US}`) + the localized **Face ID** and
  **Local Network** purpose strings
  (`app/ios/Runner/{en,tr,ar}.lproj/InfoPlist.strings`).
- **New, when 4(a) lands:** the **push notification copy** — three (soon four)
  message types × TR/AR/EN × the discreet variant. These are the only strings in
  the product a user reads on a lock screen, in front of other people.

## ★ Crisis-content safety review — the one gate before the coach runs on a real device

The crisis word-lists (TR / AR incl. Arabizi / EN), the professional-help response,
the "not therapy" disclaimer, and the safety lines of the coach's system-prompt
preamble are AI-drafted and marked `nativeReview: PENDING`. **An under-reading
crisis filter is a safety failure — only native speakers can judge the lists.**
TR: you two (~15 min). AR incl. Arabizi: your Gulf reviewer.

- **Also here:** crisis-hotline numbers are deliberately NOT in the app (a wrong
  number is dangerous) — choose the TR/SA numbers you trust and a session wires
  them in. A CI test fails if a phone-number-shaped string is added to coach copy
  without going through this gate.
- **Where:** `functions/src/coach/crisis-lexicon.ts`,
  `functions/src/coach/help-content.ts`, `functions/src/coach/persona-prompts.ts`,
  and `coachDisclaimerBody` in `app/lib/core/l10n/arb/`.
- **When:** blocks the first on-device coach use.

## 9. The legal bundle — your review, three blanks, three lawyer questions, one filing

The six documents at `docs/legal/` (privacy policy + terms × TR/AR/EN — also in the
app under Settings → Privacy & Terms) are AI-drafted against the shipped code and
marked review-PENDING. They currently carry **legal version 2**, which names
Anthropic as the coach's AI provider.

- **(a) Native + legal review** of the six docs. TR: you two (~5 min; the policy
  doubles as the KVKK aydınlatma metni). AR: your Gulf reviewer. Legal: your lawyer.
  A material change bumps the version and re-asks everyone's consent.
- **(b) Three blanks only you can fill** (bracketed in every doc): the controller's
  legal identity (your name or a company), a contact address, and the governing law.
  **This is the same blank as 2(e)(ii)** — filling it once unblocks both.
- **(c) Three recorded lawyer questions** (in `docs/legal/README.md` + ADR-023):
  **A** — is relationship-content processing special-category under KVKK Art 6 /
  PDPL (we implemented conservative YES)? **B** — may the one consent be required to
  use the reflective features (required, but sign-out/export/delete always open)?
  **C** — must consent withdrawal *erase* stored reflections, or does
  stop-collecting + self-serve deletion suffice (we implemented the latter, for the
  DV reason)?
- **(d) One real legal action — the KVKK data-transfer filing.** Hosting TR users'
  data on Google's EU servers is a cross-border transfer under amended Art 9: sign
  Google's Kurul-approved standard contract and **file it with the Kurum within 5
  business days of signing**. **Anthropic is a US processor**, so the same
  standard-contract leg and filing now cover them too. Evidence and links in
  `docs/dpa-inventory.md`. Needed before PUBLIC launch, not for TestFlight.
- **(e) Also recorded, none urgent:** the Kurul "adequate measures" question; the
  seven PDPL items before the first Saudi user; a GDPR flag for the Phase-4
  EU-diaspora channel; **İYS registration before any promotional push** — note that
  4(a) makes push real, and this obligation attaches to *promotional* messages only,
  not to the daily-ritual notifications.
- **(f) Optional, would let us say something stronger:** enable
  **zero-data-retention** on your Anthropic organisation and a session will tighten
  the privacy notice to match. Today it says Anthropic does not train on your coach
  messages (true under their commercial terms) but stops short of claiming they
  retain nothing, because their default API retention is limited but not zero.

## 8. Store-listing decisions + the missing web pages (pre-submission, none blocking)

- **(c) Privacy-policy + support-page URLs.** The support page **now exists and
  resolves** (`https://ikimiz.web.app/support`). The privacy URL does not — see
  2(e)(ii). The listing ships EMPTY URL fields behind a loud CI warning (never a
  fake URL). Apple requires both at submission; the in-app requirement is already
  met by the in-app documents. When hosted, a session drops the lint's
  `--allow-empty-urls` flag.
- **(d) Age rating:** verify at first submission — whether Apple's questionnaire
  treats the AI coach as a maturity factor is only provable in App Store Connect. If
  it forces a higher tier, the choice (constrain vs accept) is yours.
- **(e) App Privacy questionnaire** — the manifest ships
  (`app/ios/Runner/PrivacyInfo.xcprivacy`). Four recorded judgment calls to resolve
  against the questionnaire: (i) the App Privacy labels must match the declared
  types (contact info, User ID, Other User Content, Purchase History, Crash Data —
  all non-tracking); (ii) whether couples' free-text + coach content warrants
  Apple's **"Sensitive Info"** category (the manifest omits it — Apple's taxonomy ≠
  KVKK's); (iii) Crash Data declared **not linked** to identity — confirm; (iv) the
  **Local Network** purpose string ships in prod for the dev rig (prod makes no LAN
  connections) — decide keep/reword/strip at submission.

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

## #63 — Phosphor vs Material icons

The brand kit names **Phosphor** icons; the app ships **28 Material** icons and
Phosphor was never added. Options: **(a)** switch to Phosphor (new dependency, 28
icons re-drawn, a size increase, and hand-mirrored twins for every directional icon
since Phosphor will not auto-flip in Arabic); **(b)** update the brand kit to say
Material (cheapest, honest — Material outline reads well with the brand; **the
recommendation** unless you have a view). Either is fine; a Phosphor switch would be
its own session.

## #71 — a motion token in the brand kit

Motion is defined in brand-kit §6 prose (150–300ms, ease-out) but has no token in
`hayati-tokens.json`; the app realises it as `MotionTokens` (review-enforced). A
brandkit-revision decision — add a `motion` block to the tokens JSON and the parity
test could check it mechanically.

---

# Two facts about your TestFlight group you should know

Neither is a fault; both are things a founder should know rather than discover.

* **Two of the eight `Friends` testers are anonymous public-link installs**
  (`inviteType='PUBLIC_LINK'`, no email, both `INSTALLED`). A public TestFlight
  link exists somewhere and strangers have used it. That may be exactly what you
  intended — if not, the link can be disabled in App Store Connect.
* **Tester emails travel through a `workflow_dispatch` input, which is
  world-readable on a public repo** — and older revisions of this file listed five
  in plain text. Both are in git history now, so this is recorded rather than
  fixable. Noted because it should be a decision rather than a default. **This file
  no longer prints tester addresses, and the four Beta App Review contact values
  never took that path at all** — they are secrets precisely for this reason
  (ADR-038 D1). If you want the emails out of the public record, that is a history
  rewrite and a founder call. Also: because those four values are secrets, GitHub
  redacts them *anywhere* they appear in a log, including in unrelated output — one
  friend shares your surname, so her last name prints as `***` too. Nothing is
  wrong; the log is just less readable than it looks.

---

# Engineering issues you may want to know about — but that need nothing from you

Listed only so nothing on this page looks like a silent gap. Sessions drive all of
these.

| Issue | What |
|---|---|
| **#176** | The Question text style asks for Rubik **Light**, which is not bundled — so it silently renders at Regular. The cheapest real bug on the list. |
| **#175** | 10 of 14 raised cards render flat: the card decoration is copy-pasted per screen instead of coming off the theme. |
| **#174** | Nothing in the app is announced to VoiceOver when the reveal happens — no `liveRegion` anywhere. |
| **#166** | Nothing compares the **deployed function code** to `main`, the way `rules-drift` now does for rules. Deliberately measurement-first: the first question is whether it is answerable at all. |
| **#165** | `rules-drift` is built but unarmed — that is item 2(e)(iv) above. |
| **#137** | The bidi seam relies on a library whose character ranges miss one Arabic block; isolation silently no-ops for it. Not reachable in Turkish or Gulf Arabic — filed because it fails quietly. |
| **#136** | Arabic **push-notification** bodies interpolate a partner's name without the isolation the app applies on screen. Latent today — **it stops being latent the moment 4(a) lands and pushes start arriving.** |
| **#129** | The release lane's `Gemfile.lock` comment is false, the lane installs unfrozen, and no release run has touched the committed lock. |
| **#121** | Confirm a likely-dead App Store Connect key step in the release lane. Its old blocker (2(d)) is dead; pair it with #129. |
| **#41** | `app_user_id` = Firebase uid is a threat-model gap. **Wants deciding before real purchases accumulate** — after that it becomes a migration rather than a clean change. |
| **#48**, **#15** | Waiting on your device — items 4(7) and 4(8) above. |
| **#13** | Android instant verification — M6.5, waits on your Gate 3 call. |

---

# Retired item numbers still cited by code

Kept only so a message printed by a tool points somewhere real. Nothing here needs
you.

| Number | Cited by | Status |
|---|---|---|
| **2(c)** — TestFlight external submission | `tool/ci/testflight_testers.py:1291` (prints only when the four Beta App Review contact fields are missing) | **Closed 2026-08-05.** Submitted 2026-08-01, approved by Apple, build 113 `IN_BETA_TESTING`, invitations sent. The contact fields are set and held as `release`-environment secrets. |
| **#140** — merged-vs-deployed rules | ADR-041, `rules_drift.py` | **Closed 2026-08-01.** Residuals are #165 (above) and #166. |
| **#130** — seasonal vocabulary parity | ADR-026 D3 | **Closed 2026-08-02** by PR #171. |
