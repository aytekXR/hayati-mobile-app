# Resume Prompt — Session 082

> **This file contains ONE objective. That objective is the session; nothing else is.**
> (`project-rules.md` #1, `session-rules.md` §1.)
>
> Read `session-context.md` (toolchain, machine, review discipline, the
> never-without-asking list) and `session-lessons.md` (numbered to **118**) first.
> Re-derive the session number from `git log`.

**Objective: #226 — draft the legal-text revision, in ONE bundle covering push
*and* analytics, so the founder/lawyer approves once and users are re-consented
once.**

`docs/legal/privacy-policy.*` tells users *"ikimiz does not send push
notifications today"* — **true of the outcome, false of the system** — and names
neither `fcmTokens` nor `pushDiagnostic` in what it collects. That is #226, and
it has been the repo's most serious open item for two sessions.

**S081 made it due.** ADR-057 shipped funnel instrumentation, and while
**nothing leaves the device today** (prod is wired to a no-op sink, so no
processor is engaged and `dpa-inventory.md` needs no new row *yet*), the analytics
adapter is now one small diff away — and it needs the *same* legal change.

> ⚠️ **A legal revision bumps `CURRENT_LEGAL_VERSION` and re-prompts EVERY
> existing user for consent** (ADR-023's three-way source sentinel). Doing push
> now and analytics later asks your users **twice**. Bundling is the whole point
> of doing this now, and it is already written down as **operator item 18**.

## What is autonomous, and what is not

* **Autonomous:** the *drafting*. TR/AR/EN, all three policy documents, plus the
  `dpa-inventory.md` rows the revision implies. Precedent is explicit — the
  existing bundle is *"AI-drafted, review-PENDING — founder legal/native gate"*
  (`architecture.md` §8), so a draft is the expected artefact.
* **NOT autonomous:** landing it. **Do not bump `CURRENT_LEGAL_VERSION`.** The
  bump is what re-gates every user, and it is a founder/lawyer decision
  (`session-context.md` §7 by extension; the three-way sentinel means the bump
  must be one atomic diff *when the founder says go*).
* **Never** guess the founder's legal name into a legal document
  (`session-context.md` §7). The three bracketed placeholders stay bracketed.

**Stop at a reviewable draft.** A branch that changes the wording without the
version bump will fail the byte-sync drift test between `docs/legal/` and
`app/assets/legal/` — decide deliberately whether the draft lands as a separate
reviewable file (e.g. `docs/legal/proposed/`) or as a PR left open, and **say
which in the ADR**. Do not discover this at push time.

⚠️ **If #226 turns out to need the founder before a draft is even useful, the
fallback is #136's autonomous half** — the Functions-side bidi twin. Step 1 (does
the notification shade honour `U+2068`/`U+2069`) is device-blocked, but **step 3
is not**: the Arabic copy can be reordered so a partner name never sits next to a
bidi-neutral, and a test can pin the latent defect (`Aylin Y.`) that today's copy
is only accidentally safe from. Prefer finishing one thing over starting both.

## 1. Where things actually stand *(measured 2026-08-18/19 — re-measure, do not inherit)*

| | State |
|---|---|
| **Analytics (#239)** | **Instrumented, NOT measured.** 8 of 12 §7 events emit with real call sites; prod ships a **no-op sink**, so nothing leaves any device. Two sentinels keep `architecture.md` §7 and the code from drifting |
| **Notifications, server side** | **RUNNING** as of S070: `prod_pulse.py --from-firebase-cli` exit 0, scheduler ENABLED. **Not re-measured since** — run it before relying on it |
| **Notifications, device side** | **STILL ZERO** as of S071: `push_delivery_probe.py` exit 1, 0 of 4 accounts have ever registered |
| **The build gap that gates it** | Last `release.yml` run is **2026-08-09, build 119**. Everything client-side merged since — ADR-046, ADR-049, ADR-051, ADR-052, ADR-053, and now **ADR-057** — is on **nobody's phone** |
| **Deployed rules vs `main`** | `rules_drift.py` exited **1 for both projects** at the S071 close. Deploying is a **§7 founder ask**. Re-measure rather than inherit |
| **`hayatiapp-prod` Functions** | ⚠️ S077 changed `functions/` source, so prod is behind `main` on function code — a deploy is a **§7 ask** |
| **`functions-drift` / `rules-drift` in CI** | Both **visibly SKIPPED** by design — one absent secret (operator **2(e)(iv)** / item 4) |
| **#129, #137, #227, #208** | **CLOSED**. **#239** closes with S081's merge; **#242** and **#243** are its filed remainders |

### What S081 changed that a later session will trip over

* **`architecture.md` §7's FIRST SENTENCE is parsed by a test.**
  `funnel_event_sentinel_test.dart` reads the arrow chain and the `plus`-list out
  of it, behind a **≥12-name floor**. Prose added *after* that sentence is safe
  (S081 appended a long addendum and the sentinel stayed green); **rewording the
  first sentence, or renaming the `## 7. Analytics schema` heading, turns the
  suite red on the floor** — which is deliberate, and is lesson **110**'s
  fail-open case being caught rather than passed.
* **Adding a 13th event to §7 reddens the suite** until it has a `FunnelEvent`
  row *and* an emitter classification. **Deleting one reddens it too** — the
  parity is a set equality in both directions.
* **A new client event needs a CALL SITE, not just a type.**
  `funnel_call_site_sentinel_test.dart` scans `lib/features` + `lib/app.dart`
  for `.<emitterMethodName>(`. The not-built exclusion list is asserted to be
  **exactly** `{share_card_created}`, justified against `mvp.md`'s OUT list.
* **`analyticsSinkProvider` defaults to the NO-OP and must keep doing so.**
  Making it throw (the `authRepositoryProvider` idiom) would redden every widget
  test that renders an instrumented screen. This is telemetry — ADR-057 D2(c).
* **`main_prod.dart` must wire NO analytics sink.** A test asserts it. Prod
  emitting anywhere is the thing the legal gate above exists for.
* **`ref.read` after an await in an autoDispose controller THROWS** — capture the
  handle *before* the await (lesson **118**). S081 walked into this at four call
  sites and only one had a test that could see it.
* **`app/lib/core/` imports `app/lib/features/` in 0 of 631 files.** ADR-057
  designed the dimension binding *around* that boundary (the profile-aware
  resolver is an override installed from `app.dart`). Do not be the first to
  cross it casually.
* `app/lib/core/l10n/strong_bidi_ranges.dart` is **GENERATED — never edit it**
  (ADR-053). Re-derive with `python3 tool/gen_bidi_rtl_ranges.py`; CI runs
  `--check`. **If `--check` fails after a runner-image bump, read the message** —
  it prints a *different sentence* for "Unicode moved" than for a hand-edit.
* **The export must never carry a raw FCM registration token, at any nesting
  level** (ADR-054). Delivery is `Clipboard.setData`.
* **`integration-emulator`'s per-suite SILENCE bound must stay comfortably inside
  `timeout-minutes`** (ADR-055, lesson 116). The wall-clock bounds are loose
  backstops and their sum MAY exceed the ceiling — do not "fix" that.
* **Do not probe a Firestore trigger** with `assert_emulator_functions.sh`: a
  trigger answers `404`, exactly like an unknown name. Pass callables only.
* **`integration-emulator` never runs on a PR.** Prove a change to it with
  `gh workflow run ci.yml --ref <branch>` before merging.
* `FORMAT_VERSION` is **3**, pinned by **four** assertions, two of which carry the
  number in the *test's name* (lesson **108**).

---

## 2. Then, in priority order

**1 — #242 / #243**, both filed by S081 and both needing a decision more than
code: #242 is *which* server surface emits `trial_start`/`paid`/`churn` (a port
on the RC webhook, or a Firestore-triggered function over
`subscriptions/{coupleId}`) — **the decision can be recorded without the vendor**;
#243 is the distinct-id, which is a **privacy** decision and rides #226.

**2 — #136** (the Functions-side bidi twin; its fallback needs no device) ·
**#204** (`deliver` has failed to create the `tr` localization on **every**
release since build 112) · **#165** (`rules-drift` built but unarmed) · **#121**
(a watched release run) · **#115** · **#41** · **#63/#71** (brandkit).

⚠️ **Do not add `UIBackgroundModes: remote-notification`** without deciding SEC-3
first. Token capture needs none of it; only background *delivery* does.

---

## 3. Blocked — re-check every line

| What | Blocked on | Why a session cannot take it alone |
|---|---|---|
| **A build carrying ADR-046/049/051/052/053/057** | founder | `release.yml` uploads a real binary to TestFlight — **§7**. Last build **119, 2026-08-09** |
| **M3.4's last inch** | the founder's phone | One permission grant, on a build that has the fix. **If the prompt was ever declined, iOS will not show it again** |
| **Deploying S071's rules and S077's functions** | founder | §7. Both additive |
| **An analytics vendor sink** | founder + lawyer | The token is one half; the legal revision above is the other, and **there is no CI check that stops an adapter landing without it** (operator item 18) |
| **`tr` App Store localization** | founder | Apple refuses the **name**, not the locale |
| **operator 2(d)** — Associated Domains | founder | Measured absent |
| **operator 2(e)(iii)** | founder | `FIREBASE_SERVICE_ACCOUNT`. Arms **three** lanes |
| **operator 2(e)(iv) / #165** | founder | One read-only SA, two roles |
| **operator 2(a)** | founder | The budget alert |
| **operator 0(c)** | founder | `RC_WEBHOOK_TOKEN` on dev |
| **operator 2(e)(ii)** | founder | The controller's legal name. Blocks `/privacy`, `/terms`, the listing |
| **#226** | founder/lawyer | Changing the legal texts re-gates consent for every existing user. **A session may draft; it may not bump the version** |
| **#115** | founder | Making a prod endpoint world-reachable is a security decision on a live system |
| **#41** | founder | Live billing identity — *clean change* vs *migration* |
| **#48**, **#15** | the device | On-device observation nobody has made |
| **#136** | the device | Whether notification chrome honours the isolates. **Its fallback path needs no device** |
| **#13** | M6.5 | Android, Gate-3 gated (ADR-006) |
| **#63**, **#71** | founder | Brandkit revisions |

---

## 4. Close sequence — `session-rules.md` §3/§4

Append to `past-prompts.md` → regenerate this file (one objective) → refresh
`operator-expected.md` → commit + push → verify CI → **watch the post-merge `main` run**
(`integration-emulator` is main-only) → `codegraph sync`.

> ⚠️ **THE REVIEW RUNS TWICE** — *"once on the design, once on the built diff"*
> (`session-context.md` §5, item 3). **S081 ran both, and each pass found what the
> other could not**: the design pass killed a client event for a feature `mvp.md`
> lists as OUT and caught that nothing had decided how many times an event fires;
> the built-diff pass caught **two over-claims in the session's own code**. One
> pass would have shipped either half of that.

> ⚠️ **WRITE THE ADR FIRST** (`session-context.md` §5.1, lesson **111**). An ADR
> written first must state its numbers while nothing green is lending them
> authority — and S081's design pass could only exist *because* the ADR was
> committed before the code.

> ⚠️ **Do not claim a review you have not run, in the artefact itself.** ADR-057
> **revision 1** carried *"reviewed twice"* in the past tense, in a commit made
> before either review existed. That is the fifth instance of this shape (after
> `62,408`, the miscited §5.1, "every clause is false", and "a lock that cannot be
> installed frozen never reaches `main`"). Write review status **prospectively**.

> ⚠️ **FREEZE THE TREE BEFORE THE REVIEW** (lesson **113**), and **`git status`
> must be EMPTY after every review workflow returns** (§5 item 8) — they can
> mutate the tree.

> ⚠️ **A scan whose glob matches nothing reports the same clean zero as a scan
> that passed** (lesson **110**). Assert a floor on the INPUT before believing the
> output. S081's Crashlytics sentinel first failed on **the doc comment explaining
> the rule** — a guard measuring prose rather than behaviour.

> ⚠️ **Where a value is a persisted contract, assert the VALUE — behaviour is
> blind to it** (lesson **117**), and **a rule recorded in one feature's ADR does
> not generalise itself** (lesson **118**).

> ⚠️ **Check the issue rows against `gh`, not against the last session's memory.**
