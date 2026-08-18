import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/core/analytics/analytics_dimensions.dart';
import 'package:hayati_app/core/analytics/analytics_event.dart';
import 'package:hayati_app/core/analytics/funnel_event.dart';

/// The typed payloads (ADR-057 D3) and the ADR-016 crisis rule (D5).
void main() {
  group('every client event has a payload type, and only client events do', () {
    // NOT a hand-written list checked against itself: the expected SET comes
    // from the vocabulary, which `funnel_event_sentinel_test.dart` checks
    // against architecture.md §7. A payload type cannot exist without a
    // FunnelEvent (the type system requires `name`), and this asserts the
    // reverse — every client name has one.
    const samples = <AnalyticsEvent>[
      InstallEvent(),
      SignupEvent(),
      InviteSentEvent(),
      PairedEvent(),
      QAnsweredEvent(mode: AnalyticsAnswerMode.solo),
      RevealViewedEvent(),
      StreakDayEvent(count: 3),
      CoachMsgEvent(outcome: AnalyticsCoachOutcome.reply),
    ];

    test('the sample set covers exactly the client vocabulary', () {
      expect(
        samples.map((e) => e.name).toSet(),
        FunnelEvent.values
            .where((e) => e.emitter == AnalyticsEmitter.client)
            .toSet(),
        reason:
            'a client event gained or lost a payload type without this test '
            'being taught about it',
      );
    });

    test('no payload renders anything a user typed', () {
      // The structural guarantee of D3 restated as an assertion: every field on
      // every payload is drawn from a closed vocabulary or is an int, so the
      // debug rendering cannot carry content. This fails loudly if someone adds
      // a String field.
      for (final event in samples) {
        expect(event.toString(), isNot(contains('"')));
        expect(
          event.debugFields.values.whereType<String>(),
          isEmpty,
          reason: '${event.name.wire} carries a free String — D3 forbids it',
        );
      }
    });
  });

  group('q_answered carries the mode as a DIMENSION, not as a name', () {
    test('both modes share the one event name', () {
      expect(
        const QAnsweredEvent(mode: AnalyticsAnswerMode.solo).name,
        FunnelEvent.qAnswered,
      );
      expect(
        const QAnsweredEvent(mode: AnalyticsAnswerMode.mutual).name,
        FunnelEvent.qAnswered,
      );
    });

    test('the mode reaches the projection', () {
      expect(
        const QAnsweredEvent(mode: AnalyticsAnswerMode.mutual).debugFields,
        containsPair('mode', AnalyticsAnswerMode.mutual),
      );
    });
  });

  group('coach_msg reproduces the ADR-016 crisis rule, BOTH directions', () {
    test('a non-crisis outcome KEEPS the persona', () {
      const event = CoachMsgEvent(
        outcome: AnalyticsCoachOutcome.reply,
        persona: AnalyticsPersona.dateGenie,
      );
      expect(event.persona, AnalyticsPersona.dateGenie);
      expect(
        event.debugFields,
        containsPair('persona', AnalyticsPersona.dateGenie),
      );
    });

    // Asserting only the stripping is satisfied by an emitter that sends
    // nothing at all — hence the pair (ADR-057 D5).
    test('a crisis outcome DROPS the persona even when one is supplied', () {
      const event = CoachMsgEvent(
        outcome: AnalyticsCoachOutcome.help,
        persona: AnalyticsPersona.giftGenie,
      );
      expect(event.persona, isNull);
      expect(event.debugFields.containsKey('persona'), isFalse);
      expect(
        event.debugFields,
        containsPair('outcome', AnalyticsCoachOutcome.help),
      );
    });

    test('the type admits no cap counts and no crisis category at all', () {
      // The server response carries `remaining` on the post-filter help path
      // and a display-only `category`; neither has a home on this type, so an
      // emitter that forwarded what it was given could not compile.
      const event = CoachMsgEvent(outcome: AnalyticsCoachOutcome.help);
      expect(event.debugFields.keys, ['outcome']);
    });
  });

  group('no event carries a uid or a coupleId (ADR-057 D3)', () {
    test('the forbidden keys appear on no payload', () {
      const samples = <AnalyticsEvent>[
        InstallEvent(),
        SignupEvent(),
        InviteSentEvent(),
        PairedEvent(),
        QAnsweredEvent(mode: AnalyticsAnswerMode.mutual),
        RevealViewedEvent(),
        StreakDayEvent(count: 1),
        CoachMsgEvent(outcome: AnalyticsCoachOutcome.reply),
      ];
      for (final event in samples) {
        for (final forbidden in const ['uid', 'coupleId', 'text', 'answer']) {
          expect(
            event.debugFields.containsKey(forbidden),
            isFalse,
            reason: '${event.name.wire} carries $forbidden',
          );
        }
      }
    });
  });

  group('dimensions', () {
    test('locale is never null; register and storefront may be', () {
      const dimensions = AnalyticsDimensions(locale: AnalyticsLocale.tr);
      expect(dimensions.locale, AnalyticsLocale.tr);
      expect(dimensions.register, isNull);
      expect(dimensions.storefront, isNull);
    });

    test('the device fallback maps a raw platform tag, not just a subtag', () {
      expect(analyticsLocaleFor('tr'), AnalyticsLocale.tr);
      expect(analyticsLocaleFor('tr-TR'), AnalyticsLocale.tr);
      expect(analyticsLocaleFor('ar_SA'), AnalyticsLocale.ar);
      expect(analyticsLocaleFor('AR'), AnalyticsLocale.ar);
      // English is the deliberate fallback for anything unsupported, matching
      // bootstrapContentLanguage — the two must not disagree.
      expect(analyticsLocaleFor('de'), AnalyticsLocale.en);
      expect(analyticsLocaleFor(null), AnalyticsLocale.en);
      expect(analyticsLocaleFor(''), AnalyticsLocale.en);
    });
  });
}
