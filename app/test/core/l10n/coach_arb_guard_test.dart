import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// ADR-017 Test commitment 10 — the ADR-016 Decision 4 hard rule, ported
/// app-side across the disclaimer's home change: NO phone-number-shaped digit
/// run may ship in any coach-facing copy. A wrong or stale crisis number is
/// actively dangerous, and the coach ARB strings (disclaimer included) are
/// AI-drafted copy headed for native review — a reviewer could well ADD a
/// hotline number; this net catches it before CI goes green. The functions
/// suite carries the same guard over the server-side help responses.
///
/// Also pins key-set parity: every `coach*` key present in the EN template is
/// present in TR and AR (a missing translation falls back silently at runtime,
/// which for safety copy is a localization hole, not a cosmetic one).
void main() {
  // Under `flutter test` the CWD is app/ (the test-suite.md §1 convention the
  // static-asset harness relies on too).
  const arbDir = 'lib/core/l10n/arb';
  final locales = {'en': 'app_en.arb', 'tr': 'app_tr.arb', 'ar': 'app_ar.arb'};

  Map<String, String> coachValues(String fileName) {
    final raw =
        jsonDecode(File('$arbDir/$fileName').readAsStringSync())
            as Map<String, dynamic>;
    return {
      for (final entry in raw.entries)
        if (entry.key.startsWith('coach') && entry.value is String)
          entry.key: entry.value as String,
    };
  }

  final byLocale = {
    for (final locale in locales.entries) locale.key: coachValues(locale.value),
  };

  test('the EN template carries the coach key set', () {
    // A floor, not an exact count: new coach keys join the guard automatically.
    expect(byLocale['en']!.length, greaterThanOrEqualTo(25));
  });

  test('every coach* key exists in all three locales', () {
    final enKeys = byLocale['en']!.keys.toSet();
    for (final locale in ['tr', 'ar']) {
      expect(
        byLocale[locale]!.keys.toSet(),
        enKeys,
        reason: 'coach key set for $locale must match the EN template',
      );
    }
  });

  test('no coach* value in any locale contains a phone-number-shaped run', () {
    final digitRun = RegExp(r'\d{3,}');
    for (final locale in byLocale.entries) {
      for (final entry in locale.value.entries) {
        expect(
          digitRun.hasMatch(entry.value),
          isFalse,
          reason:
              '${locale.key}/${entry.key} contains a 3+ digit run — '
              'hotline numbers are founder-verified only (ADR-016 D4)',
        );
      }
    }
  });
}
