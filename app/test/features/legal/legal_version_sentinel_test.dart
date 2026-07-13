import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/legal/domain/legal_version.dart';

/// The THREE-WAY version source-sentinel (ADR-023 Decision 4, finding
/// `testability-1`). It reads all three trees from the `app/` test cwd (the
/// `device_privacy_channel_parity_test` cross-tree precedent) and asserts the
/// legal-bundle version matches across:
///
///  1. the app `currentLegalVersion` Dart const,
///  2. the Functions `CURRENT_LEGAL_VERSION` constant,
///  3. the `version:` line in `docs/legal/README.md`.
///
/// A partial bump fails RED here in BOTH directions — the app-ahead brick AND
/// the silent under-gate (documents change but no re-consent fires). The bump
/// procedure requires a SAME-DIFF change of all three sources; see
/// docs/legal/README.md.
void main() {
  // Under `flutter test` the CWD is app/, so the sibling trees are one level up.
  const functionsCore = '../functions/src/data-rights/data-rights-core.ts';
  const legalReadme = '../docs/legal/README.md';

  int functionsConstant() {
    final source = File(functionsCore).readAsStringSync();
    final match = RegExp(
      r'CURRENT_LEGAL_VERSION\s*=\s*(\d+)',
    ).firstMatch(source);
    expect(
      match,
      isNotNull,
      reason: 'CURRENT_LEGAL_VERSION not found in $functionsCore',
    );
    return int.parse(match!.group(1)!);
  }

  int docsVersion() {
    final source = File(legalReadme).readAsStringSync();
    // The exact `version:` line the README documents as the single source.
    final match = RegExp(
      r'^version:\s*(\d+)\s*$',
      multiLine: true,
    ).firstMatch(source);
    expect(
      match,
      isNotNull,
      reason: 'a `version: <n>` line not found in $legalReadme',
    );
    return int.parse(match!.group(1)!);
  }

  test('app currentLegalVersion == functions CURRENT_LEGAL_VERSION == '
      'docs/legal/README version', () {
    const app = currentLegalVersion;
    final functions = functionsConstant();
    final docs = docsVersion();
    expect(
      {app, functions, docs},
      hasLength(1),
      reason:
          'legal-bundle version sources drifted — app=$app, '
          'functions=$functions, docs=$docs. A material change to any legal '
          'document requires a SAME-DIFF bump of all three sources together '
          '(the bump procedure in docs/legal/README.md); a partial bump is '
          'either the app-ahead brick or the silent under-gate.',
    );
  });
}
