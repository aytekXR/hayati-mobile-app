# Operator Checkpoint

**Last Updated:** 2026-09-02 UTC (Session 095)

> This file is a **live checkpoint**, not a history. It carries only the current
> state and what is open right now. What each session did, and why, lives in
> `docs/past-prompts.md` and in the ADRs.

## Current Status

- Session: **095** (complete)
- Goal: **work out how much of the store-listing failure is fixable without you**
- Status: **Complete** — and it found something nobody had measured
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

**Session 095 answered the question it was given and then found a bigger one.**

| | what changed, in one line |
|---|---|
| **095** | The tool that checks your store listing could only say a field *"differs"*. Now it says *how* — and the first honest answer was that seven of your nine English fields contain **nothing at all**. Also: five documents (one of them in code) claimed your app is called `İkimiz`; it is `ikimiz`, and the guard that exists to protect that name would not have caught a careful person following the wrong instruction. |

Everything is merged to `main` and CI is green.

**Verified today:** the full `quality` job green (format, analyze, app suite,
coverage gate), `functions-rules` green, and `ios-build-smoke` **genuinely
compiled** — a 200-second Xcode build, checked in the job log rather than inferred
from a green tick. The store-metadata tool's own suite went from 41 checks to 91,
mutation-checked with 14 mutants of which 13 die on a named assertion.

## Plan Changes

**One correction to what this file told you before**, said out loud rather than
quietly fixed, because you may have read it: item 6 used to describe the store
listing as showing copy that disagreed with ours. It shows **no copy**. The
difference matters to you, so it is the first thing in this file.

**One new blocker**, below: the listing is not submittable as it stands.

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

#### 6(c) — May a session dispatch the release lane once, to test a fix?

`session-context.md` §7 says a session must never dispatch the release lane
**without asking**. So this is the asking.

The fix for #204's engineering half (**#278**) makes the lane publish the locales
it *can* publish, so one locale Apple refuses stops taking the other down with it.
It cannot be exercised anywhere else: the dev box has no Ruby or fastlane, and the
only other place it runs is a real release.

> **The decision:** yes, a session may dispatch it once for this purpose — or no,
> and it waits for your next real release.

⚠️ A dispatch uploads a real binary to your TestFlight. That is the cost. It is
about 30 free macOS minutes otherwise.

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

### 10. ⚠️ NEW — the dev box lost its Firebase login

The machine was rebuilt around **2026-08-31**. `flutter`, `dart`, `java`, `ruby`
and the `firebase` CLI all went with it, along with the git identity. A session can
reinstall the SDKs — that is just downloading, and `dart` is already back — but it
**cannot log in as you**.

> On the dev box: `npm i -g firebase-tools && firebase login`

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

Merge PR **#279** and watch the post-merge `main` run.

## Next Session Goal

**Session 096 — #278: publish the store listing per locale, so one locale Apple
refuses stops taking the other down with it.** The engineering half of #204,
split out today. It is the only open issue whose fix can be built *and proven*
on the dev box as it currently stands, and it is the thing that would put copy on
the empty listing at the top of this file.

**It will be built and not run.** Pointing it at your listing needs 6(b) — and if
you would rather it never ran at all, say so and it stops being built.

*(#136 was the obvious next candidate and was checked before being named: ADR-059
D3 has already decided its remaining question, against adding the isolate, because
whether a phone's notification shade honours those characters cannot be measured
without a phone. Naming it would have handed the next session a decision that had
already been taken.)*
