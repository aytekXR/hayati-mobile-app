import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/core/analytics/funnel_event.dart';

/// The closed §7 vocabulary (ADR-057 Decision 1). Parity with the DOCUMENT is
/// `funnel_event_sentinel_test.dart`'s job; this file pins the properties the
/// sentinel and the emitter both rely on.
void main() {
  test('the vocabulary is exactly twelve names, all distinct', () {
    expect(FunnelEvent.values, hasLength(12));
    expect(
      FunnelEvent.values.map((e) => e.wire).toSet(),
      hasLength(12),
      reason: 'two events share a wire name',
    );
  });

  test(
    'the three-way partition is total and matches ADR-057 D1 (8 + 3 + 1)',
    () {
      Iterable<FunnelEvent> by(AnalyticsEmitter emitter) =>
          FunnelEvent.values.where((e) => e.emitter == emitter);

      expect(by(AnalyticsEmitter.client), hasLength(8));
      expect(by(AnalyticsEmitter.server), hasLength(3));
      expect(by(AnalyticsEmitter.notBuilt), hasLength(1));
    },
  );

  test('the server three are exactly the entitlement events (ADR-057 D1)', () {
    expect(
      FunnelEvent.values
          .where((e) => e.emitter == AnalyticsEmitter.server)
          .map((e) => e.wire)
          .toSet(),
      {'trial_start', 'paid', 'churn'},
    );
  });

  test('share_card_created is the ONLY not-built event (mvp.md OUT list)', () {
    expect(
      FunnelEvent.values
          .where((e) => e.emitter == AnalyticsEmitter.notBuilt)
          .map((e) => e.wire)
          .toList(),
      ['share_card_created'],
    );
  });

  test('every wire name is snake_case — the parser grammar depends on it', () {
    for (final event in FunnelEvent.values) {
      expect(
        RegExp(r'^[a-z][a-z_]*$').hasMatch(event.wire),
        isTrue,
        reason: '${event.wire} is not [a-z][a-z_]*',
      );
    }
  });

  test('the derived Dart payload type name is mechanical, not a fixture', () {
    // Sentinel B derives the class name from the wire name rather than reading
    // a hand-written map, so the two cannot drift.
    expect(FunnelEvent.install.payloadTypeName, 'InstallEvent');
    expect(FunnelEvent.qAnswered.payloadTypeName, 'QAnsweredEvent');
    expect(FunnelEvent.coachMsg.payloadTypeName, 'CoachMsgEvent');
    expect(
      FunnelEvent.shareCardCreated.payloadTypeName,
      'ShareCardCreatedEvent',
    );
  });

  test('the derived emitter method name is mechanical too', () {
    expect(FunnelEvent.install.emitterMethodName, 'install');
    expect(FunnelEvent.qAnswered.emitterMethodName, 'qAnswered');
    expect(FunnelEvent.revealViewed.emitterMethodName, 'revealViewed');
    expect(FunnelEvent.coachMsg.emitterMethodName, 'coachMsg');
  });
}
