# Resume Prompt — Session 096

> **This file contains ONE objective. That objective is the session; nothing else is.**
> (`project-rules.md` #1, `session-rules.md` §1.)
>
> Read `session-context.md` and `session-lessons.md` (numbered to **150**) first.
> Re-derive the session number from `git log`.
>
> ⚠️ **`session-context.md` §2 AND §3 CHANGED THIS SESSION.** The dev box was
> rebuilt on ~2026-08-31 and lost `flutter`, `java`, `ruby` and the `firebase`
> login. **Measure the toolchain before you trust a command** (lesson **146**).
>
> ⚠️ **BEFORE PLANNING, OPEN THE ADR THAT OWNS THIS OBJECTIVE** (lesson **145**).
> Here that is **ADR-070 D3** and issue **#278**, and S095 wrote both — so read
> them as a claim to check, not as an instruction.

**Objective: #278 — `deliver` aborts for EVERY locale when Apple refuses one.
Build the per-locale writer over the App Store Connect REST API.**

### ⚠️ First, three commands. Quote all three before planning.

```sh
for c in node npm python3 java dart flutter ruby gh git; do printf '%-9s ' "$c"; command -v $c || echo MISSING; done
python3 tool/ci/prod_pulse.py --from-firebase-cli        # 0 restored · 1 down · 2 could not measure
gh workflow run testflight-testers.yml -f store_metadata_audit=true
```

Measured 2026-09-02 (S095) — **re-measure, do not inherit**:

* `flutter`, `java`, `ruby`, `firebase` **MISSING**; `dart` present but **only** at
  `~/.local/share/dart-sdk/bin` and **not on PATH**;
* `prod_pulse` exits **2 — could not measure**. ⚠️ **That is the instrument, not
  production.** S094 measured 1 on the same box. Operator item 10;
* the audit exits **1**, and its report is the reason this session exists.

### Why #278, and what S095 already established

`deliver` dies inside `verify_available_version_languages!` **before** the upload
phase, so the `tr` locale Apple refuses aborts the run **for every locale**
(ADR-047's backtrace, ADR-070 D2). Nothing has ever been published.

⚠️ **And the listing is EMPTY, not stale** (ADR-070 **D1.1**, run 33666301529):
all seven `en-US` text fields come back `PUBLISHED IS EMPTY`. ADR-047 D2 and
ADR-070 revisions 1–2 all said the store held hand-typed copy; it holds none. That
was found by asking the audit one question further than *"differs"* — **lesson
150**, and the best thing S095 did.

Two consequences you inherit: **nothing can be lost by publishing**, and the
listing is **not submittable**, which is a launch blocker that was not on any list
before.

### What you are building

A writer that publishes `fastlane/metadata/` **per locale**, so a refused locale
is a *named finding* and every other locale still lands. Not a fastlane change —
a Python tool, because that is the only thing this box can still exercise:

* the resources and the field split are already mapped in
  `tool/ci/store_metadata_audit.py` (`VERSION_FIELDS` / `APP_INFO_FIELDS`,
  ADR-047 D3). **`name`, `subtitle` and `privacyPolicyUrl` are on
  `appInfoLocalizations`; the rest are on `appStoreVersionLocalizations`** — and
  `name` is the field Apple refuses, so a writer that touched only one resource
  would miss the whole bug;
* `_fake_call` in `store_metadata_audit_test.py` is the fixture harness. ⚠️ Its
  matching is by **substring, first match wins**, so list the LONGER fragment
  first (`appStoreVersionLocalizations` before `appStoreVersions`).

### Acceptance

1. **The three commands above are run and quoted**, and `prod_pulse`'s exit 2 is
   reported as an *instrument* outage, not a production reading.
2. **ADR-070 D3 and #278 read first**, and their claim that this is unblocked
   **checked** — S095 wrote them, and a prompt is a claim (lesson 145). If it is
   already decided or already blocked, say so and stop: that is a clean outcome.
3. **An ADR committed BEFORE code** (lesson **115**) **with its index row in the
   same commit** — ADR-067's lint makes a missing row a red build, and it has now
   caught three sessions.
4. **Exit taxonomy unchanged**: 0 all locales written · 1 at least one refused or
   unwritten · 2 could not measure (ADR-041, ADR-047 D4).
5. **Mutation-checked**, and **record the mutants that do NOT discriminate** —
   S095 had one and kept it rather than tidying it away. ⚠️ **A mutant that dies
   by an exception has not proven the assertion you named** (S095 had two; the
   fixture needed a decoy before the named assertion was what caught it).
6. **It must not be able to run by accident.** Dispatch-only or explicitly gated,
   like `deploy-functions.yml` (ADR-048). It writes to a live Apple listing.
7. ⚠️ **DO NOT POINT IT AT PRODUCTION.** Operator **6(b)** (may the AI-drafted
   English copy be published at all — ADR-020 D8's never-discharged gate) and
   **6(c)** (may a session dispatch the release lane once) are both open. This
   session builds the mechanism, not the permission.

### What is NOT this session's

* **The Turkish name** (operator 6(a)) — Apple refuses it; the founder decides.
* **Restoring billing** (1), **the RevenueCat invoker** (2), **the four secrets**
  (3), **cutting a build** (4), **the legal bundle** (5), **the firebase login**
  (10).
* **Dispatching the release lane** — §7 says *without asking*, and the asking is
  operator 6(c), unanswered.
* **#136.** ⚠️ Checked before being ruled out: **ADR-059 D3 has already decided**
  not to add the bidi isolate, because whether a notification shade honours
  `U+2068`/`U+2069` cannot be measured without a phone, and ADR-059 D2 shipped the
  alternative. Its remaining step is device-blocked. Do not re-derive this.

---

## 1. Where things stand *(measured 2026-09-02 — re-measure, do not inherit)*

| | State |
|---|---|
| **The dev box** | 🔴 **REBUILT ~2026-08-31.** No `flutter`, `java`, `ruby`, `firebase`. `dart` 3.12.2 restored by S095 at `~/.local/share/dart-sdk/bin`, **not on PATH**. `node`, `npm`, `python3`, `gh`, `git`, `codegraph` fine |
| **Production** | 🔴 **DOWN since 2026-08-22** — but **unmeasurable from here** since the rebuild. Console only, until operator 10 |
| **The App Store listing** | 🔴 **EMPTY and NOT SUBMITTABLE.** 7/9 `en-US` fields blank at Apple; `tr` absent; only `name` ever set |
| **Push, device side** | **STILL 0 of 4 registered** |
| **The ADR index** | **WHOLE — 70 records, 70 rows**, gated (ADR-067) |
| **The v3 privacy draft** | All three items drafted; `CURRENT_LEGAL_VERSION` still **2**; nothing landed. Corrected **four** times without landing |
| **#204** | **OPEN**, both halves founder-owned (operator 6(a), 6(b)) |
| **#278** | **OPEN — this session** |
| **#242** | OPEN and correctly blocked by ADR-060 D6. Do not re-derive |
| **#263** | OPEN — the watcher is merged and unarmed |

### What S095 changed that a later session will trip over

* **`session-context.md` §2 and §3 now carry a measured toolchain table.** They
  described a machine that no longer exists, in runnable form (lesson **146**).
* **Five documents said the app is called `İkimiz`. It is `ikimiz`.** One was
  `session-context.md` §6's invariants table; one was in `seed_mark.dart`. The
  store-name lint would **not** have caught a session that followed the invariant,
  because the lint's own message tells you to move the pin too (lesson **148**).
* **ADR-047 D2's characterisation of the listing is corrected** by ADR-070 D1.1.
  Its *finding* was right; its *reading* of what the store held was a guess.
* **A refusal that cites a rule saying "without asking" is a question nobody
  asked** (lesson **147**) — ADR-070 D3 revision 1 did exactly that and was caught
  by its own review.

### Still true from earlier sessions

* **Open the ADR that owns the objective before planning** (lesson **145**).
* **Cite a SYMBOL, not a line number** (lesson **144**).
* **A correction is finished when every COPY of it is gone** (lesson **141**) —
  violated again in S095, which quoted the lesson and then found three of five.
  **Grep for the claim's own words.**
* **`architecture.md` §7's first sentence is sentinel-parsed** — append after it.
* **`integration-emulator` never runs on a PR**, and a docs-only merge produces a
  `main` green with it path-filtered away, measuring nothing.
* **Repeated pushes cancel the macOS gate**; verify `ios-build-smoke` actually
  COMPILED via `gh api repos/:owner/:repo/actions/jobs/<id>/logs`.
* `FORMAT_VERSION` is **3**, pinned by **four** assertions (lesson 108).
* **`main` is protected** — a close commit needs its own PR.
* **git identity is not configured on a fresh box.** S095 set
  `Aytek E <62661118+aytekXR@users.noreply.github.com>` locally, matching history.

---

## 2. Then, in priority order

**1 — restore `flutter` + Java** on the dev box (a download, no credential; it is
what stops a session verifying app-side work locally). **2 — #121** (a dead step in
the release lane — but it needs a real release run, so it rides operator 6(c)).
**3 — #165** (rules-drift, skipped until one read-only secret exists).

⚠️ **#242 and #136 are NOT in this list, deliberately** — both are decided or
blocked by an ADR, above.

---

## 3. Blocked — re-check every line

| What | Blocked on | Why a session cannot take it alone |
|---|---|---|
| 🔴 **Restoring billing** | **founder** | A closed account is a payment instrument on their Google identity. **Everything server-side is downstream** |
| 🔴 **Seeing whether production is alive** | **founder** | Operator 10 — the box lost its `firebase login`; every local probe now answers 2 |
| **Publishing ANY store copy** | founder | Operator 6(b): ADR-020 D8's review gate has never been discharged, and the copy is AI-drafted |
| **The Turkish localization** | founder | Apple refuses the **name** (6(a)) |
| **Exercising the release lane** | founder | Operator 6(c) — §7 asks; the asking is open |
| **Arming the watcher** | founder | `PROD_PULSE_VIEWER_SA`, operator 3 |
| **A build carrying everything since ADR-046** | founder | Last build **119**, cut 2026-08-09 |
| **M3.4's last inch** | the founder's phone | One permission grant |
| **Deploying rules/functions** | founder | §7, downstream of billing |
| **#226**, **#243** | founder / lawyer | A consent re-gate; a definitional sentence |
| **#136 step 1**, **#48**, **#15** | the device | On-device observation nobody has made |
| **An analytics vendor sink** | founder + lawyer | #247 |
| **#250**, **#13** | M6.5 | Gate-3 gated |
| **#115**, **#41**, **#63**, **#71** | founder | A world-reachable endpoint; billing identity; brandkit |

---

## 4. Close sequence — `session-rules.md` §3/§4

Append to `past-prompts.md` → regenerate this file (one objective) → refresh
`operator-expected.md` → commit + push → verify CI → **watch the post-merge `main`
run** (`integration-emulator` is main-only) → `codegraph sync`.

> ⚠️ **THE REVIEW RUNS TWICE**, and S095 is the cleanest evidence yet that the two
> passes find different things. Its design pass refuted 4 of 16 arguing about a
> *decision*; its built-diff pass refuted **0 of 6**, because every finding was a
> checkable fact about code — and **five correctness lenses came back
> considered-empty**. The distribution is a signal about the QUESTION (lesson 137).

> ⚠️ **WRITE THE ADR FIRST** (lesson **115**), with its index row.

> ⚠️ **Report `agents_error` and `agents_empty_result` as numbers**, and say
> whether an empty lens was **considered**-empty or **failed**-empty.

> ⚠️ **FREEZE THE TREE BEFORE THE REVIEW** (lesson **113**); `git status` must be
> EMPTY after every review workflow returns.

> ⚠️ **A NUMBER IS A CLAIM; CARRY THE COMMAND THAT PRODUCED IT** (lesson **133**).
> S095 quoted that lesson in its own ADR and then got **four** counts wrong. Three
> were caught by review agents; the fourth was caught only because the run that
> produced it had **exited 1 partway** and nobody had read the exit code
> (lesson **149**). **Read the exit code of the run you are counting.**

> ⚠️ **ASK WHAT ELSE YOUR VERDICT IS COMPATIBLE WITH** (lesson **150**). *"Differs"*
> stood for seventeen days and two ADRs while meaning something nobody had guessed.

> ⚠️ **IF YOUR ADR DECLINES TO BUILD SOMETHING, POINT A LENS AT THAT DECISION**
> (lesson **147**). Nothing fails when a refusal is wrong — the work simply does
> not happen. S095's first refusal cited a rule that says *"without asking"* and a
> precedent that protects **working** systems; both broke under one lens.

> ⚠️ **SELF-REVIEW DOES NOT CATCH SELF-FLATTERY** (lesson **143**). **Six**
> consecutive sessions have now shipped an ADR whose worst error was a claim that
> flattered its own argument, caught every time by an outside reader comparing the
> claim to its source. S095's were a **superlative** ("the first movement in eleven
> sessions") and an **overstatement** ("a live detonator"). **Spend review agents
> on checking claims against sources, not only on lenses over the diff.**

> ⚠️ **A GUARD DOES NOT PROTECT AGAINST A CONSCIENTIOUS READER FOLLOWING A STALE
> INSTRUCTION** (lesson **148**). "A lint covers it" is not a reason to leave one
> standing.
