# Resume Prompt — Session 064

> **This file contains ONE objective. That objective is the session; nothing else is.**
> (`project-rules.md` #1, `session-rules.md` §1.)
>
> Before starting, read the two companions:
> * **`session-context.md`** — toolchain, machine, review discipline, binding
>   invariants, and the never-without-asking list.
> * **`session-lessons.md`** — the institutional lessons, numbered to **86**. Cited
>   below by number.
>
> Re-derive the session number from `git log`; a session on another machine can consume it.

**Objective: ship the app icon the founder chose.**

It is decided, unblocked, and has lost to the push objective for three sessions
running. The founder asked for it on 2026-08-05 and it is the fastest visible win
left.

> **Push is no longer this file's objective.** S063 took it as far as engineering
> reaches: the capability is ticked, `aps-environment` is signed into **build
> 116**, all three behaviours compose and route, and — this was nearly missed —
> **the server half is now actually DEPLOYED** (it had been merged and green and
> not running; lesson **86**). **One console action remains** — the APNs `.p8` into both Firebase projects — and it is
> founder-only and unmeasurable (`gcloud` absent, no ADC, no Firebase CLI APNs
> command; re-checked 2026-08-06, do not re-derive by guessing). When the founder
> says it is done, the very next thing to do is **ask them to open build 115,
> grant the notification permission, and report whether a push arrives** — that
> observation is the only thing that can close M3.4, and no session can make it.

---

## 1. Where things actually stand *(measured 2026-08-06 — re-measure, do not inherit)*

| | State |
|---|---|
| **Push, server side** | **DONE.** All three founder behaviours compose and route: `dailyQuestion` at couple-local 08:00, `partnerAnswered` on the reveal trigger, the unanswered nudge at 16:00. `fcmTokens` has writers and a rules lock. |
| **Push, device side** | **Nothing has ever arrived** — but the plugin, the adapter, the app-root activation AND `aps-environment` are all on `main` and **shipped in build 115**. Missing: the APNs `.p8` in Firebase (founder-only). |
| **App ID capabilities** | `PUSH_NOTIFICATIONS` **ticked 2026-08-06** (API, founder-authorised; undo id `Q344R7M7MY_PUSH_NOTIFICATIONS`). `ASSOCIATED_DOMAINS` and `APP_ATTEST` still absent — neither blocks anything today. |
| **Build 116** | Uploaded 2026-08-07, `VALID`, `internal=IN_BETA_TESTING`, assigned to `Friends`, submitted for review. **THE build to talk to the founder about** — 115 has the entitlement but NOT the permission prompt, so 115 can never capture a token. 116 can. |
| **Build 115** | Superseded. Apple approved its beta review (`external=IN_BETA_TESTING`), but it is functionally push-dead — no permission request. |
| **`MATCH_BOOTSTRAP`** | Set for exactly one release run to regenerate the profile, then **deleted**. Verify it is still gone (`gh variable list`) — if it is set, CI can mint credentials, which ADR-032's readonly exists to prevent. |
| **Deployed Functions** | Brought up to `main` on 2026-08-07 by hand (there is **no deploy workflow** — see #166). **Re-measure, do not inherit:** `firebase functions:list --project hayatiapp-prod` against the exports in `functions/src/index.ts`, and `firebase functions:log --only questionRollover` for the three per-sweep summary lines. A missing `daily-question sweep complete` means prod is behind again. |
| **Deployed rules** | Match `main` as of 2026-08-07 (`rules_drift.py --project hayatiapp-prod --from-firebase-cli` → exit 0). The `fcmTokens` freeze is live. |
| **Build 113/114** | Superseded by 115. |
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

### Part 2 — ship the icon in a build

Build 115 went out on 2026-08-06 with the push slice. The icon needs one more.

```sh
gh workflow run release.yml --ref main
gh workflow run testflight-testers.yml -f dry_run=false -f assign_latest_build=true -f submit_for_review=true
```

⚠️ **Ask the founder before dispatching `release.yml`** (`session-context.md`
never-without-asking list). They authorised the 115 dispatch specifically; that
does not carry forward.
⚠️ **Never infer delivery from a green release** — read the assignment step's log
or re-run `-f status_only=true`. It has failed silently twice, and Apple refuses a
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

**2 — Close M3.4, but only the founder can start it.** Ask whether the APNs `.p8`
is uploaded to **both** Firebase projects. If yes: ask them to install **build
116** (not 115), open it to the paired home screen, **accept the permission
prompt**, and say whether anything arrives at 08:00. **That observation is the
only thing that can close M3.4**, and no session can make it.

⚠️ **Runtime is still unobserved.** The plugin BUILDS against this project's
pure-Dart `FirebaseOptions` (there is no `GoogleService-Info.plist`) and coexists
with the scene-based AppDelegate — both proven by a real macOS compile. Nothing has
proven the swizzling behaves on a live device, or that a token is ever actually
captured. `PushTokenSync` fails open around all of it, so the honest failure mode
is silence. **Build 115 is the first build that could show this. Ask.**

⚠️ **Do not add `UIBackgroundModes: remote-notification`** without deciding SEC-3
first (`secure_storage_pin_lock_store.dart`: a locked-device background read of an
`unlocked_this_device` Keychain item fails and hits the fail-open path). Token
capture needs none of it; only background *delivery* does. `signing_sentinel_test`
reddens if it is added.

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
