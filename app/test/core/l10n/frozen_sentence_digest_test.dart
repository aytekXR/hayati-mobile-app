import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

/// A FROZEN-SENTENCE DIGEST — the W4 golden-update flag, applied to the copy
/// that carries safety and legal meaning (ADR-025 D5.iii, slice 0).
///
/// WHY: the app's ARB guards prove key-set parity, non-empty translations and
/// the no-phone-number rule — but nothing pins the WORDS. A session could
/// reword the crisis disclaimer or a consent sentence in any locale and ship a
/// green pipeline. For most copy that is fine and the native-review gate
/// (operator item 1) is an honest human process. For these 96 strings it is
/// not:
///   * the ★ safety keys are the not-therapy disclaimer and the crisis/help
///     path — the strings the ★ native-review gate exists to protect, and the
///     gate BLOCKS the coach's first run on a real device;
///   * `consent*` and `legal*` are ADR-023 guarantee surfaces: their sentences
///     were adversarially matched to what the code actually does, and a
///     material change to them is a legal-version event that must re-ask every
///     user for consent (`legal_version_sentinel_test.dart` enforces the
///     version half; this enforces the wording half).
///
/// `legal*` is in scope deliberately. ADR-025 D10 promises that rewording it
/// turns CI red, and an earlier draft of D5.iii scoped the digest to the ★ keys
/// and `consent*` only — which would have left the consent-WITHDRAWAL dialog
/// (`legalWithdrawDialogBody`) unprotected while the ADR claimed otherwise.
/// That gap was the pre-code review's blocking finding.
///
/// WHEN THIS FAILS, it is doing its job. It does not mean "revert". It means
/// *decide*, in this order:
///   1. Was the change intended? If not, revert it — you just caught a silent
///      reword of a safety or legal sentence.
///   2. If intended: does it change MEANING? A `consent*`/`legal*` change that
///      does is a material change — bump all three legal-version sources in the
///      same diff (ADR-023 D4) and expect every user to re-consent. A ★ change
///      re-enters the ★ native-review gate (operator-expected).
///   3. Only then re-stamp [expectedDigest] with the value this test prints,
///      and say in the PR why.
void main() {
  const arbDir = 'lib/core/l10n/arb';
  const locales = <String>['ar', 'en', 'tr'];

  /// The ★ safety keys, enumerated BY NAME (ADR-025 D5.iii).
  ///
  /// A prefix would not do here: `coach*` holds 27 keys, most of them ordinary
  /// UI chrome (send button, quota caption, error strings) whose rewording is
  /// routine. Only these five carry the safety meaning the ★ gate is about.
  const starSafetyKeys = <String>[
    'coachDisclaimerTitle',
    'coachDisclaimerBody',
    'coachDisclaimerCta',
    'coachHelpTitle',
    'coachPausedBody',
  ];

  /// The guarantee-surface prefixes. These ARE prefixes on purpose: a NEW
  /// `consent*` or `legal*` key is a new legal sentence and should join the
  /// digest automatically rather than wait for someone to remember.
  const guaranteePrefixes = <String>['consent', 'legal'];

  /// SHA-256 over UTF-8 of the sorted `"<locale>.<key>=<value>\n"` lines.
  /// Re-stamp only after working through the checklist in this file's header.
  const expectedDigest =
      '3b57dfa0c17bfe7a183f9f36c950103528a0921d29d32b84ec9cdea82aa7d0c3';

  /// The number of frozen pairs at the time of the last deliberate re-stamp.
  /// Pinned separately from the digest so a failure can distinguish "someone
  /// reworded a sentence" (count same, digest differs) from "someone added or
  /// removed a legal string" (count differs) — two situations with very
  /// different follow-ups.
  const expectedPairCount = 96;

  bool inScope(String key) =>
      starSafetyKeys.contains(key) ||
      guaranteePrefixes.any((prefix) => key.startsWith(prefix));

  late Map<String, Map<String, String>> arb;
  late List<String> frozenLines;

  setUpAll(() {
    arb = <String, Map<String, String>>{};
    for (final locale in locales) {
      final file = File('$arbDir/app_$locale.arb');
      expect(
        file.existsSync(),
        isTrue,
        reason:
            'the digest must fail loudly if an ARB file is renamed or moved '
            'rather than silently freeze fewer strings — re-point arbDir',
      );
      final decoded =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      arb[locale] = <String, String>{
        for (final entry in decoded.entries)
          // `@key` entries are ARB metadata (descriptions, placeholder specs),
          // not user-visible copy.
          if (!entry.key.startsWith('@')) entry.key: entry.value as String,
      };
    }

    frozenLines = <String>[
      for (final locale in locales)
        for (final entry in arb[locale]!.entries)
          if (inScope(entry.key)) '$locale.${entry.key}=${entry.value}\n',
    ]..sort();
  });

  test('every ★ safety key still exists in every locale, by name', () {
    // Without this, renaming a ★ key would quietly shrink the frozen set and
    // the digest would simply be re-stamped as "changed copy" — the safety
    // string would leave the net without anyone noticing it had.
    for (final locale in locales) {
      for (final key in starSafetyKeys) {
        expect(
          arb[locale],
          contains(key),
          reason:
              '★ safety key `$key` is missing from app_$locale.arb. If it was '
              'renamed, rename it in starSafetyKeys in the same diff — do not '
              'let it drop out of the frozen set.',
        );
      }
    }
  });

  test('the frozen set is the expected size', () {
    expect(
      frozenLines.length,
      expectedPairCount,
      reason:
          'the number of frozen safety/legal strings changed '
          '(${frozenLines.length} vs $expectedPairCount). A NEW consent*/legal* '
          'key is picked up automatically and is usually fine — re-stamp both '
          'constants. A REMOVED one means a legal sentence left the app: '
          'confirm that was intended before re-stamping.',
    );
  });

  test('the frozen safety and legal sentences are unchanged', () {
    final actual = sha256.convert(utf8.encode(frozenLines.join())).toString();
    expect(
      actual,
      expectedDigest,
      reason:
          'a ★ safety or ADR-023 guarantee-surface sentence changed.\n'
          'Current digest: $actual\n'
          'Work through the checklist at the top of this file BEFORE '
          're-stamping expectedDigest — a material consent*/legal* change is a '
          'legal-version event (ADR-023 D4), and a ★ change re-enters the '
          'crisis-content native-review gate.',
    );
  });
}
