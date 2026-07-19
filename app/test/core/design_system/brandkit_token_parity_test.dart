import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/core/design_system/color_tokens.dart';
import 'package:hayati_app/core/design_system/radius_tokens.dart';
import 'package:hayati_app/core/design_system/spacing_tokens.dart';
import 'package:hayati_app/core/design_system/typography_tokens.dart';

/// A CROSS-TREE PARITY test, in the shape of `legal_version_sentinel_test.dart`
/// (which pins the app const, the functions const and the docs version to each
/// other) — but here the two sides are the exported brand kit and the Dart
/// tokens the app actually renders from.
///
/// WHY (ADR-025 D3/D5.ii, issue #62): `brandkit/brandkit/tokens/
/// hayati-tokens.json` is the exported source of truth for the palette, type
/// scale, line-heights, spacing grid and radii. Those values reach the app by
/// **hand transcription** — there is no codegen, and until this test there was
/// no check either. They matched by care, not by construction. The whole of
/// ADR-025 rests on "the refactor is expressed through brandkit tokens; the
/// brandkit decides", and that rule cannot rest on a hand-copy nobody verifies:
/// a brandkit revision that skipped the Dart side, or a token edited during a
/// refactor slice, would both have shipped green in either direction.
///
/// The correspondence is deliberately NOT 1:1. Four groups of JSON entries have
/// no Dart counterpart and are NOT asserted — they are listed explicitly at the
/// bottom of this file so the gap is recorded rather than silently skipped
/// (ADR-025 D5.ii's mapping table is the spec):
///   * `typography.minimumBodySize` / `dynamicTypeMax` — brandkit RULES, not
///     values the theme emits; the second is realised as the goldens' scale-130
///     cells rather than as a constant.
///   * `iconography.*` — the app ships Material icons, not the brandkit's
///     Phosphor (a recorded, unresolved divergence: issue #63). Asserting it
///     would fail on first write against a decision nobody has made yet.
///   * `rules[]` — prose.
///
/// If this test fails, do NOT edit whichever side is easier. Decide which side
/// is right — the brand kit is the constitution (ADR-025 D3) — and if the
/// divergence is a visual decision rather than a typo, it is the founder's call.
void main() {
  const tokensPath = '../brandkit/brandkit/tokens/hayati-tokens.json';

  late Map<String, dynamic> tokens;

  setUpAll(() {
    final file = File(tokensPath);
    expect(
      file.existsSync(),
      isTrue,
      reason:
          'the parity test must fail loudly if the exported tokens are renamed '
          'or moved rather than pass vacuously — re-point tokensPath and keep '
          'the pin',
    );
    tokens = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  });

  /// `Color(0xFF231A33)` against the brandkit's `"#231A33"`.
  void expectHex(Color actual, String jsonKey, {required String reason}) {
    final entry =
        (tokens['color'] as Map<String, dynamic>)[jsonKey]
            as Map<String, dynamic>;
    final expected = entry['value'] as String;
    final actualHex =
        '#'
        '${(actual.r * 255).round().toRadixString(16).padLeft(2, '0')}'
        '${(actual.g * 255).round().toRadixString(16).padLeft(2, '0')}'
        '${(actual.b * 255).round().toRadixString(16).padLeft(2, '0')}';
    expect(
      actualHex.toUpperCase(),
      expected.toUpperCase(),
      reason: 'ColorTokens.$reason drifted from brandkit color.$jsonKey',
    );
    expect(
      (actual.a * 255).round(),
      255,
      reason: 'brand palette entries are fully opaque',
    );
  }

  group('color — every brandkit hex reaches the Dart palette', () {
    test('all nine palette entries match', () {
      expectHex(ColorTokens.night, 'night', reason: 'night');
      expectHex(ColorTokens.nightRaised, 'night.raised', reason: 'nightRaised');
      expectHex(ColorTokens.pomegranate, 'pomegranate', reason: 'pomegranate');
      expectHex(
        ColorTokens.pomegranateDeep,
        'pomegranate.deep',
        reason: 'pomegranateDeep',
      );
      expectHex(ColorTokens.sand, 'sand', reason: 'sand');
      expectHex(ColorTokens.gold, 'gold', reason: 'gold');
      expectHex(ColorTokens.sage, 'sage', reason: 'sage');
      expectHex(ColorTokens.clay, 'clay', reason: 'clay');
      expectHex(ColorTokens.alert, 'alert', reason: 'alert');
    });

    test('the brandkit defines no palette entry the app is missing', () {
      // The other direction: a NEW brandkit colour must not sit unnoticed
      // outside the Dart palette. Nine names, pinned — adding a tenth to the
      // JSON turns this red until ColorTokens carries it too.
      expect(
        (tokens['color'] as Map<String, dynamic>).keys.toSet(),
        {
          'night',
          'night.raised',
          'pomegranate',
          'pomegranate.deep',
          'sand',
          'gold',
          'sage',
          'clay',
          'alert',
        },
        reason:
            'the brand kit gained or lost a colour — mirror it in '
            'ColorTokens (and in this pin) in the same diff',
      );
    });
  });

  group('typography — family, scale and the per-script line-heights', () {
    test('family and fallback stack match', () {
      final typography = tokens['typography'] as Map<String, dynamic>;
      final family = typography['family'] as Map<String, dynamic>;
      expect(TypographyTokens.family, family['value']);
      expect(TypographyTokens.fallback, family['fallback']);
    });

    test('the body line-heights are the brandkit per-script pair', () {
      final body =
          (tokens['typography'] as Map<String, dynamic>)['body']
              as Map<String, dynamic>;
      final lineHeight = body['lineHeight'] as Map<String, dynamic>;
      expect(TypographyTokens.bodyHeightLatin, lineHeight['latin']);
      expect(TypographyTokens.bodyHeightArabic, lineHeight['arabic']);
      // The selector is the thing screens actually call.
      expect(TypographyTokens.bodyHeightFor('ar'), lineHeight['arabic']);
      expect(TypographyTokens.bodyHeightFor('tr'), lineHeight['latin']);
      expect(TypographyTokens.bodyHeightFor('en'), lineHeight['latin']);
    });

    test('every type-scale step reaches its Material role at size+weight', () {
      final typography = tokens['typography'] as Map<String, dynamic>;
      final theme = TypographyTokens.textThemeFor('en');

      void expectStep(String jsonKey, List<TextStyle?> roles) {
        final step = typography[jsonKey] as Map<String, dynamic>;
        for (final style in roles) {
          expect(
            style?.fontSize,
            (step['size'] as num).toDouble(),
            reason: 'type scale `$jsonKey` size drifted',
          );
          expect(
            style?.fontWeight?.value,
            step['weight'],
            reason: 'type scale `$jsonKey` weight drifted',
          );
        }
      }

      // The role mapping is documented in typography_tokens.dart.
      expectStep('display', [theme.displaySmall, theme.headlineLarge]);
      expectStep('h1', [theme.headlineMedium]);
      expectStep('h2', [theme.titleLarge]);
      expectStep('body', [theme.bodyLarge, theme.bodyMedium]);
      expectStep('caption', [theme.bodySmall]);
    });

    test('the Arabic theme raises body line-height and nothing else', () {
      final ar = TypographyTokens.textThemeFor('ar');
      final en = TypographyTokens.textThemeFor('en');
      final lineHeight =
          ((tokens['typography'] as Map<String, dynamic>)['body']
                  as Map<String, dynamic>)['lineHeight']
              as Map<String, dynamic>;

      expect(ar.bodyLarge?.height, lineHeight['arabic']);
      expect(en.bodyLarge?.height, lineHeight['latin']);
      // Headings carry NO height in either locale — the brandkit fixes none,
      // and inventing one is exactly the drift this test exists to catch.
      expect(ar.headlineMedium?.height, isNull);
      expect(en.headlineMedium?.height, isNull);
      // Sizes are script-independent.
      expect(ar.bodyLarge?.fontSize, en.bodyLarge?.fontSize);
    });
  });

  group('spacing — the grid and its named steps', () {
    test('the named spacing values match', () {
      final spacing = tokens['spacing'] as Map<String, dynamic>;
      expect(SpacingTokens.x1, (spacing['grid'] as num).toDouble());
      expect(
        SpacingTokens.screenGutter,
        (spacing['screenGutter'] as num).toDouble(),
      );
      expect(
        SpacingTokens.cardPadding,
        (spacing['cardPadding'] as num).toDouble(),
      );
    });

    test('x2..x8 stay exact multiples of the brandkit grid', () {
      // The derived steps are not in the JSON, so a naive "assert every JSON
      // entry" would leave them unguarded — a hand-edit of x3 from 12 to 14
      // would break the 4pt rhythm silently (ADR-025 D5.ii's derived-spacing
      // rule). Multiples are the guarantee the brandkit actually states.
      final grid = ((tokens['spacing'] as Map<String, dynamic>)['grid'] as num)
          .toDouble();
      const steps = <int, double>{
        2: SpacingTokens.x2,
        3: SpacingTokens.x3,
        4: SpacingTokens.x4,
        5: SpacingTokens.x5,
        6: SpacingTokens.x6,
        8: SpacingTokens.x8,
      };
      steps.forEach((multiple, value) {
        expect(
          value,
          grid * multiple,
          reason: 'SpacingTokens.x$multiple must be $multiple x the 4pt grid',
        );
      });
    });
  });

  group('radius', () {
    test('card and sheet radii match, and chip is the stadium', () {
      final radius = tokens['radius'] as Map<String, dynamic>;
      expect(RadiusTokens.card, (radius['card'] as num).toDouble());
      expect(RadiusTokens.sheet, (radius['sheet'] as num).toDouble());
      expect(
        RadiusTokens.cardRadius,
        BorderRadius.circular((radius['card'] as num).toDouble()),
      );
      expect(
        RadiusTokens.sheetRadius,
        BorderRadius.circular((radius['sheet'] as num).toDouble()),
      );
      // `"chip": "full"` is a shape, not a number — the brandkit's word for a
      // stadium border. Asserted as a type so a future numeric radius on chips
      // fails instead of quietly rounding the brand's pill buttons.
      expect(radius['chip'], 'full');
      expect(RadiusTokens.stadium, isA<StadiumBorder>());
    });
  });

  group('the recorded non-assertions stay recorded', () {
    test('the four unasserted JSON groups are still present and unchanged', () {
      // These are NOT asserted against Dart (there is nothing to assert them
      // against — see the file header). What IS pinned is that they still exist
      // with the values ADR-025 D5.ii recorded, so that if the brand kit ever
      // gains a Dart counterpart — or if issue #63 resolves the icon question —
      // this test is the place that turns red and says so.
      final typography = tokens['typography'] as Map<String, dynamic>;
      expect(typography['minimumBodySize'], 14);
      expect(typography['dynamicTypeMax'], '130%');

      expect(
        tokens['iconography'],
        {'set': 'Phosphor', 'weight': 'rounded', 'grid': 24, 'stroke': 1.75},
        reason:
            'the brand kit still specifies Phosphor while the app ships '
            'Material icons — issue #63. When that is resolved, resolve this '
            'pin with it: either assert the icon set for real, or amend the '
            'brand kit. Do not simply delete this expectation.',
      );

      expect(tokens['rules'], isA<List<dynamic>>());
    });

    test('the brandkit version this parity mapping was written against', () {
      // A major brandkit revision should force a human to re-read the mapping
      // table in ADR-025 D5.ii rather than trust that it still holds.
      expect(
        tokens['version'],
        '1.0',
        reason:
            'the brand kit version changed — re-check ADR-025 D5.ii\'s '
            'JSON<->Dart mapping before bumping this pin',
      );
      expect(tokens['brand'], 'Hayati');
    });
  });
}
