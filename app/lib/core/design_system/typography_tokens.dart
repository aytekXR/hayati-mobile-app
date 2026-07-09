import 'package:flutter/material.dart';

/// Typography tokens from docs/frontend-brandkit.md / hayati-tokens.json v1.0.
///
/// Type scale: display 32/w700, h1 24/w700, h2 20/w600, body 16/w400,
/// caption 13/w400 (minimum body 14). Family [family] with [fallback]
/// (Noto Sans for Latin/Turkish, Noto Sans Arabic for Arabic glyphs Rubik
/// lacks). The ONLY line-heights the brandkit fixes are for body + caption and
/// they are per-script: 1.5 latin / 1.7 arabic. It specifies NO heading
/// line-height, so headings deliberately keep the font default (no `height:`)
/// rather than an invented value.
abstract final class TypographyTokens {
  static const String family = 'Rubik';
  static const List<String> fallback = ['Noto Sans', 'Noto Sans Arabic'];

  static const FontWeight regular = FontWeight.w400;
  static const FontWeight semiBold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;

  /// Body + caption line-heights (the only heights the brandkit fixes).
  static const double bodyHeightLatin = 1.5;
  static const double bodyHeightArabic = 1.7;

  /// Arabic ('ar') reads at 1.7 line-height; every other script at 1.5.
  static double bodyHeightFor(String languageCode) =>
      languageCode == 'ar' ? bodyHeightArabic : bodyHeightLatin;

  /// The brand [TextTheme] for [languageCode]. Body + caption styles carry the
  /// per-script line-height; headings keep the font default height.
  ///
  /// Material-role mapping (chosen so the EXISTING screen lookups land on
  /// sensible brand sizes):
  ///   displaySmall / headlineLarge = display 32/w700 (hero wordmark)
  ///   headlineMedium               = h1      24/w700 (screen titles)
  ///   titleLarge                   = h2      20/w600 (error titles)
  ///   titleMedium                  = body-emphasis 16/w600 (section labels)
  ///   bodyLarge / bodyMedium       = body    16/w400 (per-script height)
  ///   bodySmall                    = caption 13/w400 (per-script height)
  ///   labelLarge                   = button label 16/w600
  static TextTheme textThemeFor(String languageCode) {
    final bodyHeight = bodyHeightFor(languageCode);
    return TextTheme(
      displaySmall: _heading(32, bold),
      headlineLarge: _heading(32, bold),
      headlineMedium: _heading(24, bold),
      titleLarge: _heading(20, semiBold),
      titleMedium: _heading(16, semiBold),
      bodyLarge: _body(16, regular, bodyHeight),
      bodyMedium: _body(16, regular, bodyHeight),
      bodySmall: _body(13, regular, bodyHeight),
      labelLarge: _heading(16, semiBold),
    );
  }

  /// Heading style: no `height:` — the brandkit fixes no heading line-height.
  static TextStyle _heading(double size, FontWeight weight) => TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    fontSize: size,
    fontWeight: weight,
  );

  static TextStyle _body(double size, FontWeight weight, double height) =>
      TextStyle(
        fontFamily: family,
        fontFamilyFallback: fallback,
        fontSize: size,
        fontWeight: weight,
        height: height,
      );
}
