# ADR-009: Solo mode — bundled schema-shaped packs, createdAt-anchored local day rotation, Firestore soloAnswers

- **Status:** Accepted
- **Date:** 2026-07-10
- **Deciders:** Session 010 (per `docs/resume-prompt.md` M2.4 "decide + document" mandate)
- **Related:** [ADR-005](005-couple-scoped-data-model.md) (couple-scoped model — soloAnswers is the deliberate single-user exception, scoped under `users/{uid}`); [ADR-007](007-de-gate-build-from-content-validation.md) (personal-use-first — native content review becomes an operator item, not a build blocker); `docs/prd.md` F1; `docs/mvp.md` IN #2; `docs/architecture.md` §3

## Context

M2.4 gives the unpaired user a reason to stay: 7 days of solo reflection questions with persistent invite nudges (`prd.md` F1). Three decisions had real alternatives:

1. **Where the 7×3 questions live.** Candidates: (a) ARB strings — zero new infrastructure, but ARBs are UI-copy-only by doctrine (`architecture.md` §6) and the content would need extraction at M3; (b) Dart constants — cheap, but invents a third content format the M3 pipeline would have to unwind; (c) a bundled JSON asset shaped like `content/schema/question-pack.schema.json` — new asset/loader infrastructure, but the format IS the M3 contract, so M3 swaps the loading strategy behind the same seam instead of migrating content.
2. **What anchors day-N.** Candidates: (a) first-open timestamp stored locally — lost on reinstall, forgeable; (b) a per-user server field written for the purpose — new write path, new rules; (c) the existing `users/{uid}.createdAt` — already rules-enforced create-once and immutable (M1.2/M2.1), already server-stamped, needs only a READ path. And the day boundary itself: 24-hour intervals vs local calendar dates.
3. **Where answers persist.** Candidates: (a) local-first storage — no rules work, but history dies with the device and can't surface post-pairing; (b) `users/{uid}/soloAnswers/{yyyymmdd}` in Firestore — survives reinstall, feeds the M3 post-pairing surface, needs self-only rules with mutation tests.

## Decision

1. **Content ships as three bundled JSON packs** (`app/assets/content/solo_{tr,ar,en}.json`), each shaped exactly like `content/schema/question-pack.schema.json` (`packId solo_<locale>`, `version 1`, `register: neutral`, exactly 7 questions), loaded through a `SoloQuestionPackRepository` seam with a loud pure mapper. Pack selection follows `profile.contentLanguage` (the question language, not the UI locale). Register-aware packs and the validator/remote-sync pipeline stay M3; solo packs are register-neutral by design. AI-drafted content carries `reviewedBy: PENDING…` — **native register-owner review (Gulf reviewer for AR) is mandatory before public launch** (W9), tracked in `docs/operator-expected.md`; acceptable pre-review for the personal-use-first target (ADR-007).
2. **Day N anchors on `users/{uid}.createdAt`**, surfaced to the client READ-ONLY (the exact pattern `coupleId` used at M2.3: never emitted by `profileToMap`, not a `copyWith` parameter). Day N is a **local calendar-date distance** computed from date components only (`soloDayNumber`): an account created at 23:59 sees day 2 two minutes later, and DST shifts can never move a boundary because hour arithmetic never happens. The wall clock enters through `soloClockProvider` — the app's single clock seam — so day-N proofs are clock-independent. Null anchor (pending server stamp) and future anchors (clock skew) clamp to day 1. The day is computed per build, deliberately without a midnight timer.
3. **Day 8+ stops the cycle.** Questions never repeat, no modulo wrap; the solo home becomes a completed state whose primary action is the invite. Honest framing over engagement mechanics: the product's ritual is for two, and pretending otherwise with an infinite solo loop would undercut the pairing funnel (`prd.md` F1 "app is honest that it's better together").
4. **Answers persist to `users/{uid}/soloAnswers/{yyyymmdd}`** (dayKey = the same local calendar date the day number came from; one editable bucket per day, same-day saves overwrite). Rules are self-only with a frozen field surface: `hasOnly([questionId, text, answeredAt])`, bounded non-empty text (≤2000), and `answeredAt == request.time` so a client clock can never forge the answer time; client delete denied (M6 cascade owns removal). Every clause is mutation-tested in the M2.1 weakened-rules harness.

## Consequences

**Positive**

- M3 inherits, rather than migrates: the pack format, the loader seam, the `soloAnswers` history (for the post-pairing surface), and the clock seam (for rollover work) are all already in place.
- The anchor is unforgeable and reinstall-proof for free — no new server writes, no new trust surface; the rules suite already guarded it.
- Calendar-date arithmetic is deterministic on any host timezone, which made the acceptance proof ("day 3 on day 3, clock-independent") a plain unit/widget test instead of a flaky time simulation.
- Solo history survives device loss and pairing: nothing the user wrote in their first week is discarded when the partner arrives.

**Negative / accepted trade-offs**

- A timezone traveller can see day N jump (the local calendar date is the ritual's frame of reference, matching the couple's `days/{yyyymmdd}` convention); accepted and documented.
- A user sitting on the screen across midnight keeps the old day until the next rebuild — no midnight timer by design (M3's rollover owns time-driven refresh).
- The bundled packs duplicate `content/`'s eventual home; until the M3 pipeline lands, `app/assets/content/` is the single authoring location (noted in `content/README.md`) so there is no dual-source drift.
- Firestore persistence costs a rules surface + mutation tests up front — paid in this session, with the M2.1 harness making it cheap.
