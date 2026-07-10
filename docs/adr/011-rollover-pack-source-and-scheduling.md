# ADR-011: Rollover pack source, timezone-sweep scheduling, and selection policy

- **Status:** Accepted
- **Date:** 2026-07-10
- **Deciders:** Session 012 (per `docs/resume-prompt.md` M3.2 "decide + document" mandate)
- **Related:** [ADR-010](010-content-authoring-home-and-sync.md) (single authoring home `content/packs/`, validator-owned sync — pre-blesses Functions reading repo-root content); [ADR-007](007-de-gate-build-from-content-validation.md) (personal-use-first scale posture); `docs/architecture.md` §2–4; `docs/test-suite.md` §1

## Context

M3.2 builds the scheduled `questionRollover` Function that assigns each couple
its day's question by writing `couples/{cid}/days/{yyyymmdd}`. Four decisions
came due, each with real alternatives:

1. **Pack source for Functions.** How does the Function read validated pack
   content? (a) Bundle `content/packs/` into the functions build via a copy
   step in `npm run build`; (b) host packs in Firestore (`questions/{qid}` or
   pack docs) and read at runtime.
2. **Timezone-bucket scheduling granularity.** (a) Per-timezone scheduled
   functions (one cron per zone at its local midnight); (b) a single hourly
   UTC run that computes, per couple, whether the couple's local calendar day
   already has a day doc, and assigns if not. The input domain is the M2.3
   allow-list: `couples/{cid}.timezone` is an IANA id validated against
   `Intl.supportedValuesOf('timeZone')` at join (default `Europe/Istanbul`).
3. **`packConfig` shape** on `couples/{cid}` (resume-prompt minimum: `packId`),
   and what couples *without* the field get (no writer of `packConfig` exists
   yet — M2.3 join writes only `memberUids`/`timezone`/`createdAt`).
4. **Seasonal-window policy.** `seasonalWindow` (`ramadan`/`eid`/`new_year`,
   free-form) is carried verbatim by the content schema and Dart model since
   M3.1; window→date resolution (Hijri calendar for ramadan/eid) was
   deliberately deferred to this session as a decide-or-defer item.

## Decision

1. **Build-time bundle.** `npm run build` becomes `tsc` + a copy step
   (`scripts/bundle-packs.mjs`) that copies `content/packs/*.json` into
   `lib/content/packs/`. The loader (`src/rollover/pack-loader.ts`) resolves
   that directory relative to the compiled module and parses packs with a
   strict, loud parser (schema-shaped: required fields, enums, integer
   version, unique ids). The validator remains the single content *gate*
   (CI-enforced on every push); the parser is defense-in-depth at the
   consumption edge. Firestore-hosted packs are deferred to the remote-sync
   follow-up ADR-010 already anticipates — at personal-use scale (ADR-007) a
   runtime content store adds reads, deploy coupling, and a second
   validation surface for zero benefit.
2. **Single hourly UTC sweep** (`onSchedule('0 * * * *')`, `Etc/UTC`,
   `europe-west1`). Each run reads all couples, groups them by `timezone`
   (the "bucket"), computes the bucket's current **local calendar date** once
   via `Intl.DateTimeFormat` (`formatToParts`, DST-correct by construction),
   and for each couple **creates `days/{dayKey}` only if absent**
   (`create()`, never overwrite). Why not per-zone crons: ~400 zones would
   need ~40 distinct cron expressions (offsets are not whole hours:
   Kathmandu +5:45, Chatham +12:45), and a missed run silently skips that
   zone's day until the *next* midnight. The hourly sweep is self-healing
   (a missed hour is caught up the next hour), naturally idempotent, and
   assigns within ≤1h of local midnight (sub-hour-offset zones get their doc
   at the first run after their midnight — up to 45 min late, accepted).
   Cost shape: O(couples) document reads per hour — trivial at personal-use
   scale. The binding ceiling at fleet scale is the invocation wall-clock
   (sequential per-couple history reads), not read cost — the scheduler
   options pin `timeoutSeconds` explicitly, and the documented scale path is
   a `timezone`-indexed query filtered to zones currently in their first
   local hour. Self-healing is **intra-day only** by design: only *today's*
   dayKey is ever written, a fully-missed calendar day is skipped, never
   backfilled — the no-overlapping-writes safety argument rests on this, so
   backfill must not be added without revisiting it. No scheduler retries:
   the next hourly sweep IS the retry (idempotent by construction).
3. **`packConfig: { packId: string }`**, optional on the couple doc. Absent →
   `DEFAULT_PACK_ID = 'solo_tr'` (the founder-couple register-neutral TR pack,
   mirroring the `DEFAULT_COUPLE_TIMEZONE = 'Europe/Istanbul'` precedent —
   ADR-007 personal-use-first). This is an explicit placeholder: the couple
   pack bank (`tr_playful`, `tr_respectful`, `ar_msa_gulf`, `en`) arrives with
   W9 authoring, and pack *choice* UI is a later milestone; nothing writes
   `packConfig` today. A present-but-malformed `packConfig` (non-string or
   unknown `packId`) is a **loud per-couple skip** — `logger.error` with the
   coupleId plus a failure count in the run summary — never a silent
   fallback: misconfiguration must not masquerade as the default. The same
   error boundary covers a missing/corrupt `timezone`: the stored zone is
   used **verbatim** (never re-resolved through the join-time
   `resolveCoupleTimezone`, whose silent-Istanbul fallback would mask corrupt
   state), and an absent or non-IANA zone is a per-couple skip. Per-couple
   failures do **not** fail the run — one poisoned couple document must not
   paint every hourly sweep red and drown real outages; the throw is
   reserved for systemic failures (couples unlistable, handler-level
   errors). Register is a *pack-level* property, so "register honored" holds
   by construction: selection never leaves the configured pack.
4. **Evergreen-only selection policy (explicit deferral).** Questions carrying
   any `seasonalWindow` are excluded from selection. No shipped question has a
   window today, so the filter is a no-op in practice; the Hijri window→date
   mapping (ramadan/eid) lands with the first seasonal content (tracked as a
   follow-up issue). Selection itself is a pure function of
   (pack, days-history): first *unseen* evergreen question in pack authoring
   order (the curriculum order the solo week established); when the pack is
   exhausted, recycle deterministically by minimum times-assigned, pack order
   breaking ties. History is read as a projection (`select('questionId')`) of
   the couple's `days` subcollection — O(history) reads per assignment
   (365/couple/year), accepted at this scale; the scale path is a selection
   cursor on the couple doc, deliberately rejected for now because the day
   docs stay the single source of truth (no cursor-drift class of bugs).

## Consequences

**Contracts this fixes for M3.3+ (decided here, binding)**

- **The couple dayKey is a pure function of `couples/{cid}.timezone`** —
  never the device clock. The app-side day read must compute the key from
  the couple's stored zone (a TS/Dart mirror of `localDayKey`), NOT reuse
  `soloDayKey(DateTime.now())`: a couple stored as `Europe/Istanbul` with
  devices in another zone would otherwise read the wrong doc around
  midnight. The stored zone is treated as stable; a member editing it
  mid-day can shift their own couple's next assignment by up to a day
  (bounded, self-correcting, no security boundary crossed — accepted).
- **The day doc is question/assignment metadata ONLY**
  (`questionId`, `packId`, `packVersion`, `assignedAt`) and its member-only
  read rule applies to exactly that surface. Answers must NOT be embedded as
  fields on this doc — Firestore rules are document-granular, so an embedded
  `answers{uid}` map would leak the partner's answer pre-reveal. M3.3 puts
  answers in a reveal-gated per-user structure
  (`couples/{cid}/days/{dayKey}/answers/{uid}`), updating architecture §3
  accordingly. `packId` is a deliberate addition to the resume-prompt's
  minimal list (`questionId`, `assignedAt`, pack version): a bare version
  number is meaningless once `packConfig` can point at different packs.
- **The server assignment is authoritative.** Client offline prefetch is a
  *prediction* (same selection over the same bundled pack); an app whose
  bundled pack version lags the deployed Function's can predict differently,
  so the client reconciles to the day doc's `questionId` when it syncs.

**Positive**

- Determinism end-to-end: same (couple, local date, pack version, history) →
  same question, so the client can prefetch offline (`architecture.md` §4/§5)
  and concurrent/overlapping runs race benignly (`create()` + identical
  computed assignment).
- The rollover is exactly as testable as the M2.x Functions: pure selection /
  day-key cores unit-tested (DST included), service + handler driven
  in-process against the Firestore emulator, schedule trigger itself
  deploy-verified later (Blaze item, `operator-expected.md`).
- Content stays validator-gated in one place; the functions bundle is a
  byte-copy of the authoring tree, verified by a build-artifact test.

**Negative / accepted**

- A third committed-content touchpoint (build artifact, not committed — but a
  copy step to keep in mind when the build changes). The bundle-equality test
  fails loudly if the copy step rots.
- Full-history reads grow linearly with couple age; fine for years at
  personal scale, revisit with the cursor path if fleet scale arrives.
- Deployed rollover cadence is hourly even though each couple needs one write
  per day — 24 mostly-no-op sweeps/day, bought deliberately for
  self-healing + DST-freedom.
- `solo_tr` doubles as the couple stand-in bank until W9 — the same 7
  questions the founders answered solo may reappear in the couple loop;
  accepted for dogfooding, resolved by W9 content.

## Follow-ups

- Seasonal window→date mapping (Hijri for `ramadan`/`eid`, Gregorian for
  `new_year`) when the first seasonal content is authored.
- Remote pack sync (Remote Config / Firestore) per ADR-010 follow-ups;
  `packConfig` grows pack-choice UI when couple packs exist (W9).
- Timezone-indexed sweep query + selection cursor if scale ever demands it.
