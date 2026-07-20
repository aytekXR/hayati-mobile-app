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
    // ── The raised-surface family (ADR-025 slice 1) ──────────────────────────
    // Material 3 resolves component backgrounds through these slots, and an
    // UNSET slot does not fall back to something sensible — Flutter falls
    // `surfaceContainer*` back to `surface` and `inverseSurface` to
    // `onSurface` (color_scheme.dart). Before slice 1 only `Highest` was set,
    // which is the slot almost nothing reads: `AlertDialog` reads
    // `surfaceContainerHigh` (one word apart), `Card`/`BottomSheet` read
    // `surfaceContainerLow`. All three therefore rendered flat `night` — the
    // same value as the page behind them, i.e. no separation at all — while
    // `SnackBar` resolved `inverseSurface ?? onSurface` and rendered on `sand`,
    // a cream slab in a dark-first app.
    //
    // The brandkit assigns night.raised to "Cards, sheets" (§2/§4), so the
    // whole container family takes it: one raised tone, used consistently,
    // rather than a tonal ladder the brandkit does not define.
    surfaceContainerLowest: ColorTokens.nightRaised,
    surfaceContainerLow: ColorTokens.nightRaised,
    surfaceContainer: ColorTokens.nightRaised,
    surfaceContainerHigh: ColorTokens.nightRaised,
    surfaceContainerHighest: ColorTokens.nightRaised,
    // The inverse pair is what SnackBar reads. Keeping it inside the brand
    // (raised plum + sand) is the whole point: an "inverse" surface in a
    // dark-first app must not become a light-mode intrusion.
    inverseSurface: ColorTokens.nightRaised,
    onInverseSurface: ColorTokens.sand,
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
    // ── ADR-025 slice 1: the components the app actually mounts ─────────────
    // Only these. The slice deliberately does NOT add CardTheme,
    // BottomSheetThemeData or PopupMenuThemeData: `grep` finds zero `Card(`,
    // zero bottom sheets and zero popup menus in `lib/`, and theming a widget
    // the app never builds is dead configuration that reads as coverage. The
    // ColorScheme container family above already carries the right value for
    // all three the day one of them is used.
    //
    // The brandkit fixes no dialog/snackbar radius, so each takes the NEAREST
    // defined token, following the M1.4 precedent that mapped buttons to the
    // chip token and inputs to the card token (frontend-brandkit §10).
    dialogTheme: DialogThemeData(
      // A dialog is a sheet-scale surface -> the sheet token (24).
      backgroundColor: ColorTokens.nightRaised,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: RadiusTokens.sheetRadius,
      ),
      titleTextStyle: textTheme.titleLarge,
      contentTextStyle: textTheme.bodyMedium,
    ),
    snackBarTheme: SnackBarThemeData(
      // Card-scale surface -> the card token (16). Explicit background rather
      // than relying on inverseSurface, so a future ColorScheme edit cannot
      // silently return the snackbar to a light slab.
      backgroundColor: ColorTokens.nightRaised,
      contentTextStyle: textTheme.bodyMedium,
      shape: const RoundedRectangleBorder(
        borderRadius: RadiusTokens.cardRadius,
      ),
      behavior: SnackBarBehavior.floating,
    ),
    tooltipTheme: TooltipThemeData(
      // Used on three icon buttons (export copy, new conversation, settings
      // gear) — all inside the Navigator, never on the lock screen, where a
      // Tooltip has no Overlay to mount into (ADR-018 D3, sentinel-enforced).
      decoration: const BoxDecoration(
        color: ColorTokens.nightRaised,
        borderRadius: RadiusTokens.cardRadius,
      ),
      textStyle: textTheme.bodySmall,
    ),
  );
}
