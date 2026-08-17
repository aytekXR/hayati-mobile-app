# ADR-055: a hang must FAIL loudly, not be CANCELLED quietly

- **Status:** Accepted
- **Date:** 2026-08-17 (Session 078)
- **Deciders:** session agent (no operator dependency; CI-only change, no runtime code)
- **Related:** **ADR-024 D2** (the Slack notifier's outcome policy — this ADR does *not* overturn it), **ADR-029 D6** / issue **#100** (why this job is main-only), issue **#208**, issue **#15** (the quarantined suite)

> Written and committed **before** the implementation, per `session-rules` §5.1.

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

⚠️ **This arithmetic is the design, so a self-test asserts it** — that the sum of
the configured bounds plus a setup allowance fits inside the job timeout. If it
ever stops fitting, the watchdog can no longer fire before the job dies and the
entire mechanism silently reverts to the behaviour it was built to fix: a
`cancelled` job and no notification. That is this repo's most familiar shape — a
guard that is present, green, and structurally unable to act — so it is pinned
rather than trusted.

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
