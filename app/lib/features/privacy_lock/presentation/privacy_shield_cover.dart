import 'package:flutter/material.dart';

import '../../../core/design_system/color_tokens.dart';

/// The app-switcher snapshot shield (ADR-018 Decision 5 — closing ADR-017's
/// deferral). Raised by [PrivacyGuard] on `inactive` / `hidden` / `paused`, so
/// it is painted BEFORE iOS images the view for the app-switcher card, and
/// dropped on `resumed`. Always on, for every user, free tier included: the
/// daily answer on the paired home is exactly as intimate as a coach reply, and
/// a per-surface list would re-litigate that forever.
///
/// **DELIBERATELY NEUTRAL — no brand mark, no logo, no text, no content (review
/// finding DVUX-4). Do not "improve" this by painting the Hayati mark here.**
/// The app-switcher card is a surface a snooping partner scans; a brand mark on
/// it would re-identify the app for exactly the user who chose the discreet icon
/// (Decision 6). Content-hiding must not trade for identity-leaking. A plain
/// fill is the whole design.
///
/// Pure Dart on purpose (Decision 5): a native `sceneWillResignActive` cover
/// would duplicate the mechanism at the same lifecycle moment behind an
/// untestable seam. It is the recorded escalation if the device check ever
/// catches content in the switcher — not shipped speculatively.
class PrivacyShieldCover extends StatelessWidget {
  const PrivacyShieldCover({super.key});

  @override
  Widget build(BuildContext context) =>
      const ColoredBox(color: ColorTokens.night);
}
