# Resume Prompt — Session 062

> **This file contains ONE objective. That objective is the session; nothing else is.**
> (`project-rules.md` #1, `session-rules.md` §1.)
>
> Before starting, read the two companions — they carry what used to be crammed into
> this file's header:
> * **`session-context.md`** — toolchain, machine, review discipline, binding
>   invariants, and the never-without-asking list.
> * **`session-lessons.md`** — the institutional lessons, numbered to **80**. Cited below
>   by number.
>
> Re-derive the session number from `git log`; a session on another machine can consume it.

**Objective: make the app send push notifications. It never has — not once, to anyone.**

---

## 1. Where things actually stand *(measured 2026-08-05 — re-measure, do not inherit)*

| | State |
|---|---|
| **Build 113** | **Apple approved it.** `external=IN_BETA_TESTING`. `Friends` holds 8: founder `INSTALLED`, 1 emailed tester `INSTALLED`, **2 anonymous `PUBLIC_LINK` installs**, 4 `INVITED`. |
| **Build 114** | Uploaded 2026-08-02, **`READY_FOR_BETA_SUBMISSION` — never submitted.** Everyone is testing 113. |
| **Rules drift** | exit **0**, prod + dev both match `main`. |
| **Secrets** | exactly 5, all release-signing. No `FIREBASE_RULES_VIEWER_SA`, `FIREBASE_SERVICE_ACCOUNT`, or `SLACK_WEBHOOK_URL`. |
| **#115 webhook** | still **HTML 403** — broken. |
| **Site** | `/` `/support` `/i/<code>` **200**; `/privacy` **404** (deliberate). `ikimiz.beyondkaira.com` still fails TLS. |
| **Screenshots** | **en-US: 6 live on the App Store listing** since 2026-08-03. `tr` never uploaded. |

**Housekeeping done on 2026-08-05, so S062 does not repeat it:** `resume-prompt.md`
(this file) rebuilt, `operator-expected.md` pruned to open items, `past-prompts.md`
given a reconstructed entry for S059–S061 (which merged eleven PRs without ever
running the close sequence — this file had gone stale enough to name a closed issue
as its objective).

---

## 2. THE OBJECTIVE — push notifications

The founder, verbatim on 2026-08-05:

> app does not sent notificaiton. It needs to be send new questions at 08.00 TSI with a
> question. And when your partner answers your question you need to be notified. If you
> did not reply the question as of 16.00 you need to be notified so that your partner
> dont get angry.

### Why nothing arrives

M3.4 built three push kinds, an injectable `MessagingPort`, quiet-hours policy,
discreet-mode policy, recipient resolution and 35 tests — and `implementation-plan.md`
ticks it **✅**. Four independent measurements say the delivery path does not exist:

| Layer | State |
|---|---|
| `app/pubspec.yaml` | **no `firebase_messaging`** — the plugin was never added |
| `app/ios/Runner/Runner.entitlements` | **no `aps-environment`** |
| `app/ios/Runner/Info.plist` | **no `UIBackgroundModes` / `remote-notification`** |
| a **writer** of `users.fcmTokens` | **none** — not in `functions/src`, `app/lib`, or `firestore.rules` |

So `fcmTokensOf()` returns `[]` for every user, every send is a counted
`skippedNoToken`, and **no notification has ever been delivered.** That is
lesson **79**, and it is why this was invisible for three weeks.

### The three asks against what exists

| Ask | Today | Gap |
|---|---|---|
| **new question at 08:00** | `questionRollover` writes each couple's day doc at **couple-local midnight** (hourly UTC sweep, `0 * * * *`). **There is no daily-question push kind at all** — `PushKind` is `partnerAnswered \| reveal \| streakAtRisk` | a new kind + a local-hour-8 pass |
| **partner answered** | **BUILT.** `answerReveal` composes `partnerAnswered` and hands it to the port | delivery only |
| **unanswered by 16:00** | `runStreakAtRisk` fires at **hour 20**, only when **`streak.count > 0`** | the hour, and the streak gate |

**"08:00 TSİ" should be read as 08:00 couple-local**, which *is* TSİ for the founder
couple and matches how every other time decision in this system works (stored couple
timezone, never a fixed offset). Say so in the ADR rather than leaving it implied.

**Quiet hours are 22:00–08:00, right-open** (`isQuietLocalHour`: `hour >= 22 || hour < 8`).
Both 08:00 and 16:00 are already legal, with 08:00 exactly on the boundary — the daily
push is the first thing allowed each day. Elegant, and **fragile**: an off-by-one either
way silently suppresses the whole feature.

**The 16:00 nudge is not the 20:00 one with a different number.** Today's push protects a
*streak*; the founder's protects a *relationship* ("so that your partner dont get angry"),
which must fire for a couple with **no streak at all**. Different eligibility, different
feature. Say which one you built.

### Two decisions the ADR must make explicitly

**(a) `aps-environment` cannot just be added.** It must exist in the **provisioning
profile** too, and `match` runs `readonly: true` in CI (`fastlane/Fastfile:82`) so it
cannot add a capability — a build claiming an entitlement its profile lacks **fails at
codesign**. This is exactly the failure ADR-040 was written about, one capability over.
**Push Notifications must be ticked on the App ID first (operator item 4(a)).** Build the
app half behind the plugin and land the entitlement only once the founder confirms, or in
a separate labelled commit that is not merged until then. **Do not discover this by
breaking the release lane.**

**(b) `users.fcmTokens` is NOT frozen, and nobody decided that.** Every other server-owned
field on `users` is frozen in **both** directions (`firestore.rules:37-59`: `coupleId`,
`coupleEnded`, `notificationPrivacy`, `consent` — forbidden at create *and* compared on
update, because "the update freeze is worthless if a client can mint the field on a fresh
self-doc"). `fcmTokens` is in neither list, and there is no `hasOnly`, so **a client can
write it today** — while `firestore_profile_repository.dart:87` calls it server-owned in a
comment. Pick one and say why:

* **a `registerPushToken` callable** + add `fcmTokens` to both freeze clauses — house
  style, matches `recordConsent` / `updateNotificationPrivacy`, lets the server bound and
  de-duplicate the array, and closes a rules asymmetry that is currently only a comment;
* **direct client write**, documented as deliberate — self-only via `isSelf(uid)`, so junk
  costs the user their own pushes and nothing else.

Either way the mutation test is the same: **prove the other path is denied**, and prove the
freeze spans **create** as well as update (that clause exists because a review found the
create-path mint gap in M6.2).

### Slice it — this is more than one session

Whole feature = plugin + permission UX + token capture/refresh/removal + a new push kind +
two new sweep passes + rules + ADR + operator items + a build. **Take the first coherent
slice; record in `past-prompts.md` what you left and why.** Recommended cut:

1. **Check operator item 4(a) in the first ten minutes.** The APNs key and the portal tick
   are founder-blocked and everything else is downstream. If they are not done, say so out
   loud rather than quietly building around it.
2. **The device half** — `firebase_messaging`; the permission request at the right moment
   (ADR-039's fail-open boot is binding: a permission prompt must never become a blocking
   wait); token capture on login + `onTokenRefresh`; **token removal on sign-out and in the
   ADR-019 delete cascade.** A token that outlives a sign-out sends the next user's pushes
   to the previous user's phone — a privacy defect, not a cleanup task. It belongs in the
   design review.
3. **The daily-question push kind** — TR/AR/EN across the registers plus the discreet
   variant, and a local-hour-8 pass over the **same** timezone buckets. ADR-012 D3's hard
   constraint is ONE couples read per sweep; a third pass must not add a second.
4. **The 16:00 nudge** — re-point or duplicate the at-risk pass, with the eligibility
   question above answered on purpose.

Everything cut becomes an issue, filed before the session ends, with the reason.

### Acceptance criteria

1. **An ADR, written and committed BEFORE the code**, then adversarially design-reviewed
   (`session-context.md` §5). This is a new architectural surface — device push, token
   lifecycle, a fourth push kind, a fourth sweep pass, a rules decision. It **amends
   ADR-012**; say so in both headers.
2. **Tests first** (`session-rules.md` §2 — Functions logic and rules may not skip TDD).
   The `MessagingPort` seam already exists and is where composition and eligibility get
   proven without FCM.
3. **Mutation-check the hour boundaries in both directions** — 8 must not be quiet, 22 must
   be, 16 must not. Move each and watch the **named** assertion redden; report *which*
   assertions moved (lesson **75**).
4. **Correct `implementation-plan.md`'s M3.4 line in the same commit** — strikethrough +
   dated note, as ADR-026 D3 was corrected. Lesson **79**.
5. **Do not claim delivery you have not seen.** If the APNs key is not in place, the honest
   close is *"composed, routed and provably handed to the port; never delivered to a device,
   because <named blocker>"* — lessons **69** and **78**.
6. **#136 stops being latent the moment a push lands** (Arabic push bodies interpolate a
   partner name with no bidi isolation). If this slice ships delivery, pull #136 into it.

---

## 3. Then, in priority order

**1 — The app icon. DECIDED, unblocked, do it first; it is the fastest visible win.**
The founder was shown the candidates and chose **`brandkit/branding-assets/icons/hayati-appicon-ios-1024.png`**,
the pre-redesign mark. Execute that; do not re-open the choice.
⚠️ **The literal git-previous is the default blue Flutter logo** — `git log --follow` on the
1024 icon returns exactly two commits and that is the other one. The chosen file has never
been in that path's history, so **`git revert` is the wrong instrument** (lesson **80**).
There is **no `flutter_launcher_icons`**: the 15 iOS PNGs and 5 Android `mipmap-*/ic_launcher.png`
are hand-produced — generate them deliberately and **verify every size actually changed**
(lesson **66**). **Leave `AppIconDiscreet` alone** — `redesign/icons/README.md` §5 is explicit,
and it is load-bearing for the on-device check at operator 4(3).

**2 — Ship a build.** Build 113 predates #169 (the post-sign-in dead-end fix — *the founder's
own "Something went wrong"*), #170 (the support page the store listing points at), #173 (UI
polish) and #179 (iPhone-only). Those are merged, built into 114, and have reached nobody.
The icon and any push entitlement need a new build anyway.
```sh
gh workflow run release.yml --ref main
gh workflow run testflight-testers.yml -f dry_run=false -f assign_latest_build=true -f submit_for_review=true
```
⚠️ **Ask the founder before dispatching `release.yml`.** ⚠️ **Never infer delivery from a green
release** — read the assignment step's log or re-run `-f status_only=true` (it failed silently twice).

**3 — Screenshots (`tr` only).** **TestFlight has no screenshot field** — measured and recorded
in PR #181; screenshots belong to the App Store listing. en-US is **done and live**; tell the
founder, because they asked again only because nobody told them. `tr` was dropped from the
2026-08-03 upload and needs its App Store **version localization** to exist first. Read the
listing with `tool/ci/testflight_testers.py --store-status`; if `tr` exists, dispatch
`appstore-screenshots.yml` with `-f upload=true -f locales=en-US,tr`. If it does not, that is a
founder action, already on the operator page.

**4 — The rest of the queue.** Re-derive from `gh issue list`; do not inherit this line.
**#176** (Rubik Light declared but not bundled — the cheapest real bug here) · **#175** (10 of
14 raised cards render flat) · **#174** (no `liveRegion` — the reveal is never announced) ·
**#166** (Functions half of #140, measurement-first — it may honestly close as unanswerable) ·
**#137** (`intl` misses Arabic Extended-A) · **#129/#121** (release-lane lockfile comment +
`--frozen`; #121's stated blocker is dead — re-derive it).

---

## 4. Blocked — re-check every line

| What | Blocked on | Why a session cannot take it alone |
|---|---|---|
| **operator 4(a)** — APNs key + Push Notifications tick | founder | **Gates the objective.** Without the key FCM cannot reach Apple; without the tick a push build cannot sign |
| **`tr` App Store version localization** | founder | Screenshots cannot upload into a locale that does not exist |
| **operator 2(e)(iv) / #165** | founder | One read-only service account + `gh secret set`. Until then `rules-drift` is SKIPPED **by design** — not a regression |
| **operator 2(d)** | founder | Associated Domains. Not blocking (ADR-040). *Ask in the same portal visit as 4(a)* |
| **operator 2(e)(i)** | founder | `ikimiz` A-record points at the founder's VPS. Not blocking — invites serve from `ikimiz.web.app` |
| **operator 2(e)(ii)** | founder | The controller's legal name. Blocks `/privacy`, `/terms`, the App Store listing |
| **operator 2(e)(iii)** | founder | `FIREBASE_SERVICE_ACCOUNT`. Blocks CI site deploys and `deploy-rules.yml` |
| **#115** | founder | Making a prod endpoint world-reachable is a security decision on a live system |
| **#41** | founder | Live billing identity — decides *clean change* vs *migration* |
| **#48**, **#15**, **#136** | the device | On-device observation nobody has made — **and four testers now have it installed** |
| **#13** | M6.5 | Android, Gate-3 gated (ADR-006) |
| **#63**, **#71** | founder | Brandkit revisions |

---

## 5. Close sequence — `session-rules.md` §3/§4

Append to `past-prompts.md` → regenerate this file (one objective) → refresh
`operator-expected.md` → commit + push → verify CI → **watch the post-merge `main` run**
(`integration-emulator` is main-only) → `codegraph sync`.

**S059, S060 and S061 skipped this three times running, and this file went stale enough to
name a closed issue as its objective. Do not make it four.**
