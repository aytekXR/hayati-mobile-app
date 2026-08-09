# Resume Prompt — Session 066

> **This file contains ONE objective. That objective is the session; nothing else is.**
> (`project-rules.md` #1, `session-rules.md` §1.)
>
> Before starting, read the two companions:
> * **`session-context.md`** — toolchain, machine, review discipline, binding
>   invariants, and the never-without-asking list.
> * **`session-lessons.md`** — the institutional lessons, now numbered to **96**.
>   Cited below by number.
>
> Re-derive the session number from `git log`; a session on another machine can consume it.

**Objective: make a failed `deliver` VISIBLE, so a green release can never again
mean "store metadata silently did not land" — the engineering half of #204.**

This is not the Turkish-name decision. That half is the founder's and is
correctly stated on the operator page; **do not touch it and do not re-ask it.**

The defect is underneath it and is entirely ours: `fastlane store_metadata
(deliver per locale)` in `release.yml` has failed **identically on every release
since build 112** — six of them — and the step reports success, the job reports
success, the run is green, and Slack says nothing. `continue-on-error: true` is
**right** there (ADR-020 D8: the binary already shipped; store copy is
native-review-gated and must never fail a release). Lesson **69** is exact:
*`continue-on-error` is not the bug; an UNREAD failure is.*

**It has already produced real harm, twice** — `operator-expected.md` told the
founder for several sessions that Turkish screenshots were blocked by an unclicked
button, and S064 wrote a *fresh* version of that same wrong instruction from a
correct measurement and a wrong inference. That is lesson **91**: an unread
failure does not stay silent, it gets *explained*, and the explanation lands on a
person.

### The constraint that shapes the design

**ADR-024 D1: all notifier policy lives in `tool/ci/slack_notify.sh`, and the
notifier has NO VOTE on the build.** So the fix cannot be "make the step fail",
and it cannot be a new bespoke notification path. Read that ADR before designing;
the invariant is binding (`session-context.md` §6).

Read the whole of **#204** — it names the acceptance criteria and its first one
is *visibility*, not the fix.

### Watch for the shape this repo keeps paying for

Whatever you build, it must be **impossible to satisfy vacuously**. A "check the
deliver log" step that greps for a string and prints nothing when the log format
changes is the same defect one level down. Give it a hermetic self-test in
`quality` and mutation-check it, the way `functions_drift_test.py` and
`app_icons_test.py` are — and make sure the **absence** of the expected evidence
is a finding, not a pass (lesson **65**).

⚠️ **You cannot dispatch `release.yml` to test this** — it uploads a real binary
to the founder's TestFlight and is on the never-without-asking list
(`session-context.md` §7). Design so the logic is provable *without* a release
run; the last six runs' logs are already on GitHub and are your fixture source
(`gh api repos/:owner/:repo/actions/jobs/<id>/logs` — **never** `gh run view
--job --log`, lesson **65**).

---

## 1. Where things actually stand *(measured 2026-08-09 — re-measure, do not inherit)*

| | State |
|---|---|
| **#166 — deployed vs merged Functions** | **CLOSED.** `firebase-functions-hash` turned out to be fully derivable from a checkout; all 13 prod hashes reproduced exactly. `tool/ci/functions_drift.py` + 157 hermetic checks + 22 mutations, ADR-043, architecture §9. Run it: `python3 tool/ci/functions_drift.py --project hayatiapp-prod --project hayatiapp-dev`. |
| **`hayatiapp-dev` Functions** | **Deployed from a clean tree this session** and now current: 12 of 13, every hash matching the reference exactly. The 13th (`revenueCatWebhook`) cannot deploy until operator **0(c)**. |
| **`hayatiapp-prod` Functions** | Running **this ref's source**, but hand-deployed from a laptop that swept in 62 gitignored files, so it does not equal a clean checkout. A **process** gap, not wrong code. That is **#206**, and the tool says so in those words. |
| **Push, server side** | **DONE and RUNNING.** All 13 exports deployed to prod; all three per-sweep summary lines on every hourly pass. |
| **Push, device side** | **STILL ZERO — re-measured 2026-08-09.** `registerPushToken` has only ever received `CreateFunction` audit entries, never a device call, and `daily-question sweep complete` still logs `checked: 0` on every pass. Nobody has opened a build and tapped Allow. |
| **Build 117** | Live, `external=IN_BETA_TESTING`, carries the icon and the whole push slice. |
| **Deployed rules** | Both projects matched `main` on 2026-08-08. Re-measure with `rules_drift.py --from-firebase-cli`. |
| **`functions-drift` / `rules-drift` in CI** | Both **visibly SKIPPED** by design — one absent secret (operator **2(e)(iv)**, whose instructions changed this session: the same account now needs **Cloud Functions Viewer** too). |

---

## 2. Then, in priority order

**1 — #206, the Cloud Functions deploy lane.** Filed this session as #166's
residual, and the direct reason prod cannot be compared to a clean checkout.
Follow `deploy-rules.yml` (ADR-041 D5): dispatch-only, typed project-id
confirmation for prod, **measure before deploying** (exit 2 aborts, exit 1 is the
normal reason to be running it), deploy, **read back**. It will ship *unarmed*
until operator **2(e)(iii)**, exactly like `deploy-rules.yml` — that is fine and
precedented, but say so rather than letting it look armed.

**2 — #188 may already be done; verify before working it.** It is blocked "until
`appid-capabilities.yml` returns exit 0", and `PUSH_NOTIFICATIONS` was ticked on
**2026-08-06**. Builds 115–117 carry the entitlement, `registerPushToken` is
deployed, and 116/117 do ask for permission. **Re-derive its state and close it if
it is stale** rather than re-implementing something that shipped.

**3 — The rest.** Re-derive from `gh issue list`. **#208** (`integration-emulator`
hung silently and burned its whole 50-minute budget — second blow-out, and
raising the ceiling again is not a fix) · **#175** (10 of 14 raised cards render
flat) · **#174** (no `liveRegion` — the reveal is never announced) · **#137** ·
**#136** · **#129/#121** · **#115** · **#41**.

⚠️ **Do not add `UIBackgroundModes: remote-notification`** without deciding SEC-3
first. Token capture needs none of it; only background *delivery* does.
`signing_sentinel_test` reddens if it is added.

---

## 3. Blocked — re-check every line

| What | Blocked on | Why a session cannot take it alone |
|---|---|---|
| **M3.4's last inch** | the founder's phone | One install + one permission tap. Every other layer is done and measured. Verification no longer needs the founder (lesson **90**) — only the tap does. |
| **`tr` App Store localization** | founder | Apple refuses the **name**, not the locale. Needs a decision (a different Turkish display name), not a click. The engineering half is this session's objective. |
| **operator 2(d)** — Associated Domains | founder | Measured absent. Same portal page as the push tick |
| **operator 2(e)(iii)** | founder | `FIREBASE_SERVICE_ACCOUNT`. Gates arming any deploy lane in CI — including **#206** |
| **operator 2(e)(iv) / #165** | founder | One read-only SA, now needing **two** roles. Until then `rules-drift` **and** `functions-drift` are SKIPPED by design |
| **operator 0(c)** | founder | `RC_WEBHOOK_TOKEN` on dev. The reason dev runs 12 of 13 functions |
| **operator 2(e)(ii)** | founder | The controller's legal name. Blocks `/privacy`, `/terms`, the listing |
| **#115** | founder | Making a prod endpoint world-reachable is a security decision on a live system |
| **#41** | founder | Live billing identity — *clean change* vs *migration* |
| **#48**, **#15**, **#136** | the device | On-device observation nobody has made |
| **#13** | M6.5 | Android, Gate-3 gated (ADR-006) |
| **#63**, **#71** | founder | Brandkit revisions |

---

## 4. Close sequence — `session-rules.md` §3/§4

Append to `past-prompts.md` → regenerate this file (one objective) → refresh
`operator-expected.md` → commit + push → verify CI → **watch the post-merge `main` run**
(`integration-emulator` is main-only) → `codegraph sync`.

**S062, S063, S064 and S065 all ran it. Keep the streak.**

> ⚠️ **New, and it cost this session a wrong measurement (lesson 96).** A review
> agent told "read-only" ran the session's **own mutation harness** out of the
> scratchpad; it writes a mutation into the source and restores a snapshot in a
> `finally`, and its restore silently reverted an edit made after that snapshot.
> Nothing errored. **A harness that mutates tracked files is a write tool** —
> move it out of reach before any concurrent agent runs — and `session-context.md`
> §5.8's `git status` check applies to every measurement taken *while* a review
> is in flight, not only to the commit afterwards.
