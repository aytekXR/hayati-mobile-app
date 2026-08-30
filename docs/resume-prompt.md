# Resume Prompt — Session 093

> **This file contains ONE objective. That objective is the session; nothing else is.**
> (`project-rules.md` #1, `session-rules.md` §1.)
>
> Read `session-context.md` (toolchain, machine, review discipline, the
> never-without-asking list) and `session-lessons.md` (numbered to **144**) first.
> Re-derive the session number from `git log`.

**Objective: #242 — the three server-side money events (`trial_start`, `paid`,
`churn`) are specified, are named in `architecture.md` §7, and have no emitter.**

### ⚠️ First, two commands. Quote both before planning.

```sh
python3 tool/ci/prod_pulse.py --from-firebase-cli     # 0 = restored, 1 = still down
python3 tool/ci/push_delivery_probe.py --from-firebase-cli
```

Measured 2026-08-30 (S092) — **re-measure, do not inherit**: both exit **1**.
**Neither is this session's** — operator items 1 ① and 1 ② — but both bound what
you can claim. ⚠️ The first may report an **HTTP 429** gap on the Logging API;
that is a named gap, not a finding, and re-running usually clears it.

### Why #242 is next, and the trap in it

ADR-060 decided **where** the three events are emitted — at the RevenueCat
webhook, *where the decision is made*, rather than inferred later from a mirror.
The decision exists; the emitter does not. This is the same shape as #253 was
before S089: **a feature that is wrong rather than unshipped.**

⚠️ **The trap is that it looks blocked and is only half-blocked.** There is no
analytics sink in production (ADR-057: prod is wired to a no-op), and a vendor
adapter needs a legal change first (**#247**, **#226**). So *delivering an event
to a vendor* is blocked. **Emitting it into the port that already exists is
not** — the app already does exactly that for eight events, into a no-op, and
that is how #242's own body describes the gap. Decide explicitly which half you
are doing and say so.

### Acceptance

1. **The two probes are run and quoted** before anything is designed.
2. **Read ADR-060 first and say what it already decided.** #242 is its unbuilt
   half. An ADR that re-decides what ADR-060 decided is the failure mode; an ADR
   that says *"ADR-060 D-n covers this, here is only what it left open"* is the
   shape.
3. **An ADR or slice design committed BEFORE code** (lesson **115**), **with its
   index row in the same commit** — the ADR-067 gate makes a missing row a red
   build, and it has already caught one session.
4. **The webhook is the one server path that handles money.** Any change to it
   states what happens on a replayed event, an out-of-order event, and an event
   for a couple that no longer exists. ADR-013/014/015 decided those; do not
   re-decide them, but say which of them your emitter sits inside.
5. **Do not create a join key.** ADR-062 refused one, twice, for a reason: this
   product will not put an account identifier on anything it counts. If the
   events feel unusable without one, that is #243 and it is a founder decision.

### What is NOT this session's

* **Restoring billing** (operator 1 ①) and **cutting a build** (operator 1 ②).
* **Arming the watcher** — operator item 4's `PROD_PULSE_VIEWER_SA`.
* **Landing the privacy revision** — #226, and now the whole of operator item 16.
* **Building a vendor adapter.** #247 says the legal change comes first, and
  ADR-057 says prod ships a no-op deliberately.

---

## 1. Where things stand *(measured 2026-08-30 — re-measure, do not inherit)*

| | State |
|---|---|
| **Production** | 🔴 **DOWN since 2026-08-22T02:00Z**, account closed and `billingEnabled` false on both projects |
| **`prod_pulse`** | Correct for all four billing states (ADR-066), verified in live use |
| **The watcher** | BUILT, MERGED, **UNARMED**; the armed path is still unexercised |
| **Push, device side** | **STILL 0 of 4 registered** |
| **The ADR index** | **WHOLE — 68 records, 68 rows**, guarded (ADR-067). **An ADR without its row is a red build** |
| **#248 / #249 / #253 / #267** | **CLOSED** by S091 / S092 / S089 / S090 |
| **#263** | **OPEN** — the watcher is merged and unarmed, so open is honest |
| **#226 / #258** | Open, and **operator item 16 now carries them with #249's landing as ONE decision** |
| **#242** | **OPEN — this session** |
| **#243 / #247 / #250** | Unchanged; #243 needs the founder |
| **Deployed rules vs `main`** | **DRIFTED** — downstream of billing |

### What S092 changed that a later session will trip over

* **The v3 privacy draft gained a bullet** (the consent record). It is **draft
  only** — `app/assets/legal/` is untouched, `CURRENT_LEGAL_VERSION` is still
  **2**, and both are asserted in the diff. Do not "sync" them.
* **`docs/legal/README.md` now has SIX lawyer questions**, not five. The sixth is
  whether the age attestation is named separately or folded.
* **A non-voting disclosure note sits above the export interfaces** in
  `data-rights-core.ts`. If you add an export lane, it is asking you a question:
  does the notice name it? There is deliberately **no check** — ADR-068 D3 says
  why, and half of that reasoning was demolished by its own review, so read the
  ADR rather than the summary.

### Still true from earlier sessions

* **Cite a SYMBOL, not a line number** (lesson **144**): S092 corrected a line
  citation and its own diff made the correction stale in the same commit.
* **A correction is finished when every COPY of it is gone** (lesson **141**) —
  violated again in S092, in three places, by the session that wrote the lesson.
  **Grep for the claim's own words before saying it is fixed.**
* **`architecture.md` §7's first sentence is sentinel-parsed** — append after it.
* **The emulator suite can fail on a loaded box.** If you re-run, **say you re-ran**.
* **`integration-emulator` never runs on a PR**, and a docs-or-tooling-only merge
  produces a `main` green with it path-filtered away, measuring nothing.
* **Repeated pushes cancel the macOS gate**; verify `ios-build-smoke` actually
  COMPILED via `gh api repos/:owner/:repo/actions/jobs/<id>/logs`.
* `FORMAT_VERSION` is **3**, pinned by **four** assertions (lesson 108).
* **`main` is protected** — a close commit needs its own PR.

---

## 2. Then, in priority order

**1 — #258** (the legal draft under-describes deletion; drafted alongside #226 in
operator item 16). **2 — #204** (the `tr` store localization has failed on every
release since build 112). **3 — #165**.

**4 — #121** · **#115** · **#41** · **#63/#71**.

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
