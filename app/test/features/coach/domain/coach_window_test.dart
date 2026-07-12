import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/coach/domain/coach_reply.dart';
import 'package:hayati_app/features/coach/domain/coach_transcript_entry.dart';
import 'package:hayati_app/features/coach/domain/coach_window.dart';

void main() {
  group('buildCoachWindow — bounds + trimming', () {
    test(
      'caps at kCoachWindowMaxMessages including the new last-user turn',
      () {
        final entries = [for (var i = 0; i < 30; i++) CoachUserTurn('u$i')];

        final window = buildCoachWindow(
          entries: entries,
          newUserText: 'newest',
        );

        expect(window, hasLength(kCoachWindowMaxMessages));
        expect(window.last, const CoachMessage(role: 'user', text: 'newest'));
      },
    );

    test('trims oldest-first', () {
      final entries = [for (var i = 0; i < 30; i++) CoachUserTurn('u$i')];

      final window = buildCoachWindow(entries: entries, newUserText: 'newest');

      // 30 eligible + 1 new = 31; keep last 20 → first surviving is u11.
      expect(window.first, const CoachMessage(role: 'user', text: 'u11'));
    });

    test('the last message is always the new user text', () {
      final window = buildCoachWindow(
        entries: const [CoachUserTurn('u'), CoachPersonaTurn('p')],
        newUserText: 'brand new',
      );

      expect(window.last, const CoachMessage(role: 'user', text: 'brand new'));
    });
  });

  group('buildCoachWindow — help exclusion + crisis retention', () {
    test('help entries never enter the window', () {
      final window = buildCoachWindow(
        entries: const [
          CoachUserTurn('a'),
          CoachHelpTurn('HELP CARD', category: CoachCrisisCategory.selfHarm),
          CoachUserTurn('b'),
        ],
        newUserText: 'c',
      );

      expect(window.map((m) => m.text), ['a', 'b', 'c']);
      expect(window.every((m) => m.role == 'user'), isTrue);
    });

    test(
      'user turns are re-sent verbatim — even one that drew a help entry',
      () {
        // Crisis retention semantics (Decision 2 rule 2): NO crisis-aware
        // filtering; the user turn that tripped the detector stays verbatim.
        final window = buildCoachWindow(
          entries: const [
            CoachUserTurn('i feel like hurting myself'),
            CoachHelpTurn('help', category: CoachCrisisCategory.selfHarm),
          ],
          newUserText: 'later, calmer message',
        );

        expect(window, const [
          CoachMessage(role: 'user', text: 'i feel like hurting myself'),
          CoachMessage(role: 'user', text: 'later, calmer message'),
        ]);
      },
    );
  });

  group('buildCoachWindow — roles + assistant truncation', () {
    test('roles map user→user, persona→assistant, new→user', () {
      final window = buildCoachWindow(
        entries: const [CoachUserTurn('u'), CoachPersonaTurn('p')],
        newUserText: 'new',
      );

      expect(window.map((m) => m.role), ['user', 'assistant', 'user']);
    });

    test('a persona turn at or under the bound is not truncated', () {
      final exact = 'y' * kCoachMessageMaxChars;
      final under = 'z' * 10;

      final window = buildCoachWindow(
        entries: [CoachPersonaTurn(exact), CoachPersonaTurn(under)],
        newUserText: 'hi',
      );

      expect(window[0].text, exact);
      expect(window[1].text, under);
    });

    test(
      'a persona turn over the bound truncates to exactly the char limit',
      () {
        final long = 'x' * (kCoachMessageMaxChars + 500);

        final window = buildCoachWindow(
          entries: [CoachPersonaTurn(long)],
          newUserText: 'hi',
        );

        expect(window.first.role, 'assistant');
        expect(window.first.text.length, kCoachMessageMaxChars);
      },
    );

    test('truncation counts UTF-16 code units (surrogate-pair boundary)', () {
      // 1999 'a' + emojis (each a 2-code-unit surrogate pair). Truncating to
      // 2000 code units keeps 1999 'a' plus ONE lone high surrogate — a
      // grapheme-aware cut could never land on 2000, proving code-unit counting.
      final emojiHeavy = '${'a' * 1999}${'😀' * 20}';
      expect(emojiHeavy.length, greaterThan(kCoachMessageMaxChars));

      final window = buildCoachWindow(
        entries: [CoachPersonaTurn(emojiHeavy)],
        newUserText: 'hi',
      );

      final text = window.first.text;
      expect(text.length, kCoachMessageMaxChars);
      final lastUnit = text.codeUnitAt(kCoachMessageMaxChars - 1);
      expect(lastUnit, greaterThanOrEqualTo(0xD800));
      expect(lastUnit, lessThanOrEqualTo(0xDBFF));
    });

    test(
      'user turns are never truncated (send gate already conformed them)',
      () {
        final long = 'u' * (kCoachMessageMaxChars + 500);

        final window = buildCoachWindow(
          entries: [CoachUserTurn(long)],
          newUserText: 'hi',
        );

        expect(window.first.text.length, kCoachMessageMaxChars + 500);
      },
    );
  });
}
