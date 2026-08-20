# Operator Checkpoint

**Last Updated:** 2026-08-21 UTC

## Current Status

- Session: **082**
- Goal: **#226 — draft the bundled legal-text revision covering push and analytics**
- Status: **Complete for the autonomous half** (ADR-058; PR #251). A version-3 draft is on `main` at `docs/legal/proposed/`, **not in force**. Five issues filed: **#246**–**#250**
- ⚠️ **One decision is now waiting on you and it is the oldest open honesty gap in the repo — see items 16 and 18**
- Completion: **~60%** of the iOS MVP as specified, to public launch
- Production Readiness: **Beta Ready**

### How that 60% is arrived at, since one number hides two very different pictures

| | state |
|---|---|
| Engineering infrastructure (M0–M6.3, coach live) | **~95%** — all milestones closed; `coachProxy` is deployed to prod on the live Anthropic provider with `LLM_API_KEY` present on both projects (verified today) |
| MVP scope item 3 — question bank 400/300/300 | **~2%** — 7 questions per locale exist, solo only; no couple packs |
| MVP scope item 11 — analytics (Mixpanel + gate instrumentation) | **instrumented, not measured** — was 0% until S081. The app now emits 8 of the 12 funnel events with typed payloads and real call sites, and two tests keep the code and `architecture.md` §7 from drifting apart. **But prod ships a no-op sink: no event leaves any device, and no Mixpanel project exists.** Three named gaps remain — the 3 entitlement events have no server emitter (#242), Gate 3's `install→paid` has no join key (#243), and the vendor adapter needs a legal-text change first (#226, item 16) |
| MVP acceptance (purchases, push delivery, native review, legal) | **not met** — see Blockers |

The engineering is nearly done. **Content and instrumentation are the gap**, and most of what is left is yours rather than a session's.

## Latest Checkpoint

**S082 (2026-08-21) — the privacy policy now has a correction waiting for you.**
A **version-3 draft** of the three privacy policies sits at
`docs/legal/proposed/`. It is **not in force**: `CURRENT_LEGAL_VERSION` is still
**2**, no user has been re-prompted, and a test asserts that not-landed state so
it cannot land by accident.

**What the session measured, and why it matters more than "a doc is stale."**
The policy says *"ikimiz does not send push notifications today."* **Build 119 —
the only build on any phone — already asks for notification permission and tries
to register the device's address with our server.** The server sweep has been
running since S070. The only reason nothing is stored is that the registration
has never once succeeded (0 of 4 accounts, re-measured). **So the app is already
attempting a collection its notice denies.** That is not a future problem; it is
a present one, and it gets wider with the next build, which adds two more things
the notice does not name.

**What you have to do:** read `docs/legal/proposed/README.md`. It carries the
delta in plain language, what is still blank, and — if you approve — the exact
landing diff, step by step. Then items **16** and **18**.

**Two things the review surfaced that are yours to decide**, both flagged in that
README at the moment they are cheapest: whether to also disclose the **consent
record** itself (#249 — one bullet, nearly free while your lawyer has the
document open, expensive as its own round later), and that the draft makes a
promise the future **Android** build must keep (#250).

*(Previous checkpoint — S081, 2026-08-19 — analytics, MVP item 11.)* The app has gone from **no
analytics code at all** to emitting **8 of the 12 funnel events** with typed
payloads and real call sites, behind a port. **1,819 app tests** (was 1,743),
coverage **87.69%**. Nothing is broken.

**Read this part carefully, because the honest status is narrower than "analytics
is built":** prod is wired to a **no-op sink**. **No event leaves any device.**
There is no Mixpanel project, no SDK, and no new processor — so nothing in your
DPA paperwork changes *today*. What exists is the seam, the events, and two tests
that stop the code and the specification drifting apart. Turning it into a
*measurement* is **item 18**, and its first step is legal, not technical.

Three gaps are named rather than hidden: the three entitlement events
(`trial_start`/`paid`/`churn`) have **no server emitter** (#242); Gate 3's
`install→paid` **cannot be computed** because the two halves of the funnel share
no identity, and minting one is a privacy decision (#243); and the `storefront`
dimension is empty because the app has no source for it.

Before that, four issues closed — **#129**, **#137**, **#227**, **#208**, and
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

### 15. The legal bundle — review, three blanks, **five** lawyer questions, one filing
Six documents in `docs/legal/`, all `review-PENDING`. Blanks: controller identity,
contact address, governing law. **Five** lawyer questions are now listed in
`docs/legal/README.md` — A/B/C from ADR-023, plus **D** (does naming an analytics
provider at its own opt-in discharge the duty to inform, or does that adapter
re-prompt everyone a second time) and **E** (on the notification leg, is Apple a
processor or its own controller). Plus the KVKK data-transfer filing for EU
hosting and the US processor.

### 16. Decide **#226** — the draft is written; the decision is yours
**The wording exists now.** `docs/legal/proposed/` holds a version-3 draft of all
three privacy policies, and `docs/legal/proposed/README.md` explains the change in
plain language and carries the exact landing diff.

It corrects two things in one revision: the push disclosure (what the app stores,
all four notification kinds and their hours, that a notification can show your
partner's **name** unless discreet mode is on, the quiet window, Google's and
Apple's notification services as recipients, and that nothing has actually been
delivered yet) and the analytics sentence (the app now counts a few milestones and
discards them on the phone — no provider, nothing sent).

⚠️ **Landing it bumps `CURRENT_LEGAL_VERSION` and re-prompts every existing user
for consent.** That is why a session drafted it and stopped. **What is needed from
you:** read it, put it in front of your lawyer with the five questions in
`docs/legal/README.md`, and say go — or say what to change. The three bracketed
blanks stay blank until item 5.

### 17. Two content decisions that are yours
- The **couple** questions are currently the Turkish *solo* pack — a known
  placeholder. The launch target is 400/300/300; **7 per locale exist**.
- **#63** Phosphor vs Material icons, and **#71** a motion token — brandkit
  revisions, both low priority.

### 18. The analytics vendor — and the legal change that must land BEFORE it
S081 built the funnel behind a port: eight events emit today, into a debug sink,
**in dev only**. Prod is wired to a no-op, so **nothing leaves any device** and no
processor is engaged. Turning it into a *measurement* needs two things from you,
in this order:

1. **A Mixpanel (or Firebase Analytics) project and token.** It drops in behind
   an unchanged seam — no app rework.
2. **⚠️ FIRST, the legal change.** Analytics events are *collection*. The moment
   an adapter sends them off the device, `docs/legal/` needs a collection line
   and `docs/dpa-inventory.md` needs a processor row — and that **bumps
   `CURRENT_LEGAL_VERSION` and re-prompts every existing user for consent**,
   exactly like item 16. **Bundle the two**: one legal revision, one re-consent,
   covering both push and analytics, rather than asking your users twice.

**Step 2 is now drafted — see item 16.** The version-3 draft covers the analytics
correction as well as push, so the two ride one review and one re-consent.

⚠️ **This bullet used to promise more than engineering can deliver, and S082
corrected it.** Bundling gets you **one review and one re-consent for what exists
today**. It does **not** guarantee that connecting a vendor later needs no second
prompt: a privacy notice has to name the company that receives your users' data,
and we have not contracted with one — naming Mixpanel today would be a *different*
false sentence in the same document. Whether the adapter must therefore bump the
version again is **lawyer question D**, and until your lawyer says otherwise the
conservative answer stands: **assume it does.**

**There is no CI check that stops an adapter landing without step 2** — the gate
is a paragraph in ADR-057, now also tracked as **#247**. Stated plainly rather
than implied.

## Current Blockers

Nothing blocks the *next session's engineering*. These block **launch**:

1. **Payments cannot complete** — the RevenueCat webhook is not invocable (#115, item 2).
2. **Push has never been delivered** — no device has ever registered (item 1).
3. **Prod-vs-`main` drift is unmeasured**, not passing — both drift checks SKIPPED for want of one read-only secret (item 4).
4. **Legal documents are unreviewed** with three blanks (items 5, 14, 15) — **and the ones in force are wrong about push**: a correction is drafted and waiting on you (item 16). This is the only launch blocker whose fix is written and sitting still.
5. **Content is ~2% authored** — MVP scope item 3.
6. **The funnel emits into a no-op in prod** — item 11 is instrumented but not *measured*, and turning that on is item 18 plus item 16.

## Next Step

Begin **S083 / #136** — the Arabic push copy's bidi twin, the half that needs no
device.

S082 is closed: **#226**'s autonomous half is done (PR #251, ADR-058) — a
version-3 draft on `main`, deliberately not landed. **#226 stays open until you
and your lawyer approve it.** Five issues were filed along the way: **#246**
(on-device analytics markers survive account deletion), **#247** (the analytics
adapter gate is prose, not a check), **#248** (nine ADRs missing from the index),
**#249** (the consent record is named in no collection list), **#250** (Android
backup would break a promise the new draft makes).

**Nothing blocks the next session's engineering.**

## Next Session Goal

**#136 — the Arabic notification copy interpolates a partner's name with no bidi
protection**, and S082 made that pointed: the new draft tells Arabic users, in
writing, that a notification can show their partner's name. Having just promised
it, the repo should be sure the name renders the way its owner wrote it.

The half that needs a phone — whether the notification shade honours the isolation
characters — stays blocked on you (item 1). The half that does not is real work:
today's Arabic copy is only **accidentally** safe, because the name happens to sit
at the end of the clause. A name followed by a full stop — `Aylin Y.` — reorders.
The session will rearrange the Arabic strings so that cannot happen and pin the
case with a test.

**Nothing in that touches your phone, your accounts, or your money.**
