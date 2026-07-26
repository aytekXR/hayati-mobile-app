import 'package:flutter/material.dart';

import '../design_system/color_tokens.dart';
import '../design_system/motion_tokens.dart';
import '../design_system/spacing_tokens.dart';

/// Default testing handle on the group [Opacity] the choreography fades in —
/// the same seam contract as `SoftUnfoldReveal.opacityKey` (a caller may
/// override it; the daily reveal passes its `revealUnfoldOpacityKey`).
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

/// Builds the streak strip slot, receiving the beat-3 seed-drop progress
/// (linear 0→1 across `MotionTokens.revealBeatSeedDrop`). Wrap the strip in a
/// [SeedDropOverlay] to get the spec'd falling seed for free.
typedef RevealStreakStripBuilder =
    Widget Function(BuildContext context, Animation<double> seedDrop);

/// The reveal three-beat choreography (redesign ui-ux §11, creative-assets
/// §7.2) — the product's ONE choreography budget, mounted where the mutual
/// reveal renders (the paired home's revealed group):
///
///   Beat 1 `unfoldReveal` (300ms): the partner's card unfolds toward yours —
///     it enters from the partner-slot position below with a subtle 3D fold
///     flattening at the meeting edge, while the group crossfades in.
///   Beat 2 `settlePair` (180ms): both cards settle as a pair — one
///     simultaneous 2dp settle. [onSettle] fires as the settle lands: the
///     caller hooks the single light haptic here (kept, sacred).
///   Beat 3 `seedDrop` (420ms): one seed drops into the streak strip's vessel
///     ([SeedDropOverlay] via [streakStripBuilder]), gentle spring, overshoot
///     ≤4dp.
///
/// Total 900ms — inside the ≤1.2s budget pinned by `motion_tokens_test.dart`.
/// Reduce-motion collapses the whole sequence to an instant crossfade with
/// [onSettle] (the haptic) preserved. At rest the tree is pixel-neutral: the
/// group [Opacity] sits at 1 (Flutter's no-op fast path), every transform is
/// skipped, and the seed overlay renders nothing — so a settled golden is
/// byte-identical to a never-animated layout.
///
/// RTL: every motion vector is vertical (the cards stack as a pair, the seed
/// falls), so the choreography is direction-neutral by construction; the only
/// horizontal placement (the seed's landing point) resolves through
/// [SeedDropOverlay.alignment], an [AlignmentDirectional] — mirrored by the
/// ambient [Directionality], never a physical left/right.
///
/// `alwaysIncludeSemantics` keeps both answers in the semantics tree from the
/// first frame (ui-ux §8 VoiceOver: the reveal announces as one event — a
/// screen reader must never lose it mid-unfold).
class RevealChoreography extends StatefulWidget {
  const RevealChoreography({
    super.key,
    required this.ownCard,
    required this.partnerCard,
    this.streakStripBuilder,
    this.stripGap = SpacingTokens.x3,
    this.pairGap = SpacingTokens.x4,
    this.onSettle,
    this.opacityKey = revealChoreographyOpacityKey,
  });

  /// The own answer card — already on screen conceptually (the entry collapses
  /// into it), so it carries no motion of its own beyond the group fade.
  final Widget ownCard;

  /// The partner's answer card — the star of beat 1.
  final Widget partnerCard;

  /// The streak strip slot above the pair (null when the couple has no strip —
  /// e.g. reveal-trigger lag renders no streak). Receives the beat-3 progress.
  final RevealStreakStripBuilder? streakStripBuilder;

  /// Gap between the streak strip and the card pair.
  final double stripGap;

  /// Gap inside the card pair (own → partner) — x4, tighter than the x6 that
  /// sets the reveal apart from the affordances below it, so the two answers
  /// read as one shared moment.
  final double pairGap;

  /// Fired exactly once per mount, the moment beat 2's settle lands (or
  /// immediately under reduce-motion — the haptic is preserved when the
  /// animation is not). The caller owns any at-most-once-per-day guard.
  final VoidCallback? onSettle;

  /// Key stamped on the group [Opacity] (the crossfade), so each reveal
  /// surface exposes its own `@visibleForTesting` seam.
  final Key opacityKey;

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

  /// Beat 1's entry rise: the partner card starts this far below its rest
  /// position (the partner-slot direction) and travels up toward the pair.
  static const double _entryRise = 24;

  /// Beat 1's fold: the subtle 3D flattening at the meeting edge, in radians
  /// (≈17° — "subtle", not a full page-turn).
  static const double _foldAngle = 0.3;

  /// Beat 2's simultaneous pair settle distance (creative-assets §7.2: "2dp
  /// settle").
  static const double _settleLift = 2;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: RevealChoreography.total,
  );

  /// Group crossfade + partner entry share beat 1's window.
  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Interval(0, _beat1End, curve: MotionTokens.enter),
  );

  /// Beat 2: both cards settle as a pair.
  late final Animation<double> _settle = CurvedAnimation(
    parent: _controller,
    curve: Interval(_beat1End, _beat2End, curve: MotionTokens.enter),
  );

  /// Beat 3's raw progress — [SeedDropOverlay] applies the spring character
  /// ([MotionTokens.seedDropCurve]) to the fall itself.
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
      builder: (context, _) {
        final done = _controller.isCompleted;

        var partner = widget.partnerCard;
        if (!done) {
          final t = _fade.value;
          partner = Opacity(
            key: revealPartnerEntryKey,
            opacity: t,
            alwaysIncludeSemantics: true,
            child: Transform(
              // The fold-line is the pair's meeting edge — the top of the
              // partner card (the own card sits above). Vertical axis motion
              // only: direction-neutral, no RTL variant needed.
              alignment: Alignment.topCenter,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0015)
                ..translateByDouble(0, (1 - t) * _entryRise, 0, 1)
                ..rotateX((1 - t) * _foldAngle),
              child: partner,
            ),
          );
        }

        Widget pair = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            widget.ownCard,
            SizedBox(height: widget.pairGap),
            partner,
          ],
        );
        if (!done) {
          // Beat 2: the pair rides 2dp high through beat 1, then settles to
          // rest together — one simultaneous landing, felt via [onSettle].
          pair = Transform.translate(
            offset: Offset(0, -_settleLift * (1 - _settle.value)),
            child: pair,
          );
        }

        final strip = widget.streakStripBuilder?.call(context, _seedDrop);
        return Opacity(
          key: widget.opacityKey,
          opacity: _fade.value,
          alwaysIncludeSemantics: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (strip != null) ...[strip, SizedBox(height: widget.stripGap)],
              pair,
            ],
          ),
        );
      },
    );
  }
}

/// Beat 3 realised over a streak strip: a single seed materialises 24dp above
/// [child], falls with the sanctioned gentle spring
/// ([MotionTokens.seedDropCurve], overshoot ≈2.4dp ≤ the 4dp budget) and
/// merges into the strip as it lands — the landed seed is the strip's own
/// render (the server streak already counts today), so the overlay ends empty
/// and the rest frame is pixel-neutral.
class SeedDropOverlay extends StatelessWidget {
  const SeedDropOverlay({
    super.key,
    required this.progress,
    required this.child,
    this.alignment = AlignmentDirectional.center,
  });

  /// Beat-3 progress, linear 0→1 (from [RevealChoreography]'s third interval).
  final Animation<double> progress;

  /// The streak strip (the vessel's home).
  final Widget child;

  /// Where the seed lands over [child] — logical (start/end) coordinates, so a
  /// vessel sitting at the start of the strip mirrors correctly under RTL.
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
