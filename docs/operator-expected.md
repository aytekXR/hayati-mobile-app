# Operator Expected — what Hayati needs from you (the founder)

> **Canonical, committed** operator checklist (founder request, Session 009): the
> single place to see what is expected from you, refreshed at every session
> close. It replaces the two untracked root scratch files (`FOUNDER-ACTIONS.md`,
> `OPERATOR-EXPECTED.md`), whose content was consolidated here on 2026-07-09.
> Sessions update this file with docs-with-code discipline (rule #8); check it
> after every merge to `main`.

_Last refreshed: 2026-07-10, Session 011 (M3.1 — question-packs pipeline)._

## Expected from you right now: **nothing is blocking.**

Session 011 shipped M3.1 entirely machine-side (emulator-free): the
question-pack validator is real and enforcing (schema + cross-pack invariants
+ authoring↔bundle drift, 63 self-checks), it runs in CI on every push/PR (a
red pack now blocks merge), packs are authored in ONE place
(`content/packs/`, synced into the app bundle by the validator — ADR-010),
and the app's pack model is the generalized M3 spine (`QuestionPack` with
register + seasonal surface; solo path unchanged — goldens byte-identical,
602 app tests, 87.8% coverage). The next session
(`docs/resume-prompt.md`: **M3.2 — daily rollover Function: timezone
buckets, deterministic selection, `days/{yyyymmdd}` + rules**) is
emulator-only; start it as usual, nothing from you required.

**Plan tracking:** M0 ✅ · M1 ✅ · M2 ✅ · **M3 1/4** · M4–M6 pending →
**10/22 session-units (~45%) in 11 sessions — 12 planned session-units
remain** (M3: 3 · M4: 3 · M5: 3 · M6: 3; M6.5 Android follow-on sits outside
the 22-unit MVP count, timed by Gate 3). **On track — no plan or scope changes
in Session 011** (M1's +1 session remains the only slippage ever).
Readiness: **pre-MVP, emulator/CI-proven** — pairing loop, solo week, and now
the content pipeline are green end-to-end; still nothing deployed (Spark) and
nothing on-device (items 2–4 below own that path, then M6).

## 1. Native review of the solo question content (before public launch)

- **What:** the first shippable content — 7 solo reflection questions ×
  TR/AR/EN — is AI-drafted and marked `reviewedBy: PENDING…`. Per the binding
  authoring rules (`content/README.md`, W9): **native register-owner review is
  mandatory before any public launch — TR by you two, AR by a Gulf-dialect
  reviewer.**
- **Where (changed in Session 011):** the packs now live at
  **`content/packs/solo_{tr,ar,en}.json`** (the single authoring home). Edit
  there, set `reviewedBy` to the reviewer's name, then run
  `dart content/validator/validate.dart --sync` and commit both trees — or
  just send the edits to a session and it will do the mechanics. CI validates
  every change (the reviewedBy `PENDING` warning disappears once set).
- **When needed:** NOT blocking personal use or any engineering session
  (ADR-007 personal-use-first). Becomes a hard gate before TestFlight
  beta/soft launch (M6). Reviewing the TR pack is ~10 minutes of reading; the
  AR pack needs your Gulf reviewer contact.
- **Bonus while you're there:** these are the questions your own app will ask
  you on days 1–7 — edits welcome (a content edit intentionally shows up as a
  golden change in CI).

## 2. Blaze plan decision — **last call, optional bonus otherwise**

- **What:** upgrading `hayatiapp-dev`/`hayatiapp-prod` from Spark (free) to
  **Blaze** (pay-as-you-go) — deploying Cloud Functions requires it.
- **Status:** three Functions (`createInvite`, `invitePreview`, `joinInvite`),
  all emulator-proven; **nothing deployed yet.** M3.2 adds a fourth (the
  scheduled daily rollover) — still emulator-only, but the pile of
  deploy-ready-but-undeployed Functions keeps growing, and the rollover's
  *schedule trigger* can only be verified end-to-end on a real deploy.
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

## Progress & readiness snapshot (as of Session 011 close)

- **Plan progress:** M0 ✅ · M1 ✅ · M2 ✅ · M3 1/4 · M4–M6 pending — 10/22
  session-units (~45%) in 11 sessions; 12 planned session-units left to the
  MVP (M6 close). On track, no scope changes.
- **Readiness:** pre-MVP, emulator/CI-proven. Auth, profile+rules, the whole
  pairing loop, the unpaired solo week, AND the content pipeline (validated
  packs, single authoring home, CI-enforced sync, generalized pack model) are
  green against emulators and CI. Nothing deployed (Spark), nothing on-device
  (Mac/enrollment pending) — items 1–4 above + M3–M6 are the path to "runs on
  your phones".
