# Operator Checkpoint

**Last Updated:** 2026-08-30 UTC (S092)

## Current Status

- Session: **092**
- Goal: **the app records that you consented, when, and that you confirmed your age — and told you none of it**
- Status: **Corrected in the draft, and item 16 now asks you for ONE decision instead of three.** The red box below is still the most urgent thing in this document, and only you can act on it
- 🔴 **PRODUCTION IS DOWN AND HAS BEEN SINCE 2026-08-22. Your Google billing account is CLOSED.** Nothing your app does on a server has worked for **eight days**: no daily question is being assigned, no push is composed, and purchases cannot be processed. **Item 1 ① is the whole fix and only you can do it.**
- 🔴 **It has moved a step further since 2026-08-28, and this is the one new fact in this document you should act on.** Until then the projects still *reported* billing as enabled while the account behind them was closed. Re-measured **2026-08-30**: `billingEnabled` is now **`false` on BOTH `hayatiapp-prod` and `hayatiapp-dev`** — Google has now switched billing off at the project, not merely at the card. **Reopening the account may no longer be enough on its own; check that both projects are still linked to an open account afterwards**, and confirm with the command in item 1
- ⚠️ **Last time this happened it cost 37 hours (2026-08-09→11). This time it has cost eight days**, because the tool built afterwards to catch it could not report during the outage. That tool was fixed at S087, S089 caught it printing the wrong sentence for the *new* state, and **S090 fixed that too (#267)** — so the command in item 1 now tells you exactly which of the two billing switches is off, and what to do about each
- ⚠️ **Item 16 is still waiting on you, and it is the oldest open honesty gap in the repo**
- ⚠️ **The privacy document waiting for your lawyer now carries FOUR small notes, not one — see item 16.** The newest is S089's, and it is the one that changed direction: the notification bullet said no notification names anyone, and that is no longer true
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

## 🔴 Your billing account is closed, and it has taken production down

You asked why the 9 a.m. question never arrives. I found the answer today, and it
is **not** the answer this document gave you last week.

**Measured, 2026-08-27/28:**

* Your billing account **`012195-7EF76F-3A9083` ("Firebase Payment", TRY)** reports
  **`"open": false`** — it is **closed**.
* Every hourly run of the daily-question sweep since **2026-08-22 02:00 UTC** has
  been refused before it started, with Google's own words:
  *"The request failed because billing is disabled for this project."*
* The last time the sweep actually completed was **2026-08-25 15:00 UTC** — one
  lone hour that got through. Before that, **2026-08-22 01:00 UTC**.
* Your **dev** project is linked to the same closed account, so it is down too.

**What that means in plain terms:** for eight days (six when this was written,
re-measured 2026-08-30) your app has not been assigning
anybody a daily question, has not been sending any notification, and cannot
process a purchase. This is not a code problem — nothing in the app is broken.
The servers are refusing to run because the card behind them stopped paying.

### The two steps, and why the order is not optional

> **① Restore billing.** Open
> <https://console.cloud.google.com/billing/012195-7EF76F-3A9083> (or Firebase
> Console → ⚙ → Usage and billing). Either reopen this account with a working
> payment method, or link **both** `hayatiapp-prod` and `hayatiapp-dev` to an open
> billing account. It usually takes a few minutes to propagate.
>
> **② Then dispatch the release lane**, install the build from TestFlight, open the
> app to the paired home screen, and tap **Allow** on the notification prompt.

**Do ① first.** Doing ② first cannot make a 9 a.m. question arrive — there is no
question being assigned to announce, and the call your phone makes to register
itself would be refused too. You would grant permission, see nothing the next
morning, and reasonably conclude push is still broken. That is the fifth time in a
row this feature has produced a silence with a different cause, and it is the one
thing I am trying to stop happening again.

*(If you have **already** done ②: nothing is lost. iOS remembers the permission,
and the app re-attempts registration every time it launches — so once ① is done,
just open the app once and it will register itself.)*

**How you will know ① worked**, without asking me:

```
python3 tool/ci/prod_pulse.py --from-firebase-cli
```

Today it prints the closed account and a **106.7-hours**-stale sweep and exits
**1** (55 hours when this was written).
When billing is restored it will print *"the daily loop is running"* and exit **0**,
within about an hour. *(Until today that command answered `could not measure` —
it read the project's billing **link**, which says "enabled", rather than the
**account**, which says closed, and it threw away that reading anyway when a
second API refused it. Both are fixed; ADR-063.)*

*(A functions deploy may also be needed — prod has drifted from `main` since S077.
That is item 4's territory and I will confirm it once the servers are running
again, so you are not asked for two things when one may do.)*

**S092 (2026-08-30) — a thing we record about you that we never mentioned.**

When you accept the privacy notice, the app stores three facts: **which version
you accepted, when you accepted it, and that you confirmed you are old enough to
use ikimiz.** If you ever ask for your data, all three are handed to you. And the
notice's own list of *"what we collect"* named none of them.

That is the same gap as item 16's push disclosure, one field over: **we show it
if you ask and do not say we hold it.** It is corrected in the draft — one bullet,
in all three languages.

**Nothing has landed and nobody has been re-prompted.** The document in force is
untouched and still version 2; only the draft waiting for your lawyer changed.

**What this changes for you is one line in item 16:** three separate disclosure
gaps are now presented as **one decision**, so the lawyer round you are already
planning settles all three instead of one. There is also a sixth question for
them now, and it is small: *should the age confirmation be listed separately, or
folded into the consent record?* Engineering has no preference and will do either.

**S091 (2026-08-30) — housekeeping, and the reason it is worth a line to you.**

**Nothing here needs you and nothing changes on your phone.** This project keeps
a numbered record of every architectural decision — 67 of them now — and an index
at the front so anyone can see what has already been decided without opening 67
files. **The index had stopped being updated eighteen decisions ago.** It was on
the to-do list for three sessions running and lost each time to something more
urgent, which is exactly how it got to eighteen.

All eighteen are written in now, and a check runs on every push that fails the
build if a decision is ever added without its index entry. **The point is not
tidiness.** When a session cannot find a decision that was already made, it makes
it again — usually differently — and that is how a codebase ends up with two
answers to the same question and no way to tell which one is live.

One small thing it turned up while being built: an entry from an earlier session
had been quietly rendering wrong on GitHub for months, with its status pushed out
of the table. Fixed.

**S090 (2026-08-30) — the instrument was telling you to look for a link that was already there.**

**Nothing here needs you, and it takes one paragraph.** The command this document
gives you as *"how you will know billing is restored"* was printing **"no billing
account is linked"** — directly underneath a line naming the linked account. It
was wrong: the account **is** linked, it is **closed**, and since 2026-08-30
billing is switched off at the project as well. A reader following that sentence
would go to the console hunting for a missing link that is there.

It could not have said anything better, and that is the interesting part: the
function writing that sentence was never given the account **name**, so *"not
linked"* and *"linked and switched off"* looked identical to it. It now knows the
difference and has four sentences instead of one — including the one you will
want if you reopen the account and the project takes a moment to catch up
(*"billing is off at the project even though the account is open — enable billing
on this project, or wait"*), rather than being told to re-link something already
linked.

**What you should take from it:** the wording in item 1 is now the tool's own
wording, so you no longer need this document to translate it for you.

**S089 (2026-08-30) — the notification finally says who answered, and the name is treated as something a stranger typed.**

**What changes for you, when a build eventually reaches a phone.** Until now every
"your partner answered" notification said exactly that — *"Your partner
answered"* — because nothing ever supplied the name. It now says **"Your partner
Aylin answered"**, in Turkish and English. **Arabic readers are unaffected**: for
them discreet notifications are on by default and cannot be turned down, so their
notifications stay generic, which is deliberate (PRD F6).

**The part that took the session, and it is not the wiring.** The name comes from
what your partner typed about themselves, and there is no server checking it. So
it is the first time a string one person chooses lands on **another person's lock
screen**, under your app's name. Measured against the code as it stood: a name
containing a line break put **two attacker-chosen lines** on that lock screen, in
the visual position a system message occupies; a name containing one invisible
control character reversed the whole sentence; a 500-character name composed a
payload large enough to fail the send outright, so the notification would simply
never arrive. None of those could happen before, because the branch was
unreachable — and all three would have shipped the moment it became reachable.
The name is now cleaned before it is used, and if what is left is not a name, the
notification quietly goes back to saying *"your partner"*.

**Two sentences in the app were made false by this and are corrected in the same
change**: the line under the name field (it said your partner would see the name
*on your invitation* — now also in a notification) and the description of the
**Discreet notifications** setting (it promised to hide "message content", which
notifications have never carried; it now says what it actually hides — the name,
the event, the streak).

**Nothing here can be seen on a phone yet**, and that is item 1, not this work:
production is down and no device has ever registered. It is proven in the
emulator, which is where every part of the notification feature has been proven.

**Nothing in this needs you.** The privacy draft waiting for your lawyer (item 16)
was updated in the same change so it describes what the app now does.

**S086 (2026-08-27) — a launch metric that cannot be measured, and the identifier I did not create.**

Your Gate 3 targets include *install → paid ≥ 2%*. The app counts an install
before anyone has an account, and a payment against a couple — **and there is
deliberately no thread joining them**, because this product refuses to put an
account identifier on anything it counts. That refusal is a safety choice for
people for whom being identifiable is dangerous, and it has now been made three
times.

I did **not** create an identifier. Two findings say the question is smaller than
it looks:

**First, and this one needs a sentence from you.** *Install* counts **phones**.
*Paid* counts **couples** — one subscription covers both partners. So a couple who
both install and then subscribe once is **two installs and one payment**, and the
number halves itself for exactly the people this app is for. **Does "2% of
installs end up paying" mean 2% produce a payment, or 2% become a paying person?**
Those differ by exactly 2×, which is the whole value of the threshold. No
identifier fixes this — it is a definition, and it is free to settle now.

**Second, the number may not need the join at all.** Comparing installs and
payments **over the same month** answers *"is acquisition worth paying for"*
without identifying anybody, and it errs on the cautious side — it can only ever
tell you to spend *less* than the truth, never more. *(My first draft suggested
comparing this month's installs against next month's payments. A review caught
that: while installs are growing that version flatters the number and could tell
you to spend on a product that has not earned it. The safe version is the plain
same-month one.)*

> **② When you next look at the privacy documents, answer one sentence: does
> `install→paid` count payments, or paying people?** *(No rush, no cost, nothing
> waits on it except the eventual dashboard.)*

**S085 (2026-08-26) — "delete my account" now reaches the phone, and nothing here needs you.**

When someone tapped *"Delete account & data"*, everything on our servers went —
that part has worked since M6.2. But the app also keeps a handful of small
private markers on the phone itself, so it does not ask you the same thing twice:
that you have seen the coach's "this is not therapy" note, that you have been
shown the privacy card once, that a milestone was already counted. Those markers
name the account they belong to, and **they were surviving the deletion**, because
a server cannot reach into a phone.

They go now. On the phone that runs the deletion, every marker tied to that
account is removed along with it. Two markers stay, deliberately: *"this phone
installed the app"* and *"this phone has seen the intro"*. Neither names a person
— they describe the handset, not the account — and clearing them would just make
the app show a first-launch intro to someone who has already seen it.

**Two honest limits, so nobody is surprised later.** It reaches the phone the
deletion was run on; a second phone the same account once signed into keeps its
markers until the app is removed there. And if the phone's own backup already
copied them to Apple or Google, that copy is out of our reach — the same limit
that applies to every app.

**One thing for your lawyer, and it is small.** The draft privacy notice you are
holding says these markers *"go when you remove the app"*. That is still true.
It is now also incomplete, because deleting your account removes them too — the
notice promises **less** than the app does, which is the safe direction. One
added clause would close it. It is written up in the draft's own README beside
the other note, and it is **your call, not a session's**.

**S084 (2026-08-21) — a decision made, no code, and nothing you need to do.**

The three subscription events that Gate 3 is made of (`trial_start`, `paid`,
`churn`) had no home. They now have one, written down: they come from the
RevenueCat webhook's own decision point, not from a watcher on our subscription
records. The alternative was rejected on two measurements — a watcher would have
inherited exactly the delivery failures it was supposed to avoid, and it would
have recorded a **churn** every time somebody deleted their account.

**Nothing was built**, on purpose: there is nowhere to send the events until the
analytics decision in item 16/18 is yours to make. What exists is a decision
precise enough that building it later is transcription.

**S083 (2026-08-21) — a notification bug fixed before anyone could receive it, and one sentence of last session's draft corrected.**

Nothing here needs you, and nothing changes on your phone. Two things are worth
knowing.

**A partner's name would have broken notifications, in English and Turkish more
than in Arabic.** The copy put the name first, and a phone decides which way to
lay out a line from its first letter — so a partner with an Arabic name would
have made the whole English notification render backwards. Measured with the
reference implementation rather than guessed. Both are fixed before the feature
is switched on.

**And the app never actually sends a partner's name at all** — the code that
would is written and tested, but nothing calls it, so every notification says
*"your partner"*. That is filed as a gap to close deliberately (**#253**), not a
bug. ⚠️ **That sentence stopped being true on 2026-08-30: S089 closed #253, and
the notification now names your partner. See the S089 entry below.** It is left
standing rather than deleted because the *shape* of the gap — code written,
tested, and reached by nothing — is the thing worth remembering. It also means one sentence in last session's legal draft — *"a notification
can show your partner's name"* — was **wrong**, and it has been corrected. That
is exactly the kind of error the draft exists to remove, so finding it in the
draft itself is worth saying out loud rather than quietly fixing.

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

### 1. Restore billing, THEN install the build and allow notifications — in that order

**① Restore billing — this one is on fire.** Account
`012195-7EF76F-3A9083` reports `"open": false`. Every server-side run since
**2026-08-22 02:00 UTC** has been refused with *"The request failed because
billing is disabled for this project."* Reopen the account with a working payment
method, or link `hayatiapp-prod` **and** `hayatiapp-dev` to an open one.

⚠️ **Re-measured 2026-08-30 and it has changed shape.** Both projects now report
`billingEnabled: false` *while still naming that account* — so billing is off at
the **project** as well as at the account:

```
hayatiapp-prod  billingEnabled=False  billingAccountName=billingAccounts/012195-7EF76F-3A9083  account open=False
hayatiapp-dev   billingEnabled=False  billingAccountName=billingAccounts/012195-7EF76F-3A9083  account open=False
```

**What that changes for you:** reopening the account is still step one, but do not
stop there — **confirm afterwards that each project shows billing enabled again**
(Firebase Console → ⚙ → Usage and billing, for both projects).

*(S089 found `prod_pulse` narrating this state as "no billing account is linked",
which was wrong — the account is linked and closed — and this document carried a
note telling you to ignore that line. **S090 fixed the tool (#267), so the note is
gone and the command's own words are correct again.** It now prints:*
*"BILLING IS OFF for this project, and the account it is linked to
(billingAccounts/012195-7EF76F-3A9083) is CLOSED. Reopen that account with a
working payment method, or link this project to an open one — then check the
project shows billing enabled again."*)

The last **completed** sweep is still **2026-08-25 15:00 UTC** (**106.7 hours**
before this measurement).

*Blocked by this:* **everything the server does.** No daily question is assigned at
local midnight, so none can be announced at 9 a.m.; no push of any kind is
composed; the RevenueCat webhook cannot process a purchase even after item 2.
Verify with `python3 tool/ci/prod_pulse.py --from-firebase-cli` — exit **0** and
*"the daily loop is running"* means done.

**② Then** open TestFlight → install a **current** build → open the app to the
paired home screen → tap **Allow** on the notification prompt. If no prompt appears
(iOS shows it only once ever), go to **iOS Settings → Notifications → ikimiz →
Allow Notifications ON**.

*Blocked by this:* every push reaching a phone. **0 of 4 accounts have ever
registered a device token**, and all four report *"no report"* — measured again
today. ⚠️ Build 119 was cut **2026-08-09**; **seven** merged client slices are on
**nobody's phone** — ADR-049, 051, 052, 053, 054, 057 and 061, counted from
`git log --since=2026-08-09 -- app/lib app/ios` rather than estimated — including
the push self-diagnostic that would say which link broke. **Cutting a new build is yours** (the release lane uploads a real binary; a
session must never dispatch it).

**Why ① before ②:** ② cannot deliver a 9 a.m. question while ① is unfixed — there
is nothing being assigned to announce, and the registration call would be refused
by the same serving layer. You would spend the prompt and learn nothing. *(If ② is
already done, nothing is lost: iOS keeps the grant and the app re-registers itself
on the next launch after ① — `_syncFrom` → `_captureAndRegister`, every launch.)*

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

### 4. THREE service-account secrets — one arms three deploy lanes, one arms two drift checks, one arms the production watcher

**⚠️ New (S088): `PROD_PULSE_VIEWER_SA`.** Without it, **nothing watches whether
production is running** — which is how the current six-day outage went unnoticed.
The grant is deliberately tiny:

* a service account with **`roles/logging.viewer`** on `hayatiapp-prod` and
  `hayatiapp-dev`, and nothing else;
* paste its JSON key as the repository secret **`PROD_PULSE_VIEWER_SA`**.

**It is scoped to reading logs and NOTHING ELSE, on purpose.** This repository is
public, so the question is not "can the key write" but "what would a leaked key
*see*". `roles/billing.viewer` — the obvious grant — carries your payment
metadata, your spend, your credits and a list of every project on your billing
account, so the watcher does **not** get it: the reason the loop stopped is already
in the logs in Google's own words. The richer billing read stays on my local
`--from-firebase-cli` path, where no key is stored anywhere.

*Blocked by this:* the 6-hourly production watcher and its post-merge twin. Both
ship **unarmed** and say so loudly in the run log until this secret exists.


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

### 9. Set a Firebase budget alert — ⚠️ still the item that would have saved six days, and item 4's new secret does NOT replace it
The only watchdog that would have caught the 37-hour outage of 2026-08-09→11 —
**and it would have caught the current one too.** It was left unset after that
incident, and the same failure recurred on 2026-08-22 and ran for **six days**
before anyone looked. Billing is **NOT** fine: see item 1 ①.

A budget alert catches the *cause* (the card) days before anything catches the
*symptom* (a dead sweep). It is the cheapest control in this document.

**S088 built the symptom-catcher, and that is not this.** The new watcher (item 4)
tells you production has *already* stopped. A budget alert tells you the card is
about to fail while everything still works. They are not substitutes, and shipping
the watcher must not be read as closing this item.

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

⚠️ **The notification bullet has now been rewritten twice, in opposite
directions, and that is the reason this document keeps being worth reading.**
ADR-058 drafted *"a notification can show your partner's name"*; S083 corrected it
to *"no notification names anyone"*, which was true then because nothing supplied
the name; **S089 made it false again by supplying it**, and rewrote the bullet a
third time to say the notification **does** carry the name, that discreet mode
removes it, that discreet is on by default in Arabic, and that the name is
whatever your partner typed — unverified by us. Each rewrite was correct when
written. **Nothing here changes what you have to decide**; it changes what the
document you hand your lawyer will say.

**S092 added a fourth note — the consent record — and made this item carry the
whole class, so one lawyer round settles it.** Three separate issues are the same
shape: *the app holds or does something, and the notice does not say so.*

| | |
|---|---|
| **#226** | the notice denies push and never names the device address or the phone's own status report |
| **#249** | the record of your consent — which version, when, and that you confirmed your age — is stored, is handed to a user who asks for their data, and is named nowhere. **Corrected in the draft by S092** |
| **#258** | what deletion actually removes is under-described, since the delete-my-account work landed |

All three were found by review passes reading the documents, all three are
drafted, and **all three wait on the same decision from you**. Sending them
together costs one round; sending them separately costs three.

⚠️ **Landing it bumps `CURRENT_LEGAL_VERSION` and re-prompts every existing user
for consent.** That is why a session drafted it and stopped. **What is needed from
you:** read it, put it in front of your lawyer with the **six** questions in
`docs/legal/README.md` — the sixth is new and small: *should the age confirmation
be named separately in the list, or folded into the consent record?* Engineering
has no preference and will implement either. Then say go, or say what to change.
The three bracketed blanks stay blank until item 5.

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

🔴 **Production itself is down** — the billing account is closed (item 1 ①). That
blocks the next session's engineering too: nothing that spans a deploy boundary
can be verified against prod until it is restored.

These block **launch**:

1. **Nothing runs on the server at all** — billing account closed since
   2026-08-22 (item 1 ①). Every item below is downstream of this one.
2. **Payments cannot complete** — the RevenueCat webhook is not invocable (#115, item 2) — *and* would be refused by the serving layer anyway until ① is done.
3. **Push has never been delivered** — no device has ever registered (item 1 ②).
4. **Prod-vs-`main` drift is unmeasured**, not passing — both drift checks SKIPPED for want of one read-only secret (item 4).
5. **Legal documents are unreviewed** with three blanks (items 5, 14, 15) — **and the ones in force are wrong about push**: a correction is drafted and waiting on you (item 16). This is the only launch blocker whose fix is written and sitting still.
6. **Content is ~2% authored** — MVP scope item 3.
7. **The funnel emits into a no-op in prod** — item 11 is instrumented but not *measured*, and turning that on is item 18 plus item 16.

## Next Step

**Item 1 ① — restore billing.** It is the only thing in this document that stops
everything else from being true, and it is entirely yours. One console visit —
**and now one extra check afterwards**: since 2026-08-30 both projects report
billing *disabled at the project*, not only a closed account behind them, so once
you have reopened the account confirm that `hayatiapp-prod` **and**
`hayatiapp-dev` are each linked to it. Then:

```
python3 tool/ci/prod_pulse.py --from-firebase-cli     # exit 0 = the loop is running
```

**S089 (2026-08-30)** closed the last piece of the notification feature that was
*wrong* rather than merely unshipped: the "your partner answered" notification now
says **who**. Because the name is something your partner types and nothing checks
it, the session spent most of its time on what a hostile name could do to your
lock screen — a line break, a reversed sentence, a payload too large to deliver —
and closed all three. **None of it can be seen on a phone until ① is done**, and
that is the whole of what stands between you and this working.

It also found the tool in the box above printing *"no billing account is
linked"* when the truth was *"linked to a closed account"*, and this document
carried a note telling you to ignore that line. **S090 (2026-08-30) fixed the
tool (#267), so the note is gone and the command speaks for itself again** — it
now names which of the two billing switches is off and what to do about each.

S086 is closed: **#243** decided (ADR-062), nothing built, **no identifier
created**, issue stays open for your one sentence (the question under item 16).

## Next Session Goal

**#242 — the three money events have nowhere to go.** When a trial starts, a
payment succeeds, or a subscription lapses, the app is supposed to count it. The
decision about *where* to count it was made (ADR-060); the code that does it was
never written. Nothing about it needs you — and to be clear about the limit, it
will count into the same no-op the other eight events already count into, because
sending anything to an analytics vendor needs the legal change in item 16 first.

*Done, and kept here because they were the previous goals:* **#249** — the
consent record, corrected in the draft at S092 (ADR-068). **#248** — the decision
index had fallen eighteen entries behind, closed at S091 (ADR-067) with a check
that now fails the build if it happens again.

*Done, and kept here because it was the previous goal:* **#267** — `prod_pulse`
measured two separate billing facts and, on the state production entered on
2026-08-30, printed a sentence denying one of them one line beneath the other.
Fixed at S090 (ADR-066); the command in the box above is now correct for all four
billing states. It went first, not because it was large, but because **this repo
has paid 37 hours and then eight days for instruments that could not report
correctly.**

**Nothing in either needs you.** Superseded goals are kept below for the record.

*Watch the loop, so a closed card is never again found six days late.* Built and
merged at S088 (ADR-064) and **still unarmed** — it needs the read-only secret in
item 4, and the budget alert in item 9 catches the same failure days earlier.

*Make the 9 a.m. question actually arrive.* The honest headline was *the feature is
finished and has never fired once.* The server picks 9 a.m. in each couple's own
timezone, writes the message and sends it; the app knows how to receive one; both
halves are tested. **Zero of four phones have ever said where to send it** — and,
it turns out, no server has been running to send anything to them.

**What no session can do is put a build on your phone.** That stays action ①.

**No accounts, no keys, no money — for the session. One build install and one
permission tap, for you.**
