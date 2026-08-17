# Resume Prompt — Session 078

> **This file contains ONE objective. That objective is the session; nothing else is.**
> (`project-rules.md` #1, `session-rules.md` §1.)
>
> Read `session-context.md` (toolchain, machine, review discipline, the
> never-without-asking list) and `session-lessons.md` (numbered to **113**) first.
> Re-derive the session number from `git log`.

**Objective: #208 — `integration-emulator` hung SILENTLY for 38 minutes and burned
its whole budget, and the previous mitigation was to raise the ceiling.**

This is blow-out **two**, and the two have **different shapes** — which is the
part a session must not flatten:

* **S024's** was uniform slowness. Suites kept printing progress; a slow macOS
  runner ran the same work ~55% longer and hit `timeout-minutes: 40` exactly. The
  fix was 40 → 50.
* **This one emitted nothing at all for 38 minutes**, parked at `00:00 +0`
  immediately after a clean 49-second Xcode build. A slow runner still prints.
  That is a **hang** — the app never reaching the emulators, or the simulator
  wedging — not a budget shortfall.

**So raising 50 → 60 converts a 50-minute hang into a 60-minute hang.** Do not.

Two facts worth carrying in before measuring anything:

1. **GitHub reported the conclusion as `cancelled`, not `failure`.** That reads
   like a human pressed a button, and `slack_notify.sh` reported everything else
   as success-shaped. A timeout on the one **main-only** job is exactly ADR-024's
   founding case — the red that lands after the session's attention has moved on.
2. **It was checked, not assumed, that this was not a regression.** The merge
   touched nothing under `app/` or `functions/`, and a re-run of the same job on
   the same commit passed while genuinely running all four suites. The re-run
   still took **37m46s**, against the 25–26 min the job's own comment calls
   healthy.

The issue's own checklist is a good starting shape — a per-suite watchdog that
**names itself** when it fires, something logged during the silence so there is
anything at all to debug from, distinct Slack handling for `cancelled`, and a
re-check of whether four serial Xcode debug builds are still the right trade
(that is most of the 25–26 min baseline and is what leaves no headroom).

⚠️ **The trap in this one:** a watchdog that fires is easy to build and easy to
get wrong in the way this repo keeps finding — a timeout that reports "timed out"
without saying *which suite, at which phase* is the same non-diagnosis in a
shorter wrapper. And it will be **hard to test**, because the failure is a hang
you cannot reproduce on demand. Decide before writing code what evidence would
prove the watchdog works, and note that **the emulator suite cannot run on this
box without `~/.local/share/java/jdk-21.0.11+10-jre/bin` on PATH** — S077 lost a
run to `java: command not found` before reading `session-context.md` §"Functions
/ emulator", which documents it.

## 1. Where things actually stand *(measured 2026-08-17 — re-measure, do not inherit)*

| | State |
|---|---|
| **Notifications, server side** | **RUNNING** as of S070: `prod_pulse.py --from-firebase-cli` exit 0, scheduler ENABLED. **Not re-measured since** — run it before relying on it. |
| **Notifications, device side** | **STILL ZERO** as of S071: `push_delivery_probe.py` exit 1, 0 of 4 accounts have ever registered. |
| **The build gap that gates it** | Last `release.yml` run is **2026-08-09, build 119**. Everything client-side merged since — ADR-046, ADR-049, ADR-051, ADR-052, **ADR-053** — is on **nobody's phone**. |
| **Deployed rules vs `main`** | `rules_drift.py` exited **1 for both projects** at the S071 close. Deploying is a **§7 founder ask**. Re-measure rather than inherit. |
| **`hayatiapp-prod` Functions** | Clean at S070. ⚠️ **S077 changed `functions/` source** (the export's device lane), so prod is now behind `main` on function code as well — a deploy is a **§7 ask**, and `functions_drift.py` should report it. |
| **`functions-drift` / `rules-drift` in CI** | Both **visibly SKIPPED** by design — one absent secret (operator **2(e)(iv)**). |
| **#137, #227** | **CLOSED** (ADR-053, ADR-054). |
| **#176, #175, #174** | **CLOSED** — and they were still listed as *open* in `operator-expected.md` until S077 checked every row against `gh`. |

### What S076/S077 changed that a later session will trip over

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

> ⚠️ **WRITE THE ADR FIRST** (§5.1, lesson **111**). S076 inverted it and paid
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
