# Resume Prompt — Session 086

> **This file contains ONE objective. That objective is the session; nothing else is.**
> (`project-rules.md` #1, `session-rules.md` §1.)
>
> Read `session-context.md` (toolchain, machine, review discipline, the
> never-without-asking list) and `session-lessons.md` (numbered to **129**) first.
> Re-derive the session number from `git log`.

**Objective: #243 — Gate 3's `install→paid ≥2%` cannot be computed, because the
two emitters share no identity. Record the options and their honest costs in an
ADR. Do NOT mint an identifier.**

`install` is a **client** event fired before any account exists. `paid` is a
**server** event keyed to a `coupleId` the RevenueCat webhook resolves. Nothing
joins them — and the obvious join was removed on purpose: **ADR-057 D3 forbids a
uid or `coupleId` on any client event, ever**, which is stronger than ADR-016
requires because this is a DV-aware product.

**This is a decision session, like S084/ADR-060 — decide and record, build
nothing.** Minting a device-scoped id is **collection**, it lands in
`PrivacyInfo.xcprivacy`, the #226 policy revision and `docs/dpa-inventory.md`'s
processor register, and it is the one identifier that **survives sign-out**,
which in a DV threat model is a property to decide deliberately rather than
inherit from an SDK default. **That call is the founder's, alongside #226.**

**The three options the ADR must price honestly**, per the issue: a device-scoped
id aliased to the account at signup · **accepting the metric is uncomputable**
and saying so in `mvp.md` · an install-time server ping. The second is a real
answer, not a failure — Gate 2 and Gate 3's `trial→paid` are both computable
without it (the issue's own table says so), so what is at stake is **one**
headline threshold, and the ADR should say what the founder loses by dropping it.

⚠️ **ADR-060 D2 deliberately left #243 open** and resolved the identity question
*conservatively* (neither identifier on the server three), handing the
**relaxation** to this issue. Read that decision before re-opening it.

**Acceptance:** an ADR that states which option is recommended and why, what each
costs in paperwork that already exists, and exactly what the founder must decide.
`operator-expected.md` gains the decision. **No identifier is minted, no
`PrivacyInfo.xcprivacy` edit, no legal-version bump.**

## 1. Where things stand *(measured 2026-08-26 — re-measure, do not inherit)*

| | State |
|---|---|
| **#246** | **CLOSED by S085** (ADR-061). The delete path sweeps the device; the flag seam is typed so a flag cannot exist unclassified |
| **#226** | **DRAFT on `main`, revision NOT landed.** `docs/legal/proposed/` holds version 3; `CURRENT_LEGAL_VERSION` is **still 2** and a test asserts it. Closes only when founder + lawyer approve |
| **The legal-review cluster** | **#249**, **#258** and this objective all end at the same desk. Two are one-line notes already written into `docs/legal/proposed/README.md`; #243 is the one that needs a decision, not a clause |
| **#136** | **Autonomous half DONE** (ADR-059). Stays open for **step 1** — whether the notification shade honours `U+2068`/`U+2069` — which is device-blocked |
| **#242** | **DECIDED, not built** (ADR-060). Stays open for the emitter, which waits on a sink. `ProcessOutcome` must grow to carry the previous lane state first |
| **Push, device side** | **STILL ZERO.** 0/4 accounts registered, all four "no report" |
| **The build gap** | Last `release.yml` run is **2026-08-09, build 119**. ADR-046/049/051/052/053/057/059/**061** are on **nobody's phone** |
| **Deployed rules / functions vs `main`** | Both **drifted or unmeasured** since S071/S077. A deploy is a **§7 founder ask** |
| **Open issues** | **#242**, **#243**, **#247**–**#250**, **#253**, **#258**, plus the older set |

### What S085 changed that a later session will trip over

* **`LocalFlagStore.isSet`/`set` take a `LocalFlagKey`, not a `String`.** A new
  device-local flag needs an `AccountFlag` or `DeviceFlag` member — that is the
  design, not friction: it is what makes the deletion sweep total. **Account-scoped
  unless the flag genuinely describes the phone**, and if it describes the phone,
  say why in the enum's doc comment.
* **`analytics_test.dart`'s character-for-character key table is load-bearing** and
  was deliberately left untouched by the diff that could have broken it. Do not
  "tidy" it into the typed vocabulary — its independence is the point.
* **The sweep is in `AuthController.deleteAccount`, not in `app.dart`.** Both a
  deletion and a sign-out end in `AuthSignedOut`; a test pins that `signOut()`
  clears nothing. Do not move it.
* **A rewrite that keeps every test green can still delete an assertion**
  (lesson **129**). Diff the old file's assertions against the new one.
* **Put the classification in the type and there is no inventory to keep**
  (lesson **128**) — before writing a source scan that enumerates what code must
  declare, ask whether the compiler can enumerate it instead.
* **Reason about the KEY, not about the flag** (lesson **127**). A per-identity
  cache key does not have the invalidation problem a global one has.

### Still true from S083/S084

* **`architecture.md` §7 has a second paragraph** after the sentinel-parsed first
  sentence. Appending there is safe and proven three times; **rewording the first
  sentence, or renaming the heading, is not.** §8 is free-form.
* **Prefer a rule over state WE own to one over a field the VENDOR controls**
  (lesson **125**).
* **Grep the file you are appending to for the words you are about to use**
  (lesson **126**).
* **`tool/bidi_visual.py`'s `--control` is the point** — run it before believing
  any output. Not a CI gate, deliberately.
* **Do not hand-roll a Unicode range** (lesson **124**). `\p{Script=…}`.
* `app/lib/core/l10n/strong_bidi_ranges.dart` is **GENERATED — never edit it**
  (ADR-053).
* **The emulator suite can fail on a loaded box.** Distinguish by SHAPE: a
  clock-shaped failure on a busy machine is not an assertion about behaviour. Do
  not re-run to green without saying you did.
* **`integration-emulator` never runs on a PR.** Prove a change to it with
  `gh workflow run ci.yml --ref <branch>` before merging.
* **Do not probe a Firestore trigger** with `assert_emulator_functions.sh` — a
  trigger answers `404`, exactly like an unknown name. Callables only.
* `FORMAT_VERSION` is **3**, pinned by **four** assertions (lesson **108**).

---

## 2. Then, in priority order

**1 — #249** (the consent record is named in no collection list — the third note
for the same legal desk) · **#248** (**thirteen** ADRs missing from the index now,
049–061; the issue body was re-measured in S085 and the proposed fix is a test
that asserts the file set equals the linked set — it would have failed thirteen
sessions ago).

**2 — #253** (`partnerAnswered` names nobody: **no caller supplies
`partnerName`**, which is also why ADR-059's `sanitizePushName` sits in a branch
nothing calls — closing #253 is what activates it) · **#204** (`deliver` has
failed to create the `tr` localization on **every** release since build 112, but
the **name** is what Apple refuses, so its fix is founder-blocked) · **#165**
(`rules-drift` built but unarmed) · **#121** · **#115** · **#41** · **#63/#71**.

⚠️ **Do not add `UIBackgroundModes: remote-notification`** without deciding SEC-3
first. Token capture needs none of it; only background *delivery* does.

---

## 3. Blocked — re-check every line

| What | Blocked on | Why a session cannot take it alone |
|---|---|---|
| **Landing the #226 revision** | founder/lawyer | The bump re-gates consent for **every** existing user. `docs/legal/proposed/README.md` has the exact diff, and now carries **two** notes (#249, #258) |
| **Minting the #243 identifier** | founder | Collection, and the one identifier that survives sign-out |
| **#136 step 1** | the device | Whether the notification shade honours the isolates |
| **A build carrying ADR-046/049/051/052/053/057/059/061** | founder | `release.yml` uploads a real binary — **§7**. Last build **119** |
| **M3.4's last inch** | the founder's phone | One permission grant. **If the prompt was ever declined, iOS will not show it again** |
| **Deploying S071's rules and S077/S083's functions** | founder | §7 |
| **An analytics vendor sink** | founder + lawyer | #226 is the other half. No CI check stops an adapter landing without it — **#247** |
| **#250** | M6.5 | Android backup exclusion, Gate-3 gated (ADR-006). **S085 made it sharper**: the sweep removes what is on the device and cannot reach a copy Google already took |
| **`tr` App Store localization** | founder | Apple refuses the **name**, not the locale |
| **operator 2(d) / 2(e)(ii) / 2(e)(iii) / 2(e)(iv) / 2(a) / 0(c)** | founder | Domains, legal name, three secrets, the budget alert |
| **#115** | founder | Making a prod endpoint world-reachable is a security decision on a live system |
| **#41** | founder | Live billing identity — *clean change* vs *migration* |
| **#48**, **#15** | the device | On-device observation nobody has made |
| **#13** | M6.5 | Android, Gate-3 gated |
| **#63**, **#71** | founder | Brandkit revisions |

---

## 4. Close sequence — `session-rules.md` §3/§4

Append to `past-prompts.md` → regenerate this file (one objective) → refresh
`operator-expected.md` → commit + push → verify CI → **watch the post-merge `main`
run** (`integration-emulator` is main-only) → `codegraph sync`.

> ⚠️ **THE REVIEW RUNS TWICE**, and **S085's second pass found what the first
> could not**: the design pass blocked a guard that reproduced the very defect it
> was written for, and the built-diff pass found a byte-level pin the rewrite had
> silently deleted — a pin whose absence every test in the suite agreed with.

> ⚠️ **WRITE THE ADR FIRST** (`session-context.md` §5 item 1 — **not** §5.1;
> lesson **115**). S085 revised its ADR **twice before writing code** and both
> revisions were forced by measurement, not taste.

> ⚠️ **Report `agents_error` and `agents_empty_result` as numbers**, and say what
> was **dropped unverified** at the cap (§5 items 5 and 6). S085 ran 3-of-5 empty
> on both passes; each empty lens had read 69–97k tokens first, which is what
> makes it *considered*-empty rather than failed-empty. **Say which it was.**

> ⚠️ **FREEZE THE TREE BEFORE THE REVIEW** (lesson **113**); `git status` must be
> EMPTY after every review workflow returns (§5 item 8).

> ⚠️ **Run the guard you just wrote, and mutation-check it.** S085 ran eleven, and
> two of them changed the diff: one proved a behavioural test stayed green against
> the exact bug it looked like it covered.

> ⚠️ **If a claim in the issue — or in THIS FILE — is load-bearing, measure it
> yourself** (lesson **123**). S085's objective arrived with a trade-off in its
> first paragraph that did not exist, written by the previous session from a
> document that was right about a different key.

> ⚠️ **Check the issue rows against `gh`, not against the last session's memory.**
