import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// ADR-019's ARB commitment — the `privacy_arb_guard_test` parity + placeholder
/// shape, ported to the M6.2 data-rights prefixes (`dataRights*`, `coupleEnded*`,
/// `settingsNotificationPrivacy*`).
///
/// The coach guard's DIGIT-RUN rule is deliberately NOT cloned (same reasoning as
/// the privacy guard): it is an ADR-016 D4 hotline obligation, and data-rights
/// copy legitimately carries no phone numbers — re-using the net here would ban
/// honest strings for a reason that does not apply to them.
///
/// A missing translation falls back silently at runtime. For deletion/notice copy
/// that is not cosmetic: a user acting on an irreversible legal right, or reading
/// that their shared space was permanently deleted, must do so in their own
/// language.
void main() {
  // Under `flutter test` the CWD is app/ (the test-suite.md §1 convention).
  const arbDir = 'lib/core/l10n/arb';
  const locales = {'en': 'app_en.arb', 'tr': 'app_tr.arb', 'ar': 'app_ar.arb'};

  bool isDataRightsKey(String key) =>
      key.startsWith('dataRights') ||
      key.startsWith('coupleEnded') ||
      key.startsWith('settingsNotificationPrivacy');

  Map<String, String> dataRightsValues(String fileName) {
    final raw =
        jsonDecode(File('$arbDir/$fileName').readAsStringSync())
            as Map<String, dynamic>;
    return {
      for (final entry in raw.entries)
        if (isDataRightsKey(entry.key) && entry.value is String)
          entry.key: entry.value as String,
    };
  }

  final byLocale = {
    for (final locale in locales.entries)
      locale.key: dataRightsValues(locale.value),
  };

  test('the EN template carries the data-rights key set', () {
    // A floor, not an exact count: new keys join the guard automatically.
    expect(byLocale['en']!.length, greaterThanOrEqualTo(25));
  });

  test('every data-rights key exists in all three locales', () {
    final enKeys = byLocale['en']!.keys.toSet();
    for (final locale in ['tr', 'ar']) {
      expect(
        byLocale[locale]!.keys.toSet(),
        enKeys,
        reason:
            'the data-rights key set for $locale must match the EN template',
      );
    }
  });

  test('no data-rights value in any locale is left as a placeholder', () {
    // The founder reviews the TR/AR copy later (native review flagged at close).
    // What must not ship is an untranslated stub masquerading as a translation.
    for (final locale in ['tr', 'ar']) {
      for (final entry in byLocale[locale]!.entries) {
        expect(
          entry.value.trim(),
          isNotEmpty,
          reason: '$locale/${entry.key} is empty',
        );
        expect(
          entry.value,
          isNot(equals(byLocale['en']![entry.key])),
          reason:
              '$locale/${entry.key} is byte-identical to the EN template — an '
              'untranslated placeholder, not a translation',
        );
      }
    }
  });
}
