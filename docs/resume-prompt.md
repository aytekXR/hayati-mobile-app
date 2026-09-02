# Resume Prompt — Session 099

> **This file contains ONE objective. That objective is the session; nothing else is.**
> (`project-rules.md` #1, `session-rules.md` §1.)
>
> Read `session-context.md` and `session-lessons.md` (numbered to **157**) first.
> Re-derive the session number from `git log`.
>
> ⚠️ **`session-context.md` §2/§3 changed again in S096** — the toolchain is
> mostly **restored** now (Flutter, Java, Dart, firebase-tools). Still measure it;
> the table is a claim like any other (lesson **146**).
>
> ⚠️ **BEFORE PLANNING, OPEN THE ADR THAT OWNS THIS OBJECTIVE** (lesson **145**).
> Here that is **ADR-032 D4**, which *kept* the step this session is about and
> said exactly what it lacked. Read it as the thing to discharge, not to re-argue.
>
> ⚠️ **AND POINT ONE LENS AT THE OBJECTIVE ITSELF** (lesson **154**). **If your
> diff does not touch the file your acceptance criteria name, you have changed
> objective.**

**Objective: #121 — settle whether `release.yml`'s `write App Store Connect API
key` step is dead, by READING THE INSTALLED FASTLANE rather than by waiting for a
release run.** Restore `ruby` + `bundle` (the last missing toolchain) and use the
gem source to answer the question ADR-032 D4 recorded as unanswerable from here.

### ⚠️ First, three commands. Quote all three before planning.

```sh
for c in node npm python3 java dart flutter ruby bundle gh git firebase; do printf '%-9s ' "$c"; command -v $c || echo MISSING; done
gh workflow run publish-store-metadata.yml     # confirm BLANK — writes nothing
gh issue view 121 --json body -q .body
```

⚠️ **`java`, `dart` and `flutter` read MISSING until you export PATH** — they are
installed (`session-context.md` §3). `ruby`/`bundle` are the genuinely absent
ones, and restoring them is step one of this objective.

### Why this is the objective, and why it is not a release run

Everything else is operator-blocked — re-derived, not inherited, at the end of
S098 (§3). **#121 is the one open issue whose central question can be answered
without the founder**, and only because the answer lives in a gem this box can
now install.

`release.yml` writes the App Store Connect `.p8` to xcodebuild's auto-discovery
path, `$HOME/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID}.p8`. That step
exists for **ADR-021 D5's cloud signing**, which ADR-032 replaced with fastlane
`match`. The issue's own evidence says nothing reads it any more — and
**ADR-032 D4 KEPT it anyway**, on ADR-029 D2's precedent: *"very likely dead" is
not "proven dead"*, and the cost of being wrong is a broken release the founder
cannot debug.

**That precedent is about not making a blind EDIT. It is not a reason to avoid
LOOKING** — and *query the platform, not the docs* is this repo's standing rule.
`fastlane`'s own source will say whether `app_store_connect_api_key`, `match`,
`pilot` or `deliver` ever consults that path, and whether `xcodebuild
-allowProvisioningUpdates` still needs it under **manual** signing with an
explicit `ExportOptions.plist`.

### Acceptance

1. **The three commands are run and quoted**, with `ruby`/`bundle` restored and
   the version `Gemfile.lock` pins (`fastlane 2.237.0`) actually installed.
2. **ADR-032 D4 and #121 read first**, and D4's bound quoted before any
   conclusion. **It is a bound on editing, not on reading — say so explicitly.**
3. **The question answered FROM THE GEM SOURCE**, with file paths and quoted
   lines from the installed fastlane, not from documentation and not from memory.
   ⚠️ **Only the vendor can refute a vendor API shape** — the gem *is* the vendor.
4. **Say plainly which half is proven** (lesson **78**): reading the source can
   prove *"nothing in these lanes reads that path"*; it **cannot** prove
   *"xcodebuild never reads it"*, because `xcodebuild` is not in the gem. If the
   answer needs a real run, **say so and stop** — that is a clean outcome.
5. **If it is proven dead**: delete the step, amend **ADR-032 D4** with the
   evidence, and **an ADR or amendment committed BEFORE the code** with its index
   row in the same commit.
6. **If it is NOT proven dead**: leave it, and write down *what* consults the path
   — the issue itself says that is a genuinely useful fact worth recording rather
   than re-deriving.
7. ⚠️ **Do NOT dispatch the release lane.** §7, and operator 6(c) is unanswered.

### What is NOT this session's

* **Dispatching `release.yml`** (6(c)), **writing to App Store Connect** (6(b)),
  **the Turkish name** (6(a)), **billing** (1), **the invoker** (2), **the four
  secrets** (3), **a build** (4), **the legal bundle** (5), **the firebase
  login** (10).
* **#136** — ADR-059 D3 decided it. **#71** — its own issue says *"this is not a
  bug"* and ADR-025 D5.ii decided the arrangement is correct. **#242** — ADR-060
  D6. **Do not re-derive any of the three.**
* **#63** — ADR-025 records it as a whole-app decision. ⚠️ **Putting the question
  into `operator-expected.md` IS a session's and has never been done**; answering
  it is not. Do that only if #121 closes early.

---

## 1. Where things stand *(measured 2026-09-02 — re-measure, do not inherit)*

| | State |
|---|---|
| **The dev box** | **Mostly restored** (S096): Flutter 3.44.5, Java 21, Dart 3.12.2, firebase-tools 15.22.4, node, python3, gh. **`ruby`/`bundle` still MISSING** — fastlane cannot run here. Flutter/Java **not on PATH**. ⚠️ git-over-HTTPS is intercepted on this network; Flutter's remote is on SSH |
| **Production** | 🔴 **DOWN since 2026-08-22**, and **unmeasurable from here** — operator 10 |
| **The App Store listing** | 🔴 **EMPTY and NOT SUBMITTABLE.** 7/9 `en-US` fields blank at Apple; `tr` absent; only `name` ever set |
| **The publish lane** | **BUILT, RUN, AND HONEST.** Since #281 its dry run exits **1** — agreeing with the auditor — and the lane does not vote. Run 33686025994: *15 field(s) would change* |
| **Push, device side** | **STILL 0 of 4 registered** |
| **The ADR index** | **WHOLE — 72 records, 72 rows**, gated (ADR-067) |
| **The queue** | ⚠️ **After #281, every open issue but #121 is operator-blocked** — re-derived at the end of S098 from `gh issue list`, not inherited. **Re-derive it again** |
| **#204 / #278** | **OPEN**, both founder-gated (6(a), 6(b), 6(c)) |
| **#121** | **OPEN — this session** |
| **#281** | **CLOSED** by S098 |
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
