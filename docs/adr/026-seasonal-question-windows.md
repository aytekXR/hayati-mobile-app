# ADR-026: Seasonal question windows — the Hijri/Gregorian window→date mapping and the seasonal-preferring selection policy

- **Status:** Accepted (Session 037, 2026-07-25) — **rev 2**, hardened by the
  pre-code adversarial design review (11 surfaced findings folded in; see
  *Review record* at the end)
- **Closes:** issue #29 · ADR-011 Decision 4's explicit deferral and its
  first Follow-up line
- **Amends:** ADR-011 Decision 4 (evergreen-only selection policy), and
  narrows the reading of ADR-011's Consequences on client prefetch (D7)
- **Scope:** `functions/` selection core + the content vocabulary
  (schema / validator / schema-agreement guard / both strict parsers).
  **No app behavior changes** — the shipped client reads the day doc's
  `questionId` and never computes a selection, so no Dart mirror of the
  calendar math exists or is added.

## Context

M3.2 shipped the daily rollover with a documented **evergreen-only**
selection policy (ADR-011 D4): any question carrying a `seasonalWindow` is
excluded from selection entirely. No shipped question carries one, so the
filter is a no-op in practice — and the deferral was honest, because the
missing half is a *calendar* problem, not a selection problem: `ramadan`
and `eid` are Hijri, and the Hijri year drifts ~11 days per Gregorian year.

Two things are missing, and #29 names both:

1. **window → date resolution** — the predicate `(window, local calendar
   date) → in-window?`, including the Hijri mapping;
2. **the selection-core change** — prefer in-window seasonal questions over
   evergreen ones.

Three facts about the current code shape the decision:

- **Selection is a pure function of (pack, history)** and its determinism is
  load-bearing: `assignDayQuestion` does a non-transactional read-then-create,
  and the safety argument for that is *"losing the create race to an
  overlapping sweep is benign because the racer computed the same
  assignment"* (ADR-011 D2). Anything that makes selection depend on the
  wall clock breaks that argument.
- **The `seasonalWindow` contract is a free string today** (`string |
  undefined`, non-empty). Nothing anywhere knows what the legal values are —
  the schema says *"e.g. ramadan, eid, new_year"* in a description, and both
  strict parsers accept any non-empty string.
- **The couple's local calendar date already exists at the selection call
  site** as the day doc's own `dayKey` (`yyyymmdd`, computed once per
  timezone bucket). The timezone has already done its work by then.

## Decision

### D1 — The window predicate keys off the day doc's own `dayKey`, never `now`

`selectQuestion(pack, historyQuestionIds, dayKey)` — a **required** third
parameter, not an optional one with an evergreen-only default (a default
would let a future caller silently lose seasonal selection).

The predicate is a pure function of the `dayKey` *string*, so it inherits
that key's determinism: two overlapping sweeps assigning the same day doc —
one at 23:59 local, one at 00:30 local, one on a retry hours later —
compute the same window verdict, because they are all writing the same
`days/{dayKey}` and the verdict is derived from that id. Keying off the
sweep instant (`at`) instead would make two racers disagree across a
midnight boundary. The `dayKey` is also exactly the right *semantic* input:
the window is asked about the couple's local calendar day, which is what
the doc id means.

**Precision on what ADR-011 D2's benign-race argument actually rests on**
(review finding B-1, partially accepted). ADR-011 words it as *"concurrent
runs race benignly (they compute identical assignments)"*, and the same
phrasing is echoed in `select-question.ts` and `rollover-service.ts`. The
load-bearing property is narrower than that sentence: the race is benign
because **`create()` is atomic and exactly one assignment can land** —
identical computation is what makes the discarded one *uninteresting*, not
what makes the race safe. Two racers can already compute different
questions today whenever their history reads straddle another day doc's
commit (an overlapping sweep that crosses a bucket's local midnight writes
`D+1` while a slower sweep is still assigning `D`); with evergreen-only
selection an `H={}` vs `H={E1}` skew already flips the pick from `E1` to
`E2`. ADR-026 does **not** introduce that class — it only makes seasonal
ids, which previously could not affect an evergreen-only filter, count the
same way evergreen ids always have. So: the window verdict is fully
racer-invariant (this ADR's contribution), the same-question property was
never absolute, and nothing is corrupted either way. The comments in
`select-question.ts` and `rollover-service.ts` are corrected in the same
diff so they stop claiming more than the mechanism carries.

### D2 — Hijri via ICU `islamic-umalqura`, zero dependency — with a loud availability guard, because the silent fallback is Gregorian

Node 20 (the pinned Functions runtime) ships full ICU, which carries the
Umm al-Qura civil calendar. The conversion is one `Intl.DateTimeFormat` —
the same primitive `day-key.ts` already uses, so no new dependency, no
hand-rolled arithmetic, and no calendar table to maintain:

```ts
new Intl.DateTimeFormat('en-US', {
  calendar: 'islamic-umalqura',
  numberingSystem: 'latn',
  timeZone: 'UTC',
  year: 'numeric', month: 'numeric', day: 'numeric',
})
```

formatted over **12:00 UTC of the `dayKey`'s Gregorian date**. Noon-UTC and
`timeZone: 'UTC'` together make the conversion a pure calendar→calendar map
with no offset arithmetic anywhere near a date boundary; the couple's zone
is deliberately *not* an input here (it already produced the `dayKey`).

**The guard is the load-bearing part of this decision.** An unsupported
calendar is not an error in `Intl` — it is silently ignored, and
`resolvedOptions().calendar` reports what was actually used. Verified on
this box:

```
option calendar=islamic-umalqura -> resolved=islamic-umalqura | 9/1/1447 AH
option calendar=nonexist         -> resolved=gregory          | 2/18/2026
```

So a runtime with a trimmed ICU would not throw — it would hand back
**Gregorian** month/day numbers, and a `month === 9` Ramadan test would
then fire **every September, for every couple, forever**, with nothing red
anywhere. That is the single most dangerous failure mode in this ADR, and
it is invisible without an explicit check.

**Mechanism, named end to end** (review findings ADR026-1 / B-3 — the
original text asserted "logs once per sweep" with no channel between the
pure predicate module and the only layer that holds a logger):

1. `seasonal-window.ts` (pure, no `firebase-functions` import) builds its
   formatter once, lazily, and memoises the verdict
   `resolvedOptions().calendar === 'islamic-umalqura'`. It exports
   **`hijriCalendarAvailable(): boolean`**.
2. When unavailable, `hijriDateOf()` returns `null` for every input and
   every **Hijri** window (`ramadan`, `eid_fitr`, `eid_adha`) is reported
   **CLOSED**. `new_year` is Gregorian, derived from the `dayKey`
   characters themselves, and is unaffected.
3. `runQuestionRollover` calls `hijriCalendarAvailable()` **once per sweep,
   before the bucket loop**, and on `false` emits a single `logger.error`
   naming the degradation and its consequence.
4. The same verdict is surfaced on the run summary as
   **`RolloverSummary.seasonalCalendarUnavailable: boolean`**, so the
   property is asserted by an ordinary test against a returned value rather
   than by log-spying, and the handler's existing summary log carries it
   into Cloud Logging for free.

**Fail direction, deliberately split:** closed in the *content* sense
(never show a Ramadan question outside Ramadan — a wrong-content failure
is the one users would see), open in the *availability* sense (evergreen
selection keeps working, so the daily loop does not stop for every couple
over a calendar library). Throwing instead would turn a cosmetic capability
loss into a total outage of the product's core loop, dressed up as N
per-couple skips.

### D3 — The window vocabulary becomes a CLOSED enum, gated in FIVE places

| id | calendar | window (inclusive) |
|---|---|---|
| `ramadan` | Umm al-Qura | month 9, all days (1–29/30) |
| `eid_fitr` | Umm al-Qura | month 10 (Shawwāl), days 1–3 |
| `eid_adha` | Umm al-Qura | month 12 (Dhū al-Ḥijjah), days 10–13 |
| `new_year` | Gregorian | Dec 31 – Jan 1 |

Enforced in **five** places — the four readers plus the drift guard that
keeps two of them honest (review findings ADR026-2 / D-1: the original text
said "four", and the *existing pattern for every other enum* it invoked is
in fact a three-way sync, not a two-way one):

1. the JSON schema (`enum`);
2. the content validator's per-question check (`knownSeasonalWindows`) —
   the single content **gate**;
3. `validateSchemaAgreement`'s `checkEnum('questions.items.seasonalWindow',
   …)` — without this, schema and validator can silently diverge on the
   vocabulary and the authoring gate the enum exists to provide is exactly
   the thing that rots first;
4. the TS pack parser (`SEASONAL_WINDOWS as const` → `SeasonalWindow`,
   narrowing `Question.seasonalWindow`, mirroring `QUESTION_CATEGORIES`);
5. the Dart pack DTO (defense-in-depth at the app's consumption edge, the
   existing pattern for every other enum in this schema).

Why closed rather than free-string: with a free string, an author who
writes `"Ramadan"`, `"eid"`, or `"ramadan_2027"` gets a question that is
**never selected, silently, forever** — the worst possible content bug,
because the pack validates, CI is green, and the question simply never
appears. A closed enum turns that into a red content gate at authoring
time. Nothing is lost: no shipped pack carries a window, so the tightening
breaks no existing content.

**`eid` is deliberately NOT a value.** There are two Eids about two months
apart; a single `eid` tag cannot express which, and an "Eid Mubarak"
question that fires on both is a different editorial choice from one that
fires on either. Authors say which.

Two in-repo uses of the retired vocabulary are updated in the same diff
(review finding D-2 — the narrowed type makes the second a *compile*
error, not a test failure): the schema description's `e.g. … eid …`
example, and `functions/test/unit/select-question.test.ts`'s
`q('e1', 'eid')`. That test's helper signature is narrowed to
`SeasonalWindow` so a future value-level mistake is caught by `tsc`, and
its `NoSelectableQuestionError` case is given a `dayKey` outside every
window so the assertion still means what it meant.

### D4 — Selection policy: in-window seasonal **unseen** first, then evergreen, then in-window recycle

Replacing ADR-011 D4's exclusion filter, in order:

1. **In-window seasonal, unseen** → first such question in pack authoring
   order.
2. Else **evergreen** → unchanged: first unseen in pack order, then
   min-times-assigned recycle with pack order breaking ties.
3. Else **in-window seasonal, recycled** → min-times-assigned, pack order
   breaking ties (this is what keeps an all-seasonal pack usable *inside*
   its window).
4. Else → `NoSelectableQuestionError` (unchanged class; the message now
   names the day, since selectability is date-dependent).

Out-of-window seasonal questions are excluded exactly as today.

The load-bearing choice is **step 1's "unseen"**, i.e. the seasonal
preference applies only while the seasonal stock is fresh. #29 asks to
"prefer in-window seasonal questions over evergreen ones"; a naive reading
— prefer them *always* — means 5 Ramadan questions loop six times over a
30-day Ramadan while the evergreen curriculum sits idle. That is worse
than what ships today, and it is the kind of thing that reads fine in a
diff and feels broken in week two. Unseen-first gives the season its
moment and then returns to the curriculum, and it preserves the existing
recycle semantics *exactly* (no cross-set count interaction is introduced).

Rejected alternative — *recycle seasonal before recycling evergreen inside
a window*: defensible ("during Ramadan a repeated Ramadan question beats a
repeated evergreen one") but it introduces a second recycle domain whose
behavior changes mid-window, for a marginal editorial gain. Reconsider when
real seasonal content exists and the founder has an opinion.

### D5 — Umm al-Qura is the authority; the ±1-day observance divergence is a recorded bound, not padded

Umm al-Qura is a *calculated civil* calendar (Saudi Arabia's). Actual
observance differs by country and method: Türkiye's Diyanet uses
astronomical calculation and can run a day earlier; sighting-based
countries can run a day later. So a window edge can be off by a day
somewhere.

We do **not** pad the windows. Padding Ramadan by a day either side would
be harmless, but the same padding on `eid_fitr` would put an "Eid Mubarak"
question on the last fasting day — a worse error than the one it fixes,
and the asymmetry is what makes a blanket pad wrong. A one-day edge
difference on a question-of-the-day is cosmetic: nothing about safety,
money, or data depends on it (the day doc carries `questionId` only — no
push copy, streak rule, coach input or entitlement reads the window).
Recorded here rather than discovered later.

### D6 — `new_year` is Dec 31 – Jan 1

Two days, the turn itself, no Hijri involvement — and deliberately the one
window that **straddles a Gregorian year boundary**, so the implementation
cannot express it as a single `(month, day)` range comparison and the
fixture proves both halves. Wider windows dilute ("what do we want for us
this year" is a January-1 question, not a December-20 one), and the
unseen-first rule means extra stock is not lost — it fires next year.
Widening is a one-row edit in the window table.

### D7 — The Hijri predicate is server-only; no Dart mirror, and no parity fixture — with ADR-011's prefetch language read honestly

**What ADR-011 actually says** (review finding B-2 — rev 1 paraphrased it
as "ADR-011 binds *the client never predicts*", which is not in that
document): ADR-011's Consequences bind *"the server assignment is
authoritative"* and then **contemplate** client offline prefetch as a
*prediction* over the same bundled pack that reconciles to the day doc on
sync. That is a permitted future capability, not a commitment — and it was
never built. The shipped app reads `days/{dayKey}.questionId` and renders
the pack question by id; its own code and localization strings say so
(`paired_providers.dart`: *"never a client-side prediction; ADR-011"*), and
the honest no-day-yet state exists precisely because the client will not
guess.

So the Hijri predicate lives **only** in TS. This is the deliberate
difference from `localDayKey`, whose Dart mirror exists *because* the app
must compute the doc id it reads — and which is byte-pinned by
`day-key-parity.json` for that reason. A Dart Hijri mirror today would
create a parity surface with nothing on the other side of it.

**Recorded, not foreclosed:** if offline prefetch-as-prediction is ever
built, it needs a Dart mirror of this predicate *and* a
`day-key-parity`-style fixture pinning the two calendars byte-for-byte —
Dart's `intl` does not carry Umm al-Qura, so that is a real cost to price
in at that time, not a footnote. Listed under Follow-ups.

The Dart side's only change here is D3's vocabulary check — string
equality against four constants, no calendar math.

### D8 — The acceptance harness: an explicit date fixture, a real dangerous-mode simulation, and a mutation check

**The fixture** — `functions/test/fixtures/seasonal-window-cases.json`,
each row a `dayKey` → expected Hijri `(year, month, day)` → expected
**open-window set**. Enumerated explicitly rather than described, because a
described edge is an edge someone computes wrong (review findings CAL-1,
CAL-2):

| dayKey | Hijri | open |
|---|---|---|
| `20260217` | 1447/8/29 | — (Ramadan entry, outside) |
| `20260218` | 1447/9/1 | `ramadan` |
| `20260319` | 1447/9/30 | `ramadan` (exit, inside — a **30-day** Ramadan) |
| `20260320` | 1447/10/1 | `eid_fitr` (Ramadan exit outside; Eid entry inside) |
| `20260322` | 1447/10/3 | `eid_fitr` (exit, inside) |
| `20260323` | 1447/10/4 | — (`eid_fitr` exit, outside) |
| `20260526` | 1447/12/9 | — (**`eid_adha` entry, outside** — CAL-1) |
| `20260527` | 1447/12/10 | `eid_adha` |
| `20260530` | 1447/12/13 | `eid_adha` (exit, inside) |
| `20260531` | 1447/12/14 | — (exit, outside) |
| `20261230` | 1448/7/21 | — (`new_year` entry, outside) |
| `20261231` | 1448/7/22 | `new_year` |
| `20270101` | 1448/7/23 | `new_year` (the **year-boundary** half) |
| `20270102` | 1448/7/24 | — (exit, outside) |
| `20270207` | 1448/8/30 | — (Ramadan 1448 entry, outside) |
| `20270208` | 1448/9/1 | `ramadan` |
| `20270308` | 1448/9/29 | `ramadan` (exit, inside — a **29-day** Ramadan) |
| `20270309` | 1448/10/1 | `eid_fitr` |

Every window therefore has **both sides of both edges**. Two rows carry
extra weight: the 1448 pair sits ~11 Gregorian days earlier than the 1447
pair, so any "Gregorian month mistaken for Hijri month" bug fails; and
1448's Ramadan is **29 days** while 1447's is 30, so an implementation that
hardcodes a month length rather than testing `month === 9` fails too. All
18 rows verified against Node 20's ICU while writing this ADR.

**The dangerous-mode simulation** (review finding D-3 — rev 1's "break the
assertion and prove a test reddens" could not actually demonstrate the
failure mode, because on a full-ICU box *deleting* the guard changes
nothing and only *inverting* it reddens anything, which proves the wrong
thing). The suite installs the real degradation:
`vi.spyOn(Intl.DateTimeFormat.prototype, 'resolvedOptions')` returning
`{…, calendar: 'gregory'}` (verified writable+configurable on Node 20),
then `vi.resetModules()` + a dynamic re-import so the module's memoised
verdict is computed under the spy, and asserts:

- `hijriCalendarAvailable() === false`;
- `hijriDateOf()` is `null` for every fixture dayKey;
- every **Hijri** window is CLOSED on dates the fixture proves are inside
  it — i.e. *"Ramadan does not fire in September"* is asserted, not hoped;
- `new_year` still opens on `20261231` (the Gregorian window is unaffected);
- `runQuestionRollover` sets `seasonalCalendarUnavailable: true` and still
  assigns evergreen questions to every couple.

This also covers the otherwise-unreachable null branch for the coverage
gate.

**The mutation check:** with the guard removed, that same spy-driven test
must go red (the module would report Gregorian month 9 as Ramadan). A guard
whose failure nothing observes is decoration.

**Regression:** the existing selection suite must pass with behavior
unchanged for packs with no seasonal questions — the no-op-in-practice
claim, proven mechanically rather than asserted.

## Consequences

**Positive**

- #29 and ADR-011's oldest follow-up close together; the first seasonal
  content can be authored the day the founder wants it, with a red gate if
  the tag is wrong instead of a question that never appears.
- Zero new dependencies (no Hijri library, no calendar table to age), and
  the same `Intl` primitive the day-key core already trusts.
- The one genuinely dangerous failure mode (silent Gregorian fallback →
  "Ramadan every September") is closed by an explicit, observable,
  mutation-checked guard rather than by hoping the runtime has full ICU.

**Negative / accepted**

- Selection is no longer a pure function of (pack, history) — it is now a
  pure function of (pack, history, **dayKey**). The signature change
  touches every caller and the existing suite.
- Window edges follow Umm al-Qura and can differ by a day from local
  observance (D5), unpadded and on purpose.
- A pack that is entirely seasonal now succeeds *inside* a window and
  throws outside it, where before it always threw. The failure path is
  unchanged (a loud per-couple skip counted in `summary.failed`, and the
  app's honest no-day-yet state) — but it is now date-dependent, which is
  worth knowing when reading a run summary. *(Reviewed and deliberately
  not split into its own counter: no all-seasonal pack exists, and the
  per-couple log line already carries the error type and coupleId.)*
- The vocabulary is closed, so adding a season later (e.g. `mothers_day`)
  is a five-file change, not a content edit. That is the intended trade.

## Follow-ups

- Seasonal **content** authoring stays a founder/W9 item — this ADR builds
  the mechanism, not the questions. (`operator-expected.md` item 1.)
- If offline prefetch-as-prediction is ever built (ADR-011 contemplates it;
  nothing implements it), it needs a Dart mirror of this predicate plus a
  `day-key-parity`-style byte-pinned fixture — and Dart's `intl` has no
  Umm al-Qura calendar, so price that in before promising the capability.
- If the founder ever wants observance-accurate (sighting-based) Ramadan
  dates per market, that is a data source, not a code change: the window
  table gains a per-market override and D5's bound is revisited.
- `ramadan` fires for the whole month by design; a "last ten nights"
  window is a vocabulary addition if content ever wants one.
- The TS parser's enums (`PACK_LOCALES`, `PACK_REGISTERS`,
  `QUESTION_CATEGORIES`, and now `SEASONAL_WINDOWS`) have **no**
  schema-agreement guard on the TS side — only the Dart validator does
  (D3.3). That pre-dates this ADR and is not widened by it; filed as its
  own issue rather than smuggled into this diff.

## Review record — the pre-code adversarial pass (rev 1 → rev 2)

Four lenses (calendar correctness · determinism & the ADR-011 invariants ·
failure modes & guarantee-vs-mechanism · contract-tightening blast radius),
each finding double-verified by a refuting skeptic and a governing-docs
adjudicator, surfaced when **either** verifier called it real (the S030
aggregation rule). **12 raw findings, 11 surfaced, 1 refuted, 2 verifier
splits.** Folded into rev 2:

| id | severity | what it caught | landed in |
|---|---|---|---|
| ADR026-1 / B-3 | **BLOCKING** | "logs once per sweep" had *no channel* from the pure module to the logging layer — the classic guarantee-vs-mechanism gap | D2 mechanism 1–4 (`hijriCalendarAvailable()` + sweep-level log + summary flag) |
| ADR026-2 / D-1 | SERIOUS | the "existing pattern for every other enum" is a **three**-way sync; `validateSchemaAgreement` was the missing fifth reader | D3 (five places, `checkEnum` named) |
| D-3 | SERIOUS | rev 1's mutation check could not demonstrate the dangerous mode — deleting the guard changes nothing on a full-ICU box | D8 (spy-driven real degradation + `vi.resetModules`) |
| B-2 | SERIOUS | D7 cited ADR-011 for a sentence it does not contain; ADR-011 *contemplates* client prefetch | D7 rewritten; the mirror cost recorded as a follow-up |
| CAL-1 | SERIOUS | the fixture's own "both sides of each edge" claim was false — `eid_adha` had no pre-entry row | D8 fixture (`20260526`) |
| D-2 | SERIOUS | `select-question.test.ts`'s `q('e1','eid')` becomes a **compile** error under the narrowed type; its all-seasonal case also changes meaning under D4 | D3 (both in-repo uses named) |
| D-4 | MINOR | `architecture.md` §4, the M3.2 plan entry and ADR-011 itself go stale | the same-diff doc set (below) |
| CAL-2 | MINOR *(split)* | "same Ramadan edges in 1448" hides that Ramadan 1448 is **29** days | D8 fixture enumerated explicitly; the 29/30 contrast is now a deliberate property |
| B-1 | SERIOUS *(split)* | claimed ADR-026 breaks ADR-011 D2's "identical assignments" | **partially accepted** — the skeptic's counter-example is decisive (history-read skew already flips evergreen picks, so the class pre-dates this ADR), but the adjudicator is right that D1 overclaimed; D1 now states what the race actually rests on |
| ADR026-3 | — | `NoSelectableQuestionError` shares `summary.failed` with misconfiguration | **refuted** — already named in Consequences; recorded there explicitly |

**Same-diff document set** (project-rules #8, finding D-4): this ADR ·
`docs/adr/README.md` index · ADR-011 (Status gains an *amended-by* pointer;
D4 and the Follow-up line marked closed) · `docs/architecture.md` §4's
rollover paragraph · `docs/implementation-plan.md`'s M3.2 entry ·
`content/schema/question-pack.schema.json`'s description.
