# Operator Checkpoint

**Last Updated:** 2026-09-13 UTC (Session 102)

> This file is a **live checkpoint, not a history.** It carries only what is
> **open right now**. Closed items are deleted, not archived — what each session
> did, and why, lives in `docs/past-prompts.md` and in the ADRs.
>
> ⚠️ **Item numbers are stable.** ADRs, `resume-prompt.md` and issues cite them by
> number ("operator item 6(b)"). A surviving item keeps its number even when the
> list around it shrinks.

## Current Status

| | |
|---|---|
| Completion | **~58%** of the iOS MVP, to public launch |
| Production Readiness | **Integration Ready** |
| Production | 🟢 **UP.** Billing restored 2026-09-03 ~22:05 UTC after 12 days down; the **23:00 UTC sweep completed** (`assigned=1, failed=0`) and `prod_pulse` exits **0** — item 1 |
| Open operator items | **1, 2 and 10 DONE**; **9 is the urgent one** — billing is live and nothing watches the bill; 3–8 stand; **11 is new** — a brand decision, and the first thing here that costs you nothing but a choice |

**Completion — ~58%.** Engineering (M0–M6.3) is **~95%** — the code builds, signs
and passes its gates. ⚠️ *"Every milestone closed" is not true and was written
here: **M5.3 has no ✅** in `implementation-plan.md`.* The question bank is **2.1%** — 21 of
1000 questions (measured today: 7 each in `solo_ar`, `solo_en`, `solo_tr`).
Weighting engineering at 60% and content at 40%: `(0.60 × 95) + (0.40 × 2.1) ≈ 58`.
**The engineering is nearly done; content and the items below are the gap.**

**Integration Ready**, not Beta Ready: no push has ever reached any phone, the
listing is unpublished, and nothing is watching production. *(The webhook's
**HTTP 403** stood here until 2026-09-03; it now answers its own JSON — item 2.)* *Beta Ready* would mean real people
using real features on real devices, and that has never happened.

**To reach Beta Ready:** ~~billing restored and verified~~ ✅ · one push delivered
to a real phone · a current build on devices (**a build is in flight** — item 4) ·
the drift checks measuring instead of skipping.

---

## Open Operator Actions

Ordered by how much each unblocks. Every line below was verified on 2026-09-03.

### 1. ✅ CLOSED — billing restored and the sweep proven

**Done 2026-09-03 ~22:05 UTC.** Account `01D7C5-DBC2D5-E53938` (the one already
linked to `hayatiapp-prod`) was **activated** — the payment instrument is on
someone else's identity, which is why our token could not see it open earlier.
Both conditions now hold, which is the pair ADR-066 exists to keep apart:

```
projects/hayatiapp-prod/billingInfo   billingEnabled : true    (LINKED)
billingAccounts/01D7C5-DBC2D5-E53938  open           : true    (PAYING)
```

**What came back with it**, measured rather than assumed:

| | before | now |
|---|---|---|
| Cloud Scheduler API | HTTP 403 — the API was off with billing | **readable**; job **ENABLED** |
| `revenueCatWebhook` | HTML 500 *"billing is disabled"* | **the function's own JSON** — see item 2 |

⚠️ **Not finished yet, and the remaining line is honest:** no
`question_rollover: sweep complete` record exists, because the **22:00 UTC sweep
attempted and failed** (gRPC 13) — billing was restored a few minutes *after* it
ran. `prod_pulse` still exits **1**, correctly: it is keyed on the sweep's own
record, so a punctual scheduler over a backend that was dead at the time reads
red (ADR-063).

**The scheduler's own record, read today**, so the next reader knows exactly what
to look for rather than re-deriving it:

```
state           : ENABLED
schedule        : 0 * * * *   (Etc/UTC — hourly, on the hour)
lastAttemptTime : 2026-09-03T22:00:00Z
status.code     : 13          <-- that attempt FAILED; billing was still off
scheduleTime    : 2026-09-03T23:00:00Z   <-- the next attempt
```

**The next hourly sweep was the proof, and it passed.** The **23:00 UTC** run
completed — `question_rollover: sweep complete`, `assigned=1, failed=0,
seasonalCalendarUnavailable=False` — and `prod_pulse` now exits **0**. The daily
loop is genuinely running. **Nothing further is needed from you on this item.**

⚠️ **`status.code` has no `message` field.** Reading it with a `.get("message",
"…succeeded")`-shaped default prints a confident success line while the code says
13 — which happened today. Read `status.code`, not a message that is not there.

⚠️ **`hayatiapp-dev` stays unbilled** (your decision). It is still linked to the
old closed `012195-7EF76F-3A9083` and reports `billingEnabled: false`. The cost is
that dev Functions cannot be deployed or exercised, so `session-context.md`'s
*"dev is a session's to exercise"* does not hold while this stands. CI is
unaffected — the emulator suites run against `demo-hayati`.

⚠️ **Item 9 is now the urgent one.** Billing is live and **nothing is watching the
bill.**

### 2. ✅ The webhook works — only RevenueCat's own dashboard is unverified

Three things were needed and all three are now **proven by the function's own
response**, not inferred:

```
$ curl -X POST https://revenuecatwebhook-mzym2uw5gq-ew.a.run.app -d '{}'
HTTP 401  {"error":"unauthorized"}
```

That single line settles all of it, because of how the handler is ordered
(`revenuecat-webhook.ts`): the **503 `unconfigured`** branch is checked
**before** the token compare, *"so a misconfiguration can never be mistaken for
an unauthorized caller"*. Getting **401 and not 503**, with no header sent, means:

| | proof |
|---|---|
| the container runs | a JSON body came back, not Google's HTML error page — **billing works** |
| the request reaches it | not a Cloud Run 403 — **the invoker grant works** (granted 2026-09-03, `allUsers` → `roles/run.invoker`) |
| `RC_WEBHOOK_TOKEN` is set and non-empty | the 503 branch was **not** taken — **the secret is bound and populated** (**version 2**, revision `revenuecatwebhook-00007-tof`, redeployed 2026-09-03; the invoker grant survived the redeploy and `functions_drift` exits **0**) |

This is `session-context.md` §8's own test — *"JSON = fixed, HTML 403 = broken"* —
answering **fixed**.

#### 2.1 — The one thing left: does RevenueCat send the same string?

RevenueCat sends whatever is in its dashboard **verbatim** in the `Authorization`
header — no `Bearer`, no HMAC (ADR-013 D1). Nothing here can read RevenueCat's
console, so this is yours:

> **Read the value:** Secret Manager → `RC_WEBHOOK_TOKEN` → **version 2** (the
> live one — version 1 is superseded) → *View secret value*. (Or, after
> `gcloud auth login`: `gcloud secrets versions access 2 --secret=RC_WEBHOOK_TOKEN --project=hayatiapp-prod`.)
>
> **RevenueCat** → your project → **Integrations → Webhooks**:
> URL `https://revenuecatwebhook-mzym2uw5gq-ew.a.run.app`,
> **Authorization** = that exact string, no prefix.
>
> **Then press RevenueCat's "Send test event".** A 200 there is end-to-end proof.
> A 401 means the two strings differ.

**Where RevenueCat's three credentials go**, since they are easy to confuse and
only two exist here:

| credential | shape | where it lives |
|---|---|---|
| iOS **publishable** SDK key | `appl_…` | repo **variable** `REVENUECAT_IOS_API_KEY` — ships in the binary, public by design. **Already set** |
| webhook **shared token** | a string you choose | Secret Manager `RC_WEBHOOK_TOKEN` **and** the RC dashboard. **Google side done** |
| **v2 secret API key** | `sk_…` | ⚠️ **nothing in this repository reads one.** ADR-013's mirror is webhook-driven and never calls RevenueCat's REST API; #41 lists RC-REST reconciliation as future work |

⚠️ **No credential is ever committed** (`architecture.md` §9). Secrets reach CI via
`gh secret set` and the Function via Secret Manager — never a file in the tree, and
never a `workflow_dispatch` input, because this repository is **public**. **A key
pasted into a chat, an issue or a PR is a burned key — rotate it.**

### 3. Four secrets — without them, nothing is watching production

**None of these four exists.** Verified today: `gh secret list` returns five
secrets and not one of them is on this list.

| secret | what it turns on |
|---|---|
| `PROD_PULSE_VIEWER_SA` | the production watcher. **Until it exists nothing notices if the daily loop dies** — which is how the current outage ran for days |
| `FIREBASE_RULES_VIEWER_SA` | the two drift checks — whether what is deployed still matches the code |
| `FIREBASE_SERVICE_ACCOUNT` | the three deploy lanes (rules, functions, site) |
| `SLACK_WEBHOOK_URL` | build notifications. The store-listing warning built for #204 reaches you through this and nothing else |

Setup steps: `docs/adr/064-*.md` (watcher), `docs/adr/041-*.md` (drift). All but
the deploy one are **read-only** service accounts.

### 4. Install build 121 and open the app to the paired home screen

**Where this stands, in one line: 120 is installed and told us why it failed;
121 is on TestFlight carrying the fix and has not been installed.**

| build | cut | on your phone? | what it gave us |
|---|---|---|---|
| 119 | 2026-08-09 | superseded | — |
| 120 | 2026-09-04, run #20 | ✅ installed, permission **granted** | the first diagnostic this system has ever produced — §4.1 |
| **121** | **2026-09-06, run #21** | ❌ **not yet** | the fix, and the callback that makes a refusal speak — §4.2 |

> **Install 121 from TestFlight → open the app to the paired home screen.** You
> will **not** be asked for permission again: iOS shows that dialog once per
> install and you already granted it, which is exactly why 121 had to do its
> asking on the app's own side instead.

⚠️ **This is still the one thing on this page that only a phone can answer.** The
whole server half is proven (§4.1) and every link that can be measured from CI
has been (§4.2). What has never happened is a device reporting an address.

✅ **Item 1's precondition was met before 120 went out**, which is why the
permission prompt was not wasted: before billing was restored the registration
call would have been refused, and iOS shows that dialog **once per install**.

### 4.1 — You did it, it failed, and the failure was USEFUL (2026-09-06)

You installed 120, allowed notifications, answered, and your partner answered
ninety seconds later. **The server did everything right and no phone made a
sound.** Production logs, your own timestamps:

```
13:26:10Z (16:26 TSİ)  you answered    -> one-answer -> push to partner -> no-tokens
13:27:56Z (16:28 TSİ)  partner answered -> revealed, streak applied
                                        -> push to you -> no-tokens
```

The trigger fired, found the right partner, applied the streak. **The only broken
link is the address**: `registerPushToken` has *never been called by anyone*, and
`0 of 4` accounts have a device registered.

**Your phone's own report says why, and it is the first one this system has ever
produced** (the diagnostic shipped in build 120):

```
awaitingDeviceToken / captureExhausted — 2026-09-06T13:24:56Z
```

Your tap **worked** — permission is held. What failed is the step after it: iOS
never handed the app an APNs address.

**Four suspects were eliminated by measurement, not by reasoning:** the App ID
capability is ticked (re-read today), `aps-environment` is declared *and proven*
by build 120 having codesigned at all, FCM auto-init is on, and the manual
handoff ADR-046 D6 added is in place.

⚠️ **The fifth could not be eliminated, because nobody was listening.** iOS
reports an APNs refusal on a callback this app never implemented — the only
handler in the process was the Firebase plugin's, which writes it to a device log
that reaches nobody. So *"APNs said no"* and *"APNs said nothing"* — two failures
with **opposite** remedies — were arriving as the same silence. **That is fixed
and rides the next build** (ADR-074).

**And the obvious suspect turned out to be innocent** (ADR-075). An entitlement
has to survive three places — the binary, the App ID, and the **provisioning
profile** — and iOS checks the third, which nothing here had ever been able to
read. It can be read now, and it is fine:

```
match AppStore com.beyondkaira.hayati  [ACTIVE]  created 2026-08-07
  ✅ aps-environment = 'production'
```

That matters because the next step would otherwise have been asking **you** to
run a `MATCH_BOOTSTRAP` release — a one-shot that changes how your binary signs.
It would have cost a bootstrap, a regenerated profile, a release, and the same
silence at the end. **All three links are now proven intact.**

#### 4.2 — Where the hunt landed, and the one thing left

Your phone tried **twice**, 78 minutes apart (13:24:56 and 14:42:56), and got no
address both times. That rules out bad luck: a timing race does not survive an
hour and a fresh app launch.

Everything that could be checked without your phone has been:

| link | verdict |
|---|---|
| the server sends | ✅ proven — both pushes were built and addressed correctly |
| the binary claims the entitlement | ✅ `Runner.entitlements`, in git |
| the App ID permits it | ✅ measured, run 34038316432 |
| **the signing profile grants it** | ✅ measured, run 34040358971 — `ACTIVE`, `aps-environment = production` |
| the device has an address | ❌ **no**, twice |

**And then the last link turned out to have a hole in it.** *Who actually asks
APNs for an address?* Nobody in this app — the request came entirely from the
Firebase plugin, which issues it during launch **only if Firebase is already
configured at that instant**. This app configures Firebase from Dart code (there
is no `GoogleService-Info.plist`), so whether that condition is true at that
moment is an ordering nobody here chose or can see. If it is false, **nothing
ever asks**, and the phone waits forever for an answer to a question that was
never put.

**That is now fixed** (ADR-076): the app asks iOS itself, every time it notices
it has no address. Apple documents the call as safe to repeat, so it costs
nothing if the plugin was already doing it — and it is the whole feature if it
was not.

> ✅ **Build 121 is on TestFlight** — release run **#21**, 2026-09-06 16:16:47
> UTC, `assigned build 121 to 'Friends'` (7 testers), read from the job log. It
> carries **both** halves: the fix above, and the callback that makes iOS *state
> its reason* if it refuses (ADR-074) instead of failing silently.
>
> **Install 121 and open the app to the paired home screen.** You will not be
> asked for permission again — iOS shows that dialog once per install and you
> already granted it, which is exactly why this build had to do the asking on
> its own side instead.
>
> Then tell me, and I re-read the report. **Three outcomes, all of them
> progress:**
>
> | what the report says | what it means |
> |---|---|
> | a token is registered | **it worked** — I send a real test notification to prove the last link |
> | `apnsRegistrationRefused` | iOS refused and **named the reason**; the sentence is in the device log, and the fault is finally addressable |
> | `captureExhausted` still | ⚠️ **read §4.4 before believing this row.** It used to mean *"the request went out and APNs stayed silent, so the fault is the network path, not this app"* — and in **121** that is no longer safe to conclude, because one path in 121 could have skipped the request entirely |

⚠️ Honest bound: the fix is a **candidate**, not a diagnosis. It removes a real
dependency on vendor ordering and is the best-supported explanation left
standing — but until 121 is installed, nothing here has touched a phone. As of
this writing the last device report is still **2026-09-06T14:42:56Z**, which
predates 121: it has not been installed yet.

#### 4.3 — A near-miss worth knowing about (issue #293)

Before handing you a build, one thing was checked that could have made the whole
exercise pointless: **can your phone actually WRITE the new diagnostic?**

The new report value rides a security rule with a closed list of allowed values.
If production were running the old list, your phone would try to report
`apnsRegistrationRefused`, Firestore would reject it, the app would swallow the
rejection by design — and **build 121's whole diagnostic half would have been
silently dead on the one build cut to carry it.**

Measured instead of assumed: the live production ruleset contains **no mention of
this field at all** — it is 62 lines behind the code and never received that gate.
So the write is unconstrained and **the report will record.** ✅

**It works because of a gap, not because of a guarantee**, and that is filed as
**#293**: the rule that is supposed to validate this field is doing nothing in
production, in either direction. Deploying the current ruleset is a prod deploy
and therefore yours to authorise — it is **not** needed for the notification test
and should not be mixed into it.

#### 4.4 — ⚠️ 121 carries a HOLE in the fix, found after it shipped (ADR-077)

Said plainly, because a version number should not have to be decoded.

**Build 121 does not carry everything.** Reviewing ADR-076's change *after* it
went out turned up a gap in it: the code asks iOS for an address when it reads
back *"no address"*, and falls through correctly — **but when that read throws
an error instead of answering, the old code gave up and asked nobody.** The
branch whose own comment says *"not 'no' — cannot tell"* was the only branch that
never asked, and *cannot tell* is exactly the state this app's Firebase setup is
most likely to produce.

**What that changes for you: almost nothing, and here is the honest version.**

| | |
|---|---|
| **Still install 121?** | **Yes.** The hole only bites if that read *throws*. A plain *"no address"* — the case your phone has shown twice — reaches the request in 121 just fine |
| **If 121 registers a token** | It worked. Nothing below matters and I send you a real test notification |
| **If 121 still says `captureExhausted`** | That reading is **no longer clean**: one path could have skipped the ask. **Build 122 is what makes it unambiguous** |
| **Do you need to do anything now?** | **No.** No build is being cut and none is being asked for |

**Cost of finding it now rather than later: a build.** Cost of finding it after
you had installed 122 on the strength of a clean-looking 121: a round trip
through your phone, and a conclusion drawn from a measurement that had a hole in
it.

### 5. The legal bundle — one decision, three drafted parts, six questions

`docs/legal/proposed/` holds the version-3 draft of all three privacy policies. It
is **not in force**: `CURRENT_LEGAL_VERSION` is still **2** and nobody has been
re-prompted.

| | the gap it closes | issue |
|---|---|---|
| **#226** | the notice denies push, and never names the device address or the phone's own status report | **OPEN** |
| **#249** | the record of your consent — version, when, age confirmation — is stored, handed over on request, and named nowhere | **closed** — the clause is in the draft |
| **#258** | what account deletion actually removes was under-described | **closed** — the clause is in the draft |

⚠️ **Two of those three issues are closed and the third is not.** Closing them
recorded that the *wording exists*; it did not put it in force. The decision below
is what puts it in force, and it is unaffected by the issue tracker.

**What is needed from you:** read the draft, put it in front of your lawyer with
the **six** questions in `docs/legal/README.md`, and say go — or say what to change.

⚠️ **Landing it bumps the legal version and re-prompts every existing user**,
which is why sessions draft it and stop. ⚠️ **It has been corrected four times
without landing.** Past some point the thing to question is the landing, not the
corrections.

### 6. The store listing — two decisions and one authorization

**Your App Store listing is empty.** Not out of date — *empty*. App Store Connect
holds nothing for the English description, keywords, subtitle, promotional text,
release notes, privacy URL or support URL. The only field ever set is the app's
**name**, and that one is correct.

```
audited App Store version: 1.0 state=PREPARE_FOR_SUBMISSION
  - en-US: description differs — PUBLISHED IS EMPTY — published 0 vs committed 1454 code points
  ... all seven the same ...
  - tr: NOT PUBLISHED
```

Two consequences: **publishing our copy cannot overwrite anything of yours** —
there is nothing there — and **a listing with no description, subtitle, keywords
or support URL cannot be submitted to Apple.**

(a), (b) and (c) below are **independent**: you can answer (b) and (c) without
settling (a).

#### 6(a) — The Turkish name. Apple refuses `ikimiz` for `tr`

The `tr` listing has failed to publish on **every release since build 112**.
Apple's refusal is *"the app name is already being used by another app"* — display
names are unique per locale and someone else holds this one for Turkish. **A
product decision, not a click** (#204). Three options, none a session should pick:

1. a distinct Turkish display name in `fastlane/metadata/tr/name.txt`;
2. drop the `tr` localization and keep one global name (then `tr` screenshots are
   moot and this closes as won't-do);
3. pursue the trademark claim Apple's message points at — slow, and yours alone.

#### 6(b) — May our English copy be published at all?

ADR-020 D8 put *all* store copy behind a review gate: every string in
`fastlane/metadata/en-US/` is **AI-drafted and has never been read by a human who
owns the product**. `fastlane/README.md` still says *"Native review: PENDING"*.

**This is the only item on the page that needs no money, no hardware and nobody
else.** You can see exactly what would happen first — the dry run **writes
nothing**:

```
Actions → publish-store-metadata → Run workflow → leave "confirm" BLANK
```

Its last real output:

```
en-US: PATCH appInfoLocalizations          — 3 field(s), 2 would change
en-US: PATCH appStoreVersionLocalizations  — 5 field(s), 5 would change
tr:    POST  appInfoLocalizations          — 3 field(s), 3 would change
tr:    POST  appStoreVersionLocalizations  — 5 field(s), 5 would change
15 field(s) would change — the listing does not yet carry what this ref committed.
```

**Eight fields per language; Turkish is created from scratch** (`POST`), English
already exists and is simply empty (`PATCH`). `marketing_url` is deliberately
absent — it is empty in the repo and this tool never writes a blank over anything.

⚠️ **The Turkish half will still fail** — Apple refuses the name, 6(a). The point
is that **it now fails alone**: English publishes regardless.

> **Say yes** → a session types `PUBLISH` into that same box and your store page
> stops being blank.
> **Say "let me read it first"** → nothing happens until you have.
> **Say no** → #278 is closed rather than left looking open.

#### 6(c) — May a session dispatch the release lane once?

`session-context.md` §7 says a session must never dispatch the release lane
**without asking**. This is the asking.

It is **not** on the critical path: publishing store copy no longer needs a
release. What 6(c) buys is settling **#121** — a step in the release lane
suspected dead for months. Half is now proven from fastlane's own source
(fastlane never touches that file); what is left is whether Apple's `xcodebuild`
reads it, which no source we have can answer.

The experiment is a **redirect, not a deletion**: move the file where nothing can
find it and run the lane. **Identical run = the step is dead and goes; a failure
names the missing key at that exact path**, which is diagnosable rather than
cryptic.

⚠️ **The reason this was declined before has reversed.** It was put off because *a
build was the single thing blocking push testing*. It is not any more — production
is down, and item 4 says to cut a build **after** billing. **A failed release costs
you less today than when this was last considered.**

> **The decision:** yes, once, for this purpose — or no, and it waits for your next
> real release. A dispatch uploads a real binary to your TestFlight; that is the
> cost, and about 30 free macOS minutes otherwise.

#### 6(d) — ⚠️ The two URLs Apple requires point at a domain that serves NOTHING (#296)

**New at S102, and found by accident.** Independent of the copy being empty:
`fastlane/metadata/{en-US,tr}/support_url.txt` and `privacy_url.txt` both point
at **`https://ikimiz.beyondkaira.com/`**, and Apple requires both to be
reachable. **Measured 2026-09-13:**

| | |
|---|---|
| `https://ikimiz.beyondkaira.com/` | **the certificate does not match the name, so the connection is refused before any HTTP** — *"no alternative certificate subject name matches target host name"*. (Said precisely: the TLS handshake reaches CERT verify and **verification** fails. The effect is the same — there is no response — but the cause is a certificate, not a broken TLS stack) |
| `http://ikimiz.beyondkaira.com/` | **404** |
| the VPS certificate | `CN = ams.beyondkaira.com`, SANs: `ams, bedirhandemirel, beyondkaira.com, brier, matbu, pulse, test, www, yanki` — **no `ikimiz`** |

DNS points `ikimiz.beyondkaira.com` at the VPS (`161.97.172.146`), so the name
resolves to a box with neither a certificate covering it nor a vhost for it.
HSTS on the apex means there is no degraded HTTP mode either — a browser will
not offer a click-through.

⚠️ **The certificate has been reissued since this was first reported** and
`ikimiz` still was not added — PR #172 listed eight SANs on 2026-08-02 and there
are nine today (`test.` was added). So it is not that nobody has touched the box.

**The good news, measured at the same time:** the AASA *is* served and correct —
`https://ikimiz.web.app/.well-known/apple-app-site-association` → **200,
`application/json`**, which is ADR-040's claim holding up. What exists nowhere is
`/privacy`: `ikimiz.web.app/privacy` is a **404**.

**The decision that is yours, and it is one sentence: VPS or Firebase Hosting?**

* **VPS** — PR **#172** implements it, on your own directive, with the nginx
  config derived from `firebase.json` directive by directive so `cleanUrls`, the
  `/i/**` invite rewrite and the AASA content type all survive. DNS already
  points there. It needs the certificate reissued *with* `ikimiz` and the vhost
  installed — on the box, which no session can reach.
* **Firebase Hosting** — what `deploy-site.yml` assumes. It needs a Hosting site
  named `ikimiz` in `hayatiapp-prod` with the custom domain connected, and a DNS
  change away from the VPS.

**Both cannot be right**, and whichever wins holds the certificate and serves
every invite link ever shared.

⚠️ **Note the ordering: this does not shortcut item 5.** `deploy-site.yml`
renders `/privacy` from `docs/legal/` and **refuses by default** while those
texts still say *"[FOUNDER LEGAL ENTITY — to be completed by the founder]"* —
correctly, because a policy Apple points at must not say that. So the real
sequence is **item 5 → a host decision → publish**. This item exists because
even with the text finished, the URL currently goes nowhere, and that was not
recorded anywhere.

### 7. Content — the largest single gap in the product

**21 of 1000 questions exist** — measured today: 7 each in `solo_ar.json`,
`solo_en.json`, `solo_tr.json`, solo only. The couple questions are currently the
Turkish solo pack, a known placeholder. Target: 400/300/300.

### 8. Before public launch, but not before beta

- **Your legal name as data controller** — three bracketed blanks stay blank until you supply it.
- **Native TR/AR review** of every user-visible string. *(In-app strings in the two languages that need a native speaker. **Not** 6(b), which is store copy in English and a different gate — conflating them is how 6(b) went unrecorded for weeks.)*
- **★ Crisis-content safety review** — the gate before the coach runs on a real device.
- **Sandbox purchase test**, once Apple's pricing propagation clears.
- **Enable Dependabot alerts** (~1 min); optionally make `gemfile-lock-verify` a required check.

### 9. ⚠️ A budget alert — now the most urgent thing on this page

Item 3's watcher catches the *symptom* days late; a budget alert catches the
*cause*. **Had one existed, the outage just closed would have been hours rather
than 12 days.** Billing has been live since **2026-09-03** and **nothing is watching
the bill.**

⚠️ **The URL this item carried was the CLOSED account** (`012195-7EF76F-3A9083`)
and would have sent you to the wrong place. The live one:

> <https://console.cloud.google.com/billing/01D7C5-DBC2D5-E53938/budgets>
> → **CREATE BUDGET**

| field | what to choose |
|---|---|
| **Scope** | Projects → **`hayatiapp-prod`** only. The account now carries someone else's spending too; scoping to the project keeps their costs out of your alerts |
| **Amount** | a small **monthly** figure. With no live users real spend should be ≈ zero, so this is an **early warning**, not a cap — set it low enough to fire before a runaway costs anything |
| **Thresholds** | 50% / 90% / 100%, on **Actual** spend (not *Forecasted* — you want what happened, not a prediction) |
| **Email** | ⚠️ see below |

⚠️ **Check the email recipients explicitly.** Budget alerts default to the billing
account's admins, and **the account is on someone else's identity now** — so the
warning could land with them and not you. Verified today that your identity does
hold `billing.accounts.update` and `billing.budgets.create` on it, so you should
be among the defaults; confirm it on the creation screen anyway. **An alert sent
to an address you do not read is not an alert.**

⚠️ **A session cannot do this one for you**, and the reason is worth recording so
nobody retries it: the Cloud Billing Budget API answers `SERVICE_DISABLED` for the
firebase CLI's own consumer project (`563584335869` — Google's, not yours), so the
API path is closed from here even though the permission is present. **The console
enables it for you in the same flow.**

### 10. ✅ DONE — the dev box is signed in (kept for the trap it left behind)

The machine was rebuilt around **2026-08-31**. A session restored everything it
could by itself — Flutter, Java, the Dart SDK and `firebase-tools` are all back and
app-side checks run locally again. **What is left is the one step that is yours**,
because it is an interactive sign-in with your Google identity:

✅ **Done on 2026-09-03.** `prod_pulse.py --from-firebase-cli` now returns a real
verdict instead of *"could not measure"*, and that is how item 1's state above was
established.

**This item stays on the page only for its trap**, which cost a measurement
earlier the same day and will recur on the next rebuild:

⚠️ **Do not check this by looking for the file.**
`~/.config/configstore/firebase-tools.json` **exists today and is still not a
login** — installing `firebase-tools` creates it empty. The only honest check is
to run a probe:

```sh
python3 tool/ci/prod_pulse.py --from-firebase-cli   # 2 = still not logged in
```

`~/.config/configstore/firebase-tools.json` **existed while still not being a
login** — installing `firebase-tools` creates it empty, and only the `tokens` key
appearing makes it real. The only honest check is to run a probe and read its exit
code. **Delete this item once it has survived one rebuild without anyone falling
for it.**

### 11. A brand decision nobody has ever put to you — Phosphor or Material (#63)

**This is the only item on this page that needs no money, no hardware, no lawyer
and nobody but you.** It has also been named as *"the next session's objective"*
three times and never actually written down for you, which is why it is a
numbered item now instead of a promise.

**The situation.** `brandkit` §5 specifies **Phosphor** icons. The app ships
**Material** ones. `ADR-025` has recorded that honestly as a known divergence
since the design arc, and the shipped rule it states — *one consistent icon
family at a consistent weight* — is satisfied. Nothing is broken. **What has
never happened is anyone asking you which family is the real one.**

**Measured today, so the numbers are not inherited** (the commands are beside
them because earlier write-ups of this said "28 icons" and that is not the count
at this ref):

| | |
|---|---|
| `Icons.*` call sites in `app/lib` | **34** — `grep -rno "Icons\.[a-zA-Z_]*" app/lib \| wc -l` |
| distinct icons used | **23** — the same, `sort -u` |
| files touched | **15** |
| `phosphor` in `app/pubspec.yaml` | **absent** |
| committed goldens (the re-baseline ceiling) | **360** — `git ls-files 'app/test/**/*.png' \| wc -l` |

### Two ways out. Both are defensible and **neither is recommended here**

**(a) Migrate the app to Phosphor.** The brandkit becomes true.

* one new dependency and a second icon font in the bundle;
* **23 distinct icons across 34 call sites in 15 files**;
* a golden re-baseline — **360 committed PNGs is the ceiling**, and any golden
  rendering an icon moves;
* **the RTL mirroring, which is smaller than it has been described.** The usual
  argument is that Material icons auto-mirror in Arabic and Phosphor glyphs do
  not, so the whole mirror net needs rework. Measured against Flutter's own
  `icons.dart`: of the 23 icons this app uses, **2 auto-mirror** —
  `chevron_right` and `backspace_outlined` — at **4 call sites** between them.
  *(Control: 303 icons in that file do declare mirroring, and `arrow_back` is
  one, so the measurement can tell the difference.)*

**(b) Amend the brandkit** to record Material outline as the shipped icon system.

* a documentation change, the way §10 already records the contrast exception;
* the app does not move, no goldens move, no dependency is added;
* the cost is that the brandkit stops specifying and starts describing — on this
  one line.

⚠️ **Do not read the cost asymmetry as a recommendation.** (b) is cheaper and
(a) is a day's work, and that is *not* the question. The question is which icon
family is **ikimiz**, and that is yours the way the name and the palette are
yours. A session picking (b) because it is cheaper is how a founder's decision
becomes a session's by attrition — which is precisely what has been happening to
this one for three sessions.

**What I need from you: one word — *Phosphor* or *Material*.** Either way #63
closes, a session does the work or writes the amendment, and the design record
stops carrying an open question as a footnote.

---

## Current Blockers

🟢 **Production is UP** (item 1, restored 2026-09-03) — the line here said *"down"*
for ten days after it came back. What is down is nothing; what is **unwatched**
is everything, which is item 9.

These block **public launch**:

1. ~~Nothing runs on the server~~ — ✅ **closed.** Billing restored 2026-09-03 and the 23:00 UTC sweep completed (`assigned=1, failed=0`); `prod_pulse` exits **0** (item 1).
2. **Payments** — Google's side is done and proven; what remains is matching the token in RevenueCat's dashboard (item 2.1).
3. **Push has never been delivered** — item 4; 0 of 4 devices registered. **Build 121 is on TestFlight and uninstalled**, and §4.4 says what it does and does not carry.
4. **The App Store listing is not submittable** — seven of nine English fields empty at Apple, Turkish absent (items 6(a), 6(b)) — **and the support and privacy URLs it carries serve nothing at all** (item 6(d), #296, measured 2026-09-13).
5. **Prod-vs-`main` drift is unmeasured**, not passing — both checks skip for one missing secret (item 3). ⚠️ And it is no longer only a measurement gap: the **live ruleset is 62 lines behind `main`** (§4.3, #293).
6. **Legal texts are unreviewed**, with three blanks — items 5 and 8.
7. **Content is ~2% authored** — item 7.
8. **Nothing is watching the bill** — item 9, and it became urgent the moment billing came back.
9. **The analytics funnel emits into a no-op** in production; turning it on needs the legal change in item 5 first.

**Not blockers, recorded so they are not mistaken for one:** #242 (the three
server-side money events) is open and *correctly* unbuilt — ADR-060 decided not
to build an emitter before there is somewhere to emit.

⚠️ **Two issues closed on 2026-09-13, both re-measured rather than closed on the
record of their fix.** **#115** — the RevenueCat webhook now answers *its own*
JSON (`401 {"error":"unauthorized"}`) instead of Google's HTML, which is that
issue's own acceptance test; the dashboard token match stays open as **2.1**.
**#278** — the per-locale writer is built, gated and self-tested (run again that
day, exit 0); publishing it is still **6(b)** and it has never been run in write
mode.

---

## Next Step

**Three things, and none of them waits on another.**

1. **Item 9** — a budget alert. Billing is live and nothing is watching it; this
   is the one that can cost real money while nobody is looking.
2. **Item 4** — install **121** and open the app. The only question on this page
   that a phone can answer, and it has never been answered.
3. **Item 11** — one word, *Phosphor* or *Material*. The only item here that
   costs nothing but a decision.

**Item 6(b)** remains the largest thing you could unblock with a reading session
rather than a purchase.

## Next Session Goal

**There is no unblocked engineering objective left that a session can pick on its
own, and that is a finding rather than a gap.** Session 102 re-derived the queue
from `gh issue list` rather than inheriting it: of the open issues, the ones a
session could act on alone are M6.5-gated (#13, #250), device-gated (#15, #48,
#136) or brand-gated (#63 — now item **11**, above). Everything else waits on a
secret, a lawyer, a phone, a release authorisation, or a decision on this page.

**So the next session's most useful work is whatever your answers open.** A
word on item 11 starts a real slice; a report from 121 either ends the push hunt
or points it at the network path; the item-3 secrets turn two skipped CI checks
into measurements.
