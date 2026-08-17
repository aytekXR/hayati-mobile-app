import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/notifications/domain/push_diagnostic.dart';
import 'package:hayati_app/features/notifications/domain/push_registration.dart';

/// A CROSS-LANGUAGE parity test (ADR-049 Decision 9), in the shape of
/// `legal_version_sentinel_test.dart` and `brandkit_token_parity_test.dart`:
/// two artifacts in two languages must agree, and nothing but this test connects
/// them.
///
/// WHY. `users/{uid}.pushDiagnostic` carries two CLOSED vocabularies — ADR-046's
/// [PushRegistrationState] and ADR-049's [PushDiagnosticDetail] — and
/// `firestore.rules` hard-codes both as string literals. Dart owns the enums.
/// The `.name`s are wire values the moment they are written.
///
/// **The failure this exists to catch is silent in every other instrument.** Add
/// a sixth state in Dart and the rules reject the write; `PushTokenSync` catches
/// the denial by design (ADR-039 D1: a diagnostic must never cost a frame), so
/// the device goes quiet on exactly the state someone thought worth adding —
/// green build, green tests, and a field that stops reporting. Remove one from
/// the rules and the same thing happens to an existing state.
///
/// So the assertion is SET EQUALITY, both directions, for BOTH vocabularies.
/// One comparison would leave the other half exactly as unguarded as it was
/// before this file existed — which is why `detail` was given an enum rather
/// than being left a bare string.
///
/// If this fails, do not edit whichever side is easier. A vocabulary change is a
/// data change: existing documents already carry the old words, and
/// `tool/ci/push_delivery_probe.py` maps them by name too — it is the third
/// reader, and it degrades honestly (`UNMAPPED state`) rather than silently,
/// which is why it is not asserted here.
void main() {
  const rulesPath = '../firestore.rules';

  late String rules;

  setUpAll(() {
    final file = File(rulesPath);
    expect(
      file.existsSync(),
      isTrue,
      reason:
          '$rulesPath not found — this test must run with `app/` as the working '
          'directory, like the brandkit and legal parity tests.',
    );
    rules = file.readAsStringSync();
  });

  /// The literals of the rules list that FOLLOWS [afterMarker].
  ///
  /// Anchored on the field access rather than on a bare bracket: a `[...]`
  /// scraped from anywhere in the file would keep passing while the clause it
  /// was meant to read had been deleted — a test whose fixture came from its own
  /// subject. If the anchor rots, this fails loudly instead of proving nothing.
  Set<String> vocabularyAfter(String afterMarker) {
    final markerAt = rules.indexOf(afterMarker);
    expect(
      markerAt,
      isNot(-1),
      reason:
          'anchor "$afterMarker" is gone from firestore.rules — the rule was '
          'refactored, and this test can no longer see what it is guarding.',
    );
    final open = rules.indexOf('[', markerAt);
    final close = rules.indexOf(']', open);
    expect(open, isNot(-1));
    expect(close, isNot(-1));
    return rules
        .substring(open + 1, close)
        .split(',')
        .map((raw) => raw.trim().replaceAll("'", ''))
        .where((word) => word.isNotEmpty)
        .toSet();
  }

  test('the state vocabulary matches PushRegistrationState exactly', () {
    expect(
      vocabularyAfter('request.resource.data.pushDiagnostic.state in'),
      PushRegistrationState.values.map((state) => state.name).toSet(),
    );
  });

  test('the detail vocabulary matches PushDiagnosticDetail exactly', () {
    expect(
      vocabularyAfter('request.resource.data.pushDiagnostic.detail in'),
      PushDiagnosticDetail.values.map((detail) => detail.name).toSet(),
    );
  });

  // The rule validates a fixed key set too, and the recorder writes exactly
  // those three. A fourth key added on either side without the other is the same
  // silent-rejection failure as a vocabulary drift.
  test('the accepted key set is exactly what the recorder writes', () {
    expect(
      vocabularyAfter('request.resource.data.pushDiagnostic.keys().hasOnly'),
      {'state', 'detail', 'at'},
    );
    expect(
      vocabularyAfter('request.resource.data.pushDiagnostic.keys().hasAll'),
      {'state', 'at'},
    );
  });
}
