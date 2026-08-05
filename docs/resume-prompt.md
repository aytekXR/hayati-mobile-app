# Resume Prompt — Session 063

> **This file contains ONE objective. That objective is the session; nothing else is.**
> (`project-rules.md` #1, `session-rules.md` §1.)
>
> Before starting, read the two companions:
> * **`session-context.md`** — toolchain, machine, review discipline, binding
>   invariants, and the never-without-asking list.
> * **`session-lessons.md`** — the institutional lessons, numbered to **82**. Cited
>   below by number.
>
> Re-derive the session number from `git log`; a session on another machine can consume it.

**Objective: make a push actually arrive — build the daily-question kind and the
two clock hours the founder asked for (#189, ADR-042 D3/D4).**

---

## 1. Where things actually stand *(measured 2026-08-06 — re-measure, do not inherit)*

| | State |
|---|---|
| **`users.fcmTokens`** | **Has a writer and a lock as of S062** (#187). `registerPushToken` / `unregisterPushToken`, frozen in `firestore.rules` at create AND update, mutation-proven both ways. |
| **A push reaching a phone** | **Still never happened.** The device half is #188 and is founder-blocked. |
| **App ID capabilities** | **Measured** 2026-08-06, run `31054773143`: `APPLE_ID_AUTH` + `IN_APP_PURCHASE` ticked. **`PUSH_NOTIFICATIONS`, `ASSOCIATED_DOMAINS`, `APP_ATTEST` all ABSENT.** |
| **Build 113** | Apple-approved, `IN_BETA_TESTING`, 8 in `Friends` (2 anonymous public-link installs). |
| **Build 114** | Uploaded 2026-08-02, **`READY_FOR_BETA_SUBMISSION` — never submitted.** Everyone is still testing 113. |
| **Screenshots** | en-US: 6 live since 2026-08-03. `tr` never uploaded (needs its version localization first). |
| **#115 webhook** | still HTML 403. |

**Re-derive all of it.** The capability line is one `gh workflow run
appid-capabilities.yml` away and is the single most decision-changing fact on this page.

---

## 2. THE OBJECTIVE — #189, the fourth kind and the two hours

The founder, verbatim 2026-08-05:

> app does not sent notificaiton. It needs to be send new questions at 08.00 TSI with a
> question. And when your partner answers your question you need to be notified. If you
> did not reply the question as of 16.00 you need to be notified so that your partner
> dont get angry.

**"Partner answered" is already built.** These are the other two, and **both are pure
Functions logic, fully emulator-provable — no plugin, no Mac, no APNs key.** Nothing
blocks this session. That is why it is the objective and #188 is not.

### D3 — a fourth push kind, on the SAME single couples read

`PushKind` gains **`dailyQuestion`**, TR/AR/EN across the registers plus the discreet
variant, under the standing invariant that **no payload in any mode carries question or
answer text** — which `composePush` guarantees structurally by having no question
parameter, not by copy review.

The hour-8 pass iterates the **same `CoupleBuckets`** the assignment and at-risk passes
already share (`question-rollover.ts:72-82`). **ADR-012 D3's hard constraint is ONE
couples read per sweep and it is NOT amended** — a third pass is one more argument to the
existing `bucket(db)`, never a second read.

⚠️ **08:00 sits exactly on the quiet-hours boundary.** `isQuietLocalHour` is
`hour >= 22 || hour < 8` — right-open, so hour 8 is the first legal hour of the day and
the daily push is the first thing allowed. Elegant, and an off-by-one **in either
direction silently suppresses the entire feature with every test green.**

### D4 — the 16:00 nudge REPLACES the 20:00 one

Not the same push with a different number. Today's protects a **streak**
(`at-risk.ts:202`: `streak.count > 0` or skip). The founder's protects a
**relationship** — *"so that your partner dont get angry"* — and must fire for a couple
with **no streak at all**, which is most couples in week one and every couple that ever
broke one.

**Decided in ADR-042 D4: re-point, do not duplicate.** `AT_RISK_LOCAL_HOUR` 20 → **16**,
and the `streak.count > 0` gate is **dropped**. The 16:00 population is a strict superset
of the 20:00 one, so re-pointing loses no couple. Keeping both would give a couple with a
streak two pushes in one evening, and ADR-012 D3 deliberately has no dedup state.

### ⚠️ The tripwire — read this before you meet the red test

`payload-policy.test.ts:44-57` asserts **two** things: that the `PushKind` union is
**exactly three kinds**, and that the source `not.toContain('coupleEnded')`.

**Adding `dailyQuestion` will turn it red, on purpose.** The correct response updates the
expected union to four and **leaves the `coupleEnded` assertion completely alone.** That
assertion is ADR-019 D3's no-push-on-deletion invariant — a proactive real-time ping to a
possibly-abusive partner at the deleting victim's moment of escape. The "exactly N" clause
is a change-detector; **the `coupleEnded` absence is the safety property.** A session that
meets the red and relaxes the test wholesale deletes a DV control while believing it fixed
a test. (ADR-042 D5 says this too, in the ADR, for the same reason.)

`at-risk.test.ts:98-99` (pins hour 20) and `:202-214` (pins the streak gate) both change
**by design** — update them inside the TDD cycle, do not relax them.

### Acceptance criteria

1. **Tests first** (`session-rules.md` §2 — Functions logic may not skip TDD).
2. **Mutation-check the hour boundaries in BOTH directions** — 8 must not be quiet, 22
   must be, 16 must not. Report **which named assertions moved** (lesson **75**), and
   **anchor each mutation on text unique to the line you mean** (lesson **82** — S062 had
   a first-occurrence replace hit the wrong guard and report a false all-green).
3. **Prove the ONE-couples-read constraint holds**, by construction rather than by
   promise. If it cannot be asserted, say so rather than claiming it.
4. **Amend ADR-012 §10's cost model in the same diff.** The day-doc read was "one per
   couple per day, hour-20 bucket, **for couples with a streak**"; it becomes "hour-16
   bucket, **unconditionally**", because eligibility can no longer be decided from the
   couple document already in the bucket. Single-digit reads/day at current scale —
   recorded because a cost claim that quietly widened is the drift ADRs exist to prevent.
5. **Do not claim delivery you have not seen** (lessons **69**, **78**). The honest close
   is *"composed, routed and provably handed to the port; never delivered to a device,
   because `PUSH_NOTIFICATIONS` is not ticked."*
6. **#136 becomes live the moment a push lands** (Arabic push bodies interpolate a partner
   name with no bidi isolation). Composing a fourth Arabic body is the moment to decide
   it — ADR-033 isolates **at render only**, and a push body is composed on the server and
   rendered by iOS.

---

## 3. Then, in priority order

**1 — The app icon. DECIDED, unblocked, and S062 did not get to it.**
The founder chose **`brandkit/branding-assets/icons/hayati-appicon-ios-1024.png`**, the
pre-redesign mark. Execute it; do not re-open the choice.
⚠️ **The literal git-previous is the default blue Flutter logo** — `git log --follow` on
the 1024 icon returns exactly two commits and that is the other one, so **`git revert` is
the wrong instrument** (lesson **80**). There is **no `flutter_launcher_icons`**: the 15
iOS PNGs and 5 Android `mipmap-*/ic_launcher.png` are hand-produced — generate them
deliberately and **verify every size actually changed** (lesson **66**). **Leave
`AppIconDiscreet` alone** (`redesign/icons/README.md` §5).

**2 — Ship a build.** 113 predates #169 (the founder's own *"Something went wrong"*),
#170, #173, #179 — all merged, built into 114, and reached nobody.
```sh
gh workflow run release.yml --ref main
gh workflow run testflight-testers.yml -f dry_run=false -f assign_latest_build=true -f submit_for_review=true
```
⚠️ **Ask the founder before dispatching `release.yml`.** ⚠️ **Never infer delivery from a
green release** — read the assignment step's log or re-run `-f status_only=true`.

**3 — Screenshots (`tr` only).** en-US is **done and live** — tell the founder, they asked
again only because nobody told them. **TestFlight has no screenshot field** (measured, PR
#181). `tr` needs its App Store **version localization** to exist first: read with
`tool/ci/testflight_testers.py --store-status`; if `tr` exists, dispatch
`appstore-screenshots.yml -f upload=true -f locales=en-US,tr`. If not, founder action.

**4 — The rest.** Re-derive from `gh issue list`. **#188** (the device half — blocked on
4(a)) · **#176** (Rubik Light declared, not bundled) · **#175** (10 of 14 raised cards
render flat) · **#174** (no `liveRegion` — the reveal is never announced) · **#166**
(measurement-first; may honestly close as unanswerable) · **#137** · **#129/#121**.

---

## 4. Blocked — re-check every line

| What | Blocked on | Why a session cannot take it alone |
|---|---|---|
| **operator 4(a)** — APNs key + Push Notifications tick | founder | **MEASURED ABSENT 2026-08-06.** Gates #188 and every actual delivery. The `.p8` half is console-only and unmeasurable. |
| **operator 2(d)** — Associated Domains | founder | **MEASURED ABSENT.** Same portal page as 4(a) — one visit does both. Not blocking (ADR-040). |
| **`tr` App Store version localization** | founder | Screenshots cannot upload into a locale that does not exist |
| **operator 2(e)(iv) / #165** | founder | One read-only SA + `gh secret set`. Until then `rules-drift` is SKIPPED **by design** |
| **operator 2(e)(ii)** | founder | The controller's legal name. Blocks `/privacy`, `/terms`, the listing |
| **operator 2(e)(iii)** | founder | `FIREBASE_SERVICE_ACCOUNT`. Blocks CI site deploys and `deploy-rules.yml` |
| **#115** | founder | Making a prod endpoint world-reachable is a security decision on a live system |
| **#41** | founder | Live billing identity — *clean change* vs *migration* |
| **#48**, **#15**, **#136** | the device | On-device observation nobody has made — **and four testers have it installed** |
| **#13** | M6.5 | Android, Gate-3 gated (ADR-006) |
| **#63**, **#71** | founder | Brandkit revisions |

⚠️ **`firestore.rules` changed in S062.** Prod and dev now differ from `main` until
`deploy-rules.yml` runs, which needs `FIREBASE_SERVICE_ACCOUNT` (operator 2(e)(iii)).
**The freeze is not live yet.** Re-measure with `tool/ci/rules_drift.py` and read the exit
code directly — **never through a pipe** (`${PIPESTATUS[0]}`, the most-cited lesson here).

---

## 5. Close sequence — `session-rules.md` §3/§4

Append to `past-prompts.md` → regenerate this file (one objective) → refresh
`operator-expected.md` → commit + push → verify CI → **watch the post-merge `main` run**
(`integration-emulator` is main-only) → `codegraph sync`.

**S059–S061 skipped this three times running. S062 ran it. Keep the streak.**
