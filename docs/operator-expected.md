# Operator Checkpoint

**Last Updated:** 2026-09-03 UTC (Session 099)

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
| Production | 🟡 **Billing RESTORED 2026-09-03 ~22:05 UTC** after 12 days down. The webhook answers again; the first successful daily sweep is still pending — item 1 |
| Open operator items | **items 1, 2 and 10 are DONE**; 3–9 stand |

**Completion — ~58%.** Engineering (M0–M6.3) is **~95%** — every milestone closed,
the code builds, signs and passes its gates. The question bank is **2.1%** — 21 of
1000 questions (measured today: 7 each in `solo_ar`, `solo_en`, `solo_tr`).
Weighting engineering at 60% and content at 40%: `(0.60 × 95) + (0.40 × 2.1) ≈ 58`.
**The engineering is nearly done; content and the items below are the gap.**

**Integration Ready**, not Beta Ready: production has been down 12 days, no push
has ever reached any phone, the RevenueCat webhook answers **HTTP 403** (verified
today), and nothing is watching production. *Beta Ready* would mean real people
using real features on real devices, and that has never happened.

**To reach Beta Ready:** billing restored and verified · one push delivered to a
real phone · a current build on devices (the last is **25 days** old) · the drift
checks measuring instead of skipping.

---

## Open Operator Actions

Ordered by how much each unblocks. Every line below was verified on 2026-09-03.

### 1. ✅ Billing is RESTORED — waiting on the first successful sweep

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

> **The next hourly sweep is the proof.** Re-run:
> `python3 tool/ci/prod_pulse.py --project hayatiapp-prod --from-firebase-cli`
> — **0** means the daily loop is genuinely running.

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
| `RC_WEBHOOK_TOKEN` is set and non-empty | the 503 branch was **not** taken — **the secret is bound and populated** (version 1, revision `revenuecatwebhook-00005-mok`) |

This is `session-context.md` §8's own test — *"JSON = fixed, HTML 403 = broken"* —
answering **fixed**.

#### 2.1 — The one thing left: does RevenueCat send the same string?

RevenueCat sends whatever is in its dashboard **verbatim** in the `Authorization`
header — no `Bearer`, no HMAC (ADR-013 D1). Nothing here can read RevenueCat's
console, so this is yours:

> **Read the value:** Secret Manager → `RC_WEBHOOK_TOKEN` → version 1 → *View
> secret value*. (Or, after `gcloud auth login`:
> `gcloud secrets versions access 1 --secret=RC_WEBHOOK_TOKEN --project=hayatiapp-prod`.)
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

### 4. Cut a build, install it, allow notifications

The last build is **119, cut 2026-08-09 — 25 days ago.** Everything merged since
is on nobody's phone.

> Dispatch the release lane → install from TestFlight → open the app to the paired
> home screen → tap **Allow** on the notification prompt.

⚠️ **Do this after item 1.** Before billing is restored the registration call is
refused, so you would spend the permission prompt — which iOS shows **once per
install** — and learn nothing.

### 5. The legal bundle — one decision, three drafted parts, six questions

`docs/legal/proposed/` holds the version-3 draft of all three privacy policies. It
is **not in force**: `CURRENT_LEGAL_VERSION` is still **2** and nobody has been
re-prompted.

| | the gap it closes |
|---|---|
| **#226** | the notice denies push, and never names the device address or the phone's own status report |
| **#249** | the record of your consent — version, when, age confirmation — is stored, handed over on request, and named nowhere |
| **#258** | what account deletion actually removes was under-described |

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

### 9. A Firebase budget alert

Item 3's watcher catches the *symptom* days late; a budget alert catches the
*cause*. **Had one existed, the current outage would have been hours rather than
days.**

> <https://console.cloud.google.com/billing/012195-7EF76F-3A9083/budgets> →
> **Create budget** → scope it to the billing account → set an amount and the
> alert thresholds → make sure the notification email is one you read.

⚠️ **Do this in the same sitting as item 1**, while you are already in the billing
console. It is the cheapest protection on this page.

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

---

## Current Blockers

🔴 **Production is down** (item 1). Everything server-side is downstream and no
session can fix it.

These block **public launch**:

1. ~~Nothing runs on the server~~ — **billing restored 2026-09-03**; awaiting the first successful sweep (item 1).
2. **Payments** — Google's side is done and proven; what remains is matching the token in RevenueCat's dashboard (item 2.1).
3. **Push has never been delivered** — item 4; 0 of 4 devices registered.
4. **The App Store listing is not submittable** — seven of nine English fields empty at Apple, Turkish absent. Items 6(a) and 6(b).
5. **Prod-vs-`main` drift is unmeasured**, not passing — both checks skip for one missing secret (item 3).
6. **Legal texts are unreviewed**, with three blanks — items 5 and 8.
7. **Content is ~2% authored** — item 7.
8. **The analytics funnel emits into a no-op** in production; turning it on needs the legal change in item 5 first.

**Not blockers, recorded so they are not mistaken for one:** #242 (the three
server-side money events) is open and *correctly* unbuilt — ADR-060 decided not to
build an emitter before there is somewhere to emit. #278 (publish per locale) is
open, built and deliberately unrun pending 6(b).

---

## Next Step

**Two things, and neither waits on the other.**

1. **Item 1** — restore billing, and set the budget alert (item 9) while you are
   in the console. Everything server-side is downstream of it.
2. **Item 6(b)** — the only item that needs no money, no hardware and nobody else.

## Next Session Goal

**Session 100 — #63: a brand decision nobody has ever put to you.** Your brandkit
specifies **Phosphor** icons; the app ships **28 Material** ones, and the design
record has carried that as a known divergence rather than a question. Session 100
will write up both ways out and what each costs, and deliberately **will not
recommend one**, because it is your brand.

**It is the last thing on the board a session can move.** After it, every open
issue is waiting on billing, a phone, a lawyer, a secret, or a decision on this
page.
