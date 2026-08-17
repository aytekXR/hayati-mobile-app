import 'package:flutter/material.dart';

import '../design_system/color_tokens.dart';
import '../design_system/motion_tokens.dart';

/// Default testing handle on the pair group's [Opacity] (the beat-1
/// crossfade) — the same seam contract as `SoftUnfoldReveal.opacityKey` (a
/// caller may override it; the daily reveal passes its
/// `revealUnfoldOpacityKey`).
@visibleForTesting
const revealChoreographyOpacityKey = ValueKey<String>(
  'reveal-choreography-opacity',
);

/// Testing handle on the partner card's beat-1 entry [Opacity], so a test can
/// sample the unfold-toward mid-flight independently of the group fade.
@visibleForTesting
const revealPartnerEntryKey = ValueKey<String>('reveal-partner-entry');

/// Testing handle on the falling seed of beat 3 (mounted only mid-drop — the
/// overlay is empty before the beat and after the seed merges into the strip).
@visibleForTesting
const revealSeedDropKey = ValueKey<String>('reveal-seed-drop');

/// The live handles of the three-beat timeline, handed to
/// [RevealChoreography.builder] every frame so the caller can compose the
/// reveal surface freely — the streak strip (beat 3's target) sits ABOVE the
/// question card in the redesigned layout, outside the pair's fade group, so
/// the choreography cannot own the whole column itself.
class RevealBeats {
  const RevealBeats._({
    required this.fade,
    required this.settle,
    required this.seedDrop,
    required this.done,
  });

  /// Beat 1 `unfoldReveal`: the pair group's crossfade AND the partner card's
  /// entry share this window (0–300ms, easeOut).
  final Animation<double> fade;

  /// Beat 2 `settlePair`: both cards settle as a pair (300–480ms, easeOut).
  final Animation<double> settle;

  /// Beat 3 `seedDrop`: linear progress across 480–900ms — [SeedDropOverlay]
  /// applies the spring character ([MotionTokens.seedDropCurve]) to the fall.
  final Animation<double> seedDrop;

  /// True once the timeline has completed (or collapsed under reduce-motion):
  /// [RevealPairGroup] and [RevealPartnerEntry] retire their transforms so the
  /// settled tree is pixel-neutral.
  final bool done;
}

/// Builds the reveal surface for the current beat values.
typedef RevealBuilder =
    Widget Function(BuildContext context, RevealBeats beats);

/// The reveal three-beat choreography (redesign ui-ux §11, creative-assets
/// §7.2) — the product's ONE choreography budget, owner of the timeline where
/// the mutual reveal renders (the paired home's revealed state):
///
///   Beat 1 `unfoldReveal` (300ms): the partner's card unfolds toward yours —
///     it enters from the partner-slot position below with a subtle 3D fold
///     flattening at the meeting edge ([RevealPartnerEntry]), while the answer
///     pair crossfades in ([RevealPairGroup]).
///   Beat 2 `settlePair` (180ms): both cards settle as a pair — one
///     simultaneous 2dp settle. [onSettle] fires as the settle lands: the
///     caller hooks the single light haptic here (kept, sacred).
///   Beat 3 `seedDrop` (420ms): one seed drops into the streak strip's vessel
///     ([SeedDropOverlay]), gentle spring, overshoot ≤4dp.
///
/// Total 900ms — inside the ≤1.2s budget pinned by `motion_tokens_test.dart`.
/// Reduce-motion collapses the whole sequence to an instant crossfade with
/// [onSettle] (the haptic) preserved. At rest the tree is pixel-neutral: the
/// pair [Opacity] sits at 1 (Flutter's no-op fast path), every transform is
/// retired, and the seed overlay renders nothing — so a settled golden is
/// byte-identical to a never-animated layout.
///
/// RTL: every motion vector is vertical (the cards stack as a pair, the seed
/// falls), so the choreography is direction-neutral by construction; the only
/// horizontal placement (the seed's landing point) resolves through
/// [SeedDropOverlay.alignment], an [AlignmentDirectional] — mirrored by the
/// ambient [Directionality], never a physical left/right.
class RevealChoreography extends StatefulWidget {
  const RevealChoreography({super.key, required this.builder, this.onSettle});

  /// Composes the reveal surface — typically: the streak strip wired to
  /// `beats.seedDrop`, the question card (outside the fade — it was already
  /// on screen pre-reveal), then a [RevealPairGroup] holding the own card and
  /// a [RevealPartnerEntry]-wrapped partner card.
  final RevealBuilder builder;

  /// Fired exactly once per mount, the moment beat 2's settle lands (or
  /// immediately under reduce-motion — the haptic is preserved when the
  /// animation is not). The caller owns any at-most-once-per-day guard.
  final VoidCallback? onSettle;

  /// The full three-beat span: 300 + 180 + 420 = 900ms (≤1.2s budget).
  static final Duration total =
      MotionTokens.revealBeatUnfold +
      MotionTokens.revealBeatSettle +
      MotionTokens.revealBeatSeedDrop;

  @override
  State<RevealChoreography> createState() => _RevealChoreographyState();
}

class _RevealChoreographyState extends State<RevealChoreography>
    with SingleTickerProviderStateMixin {
  static final double _beat1End =
      MotionTokens.revealBeatUnfold.inMilliseconds /
      RevealChoreography.total.inMilliseconds;
  static final double _beat2End =
      (MotionTokens.revealBeatUnfold + MotionTokens.revealBeatSettle)
          .inMilliseconds /
      RevealChoreography.total.inMilliseconds;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: RevealChoreography.total,
  );

  /// Beat 1: the pair's crossfade + the partner card's entry window.
  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Interval(0, _beat1End, curve: MotionTokens.enter),
  );

  /// Beat 2: both cards settle as a pair.
  late final Animation<double> _settle = CurvedAnimation(
    parent: _controller,
    curve: Interval(_beat1End, _beat2End, curve: MotionTokens.enter),
  );

  /// Beat 3's raw progress — [SeedDropOverlay] applies the spring character.
  late final Animation<double> _seedDrop = CurvedAnimation(
    parent: _controller,
    curve: Interval(_beat2End, 1),
  );

  bool _started = false;
  bool _settleFired = false;

  void _fireSettle() {
    if (_settleFired) return;
    _settleFired = true;
    widget.onSettle?.call();
  }

  void _onTick() {
    if (_controller.value >= _beat2End) _fireSettle();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      // Reduce-motion: the sequence collapses to an instant crossfade — the
      // composition appears settled on the first frame; the haptic hook is
      // PRESERVED (ui-ux §8: the reveal must remain feelable without motion).
      _controller.value = 1;
      _fireSettle();
    } else {
      _controller.addListener(_onTick);
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => widget.builder(
        context,
        RevealBeats._(
          fade: _fade,
          settle: _settle,
          seedDrop: _seedDrop,
          done: _controller.isCompleted,
        ),
      ),
    );
  }
}

/// Beats 1+2 over the answer PAIR: the crossfade in (beat 1) and the shared
/// 2dp settle (beat 2 — the pair rides 2dp high through the unfold, then
/// lands together; the landing is what [RevealChoreography.onSettle] makes
/// feelable). At rest: [Opacity] 1 (no-op fast path) and the translate is
/// retired — pixel-neutral.
///
/// `alwaysIncludeSemantics` keeps both answers REACHABLE in the semantics tree
/// from the first frame, so a screen reader never loses them mid-unfold.
///
/// ⚠️ This comment used to add "the reveal announces as one event", and until
/// ADR-051 **nothing announced anything** — `grep -rn "liveRegion\|SemanticsService"
/// app/lib` returned zero hits (issue #174). Reachability and announcement are
/// different guarantees, and only the first was ever built here. The second now
/// lives where the haptic does: `PairedHomeScreen._signalReveal`, fired by
/// [RevealChoreography.onSettle] at beat 2, once per reveal.
class RevealPairGroup extends StatelessWidget {
  const RevealPairGroup({
    super.key,
    required this.beats,
    required this.child,
    this.opacityKey = revealChoreographyOpacityKey,
  });

  final RevealBeats beats;

  /// The pair column: own card, gap, [RevealPartnerEntry]-wrapped partner card.
  final Widget child;

  /// Key stamped on the pair [Opacity], so each reveal surface exposes its own
  /// `@visibleForTesting` seam.
  final Key opacityKey;

  /// Beat 2's simultaneous pair settle distance (creative-assets §7.2: "2dp
  /// settle").
  static const double settleLift = 2;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      key: opacityKey,
      opacity: beats.fade.value,
      alwaysIncludeSemantics: true,
      child: beats.done
          ? child
          : Transform.translate(
              offset: Offset(0, -settleLift * (1 - beats.settle.value)),
              child: child,
            ),
    );
  }
}

/// Beat 1 over the partner card alone: it enters from the partner-slot
/// position below (rising toward its pair) with a subtle 3D fold flattening
/// at the meeting edge — the fold-line is the card's top edge, where it meets
/// the own card above, so the axis is horizontal and the motion is
/// direction-neutral (no RTL variant needed). Retired entirely at rest.
class RevealPartnerEntry extends StatelessWidget {
  const RevealPartnerEntry({
    super.key,
    required this.beats,
    required this.child,
  });

  final RevealBeats beats;
  final Widget child;

  /// The entry rise: the card starts this far below its rest position.
  static const double entryRise = 24;

  /// The fold: the subtle 3D flattening, in radians (≈17° — "subtle", not a
  /// full page-turn).
  static const double foldAngle = 0.3;

  @override
  Widget build(BuildContext context) {
    if (beats.done) return child;
    final t = beats.fade.value;
    return Opacity(
      key: revealPartnerEntryKey,
      opacity: t,
      alwaysIncludeSemantics: true,
      child: Transform(
        alignment: Alignment.topCenter,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0015)
          ..translateByDouble(0, (1 - t) * entryRise, 0, 1)
          ..rotateX((1 - t) * foldAngle),
        child: child,
      ),
    );
  }
}

/// Beat 3 realised over the streak strip's vessel: a single seed materialises
/// 24dp above [child], falls with the sanctioned gentle spring
/// ([MotionTokens.seedDropCurve], overshoot ≈2.4dp ≤ the 4dp budget) and
/// merges into the strip as it lands — the landed seed is the vessel's own
/// render (the server streak is the count of record; the client never
/// anticipates it), so the overlay ends empty and the rest frame is
/// pixel-neutral.
class SeedDropOverlay extends StatelessWidget {
  const SeedDropOverlay({
    super.key,
    required this.progress,
    required this.child,
    this.alignment = AlignmentDirectional.center,
  });

  /// Beat-3 progress, linear 0→1 ([RevealBeats.seedDrop]).
  final Animation<double> progress;

  /// The drop target — typically the vessel glyph itself, so the seed lands
  /// exactly on it wherever the strip's layout puts it.
  final Widget child;

  /// Where the seed lands over [child] — logical (start/end) coordinates, so
  /// a vessel sitting at the start of the strip mirrors correctly under RTL.
  final AlignmentGeometry alignment;

  /// The fall distance (creative-assets §7.3: appears 24dp above the rim).
  /// With the ~10% easeOutBack overshoot this stays inside the ≤4dp budget.
  static const double dropHeight = 24;

  static const double _seedSize = 10;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progress,
      builder: (context, _) {
        final t = progress.value;
        // Before the beat and once landed: just the strip — pixel-neutral.
        if (t <= 0 || t >= 1) return child;
        final fall = MotionTokens.seedDropCurve.transform(t);
        // Materialise over the first 20% of the beat (≈84ms — §7.3's "100% by
        // 80ms"), merge into the vessel over the last 15%.
        final appear = (t / 0.2).clamp(0.0, 1.0);
        final merge = t < 0.85 ? 1.0 : (1 - t) / 0.15;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            child,
            Positioned.fill(
              child: Align(
                alignment: alignment,
                child: Opacity(
                  key: revealSeedDropKey,
                  opacity: appear * merge,
                  child: Transform.translate(
                    offset: Offset(0, (fall - 1) * dropHeight),
                    child: const _Seed(),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The falling seed glyph: a small pomegranate seed carrying the ONE
/// sanctioned gradient pair (ui-ux §9.4 — pomegranate → pomegranate deep, for
/// seed shading). Decorative: the reveal's semantics live on the answer cards
/// and the strip's own count.
class _Seed extends StatelessWidget {
  const _Seed();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: SeedDropOverlay._seedSize,
        height: SeedDropOverlay._seedSize,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
            colors: [ColorTokens.pomegranate, ColorTokens.pomegranateDeep],
          ),
        ),
      ),
    );
  }
}
