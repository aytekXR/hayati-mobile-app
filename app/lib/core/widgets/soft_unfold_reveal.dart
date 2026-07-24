import 'package:flutter/material.dart';

import '../design_system/motion_tokens.dart';

/// Default testing handle on the [Opacity] the reveal animates, so a widget test
/// can read the climbing opacity mid-unfold. A caller may override it via
/// [SoftUnfoldReveal.opacityKey] — the daily-question reveal passes its own
/// `@visibleForTesting` `revealUnfoldOpacityKey` (defined in
/// `paired_home_screen.dart`), the pairing preview takes this default. The
/// [Transform.translate] is this Opacity's direct child, so a test reaches the
/// rise via `find.descendant(of: find.byKey(opacityKey), matching:
/// find.byType(Transform))` — the "gentle rise" half of §6 is proven, not just
/// the fade.
@visibleForTesting
const softUnfoldOpacityKey = ValueKey<String>('soft-unfold-opacity');

/// A one-shot "soft unfold" enter animation for a reveal moment: a fade plus a
/// gentle vertical rise, per brandkit §6 ("reveal moment = soft unfold …").
///
/// The single shared realisation of the §6 unfold, used by both reveal moments:
/// the pairing activation moment (the invitee's first sight of who invited them,
/// `partner_preview_screen.dart` `_ValidPreview`) and the daily-question reveal
/// (`paired_home_screen.dart`). Slice 2 first built it inline as `_RevealUnfold`
/// and slice 3 re-created it here rather than extract it, to keep slice 2's
/// goldens untouched mid-slice; issue #74 then folded the daily-reveal copy back
/// onto this one — still pixel-neutral, so no golden moved. Each caller pins its
/// own `@visibleForTesting` [opacityKey] so a test targets that surface's unfold
/// unambiguously (the daily reveal passes `revealUnfoldOpacityKey`, the pairing
/// preview takes [softUnfoldOpacityKey]).
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
  const SoftUnfoldReveal({
    super.key,
    required this.child,
    this.opacityKey = softUnfoldOpacityKey,
  });

  final Widget child;

  /// Key stamped on the animated [Opacity], so each reveal surface exposes its
  /// own `@visibleForTesting` seam. Defaults to [softUnfoldOpacityKey].
  final Key opacityKey;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: reduceMotion ? Duration.zero : MotionTokens.revealUnfold,
      curve: MotionTokens.enter,
      child: child,
      builder: (context, t, child) => Opacity(
        key: opacityKey,
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
