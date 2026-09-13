# Resume Prompt — Session 103

> **This file contains ONE objective. That objective is the session; nothing else is.**
> (`project-rules.md` #1, `session-rules.md` §1.)
>
> Read `session-context.md` and `session-lessons.md` (numbered to **162**) first.
> Re-derive the session number from `git log`.
>
> ⚠️ **S100 and S101 wrote no `past-prompts.md` entry and never regenerated this
> file.** S102 reconstructed both from git and said so in the entry. If this
> prompt is the only thing you read, you will be reading a third-hand account —
> **open ADR-074/075/076/077 themselves**, they are first-hand.
>
> ⚠️ **BEFORE PLANNING, OPEN THE ADR THAT OWNS THIS OBJECTIVE** (lesson **145**).
> Here that is **ADR-055** — the watchdog — and it is worth reading as a success:
> it turned a silent `cancelled` into a named `failure`, exactly as designed. The
> objective below is the *next* question, not a complaint about that one.
>
> ⚠️ **AND CHECK THE OBJECTIVE ITSELF BEFORE BUILDING ANYTHING** (lessons **145**,
> **154**). S102's own queue pass produced **two wrong calls** that only reading
> the issues caught: it reported **#71** as unblocked engineering when #71's body
> says *"this is not a bug"* and names a brandkit-revision decision, and **#48**
> as unblocked when #48 says *"worth revisiting **on device**"*. **An agent's
> classification is a claim.**

**Objective: make the `integration-emulator` wedge EXPLAIN itself — and find out
whether the dependency that wedges can be removed (ci-debt #15 / #208).**

This suite has hung **three times** — S065 (#208, 38 minutes of silence), S088
(on a diff of docs and Python only), and S101's ADR-076 merge. Each time the
answer has been *"the known flake"*, and each time that has been correct and
useless. **It has now cost three sessions' attention and one six-day unexamined
red on `main`** (lesson **160**).

### ⚠️ First, four commands. Quote all four before planning.

```sh
gh run list --workflow ci.yml --branch main --limit 6 --json databaseId,headSha,conclusion
# then for each: gh run view <id> --json jobs -q '.jobs[]|"\(.name) \(.conclusion)"'
#   ^ lesson 160: "CI is green" is a claim about the last run that INCLUDED the job
gh issue list --state open --limit 40 --json number,title -q '.[]|"\(.number) \(.title[0:60])"' | sort -n
grep -n "simulator state" -A 20 tool/ci/integration_watchdog.sh
```

The second is the one that matters: **re-derive the queue.** S102 closed #115 and
#278 and filed **#296**, so it is **18**, not 19 — and a founder action since may
have unblocked something. Never inherit it.

### What is already known, so you do not re-derive it

S102 read the failing job log of run **34042187123** in full. At the moment the
watchdog fired, its own diagnostic block printed:

| | |
|---|---|
| the simulator | `hayati-ci (…) (Booted)` — **alive** |
| ports 8080 / 9099 / 5001 | **all three ANSWERING** — the emulators were fine |
| the suite | `No tests ran.` |
| the tool | **`Error waiting for a debug connection: The log reader failed unexpectedly`** |

So it is **not** the emulators, **not** a dead simulator, and **not** a slow
runner. `flutter test` never attached: it discovers the Dart VM service by
**scraping the simulator's system log**, and that reader failed. Everything after
that is silence by construction, because the tests never started.

### The two halves, and the second is the one that matters

**(1) Make it speak.** The watchdog's diagnostic block knows about the simulator
and the ports and nothing about the app. On timeout it should also capture, all
best-effort and never fatal (the block's existing discipline):

* the simulator's own log — `xcrun simctl spawn <udid> log show --last 5m --style compact`, or `log collect`;
* whether the app process exists at all — `xcrun simctl spawn <udid> launchctl list | grep hayati`;
* any crash report under `~/Library/Logs/DiagnosticReports`;
* a `sample`/`spindump` of the `dartvm` child, so a wedge inside Dart is distinguishable from never having connected;
* uploaded as an artifact (`actions/upload-artifact`, already used at `ci.yml:393`) rather than only inlined, because a `log show` is large.

**(2) Ask whether the dependency can be removed at all** — this is ADR-076's
argument in a different costume, and it is why this objective is worth a session.
*The app depends on log-scraping to be attached to, and nobody here chose that.*
Investigate `--device-vmservice-port` / `--host-vmservice-port` on
`flutter test integration_test/`, and whether a fixed port removes the reader
from the path. **Measure it; do not conclude it.** If it cannot be removed, say
so with the evidence and ship (1) alone — that is a complete session.

### Acceptance

1. **The four commands run and quoted**, and the queue re-derived rather than
   inherited from §3 below.
2. **ADR-055 read first**, and the watchdog's existing timeout block read before
   adding to it — it already handles "absent tools must not turn a useful
   timeout report into a second failure", and that discipline is kept.
3. **The instrumentation is PROVEN to fire, not asserted.** `integration_watchdog_test.sh`
   exists and is the right place; a new capture path that has never executed is
   a claim (lesson **161** — and an absence needs a control that should PASS).
   ⚠️ **And prove it in CI, not only locally**: the box has no `xcrun`, so every
   new branch is the `(not available)` branch here. `gh workflow run ci.yml --ref <branch>`
   runs `integration-emulator` on a branch — that is the documented way and S102
   used it.
4. **Part (2) answered either way, with the command that answered it.** *"A fixed
   VM-service port removes the log reader from the path"* and *"it does not"* are
   both good outcomes; *"it probably would"* is not.
5. **ADR written FIRST** (lesson **115**), with its index row — `dart tool/adr_index_lint.dart`
   is a real gate and will fail the build without the row. Next number is **078**.
6. **`ci-debt #15` is updated, not closed.** Unless the wedge is actually
   diagnosed, it stays open; ADR-077 D3 was careful about exactly this and the
   next session should be too.

### What is NOT this session's

* **A build, a release, a deploy.** Nothing on this objective needs one.
* **#63** — now operator item **11**, waiting on the founder. **Do not decide it.**
* **#71** and **#48** — see the warning at the top; both are gated and their own
  issue bodies say so.
* **#293** (the prod ruleset), **#242** (ADR-060), **#136**, **#226**, **#243**,
  **#247** — each decided or blocked by an ADR or an operator item.

---

## 1. Where things stand *(measured 2026-09-13 — re-measure, do not inherit)*

| | State |
|---|---|
| **The dev box** | `flutter` 3.44.5, `dart` 3.12.2, `java` 21, `node`, `python3`, `gh`, `firebase-tools` — **present but NOT on PATH**: `export PATH=~/flutter/bin:~/.local/share/java/jdk-21.0.12.1+1-jre/bin:$PATH`. **`ruby`/`bundle` still absent and that is fine** (ADR-073, lesson 158). **No `xcrun`, no `shellcheck`** |
| **Production** | 🟢 **UP** since 2026-09-03. `prod_pulse` exits **0**; the hourly sweep runs. ⚠️ **Nothing watches the bill** — operator 9 |
| **`main`** | green — but ⚠️ **the last run that actually RAN `integration-emulator` was S101's, and it FAILED**; three docs-only runs skipped past it (lesson **160**). S102's merge re-runs it for real |
| **Push, device side** | **STILL 0 of 4 registered.** Build **121** is on TestFlight, **uninstalled**, and §4.4 records that it does **not** carry ADR-077 D1 |
| **The App Store listing** | 🔴 EMPTY and NOT SUBMITTABLE. 7/9 `en-US` fields blank; `tr` absent (#204 → operator 6(a)) — **and its support/privacy URLs serve nothing** (#296 → operator **6(d)**, new at S102) |
| **The ADR index** | **WHOLE — 77 records, 77 rows**, gated by ADR-067's lint |
| **The queue** | **18 open**: S102 closed **#115** and **#278** on fresh measurement and filed **#296**. PR **#287** closed as superseded; **PR #172** now carries a stated blocker instead of dangling |
| **Tests** | `flutter test` **1888** at S102's merge · `flutter analyze` clean · `dart format` clean (497 files) |
| **#63** | **OPEN, and finally ASKED** — operator item **11**, with measured costs and no recommendation |

### What S102 changed that a later session will trip over

* **`device_privacy_channel_parity_test.dart` now derives its method sets from
  the two files** rather than walking a literal. Adding a channel method without
  pinning it is now a **red test** — that is deliberate, and the failure message
  says what to do.
* **The dartdoc's own method count is gated.** Editing
  `DevicePrivacyChannel`'s class comment without keeping the count and the
  bullets in step fails the suite.
* **A new sentinel pins a COMMENT**: `fcm_push_token_source_sentinel_test.dart`
  requires the phrase *"FALLS THROUGH"* in one catch block. It is load-bearing
  prose — the invariant it protects is the **absence** of a `return` — and
  ADR-077 D2 argues that case. Reword the comment and the suite goes red.
* **`operator-expected.md` gained item 11 and §4.4**, and its Blockers / Next
  Step / Next Session Goal were rewritten. If you change what build 121 means,
  **§4.4 goes stale** — it makes a specific promise about how to read a
  `captureExhausted` from it.

### Still true from earlier sessions

* **Open the ADR that owns the objective before planning** (lesson **145**), and
  check the objective before HANDING it on.
* **Cite a SYMBOL, not a line number** (lesson **144**).
* **A correction is finished when every COPY of it is gone** (lesson **141**).
* **`architecture.md` §7's first sentence is sentinel-parsed** — append after it.
* **`integration-emulator` never runs on a PR** — and now also **will not re-run
  on a docs-only push to `main`**, which is lesson **160**.
* **Repeated pushes cancel the macOS gate** on a PR ref; a `push` to `main` keys
  on the COMMIT and is never cancelled by the next one (ADR-024 D8).
* `FORMAT_VERSION` is **3**, pinned by **four** assertions (lesson 108).
* **`main` is protected** — a close commit needs its own PR.
* **git identity** on this box: `Aytek E <62661118+aytekXR@users.noreply.github.com>`.

---

## 2. Then, in priority order

⚠️ **Re-derive this; never inherit it.** As measured at S102's close, after this
objective the board is:

1. **This objective** — ci-debt #15/#208, above. The only unblocked engineering
   with a real cost attached to leaving it.
2. **#250** (Android Auto-Backup vs `SharedPreferences`, three places) — real,
   and **M6.5/Gate-3 gated** by the roadmap. Do not start it without saying why
   the gate does not apply.
3. **#13** (Android instant verification) — same gate.
4. Everything else waits on **a secret (3)**, **a phone (4)**, **a lawyer (5)**,
   **a founder decision (6(a)/6(b)/6(c), 11)**, **a budget alert (9)**, or
   **content (7)**.

⚠️ **"No unblocked engineering" is a claim to re-derive every session**, never to
inherit — and a founder action between sessions can change it without anyone
saying so. S102 found three real pieces of work while *believing* that claim.

---

## 3. Blocked — re-check every line

| What | Blocked on | Why a session cannot take it alone |
|---|---|---|
| **Push reaching a phone** | the founder's phone | Operator 4. Build 121 is on TestFlight and uninstalled; every link that can be measured from CI has been |
| **A budget alert** | founder | Operator 9, and the most urgent thing on the page — billing is live and unwatched |
| **The four secrets** | founder | Operator 3. `rules-drift` and `functions-drift` skip without them; #165 and #263 are downstream |
| **Deploying the prod ruleset** | founder | #293 — the live ruleset is **62 lines behind `main`**. A prod deploy, `session-context.md` §7 |
| **Publishing ANY store copy** | founder | Operator 6(b): ADR-020 D8's review gate has never been discharged, and the copy is AI-drafted |
| **The Turkish localization** | founder | Apple refuses the **name** — 6(a), #204 |
| **Exercising the release lane** | founder | Operator 6(c) — and #121's experiment rides it |
| **#63 / the icon family** | founder | Operator **11**, now asked with measured costs |
| **#71** | founder | A brandkit revision. **Its own body says "this is not a bug"** |
| **#48**, **#15**, **#136** | a device | Each issue says so in its own text |
| **#226**, **#243**, **#247** | founder / lawyer | A consent re-gate, a privacy decision, a vendor sink |
| **#242** | ADR-060 | Correctly unbuilt — no emitter before there is a sink |
| **#250**, **#13** | M6.5 | Gate-3 gated |
| **#296 / PR #172** | founder | ⚠️ **New, and a submission blocker.** The support and privacy URLs in `fastlane/metadata` point at `ikimiz.beyondkaira.com`, which **serves nothing** — TLS fails, HTTP 404, and the VPS certificate has no SAN for it (re-measured 2026-09-13; the cert was reissued in the interval and `ikimiz` still was not added). The AASA *is* fine, from `ikimiz.web.app`. **VPS or Firebase Hosting is one sentence from the founder**, and item 5 comes first either way — operator **6(d)** |

---

## 4. Close sequence — `session-rules.md` §3/§4

Append to `past-prompts.md` → regenerate this file (one objective) → refresh
`operator-expected.md` → commit + push → verify CI → **watch the post-merge `main`
run** (`integration-emulator` is main-only) → `codegraph sync`.

> ⚠️ **DO NOT SKIP THE CLOSE.** S100 and S101 both did, and S102 spent a third of
> itself reconstructing them from `git log`. Some of what those sessions knew is
> simply gone. `project-rules.md` #2 is two files and ten minutes.

> ⚠️ **THE REVIEW RUNS TWICE** — once on the design, once on the built diff.
> S102's review found its headline defect (the unpinned channel methods)
> **outside the diff under review**: the diff was three lines of control flow and
> the defect was in a test file nobody had touched. Point a lens at what the
> change *rests on*, not only at what it changes.

> ⚠️ **WRITE THE ADR FIRST** (lesson **115**), with its index row. The next number
> is **078** and `dart tool/adr_index_lint.dart` will fail the build without the row.

> ⚠️ **MUTATION-CHECK EVERY GUARD *AND* THE TEST, IN BOTH DIRECTIONS** (standing).
> S102's sentinel was **green over its own mutation** until the mutation was run:
> a `contains('_askApnsToRegister()')` scoped "up to the next `@override`" was
> satisfied by the private helper's own *declaration* with the call site deleted.

> ⚠️ **AN ABSENCE NEEDS A CONTROL THAT SHOULD PASS** (lesson **161**). A probe
> reporting "none" is the cheapest wrong answer there is, and nobody argues with
> a clean result.

> ⚠️ **A GUARD THAT WALKS A HAND-KEPT LIST IS ONLY AS COMPLETE AS THE LIST**
> (lesson **162**). Derive the inventory from the artefact, in both directions.

> ⚠️ **"CI IS GREEN" IS A CLAIM ABOUT THE LAST RUN THAT INCLUDED THE JOB**
> (lesson **160**). Check when the main-only jobs last actually RAN.

> ⚠️ **A NUMBER IS A CLAIM AND THE COMMAND BESIDE IT MUST BE THE ONE YOU RAN**
> (lessons **133**, **149**, **153**). S102 found two live examples: ADR-076's
> *"78 tests"* (unreproducible — 69 / 151 / 1883, each with its command) and
> three resume prompts' *"28 Material icons"* (it is **34 call sites, 23
> distinct**).

> ⚠️ **REPORT `agents_error` and `agents_empty_result` AS NUMBERS**, and say
> whether an empty lens was **considered**-empty or **failed**-empty.

> ⚠️ **FREEZE THE TREE BEFORE THE REVIEW** (lesson **113**); `git status` must be
> EMPTY after every review workflow returns. ⚠️ **S102's review agents wrote a
> file into the tree** — a test the session then kept, rewrote and mutation-tested,
> which is fine, but it was found by `git status` and not by anyone announcing it.

> ⚠️ **SELF-REVIEW DOES NOT CATCH SELF-FLATTERY** (lesson **143**). **Eight**
> consecutive sessions have shipped an ADR whose worst error was caught by an
> outside reader comparing a claim to its source — never by a lens reading prose.
