import 'package:flutter/material.dart';

import 'color_tokens.dart';
import 'elevation_tokens.dart';
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
    // moonlight-on-pomegranate 4.7:1 — the redesign's dedicated on-accent
    // token (ui-ux §9.1) closes the recorded brandkit gap 1 (sand was 3.94:1,
    // an AA failure).
    onPrimary: ColorTokens.moonlight,
    primaryContainer: ColorTokens.pomegranateDeep,
    // moonlight-on-pomegranateDeep 7.5:1 — selected chips carry the Moonlight
    // label per ui-ux §9.4.
    onPrimaryContainer: ColorTokens.moonlight,
    secondary: ColorTokens.clay,
    onSecondary: ColorTokens.night,
    tertiary: ColorTokens.sage,
    onTertiary: ColorTokens.night,
    // alert-on-night 4.94:1 OK.
    error: ColorTokens.alert,
    onError: ColorTokens.night,
    surface: ColorTokens.night,
    onSurface: ColorTokens.sand,
    // Secondary text (M3 ListTile subtitles, supporting text) — Mist, 7.9:1
    // on night / 7.0:1 on nightRaised; kills the Material-grey leak recorded
    // as gap #67. Boundaries (M3 Divider reads outlineVariant, focus/borders
    // read outline) — Veil, a deliberately quiet non-text role (ui-ux §9.1).
    onSurfaceVariant: ColorTokens.mist,
    outline: ColorTokens.veil,
    outlineVariant: ColorTokens.veil,
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
        // Moonlight on pomegranate 4.7:1 (ui-ux §9.4 "all CTAs") — closes the
        // recorded AA failure (sand was 3.94:1, brandkit §10 gap 1).
        foregroundColor: ColorTokens.moonlight,
        // Disabled: Night Raised fill, Mist label (ui-ux §9.4) — never
        // Material's onSurface-at-opacity grey.
        disabledBackgroundColor: ColorTokens.nightRaised,
        disabledForegroundColor: ColorTokens.mist,
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
        // Rose 6.8:1 on night (ui-ux §9.1) — links/TextButtons finally read as
        // links: color PLUS the labelLarge w600 weight, never color alone.
        // (pomegranate itself stays a fill/accent — 3.45:1 as text, gap 2.)
        foregroundColor: ColorTokens.rose,
        shape: RadiusTokens.stadium,
        textStyle: textTheme.labelLarge,
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: ColorTokens.nightRaised,
      // ui-ux §9.4 inputs: Veil hairline at rest -> 2dp pomegranate when
      // focused; error carries the Alert line. The base `border` keeps the
      // card radius as the shared shape.
      border: OutlineInputBorder(
        borderRadius: RadiusTokens.cardRadius,
        borderSide: BorderSide(color: ColorTokens.veil),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: RadiusTokens.cardRadius,
        borderSide: BorderSide(color: ColorTokens.veil),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: RadiusTokens.cardRadius,
        borderSide: BorderSide(color: ColorTokens.pomegranate, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: RadiusTokens.cardRadius,
        borderSide: BorderSide(color: ColorTokens.alert),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: RadiusTokens.cardRadius,
        borderSide: BorderSide(color: ColorTokens.alert, width: 2),
      ),
      // Labels/hints in Mist (ui-ux §9.4). The hint renders over the
      // nightRaised fill, so its floor is the >=4.5:1 brandkit rule against
      // THAT surface: mist-on-nightRaised is 7.0:1 (and 7.9:1 against night)
      // — comfortably past the bar the old sand-alpha blends scraped.
      labelStyle: TextStyle(color: ColorTokens.mist),
      hintStyle: TextStyle(color: ColorTokens.mist),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: ColorTokens.nightRaised,
      // Selected ChoiceChip surface — pomegranateDeep with a Moonlight label
      // (7.5:1; ui-ux §9.4 "no checkmarks" — the fill is the signal, and the
      // label color shift keeps color from being the sole signal's partner).
      selectedColor: ColorTokens.pomegranateDeep,
      labelStyle: textTheme.bodyMedium?.copyWith(
        color: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? ColorTokens.moonlight
              : ColorTokens.sand,
        ),
      ),
      secondaryLabelStyle: textTheme.bodyMedium?.copyWith(
        color: ColorTokens.moonlight,
      ),
      shape: RadiusTokens.stadium,
      // Veil hairline on the resting chip; the selected fill needs no border
      // (ui-ux §9.4 "Night Raised + Veil border -> selected Pomegranate Deep
      // fill + Moonlight label").
      side: WidgetStateBorderSide.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? BorderSide.none
            : const BorderSide(color: ColorTokens.veil),
      ),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.x3,
        vertical: SpacingTokens.x2,
      ),
    ),
    // Veil hairlines (ui-ux §9.1) — the app finally has a divider color that
    // is not Material grey. M3 `Divider` also reads outlineVariant; both point
    // at the same token so the explicit theme is documentation, not override.
    dividerTheme: const DividerThemeData(
      color: ColorTokens.veil,
      thickness: 1,
    ),
    // Tile glyphs/chevrons in Clay — the kept secondary-icon role (ui-ux
    // §9.4). Without this, M3 ListTile icons would follow onSurfaceVariant
    // into Mist, conflating the icon role with secondary TEXT. Subtitles are
    // deliberately NOT pinned here: they inherit Mist via onSurfaceVariant.
    listTileTheme: const ListTileThemeData(iconColor: ColorTokens.clay),
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
      // ui-ux §9.3 Level 2 (sheets/dialogs), Material-approximated: Material
      // derives blur/offset from `elevation`, so only the plum tint is exact
      // here — widgets that own their decoration use
      // `ElevationTokens.level2` directly for the y6/blur24/36% spec.
      elevation: 6,
      shadowColor: ElevationTokens.shadowBase,
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
