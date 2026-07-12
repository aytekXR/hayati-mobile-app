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
  proxy only … per-user rate limits … model-swappable"), §3 (data model), §4
  (Functions), §7 (analytics schema — unbuilt), §8 (privacy), §10 (cost);
  ADR-011 (dayKey parity); ADR-013 (mirror + Decision 5); ADR-014 (premium
  gating); `frontend-brandkit.md` (registers, "never clinical — we are not
  therapy").
- **Review note:** hardened pre-code by the S018 four-lens adversarial design
  review (safety/normalization, server/concurrency, privacy/security,
  scope/consistency; every finding independently verified, then adjudicated).
  2 blocking + 10 serious + ~20 minor accepted findings are folded in below;
  refuted findings and the two adjudication calls that overrode a verifier
  are recorded in Consequences.

## Context

M5 puts a **generative system in front of a couple in crisis, in three
languages**. The accept line is a safety line: *seeded crisis phrases in
TR/AR/EN route to the professional-help path, never to the persona.* This
slice builds the safety spine and the server seam — NOT the chat UI (M5.2).

Forces:

- **Safety is the product here.** A naive `includes()` check is a safety
  hole: Arabic carries optional diacritics, tatweel stretching, and
  hamza/alef orthographic variants; Turkish casefolding is locale-sensitive
  (İ/i, I/ı) and Turks routinely type WITHOUT diacritics entirely; Arabizi
  (Franco-Arabic — Arabic written in Latin script with digit-letters 3=ع,
  7=ح, 5=خ) is the dominant informal register for young Arabic speakers; and
  trivial evasions (spacing, leetspeak, homoglyphs, letter repetition)
  defeat literal matching. An **under-triggering** crisis filter is
  dangerous; an **over-triggering** one merely costs a persona reply.
  Asymmetry decides the design: conservative everywhere. Evasion resistance
  comes from **normalization, never from lexicon secrecy** — the seed lists
  are committed to a public repo by design.
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
  caps and §1 requires **per-user rate limits** on the LLM proxy. Remote
  Config is the PRD's aspiration for tunability — but nothing is deployed,
  so nothing is tunable yet; the storage decision (where the counts live and
  how they are enforced under concurrency) is what's due now.
- **Privacy by construction.** "No coach text in analytics payloads
  (asserted)" is an accept line. The repo's precedent is
  `payload-policy.ts`: *the type signature is the guarantee* — `composePush`
  has no question/answer parameter, so there is nothing to leak. No analytics
  stack exists yet (scout-verified; §7 is an unbuilt schema), so the
  assertable surface today is **logs** — and the review showed "logs" means
  more than the handler's own lines: the callable framework auto-logs any
  escaped non-`HttpsError` (message + stack), and the existing callable mold
  ends its catch with `logger.error('… failed', error)` — both are leak
  vectors the coach path must close. **This is also a domestic-violence-aware
  product**: the `violence` lexicon exists because partner violence is in
  scope, so *metadata* (who tripped the crisis detector; how often a partner
  uses the coach) is sensitive too, not just message text.

Alternatives considered are inlined per decision.

**Naming note:** governing docs (`architecture.md` §2/§4, `test-suite.md`,
the resume prompt) say `coach_proxy` — that is the pre-build placeholder
style (`rc_webhooks` → `revenueCatWebhook`, `question_rollover` →
`questionRollover`). The shipped export is **`coachProxy`**, matching the
codebase's camelCase function exports. Docs are reconciled in this session's
docs-with-code pass.

## Decision 1 — Server surface: `coachProxy` callable, europe-west1

`coachProxy` is an **`onCall` callable** (like `createInvite`/`joinInvite`),
region `FUNCTIONS_REGION = 'europe-west1'` (imported, not redefined),
`enforceAppCheck: false` (repo-wide posture until the item-4 device slice),
exported from `index.ts`. The handler is a **factory with defaulted DI**
(`makeCoachProxyHandler(deps)`) so tests inject `db`/`now`/provider/caps —
the `makeRevenueCatWebhookHandler` mold.

Request shape (every field validated server-side at runtime — the TS union
types are compile-time only; the wire is untrusted):

```ts
{
  coupleId: string,            // caller must be a member (server-verified)
  personaId: 'coach' | 'dateGenie' | 'giftGenie',   // closed enum, validated
  language: 'tr' | 'ar' | 'en',                     // closed enum, validated
  register: 'tr-playful' | 'tr-respectful'
          | 'ar-gulf-respectful' | 'en-neutral',    // closed enum, validated
  messages: [{ role: 'user' | 'assistant', text: string }, ...]
}
```

`register` is a **closed union of the brandkit register ids, validated at
input** — review finding: an open `string` passed toward a future
system-prompt position is a prompt-injection seam; it is closed now, at the
port shape, before any adapter exists.

Bounds (`invalid-argument` on violation, all messages static — see
Decision 8): ≤ 20 messages per window, ≤ 2,000 chars per message, last
message must be `role: 'user'`, enums as above. The window is
client-carried; **the server persists no message content** (Decision 8).

Auth guard: `request.auth?.uid` must be a non-empty string (the
`uid.length === 0` guard both existing callables carry, because the
emulator's debug mode can pass garbage tokens through as `auth` with an
undefined uid).

Response contract (M5.2 renders from this):

```ts
{
  kind: 'reply' | 'help',      // help = crisis path (pre- or post-filter)
  category?: 'selfHarm' | 'violence',   // present when kind = 'help'
  text: string,
  remaining?: { daily: number, monthly: number }  // optional, point-in-time
}
```

`remaining` is present only on paths that ran the cap transaction (persona
reply, post-filter help); it is a **point-in-time hint**, not authoritative —
the monthly bucket is couple-shared, so a partner's concurrent reserve makes
it stale immediately. The `kind` discriminator exists so M5.2 renders the
help path with non-persona treatment (review finding: without it, a
post-filter help response is indistinguishable from a persona turn).

*Alternative rejected:* `onRequest` — wrong tool; there is no server-to-server
caller and we would hand-roll auth the callable gives us.

## Decision 2 — Pipeline order and fail-closed semantics (the safety spine)

The handler runs this fixed order:

1. **Auth** — missing/empty uid → `unauthenticated`.
2. **Per-uid rate limit** — in-memory, 30 calls/min/uid, the `invitePreview`
   per-IP limiter mold (per-instance only, documented limitation). Exceeded
   → `resource-exhausted` / `details.reason: 'rate-limited'`. This honors
   `architecture.md` §1's "per-user rate limits" mandate and bounds the
   only path that consumes no cap (the crisis scan). 30/min is far above
   any human typing rate — a genuine caller, in crisis or not, never hits
   it; a scripted loop does.
3. **Crisis pre-scan — before ANY rejection.** The detector (Decision 3)
   runs over **every message in the window regardless of role** (a forged
   `assistant` turn is still attacker-controlled input headed for the
   provider), each message truncated to its first 4,000 chars for scanning
   (double the legit maximum, so no well-formed content is ever truncated),
   **plus the space-joined concatenation of all message texts** (a phrase
   split across two turns must still hit), with **all three language
   lexicons always** — the client-declared `language` NEVER selects the
   detection lexicon (review blocking finding: a lied-about language must
   not bypass detection; `language` selects only the help-copy localization,
   falling back to EN if the field is junk). A hit returns the help path
   immediately: **no provider call, no cap consumption, no persona, no
   Firestore read.** This branch runs for ANY authenticated caller —
   premium or not, member or not. Rationale: safety outranks gating; the
   help path costs nothing, reveals nothing (the lexicon is public by
   design), and a person in crisis must never be turned away by a paywall,
   a cap, **or an input-validation rejection** — which is why the scan
   precedes step 4 (review finding: a 2,400-char crisis outpouring must get
   the help path, not `invalid-argument`).
4. **Input validation** — bounds + enums (Decision 1) → `invalid-argument`.
5. **Transaction** (Decision 7; one consistent read set — couples doc,
   subscriptions mirror, cap docs):
   a. **Membership** — evaluated from the in-transaction `couples` read
      (never a separate pre-read; no TOCTOU) — `auth.uid ∈ memberUids` else
      the transaction returns a typed `not-member` outcome → the shell maps
      to `permission-denied`. A missing/malformed couple doc is `not-member`,
      never a raw throw — membership resolves BEFORE any dayKey derivation.
   b. **Premium gate** (Decision 6) — not premium → typed `not-premium`
      outcome → **`failed-precondition`** / `details.reason: 'not-premium'`
      (review finding: the repo's state-precondition precedent is
      `failed-precondition` + reason — `already-paired`, `expired`,
      `consumed` — and it keeps `permission-denied` unambiguous as
      "non-member", separable by CODE even if `details` is dropped by the
      platform channel; M5.2's paywall trigger keys on this).
   c. **Cap reservation** — would-exceed → typed `cap-exceeded` outcome →
      `resource-exhausted` / `details.reason: 'cap-daily' | 'cap-monthly'`
      (frozen wire strings — M5.2 renders "come back tomorrow" vs "monthly
      limit reached" from exactly these).
   The transaction **returns typed outcomes, never throws for decidable
   states** (the `ProcessOutcome` mold); the shell maps outcomes to
   `HttpsError`. All logging happens AFTER the transaction returns (the
   callback re-runs under contention; log lines inside it would duplicate).
6. **Provider call** (Decision 5) through the port — outside the
   transaction, after the reserve.
7. **Crisis post-filter** — the same detector (all three lexicons — an LLM
   can reply in an unexpected language) over the provider's reply. A hit
   discards the persona reply and returns the help path (cap stays
   consumed — the provider was paid).
8. Reply to the client (`kind`/`category`/`text`/`remaining`).

**Fail-closed semantics, precisely:**

- Any **error inside the safety pipeline** (normalizer throw, detector
  throw, post-filter throw) → **help path**. Doubt about safety resolves to
  the help path, never to the persona. Every such catch logs via
  `logCoachEvent` typed fields only — never the error message (a thrown
  error's message can embed input text).
- Any **provider/infra error** (port throw, timeout, unconfigured provider)
  → typed `unavailable` — the honest "coach unavailable" state (the RC
  webhook's 503 discipline, callable-side). An outage is not a crisis; a
  coach that answered every outage with crisis resources would train users
  to ignore the help path. The reserved cap units are **refunded
  best-effort** (Decision 7); if the refund itself fails, the units stay
  burned and the failure is logged (typed fields only) — accepted trade-off.
- Any **other unexpected throw** (e.g. a timezone-resolution failure inside
  the cap path — near-impossible, the couple timezone is allow-listed at
  join) → typed `internal`, never a raw escape: the handler **catches every
  throw and rethrows only static-message `HttpsError`s** (Decision 8 —
  otherwise the callable framework auto-logs the raw error object).
- A **crisis phrase must never reach the provider**: the pre-scan covers
  every role and the concatenation, runs before the port, and the tests pin
  "zero provider calls on every seeded phrase" via the port's call log.

## Decision 3 — Crisis detector: pure core, normalization-first, conservative lexicons

**Files:** `functions/src/coach/normalize.ts`, `crisis-lexicon.ts`,
`crisis.ts` — all pure (the `streak.ts`/`entitlement-core.ts` mold: no
Firestore, no I/O, total functions over plain values), exhaustively unit- and
property-tested without the emulator.

**Normalizer pipeline** (applied identically to lexicon entries at build
time and input text at match time — one code path, so the two can never
skew):

1. Unicode **NFKC** normalization (folds full-width forms, ligatures,
   presentation forms — Arabic presentation forms A/B included).
2. **Format-character strip:** the full Unicode `Cf` category (tatweel
   U+0640 is handled in step 3; this covers ZWJ/ZWNJ/ZWSP, directional
   marks, U+FEFF, soft hyphen U+00AD, U+2060–U+2064, and the rest) plus
   variation selectors U+FE00–U+FE0F.
3. **Arabic folding:** strip tashkeel (U+064B–U+065F, U+0670), strip tatweel
   (U+0640); fold alef variants أ/إ/آ/ٱ → ا; fold ى → ي; fold ة → ه; fold
   the hamza carriers **ؤ → و and ئ → ي**; strip bare hamza ء (review
   finding: hamza-dropping is routine casual Arabic typing — a seed with ؤ
   must match hamza-less input).
4. **Digit normalization:** Arabic-Indic ٠–٩ (U+0660–0669) and Extended
   Arabic-Indic ۰–۹ (U+06F0–06F9) fold to ASCII digits.
5. **Casefold:** full lowercase over ALL letters, with Turkish I-rules
   applied to the I-family (İ→i, I→ı), then ı and i **fold to a single
   bucket `i`**. Then the **Turkish ASCII-fold: ç→c, ş→s, ğ→g, ö→o, ü→u**
   (review blocking finding: diacritic-less typing is the Turkish norm —
   "kendimi oldurecegim" must match a seed "kendimi öldüreceğim").
6. **Homoglyph fold:** common Cyrillic/Greek confusables → Latin (е→e, а→a,
   о→o, с→c, р→p, …).
7. **Repetition collapse:** ALL runs of the same letter ≥ 2 collapse to one,
   on both lexicon and input (review finding: preserving doubles while
   collapsing ≥3 is non-monotone — "killll"→"kil" missed a "kill" seed;
   collapsing everything to singletons is monotone and strictly
   over-triggering, i.e. safe).
8. Two match texts are produced: **space-collapsed** (separators → single
   space) and **separator-stripped** (every non-letter removed).
9. **Leet variants:** matching runs against BOTH the leet-folded (0→o, 1→i,
   3→e, 4→a, 5→s, 7→t, 8→b, @→a, $→s, !→i) and the unfolded forms of the
   input (review finding: a global leet fold corrupts Arabizi, where 3=ع,
   7=ح, 5=خ are letters — "3ayez amout" must stay matchable by an Arabizi
   seed in its unfolded form; matching both variants is monotone —
   more match surface, over-trigger only).

**Lexicon format** (`crisis-lexicon.ts`): per-language arrays of entries
`{ phrase, matchMode: 'substring' | 'token', category }`, with an explicit
**Arabizi seed track inside the AR list** (Latin-script entries — flagged
for the Gulf-dialect native reviewer alongside the Arabic-script ones).
`substring` matches against both normalized forms (and both leet variants).
`token` (for short/ambiguous single words like TR "öl") requires the token
to appear as a **maximal letter-run in the separator-stripped form** whose
boundaries correspond to non-letters in the original text (review finding:
the earlier "space-collapsed form only" rule reopened the spacing evasion —
"ö l" — for exactly the entries token mode protects; the maximal-run rule
keeps the false-positive control without the hole). Token mode is the single
concession to false-positive control, per-entry, never global. Categories:
`selfHarm`, `violence`. Seeding is **deliberately conservative
(over-triggering)**.

**Native review is a BLOCKING operator item before the coach ships to any
device** (added to `operator-expected.md` this session): the TR list by the
founders, the AR list (Arabic script AND Arabizi) by the Gulf-dialect
reviewer. AI-drafted seeds ship the *mechanism* now (ADR-007
personal-use-first allows engineering to proceed); the *lexicon quality
gate* is human and native.

**Testing — one red lever per fold step.** Exhaustive unit tables per
language per entry, plus **fast-check property tests with one mutation class
per normalizer step**, so removing ANY fold turns the suite red (review
finding: the earlier enumeration left NFKC, alef variants, ى/ة, homoglyphs
and hamza-drop unpinned): NFKC forms (full-width/presentation-form
substitution), Cf/VS injection, tashkeel + tatweel injection, alef-variant
and ى/ة and hamza-carrier swaps, Arabic-Indic digit substitution, TR case
randomization incl. İ/ı, TR diacritic stripping, homoglyph substitution,
letter repetition, separator injection (INCLUDING against token-mode
entries), leet substitution, and **cross-message splitting** (a seed phrase
split across two window messages must still hit via the concatenation
scan). The seed phrases + canonical evasion variants live in
`functions/test/fixtures/coach-crisis-seeds.json` following the
`day-key-parity.json` discipline: a `policy` header (which also carries a
content warning — the file necessarily contains self-harm/violence
vocabulary; entries stay minimal and non-graphic), a `cases[]` array, and a
spread guard (≥ N cases per language) so the fixture cannot silently rot.

## Decision 4 — Help path + disclaimer content: static, localized, no unverified hotline numbers

`functions/src/coach/help-content.ts` carries, per language (TR/AR/EN, with
EN as the fallback when the declared `language` is junk):

- The **help-path response**: warm, direct, non-clinical (brandkit voice —
  "considerate friend", never guilt), acknowledging the seriousness, urging
  contact with local emergency services and a trusted professional or
  person.
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
    personaId: CoachPersonaId; language: CoachLanguage; register: CoachRegister;
    messages: ReadonlyArray<{ role: 'user' | 'assistant'; text: string }>;
  }): Promise<{ text: string }>;
}
```

The shape is **ours, not any vendor's** — deliberately smaller than every
provider API so any of them can adapt to it. The system-prompt scaffold
(persona presets' content) is M5.2 scope; this slice defines only the closed
`CoachPersonaId`/`CoachRegister` types and passes the fields through the
port.

- **`FixtureCoachProvider`** (test): replays
  `functions/test/fixtures/coach-provider-fixtures.json` (policy-headed,
  same fixture discipline, content warning included), keyed by scenario;
  records a **call log** the safety tests assert against ("zero calls on
  crisis input"). Fixtures include a reply that *contains* crisis text
  (pinning the post-filter) and a throwing scenario (pinning the
  `unavailable` + refund path — also needed to keep the fail-closed branch
  inside the 80% branch-coverage gate).
- **`UnconfiguredCoachProvider`** (production default this slice): always
  throws a typed `ProviderUnavailableError` → the handler's `unavailable`
  path. This is the `REVENUECAT_IOS_API_KEY` fail-closed pattern: no key, no
  provider, honest unavailable state — and it means `coachProxy` can DEPLOY
  safely before any provider decision is made.
- **`ProviderUnavailableError` carries a classification enum ONLY** — its
  `message` is a static string and it never embeds upstream response text
  (review finding: a future adapter writing
  ``new ProviderUnavailableError(`upstream 400: ${body}`)`` would put echoed
  prompt content into any log that ever sees the error; the type shape
  forbids it before any adapter exists).

**When a live adapter lands (M5.2/M5.3):** the key follows the
`RC_WEBHOOK_TOKEN` precedent exactly — `secrets: ['LLM_API_KEY']` on the
function, read from `process.env` **at request time** behind an injectable
deps seam, a line in `functions/.env.demo-hayati` for emulator runs
(throwaway value), real value in Secret Manager at deploy. No CI change.
The live adapter also inherits two obligations recorded here: the
post-filter already runs all three lexicons (off-language replies), and the
adapter must map upstream errors to the classification enum without ever
copying upstream text into an error message.

**Candidates + costs (founder decision, recorded in `operator-expected.md`):**
quality in Arabic (Gulf register) and Turkish is the differentiating
requirement. Anthropic Claude models, current published prices per million
tokens (input/output): Haiku 4.5 $1/$5; Sonnet 4.6 $3/$15 (Sonnet 5 intro
$2/$10 through 2026-08-31, then $3/$15); Opus 4.8 $5/$25. At a realistic
coach message (~3K input incl. persona scaffold + window, ~300 output):
Haiku ≈ $0.005, Sonnet ≈ $0.014, Opus ≈ $0.023 per message. Worst-case
couple at full caps (2 users × 30/day × 30 days = 1,800 msgs):
Haiku ≈ $8/mo, Sonnet ≈ $24/mo, Opus ≈ $41/mo — realistic usage is far
below cap, the monthly couple cap (Decision 7) binds well before that, and
prompt caching cuts the recurring scaffold input cost ~90%. OpenAI and
Google Gemini are viable alternatives behind the same port; their current
pricing is to be pulled fresh at decision time (not quoted here from
memory). No commitment is made in this ADR.

## Decision 6 — Server-side premium gate off the mirror (ADR-013 D5, one shared helper)

The D5 check gets **one home**: a pure helper in `entitlement-core.ts` —

```ts
isPremiumMirror(summary: { entitled: boolean; expiresAtMs: number | null },
                nowMs: number): boolean
// entitled === true && (expiresAtMs === null || expiresAtMs > nowMs)
```

(review finding: `coachProxy` is the FIRST server-side consumer of the
mirror; the same formula already lives in the app's `isPremium` provider —
extracting the helper gives every future Function the binding D5 discipline
without re-inlining, and keeps the strict-`>` boundary byte-consistent with
the app.)

Inside the cap transaction (one consistent read set), `coachProxy` reads
`subscriptions/{coupleId}` and applies `isPremiumMirror(summary, now())`:

- Absent doc → free tier → `failed-precondition` / `'not-premium'`.
- `entitled: true` with past `expiresAtMs` → NOT premium (the delayed-
  EXPIRATION window ADR-013 D5 exists for).
- `now()` is an injectable dep (test-controlled), like the webhook's.
- The client's opinion is never consulted. `PremiumGate`/`isPremiumProvider`
  (ADR-014) will gate the M5.2 *surface*; this is the *enforcement*.

## Decision 7 — Caps: parent doc + self-read daily subcollection, transactional reserve-then-refund

**Storage** (couple-scoped, function-written; split shaped by the
review's strongest privacy finding):

```
coachUsage/{coupleId}:                    // parent: couple-shared state
  monthly: { monthKey: 'yyyymm', count: number }
  updatedAt: serverTimestamp

coachUsage/{coupleId}/daily/{uid}:        // per-user lane: SELF-read only
  dayKey: 'yyyymmdd'
  count: number
  updatedAt: serverTimestamp
```

**Why the split:** a single member-read doc holding
`daily: { <uid>: count }` would let each partner read the other's coach
usage frequency — in a product whose `violence` lexicon exists precisely
because domestic violence is in scope, an abusive partner monitoring the
victim's quiet coach use is a real leak. The repo already solved this
shape once: M3 put per-user answers in a subcollection because rules are
document-granular. Same move here: the **monthly bucket is couple-shared
and member-read** (it is genuinely joint state); the **daily lane is
self-read only**.

- **Self-resetting, zero cleanup:** period keys are compared at read time —
  a stored `dayKey`/`monthKey` differing from the current one means the
  count is stale and resets to 0 before the increment. No TTL policy, no
  scheduled sweep, no unbounded growth. This is the invite-expiry
  lazy-evaluation precedent.
- **Period keys derive from the couple's timezone** via the existing
  `localDayKey` (ADR-011 parity-pinned; DST-correct by construction; the
  timezone field is allow-listed at join and frozen by rules, so the
  RangeError path is defensively mapped but effectively unreachable);
  `monthKey` is the `yyyymm` prefix of the same `localDayKey` result.
- **Transaction discipline** (`coach-service.ts`, the entitlement-service
  mold: `db` first param, deps seam, decide-then-write, **typed outcome
  union returned to the shell — decidable states never throw**): one
  `db.runTransaction` reads `couples/{coupleId}` (membership FIRST, then
  timezone), `subscriptions/{coupleId}` (Decision 6), the parent
  `coachUsage` doc and the caller's `daily/{uid}` doc; checks both caps;
  **increments BOTH lanes (reserves) before the provider call** and writes
  them back. Concurrency is the reason reservation is transactional and
  precedes the call: parallel requests otherwise all read count = 29 and
  all pass — an unbounded provider-cost hole. The reserve **returns the
  period keys it wrote** (`reservedDayKey`, `reservedMonthKey`) for the
  refund guard. `logCoachEvent` is called only after the transaction
  returns.
- **Refund (per-lane captured-key guard):** on provider failure
  (Decision 2), a best-effort second transaction decrements **each lane
  independently, guarded by its OWN captured key**: the daily lane
  decrements iff its stored `dayKey` still equals `reservedDayKey`; the
  monthly lane iff its stored `monthKey` equals `reservedMonthKey`; floor 0;
  **on a key mismatch the refund writes NOTHING to that lane** — never a
  lazy reset (review finding: a reserve at 23:59 refunded at 00:01 crosses
  the daily boundary but not the monthly one — a single shared guard either
  corrupts the fresh day's count or skips a valid monthly refund; and a
  refund that "resets then decrements" would eat a concurrent partner's
  fresh reservation). Refund failure → units burned, logged with typed
  fields.
- **Cap values:** defaults in code constants — `DAILY_PER_USER = 30` (PRD),
  `MONTHLY_PER_COUPLE = 1000` (cost guard ≈ 55% of the 1,800 theoretical
  max; at Sonnet pricing caps worst-case couple spend ≈ $14/mo) — injected
  through the service's deps seam (`caps: CapConfig`). Note the arithmetic
  consequence, deliberately accepted and founder-tunable: a couple at both
  daily caps every day hits the monthly cap around day 17; M5.2 must
  render daily vs monthly exhaustion distinctly (the frozen
  `cap-daily`/`cap-monthly` reasons exist for exactly this). **Remote
  Config binding is explicitly deferred to the deploy era**: nothing is
  deployed, so nothing is remotely tunable; when the first deploy lands,
  the seam takes a Remote-Config-backed implementation without touching
  the service. This honors PRD F5's "Remote Config" intent without
  building dead plumbing now (documented debt, not silent). The §4
  "per-couple monthly token cap" wording is reconciled to **message cap**
  in the docs-with-code pass (counting tokens requires provider-specific
  tokenizers the port deliberately hides).

**Rules** (`firestore.rules`; the header comment listing unmatched
collections is updated — `coachUsage` becomes matched, `coach_sessions`
stays deferred):

```
match /coachUsage/{coupleId} {
  allow read: if request.auth != null
    && request.auth.uid in get(/databases/$(database)/documents/couples/$(coupleId)).data.memberUids;
  allow write: if false; // coachUsage: function-only (coachProxy, admin SDK)

  match /daily/{uid} {
    allow read: if request.auth != null && request.auth.uid == uid;
    allow write: if false; // coachUsage daily lanes: function-only
  }
}
```

Member-read on the parent (monthly) and self-read on the daily lane exist so
M5.2 can watch remaining quota live — with one documented obligation: resets
are **lazy** (applied in the next `coachProxy` transaction), so a client
watching the raw docs at a period boundary sees the stale stored count until
the next call; M5.2 must apply the same stored-key-vs-current-key comparison
(via `coupleDayKey`) client-side, or prefer the response's `remaining` hint.
Covered by the standard rules cases per block (member/self read allowed,
other-partner denied on daily, non-member + anon denied, all client writes
denied, orphan-couple fail-closed) **plus ≥ 2 mutation entries per block**
(write-deny → authed-allow; read-guard → authed-only) with block-qualified
anchors per the mutation-suite discipline.

## Decision 8 — Privacy by construction: no message text, no uid, no crisis-identity join on any log surface

- **Logging:** all `coachProxy` logging goes through `logCoachEvent(fields)`
  in the pure core, whose input type has **no message/text field and no uid
  field** — `{ outcome, coupleId?, personaId, language, capRemainingDaily?,
  capRemainingMonthly?, latencyMs?, errorCode? }`. The payload-policy
  precedent: the signature is the guarantee. Three review-driven
  tightenings:
  1. **Crisis-outcome lines omit `coupleId`** (and carry no uid, like every
     coach line): a log stating "couple X tripped the self-harm detector"
     is special-category-adjacent personal data under the KVKK/PDPL
     posture; help-path lines carry only
     `{ outcome, language, latencyMs }`. Ops can count help-path hits, not
     attribute them.
  2. **No uid-bearing entry log:** the createInvite/joinInvite mold's
     `logger.info(name, { uid, … })` entry line is explicitly NOT copied
     into the coach path; the coach's entry/exit logging is `logCoachEvent`
     only.
  3. **The raw-object catch log is forbidden in the coach path:** the mold's
     `logger.error('… failed', error)` would write `error.message` (which
     can embed input text) to Cloud Logging. The coach handler catches
     EVERY throw and (a) logs via `logCoachEvent` with a typed `errorCode`
     classification only, (b) rethrows only **static-message
     `HttpsError`s** — so the callable framework's own
     "unhandled error" auto-logger (which logs message + stack of any
     escaped non-`HttpsError`) can never fire on request-derived content.
     All `HttpsError` messages and `details` values in the coach path are
     static/enumerated; nothing is ever interpolated from request text.
- **Persistence:** this slice persists **nothing** of the conversation — no
  `coach_sessions`, no message docs (private-thread/history is an explicit
  M5.2+ scope decision). The only writes are the `coachUsage` counters.
  PRD §8 "AI inputs never retained beyond session context window budget" is
  satisfied trivially: retention is zero. One documented consequence for
  M5.2 (review finding): because the window is client-carried and the
  pre-scan covers the whole window, a crisis turn left in the window
  re-routes every subsequent call to the help path — M5.2's window
  construction owns the drop-or-retain decision, and this ADR pins that
  obligation.
- **Analytics:** none exists in the codebase (scout-verified). The accept
  line "no coach text in analytics payloads (asserted)" is therefore pinned
  today at the log surface: handler tests seed a **sentinel string** in
  message text across every path (crisis, persona, cap-exhausted,
  provider-failure, **and a forced normalizer-throw case** — an ordinary
  sentinel never exercises the catch sites), capture all console output
  during the run, and assert the sentinel never appears; a further test
  asserts **no non-`HttpsError` ever propagates out of the handler** on any
  seeded path, and at least one sentinel case drives the WRAPPED callable
  through the functions emulator so the framework's own logging surface is
  inside the captured perimeter. When `coach_msg` instrumentation lands
  (§7, pre-launch), its emitter MUST take the `logCoachEvent` typed-fields
  shape — this ADR makes that binding.

## Test commitments (pinned, not inferred)

The accept lines resolve to these concrete assertions, named here so none
can silently degrade to "implied":

1. Every seeded crisis phrase and every generated evasion variant (TR/AR/EN
   incl. Arabizi track, all mutation classes of Decision 3) → help path,
   with **zero provider-port calls** (fixture call log) — unit + property.
2. Cap exhaustion end-to-end: drive the daily lane to `DAILY_PER_USER` →
   `resource-exhausted`/`cap-daily` AND zero port calls; same for the
   monthly bucket → `cap-monthly`.
3. Non-premium mirror (absent doc; `entitled:false`; `entitled:true` +
   past `expiresAtMs`) → `failed-precondition`/`not-premium`, zero cap
   consumption, zero port calls.
4. Provider failure → `unavailable`, BOTH lanes refunded (and the
   captured-key mismatch case: refund after a simulated period rollover
   writes nothing to the rolled lane).
5. Post-filter: fixture reply containing crisis text → `kind:'help'`, cap
   consumed.
6. The sentinel/log perimeter suite of Decision 8 (incl. the forced-throw
   and wrapped-callable cases).
7. Rules: the standard allow/deny matrix for `coachUsage` parent + daily
   lane (incl. partner-denied on daily) + ≥2 mutations per block.
8. `coachProxy` e2e through the functions emulator against
   `FixtureCoachProvider` (recorded fixtures; no live calls anywhere).

## Docs-with-code checklist (this session's pass)

`architecture.md` §2 (coach_proxy → coachProxy naming), §3 (add `coachUsage`
parent + daily subcollection to the data model), §4 (coachProxy flow;
"token cap" → "message cap"; rate limiter; Remote-Config-deferred note), §7
(the `coach_msg` emitter binding to `logCoachEvent`'s shape), §8 (coach log
discipline incl. the no-uid/no-crisis-join rules), §10 (cost bounds under
caps); `test-suite.md` §1 (coach rows: pure-core unit/property, handler
emulator, rules mutations); `implementation-plan.md` (M5.1 entry);
`firestore.rules` header comment; `resume-prompt.md` (M5.2 next);
`operator-expected.md` (lexicon + hotline native review as a blocking
pre-device item; provider candidates + costs; LLM key becoming due at first
live call).

## Consequences

**Positive**

- Crisis safety is a pure, property-tested core with one normalizer code
  path shared by lexicon and input — the class of "matcher and data skewed"
  bugs is structurally excluded, and CI proves evasion resistance (one red
  lever per fold step) on every run without any network.
- The coach can be built, tested, reviewed, and even deployed with **no
  provider account, no key, and no cost** — the founder's provider decision
  is decoupled from the engineering timeline (the ADR-007 spirit).
- Cost is bounded three times over before any real spend exists: the
  per-uid rate limiter, transactional caps closing the concurrency hole,
  and the monthly couple cap putting a hard ceiling under any future
  provider price.
- Safety, gating, and caps are enforced **server-side in one transaction**;
  no client claim is trusted anywhere in the path; the wire contract
  (`failed-precondition`/`not-premium`, `resource-exhausted`/`cap-daily`/
  `cap-monthly`, `kind` discriminator) is frozen for M5.2.
- Zero content retention, no-text-no-uid log types, and the
  static-`HttpsError` catch-all discipline make the privacy accept line
  hold by construction — including against the framework's own error
  logger, not just our lines.

**Negative / accepted trade-offs**

- **Over-triggering filter:** legitimate conversations mentioning crisis
  vocabulary (e.g., discussing a news story) get the help path instead of
  the persona; the both-leet-variants and all-lexicon matching widen this
  further. Accepted deliberately; the asymmetry of harms decides.
- **AI-drafted lexicons until native review:** the mechanism ships proven;
  the seed quality gate is human and BLOCKS device rollout (operator item).
- **Cap unit burn on failed refund:** a provider failure whose refund also
  fails costs the user one message of quota. Rare (two independent
  failures), bounded (one unit per lane), logged.
- **Post-filter consumes the cap:** a persona reply discarded by the
  post-filter still cost a provider call, so the unit stays consumed.
- **Remote Config deferred:** cap tuning requires a code change until the
  deploy era. Documented here, not silent.
- **Non-premium/non-member crisis callers get the help path:** a
  deliberate, information-free exception to "free tier gets ZERO" — the
  free tier gets zero *coach*; it does not get zero *safety*. The review's
  "crisis-lexicon oracle" concern was adjudicated REFUTED-as-blocking: the
  lexicon is committed to a public repo by design (normalization, not
  secrecy, is the defense), so the pre-scan reveals nothing an attacker
  can't read; the residual compute surface is bounded by the per-uid rate
  limiter. The free-tier-untouched assertion suite is unaffected (no coach
  UI exists for free users; the exception is defense in depth).
- **Rate limiter is per-instance, in-memory** (the invitePreview
  precedent): a multi-instance deployment multiplies the effective limit by
  instance count. Accepted at this scale; revisit at deploy hardening.
- **Sticky help path on crisis-bearing windows** is intended conservatism;
  M5.2 owns the window-construction decision and inherits it documented,
  not discovered.

**Neutral**

- `coach_sessions`/private thread, persona system-prompt content, the live
  provider adapter, and the chat UI remain M5.2+ scope. The
  `questions`-style unmatched-collection discipline keeps any future coach
  collections denied until their rules ship with tests.
- Review findings refuted with evidence (recorded for the S017 discipline):
  the committed crisis fixtures as a "leak" (public by design;
  content-warning headers added instead); the webhook-rationale rate-limit
  refutation was itself overridden by `architecture.md` §1's explicit
  mandate (the two verifier lenses disagreed; the architecture doc decides).
