# Operator Expected — what Hayati needs from you (the founder)

> **Canonical, committed** operator checklist (founder request, Session 009): the
> single place to see what is expected from you, refreshed at every session
> close. It replaces the two untracked root scratch files (`FOUNDER-ACTIONS.md`,
> `OPERATOR-EXPECTED.md`), whose content was consolidated here on 2026-07-09.
> Sessions update this file with docs-with-code discipline (rule #8); check it
> after every merge to `main`.

_Last refreshed: 2026-07-11, Session 013 (M3.3 — answer → mutual reveal)._

## Expected from you right now: **nothing is blocking.**

Session 013 shipped M3.3 entirely emulator-side: **your daily loop now
closes** — the paired home shows the day's server-assigned question, each of
you answers, and the partner's answer stays server-side-unreadable until your
own exists (the M3 accept-line invariant, proven with mutation tests: weaken
the rule and the suite goes red), then streams in live; once both exist the
day is revealed and both answers freeze. The app computes the couple's day
from the couple's STORED timezone (never the device zone), byte-pinned to the
server by a shared Dart↔TS parity fixture. `couples.timezone` is now
rules-frozen (a member rewrite would have bricked the loop). Until the W9
couple packs land, the questions are your 7 solo questions (`solo_tr`,
ADR-011) — you will recognize them; that is the accepted dogfooding posture
(and one more reason item 1 below pays off twice). One session-013 note for
you: two Claude sessions briefly ran concurrently on this milestone (an old
tmux window `uh` was still alive); it was detected, stopped, and cost
nothing — all work was reconciled and verified from scratch.

The next session (`docs/resume-prompt.md`: **M3.4 — streak engine + pushes**)
is emulator-only for the streak half; the push half needs APNs = Mac slice
(item 4), so notifications will land device-verifiable-later like everything
else. Start it as usual, nothing from you required.

**Plan tracking:** M0 ✅ · M1 ✅ · M2 ✅ · **M3 3/4** · M4–M6 pending →
**12/22 session-units (55%) in 13 sessions — 10 planned session-units
remain** (M3: 1 · M4: 3 · M5: 3 · M6: 3; M6.5 Android follow-on sits outside
the 22-unit MVP count, timed by Gate 3). **On track — no plan or scope changes
in Session 013** (M1's +1 session remains the only slippage ever).
Readiness: **pre-MVP, emulator/CI-proven** — pairing loop, solo week, content
pipeline, and now the FULL daily loop (server assignment + answer + mutual
reveal) are green end-to-end; still nothing deployed (Spark) and nothing
on-device (items 2–4 below own that path, then M6).

## 1. Native review of the solo question content (before public launch)

- **What:** the first shippable content — 7 solo reflection questions ×
  TR/AR/EN — is AI-drafted and marked `reviewedBy: PENDING…`. Per the binding
  authoring rules (`content/README.md`, W9): **native register-owner review is
  mandatory before any public launch — TR by you two, AR by a Gulf-dialect
  reviewer.**
- **Where:** the packs live at **`content/packs/solo_{tr,ar,en}.json`** (the
  single authoring home). Edit there, set `reviewedBy` to the reviewer's name,
  then run `dart content/validator/validate.dart --sync` and commit both
  trees — or just send the edits to a session and it will do the mechanics.
  CI validates every change (the reviewedBy `PENDING` warning disappears once
  set).
- **When needed:** NOT blocking personal use or any engineering session
  (ADR-007 personal-use-first). Becomes a hard gate before TestFlight
  beta/soft launch (M6). Reviewing the TR pack is ~10 minutes of reading; the
  AR pack needs your Gulf reviewer contact.
- **Extra weight since M3.2:** these same 7 questions are the **couple**
  question bank placeholder too (`packConfig` absent → `solo_tr`, ADR-011)
  until the W9 couple packs are authored — your own paired daily loop will
  serve them, so edits pay off twice.

## 2. Blaze plan decision — **last call, optional bonus otherwise**

- **What:** upgrading `hayatiapp-dev`/`hayatiapp-prod` from Spark (free) to
  **Blaze** (pay-as-you-go) — deploying Cloud Functions requires it.
- **Status:** four Functions now (`createInvite`, `invitePreview`,
  `joinInvite`, and since M3.2 the scheduled **`questionRollover`**), all
  emulator-proven; **nothing deployed yet.** New since M3.2: the rollover's
  *schedule trigger* (Cloud Scheduler firing the hourly sweep) is the one
  piece that **cannot** be verified in the emulator — it is deploy-verified
  only. The handler/service logic is fully proven in-process.
- **When needed:** the optional first deploy + real-device pairing test (which
  also needs your Mac, so on-device stays a bonus either way). Hard requirement
  at latest before the first TestFlight build (M6).
- **Cost posture:** couple-scoped workload ≈ near-zero at dev scale — the
  hourly sweep reads O(couples) docs (architecture §10); budget alerts at $
  thresholds (`architecture.md` §10).

## 3. Enable Apple + Phone sign-in providers (open since M1.3)

- **What:** Firebase console → Authentication → Sign-in method → enable
  **Apple** and **Phone** on **both** projects (`hayatiapp-dev`,
  `hayatiapp-prod`).
- **Why manual:** free-tier Auth provider init is console-only (M1.2 finding) —
  no API/CLI path exists.
- **When needed:** only for **real-device** sign-in; CI/emulator sessions run
  without it. ~5 minutes.

## 4. The Mac / Apple Developer slice (enrollment promised 2026-07-08)

Everything here needs your Mac and/or the Apple Developer enrollment:

- **App Attest**: entitlement + console registration, then on-device
  verification. **App Check enforcement stays OFF in both consoles until
  attestation is verified on-device** (current posture in all Functions).
- **APNs** setup (push — needed by M3.4 notifications on device).
- **dSYM upload** for prod Crashlytics symbolication.
- **Issue #15**: capture the native crash log for the phone-auth emulator
  suite on the iOS simulator.
- On-device confirmation that Apple's first-authorization full name reaches
  `displayName`.
- **Deep-link delivery test** (M2.2/M2.3): `hayati://invite/<code>` cold + warm
  OS→app delivery can only be proven on a device/simulator.
- **Universal links** (decision, not urgent): needs enrollment + a hosted
  `apple-app-site-association` → a domain choice. Custom scheme shipped in
  M2.2; upgrade path documented in `architecture.md` §4.
- First **real-device pairing test** (pairs with item 2: deploy first).

## X. Cross-project: Unhooked panic-button verification (reported 2026-07-11)

> Not a Hayati item — parked here because this is the checklist you read.
> The **unhooked** iOS panic-control fix sits UNCOMMITTED on your Mac
> (intents moved into the app target + warm-launch gate; unit 151/151,
> snapshot 17/17, status DONE_WITH_CONCERNS). Needed from you, on the Mac /
> iPhone: (1) cold test — app closed, tap Control Center Panic → app must
> launch straight into the panic flow; (2) warm test — app open on the
> dashboard, tap Panic → panic sheet over the dashboard; (3) decide whether
> the swipe-dismissible warm sheet should become a hard cover (the
> celebration screen has no dismiss button — a full cover would trap you);
> (4) let an unhooked Mac session commit via its ritual + run the UI-test
> lane. Optional: gstack 1.39 → 1.60 (`/gstack-upgrade`).

## 5. Slack webhook rotation (from Session 005, still open)

The local branch `chore/slack-notifications` holds commit `13f1e6d` with a
**live incoming-webhook URL**; GitHub push protection rejects it. Rotate the
webhook in Slack (treat it as leaked), store the new one as a **repository
secret**, then rework/land the branch.

## Progress & readiness snapshot (as of Session 012 close)

- **Plan progress:** M0 ✅ · M1 ✅ · M2 ✅ · M3 2/4 · M4–M6 pending — 11/22
  session-units (50%) in 12 sessions; 11 planned session-units left to the
  MVP (M6 close). On track, no scope changes.
- **Readiness:** pre-MVP, emulator/CI-proven. Auth, profile+rules, the whole
  pairing loop, the unpaired solo week, the content pipeline, AND the daily
  rollover (server half of the core loop — deterministic, idempotent,
  DST-proven, rules-guarded) are green against emulators and CI. Nothing
  deployed (Spark), nothing on-device (Mac/enrollment pending) — items 1–4
  above + M3.3–M6 are the path to "runs on your phones". Deferred loudly:
  seasonal question windows (issue #29, with first seasonal content), the
  rollover schedule trigger (deploy-verified at first Blaze deploy).
