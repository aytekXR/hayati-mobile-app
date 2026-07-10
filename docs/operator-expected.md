# Operator Expected — what Hayati needs from you (the founder)

> **Canonical, committed** operator checklist (founder request, Session 009): the
> single place to see what is expected from you, refreshed at every session
> close. It replaces the two untracked root scratch files (`FOUNDER-ACTIONS.md`,
> `OPERATOR-EXPECTED.md`), whose content was consolidated here on 2026-07-09.
> Sessions update this file with docs-with-code discipline (rule #8); check it
> after every merge to `main`.

_Last refreshed: 2026-07-10, Session 010 (M2.4) — **closed, M2 complete**._

## Expected from you right now: **nothing is blocking.**

Session 010 shipped M2.4 (solo mode — the day-N solo reflection ritual with
persistent invite nudges) entirely against the emulators and closed **all of
M2**. Evidence: functions 142 tests / **100% coverage**; app 593 tests /
**87.95%** (gate ratcheted 62→**64**); 33 new six-cell goldens; 13-agent
adversarial review — 5 of 6 dimensions returned zero findings, both confirmed
app-flow findings fixed with regression tests; ci-debt #17 closed (docs-only
pushes to main no longer burn ~140–210 billed macOS minutes). The next
session (`docs/resume-prompt.md`: **M3.1 — question-packs pipeline: validator
+ CI wiring + pack-model generalization**) is emulator-free; start it as
usual, nothing from you required.

**Plan tracking:** M0 ✅ · M1 ✅ · **M2 ✅ (4/4)** · M3–M6 pending →
**9/22 session-units (~41%) in 10 sessions — 13 planned session-units
remain** (M3: 4 · M4: 3 · M5: 3 · M6: 3; M6.5 Android follow-on sits outside
the 22-unit MVP count, timed by Gate 3). **On track — no plan or scope changes
in Session 010** (M1's +1 session remains the only slippage ever).
Readiness: **pre-MVP, emulator/CI-proven** — the full pairing loop AND the
unpaired solo experience are complete end-to-end against emulators; still
nothing deployed (Spark) and nothing on-device (items 2–4 below own that
path, then M6).

## 1. NEW — native review of the solo question content (before public launch)

- **What:** Session 010 authored the first shippable content: 7 solo
  reflection questions × TR/AR/EN (`app/assets/content/solo_{tr,ar,en}.json`).
  They are AI-drafted and marked `reviewedBy: PENDING…`. Per the binding
  authoring rules (`content/README.md`, W9): **native register-owner review is
  mandatory before any public launch — TR by you two, AR by a Gulf-dialect
  reviewer.**
- **When needed:** NOT blocking personal use or any engineering session
  (ADR-007 personal-use-first). Becomes a hard gate before TestFlight
  beta/soft launch (M6). Reviewing the TR pack is ~10 minutes of reading;
  the AR pack needs your Gulf reviewer contact.
- **Bonus while you're there:** you'll see the questions your own app will
  ask you on days 1–7 — edits welcome, they're one JSON file each (a content
  edit intentionally shows up as a golden change in CI).

## 2. Blaze plan decision — **last call, optional bonus otherwise**

- **What:** upgrading `hayatiapp-dev`/`hayatiapp-prod` from Spark (free) to
  **Blaze** (pay-as-you-go) — deploying Cloud Functions requires it.
- **Status:** three Functions (`createInvite`, `invitePreview`, `joinInvite`),
  all emulator-proven; **nothing deployed yet.**
- **When needed:** the optional first deploy + real-device pairing test (which
  also needs your Mac, so on-device stays a bonus either way). Hard requirement
  at latest before the first TestFlight build (M6).
- **Cost posture:** couple-scoped workload ≈ near-zero at dev scale; budget
  alerts at $ thresholds (`architecture.md` §10).

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
- **APNs** setup (push — needed by M3 notifications on device).
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

## 5. Slack webhook rotation (from Session 005, still open)

The local branch `chore/slack-notifications` holds commit `13f1e6d` with a
**live incoming-webhook URL**; GitHub push protection rejects it. Rotate the
webhook in Slack (treat it as leaked), store the new one as a **repository
secret**, then rework/land the branch.

## Progress & readiness snapshot (as of Session 010 close)

- **Plan progress:** M0 ✅ · M1 ✅ · M2 ✅ · M3–M6 pending — 9/22
  session-units (~41%) in 10 sessions; 13 planned session-units left to the
  MVP (M6 close). On track, no scope changes.
- **Readiness:** pre-MVP, emulator/CI-proven. Auth, profile+rules, the whole
  pairing loop (issue → WhatsApp share → zero-auth preview → race-safe
  transactional join) AND the unpaired solo week (bundled TR/AR/EN questions,
  Firestore-persisted answers, invite nudges) are green against emulators and
  CI. Nothing deployed (Spark), nothing on-device (Mac/enrollment pending) —
  items 1–4 above + M3–M6 are the path to "runs on your phones".
