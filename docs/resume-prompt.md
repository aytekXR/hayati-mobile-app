# Resume Prompt — Session 068

> **This file contains ONE objective. That objective is the session; nothing else is.**
> (`project-rules.md` #1, `session-rules.md` §1.)
>
> Read `session-context.md` (toolchain, machine, review discipline, the
> never-without-asking list) and `session-lessons.md` (numbered to **99**) first.
> Re-derive the session number from `git log`.

**Objective: make a failed `deliver` VISIBLE — the engineering half of #204.**

> ⚠️ **S066 and S067 both deferred this**, and the reason each time was a live
> founder directive, not neglect: S066 fixed the two notification bugs
> (ADR-044 + #215) and S067 re-pointed the notification hours (ADR-045) and
> cleaned the operator page. The measurement phase is **already done and recorded
> as a comment on #204** — read it before designing:
>
> * the step already exits 1 with an `##[error]`; it has **no `id`**, so
>   `steps.<id>.outcome` is unreachable;
> * `slack_notify.sh` derives everything from job-level `NEEDS_JSON`, so a
>   step-level failure is structurally invisible to it;
> * **ADR-024 D1 is binding** — all notifier policy lives in that one tested
>   script and the notifier has **no vote** on the build. So the fix cannot be
>   "make the step fail" and cannot be a bespoke notification path.

`fastlane store_metadata (deliver per locale)` has failed identically on **every
release since build 112** — now nine of them, 112 through 119 — and every run was
green and Slack said nothing. `continue-on-error: true` is **right** there
(ADR-020 D8); lesson **69**: *`continue-on-error` is not the bug; an UNREAD
failure is.* It has already produced a wrong instruction to the founder twice
(lesson **91**).

**Do not grep for Apple's error string.** That is the same defect one level down —
it goes quiet the day the message changes, and quiet reads as fine. Assert
**positive evidence of publication per locale** (expected set from
`fastlane/metadata/*/`, actual from what deliver reports) and treat *absence of
evidence* as a finding (lesson **65**), with the repo's exit taxonomy.

⚠️ **You cannot dispatch `release.yml` to test this** (§7). The last nine runs'
logs are the fixture source: `gh api repos/:owner/:repo/actions/jobs/<id>/logs`,
**never** `gh run view --job --log` (lesson **65**). Job ids: `93254284862` (119),
`93165024416` (117), `92747059901` (116).

## 1. Where things actually stand *(measured 2026-08-09 — re-measure, do not inherit)*

| | State |
|---|---|
| **#166 — deployed vs merged Functions** | **CLOSED.** `firebase-functions-hash` turned out to be fully derivable from a checkout; all 13 prod hashes reproduced exactly. `tool/ci/functions_drift.py` + 157 hermetic checks + 22 mutations, ADR-043, architecture §9. Run it: `python3 tool/ci/functions_drift.py --project hayatiapp-prod --project hayatiapp-dev`. |
| **`hayatiapp-dev` Functions** | **Deployed from a clean tree this session** and now current: 12 of 13, every hash matching the reference exactly. The 13th (`revenueCatWebhook`) cannot deploy until operator **0(c)**. |
| **`hayatiapp-prod` Functions** | Running **this ref's source**, but hand-deployed from a laptop that swept in 62 gitignored files, so it does not equal a clean checkout. A **process** gap, not wrong code. That is **#206**, and the tool says so in those words. |
| **Push, server side** | **DONE and RUNNING.** All 13 exports deployed to prod; all three per-sweep summary lines on every hourly pass. |
| **Push, server side — MEASURED PROPERLY at last** | At the couple's OWN 08:00 (05:00Z; they are UTC+3, derived from `assigned: 1` at 21:00Z = local midnight) the sweep logs `checked:1  sent:0  skippedNoToken:2` and names both recipient uids. **Everything above the token lookup is verified working in production.** Reading `checked: 0` at any other hour says nothing — the pass is gated on couple-local hour 8 (lesson **97**). |
| **Notification hours** | **CHANGED on `main`, ADR-045**: question announcement **09:00** (was 08:00), unanswered nudge **22:00** (was 16:00), quiet window **23:00–08:00** (was 22:00) — the window HAD to move or the 22:00 nudge would have been swallowed by our own guard. **Production still runs the OLD hours** until Functions are redeployed (#206; a prod deploy is a §7 ask). `functions_drift.py` is what makes that visible. |
| **Push, device side** | **Was a real BUG, not just a missing tap** (ADR-044, merged S066). iOS delivers the APNs token *after* `requestPermission()` returns; capture asked once, in that window, caught the throw and never retried. **Builds 115–117 all carry it.** Fixed with a bounded retry. `registerPushToken` still has **zero device invocations** — re-measure with `firebase functions:log --only registerPushToken`. |
| **What push now needs** | **The founder's install + tap. Build 119 is live** (`internal=IN_BETA_TESTING`) and carries BOTH fixes — ADR-044's token-capture retry and #215's foreground presentation. `registerPushToken` still has **zero device invocations**; re-measure with `firebase functions:log --only registerPushToken`. |
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

**2 — Verify the push fix landed on a device, the moment a build ships.** The
instrument needs nothing from the founder (lesson **90**): `firebase functions:log
--project hayatiapp-prod --only registerPushToken` moves from deploy-audit-only
to a real invocation, and the couple's **05:00Z** sweep moves from
`skippedNoToken: 2` to `sent: N`. Read those, not the founder.

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
