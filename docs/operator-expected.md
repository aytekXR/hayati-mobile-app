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
> `.github/workflows/deploy-site.yml` and several ADRs cite them by name, so a
> surviving item keeps its number even when the list around it shrinks. Read
> top-to-bottom for priority.
>
> Re-pruned to open-items-only on **2026-07-31 (Session 057)** — the file had
> re-accumulated ~350 lines of ✅ DONE blocks, superseded corrections and session
> narrative since the last prune at Session 050.

_Last refreshed: 2026-08-01 (Session 057 close). Re-derived from Apple and GitHub at the close, not carried forward._

**Where things stand in one line:** the MVP is code-complete, both backends run
current code and current rules, the invite site is live, and **build 113 is
IN APPLE'S BETA APP REVIEW** — submitted 2026-08-01, `externalBuildState =
WAITING_FOR_BETA_REVIEW`, attached to `Friends`, which now holds **six** testers
including your own Apple ID. **Nothing on the TestFlight path is waiting on you
any more.** The product's one unproven link is still a **real purchase**, behind
item 0(a).

> **✅ The thing that blocked this page for five sessions is done.** The four
> Beta App Review contact fields are written — your name, an email and a phone
> number, held as `release`-environment secrets so no value ever reaches a log
> **or this file**. Apple typically takes **24–48 h** on a first
> submission. When it passes, all six testers get the install notification
> automatically — you do not need to do anything to make that happen.
>
> **What to do while you wait:** item **4** — install build 113 from the
> `founders` internal group (it is already there, no review needed) and work the
> on-device checklist. Those are the checks only your iPhone can settle, and they
> are the best use of the next two days.

## Readiness snapshot — three different questions, three different answers

A single "% done" hides the thing you actually need to know, which is *done for
what*. These are measured, and each one names its own remaining blockers.

| Question | Where it stands | What is left |
|---|---|---|
| **Is the MVP built?** | **100%** — M1→M6.3 including M5.3 all merged (`implementation-plan.md`). App suite 1625 tests / 87.4% coverage (gate 68); Functions 97.2% (gate 80). Both backends run current code and current rules. | Nothing. M6.5 (Android) is a Gate-3-gated follow-on, deliberately not MVP (ADR-006). |
| **Can your six friends install it?** | **~99%** — build 113 is `WAITING_FOR_BETA_REVIEW`, attached to `Friends`, six testers in place, Test Information complete, export compliance answered. | **Apple's 24–48 h, and nothing of yours.** The only branch left is a rejection, and item 2(c) says what to do if that happens. |
| **Could this go on the public App Store?** | **~55%** — and this is the honest number, not the discouraging one. The build is ready; the *business and legal surface around it* is not. | Items **0(a)** (purchases take money and do not unlock Premium — the single most serious open item on this page), **0(b)** (the sandbox purchase has never been run, so the paid loop is unproven end to end), **9** (legal bundle: three blanks, unreviewed, one KVKK filing), **1** and **★** (native TR/AR review — the biggest quality risk, and the crisis lexicon is a safety gate), **8(c)/(d)/(e)** (store URLs, age rating, App Privacy), and **analytics** (Gates 2 and 3 are unfalsifiable without it). |

**The one-sentence version:** the software is finished, the beta is in Apple's
queue, and public launch is gated on money, law and language — none of
which is an engineering problem, and most of which needs you rather than a
session.

---

# ⏳ 2(c). TestFlight external — submitted, in Apple's hands, nothing owed by you

**Done 2026-08-01.** This item blocked the page for five sessions and is closed.
Kept (against the open-items-only rule) because it is the item you have been
waiting on, because `tool/ci/testflight_testers.py` and `deploy-site.yml` cite it
by number, and because the rejection branch below is still live. **Delete at the
next close if Apple has passed it.**

Measured against Apple immediately after submission:

```
build 113  processing=VALID  external=WAITING_FOR_BETA_REVIEW  internal=IN_BETA_TESTING
           groups: founders, Friends
'Friends' now has 6 tester(s)
review contact: set contactEmail, contactFirstName, contactLastName, contactPhone
```

The four contact values live as `release`-environment secrets. The tool prints
field **names** and `set`/`unchanged`/`missing`, never a value — this repo is
public and its logs are permanent, so that is enforced by a sentinel test rather
than promised (ADR-038).

### No, your friends have NOT been emailed yet — and that is correct

**Re-checked 2026-08-01 14:47 UTC: unchanged, and on schedule.** Submitted 12:20
UTC, so ~2.5 h in against Apple's typical 24–48 h. Nothing is stuck; there is
simply nothing to see yet.

Measured 2026-08-01, right after submission:

```
'Friends' (external)
  <five friends>   inviteType='EMAIL'  state='NOT_INVITED'
  <your Apple ID>  inviteType='EMAIL'  state='INSTALLED'
```

**`NOT_INVITED` is the expected state and not a fault.** Apple does not email an
external tester while the group's build is still in review — adding someone to
the group and inviting them are two separate events, and Apple holds the second
one until there is an approved build to invite them *to*. Nothing is stuck.

Your own entry reads `INSTALLED` because you already have the build through the
internal `founders` group.

### What happens without you

Apple's Beta App Review is typically **24–48 h** for a first submission. On
approval the build's state becomes `READY_FOR_BETA_TESTING`, Apple sends the
invitations, and each tester moves `NOT_INVITED` → `INVITED` → `ACCEPTED` →
`INSTALLED`. **All of that is automatic.** Check at any time, changing nothing:

```sh
gh workflow run testflight-testers.yml -f status_only=true
```

Since S057 that command prints **each tester and their state**, so "did it reach
them?" is now answerable without changing anything. Two states to watch:
`READY_FOR_BETA_TESTING` on the build, and `INVITED` or better on the people.

> **⚠️ Your CI logs now mask more than you expect.** The four contact values are
> secrets, so GitHub redacts them *anywhere* they appear — including in unrelated
> output. One friend shares your surname, so her last name prints as `***` too.
> Nothing is wrong; the log is just less readable than it looks.

### If Apple REJECTS it

You will get an email with a reason. Nothing here self-heals, so:

1. Read the reason. Most first-submission rejections are metadata or a missing
   demo account, not code.
2. If it needs a **code** change: a session fixes it, then `gh workflow run
   release.yml --ref main` cuts a new build, which auto-assigns to `Friends`
   (ADR-037 — proven working since build 113).
3. Re-submit the newest build:
   ```sh
   gh workflow run testflight-testers.yml \
     -f dry_run=false -f assign_latest_build=true -f submit_for_review=true
   ```
   `submit_for_review` refuses rather than earning a second rejection if anything
   is incomplete, and is a no-op if the build is already through.

⚠️ **One thing to know about the six testers.** Your own Apple ID is now an
**external** tester as well as an internal one. That is deliberate — it is the
only way to see exactly what your friends see — but it means you will receive the
same build notification twice.

⚠️ **Tester emails travel through a `workflow_dispatch` input, which is
world-readable on a public repo — and older revisions of THIS file listed all
five in plain text.** Neither is new exposure as of today, and both are in git
history now, so this is recorded rather than fixable. It is noted because it
should be a decision rather than a default. **This file no longer prints tester
addresses, and the four contact values never took that path at all** — they are
secrets precisely for this reason (ADR-038 D1). If you want the emails out of
the public record, that is a history rewrite and a founder call.

---

# 🔴 0(a). Grant the prod RevenueCat webhook its public invoker — **issue #115**

**A purchase on production today would take your customer's money and not unlock
Premium.** `revenueCatWebhook` is deployed and `ACTIVE` on `hayatiapp-prod`, but
its Cloud Run service has **no public-invoker permission**, so Google rejects
RevenueCat's calls *before* your code runs. RevenueCat can never report a
subscription, renewal or cancellation. The charge goes through, Premium never
turns on, and **nothing anywhere reports an error**.

Re-probed at the Session 052 close, immediately after a full eleven-function
redeploy: **still returning Google's HTML 403.** A deploy does not grant
public-invoker permission, so the honest reading is that **the binding has never
existed** — nothing is fighting you, and the command below is the only thing that
will create it.

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

## 0(c). Put `RC_WEBHOOK_TOKEN` on **dev** — the only safe place to rehearse 0(a)

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
dashboard.

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

---

# Console and portal items

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
(`brace-expansion`, `uuid`) will appear immediately. Both were measured as
**unreachable** — one hangs off a `rimraf` that `google-gax` declares and never
imports, the other sits under an optional Google Cloud Storage package these
Functions never load. They are recorded in ADR-034, not forgotten.

## 🟡 2(d). Enable **Associated Domains** on the App ID — invite links open the app instead of the browser

Apple Developer portal → Certificates, Identifiers & Profiles → **Identifiers** →
`com.beyondkaira.hayati` → tick **Associated Domains** → Save.

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

**Say what you see either way.** A session cannot read the portal, so nobody knows
whether this capability is already enabled — no build has ever been signed with
the entitlement, so it has never been exercised. If it turns out to be enabled
already, restoring universal links is a two-line change.

> **While you are on that page, one more question to answer (ADR-039).** The prod
> App Check provider is **App Attest**, but `Runner.entitlements` deliberately
> does *not* declare `com.apple.developer.devicecheck.appattest-environment` — so
> prod attestation cannot currently succeed. It is harmless today (App Check
> activation fails open instead of blocking the boot, and enforcement is off),
> but it will hard-break the day enforcement is switched on. A session did not add
> the entitlement blind: it changes what the provisioning profile must contain,
> `match` runs **readonly** (ADR-032), and a wrong guess turns this into the next
> signing mystery. When you are in the portal for Associated Domains, check
> whether **App Attest** appears in the capability list for
> `com.beyondkaira.hayati` and say what you see — that one observation settles it.

---

## 2(e). The website — the invite half is LIVE; the pretty domain and the legal pages need you

The invite surface is deployed and serving on **`https://ikimiz.web.app`** —
`/i/<code>` → 200, AASA → 200 `application/json`. Nothing below blocks invites,
TestFlight, or Beta App Review.

Two things stand between that and the full site on your own domain.

### (i) The DNS record points somewhere else — measured, not assumed

```
ikimiz.beyondkaira.com  ->  161.97.172.146     (your own VPS: HTTP 404,
beyondkaira.com         ->  161.97.172.146      TLS cert covers the apex only)
```

There is an explicit `A` record for `ikimiz` pointing at your server, not a wildcard.
Firebase Hosting needs it pointed at Firebase instead:

Firebase console → `hayatiapp-prod` → **Hosting** → the **`ikimiz`** site → **Add
custom domain** → `ikimiz.beyondkaira.com`. Firebase gives you a `TXT` record to
prove ownership and then the `A` records to replace `161.97.172.146` with. TLS is
issued automatically. **Nothing else on this page depends on it** — TestFlight and
Beta App Review do not need the website.

Until then, invite links are emitted on `ikimiz.web.app` (Google-issued TLS, no DNS
record from anybody). The custom domain is still **parsed** by the app, so nothing
already sent breaks and moving over later is a one-line change.

### (ii) One legal blank is still open, and it is the one only you can fill

You chose (Session 055): **you personally as the data controller, contact
aytek@beyondkaira.com, governed by Turkish law.** Two of those three are ready to
write. The third — the controller's **legal identity as it should appear in a privacy
policy** — needs your actual full legal name, which no session should guess. Send it
and all three land in all six documents in one diff.

Until then the builder **refuses** to publish the legal documents, which is the
point: a policy Apple's listing points at must not say "to be completed by the
founder". The invite-only publish is not a loophole in that gate — it publishes
**no policy at all**, so it cannot publish an unfinished one.

### (iii) Optional — let CI deploy the site

Today the site is deployed with the local `firebase` CLI, which is logged in as
you. `FIREBASE_SERVICE_ACCOUNT` is **unset**, so CI cannot. Worth fixing so the
site is not dependent on one laptop's login:

```sh
gh secret set FIREBASE_SERVICE_ACCOUNT < service-account.json   # Firebase Hosting Admin, hayatiapp-prod
gh workflow run deploy-site.yml -f channel=live -f invite_only=true
```

Drop `invite_only` once (ii) is filled and the full site — six legal documents in
three languages — publishes.

---

# 5. SECURITY — rotate the leaked Slack webhook (~10 min, open since S005)

**Verified still open** (`gh secret list` returns five secrets, all
release-signing: `ASC_API_KEY_P8_BASE64`, `ASC_ISSUER_ID`, `ASC_KEY_ID`,
`MATCH_GIT_URL`, `MATCH_PASSWORD`): **`SLACK_WEBHOOK_URL` does not exist.** The
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

Everything below is built and emulator-proven. Your release ritual, from `main`,
on Linux — no Mac, no Xcode, no manual upload:

```sh
git tag v0.1.0 && git push --tags     # or: gh workflow run release.yml --ref main
```

Build numbers are automatic (`100 + the CI run number`); the *version* (`0.1.0`)
comes from `app/pubspec.yaml` and must match the tag, and CI stops you loudly if
they disagree.

⚠️ **After any release, read the `assign the new build to the Friends group` step's
log, or run `-f status_only=true`. Do not infer delivery from a green release.**
That step is `continue-on-error` on purpose — Apple's processing queue is a third
party's schedule and should not redden a release — but non-blocking must not mean
unread. It failed silently on its first two attempts (S056); it worked for the
first time on build 113.

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
   (Xcode → Window → Devices → Open Console). That log is the whole blocker on the
   issue.
8. **Issue #48** — a transient Face ID lockout (too many failed attempts)
   currently appears to revoke the biometric accelerator permanently. The issue
   defers to your observation of what actually happens on the device.
9. Also: Apple first-authorization full name reaching `displayName`; deep-link
   cold+warm OS→app delivery; the real-device pairing test.

**Still riding this item:** **App Attest** (App Check enforcement stays OFF in both
consoles until on-device attestation is verified), **APNs** (the notification
logic is done and waiting on the device half — APNs registration + `users.fcmTokens`
capture), **dSYM upload** for Crashlytics, and **Universal links** (2(d)).

---

# Activation infrastructure — still unbought, still gating the funnel

None of these block TestFlight or on-device testing. All of them block a real
launch, and each is a purchase or a decision only you can make.

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
  Needs 2(e)(i)+(ii); the policy TEXT already exists (item 9). When hosted, a
  session drops the lint's `--allow-empty-urls` flag.
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
| **#140** | Nothing in CI compares what is merged to what is DEPLOYED. Firestore rules sat un-deployed for 18 days behind six green milestones — the cause of your "Something went wrong". Both projects are current now; the missing gate is not built. Until it exists, treat "it is on `main`" and "it is live" as separate facts. |
| **#137** | The bidi seam relies on a library whose character ranges miss one Arabic block; isolation silently no-ops for it. Not reachable in Turkish or Gulf Arabic — filed because it fails quietly. |
| **#136** | Arabic **push-notification** bodies interpolate a partner's name without the isolation the app now applies on screen. Latent: no current wording is affected. |
| **#130** | ADR-026 claims the seasonal vocabulary is guarded in five readers; the app's copy has no parity test. |
| **#129** | The release lane's `Gemfile.lock` comment is false, the lane installs unfrozen, and no release run has touched the committed lock. |
| **#121** | Confirm a likely-dead App Store Connect key step in the release lane. **Needs your go-ahead only** — proving it means dispatching the lane, which uploads a real binary to your TestFlight. |
| **#41** | `app_user_id` = Firebase uid is a threat-model gap. **Wants deciding before real purchases accumulate** — after that it becomes a migration rather than a clean change. |
| **#13** | Android instant verification — M6.5, waits on your Gate 3 call. |
