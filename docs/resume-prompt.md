# Resume Prompt — Session 095

> **This file contains ONE objective. That objective is the session; nothing else is.**
> (`project-rules.md` #1, `session-rules.md` §1.)
>
> Read `session-context.md` and `session-lessons.md` (numbered to **145**) first.
> Re-derive the session number from `git log`.
>
> ⚠️ **BEFORE PLANNING, OPEN THE ADR THAT OWNS THIS OBJECTIVE AND READ ITS
> DECISION** (lesson **145**). S093 was handed an objective its own ADR had
> already declined, because the prompt was written from the issue title and the
> priority list. **This prompt makes a claim about #204's state; check it.**
> The ADR to read is **ADR-047**.

**Objective: #204 — `deliver` has failed to create the `tr` App Store
localization on EVERY release since build 112, and `continue-on-error` hid it.**

### ⚠️ First, two commands. Quote both before planning.

```sh
python3 tool/ci/prod_pulse.py --from-firebase-cli     # 0 = restored, 1 = still down
python3 tool/ci/push_delivery_probe.py --from-firebase-cli
```

Measured 2026-08-30 (S094) — **re-measure, do not inherit**: both exit **1**.
Neither is this session's — operator items 1 ① and 1 ② — but both bound what you
can claim.

### Why #204, and the part of it that is NOT yours

ADR-047 built the instrument: **positive evidence of publication per locale**,
expected from `fastlane/metadata/` and actual from App Store Connect, rather than
grepping Apple's error string. It found more than the issue claimed — **`tr` is
absent AND seven of `en-US`'s nine fields disagree with this ref**, so the
committed copy has never been published at all.

⚠️ **Apple refuses the app NAME for `tr`**, and that is a founder decision
(`resume-prompt` §3 has carried it for weeks). **Do not attempt to resolve the
name.** What may be a session's: whether the audit is *armed and running*, whether
the release lane still hides the failure, and whether `en-US`'s seven-field
disagreement is a separate, unblocked defect. **Establish which half you are in
before designing anything** — S093 was handed a similar shape and its objective
turned out to be decided already.

### Acceptance

1. **The two probes are run and quoted.**
2. **ADR-047 read first**, and this prompt's characterisation of #204 checked
   against it. Say plainly if the objective is already decided or already done —
   that is a legitimate and valuable outcome, not a failed session (S093).
3. **The store-metadata audit is RUN**, not assumed:
   `gh workflow run testflight-testers.yml -f store_metadata_audit=true`. It rides
   that workflow; there is no store-metadata workflow of its own.
4. **An ADR or slice design committed BEFORE code** (lesson **115**) **with its
   index row in the same commit** — ADR-067's gate makes a missing row a red
   build, and it has already caught two sessions.
5. **If the conclusion is "blocked on the founder", follow §4**: document the
   blocker on the issue, regenerate this file for the next unblocked task, and
   end. S093 did that; it is a clean outcome.

### What is NOT this session's

* **Restoring billing** (operator 1 ①), **cutting a build** (1 ②), **arming the
  watcher** (item 4), **landing the privacy revision** (item 16).
* **The `tr` app name.** Apple refuses it; the founder decides.
* **Dispatching the release lane.** It uploads a real binary (§7).

---

## 1. Where things stand *(measured 2026-08-30 — re-measure, do not inherit)*

| | State |
|---|---|
| **Production** | 🔴 **DOWN since 2026-08-22T02:00Z**, account closed and `billingEnabled` false on both projects |
| **Push, device side** | **STILL 0 of 4 registered** |
| **The ADR index** | **WHOLE — 69 records, 69 rows**, gated (ADR-067) |
| **The v3 privacy draft** | **All three disclosure items now DRAFTED** (#226 push, #249 consent record, #258 deletion). Operator item 16 asks for **one** decision. ⚠️ `CURRENT_LEGAL_VERSION` is **2** and all three sources agree; nothing has landed |
| **#248 / #249 / #253 / #258 / #267** | **CLOSED** by S091 / S092 / S089 / S094 / S090 |
| **#242** | **OPEN and correctly blocked** by ADR-060 D6 — no sink, #226 and #247 open. Do not re-derive; the reasoning is on the issue |
| **#263** | **OPEN** — the watcher is merged and unarmed |
| **#204** | **OPEN — this session** |
| **#226 / #247 / #243 / #250** | Unchanged; #226 and #243 need the founder |

### What S093/S094 changed that a later session will trip over

* **The v3 draft has now been corrected FOUR times without landing.** ADR-068 and
  ADR-069 both flag it: **if the count keeps climbing, question the landing, not
  the corrections.** A fifth correction should come with a hard look at whether
  the draft is ever going to be sent.
* **ADR-061 D5 is AMENDED, not overturned** (ADR-069). Its principle — do not
  widen a revision under review — stands, with one recorded exception whose
  premise is stated so it cannot be cited as general licence.
* **A blocked session is a legitimate outcome.** S093 refused its objective
  against ADR-060 D6 and ended per §4. Its entry in `past-prompts.md` has no
  commits and no CI, and that is correct.

### Still true from earlier sessions

* **Open the ADR that owns the objective before planning** (lesson **145**).
* **Cite a SYMBOL, not a line number** (lesson **144**).
* **A correction is finished when every COPY of it is gone** (lesson **141**) —
  violated in S092 and again in S094. **Grep for the claim's own words.**
* **`architecture.md` §7's first sentence is sentinel-parsed** — append after it.
* **The emulator suite can fail on a loaded box.** If you re-run, **say you re-ran**.
* **`integration-emulator` never runs on a PR**, and a docs-only merge produces a
  `main` green with it path-filtered away, measuring nothing.
* **Repeated pushes cancel the macOS gate**; verify `ios-build-smoke` actually
  COMPILED via `gh api repos/:owner/:repo/actions/jobs/<id>/logs`.
* `FORMAT_VERSION` is **3**, pinned by **four** assertions (lesson 108).
* **`main` is protected** — a close commit needs its own PR.

---

## 2. Then, in priority order

**1 — #165** (rules-drift is skipped until one read-only secret exists).
**2 — #121** (a dead step in the release lane). **3 — #63/#71** (brandkit).

⚠️ **#242 is NOT in this list**, and that is deliberate: it is blocked by
ADR-060 D6 until a sink exists, which runs through #226 → #247.

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

> ⚠️ **THE LAST FOUR SESSIONS EACH SHIPPED AN ADR WHOSE WORST ERROR WAS A CLAIM
> THAT FLATTERED ITS OWN ARGUMENT** (lesson **143**), and in every case only an
> outside reader comparing the claim to its source caught it. S092's design pass
> found **four** such inflations in one document. **Spend review agents on
> checking claims against sources, not only on lenses over the diff.**

> ⚠️ **A REFUSAL IS THE EASIEST THING IN AN ADR TO GET WRONG**, because nothing
> fails if it is wrong — the work simply does not happen. S092 refused a gate on
> a precedent that had **already been distinguished** (ADR-034, refused transfer
> by ADR-041) and framed out the middle option ADR-034 itself chose. If your ADR
> declines to build something, point a lens at that decision specifically.

> ⚠️ **FIVE CONSECUTIVE SESSIONS SHIPPED AN ADR WHOSE WORST ERROR WAS A CLAIM
> THAT FLATTERED ITS OWN ARGUMENT** (lesson **143**), caught every time by an
> outside reader comparing the claim to its source and never by a lens reading
> the diff. **Spend review agents on checking claims against sources.**

> ⚠️ **IF YOUR ADR DECLINES TO BUILD SOMETHING, POINT A LENS AT THAT DECISION.**
> A refusal is the easiest thing to get wrong because nothing fails when it is
> wrong — the work simply does not happen. S092's refusal rested on a precedent
> that had already been distinguished; S094's design pass found its ADR had
> argued around `session-rules.md` §4 rather than through it.
