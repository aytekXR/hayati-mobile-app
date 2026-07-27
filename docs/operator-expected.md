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

_Last refreshed: 2026-07-27, **Session 052 close**._

**Where things stand in one line:** the MVP is code-complete, both backends now
run **current** code and **current Firestore rules**, and a TestFlight build
from `main` carries the real app icon; the product's one unproven link is a
**real purchase**, and the only thing standing in front of it that a session
cannot do is item 0(a) below.

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

**The `Friends` external group (Session 052) — one step is still yours.** The
group exists and its testers are added, via the new manual-dispatch lane
`gh workflow run testflight-testers.yml` (see `tool/ci/testflight_testers.py`;
it is idempotent, so re-running it never re-emails anyone). But **external
testers receive nothing until a build is assigned to their group and that build
clears Apple's Beta App Review** — and Beta App Review needs the **Test
Information** page filled in (beta app description, feedback email, contact
details), which is your copy and your contact details, not a session's. Internal
testers are unaffected: they get every build immediately.

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
| **#131** | Seven high-severity npm advisories in `functions/`, two in the tree that ships to production. |
| **#130** | ADR-026 claims the seasonal vocabulary is guarded in five readers; the app's copy has no parity test. |
| **#129** | The release lane's `Gemfile.lock` comment is false, the lane installs unfrozen, and no release run has touched the committed lock. |
| **#121** | Confirm a likely-dead App Store Connect key step in the release lane. **Needs your go-ahead only** — proving it means dispatching the lane, which uploads a real binary to your TestFlight. |
| **#41** | `app_user_id` = Firebase uid is a threat-model gap. **Wants deciding before real purchases accumulate** — after that it becomes a migration rather than a clean change. |
| **#13** | Android instant verification — M6.5, waits on your Gate 3 call. |
