# Resume Prompt — Session 071

> **This file contains ONE objective. That objective is the session; nothing else is.**
> (`project-rules.md` #1, `session-rules.md` §1.)
>
> Read `session-context.md` (toolchain, machine, review discipline, the
> never-without-asking list) and `session-lessons.md` (numbered to **107**) first.
> Re-derive the session number from `git log`.

**Objective: #221 — the device now KNOWS why it has no push token, and a session
still cannot read it.**

> ⚠️ **Read the objective's own ceiling before you start.** This slice writes a
> diagnostic the *server* can see. It becomes readable only on a device running a
> build that contains it — and **no build has been cut since 2026-08-09**
> (`release.yml`, sha `3550368`, build 119). ADR-046's Settings row, merged
> 2026-08-16, is on **nobody's phone**. So finish this slice, and then say
> plainly in the handoff that it — like ADR-046 before it — is waiting on a
> release the founder must authorise (`session-context.md` §7).

ADR-046 turned four indistinguishable device-side failures into five named states
and made them actionable **on the phone**. It deliberately added no server-visible
breadcrumb, so a session can still only answer *"did a device register"*, never
*"did the tap happen, and what did it do?"*.

Acceptance is in the issue and is not restated here. The four constraints that
shape it:

* a **client-writable** diagnostic field on `users/{uid}` — `fcmTokens` is
  server-owned and frozen in both directions (ADR-042 D1) and **must stay that
  way**, so this cannot ride on it;
* a `firestore.rules` change **plus** the rules tests that prove the freeze still
  holds and the new field cannot widen anything;
* an **ADR-019 cascade** review — the field is inside `users/{uid}` so it
  cascades today, and that needs asserting, not assuming;
* a `push_delivery_probe.py` mode that reads and names it.

**Crashlytics was considered and rejected** — breadcrumbs upload only attached to
a crash, non-fatals need the next launch, and neither has a read API a session
can call. It would move the signal from one place a session cannot read to
another.

```sh
python3 tool/ci/push_delivery_probe.py --from-firebase-cli
```

## 1. Where things actually stand *(measured 2026-08-17 — re-measure, do not inherit)*

| | State |
|---|---|
| **Notifications, server side** | **RUNNING, re-measured.** `prod_pulse.py --from-firebase-cli` exit **0** — billing enabled, scheduler ENABLED, last completed sweep 51m before measurement (`2026-08-16T23:00:05Z`), summary `assigned=0 buckets=1 existing=1 failed=0`. ADR-045's hours are live server-side (the Functions were deployed 2026-08-11, after #217). |
| **Notifications, device side** | **STILL ZERO.** `push_delivery_probe.py` exit 1 — **0 of 4** accounts have ever registered. Unchanged since S063. |
| **Why it is still zero, and the thing to say first** | **ADR-046's fix has never shipped.** The last `release.yml` run is **2026-08-09, sha `3550368`** — build 119. ADR-046 merged 2026-08-16 in `482f92f`. The Settings row that names which of the five states a phone is in, and the button that fixes it, exist only in `main`. **Cutting a build is a §7 founder ask** — ask for one early, then work the rest of the path (lesson **99**). |
| **The remaining notification unknown** | Whether the **APNs `.p8`** ever reached Firebase. Unreadable from any Google API (six endpoints tried). It surfaces only at the first real send, and `push_delivery_probe.py --send-test --confirm SEND` names it when it does. |
| **`hayatiapp-prod` Functions** | **CLEAN, and this is a CORRECTION.** `functions_drift.py` exit **0** — 13 deployed, reference `c250c5c25611e2fa…` over 213 files, **0 foreign**. ADR-043's 62 gitignored debris files are gone; the 2026-08-11T10:51Z redeploy was made from a clean tree and `functions/` has not changed since `52d8065`. The prediction in `operator-expected.md` that the first armed `functions-drift` run would report prod drifted has been **withdrawn**. |
| **`hayatiapp-dev` Functions** | **In sync except one.** S070 deployed 12 of 13 through the lane's own command sequence; `revenueCatWebhook` is absent and cannot deploy there until **0(c)** puts `RC_WEBHOOK_TOKEN` on dev. Unscoped the checker is therefore exit 1, for a named and filed reason. |
| **Deployed rules** | Both projects matched `main` at the last measurement (2026-08-16). **Not re-measured at S070** — run `rules_drift.py --from-firebase-cli` before relying on it. |
| **`functions-drift` / `rules-drift` in CI** | Both **visibly SKIPPED** by design — one absent secret (operator **2(e)(iv)**). |
| **#206** | **CLOSED (ADR-048).** `deploy-functions.yml` exists: dispatch-only, prod pinned to `main` **and** behind a typed project id, measure → deploy → read back. **Unarmed** until **2(e)(iii)** — like `deploy-rules.yml`, which has also never run. |
| **#219** | Cause fixed, detection instrumented. Residual: the **budget alert** (operator 2(a)) is still unset, and `prod_pulse` has no scheduled lane. |

---

## 2. Then, in priority order

**1 — #222**, this session's filed audit: 10 verified stale claims across the
handoff documents, including a false *"nothing writes `fcmTokens` yet"* in
`architecture.md` and two contradictions inside the notifications section of
`operator-expected.md`. Cheap, and it is the class of defect that gets *executed*
(lesson **64**).

**2 — #223** (`deploy-rules.yml` can publish a **branch's** rules to prod — it
checks the typed project id and never the ref — and neither it nor
`deploy-site.yml` declares `concurrency`; `deploy-functions.yml` closes both for
its own lane and #223 is the argument for doing the same there).

**3 — #208** (`integration-emulator` hung silently and burned its whole 50-minute
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
| **A build carrying ADR-046** | founder | `release.yml` uploads a real binary to TestFlight — **§7**. The last build is **119, 2026-08-09**; everything client-side merged since is on no device. This gates M3.4's last inch *and* #221's payoff |
| **M3.4's last inch** | the founder's phone | One permission grant, on a build that has the fix. **If the prompt was ever declined, iOS will not show it again** — 119's only remedy is iOS Settings → Notifications → ikimiz, which works today |
| **`tr` App Store localization** | founder | Apple refuses the **name**, not the locale. Needs a different Turkish display name; picking one fixes **eight** audit findings |
| **operator 2(d)** — Associated Domains | founder | Measured absent. Same portal page as the push tick |
| **operator 2(e)(iii)** | founder | `FIREBASE_SERVICE_ACCOUNT`. Now arms **three** lanes, and its role list **changed at S070** — four roles, measured against the IAM API. Gates arming `deploy-functions.yml` |
| **operator 2(e)(iv) / #165** | founder | One read-only SA, two roles. Until then `rules-drift` **and** `functions-drift` are SKIPPED by design |
| **operator 2(a)** | founder | The budget alert — the one control that would have caught #219's cause rather than its symptom |
| **operator 0(c)** | founder | `RC_WEBHOOK_TOKEN` on dev. Measured absent again at S070; it is why dev runs 12 of 13 functions |
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

> ⚠️ **S068 did not append its entry.** S070 did. Step 1 is not optional and it is
> the one that gets skipped.

> ⚠️ **A harness that mutates tracked files is a write tool** (lesson **96**).
> S070 ran five mutations against `functions_drift.py` inline, each with an
> explicit restore and a `diff` against a pre-mutation copy — and note the trap it
> hit: `git diff --stat` was the *wrong* baseline, because the session's own
> uncommitted work is legitimately in that diff. Compare against a copy, not
> against HEAD.

> ⚠️ **Aggregation reduces what you read; it does not decide what is true**
> (lesson **107**). S070's built-diff review had both verifiers refute a finding
> that was real — a two-minute mutant proved it. Read the raw findings list.
