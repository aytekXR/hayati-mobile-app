# Resume Prompt — Session 091

> **This file contains ONE objective. That objective is the session; nothing else is.**
> (`project-rules.md` #1, `session-rules.md` §1.)
>
> Read `session-context.md` (toolchain, machine, review discipline, the
> never-without-asking list) and `session-lessons.md` (numbered to **141**) first.
> Re-derive the session number from `git log`.

**Objective: #248 — `docs/adr/README.md` stops at ADR-048 while ADR-066 exists.
Eighteen decisions are not in the index a session uses to find precedent.**

### ⚠️ First, two commands. Quote both before planning.

```sh
python3 tool/ci/prod_pulse.py --from-firebase-cli     # 0 = restored, 1 = still down
python3 tool/ci/push_delivery_probe.py --from-firebase-cli
```

Measured 2026-08-30 (S090) — **re-measure, do not inherit**: both exit **1**.
Production has been down since 2026-08-22, and 0 of 4 devices have ever
registered. **Neither is this session's** — they are operator items 1 ① and 1 ② —
but both bound what you can claim. Say so once and work anyway.

*(The first command's wording changed at S090. If it now prints something other
than a closed account, that is the founder having acted, not a regression.)*

### Why #248 is next

It has been the documented #1 priority for three sessions and has been deferred
each time for something more urgent. Nothing more urgent is open now. Meanwhile
the gap grew: **049–066, eighteen ADRs**, counted with
`ls docs/adr/*.md | grep -oE '[0-9]{3}' | sort -u` against the index's own rows,
not by eye.

**This is not cosmetic, and the last two sessions are the evidence.** S089 leaned
on ADR-012 D3, ADR-033, ADR-053, ADR-059 and ADR-063 D8 to do its work; S090
leaned on ADR-041, ADR-063 D2/D4 and ADR-064 D2b. **None of those five is in the
index.** A session that cannot find a decision re-derives it, and re-deriving a
decision is how a repo ends up with two.

### Acceptance

1. **The two probes are run and quoted** before anything is designed.
2. **Every ADR from 049 to 066 appears**, with whatever the index's existing rows
   carry — read the file and match its shape rather than inventing a new one.
   **Count the result with a command and quote the command** (lesson **133**);
   the number in the issue title (*"nine ADRs (049-058)"*) is already stale, and
   so is the "sixteen" and "seventeen" in the last two prompts.
3. **A guard, or an explicit decision not to have one.** This index has now
   fallen behind **eighteen** times, which is a process that does not work. A
   test that fails when `docs/adr/*.md` and the index disagree is cheap and is
   the obvious fix — `legal_assets_drift_test.dart` is the precedent for a
   file-tree-versus-document check. If you decide against it, say why in writing;
   do not simply not build it.
4. **No ADR is required for this** unless you add the guard, which is a decision
   and therefore is. Say which instrument you wrote (lesson 115 applies to the
   guard, not to typing eighteen rows).
5. **The review still runs.** An index is exactly the kind of change where a
   review pass feels unnecessary and where an off-by-one is invisible.

### What is NOT this session's

* **Restoring billing** (operator 1 ①) and **cutting a build** (operator 1 ②).
* **Arming the watcher** — operator item 4's `PROD_PULSE_VIEWER_SA`.
* **The budget alert** (operator item 9).
* **Rewriting any ADR's content.** The index points; it does not summarise
  anything that is not already in the ADR's own title and status line.

---

## 1. Where things stand *(measured 2026-08-30 — re-measure, do not inherit)*

| | State |
|---|---|
| **Production** | 🔴 **DOWN since 2026-08-22T02:00Z.** Account `012195-7EF76F-3A9083` closed **and `billingEnabled` now `false` on BOTH projects** — off at the project as well as the card. Last completed sweep **2026-08-25T15:00:11Z** |
| **`prod_pulse`** | **Correct for all four billing states as of S090** (ADR-066). It names which switch is off and what to do about each |
| **The watcher** | BUILT and MERGED (ADR-064), **UNARMED**. The ARMED path is still unexercised and cannot run until `PROD_PULSE_VIEWER_SA` exists |
| **Push, device side** | **STILL 0 of 4 registered**, four *"no report"* |
| **#253** | **CLOSED by S089** (ADR-065). `sanitizePushName` is a **security boundary** with five rules |
| **#267** | **CLOSED by S090** (ADR-066) |
| **#136** | Autonomous half exercised for the first time at S089. **Step 1 is still device-blocked** |
| **#263** | ⚠️ **OPEN.** The watcher is merged and unarmed, so open is honest. (S089 corrected an inherited prompt that claimed it was closed — verify with `gh`, not with prose) |
| **#248** | **EIGHTEEN ADRs behind (049–066) — THIS SESSION** |
| **#226 / #243 / #242 / #247 / #249 / #250 / #258** | Unchanged; #226 and #243 need the founder |
| **Deployed rules vs `main`** | **DRIFTED** — downstream of billing |

### What S090 changed that a later session will trip over

* **`billing_findings` takes THREE arguments now** — `billing_enabled`,
  `account_name`, `account_open` — and `verdict()` threads `billing_account_name`
  purely to reach it. Without the name, *"not linked"* and *"linked and switched
  off"* are the same input; that was #267.
* **Four billing sentences, and the tests assert ABSENCE.** All four states
  produce exactly one finding, so a `len(findings) == 1` check passes on the bug.
  The assertions are that the unlinked sentence must **not** appear in the other
  three, behind a floor that the four stay four distinct strings.
* **Row 4 (billing off, account OPEN) is defensive and UNMEASURED**, and the ADR
  says so. Reaching it means reopening a closed account — operator item 1.

### Still true from earlier sessions

* **`architecture.md` §7's first sentence is sentinel-parsed** — append after it.
* **The emulator suite can fail on a loaded box.** If you re-run, **say you
  re-ran** (S089 had to: a background-task stop killed a run before it reported).
* **`integration-emulator` never runs on a PR** — main-only by cost design. A
  docs-only merge produces a green with it path-filtered away, measuring nothing.
* **Repeated pushes cancel the macOS gate.** Hold the last commit and push alone,
  and verify `ios-build-smoke` actually COMPILED via
  `gh api repos/:owner/:repo/actions/jobs/<id>/logs` — `gh run view --job --log`
  returns zero lines here.
* **Do not hand-roll a Unicode range** (lesson 124); `strong_bidi_ranges.dart` is
  **GENERATED** (ADR-053).
* `FORMAT_VERSION` is **3**, pinned by **four** assertions (lesson 108).
* **Do not add `UIBackgroundModes: remote-notification`** without deciding SEC-3.
* **`main` is protected.** A close commit needs its own PR; a direct push is
  rejected by the branch hook.

---

## 2. Then, in priority order

**1 — #249** (the consent record is named in no collection list). **2 — #242**
(the server three have no emitter; waits on a sink). **3 — #258** (the legal draft
under-describes deletion once #246 landed).

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

> ⚠️ **A CORRECTION IS NOT DONE UNTIL EVERY COPY OF IT IS GONE** (lesson **141**).
> S090 removed one of two copies of a stale note and its commit message said the
> note was removed. `grep` for the note's own words before claiming it.
