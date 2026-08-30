# Resume Prompt — Session 092

> **This file contains ONE objective. That objective is the session; nothing else is.**
> (`project-rules.md` #1, `session-rules.md` §1.)
>
> Read `session-context.md` (toolchain, machine, review discipline, the
> never-without-asking list) and `session-lessons.md` (numbered to **143**) first.
> Re-derive the session number from `git log`.

**Objective: #249 — the consent record is stored, is legally load-bearing, and is
named in no collection list.**

### ⚠️ First, two commands. Quote both before planning.

```sh
python3 tool/ci/prod_pulse.py --from-firebase-cli     # 0 = restored, 1 = still down
python3 tool/ci/push_delivery_probe.py --from-firebase-cli
```

Measured 2026-08-30 (S091) — **re-measure, do not inherit**: both exit **1**.
Production has been down since 2026-08-22; 0 of 4 devices have ever registered.
**Neither is this session's** — operator items 1 ① and 1 ② — but both bound what
you can claim.

### Why #249 is next

`users.consent` carries `version`, `acceptedAt` and `ageAttested`. It is
**server-owned** (ADR-023), it is what the product would show a regulator if
asked what a user agreed to and when, and **it appears in no collection list** —
not in `dpa-inventory.md`, and not in the privacy notice's own enumeration of
what is stored. That is the same defect class as **#226** and **ADR-058**: a
document describing a system that does not match the one that runs, on the
surface where being wrong is most expensive.

It is also the cheapest of the remaining legal-adjacent items and the only one
that needs neither the founder nor the lawyer to **start** — the drafting is a
session's; the landing is theirs.

### Acceptance

1. **The two probes are run and quoted** before anything is designed.
2. **Measure what is actually stored before writing a word about it.** Read the
   write sites (`recordConsent`, the rules freeze, `profile_dto.dart`) and say
   which fields exist, which are server-owned, and what the cascade and the
   export lane (ADR-054) already do with them. #249's title is a claim; check it.
3. **An ADR or slice design committed BEFORE code** (lesson **115**), saying
   which instrument you wrote.
4. **Decide explicitly whether this lands in the shipped notice or the v3 draft.**
   The draft is already awaiting the founder and lawyer (**#226**, operator item
   16) and has now been rewritten three times; adding a fourth note has a cost.
   Changing the *shipped* text is a consent re-gate and is not a session's to do.
5. **If a document gains a list, the list gets a guard or an explicit refusal.**
   ADR-067 is one session old and exists because an index nobody guarded fell
   eighteen behind. Do not add a nineteenth unguarded list without saying why.

### What is NOT this session's

* **Restoring billing** (operator 1 ①) and **cutting a build** (operator 1 ②).
* **Arming the watcher** — operator item 4's `PROD_PULSE_VIEWER_SA`.
* **Landing the privacy revision** — that is #226 and the founder's.

---

## 1. Where things stand *(measured 2026-08-30 — re-measure, do not inherit)*

| | State |
|---|---|
| **Production** | 🔴 **DOWN since 2026-08-22T02:00Z.** Account `012195-7EF76F-3A9083` closed **and `billingEnabled` false on BOTH projects**. Last completed sweep **2026-08-25T15:00:11Z** |
| **`prod_pulse`** | Correct for all four billing states (ADR-066) — **verified in live use this session** |
| **The watcher** | BUILT and MERGED (ADR-064), **UNARMED**; the armed path is still unexercised |
| **Push, device side** | **STILL 0 of 4 registered** |
| **The ADR index** | **WHOLE — 67 records, 67 rows** — and guarded by `adr_index_lint.dart` in `quality` (ADR-067). **Writing an ADR without its index row is now a red build** |
| **#248 / #253 / #267** | **CLOSED** by S091 / S089 / S090 |
| **#263** | **OPEN** — the watcher is merged and unarmed, so open is honest |
| **#226 / #243 / #242 / #247 / #249 / #250 / #258** | Unchanged; **#249 is this session** |
| **Deployed rules vs `main`** | **DRIFTED** — downstream of billing |

### What S091 changed that a later session will trip over

* **An ADR without an index row is now a RED BUILD.** Write the row in the same
  commit as the record — it is one row, paid by the person holding the context.
* **Escape `|` as `\|` in an index row, even inside backticks.** GFM does not let
  a code span protect a pipe in a table; shipped row 042 had been losing its
  Status to a fourth column since it landed.
* **The lint guards PRESENCE, not meaning.** A green lint does not mean a good
  index: 5 of 19 rows written this session were inaccurate and the lint passed
  every one of them. If you add a row, have something read it against its ADR.
* **A numbering gap is legal** and the lint asserts it stays legal. Do not "fix"
  a hole in the sequence.

### Still true from earlier sessions

* **`architecture.md` §7's first sentence is sentinel-parsed** — append after it.
* **The emulator suite can fail on a loaded box.** If you re-run, **say you re-ran**.
* **`integration-emulator` never runs on a PR**, and a docs-or-tooling-only merge
  produces a `main` green with it path-filtered away, measuring nothing.
* **Repeated pushes cancel the macOS gate**; verify `ios-build-smoke` actually
  COMPILED via `gh api repos/:owner/:repo/actions/jobs/<id>/logs`.
* **Do not hand-roll a Unicode range** (lesson 124).
* `FORMAT_VERSION` is **3**, pinned by **four** assertions (lesson 108).
* **`main` is protected** — a close commit needs its own PR.

---

## 2. Then, in priority order

**1 — #242** (the server three have no emitter; waits on a sink). **2 — #258**
(the legal draft under-describes deletion once #246 landed). **3 — #204**.

**4 — #165** · **#121** · **#115** · **#41** · **#63/#71**.

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

> ⚠️ **SELF-REVIEW DOES NOT CATCH SELF-FLATTERY** (lesson **143**). S091 wrote a
> box criticising an earlier revision for overstating in its own favour, then
> overstated in its own favour three times in the same session. The only thing
> that caught it was an agent whose sole job was to compare one claim to its
> source. **When a change produces claims ABOUT its own subject, spend agents on
> checking each claim against its source** — not only on lenses over the diff.

> ⚠️ **A STATUS WORD THAT ALSO APPEARS IN PROSE IS NOT A STATUS MARKER**
> (lesson **142**). A review harness reported a lens as FAILED-empty because the
> lens's prose contained the word "blocked". Put the classification in its own
> field, or require the marker at the START of the note.
