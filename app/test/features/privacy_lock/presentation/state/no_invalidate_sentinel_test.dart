import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A SOURCE-SENTINEL test — it reads the controller's source from disk and
/// asserts the absence of a call, in the exact shape of the biometric-only
/// contract pin (`biometric_only_contract_test.dart`).
///
/// THE INVARIANT (ADR-018 Decision 1; blocking review finding FLUTTER-2):
/// NOTHING may `ref.invalidate` the privacy-lock controller. It is `keepAlive`
/// and seeded from the BY-VALUE boot snapshot, so invalidating it would re-run
/// `build()` against that STALE snapshot and replay boot state — re-locking a
/// signed-out app with the previous user's PIN, or reverting a just-enabled lock
/// to the boot-time `null`. `wipe()` is `store.clear()` plus an in-place state
/// mutation for exactly this reason. Adding the change-PIN op (rev 4) is the
/// natural moment to close the grep gap the wipe re-read test only pins
/// behaviorally.
///
/// The guard searches only the CODE lines: the wipe's loud doc-comment names the
/// forbidden call in prose ("no code path may ever `ref.invalidate` this
/// controller") and even cites the coach listener's real
/// `ref.invalidate(coachTranscriptProvider)` as the deliberate asymmetry — so
/// comment lines are stripped first, or the pin would match its own explanation
/// and pass/fail vacuously. What remains is executable Dart.
///
/// If this test fails, do not delete it. Remove the invalidate call.
void main() {
  const path =
      'lib/features/privacy_lock/presentation/state/privacy_lock_controller.dart';

  late String code;

  setUpAll(() {
    final file = File(path);
    expect(
      file.existsSync(),
      isTrue,
      reason:
          'the sentinel must fail loudly if the controller is renamed or moved '
          'rather than pass vacuously — re-point this path and keep the pin',
    );
    // Strip `///` doc lines and `//` line comments — the only place the forbidden
    // call is named is prose; everything else is code.
    code = file
        .readAsStringSync()
        .split('\n')
        .where((line) => !line.trimLeft().startsWith('//'))
        .join('\n');
  });

  test('the controller never invalidates itself or its provider (FLUTTER-2)', () {
    expect(
      code,
      isNot(contains('ref.invalidate(')),
      reason: 'invalidation replays the STALE boot snapshot (ADR-018 D1)',
    );
    expect(
      code,
      isNot(contains('invalidateSelf')),
      reason: 'invalidateSelf re-runs build() against the boot override too',
    );
  });
}
