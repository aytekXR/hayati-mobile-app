import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/core/analytics/analytics.dart';
import 'package:hayati_app/core/analytics/analytics_dimensions.dart';
import 'package:hayati_app/core/analytics/analytics_event.dart';
import 'package:hayati_app/core/analytics/analytics_sink.dart';
import 'package:hayati_app/core/storage/local_flag_store.dart';

import '../../support/fake_local_flag_store.dart';
import '../../support/recording_analytics_sink.dart';

/// The emitter (ADR-057 D4): once-only semantics belong to the event, and no
/// path here may throw into a caller.
void main() {
  late RecordingAnalyticsSink sink;
  late FakeLocalFlagStore flags;

  ProviderContainer containerWith({bool wireFlags = true}) {
    final container = ProviderContainer(
      overrides: [
        analyticsSinkProvider.overrideWithValue(sink),
        if (wireFlags) localFlagStoreProvider.overrideWithValue(flags),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Analytics analyticsOf(ProviderContainer container) =>
      container.read(analyticsProvider);

  setUp(() {
    sink = RecordingAnalyticsSink();
    flags = FakeLocalFlagStore();
  });

  group('the port defaults to silence, never to a throw (D2c)', () {
    test('an un-overridden container records nothing and does not throw', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(
        () => container.read(analyticsProvider).install(),
        returnsNormally,
      );
    });

    test('the default dimensions carry a locale and nothing else', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final dimensions = container.read(analyticsDimensionsProvider);
      expect(dimensions.locale, isNotNull);
      expect(dimensions.register, isNull);
      expect(dimensions.storefront, isNull);
    });
  });

  group('once-only semantics (D4)', () {
    test('install fires once per device, however many times it is called', () {
      final analytics = analyticsOf(containerWith());
      analytics.install();
      analytics.install();
      analytics.install();
      expect(sink.names, ['install']);
    });

    test('install does not fire at all when the flag is already set', () {
      flags = FakeLocalFlagStore(initial: {'analytics.install'});
      analyticsOf(containerWith()).install();
      expect(sink.names, isEmpty);
    });

    test('signup is keyed per uid — a second account on one device emits', () {
      final analytics = analyticsOf(containerWith());
      analytics.signup(uid: 'u1');
      analytics.signup(uid: 'u1');
      analytics.signup(uid: 'u2');
      expect(sink.names, ['signup', 'signup']);
    });

    test('paired is keyed per uid AND coupleId', () {
      final analytics = analyticsOf(containerWith());
      analytics.paired(uid: 'u1', coupleId: 'c1');
      analytics.paired(uid: 'u1', coupleId: 'c1');
      analytics.paired(uid: 'u1', coupleId: 'c2');
      analytics.paired(uid: 'u2', coupleId: 'c1');
      expect(sink.names, ['paired', 'paired', 'paired']);
    });

    test('q_answered is keyed per day AND mode — editing does not inflate', () {
      final analytics = analyticsOf(containerWith());
      analytics.qAnswered(
        uid: 'u1',
        dayKey: '2026-08-18',
        mode: AnalyticsAnswerMode.solo,
      );
      analytics.qAnswered(
        uid: 'u1',
        dayKey: '2026-08-18',
        mode: AnalyticsAnswerMode.solo,
      );
      analytics.qAnswered(
        uid: 'u1',
        dayKey: '2026-08-18',
        mode: AnalyticsAnswerMode.mutual,
      );
      analytics.qAnswered(
        uid: 'u1',
        dayKey: '2026-08-19',
        mode: AnalyticsAnswerMode.solo,
      );
      expect(sink.names, ['q_answered', 'q_answered', 'q_answered']);
      expect(sink.events.whereType<QAnsweredEvent>().map((e) => e.mode), [
        AnalyticsAnswerMode.solo,
        AnalyticsAnswerMode.mutual,
        AnalyticsAnswerMode.solo,
      ]);
    });

    test('reveal_viewed is keyed per day, so a re-open does not re-emit', () {
      final analytics = analyticsOf(containerWith());
      analytics.revealViewed(uid: 'u1', dayKey: '2026-08-18');
      analytics.revealViewed(uid: 'u1', dayKey: '2026-08-18');
      analytics.revealViewed(uid: 'u1', dayKey: '2026-08-19');
      expect(sink.names, ['reveal_viewed', 'reveal_viewed']);
    });

    test('streak_day is keyed per mutual date', () {
      final analytics = analyticsOf(containerWith());
      analytics.streakDay(uid: 'u1', lastMutualDate: '2026-08-18', count: 4);
      analytics.streakDay(uid: 'u1', lastMutualDate: '2026-08-18', count: 4);
      analytics.streakDay(uid: 'u1', lastMutualDate: '2026-08-19', count: 5);
      expect(sink.names, ['streak_day', 'streak_day']);
      expect(sink.events.whereType<StreakDayEvent>().map((e) => e.count), [
        4,
        5,
      ]);
    });

    test('the per-action events are NOT deduplicated', () {
      final analytics = analyticsOf(containerWith());
      analytics.inviteSent();
      analytics.inviteSent();
      analytics.coachMsg(outcome: AnalyticsCoachOutcome.reply);
      analytics.coachMsg(outcome: AnalyticsCoachOutcome.reply);
      expect(sink.names, [
        'invite_sent',
        'invite_sent',
        'coach_msg',
        'coach_msg',
      ]);
    });
  });

  group('an unavailable flag store loses the DE-DUP, never the event', () {
    test('every once-only event still emits when storage throws', () {
      // localFlagStoreProvider throws when unoverridden — the state of every
      // widget test that does not wire storage.
      final analytics = analyticsOf(containerWith(wireFlags: false));
      analytics.install();
      analytics.install();
      expect(
        sink.names,
        ['install', 'install'],
        reason:
            'losing a de-dup is a counting error; losing the event is '
            'blindness',
      );
    });
  });

  group('nothing reaches the caller (ADR-039 D1)', () {
    test('a sink that throws does not throw out of emit', () {
      final container = ProviderContainer(
        overrides: [
          analyticsSinkProvider.overrideWithValue(_ThrowingSink()),
          localFlagStoreProvider.overrideWithValue(flags),
        ],
      );
      addTearDown(container.dispose);
      expect(
        () => container.read(analyticsProvider).inviteSent(),
        returnsNormally,
      );
    });

    test('a dimensions resolver that throws does not throw out of emit', () {
      final container = ProviderContainer(
        overrides: [
          analyticsSinkProvider.overrideWithValue(sink),
          localFlagStoreProvider.overrideWithValue(flags),
          analyticsDimensionsProvider.overrideWith(
            (ref) => throw StateError('resolver exploded'),
          ),
        ],
      );
      addTearDown(container.dispose);
      expect(
        () => container.read(analyticsProvider).inviteSent(),
        returnsNormally,
      );
      expect(sink.names, isEmpty);
    });
  });

  group('the dimensions reach the sink', () {
    test('whatever the resolver returns is attached to the event', () {
      const dimensions = AnalyticsDimensions(
        locale: AnalyticsLocale.ar,
        register: AnalyticsRegister.respectful,
      );
      final container = ProviderContainer(
        overrides: [
          analyticsSinkProvider.overrideWithValue(sink),
          localFlagStoreProvider.overrideWithValue(flags),
          analyticsDimensionsProvider.overrideWithValue(dimensions),
        ],
      );
      addTearDown(container.dispose);
      container.read(analyticsProvider).inviteSent();
      expect(sink.dimensions.single, dimensions);
    });
  });
}

class _ThrowingSink implements AnalyticsSink {
  @override
  void record(AnalyticsEvent event, AnalyticsDimensions dimensions) =>
      throw StateError('sink exploded');
}
