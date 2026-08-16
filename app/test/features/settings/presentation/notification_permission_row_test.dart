import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/auth/domain/auth_repository_provider.dart';
import 'package:hayati_app/features/auth/domain/auth_user.dart';
import 'package:hayati_app/features/notifications/domain/notification_settings_launcher.dart';
import 'package:hayati_app/features/notifications/domain/push_token_repository.dart';
import 'package:hayati_app/features/notifications/domain/push_token_repository_provider.dart';
import 'package:hayati_app/features/notifications/domain/push_token_source.dart';
import 'package:hayati_app/features/notifications/domain/push_token_source_provider.dart';
import 'package:hayati_app/features/notifications/presentation/state/push_token_sync.dart';
import 'package:hayati_app/features/settings/presentation/widgets/notification_permission_row.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart' show Override;

import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_notification_settings_launcher.dart';
import '../../../support/localized_app.dart';

/// The row that tells the user whether this phone can receive a notification
/// (ADR-046 Decision 3).
///
/// **What is under test is the SENTENCE and the BUTTON, per state.** Production
/// on 2026-08-16 had four accounts, zero registered devices, and zero HTTP
/// requests ever reaching `registerPushToken`, with every server-side layer
/// verified working — and no way to tell a declined prompt from an uninstalled
/// build from an APNs handshake that never completed. These four cases are that
/// distinction, made testable.
class _FakeRepository implements PushTokenRepository {
  final List<String> registered = [];

  @override
  Future<void> register(String token) async => registered.add(token);

  @override
  Future<void> unregister(String token) async {}
}

class _FakeSource implements PushTokenSource {
  PushPermission status = PushPermission.notDetermined;
  bool ready = true;
  String? token = 'device-token';

  /// Whether `ensurePermission()` grants when asked — deliberately separate from
  /// [status], so a test can prove a caller READ when it should have read and
  /// did not silently ASK (which on iOS spends the one dialog per install).
  bool grantOnRequest = true;
  int permissionRequests = 0;

  @override
  Future<PushPermission> permissionStatus() async => status;

  @override
  Future<bool> ensurePermission() async {
    permissionRequests++;
    if (grantOnRequest) status = PushPermission.granted;
    return grantOnRequest;
  }

  // Both of these model the iOS CONTRACT, not a convenient one: before a
  // permission grant iOS mints no FCM token at all, and asking produces nothing.
  // A fake that handed out a token regardless would let a `denied` device test
  // as "registered" — which is precisely the confusion this row exists to end.
  @override
  Future<bool> isReadyForToken() async =>
      ready && status == PushPermission.granted;

  @override
  Future<String?> currentToken() async =>
      status == PushPermission.granted ? token : null;

  @override
  Stream<String> tokenRefreshes() => const Stream<String>.empty();
}

void main() {
  const uid = 'uid-1';
  final en = l10nFor(const Locale('en'));

  late _FakeRepository repository;
  late _FakeSource source;
  late FakeNotificationSettingsLauncher launcher;
  late FakeAuthRepository auth;

  setUp(() {
    repository = _FakeRepository();
    source = _FakeSource();
    launcher = FakeNotificationSettingsLauncher();
    auth = FakeAuthRepository(initialUser: const AuthUser(uid: uid));
    addTearDown(auth.dispose);
    // ADR-044's bounded retry schedules real timers, and `pumpAndSettle` never
    // settles while one is pending (the shape that once took 60 unrelated widget
    // tests red). The attempt COUNT is left at its shipped value on purpose — a
    // test that shrank that would stop guarding the bound it exists to guard.
    PushTokenSync.tokenCaptureBackoff = Duration.zero;
    addTearDown(
      () =>
          PushTokenSync.tokenCaptureBackoff = const Duration(milliseconds: 500),
    );
  });

  List<Override> overrides() => [
    authRepositoryProvider.overrideWith((ref) => auth),
    pushTokenRepositoryProvider.overrideWith((ref) => repository),
    pushTokenSourceProvider.overrideWith((ref) => source),
    notificationSettingsLauncherProvider.overrideWithValue(launcher),
  ];

  Future<void> pumpRow(WidgetTester tester) async {
    await tester.pumpWidget(
      localizedApp(
        const Scaffold(body: NotificationPermissionRow()),
        overrides: overrides(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a REGISTERED device says so out loud and offers no action', (
    tester,
  ) async {
    // Lesson 65 inverted: success is stated, never implied by the absence of a
    // warning. A blank row is what "we have no idea" looked like for five
    // sessions.
    source
      ..status = PushPermission.granted
      ..ready = true;
    await pumpRow(tester);

    expect(find.text(en.settingsNotificationsTitle), findsOneWidget);
    expect(find.text(en.settingsNotificationsSubtitleOn), findsOneWidget);
    expect(find.byType(TextButton), findsNothing);
    expect(repository.registered, ['device-token']);
  });

  testWidgets('a DENIED permission names the dead end and offers Settings', (
    tester,
  ) async {
    // The state no build can fix: iOS shows its dialog once per install, so a
    // "Turn on" button here would be a lie that does nothing.
    source.status = PushPermission.denied;
    await pumpRow(tester);

    expect(find.text(en.settingsNotificationsSubtitleDenied), findsOneWidget);
    expect(find.text(en.settingsNotificationsOpenSettings), findsOneWidget);
    expect(find.text(en.settingsNotificationsTurnOn), findsNothing);

    await tester.tap(find.text(en.settingsNotificationsOpenSettings));
    await tester.pumpAndSettle();

    expect(launcher.openCalls, 1);
    // And it never asked the OS — the dialog is already spent.
    expect(source.permissionRequests, 0);
  });

  testWidgets(
    'a Settings launch the OS REFUSES says so, and does not pretend',
    (tester) async {
      source.status = PushPermission.denied;
      launcher.failWith = const NotificationSettingsException('channel-error');
      await pumpRow(tester);

      await tester.tap(find.text(en.settingsNotificationsOpenSettings));
      await tester.pumpAndSettle();

      expect(find.text(en.settingsNotificationsOpenFailed), findsOneWidget);
    },
  );

  testWidgets('a NEVER-ASKED permission offers the prompt, and it works', (
    tester,
  ) async {
    source
      ..status = PushPermission.notDetermined
      ..ready = true;
    await pumpRow(tester);

    expect(find.text(en.settingsNotificationsSubtitleOff), findsOneWidget);

    await tester.tap(find.text(en.settingsNotificationsTurnOn));
    await tester.pumpAndSettle();

    expect(source.permissionRequests, 1);
    expect(repository.registered, ['device-token']);
    expect(find.text(en.settingsNotificationsSubtitleOn), findsOneWidget);
  });

  testWidgets('GRANTED but no token offers Try again, and a later try lands', (
    tester,
  ) async {
    // The signature of the one runtime link ADR-042 left UNVERIFIED, and the
    // reason ADR-046 D6 stopped relying on method swizzling alone.
    source
      ..status = PushPermission.granted
      ..ready = false;
    await pumpRow(tester);

    expect(find.text(en.settingsNotificationsSubtitleAwaiting), findsOneWidget);
    expect(find.text(en.settingsNotificationsRetry), findsOneWidget);

    // APNs answers in the meantime.
    source.ready = true;
    await tester.tap(find.text(en.settingsNotificationsRetry));
    await tester.pumpAndSettle();

    expect(repository.registered, ['device-token']);
    expect(find.text(en.settingsNotificationsSubtitleOn), findsOneWidget);
  });

  testWidgets('mounting the row NEVER spends the one-per-install dialog', (
    tester,
  ) async {
    // The load-bearing property of ADR-046 D1. Opening Settings must not be able
    // to consume the prompt: iOS gives exactly one, and the paired-home ask
    // (ADR-042 D6) is where it is supposed to be spent.
    source.status = PushPermission.notDetermined;
    await pumpRow(tester);
    await pumpRow(tester);

    expect(source.permissionRequests, 0);
  });

  for (final locale in supportedTestLocales) {
    testWidgets('renders in ${locale.languageCode} with no overflow', (
      tester,
    ) async {
      source.status = PushPermission.denied;
      await tester.pumpWidget(
        localizedApp(
          const Scaffold(body: NotificationPermissionRow()),
          locale: locale,
          overrides: overrides(),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(l10nFor(locale).settingsNotificationsSubtitleDenied),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
