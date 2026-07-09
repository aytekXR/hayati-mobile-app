import 'package:flutter/material.dart';

import 'color_tokens.dart';
import 'radius_tokens.dart';
import 'spacing_tokens.dart';
import 'typography_tokens.dart';

/// The full dark brand [ThemeData], built from the token files ONLY (no color
/// or size literals live here). [languageCode] selects the per-script body
/// line-height in [TypographyTokens] (Arabic reads at 1.7, everything else at
/// 1.5), so callers rebuild the theme when the resolved locale changes.
///
/// MVP is dark-first, single theme (docs/mvp.md OUT list).
ThemeData hayatiTheme({required String languageCode}) {
  // Colour brand text with sand (sand-on-night 13.6:1 — well past the >=4.5
  // brandkit rule); displayColor covers the display/headline hero styles.
  final textTheme = TypographyTokens.textThemeFor(
    languageCode,
  ).apply(bodyColor: ColorTokens.sand, displayColor: ColorTokens.sand);

  // Manual dark scheme with the EXACT brand hexes — ColorScheme.fromSeed
  // detunes the palette, so the scheme is assembled by hand.
  const colorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: ColorTokens.pomegranate,
    // sand-on-pomegranate is 3.94:1 — BELOW the 4.5 bar. The brandkit only
    // mandates >=4.5 against night and defines no on-pomegranate token, so sand
    // is chosen as onPrimary and logged as a recorded brandkit gap
    // (docs/frontend-brandkit.md gap note, written in Stage 3).
    onPrimary: ColorTokens.sand,
    primaryContainer: ColorTokens.pomegranateDeep,
    // sand-on-pomegranateDeep 6.46:1 OK — deep is the selected-chip surface.
    onPrimaryContainer: ColorTokens.sand,
    secondary: ColorTokens.clay,
    onSecondary: ColorTokens.night,
    tertiary: ColorTokens.sage,
    onTertiary: ColorTokens.night,
    // alert-on-night 4.94:1 OK.
    error: ColorTokens.alert,
    onError: ColorTokens.night,
    surface: ColorTokens.night,
    onSurface: ColorTokens.sand,
    surfaceContainerHighest: ColorTokens.nightRaised,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: ColorTokens.night,
    // Both the resolved textTheme (styles already carry family + fallback) and
    // the ambient defaults use Rubik with the Noto fallback stack.
    fontFamily: TypographyTokens.family,
    fontFamilyFallback: TypographyTokens.fallback,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: ColorTokens.night,
      foregroundColor: ColorTokens.sand,
      elevation: 0,
      // h2 weight (20/w600) for the title.
      titleTextStyle: textTheme.titleLarge,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: ColorTokens.pomegranate,
        foregroundColor: ColorTokens.sand,
        // >=44dp touch target (frontend-brandkit §8); 48 keeps a comfortable
        // margin. Stadium (full) radius per the chip/button token.
        minimumSize: const Size.fromHeight(48),
        shape: RadiusTokens.stadium,
        // body-size w600.
        textStyle: textTheme.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        // pomegranate text on night is 3.45:1 — fails >=4.5, so link/secondary
        // labels use sand, never pomegranate.
        foregroundColor: ColorTokens.sand,
        shape: RadiusTokens.stadium,
        textStyle: textTheme.labelLarge,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: ColorTokens.nightRaised,
      border: const OutlineInputBorder(
        borderRadius: RadiusTokens.cardRadius,
        borderSide: BorderSide.none,
      ),
      // Labels/hints are sand at reduced opacity (still derived from onSurface).
      // The hint renders over the nightRaised fill, so its floor is the >=4.5:1
      // brandkit rule against THAT surface: 0.5 blends to 4.12:1 (fails), 0.6
      // blends to 5.29:1 (passes, and 6.01:1 against night).
      labelStyle: TextStyle(color: ColorTokens.sand.withValues(alpha: 0.7)),
      hintStyle: TextStyle(color: ColorTokens.sand.withValues(alpha: 0.6)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: ColorTokens.nightRaised,
      // Selected ChoiceChip surface — pomegranateDeep (sand-on-deep 6.46:1 OK).
      selectedColor: ColorTokens.pomegranateDeep,
      labelStyle: textTheme.bodyMedium,
      secondaryLabelStyle: textTheme.bodyMedium,
      shape: RadiusTokens.stadium,
      side: BorderSide.none,
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.x3,
        vertical: SpacingTokens.x2,
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: ColorTokens.pomegranate,
    ),
  );
}
