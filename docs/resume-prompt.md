# Resume Prompt — Session 090

> **This file contains ONE objective. That objective is the session; nothing else is.**
> (`project-rules.md` #1, `session-rules.md` §1.)
>
> Read `session-context.md` (toolchain, machine, review discipline, the
> never-without-asking list) and `session-lessons.md` (numbered to **140**) first.
> Re-derive the session number from `git log`.

**Objective: #267 — `prod_pulse` measures two billing facts, prints a sentence
that denies one of them, and it is the sentence the founder acts on.**

### ⚠️ First, two commands. Quote both before planning.

```sh
python3 tool/ci/prod_pulse.py --from-firebase-cli     # 0 = restored, 1 = still down
python3 tool/ci/push_delivery_probe.py --from-firebase-cli
```

Measured 2026-08-30 (S089) — **re-measure, do not inherit**: both exit **1**. The
first is also **this session's subject**, so read its output as evidence rather
than as background.

### Why #267 is next, ahead of the ADR index

**The billing state changed between S088 and S089 and the tool started lying
about it.** Read through `prod_pulse`'s own helpers on 2026-08-30:

```
hayatiapp-prod  billingEnabled=False  billingAccountName=billingAccounts/012195-7EF76F-3A9083  account open=False
hayatiapp-dev   billingEnabled=False  billingAccountName=billingAccounts/012195-7EF76F-3A9083  account open=False
```

For the whole outage `billingEnabled` said **`true`** — the disagreement ADR-063
D4 was written about. It is now **`false`**, and `billing_findings()`
(`tool/ci/prod_pulse.py:178`) returns early on that branch with *"BILLING IS OFF
for this project — **no billing account is linked**"*, **discarding the
`account_open` fact it measured successfully in the same run**. So the report
prints that sentence directly beneath the linked account's own id.

That is not a wording nit. It is the instruction the founder acts on
(`operator-expected.md` item 1 tells them to reopen the account *or* link one),
and it sends them looking for a link that is already there. **This repo has paid
37 hours and then eight days for instruments that could not report correctly**
(#219, #263). Fixing the instrument outranks indexing the ADRs.

It is also small, which is the point: it should leave room to do #248 properly
next rather than stretching this one.

### Acceptance

1. **The two probes are run and quoted** before anything is designed — and for
   this objective, the first one's output IS the defect. If billing has been
   restored in the meantime, **the branch is no longer reachable live**: say so,
   and prove the fix against `prod_pulse_test.py` fixtures instead. Do not wait
   for an outage to test an outage path.
2. **An ADR or slice design written and committed BEFORE code** (lesson **115**).
   It is small enough that a slice design may be the right instrument — but say
   which you wrote, and do not skip it (`session-context.md` §5 item 1).
3. **Three states, three sentences**, because there are three and the code
   currently has two: *not linked* (`billingAccountName` empty), *linked to a
   CLOSED account* (today), and *linked, `open` unreadable* — the last one named
   as a **gap**, never assumed in either direction (ADR-063's rule).
4. **The exit-code taxonomy is NOT touched.** ADR-041's 0/1/2 is binding and the
   local operator command depends on it. This is a reporting change; if you find
   yourself editing `verdict()`, stop and re-read.
5. **`prod_pulse_test.py` gains the state production is actually in.** There is
   today **no fixture** where `billing_enabled=False` and `account_open=False`
   together — which is why the defect shipped. Add it, and **mutation-check**:
   restoring the old early-return must redden a *named* assertion.
6. **Check the Slack path.** `--notifier-findings` feeds `EXTRA_FINDINGS` into
   `slack_notify.sh` (ADR-064 D2b). Whatever sentence you write is what the
   watcher would post, so assert the notifier text too, not only the report.

### What is NOT this session's

* **Restoring billing** (operator 1 ①) and **cutting a build** (operator 1 ②).
* **Arming the watcher** — operator item 4's `PROD_PULSE_VIEWER_SA`.
* **The budget alert** (operator item 9), still open, still the item that catches
  the *cause* rather than the symptom.
* **#248** — it is next, not now. See §2.

---

## 1. Where things stand *(measured 2026-08-30 — re-measure, do not inherit)*

| | State |
|---|---|
| **Production** | 🔴 **DOWN since 2026-08-22T02:00Z.** Account `012195-7EF76F-3A9083` is closed **and `billingEnabled` is now `false` on BOTH projects** — Google has switched billing off at the project, not only at the card. Last completed sweep **2026-08-25T15:00:11Z** |
| **`prod_pulse`** | Reports during the outage (ADR-063) — and **#267, this session**: it discards the account-open fact on the `billingEnabled=false` branch |
| **The watcher** | BUILT and MERGED (ADR-064), **UNARMED**. `prod-pulse.yml` parses; one dispatch proved the unarmed path. **The ARMED path is still unexercised** and cannot run until `PROD_PULSE_VIEWER_SA` exists |
| **Push, device side** | **STILL 0 of 4 registered**, four *"no report"* |
| **#253** | **CLOSED by S089** (ADR-065). `partnerAnswered` names the author; `sanitizePushName` is now a **security boundary** with five rules, not a formatter |
| **#136** | Autonomous half **exercised for the first time** — the bidi property is asserted at the seam that now reaches it. **Step 1 is still device-blocked** |
| **#263** | ⚠️ **OPEN.** `gh issue view 263` → `OPEN`, `closedAt=null`. The S089 prompt said "CLOSED by S088" and that was wrong; the watcher is merged and unarmed, so open is honest |
| **#248** | **SEVENTEEN ADRs behind** (049–065; `docs/adr/README.md` stops at 048 — counted with `ls docs/adr/*.md`, not by eye) |
| **#267** | **OPEN — this session** |
| **#226 / #243 / #242 / #247 / #249 / #250 / #258** | Unchanged; #226 and #243 need the founder |
| **Deployed rules vs `main`** | **DRIFTED** — downstream of billing; §7 founder ask |

### What S089 changed that a later session will trip over

* **`sanitizePushName` is a security boundary now, not a formatter.** Five rules,
  and its unit suite is a **security** suite: 30 cases × 3 languages behind a
  count floor. Adding a rule means adding a mutation check.
* **`hasContent` disqualifies `Default_Ignorable_Code_Point`** — it does not
  delete it. The distinction matters: the property covers characters real
  orthography carries (Khmer U+17B4/U+17B5, variation selectors).
* **`\p{Cs}` deletes only LONE surrogates.** Under `/u` an emoji is one `So` code
  point and never matches. Do not "simplify" this to a code-unit check.
* **`reveal-service.test.ts` now builds a `[DEFAULT]` Firebase app** so `getAuth()`
  works beside the no-trigger Firestore project. Another suite that assumes no
  default app exists will be surprised.
* **The privacy draft's notification bullet has been rewritten three times, in
  alternating directions** (ADR-058 → ADR-059 → ADR-065). Each was correct when
  written. If you change what a notification contains, that bullet is the fourth.
* **Two ARB strings now describe the push** (`nameCaptureHelper`,
  `settingsNotificationPrivacySubtitle`). They are not in the frozen digest —
  verified, not assumed — so nothing will stop you making them false.

### Still true from earlier sessions

* **`architecture.md` §7's first sentence is sentinel-parsed** — append after it,
  never reword it or rename the heading.
* **The emulator suite can fail on a loaded box.** Distinguish by SHAPE; if you
  re-run, **say you re-ran**. S089 had to: a background-task stop killed the first
  run before it reported, so it was never evidence of anything.
* **`integration-emulator` never runs on a PR.** Prove a change to it with
  `gh workflow run ci.yml --ref <branch>` before merging.
* **Repeated pushes cancel the macOS gate.** Hold the last commit and push it alone.
* **Do not hand-roll a Unicode range** (lesson 124); `strong_bidi_ranges.dart` is
  **GENERATED** (ADR-053). S089 chose properties over lists twice more for the
  same reason.
* `FORMAT_VERSION` is **3**, pinned by **four** assertions (lesson 108).
* **Do not add `UIBackgroundModes: remote-notification`** without deciding SEC-3.

---

## 2. Then, in priority order

**1 — #248** (seventeen ADRs missing from the index; cheap, and the index is how a
session finds precedent — S089 leaned on ADR-012/033/053/059/063 to do its work).
**2 — #249** (the consent record is named in no collection list). **3 — #242** (the
server three have no emitter; waits on a sink).

**4 — #204** · **#165** · **#121** · **#115** · **#41** · **#63/#71**.

---

## 3. Blocked — re-check every line

| What | Blocked on | Why a session cannot take it alone |
|---|---|---|
| 🔴 **Restoring billing** | **founder** | A closed account is a payment instrument on their Google identity. **Everything server-side is downstream**, and it is now off at the project too |
| **Arming the watcher** | founder | `PROD_PULSE_VIEWER_SA`, operator item 4 |
| **The budget alert** | founder | Operator item 9 — catches the *cause*; the watcher only catches the *symptom* |
| **A build carrying ADR-046/049/051/052/053/057/059/061/063/064/065** | founder | §7. Last build **119**, cut 2026-08-09 |
| **M3.4's last inch** | the founder's phone | One permission grant |
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

> ⚠️ **THE REVIEW RUNS TWICE.** S089's design pass produced a **12/12-refuted**
> distribution that was wrong about six true findings, and its built-diff pass
> produced **4/4 real to both verifiers** — same harness, opposite outcome. The
> distribution is a signal about the QUESTION, not about the design (lesson 137).

> ⚠️ **WRITE THE ADR FIRST** (lesson **115**).

> ⚠️ **Report `agents_error` and `agents_empty_result` as numbers**, and say
> whether an empty lens was **considered**-empty or **failed**-empty.

> ⚠️ **FREEZE THE TREE BEFORE THE REVIEW** (lesson **113**); `git status` must be
> EMPTY after every review workflow returns.

> ⚠️ **Mutation-check the guard you wrote — then check the MUTANT** (lesson 112).
> And record the cases that do **not** discriminate; S089 had two.

> ⚠️ **A number is a claim; carry the command that produced it** (lesson **133**) —
> and that includes a claim about an ISSUE's state. S089's inherited prompt said
> #263 was closed; `gh` said otherwise.

> ⚠️ **Measure the load-bearing claim yourself, including one a review agent hands
> you** (lessons **123**, **135**, **139**) — and when a lens says *"cosmetic"*,
> ask what the OTHER consumer of that value does with it.

> ⚠️ **Grep the ARB files for what your change makes false** (lesson **140**). The
> sentence that goes stale is rarely in the code.
