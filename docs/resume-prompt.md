# Resume Prompt — Session 100

> **This file contains ONE objective. That objective is the session; nothing else is.**
> (`project-rules.md` #1, `session-rules.md` §1.)
>
> Read `session-context.md` and `session-lessons.md` (numbered to **159**) first.
> Re-derive the session number from `git log`.
>
> ⚠️ **`session-context.md` §2/§3 changed again in S096** — the toolchain is
> mostly **restored** now (Flutter, Java, Dart, firebase-tools). Still measure it;
> the table is a claim like any other (lesson **146**).
>
> ⚠️ **BEFORE PLANNING, OPEN THE ADR THAT OWNS THIS OBJECTIVE** (lesson **145**).
> Here that is **ADR-025 Appendix A**, which records this as a *whole-app
> decision* and cites #63 rather than asserting compliance. **Read it as the
> reason this is the founder's, not as a design to implement.**
>
> ⚠️ **AND CHECK THE OBJECTIVE ITSELF BEFORE BUILDING ANYTHING** (lessons **145**,
> **154**). S099's prompt named #121 as open when **ADR-056 D4 had already
> decided it** — the corollary landing on a prompt, one session after that lesson
> was cited in it. **This prompt makes a claim too: that #63's question has never
> been put to the founder. Check `operator-expected.md` before believing it.**

**Objective: #63 — put the icon-family decision to the founder.** The brandkit
specifies **Phosphor**; the app ships **28 Material `Icons.*`** and Phosphor is
not a dependency. ADR-025 records the divergence honestly and cites this issue —
but **nobody has ever asked the founder which way to resolve it.**

### ⚠️ First, three commands. Quote all three before planning.

```sh
grep -c "Icons\." app/lib -r ; grep -rn "phosphor" app/pubspec.yaml || echo "phosphor: absent"
gh workflow run publish-store-metadata.yml            # confirm BLANK — writes nothing
gh issue list --state open --limit 40 --json number,title -q '.[]|"\(.number) \(.title[0:60])"' | sort -n
```

The third one is the one that matters: **re-derive the queue.** S098 and S099
both found it entirely operator-blocked below their own objective, and that claim
expires — an issue may have been unblocked by a founder action since.

### Why this, and what a session may and may not do

ADR-025 Appendix A states the shipped rule — *one consistent icon family at a
consistent weight; today that is Material outline* — and names two ways out:

* **(a) migrate to Phosphor** — a dependency, 28 call sites, the RTL mirror net
  reworked (Material icons auto-mirror via `matchTextDirection`; Phosphor glyphs
  do not), a second icon font against the size cap, and a full golden re-baseline;
* **(b) amend the brandkit** to record Material outline as the shipped system, the
  way §10 already records the contrast exception.

**Both are the founder's call — it is their brand.** ⚠️ **What is a session's is
putting the question, with its costs, where they will see it.** That has never
been done, and it is the whole objective. **Do not pick (b) because it is
cheaper.**

### Acceptance

1. **The three commands run and quoted**, and the queue re-derived rather than
   inherited from §3 below.
2. **ADR-025 Appendix A and #63 read first**, and this prompt's claim — that the
   question has never been put — **checked against `operator-expected.md`**. If it
   is already there, say so and stop: that is a clean outcome.
3. **`operator-expected.md` gains the decision**, with **both** options, their
   real costs (the mirror-net rework and the golden re-baseline are the expensive
   part of (a), not the dependency), and a plain statement that either is
   defensible. ⚠️ **Do not recommend one.** ADR-025 already leans, and repeating
   the lean as advice is how a founder decision becomes a session's by attrition.
4. **No code, no `pubspec.yaml` change, no golden touched.** If the diff contains
   a `.dart` file you have changed objective (lesson **154**).
5. **If the queue turns out to have something unblocked and larger**, take that
   instead and say why — this objective is small on purpose, because it is what
   was left.

### What is NOT this session's

* **Choosing (a) or (b).** The founder's brand, the founder's call.
* **#121's experiment** — operator 6(c). **Publishing store copy** — 6(b).
* **Billing** (1), **the invoker** (2), **the four secrets** (3), **a build** (4),
  **the legal bundle** (5), **the firebase login** (10).
* **#136** (ADR-059 D3), **#71** (its own issue says *"this is not a bug"*),
  **#242** (ADR-060 D6). **Do not re-derive any of the three.**

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
| **#121** | **OPEN** — fastlane half PROVEN inert (ADR-073); the xcodebuild half needs 6(c) |
| **#63** | **OPEN — this session**, and it is a question to ASK, not to answer |
| **#281** | **CLOSED** by S098 |
| **The toolchain** | Flutter/Java/Dart/firebase-tools restored; **`ruby` still absent and that is fine** — ADR-073 read the gem with `tar`, and `ruby-full` would need `sudo` (lesson **158**) |
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

⚠️ **There is no priority list any more, and that is the finding.** S098 and
S099 each re-derived the queue and found everything below their own objective
waiting on billing, a phone, a lawyer, a secret, or a decision on
`operator-expected.md`. After #63's question is asked, **a session should expect
to end per §4** — and that is a clean outcome, not a failure (S093's precedent).

⚠️ **Re-derive it anyway.** *"No unblocked engineering"* is a claim to re-derive
every session, never to inherit — and a founder action between sessions can
change it without anyone saying so.

**`ruby` is deliberately NOT on this list.** ADR-073 answered #121's fastlane half
by reading the gem with `tar`; installing `ruby-full` needs `sudo` and would make
an operator dependency out of nothing (lesson **158**). Install it when something
needs to *run* fastlane, which is a release run, which is 6(c).

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
