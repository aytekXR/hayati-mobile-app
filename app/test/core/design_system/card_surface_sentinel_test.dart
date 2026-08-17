import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/core/design_system/card_surface.dart';
import 'package:hayati_app/core/design_system/elevation_tokens.dart';
import 'package:hayati_app/core/design_system/radius_tokens.dart';

/// A SOURCE SENTINEL over the card surface (ADR-052, issue #175), in the shape
/// `brandkit_token_parity_test.dart` and `lock_screen_forbidden_api_sentinel_test.dart`
/// already use: it reads the repo, not a rendered widget.
///
/// WHY IT IS NOT "each screen has a shadow". That assertion is satisfied by
/// fourteen hand-copied decorations carrying the right value — which is *exactly*
/// the state this slice ended, passing the test written to prevent it. Lesson
/// **108** in its natural habitat: the test would be green, the defect intact,
/// and the eleventh card would still copy its neighbour.
///
/// What is asserted instead is that there is **one definition**. Before ADR-052
/// there were fourteen: 4 carrying [ElevationTokens.level1] and 10 with no
/// shadow at all, so the token that defines "raised" in this product (ui-ux §9.3,
/// plum, never black) reached four of the surfaces the brandkit assigns it to.
///
/// If this fails, do not add the shadow to the offending file. Call
/// [raisedCardDecoration] — that is the entire point.
void main() {
  const featuresDir = 'lib/features';

  test('no feature file builds its own card surface', () {
    final dir = Directory(featuresDir);
    expect(
      dir.existsSync(),
      isTrue,
      reason:
          '$featuresDir not found — this test must run with `app/` as the '
          'working directory, like the brandkit and legal parity tests.',
    );

    final darts = dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();

    // ⚠️ SENTINEL-OF-THE-SENTINEL. A scanner over an empty set is the greenest
    // output in this repo and measures nothing — if a refactor moves the feature
    // tree, this test must fail loudly rather than pass over nothing.
    expect(
      darts.length,
      greaterThan(50),
      reason:
          'scanned only ${darts.length} files under $featuresDir — the walker '
          'is broken, not the tree clean.',
    );

    final offenders = <String>[];
    for (final file in darts) {
      // Strip comments first: ADR-052 and this slice's own commit messages
      // quote `surfaceContainerHighest` while explaining the rule, and a
      // sentinel that reddens on prose about itself is a sentinel people delete
      // (`release_lane_lint.dart`'s "scan CODE, not commentary").
      final code = file
          .readAsStringSync()
          .split('\n')
          .map((l) => l.replaceFirst(RegExp(r'\s*//.*'), ''))
          .join('\n');
      if (code.contains('surfaceContainerHighest')) {
        offenders.add(file.path);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'These files build a card surface by hand instead of calling '
          'raisedCardDecoration() (ADR-052, #175). Ten of the fourteen original '
          'copies silently omitted ElevationTokens.level1 — the point is not '
          'that the values are right today but that the next card inherits '
          'rather than copies:\n  ${offenders.join('\n  ')}',
    );
  });

  // The value itself is pinned here rather than left to the goldens: a golden
  // proves the pixels did not change, never that they were right to begin with.
  testWidgets('the one definition carries surface, radius and Level-1', (
    tester,
  ) async {
    late BoxDecoration decoration;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Builder(
          builder: (context) {
            decoration = raisedCardDecoration(Theme.of(context));
            return const SizedBox();
          },
        ),
      ),
    );

    expect(
      decoration.color,
      ThemeData.dark().colorScheme.surfaceContainerHighest,
    );
    expect(decoration.borderRadius, RadiusTokens.cardRadius);
    expect(decoration.boxShadow, ElevationTokens.level1);
    // Absent unless a caller asks — the four bordered cards do, the ten others
    // must not silently acquire an edge they never had.
    expect(decoration.border, isNull);
  });

  testWidgets('a caller may add a border without re-declaring the surface', (
    tester,
  ) async {
    late BoxDecoration decoration;
    final border = Border.all(color: const Color(0xFF123456));
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Builder(
          builder: (context) {
            decoration = raisedCardDecoration(
              Theme.of(context),
              border: border,
            );
            return const SizedBox();
          },
        ),
      ),
    );

    expect(decoration.border, border);
    // The elevation survives the border — the combination `PrivacySpotlightCard`
    // and `partner_preview` already shipped, and the reason `border` is a
    // parameter rather than a reason to keep an inline decoration.
    expect(decoration.boxShadow, ElevationTokens.level1);
  });
}
