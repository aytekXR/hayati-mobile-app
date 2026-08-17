# Resume Prompt — Session 076

> **This file contains ONE objective. That objective is the session; nothing else is.**
> (`project-rules.md` #1, `session-rules.md` §1.)
>
> Read `session-context.md` (toolchain, machine, review discipline, the
> never-without-asking list) and `session-lessons.md` (numbered to **109**) first.
> Re-derive the session number from `git log`.

**Objective: #137 — the bidi seam asks `intl` which way a string leans, and
`intl` gets Arabic Extended-A wrong.**

`isolateWithin()` decides whether to emit the isolate controls from
`Bidi.startsWithLtr()`. `intl`'s RTL character class
(`intl-0.20.2/lib/src/intl/bidi.dart:46-49`) runs `֑-߿` and `יִ-﷽` and `ﹰ-ﻼ` —
and **Arabic Extended-A (U+08A0–U+08FF) falls outside it while `intl`'s LTR
class matches it.** So `startsWithLtr()` returns **true** for a string starting
with a strong *RTL* character.

The issue has the measured table (`U+0627` classifies correctly; `U+08A0` and
`U+08B5` do not; `U+1E900` ADLAM matches neither class). Verify it with
`python3 unicodedata` before designing — do not inherit it.

**Why it is worth a session despite being low severity:** the failure is
**silent and one-directional**.

* In **RTL chrome** it is harmless — the seam isolates anyway and `FSI` resolves
  by the *real* first-strong character, which agrees with the paragraph. Correct
  by accident.
* In **LTR chrome** the mirror defect survives: the seam believes content and
  paragraph agree, emits nothing, and the trailing neutral stays on the wrong
  end. **Nothing goes red.**

That is recurring shape 5 — *a guard that guards one direction and is silent on
the others* — in the one seam ADR-033 built to prevent exactly this.

⚠️ **ADR-033's invariant is binding** (`session-context.md` §6): isolation is
applied at the **string boundary and at render only**, and nothing persisted,
exported or shared may carry `U+2068`/`U+2069`. A fix that widens the
first-strong test must not widen *where* isolation happens.

The existing `content_text_test.dart` is the mold and it is unusually good —
it asserts a *specification* (the terminating punctuation binds to the trailing
side of its own run) read back from `RenderParagraph.getBoxesForSelection`,
never a coordinate, and it never calls `isolate()` to build its expectation. Add
to it rather than beside it.

## 1. Where things actually stand *(measured 2026-08-17 — re-measure, do not inherit)*

| | State |
|---|---|
| **Notifications, server side** | **RUNNING** at the last measurement (S070): `prod_pulse.py --from-firebase-cli` exit 0, scheduler ENABLED, sweep summary `assigned=0 buckets=1 existing=1 failed=0`. **Not re-measured at S071** — run it before relying on it. |
| **Notifications, device side** | **STILL ZERO, re-measured 2026-08-17.** `push_delivery_probe.py` exit 1 — 0 of 4 accounts have ever registered. Unchanged since S063. |
| **What is NEW, and its ceiling** | **ADR-049 shipped**: `users/{uid}.pushDiagnostic` — the device's own report of *why* it has no token (state + detail + server-stamped time), read and named by `push_delivery_probe.py`. It reports **nothing until a build ships**: the last `release.yml` run is **2026-08-09, build 119**, and ADR-046's Settings row **and** this field are both on nobody's phone. The probe says so in those words rather than letting four silent accounts read as a negative. |
| **`fcmTokens`** | Untouched and re-proven: server-owned, frozen at create and update, and a valid diagnostic in the same write as a token mint is still denied. |
| **The remaining notification unknown** | Whether the **APNs `.p8`** ever reached Firebase. Unreadable from any Google API (six endpoints tried). It surfaces only at the first real send, and `push_delivery_probe.py --send-test --confirm SEND` names it when it does — which needs a registered device first. |
| **Deployed rules vs `main`** | **MEASURED at the S071 close: `rules_drift.py --from-firebase-cli` exits 1 for BOTH projects.** S071 changed `firestore.rules`, so prod and dev are each serving a ruleset that is not this ref. Additive and harmless meanwhile — the deployed ruleset simply validates nothing where the new one validates a shape — but **deploying it is a §7 founder ask**. ⚠️ **Do not read that as "the field does not work until it deploys."** The OLD ruleset has no `pushDiagnostic` clause and the users update rule has no `hasOnly`, so a device's writes LAND either way — what is missing until the deploy is the *validation*, i.e. the guarantee that what the probe reads is a shape it can trust. Re-measure rather than inherit. |
| **`hayatiapp-prod` Functions** | CLEAN at S070 (`functions_drift.py` exit 0, 13 deployed, 0 foreign). `functions/` **source** is unchanged by S071 — only its tests moved — so no redeploy is implied. |
| **`hayatiapp-dev` Functions** | 12 of 13; `revenueCatWebhook` cannot deploy there until **0(c)** puts `RC_WEBHOOK_TOKEN` on dev. Unscoped the checker is exit 1, for a named and filed reason. |
| **`functions-drift` / `rules-drift` in CI** | Both **visibly SKIPPED** by design — one absent secret (operator **2(e)(iv)**). |
| **#221** | **CLOSED (ADR-049).** |

---

## 2. Then, in priority order

**1 — #222**, S071's filed stale-claims audit: 10 verified stale claims across the
handoff documents. **Two were served in passing** by S071 (the false *"nothing
writes `fcmTokens` yet"* in `architecture.md` §3 and its twin in
`dpa-inventory.md`) because that diff touched those exact lines — the other eight
are open, including the two contradictions inside `operator-expected.md`'s
notifications section. Cheap, and it is the class of defect that gets *executed*
(lesson **64**).

**2 — #226 / #227**, both filed by S071 and both needing a decision rather than
code: the privacy policy says *"ikimiz does not send push notifications today"*
and names none of the device data we store (**#226** — a fix bumps
`CURRENT_LEGAL_VERSION` and **re-gates consent for every user**, so it is a
founder/lawyer call), and the export whitelist omits `fcmTokens` and
`pushDiagnostic` (**#227**).

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
| **A build carrying ADR-046 + ADR-049** | founder | `release.yml` uploads a real binary to TestFlight — **§7**. Last build **119, 2026-08-09**. Everything client-side merged since is on no device, and **ADR-049's whole payoff is behind it** |
| **M3.4's last inch** | the founder's phone | One permission grant, on a build that has the fix. **If the prompt was ever declined, iOS will not show it again** — 119's only remedy is iOS Settings → Notifications → ikimiz, which works today |
| **Deploying S071's rules** | founder | §7. Additive, so nothing is broken until it lands — but `rules-drift` will report prod behind `main` |
| **`tr` App Store localization** | founder | Apple refuses the **name**, not the locale. Needs a different Turkish display name; picking one fixes **eight** audit findings |
| **operator 2(d)** — Associated Domains | founder | Measured absent. Same portal page as the push tick |
| **operator 2(e)(iii)** | founder | `FIREBASE_SERVICE_ACCOUNT`. Arms **three** lanes — and is what makes #223's fix testable by dispatch rather than by reading |
| **operator 2(e)(iv) / #165** | founder | One read-only SA, two roles. Until then `rules-drift` **and** `functions-drift` are SKIPPED by design |
| **operator 2(a)** | founder | The budget alert — the one control that would have caught #219's cause rather than its symptom |
| **operator 0(c)** | founder | `RC_WEBHOOK_TOKEN` on dev. Why dev runs 12 of 13 functions |
| **operator 2(e)(ii)** | founder | The controller's legal name. Blocks `/privacy`, `/terms`, the listing |
| **#226** | founder/lawyer | Changing the legal texts re-gates consent for every existing user |
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

> ⚠️ **A mutation run that applies nothing prints the same green as a guard that
> works** (lesson **109**). S071's first parity mutation run edited *nothing* — a
> `cd` inside the runner left the script opening a relative path that did not
> exist — and reported three passes with the traceback two lines above them.
> Assert the anchor and the landed edit **before** running the test, and use
> absolute paths.

> ⚠️ **When a mutant survives, suspect the test's NAME first** (lesson **108**).
> S071 found a guard whose test proved a different guard entirely. The three
> honest resolutions are delete it, make it reachable, or rename the test to what
> it measures and record that the guard is unfalsifiable there. "Leave it" is not
> one of them.

> ⚠️ **An empty lens is UNVERIFIED, never a clean bill** (§5.5). Two of S071's five
> design lenses returned zero findings, and the `data-rights` silence was a false
> negative — the legal gap now filed as #226 was found by hand afterwards, in the
> files that lens had been pointed at. Read the raw findings list (lesson **107**),
> and when a lens is quiet on a subject you have not checked yourself, check it.
