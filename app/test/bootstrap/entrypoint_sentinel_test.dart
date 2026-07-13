import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// SOURCE-SENTINEL for the cold-start bootstrap (ADR-022 Decision 2), the S020
/// pattern applied to the pre-first-frame critical path. It reads
/// `lib/main_dev.dart` + `lib/main_prod.dart` as TEXT (CWD is `app/` under
/// `flutter test`) and pins three things a runtime test cannot:
///
///  (a) the EXACT set of `await`s before `runHayati(` — four, in order:
///      `initializeFirebase`, the record `.wait` over `activateAppCheck` +
///      `initializeCrashlytics`, `RcPurchasesRepository.configureIfKeyed`, and
///      the record `.wait` over `SharedPreferences.getInstance` +
///      `readInitialLockSnapshot` (ADR-022 Decision 1 rev 2, review PERF-2);
///  (b) `ensureCoupleTimeZonesInitialized` runs ONLY post-frame, inside an
///      `addPostFrameCallback`, never awaited pre-frame (Decision 1);
///  (c) the two entrypoints' bootstrap shapes are byte-equal once the flavor
///      const is normalized — so they cannot drift.
///
/// ADR-022 Decision 2: editing the bootstrap means editing THIS sentinel in the
/// same diff — a new pre-frame await becomes a reviewed decision, not an accident
/// that quietly lengthens every cold start. That friction IS the feature. If this
/// fails, read ADR-022 Decision 1 before "fixing" the test.
void main() {
  const devPath = 'lib/main_dev.dart';
  const prodPath = 'lib/main_prod.dart';

  late String devSource;
  late String prodSource;

  setUpAll(() {
    devSource = _readOrFail(devPath);
    prodSource = _readOrFail(prodPath);
  });

  for (final entry in const {
    'main_dev.dart': devPath,
    'main_prod.dart': prodPath,
  }.entries) {
    final label = entry.key;

    test('$label pins exactly the four allowed pre-frame awaits, in order', () {
      final source = _readOrFail(entry.value);
      final code = _collapse(_stripComments(_preRunHayati(source)));

      expect(
        RegExp(r'\bawait\b').allMatches(code).length,
        4,
        reason:
            'exactly four awaits may precede runHayati (ADR-022 D1); adding one '
            'is a reviewed decision — edit this sentinel and the ADR together',
      );

      // Anchored on the function names, tolerant of whitespace/argument details.
      final allowed = <RegExp>[
        RegExp(r'await\s+initializeFirebase\s*\('),
        RegExp(
          r'await\s*\(\s*activateAppCheck\b.*?initializeCrashlytics\b.*?\)\s*\.wait',
          dotAll: true,
        ),
        RegExp(r'await\s+RcPurchasesRepository\.configureIfKeyed\s*\('),
        RegExp(
          r'await\s*\(\s*SharedPreferences\.getInstance\b.*?readInitialLockSnapshot\b.*?\)\s*\.wait',
          dotAll: true,
        ),
      ];

      var previousEnd = -1;
      for (final pattern in allowed) {
        final match = pattern.firstMatch(code);
        expect(
          match,
          isNotNull,
          reason: 'missing an allowed pre-frame await: /${pattern.pattern}/',
        );
        expect(
          match!.start,
          greaterThan(previousEnd),
          reason: 'the four awaits are out of the ADR-022 D1 order',
        );
        previousEnd = match.start;
      }
    });

    test(
      '$label defers the tz parse to a post-frame callback, never awaited',
      () {
        final source = _readOrFail(entry.value);
        final code = _collapse(_stripComments(source));

        expect(
          RegExp(
            r'ensureCoupleTimeZonesInitialized\s*\(',
          ).allMatches(code).length,
          1,
          reason: 'the tz warm-up is called exactly once (ADR-022 D1)',
        );

        // It must NOT sit in the pre-frame segment.
        final preFrame = _collapse(_stripComments(_preRunHayati(source)));
        expect(
          preFrame,
          isNot(contains('ensureCoupleTimeZonesInitialized')),
          reason: 'the tz parse moved off the critical path (ADR-022 D1)',
        );

        // It must sit inside an addPostFrameCallback body, after runHayati(.
        expect(
          code,
          contains(
            RegExp(
              r'addPostFrameCallback\s*\(\s*\(_\)\s*\{\s*'
              r'ensureCoupleTimeZonesInitialized\s*\(\s*\)\s*;\s*\}\s*\)',
            ),
          ),
          reason:
              'the tz warm-up must run in a post-frame callback — a deterministic '
              '"after first frame", not an event-queue race (ADR-022 D1)',
        );
        expect(
          code.indexOf('ensureCoupleTimeZonesInitialized'),
          greaterThan(code.indexOf('runHayati(')),
          reason: 'the post-frame callback is registered AFTER runHayati',
        );

        // And never awaited — that would drag it back onto the critical path.
        expect(
          code,
          isNot(contains(RegExp(r'await\s+ensureCoupleTimeZonesInitialized'))),
          reason:
              'awaiting the tz parse re-blocks the first frame (ADR-022 D1)',
        );
      },
    );
  }

  test('the two entrypoints cannot drift (lockstep, ADR-022 D2)', () {
    // The two files differ ONLY in the flavor const (AppFlavor.dev vs .prod) and
    // the flavor-specific trailing comment on the App Check block — verified by a
    // raw diff at authoring time. Normalization strips comments, collapses
    // whitespace, and neutralizes the flavor token; what remains is the bootstrap
    // CODE, which must be identical so neither entrypoint can quietly diverge.
    expect(
      _normalizeBootstrap(devSource),
      _normalizeBootstrap(prodSource),
      reason:
          'main_dev and main_prod bootstrap shapes drifted — keep them lockstep '
          '(ADR-022 D2); only the flavor const may differ',
    );
  });
}

String _readOrFail(String path) {
  final file = File(path);
  expect(
    file.existsSync(),
    isTrue,
    reason:
        'the sentinel must fail loudly if an entrypoint is renamed or moved '
        'rather than pass vacuously — re-point this path and keep the pin ($path)',
  );
  return file.readAsStringSync();
}

/// The bootstrap body from `main` up to (not including) the `runHayati(` call.
String _preRunHayati(String source) {
  final mainStart = source.indexOf('Future<void> main() async {');
  final runHayatiStart = source.indexOf('runHayati(');
  expect(mainStart, greaterThanOrEqualTo(0), reason: 'main() not found');
  expect(
    runHayatiStart,
    greaterThan(mainStart),
    reason: 'runHayati( not found after main()',
  );
  return source.substring(mainStart, runHayatiStart);
}

/// Removes `//` line comments. Safe here because no bootstrap line carries a `//`
/// inside a string literal (no URLs live on the pre-frame path).
String _stripComments(String source) {
  final buffer = StringBuffer();
  for (final line in source.split('\n')) {
    final idx = line.indexOf('//');
    buffer.writeln(idx >= 0 ? line.substring(0, idx) : line);
  }
  return buffer.toString();
}

String _collapse(String source) =>
    source.replaceAll(RegExp(r'\s+'), ' ').trim();

String _normalizeBootstrap(String source) {
  final code = _collapse(_stripComments(_preRunHayati(source)));
  return code.replaceAll(RegExp(r'AppFlavor\.\w+'), 'AppFlavor.<flavor>');
}
