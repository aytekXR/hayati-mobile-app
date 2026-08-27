# Resume Prompt — Session 088

> **This file contains ONE objective. That objective is the session; nothing else is.**
> (`project-rules.md` #1, `session-rules.md` §1.)
>
> Read `session-context.md` (toolchain, machine, review discipline, the
> never-without-asking list) and `session-lessons.md` (numbered to **132**) first.
> Re-derive the session number from `git log`.

**Objective: nothing watches production. Build the watcher — and arm every part of
it that does not need the founder.**

### ⚠️ Before planning: run this, and put its output in your first message

```sh
python3 tool/ci/prod_pulse.py --from-firebase-cli
```

**Exit 0 = the founder restored billing and the loop is running again.**
**Exit 1 = still down; read the FINDING lines, they name the cause.**

Measured 2026-08-28 (S087) — **re-measure, do not inherit**:

| | |
|---|---|
| `billingAccounts/012195-7EF76F-3A9083` | **`"open": false`** — the account is CLOSED |
| `projects/hayatiapp-prod/billingInfo` | `"billingEnabled": true` — still LINKED, so the project flag reads healthy |
| `questionRollover` | refused **every hour since 2026-08-22T02:00:01Z**: *"The request failed because billing is disabled for this project."* |
| last completed sweep | **2026-08-25T15:00:11Z** — one lone recovery; before it, 2026-08-22T01:00Z |
| `hayatiapp-dev` | linked to the **same closed account** |

If it is still exit 1, **that is not this session's to fix** — it is operator item
1 ①, it is a payment action on the founder's Google identity, and no amount of
engineering reaches it. Say so once, in the log, and do the objective below.

### Why THIS is the objective

**Production died on 2026-08-22 and nobody noticed for six days.** That is the
second total outage in nineteen days from the same cause. #219 closed with a
residual list, and **its two open items are precisely why this recurrence went
unseen** — quote it, do not paraphrase it:

> - [ ] **Budget alert (operator item 2(a))** is still unset — the one control that
>       would have caught the cause rather than the symptom.
> - [ ] `prod_pulse` is a local/manual instrument. It has no scheduled lane, so it
>       only runs when someone runs it. A cron that calls it and notifies would
>       close the detection gap properly; that needs a credential decision
>       (`firebase.readonly` is insufficient — it needs logging/scheduler/billing
>       read).

**The residuals of the last incident are the cause of this one.** S087 fixed the
instrument so it can now *report* the outage (ADR-063); it did nothing about the
fact that **only a human running a command locally ever asks it.**

### The two hard parts, both real, neither a reason to skip the session

1. **The credential.** `prod_pulse` is `--from-firebase-cli` only, by design: the
   `firebase.readonly` scope its two siblings use **cannot** read Cloud Logging,
   Cloud Scheduler or Cloud Billing, so wiring that SA would produce a confident
   `exit 2` on every run. Decide what the lane needs and **name it as an operator
   item**, exactly as `rules-drift` (2(e)(iii)) and `deploy-functions` did. The
   repo's established pattern is **build it unarmed and say so** — three lanes ship
   that way today, and `session-context.md` §2 says saying so is the point.
2. **A cron here is not free.** ADR-034 D4's finding is on the record and
   transfers: **GitHub disables scheduled workflows after 60 days of repository
   inactivity** — i.e. during exactly the quiet period a watcher would exist for.
   Decide this in the ADR rather than discovering it. `rules-drift` and
   `functions-drift` both chose *post-merge on `main`* over a cron for this reason;
   a push-triggered watcher catches an outage only when someone commits, which for
   this failure mode may be worse than useless. **Say which trade you take and why.**

### Acceptance

1. **`prod_pulse.py` is run and its output quoted** before anything is designed.
2. **An ADR, written and committed BEFORE code** (`session-context.md` §5 item 1,
   lesson **115**), deciding: the trigger, the credential, the vote, and what the
   notifier says. `slack_notify.sh` is the **single** notifier with **no vote on
   the build and all policy in the script** (ADR-024 D1) — read it before assuming
   it can carry this.
3. **Exit codes stay a taxonomy** (ADR-041, binding): a watcher that cannot
   measure must not report *"broken"*, and must never report green. ADR-063 D2's
   rule already exists in `verdict()`; do not re-derive it differently in a lane.
4. **The lane is proven to the limit a session can reach** — its command sequence
   exercised locally, its self-test hermetic, and **whether it has ever executed
   stated plainly.** A dispatch-only workflow is **unparsed until it reaches the
   default branch** (memory: its first real parse is someone's first dispatch).
5. **`operator-expected.md` names exactly what the founder must add**, and item 9
   (the budget alert) keeps its promoted position — it catches the *cause*, this
   lane catches the *symptom*, and the ADR should say which one it is not.

### What is NOT this session's

* **Restoring billing.** Operator item 1 ①.
* **The budget alert.** Operator item 9.
* **Cutting a build.** Operator item 1 ②, and it is downstream of ①.

---

## 1. Where things stand *(measured 2026-08-27/28 — re-measure, do not inherit)*

| | State |
|---|---|
| **Production** | 🔴 **DOWN since 2026-08-22T02:00Z.** Billing account closed. No day doc assigned, no push composed, no purchase processable. **The single most important line in this table** |
| **`prod_pulse.py`** | **FIXED (ADR-063).** Was exit 2 *"could not measure"* during the outage; now exit 1 naming the closed account, the 55h-stale sweep, and the refusal in Google's own words. 8 mutants, each reddening a named assertion |
| **The 09:00 chain** | **Complete, and now proven by what it SENDS** — the port receives the `dailyQuestion` copy per recipient language, carrying no `questionId`. Mutation-checked: the old suite stayed green with the question id on the lock screen |
| **The comment family** | **6 "this cannot work yet" claims and 21 wrong-hour sites corrected** (ADR-063 D7/D9). Corrected comments now name the instrument instead of restating its answer |
| **Push, device side** | **STILL 0 of 4 registered**, four *"no report"*. Unchanged, and now known to be the *second* problem, not the first |
| **The build gap** | Last `release.yml` run **2026-08-09, build 119**. Operator item 1 ② — and correctly ordered AFTER ① |
| **#226** | **DRAFT on `main`, revision NOT landed.** `CURRENT_LEGAL_VERSION` still **2**, a test asserts it. Founder + lawyer |
| **#243** | **DECIDED, nothing built** (ADR-062). One founder sentence: does `install→paid` count *payments* or *paying users* — they differ by **2×** |
| **#248** | **Now FIFTEEN ADRs behind** (049–063), not nine. `docs/adr/README.md` stops at 048. S087 deliberately did **not** add its own row — one row into a 15-row gap is worse than the gap |
| **#136** | Autonomous half DONE (ADR-059); step 1 is device-blocked |
| **#242** | DECIDED, not built (ADR-060); waits on a sink |
| **Deployed rules vs `main`** | **DRIFTED** — `rules_drift.py` exits 1 today with a real diff (the `pushDiagnostic` clauses are not deployed). A deploy is a **§7 founder ask**, and is downstream of billing |
| **Open issues** | **#242**, **#243**, **#247**–**#250**, **#253**, **#258**, plus the older set |

### What S087 changed that a later session will trip over

* **`verdict()` in `prod_pulse.py` takes `gaps: dict[str, str]`**, and a fact named
  there is **never** turned into a finding. If you add a fact, add its gap
  suppression too, or an unreadable probe will print a confident false cause.
* **`measure_billing` returns `(linked, account_name)`**, not a bool. The
  authoritative fact is `measure_billing_account(...)` → `open`.
* **Exit 2 now means "no finding, and something was unread"** — not "one probe
  threw". A raising probe alone no longer aborts the run.
* **`DEFAULT_LOOKBACK_HOURS` is 168**, deliberately much wider than the 90-minute
  `--max-age-minutes` that decides the verdict. The window only decides whether the
  report can **date** the outage.
* **`daily-question.test.ts` imports `composePush`** as an independent oracle. It is
  not a tautology: the pass chooses the kind and the language, the test states both.
* **A comment may not carry a measured fact about build/device/portal state**
  (ADR-063 D7). Name the instrument instead. This is discipline, **not** a CI gate,
  and the ADR says why a scan cannot do it.

### Still true from earlier sessions

* **`architecture.md` §7 has a second paragraph** after the sentinel-parsed first
  sentence. Appending there is safe and proven; **rewording the first sentence, or
  renaming the heading, is not.** §8 and §9 are free-form.
* **The emulator suite can fail on a loaded box.** Distinguish by SHAPE. S087 met
  this: one `beforeEach` hook timed out at 10s with 50/51 passing, re-ran clean at
  51/51, **and said so**. Do not re-run to green silently.
* **`integration-emulator` never runs on a PR.** Prove a change to it with
  `gh workflow run ci.yml --ref <branch>` before merging.
* **Do not probe a Firestore trigger** with `assert_emulator_functions.sh`.
* **Do not hand-roll a Unicode range** (lesson 124). `\p{Script=…}`.
* `app/lib/core/l10n/strong_bidi_ranges.dart` is **GENERATED — never edit it**.
* `FORMAT_VERSION` is **3**, pinned by **four** assertions (lesson 108).
* **Do not add `UIBackgroundModes: remote-notification`** without deciding SEC-3.

---

## 2. Then, in priority order

**1 — #253** (`partnerAnswered` names nobody: **no caller supplies `partnerName`**,
which is also why ADR-059's `sanitizePushName` sits in a branch nothing calls —
closing #253 is what activates it, and it is the same feature family as the last
two sessions). **2 — #248** (fifteen ADRs missing from the index). **3 — #249**
(the consent record is named in no collection list).

**4 — #204** (`deliver` has failed to create the `tr` localization on every release
since build 112; the **name** is what Apple refuses, so founder-blocked) ·
**#165** (`rules-drift` built but unarmed) · **#121** · **#115** · **#41** ·
**#63/#71**.

---

## 3. Blocked — re-check every line

| What | Blocked on | Why a session cannot take it alone |
|---|---|---|
| 🔴 **Restoring billing** | **founder** | A closed billing account is a payment instrument on their Google identity. **Everything server-side is downstream of this** |
| **The budget alert** | founder | Operator item 9 — the control that would have caught **both** outages |
| **A build carrying ADR-046/049/051/052/053/057/059/061/063** | founder | `release.yml` uploads a real binary — §7. Last build **119** |
| **M3.4's last inch** | the founder's phone | One permission grant. Not destroyed if spent early — the app re-registers on the next launch — but it cannot deliver anything while billing is off |
| **Deploying S071's rules and S077/S083's functions** | founder | §7, and downstream of billing |
| **Landing the #226 revision** | founder/lawyer | The bump re-gates consent for **every** existing user |
| **Minting the #243 identifier** | founder | Collection, and the one identifier that survives sign-out |
| **#136 step 1** | the device | Whether the notification shade honours the isolates |
| **An analytics vendor sink** | founder + lawyer | #226 is the other half — **#247** |
| **#250** | M6.5 | Android backup exclusion, Gate-3 gated |
| **`tr` App Store localization** | founder | Apple refuses the **name**, not the locale |
| **operator 2(d) / 2(e)(ii)–(iv) / 2(a)** | founder | Domains, legal name, three secrets, the budget alert |
| **#115**, **#41** | founder | A world-reachable prod endpoint; live billing identity |
| **#48**, **#15** | the device | On-device observation nobody has made |
| **#63**, **#71** | founder | Brandkit revisions |

---

## 4. Close sequence — `session-rules.md` §3/§4

Append to `past-prompts.md` → regenerate this file (one objective) → refresh
`operator-expected.md` → commit + push → verify CI → **watch the post-merge `main`
run** (`integration-emulator` is main-only) → `codegraph sync`.

> ⚠️ **THE REVIEW RUNS TWICE**, and **S087's design pass earned its keep**: it found
> a **blocking** hole in the exit rule that would have let the tool print *"the daily
> loop is running"* over a dead sweep, showed the design was **unimplementable**
> against the function it delegated to, and **refuted the ADR's own Finding 4** —
> the claim that the founder's permission grant would be destroyed. It is not.

> ⚠️ **WRITE THE ADR FIRST** (`session-context.md` §5 item 1; lesson **115**).

> ⚠️ **Report `agents_error` and `agents_empty_result` as numbers**, and say what
> was **dropped unverified** at the cap. S087 ran **0 and 0**, 11 findings raised,
> 11 verified, 0 dropped, 3 surfaced.

> ⚠️ **FREEZE THE TREE BEFORE THE REVIEW** (lesson **113**); `git status` must be
> EMPTY after every review workflow returns (§5 item 8).

> ⚠️ **Run the guard you just wrote, and mutation-check it — then check the MUTANT.**
> S087 ran eleven. One "stayed green", and the mutant was the defect: it inserted
> dead code instead of changing behaviour (lesson **112**, from the other side).

> ⚠️ **If a claim in the issue — or in THIS FILE — is load-bearing, measure it
> yourself** (lesson **123**). S087's objective arrived asserting that one operator
> step stood between the feature and a notification. **It was wrong**, and the
> instrument that would have said so was one command away.

> ⚠️ **Check the issue rows against `gh`, not against the last session's memory.**
