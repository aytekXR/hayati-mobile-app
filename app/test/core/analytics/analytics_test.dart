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

    // The keys are the ADR-057 D4 table, asserted as STRINGS and not only as
    // behaviour. Added in review pass 2: a behavioural test ("call twice, see
    // one") passes just as happily for `analytics.singup.$uid` as for
    // `analytics.signup.$uid` — and these keys live in SharedPreferences ACROSS
    // app updates, so a typo does not fail, it silently re-emits a once-only
    // event for every existing user on the version that fixes it.
    test(
      'every once-key matches the ADR-057 D4 table, character for character',
      () {
        const cases = <String, void Function(Analytics)>{
          'analytics.install': _install,
          'analytics.signup.u1': _signup,
          'analytics.paired.u1.c1': _paired,
          'analytics.q.u1.20260818.solo': _qAnsweredSolo,
          'analytics.reveal.u1.20260818': _revealViewed,
          'analytics.streak.u1.20260818': _streakDay,
        };
        expect(
          cases,
          hasLength(6),
          reason:
              'ADR-057 D4 lists six keyed events; teach this test about any '
              'new one',
        );
        for (final entry in cases.entries) {
          final sink = RecordingAnalyticsSink();
          final container = ProviderContainer(
            overrides: [
              analyticsSinkProvider.overrideWithValue(sink),
              localFlagStoreProvider.overrideWithValue(
                FakeLocalFlagStore(initial: {entry.key}),
              ),
            ],
          );
          addTearDown(container.dispose);
          entry.value(container.read(analyticsProvider));
          expect(
            sink.names,
            isEmpty,
            reason:
                'the emitter did not recognise the already-claimed key '
                '"${entry.key}" — its key string has drifted from ADR-057 D4, and '
                'every existing user would re-emit this event once on upgrade',
          );
        }
      },
    );

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

// Top-level so the key table above stays a map of (key -> the one call that
// should be suppressed by it), rather than closures that could quietly drift
// from the emitter's real signatures.
void _install(Analytics a) => a.install();
void _signup(Analytics a) => a.signup(uid: 'u1');
void _paired(Analytics a) => a.paired(uid: 'u1', coupleId: 'c1');
void _qAnsweredSolo(Analytics a) =>
    a.qAnswered(uid: 'u1', dayKey: '20260818', mode: AnalyticsAnswerMode.solo);
void _revealViewed(Analytics a) =>
    a.revealViewed(uid: 'u1', dayKey: '20260818');
void _streakDay(Analytics a) =>
    a.streakDay(uid: 'u1', lastMutualDate: '20260818', count: 3);
