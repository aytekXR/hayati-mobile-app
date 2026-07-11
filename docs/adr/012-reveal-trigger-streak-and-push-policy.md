# ADR-012: Reveal trigger design, streak/grace semantics, and push payload policy

- **Status:** Accepted
- **Date:** 2026-07-11
- **Deciders:** Session 014 (per `docs/resume-prompt.md` M3.4 "decide + document" mandates)
- **Related:** [ADR-011](011-rollover-pack-source-and-scheduling.md) (day-doc shape, hourly sweep, dayKey contract — its metadata-only day-doc posture is **amended** here); [ADR-005](005-couple-scoped-data-model.md); `docs/architecture.md` §3–§4, §10; `docs/prd.md` F3 (streak + mercy day), F6 (discreet mode); `docs/test-suite.md` §1

## Context

M3.3 closed the answer → mutual-reveal loop with the reveal invariant enforced
server-side in rules, and deliberately parked two seams for this session:
`revealedAt` was left unstamped (both-answered is client-derivable; the day doc
is client-write-denied), and nothing server-side reacted to answers. M3.4 adds
what the loop *produces* — the couple streak — and the pushes that pull the
couple back in. Three decision clusters came due:

1. **Trigger type and idempotency model** for the repo's first Firestore
   trigger on `couples/{cid}/days/{dayKey}/answers/{authorUid}`:
   `onDocumentCreated` vs `onDocumentWritten`, and how duplicate delivery and
   the two-answers race (both creates firing "second") are made safe.
2. **Streak semantics** for `couples.streak {count, lastMutualDate,
   graceTokens}` (`architecture.md` §3 pinned this shape at M3.2): what
   increments, what resets, and the grace-token earn/refill policy the PRD
   anchors only as "one free 'mercy day' (grace token) per week" (F3).
3. **Push policy**: which events push, how streak-at-risk is scheduled,
   and the quiet-hours + discreet-text payload rules (F6: "neutral
   notification text; notification privacy defaults ON in AR locale").

## Decision 1 — `onDocumentCreated`, with a transactional `revealedAt` latch

The trigger is **`onDocumentCreated`** on
`couples/{cid}/days/{dayKey}/answers/{authorUid}`, not `onDocumentWritten`.

The reveal condition ("both answer docs exist") can only *become* true at the
CREATE of the second answer: the M3.3 rules deny deletes always and deny
updates once both answers exist, so post-reveal the docs are immutable, and a
pre-reveal update (the typo window on one's own answer) never changes
existence. `onDocumentWritten` would add invocations on every edit with zero
correctness gain.

**Idempotency latch.** All semantics live in one Firestore transaction
(`handleAnswerCreated`), which reads the day doc, both answer docs, and the
couple doc, then:

- both answers exist AND the day doc has no `revealedAt` → stamp
  `revealedAt: serverTimestamp()` on the day doc (admin write; the doc stays
  client-write-denied) and write the new `couples.streak` computed by the
  pure engine (Decision 2) — **the M3.3 deferral lands here**;
- both answers exist AND `revealedAt` already present → no-op (duplicate
  delivery, or the loser of the race);
- one answer exists → no reveal; the invocation may emit the
  partner-answered nudge (Decision 3).

At-least-once trigger delivery and the two-answers race both collapse onto the
same latch: Firestore transactions are serializable (reads of the *absence* of
a doc are part of the read set, so a concurrent second-answer create forces a
retry, never a stale decision), and exactly one committed transaction observes
"both exist, unrevealed". Duplicate deliveries and race losers observe
`revealedAt` set and do nothing. **Exactly one `revealedAt` stamp and exactly
one streak application per mutual day** is therefore transactional truth, not
best-effort — proven in-process by the emulator suites (duplicate re-drive +
`Promise.all` concurrent drive).

Push sends happen **after** the transaction commits, only on the invocation
that won the latch (reveal) or observed the one-answer state (nudge). Sends
are best-effort: a benign race can nudge a partner whose own answer is
milliseconds from committing; the transactional invariant above is what must
never break, and delivery timing is not part of it.

The registration sets **`retry: true`** (Session 014 review finding): the
handler converts every data-shape problem into a typed non-throwing skip, so
a throw means a genuinely systemic failure — and because post-reveal answer
docs are immutable, no create event would ever re-fire for that day. Without
retry, one dropped event would lose the mutual day forever and poison the
next streak fold as a phantom missed day. The latch makes redelivery safe by
construction, which is exactly what earns the retry flag.

This **amends ADR-011's metadata-only day-doc posture**: the day doc surface
is now `{questionId, packId, packVersion, assignedAt, revealedAt?}` — still
assignment/lifecycle metadata only, still zero answer content, still
client-write-denied.

## Decision 2 — Streak semantics: couple-local calendar, weekly grace refill

`couples.streak = {count, lastMutualDate, graceTokens}` where
`lastMutualDate` is a `yyyymmdd` dayKey (couple-local calendar — dayKeys are
produced by `localDayKey(instant, couples.timezone)`, ADR-011; once keys
exist, streak arithmetic is pure Gregorian calendar math, zone-free by
construction). An absent `streak` field reads as the zero state
`{count: 0, lastMutualDate: null, graceTokens: 1}` — no migration, no join
Function change.

`applyMutualDay(prev, dayKey)` is a **pure function** (`fast-check`
property-tested, test-suite §1):

1. **Refill first:** if `dayKey` falls in a later ISO week (Monday-start,
   couple-local calendar) than `lastMutualDate`, `graceTokens` resets to 1.
   This is the literal reading of PRD F3's "one free mercy day per week":
   at most one bridge per ISO week, restored on week entry. (Week-start
   convention: ISO-8601 Monday. The Gulf Fri/Sat weekend does not obviously
   move a *mercy-token refill* boundary; revisit with W9 content decisions if
   cultural framing wants it.)
2. `dayKey == lastMutualDate` → no-op (same-day idempotence; defense in
   depth behind the latch).
3. `dayKey < lastMutualDate` → no-op (late completion of an older day still
   stamps that day's `revealedAt` — the mutual-day record is true — but never
   rewrites streak history).
4. Consecutive day (`dayKey == lastMutualDate + 1`) → `count + 1`.
5. Exactly one missed day (`dayKey == lastMutualDate + 2`) and
   `graceTokens ≥ 1` after refill → **bridge**: `count + 1`,
   `graceTokens - 1`.
6. Anything else (gap > one missed day, or no token) → reset: `count = 1`
   (`graceTokens` unchanged — a reset consumes nothing).
7. First mutual day ever (`lastMutualDate == null`) → `count = 1`.

`lastMutualDate` always becomes `max(prev, dayKey)`'s winner, i.e. it only
moves forward. Rules freeze `streak` against client writes (the M3.3
`timezone`/`createdAt` freeze pattern, with symmetric absence handling — the
field does not exist until the first mutual day), mutation-tested.

## Decision 3 — Pushes: two trigger-driven, one sweep-piggybacked; policy is pure

Three pushes ship, all behind an injectable `MessagingPort` seam
(`messaging.send` — FCM has no emulator, so the SEND is mocked in-process;
APNs/on-device delivery remains operator-expected item 4):

- **Partner-answered nudge** (trigger, one-answer state): to the member who
  has not answered. Fires only POST-first-answer — this deliberately reveals
  "your partner answered", which the M3.3 no-existence-oracle posture
  explicitly permits as a push (never as a loosened read rule).
- **Reveal push** (trigger, latch winner): to the partner of the
  latch-winning invocation's author — in the common sequential case that is
  the *first* answerer (the second answerer is in-app at that moment).
  Reordered/delayed trigger delivery can make either invocation win, so the
  exact recipient is best-effort, consistent with the push posture above; the
  guarantee is *one* reveal push, not *whose*.
- **Streak-at-risk** (sweep): **piggybacked on the hourly `questionRollover`
  sweep**, not a separate schedule — the sweep already buckets every couple
  by stored timezone each hour, so a second scheduled Function would
  duplicate that machinery for one extra check. On the run where a bucket's
  couple-local hour is **20** (once per zone per day; DST transitions never
  occur at 20:xx in practice), couples with `streak.count > 0` whose day doc
  for the bucket's local date is unrevealed get the at-risk push. Cost shape
  (§10) unchanged in O(): one extra day-doc read per couple, once per day,
  in the hour-20 bucket only. Best-effort by design (no dedup state; the
  hourly cadence makes double-sends structurally absent, not guarded).

**Payload policy is a pure, unit-tested function** with two axes:

- **Quiet hours:** 22:00–08:00 in the couple's STORED timezone → the push is
  **suppressed** (dropped with a loud log), not queued — no scheduling infra
  this session; the at-risk push at 20:xx local is outside the window by
  construction. Suppress-vs-delay is revisitable when a real notification
  backlog exists.
- **Discreet-text mode** (PRD F6, privacy posture): **no payload, in ANY
  mode, ever contains question or answer text** — lock screens are not
  couple-private. Non-discreet payloads may name the partner and the event
  (localized TR/AR/EN by the recipient's `users.contentLanguage`); discreet
  payloads are fully generic (no names, no event specifics — "Hayati" +
  neutral copy). Default: discreet ON when the recipient's
  `contentLanguage == ar` (F6: "notification privacy defaults ON in AR
  locale"), OFF otherwise; a per-user settings override is a future surface
  and reads through the same resolver seam.

**Token storage:** recipients resolve through `users/{uid}.fcmTokens`
(string array). Nothing writes it yet — the app-side capture is
platform-channel work needing APNs and is **deferred to the on-device slice**
(recorded loudly: operator-expected item 4 / M6). Absent or empty tokens →
the send is skipped and counted loudly in the trigger/sweep summary; the
Functions half is fully emulator-proven against the port.

## Consequences

- The daily loop now *produces* durable state: `revealedAt` on the day doc
  (server truth for "mutual day") and `couples.streak` — both admin-written,
  both client-write-denied, both readable by members through existing rules.
- The streak engine being pure calendar math over dayKeys means every PRD
  streak property (grace, gaps, DST, zone edges) is testable without any
  emulator, and Dart↔TS parity concerns stay confined to dayKey *generation*
  (already byte-pinned by the shared fixture).
- The trigger wire itself (emulator trigger delivery) is a thin e2e on top of
  in-process handler proofs; if trigger delivery flakes in CI, the handler
  tests carry the acceptance (the M3.2 pattern) and the wire is
  deploy-verified at the first Blaze deploy — same posture as the rollover's
  schedule trigger.
- Real device delivery (APNs) and `fcmTokens` capture remain outside the
  emulator's reach; the seam boundary makes that a bounded, documented gap
  (operator item 4), not silent debt.
