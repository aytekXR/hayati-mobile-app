import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/core/design_system/motion_tokens.dart';
import 'package:hayati_app/core/widgets/soft_unfold_reveal.dart';

/// The soft-unfold motion is transient — no golden captures it (it settles
/// pixel-neutral), so per the S028 lesson (a fix on a transient surface needs a
/// widget test) THIS file is its proof. It asserts both halves of the brandkit
/// §6 unfold — the fade AND the gentle rise — plus the reduce-motion collapse
/// and the a11y-from-first-frame guarantee. Reading the rise via on-screen
/// position (getTopLeft) rather than the transform matrix keeps it robust and
/// also catches a sign inversion or a zero slide.
void main() {
  Future<void> pumpUnfold(
    WidgetTester tester, {
    bool reduceMotion = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (context) {
                const child = SoftUnfoldReveal(child: Text('reveal-child'));
                if (!reduceMotion) return child;
                return MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(disableAnimations: true),
                  child: child,
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  double opacityOf(WidgetTester tester) =>
      tester.widget<Opacity>(find.byKey(softUnfoldOpacityKey)).opacity;

  double childTop(WidgetTester tester) =>
      tester.getTopLeft(find.text('reveal-child')).dy;

  testWidgets('softly unfolds: the fade climbs 0→1 and the gentle rise settles '
      'to zero', (tester) async {
    await pumpUnfold(tester);

    // First frame — the enter start: faded out and lifted DOWN by the §6 slide.
    final op0 = opacityOf(tester);
    final top0 = childTop(tester);
    expect(
      op0,
      lessThan(1.0),
      reason: 'starts faded out (the enter begins at 0)',
    );

    // Mid-flight (bare fixed pump, never pumpAndSettle here): the fade climbs
    // and the child rises (moves UP → smaller dy).
    await tester.pump(const Duration(milliseconds: 120));
    expect(opacityOf(tester), greaterThan(op0), reason: 'opacity climbs');
    expect(
      childTop(tester),
      lessThan(top0),
      reason: 'the child rises as it settles',
    );

    // Settle deterministically past the 240ms unfold so no ticker is left
    // pending at teardown.
    await tester.pump(const Duration(milliseconds: 300));
    expect(opacityOf(tester), 1.0, reason: 'fully faded in at rest');
    final topRest = childTop(tester);
    expect(
      top0 - topRest,
      closeTo(MotionTokens.revealSlide, 1.0),
      reason:
          'rose exactly the §6 slide distance (${MotionTokens.revealSlide}dp) '
          'from below — proves the rise direction, magnitude and zero rest',
    );
  });

  testWidgets('reduce-motion collapses to an instant, settled appearance — no '
      'fade, no rise', (tester) async {
    await pumpUnfold(tester, reduceMotion: true);
    await tester.pump(); // let the zero-duration controller resolve

    final topAfter = childTop(tester);
    expect(opacityOf(tester), 1.0, reason: 'no fade under reduce-motion');

    // Pumping further must not move it — a broken reduce-motion path would keep
    // animating and shift the child.
    await tester.pump(const Duration(milliseconds: 300));
    expect(opacityOf(tester), 1.0);
    expect(
      childTop(tester),
      topAfter,
      reason: 'no rise under reduce-motion (stays put)',
    );
  });

  testWidgets('keeps the child in the semantics tree from the first frame '
      '(alwaysIncludeSemantics — no mid-unfold a11y gap)', (tester) async {
    await pumpUnfold(tester);
    expect(
      tester
          .widget<Opacity>(find.byKey(softUnfoldOpacityKey))
          .alwaysIncludeSemantics,
      isTrue,
    );
  });

  testWidgets(
    'a caller-supplied opacityKey is stamped on the animated Opacity, '
    'and the default is then unused (the daily reveal passes its own key, '
    'issue #74)',
    (tester) async {
      const customKey = ValueKey<String>('custom-unfold-opacity');
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SoftUnfoldReveal(
                opacityKey: customKey,
                child: Text('reveal-child'),
              ),
            ),
          ),
        ),
      );

      // The override routes to the animated Opacity; the default no longer
      // matches — so a regression where build() ignored opacityKey would fail
      // here even without the paired_home_screen daily-reveal tests.
      expect(find.byKey(customKey), findsOneWidget);
      expect(find.byKey(softUnfoldOpacityKey), findsNothing);

      // Settle past the 240ms unfold so no ticker is left pending at teardown.
      await tester.pump(const Duration(milliseconds: 300));
    },
  );
}
