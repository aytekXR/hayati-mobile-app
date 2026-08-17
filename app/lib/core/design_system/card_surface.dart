import 'package:flutter/material.dart';

import 'elevation_tokens.dart';
import 'radius_tokens.dart';

/// The ONE definition of a raised card surface (ADR-052, issue #175).
///
/// WHY THIS EXISTS. Before it, "raised" had one definition in the tokens and
/// **fourteen implementations** in the features — counted, not estimated: 14
/// card-shaped `BoxDecoration`s on `surfaceContainerHighest`, of which **4**
/// carried [ElevationTokens.level1] and **10** carried no shadow at all. Those
/// ten separated from the page by a `nightRaised`-vs-`night` colour step of
/// about 1.3:1 and read as flat panels of a slightly different colour, while the
/// token that defines what raised MEANS in this product (ui-ux §9.3, plum, never
/// black — the brandkit assigns it to "Cards, sheets") reached four of them.
///
/// **The defect was not that ten values were wrong; it was that there were
/// fourteen.** Ten happened to be missing a line, and the eleventh surface
/// anyone wrote would have copied whichever neighbour they were looking at.
///
/// **Why a function and not a `CardThemeData`.** ADR-025 D1 refused a card theme
/// because `grep` finds **zero constructed `Card(`** in `lib/` — this app builds
/// `Container`s — and theming a widget nobody builds is dead configuration that
/// reads as coverage. That decision stands. A function is not a lesser theme: it
/// is the form that matches how these surfaces are actually built, and unlike a
/// `CardTheme` it can be *called* from the `Container` that needs it.
///
/// **It takes a [ThemeData], not a [BuildContext]**, because that is what every
/// call site already holds: all fourteen migrated decorations read
/// `theme.colorScheme.surfaceContainerHighest` from a local `theme`, and one of
/// them (`_cardDecoration` in the paired home) is a top-level function with no
/// context at all. A context-taking signature would have forced that one to keep
/// its inline decoration — the same first-hole problem the `border` parameter
/// avoids. `hayatiTheme` is memoized per language code (ADR-039 D7) either way.
///
/// ⚠️ A new card surface belongs here, not in a feature file.
/// `card_surface_sentinel_test.dart` fails the build if a `BoxDecoration` naming
/// `surfaceContainerHighest` appears under `lib/features/` — the point is not
/// that today's ten values are right but that tomorrow's eleventh inherits
/// instead of copying.
BoxDecoration raisedCardDecoration(
  ThemeData theme, {
  BorderRadiusGeometry? borderRadius,
  BoxBorder? border,
}) {
  return BoxDecoration(
    color: theme.colorScheme.surfaceContainerHighest,
    borderRadius: borderRadius ?? RadiusTokens.cardRadius,
    // `border` is a real parameter and not an oversight: `PrivacySpotlightCard`
    // already carried `Border.all(outlineVariant)` on top of the same surface,
    // radius and elevation. Without it that card would have kept its inline
    // decoration and the sentinel above would have needed its first exception —
    // which is how a rule acquires its first hole.
    border: border,
    boxShadow: ElevationTokens.level1,
  );
}
