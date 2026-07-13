import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// ADR-023's ARB commitment — the `data_rights_arb_guard` parity + placeholder
/// shape, ported to the consent/legal prefixes (`consent*`, `legal*`).
///
/// The coach guard's DIGIT-RUN rule is deliberately NOT cloned (same reasoning
/// as the privacy/data-rights guards): it is an ADR-016 D4 hotline obligation,
/// and consent/legal copy legitimately carries a date placeholder and a `18`.
///
/// A missing translation falls back silently at runtime. For legal copy that is
/// exactly wrong: a user consenting to special-category processing, or reading
/// their rights, must do so in their own language and register (TR/AR use the
/// RESPECTFUL register on these surfaces — ADR-020 D8 precedent).
void main() {
  // Under `flutter test` the CWD is app/ (the test-suite.md §1 convention).
  const arbDir = 'lib/core/l10n/arb';
  const locales = {'en': 'app_en.arb', 'tr': 'app_tr.arb', 'ar': 'app_ar.arb'};

  bool isLegalKey(String key) =>
      key.startsWith('consent') || key.startsWith('legal');

  Map<String, String> legalValues(String fileName) {
    final raw =
        jsonDecode(File('$arbDir/$fileName').readAsStringSync())
            as Map<String, dynamic>;
    return {
      for (final entry in raw.entries)
        if (isLegalKey(entry.key) && entry.value is String)
          entry.key: entry.value as String,
    };
  }

  final byLocale = {
    for (final locale in locales.entries) locale.key: legalValues(locale.value),
  };

  // The `{placeholder}` token SET a value carries (order-independent).
  Set<String> placeholders(String value) =>
      RegExp(r'\{(\w+)\}').allMatches(value).map((m) => m.group(1)!).toSet();

  test('the EN template carries the consent/legal key set', () {
    // A floor, not an exact count: new keys join the guard automatically.
    expect(byLocale['en']!.length, greaterThanOrEqualTo(25));
  });

  test('every consent/legal key exists in all three locales', () {
    final enKeys = byLocale['en']!.keys.toSet();
    for (final locale in ['tr', 'ar']) {
      expect(
        byLocale[locale]!.keys.toSet(),
        enKeys,
        reason:
            'the consent/legal key set for $locale must match the EN template',
      );
    }
  });

  test('no consent/legal value in any locale is left as a placeholder', () {
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

  test('every locale carries the same placeholder tokens per key', () {
    // A dropped `{version}`/`{date}` in a translation would render a broken
    // status line — the placeholder-shape guard.
    final en = byLocale['en']!;
    for (final key in en.keys) {
      final expected = placeholders(en[key]!);
      for (final locale in ['tr', 'ar']) {
        expect(
          placeholders(byLocale[locale]![key]!),
          expected,
          reason:
              '$locale/$key placeholders ${placeholders(byLocale[locale]![key]!)} '
              'differ from EN $expected',
        );
      }
    }
  });
}
