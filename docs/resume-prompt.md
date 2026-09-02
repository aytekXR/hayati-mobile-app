# Resume Prompt — Session 098

> **This file contains ONE objective. That objective is the session; nothing else is.**
> (`project-rules.md` #1, `session-rules.md` §1.)
>
> Read `session-context.md` and `session-lessons.md` (numbered to **155**) first.
> Re-derive the session number from `git log`.
>
> ⚠️ **`session-context.md` §2/§3 changed again in S096** — the toolchain is
> mostly **restored** now (Flutter, Java, Dart, firebase-tools). Still measure it;
> the table is a claim like any other (lesson **146**).
>
> ⚠️ **BEFORE PLANNING, OPEN THE ADR THAT OWNS THIS OBJECTIVE** (lesson **145**).
> Here that is **ADR-072**, and S097 wrote it — read it as a claim to check. It is
> already reviewed pre-code and carries three corrections; start from it, not from
> the issue title.
>
> ⚠️ **AND POINT ONE LENS AT THE OBJECTIVE ITSELF** (lesson **154**). S097 found
> something interesting on the way to its objective and spent itself on that
> instead. **The tell is checkable: if your diff does not touch the file your
> acceptance criteria name, you have changed objective.**

**Objective: #281 — the publish lane's dry run exits `0` and calls it
"published" having published nothing, while the auditor exits `1` on the same
listing. Make them agree, and stop the lane voting.**

### ⚠️ First, three commands. Quote all three before planning.

```sh
for c in node npm python3 java dart flutter ruby gh git firebase; do printf '%-9s ' "$c"; command -v $c || echo MISSING; done
gh workflow run testflight-testers.yml -f store_metadata_audit=true    # the auditor's verdict
gh workflow run publish-store-metadata.yml                             # the publisher's — confirm BLANK, writes nothing
```

Measured 2026-09-02 (S097) — **re-measure, do not inherit**:

* `ruby`/`bundle` **MISSING**; everything else present. `flutter` and `java` are
  **not on PATH** — export them (`session-context.md` §3);
* **the two lanes disagree, and that is the objective**: the auditor exits **1**
  (seven `en-US` fields `PUBLISHED IS EMPTY`, `tr` absent), the publisher's dry
  run exits **0**, glossed as *published*, having sent nothing;
* `prod_pulse` still exits **2 — could not measure** (the instrument, not
  production — operator item 10).

### Why this, and what is already decided

**ADR-072 designed it and a pre-code review has already corrected it three
times** — so this session's job is to build a reviewed design, not to re-derive
it. The three corrections are the parts most likely to be got wrong:

1. **The data is not there.** `main` reads both resources and keeps only
   `{locale: id}`, throwing the attributes away, because ids are all a *writer*
   needs. Call `audit.published_locales()` in the dry-run path — it already
   merges both resources into the shape `audit_findings` wants, and the dry run
   stays read-only.
2. **The two paths are two implementations of one rule.** A dry run compares
   **before** the attempt; a write compares **after**, via the read-back. Do not
   go looking for a shared code path — the write path is **untouched**.
3. **The lane must stop voting.** Under the new rule a dry run over today's
   listing exits **1** forever, so without `continue-on-error: true` every run
   reddens — the cries-wolf failure with its sign flipped (ADR-047 D4's shape).

### Acceptance

1. **The three commands are run and quoted**, and the two lanes' disagreement is
   shown before and after.
2. **ADR-072 read first**, and its claims checked — S097 wrote it (lesson 145).
3. **A dry run over the current listing exits 1** and says how many fields would
   change; **over a matching listing exits 0**; **a successful write still exits
   0** via the untouched read-back path.
4. **The lane is green in both cases.** Its colour carries nothing.
5. **Self-tests for each, mutation-checked**, with any non-discriminating mutant
   **recorded rather than removed** (S095 and S096 each had one).
6. **An ADR amendment or a note committed BEFORE the code** if anything in
   ADR-072 turns out wrong, **with its index row in the same commit** — ADR-067's
   lint has caught three sessions.
7. **Re-run the dry run at the end and quote it.** The change is about what that
   run says; a session that does not run it has not verified it.

### What is NOT this session's

* ⚠️ **Writing to App Store Connect.** Operator **6(b)** carries the plan and is
  unanswered; **do not pass `confirm`.**
* **The Turkish name** (6(a)), **billing** (1), **the RevenueCat invoker** (2),
  **the four secrets** (3), **a build** (4), **the legal bundle** (5), **the
  firebase login** (10).
* **#136** — ADR-059 D3 decided it; **#71** — its own issue says *"this is not a
  bug"*. **Do not re-derive either.**

---

## 1. Where things stand *(measured 2026-09-02 — re-measure, do not inherit)*

| | State |
|---|---|
| **The dev box** | **Mostly restored** (S096): Flutter 3.44.5, Java 21, Dart 3.12.2, firebase-tools 15.22.4, node, python3, gh. **`ruby`/`bundle` still MISSING** — fastlane cannot run here. Flutter/Java **not on PATH**. ⚠️ git-over-HTTPS is intercepted on this network; Flutter's remote is on SSH |
| **Production** | 🔴 **DOWN since 2026-08-22**, and **unmeasurable from here** — operator 10 |
| **The App Store listing** | 🔴 **EMPTY and NOT SUBMITTABLE.** 7/9 `en-US` fields blank at Apple; `tr` absent; only `name` ever set |
| **The publish lane** | **BUILT, MERGED, AND RUN** — S097's dry run (33681088334) worked on first contact and confirmed four of ADR-071's assumptions. Its exit code is what #281 fixes |
| **Push, device side** | **STILL 0 of 4 registered** |
| **The ADR index** | **WHOLE — 72 records, 72 rows**, gated (ADR-067) |
| **#204 / #278** | **OPEN**, both founder-gated (6(a), 6(b), 6(c)) |
| **#281** | **OPEN — this session.** Designed and reviewed in ADR-072 |
| **#242 / #263** | OPEN and correctly blocked. Do not re-derive |

### What S096/S097 changed that a later session will trip over

* **`session-context.md` §2/§3 describe a restored toolchain**, including the SSH
  workaround Flutter needs on this network.
* **A workflow can write to the founder's live App Store listing.** Dispatch-only,
  dry-run by default, gated on a typed literal — but `confirm: PUBLISH` is the
  whole distance between a report and a publication.
* **`operator-expected.md` 6(b) now carries a real plan** rather than a question.
  If you change what the lane would do, **that block goes stale** — it quotes a
  specific run.
* **ADR-071's `except` clause was widened** after a `URLError` on one locale was
  found aborting the rest — #278's own defect inside the tool written to fix it
  (lesson **151**).

### Still true from earlier sessions

* **Open the ADR that owns the objective before planning** (lesson **145**), and
  check an objective before HANDING it on — S096 ruled out two candidates that way.
* **Cite a SYMBOL, not a line number** (lesson **144**).
* **A correction is finished when every COPY of it is gone** (lesson **141**).
* **`architecture.md` §7's first sentence is sentinel-parsed** — append after it.
* **`integration-emulator` never runs on a PR**; watch the post-merge `main` run.
* **Repeated pushes cancel the macOS gate**; verify `ios-build-smoke` actually
  COMPILED via `gh api repos/:owner/:repo/actions/jobs/<id>/logs`.
* `FORMAT_VERSION` is **3**, pinned by **four** assertions (lesson 108).
* **`main` is protected** — a close commit needs its own PR.
* **git identity** on this box: `Aytek E <62661118+aytekXR@users.noreply.github.com>`.

---

## 2. Then, in priority order

**1 — restore `ruby` + `bundle`**, the last missing toolchain: it is what stops a
session exercising a fastlane change, which **ADR-070 D3 and ADR-071 D1 both cite
as a reason for choosing a REST tool over a lane fix**. A download, no credential.
**2 — #121** (the dead `.p8` step in the release lane) — still needs a real
release run, so it rides operator 6(c). **3 — #63** (Phosphor vs the shipped
Material icons): ⚠️ **not simply a session's** — ADR-025 records it as a whole-app
decision, and its option (b) *"amend the brandkit to record what shipped"* is a
brand decision the founder has never been asked to make. **Putting that question
into `operator-expected.md` is a session's; answering it is not.**

⚠️ **After #281, be honest about the queue.** Every remaining open issue is
waiting on billing, a phone, a lawyer, a secret, or a decision on
`operator-expected.md`. A session that cannot find unblocked work should say so
and end per §4 — **S093 did exactly that and it was correct.**

⚠️ **#242, #136 and #71 are NOT in this list, deliberately** — each is decided or
blocked by an ADR, above and in §3.

---

## 3. Blocked — re-check every line

| What | Blocked on | Why a session cannot take it alone |
|---|---|---|
| 🔴 **Restoring billing** | **founder** | A closed account is a payment instrument on their Google identity. Everything server-side is downstream |
| 🔴 **Seeing whether production is alive** | **founder** | Operator 10 — the box has no `firebase login`; every local probe answers 2 |
| **Publishing ANY store copy** | founder | Operator 6(b): ADR-020 D8's review gate has never been discharged, and the copy is AI-drafted |
| **The Turkish localization** | founder | Apple refuses the **name** (6(a)) |
| **Exercising the release lane** | founder | Operator 6(c) |
| **Arming the watcher** | founder | `PROD_PULSE_VIEWER_SA`, operator 3 |
| **A build carrying everything since ADR-046** | founder | Last build **119**, cut 2026-08-09 |
| **M3.4's last inch** | the founder's phone | One permission grant |
| **Deploying rules/functions** | founder | §7, downstream of billing |
| **#226**, **#243** | founder / lawyer | A consent re-gate; a definitional sentence |
| **#136 step 1**, **#48**, **#15** | the device | On-device observation nobody has made |
| **An analytics vendor sink** | founder + lawyer | #247 |
| **#250**, **#13** | M6.5 | Gate-3 gated |
| **#115**, **#41**, **#63**, **#71** | founder | A world-reachable endpoint; a real RC key (#41 is operator item 0's); brandkit decisions |

---

## 4. Close sequence — `session-rules.md` §3/§4

Append to `past-prompts.md` → regenerate this file (one objective) → refresh
`operator-expected.md` → commit + push → verify CI → **watch the post-merge `main`
run** (`integration-emulator` is main-only) → `codegraph sync`.

> ⚠️ **THE REVIEW RUNS TWICE**, and S096 is the clearest case yet for why. Its
> design pass found ten real defects **including a tool that could not run at
> all**; its built-diff pass found the one thing no design pass could see — an
> `except AscError` that let a network error abort every remaining locale, which
> is the very defect the tool was written to prevent (lesson **151**).

> ⚠️ **WRITE THE ADR FIRST** (lesson **115**), with its index row.

> ⚠️ **Report `agents_error` and `agents_empty_result` as numbers**, and say
> whether an empty lens was **considered**-empty or **failed**-empty.

> ⚠️ **FREEZE THE TREE BEFORE THE REVIEW** (lesson **113**); `git status` must be
> EMPTY after every review workflow returns.

> ⚠️ **A NUMBER IS A CLAIM AND THE COMMAND BESIDE IT MUST BE THE ONE YOU RAN**
> (lessons **133**, **149**, **153**). Across S095 and S096 that went wrong **six
> times**: four counts, one truncated run read as a total, and one `grep` quoted
> without the `-i` that produced its own number — the last written while
> correcting the first.

> ⚠️ **ASK WHAT ELSE YOUR VERDICT IS COMPATIBLE WITH** (lesson **150**).

> ⚠️ **IF YOUR ADR DECLINES TO BUILD SOMETHING, POINT A LENS AT THAT DECISION**
> (lesson **147**) — and **check where the thing you are protecting actually
> lives** before deciding not to build the door (lesson **152**).

> ⚠️ **RUNNING THE THING IS THE DELIVERABLE** (lesson **154**). A defect found on
> the way to an objective goes to `gh issue create`, not into the diff. **If your
> diff does not touch the file your acceptance criteria name, you have changed
> objective** — and the technical lenses will not tell you, because they have no
> opinion about whether your work should exist. Point one lens at the objective.

> ⚠️ **TWO INSTRUMENTS OVER ONE SUBJECT MUST NOT RETURN OPPOSITE VERDICTS**
> (lesson **155**) — and check what the exit code's own GLOSS claims, because that
> is the half a human reads.

> ⚠️ **AN ISOLATION GUARANTEE IS ONLY AS WIDE AS ITS `except` CLAUSE**
> (lesson **151**). Enumerate what the layer below you actually raises; a suite
> written from the failure you have in mind tests the failure you have in mind.

> ⚠️ **SELF-REVIEW DOES NOT CATCH SELF-FLATTERY** (lesson **143**). **Seven**
> consecutive sessions have shipped an ADR whose worst error was caught by an
> outside reader comparing a claim to its source — never by a lens reading prose.
