# ADR-079: A threshold twenty points below the measurement is not a gate

- **Status:** Accepted. **One gate tightened and made self-checking; one
  documented gate DECLINED with the measurement that refutes it.**
- **Date:** 2026-09-13 (Session 104)
- **Deciders:** session agent. **No operator dependency. CI-only; no runtime
  code, no deploy, no release.**
- **Related:** **`docs/test-suite.md` §3** (the ratchet rule this is about),
  **ADR-055 D2 revised** (the house precedent for deriving a bound, and why a
  tight one was wrong *there*), **ADR-041** / **ADR-047 D4** (the 0/1/2 exit
  taxonomy `coverage_gate.dart` already implements), lessons **162**, **164**,
  **165**

## Context — the third guard in three sessions that is green and cannot act

S102 found a channel sentinel pinning five of seven methods. S103 found a hang
watchdog that could itself be hung. This is the same shape a third time, and the
rule it breaks was already written down.

`docs/test-suite.md` §3, verbatim:

| Scope | Target | Gate |
|---|---|---|
| `domain/` (all features) | 90% | **Hard fail <85%** |
| Functions (TS) | 85% | Hard fail <80% |
| Overall Dart | **70% by M6** | Ratchet: starts 60%, +2%/milestone, never lowered — **68 since the M4 close** (measured **86.50%**) |

**Measured today, with the commands beside the numbers:**

```
$ cd app && flutter test --coverage
$ dart tool/coverage_gate.dart --min 68 app/coverage/lcov.info
coverage_gate: lines found 8246, lines hit 7236
coverage_gate: 87.75% (threshold 68%)          <- 19.75 points of slack

$ firebase emulators:exec --only auth,firestore,functions --project demo-hayati \
    'cd functions && npm run test:ci'
All files          |   97.43 |    92.81 |   97.78 |   97.68 |
                        stmts    branch     funcs     lines  <- thresholds: 80 / 80 / 80 / 80
```

So:

* **The app gate permits a ~1,630-line coverage regression** before it says
  anything. The project is at **M6.3** and the gate is **68**, *below its own
  table's "70% by M6"* — the ratchet stopped at the M4 close and nothing noticed.
* **The functions gate has 17.7 points of slack on lines** and 12.8 on branches.
* ⚠️ **§3's own row already recorded the gap** — *"68 … (measured 86.50%)"*. The
  eighteen-point distance was known, written down, and left. **This is not an
  oversight; it is a rule with no enforcement**, which is the only kind of rule
  this repo keeps finding broken.

## Decision 1 — The gate fails when it becomes DECORATIVE, not only when coverage drops

Raising `--min` fixes today and rots the same way by M7. The ratchet rule is
prose, and prose is what failed. So `coverage_gate.dart` gains a second bound:

```
dart tool/coverage_gate.dart --min <floor> --max-slack <points> <lcov>
```

* **below `--min`** → FAIL, exit 1, as today: *coverage regressed*.
* **above `--min + --max-slack`** → **FAIL, exit 1**: *the floor has drifted so
  far below the measurement that it can no longer catch a regression — raise it.*

**A guard that detects its own irrelevance.** It converts *"+2% per milestone,
never lowered"* from something a human must remember into something CI says out
loud, at the moment it stops being true rather than eight milestones later.

⚠️ **The failure message must name the new floor to write**, or the next session
will have the same argument with the same file. It prints the measurement, the
slack, and the value to set.

### D1.1 — the values, committed here rather than chosen at the keyboard

| | value | why |
|---|---|---|
| `--min` | **86** | 87.75 measured, so **1.75 points / 144 lines** of headroom. Tighter (87) leaves 62 lines and collides with ADR-042 D2's licence to ship a thin adapter untested — one 60-line adapter would eat it. Looser (85) doubles what a silent `domain/` regression can hide (D3.1) |
| `--max-slack` | **5** | fires once the measurement reaches **91**. Wide enough that ordinary movement does not trip it, narrow enough that it would have fired years before 19.75 points accumulated — which is the whole complaint |
| functions | **95** stmts / **90** branches / **95** funcs / **95** lines | branch coverage at **92.81** is the binding metric, not lines at 97.68. One number for all four is what produced a table nobody could act on |

⚠️ **And the slack bound is itself a claim that can rot**, which is worth saying
rather than pretending otherwise: a session that hits this failure can satisfy it
by widening `--max-slack` instead of raising `--min`. Nothing mechanical prevents
that. What the design buys is that the choice becomes **explicit and reviewed**
instead of silent — which is the whole distance between this gate and the one it
replaces.

## Decision 2 — Why a tight floor is safe HERE, and was not in ADR-055

ADR-055 D2 was revised the same day it shipped because a wall-clock bound could
not separate *slow* from *wedged*: runner speed alone moved the same suite
**1.82×**. Its conclusion — *"no wall-clock number is both tight enough to be
useful and loose enough to be safe"* — is the reason to check before reusing the
shape here.

**Coverage is not like that, and it was measured rather than assumed.** Two
consecutive `flutter test --coverage` runs on an unchanged tree:

| | run 1 | run 2 |
|---|---|---|
| lcov bytes | — | **differs** |
| lines found / hit | 8246 / 7236 | **8246 / 7236** |
| percentage | 87.75% | **87.75%** |

⚠️ **The raw file differs and the total does not.** Per-line *hit counts* vary
(`DA:9,3` vs `DA:9,4`) — the same line executed a different number of times — but
the *set* of covered lines is identical. So the aggregate is stable to the
hundredth of a point across runs, and a floor a couple of points under the
measurement is safe in a way a wall-clock bound never was.

**n = 2**, and that is stated rather than dressed up. It is two more samples than
the number 68 ever had.

## Decision 3 — The documented `domain/ ≥ 85%` gate is DECLINED, and the measurement is why

§3 documents a **hard fail below 85%** for `domain/`. **It has never been
implemented** — `ci.yml` runs one `coverage_gate.dart` over the whole lcov and
nothing per-directory. The obvious move is to build it. **That would be wrong.**

Measured today:

```
domain/ : 790/1254 = 63.00%
```

**Twenty-two points below a gate documented as a hard fail.** But the gap is not
where the wording implies:

| what the file is | missing | of | covered |
|---|---|---|---|
| exception / error taxonomies | **166** | 317 | 48% |
| value & state types | **93** | 208 | 55% |
| provider declarations | 24 | 32 | 25% |
| **everything else — the actual logic** | 181 | 697 | **74%** |

**283 of the 464 missing lines — 61% — are hand-written `operator ==`,
`hashCode` and `toString` on sealed-class variants.** `SoloAnswerException` is
the shape: a sealed taxonomy whose every variant carries three boilerplate
members.

⚠️ **An earlier draft said this was "because the codebase does not use a code
generator here". That is wrong and the correction matters.** The app *does* use
one — `riverpod_generator`, producing **53 committed `.g.dart` files**. What it
does not use is a generator for **value semantics**: no `freezed`, no
`equatable`, and **no ADR records that choice**.

**So the steelman deserves an answer rather than a dodge:** *the real finding
might be that this code should not be hand-written at all.* It might. Adopting
`freezed` or `equatable` for the domain types would delete most of those 283
lines and raise `domain/` mechanically, without a single padding test — a
strictly better outcome than either gating or not gating them.

**It is also a far larger change than this objective** — a new dependency, a
codegen step on files that have none today, and every domain type rewritten —
and it is a decision about the codebase's shape rather than about a threshold.
**Filed as an issue, not taken here**, and named so that D3 cannot be read as
*"boilerplate is inevitable"*. It is not; it is merely not this session's.

**So reaching 85% in `domain/` means writing tests that call `toString()` on
exception variants.** That is coverage padding — executing lines without
asserting anything — and it is precisely the failure mode this objective was most
likely to cause.

**The decision: correct the document, not the code.** §3's `domain/` row was
written without measuring what `domain/` contains. It is replaced with what is
true and checkable, and the reason is recorded so the next reader does not
"restore" the 85% as though it had been lost.

**The replacement row, drafted here so the diff cannot quietly say something
softer:**

> | `domain/` (all features) | logic ≥ 74%, *not gated* | **No gate.** 63% measured 2026-09-13 (790/1254). **61% of the gap is `==`/`hashCode`/`toString` on sealed variants** — an 85% gate would be met by padding, so ADR-079 D3 declines it. The **74%** logic bucket is the honest figure and is **unguarded**: see D3.1 for what that permits |

⚠️ **It states what is expected AND that nothing enforces it**, because a row
that only says *"no gate"* reads as a standard being lowered, and a row that only
states a target reads as a gate that exists. Neither was true before; both halves
have to be on the line.

⚠️ **What is NOT claimed:** that `domain/` is well covered. The logic bucket at
**74%** is the honest number, and it is lower than the repo-wide 87.75% — which
is the one real thing the global gate hides. That is filed rather than fixed
here; inventing a second threshold in the same session that argues against
unmeasured thresholds would be its own joke.

### D3.1 — what declining actually costs, as a number

A refusal that does not price itself is just a preference. **How much `domain/`
regression can hide inside a global floor?** Computed from the same lcov:

| global floor | lines that may go uncovered first | `domain/` could fall to |
|---|---|---|
| 85% | **227** | **45%** |
| 86% | 144 | 51% |
| 87% | 62 | 58% |

**So D3 is not free: at an 85% floor, `domain/` could lose 29% of its covered
lines with every gate green.** The tighter the global floor, the smaller that
budget — which is a second, independent reason to set `--min` high, and the
reason the two decisions cannot be taken separately.

⚠️ **And there is a collision with this repo's own licence that a tighter floor
creates.** ADR-042 D2 deliberately ships thin adapters *untested* — the
`FcmPushTokenSource` shape, ~60 lines of platform call with no branches. At a
floor with only 62 lines of headroom, **adding one such adapter fails CI**, and
the author's cheapest escape is to write a test that asserts nothing. That is the
padding this objective was most likely to cause, arriving through the front door.

The floor must therefore leave room for one or two deliberately-untested
adapters — which is what fixes the number below 87 rather than at it, and is
stated here so the choice is visible rather than inferred.

## Decision 4 — The functions gate gets the same treatment and the same honesty

`vitest.config.ts` enforces **80 / 80 / 80 / 80**; the suite measures
**97.43 / 92.81 / 97.78 / 97.68**. §3 also names an **85% target** that exists
nowhere in the config — a second unenforced number in the same table.

Vitest has no *"fail if the threshold is too low"* concept, so the same
self-checking cannot be expressed in its config. **The floors are raised to a
measured value and §3 is corrected to say what is enforced**, with the asymmetry
recorded: the Dart gate polices its own currency, the TS gate does not, and a
future session wanting parity would have to wrap `vitest` the way
`coverage_gate.dart` wraps lcov.

⚠️ **Branch coverage is the binding one at 92.81%**, not lines at 97.68 — so the
floors are not one number. Setting all four to the same value is what produced a
table nobody could act on.

## Decision 5 — The gate has no self-test, and it is one of only four tools here that do not

Found while planning the mutation check, and it is the tidiest illustration of
this ADR's own subject. Counted across every tool in the repo:

```
20 of 24 tools have a <name>_test.<ext> beside them.
The four that do not:  coverage_gate.dart · build_size_report.dart
                       rtl_lint.dart      · ci/appstore_screenshots.sh
```

**The guard this session is about is also one of the few nobody tested.** Its
0/0 path, its `--min` parsing, its exit taxonomy — all of it has only ever been
exercised by being run in CI against a real lcov that always passed.

So `tool/coverage_gate_test.dart` is written **before** `--max-slack` exists, and
the mutations are enumerated first (S102 and S103 each paid for learning this
twice in one session):

| mutation | must |
|---|---|
| coverage below `--min` | FAIL, exit 1 |
| coverage above `--min + --max-slack` | FAIL, exit 1, **naming the floor to write** |
| coverage inside the band | PASS, exit 0 |
| `LF:0` everywhere (0/0) | exit **64** — *could not measure* must never read as green |
| a missing / unreadable lcov path | exit 64 |
| `--max-slack` absent | the slack check is **off**, and the tool behaves exactly as today |
| `--min` above 100, or non-numeric | exit 64 |

⚠️ **And lesson 164's question — what would stop the gate running at all?** Three
answers, and each gets an assertion rather than a hope:

1. **The `ci.yml` step is deleted or renamed.** Nothing in the repo notices today.
   `coverage_gate_test.dart` asserts the workflow still invokes the tool **with
   both bounds**, parsed out of `ci.yml` rather than restated — the shape
   `integration_watchdog_test.sh` already uses for ADR-055's arithmetic.
2. **`--coverage` is dropped from the `flutter test` step**, leaving a stale
   `lcov.info` — or none. The 0/0 path covers *none*; for *stale* the honest
   answer is that nothing can tell from the file alone, and that is recorded as a
   limit rather than papered over.
3. **The threshold is "fixed" by widening `--max-slack`.** Unpreventable by
   construction (D1 says so); what the test can pin is that both numbers live in
   `ci.yml` where a diff shows them.

## Decision 6 — `session-context.md` §3 moves in the same diff

§3's **Gates** block reads *"Coverage: app **68**, functions **80 hard / 85
target**"*. It is read at the start of every session, and this ADR makes all four
of those numbers wrong.

⚠️ **The "85 target" for functions exists in no config at all** — a second
unenforced number in the same breath as the one this ADR is about. It is removed
rather than carried forward: a target nothing measures is how §3's `domain/` row
came to promise a gate that was never built.

## Consequences

**Positive**

- A gate that drifts twenty points below reality now fails **at the moment it
  drifts**, naming the value to set.
- The `domain/` row stops documenting a gate that does not exist and would force
  padding if it did.
- Both real coverage numbers are written down with the commands that produced
  them, for the first time since the M4 close.

**Negative / accepted trade-offs**

- **A tight floor will fail a legitimate refactor** that deletes covered code.
  Accepted: the failure is loud, the fix is one reviewed line, and the
  alternative is the twenty-point drift this ADR exists to end.
- **`--max-slack` can be satisfied by widening itself.** Stated in D1 rather than
  hidden; the design buys an explicit choice, not an impossible one.
- **The `domain/` logic bucket at 74% is left un-gated.** Named here so it is a
  known debt rather than a discovery.
- **n = 2 for the determinism claim** behind the tight floor.
