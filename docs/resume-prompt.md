# Resume Prompt — Session 097

> **This file contains ONE objective. That objective is the session; nothing else is.**
> (`project-rules.md` #1, `session-rules.md` §1.)
>
> Read `session-context.md` and `session-lessons.md` (numbered to **153**) first.
> Re-derive the session number from `git log`.
>
> ⚠️ **`session-context.md` §2/§3 changed again in S096** — the toolchain is
> mostly **restored** now (Flutter, Java, Dart, firebase-tools). Still measure it;
> the table is a claim like any other (lesson **146**).
>
> ⚠️ **BEFORE PLANNING, OPEN THE ADR THAT OWNS THIS OBJECTIVE** (lesson **145**).
> Here that is **ADR-071**, and S096 wrote it — read it as a claim to check.

**Objective: RUN THE DRY RUN. Exercise `publish-store-metadata.yml` against the
real App Store Connect for the first time, fix what first contact reveals, and
put the resulting plan in front of the founder so operator 6(b) becomes
answerable.**

### ⚠️ First, three commands. Quote all three before planning.

```sh
for c in node npm python3 java dart flutter ruby gh git firebase; do printf '%-9s ' "$c"; command -v $c || echo MISSING; done
gh workflow run testflight-testers.yml -f store_metadata_audit=true    # the listing today
gh workflow run publish-store-metadata.yml                             # THE OBJECTIVE — confirm blank = dry run
```

Measured 2026-09-02 (S096) — **re-measure, do not inherit**:

* `ruby`/`bundle` **MISSING**; everything else present. `flutter` and `java` are
  **not on PATH** — export them (`session-context.md` §3);
* the audit exits **1**: seven `en-US` fields `PUBLISHED IS EMPTY`, `tr` absent;
* `prod_pulse` still exits **2 — could not measure** (the instrument, not
  production — operator item 10).

### Why this, and why it is not just "press the button"

**The tool has never run against Apple.** ADR-071 says so in three places and
D5's read-back exists because of it. Its request shapes are the JSON:API form
this repo uses for `betaGroups`; **nobody here has seen what the REST API returns
for the `tr` name refusal** — #204's quote is a Ruby `Spaceship` wrapper. First
contact with a real API finds things. That is the session.

⚠️ **A dry run writes NOTHING and needs no permission.** `confirm` blank →
`store_metadata_publish.py` with no `--confirm` → `MODE_DRY_RUN` → `execute`
returns before any request. It reads (to resolve the app, the editable version,
the appInfo id and the existing localizations) and then prints the plan. This is
the ADR-047 D6 precedent — the read-only side door — one tool over.

**And the plan is the deliverable.** Operator **6(b)** asks the founder whether
the AI-drafted English copy may be published at all. What they need in order to
answer is exactly what would be written. Nobody has ever shown them that.

### Acceptance

1. **The three commands are run and quoted**, and `prod_pulse`'s exit 2 is
   reported as an **instrument** outage, not a production reading.
2. **ADR-071 read first**, and its claims checked — S096 wrote it. In particular
   check **D3's assumed-versus-known table**: if the real run contradicts it, that
   is the session's most valuable finding, not an inconvenience.
3. **The dry run is dispatched and its full output quoted.** If it exits **2**,
   say which fact could not be measured; **2 is not 1** (ADR-041, ADR-047 D4).
4. **Whatever it reveals is fixed**, with an **ADR or an amendment committed
   BEFORE the code** (lesson **115**) and its **index row in the same commit** —
   ADR-067's lint has now caught three sessions.
5. **The plan is put in front of the founder**: `operator-expected.md` item 6(b)
   gains the actual per-locale, per-field plan (names and counts — **never the
   store's own text**, ADR-070 D7.4; this repo is public).
6. ⚠️ **DO NOT PASS `confirm`.** Operator **6(b)** and **6(c)** are both open, and
   a write publishes AI-drafted copy nobody has reviewed to a real Apple listing.
   A wrong value is REFUSED (exit 64) by design — do not test that against
   production either.
7. **If the dry run cannot run at all** (a credential the lane does not see, an
   input shape GitHub rejects), that is a real finding about the lane S096 built.
   Fix it, and say plainly that ADR-071's *"the dry run is the deliverable"* was
   untested when it was written.

### What is NOT this session's

* **Writing anything to App Store Connect.** Operator 6(b)/6(c).
* **The Turkish name** (6(a)) — Apple refuses it; the founder decides.
* **Restoring billing** (1), **the RevenueCat invoker** (2), **the four secrets**
  (3), **cutting a build** (4), **the legal bundle** (5), **the firebase login**
  (10).
* **#136** — ADR-059 D3 has already decided it, and its remaining step needs a
  phone. **#71** — its own issue says *"This is not a bug"* and ADR-025 D5.ii
  decided the current arrangement is correct. **Do not re-derive either.**

---

## 1. Where things stand *(measured 2026-09-02 — re-measure, do not inherit)*

| | State |
|---|---|
| **The dev box** | **Mostly restored** (S096): Flutter 3.44.5, Java 21, Dart 3.12.2, firebase-tools 15.22.4, node, python3, gh. **`ruby`/`bundle` still MISSING** — fastlane cannot run here. Flutter/Java **not on PATH**. ⚠️ git-over-HTTPS is intercepted on this network; Flutter's remote is on SSH |
| **Production** | 🔴 **DOWN since 2026-08-22**, and **unmeasurable from here** — operator 10 |
| **The App Store listing** | 🔴 **EMPTY and NOT SUBMITTABLE.** 7/9 `en-US` fields blank at Apple; `tr` absent; only `name` ever set |
| **The publish lane** | **BUILT, MERGED, NEVER RUN** — this session runs it |
| **Push, device side** | **STILL 0 of 4 registered** |
| **The ADR index** | **WHOLE — 71 records, 71 rows**, gated (ADR-067) |
| **#204 / #278** | **OPEN**, both founder-gated (6(a), 6(b), 6(c)) |
| **#242 / #263** | OPEN and correctly blocked. Do not re-derive |

### What S096 changed that a later session will trip over

* **`session-context.md` §2/§3 now describe a restored toolchain**, including the
  SSH workaround Flutter needs on this network.
* **A new workflow can write to the founder's live App Store listing.** It is
  dispatch-only, dry-run by default and gated on a typed literal — but it exists,
  and `confirm: PUBLISH` is the whole distance between a report and a publication.
* **ADR-071's `except` clause was widened after the built-diff review** found that
  a `URLError` on one locale aborted the rest — #278's own defect inside the tool
  written to fix it (lesson **151**).

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

> ⚠️ **AN ISOLATION GUARANTEE IS ONLY AS WIDE AS ITS `except` CLAUSE**
> (lesson **151**). Enumerate what the layer below you actually raises; a suite
> written from the failure you have in mind tests the failure you have in mind.

> ⚠️ **SELF-REVIEW DOES NOT CATCH SELF-FLATTERY** (lesson **143**). **Seven**
> consecutive sessions have shipped an ADR whose worst error was caught by an
> outside reader comparing a claim to its source — never by a lens reading prose.
