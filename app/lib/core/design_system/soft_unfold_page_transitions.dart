import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'motion_tokens.dart';

/// The Soft Unfold route transition (redesign QW-10, ui-ux §11 `unfoldSoft`):
/// the same fade-plus-gentle-rise verb [SoftUnfoldReveal] gives a widget, spent
/// on a whole page arriving. 240ms, ease-out, a 12dp rise — all read from
/// [MotionTokens], so the route transition and the in-page unfold can never
/// drift apart.
///
/// **Vertical only, so RTL needs nothing.** A horizontal slide would have to be
/// mirrored for Arabic; a rise is direction-neutral by construction, which is
/// why `tool/rtl_lint.dart` has no opinion about this file. Same reasoning as
/// `SoftUnfoldReveal`'s.
///
/// **Reduce-motion returns the child unwrapped.** `MediaQuery.disableAnimations`
/// is advisory in Flutter — the framework does not zero a route's transition for
/// you — so the honest reading of "collapses to instant" is: no fade, no rise,
/// the page renders settled from its first frame. The route still *technically*
/// runs its [transitionDuration], but nothing on screen moves during it, and an
/// opaque page occludes the one behind it immediately. Pinned by
/// `soft_unfold_page_transitions_test.dart`.
///
/// ## Why iOS and macOS deliberately do NOT get this
///
/// The roadmap says "unfold everywhere". Taken literally that is a regression on
/// the platform this app ships to first, and the reason is not obvious from the
/// theme: on iOS the interactive **edge-swipe-back gesture is supplied by the
/// page transitions builder itself**, not by the route. Flutter builds it inside
/// `CupertinoRouteTransitionMixin.buildPageTransitions`, which wraps the child in
/// a private `_CupertinoBackGestureDetector` — a class no third-party builder can
/// reach. So replacing [CupertinoPageTransitionsBuilder] does not merely restyle
/// the transition; it silently deletes swipe-to-go-back, and nothing in the test
/// suite or the goldens would notice.
///
/// Trading a native navigation affordance for a 240ms brand flourish is a bad
/// trade on an iOS-first product (ADR-006), so [softUnfoldPageTransitionsTheme]
/// installs this builder on the platforms where it costs nothing and leaves
/// Cupertino in place on iOS and macOS. The brand's motion budget on iOS is
/// spent where the redesign actually wants it — the reveal (`RevealChoreography`),
/// which is the one choreography this product buys.
class SoftUnfoldPageTransitionsBuilder extends PageTransitionsBuilder {
  const SoftUnfoldPageTransitionsBuilder();

  /// 240ms, from the same token the in-page unfold uses — not Material's 300ms
  /// default, which sits outside brandkit §6's 150–300ms band at its ceiling.
  @override
  Duration get transitionDuration => MotionTokens.revealUnfold;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        // `animation.value` is the route's linear 0→1 (and 1→0 on pop); the
        // curve is applied here rather than through a CurvedAnimation so this
        // builder owns no disposable animation object.
        final t = MotionTokens.enter.transform(animation.value);
        return Opacity(
          opacity: t,
          // The arriving page stays in the semantics tree for the whole
          // transition, so a screen reader never loses the screen mid-unfold.
          alwaysIncludeSemantics: true,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * MotionTokens.revealSlide),
            child: child,
          ),
        );
      },
    );
  }
}

/// The app's [PageTransitionsTheme]: Soft Unfold everywhere Flutter's own
/// builder is not carrying a platform gesture, Cupertino on iOS and macOS.
/// See the class doc above for why that exception is deliberate.
const PageTransitionsTheme softUnfoldPageTransitionsTheme =
    PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.android: SoftUnfoldPageTransitionsBuilder(),
        TargetPlatform.fuchsia: SoftUnfoldPageTransitionsBuilder(),
        TargetPlatform.linux: SoftUnfoldPageTransitionsBuilder(),
        TargetPlatform.windows: SoftUnfoldPageTransitionsBuilder(),
        // iOS + macOS keep CupertinoPageTransitionsBuilder — it is the only
        // supplier of edge-swipe-back.
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      },
    );
