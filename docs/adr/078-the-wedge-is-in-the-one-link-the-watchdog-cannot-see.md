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
xcrun simctl spawn "$DEVICE_ID" log show --last <window> --style compact
```

and reports whether `Dart VM Service is listening on` appears at all. Three
outcomes, each pointing somewhere different:

| what the device log says | what it means | where the fault is |
|---|---|---|
| the URI line **is** there | the app started and announced itself; the reader shut down before seeing it | **the tool / the `log stream` pipe** — and a retry would have worked |
| **no** URI line, app process **present** | the app launched and never reached the engine's listen | **the app or the engine** — and this repo has a `SceneDelegate`, which the predicate above has two special cases for |
| **no** URI line, app process **absent** | it never launched, or it died | **launch / crash** — the crash report says which |

⚠️ **The second row is not a neutral possibility.** ADR-076 established that this
app has a `UIApplicationSceneManifest` and configures Firebase from pure-Dart
options — the same scene-lifecycle territory Flutter's own predicate carves out
two clauses for. That is a reason to capture, not a conclusion; **no claim is
made here that it is the cause.**

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
  property most likely to be broken by adding to this block.

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
