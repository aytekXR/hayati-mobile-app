// Cold-start timing DIAGNOSTICS for the dev bootstrap — device/simulator only
// (the real entrypoint reaches Firebase / Keychain / App Check platform
// channels, so it cannot run in the plain `flutter test` VM).
//
// It drives the REAL dev entrypoint (`main_dev.main()`) against the emulators
// under the same USE_*_EMULATOR dart-defines as the sibling suites, waits for the
// first frame, and prints a labeled BootTrace stage table plus time-to-first-
// frame into the CI log (also surfaced via `binding.reportData`).
//
// WHY the assertions are SANITY ONLY — no <2s budget (ADR-022 Decision 5): a
// debug-JIT launch on a shared macOS runner, sharing the box with the emulators,
// measures runner contention, not user experience. A <2s assertion here would be
// theater in both directions — flaky red on runner noise, meaningless green
// against a real mid-range device. The honest cold-start number lives in two
// recorded places: the M6.5 Android pass (the PRD's actual device class) and
// operator item 4's on-device stopwatch (iPhone 17, prod flavor, airplane-mode
// and warm-network runs). This suite proves the SHAPE — a first frame renders
// and the bootstrap stages fire in order — and prints the numbers for a human to
// read, nothing more.
//
// The functions emulator require()s functions/lib/index.js (it never compiles
// TS), so `npm run build` in functions/ must land first; the firestore emulator
// needs Java 21+ on PATH. Run (two terminals, repo root then app/):
//   npx firebase-tools emulators:start \
//     --only auth,firestore,functions --project demo-hayati
//   flutter test integration_test/startup_timing_emulator_test.dart \
//     --dart-define=USE_AUTH_EMULATOR=true \
//     --dart-define=USE_FIRESTORE_EMULATOR=true \
//     --dart-define=USE_FUNCTIONS_EMULATOR=true \
//     -d <device>
//
// CI runs this suite on the main-only `integration-emulator` job (macOS runner;
// POST-MERGE signal — run locally before merging when possible).
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/core/firebase/firebase_bootstrap.dart'
    show kUseAuthEmulator;
import 'package:hayati_app/core/observability/boot_trace.dart';
import 'package:hayati_app/main_dev.dart' as entry;
import 'package:integration_test/integration_test.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    if (!kUseAuthEmulator) {
      fail(
        'This suite drives the dev bootstrap against the emulators. Pass '
        '--dart-define=USE_AUTH_EMULATOR=true (see file header).',
      );
    }
  });

  testWidgets('cold bootstrap renders a first frame and records its stages', (
    tester,
  ) async {
    final stopwatch = Stopwatch()..start();

    // Drive the REAL dev entrypoint — the exact code path a cold launch runs.
    await entry.main();

    // First frame: pump once to build/layout/paint, then let the engine confirm
    // it rasterized. pumpAndSettle is avoided on purpose — the sign-in screen's
    // progress indicator can keep the tree "busy" indefinitely, and the number
    // we want is time-to-FIRST-frame, not time-to-idle.
    await tester.pump();
    await binding.waitUntilFirstFrameRasterized;
    stopwatch.stop();

    final totalMs = stopwatch.elapsedMilliseconds;
    final stageNames = BootTrace.marks.map((stage) => stage.name).toList();

    // Labeled table into the CI log — diagnostics, not a gate (ADR-022 D5).
    final table = StringBuffer()
      ..writeln('=== cold-start BootTrace (dev flavor, simulator) ===')
      ..writeln('${'stage'.padRight(28)} elapsedMs');
    for (final stage in BootTrace.marks) {
      table.writeln(
        '${stage.name.padRight(28)} ${stage.elapsed.inMilliseconds}',
      );
    }
    table.writeln('${'timeToFirstFrame'.padRight(28)} $totalMs');
    debugPrint(table.toString());

    binding.reportData = <String, dynamic>{
      'timeToFirstFrameMs': totalMs,
      'stages': <Map<String, dynamic>>[
        for (final stage in BootTrace.marks)
          {'name': stage.name, 'elapsedMs': stage.elapsed.inMilliseconds},
      ],
    };

    // SANITY ONLY (ADR-022 Decision 5) — no timing budget is asserted here.
    expect(
      tester.allWidgets,
      isNotEmpty,
      reason: 'the bootstrap must render a first frame',
    );
    expect(
      stageNames,
      containsAllInOrder(<String>[
        BootTrace.stageMain,
        BootTrace.stageFirebaseReady,
        BootTrace.stageAppCheckCrashlyticsReady,
        BootTrace.stageRcConfigured,
        BootTrace.stageLocalStateReady,
        BootTrace.stageRunApp,
      ]),
      reason: 'the six bootstrap stages must fire in ADR-022 D1 order',
    );
    expect(
      totalMs,
      lessThan(60000),
      reason:
          'a generous ceiling only — the real cold-start budget rides M6.5 + '
          'operator item 4, never this shared-runner debug launch',
    );
  });
}
