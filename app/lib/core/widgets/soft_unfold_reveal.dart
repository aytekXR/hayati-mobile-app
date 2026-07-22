import 'package:flutter/material.dart';

import '../design_system/motion_tokens.dart';

/// Testing handle on the [Opacity] the reveal animates, so a widget test can
/// read the climbing opacity mid-unfold (mirrors the `@visibleForTesting`
/// `revealUnfoldOpacityKey` defined in `paired_home_screen.dart`). The
/// [Transform.translate]
/// is this Opacity's direct child, so a test reaches the rise via
/// `find.descendant(of: find.byKey(softUnfoldOpacityKey), matching:
/// find.byType(Transform))` — the "gentle rise" half of §6 is proven, not just
/// the fade.
@visibleForTesting
const softUnfoldOpacityKey = ValueKey<String>('soft-unfold-opacity');

/// A one-shot "soft unfold" enter animation for a reveal moment: a fade plus a
/// gentle vertical rise, per brandkit §6 ("reveal moment = soft unfold …").
///
/// This is the shared realisation of the pattern slice 2 built inline as
/// `_RevealUnfold` for the daily-question reveal (`paired_home_screen.dart`);
/// slice 3 reuses it for the pairing activation moment (the invitee's first
/// sight of who invited them, `partner_preview_screen.dart` `_ValidPreview`).
/// It is deliberately a NEW widget rather than an extraction of `_RevealUnfold`:
/// touching slice 2's surface risks its goldens, and the two files can be DRYed
/// in a later tidy without pixel risk (tracked as issue #74). The ~15 lines
/// of shared shape are recorded, not smuggled.
///
/// Motion values come from [MotionTokens] (§6's 150–300ms band, ease-out
/// entering). The slide is VERTICAL-only, so it is direction-neutral and needs
/// no RTL mirror variant. Reduce-motion → [Duration.zero]: the child appears
/// settled, no fade, no rise. At rest it is pixel-neutral — `Opacity(1)` and
/// `Transform.translate(Offset.zero)` both hit Flutter's no-op fast paths — so
/// it changes NO settled golden. `alwaysIncludeSemantics` keeps the child in the
/// semantics tree from the first frame, so a screen reader never loses it
/// mid-unfold (Appendix A, "screen-reader order matches visual order").
class SoftUnfoldReveal extends StatelessWidget {
  const SoftUnfoldReveal({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: reduceMotion ? Duration.zero : MotionTokens.revealUnfold,
      curve: MotionTokens.enter,
      child: child,
      builder: (context, t, child) => Opacity(
        key: softUnfoldOpacityKey,
        opacity: t,
        alwaysIncludeSemantics: true,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * MotionTokens.revealSlide),
          child: child,
        ),
      ),
    );
  }
}
