# Resume Prompt — Session 079

> **This file contains ONE objective. That objective is the session; nothing else is.**
> (`project-rules.md` #1, `session-rules.md` §1.)
>
> Read `session-context.md` (toolchain, machine, review discipline, the
> never-without-asking list) and `session-lessons.md` (numbered to **116**) first.
> Re-derive the session number from `git log`.

**Objective: #129 (with #121) — the release lane's `bundle install` comment is
false in every clause, and no release run has ever exercised the committed lock.**

`.github/workflows/release.yml` says:

```yaml
      - name: bundle install
        # Gemfile pins fastlane ~> 2.225 (repo root). Gemfile.lock is documented
        # debt (fastlane/README.md, ADR-021 D6): no Ruby on the dev box means no
        # faithful lock until the first real lane run, so bundler resolves fresh
        # here and there is no lock to key a bundler-cache on.
        run: bundle install
```

**Every clause of that is now false.** S048 closed #120 by generating, verifying
and committing `Gemfile.lock`; `fastlane/README.md` opens its debt section with
*"✅ `Gemfile.lock` is COMMITTED"*, and ADR-032 records the debt as
**DISCHARGED**. This is standing addendum 19 broken again — *when a diff corrects
a claim, grep the WHOLE repo for that claim* — and S048 corrected it in the ADR
and the README while leaving the workflow saying the opposite.

⚠️ **The comment is the smaller half.** `bundle install` without `--deployment`
(or `bundle config set frozen true`) **resolves fresh and ignores the committed
lock**, so the lane has never actually run the versions the lock pins. Fixing the
comment without fixing the install would leave a truthful sentence describing an
unenforced lock — which is worse, because it reads as verified.

**Pair it with #121**, which asks whether the *"write App Store Connect API
key"* step is dead under manual signing. Same file, same lane, and the release
lane is **§7 — a session must never dispatch it**, so both are read-and-reason
changes whose verification is by inspection plus whatever the next founder-run
release reports. Say so plainly rather than implying a green.

## 1. Where things actually stand *(measured 2026-08-17 — re-measure, do not inherit)*

| | State |
|---|---|
| **Notifications, server side** | **RUNNING** as of S070: `prod_pulse.py --from-firebase-cli` exit 0, scheduler ENABLED. **Not re-measured since** — run it before relying on it. |
| **Notifications, device side** | **STILL ZERO** as of S071: `push_delivery_probe.py` exit 1, 0 of 4 accounts have ever registered. |
| **The build gap that gates it** | Last `release.yml` run is **2026-08-09, build 119**. Everything client-side merged since — ADR-046, ADR-049, ADR-051, ADR-052, **ADR-053** — is on **nobody's phone**. |
| **Deployed rules vs `main`** | `rules_drift.py` exited **1 for both projects** at the S071 close. Deploying is a **§7 founder ask**. Re-measure rather than inherit. |
| **`hayatiapp-prod` Functions** | Clean at S070. ⚠️ **S077 changed `functions/` source** (the export's device lane), so prod is now behind `main` on function code as well — a deploy is a **§7 ask**, and `functions_drift.py` should report it. |
| **`functions-drift` / `rules-drift` in CI** | Both **visibly SKIPPED** by design — one absent secret (operator **2(e)(iv)**). |
| **#137, #227, #208** | **CLOSED** (ADR-053, ADR-054, ADR-055). |
| **#176, #175, #174** | **CLOSED** — and they were still listed as *open* in `operator-expected.md` until S077 checked every row against `gh`. |

### What S076/S077/S078 changed that a later session will trip over

* `app/lib/core/l10n/strong_bidi_ranges.dart` is **GENERATED — never edit it.**
  Re-derive with `python3 tool/gen_bidi_rtl_ranges.py`; CI runs `--check` plus
  `tool/gen_bidi_rtl_ranges_test.py`. **If `--check` fails after a runner-image
  bump, read the message** — the table is pinned to the interpreter's Unicode
  version, and the tool prints a *different sentence* for "Unicode moved" than
  for a hand-edit.
* The generator's output must stay **`dart format`-clean**, or that gate and
  `--check` deadlock against each other permanently.
* **The export must never carry a raw FCM registration token, at any nesting
  level** (ADR-054). Delivery is `Clipboard.setData`, so a leak lands on the
  system pasteboard. `data-rights-core.test.ts` asserts this over the whole
  serialized projection; do not narrow it.
* **`integration-emulator`'s per-suite bounds must keep summing to LESS than
  `timeout-minutes`** (ADR-055). If they stop fitting, the watchdog can never
  fire, the job goes back to being **`cancelled`**, and `slack_notify.sh` goes
  back to saying nothing — a dead guard behind green tooling.
  `integration_watchdog_test.sh` asserts the arithmetic and derives the suite
  count from the tree, so **adding a sixth integration suite reddens it**. That
  is deliberate: move the bounds or the ceiling, consciously.
* **Do not probe a Firestore trigger** with `assert_emulator_functions.sh`.
  Measured: a loaded callable answers `400`, an unknown name `404`, and a
  **trigger also answers `404`** — so probing `answerReveal` fails against a
  perfectly healthy emulator. Pass callables only.
* **`integration-emulator` never runs on a PR.** Prove a change to it with
  `gh workflow run ci.yml --ref <branch>` before merging, as S078 did — a green
  PR says nothing about that job.
* `FORMAT_VERSION` is **3**. **Four** assertions pin it — three
  `expect(...formatVersion).toBe()` and the constant itself — and **two** carry
  the number in the *test's name*. Bump all of them together, or the next
  session debugs a name that disagrees with its own assertion (lesson **108**).

---

## 2. Then, in priority order

**1 — #226**, and it is the most serious open item in the repo: the privacy
policy tells users *"ikimiz does not send push notifications today"*, which is
true of the outcome and **false of the system**. **Founder/lawyer-blocked** — any
revision bumps `CURRENT_LEGAL_VERSION` and re-gates consent for every existing
user. A session can draft the wording; it cannot land it. **Now listed in
`operator-expected.md`**, which it was not before S077.

**2 — #204** (`deliver` has failed to create the `tr` localization on **every**
release since build 1) · **#165** (`rules-drift` built but unarmed) · **#136**
(the Functions-side bidi twin — device-blocked, but its fallback is not) ·
**#129/#121** (release lane) · **#115** · **#41** · **#63/#71** (brandkit).

⚠️ **Do not add `UIBackgroundModes: remote-notification`** without deciding SEC-3
first. Token capture needs none of it; only background *delivery* does.

---

## 3. Blocked — re-check every line

| What | Blocked on | Why a session cannot take it alone |
|---|---|---|
| **A build carrying ADR-046/049/051/052/053** | founder | `release.yml` uploads a real binary to TestFlight — **§7**. Last build **119, 2026-08-09** |
| **M3.4's last inch** | the founder's phone | One permission grant, on a build that has the fix. **If the prompt was ever declined, iOS will not show it again** |
| **Deploying S071's rules and S077's functions** | founder | §7. Both additive; `rules-drift`/`functions-drift` will report prod behind `main` |
| **`tr` App Store localization** | founder | Apple refuses the **name**, not the locale. A different Turkish display name fixes **eight** audit findings |
| **operator 2(d)** — Associated Domains | founder | Measured absent |
| **operator 2(e)(iii)** | founder | `FIREBASE_SERVICE_ACCOUNT`. Arms **three** lanes |
| **operator 2(e)(iv) / #165** | founder | One read-only SA, two roles |
| **operator 2(a)** | founder | The budget alert — the control that would have caught #219's cause rather than its symptom |
| **operator 0(c)** | founder | `RC_WEBHOOK_TOKEN` on dev |
| **operator 2(e)(ii)** | founder | The controller's legal name. Blocks `/privacy`, `/terms`, the listing |
| **#226** | founder/lawyer | Changing the legal texts re-gates consent for every existing user |
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
> (`session-context.md` §5, item 3). S076, S077 and S078 each ran **one**, on the
> built diff, while quoting the section by number. Read the whole clause before
> citing it (lesson **115**): the parts you are not quoting are the parts you
> have stopped doing.

> ⚠️ **WRITE THE ADR FIRST** (`session-context.md` §5.1, lesson **111**). S076 inverted it and paid
> three claims for it, including a figure — *"62,408"* — that corresponded to
> nothing measurable and had reached three files. S077 did it in the right order.
> An ADR written first must state its numbers while nothing green is lending
> them authority.

> ⚠️ **FREEZE THE TREE BEFORE THE REVIEW** (lesson **113**). S076 kept editing
> docs while its five lenses read the repo, and all three surfaced blockers were
> *"the documentation is uncommitted"* — true when read, false by the time it was
> read back, and never a defect in the change. Commit or stash first.

> ⚠️ **A scan whose glob matches nothing reports the same clean zero as a scan
> that passed** (lesson **110**). Assert a floor on the input before believing
> the output, in throwaway probes as much as in committed tests.

> ⚠️ **State a mutant by its measured post-condition, not its intent** (lesson
> **112**), and **assert the anchor landed before running the test** using
> **absolute paths** (lesson **109**).

> ⚠️ **Check the issue rows against `gh`, not against the last session's memory.**
> S077 found three CLOSED issues still listed as open in `operator-expected.md`,
> and **#226 — founder-blocked — listed in no operator document at all.**
