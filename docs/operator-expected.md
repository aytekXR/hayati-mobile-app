# Operator Expected — what Hayati needs from you (the founder)

> **Canonical, committed** operator checklist (founder request, Session 009): the
> single place to see what is expected from you, refreshed at every session
> close. Check it after every merge to `main`.
>
> **This file lists ONLY open, actionable items.** Nothing that is finished
> appears here. Closed items and the session-by-session narrative live in
> `docs/past-prompts.md`; engineering decisions live in `docs/adr/`; tracked
> engineering work lives in GitHub issues.
>
> Re-pruned to open-items-only on **2026-07-27 (Session 050)** — the file had
> re-accumulated ~450 lines of ✅ DONE blocks, superseded corrections and session
> narrative since the last prune at Session 036.

_Last refreshed: 2026-07-28, **Session 055 close**._

**Where things stand in one line:** the MVP is code-complete, both backends run
current code and current rules, and build **110** (real icon) is **installable on
your own phone right now** via the `founders` internal group — **the only thing between it and your five
testers is four contact fields, and item 2(c) is now a four-line recipe for
them**; the website is built and proven on a preview URL and waits only on a DNS
record and one legal blank; the product's one unproven link is still a **real
purchase**, behind item 0(a).

> **⚠️ Read 2(c) and 2(d) first.** 2(c) is ~2 minutes and puts the app in your
> friends' hands. 2(d) is one checkbox in Apple's portal and, until it is ticked,
> **the next release build will fail to sign** — build 110 predates that
> entitlement, which is why 2(c) ships 110 rather than cutting a new build.

> **⚠️ What Session 052 found, because it is the thing most likely to bite you
> again.** Your "Something went wrong" bug was never in the app. **Firestore
> rules had not been deployed since 2026-07-09** — prod and dev were both
> serving the M2.1 ruleset, so six milestones of rules (solo answers, couple
> days, answers, subscriptions, coach usage, consent) existed only in the repo
> and every read they governed was denied. Separately, prod **Functions** ran
> code from 2026-07-25 21:54 UTC. Both are now current on both projects.
>
> Nothing in CI compares what is *merged* to what is *deployed*, for rules or
> for functions — which is why this sat green for eighteen days. **Issue #140**
> tracks the missing gate. Until it exists, treat "it is on `main`" and "it is
> live" as separate facts.

---

# 🔴 0(a). Grant the prod RevenueCat webhook its public invoker — **issue #115**

**A purchase on production today would take your customer's money and not unlock
Premium.** `revenueCatWebhook` is deployed and `ACTIVE` on `hayatiapp-prod`, but
its Cloud Run service has **no public-invoker permission**, so Google rejects
RevenueCat's calls *before* your code runs. RevenueCat can never report a
subscription, renewal or cancellation. The charge goes through, Premium never
turns on, and **nothing anywhere reports an error**.

Re-probed at the Session 052 close (2026-07-27 16:26 UTC), immediately after a
full eleven-function redeploy: **still returning Google's HTML 403.** Unchanged
for five sessions.

**That redeploy settles a question this page used to leave open.** The old
wording said HTML *after* a fresh deploy would mean "something is actively
removing that binding." It does not. A deploy does not grant public-invoker
permission, so a redeploy was never going to create one — the honest reading is
simply that **the binding has never existed**, and the `gcloud` command below is
still the only thing that will create it. Nothing is fighting you.

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

**Why a session will not do this for you:** making a production endpoint publicly
reachable is a security decision on your live system, and a session cannot read
your webhook token to confirm it matches what RevenueCat sends. Opening the
endpoint without that confirmation replaces a closed door with a door that
rejects everything.

---

# The rest of the paid loop

## 0(b). Apple's pricing propagation → then the sandbox purchase test

The RevenueCat project, the `premium` entitlement, both products, the `default`
offering and the In-App Purchase key are wired, and the App Store subscription
products exist. Pricing has been 409-ing purely on Apple's post-agreement
propagation (Business is green) — that is **Apple's clock, not yours**.

When it clears: run the **sandbox purchase test** (TR + SA, Premium must flip on
both phones — this is M4's acceptance line and the last unproven link in the
product), then **revoke the RevenueCat `sk_` v2 key**.

⚠️ **If you ever add another subscription product: leave "Family Sharing" OFF.**
It is **IRREVERSIBLE** — Apple cannot turn it off once on, and it would create a
second entitlement source the server does not control (ADR-015).

## 0(c). Put `RC_WEBHOOK_TOKEN` on **dev** — the only safe place to rehearse item 0(a)

**Dev is missing the shared secret, so dev runs ten of the eleven functions.**
`revenueCatWebhook` never deploys there. Measured at the Session 051 open, with
prod as the control:

```
$ firebase functions:secrets:access RC_WEBHOOK_TOKEN --project hayatiapp-dev
Error: … HTTP Error: 404, Secret [projects/870954957461/secrets/RC_WEBHOOK_TOKEN]
not found or has no versions.

$ firebase functions:secrets:access RC_WEBHOOK_TOKEN --project hayatiapp-prod
(exit 0 — prod has it)
```

Why this is yours and not a session's: the value must be **the same token you
configure in the RevenueCat dashboard**, and a session cannot read your
dashboard. It is ADR-013 work to do *with* you — it takes one command once you
have the token in front of you:

```sh
printf '%s' '<the token from RevenueCat>' | \
  firebase functions:secrets:set RC_WEBHOOK_TOKEN --project hayatiapp-dev --data-file=-
```

**Why it is worth doing before 0(a).** Item 0(a) asks you to make a *production*
endpoint world-reachable. Doing that with no rehearsal anywhere is the part that
makes it a security decision rather than a chore. With the token on dev, a
session can deploy the eleventh function there, prove the token check refuses an
unsigned POST with **JSON** rather than Google's HTML, and hand you a verified
procedure instead of a leap.

This has been quietly true since Session 013 and was never written down here —
it lived only in the session-to-session prompt. Filed now because a remainder
that lives only in prose is a remainder that gets lost.

## 2(a). Set a Firebase budget alert

Billing is live on both projects. The workload is couple-scoped and near-zero at
current scale, but a budget alert is **the one thing a session cannot do for
you**, and the one thing you would want already in place before a surprise.

## 2(b). Turn on Dependabot **alerts** (~1 min, one click) — issue #131's other half

Session 053 built the half a session can build: CI now fails a PR that
**introduces** a new dependency advisory into `functions/`. What it deliberately
does *not* do is fire when a new advisory is published against dependencies
**nobody touched** — a gate that reddens `main` for a third party's action, on
something no session can fix that hour, is a build that cries wolf, so it was
rejected on purpose (ADR-034).

That other half is a GitHub feature this repo simply has switched off:

```
$ gh api repos/:owner/:repo/dependabot/alerts
Dependabot alerts are disabled for this repository. (HTTP 403)
$ gh api repos/:owner/:repo/automated-security-fixes
{"enabled":false,"paused":false}
```

**Settings → Advanced Security → Dependabot alerts → Enable.** The repo is
**public**, so it is free. It watches **every** ecosystem here — `functions/`
npm, the app's `pubspec.lock`, `Gemfile.lock` and the GitHub Actions versions —
not just the one lockfile CI reads, and unlike a scheduled job it cannot rot or
switch itself off.

⚠️ **Alerts, yes. "Dependabot security updates" (automatic PRs), no** — at least
not yet. This repo currently carries two open advisories whose only npm-offered
fix is downgrading `firebase-admin` to 10.3.0, which would undo ADR-031 and
conflict with ADR-030. Automatic PRs would propose exactly that, repeatedly.

**Why this is yours:** it changes repository settings and starts sending mail to
you. Neither is a session's call, even though the account has the permission.

**What you will see, and what it means:** the two open advisories
(`brace-expansion`, `uuid`) will appear immediately. Both were measured this
session as **unreachable** — one hangs off a `rimraf` that `google-gax` declares
and never imports, the other sits under an optional Google Cloud Storage package
these Functions never load. They are recorded in ADR-034, not forgotten.

## 🔴 2(c). Get the app to your five testers — **four secrets, then one command**

**This is the shortest path on this page and it is worth doing first.** Session 055
measured what actually stands between your testers and the app, and it is smaller
than this page used to imply:

```
app: ikimiz (com.beyondkaira.hayati)
builds: 110 VALID (2026-07-27, real icon)  109 VALID  3  2  1
beta app review readiness (external testers need this):
  MISSING - Test Information: review contact email is empty
  MISSING - Test Information: review contact first name is empty
  MISSING - Test Information: review contact last name is empty
  MISSING - Test Information: review contact phone is empty
```

**That is the whole gap.** The beta description and the feedback email are already
filled in — only the four *contact* fields are empty, and none of them is copy. They
are your name, your email and your phone number. A good build has been sitting in
TestFlight since 27 July waiting on a form.

> ### ✅ You can install build 110 today. Right now.
>
> Measured against Apple immediately after the Session 055 merge:
>
> ```
> build 110  processing=VALID  external=READY_FOR_BETA_SUBMISSION  internal=IN_BETA_TESTING
> ```
>
> **`internal=IN_BETA_TESTING`** means the **`founders`** internal group already has
> it. Open TestFlight on your iPhone and it is there — no review, no waiting, nothing
> below required. If your partner is not seeing it, she is not in that group yet:
> App Store Connect → **Users and Access** → invite her Apple ID → add her to
> `founders`. Internal testers never wait for Beta App Review.
>
> `external=READY_FOR_BETA_SUBMISSION` is the other half: the *external* groups
> (`Friends`, `arkadaslar`) are not in review yet, which is what the four fields
> below unblock.

A session can now write that form for you (ADR-038), but the four values are facts
about *you*, so they come from secrets rather than from a text box. **They must not
go in a workflow input: this repository is public, and dispatch inputs are recorded
in run metadata anyone can read — a box asking for your mobile number would publish
it permanently.**

### Step 1 — set four secrets (once, ~1 minute)

```sh
gh secret set ASC_REVIEW_CONTACT_FIRST_NAME --env release --body 'Aytek'
gh secret set ASC_REVIEW_CONTACT_LAST_NAME  --env release --body 'YOUR SURNAME'
gh secret set ASC_REVIEW_CONTACT_EMAIL      --env release --body 'aytek@beyondkaira.com'
gh secret set ASC_REVIEW_CONTACT_PHONE      --env release --body '+90XXXXXXXXXX'
```

The `release` environment, to match `ASC_KEY_ID`/`ASC_ISSUER_ID`. Apple wants a phone
number it could actually reach; it is not published to testers.

⚠️ **All four or none.** Apple accepts three of four and still shows the page as
incomplete, so the tool refuses a partial write and names what is missing.

### Step 2 — write the page, attach the build, and start the review

```sh
# Look first. Writes nothing, invites nobody.
gh workflow run testflight-testers.yml -f dry_run=true -f set_review_contact=true

# Then, for real: fill the page and send build 110 to Beta App Review.
gh workflow run testflight-testers.yml \
  -f dry_run=false \
  -f set_review_contact=true \
  -f submit_for_review=true
```

> **`assign_latest_build` is not needed** — measured at the S055 close, build 110
> is already attached to **`founders, Friends`**. The group is not empty and the
> build is not unassigned; only the contact fields are missing. Pass
> `-f assign_latest_build=true` anyway if you like: it is idempotent.

`submit_for_review` **refuses** if anything is still missing rather than earning you
a rejection, and is a no-op if the build is already through the gate. Apple's Beta
App Review typically takes 24–48 h for a first submission. After that your five
testers get the install.

### What you can check at any time, without changing anything

```sh
gh workflow run testflight-testers.yml -f status_only=true
```

It now prints, per build, `externalBuildState` — Apple's **reviewer** — next to the
`processingState` that is only Apple's **encoder**, plus which groups the build is
attached to. `READY_FOR_BETA_TESTING` is the state that means your friends can
install it. A build can read `VALID` forever and reach nobody.

> **Two external groups exist**: `Friends` (which every release is auto-assigned to)
> and `arkadaslar` (yours, pre-existing). Anyone in `arkadaslar` and not in `Friends`
> receives nothing. Tracked as **issue #146** — a session can list who is where; only
> you can decide whether to re-invite them, since that emails them again.
> **Internal testers (`founders`) are unaffected and never need review.**

---

## 🔴 2(d). Enable **Associated Domains** on the App ID — the next release build cannot sign without it

Apple Developer portal → Certificates, Identifiers & Profiles → **Identifiers** →
`com.beyondkaira.hayati` → tick **Associated Domains** → Save.

**This is now blocking, not optional.** ADR-036 put `applinks:ikimiz.beyondkaira.com`
into `Runner.entitlements`, and the entitlement must exist in the **provisioning
profile** too. `match` fetches profiles **readonly** (ADR-032) precisely so CI can
never mint credentials, so it cannot add the capability itself — the signing step
will fail with an entitlement mismatch. Loudly, not silently, but it will fail.

**Build 110 predates the entitlement and is unaffected**, which is exactly why 2(c)
above ships *that* build rather than cutting a new one. Do this before the next
release run.

> **While you are on that page, one more question to answer (ADR-039).** The prod
> App Check provider is **App Attest**, but `Runner.entitlements` deliberately
> does *not* declare `com.apple.developer.devicecheck.appattest-environment` — so
> prod attestation cannot currently succeed. It is harmless today (App Check
> activation now fails open instead of blocking the boot, and enforcement is off),
> but it will hard-break the day enforcement is switched on. A session did not add
> the entitlement blind: it changes what the provisioning profile must contain,
> `match` runs **readonly** (ADR-032), and a wrong guess turns this into the next
> signing mystery. When you are in the portal for Associated Domains, check
> whether **App Attest** appears in the capability list for
> `com.beyondkaira.hayati` and say what you see — that one observation settles it.

---

## 🔴 2(e0). Make invite links work — **one command, no DNS, no legal blank** (ADR-039)

**Measured at the Session 056 open, and it is the reason invites are not
spreading:**

```
$ curl -sI https://ikimiz.beyondkaira.com/i/9U4VUVRV
curl: (60) SSL: no alternative certificate subject name matches target host name
$ curl -so /dev/null -w '%{http_code}\n' https://ikimiz.web.app/i/9U4VUVRV
404
```

**Every invite link the app has ever shared lands on a browser security
warning.** `ikimiz.beyondkaira.com` still points at your VPS (2(e)(i) below),
whose certificate covers the apex only — so the invitee's first contact with this
product is a red "This Connection Is Not Private" screen, at the exact moment
they are deciding whether to trust what their partner just sent them. Nothing
about the app was wrong; the link had nowhere to land.

Two things changed in code, and one thing is left for you:

* invites are now built on **`ikimiz.web.app`** — Firebase Hosting's own domain
  for the *same site*, with TLS Google issues and renews. It needs **no DNS
  record from anybody**. The custom domain is still parsed, so nothing already
  sent breaks and moving to it later is a one-line change;
* the site builder gained **`--invite-only`**, which publishes the invite page
  and the Apple `app-site-association` file and **no legal documents at all** —
  so the open legal blank in 2(e)(ii) no longer holds your invite links hostage.
  It is not a loophole in that gate: a build that publishes no policy cannot
  publish an unfinished one.

### What you run

```sh
gh secret set FIREBASE_SERVICE_ACCOUNT < service-account.json   # if not set yet
gh workflow run deploy-site.yml -f channel=live -f invite_only=true
```

### How to tell it worked

```sh
curl -so /dev/null -w '%{http_code}\n' https://ikimiz.web.app/i/9U4VUVRV        # want 200
curl -s https://ikimiz.web.app/.well-known/apple-app-site-association           # want the JSON
```

**A session did not run this for you** because it publishes a page on your live
production hosting under your name. The build is proven locally and the command
above is the whole of it.

⚠️ **The link opens the WEB PAGE, not the app, until 2(d) is done.** iOS only
hands a URL to an app whose build carried the Associated Domains entitlement, and
build 110 predates it. Until then the page does its job — it shows the code and
tells the invitee what to do with it — which is still enormously better than a
certificate error.

---

## 2(e). The website — the site now exists and is proven; the live domain needs you

**Session 055 created the Hosting site and deployed the real pages to a preview
channel.** All six legal documents render in three languages, the Apple
app-site-association file serves as `application/json`, and `/i/<code>` rewrites to
the invite page. Nothing about the generator is unproven any more:

> **https://ikimiz--s055-preview-md20kd9a.web.app** — expires 2026-08-04

Two things stand between that and the real domain.

### (i) The DNS record points somewhere else — measured, not assumed

```
ikimiz.beyondkaira.com  ->  161.97.172.146     (your own VPS: HTTP 404,
beyondkaira.com         ->  161.97.172.146      TLS cert covers the apex only)
```

There is an explicit `A` record for `ikimiz` pointing at your server, not a wildcard.
Firebase Hosting needs it pointed at Firebase instead:

Firebase console → `hayatiapp-prod` → **Hosting** → the **`ikimiz`** site (it exists
now) → **Add custom domain** → `ikimiz.beyondkaira.com`. Firebase gives you a `TXT`
record to prove ownership and then the `A` records to replace `161.97.172.146` with.
TLS is issued automatically. **Nothing else on this page depends on it** — TestFlight
and Beta App Review do not need the website.

### (ii) One legal blank is still open, and it is the one only you can fill

You chose (Session 055): **you personally as the data controller, contact
aytek@beyondkaira.com, governed by Turkish law.** Two of those three are ready to
write. The third — the controller's **legal identity as it should appear in a privacy
policy** — needs your actual full legal name, which no session should guess. Send it
and all three land in all six documents in one diff.

Until then the builder **refuses** to publish, which is the point: a policy Apple's
listing points at must not say "to be completed by the founder". **That gate was
itself broken and is now fixed** — it matched two English phrases and was blind to
both Turkish and both Arabic documents, so a Turkish privacy policy saying exactly
that, to your primary market, would have passed as clean.

### (iii) Optional — let CI deploy it

```sh
gh secret set FIREBASE_SERVICE_ACCOUNT < service-account.json   # Firebase Hosting Admin, hayatiapp-prod
gh workflow run deploy-site.yml -f channel=live                 # once the blank above is filled
```

Not required: Session 055 deployed the preview with the Firebase CLI login already on
the dev box. The secret only matters if you want the deploy to run from CI.

---

# 5. SECURITY — rotate the leaked Slack webhook (~10 min, open since S005)

**Verified still open at the Session 051 open** (`gh secret list` returns five
secrets, all release-signing: `ASC_API_KEY_P8_BASE64`, `ASC_ISSUER_ID`,
`ASC_KEY_ID`, `MATCH_GIT_URL`, `MATCH_PASSWORD`): **`SLACK_WEBHOOK_URL` does not
exist.** The local `chore/slack-notifications` branch still exists too, so the
webhook to revoke is still identifiable.

The local branch `chore/slack-notifications` (commit `13f1e6d`) has a **live Slack
webhook URL in plaintext** inside a workflow file. It never reached GitHub (push
protection blocked it), but a credential in a git commit is a leaked credential.

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

Everything below is built and emulator-proven. Your release ritual, from `main`,
on Linux — no Mac, no Xcode, no manual upload:

```sh
git tag v0.1.0 && git push --tags
```

Build numbers are automatic (`100 + the CI run number`); the *version* (`0.1.0`)
comes from `app/pubspec.yaml` and must match the tag, and CI stops you loudly if
they disagree.

⚠️ **Keep your `MATCH_PASSWORD` safe.** It decrypts the certificates repo
(`aytekXR/hayati-match-certs`). Lose it and the stored signing identity is
unreadable — recoverable (a session can re-bootstrap) but annoying, and Apple
caps distribution certificates at 3.

**If your partner is not yet on the TestFlight build:** App Store Connect →
**Users and Access** → invite her Apple ID → add her to the internal group
(internal groups get builds instantly, no Beta App Review).

**The `Friends` external group — see item 2(c) above, which now supersedes what
used to be written here.** This page used to say the Test Information page was
"your copy and your contact details, not a session's". Session 055 measured that
and it was half wrong in the expensive direction: the description and feedback
email were **already filled in**, and the four remaining fields are not copy at
all — they are your name, email and phone. A session can write them, from
secrets. Item 2(c) is the four-line version. Internal testers are unaffected:
they get every build immediately, with no review.

⚠️ **Sequencing that matters for these five people.** Give them a build from
`main` at or after commit `fa990e6` — *not* the build that was in TestFlight
before Session 052. The earlier one carries the default Flutter icon and
`currentLegalVersion = 1`.

Please eyeball each of these on a TestFlight build:

1. **Keychain round-trip** — set a PIN, force-quit, relaunch → must ask for the
   PIN. Then **delete the app, reinstall, launch → it must STILL ask for the PIN**
   (the reinstall-bypass defence; if it opens straight in, that is a real hole —
   tell a session immediately).
2. **Face ID self-revoke** — turn it on, lock, unlock with Face ID. Then change or
   add a face in iOS Settings and reopen Hayati → it must have switched Face ID
   **off** by itself and demand the PIN.
3. **Discreet icon** — flip it in Settings. iOS shows its own "you changed the
   icon" alert (Apple's, expected, unsuppressible). Confirm the icon changes and
   the **name under it does not**.
4. **App-switcher snapshot** — open the coach or a revealed answer, swipe to the
   app switcher → the Hayati card must show a **blank panel**, never your content.
5. **Cold-start stopwatch** — time a cold launch of the **prod** build (airplane
   mode + normal). CI deliberately does not assert the <2s number; your phone is
   where the honest number comes from.
6. **Issue #15** — if phone-auth sign-in crashes natively, capture the log
   (Xcode → Window → Devices → Open Console). That log is the whole blocker on the
   issue.
7. **Issue #48** — a transient Face ID lockout (too many failed attempts)
   currently appears to revoke the biometric accelerator permanently. The issue
   defers to your observation of what actually happens on the device.
8. Also: Apple first-authorization full name reaching `displayName`; deep-link
   cold+warm OS→app delivery; the real-device pairing test.

**Still riding this item:** **App Attest** (App Check enforcement stays OFF in both
consoles until on-device attestation is verified), **APNs** (the notification
logic is done and waiting on the device half — APNs registration + `users.fcmTokens`
capture), **dSYM upload** for Crashlytics, and **Universal links** (needs the
domain decision below; the custom scheme ships today).

---

# Activation infrastructure — still unbought, still gating the funnel

None of these block TestFlight or on-device testing. All of them block a real
launch, and each is a purchase or a decision only you can make.

- [ ] **Domain purchase + AASA hosting** — universal links. The invite is still
      code-first *partly because* links cannot be tappable without this. Also
      supplies the URLs item 8(c) needs.
- [ ] **Analytics wiring decision** — `app/lib/core/analytics/` is empty. **Gate 2
      and Gate 3 are unfalsifiable without it**: activation and monetization
      cannot be measured, so the gates cannot be passed or failed honestly.
- [ ] **APNs key** — the daily ritual has no heartbeat until push works.
- [ ] **The Gate 1 content bank** — the TikTok/content-ops track, dormant by
      ADR-007 unless you re-activate it.
- [ ] **The ADR-027 trademark decision** — worth doing before public launch, not
      blocking anything now.

---

# Before PUBLIC launch (none of these block TestFlight or on-device testing)

## 1. Native review of the app content — **the biggest quality risk in the product**

Every TR/AR string is an AI draft marked review-PENDING. The redesign waves added
more, all flagged "native register review pending" per commit. TR: you two. AR:
your Gulf-dialect reviewer. Mandatory before any public launch
(`content/README.md`, W9). All editable in place, or send corrections to a session.

> **⚠️ One concrete thing to watch for in the ARABIC copy, found by measurement
> this session.** Arabic punctuation and Western punctuation are **not
> interchangeable** in a right-to-left layout. `؟` (the Arabic question mark,
> U+061F) is a *strong* character — it always sits where it should. A Western
> `.` or `?` is *neutral*, and next to Latin text it can jump to the wrong end
> of the line. All seven Arabic solo questions correctly end with `؟`; some of
> the AI-drafted **coach** copy ends Arabic sentences with a Western `.`
> instead. The app now compensates automatically, so nothing is broken — but
> **if you are editing Arabic copy, prefer `؟` and `،` over `?` and `,`**. It is
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
- **Also marked ◆** in the design-system screen cards — bundle those with this pass.

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
  EU-diaspora channel; İYS registration before any promotional push.
- **(f) Optional, would let us say something stronger:** enable
  **zero-data-retention** on your Anthropic organisation and a session will tighten
  the privacy notice to match. Today it says Anthropic does not train on your coach
  messages (true under their commercial terms) but stops short of claiming they
  retain nothing, because their default API retention is limited but not zero.

## 8. Store-listing decisions + the missing web pages (pre-submission, none blocking)

- **(c) Privacy-policy + support-page URLs do not exist** — the store listing ships
  EMPTY URL fields behind a loud CI warning (never a fake URL). Apple requires both
  at submission; the in-app requirement is already met by the in-app documents.
  Needs the **domain choice + hosting** above; the policy TEXT already exists (item
  9). When hosted, a session drops the lint's `--allow-empty-urls` flag.
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

# Engineering issues you may want to know about — but that need nothing from you

Listed only so nothing on this page looks like a silent gap. Sessions drive all of
these.

| Issue | What |
|---|---|
| **#140** | Nothing in CI compares what is merged to what is DEPLOYED. Firestore rules sat un-deployed for 18 days behind six green milestones — the cause of your "Something went wrong". Both projects are current now; the missing gate is not built. |
| **#137** | The bidi seam relies on a library whose character ranges miss one Arabic block; isolation silently no-ops for it. Not reachable in Turkish or Gulf Arabic — filed because it fails quietly. |
| **#136** | Arabic **push-notification** bodies interpolate a partner's name without the isolation the app now applies on screen. Latent: no current wording is affected. |
| **#146** | Two external beta groups exist (`Friends`, which every release is assigned to, and your pre-existing `arkadaslar`). Anyone in `arkadaslar` and not in `Friends` receives nothing, with every check green. A session can list who is where; re-inviting them emails them, so that part is yours. |
| **#130** | ADR-026 claims the seasonal vocabulary is guarded in five readers; the app's copy has no parity test. |
| **#129** | The release lane's `Gemfile.lock` comment is false, the lane installs unfrozen, and no release run has touched the committed lock. |
| **#121** | Confirm a likely-dead App Store Connect key step in the release lane. **Needs your go-ahead only** — proving it means dispatching the lane, which uploads a real binary to your TestFlight. |
| **#41** | `app_user_id` = Firebase uid is a threat-model gap. **Wants deciding before real purchases accumulate** — after that it becomes a migration rather than a clean change. |
| **#13** | Android instant verification — M6.5, waits on your Gate 3 call. |
