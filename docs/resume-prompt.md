# Resume Prompt — Session 064

> **This file contains ONE objective. That objective is the session; nothing else is.**
> (`project-rules.md` #1, `session-rules.md` §1.)
>
> Before starting, read the two companions:
> * **`session-context.md`** — toolchain, machine, review discipline, binding
>   invariants, and the never-without-asking list.
> * **`session-lessons.md`** — the institutional lessons, numbered to **83**. Cited
>   below by number.
>
> Re-derive the session number from `git log`; a session on another machine can consume it.

**Objective: ship the app icon the founder chose, and get a build to the testers.**

Both are unblocked. Both have lost to the push objective for two sessions running.
The founder has asked about the icon once and about testers' builds twice.

---

## 1. Where things actually stand *(measured 2026-08-06 — re-measure, do not inherit)*

| | State |
|---|---|
| **Push, server side** | **DONE.** All three founder behaviours compose and route: `dailyQuestion` at couple-local 08:00, `partnerAnswered` on the reveal trigger, the unanswered nudge at 16:00. `fcmTokens` has writers and a rules lock. |
| **Push, device side** | **Nothing has ever arrived.** #188, blocked on the App ID tick. |
| **App ID capabilities** | Measured 2026-08-06 (run `31054773143`): `APPLE_ID_AUTH` + `IN_APP_PURCHASE` ticked; **`PUSH_NOTIFICATIONS`, `ASSOCIATED_DOMAINS`, `APP_ATTEST` ABSENT.** Re-dispatch `appid-capabilities.yml` — it is one command and it decides whether #188 is live. |
| **Build 113** | Apple-approved, `IN_BETA_TESTING`, 8 in `Friends` (2 anonymous public-link installs). |
| **Build 114** | Uploaded 2026-08-02, **`READY_FOR_BETA_SUBMISSION` — never submitted.** Everyone is still on 113. |
| **`firestore.rules`** | **Changed in S062 and NOT deployed** — prod/dev differ from `main` until `deploy-rules.yml` runs, which needs `FIREBASE_SERVICE_ACCOUNT` (operator 2(e)(iii)). **The `fcmTokens` freeze is not live yet.** |
| **Screenshots** | en-US: 6 live since 2026-08-03. `tr` never uploaded. |

---

## 2. THE OBJECTIVE

### Part 1 — the app icon (decided, just not executed)

The founder was shown the candidates and chose
**`brandkit/branding-assets/icons/hayati-appicon-ios-1024.png`**, the pre-redesign
mark. **Execute that; do not re-open the choice.**

⚠️ **`git revert` is the wrong instrument** (lesson **80**). `git log --follow` on
`Icon-App-1024x1024@1x.png` returns exactly two commits, and the earlier one is the
**default blue Flutter logo** from the m0.1 scaffold. The chosen file has never been
in that path's history.

⚠️ **There is no `flutter_launcher_icons`.** The 15 iOS PNGs and 5 Android
`mipmap-*/ic_launcher.png` are hand-produced. Generate them deliberately and
**verify every size actually changed** (lesson **66** — a generator that silently
skips a size leaves a stale icon at exactly one scale factor, which is the one a
tester's device will use).

⚠️ **Leave `AppIconDiscreet` alone.** `redesign/icons/README.md` §5 is explicit, and
it is load-bearing for the on-device check at operator 4(3).

### Part 2 — ship a build

113 predates #169 (the founder's own *"Something went wrong"*), #170, #173, #179,
and now the entire push slice. All merged, built into 114, and reached nobody.

```sh
gh workflow run release.yml --ref main
gh workflow run testflight-testers.yml -f dry_run=false -f assign_latest_build=true -f submit_for_review=true
```

⚠️ **Ask the founder before dispatching `release.yml`.** (`session-context.md`
never-without-asking list.)
⚠️ **Never infer delivery from a green release** — read the assignment step's log or
re-run `-f status_only=true`. It has failed silently twice, and Apple refuses a
second beta submission with a message that prints as "already submitted — no-op"
and exits **0**.

### Acceptance criteria

1. Every icon size regenerated and **diffed** — assert on the bytes, not on the
   generator's exit code.
2. `AppIconDiscreet` byte-identical before and after.
3. The build dispatched only after the founder says yes, and its TestFlight
   assignment **read back from the API**, not inferred.
4. If the founder is unavailable, land the icon and **say plainly that the build
   was not dispatched and why** — do not dispatch it to avoid an awkward handoff.

---

## 3. Then, in priority order

**1 — `tr` screenshots.** en-US is **done and live**; tell the founder, they asked
again only because nobody told them. **TestFlight has no screenshot field**
(measured, PR #181). `tr` needs its App Store **version localization** to exist
first: read with `tool/ci/testflight_testers.py --store-status`; if `tr` exists,
dispatch `appstore-screenshots.yml -f upload=true -f locales=en-US,tr`. If not, it
is a founder action already on the operator page.

**2 — #188, the device half — ONLY if the capability probe returns exit 0.** Run it
first; it is one command. If it still returns 1, say so and move on rather than
building around it. Everything above the device is done and waiting.

**3 — The rest.** Re-derive from `gh issue list`. **#176** (Rubik Light declared,
not bundled — the cheapest real bug here) · **#175** (10 of 14 raised cards render
flat) · **#174** (no `liveRegion` — the reveal is never announced) · **#166**
(measurement-first; may honestly close as unanswerable) · **#137** · **#129/#121**.

---

## 4. Blocked — re-check every line

| What | Blocked on | Why a session cannot take it alone |
|---|---|---|
| **operator 4(a)** — APNs key + Push Notifications tick | founder | **MEASURED ABSENT 2026-08-06.** Gates #188 and every actual delivery. The `.p8` half is console-only and unmeasurable. |
| **operator 2(d)** — Associated Domains | founder | **MEASURED ABSENT.** Same portal page as 4(a) — one visit does both. |
| **`tr` App Store version localization** | founder | Screenshots cannot upload into a locale that does not exist |
| **operator 2(e)(iii)** | founder | `FIREBASE_SERVICE_ACCOUNT`. **Now also blocks the S062 rules freeze from going live.** |
| **operator 2(e)(iv) / #165** | founder | One read-only SA + `gh secret set`. Until then `rules-drift` is SKIPPED **by design** |
| **operator 2(e)(ii)** | founder | The controller's legal name. Blocks `/privacy`, `/terms`, the listing |
| **#115** | founder | Making a prod endpoint world-reachable is a security decision on a live system |
| **#41** | founder | Live billing identity — *clean change* vs *migration* |
| **#48**, **#15**, **#136** | the device | On-device observation nobody has made — **and four testers have it installed** |
| **#13** | M6.5 | Android, Gate-3 gated (ADR-006) |
| **#63**, **#71** | founder | Brandkit revisions |

---

## 5. Close sequence — `session-rules.md` §3/§4

Append to `past-prompts.md` → regenerate this file (one objective) → refresh
`operator-expected.md` → commit + push → verify CI → **watch the post-merge `main` run**
(`integration-emulator` is main-only) → `codegraph sync`.

**S059–S061 skipped this three times. S062 and S063 both ran it. Keep the streak.**
