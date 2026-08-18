# Operator Checkpoint

**Last Updated:** 2026-08-18 02:40 UTC

## Current Status

- Session: **080**
- Goal: **#129 — the release lane installs the lock it was given, and CI verifies that lock for the first time**
- Status: **Complete** (S080 merged and verified on `main`)
- Completion: **~60%** of the iOS MVP as specified, to public launch
- Production Readiness: **Beta Ready**

### How that 60% is arrived at, since one number hides two very different pictures

| | state |
|---|---|
| Engineering infrastructure (M0–M6.3, coach live) | **~95%** — all milestones closed; `coachProxy` is deployed to prod on the live Anthropic provider with `LLM_API_KEY` present on both projects (verified today) |
| MVP scope item 3 — question bank 400/300/300 | **~2%** — 7 questions per locale exist, solo only; no couple packs |
| MVP scope item 11 — analytics (Mixpanel + gate instrumentation) | **0%** — no analytics code in `app/lib` at all |
| MVP acceptance (purchases, push delivery, native review, legal) | **not met** — see Blockers |

The engineering is nearly done. **Content and instrumentation are the gap**, and most of what is left is yours rather than a session's.

## Latest Checkpoint

`main` is at **`509f23d`**, green on every job including `integration-emulator`.
**2,844 tests pass** (1,743 app across 158 files; 1,101 functions across 54 files,
97.47% coverage). Nothing is broken.

Since the last checkpoint, four issues closed — **#137**, **#227**, **#208**, and
earlier **#175/#174/#222/#223/#221**:

- **#137** — the bidi seam classifies characters against generated Unicode tables
  instead of asking `intl`. Measuring found the filed defect *understated*: five
  blocks rather than one, plus a second, separate bug where every astral RTL
  script and every emoji read as left-to-right.
- **#227** — the data-rights export stopped being narrower than the deletion
  lane. Deletion already erases device state, so the system was **deleting data
  it would not show you**. The export now carries a device lane: the diagnostic
  verbatim, the FCM tokens as a **count only** — because delivery is the system
  clipboard and a raw token is a live credential addressing a phone.
- **#208** — a wedged CI suite now **fails with a name** instead of being
  cancelled in silence. The finding underneath it matters to you: the job's
  safety net was the Slack notifier, and the notifier is silent for `cancelled`
  — which is exactly what GitHub calls a timeout. **That net is still unarmed:
  there is no `SLACK_WEBHOOK_URL` secret, so no CI notification reaches you at
  all today** (the last `main` run logged *"no notification sent"*).

**Three corrections were made to the project's own records**, each found by
measuring rather than re-reading: three closed issues were still listed as open
in this file; **#226 appeared in no operator document at all** despite being
founder-blocked; and three ADRs cited a rule (`session-rules` §5.1) that does not
exist — the rule is `session-context.md` §5.

## Plan Changes

**S079 was replanned mid-session, and it is worth one paragraph of yours.**

It opened on **#129** (the release lane's stale `Gemfile.lock` comment). Before
starting, the post-merge run of the *previous* session's work produced data that
falsified a bound that work had just shipped: the integration watchdog was sized
by wall-clock time, and the same test suite has now been observed at **457, 513,
540, 640 and 936 seconds — a 2.05× spread from runner speed alone**. No fixed
duration is both tight enough to catch a hang and loose enough to avoid falsely
failing a slow run.

The instrument was wrong, not the number: a hang is defined by producing
**nothing**, and a healthy run goes quiet for at most 299s against the incident's
2280s — a 7.6× separation. The watchdog now bounds **silence**. Fixing that took
priority over #129 because the alternative was leaving a guard that would have
started reddening `main` for no reason.

**#129 (with #121) moves to the next session.** No roadmap change; no milestone
moved.

## Open Operator Actions

Ordered by how much each unblocks. Every item below was verified today.

### 1. Install the TestFlight build and allow notifications — unblocks the whole notification feature
Open TestFlight → install **build 119** → open the app to the paired home screen →
tap **Allow** on the notification prompt. If no prompt appears (iOS shows it only
once ever), go to **iOS Settings → Notifications → ikimiz → Allow Notifications ON**.

*Blocked by this:* every push. The server has composed and attempted pushes on
schedule since 2026-08-11, and **0 of 4 accounts have ever registered a device
token** (re-measured today). Nothing else can be tested until one device registers.

⚠️ Build 119 was cut **2026-08-09**. Five merged client slices are on **nobody's
phone** — the notification diagnostics, the Settings row, the reveal
announcement, the card surfaces and the bidi fix. **Cutting a new build is
yours** (the release lane uploads a real binary; a session must never dispatch it).

### 2. Grant the RevenueCat webhook a public invoker — purchases currently take money and never unlock Premium
```
gcloud run services add-iam-policy-binding revenuecatwebhook \
  --region=europe-west1 --project=hayatiapp-prod \
  --member=allUsers --role=roles/run.invoker
```
Verify: `curl -i -X POST https://revenuecatwebhook-mzym2uw5gq-ew.a.run.app -H 'Content-Type: application/json' -d '{}'`
— a **JSON refusal is correct**; HTML means still broken.

*Measured today:* **HTTP 403**. Still closed. This is issue **#115**, and it is a
security-posture decision on a live system, which is why a session will not take
it alone.

### 3. Rotate the leaked Slack webhook and set `SLACK_WEBHOOK_URL`
1. Revoke the old webhook (api.slack.com/apps → Incoming Webhooks → remove).
2. Create a fresh Incoming Webhook for Hayati CI.
3. `gh secret set SLACK_WEBHOOK_URL --body 'https://hooks.slack.com/services/...'`

*Blocked by this:* **all CI notifications**. This has risen in importance — the
`integration-emulator` job is post-merge-only by design, and its compensating
control is precisely this notifier. Today a red on `main` reaches you only if you
go looking.

### 4. Two service-account secrets — one arms three deploy lanes, one arms two drift checks
- **`FIREBASE_SERVICE_ACCOUNT`** (Firebase Admin, Service Account User, Cloud
  Scheduler Admin, Secret Manager Viewer) → `gh secret set FIREBASE_SERVICE_ACCOUNT < sa.json`.
  Arms `deploy-site.yml`, `deploy-rules.yml`, `deploy-functions.yml`. Point the
  first run at `hayatiapp-dev`.
- **`FIREBASE_RULES_VIEWER_SA`** (Firebase Rules Viewer + Cloud Functions Viewer,
  both projects, read-only) → `gh secret set FIREBASE_RULES_VIEWER_SA < ro.json`.

*Verified today:* both absent; `rules-drift` and `functions-drift` were **SKIPPED**
on the latest `main` run. **So "is production running what `main` says?" is
currently unmeasured** — and that exact gap cost the notification feature once
already.

### 5. Your legal name as data controller
One fact. It unblocks the privacy policy, the terms, the `/privacy` URL and
public App Store submission. A session will not guess it into a legal document.

### 6. The Turkish App Store name — Apple refuses `ikimiz` for `tr`
Another app holds it. Choose: a different Turkish display name, ship
English-only, or file a trademark claim. *Blocked by this:* **all eight store
metadata fields** — nothing written in the repo has ever reached the Turkish
store page (issue **#204**).

### 7. Enable Associated Domains on the App ID
Apple Developer portal → Identifiers → `com.beyondkaira.hayati` → tick
**Associated Domains** → Save. Without it, an invite link opens the web page
instead of jumping into the app.

### 8. Optional, one setting — make `gemfile-lock-verify` a required check
Settings → Branches → `main` → Require status checks → add **`gemfile-lock-verify`**.

Today the required list is `quality`, `ios-build-smoke`, `functions-rules`. The
new job verifies that the committed `Gemfile.lock` actually installs — but as a
non-required check it is **visible, not enforcing**: a red result shows on the PR
without blocking the merge. This is the difference between seeing a broken lock
and being stopped by one. Low risk; it only ever runs when `Gemfile*` changes.

### 9. Set a Firebase budget alert
The only watchdog that would have caught the 37-hour outage of 2026-08-09→11.
Billing itself is **fine** (restored 2026-08-11, verified).

### 10. Enable Dependabot **alerts** (~1 min)
Settings → Advanced Security → Dependabot alerts → Enable.
⚠️ Do **not** enable "Dependabot security updates" — the auto-PRs would propose
downgrading `firebase-admin`. *Verified today:* alerts are disabled.

### 11. `RC_WEBHOOK_TOKEN` on the **dev** project
```
printf '%s' '<token>' | firebase functions:secrets:set RC_WEBHOOK_TOKEN --project hayatiapp-dev --data-file=-
```
Without it dev runs 12 of 13 functions and item 2 cannot be rehearsed safely.

### 12. Sandbox purchase test, once Apple's pricing propagation clears
Buy in **TR** and **SA** sandbox; Premium must flip on **both** phones. Then
revoke the RevenueCat `sk_` v2 key. This is M4's acceptance line and it has never
been met.

### 13. Native TR/AR review of every user-visible string — mandatory before public launch
All TR/AR copy is an AI draft marked `review-PENDING`: solo questions, paywall and
pack copy, the 27 coach strings, 41 lock/settings strings, data-rights copy, store
listing, `InfoPlist.strings`. **TR: the two of you. AR: a Gulf-dialect reviewer.**

### 14. ★ Crisis-content safety review — the gate before the coach runs on a real device
Review the crisis word lists (TR/AR including Arabizi, EN), the professional-help
response and the "not therapy" disclaimer, and give crisis hotline numbers for TR
and SA that you trust. Files: `functions/src/coach/crisis-lexicon.ts`,
`help-content.ts`, `persona-prompts.ts`. **An under-reading filter is a safety
failure, not a bug.**

### 15. The legal bundle — review, three blanks, three lawyer questions, one filing
Six documents in `docs/legal/`, all `review-PENDING`. Blanks: controller identity,
contact address, governing law. Three lawyer questions are listed in
`docs/legal/README.md`. Plus the KVKK data-transfer filing for EU hosting and the
US processor.

### 16. Decide **#226** — the privacy policy is factually wrong about push
It says *"ikimiz does not send push notifications today"*, which is true of the
outcome and **false of the system**, and it names neither `fcmTokens` nor
`pushDiagnostic` in what we collect. ⚠️ Any revision bumps `CURRENT_LEGAL_VERSION`
and **re-prompts every existing user for consent** — your call, not a session's.
A session can draft the wording.

### 17. Two content decisions that are yours
- The **couple** questions are currently the Turkish *solo* pack — a known
  placeholder. The launch target is 400/300/300; **7 per locale exist**.
- **#63** Phosphor vs Material icons, and **#71** a motion token — brandkit
  revisions, both low priority.

## Current Blockers

Nothing blocks the *next session's engineering*. These block **launch**:

1. **Payments cannot complete** — the RevenueCat webhook is not invocable (#115, item 2).
2. **Push has never been delivered** — no device has ever registered (item 1).
3. **Prod-vs-`main` drift is unmeasured**, not passing — both drift checks SKIPPED for want of one read-only secret (item 4).
4. **Legal documents are unreviewed** with three blanks (items 5, 14, 15).
5. **Content is ~2% authored** and no analytics exist — MVP scope items 3 and 11.

## Next Step

Begin **S081 / #239** — the analytics contract, port and emitters.

S080 is closed: `9318c44` on `main`, **#129 CLOSED**, post-merge run green on
every job including `integration-emulator`. The new `gemfile-lock-verify` check
reported **`skipped`** on both the PR and `main` — visible in the checks list
rather than absent, which was the whole point of gating it with a job-level `if:`
instead of a workflow paths filter.

## Next Session Goal

**#239 — analytics.** MVP item 11 is entirely unbuilt: no event is emitted
anywhere in the app, so **Gates 2 and 3 are not merely unmeasured, they are
unmeasurable**. The contract already exists (`architecture.md` §7 enumerates the
funnel; §2 reserves `core/analytics/`; ADR-016 binds the `coach_msg` shape).

The typed contract, the port and the emitters are autonomous, and Firebase is
already wired so it can back them today. **The Mixpanel token is yours** — it
belongs behind the same port rather than in front of the work.

⚠️ Analytics events are *collection*, and **#226** already says the privacy
policy's collection list is wrong. Do not let a second instance of that defect
land quietly.
