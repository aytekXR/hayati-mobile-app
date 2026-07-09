import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/core/observability/error_hooks.dart';

import '../../support/fake_crash_reporter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('installErrorHooks', () {
    late FakeCrashReporter reporter;

    setUp(() {
      reporter = FakeCrashReporter();
      // Both hooks are process-global mutable state; snapshot and restore them
      // so an installed hook never leaks into another test in this VM.
      final savedFlutterOnError = FlutterError.onError;
      final savedPlatformOnError = PlatformDispatcher.instance.onError;
      addTearDown(() {
        FlutterError.onError = savedFlutterOnError;
        PlatformDispatcher.instance.onError = savedPlatformOnError;
      });
      installErrorHooks(reporter);
    });

    test('routes FlutterError.onError to recordFlutterError as fatal', () {
      final details = FlutterErrorDetails(
        exception: StateError('framework boom'),
        library: 'error_hooks_test',
      );

      FlutterError.onError!(details);

      expect(reporter.flutterErrors, hasLength(1));
      expect(reporter.flutterErrors.single.details, same(details));
      expect(reporter.flutterErrors.single.fatal, isTrue);
    });

    test(
      'routes PlatformDispatcher.onError to recordError, fatal, handled',
      () {
        final error = StateError('async boom');
        final stack = StackTrace.current;

        final handled = PlatformDispatcher.instance.onError!(error, stack);

        // The callback must return true to mark the async error handled.
        expect(handled, isTrue);
        expect(reporter.errors, hasLength(1));
        expect(reporter.errors.single.error, same(error));
        expect(reporter.errors.single.stack, same(stack));
        expect(reporter.errors.single.fatal, isTrue);
      },
    );
  });
}
