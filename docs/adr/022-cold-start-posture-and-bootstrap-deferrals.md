# ADR-022: Cold-start posture — instrument honestly, pin the pre-frame await set, defer the tz parse past first frame (App Check stays — rev 2), and refuse the fake <2s pass

- **Status:** Accepted
- **Date:** 2026-07-13 (Session 022, M6.3)
- **Deciders:** session agent, per resume-prompt M6.3
- **Related:** `docs/prd.md` §8/§10 (the budget and its device class), ADR-018 D2 (the boot snapshot is synchronous BY DESIGN), ADR-013/014 (RC identity-sync semantics that forbid one "obvious" deferral), operator-expected item 4 (real-device measurement)

## Context

The PRD's only cold-start number is **"cold start <2s mid-range Android (TR device reality)"**, and PRD §10 explicitly scopes its verification to M6.5 ("the mid-range Android cold-start target in §8 — are verified in the Android enablement follow-on (M6.5), not this MVP"). The iOS MVP has **no numeric cold-start gate** — the resume-prompt asks for the iOS-first *posture*: instrument, measure what CI can honestly measure, apply real wins, and put the real-device number where it belongs (operator item 4's on-device checklist). The stopping condition is explicit: "simulator-only measurement can be noise … record the honest bound … rather than faking a pass."

What CI can and cannot prove:

- A debug-mode simulator launch on a shared macOS runner measures JIT + emulator contention, not user experience. A <2s assertion there would be theater in both directions (flaky red on runner noise, meaningless green vs. a real mid-range device).
- What CI CAN prove deterministically: **the composition of the pre-first-frame critical path** (which awaits run before `runApp`), **per-stage wall-clock as diagnostics**, and **build size** (a stable, exact number).

The bootstrap audit (scout record, per-step cost table) found the pre-frame path in `main_prod.dart`/`main_dev.dart` is seven sequential steps; four carry explicit must-precede-frame reasons, three do not:

| Step | Must precede first frame? | Why |
|---|---|---|
| `WidgetsFlutterBinding.ensureInitialized` | yes | framework |
| `initializeFirebase` | yes | first frame watches the auth stream |
| `activateAppCheck` | **yes (rev 2)** | rev 1 claimed "only needed before the first attested backend call, which requires user interaction" — **FALSE, review finding PERF-1**: on a warm signed-in boot `AuthController.build()` seeds `AuthSignedIn` synchronously, `OnboardingGate` opens the `profileStreamProvider` Firestore listen at first-frame BUILD (before any post-frame callback), so every warm boot fires an attested read with zero interaction. Deferring App Check is the exact warm-boot landmine class Decision 3 refuses for RevenueCat. It stays pre-frame; the win is recovered by overlapping it with Crashlytics (Decision 1) |
| `initializeCrashlytics` | yes (kept) | the reporter object feeds `installErrorHooks` and the lock-snapshot read; the flag write is one cheap channel call, and NOT awaiting it opens a first-launch window where a dev-flavor crash could upload before the dev-OFF flag lands — a privacy fail-direction for milliseconds of win. Kept awaited. |
| `RcPurchasesRepository.configureIfKeyed` | **no, but kept** (Decision 3) | currently a synchronous no-op (no key); moving it would plant a warm-boot identity-sync landmine for the first live-key session |
| `ensureCoupleTimeZonesInitialized` | **no** | pure-Dart parse of the 10-year tz database; `coupleDayKey` already lazily self-guards (its own comment admits "this just front-loads the parse"); the first frame is `SignInScreen`, which never needs it |
| `SharedPreferences.getInstance` + `readInitialLockSnapshot` | yes, both | the disclaimer gate reads its ack synchronously at frame one (ADR-017 D4); the lock gate must decide frame one — an async check would flash couple content and the OS would snapshot the flash (ADR-018 D2). **The lock read is a security mechanism, not an optimization target.** |

## Decision 1 (rev 2) — One deferral to a post-first-frame callback; two parallelizations; everything else stays

`main_dev.dart`/`main_prod.dart` (edited in lockstep, as always):

- **Only `ensureCoupleTimeZonesInitialized` moves to an `addPostFrameCallback`** registered after `runHayati` — deterministic "after first frame", not an event-queue race against the first vsync. The tz parse keeps its lazy in-function guard as the correctness backstop; the post-frame call remains purely a warm-up. (Rev 1 also deferred `activateAppCheck`; deleted per review finding PERF-1 — see the table above. The over-claim is deleted rather than the mechanism faked, per the S020 rule.)
- **`activateAppCheck` and `initializeCrashlytics` overlap via `Future.wait`** — both depend only on the initialized default Firebase app and not on each other; App Check activation still completes before `runApp`, so the activate-before-any-attested-call ordering holds for cold AND warm boots, enforcement on or off.
- **`SharedPreferences.getInstance()` and `readInitialLockSnapshot(...)` overlap via `Future.wait`** — two independent platform-channel round-trips that both must complete before frame one; overlapping them shortens the critical path without changing what frame one knows. The lock read keeps its degraded-snapshot semantics untouched (the `Future.wait` wraps the same two futures; failure handling stays inside `readInitialLockSnapshot`; it needs the reporter from the first `Future.wait`, which is why the two pairs stay sequential to each other).
- Net critical path becomes: binding → Firebase → (App Check ∥ Crashlytics) → `configureIfKeyed` → (prefs ∥ lock snapshot) → `runApp`. Two channel round-trips overlap away and a CPU parse leaves the path; zero security or product semantics change.

## Decision 2 — The pre-frame await set is PINNED by a source-sentinel test; the trace is diagnostics, the sentinel is the gate

The durable form of the deferred-init audit is not a flaky timer but a **source sentinel** (the S020 pattern): a test that reads `main_dev.dart` + `main_prod.dart` as source and asserts (a) the exact allowed set of `await`s before `runHayati` — **rev 2 (review finding PERF-2, blocking: rev 1's set omitted `configureIfKeyed`, contradicting Decision 3 and turning the gate red against its own mandated source): the four awaits are `initializeFirebase`, the `Future.wait` over `activateAppCheck` + `initializeCrashlytics`, `RcPurchasesRepository.configureIfKeyed`, and the `Future.wait` over `SharedPreferences.getInstance` + `readInitialLockSnapshot`** — (b) lockstep equality of the two entrypoints' bootstrap shape, and (c) that `ensureCoupleTimeZonesInitialized` appears only in the post-frame block, never awaited pre-frame. Anyone adding a pre-frame await must edit the sentinel in the same diff — the addition becomes a *reviewed decision*, which is the entire point. The sentinel is mutation-checked at authoring time (move a call pre-frame, watch exactly the sentinel go red, restore).

## Decision 3 — `configureIfKeyed` deliberately does NOT move, despite being deferrable on paper

Today it is a zero-cost synchronous no-op (`kRevenueCatIosApiKey` is empty until operator item 0). Post-frame-deferring it now would be free today and WRONG later: `PurchasesIdentitySync` is current-state-then-listen — on a warm signed-in boot it reads auth state at provider init (first build), and against a not-yet-configured SDK the fail-closed adapter no-ops the `logIn`, after which **nothing retriggers identity sync until the next auth transition** — a whole session of anonymous-store state, paywall honestly-unavailable, on every warm boot. That interaction is exactly the "RC identity-sync retry hardening" already deferred to the first live-key session (ADR-014 lineage). The first live-key session owns re-sequencing this await together with that hardening; this ADR records the trap so the "obvious win" is not re-discovered and shipped blind. A comment at the call site points here.

## Decision 4 — Build size gets an exact CI number with a pathology cap: `tool/build_size_report.dart` in the release lane's `build-report` job

`flutter build ios --release --no-codesign --analyze-size -t lib/main_prod.dart` on the macOS runner emits the size JSON; the tool (house style: pure `dart:io`, `--max-mb` argument from the workflow, exit 0/1/64, measured numbers always printed) parses it, prints the top-level breakdown into the job log, uploads the JSON as an artifact, and **fails at >200 MB uncompressed .app** — a deliberately generous pathology cap (an accidental asset/binary regression, not a tuning target), with the ratchet recorded as a follow-up once two or three real measurements exist. A missing/unparseable size JSON is exit 64, never a pass — "couldn't measure" must not read as green (the coverage-gate 0/0 precedent).

## Decision 5 — Startup timing lands as diagnostics in the existing integration job; the real-device number rides operator item 4

A `startup_timing_emulator_test.dart` integration suite launches the app cold on the simulator and reports time-to-first-frame plus the bootstrap stage timings through a lightweight `BootTrace` (Timeline events + a debug-only stage log around each bootstrap step — stripped by `kReleaseMode` so prod pays nothing). It PRINTS a labeled table into the CI log and asserts only sanity (stages complete, first frame rendered) — **no <2s assertion on a shared debug simulator**, per the stopping condition. The honest numeric gate lives in two recorded places: the M6.5 Android pass (the PRD's actual device class) and operator item 4's on-device checklist, which gains "cold-start stopwatch on the iPhone 17, prod flavor, airplane-mode and warm-network runs" at session close.

## Decision 6 — Crash-free posture: audited, documented, not rebuilt

The M1.3 mechanism is confirmed live and correct: `initializeCrashlytics` applies dev-OFF/prod-ON via the runtime API (persists natively, self-corrects a flavor switch), `installErrorHooks` wires Flutter + platform-dispatcher errors to the reporter, and the app-side no-content rule (M5.2) keeps payloads content-free. What crash-free ≥99.5% (PRD §10, Gate 2) still needs, all previously recorded, none new: dSYM upload for symbolication (item 4), a deployed prod app to report from (item 2), and Gate-2 funnel instrumentation (mvp item 11, not this session). No code change; `architecture.md` §-observability text gets the audit note in the docs pass.

## Consequences

**Positive:**

- The cold-start path is structurally shorter (two channel calls + one parse off the critical path) with zero semantic risk, and the shape is now *enforced*, not aspirational — regressions need a sentinel edit, not archaeology.
- CI reports exact, stable numbers (build size, stage timings) instead of asserting noisy ones; the <2s theater is refused in writing.
- The RC deferral trap is documented at the exact place a future optimizer would trip it.

**Negative / accepted trade-offs:**

- No CI job asserts "<2s" — deliberately. The number the PRD means is a real-device Android number (M6.5) and a real-iPhone stopwatch (item 4). Anyone wanting a green cold-start badge before then is asking for the fake.
- The cold-start win is smaller than rev 1 sketched (one parse deferred + two overlaps; no App Check deferral). Accepted: rev 1's extra win rested on a false premise (PERF-1) and would have shipped a warm-boot failure for every user the day App Check enforcement turns on.
- The source sentinel makes bootstrap edits noisier (two files + a test). That friction is the feature.
- The 200 MB cap will read as toothless until real measurements let it ratchet; accepted over inventing a number.

## Pre-code adversarial review record (Session 022 — eight-for-eight)

Shared record in ADR-021. The two findings that landed here, both dual-confirmed: **PERF-1 (serious)** — the App Check deferral's "no backend call before user interaction" premise is false (warm signed-in boot opens the profile Firestore listen at first-frame build; the deferral was the same landmine class Decision 3 refuses for RC) → deferral deleted, overlap kept; **PERF-2 (blocking)** — the sentinel's allowed-await set omitted `configureIfKeyed`, contradicting Decision 3 → the pinned set is now the four real awaits. The skeptic's deeper note on PERF-1 (the item-4 "re-verify sign-in under enforcement" line could never have exercised the warm-boot path) died with the deferral itself: with App Check pre-frame, activation precedes every listen again and no special enforcement-era warm-boot check is owed by this session.
