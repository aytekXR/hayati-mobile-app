import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/core/design_system/color_tokens.dart';
import 'package:hayati_app/core/design_system/hayati_theme.dart';

/// ADR-025 slice 1 — the Material default floor.
///
/// THE DEFECT (verified against the installed SDK before the fix): Material 3
/// resolves component backgrounds through `ColorScheme` slots, and an UNSET
/// slot does not fall back to something sensible. Flutter falls
/// `surfaceContainer*` back to `surface` and `inverseSurface` back to
/// `onSurface` (`color_scheme.dart`). `hayatiTheme` set only
/// `surfaceContainerHighest` — the slot almost nothing reads — so:
///
///   * `AlertDialog` reads `surfaceContainerHigh` (one word apart) -> `night`,
///     the SAME value as the page behind it: no separation at all. The three
///     dialogs affected are the app's most consequential confirmations — the
///     biometric shared-device warning, the irreversible-delete confirmation,
///     and the consent-withdrawal dialog.
///   * `Card` / `BottomSheet` read `surfaceContainerLow` -> `night`, same.
///   * `SnackBar` reads `inverseSurface` -> `?? onSurface` -> **`sand`**, a
///     cream slab in a dark-first app.
///
/// WHY A TEST AND NOT A GOLDEN: dialogs and snackbars are transient. They mount
/// above the screen, so no golden in the 303-file matrix captures ANY of them —
/// which is exactly why this defect survived from M1.4 to now with a full
/// golden net in place. A widget test that pumps the real thing and reads back
/// the resolved colour is the mechanism the golden matrix structurally cannot
/// provide.
///
/// If this test fails, a `ColorScheme` slot was dropped or re-pointed. Do not
/// re-stamp it against whatever the new value is — check first whether a
/// surface has gone back to rendering flat against its own background.
void main() {
  final theme = hayatiTheme(languageCode: 'en');
  final scheme = theme.colorScheme;

  group('no component resolves a background through an unset slot', () {
    test('every surface-container slot is the brandkit raised tone', () {
      // The whole family, because M3 components read different members of it
      // and the brandkit defines ONE raised tone ("Cards, sheets", §2/§4)
      // rather than a tonal ladder.
      expect(scheme.surfaceContainerLowest, ColorTokens.nightRaised);
      expect(scheme.surfaceContainerLow, ColorTokens.nightRaised);
      expect(scheme.surfaceContainer, ColorTokens.nightRaised);
      expect(scheme.surfaceContainerHigh, ColorTokens.nightRaised);
      expect(scheme.surfaceContainerHighest, ColorTokens.nightRaised);
    });

    test('no container slot silently equals surface (the original defect)', () {
      // The regression that WAS shipping: an unset slot falls back to
      // `surface`, so a raised surface renders flat against the page. Asserting
      // "not equal to surface" catches it even if the raised tone is later
      // re-pointed to some other brand colour.
      for (final container in <Color>[
        scheme.surfaceContainerLowest,
        scheme.surfaceContainerLow,
        scheme.surfaceContainer,
        scheme.surfaceContainerHigh,
        scheme.surfaceContainerHighest,
      ]) {
        expect(
          container,
          isNot(scheme.surface),
          reason:
              'a raised surface that equals `surface` has no separation from '
              'the page behind it — this is the defect ADR-025 slice 1 fixed',
        );
      }
    });

    test('the inverse pair stays inside the dark brand', () {
      // `inverseSurface ?? onSurface` was resolving to `sand`. In a dark-first
      // app the "inverse" surface must not become a light-mode intrusion.
      expect(scheme.inverseSurface, ColorTokens.nightRaised);
      expect(scheme.onInverseSurface, ColorTokens.sand);
      expect(
        scheme.inverseSurface,
        isNot(scheme.onSurface),
        reason:
            'inverseSurface falling back to onSurface is the cream-slab bug',
      );
    });
  });

  group('the transient surfaces no golden can capture', () {
    testWidgets('an AlertDialog renders on the raised tone, not the page', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const AlertDialog(content: Text('x')),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final dialog = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(dialog.color, ColorTokens.nightRaised);
      expect(
        dialog.color,
        isNot(ColorTokens.night),
        reason:
            'the biometric warning, the delete confirmation and the consent '
            'withdrawal all render through this — flat-on-flat is the defect',
      );
    });

    testWidgets('a SnackBar renders on the raised tone, not on sand', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('copied'))),
                child: const Text('copy'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('copy'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 750));

      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(SnackBar),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.color, ColorTokens.nightRaised);
      expect(
        material.color,
        isNot(ColorTokens.sand),
        reason: 'the export screen\'s "copied" bar was a cream slab',
      );
    });
  });

  group('the sub-themes cover exactly the components the app mounts', () {
    test('dialog, snackbar and tooltip carry brand shape and typography', () {
      expect(theme.dialogTheme.backgroundColor, ColorTokens.nightRaised);
      expect(theme.snackBarTheme.backgroundColor, ColorTokens.nightRaised);

      // Compared property-by-property rather than by object equality:
      // `ThemeData` merges a debugLabel and a decoration colour into the
      // TextTheme it exposes, so the style read back is never `==` the style
      // handed in even when it is the same brand step.
      final title = theme.dialogTheme.titleTextStyle;
      expect(title?.fontSize, theme.textTheme.titleLarge?.fontSize);
      expect(title?.fontWeight, theme.textTheme.titleLarge?.fontWeight);
      expect(title?.fontFamily, theme.textTheme.titleLarge?.fontFamily);

      expect(
        (theme.tooltipTheme.decoration as BoxDecoration?)?.color,
        ColorTokens.nightRaised,
      );
    });

    test('unused components are deliberately NOT themed', () {
      // `grep` finds zero `Card(`, zero bottom sheets and zero popup menus in
      // lib/. Theming a widget the app never builds is dead configuration that
      // reads as coverage — and the ColorScheme family above already carries
      // the right value the day one of them IS used. If this test fails
      // because a sub-theme was added, first check whether the widget is now
      // actually mounted; if it is, this expectation is what should change.
      expect(theme.cardTheme.color, isNull);
      expect(theme.bottomSheetTheme.backgroundColor, isNull);
      expect(theme.popupMenuTheme.color, isNull);
    });
  });
}
