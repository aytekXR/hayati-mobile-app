import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// ADR-018 Decision 7's ARB commitment — the `coach_arb_guard_test` key-set
/// parity check, ported to the `settings*` / `lock*` prefixes.
///
/// A missing translation falls back silently at runtime. For lock copy that is
/// not cosmetic: a user staring at an English "Too many attempts" they cannot
/// read, on a screen that is holding their app closed, has no way out — and the
/// recovery line is the one string they most need in their own language.
///
/// The coach guard's DIGIT-RUN rule is deliberately NOT cloned here. It is an
/// ADR-016 Decision 4 hotline obligation (no phone-number-shaped run may ship in
/// safety copy); lock copy legitimately says "6-digit PIN" and "about 30
/// seconds", and re-using the net here would ban honest strings for a reason
/// that does not apply to them.
void main() {
  // Under `flutter test` the CWD is app/ (the test-suite.md §1 convention).
  const arbDir = 'lib/core/l10n/arb';
  const locales = {'en': 'app_en.arb', 'tr': 'app_tr.arb', 'ar': 'app_ar.arb'};

  bool isPrivacyKey(String key) =>
      key.startsWith('settings') || key.startsWith('lock');

  Map<String, String> privacyValues(String fileName) {
    final raw =
        jsonDecode(File('$arbDir/$fileName').readAsStringSync())
            as Map<String, dynamic>;
    return {
      for (final entry in raw.entries)
        if (isPrivacyKey(entry.key) && entry.value is String)
          entry.key: entry.value as String,
    };
  }

  final byLocale = {
    for (final locale in locales.entries)
      locale.key: privacyValues(locale.value),
  };

  test('the EN template carries the settings/lock key set', () {
    // A floor, not an exact count: new keys join the guard automatically.
    expect(byLocale['en']!.length, greaterThanOrEqualTo(40));
  });

  test('every settings*/lock* key exists in all three locales', () {
    final enKeys = byLocale['en']!.keys.toSet();
    for (final locale in ['tr', 'ar']) {
      expect(
        byLocale[locale]!.keys.toSet(),
        enKeys,
        reason:
            'the settings/lock key set for $locale must match the EN template',
      );
    }
  });

  test('no settings*/lock* value in any locale is left as a placeholder', () {
    // The founder reviews the TR/AR copy later (operator item 1). What must not
    // ship is an untranslated stub masquerading as a translation.
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
