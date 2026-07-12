# ADR-017: Coach chat UI — one premium surface, retained-crisis windows, ephemeral threads, server-side persona scaffolds

- **Status:** Accepted
- **Date:** 2026-07-12 (Session 019, M5.2)
- **Deciders:** Session 019 (autonomous, per resume-prompt objective); founder
  directives inherited: ADR-007 (personal-use-first), ADR-013 Decision 5
  (expiry pairing), ADR-014 (PremiumGate / `isPremiumProvider` — the seam this
  slice mounts on), ADR-016 (the FROZEN coach wire contract and the
  drop-or-retain obligation this ADR discharges).
- **Related:** PRD F5 (coach personas, disclaimer, register-aware tone), F4
  (premium gating), §8 NFR ("AI inputs never retained beyond session context
  window budget"); `mvp.md` IN #7; `implementation-plan.md` M5;
  `architecture.md` §2/§4/§8; `frontend-brandkit.md` (registers, voice,
  design principles); ADR-009 (clock seam), ADR-011 (dayKey discipline —
  deliberately NOT consumed here, see Decision 6), ADR-015 (couple-scoped
  premium).
- **Review note:** to be adversarially design-reviewed BEFORE implementation
  (the S015–S018 four-for-four discipline). Findings folded in below are
  marked; refuted findings recorded in Consequences.

## Context

M5.1 shipped the coach's safety spine and `coachProxy` — emulator-proven,
fail-closed, zero live calls. Its wire contract is FROZEN (ADR-016): request
`{coupleId, personaId, language, register, messages[≤20 × ≤2,000 chars, last
role 'user']}`; response `{kind: 'reply'|'help', category?, text,
remaining?}`; errors separable by CODE first — `failed-precondition`/
`'not-premium'`, `resource-exhausted`/`'cap-daily'|'cap-monthly'|
'rate-limited'`, `permission-denied` = non-member only, `unavailable` =
provider/infra. M5.2 mounts the couple-facing chat experience on that spine
and claims three parked decisions: the chat surface shape, the
crisis-turn window decision (ADR-016 pinned the obligation: a crisis turn
retained in the window re-routes EVERY subsequent call to the help path),
and the private-thread persistence scope.

Forces:

- **The free tier sees ZERO coach surface** (PRD F5: free tier zero; the
  resume prompt makes it an accept line with assertion extension). This is
  stricter than the packs tile (which free users SEE, locked): the coach
  must not exist for free users, not even as a teaser.
- **Safety UX inherits ADR-016's asymmetry rule.** An under-protective
  window policy is dangerous; an over-protective one costs persona replies.
  The client owns the window, so the client's construction rules are part
  of the safety posture — and the help path must never be mistakable for
  the persona (the `kind` discriminator exists for exactly this).
- **This is a DV-aware product on shared devices.** M5.1's strongest review
  finding split the cap counters so a partner cannot monitor the other's
  coach usage. The same threat model applies to CONTENT at rest: a
  persisted coach thread is discoverable by a partner holding the phone.
  Device-level privacy protections (PIN/biometric lock, discreet icon) are
  M6 scope and do not exist yet.
- **Retention is a privacy stance, not an engineering default.** PRD §8
  says "AI inputs never retained beyond session context window budget";
  `architecture.md` §3 sketches `coach_sessions` with TTL-30d as FUTURE;
  the resume prompt's stopping condition names TTL/retention posture a
  founder decision. No native Firestore TTL policy exists in this repo.
- **No local persistence exists app-side.** `core/storage/` is an empty
  placeholder; the app has no shared_preferences/hive/sqflite dependency.
  Every persisted thing today lives in Firestore behind rules with a
  deliberately narrow write surface.
- **Three register vocabularies exist and none matches the wire.** The
  profile stores `ContentRegister {playful, respectful}` +
  `ContentLanguage {tr, ar, en}`; the wire wants the brandkit union
  `'tr-playful'|'tr-respectful'|'ar-gulf-respectful'|'en-neutral'`. A
  naive `.name` send would be rejected by `validateCoachRequest`
  (`bad-register`).
- **The generic failure mapper mis-buckets the coach codes** (confirmed:
  `mapFunctionsFailure` collapses `resource-exhausted` into the unknown
  bucket and reads `permission-denied` as a generic permission problem —
  which for the coach means "non-member", a different UX). ADR-016's
  review already mandated an app-side coach-owned taxonomy mapped by CODE
  first, `details.reason` second (the platform channel may drop details).
- **Copy discipline:** all coach-facing copy is AI-drafted in the brandkit
  voice and joins the founder native-review gate (TR by the founders, AR
  incl. register by the Gulf reviewer). The "not therapy" disclaimer
  currently lives server-side (`help-content.ts`) with NO wire consumer —
  M5.2's UI is its only real consumer, and two homes for one safety string
  is drift waiting to happen (the repo's answer to two homes has always
  been one authoring home + sync or a single home: ADR-010).

Alternatives considered are inlined per decision.

## Decision 1 — Chat surface: ONE coach screen, persona switcher, per-persona transcripts

**Shape:** one `CoachScreen` (feature `app/lib/features/coach/`), pushed
from a paired-home tile, with a **persona switcher** (three choice chips:
Coach / Date Genie / Gift Genie) and **one transcript per persona**.
Switching personas swaps the visible transcript; it never mixes windows — a
window sent to `coachProxy` only ever contains turns exchanged with the
selected persona (a Date-Genie window carrying Coach turns would feed one
persona's context to another's system prompt).

*Alternative rejected — three separately-pushed persona screens:* three
pushed routes triple the golden surface and the state plumbing for zero UX
gain at three personas; the switcher keeps discovery of all three personas
one tap away (PRD F5 presents them as presets of one coach feature).
*Alternative rejected — one shared transcript with a persona dropdown per
message:* mixes personas inside one window; the provider port takes ONE
`personaId` per call, so a mixed transcript misattributes turns.

**Mount (two layers, both on the ADR-014 seam):**

1. **Paired-home coach tile** — rendered inside
   `PremiumGate(coupleId:, unlocked: _CoachTile(...), locked:
   SizedBox.shrink())`. The locked branch renders NOTHING: the free tier
   sees zero coach surface (stricter than the packs tile by explicit PRD F5
   scope). The tile follows the packs-tile placement and navigates via the
   exported `showCoach(context, {required uid, required coupleId})` helper
   (the `showPaywall` mold).
2. **The screen itself** — `CoachScreen` is a pushed route
   (`Scaffold(appBar: AppBar())` back affordance; auth-loss self-pop via
   the `authControllerProvider` listen idiom) whose body mounts
   `PremiumGate(coupleId:, unlocked: <chat>, locked: _CoachGatedView(...))`.
   The gated view exists for the mid-session downgrade (premium expires
   while the route is open): lock icon + honest copy + a
   `showPaywall(context, coupleId:)` CTA — the pack-selection `_GatedView`
   mold. A free user can never *reach* the screen (the tile is their only
   path and it renders nothing); the gated view is defense in depth, not a
   discovery surface.

The screen takes `{required String uid, required String coupleId}` (the
`PairedHomeScreen` construction mold). Language and register derive from the
caller's live profile (`profileStreamProvider(uid)`):

```dart
CoachRegister coachRegisterFor(ContentLanguage language, ContentRegister register) =>
    switch (language) {
      ContentLanguage.tr => register == ContentRegister.playful
          ? CoachRegister.trPlayful : CoachRegister.trRespectful,
      ContentLanguage.ar => CoachRegister.arGulfRespectful,
      ContentLanguage.en => CoachRegister.enNeutral,
    };
```

— a total pure function (unit-tested over the full 3×2 product). The wire
`language` field is `profile.contentLanguage.name` (verbatim match with the
server union). The app-side `CoachRegister` enum carries explicit wire
strings (`'tr-playful'` …) — enum `.name` is NOT the wire value here (the
hyphens make that impossible), so the DTO carries an explicit `wire` field,
the `QuestionRegister.msaGulf`/`'msa_gulf'` precedent.

## Decision 2 — Window construction: transcript-derived, help-excluded, crisis-RETAINED

The client-owned window sent to `coachProxy` derives from the selected
persona's transcript by fixed rules:

1. **Only user and persona turns enter the window.** Help-path entries
   (`kind:'help'` responses) are UI artifacts of the safety system, not
   conversation turns — they are NEVER sent as `assistant` messages (a help
   text in an `assistant` slot would be forged conversation the provider
   never produced, and its crisis-adjacent vocabulary could trip the
   post-filter's lexicons on legitimate later turns… or worse, teach the
   persona to imitate the help voice).
2. **Crisis turns are RETAINED** — the ADR-016-pinned decision, resolved on
   the conservative side. The window builder applies NO crisis-aware
   filtering: every confirmed user turn stays, including one that drew a
   help response. Consequence (documented in ADR-016, deliberate here): a
   conversation containing a crisis turn routes EVERY subsequent call to
   the help path — the conversation is **help-sticky by design**. The
   asymmetry rule decides: dropping the crisis turn would silently resume
   persona coaching *in the same conversation where a crisis was just
   disclosed*, which is exactly what "we are not therapy" forbids; keeping
   it costs persona replies, never safety. Retention is also strictly
   simpler: the client needs no knowledge of WHICH turn was the crisis
   (pre-scan hits and post-filter hits are indistinguishable client-side by
   design — the response carries no per-turn attribution).
3. **The exit is explicit, not silent: a "new conversation" affordance**
   (per persona) clears that persona's transcript — visible whenever the
   transcript is non-empty. A user whose crisis mention was
   conversational (a news story, a film) can deliberately start fresh;
   the reset is not an evasion vector because detection is per-call and
   normalization-based — a NEW conversation's messages are scanned exactly
   the same; only the stickiness of the OLD conversation ends. The help
   entry itself explains this state honestly (help copy + a caption that
   this conversation stays paused; ARB, native-review flagged).
4. **Bounds mirror the wire:** the window is the LAST
   `kCoachWindowMaxMessages = 20` eligible turns (including the new user
   message, which is always last and always role `'user'`); input is
   hard-capped at `kCoachMessageMaxLength = 2000` chars by
   `LengthLimitingTextInputFormatter` (the answer-entry mold) so
   `message-too-long`/`too-many-messages` are unreachable from a
   well-behaved client; the send button disables on empty/whitespace-only
   input (trimmed, the `_entry` mold).

*Alternative rejected — drop crisis turns from subsequent windows:* resumes
persona coaching mid-crisis-conversation; requires client-side crisis
attribution that the wire deliberately does not provide; and turns the
client into a safety-policy decision point when ADR-016 put that policy
server-side. *Alternative rejected — auto-clear the transcript after a help
response:* destroys the user's own words moments after a crisis disclosure
(hostile UX at the worst moment) and silently un-sticks the safety state;
the explicit affordance keeps agency with the user.

## Decision 3 — Persistence: ephemeral in-memory this slice (the private-thread scope decision)

**No conversation content is persisted anywhere — no `coach_sessions`, no
local database, nothing.** Transcripts live in a `keepAlive` Riverpod
family keyed by `(uid, coupleId, personaId)` and die with the process.
Backgrounding survives (the family is keepAlive); app restart clears; the
route can be popped and re-pushed without loss (the durable
`PendingPurchase` precedent). Keying by `uid` means a second account signing
in on the same device gets fresh families — no cross-user bleed through the
UI; sign-out additionally pops the route (Decision 1's self-pop).

Why ephemeral is the RIGHT scope now, not a deferral of convenience:

- **It is the most conservative KVKK/PDPL posture** — PRD §8's "never
  retained beyond session context window" is satisfied at retention zero,
  server-side (M5.1) AND client-side (this decision).
- **The DV threat model:** a persisted private thread on a shared/observed
  device is readable by whoever holds the phone; the app's device-privacy
  layer (PIN/biometric, discreet icon) is M6 and unbuilt. Shipping
  persistence BEFORE the lock exists would be backwards.
- **Retention posture is the founder's privacy stance to set** (the resume
  prompt's stopping condition names it): TTL length, whether threads
  survive un-pairing, whether export/delete cascades cover them (M6 KVKK
  work) — all one decision bundle. The options are recorded in
  `operator-expected.md` this session (ephemeral-forever vs
  `coach_sessions/{uid}` per-user private thread, TTL-30d, self-read-only
  rules + mutation tests + no-partner-read pin + M6 cascade/export
  integration + the no-native-TTL note). Until answered, ephemeral.
- **`coach_sessions` stays an unmatched collection** in `firestore.rules`
  (default-deny; the header comment already lists it as deferred), so
  nothing can write it prematurely.

Cost, accepted and visible: a couple loses coach context on app restart.
At personal-use scale (ADR-007) this is a non-cost; it becomes a product
question exactly when the founder answers the retention question.

## Decision 4 — Disclaimer: ARB is the single home; shown before first use; ack persisted in a NEW local-flag seam

**Copy home:** the "not therapy" disclaimer moves to the app's ARB files
(`coachDisclaimer*` keys, TR/AR/EN) — the UI is its only consumer.
`help-content.ts` keeps ONLY the help-path response (which IS wire
content); its `disclaimer()` export and `DISCLAIMER` table are REMOVED in
the same commit that lands the ARB keys (single home, ADR-010 spirit; two
AI-drafted homes for one safety string WILL drift through the native
review). The functions unit suite drops the disclaimer cases; the ★
operator item's pointer moves accordingly (help response + lexicon in
`functions/src/coach/`, disclaimer in the ARB set).

**Show semantics:** on first open of the coach surface (per user, per
device), the chat is replaced by a full **disclaimer view** — brandkit-warm
"not therapy" framing + a single acknowledge CTA. Until acknowledged,
nothing can be sent and no transcript renders (PRD F5 "disclaimer shown
before first coach use", literally enforced: the CTA gates the chat).
Acknowledgement is **persisted per device + uid** and never re-asked on
that device — except after reinstall/new device, where re-showing a safety
note is a feature, not a bug.

**Persistence home:** a NEW minimal local-flag seam —
`LocalFlagStore` (abstract) in `core/storage/` with a
`SharedPreferencesLocalFlagStore` implementation (`shared_preferences` is
added as the app's first local-persistence dependency), exposed through a
throw-until-overridden `@Riverpod(keepAlive: true)` provider bound in the
flavor entrypoints (the repository-seam discipline everywhere else), faked
in tests (`FakeLocalFlagStore`). Key shape: `coachDisclaimerAck.<uid>`.

*Alternative rejected — a `users/{uid}.coachDisclaimerAckAt` Firestore
field:* passes today's rules (no `hasOnly` on the profile block) but widens
the client-writable profile surface that M2-era reviews deliberately kept
narrow; records coach-adjacent metadata server-side that the M5.1 privacy
posture spent real effort NOT recording (data minimization: the server
currently cannot say whether a given user ever opened the coach — a
Firestore ack field would change that for zero functional gain); and
auto-syncs the ack across devices, silently skipping the safety note on
every new device. *Alternative rejected — in-memory only:* re-shows the
disclaimer every launch; PRD F5 says "dismissal persisted".

## Decision 5 — App-side wire taxonomy: coach-owned, code-first, total

`app/lib/features/coach/domain/coach_exception.dart` — a sealed
`CoachException` family, mapped in ONE data-layer choke point
(`mapCoachFailure`, the pairing `mapJoinFailure`/`_reasonOf` mold), by
CODE first, `details.reason` refinement second:

| Wire | Exception | UX (frozen contract → surface) |
|---|---|---|
| `permission-denied` | `CoachNotMemberException` | honest error state (should be unreachable: the screen only mounts with the caller's own coupleId) |
| `failed-precondition` (any reason) | `CoachNotPremiumException` | **paywall push** via `showPaywall(context, coupleId:)` + the gated inline state (the mirror will catch up through `PremiumGate`) |
| `resource-exhausted` + `'cap-daily'` | `CoachDailyCapException` | distinct copy: today's messages are used, come back tomorrow |
| `resource-exhausted` + `'cap-monthly'` | `CoachMonthlyCapException` | distinct copy: this month's shared limit is reached |
| `resource-exhausted` + `'rate-limited'` | `CoachRateLimitedException` | slow-down copy, immediate retry honest |
| `resource-exhausted`, reason absent/unknown | `CoachLimitReachedException` | neutral limit copy ("a limit was reached — try again later"): the channel dropped the reason, so the client claims neither "tomorrow" nor "this month" (never over-claim on a dropped detail) |
| `unavailable`, `deadline-exceeded` | `CoachUnavailableException` | honest unavailable state + retry affordance (provider outage and transport outage are indistinguishable client-side and share the UX) |
| `unauthenticated` | `CoachUnknownException` | unreachable in practice (auth-loss self-pops the route first); no dedicated surface |
| anything else (`invalid-argument`, `internal`, non-Functions throws) | `CoachUnknownException({code, message})` | generic honest failure copy |

`failed-precondition` maps to not-premium on CODE alone (reason is
confirmation, not requirement) — the server emits no other
`failed-precondition` on this callable, and the mapping must survive a
dropped `details` (ADR-016 rev-2 finding, discharged here).

The RESPONSE mapper (`coachReplyFromCallable`) is the pure/loud mold:
`kind` must be `'reply'|'help'`, `text` a non-empty string; `category` and
`remaining` optional with type-checked shapes; anything else throws
`FormatException` → surfaces as `CoachUnknownException` (never renders
bogus data as a persona reply).

## Decision 6 — Quota surface: response-hint only, display-only

The UI renders remaining quota ONLY from the last response's `remaining`
hint (an ARB plural caption, full AR CLDR set): no live watch on
`coachUsage` this slice. ADR-016 documents the watcher's staleness trap
(lazy resets mean a boundary-crossing client must re-derive period keys via
`coupleDayKey` to avoid rendering yesterday's exhausted count) and
explicitly blesses "prefer the response's `remaining` hint" — the hint
needs no dayKey math, no timezone read, and no new Firestore read path.

**The hint never gates sending.** `remaining.daily == 0` renders the
exhausted caption but the input stays enabled: the hint is point-in-time
(a partner's concurrent turn stales it instantly; a day boundary un-caps
without the client knowing), and the server is the only authority — a send
after exhaustion gets the typed `cap-daily`/`cap-monthly` answer and its
honest state. Before the first response there is no hint and no caption
(never fabricate a count).

*Deferred loudly:* a live `coachUsage` watch (with the client-side key
comparison obligation) becomes worth building only if the founder wants a
quota meter visible before the first message of the day — recorded, not
built.

## Decision 7 — Persona system prompts: server-side pure scaffolds, register-aware, unconsumed until the live adapter

`functions/src/coach/persona-prompts.ts` — a pure builder in the provider
path:

```ts
buildPersonaSystemPrompt(input: {
  personaId: CoachPersonaId; language: CoachLanguage; register: CoachRegister;
}): string
```

Composed EXCLUSIVELY from static literals keyed by the closed enums (the
signature admits no user content — the injection-closed posture of
ADR-016 Decision 5 extended to prompt construction; there is nothing to
sanitize because there is no interpolation site):

- a **shared safety preamble** (every persona): warm companion framing;
  NOT therapy, no medical/legal/psychological advice; never claim to be
  human; brief, concrete, couple-positive; never guilt (brandkit voice
  rules); respond only in the requested language.
- a **persona block** (PRD F5): Coach — communication help between
  partners; Date Genie — locale-aware date ideas; Gift Genie —
  occasion-aware gift ideas.
- a **register block** (brandkit §7): `tr-playful` arkadaşça, light
  playfulness allowed; `tr-respectful` warm-formal; `ar-gulf-respectful`
  formal-warm, family-safe Gulf register; `en-neutral` neutral-warm.
- a **language directive** naming the reply language explicitly (defense
  for the all-lexicon post-filter: the reply language is requested, never
  assumed).

The builder is TOTAL over the full 3×3×4 enum product — including
mismatched pairs the wire permits (`language:'en'` + `register:'tr-playful'`
passes validation by design; the scaffold must produce something coherent:
the language directive wins, the register tone note stays). Marked
`nativeReview: PENDING` (TR/AR blocks join the founder copy gate — same
tier as the paywall copy, NOT the ★ crisis gate: prompts shape tone, not
safety; safety lives in the detector + preamble and the ★ item's help
content). Consumed by no production code this slice (the default provider
stays `UnconfiguredCoachProvider`); the M5.3 live adapter picks it up —
shipping it now fixes the contract while the copy goes through review.
Unit tests pin totality, non-emptiness, per-enum content markers, the
not-therapy line in every language, and zero interpolation surface (the
function's only inputs are enums — asserted by type, like
`composePush`).

*Alternative rejected — scaffolds in the app, sent over the wire:* the
wire's `register` union was closed specifically so no free client text
flows toward a system prompt; client-side prompts would reopen that seam
at full width.

## Decision 8 — Transcript state + send discipline: server-ack, manual-op, no optimistic UI

- **Transcript model** (pure Dart): sealed `CoachTranscriptEntry` —
  `CoachUserTurn(text)`, `CoachPersonaTurn(text)`,
  `CoachHelpTurn(text, category?)`. The transcript notifier
  (`CoachTranscript`, the keepAlive family of Decision 3) appends
  **confirmed turns only**: on a successful send, the user turn + the
  response entry land together; nothing is appended while in flight, and a
  failed send leaves the transcript untouched with the draft still in the
  input (the M3.3 server-ack discipline — this codebase has no optimistic
  UI anywhere, and a chat bubble that later "un-sends" is worse than a
  spinner).
- **Send controller** (`CoachSendController`, autoDispose family): sealed
  state `CoachSendIdle | CoachSendSending | CoachSendFailure(CoachException)`;
  re-entrant sends dropped while one is in flight; every await followed by
  `ref.mounted`; catches ONLY `CoachException` (the manual-op contract,
  `SoloAnswerController` mold). Success clears the input; failure keeps it
  (retry = tap send again; no auto-retry — the repo's `_noRetry`
  philosophy).
- **Help rendering is structurally distinct:** `CoachHelpTurn` renders as
  its own widget type (full-width card: alert-family styling per brandkit
  `alert`/`sand` tokens, safety icon, no persona chip/avatar, the
  help-sticky caption of Decision 2) — never a chat bubble. Widget tests
  pin the TYPE distinction (`find.byType`), not just styling, so a
  refactor cannot quietly re-bubble the help path (the resume prompt's
  accept line).
- **Persona reply bubbles** are visually attributed (persona label chip)
  and aligned with logical `start`/`end` only (RTL lint). Dynamic type to
  130% covered by the golden scale variants.
- **While sending:** input disabled + inline progress on the send button
  (the answer-save mold); `pumpAndSettle`-safe by completing fakes.

## Test commitments (pinned, not inferred)

1. `coachRegisterFor` total over `ContentLanguage × ContentRegister` (3×2);
   wire strings byte-equal to the server union (a fixture-free parity
   table in the app unit suite mirroring `COACH_REGISTERS`).
2. Window builder: ≤20 turns including the new last-user turn; help
   entries never enter; crisis turns never filtered (a transcript with a
   help entry still re-sends its user turns verbatim); oldest-first
   trimming; empty/whitespace sends impossible.
3. `mapCoachFailure`: the full matrix of Decision 5 — every code × reason
   (present/absent/junk `details`) lands in exactly the documented member;
   non-Functions throws → `CoachUnknownException`.
4. `coachReplyFromCallable`: valid reply/help shapes (with/without
   `category`/`remaining`), every malformed shape throws `FormatException`.
5. Controller: re-entrant drop (Completer-gated double-tap → one repo
   call), `ref.mounted` teardown safety, failure keeps state/draft,
   success appends exactly [user, response] to the transcript family.
6. Widget: disclaimer gates the chat until CTA (and persists — re-pump
   with the fake flag set skips it); send flow renders persona bubble from
   fixture reply; help turn renders the distinct TYPE (never the bubble
   type) incl. post-filter help (help + remaining hint); each error state
   renders its copy (cap-daily ≠ cap-monthly asserted as distinct
   strings); `not-premium` failure pushes `PaywallScreen`; auth-loss
   self-pops; persona switch swaps transcripts and windows; "new
   conversation" clears only the active persona's transcript; quota
   caption renders from hint and never disables input.
7. Free-tier probes (the M4.2 suite extended): free couple → NO coach
   tile, NO `CoachScreen` push anywhere in the daily answer flow; premium
   couple → tile present; the live-mirror flip flips tile visibility BOTH
   directions (incl. past-expiry downgrade); the gift probe untouched.
8. Goldens: `coach_screen` × {`disclaimer`, `conversation`, `help_path`}
   × six cells + scale-130 naturals (27 PNGs), deterministic fixture
   transcript through the fake repo; paired-home cells re-baselined ONLY
   if the tile lands inside existing golden frames (W4 flag, intentional).
9. Functions (touched surface only): `persona-prompts` totality/content
   suite; `help-content` suite updated for the disclaimer removal; full
   functions gate re-run green (80 hard).

## Docs-with-code checklist (this session's pass)

`architecture.md` §2 (coach feature dir goes live app-side), §4 (coach
flow: chat UI status, window rules, ephemeral scope, disclaimer home), §8
(client-side zero retention + disclaimer ARB home + local-flag seam);
`test-suite.md` §1 (coach app rows: unit/widget/golden; functions row for
persona-prompts); `implementation-plan.md` (M5.2 entry);
`resume-prompt.md` (M5.3 next); `operator-expected.md` (persona-prompt +
coach ARB copy join the native-review scope; the private-thread founder
decision recorded with options; ★ item pointer updated for the disclaimer
move); `past-prompts.md` (Session 019 entry).

## Consequences

**Positive**

- The couple-facing coach ships end-to-end against the emulator with zero
  live calls, zero new server surface (persona scaffolds are pure,
  unconsumed), zero persistence — the smallest honest slice that makes the
  frozen contract renderable.
- Every frozen wire outcome has exactly one typed exception and one
  surface; a dropped `details.reason` degrades to honest-generic copy,
  never to a wrong claim.
- The crisis-turn decision lands on the conservative side with an explicit,
  user-agency exit; the client stays safety-policy-free (no crisis
  attribution logic app-side).
- The free tier's zero-coach-surface guarantee is structural (locked =
  nothing) AND assertion-pinned (probes extended).
- The disclaimer gains one home, one review surface, and a per-device
  re-show property that favors safety.

**Negative / accepted trade-offs**

- **Transcripts die on restart** (ephemeral scope). Deliberate; the
  founder owns the retention decision (operator-expected).
- **Help-sticky conversations** cost persona replies until the user starts
  fresh — the over-trigger direction, accepted per the asymmetry rule.
  Crisis text is re-sent (TLS, never persisted/logged server-side) on
  every subsequent call in that conversation; bounded by the user's own
  exit affordance.
- **A new dependency** (`shared_preferences`) enters for one flag. The
  seam keeps it swappable; the empty `core/storage/` dir existed for this.
- **The server loses its disclaimer export** — a consumer that never
  existed; if a future surface needs server-delivered disclaimers (e.g.
  web), the ARB→server move reverses with the same single-home rule.
- **Quota visibility starts at the first response** (no meter before the
  day's first message). Deferred loudly, not silently.
- **Persona scaffold copy ships unreviewed** (nativeReview: PENDING) and
  unconsumed; it cannot affect any user until the live adapter lands, by
  which time the review gate applies.

**Neutral**

- The live provider adapter (+ `LLM_API_KEY`), `coach_sessions`
  persistence, hotline numbers (★), Remote-Config caps, and any coach
  analytics event remain out of scope, unchanged from ADR-016's deferrals.
- `coach_msg` analytics, when built (M6), inherits `logCoachEvent`'s
  typed-fields shape (ADR-016 binding) — nothing in this slice loosens it.
