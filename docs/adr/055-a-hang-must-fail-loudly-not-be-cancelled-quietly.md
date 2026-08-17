# ADR-055: a hang must FAIL loudly, not be CANCELLED quietly

- **Status:** Accepted
- **Date:** 2026-08-17 (Session 078)
- **Deciders:** session agent (no operator dependency; CI-only change, no runtime code)
- **Related:** **ADR-024 D2** (the Slack notifier's outcome policy — this ADR does *not* overturn it), **ADR-029 D6** / issue **#100** (why this job is main-only), issue **#208**, issue **#15** (the quarantined suite)

> Written and committed **before** the implementation, per `session-context.md` §5.1.

## Context — the failure, and the compensation that was pointing the wrong way

`integration-emulator` was killed at exactly `timeout-minutes: 50` after emitting
**nothing at all for 38 minutes**, parked at `00:00 +0` immediately following a
clean 49-second Xcode build. GitHub reported the conclusion as **`cancelled`**.

This is blow-out **two**. S024's was a different animal — uniform slowness, suites
still printing progress, a slow runner hitting `40` exactly — and the fix then was
`40 → 50`. **Raising 50 → 60 converts a 50-minute hang into a 60-minute hang.**

### The finding that reframes the whole issue

The job's own comment names its compensating control and asserts it works:

> *"the compensation for its post-merge-only verdict already exists and works:
> ADR-024's Slack notifier reports the run nobody is watching"*

It does not work for this failure. `tool/ci/slack_notify.sh` derives an outcome
from the `needs` results and then:

```sh
if [ "$outcome" = "cancelled" ]; then
  info "run was cancelled (superseded or aborted) — not an event, no notification (D2)."
  exit 0
fi
```

**A timed-out job is reported by GitHub as `cancelled`.** So the single control
that exists to surface a post-merge red on a main-only job is *silent by design*
for precisely the outcome a timeout produces. The 38-minute hang was invisible
twice over: no progress in the log, and no notification afterwards.

**ADR-024 D2 is not wrong.** A superseded run genuinely is not an event, and a new
push cancelling an in-flight run is the common case by a wide margin. The defect
is that **GitHub spends one word — `cancelled` — on two unrelated things**, and
the notifier cannot tell them apart from the `needs` results alone.

### Measured, not assumed — the healthy run (`32062696199`, S076 post-merge)

| suite | wall clock | Xcode build |
|---|---|---|
| `auth_emulator_test.dart` | **8m33s** | 262.9s (cold) |
| `daily_question_emulator_test.dart` | 3m08s | 73.9s |
| `pairing_emulator_test.dart` | 2m40s | 84.5s |
| `profile_emulator_test.dart` | 2m10s | 67.2s |
| `startup_timing_emulator_test.dart` | 2m02s | 68.7s |

```
job total          22.7 min
  setup             3.9 min   (checkout, flutter, java, node, npm ci, build, sim boot)
  suites           18.6 min
    of which Xcode builds 9.3 min  — 50% of suite time
```

**Three claims in the job's own comments are false, and each mattered here:**

1. *"four suites… ~4 Xcode debug builds"* — there are **five** (`startup_timing`
   is not in the list). Six files; `phone_auth` is quarantined (#15).
2. *"the 30-min job timeout is the real bound"* (justifying `--timeout none`) —
   the job timeout is **50**, and has been since S024 changed it without
   updating the sentence that depends on it.
3. *"`-r expanded` streams progress so a wedge shows"* — refuted by the incident.
   38 minutes of silence is what `-r expanded` produced. It streams progress
   *between tests*; it says nothing while the app is failing to launch.

## Decision 1 — The watchdog's real job is to convert `cancelled` into `failure`

Not "to catch a hang sooner". A per-suite wall-clock bound that fires **strictly
before** `timeout-minutes` means the job ends in **`failure`**, with a named
suite — and `slack_notify.sh` then reports it through the path that already
works, with **no change to ADR-024 D2's supersede policy**.

That is the whole leverage: the notifier's silence is correct for `cancelled`, so
the fix is to stop producing `cancelled` for a case that is not a supersede,
rather than to teach the notifier a distinction the `needs` results cannot carry.

## Decision 2 — The bounds are derived from the measurement, and their SUM is asserted

A single per-suite bound cannot work: the first suite carries the cold Xcode build
(262.9s vs 67–85s) and legitimately takes 4× the others. So:

| | bound | measured worst | headroom |
|---|---|---|---|
| first suite | **16 min** | 8m33s | 1.9× |
| each later suite | **6 min** | 3m08s | 1.9× |

**Worst case `16 + 4×6 = 40` min, plus 3.9 min measured setup = 43.9 min, inside
`timeout-minutes: 50` with ~6 min of slack.** The ceiling is **not** raised.

### Validated on a real runner — and the first sizing was WRONG

`integration-emulator` never runs on a PR, so a change to it is proven by
`gh workflow run ci.yml --ref …` or not at all. Three runs, and **the spread is
the finding**:

| run | `auth` | others |
|---|---|---|
| `32062696199` (healthy, pre-watchdog) | 513s | 122–188s |
| `32067814813` (dispatch) | 540s | 90–113s |
| `32071907287` (dispatch, after the review fixes) | **640s** | **189–203s** |

The first bound — 960s — was sized against the 540s run and looked comfortable
at 1.78×. **Against the worst observed run it fails the check that matters:**
640 × 1.55 = **992s > 960s**, so a runner as slow as S024's would have been
reported as *wedged* while working correctly. The bound is now **1080s** (and
the later suites' 360s holds: 203 × 1.55 = 315s).

**This is the ADR's own trap, sprung on the ADR.** The +55% column was added
precisely because a bound that only fits a healthy runner converts S024's failure
mode into a false positive — and then the number was sized against a single
favourable run anyway. It was caught only by re-measuring the third dispatch
instead of reusing the figure already written down. *Worst observed, not median,
and re-derive it every time a new run exists.*

Worst case is now 18 + 4×6 = 42 min + 4 setup = **46 min**, inside the unchanged
50-minute ceiling with 4 minutes of slack.

⚠️ **This arithmetic is the design, so a self-test asserts it** — that the sum of
the configured bounds plus a setup allowance fits inside the job timeout. If it
ever stops fitting, the watchdog can no longer fire before the job dies and the
entire mechanism silently reverts to the behaviour it was built to fix: a
`cancelled` job and no notification. That is this repo's most familiar shape — a
guard that is present, green, and structurally unable to act — so it is pinned
rather than trusted.

## Decision 2 REVISED (same day) — bound the SILENCE, not the wall clock

**The first post-merge run falsified D2 within an hour of merging it.** `auth`
took **936s** against the freshly-raised 1080s bound — 1.15× headroom. Four
observations now exist and they span **1.82×**:

```
auth: 513s (healthy) · 540s (dispatch) · 640s (dispatch) · 936s (post-merge main)
```

The runner-to-runner spread is **wider than the ±55% factor** the bounds were
being stress-tested against, so no wall-clock number is both tight enough to be
useful and loose enough to be safe. Raising it again does not converge — which is
the very criticism #208 makes of raising `timeout-minutes`, arriving one level
down. **The instrument was wrong, not the number.**

**Silence separates the two failure modes; duration does not.** Measured from the
logs:

| | longest gap between log lines |
|---|---|
| healthy run (cold Xcode build is the worst case) | **299s** |
| the #208 incident | **2280s** |

That is a **7.6× separation**, against 1.82× for total duration — and it is
*structurally* stable, because a slow runner still prints while a wedged one does
not. This is the distinction the heartbeat was already reporting
(`silent for …s`) and the decision was not using.

So the bound becomes **time since the child last produced output**, set at
**600s** (2.0× the worst healthy silence, catching the incident in 10 minutes
rather than 50). The wall-clock bound stays as a **generous backstop** — it is no
longer the thing that discriminates, so it can be loose without being useless.

*This is the same error as the one two paragraphs above, made again in the same
session: sizing a threshold from a quantity whose spread I had not measured.
Recorded rather than quietly re-tuned, because the second occurrence is the
evidence that the fix was the wrong shape rather than the wrong value.*

## Decision 3 — Log during the silence, and name the phase

The incident produced **nothing to debug from**: no evidence whether the app
booted, whether it reached the emulators, or where it stopped. So the wrapper
emits a **heartbeat** carrying elapsed time and, critically, **how long since the
suite last produced any output** — the quantity that distinguishes "slow" from
"wedged", which is exactly the distinction S024 and this incident differ on and
which no reader could make from the logs.

On expiry it prints a diagnosis rather than a timeout: which suite, how long, the
last line of output seen, and a snapshot of the two things that can wedge — the
simulator's state and whether the emulator ports answer.

## Decision 3b — A precondition, because the SAME class of failure arrived mid-session

While this ADR was being implemented, S077's post-merge run went red — and the
red said nothing true. The functions emulator printed *"Failed to load function
definition from source … Cannot determine backend specification. Timeout after
10000"*, loaded **zero** functions, and `emulators:exec` ran every suite against
it anyway. Fifteen minutes later `daily_question_emulator_test.dart` failed on
*"answer → mutual reveal round trip"*, because the `answerReveal` **trigger** had
never loaded. The test named itself; nothing named the emulator.

That is this ADR's thesis in a second costume: the job failed for a real reason
and reported a different one. So `tool/ci/assert_emulator_functions.sh` probes a
known **callable** before any suite runs and fails immediately with the cause.

**Its codes are measured, not assumed** — against a live emulator, a loaded
callable answers a bare GET with `400`, an unknown name with `404`, **and a
Firestore trigger also answers `404`**, because triggers are not HTTP-addressable
at all. Probing a trigger would therefore fail against a perfectly healthy
emulator, and `answerReveal` — the very function whose absence caused the
incident — is the first one someone would reach for. The constraint is written at
the top of the script for that reason.

## Decision 4 — The build strategy is NOT changed here, and the number is recorded

Rebuilding per suite costs **9.3 min of the 18.6**, so #208's fourth checkbox is
real and is the largest single lever. It is deliberately out of scope:

* The serial-per-suite shape exists for a **measured** reason the step comment
  records — passing the directory let `flutter_tools` run suites concurrently
  against one simulator, where they fought over the shared `com.hayati.app`
  bundle and a whole suite reported *"did not complete"*.
* Changing how the binary is built or shared is a change to **what the job
  proves**, made in the same slice that changes how it fails. If it regressed,
  the two would be indistinguishable.

Recorded here so the next session picks it up with the number in hand rather than
re-deriving it.

## What the design review found — two defects in the watchdog itself

Both were in the mechanism, not the design, and both are the shape this repo
names failure **5**: a guard strict in one direction and silent in another.

**1. A passing suite could be reported as wedged (blocker).** `kill -0` was
tested at the top of the loop, which then slept a second — so a child that
finished *during* that sleep, at an elapsed time that also crossed the bound,
fell into the timeout branch. Measured: a command running 1.9s under a 2s bound
and exiting **42** returned **124**, three times out of three. A watchdog that
calls a passing suite wedged reddens `main` for no reason and teaches everyone
to distrust it — strictly worse than not having one. Fixed by re-checking the
child before declaring a timeout, and pinned by a test that asserts **both**
halves at the same bound: a near-boundary completion keeps its own status, and a
genuine hang at that same bound is still 124. Asserting only the first would
have been satisfied by simply disabling the timeout.

**2. `WATCHDOG_HEARTBEAT_SECONDS=0` span forever (major).** The timeout argument
was validated; the heartbeat interval, read from the environment, was not. The
next-beat loop advances by that value, so `0` never passes `elapsed`. The
resulting job hangs until `timeout-minutes` **cancels** it — *the exact outcome
this ADR exists to prevent, produced by the tool meant to prevent it.* Now
validated identically to the timeout, with `0`, `abc` and `-5` rejected. An
**empty** value is deliberately not an error and is asserted separately: `${VAR:-30}`
treats empty as unset, so `WATCHDOG_HEARTBEAT_SECONDS=` means "use the default",
which is the opposite of a `0` the caller actively chose.

Worth recording because neither was reachable by reading the script, and neither
would have been caught by the suite as first written — the first draft's wedge
test used a bound far below the child's runtime, so it never approached the
boundary at all.

## Consequences

**What this buys.** A hang costs at most ~16 min instead of 50, ends as
`failure` rather than `cancelled`, names the suite, and reaches Slack.

**What it costs.** A wrapper script between CI and `flutter test` — one more
place a CI failure can originate. Mitigated by self-tests to the repo's usual
convention, and by the wrapper being transparent on the success path.

**⚠️ What no test here can prove.** That the watchdog fires correctly against
*the real hang*, because the hang is not reproducible on demand — it appeared
once in a job that passed on re-run of the same commit. The self-tests drive the
wrapper against a **synthetic** hang (a process that sleeps and prints nothing),
which proves the mechanism, not the diagnosis of this specific wedge. Stated
plainly because "the watchdog works" and "we understand the 38-minute silence"
are different claims, and only the first is being made.

**What is explicitly NOT fixed.** The root cause. This ADR makes the failure
loud, bounded, and diagnosable; it does not explain why the app never reached the
emulators. The heartbeat exists so the *next* occurrence produces the evidence
this one did not.
