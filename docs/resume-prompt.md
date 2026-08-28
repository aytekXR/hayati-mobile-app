# Resume Prompt — Session 089

> **This file contains ONE objective. That objective is the session; nothing else is.**
> (`project-rules.md` #1, `session-rules.md` §1.)
>
> Read `session-context.md` (toolchain, machine, review discipline, the
> never-without-asking list) and `session-lessons.md` (numbered to **135**) first.
> Re-derive the session number from `git log`.

**Objective: #253 — `partnerAnswered` is supposed to name the partner and never
does, because no caller supplies `partnerName`. Close it, and ADR-059's
`sanitizePushName` stops being a branch nothing calls.**

### ⚠️ First, two commands. Quote both before planning.

```sh
python3 tool/ci/prod_pulse.py --from-firebase-cli     # 0 = restored, 1 = still down
python3 tool/ci/push_delivery_probe.py --from-firebase-cli
```

Measured 2026-08-28 (S088) — **re-measure, do not inherit**: the first exits **1**
(billing account `012195-7EF76F-3A9083` is `"open": false`; last completed sweep
**2026-08-25T15:00:11Z**), the second exits **1** (0/4 registered, four *"no
report"*). **Neither is this session's to fix** — they are operator items 1 ① and
1 ② — but both bound what you can claim: **nothing you build here can be observed
on a phone until billing is restored.** Say so once and build anyway; the work is
correct or not regardless, and it is proven in the emulator.

### Why #253 is next

It is the last piece of the notification feature that is *wrong* rather than
*unshipped*. `partnerAnswered` is the one push that fires when the recipient is
most likely to be looking, and it is name-free in every language because **no call
site passes `partnerName`** — so ADR-059's `sanitizePushName`, written to stop a
partner's name choosing the paragraph direction (#136), sits in a branch nothing
reaches. Closing #253 activates it, which means **#136's bidi work gets its first
real exercise** in the same change. Same feature family as S087 and S088.

### Acceptance

1. **The two probes are run and quoted** before anything is designed.
2. **An ADR written and committed BEFORE code** (`session-context.md` §5 item 1,
   lesson **115**), deciding at minimum: **where the name comes from** (the
   partner's `users/{uid}` document — which field, and what happens when it is
   absent, empty, or junk), **whether reading it is a new read on a hot path**
   (the reveal trigger already reads documents here — do not add one without
   saying so), and **what the push says when there is no name** (there is already
   a name-free variant; it must stay reachable and tested).
3. **The privacy question is answered explicitly, not inherited.** A name on a
   lock screen is content. ADR-012's discreet mode already suppresses it and
   defaults ON for AR — assert that, do not assume it.
4. **`sanitizePushName` is exercised end to end for the first time**, and the
   bidi property it exists for is asserted at the seam that now reaches it, not
   only in its own unit test. **Mutation-check it**: removing the sanitiser must
   redden a named assertion.
5. **The payload proof pattern from ADR-063 D8 is followed** — assert what the
   port RECEIVES, not only who receives it. That gap was found on the
   daily-question pass and the same shape applies here.

### What is NOT this session's

* **Restoring billing** (operator 1 ①) and **cutting a build** (operator 1 ②).
* **Arming the watcher** — operator item 4's new `PROD_PULSE_VIEWER_SA`.
* **The budget alert** (operator item 9), which S088 explicitly did not close.

---

## 1. Where things stand *(measured 2026-08-28 — re-measure, do not inherit)*

| | State |
|---|---|
| **Production** | 🔴 **DOWN since 2026-08-22T02:00Z**, billing account closed. No question assigned, no push composed, no purchase processable |
| **The watcher** | **BUILT and MERGED (ADR-064), UNARMED.** 6-hourly cron + post-merge job, no vote, credential scoped to `logging.read` only. `prod-pulse.yml` **parses** (GitHub lists it active) and one dispatch proved the unarmed path — preflight success, watcher visibly skipped with real `warning:` annotations. **The ARMED path is still unexercised** and cannot run until `PROD_PULSE_VIEWER_SA` exists. Watch the first cron |
| **`prod_pulse.py`** | Reports correctly during an outage (ADR-063); now has a CI path and a pure `findings_for_notifier` |
| **Push, device side** | **STILL 0 of 4 registered**, four *"no report"* |
| **#253** | **OPEN — this session.** No caller supplies `partnerName`; `sanitizePushName` is unreached |
| **#136** | Autonomous half done (ADR-059); its seam is unexercised until #253 lands. Step 1 is device-blocked |
| **#248** | **SIXTEEN ADRs behind** (049–064). `docs/adr/README.md` stops at 048 |
| **#263** | **CLOSED by S088** (ADR-064) |
| **#226 / #243 / #242 / #247 / #249 / #250 / #258** | Unchanged; #226 and #243 need the founder |
| **Deployed rules vs `main`** | **DRIFTED** — `rules_drift.py` exits 1 with a real diff. Downstream of billing; §7 founder ask |

### What S088 changed that a later session will trip over

* **`slack_notify.sh` suppresses a green `schedule` run**, exactly as it suppresses
  a green PR. A finding is exempt from both. If you add a scheduled lane, that is
  why it is quiet.
* **`ci.yml`'s `slack-notify` now `needs: prod-pulse`** and passes
  `EXTRA_FINDINGS`. Adding a second producer means deciding how two findings
  concatenate — nobody has.
* **`rules_drift.py`'s `sa_assertion_claims`/`token_from_service_account` take a
  `scope`** (default unchanged). Pass one rather than adding a second OAuth path.
* **`PULSE_SCOPE` is pinned by a test.** Widening the CI credential past
  `logging.read` is meant to be a deliberate act with a red build.
* **A count in a document carries the command that produced it** (lesson **133**).
  Three counts were wrong across S087/S088 and no habit caught any of them.
* **A review agent's refutation is a claim** (lesson **135**). One was confident,
  specific, and wrong about an IAM fact that a single API call settled.

### Still true from earlier sessions

* **`architecture.md` §7's first sentence is sentinel-parsed** — append after it,
  never reword it or rename the heading. §8 and §9 are free-form.
* **The emulator suite can fail on a loaded box.** Distinguish by SHAPE; if you
  re-run, **say you re-ran**.
* **`integration-emulator` never runs on a PR.** Prove a change to it with
  `gh workflow run ci.yml --ref <branch>` before merging.
* **Repeated pushes cancel the macOS gate.** `ios-build-smoke` can read as covered
  while never having compiled; hold the last commit and push it alone.
* **Do not hand-roll a Unicode range** (lesson 124); `strong_bidi_ranges.dart` is
  **GENERATED** (ADR-053).
* `FORMAT_VERSION` is **3**, pinned by **four** assertions (lesson 108).
* **Do not add `UIBackgroundModes: remote-notification`** without deciding SEC-3.

---

## 2. Then, in priority order

**1 — #248** (sixteen ADRs missing from the index; cheap, and the index is how a
session finds precedent). **2 — #249** (the consent record is named in no
collection list). **3 — #242** (the server three have no emitter; waits on a sink).

**4 — #204** · **#165** · **#121** · **#115** · **#41** · **#63/#71**.

---

## 3. Blocked — re-check every line

| What | Blocked on | Why a session cannot take it alone |
|---|---|---|
| 🔴 **Restoring billing** | **founder** | A closed account is a payment instrument on their Google identity. **Everything server-side is downstream** |
| **Arming the watcher** | founder | `PROD_PULSE_VIEWER_SA`, operator item 4 |
| **The budget alert** | founder | Operator item 9 — catches the *cause*; the watcher only catches the *symptom* |
| **A build carrying ADR-046/049/051/052/053/057/059/061/063/064** | founder | §7. Last build **119**, cut 2026-08-09 |
| **M3.4's last inch** | the founder's phone | One permission grant — deferred, not destroyed, if spent early |
| **Deploying rules/functions** | founder | §7, downstream of billing |
| **#226**, **#243** | founder / lawyer | A consent re-gate; a definitional sentence |
| **#136 step 1**, **#48**, **#15** | the device | On-device observation nobody has made |
| **An analytics vendor sink** | founder + lawyer | #247 |
| **#250**, **#13** | M6.5 | Gate-3 gated |
| **`tr` App Store localization** | founder | Apple refuses the **name** |
| **#115**, **#41**, **#63**, **#71** | founder | A world-reachable endpoint; billing identity; brandkit |

---

## 4. Close sequence — `session-rules.md` §3/§4

Append to `past-prompts.md` → regenerate this file (one objective) → refresh
`operator-expected.md` → commit + push → verify CI → **watch the post-merge `main`
run** (`integration-emulator` is main-only) → `codegraph sync`.

> ⚠️ **THE REVIEW RUNS TWICE.** S088's design pass found a **blocking** hole — a
> stated goal with no mechanism — and its built-diff pass found three more, one of
> which was a **crash that would have been silent**: a malformed secret raised
> `JSONDecodeError`, `main()` did not catch it, and the lane captures stdout, so
> the watcher would have posted nothing while appearing to run.

> ⚠️ **WRITE THE ADR FIRST** (lesson **115**).

> ⚠️ **Report `agents_error` and `agents_empty_result` as numbers**, and say
> whether an empty lens was **considered**-empty or **failed**-empty. S088 ran
> 0/0 on the design pass and 0/3-considered on the built-diff pass.

> ⚠️ **FREEZE THE TREE BEFORE THE REVIEW** (lesson **113**); `git status` must be
> EMPTY after every review workflow returns.

> ⚠️ **Mutation-check the guard you wrote — then check the MUTANT.** S087 had one
> "stay green" that was a no-op mutant, not a gap in the test (lesson 112).

> ⚠️ **A number is a claim; carry the command that produced it** (lesson **133**).

> ⚠️ **Measure the load-bearing claim yourself — including one a review agent
> hands you** (lessons **123**, **135**).
