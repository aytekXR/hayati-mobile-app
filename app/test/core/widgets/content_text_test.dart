import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/core/l10n/bidi_isolate.dart';
import 'package:hayati_app/core/widgets/content_text.dart';

/// Issue #133 / ADR-033 D7. The spec under test, stated so it does not depend
/// on where the block happens to be aligned:
///
///   **A sentence's terminating punctuation must bind to the trailing side of
///   its OWN run, whatever direction the surrounding paragraph runs in.**
///
/// For LTR content that means the terminator sits to the RIGHT of the last
/// letter; for RTL content, to its LEFT. Encoded as geometry read back from
/// `RenderParagraph`, never as "the period is at x=306" — a card's padding may
/// change without this defect returning.
///
/// The assertion is deliberately NOT derived from [isolate]: it reads the
/// rendered string off the widget and measures the framework's layout result,
/// so neutering the production fix moves the box and turns this red
/// (`session-rules` addendum 43 — a test whose fixture comes from its subject
/// proves nothing).
///
/// `TextDirection` literals are fine here: `rtl_lint` scans `app/lib` only.

/// Latin sentence — the exact string the committed golden mangles.
const _latinContent = 'Kahvaltıda birlikte gülmemiz.';

/// Arabic sentence — the MIRROR case (ADR-033 D5). #133 does not mention it;
/// it is reachable today via `contentLanguage: ar` under a `tr`/`en` interface,
/// and no golden covers it.
const _arabicContent = 'أجبتما كلاكما اليوم.';

Future<RenderParagraph> _pumpContent(
  WidgetTester tester,
  String content, {
  required TextDirection paragraph,
  double width = 320,
}) async {
  final key = GlobalKey();
  await tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(),
      child: Directionality(
        textDirection: paragraph,
        child: Center(
          child: SizedBox(
            width: width,
            child: ContentText(
              content,
              key: key,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ),
      ),
    ),
  );
  return tester.renderObject<RenderParagraph>(find.byType(RichText));
}

/// The string the paragraph actually laid out — the artefact, not the input.
String _renderedText(WidgetTester tester) =>
    tester.widget<Text>(find.byType(Text)).data!;

Rect _boxOf(RenderParagraph rp, int index) {
  final boxes = rp.getBoxesForSelection(
    TextSelection(baseOffset: index, extentOffset: index + 1),
  );
  expect(boxes, isNotEmpty, reason: 'character at $index has no render box');
  final b = boxes.first;
  return Rect.fromLTRB(b.left, b.top, b.right, b.bottom);
}

/// Asserts the last `.`/`?`/`!` binds to the trailing side of its own run.
void _expectTerminatorBindsToRun(
  RenderParagraph rp,
  String rendered, {
  required bool contentIsLtr,
}) {
  final terminator = rendered.lastIndexOf(RegExp(r'[.?!]'));
  expect(terminator, greaterThan(0), reason: 'fixture must end in punctuation');
  final letter = terminator - 1;

  final t = _boxOf(rp, terminator);
  final l = _boxOf(rp, letter);

  // Same line, or "trailing side" is not a meaningful comparison at all.
  expect(
    t.top,
    l.top,
    reason: 'terminator was pushed onto a different line from its sentence',
  );

  if (contentIsLtr) {
    expect(
      t.left,
      greaterThanOrEqualTo(l.right - 0.01),
      reason:
          'LTR sentence: "${rendered[letter]}" ends at x=${l.right}, so its '
          'terminator must start at or after that — found x=${t.left}. '
          'The punctuation has jumped to the leading edge (issue #133).',
    );
  } else {
    expect(
      t.right,
      lessThanOrEqualTo(l.left + 0.01),
      reason:
          'RTL sentence: "${rendered[letter]}" ends at x=${l.left}, so its '
          'terminator must end at or before that — found x=${t.right}. '
          'The punctuation has jumped to the leading edge (the mirror case).',
    );
  }
}

void main() {
  group('the terminator binds to its own run', () {
    testWidgets('Latin content inside RTL chrome (issue #133)', (tester) async {
      final rp = await _pumpContent(
        tester,
        _latinContent,
        paragraph: TextDirection.rtl,
      );
      _expectTerminatorBindsToRun(
        rp,
        _renderedText(tester),
        contentIsLtr: true,
      );
    });

    testWidgets('Arabic content inside LTR chrome (the mirror case)', (
      tester,
    ) async {
      final rp = await _pumpContent(
        tester,
        _arabicContent,
        paragraph: TextDirection.ltr,
      );
      _expectTerminatorBindsToRun(
        rp,
        _renderedText(tester),
        contentIsLtr: false,
      );
    });

    // The two cells that were never broken. They pin the fix to the cases it is
    // for: a change that "fixes" #133 by flipping everything would redden here.
    testWidgets('Latin content inside LTR chrome stays correct', (
      tester,
    ) async {
      final rp = await _pumpContent(
        tester,
        _latinContent,
        paragraph: TextDirection.ltr,
      );
      _expectTerminatorBindsToRun(
        rp,
        _renderedText(tester),
        contentIsLtr: true,
      );
    });

    testWidgets('Arabic content inside RTL chrome stays correct', (
      tester,
    ) async {
      final rp = await _pumpContent(
        tester,
        _arabicContent,
        paragraph: TextDirection.rtl,
      );
      _expectTerminatorBindsToRun(
        rp,
        _renderedText(tester),
        contentIsLtr: false,
      );
    });
  });

  group('ContentText contract', () {
    testWidgets('the accessibility label is the PRISTINE string', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pumpContent(tester, _latinContent, paragraph: TextDirection.rtl);

      final node = tester.getSemantics(find.byType(Text));
      expect(
        node.label,
        _latinContent,
        reason: 'a screen reader must never receive the isolate controls',
      );
      expect(node.label.contains(firstStrongIsolate), isFalse);
      expect(node.label.contains(popDirectionalIsolate), isFalse);
      handle.dispose();
    });

    testWidgets('empty content renders without stray control characters', (
      tester,
    ) async {
      await _pumpContent(tester, '', paragraph: TextDirection.rtl);
      expect(_renderedText(tester), isEmpty);
    });

    // ADR-033 D9's declaration rests on these two. Unconditional isolation is
    // semantically harmless but NOT pixel-neutral — the controls re-shape the
    // run — so the seam must not emit them when the direction already agrees.
    testWidgets('content matching the paragraph is left PRISTINE', (
      tester,
    ) async {
      await _pumpContent(tester, _latinContent, paragraph: TextDirection.ltr);
      expect(_renderedText(tester), _latinContent);

      await _pumpContent(tester, _arabicContent, paragraph: TextDirection.rtl);
      expect(_renderedText(tester), _arabicContent);
    });

    testWidgets('content opposing the paragraph IS isolated', (tester) async {
      await _pumpContent(tester, _latinContent, paragraph: TextDirection.rtl);
      expect(_renderedText(tester), isolate(_latinContent));

      await _pumpContent(tester, _arabicContent, paragraph: TextDirection.ltr);
      expect(_renderedText(tester), isolate(_arabicContent));
    });

    testWidgets('a string with NO strong character is left pristine', (
      tester,
    ) async {
      // No direction of its own, so it should take the paragraph's — which is
      // what it already does. Forcing an isolate would pin it to LTR.
      await _pumpContent(tester, '2026 · 4', paragraph: TextDirection.rtl);
      expect(_renderedText(tester), '2026 · 4');
    });

    testWidgets('isolation does not move already-correct LTR content', (
      tester,
    ) async {
      final isolated = await _pumpContent(
        tester,
        _latinContent,
        paragraph: TextDirection.ltr,
      );
      final isolatedBoxes = [
        for (var i = 0; i < _latinContent.length; i++)
          _boxOf(isolated, _renderedText(tester).indexOf(_latinContent) + i),
      ];

      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: SizedBox(
                width: 320,
                child: Text(_latinContent, style: TextStyle(fontSize: 14)),
              ),
            ),
          ),
        ),
      );
      final plain = tester.renderObject<RenderParagraph>(find.byType(RichText));
      final plainBoxes = [
        for (var i = 0; i < _latinContent.length; i++) _boxOf(plain, i),
      ];

      expect(isolatedBoxes, plainBoxes);
    });
  });

  group('isolate()', () {
    test('wraps in FSI/PDI', () {
      expect(isolate('abc'), '${firstStrongIsolate}abc$popDirectionalIsolate');
    });

    test('is a no-op on the empty string', () {
      expect(isolate(''), '');
    });

    test('the constants are the Unicode isolate code points', () {
      expect(firstStrongIsolate.codeUnitAt(0), 0x2068);
      expect(popDirectionalIsolate.codeUnitAt(0), 0x2069);
    });
  });
}
