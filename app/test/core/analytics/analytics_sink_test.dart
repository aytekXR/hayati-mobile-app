import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/core/analytics/analytics_dimensions.dart';
import 'package:hayati_app/core/analytics/analytics_event.dart';
import 'package:hayati_app/core/analytics/analytics_sink.dart';
import 'package:hayati_app/core/analytics/debug_analytics_sink.dart';

/// ADR-057 Decision 2: the sink writes to `debugPrint` and to NOTHING else, it
/// is a no-op in release, and the port's default is silence rather than a throw.
void main() {
  late List<String> printed;
  late DebugPrintCallback original;

  setUp(() {
    printed = <String>[];
    original = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) printed.add(message);
    };
  });

  tearDown(() => debugPrint = original);

  const dimensions = AnalyticsDimensions(
    locale: AnalyticsLocale.tr,
    register: AnalyticsRegister.playful,
  );

  group('DebugAnalyticsSink', () {
    test('renders the event name and the dimensions', () {
      const DebugAnalyticsSink(releaseMode: false).record(
        const QAnsweredEvent(mode: AnalyticsAnswerMode.mutual),
        dimensions,
      );
      expect(printed, hasLength(1));
      expect(printed.single, contains('q_answered'));
      expect(printed.single, contains('mutual'));
      expect(printed.single, contains('tr'));
      expect(printed.single, contains('playful'));
    });

    // The BootTrace discipline (ADR-022 D5): prod pays nothing. Injected rather
    // than read off kReleaseMode so this is a behavioural assertion that can
    // actually fail, not a source scan.
    test('is a NO-OP under release mode', () {
      const DebugAnalyticsSink(
        releaseMode: true,
      ).record(const InstallEvent(), dimensions);
      expect(printed, isEmpty);
    });

    test(
      'the injected default IS kReleaseMode, so the guard cannot be lost',
      () {
        // A default of `false` would make every release build print. The default
        // is not observable from a test binary (kReleaseMode is false here), so
        // this is the one place a source assertion is the honest instrument.
        final source = File(
          'lib/core/analytics/debug_analytics_sink.dart',
        ).readAsStringSync();
        expect(
          source,
          contains('this.releaseMode = kReleaseMode'),
          reason: 'the release guard default was changed or removed',
        );
      },
    );

    test('reaches no crash reporter — analytics is not a Crashlytics breadcrumb', () {
      // ADR-057 D2(a): routing events through CrashReporter.log would put
      // product telemetry into crash reports and hand an existing processor a
      // data category docs/dpa-inventory.md does not list for it.
      //
      // The scan is over CODE, with comment lines stripped — the first version
      // of this test failed on the doc comment that EXPLAINS the rule, which is
      // a guard measuring prose rather than behaviour.
      String code(File file) => file
          .readAsLinesSync()
          .where((line) => !line.trimLeft().startsWith('//'))
          .join('\n');

      final analytics = Directory('lib/core/analytics')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();
      expect(
        analytics.length,
        greaterThanOrEqualTo(5),
        reason:
            'scanned only ${analytics.length} files under lib/core/analytics — '
            'the walker is broken, not the tree clean',
      );
      for (final file in analytics) {
        final source = code(file);
        // Stripping comments must not empty the file, or every assertion below
        // passes vacuously (lesson 110 applied to this guard itself).
        expect(
          source.length,
          greaterThan(200),
          reason:
              '${file.path} is ${source.length} chars after stripping '
              'comments — the stripper ate the code',
        );
        for (final forbidden in const [
          'CrashReporter',
          'crash_reporter',
          'Crashlytics',
          'crashlytics',
        ]) {
          expect(
            source,
            isNot(contains(forbidden)),
            reason: '${file.path} reaches $forbidden',
          );
        }
      }
    });
  });

  group('the sink is wired in DEV ONLY (ADR-057 D2b)', () {
    // The second of the two independent gates. The kReleaseMode guard above
    // survives someone copying the wiring into the wrong entrypoint; THIS
    // survives someone deleting that guard. Asserting only one of them leaves
    // a single point of failure in front of the claim "prod emits nothing".
    test('main_dev wires the DebugAnalyticsSink', () {
      expect(
        File('lib/main_dev.dart').readAsStringSync(),
        contains('DebugAnalyticsSink()'),
      );
    });

    test('main_prod wires NO analytics sink at all', () {
      final prod = File('lib/main_prod.dart').readAsStringSync();
      expect(
        prod.length,
        greaterThan(1000),
        reason: 'main_prod.dart read as ${prod.length} chars — the path moved',
      );
      expect(
        prod,
        isNot(contains('DebugAnalyticsSink')),
        reason:
            'prod must leave analyticsSinkProvider at its NoopAnalyticsSink '
            'default: this slice ships NO vendor sink, and docs/legal/ + '
            'docs/dpa-inventory.md have no row for one (#226)',
      );
      expect(prod, isNot(contains('analyticsSinkProvider')));
    });
  });

  group('NoopAnalyticsSink', () {
    test('records nothing and never throws', () {
      expect(
        () => const NoopAnalyticsSink().record(
          const CoachMsgEvent(outcome: AnalyticsCoachOutcome.help),
          dimensions,
        ),
        returnsNormally,
      );
      expect(printed, isEmpty);
    });
  });
}
