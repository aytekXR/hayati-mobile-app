# ADR-016: AI coach v0 — safety spine first, provider-agnostic seam, transactional caps, server-side premium gate

- **Status:** Accepted
- **Date:** 2026-07-12 (Session 018, M5.1)
- **Deciders:** Session 018 (autonomous, per resume-prompt objective); founder
  directives inherited: ADR-007 (personal-use-first), ADR-013 Decision 5
  (expiry pairing, binding on every consumer), ADR-014 (PremiumGate /
  `isPremiumProvider` seam).
- **Related:** PRD F5 (coach), F1 (registers), §8 NFR ("AI inputs never
  retained beyond session context window budget"); `mvp.md` IN #7;
  `implementation-plan.md` M5; `architecture.md` §1 ("LLM via Cloud Function
  proxy only … model-swappable"), §3 (data model), §4 (Functions), §7
  (analytics schema — unbuilt), §8 (privacy), §10 (cost); ADR-011 (dayKey
  parity); ADR-013 (mirror + Decision 5); ADR-014 (premium gating);
  `frontend-brandkit.md` (registers, "never clinical — we are not therapy").

## Context

M5 puts a **generative system in front of a couple in crisis, in three
languages**. The accept line is a safety line: *seeded crisis phrases in
TR/AR/EN route to the professional-help path, never to the persona.* This
slice builds the safety spine and the server seam — NOT the chat UI (M5.2).

Forces:

- **Safety is the product here.** A naive `includes()` check is a safety
  hole: Arabic carries optional diacritics, tatweel stretching, and hamza/alef
  orthographic variants; Turkish casefolding is locale-sensitive (İ/i, I/ı);
  and trivial evasions (spacing, leetspeak, homoglyphs, letter repetition)
  defeat literal matching. An **under-triggering** crisis filter is dangerous;
  an **over-triggering** one merely costs a persona reply. Asymmetry decides
  the design: conservative everywhere.
- **CI must be hermetic and free.** The repo's discipline is a fakeable port
  contract-tested against recorded fixtures (`purchases_flutter` behind
  `PurchasesRepository`; RC webhook against RC's documented payloads). The
  coach must never call a live model in CI (`test-suite.md` §4 policy), and
  this slice makes **zero live calls anywhere** — no provider account exists.
- **No provider is chosen, and none needs to be.** No repo doc names a
  provider (scout-verified). The resume prompt's stopping condition applies:
  the seam is provider-agnostic, fixtures only; candidates + costs are
  recorded in `operator-expected.md` for the founder's decision at M5.2/M5.3
  (an API key becomes an operator item only when a live call is first made).
- **Premium truth is server-owned.** The entitlement mirror
  (`subscriptions/{coupleId}`) is the ONLY source of premium truth, and
  ADR-013 Decision 5 is binding server-side: `entitled` alone is a projection
  artifact; every consumer pairs it with the `expiresAtMs` future-check. The
  Function must not trust any client premium claim.
- **Caps are cost control, not billing.** PRD F5: premium-only, 30 msgs/day
  per user, free tier zero. `architecture.md` §10 requires enforceable cost
  caps. Remote Config is the PRD's aspiration for tunability — but nothing is
  deployed, so nothing is tunable yet; the storage decision (where the counts
  live and how they are enforced under concurrency) is what's due now.
- **Privacy by construction.** "No coach text in analytics payloads
  (asserted)" is an accept line. The repo's precedent is
  `payload-policy.ts`: *the type signature is the guarantee* — `composePush`
  has no question/answer parameter, so there is nothing to leak. No analytics
  stack exists yet (scout-verified; §7 is an unbuilt schema), so the
  assertable surface today is **logs** — and the same by-construction
  discipline must hold when `coach_msg` instrumentation lands.

Alternatives considered are inlined per decision.

## Decision 1 — Server surface: `coachProxy` callable, europe-west1

`coachProxy` is an **`onCall` callable** (like `createInvite`/`joinInvite`),
region `FUNCTIONS_REGION = 'europe-west1'`, exported from `index.ts`. The
caller is the authenticated app — callable gives us auth context, typed
`HttpsError` codes the app's `mapFunctionsFailure` pattern already speaks,
and the same App Check posture as every other callable (enforcement OFF until
the item-4 device slice, consistent with current repo posture).

Request shape (validated, bounded — the `answerSurfaceOk` discipline):

```ts
{
  coupleId: string,            // caller must be a member (server-verified)
  personaId: 'coach' | 'dateGenie' | 'giftGenie',
  language: 'tr' | 'ar' | 'en',
  register: string,            // brandkit register id; opaque to this slice
  messages: [{ role: 'user' | 'assistant', text: string }, ...]
}
```

Bounds (invalid-argument on violation): ≤ 20 messages per window, ≤ 2,000
chars per message, last message must be `role: 'user'`. The window is
client-carried; **the server persists no message content** (Decision 8).

*Alternative rejected:* `onRequest` — wrong tool; there is no server-to-server
caller and we would hand-roll auth the callable gives us.

## Decision 2 — Pipeline order and fail-closed semantics (the safety spine)

The handler runs this fixed order:

1. **Auth** — unauthenticated → `unauthenticated`.
2. **Input validation** — bounds above → `invalid-argument`.
3. **Crisis pre-filter** — the detector (Decision 3) runs over **every
   user-role message in the window**, on the raw request, **before the
   premium gate and before the caps**. A hit returns the localized help-path
   response (Decision 4) immediately: **no provider call, no cap consumption,
   no persona.** This branch runs for ANY authenticated caller — premium or
   not. Rationale: safety outranks gating; the help path costs nothing (no
   provider call), reveals nothing, and a person in crisis must never be
   turned away by a paywall or a cap.
4. **Membership** — `auth.uid ∈ couples/{coupleId}.memberUids` →
   else `permission-denied`. (Read of the couple doc also yields the
   timezone for Decision 7's period keys.)
5. **Server-side premium gate** (Decision 6) — not premium →
   `permission-denied` with `details.reason: 'not-premium'`.
6. **Cap reservation** (Decision 7) — transactional; would-exceed →
   `resource-exhausted` with `details` naming which cap.
7. **Provider call** (Decision 5) through the port.
8. **Crisis post-filter** — the same detector over the provider's reply.
   A hit discards the persona reply and returns the help path (cap stays
   consumed — the provider was paid).
9. Reply to the client. Response carries `remaining` cap counts so M5.2 can
   render "X messages left" without a second read.

**Fail-closed semantics, precisely:**

- Any **error inside the safety pipeline** (normalizer throw, detector
  throw, post-filter throw) → **help path**. Doubt about safety resolves to
  the help path, never to the persona.
- Any **provider/infra error** (port throw, timeout, unconfigured provider)
  → typed `unavailable` — the honest "coach unavailable" state (the RC
  webhook's 503 discipline, callable-side). An outage is not a crisis; a
  coach that answered every outage with crisis resources would train users
  to ignore the help path. The reserved cap unit is **refunded best-effort**
  (Decision 7); if the refund itself fails, the unit stays burned and the
  failure is logged (typed fields only) — accepted trade-off.
- A **crisis phrase must never reach the provider**: the pre-filter runs
  before the port, and the tests pin "zero provider calls on every seeded
  phrase" via the port's call log.

## Decision 3 — Crisis detector: pure core, normalization-first, conservative lexicons

**Files:** `functions/src/coach/normalize.ts`, `crisis-lexicon.ts`,
`crisis.ts` — all pure (the `streak.ts`/`entitlement-core.ts` mold: no
Firestore, no I/O, total functions over plain values), exhaustively unit- and
property-tested without the emulator.

**Normalizer pipeline** (applied to both lexicon entries at build time and
input text at match time — one code path, so the two can never skew):

1. Unicode **NFKC** normalization (folds full-width forms, ligatures,
   presentation forms — Arabic presentation forms A/B included).
2. **Arabic folding:** strip tashkeel (U+064B–U+065F, U+0670), strip tatweel
   (U+0640); fold alef variants أ/إ/آ/ٱ → ا; fold ى → ي; fold ة → ه; strip
   ZWJ/ZWNJ/ZWSP and directional marks (U+200B–U+200F, U+202A–U+202E,
   U+2066–U+2069).
3. **Turkish-aware casefold:** İ→i, I→ı applied per Turkish rules, then both
   ı and i **fold to a single bucket `i`** for matching. Folding the dotted/
   dotless distinction away over-triggers slightly (safe) and makes matching
   immune to the classic `toLowerCase()` locale bug.
4. **Leet/homoglyph fold:** 0→o, 1→i, 3→e, 4→a, 5→s, 7→t, 8→b, @→a, $→s,
   !→i, plus a table of common Cyrillic/Greek homoglyphs → Latin
   (е→e, а→a, о→o, с→c, р→p, ...).
5. **Repetition collapse:** runs of the same letter ≥ 3 collapse to one
   (`kendimiiii` → `kendimi`); runs of 2 are preserved (legitimate doubled
   letters exist in all three languages).
6. Two match texts are produced: **space-collapsed** (separators → single
   space) and **separator-stripped** (every non-letter removed) — the second
   defeats `k e n d i m i` spacing and interleaved punctuation evasion.

**Lexicon format** (`crisis-lexicon.ts`): per-language arrays of entries
`{ phrase, matchMode: 'substring' | 'token', category }`. `substring`
matches against both normalized forms; `token` (for short/ambiguous single
words) requires word-boundary containment in the space-collapsed form only —
this is the single concession to false-positive control, and it is
per-entry, never global. Categories: `selfHarm`, `violence` (partner/domestic
violence and threats). Seeding is **deliberately conservative
(over-triggering)** per the resume-prompt stopping condition: an
over-triggering filter costs a persona reply; an under-triggering one is a
safety failure.

**Native review is a BLOCKING operator item before the coach ships to any
device** (added to `operator-expected.md` this session): the TR list by the
founders, the AR list by the Gulf-dialect reviewer. AI-drafted seeds ship the
*mechanism* now (ADR-007 personal-use-first allows engineering to proceed);
the *lexicon quality gate* is human and native.

**Testing:** exhaustive unit tables per language per entry; **fast-check
property tests** that generate evasion mutations of every seed phrase —
random diacritic insertion (AR), tatweel injection (AR), case randomization
incl. İ/ı (TR), leet substitution, separator injection, letter repetition —
and assert detection survives every mutation. A weakened normalizer (any
folding step removed) turns these red; that is the point. The seed phrases +
canonical evasion variants live in
`functions/test/fixtures/coach-crisis-seeds.json` following the
`day-key-parity.json` discipline: a `policy` header stating what the fixture
pins and why shrinking it is release-blocking, a `cases[]` array, and a
spread guard (≥ N cases per language) so the fixture cannot silently rot.

## Decision 4 — Help path + disclaimer content: static, localized, no unverified hotline numbers

`functions/src/coach/help-content.ts` carries, per language (TR/AR/EN):

- The **help-path response**: warm, direct, non-clinical (brandkit voice —
  "considerate friend", never guilt), acknowledging the seriousness, urging
  contact with local emergency services and a trusted professional or person.
- The **disclaimer copy** (PRD F5 accept line: drafted TR/AR/EN, founder
  native review flagged): "not therapy" framing, shown by M5.2's UI.

**Hard rule: no specific hotline phone numbers ship in this slice.** A wrong
or stale crisis number is actively dangerous. The copy names the universal
emergency route ("your local emergency number") and the pattern for
country-specific lines is left as a **founder-verified** addition (operator
item, same gate as the lexicon review). The help response is static content,
not model output — the help path never involves the provider.

## Decision 5 — Provider seam: provider-agnostic port, recorded fixtures only, fail-closed unconfigured

**Port** (`functions/src/coach/provider-port.ts`):

```ts
interface CoachProvider {
  generateReply(req: {
    personaId: CoachPersonaId; language: CoachLanguage; register: string;
    messages: ReadonlyArray<{ role: 'user' | 'assistant'; text: string }>;
  }): Promise<{ text: string }>;
}
```

The shape is **ours, not any vendor's** — deliberately smaller than every
provider API so any of them can adapt to it. The system-prompt scaffold
(persona presets' content) is M5.2 scope; this slice defines only the
`CoachPersonaId` type and passes the fields through the port.

- **`FixtureCoachProvider`** (test): replays
  `functions/test/fixtures/coach-provider-fixtures.json` (policy-headed,
  same fixture discipline), keyed by scenario; records a **call log** the
  safety tests assert against ("zero calls on crisis input"). Fixtures
  include a reply that *contains* crisis text, pinning the post-filter.
- **`UnconfiguredCoachProvider`** (production default this slice): always
  throws a typed `ProviderUnavailableError` → the handler's `unavailable`
  path. This is the `REVENUECAT_IOS_API_KEY` fail-closed pattern: no key, no
  provider, honest unavailable state — and it means `coachProxy` can DEPLOY
  safely before any provider decision is made.

**When a live adapter lands (M5.2/M5.3):** the key follows the
`RC_WEBHOOK_TOKEN` precedent exactly — `secrets: ['LLM_API_KEY']` on the
function, read from `process.env` **at request time** behind an injectable
deps seam, a line in `functions/.env.demo-hayati` for emulator runs
(throwaway value), real value in Secret Manager at deploy. No CI change.

**Candidates + costs (founder decision, recorded in `operator-expected.md`):**
quality in Arabic (Gulf register) and Turkish is the differentiating
requirement. Anthropic Claude models, current published prices per million
tokens (input/output): Haiku 4.5 $1/$5; Sonnet 4.6 $3/$15 (Sonnet 5 intro
$2/$10 through 2026-08-31, then $3/$15); Opus 4.8 $5/$25. At a realistic
coach message (~3K input incl. persona scaffold + window, ~300 output):
Haiku ≈ $0.005, Sonnet ≈ $0.014, Opus ≈ $0.023 per message. Worst-case
couple at full caps (2 users × 30/day × 30 days = 1,800 msgs):
Haiku ≈ $8/mo, Sonnet ≈ $24/mo, Opus ≈ $41/mo — realistic usage is far
below cap, and prompt caching cuts the recurring scaffold input cost ~90%.
OpenAI and Google Gemini are viable alternatives behind the same port; their
current pricing is to be pulled fresh at decision time (not quoted here from
memory). No commitment is made in this ADR.

## Decision 6 — Server-side premium gate off the mirror (ADR-013 D5, verbatim discipline)

Inside the cap transaction (one consistent read set), `coachProxy` reads
`subscriptions/{coupleId}` and computes:

```ts
premium = entitled === true
       && (expiresAtMs === null || expiresAtMs > now())
```

- Absent doc → free tier → `permission-denied` / `'not-premium'`.
- `entitled: true` with past `expiresAtMs` → NOT premium (the delayed-
  EXPIRATION window ADR-013 D5 exists for).
- `now()` is an injectable dep (test-controlled), like the webhook's.
- The client's opinion is never consulted. `PremiumGate`/`isPremiumProvider`
  (ADR-014) will gate the M5.2 *surface*; this is the *enforcement*.

## Decision 7 — Caps: one self-resetting `coachUsage/{coupleId}` doc, transactional reserve-then-refund

**Storage** (new top-level collection, mirroring `subscriptions`' shape
philosophy — couple-scoped, function-written, member-read):

```
coachUsage/{coupleId}:
  daily:   { <uid>: { dayKey: 'yyyymmdd', count: number } }   // per-user daily
  monthly: { monthKey: 'yyyymm', count: number }              // per-couple monthly
  updatedAt: serverTimestamp
```

- **Self-resetting, zero cleanup:** period keys are compared at read time —
  a stored `dayKey`/`monthKey` differing from the current one means the
  count is stale and resets to 0 before the increment. No TTL policy, no
  scheduled sweep, no unbounded growth (the doc holds at most 2 lanes + 1
  monthly bucket). This is the invite-expiry lazy-evaluation precedent.
- **Period keys derive from the couple's timezone** via the existing
  `localDayKey` (ADR-011 parity-pinned); `monthKey` is its `yyyymm` prefix.
  A couple's "day" is their day, not UTC's.
- **Transaction discipline** (`coach-service.ts`, the entitlement-service
  mold: `db` first param, deps seam, decide-then-write): one
  `db.runTransaction` reads `couples/{coupleId}` (membership + timezone),
  `subscriptions/{coupleId}` (Decision 6), and `coachUsage/{coupleId}`;
  checks both caps; **increments (reserves) before the provider call** and
  writes the whole doc back. Concurrency is the reason reservation is
  transactional and precedes the call: parallel requests otherwise all read
  count = 29 and all pass — an unbounded provider-cost hole. Firestore
  transaction retries under contention are the existing suite's territory
  (30s vitest timeout already accounts for ABORTED backoff).
- **Refund:** on provider failure (Decision 2), a best-effort second
  transaction decrements the reserved unit (floor 0, same-period-key guard so
  a refund never crosses a period boundary). Refund failure → unit burned,
  logged with typed fields.
- **Cap values:** defaults in code constants — `DAILY_PER_USER = 30` (PRD),
  `MONTHLY_PER_COUPLE = 1000` (cost guard ≈ 55% of the 1,800 theoretical
  max; at Sonnet pricing caps worst-case couple spend ≈ $14/mo) — injected
  through the service's deps seam (`caps: CapConfig`). **Remote Config
  binding is explicitly deferred to the deploy era**: nothing is deployed,
  so nothing is remotely tunable; when the first deploy lands, the seam
  takes a Remote-Config-backed implementation without touching the service.
  This honors PRD F5's "Remote Config" intent without building dead plumbing
  now (documented debt, not silent).

**Rules** (`firestore.rules`, byte-parallel to the `subscriptions` block):

```
match /coachUsage/{coupleId} {
  allow read: if request.auth != null
    && request.auth.uid in get(/databases/$(database)/documents/couples/$(coupleId)).data.memberUids;
  allow write: if false; // coachUsage: function-only (coachProxy, admin SDK)
}
```

Member-read exists so M5.2 can watch remaining quota live. Covered by the
four standard rules cases (member read, non-member deny, anon deny, client
writes all denied) **plus ≥ 2 mutation entries** (write-deny → authed-allow;
membership-guard → authed-only) with block-qualified anchors per the
mutation-suite discipline.

## Decision 8 — Privacy by construction: no message parameter exists on any log/analytics surface

- **Logging:** all `coachProxy` logging goes through `logCoachEvent(fields)`
  in the pure core, whose input type has **no message/text field** —
  `{ outcome, coupleId, personaId, language, capRemainingDaily?,
  capRemainingMonthly?, latencyMs?, errorCode? }`. The payload-policy
  precedent: the signature is the guarantee. Provider errors log
  `error.message` NEVER (unlike the RC webhook, whose upstream errors are
  Firestore's own — a provider error message can echo prompt content; we log
  a typed `errorCode` classification only).
- **Persistence:** this slice persists **nothing** of the conversation — no
  `coach_sessions`, no message docs (private-thread/history is an explicit
  M5.2+ scope decision). The only writes are the `coachUsage` counters.
  PRD §8 "AI inputs never retained beyond session context window budget" is
  satisfied trivially: retention is zero.
- **Analytics:** none exists in the codebase (scout-verified). The accept
  line "no coach text in analytics payloads (asserted)" is therefore pinned
  today at the log surface: handler tests seed a **sentinel string** in
  message text across every path (crisis, persona, cap-exhausted, provider-
  failure), capture all console output during the run, and assert the
  sentinel never appears. When `coach_msg` instrumentation lands (§7,
  pre-launch), its emitter MUST take the `logCoachEvent` typed-fields shape —
  this ADR makes that binding.

## Consequences

**Positive**

- Crisis safety is a pure, property-tested core with one normalizer code
  path shared by lexicon and input — the class of "matcher and data skewed"
  bugs is structurally excluded, and CI proves evasion resistance on every
  run without any network.
- The coach can be built, tested, reviewed, and even deployed with **no
  provider account, no key, and no cost** — the founder's provider decision
  is decoupled from the engineering timeline (the ADR-007 spirit).
- Cost is bounded twice over before any real spend exists: transactional
  caps close the concurrency hole, and the monthly couple cap puts a hard
  ceiling under any future provider price.
- Safety, gating, and caps are enforced **server-side in one transaction**;
  no client claim is trusted anywhere in the path.
- Zero content retention makes the privacy accept line hold by construction,
  not by scrubbing.

**Negative / accepted trade-offs**

- **Over-triggering filter:** legitimate conversations mentioning crisis
  vocabulary (e.g., discussing a news story) will get the help path instead
  of the persona. Accepted deliberately; the asymmetry of harms decides.
- **AI-drafted lexicons until native review:** the mechanism ships proven;
  the seed quality gate is human and BLOCKS device rollout (operator item).
- **Cap unit burn on failed refund:** a provider failure whose refund also
  fails costs the user one message of quota. Rare (two independent failures),
  bounded (one unit), logged.
- **Post-filter consumes the cap:** a persona reply discarded by the
  post-filter still cost a provider call, so the unit stays consumed.
- **Remote Config deferred:** cap tuning requires a code change until the
  deploy era. Documented here, not silent.
- **Non-premium crisis callers get the help path:** a deliberate, tiny
  information-free exception to "free tier gets ZERO" — the free tier gets
  zero *coach*; it does not get zero *safety*. The free-tier-untouched
  assertion suite is unaffected (no UI surface exists for free users to
  reach `coachProxy`; the exception is defense in depth).

**Neutral**

- `coach_sessions`/private thread, persona system-prompt content, and the
  chat UI remain M5.2+ scope. The `questions`-style unmatched-collection
  discipline keeps any future coach collections denied until their rules
  ship with tests.
