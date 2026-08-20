# Resume Prompt — Session 083

> **This file contains ONE objective. That objective is the session; nothing else is.**
> (`project-rules.md` #1, `session-rules.md` §1.)
>
> Read `session-context.md` (toolchain, machine, review discipline, the
> never-without-asking list) and `session-lessons.md` (numbered to **121**) first.
> Re-derive the session number from `git log`.

**Objective: #136 — the Arabic push body interpolates a partner name with no bidi
isolation. Do the half that needs no device: reorder the Arabic copy so a partner
name never sits beside a bidi-neutral, and pin the latent defect with a test.**

`composePush`'s Arabic `partnerAnswered` copy is `أجاب {name}` / `أجاب {name} عن
سؤال اليوم.` — a Latin-script name dropped into an RTL sentence. **ADR-033 does
not answer this seam**: it applies isolation *at render*, in the app, and a push
payload is composed on the server and rendered by the **notification shade**,
which is neither. Nothing persisted, exported or shared may carry `U+2068`/`U+2069`
— and a push payload is arguably all three.

**S082 made this pointed.** The version-3 draft now tells Arabic users, in
writing, that *"في صورته المعتادة قد يُظهر الإشعار اسم شريككم"* — a notification
can show your partner's name. Having just promised it, the repo should be sure
that name renders the way its owner wrote it.

## What is autonomous, and what is not

* **NOT autonomous — step 1.** Whether the iOS notification shade honours
  `U+2068`/`U+2069` is a **device** question. Nobody can answer it from here, and
  no build is on a phone that could (last release **build 119, 2026-08-09**).
* **Autonomous — the reordering, and the test.** The defect is *latent* today:
  today's Arabic copy is only **accidentally** safe. `أجاب {name}` puts the name
  at the end of the clause, where the paragraph direction happens to save it. A
  name followed by a **bidi-neutral** — a full stop, a comma, a parenthesis — is
  where it breaks, and `Aylin Y.` is the case to write the test around: the
  trailing `.` is neutral, so the rendered result reorders.
* **Prefer finishing one thing.** Do the reorder + the test. Leave step 1 filed.

**Acceptance:** every Arabic push string is arranged so an interpolated name is
never adjacent to a bidi-neutral; a test pins `Aylin Y.` (and at least one
name with a trailing neutral in each other Arabic string) and **fails against
today's copy**; ADR-033's boundary is amended or explicitly ruled out of scope
for the server seam, in writing. **Mutation-check the test** — restore the old
copy and confirm exactly its own case reddens.

⚠️ **No `U+2068`/`U+2069` may enter a payload** (ADR-033, `session-context.md`
§6). The fix is word order, not isolation characters.

---

## 1. Where things actually stand *(measured 2026-08-20/21 — re-measure, do not inherit)*

| | State |
|---|---|
| **#226** | **DRAFT LANDED, revision NOT landed.** `docs/legal/proposed/` holds a version-3 draft of the three privacy policies. `CURRENT_LEGAL_VERSION` is **still 2** in all three sources and `legal_proposal_test.dart` asserts it. **The issue stays open**: it closes when the founder + lawyer approve and one diff bumps |
| **Push, device side** | **STILL ZERO.** `push_delivery_probe.py --from-firebase-cli` → exit 1, **0/4 registered, all four "no report"** |
| **Push, server side** | **RUNNING** as of S070. Not re-measured in S082 — run `prod_pulse.py --from-firebase-cli` before relying on it |
| **The build gap** | Last `release.yml` run is **2026-08-09, build 119**. ADR-046/049/051/052/053/057 are on **nobody's phone**. Build 119 **does** carry ADR-042/044 — the token capture — which is why #226 is overdue rather than pending |
| **Deployed rules vs `main`** | `rules_drift.py` exited **1 for both projects** at the S071 close. Not re-measured since. Deploying is a **§7 founder ask** |
| **`hayatiapp-prod` Functions** | S077 changed `functions/` source, so prod is behind `main`. A deploy is a **§7 ask** |
| **`functions-drift` / `rules-drift`** | Both **visibly SKIPPED** by design — one absent secret (operator **2(e)(iv)** / item 4) |
| **Open issues** | **#246**, **#247**, **#248**, **#249**, **#250** filed by S082 — all unblocked-to-file, none blocking S083 |

### What S082 changed that a later session will trip over

* **`docs/legal/proposed/` is a SECOND description of the same subject.** It will
  drift. `legal_proposal_test.dart` makes the drifts that matter loud — but its
  **anchor assertions are its own tripwire**: if the shipped text ever stops
  containing *"ikimiz does not send push notifications today."* (or its TR/AR
  twins), the test fails saying **the premise moved**. That is the message, not
  a bug in the test.
* **That test is DELETED by the diff that lands the revision** — and by a diff
  that supersedes it. Its first assertion is that the directory exists.
  `docs/legal/proposed/README.md` carries both paths as step 0.
* **`docs/legal/README.md` now lists FIVE lawyer questions**, A–E. Its
  `version:` line is still the single source the three-way sentinel reads — **do
  not add a second line matching `^version:\s*\d+\s*$` to that file.**
* **`Proposed` is now a documented ADR status** (`docs/adr/README.md`), added for
  the one shape the vocabulary lacked: a decision whose deliverable is a draft.
* **The Arabic legal documents carry exactly ONE `U+200F`**, after the `(` that
  opens the Latin processor list. It is invisible, it is pinned by a test, and
  **it is directly relevant to #136** — it is this repo's existing precedent for
  fixing an RTL/Latin adjacency without isolation characters.
* **Prefer a scripted, anchor-asserted delta over hand-editing any derived
  document** (lesson **119**). S082's hand-written Arabic draft silently dropped
  a word from a heading.
* **A guard's NAME is not its assertion** (lesson **121**). S082 shipped a parity
  test whose name promised order and whose body compared counts, and the name was
  quoted into two other documents before anyone read the body.
* **Do not write an absolute about device storage** (lesson **120**). Android
  Auto-Backup is default-on; ADR-018's `unlocked_this_device` already concedes
  iOS backups include ordinary storage. Filed as **#250**.
* **`architecture.md` §7's FIRST SENTENCE is parsed by a test** behind a
  ≥12-name floor. Prose *after* it is safe; rewording it, or renaming the
  `## 7. Analytics schema` heading, turns the suite red. **§8 is free-form** —
  S082 edited it and the suite stayed green.
* **`analyticsSinkProvider` defaults to the NO-OP and must keep doing so**;
  **`main_prod.dart` must wire NO analytics sink.** Tests assert both.
* **`ref.read` after an await in an autoDispose controller THROWS** — capture the
  handle *before* the await (lesson **118**).
* `app/lib/core/l10n/strong_bidi_ranges.dart` is **GENERATED — never edit it**
  (ADR-053). Re-derive with `python3 tool/gen_bidi_rtl_ranges.py`; CI runs
  `--check`. **Read the message on failure** — it prints a *different sentence*
  for "Unicode moved" than for a hand-edit. **This is #136's neighbourhood.**
* **The export must never carry a raw FCM registration token, at any nesting
  level** (ADR-054). Delivery is `Clipboard.setData`.
* **`integration-emulator` never runs on a PR.** Prove a change to it with
  `gh workflow run ci.yml --ref <branch>` before merging. Its per-suite SILENCE
  bound must stay comfortably inside `timeout-minutes` (ADR-055, lesson 116).
* **Do not probe a Firestore trigger** with `assert_emulator_functions.sh`: a
  trigger answers `404`, exactly like an unknown name. Callables only.
* `FORMAT_VERSION` is **3**, pinned by **four** assertions, two of which carry the
  number in the *test's name* (lesson **108**).

---

## 2. Then, in priority order

**1 — #242 / #243**, both needing a decision more than code: #242 is *which*
server surface emits `trial_start`/`paid`/`churn` — **the decision can be
recorded without the vendor**; #243 is the distinct-id, a **privacy** decision
that rides #226. **#249** (the consent record names itself in no collection list)
is the same shape and is nearly free while the lawyer has the document open.

**2 — #204** (`deliver` has failed to create the `tr` localization on **every**
release since build 112) · **#165** (`rules-drift` built but unarmed) · **#121**
(a watched release run) · **#248** (nine ADRs missing from the index) · **#115** ·
**#41** · **#63/#71** (brandkit).

⚠️ **Do not add `UIBackgroundModes: remote-notification`** without deciding SEC-3
first. Token capture needs none of it; only background *delivery* does.

---

## 3. Blocked — re-check every line

| What | Blocked on | Why a session cannot take it alone |
|---|---|---|
| **Landing the #226 revision** | founder/lawyer | The bump re-gates consent for **every** existing user. A session may draft; it may not bump. `docs/legal/proposed/README.md` has the exact diff |
| **A build carrying ADR-046/049/051/052/053/057** | founder | `release.yml` uploads a real binary to TestFlight — **§7**. Last build **119** |
| **M3.4's last inch** | the founder's phone | One permission grant, on a build that has the fix. **If the prompt was ever declined, iOS will not show it again** |
| **Deploying S071's rules and S077's functions** | founder | §7. Both additive |
| **An analytics vendor sink** | founder + lawyer | The token is one half, #226 the other. **No CI check stops an adapter landing without it** — now tracked as **#247** |
| **#136 step 1** | the device | Whether the notification shade honours the isolates. **Its reorder half needs no device — that is this session** |
| **#250** | M6.5 | Android backup exclusion. Gate-3 gated (ADR-006) |
| **`tr` App Store localization** | founder | Apple refuses the **name**, not the locale |
| **operator 2(d)** | founder | Associated Domains. Measured absent |
| **operator 2(e)(iii)** | founder | `FIREBASE_SERVICE_ACCOUNT`. Arms **three** lanes |
| **operator 2(e)(iv) / #165** | founder | One read-only SA, two roles |
| **operator 2(a)** | founder | The budget alert |
| **operator 0(c)** | founder | `RC_WEBHOOK_TOKEN` on dev |
| **operator 2(e)(ii)** | founder | The controller's legal name. Blocks `/privacy`, `/terms`, the listing |
| **#115** | founder | Making a prod endpoint world-reachable is a security decision on a live system |
| **#41** | founder | Live billing identity — *clean change* vs *migration* |
| **#48**, **#15** | the device | On-device observation nobody has made |
| **#13** | M6.5 | Android, Gate-3 gated (ADR-006) |
| **#63**, **#71** | founder | Brandkit revisions |

---

## 4. Close sequence — `session-rules.md` §3/§4

Append to `past-prompts.md` → regenerate this file (one objective) → refresh
`operator-expected.md` → commit + push → verify CI → **watch the post-merge `main`
run** (`integration-emulator` is main-only) → `codegraph sync`.

> ⚠️ **THE REVIEW RUNS TWICE** — *"once on the design, once on the built diff"*
> (`session-context.md` §5, item 3). **S082 ran both, and each found what the
> other could not**: the design pass caught a quiet-hours number heading into a
> privacy policy, and the built-diff pass caught **three false sentences in the
> drafted policy itself** plus two guards whose names outran their assertions.
> One pass would have shipped either half of that.

> ⚠️ **WRITE THE ADR FIRST** (`session-context.md` §5.1 is **not** the address —
> it is §5 item 1; lesson **115**). S082's design pass could only exist because
> the ADR was committed before a word of the draft.

> ⚠️ **Do not claim a review you have not run, in the artefact itself.** Write
> review status **prospectively**, then replace it with numbers. S082 recorded
> `agents_error` and `agents_empty_result` for both passes — the built-diff pass
> had **one empty verifier**, and that finding surfaced as *unverified* rather
> than being counted clean (§5 item 5).

> ⚠️ **FREEZE THE TREE BEFORE THE REVIEW** (lesson **113**), and **`git status`
> must be EMPTY after every review workflow returns** (§5 item 8).

> ⚠️ **A scan whose glob matches nothing reports the same clean zero as a scan
> that passed** (lesson **110**). Assert a floor on the INPUT, and pair every
> absence assertion with a **presence control** on a case you know is non-empty.

> ⚠️ **Run the guard you just wrote before believing it.** S082's rewritten parity
> assertion failed on correct input (Dart `List` identity equality), and its
> nested-bullet regex fired on every ordinary bullet because `\s` matches `\n`.
> Both were found by running, not by reading.

> ⚠️ **Check the issue rows against `gh`, not against the last session's memory.**
