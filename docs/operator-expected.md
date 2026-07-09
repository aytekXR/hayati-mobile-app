# Operator Expected — what Hayati needs from you (the founder)

> **Canonical, committed** operator checklist (founder request, Session 009): the
> single place to see what is expected from you, refreshed at every session
> close. It replaces the two untracked root scratch files (`FOUNDER-ACTIONS.md`,
> `OPERATOR-EXPECTED.md`), whose content was consolidated here on 2026-07-09.
> Sessions update this file with docs-with-code discipline (rule #8); check it
> after every merge to `main`.

_Last refreshed: 2026-07-10 (early AM), Session 009 (M2.3) — **late stage,
closing**._

## Expected from you right now: **nothing is blocking.**

Session 009 (M2.3 — transactional join + race rejection + partner preview
screen) runs entirely against the emulators; nothing from you was needed and
nothing is pending on you to close it. Status at this refresh: **server side
done and verified** (`joinInvite` + rules hardening, 129 functions tests, 100%
coverage), **app-side seams done** (395 unit tests green), app UI (partner
preview screen + goldens + integration test) in final verification, then
review → PR → CI → merge. Everything below is either optional-now or queued
for a later milestone.

**Plan tracking:** after this session closes, M2 is 3/4 done →
≈ 8/22 session-units (~36%) in 9 sessions. **On track — no plan or scope
changes were made in Session 009** (the plan gets its normal progress note
only). Readiness remains **pre-MVP, emulator/CI-proven**: the full pairing
loop (issue → WhatsApp share → zero-auth preview → transactional join) now
works end-to-end against emulators; still nothing deployed (Spark) and nothing
on-device (items 1–3 below own that path).

## 1. Blaze plan decision — **last call, optional bonus otherwise**

- **What:** upgrading `hayatiapp-dev`/`hayatiapp-prod` from Spark (free) to
  **Blaze** (pay-as-you-go) — deploying Cloud Functions requires it.
- **Status:** after M2.3 there are three Functions (`createInvite`,
  `invitePreview`, `joinInvite`), all emulator-proven; **nothing deployed yet.**
- **When needed:** the optional first deploy + real-device pairing test (which
  also needs your Mac, so on-device stays a bonus either way). Hard requirement
  at latest before the first TestFlight build (M6).
- **Cost posture:** couple-scoped workload ≈ near-zero at dev scale; budget
  alerts at $ thresholds (`architecture.md` §10).

## 2. Enable Apple + Phone sign-in providers (open since M1.3)

- **What:** Firebase console → Authentication → Sign-in method → enable
  **Apple** and **Phone** on **both** projects (`hayatiapp-dev`,
  `hayatiapp-prod`).
- **Why manual:** free-tier Auth provider init is console-only (M1.2 finding) —
  no API/CLI path exists.
- **When needed:** only for **real-device** sign-in; CI/emulator sessions run
  without it. ~5 minutes.

## 3. The Mac / Apple Developer slice (enrollment promised 2026-07-08)

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
- First **real-device pairing test** (pairs with item 1: deploy first).

## 4. Slack webhook rotation (from Session 005, still open)

The local branch `chore/slack-notifications` holds commit `13f1e6d` with a
**live incoming-webhook URL**; GitHub push protection rejects it. Rotate the
webhook in Slack (treat it as leaked), store the new one as a **repository
secret**, then rework/land the branch.

## Progress & readiness snapshot (as of Session 008 close)

- **Plan progress:** M0 ✅ · M1 ✅ · M2 2/4 (M2.3 in flight) · M3–M6 pending —
  ≈ 7/22 session-units (~32%) in 8 sessions; on track, no scope changes.
- **Readiness:** pre-MVP, emulator/CI-proven. Auth, profile+rules, invite
  issue/share/preview, deep-link state all green against emulators and CI.
  Nothing deployed (Spark), nothing on-device (Mac/enrollment pending) — items
  1–3 above + M2.3–M2.4 + M3 are the path to "runs on your phones".
