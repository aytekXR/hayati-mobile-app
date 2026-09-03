# Operator Checkpoint

**Last Updated:** 2026-09-03 UTC (Session 099)

> This file is a **live checkpoint**, not a history. It carries only the current
> state and what is open right now. What each session did, and why, lives in
> `docs/past-prompts.md` and in the ADRs.

## Current Status

- Session: **099** (complete)
- Goal: **prove whether a dead step in the release lane is really dead, without spending a release on it**
- Status: **Complete** — half proven, and the half that is left is item 6(c) below
- Completion: **~58%** of the iOS MVP, to public launch
- Production Readiness: **Integration Ready**

### The one thing to read if you read nothing else

**Your App Store listing is empty.** Not out of date — *empty*. App Store Connect
holds nothing for the English description, keywords, subtitle, promotional text,
release notes, privacy URL or support URL. The only field ever set is the app's
name. Measured today, run `33666301529`:

```
audited App Store version: 1.0 state=PREPARE_FOR_SUBMISSION
  - en-US: description differs from description.txt — PUBLISHED IS EMPTY — published 0 vs committed 1454 code points
  ... all seven the same ...
  - tr: NOT PUBLISHED
```

For seventeen days the record said the listing held *"whatever was typed by hand
into App Store Connect"* and that our committed copy merely disagreed with it.
That was a guess. The tool only ever said *"differs"*, and "differs" fits both
"they have different words" and "they have no words". **This session taught it to
say which, and it said the second one.**

**What it means for you, in two directions:**

- **A risk you were carrying is gone.** Publishing our copy cannot overwrite
  anything you typed, because there is nothing there. That was the only
  irreversible danger anyone had named on this.
- **A blocker nobody had counted is real.** A store page with no description, no
  subtitle, no keywords and no support URL **cannot be submitted to Apple.** This
  was not on any list before today.

### How the two headline numbers are arrived at

**Completion — ~58%**, and one number hides two very different pictures:

| | state | measured by |
|---|---|---|
| Engineering (M0–M6.3) | **~95%** — every milestone closed; the code builds, signs and passes its gates | milestone marks in `implementation-plan.md`; CI green on `main` |
| Question bank | **2.1%** — **21 of 1000** questions exist (7 per locale, solo only; target 400/300/300) | a `python3` count over `content/packs/solo_*.json` |
| MVP scope items | **7 of 12** complete, 5 partial | `docs/mvp.md` |

`(0.60 × 95) + (0.40 × 2.1) ≈ **58%**`. **The engineering is nearly done. Content
and the operational items below are the gap**, and most of what is left is yours
rather than a session's.

**Production Readiness — Integration Ready**, unchanged from last time and for the
same measured reasons: production has been down since 2026-08-22, no push has ever
reached any phone, the RevenueCat webhook answers HTTP 403, and nothing is watching
production. *Beta Ready* would mean real people exercising core features on real
devices, and that has never happened.

**To reach Beta Ready:** billing restored and verified running · one push delivered
to a real phone · a current build on devices (the last is **24 days** old) · the
drift checks measuring instead of skipping.

## Latest Checkpoint

**Two sessions ran back to back on the store listing.**

| | what changed, in one line |
|---|---|
| **095** | The tool that checks your store listing could only say a field *"differs"*. Now it says *how* — and the first honest answer was that seven of your nine English fields contain **nothing at all**. Also: five documents (one of them in code) claimed your app is called `İkimiz`; it is `ikimiz`, and the guard that exists to protect that name would not have caught a careful person following the wrong instruction. |
| **096** | Built the thing that fixes it: your store copy can now be published **one language at a time**, so the Turkish listing Apple keeps refusing stops taking the English one down with it. **Nothing has been published** — that is your decision, item 6(b), and item 6(c) just got smaller because this no longer needs a release build. |
| **097** | Pointed it at Apple for the first time, in the mode that writes nothing. **It worked**, and **item 6(b) now shows you exactly what would be published.** It also caught itself telling a small lie — a run that published nothing was reporting *"published"* — which is filed as #281 and does not affect anything you are being asked. |
| **098** | Fixed that lie. The two tools that look at your store listing now agree with each other, and the report says **how much would change** — 15 fields — instead of just *"different"*. One of those numbers is a small piece of good news: your app's **name** is the one field already correct at Apple, confirmed independently by both tools. |
| **099** | A step in the release pipeline has been suspected dead for months, and nobody could prove it without spending a release to find out. Half of it is now **proven** — read out of fastlane's own published source, which turns out not to need fastlane installed. The other half needs one release, and it is item 6(c). |

Everything is merged to `main` and CI is green.

**Verified today:** CI green on both sessions' work — the full `quality` job
(format, analyze, app suite, coverage gate), `functions-rules`, and
`ios-build-smoke` **genuinely compiled** (checked in the job log rather than
inferred from a green tick). The two store-metadata tools carry 105 self-test
checks between them, mutation-checked with 28 mutants of which 26 die on a named
assertion — and the two that did not are written down rather than tidied away.

## Plan Changes

**One correction to what this file told you before**, said out loud rather than
quietly fixed, because you may have read it: item 6 used to describe the store
listing as showing copy that disagreed with ours. It shows **no copy**. The
difference matters to you, so it is the first thing in this file.

**One blocker added in 095 and unchanged:** the listing is not submittable as it
stands.

**One item shrank:** 6(c) no longer gates the store copy — see it below.

Otherwise the plan is unchanged, and the sequence is the one it has been:
**billing first, because everything server-side is downstream of it.**

## Open Operator Actions

Ordered by how much each unblocks. Every line was verified today.

### 1. 🔴 Restore billing — eleven days down, everything waits on it

Account **`012195-7EF76F-3A9083`** is **closed**, and both projects also report
billing **off at the project**, not only at the card.

> Open <https://console.cloud.google.com/billing/012195-7EF76F-3A9083> (or
> Firebase Console → ⚙ → Usage and billing). Reopen the account with a working
> payment method, **or** link `hayatiapp-prod` **and** `hayatiapp-dev` to an open
> one. **Then check each project shows billing enabled again.**

**Blocked by this:** every server function. No daily question is assigned, no
notification is composed, no purchase can be processed.

⚠️ **How you check has changed, and it is item 10's fault, not yours.** The command
this file used to give you —
`python3 tool/ci/prod_pulse.py --from-firebase-cli` — now answers *"could not
measure"* on the dev box, because the box was rebuilt and the `firebase` login went
with it. It is telling the truth: it cannot see. Until item 10 is done, the
Firebase Console is the check.

### 2. Grant the RevenueCat webhook a public invoker — money is at stake

The webhook answers **HTTP 403**, so RevenueCat cannot deliver. **A real purchase
would charge the customer and never unlock Premium** (#115).

```
gcloud run services add-iam-policy-binding revenuecatwebhook \
  --region=europe-west1 --project=hayatiapp-prod \
  --member=allUsers --role=roles/run.invoker
```

### 3. Four secrets — without them, nothing is watching production

**None of these four exists** (`gh secret list`, verified today — the repo holds
five secrets and none of them is one of these):

| secret | what it turns on |
|---|---|
| `PROD_PULSE_VIEWER_SA` | the production watcher. **Until it exists nothing notices if the daily loop dies** — which is how the current outage ran for days |
| `FIREBASE_RULES_VIEWER_SA` | the two drift checks — whether what is deployed still matches the code |
| `FIREBASE_SERVICE_ACCOUNT` | the three deploy lanes (rules, functions, site) |
| `SLACK_WEBHOOK_URL` | build notifications. ⚠️ **Newly relevant:** the store-listing warning built for #204 travels to you through this and nothing else. Without it, a release that fails to publish your store copy still says nothing — which is the exact failure that issue exists to fix |

Setup steps: `docs/adr/064-*.md` (watcher) and `docs/adr/041-*.md` (drift). All but
the deploy one are read-only service accounts.

### 4. Cut a build, install it, allow notifications

The last build is **119, cut 2026-08-09 — 24 days ago.** Everything merged since is
on nobody's phone.

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
| **#249** | the record of your consent — version, when, and that you confirmed your age — is stored, handed over on request, and named nowhere |
| **#258** | what account deletion actually removes was under-described |

**What is needed from you:** read the draft, put it in front of your lawyer with
the **six** questions in `docs/legal/README.md`, and say go — or say what to change.
⚠️ **Landing it bumps the legal version and re-prompts every existing user**, which
is why sessions draft it and stop.

⚠️ **This draft has now been corrected four times without landing.** Past some
point, the thing to question is the landing, not the corrections.

### 6. The store listing — TWO decisions and one authorization, and only the first needs Apple

This was one line until today. It is three, and **they are independent** — you can
answer (b) and (c) now without settling (a).

#### 6(a) — The Turkish name. Apple refuses `ikimiz` for `tr`

The `tr` listing has failed to publish on **every release since build 112**.
Apple's refusal is *"the app name is already being used by another app"* — display
names are unique per locale and someone else holds this one for Turkish. **This is
a product decision, not a click** (#204). Three options, none of which a session
should pick:

1. a distinct Turkish display name in `fastlane/metadata/tr/name.txt`;
2. drop the `tr` localization and keep one global name (then `tr` screenshots are
   moot and this closes as won't-do);
3. pursue the trademark claim Apple's message points at — slow, and yours alone.

#### 6(b) — ⚠️ NEW. May our English copy be published at all?

**This has been gated the whole time and had no line in this file.** ADR-020 D8
put *all* store copy behind a review gate: every string in
`fastlane/metadata/en-US/` is **AI-drafted and has never been read by a human who
owns the product**. `fastlane/README.md` still says *"Native review: PENDING"*.

It was invisible because (a) was failing in front of it. It is now the **first
thing on #204 that does not need Apple**.

> **The decision:** may that copy go up as it stands, or do you want to read it
> first? `fastlane/metadata/en-US/` is seven short files.

**What makes this easy now:** the listing is empty (top of this file), so
publishing cannot overwrite anything of yours. **What makes it urgent:** the
listing being empty means it is **not submittable**, and our copy is the only copy
that exists.

**And you can now see exactly what would happen before deciding.** Session 096
built the lane that does this per locale, and its **dry run writes nothing**:

```
Actions → publish-store-metadata → Run workflow → leave "confirm" BLANK
```

**Session 097 ran it. Here is exactly what would happen**, from run
`33681088334` — which sent nothing:

```
store metadata publish: DRY RUN — nothing was sent.
plan (4 request(s)):
  en-US: PATCH appInfoLocalizations          — 3 field(s): name, privacyPolicyUrl, subtitle
  en-US: PATCH appStoreVersionLocalizations  — 5 field(s): description, keywords, promotionalText, supportUrl, whatsNew
  tr:    POST  appInfoLocalizations          — 3 field(s): name, privacyPolicyUrl, subtitle
  tr:    POST  appStoreVersionLocalizations  — 5 field(s): description, keywords, promotionalText, supportUrl, whatsNew
```

**In plain terms: eight fields per language, and the Turkish listing gets created
from scratch** (that is what `POST` means; English already exists and is simply
empty, so it is a `PATCH`). `marketing_url` is deliberately absent — it is empty
in the repo and this tool never writes a blank over anything.

⚠️ **The Turkish half will still fail**, and that is expected: Apple refuses the
name (6(a) above). The point of the rewrite is that **it now fails alone** —
English publishes regardless, which is the thing that has never happened.

**What you are actually deciding:** whether those eight English fields — written
by an AI, read by nobody who owns this product — may go up. The words are in
`fastlane/metadata/en-US/`: seven short files, a few minutes to read.

> **Say yes** and a session types `PUBLISH` into that same box and your store page
> stops being blank.
> **Say "let me read it first"** and nothing happens until you have.
> **Say no** and #278 stops being maintained; say so plainly and it will be closed
> rather than left looking open.

#### 6(c) — May a session dispatch the release lane once, to test a fix?

`session-context.md` §7 says a session must never dispatch the release lane
**without asking**. So this is the asking.

⚠️ **This got narrower in Session 096, in your favour.** The fix for #204's
engineering half (**#278**) is now a standalone lane that does **not** touch the
release pipeline and does **not** upload a binary — so publishing store copy no
longer needs a release at all. What 6(c) still buys is the ability to test
**#121** (a dead step in the release lane, which can only be proven by a real
run). Lower stakes, and no longer on the critical path.

> **The decision:** yes, a session may dispatch it once for this purpose — or no,
> and it waits for your next real release.

⚠️ A dispatch uploads a real binary to your TestFlight. That is the cost. It is
about 30 free macOS minutes otherwise.

**What 6(c) now buys, concretely.** Session 099 proved from fastlane's own source
that **fastlane never touches** the App Store Connect key file the release lane
writes to disk — so half of #121 is settled. What is left is whether Apple's own
`xcodebuild` reads it, and that cannot be read out of any source we have.

The experiment is **not** a deletion — that would throw away the signal. It moves
the file somewhere nothing can find it and runs the lane: **identical run = the
step is dead and goes; a failure names the missing key at that exact path**, which
is diagnosable rather than cryptic.

⚠️ **And the reason this was declined before has reversed.** It was put off
because *"a build is the single thing blocking push-notification testing"* — so a
failed release was expensive. It is not that any more: production is down, and
item 4 above now says to cut a build **after** billing. **A failed release costs
you less today than when this was last considered.** Your call either way.

### 7. Content — the largest single gap in the product

**21 of 1000 questions exist** (7 per locale, solo only). The couple questions are
currently the Turkish solo pack, a known placeholder. Target: 400/300/300.

### 8. Before public launch, but not before beta

- **Your legal name as data controller** — three bracketed blanks stay blank until you supply it.
- **Native TR/AR review** of every user-visible string. *(This is about in-app strings in the two languages that need a native speaker. It is NOT item 6(b), which is about store copy in English and is a different gate — conflating them is how 6(b) went unrecorded for weeks.)*
- **★ Crisis-content safety review** — the gate before the coach runs on a real device.
- **Sandbox purchase test**, once Apple's pricing propagation clears.
- **Enable Dependabot alerts** (~1 min); optionally make `gemfile-lock-verify` a required check.

### 9. A Firebase budget alert

⚠️ Item 3's watcher catches the *symptom* days late; a budget alert catches the
*cause*. Had one existed, the current outage would have been hours rather than
days.

### 10. The dev box needs YOUR Firebase sign-in (the rest is restored)

The machine was rebuilt around **2026-08-31**. `flutter`, `dart`, `java`, `ruby`
and the `firebase` CLI all went with it, along with the git identity. A session can
reinstall the SDKs — that is just downloading, and `dart` is already back — but it
**cannot log in as you**.

⚠️ **Session 096 restored everything a session could restore by itself** —
Flutter, Java, the Dart SDK and `firebase-tools` are all back, and app-side checks
run locally again. **What is left is the one step that is yours**, because it is an
interactive sign-in with your Google identity:

> On the dev box: `firebase login`

**Blocked by this:** every local production check. `prod_pulse.py`,
`push_delivery_probe.py`, `rules_drift.py`, `functions:log` and `functions:list`
all now answer *"could not measure"*. They are being honest — but it means a
session can no longer tell you whether production came back, and **it can no longer
tell the difference between "production is down" and "I cannot see production"**
without you.

Not urgent while production is down anyway. It becomes urgent the moment you do
item 1, because that is when someone needs to confirm it worked.

## Current Blockers

🔴 **Production is down** (item 1). Everything server-side is downstream of it and
no session can fix it.

These block **public launch**:

1. **Nothing runs on the server** — item 1. Every item below is downstream.
2. **Payments cannot complete** — item 2, and refused by the serving layer anyway until item 1.
3. **Push has never been delivered** — item 4; 0 of 4 devices registered.
4. **⚠️ NEW — the App Store listing is not submittable.** Seven of nine English fields are empty at Apple, and the Turkish localization does not exist. Items 6(a) and 6(b).
5. **Prod-vs-`main` drift is unmeasured**, not passing — both checks skip for one missing secret (item 3).
6. **Legal texts are unreviewed**, with three blanks — items 5 and 8.
7. **Content is ~2% authored** — item 7.
8. **The analytics funnel emits into a no-op** in production, and turning it on needs the legal change in item 5 first.

**Not blockers, recorded so they are not mistaken for one:** #242 (the three
server-side money events) is open and *correctly* unbuilt — ADR-060 decided not to
build an emitter before there is somewhere to emit. #278 (publish per locale) is
open, designed and deliberately unbuilt pending 6(c).

## Next Step

Read item 6(b) and answer it. Everything else on this page is downstream of item 1.

## Next Session Goal

**Session 100 — #63: put a brand decision to you that nobody has ever asked.**
Your brandkit specifies **Phosphor** icons; the app ships **28 Material** ones,
and the design record has been carrying that as a known divergence rather than a
question. Session 100 will write up both ways out and what each costs — and
deliberately **will not recommend one**, because it is your brand.

It is the last thing on the board a session can move.

⚠️ **After that, the queue is genuinely yours.** Every remaining open issue is
waiting on billing, a phone, a lawyer, a secret, or a decision on this page —
re-derived at the end of session 098 rather than assumed. **The most useful thing
you can do next is item 6(b)**: it needs no money, no hardware and nobody else,
and it is the only one that unblocks work rather than waiting on it.
