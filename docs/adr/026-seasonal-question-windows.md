# ADR-026: Seasonal question windows — the Hijri/Gregorian window→date mapping and the seasonal-preferring selection policy

- **Status:** Proposed (Session 037, 2026-07-25)
- **Closes:** issue #29 · ADR-011 Decision 4's explicit deferral and its
  first Follow-up line
- **Amends:** ADR-011 Decision 4 (evergreen-only selection policy)
- **Scope:** `functions/` selection core + the content vocabulary
  (schema / validator / both strict parsers). **No app behavior changes** —
  the client never predicts the assignment (ADR-011 Consequences), so no
  Dart mirror of the calendar math exists or is needed.

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
midnight boundary and would invalidate ADR-011 D2's benign-race argument.
The `dayKey` is also exactly the right *semantic* input: the window is
asked about the couple's local calendar day, which is what the doc id
means.

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

Mechanism: the module constructs its formatter once and asserts
`resolvedOptions().calendar === 'islamic-umalqura'`. If it is anything
else, `hijriDateOf()` returns `null` for every date and every *Hijri*
window is reported **CLOSED**.

**Fail direction, deliberately split:** closed in the *content* sense
(never show a Ramadan question outside Ramadan — a wrong-content failure
is the one users would see and the one that embarrasses), open in the
*availability* sense (evergreen selection keeps working, so the daily loop
does not stop for every couple over a calendar library). Throwing instead
would turn a cosmetic capability loss into a total outage of the product's
core loop, dressed up as N per-couple skips. The unavailability is
**not silent**: `runQuestionRollover` logs it once per sweep at
`logger.error` with an explicit message.

`new_year` is Gregorian and is unaffected by an ICU shortfall — it is
derived from the `dayKey` characters themselves.

### D3 — The window vocabulary becomes a CLOSED enum, gated in all four places

| id | calendar | window (inclusive) |
|---|---|---|
| `ramadan` | Umm al-Qura | month 9, all days (1–29/30) |
| `eid_fitr` | Umm al-Qura | month 10 (Shawwāl), days 1–3 |
| `eid_adha` | Umm al-Qura | month 12 (Dhū al-Ḥijjah), days 10–13 |
| `new_year` | Gregorian | Dec 31 – Jan 1 |

Enforced in **all four** places that read the field: the JSON schema
(`enum`), the content validator (the single content *gate*), the TS pack
parser and the Dart pack DTO (defense-in-depth at both consumption edges,
the existing pattern for every other enum in this schema).

Why closed rather than free-string: with a free string, an author who
writes `"Ramadan"`, `"eid"`, or `"ramadan_2027"` gets a question that is
**never selected, silently, forever** — the worst possible content bug,
because the pack validates, CI is green, and the question simply never
appears. A closed enum turns that into a red content gate at authoring
time. Nothing is lost: no shipped pack carries a window, so the tightening
breaks no existing content, and every value the schema description ever
named is still expressible.

**`eid` is deliberately NOT a value.** There are two Eids about two months
apart; a single `eid` tag cannot express which, and an "Eid Mubarak"
question that fires on both is a different editorial choice from one that
fires on either. Authors say which. (The schema description's old
`e.g. … eid …` example is updated in the same diff — an example that no
longer validates would be its own trap.)

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
recycle semantics *exactly* (no cross-set count interaction is ever
introduced).

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
money, or data depends on it. Recorded here rather than discovered later.

### D6 — `new_year` is Dec 31 – Jan 1

Two days, the turn itself, no Hijri involvement. Wider windows dilute
("what do we want for us this year" is a January-1 question, not a
December-20 one), and the unseen-first rule means extra stock is not lost
— it fires next year. Widening is a one-row edit in the window table.

### D7 — No Dart mirror of the calendar math; no cross-platform parity fixture

ADR-011 already binds *"the server assignment is authoritative; the client
never predicts"*, and that is true in the shipped code (the app reads
`days/{dayKey}.questionId` and renders the pack question by id; the
no-day-yet state exists precisely because it will not guess). So the Hijri
predicate lives **only** in TS. This is the deliberate difference from
`localDayKey`, whose Dart mirror exists *because* the app must compute the
doc id it reads — and which is byte-pinned by `day-key-parity.json` for
that reason. Adding a Dart Hijri mirror would create a parity surface with
nothing on the other side of it.

The Dart side's only change is D3's vocabulary check — string equality
against four constants, no calendar math.

### D8 — The acceptance harness: a committed date fixture + a mutation check on the guard

- **`functions/test/fixtures/seasonal-window-cases.json`** — dayKey →
  expected Hijri (y/m/d) and expected open-window set, spanning both edges
  of every window and both sides of each edge: Ramadan 1447 day 1 / day 30
  / the day before / the day after; Eid al-Fitr days 1–3 + day 4; Eid
  al-Adha days 10–13 + day 14; Dec 30 / 31, Jan 1 / 2; **and the same
  Ramadan edges in 1448**, whose Gregorian dates sit ~11 days earlier — a
  test any "month 9 = September"-class bug fails. The fixture is the ICU
  drift guard: if a future ICU data revision moves an Umm al-Qura date, the
  suite goes red instead of the product quietly shifting.
- **The D2 guard is MUTATION-CHECKED**: break the `resolvedOptions()`
  assertion and prove a test reddens. A guard whose failure nothing
  observes is decoration.
- Selection tests cover each numbered branch of D4 plus the
  out-of-window-ignored case, and the existing selection suite must pass
  **unchanged in behavior** for packs with no seasonal questions (the
  no-op-in-practice claim, mechanically).

## Consequences

**Positive**

- #29 and ADR-011's oldest follow-up close together; the first seasonal
  content can be authored the day the founder wants it, with a red gate if
  the tag is wrong instead of a question that never appears.
- Zero new dependencies (no Hijri library, no calendar table to age), and
  the same `Intl` primitive the day-key core already trusts.
- The one genuinely dangerous failure mode (silent Gregorian fallback →
  "Ramadan every September") is closed by an explicit, mutation-checked
  assertion rather than by hoping the runtime has full ICU.

**Negative / accepted**

- Selection is no longer a pure function of (pack, history) — it is now a
  pure function of (pack, history, **dayKey**). Determinism is preserved
  (D1), but the signature change touches every caller and the existing
  suite.
- Window edges follow Umm al-Qura and can differ by a day from local
  observance (D5), unpadded and on purpose.
- A pack that is entirely seasonal now succeeds *inside* a window and
  throws outside it, where before it always threw. The failure path is
  unchanged (a loud per-couple skip and the app's honest no-day-yet
  state) — but it is now date-dependent, which is worth knowing when
  reading a run summary.
- The vocabulary is closed, so adding a season later (e.g. `mothers_day`)
  is a four-file change, not a content edit. That is the intended trade.

## Follow-ups

- Seasonal **content** authoring stays a founder/W9 item — this ADR builds
  the mechanism, not the questions. (`operator-expected.md` item 1.)
- If the founder ever wants observance-accurate (sighting-based) Ramadan
  dates per market, that is a data source, not a code change: the window
  table gains a per-market override and D5's bound is revisited.
- `ramadan` fires for the whole month by design; a "last ten nights"
  window is a vocabulary addition if content ever wants one.
