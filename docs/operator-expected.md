# Operator Checkpoint

**Last Updated:** 2026-08-30 UTC (Session 094)

> This file is a **live checkpoint**, not a history. It carries only the current
> state and what is open right now. What each session did, and why, lives in
> `docs/past-prompts.md` and in the ADRs.

## Current Status

- Session: **094** (complete)
- Goal: **finish the three legal disclosure gaps, so one lawyer round settles all of them**
- Status: **Complete**
- Completion: **~60%** of the iOS MVP, to public launch
- Production Readiness: **Integration Ready**

### How those two numbers are arrived at

**Completion — ~60%**, and one number hides two very different pictures:

| | state | measured by |
|---|---|---|
| Engineering (M0–M6.3) | **~95%** — every milestone closed; the code builds, signs and passes its gates | milestone marks in `implementation-plan.md`; CI green on `main` |
| Question bank | **2.1%** — **21 of 1000** questions exist (7 per locale, solo only; target 400/300/300) | a `python3` count over `content/packs/solo_*.json` |
| MVP scope items | **7 of 12** complete, 5 partial | `docs/mvp.md` |

Weighting engineering at 60% of the effort and content at 40%:
`(0.60 × 95) + (0.40 × 2.1) ≈ **58%**`. **The engineering is nearly done. Content
and the operational items below are the gap**, and most of what is left is yours
rather than a session's.

**Production Readiness — Integration Ready.** ⚠️ **This is a downgrade from the
"Beta Ready" this file claimed before.** That claim had not been re-measured; it
has been now, and it does not survive:

- **Production has been down 8 days.** Account `012195-7EF76F-3A9083` is closed,
  and both projects now report `billingEnabled: false`. Last completed daily
  sweep: **2026-08-25 15:00 UTC**.
- **No push has ever reached any phone** — 0 of 4 accounts have ever registered.
- **Payments cannot complete** — the RevenueCat webhook answers **HTTP 403**.
- **Nothing is watching production** — `rules-drift`, `functions-drift` and
  `prod-pulse` **SKIP** on every run for want of credentials.

*Beta Ready* would mean real people exercising core features on real devices.
That has never happened. **Integration Ready** is the honest level: the parts
integrate, the suites pass, the app builds and signs — and the live system has
never served one end-to-end user flow.

**To reach Beta Ready:** billing restored and verified running · one push
delivered to a real phone · a current build on devices (the last is 21 days old) ·
the drift checks measuring instead of skipping.

## Latest Checkpoint

**Six sessions ran back to back; five issues closed** — #253, #267, #248, #249,
#258. Open issues went **21 → 17**. Everything is merged to `main` and CI is
green.

| session | what changed, in one line |
|---|---|
| **089** | The *"your partner answered"* notification finally says **who**. Because that name is text your partner types, the sanitiser became a security boundary: a hostile name could have put a second line on your lock screen, reversed the sentence, or made the notification fail to send. All three closed. |
| **090** | The tool that tells you whether production is alive was giving the **wrong reason** it is dead — *"no billing account is linked"*, printed directly under the linked account's own id. It now names which of the two billing switches is off, and what to do about each. |
| **091** | The record of every decision this project has made had stopped being a record: **eighteen decisions were missing from its own index.** All written in, and a check now fails the build if it happens again. |
| **092** | The app stores three facts about your consent — which version, when, and that you confirmed your age — and **told you none of them**. Corrected in the draft. |
| **093** | **Blocked, and stopped.** Its assigned task turned out to have been decided against already; it recorded why and ended without building. |
| **094** | The last of the three gaps: deleting your account also clears the on-device markers tied to it, and the notice did not say so. Now it does — naming the one marker that survives. |

**What this means for you: item 5 below is now ONE decision with all three parts
drafted.** Before this run it was one drafted and two merely noted.

**Verified today:** **3126 tests pass** (1880 app, 1246 server), coverage
**87.73%** against a 68% gate and **97.43%** against an 80% gate; 360 golden
images; the CI's own tool self-tests add 543+ checks. Last 8 runs on `main`: all
green, none red.

## Plan Changes

**One correction, and it is about this document.** The previous checkpoint told
you *"all three are drafted"* of the legal disclosure gaps. That was wrong — the
third had only been *noted*. **It is drafted now.** Said out loud rather than
quietly fixed, because you may have read the earlier version.

**One readiness downgrade**, above: *Beta Ready* → *Integration Ready*, on
measured evidence rather than a change of opinion.

Otherwise the plan is unchanged, and the sequence is the one it has been:
**billing first, because everything server-side is downstream of it.**

## Open Operator Actions

Ordered by how much each unblocks. Every line was verified today.

### 1. 🔴 Restore billing — eight days down, everything waits on it

Account **`012195-7EF76F-3A9083`** is **closed**, and since 2026-08-30 both
projects also report billing **off at the project**, not only at the card.

> Open <https://console.cloud.google.com/billing/012195-7EF76F-3A9083> (or
> Firebase Console → ⚙ → Usage and billing). Reopen the account with a working
> payment method, **or** link `hayatiapp-prod` **and** `hayatiapp-dev` to an open
> one. **Then check each project shows billing enabled again** — that second step
> is new, and it is why this reads differently from last time.

**Blocked by this:** every server function. No daily question is assigned, no
notification is composed, no purchase can be processed.

**How you will know it worked**, without asking anyone:

```
python3 tool/ci/prod_pulse.py --from-firebase-cli     # exit 0 = the loop is running
```

Today it exits **1** and names the closed account.

### 2. Grant the RevenueCat webhook a public invoker — money is at stake

The webhook answers **HTTP 403**, so RevenueCat cannot deliver. **A real purchase
would charge the customer and never unlock Premium** (#115).

```
gcloud run services add-iam-policy-binding revenuecatwebhook \
  --region=europe-west1 --project=hayatiapp-prod \
  --member=allUsers --role=roles/run.invoker
```

### 3. Four secrets — without them, nothing is watching production

**None of these four exists** (`gh secret list`, verified today):

| secret | what it turns on |
|---|---|
| `PROD_PULSE_VIEWER_SA` | the production watcher. **Until it exists nothing notices if the daily loop dies** — which is exactly how the current outage ran eight days |
| `FIREBASE_RULES_VIEWER_SA` | the two drift checks — whether what is deployed still matches the code |
| `FIREBASE_SERVICE_ACCOUNT` | the three deploy lanes (rules, functions, site) |
| `SLACK_WEBHOOK_URL` | build notifications; without it a CI failure reaches nobody |

Setup steps: `docs/adr/064-*.md` (watcher) and `docs/adr/041-*.md` (drift). All
but the deploy one are read-only service accounts.

### 4. Cut a build, install it, allow notifications

The last build is **119, cut 2026-08-09 — 21 days ago.** Everything merged since,
including all six sessions above, is on nobody's phone.

> Dispatch the release lane → install from TestFlight → open the app to the paired
> home screen → tap **Allow** on the notification prompt.

⚠️ **Do this after item 1.** Before billing is restored the registration call is
refused, so you would spend the permission prompt — which iOS shows **once per
install** — and learn nothing.

### 5. The legal bundle — one decision, three drafted parts, six questions

`docs/legal/proposed/` holds the version-3 draft of all three privacy policies.
It is **not in force**: `CURRENT_LEGAL_VERSION` is still **2** and nobody has been
re-prompted.

| | the gap it closes |
|---|---|
| **#226** | the notice denies push, and never names the device address or the phone's own status report |
| **#249** | the record of your consent — version, when, and that you confirmed your age — is stored, handed over on request, and named nowhere |
| **#258** | what account deletion actually removes was under-described |

**What is needed from you:** read the draft, put it in front of your lawyer with
the **six** questions in `docs/legal/README.md`, and say go — or say what to
change. ⚠️ **Landing it bumps the legal version and re-prompts every existing
user**, which is why sessions draft it and stop.

⚠️ **This draft has now been corrected four times without landing.** That is worth
a moment of your attention: past some point, the thing to question is the landing,
not the corrections.

### 6. The Turkish App Store name — Apple refuses `ikimiz`

The `tr` listing has failed to publish on **every release since build 112**, and a
`continue-on-error` hid it. The audit found more than the issue claimed: seven of
nine `en-US` fields also disagree with the repo. **The name is a product decision,
not a click** — Turkish needs a display name that is not already taken (#204).

### 7. Content — the largest single gap in the product

**21 of 1000 questions exist** (7 per locale, solo only). The couple questions are
currently the Turkish solo pack, a known placeholder. Target: 400/300/300.

### 8. Before public launch, but not before beta

- **Your legal name as data controller** — three bracketed blanks stay blank until you supply it.
- **Native TR/AR review** of every user-visible string.
- **★ Crisis-content safety review** — the gate before the coach runs on a real device.
- **Sandbox purchase test**, once Apple's pricing propagation clears.
- **Enable Dependabot alerts** (~1 min); optionally make `gemfile-lock-verify` a required check.
- **A Firebase budget alert.** ⚠️ Item 3's watcher catches the *symptom* days late; a budget alert catches the *cause*. Had one existed, this outage would have been hours rather than eight days.

## Current Blockers

🔴 **Production is down** (item 1). Everything server-side is downstream of it and
no session can fix it.

These block **public launch**:

1. **Nothing runs on the server** — item 1. Every item below is downstream.
2. **Payments cannot complete** — item 2, and refused by the serving layer anyway until item 1.
3. **Push has never been delivered** — item 4; 0 of 4 devices registered.
4. **Prod-vs-`main` drift is unmeasured**, not passing — both checks skip for one missing secret (item 3).
5. **Legal texts are unreviewed**, with three blanks — items 5 and 8. The only launch blocker whose fix is written and sitting still.
6. **Content is ~2% authored** — item 7.
7. **The analytics funnel emits into a no-op** in production, and turning it on needs the legal change in item 5 first.

**Not a blocker, recorded so it is not mistaken for one:** #242 (the three
server-side money events) is open and *correctly* unbuilt — ADR-060 decided not to
build an emitter before there is somewhere to emit, and that is still true.

## Next Step

Record Session 094's CI result, and open the pull request carrying this
checkpoint.

## Next Session Goal

**Session 095 — #204: establish how much of the store-listing failure is fixable
without you.** The Turkish listing has never published, and the audit shows the
English one disagrees with the repo in seven of nine fields. **The Turkish *name*
is yours** (item 6) — but whether the release lane still hides the failure, and
whether the English mismatch is a separate and unblocked defect, is a session's to
answer. If it turns out to be entirely yours, the session will say so and stop:
that is a clean outcome, not a failed one.
