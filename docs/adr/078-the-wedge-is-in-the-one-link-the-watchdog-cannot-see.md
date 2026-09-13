# ADR-078: The wedge is in the one link the watchdog cannot see

- **Status:** Accepted. **An instrument, not a fix** — and `ci-debt #15` stays
  open, because this makes the next wedge attributable rather than making it stop.
- **Date:** 2026-09-13 (Session 103)
- **Deciders:** session agent. **No operator dependency. CI-only; no runtime code,
  no deploy, no release.**
- **Related:** **ADR-055** (the watchdog this extends — read it as a success),
  **ADR-074** (the same shape one layer in: a failure that could not speak),
  **ADR-024 D2** (why a `cancelled` job is silent and a `failure` is not),
  **ADR-029 D6** / issue **#100** (why the job is main-only), issues **#208**
  (the incident ADR-055 was built from, **closed**) and **#15** (open),
  lessons **65**, **78**, **160**

## Context — three hangs, three shrugs

`integration-emulator` has wedged **three times**: S065 (#208, 38 minutes of
silence), S088 (on a diff of docs and Python only), and S101's ADR-076 merge.
Each was correctly called *"the known flake"*, and each time that was true and
useless. The cost is no longer hypothetical: S101's red stood **unexamined on
`main` for six days**, because the three runs after it were docs-only and
**skipped** the job rather than re-running it (lesson **160**).

ADR-055 did its job and this ADR should not be read as a complaint about it. The
job **FAILED with the suite named** instead of being **CANCELLED** silently, and
that difference is the reason anyone knew at all.

### What the watchdog printed, and why it was not enough

S102 read the failing job log of run **34042187123** in full. At the moment the
watchdog fired, its own diagnostic block said:

| what it measured | verdict |
|---|---|
| the simulator | `hayati-ci (…) (Booted)` — **alive** |
| ports 8080 / 9099 / 5001 | **all three ANSWERING** |

**Both healthy.** And immediately after, from the tool rather than the watchdog:

```
No tests ran.
Error waiting for a debug connection: The log reader failed unexpectedly
```

So the watchdog measured the two things that were fine and could say nothing
about the one that was not. It diagnoses the **environment**; the wedge is in the
**app-to-tool link**.

### What that sentence means, read from the vendor rather than guessed

`flutter_tools`, `ios/simulators.dart`, `IOSSimulator.startApp` — the exact
source of that string:

```dart
// Wait for the service protocol port here. This will complete once the
// device has printed "Dart VM Service is listening on..."
final Uri? deviceUri = await vmServiceDiscovery?.uri;
if (deviceUri != null) { return LaunchResult.succeeded(vmServiceUri: deviceUri); }
globals.printError(
  'Error waiting for a debug connection: The log reader failed unexpectedly',
);
```

It is the **null** branch, not the exception branch. `ProtocolDiscovery.uri`
documents that null precisely: *"Returns null if the log reader shuts down before
any uri is found."*

And the log reader is this, verbatim from `launchDeviceUnifiedLogging`:

```
xcrun simctl spawn <device-id> log stream --style json --predicate '<NSPredicate>'
```

whose predicate requires `eventType = logEvent`, the process image, and one of
`senderImagePath ENDSWITH "/Flutter"`, `…/libswiftCore.dylib`,
`processImageUUID == senderImageUUID`, or two specific **`UIScene` lifecycle**
messages.

**So the failure means exactly one thing: that stream ended without ever yielding
a line containing a VM Service URI.** Nothing in the job records whether the line
was ever *emitted*.

## Decision 1 — Capture the one fact that splits the failure in two

⚠️ **This is ADR-074's argument one layer out.** There, *"APNs said no"* and
*"APNs said nothing"* were arriving as the same silence, with opposite remedies,
because nobody implemented the callback that distinguishes them. Here,
*"the app never printed the URI"* and *"the app printed it and the reader missed
it"* arrive as the same `No tests ran`, and they also have opposite remedies.

On timeout, the watchdog asks the device log directly — **historically**
(`log show`), not by opening a second stream, so it cannot perturb the thing it
is measuring:

```sh
xcrun simctl spawn "$DEVICE_ID" log show --last "${window}s" --style compact
```

and reports whether `Dart VM Service is listening on` appears at all. Three
outcomes, each pointing somewhere different:

| what the device log says | what it means | where the fault is |
|---|---|---|
| the URI line **is** there, app process **present** | the app started and announced itself; the reader shut down before seeing it | **the tool / the `log stream` pipe** — and a retry would have worked |
| the URI line **is** there, app process **absent** | it announced itself and then died | **the app** — after listen, so the crash report is the diagnosis, not the log |
| **no** URI line, app process **present** | the app launched and never reached the engine's listen | **the app or the engine** — and this repo has a `SceneDelegate`, which the predicate above has two special cases for |
| **no** URI line, app process **absent** | it never launched, or it died before listening | **launch / crash** — the crash report says which |

⚠️ **It was three rows until the design review, and the missing one was
`URI present, process absent`** — an app that announces itself and *then* dies.
Three rows would have filed that under *"the reader missed it"* and sent the next
session hunting a tooling bug with a crash report sitting unread on disk.

⚠️ **The second row is not a neutral possibility.** ADR-076 established that this
app has a `UIApplicationSceneManifest` and configures Firebase from pure-Dart
options — the same scene-lifecycle territory Flutter's own predicate carves out
two clauses for. That is a reason to capture, not a conclusion; **no claim is
made here that it is the cause.**

### ⚠️ D1.1 — the window is DERIVED, and the first draft of this ADR got it wrong

The first version of this decision said `--last 5m`. **Measured against the
incident it was written for, 5 minutes misses everything that matters.** From run
34042187123's own timestamps:

```
15:40:15  00:00 +0: loading integration_test/auth_emulator_test.dart
15:47:06  Xcode build done.  229.5s          <- launch/attach begins here
15:57:06  ##[error] ... SILENT for 600s      <- the watchdog fires
```

The gap from **build-done to fire is exactly 600s** — necessarily, because the
silence bound starts counting at the last line of output, and the last line of
output *is* the launch. So at the moment of capture the interesting window is
**already `WATCHDOG_SILENCE_SECONDS` old**, and `--last 5m` reaches back only to
15:52:06. It would have captured ten minutes of nothing and reported *"no URI
line"* — which is the same answer it would give if the app had genuinely never
printed one.

⚠️ **That is lesson 150 exactly: a verdict compatible with two very different
worlds, where everyone would have assumed the wrong one.** An instrument built to
split one failure into three would have collapsed two of them back together, and
nothing in its output would have shown it.

So the window is **computed, not chosen**: the watchdog already tracks the
suite's elapsed seconds, and the capture covers **the whole suite plus a margin**
— which subsumes both the launch and the silent period regardless of how the
bounds are later tuned. And the window it actually used is **printed beside the
result**, so *"no URI line in the last N seconds"* can never be read as *"no URI
line"*.

### ⚠️ D1.2 — every row above assumes the query WORKED, so the query reports its own control

`log show` reads a ring buffer. **Nothing here has established that a
seventeen-minute-old line survives in it**, and this box has no `xcrun` to find
out. If it does not, *"no URI line"* is returned for a third reason — the line
aged out — and the instrument collapses the very worlds D1 exists to separate,
one layer down from the mistake D1.1 already caught. **The same failure twice in
one decision is a pattern, not an accident.**

So the capture never reports a bare verdict. It reports, beside it:

* **the window it used**, in seconds (D1.1);
* **the total number of lines** the query returned for that window;
* **the number of lines from the app's own process image**
  (`com.beyondkaira.hayati`).

**Zero total lines on a booted simulator that just completed an Xcode build and a
launch is not an answer — it is a broken measurement**, and it now looks like
one. That is the repo's own exit taxonomy applied to a log query: *could not
measure* must never be able to read as *measured, and the answer is no*
(ADR-041, ADR-047 D4).

⚠️ **A control marker was the design review's suggestion and is deliberately NOT
taken.** Writing a known string into the simulator's log at suite start would be
a cleaner control — but it needs a mechanism this box cannot verify, it adds a
step that can itself fail silently, and its absence would then be ambiguous in
exactly the way it was meant to remove. **The line counts are a control that
needs no new mechanism and cannot fail to exist**, which is the weaker instrument
and the honest one. If a future session verifies a marker on a real runner, this
is the decision to revisit.

## Decision 2 — What else is captured, and the discipline it inherits

The existing block's rule is stated in its own comment — *"best-effort and never
fatal: absent tools must not turn a useful timeout report into a second
failure"* — and every addition keeps it:

* **the app process**, `xcrun simctl spawn "$DEVICE_ID" launchctl list`, filtered
  to the bundle id — the discriminator for rows two and three above;
* **crash reports**, the newest entries under `~/Library/Logs/DiagnosticReports/`
  matching the app, listed and the newest one excerpted;
* **the device log itself**, written whole to a file rather than only grepped,
  because the grep encodes today's hypothesis and the file survives it.

⚠️ **`DEVICE_ID` is the load-bearing input and it is already exported.** The job
writes it to `GITHUB_ENV` in *Boot iOS simulator*, so the watchdog inherits it
through the step environment. If it is ever absent the block says so and skips —
it must never guess a device, because `simctl list devices booted` can return
more than one and the wrong log is worse than no log.

### ⚠️ D2.1 — the capture is BOUNDED, because an unbounded one would destroy the guarantee it rides on

**The blocking finding of the design review, and it is the kind that turns an
instrument into the failure it was built to report.**

Every command added here runs **after the silence bound has fired and before the
process-group kill**, i.e. on a runner that has already demonstrated something is
wedged. `xcrun simctl spawn … log show` talks to that same wedged simulator. **If
it hangs, the watchdog never reaches `exit 124`** — the job runs to
`timeout-minutes`, GitHub reports **`cancelled`**, and `slack_notify.sh` sends
nothing by design (ADR-024 D2). That is *precisely* the outcome ADR-055 was built
to eliminate, reintroduced by the instrument meant to explain it.

⚠️ **And `|| true` does not help.** It swallows a non-zero status; it does not
bound a hang. The existing block's `{ … } >&2 || true` is protection against the
wrong failure mode.

⚠️ **macOS ships no coreutils `timeout`** — ADR-055's own header says so, which is
why the watchdog implements its bound in portable bash rather than depending on
`brew install coreutils` inside a CI job. So the fix reuses the machinery already
in this file: each diagnostic command runs as a **backgrounded child in its own
process group**, polled, and **killed if it exceeds a small fixed bound**. The
script already does exactly this for the suite itself (`set -m`, `$!`,
`kill -TERM -"$pid"`), so this is the same pattern at a smaller scale, not a new
mechanism.

**The bound is asserted, not assumed.** The self-test's most important new case
is a stub `xcrun` that **hangs forever**: the watchdog must still exit **124**,
still name the suite, and still do so inside the harness's own timeout. That
single case is what keeps this ADR from being a regression.

### ⚠️ D2.2 — the hazard was already there, and had been since ADR-055

**Writing that test found the defect in code this ADR did not touch.** With a
stubbed `xcrun` that sleeps forever, the script hung — and it hung **before
reaching any of ADR-078's additions**, at

```
--- simulator state ---
```

which is `xcrun simctl list devices booted`, unbounded, in the block ADR-055
shipped. It talks to the same simulator the suite has just been declared wedged
against.

**So the guard built to stop a hang being silent could itself be silenced by a
hang, in the exact situation it exists for.** A `simctl` that never returns means
`exit 124` is never reached, the job runs to `timeout-minutes`, GitHub calls it
**`cancelled`**, and `slack_notify.sh` sends nothing — ADR-055's own failure mode,
sitting inside ADR-055's own remedy.

⚠️ **The design review framed this as a risk ADR-078 would introduce.** It is
older than that: this ADR only raises the odds by adding more `xcrun` calls. The
distinction matters, because *"do not add the capture"* would have left the
hazard in place and looked like caution.

⚠️ **And `|| true` is what made it invisible.** The block has always ended
`} >&2 || true`, which reads like protection and is protection against the wrong
thing — it swallows a **status**, never a **hang**.

Every call in that block is now bounded, `nc` included (`-w 2` as the cheap
guard, `run_bounded` as the one that cannot be argued with). Measured after the
fix: the same hanging stub now yields **exit 124 in 19s**.

**This is the second time in two sessions that a guard was found green over the
thing it exists to catch** — ADR-077 D5's channel sentinel, and now this. The
common shape is worth naming: *a guard's own failure mode is the one nobody
tests, because testing it means making the guard fail.*

## Decision 3 — The capture is PROVEN by stubbing the vendor tool, not by waiting for a wedge

Two facts make the obvious proof impossible: **this box has no `xcrun`**, and a
wedge cannot be reproduced on demand — three occurrences across roughly eighty
runs.

`integration_watchdog_test.sh` is already hermetic (bash + `python3`, runs in the
ubuntu `quality` job, every "suite" is a `sleep` or an `echo`). So the capture is
proven the same way: a **stub `xcrun` placed first on `PATH`** that records its
arguments and prints a scripted device log. The self-test then asserts

* that the timeout path **invokes** `log show` against the exact `DEVICE_ID` it
  was given — not a discovered one;
* that a log **containing** the URI line is reported as the first row above;
* that a log **without** it is reported as one of the other two, chosen by
  whether the process appears;
* that with **no `xcrun` on PATH at all**, the watchdog still exits **124** and
  still names the suite — the ADR-055 guarantee is unchanged, which is the
  property most likely to be broken by adding to this block;
* ⚠️ **that with an `xcrun` stub that HANGS FOREVER, the watchdog still exits
  124, still names the suite, and still finishes inside the harness's own
  timeout** — D2.1's case, and the one that decides whether this ADR is an
  instrument or a regression;
* that the **line counts and the window** are printed beside every verdict
  (D1.1, D1.2), so a broken query cannot be read as a negative result.

**The artifact path is named rather than left to the implementation.** The
watchdog runs from `app/` inside `emulators:exec`, so a bare relative path would
land somewhere nobody collects. It writes to
**`"${GITHUB_WORKSPACE:-$PWD}/watchdog-device-log.txt"`**, and the job gains an
`actions/upload-artifact` step with `if: failure()` pointed at it.

**And the plumbing is proven on the real runner too, not only in the stub.**
`integration-emulator` is main-only, so the branch is dispatched —
`gh workflow run ci.yml --ref <branch>` — and the run must come back **green**,
demonstrating that the addition does not break a healthy job. ⚠️ **A green
dispatch does not exercise the capture**, because a healthy run never times out;
it proves absence of regression and nothing more, and the difference is stated
here so a later reader does not mistake one for the other.

⚠️ **And the mutations are enumerated before the guard is written** (S102's
lesson, twice over): deleting the `log show` call, pointing it at a discovered
device instead of `$DEVICE_ID`, swallowing its output, and letting a missing
`xcrun` escape as a non-124 exit must each turn the self-test red.

**What this does NOT prove**, said plainly: that the capture produces anything
useful against a *real* wedge. A stub proves the plumbing, not the diagnosis. The
first real test is the next hang, and there is no way to schedule one.

## Decision 4 — The dependency cannot be removed, and the reason is structural rather than a missing flag

The tempting fix is ADR-076's: *stop depending on a mechanism nobody here chose.*
Pin the VM-service port, and nothing has to be scraped. **It does not work, and
the evidence is from the vendor, not from a `--help` listing.**

The weak version first, measured on Flutter 3.44.5:

| flag | `flutter run` | `flutter test` |
|---|---|---|
| `--device-vmservice-port` | yes | **no** |
| `--host-vmservice-port` | yes | **no** |
| `--dds-port` | yes | yes |

But the flag's absence is not the reason, and stopping there would have been the
shallow answer. `ProtocolDiscovery` — the class every device type uses —
**always** subscribes to the log:

```dart
_deviceLogSubscription = logReader.logLines.listen(_handleLine, onDone: _stopScrapingLogs);
```

and `devicePort` is only ever a **filter on an already-scraped URI**:

```dart
if (devicePort != null && uri.port != devicePort) {
  _logger.printTrace('skipping potential VM Service $uri due to device port mismatch');
  return;
}
```

**So a fixed port would narrow which scraped URI is accepted; it would not
provide a second way to find one.** Log-scraping is how `flutter test` attaches
to a simulator, full stop. Removing the dependency means leaving `flutter test`
— a far larger change than this failure justifies today, and one that would
trade a rare flake for a rewrite of how every integration suite runs.

**Recorded, not attempted.** If a future Flutter adds a non-log discovery path
for `flutter test`, this decision is the thing to revisit, and D4 exists so that
revisit starts from evidence rather than from the `--help` output.

## Decision 5 — `ci-debt #15` stays open

This ADR ships an instrument. It does not diagnose the wedge, and *"the flake is
handled"* would be the false summary that gets remembered (lesson **78**). #15 is
updated with what is now known — the vendor mechanism, the three-way split, and
what the next occurrence will produce — and stays open until an occurrence is
actually attributed.

## Consequences

**Positive**

- The next wedge produces evidence instead of a shrug, and the evidence
  distinguishes three faults with three different owners.
- The question *"can the log reader be taken out of the path?"* is answered from
  vendor source and written down, so no future session re-derives it from
  `--help` and reaches a shallower answer.
- The watchdog's existing guarantee is pinned by a new test rather than assumed
  to survive the addition.

**Negative / accepted trade-offs**

- **A stub proves plumbing, not diagnosis.** D3 says so rather than implying
  otherwise.
- **The window is bounded by the suite, so the capture grows with it.** A long
  first suite means a longer `log show`. Accepted: the alternative is a fixed
  window that silently stops covering the launch, which D1.1 is about.
- **`log show` on a wedged runner costs time** inside a job that has already
  spent its silence budget. It runs after the bound has fired and before the
  process-group kill, so it delays the failure by seconds, not minutes — and the
  wall-clock backstops are deliberately loose (ADR-055 D2 revised), so this
  cannot push a healthy run into a timeout.
- **The grep encodes today's hypothesis.** Mitigated by keeping the whole log as
  a file, not only the matched lines.
- **This adds simulator-specific knowledge to a generic wrapper.** The watchdog
  is used by exactly one job; the alternative — a second script — would split the
  timeout path across two files and is worse. Gated on `DEVICE_ID` being set, so
  a future non-iOS caller silently skips it.
