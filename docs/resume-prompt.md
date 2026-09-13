# Resume Prompt — Session 104

> **This file contains ONE objective. That objective is the session; nothing else is.**
> (`project-rules.md` #1, `session-rules.md` §1.)
>
> Read `session-context.md` and `session-lessons.md` (numbered to **165**) first.
> Re-derive the session number from `git log`.
>
> ⚠️ **BEFORE PLANNING, OPEN THE ADR THAT OWNS THIS OBJECTIVE** (lesson **145**).
> Find what set `--min 68` before you change it — a threshold someone chose for a
> reason is not a typo.
>
> ⚠️ **THE OBJECTIVE BELOW WAS MEASURED BY S103, NOT ASSUMED** (lessons **145**,
> **154**). The numbers are quoted with the commands beside them. **Re-measure
> anyway** — that is the rule the last four sessions have each been caught by.

**Objective: the app coverage gate is ~20 points below what the suite actually
achieves, so it cannot catch a regression. Close the gap, and pin it so it stays
closed.**

Measured on this ref, 2026-09-13, `flutter test --coverage` then:

```
$ dart tool/coverage_gate.dart --min 68 app/coverage/lcov.info
coverage_gate: lines found 8246, lines hit 7236
coverage_gate: 87.75% (threshold 68%)
coverage_gate: PASS.
```

**87.75% measured, 68% enforced.** A change could stop covering roughly **1,630
lines** and the gate would still say PASS. `session-context.md` §3 lists it as
*"app 68"*, and `ci.yml` runs it in `quality` on every PR — so it is present,
green, and **structurally unable to act**, which is this repo's most familiar
failure and the exact shape of lessons **162** and **164**.

### ⚠️ This is NOT "raise the number", and a session that treats it that way will make CI worse

A tight ratchet has its own well-known failure mode: it reddens PRs that touch
nothing related, and it rewards padding the suite with tests that execute lines
without asserting anything. **That trade is the actual design work here.** At
least these questions:

* **What the number should be, and derived how.** ADR-055 D2's *"worst observed,
  not median, and re-derive it whenever a new run exists"* is the house precedent
  — written after a bound sized against one favourable run failed immediately.
* **Whether one global percentage is even the right instrument.** A repo-wide
  number says nothing about *which* code lost coverage; a per-directory floor, or
  a "no new uncovered lines in the diff" ratchet, answers a different and possibly
  better question. Say why you chose what you chose.
* **What happens when it legitimately drops** — deleting covered code moves the
  percentage. Who lowers the gate, and on what evidence?
* **Whether the gate can be made to measure NOTHING.** `coverage_gate.dart`
  already carries the 0/0 precedent in its own source (a missing or empty lcov
  must not read as green). Re-check that path: it is the one that matters most if
  the threshold is about to become load-bearing.

### The three numbers to establish before deciding anything

| | command | S103's reading |
|---|---|---|
| app coverage | `cd app && flutter test --coverage`, then `dart tool/coverage_gate.dart --min 68 app/coverage/lcov.info` | **87.75%** (8246 found, 7236 hit) |
| the enforced gate | `grep -n coverage_gate .github/workflows/ci.yml` | `--min 68`, in `quality`, every PR |
| the functions gate | `functions/package.json` → `test:ci` is `vitest run --coverage`; find the thresholds in the vitest config | ⚠️ **NOT measured by S103.** `session-context.md` says *"functions 80 hard / 85 target"* — **measure it, do not inherit it** |

⚠️ **The functions half may be the more interesting one and it is unmeasured.**
If its real value is also far above its floor, the finding is not *"a number is
stale"* but *"**both** coverage gates in this repo are decorative"* — a different
and larger claim, worth making only with both numbers in hand.

### Acceptance

1. **All three numbers measured and quoted**, each with the command that produced
   it (lessons **133**, **149**, **153**). The queue re-derived from
   `gh issue list`, not inherited from §3 below.
2. **ADR written FIRST** (lesson **115**) with its index row —
   `dart tool/adr_index_lint.dart` is a real gate and fails the build without it.
   Next number is **079**.
3. **The chosen instrument is MUTATION-CHECKED in both directions** (standing
   lesson; S103 hit it twice): a real coverage drop must turn it red, and a
   healthy run must stay green. ⚠️ **And ask what would stop the gate running at
   all** — lesson **164**, paid for last session by a guard that could be hung.
4. **The trade is stated, not smoothed over.** If the new gate would have reddened
   any recent merge, say which and why that is acceptable.
5. **`session-context.md` §3's "Gates" block updated in the same diff** — it
   carries the old numbers and is read at the start of every session.

### What is NOT this session's

* **Raising a number and stopping.** If the diff is one character in `ci.yml`, the
  design work did not happen.
* **Writing tests to move the percentage.** That is padding, and it is the failure
  mode this objective is most likely to cause.
* **#15** — instrumented by ADR-078 and correctly still open; it waits for the
  next occurrence, which cannot be scheduled.
* **#63** (operator **11**), **#296** (operator **6(d)**), **#293**, **#242**,
  **#136**, **#226**, **#243**, **#247** — each decided or blocked elsewhere.
* **#250** and **#13** — M6.5, Gate-3 gated by `roadmap.md`. If you think the gate
  does not apply, say why in writing before starting.

---

## 1. Where things stand *(measured 2026-09-13 — re-measure, do not inherit)*

| | State |
|---|---|
| **The dev box** | `flutter` 3.44.5, `dart` 3.12.2, `java` 21, `node`, `python3`, `gh`, `firebase-tools` — **present but NOT on PATH**: `export PATH=~/flutter/bin:~/.local/share/java/jdk-21.0.12.1+1-jre/bin:$PATH`. **No `ruby`, no `xcrun`, no `shellcheck`** — the last two matter: CI found an SC2012 S103 could not have found locally (lesson **78**) |
| **Production** | 🟢 **UP** since 2026-09-03. ⚠️ **Nothing watches the bill** — operator **9**, still the most urgent thing on that page |
| **`main`** | green, and **`integration-emulator` actually RAN** on the S102 merge (34755195026) — the first real run since S101's failure. Check when it last ran, not when it last reported (lesson **160**) |
| **Push, device side** | **0 of 4 registered.** Build **121** on TestFlight, **uninstalled**; operator §4.4 records that it does not carry ADR-077 D1 |
| **The ADR index** | **78 records, 78 rows** with ADR-078; gated by ADR-067's lint |
| **The queue** | **18 open.** S102 closed #115 and #278 and filed #296; S103 closed nothing and **updated #15 rather than closing it**, deliberately |
| **Tests** | `flutter test` **1888** · `flutter analyze` clean · `dart format` clean (497 files) · `integration_watchdog_test` **46** (was 30) · `slack_notify_test` 25 · `shellcheck tool/ci/*.sh` clean **locally** |
| **Coverage** | ⚠️ **87.75% measured against a 68% gate** — this session's objective |

### What S103 changed that a later session will trip over

* **Every diagnostic in `integration_watchdog.sh`'s timeout path is now BOUNDED**,
  including the two that pre-date ADR-078. If you add another, use `run_bounded`:
  an unbounded call there can prevent `exit 124` and convert the job into the
  silent `cancelled` ADR-055 exists to eliminate (lesson **164**).
* **The boot step runs `log show` once on a healthy simulator** and warns if it
  returns nothing — ADR-078 D1.2's premise measured rather than assumed. Measured
  on the runner: **60,861 lines** from a freshly booted sim, so the mechanism
  exists. If it ever warns, the capture's control is broken **before** a wedge.
* ⚠️ **The wedge happened again during S103 (run 34759401891) and the instrument
  answered WRONGLY** — see ADR-078 **D1.3** and lesson **165**. The capture now
  prints the **delivered** log span beside the requested one and says
  **CANNOT MEASURE** when it does not reach the silence. **If you touch that
  block, keep that property**: a negative result over an unverified window is the
  most confident-looking output an instrument can produce.
* **`shellcheck` is installable here without `sudo`** — `session-context.md` §3
  now carries the three lines. S103 spent **two dispatches** learning that.
* **A wedged run writes `watchdog-device-log.txt`** to the workspace root and the
  job uploads it on failure. It is `.gitignore`d.

### Still true from earlier sessions

* **Open the ADR that owns the objective before planning** (lesson **145**), and
  check the objective before HANDING it on.
* **Cite a SYMBOL, not a line number** (lesson **144**).
* **A correction is finished when every COPY of it is gone** (lesson **141**).
* **`architecture.md` §7's first sentence is sentinel-parsed** — append after it.
* **`integration-emulator` never runs on a PR**, and does not re-run on a
  docs-only push to `main` (lesson **160**). `gh workflow run ci.yml --ref <branch>`
  is the documented way to get its verdict — S102 and S103 both used it.
* **`main` is protected** — squash-only, and a close commit needs its own PR.
* **git identity**: `Aytek E <62661118+aytekXR@users.noreply.github.com>`.

---

## 2. Then, in priority order

⚠️ **Re-derive this; never inherit it.** As measured at S103's close:

1. **This objective** — the coverage gate. The only unblocked engineering with a
   measured gap attached to it.
2. **#250** (Android Auto-Backup vs `SharedPreferences`) and **#13** — both real,
   both **M6.5/Gate-3 gated** by `roadmap.md`.
3. Everything else waits on **a secret (3)**, **a phone (4)**, **a lawyer (5)**,
   **a founder decision (6(a)–(d), 11)**, **a budget alert (9)**, or **content (7)**.

⚠️ **"No unblocked engineering" is a claim to re-derive every session.** S102
believed it and found three real pieces of work; S103 found a defect older than
its own objective. **Look before concluding.**

---

## 3. Blocked — re-check every line

| What | Blocked on | Why a session cannot take it alone |
|---|---|---|
| **Push reaching a phone** | the founder's phone | Operator 4; build 121 uninstalled |
| **A budget alert** | founder | Operator 9 — billing live and unwatched |
| **The four secrets** | founder | Operator 3; #165 and #263 are downstream |
| **Deploying the prod ruleset** | founder | #293 — 62 lines behind; a prod deploy, `session-context.md` §7 |
| **Publishing store copy** | founder | Operator 6(b), ADR-020 D8's undischarged review gate |
| **The Turkish name** | founder | 6(a), #204 |
| **The release lane** | founder | 6(c); #121 rides it |
| **#63 / the icon family** | founder | Operator **11**, asked with measured costs |
| **#296 / PR #172** | founder | The support and privacy URLs serve nothing; **VPS or Firebase Hosting** is one sentence — operator **6(d)** |
| **#71** | founder | A brandkit revision; its own body says *"this is not a bug"* |
| **#48**, **#136** | a device | Each issue says so in its own text |
| **#15** | the next occurrence | Instrumented by ADR-078; **do not close it** until a wedge is actually attributed |
| **#226**, **#243**, **#247** | founder / lawyer | Consent re-gate, a privacy decision, a vendor sink |
| **#242** | ADR-060 | Correctly unbuilt — no emitter before a sink |
| **#250**, **#13** | M6.5 | Gate-3 gated |

---

## 4. Close sequence — `session-rules.md` §3/§4

Append to `past-prompts.md` → regenerate this file (one objective) → refresh
`operator-expected.md` → commit + push → verify CI → **watch the post-merge `main`
run** → `codegraph sync`.

> ⚠️ **DO NOT SKIP THE CLOSE.** S100 and S101 both did, and S102 spent a third of
> itself reconstructing them from `git log`.

> ⚠️ **THE REVIEW RUNS TWICE** — design, then built diff. S103's design review
> found a **blocking** defect — an unbounded call that could prevent the watchdog
> firing at all — that no amount of reading the diff would have surfaced, because
> the defect was in code the diff did not touch.

> ⚠️ **WRITE THE ADR FIRST** (lesson **115**), with its index row. Next is **079**.

> ⚠️ **ASK WHAT WOULD STOP YOUR GUARD RUNNING AT ALL** (lesson **164**). Two
> consecutive sessions found a guard green over the thing it exists to catch.

> ⚠️ **AN INSTRUMENT'S WINDOW IS PART OF THE INSTRUMENT** (lesson **163**).
> Derive it from the thing being measured, and print it.

> ⚠️ **AN ABSENCE NEEDS A CONTROL THAT SHOULD PASS** (lesson **161**) — S102 hit
> this three times in one session, once in a founder-facing document.

> ⚠️ **A NUMBER IS A CLAIM AND THE COMMAND BESIDE IT MUST BE THE ONE YOU RAN**
> (lessons **133**, **149**, **153**). And `grep -c` **exits 1 when the count is
> zero**, so `$(grep -c … || echo 0)` prints the count AND the fallback.

> ⚠️ **MUTATION-CHECK EVERY GUARD *AND* THE TEST, IN BOTH DIRECTIONS** (standing).
> Enumerate the mutations **before** writing the guard, and **read the mutated
> file rather than the exit code** — S103 had a mutation that was itself broken
> and passed for the wrong reason.

> ⚠️ **A REFUTING VERIFIER CAN BE WRONG, AND ITS GROUNDS ARE CHECKABLE.** S102's
> panel returned REFUTED on a real finding by arguing about its *evidence* rather
> than its *claim*.

> ⚠️ **SAY WHICH HALF YOU PROVED AND WHICH HALF CI PROVED** (lesson **78**). This
> box has no `shellcheck`; S103's SC2012 could only ever have been found in CI.

> ⚠️ **FREEZE THE TREE BEFORE THE REVIEW** (lesson **113**); `git status` must be
> EMPTY after every review workflow returns.

> ⚠️ **SELF-REVIEW DOES NOT CATCH SELF-FLATTERY** (lesson **143**).
