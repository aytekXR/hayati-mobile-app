# Resume Prompt — Session 070

> **This file contains ONE objective. That objective is the session; nothing else is.**
> (`project-rules.md` #1, `session-rules.md` §1.)
>
> Read `session-context.md` (toolchain, machine, review discipline, the
> never-without-asking list) and `session-lessons.md` (numbered to **104**) first.
> Re-derive the session number from `git log`.

**Objective: #206 — the Cloud Functions deploy lane, the last deploy target that
is a hand-typed command nothing tracks.**

> ⚠️ **This is not a tidiness task. It has already cost this project twice.**
> S063 shipped the entire push feature merged and green while the callables the
> app calls **did not exist in production** (lesson 86). S068's outage found all
> **13** deployed functions drifted from `main` at once. Both have the same
> cause: `deploy-rules.yml` and `deploy-site.yml` exist; functions have no lane,
> so every deploy is a laptop command with no record and no readback.

Follow `deploy-rules.yml` (**ADR-041 D5**), which is the precedent and the shape:

* **dispatch-only**, never on push;
* **typed project-id confirmation** for prod;
* **measure BEFORE deploying** — `functions_drift.py` exit 2 aborts, exit 1 is
  the normal reason to be running it at all;
* deploy;
* **read back**, and say what changed.

It will ship **unarmed** until operator **2(e)(iii)** (`FIREBASE_SERVICE_ACCOUNT`),
exactly like `deploy-rules.yml` did. That is fine and precedented — **say so
rather than letting it look armed.** Deploying prod is a §7 ask either way.

```sh
python3 tool/ci/functions_drift.py --project hayatiapp-prod --project hayatiapp-dev
```

## 1. Where things actually stand *(measured 2026-08-16 — re-measure, do not inherit)*

| | State |
|---|---|
| **Notifications, server side** | **VERIFIED WORKING, to the last inch.** `prod_pulse.py` exit 0; the 06:00Z sweep reads `checked:1 skippedNoToken:2 sent:0` and names both uids; `fcm-adapter` sends `notification:{title,body}` (not data-only); the quiet window `>=23 \|\| <8` clears both 09:00 and 22:00. |
| **Notifications, the callable** | **REACHABLE.** Cloud Run `getIamPolicy`: `registerpushtoken` **and** `unregisterpushtoken` grant `roles/run.invoker` to `allUsers`. The #115 shape was the leading hypothesis and it is **refuted** — do not re-raise it without re-reading the policy. |
| **Notifications, device side** | **`registerPushToken` has still never been called.** 4 accounts, no `fcmTokens` on any; Cloud Logging shows **zero HTTP requests** ever reaching it. **ADR-046 shipped the fix for the reason nobody could tell WHY**: five named states, read from the OS without spending iOS's one-per-install dialog, shown and made actionable in Settings, plus a repeatable retry and explicit APNs forwarding in `AppDelegate`. **Re-measure with `python3 tool/ci/push_delivery_probe.py --from-firebase-cli`** — the moment it reports ≥1, the feature is closed. |
| **The remaining notification unknown** | Whether the **APNs `.p8`** ever reached Firebase. Unreadable from any Google API (six endpoints tried). It surfaces only at the first real send, and `push_delivery_probe.py --send-test --confirm SEND` names it when it does. |
| **#204** | **Engineering half CLOSED** (ADR-047). `store_metadata_audit.py` asserts positive evidence of publication per locale and is wired into `release.yml` (non-blocking, job output) and `slack_notify.sh` (`EXTRA_FINDINGS`, all policy in the script). **Run against the live listing (run 31949645300): `tr` NOT PUBLISHED *and* seven of `en-US`'s nine fields differ** — deliver dies before the upload phase, so the committed copy has never been published at all. The Turkish **name** remains a founder decision. |
| **`hayatiapp-prod` Functions** | All 13 redeployed 2026-08-11 and current with ADR-045's hours — but hand-deployed. That process gap is **this session's objective**. |
| **Deployed rules** | **Both projects match this ref**, re-measured 2026-08-16 (`rules_drift.py --from-firebase-cli`, exit 0). |
| **`functions-drift` / `rules-drift` in CI** | Both **visibly SKIPPED** by design — one absent secret (operator **2(e)(iv)**, which now needs **Cloud Functions Viewer** as well). |
| **#219** | Cause fixed (billing restored), detection instrumented (`prod_pulse.py`). Residual: the **budget alert** (operator 2(a)) is still unset, and `prod_pulse` has no scheduled lane. |

---

## 2. Then, in priority order

**1 — #221**, this session's own deferral: the device now *knows* why it has no
token and a session still cannot read it. Needs a client-writable diagnostic
field, a `firestore.rules` change with the freeze re-proven, an ADR-019 cascade
review, and a `push_delivery_probe.py` mode. Crashlytics was considered and
rejected — no read API.

**2 — #208** (`integration-emulator` hung silently and burned its whole 50-minute
budget; second blow-out, and raising the ceiling again is not a fix) · **#175**
(10 of 14 raised cards render flat) · **#174** (no `liveRegion` — the reveal is
never announced) · **#137** · **#136** · **#129/#121** · **#115** · **#41**.

⚠️ **Do not add `UIBackgroundModes: remote-notification`** without deciding SEC-3
first. Token capture needs none of it; only background *delivery* does.
`signing_sentinel_test` reddens if it is added.

---

## 3. Blocked — re-check every line

| What | Blocked on | Why a session cannot take it alone |
|---|---|---|
| **M3.4's last inch** | the founder's phone | One permission grant. **If the prompt was ever declined, iOS will not show it again** — the next build's Settings row says so and opens the right page; iOS Settings → Notifications → ikimiz works on 119 today. Verification needs nobody (lesson 90). |
| **`tr` App Store localization** | founder | Apple refuses the **name**, not the locale. Needs a different Turkish display name. Picking one now fixes **eight** audit findings, not one. |
| **operator 2(d)** — Associated Domains | founder | Measured absent. Same portal page as the push tick |
| **operator 2(e)(iii)** | founder | `FIREBASE_SERVICE_ACCOUNT`. Gates ARMING this session's **#206** lane |
| **operator 2(e)(iv) / #165** | founder | One read-only SA, now needing **two** roles. Until then `rules-drift` **and** `functions-drift` are SKIPPED by design |
| **operator 2(a)** | founder | The budget alert — the one control that would have caught #219's cause rather than its symptom |
| **operator 0(c)** | founder | `RC_WEBHOOK_TOKEN` on dev |
| **operator 2(e)(ii)** | founder | The controller's legal name. Blocks `/privacy`, `/terms`, the listing |
| **#115** | founder | Making a prod endpoint world-reachable is a security decision on a live system. **Re-measured 2026-08-16: still no `allUsers` invoker.** |
| **#41** | founder | Live billing identity — *clean change* vs *migration* |
| **#48**, **#15**, **#136** | the device | On-device observation nobody has made |
| **#13** | M6.5 | Android, Gate-3 gated (ADR-006) |
| **#63**, **#71** | founder | Brandkit revisions |

---

## 4. Close sequence — `session-rules.md` §3/§4

Append to `past-prompts.md` → regenerate this file (one objective) → refresh
`operator-expected.md` → commit + push → verify CI → **watch the post-merge `main` run**
(`integration-emulator` is main-only) → `codegraph sync`.

> ⚠️ **S068 did not append its entry.** Five commits, two tools, two lessons and
> an issue, and no `past-prompts.md` record — noted as a gap by S069 rather than
> reconstructed, because only that session could write it. **Step 1 is not
> optional and it is the one that gets skipped.**

> ⚠️ **A harness that mutates tracked files is a write tool** (lesson 96). This
> session ran five mutations against `slack_notify.sh` inline, with an explicit
> restore and a `git diff --stat` verification afterwards, and with no concurrent
> agent in flight. `session-context.md` §5.8's `git status` check applies to every
> measurement taken *while* a review is running, not only to the commit after it.
