import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/core/design_system/motion_tokens.dart';
import 'package:hayati_app/core/widgets/reveal_choreography.dart';

/// The three-beat choreography is transient — no golden captures it (it
/// settles pixel-neutral), so per the S028 lesson this file is its proof:
/// beat 1's unfold-toward, beat 2's settle timing (the haptic hook), beat 3's
/// seed drop-and-merge, the ≤1.2s budget, the reduce-motion collapse with the
/// settle hook preserved, and RTL mounting. Composed the way the paired home
/// composes it: strip (seed-drop target) outside the pair's fade group.
void main() {
  Future<void> pumpChoreography(
    WidgetTester tester, {
    VoidCallback? onSettle,
    bool reduceMotion = false,
    bool withStrip = true,
    TextDirection direction = TextDirection.ltr,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (context) {
                final choreography = RevealChoreography(
                  onSettle: onSettle,
                  builder: (context, beats) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (withStrip)
                        SeedDropOverlay(
                          progress: beats.seedDrop,
                          child: const Text('strip'),
                        ),
                      const Text('question'),
                      RevealPairGroup(
                        beats: beats,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('own-card'),
                            RevealPartnerEntry(
                              beats: beats,
                              child: const Text('partner-card'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
                final directed = Directionality(
                  textDirection: direction,
                  child: choreography,
                );
                if (!reduceMotion) return directed;
                return MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(disableAnimations: true),
                  child: directed,
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  double groupOpacity(WidgetTester tester) =>
      tester.widget<Opacity>(find.byKey(revealChoreographyOpacityKey)).opacity;

  double partnerOpacity(WidgetTester tester) =>
      tester.widget<Opacity>(find.byKey(revealPartnerEntryKey)).opacity;

  // Settle everything deterministically past the 900ms total (never
  // pumpAndSettle mid-test — the animation IS the thing under test).
  Future<void> settleAll(WidgetTester tester) =>
      tester.pump(const Duration(milliseconds: 1000));

  test('the three beats sum inside the ≤1.2s choreography budget', () {
    expect(
      RevealChoreography.total,
      MotionTokens.revealBeatUnfold +
          MotionTokens.revealBeatSettle +
          MotionTokens.revealBeatSeedDrop,
    );
    expect(RevealChoreography.total.inMilliseconds, lessThanOrEqualTo(1200));
  });

  testWidgets('beat 1: the partner card unfolds toward the pair — its entry '
      'opacity climbs and it rises to rest by the beat end; the strip and '
      'question NEVER fade (they were already on screen)', (tester) async {
    await pumpChoreography(tester);

    // First frame: the entry begins — partner faded out, pair group faded out.
    final p0 = partnerOpacity(tester);
    final top0 = tester.getTopLeft(find.text('partner-card')).dy;
    expect(p0, lessThan(1.0));
    expect(groupOpacity(tester), lessThan(1.0));
    // The strip and question sit OUTSIDE the fade group: no Opacity ancestor
    // from the choreography wraps them (the pair Opacity is not their
    // ancestor), so they render settled from frame one.
    expect(
      find.ancestor(
        of: find.text('strip'),
        matching: find.byKey(revealChoreographyOpacityKey),
      ),
      findsNothing,
    );
    expect(
      find.ancestor(
        of: find.text('question'),
        matching: find.byKey(revealChoreographyOpacityKey),
      ),
      findsNothing,
    );

    // Mid beat 1: both climb; the card has risen toward its pair (smaller dy).
    await tester.pump(const Duration(milliseconds: 150));
    expect(partnerOpacity(tester), greaterThan(p0));
    expect(tester.getTopLeft(find.text('partner-card')).dy, lessThan(top0));

    // Past beat 1 (300ms): the crossfade is complete.
    await tester.pump(const Duration(milliseconds: 200));
    expect(groupOpacity(tester), 1.0);

    await settleAll(tester);
  });

  testWidgets('beat 2: onSettle fires exactly once, AT the settle — not on '
      'mount, not before the pair lands, never twice', (tester) async {
    var settles = 0;
    await pumpChoreography(tester, onSettle: () => settles++);

    // Through beat 1 (300ms) the settle has not landed.
    await tester.pump(const Duration(milliseconds: 300));
    expect(settles, 0, reason: 'no settle during the unfold beat');

    // Beat 2 completes at 480ms — the settle (and its haptic hook) lands.
    await tester.pump(const Duration(milliseconds: 200));
    expect(settles, 1, reason: 'the settle fires as beat 2 lands');

    // The rest of the choreography adds nothing.
    await settleAll(tester);
    expect(settles, 1);
  });

  testWidgets('beat 3: the seed materialises mid-drop and has merged into the '
      'strip by rest (pixel-neutral end state)', (tester) async {
    await pumpChoreography(tester);

    // Before beat 3 (≤480ms): no seed.
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(revealSeedDropKey), findsNothing);

    // Mid beat 3 (~700ms): the seed is falling, visible above the strip.
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(revealSeedDropKey), findsOneWidget);
    expect(
      tester.widget<Opacity>(find.byKey(revealSeedDropKey)).opacity,
      greaterThan(0.0),
    );

    // At rest (≥900ms): merged — the overlay renders only the strip again.
    await settleAll(tester);
    expect(find.byKey(revealSeedDropKey), findsNothing);
    expect(find.text('strip'), findsOneWidget);
  });

  testWidgets('at rest the pair Opacity is 1 and every transform is retired '
      '(the settled tree is pixel-neutral)', (tester) async {
    await pumpChoreography(tester);
    await settleAll(tester);

    expect(groupOpacity(tester), 1.0);
    // The beat-1 entry wrapper is gone at rest — the partner card renders
    // bare, so a settled golden cannot differ from a never-animated layout.
    expect(find.byKey(revealPartnerEntryKey), findsNothing);
    expect(find.text('own-card'), findsOneWidget);
    expect(find.text('partner-card'), findsOneWidget);
  });

  testWidgets('composing without a strip still completes the beats', (
    tester,
  ) async {
    var settles = 0;
    await pumpChoreography(tester, withStrip: false, onSettle: () => settles++);
    await settleAll(tester);

    expect(find.text('strip'), findsNothing);
    expect(find.byKey(revealSeedDropKey), findsNothing);
    expect(settles, 1);
  });

  testWidgets('reduce-motion collapses to an instant crossfade — settled on '
      'frame one, with the settle hook (the haptic) preserved', (tester) async {
    var settles = 0;
    await pumpChoreography(
      tester,
      reduceMotion: true,
      onSettle: () => settles++,
    );
    await tester.pump();

    expect(groupOpacity(tester), 1.0, reason: 'no fade under reduce-motion');
    expect(find.byKey(revealPartnerEntryKey), findsNothing);
    expect(find.byKey(revealSeedDropKey), findsNothing);
    expect(settles, 1, reason: 'the haptic hook is preserved');

    // Nothing keeps animating.
    await tester.pump(const Duration(milliseconds: 300));
    expect(groupOpacity(tester), 1.0);
    expect(settles, 1);
  });

  testWidgets('mounts and completes under RTL — every motion vector is '
      'vertical/logical, so the mirrored composition needs no variant', (
    tester,
  ) async {
    await pumpChoreography(tester, direction: TextDirection.rtl);
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byKey(revealSeedDropKey), findsOneWidget);
    await settleAll(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('own-card'), findsOneWidget);
    expect(find.text('partner-card'), findsOneWidget);
  });
}
