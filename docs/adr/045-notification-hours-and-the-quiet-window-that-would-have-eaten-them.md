# ADR-045: the founder's notification hours — 09:00 and 22:00 — and the quiet window that would have silently eaten the second one

- **Status:** Accepted
- **Date:** 2026-08-10 (Session 067)
- **Deciders:** founder (the hours and the notification set), session agent (the quiet-window consequence, which is not a product choice)
- **Related:** **ADR-042 D3/D4** (this re-points both of their hours; D4's *reason* is unchanged and reaffirmed), **ADR-012 D3** (one couples read per sweep; the quiet window this amends), `docs/architecture.md` §5

## Context

The founder set the notification policy directly:

> 1. **Question delivery time:** Questions should be sent at **9:00 AM**, not at midnight.
> 2. **Notifications:** Let's only send notifications in the following cases:
>    * When a new question arrives
>    * When the partner answers the question
>    * At **10:00 PM**, if the question still hasn't been answered

Two of the three cases already existed and needed only re-timing. The third —
"when the partner answers" — already existed **twice**, and one ambiguity in the
first line was material enough to ask about rather than guess.

## Decision 1 — Only the ANNOUNCEMENT moves to 09:00. Rollover still assigns at local midnight

*"Not at midnight"* has two readings, and they are not close in cost:

* **(a)** the *notification* moves 08:00 → 09:00; the question is still assigned
  at local midnight, so someone opening the app at 00:30 already sees it;
* **(b)** the *assignment* moves to 09:00, so no question exists between midnight
  and 09:00.

**The founder chose (a)**, asked directly. (b) was not a smaller wording change:
`dayKey`, the streak, the reveal decision and both push passes are all keyed on
the local-midnight boundary, so moving assignment would have opened a nine-hour
window per day with no question and no defined app state — a new screen state to
design, not a constant to edit.

So: `DAILY_QUESTION_LOCAL_HOUR` **8 → 9**, and `question-rollover` is untouched.

## Decision 2 — The nudge moves 16:00 → 22:00, and its *meaning* was already right

`AT_RISK_LOCAL_HOUR` **16 → 22**.

Nothing else in that pass changed, because ADR-042 D4 had already made it exactly
what the founder is now asking for: it fires for couples whose day doc exists and
is **unrevealed**, with **no streak precondition**, and notifies the members who
have not answered. The file name (`at-risk.ts`) lags that meaning and is left
alone deliberately — renaming it would be a diff across the sweep, the tests and
three ADRs to fix a noun, and ADR-042 D4's header already says so in place.

## Decision 3 — The quiet window moves 22:00 → 23:00, and this is the decision that matters

**This is not a preference. Shipping D2 without it would have delivered nothing.**

`isQuietLocalHour` was `hour >= 22 || hour < 8`, and `deliverSweepPush` re-checks
it per recipient as defense in depth (ADR-012 D3). **22 was the FIRST QUIET
HOUR.** A nudge re-pointed to 22:00 would therefore have been composed, counted,
and then dropped by our own guard into `suppressedQuiet` — on every couple, every
night. The deploy would have been green, the sweep would have logged three
healthy summary lines, and no phone would ever have buzzed at 10 PM.

That is the exact failure shape this repo keeps paying for: a feature that fails
by going **quiet**, where the absence of an effect is indistinguishable from
absence of demand. It was caught by reading the guard before changing the
constant, not by testing afterwards.

So the window is now **23:00–08:00**, and **22:00 is the last legal hour** —
precisely mirroring 08:00 as the first.

### What this costs, stated rather than buried

The founder asked for a 22:00 push and therefore, necessarily, for one fewer hour
of protected quiet. A push may now arrive at 22:00–22:59 where previously nothing
could. That is the direct consequence of the request and not a side effect worth
hiding: **10 PM is inside anyone's evening, and the person receiving it may be
with family.** The discreet-mode copy already governs *what* such a push says
(ADR-018/payload-policy), so the exposure is a lock-screen line the user has
already chosen the wording class of — but the hour itself is new, and if the
founder wants it back, moving the nudge to 21:00 restores the old window with a
one-constant change and no other consequence.

## Decision 4 — The fragile boundary did not disappear; it MOVED, and it is asserted at its new end

Under ADR-042 D3 the daily question sat exactly on the 08:00 edge, and that
adjacency was documented and tested as the thing most likely to silently kill the
feature. After this change:

* **09:00 has an hour of slack** below it. The morning end is no longer fragile.
* **22:00 is now flush against the 23:00 edge.** The fragility is entirely at the
  evening end, and it is *coupled*: moving either `AT_RISK_LOCAL_HOUR` or
  `isQuietLocalHour` by one, in either direction, kills the nudge with every
  unrelated test still green.

Both ends are asserted in three places rather than one — `local-hour.test.ts`
(the window's full boundary table plus both scheduled hours), `at-risk.test.ts`
(hour 22 open, hour 23 quiet, stated as the coupling), and
`daily-question.test.ts` (hour 9 open, and that its OLD hour 08:00 is legal but
no longer fires, so a half-applied re-point shows up somewhere).

That last one is the assertion worth naming: **testing "not quiet" is not
testing "the right hour."** 08:00 is still perfectly legal; only a test pinned to
the pass's *own* hour catches a constant that moved in one file and not the other.

## Decision 5 — No notification kind is removed. The founder's list already covers all four

The founder wrote three cases; the system has four push kinds. Asked directly,
they chose to keep both partner pushes, because both *are* "the partner
answered", from opposite sides:

| kind | fires | in the founder's list as |
|---|---|---|
| `dailyQuestion` | 09:00 local | "when a new question arrives" |
| `partnerAnswered` | partner answers first, you have not | "when the partner answers" |
| `reveal` | you answered first, partner completes the day | "when the partner answers" |
| `streakAtRisk` | 22:00 local, day still unanswered | "at 10:00 PM, if still unanswered" |

Dropping `reveal` would have meant the first answerer gets **no** notification
when their partner finishes — they would have to open the app to discover the day
had opened, which is the opposite of the ask.

## Consequences

* Two constants and one policy predicate changed; no logic, no schema, no copy.
* `1071 functions tests` pass, coverage 97.45%.
* **Prod runs the OLD hours until Functions are redeployed.** They are deployed by
  hand (#206) and a prod deploy is a founder ask (`session-context.md` §7), so
  until then production announces at 08:00 and nudges at 16:00 regardless of what
  `main` says. `functions_drift.py` (ADR-043) is what makes that visible rather
  than assumed — and this is exactly the merged-vs-running gap it was built for.
* The 22:00 exposure of D3 is a founder-reversible one-constant change.
