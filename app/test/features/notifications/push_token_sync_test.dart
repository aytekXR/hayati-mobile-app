import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/auth/domain/auth_repository_provider.dart';
import 'package:hayati_app/features/auth/domain/auth_user.dart';
import 'package:hayati_app/features/notifications/domain/push_diagnostic.dart';
import 'package:hayati_app/features/notifications/domain/push_diagnostic_recorder_provider.dart';
import 'package:hayati_app/features/notifications/domain/push_registration.dart';
import 'package:hayati_app/features/notifications/domain/push_token_repository.dart';
import 'package:hayati_app/features/notifications/domain/push_token_repository_provider.dart';
import 'package:hayati_app/features/notifications/domain/push_token_source.dart';
import 'package:hayati_app/features/notifications/domain/push_token_source_provider.dart';
import 'package:hayati_app/features/notifications/presentation/state/push_token_sync.dart';

import '../../support/fake_auth_repository.dart';

/// The FCM token lifecycle, proven with no `firebase_messaging`, no Mac and no
/// APNs key — which is the entire purpose of the [PushTokenSource] seam
/// (ADR-042 D2).
///
/// What is under test is not "does it call the callable" but WHEN, and the two
/// rules that carry the privacy properties:
///   * a token is registered on every sign-in, INCLUDING a warm start where the
///     auth state is already signed-in before anything can listen;
///   * the token is removed on sign-out — because a token that outlives a
///     sign-out delivers the next user's pushes to the previous user's phone.

class _FakeRepository implements PushTokenRepository {
  final List<String> registered = [];
  final List<String> unregistered = [];
  Exception? failWith;

  @override
  Future<void> register(String token) async {
    if (failWith != null) throw failWith!;
    registered.add(token);
  }

  @override
  Future<void> unregister(String token) async {
    if (failWith != null) throw failWith!;
    unregistered.add(token);
  }
}

class _FakeSource implements PushTokenSource {
  String? token = 'device-token';
  Exception? currentTokenThrows;
  int currentTokenCalls = 0;

  /// How many readiness probes answer "not yet" before the platform is ready.
  /// This is the iOS APNs handshake, which completes AFTER the permission grant
  /// returns — the window ADR-044's retry exists for.
  int notReadyForFirst = 0;
  int readyCalls = 0;

  /// How many `currentToken` calls throw before one succeeds — iOS's
  /// `apns-token-not-set`, which is a THROW rather than a null.
  int throwsForFirst = 0;

  bool permissionGranted = true;
  Exception? permissionThrows;
  int permissionCalls = 0;

  /// What a NON-prompting read of the permission answers (ADR-046 D1). Distinct
  /// from [permissionGranted] on purpose: `permissionStatus` exists as its own
  /// method precisely because reading and asking are different acts, and a fake
  /// that conflated them could not catch a caller that asked when it meant to
  /// read — the one mistake that spends iOS's single per-install dialog.
  PushPermission? statusOverride;
  Exception? statusThrows;
  int statusCalls = 0;

  @override
  Future<PushPermission> permissionStatus() async {
    statusCalls++;
    if (statusThrows != null) throw statusThrows!;
    if (statusOverride != null) return statusOverride!;
    return _granted ? PushPermission.granted : PushPermission.notDetermined;
  }

  /// Model the iOS contract rather than a convenient one: before a permission
  /// grant, iOS mints NO token at all. Default false so the warm-start tests
  /// keep modelling the ordinary case — permission granted in an earlier
  /// session, so a restored sign-in gets a token with no prompt.
  bool tokenOnlyAfterPermission = false;
  bool _granted = false;

  @override
  Future<bool> ensurePermission() async {
    permissionCalls++;
    if (permissionThrows != null) throw permissionThrows!;
    _granted = permissionGranted;
    return permissionGranted;
  }

  final StreamController<String> refreshes =
      StreamController<String>.broadcast();

  Future<void> dispose() => refreshes.close();

  @override
  Future<bool> isReadyForToken() async {
    readyCalls++;
    if (tokenOnlyAfterPermission && !_granted) return false;
    return readyCalls > notReadyForFirst;
  }

  @override
  Future<String?> currentToken() async {
    currentTokenCalls++;
    if (currentTokenThrows != null) throw currentTokenThrows!;
    if (currentTokenCalls <= throwsForFirst) {
      throw Exception('[firebase_messaging/apns-token-not-set]');
    }
    return token;
  }

  @override
  Stream<String> tokenRefreshes() => refreshes.stream;
}

/// Captures what the device would have told the SERVER about itself (ADR-049).
class _FakeRecorder implements PushDiagnosticRecorder {
  final List<(String, PushDiagnostic)> recorded = [];
  Exception? failWith;

  @override
  Future<void> record(String uid, PushDiagnostic diagnostic) async {
    if (failWith != null) throw failWith!;
    recorded.add((uid, diagnostic));
  }

  List<PushDiagnostic> get diagnostics => [for (final r in recorded) r.$2];
  List<String> get uids => [for (final r in recorded) r.$1];
}

void main() {
  const uid = 'uid-1';
  const user = AuthUser(uid: uid);
  const other = AuthUser(uid: 'uid-2');

  late _FakeRepository repository;
  late _FakeSource source;
  late _FakeRecorder recorder;

  ProviderContainer containerFor(
    FakeAuthRepository auth, {
    bool wireRecorder = true,
  }) {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWith((ref) => auth),
        pushTokenRepositoryProvider.overrideWith((ref) => repository),
        pushTokenSourceProvider.overrideWith((ref) => source),
        // Left UNOVERRIDDEN by the `wireRecorder: false` cases on purpose: the
        // base provider throws, which is what every widget test that builds the
        // app without wiring notifications sees.
        if (wireRecorder)
          pushDiagnosticRecorderProvider.overrideWith((ref) => recorder),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(auth.dispose);
    return container;
  }

  setUp(() {
    repository = _FakeRepository();
    source = _FakeSource();
    recorder = _FakeRecorder();
    // The retry is PROVEN, not asserted — so it must run in milliseconds. The
    // attempt COUNT is left at its shipped value on purpose: a test that also
    // shrank that would stop guarding the bound it exists to guard.
    PushTokenSync.tokenCaptureBackoff = Duration.zero;
  });

  tearDown(() {
    PushTokenSync.tokenCaptureBackoff = const Duration(milliseconds: 500);
    source.dispose();
  });

  test('warm start: a restored signed-in session registers the current token '
      'with no auth event', () async {
    // ref.listen never fires for the value already present, and
    // AuthController.build() seeds AuthSignedIn synchronously on a restored
    // session. A listen-only design would skip registration on every warm start
    // — the exact shape PurchasesIdentitySync was written to avoid.
    final auth = FakeAuthRepository(initialUser: user);
    final container = containerFor(auth);

    container.read(pushTokenSyncProvider);
    await pumpEventQueue();

    expect(repository.registered, ['device-token']);
  });

  test('registers on a runtime sign-in transition', () async {
    final auth = FakeAuthRepository();
    final container = containerFor(auth);
    container.read(pushTokenSyncProvider);
    await pumpEventQueue();
    expect(repository.registered, isEmpty);

    auth.emit(user);
    await pumpEventQueue();

    expect(repository.registered, ['device-token']);
  });

  test('does not re-register for the same uid', () async {
    final auth = FakeAuthRepository(initialUser: user);
    final container = containerFor(auth);
    container.read(pushTokenSyncProvider);
    await pumpEventQueue();

    auth.emit(user);
    await pumpEventQueue();

    expect(repository.registered, ['device-token']);
  });

  // The privacy property this call exists for.
  test('sign-out UNREGISTERS the token', () async {
    final auth = FakeAuthRepository(initialUser: user);
    final container = containerFor(auth);
    container.read(pushTokenSyncProvider);
    await pumpEventQueue();

    auth.emit(null);
    await pumpEventQueue();

    expect(repository.unregistered, ['device-token']);
  });

  test(
    'sign-out removes the token it REGISTERED, not one re-read at sign-out',
    () async {
      final auth = FakeAuthRepository(initialUser: user);
      final container = containerFor(auth);
      container.read(pushTokenSyncProvider);
      await pumpEventQueue();

      // FCM rotated the token underneath us and the source now answers
      // differently. Removing the NEW token would leave the OLD one on the
      // signed-out user's document — the exact leak this call prevents.
      source.token = 'a-different-token';
      auth.emit(null);
      await pumpEventQueue();

      expect(repository.unregistered, ['device-token']);
    },
  );

  test('a sign-out with nothing registered unregisters nothing', () async {
    final auth = FakeAuthRepository();
    final container = containerFor(auth);
    container.read(pushTokenSyncProvider);
    await pumpEventQueue();

    auth.emit(null);
    await pumpEventQueue();

    expect(repository.unregistered, isEmpty);
  });

  test('re-registers when FCM rotates the token', () async {
    final auth = FakeAuthRepository(initialUser: user);
    final container = containerFor(auth);
    container.read(pushTokenSyncProvider);
    await pumpEventQueue();

    source.refreshes.add('rotated-token');
    await pumpEventQueue();

    expect(repository.registered, ['device-token', 'rotated-token']);
  });

  test('a rotated token becomes the one removed at sign-out', () async {
    final auth = FakeAuthRepository(initialUser: user);
    final container = containerFor(auth);
    container.read(pushTokenSyncProvider);
    await pumpEventQueue();
    source.refreshes.add('rotated-token');
    await pumpEventQueue();

    auth.emit(null);
    await pumpEventQueue();

    expect(repository.unregistered, ['rotated-token']);
  });

  test('a refresh arriving while signed OUT registers nothing', () async {
    final auth = FakeAuthRepository(initialUser: user);
    final container = containerFor(auth);
    container.read(pushTokenSyncProvider);
    await pumpEventQueue();
    auth.emit(null);
    await pumpEventQueue();
    repository.registered.clear();

    source.refreshes.add('rotated-token');
    await pumpEventQueue();

    expect(repository.registered, isEmpty);
  });

  // ADR-039 D1/D2: the boot is fail-open and every wait on the launch→paired
  // path is bounded. A device with no token yet is the NORMAL pre-permission
  // state, not an error.
  test('a null token registers nothing and does not throw', () async {
    source.token = null;
    final auth = FakeAuthRepository(initialUser: user);
    final container = containerFor(auth);

    container.read(pushTokenSyncProvider);
    await pumpEventQueue();

    expect(repository.registered, isEmpty);
  });

  test('an empty token registers nothing', () async {
    source.token = '';
    final auth = FakeAuthRepository(initialUser: user);
    final container = containerFor(auth);

    container.read(pushTokenSyncProvider);
    await pumpEventQueue();

    expect(repository.registered, isEmpty);
  });

  test('a permanently throwing token source never escapes', () async {
    source.currentTokenThrows = Exception('no APNs token');
    final auth = FakeAuthRepository(initialUser: user);
    final container = containerFor(auth);

    container.read(pushTokenSyncProvider);
    await pumpEventQueue();

    expect(repository.registered, isEmpty);
  });

  // ADR-044. THE regression group. The previous version of this file asserted
  // that a throwing `currentToken` was a silent no-op — which is exactly what
  // the bug was, so the test converted the defect into a specification and
  // nothing could ever go red. On iOS `getToken()` THROWS `apns-token-not-set`
  // until APNs answers, and APNs answers AFTER the permission grant returns, so
  // the single capture attempt was issued inside the one window where iOS
  // guarantees it fails. Measured consequence in production: `registerPushToken`
  // was never once invoked across builds 115-117, while the server sweep was
  // logging `checked:1  skippedNoToken:2` at the couple's 08:00.
  group('capture survives the iOS APNs handshake (ADR-044)', () {
    test(
      'a token that only arrives on a LATER attempt is still registered',
      () async {
        source.throwsForFirst = 3; // apns-token-not-set, three times
        final auth = FakeAuthRepository(initialUser: user);
        final container = containerFor(auth);

        container.read(pushTokenSyncProvider);
        await pumpEventQueue();

        expect(repository.registered, ['device-token']);
        expect(source.currentTokenCalls, 4);
      },
    );

    test(
      'a platform that is not READY yet is waited for, not given up on',
      () async {
        source.notReadyForFirst = 2; // APNs has not handed over a device token
        final auth = FakeAuthRepository(initialUser: user);
        final container = containerFor(auth);

        container.read(pushTokenSyncProvider);
        await pumpEventQueue();

        expect(repository.registered, ['device-token']);
        // It did not ask for a token while the platform said it could not mint
        // one — asking anyway is what threw.
        expect(source.currentTokenCalls, 1);
      },
    );

    test(
      'the retry is BOUNDED — a device that never becomes ready stops',
      () async {
        source.notReadyForFirst = 9999;
        final auth = FakeAuthRepository(initialUser: user);
        final container = containerFor(auth);

        container.read(pushTokenSyncProvider);
        await pumpEventQueue();

        expect(repository.registered, isEmpty);
        // ADR-039 D2: never an unbounded wait on the launch->paired path.
        //
        // The LITERAL, deliberately — not `PushTokenSync.tokenCaptureAttempts`.
        // Asserting against the constant under test is satisfied by its own
        // subject (lesson 75): doubling the budget would move both sides and this
        // check would stay green while the bound it exists to guard had changed.
        // Caught by the mutation harness, which is what it is for.
        expect(source.readyCalls, 6);
        expect(PushTokenSync.tokenCaptureAttempts, 6);
        expect(source.currentTokenCalls, 0);
      },
    );

    // The regression this fix itself introduced, caught by the full suite and
    // pinned here. A container with no source override is the pre-D2-step-4
    // state AND every widget test that builds the app — resolving the SOURCE is
    // not a transient failure, so retrying it only schedules timers, and
    // `pumpAndSettle` never settles while a timer is pending. It took 60
    // unrelated widget tests red.
    testWidgets('NO source override: gives up at once and leaves no pending '
        'timer for pumpAndSettle to wait on', (tester) async {
      final auth = FakeAuthRepository(initialUser: user);
      addTearDown(auth.dispose);
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWith((ref) => auth),
          pushTokenRepositoryProvider.overrideWith((ref) => repository),
          // pushTokenSourceProvider deliberately NOT overridden.
        ],
      );
      addTearDown(container.dispose);

      container.read(pushTokenSyncProvider);
      await tester.pumpAndSettle();

      expect(repository.registered, isEmpty);
    });

    test('a sign-out mid-retry abandons the capture', () async {
      source.notReadyForFirst = 9999;
      final auth = FakeAuthRepository(initialUser: user);
      final container = containerFor(auth);

      container.read(pushTokenSyncProvider);
      auth.emit(null);
      await pumpEventQueue();

      expect(repository.registered, isEmpty);
      // It stopped early rather than holding the loop open for an account that
      // is gone: strictly fewer probes than the full budget.
      expect(source.readyCalls, lessThan(6));
    });
  });

  test('a failing repository never escapes', () async {
    repository.failWith = Exception('callable unavailable');
    final auth = FakeAuthRepository(initialUser: user);
    final container = containerFor(auth);

    container.read(pushTokenSyncProvider);
    await pumpEventQueue();

    // The assertion is that pumping the queue completed with no unhandled
    // error: a background sync must never take down the tree.
    expect(repository.registered, isEmpty);
  });

  // ADR-042 D6. THE call that makes everything else do anything on iOS: without
  // a permission grant `getToken()` returns nothing, so the entitlement, the
  // plugin, the callables and the sweeps are all correct and SILENT. That
  // failure mode has no error surface, which is why it gets its own group.
  group('promptForPermissionAndRegister (ADR-042 D6)', () {
    // The group's premise, now actually modelled: on iOS no token exists before
    // the grant, so a sign-in alone registers nothing and this call is the only
    // thing that can produce one.
    setUp(() => source.tokenOnlyAfterPermission = true);

    test('grants -> captures the token and registers it', () async {
      final auth = FakeAuthRepository(initialUser: user);
      final container = containerFor(auth);
      final sync = container.read(pushTokenSyncProvider.notifier);
      await pumpEventQueue();
      // Nothing registered yet: the source answers only after permission, which
      // is the whole shape of the iOS contract.
      repository.registered.clear();

      final granted = await sync.promptForPermissionAndRegister();

      expect(granted, isTrue);
      expect(source.permissionCalls, 1);
      expect(repository.registered, ['device-token']);
    });

    test('declines -> registers NOTHING, and that is not an error', () async {
      source.permissionGranted = false;
      final auth = FakeAuthRepository(initialUser: user);
      final container = containerFor(auth);
      final sync = container.read(pushTokenSyncProvider.notifier);
      await pumpEventQueue();
      repository.registered.clear();

      final granted = await sync.promptForPermissionAndRegister();

      expect(granted, isFalse);
      expect(repository.registered, isEmpty);
    });

    // iOS shows its dialog once per install and never again. The guard is not
    // about the dialog — it is about not re-entering the capture path on every
    // rebuild of the screen that calls this.
    test('prompts at most ONCE, however many times it is called', () async {
      final auth = FakeAuthRepository(initialUser: user);
      final container = containerFor(auth);
      final sync = container.read(pushTokenSyncProvider.notifier);
      await pumpEventQueue();

      await sync.promptForPermissionAndRegister();
      await sync.promptForPermissionAndRegister();
      await sync.promptForPermissionAndRegister();

      expect(source.permissionCalls, 1);
    });

    // ADR-044 D3. The guard used to latch BEFORE permission was requested, so a
    // capture that failed was permanent for the life of the process — on iOS,
    // the likely outcome. It now guards re-entrancy only.
    test(
      'a GRANTED permission whose capture failed is retried on a later call',
      () async {
        source.notReadyForFirst = 9999; // APNs never answers this time round
        final auth = FakeAuthRepository(initialUser: user);
        final container = containerFor(auth);
        final sync = container.read(pushTokenSyncProvider.notifier);
        await pumpEventQueue();

        expect(await sync.promptForPermissionAndRegister(), isFalse);
        expect(repository.registered, isEmpty);

        // The phone finishes its APNs registration a moment later.
        source.notReadyForFirst = 0;

        expect(await sync.promptForPermissionAndRegister(), isTrue);
        expect(repository.registered, ['device-token']);
      },
    );

    test('a throwing permission call never escapes', () async {
      source.permissionThrows = Exception('no notification centre');
      final auth = FakeAuthRepository(initialUser: user);
      final container = containerFor(auth);
      final sync = container.read(pushTokenSyncProvider.notifier);
      await pumpEventQueue();

      expect(await sync.promptForPermissionAndRegister(), isFalse);
    });

    // The boot path must never touch this: ADR-039 D1 makes the boot fail-open
    // and D2 bounds every wait on launch->paired. A permission prompt is an
    // indefinite wait on a human, so nothing on that path may trigger it.
    test(
      'is NEVER triggered by sign-in alone — only by an explicit call',
      () async {
        final auth = FakeAuthRepository();
        final container = containerFor(auth);
        container.read(pushTokenSyncProvider);
        await pumpEventQueue();

        auth.emit(user);
        await pumpEventQueue();

        expect(source.permissionCalls, 0);
      },
    );
  });

  // ─────────────────────────────────────────────────────────────────────────
  // ADR-046: the five states, and the retry that is no longer once-only.
  //
  // Every one of these covers a production failure that was INVISIBLE until
  // 2026-08-16: four accounts, zero registered devices, zero HTTP requests ever
  // reaching `registerPushToken`, and every server-side layer verified working.
  // What made it unfixable for five sessions was not that it failed — it is that
  // the four ways it can fail all looked exactly like each other, and like
  // success.
  // ─────────────────────────────────────────────────────────────────────────
  group('PushRegistration state (ADR-046 D2)', () {
    test(
      'a warm start that registers PUBLISHES it — not just internally',
      () async {
        // The regression this guards is subtle and was live: the old code gated
        // `state =` on an `initial` flag threaded from build(), so a restored
        // session registered a token and never published it. Invisible while
        // nothing read the value; a permanently blank settings row now that the
        // row exists.
        final auth = FakeAuthRepository(initialUser: user);
        final container = containerFor(auth);
        container.read(pushTokenSyncProvider);
        await pumpEventQueue();

        expect(
          container.read(pushTokenSyncProvider),
          const PushRegistration(
            state: PushRegistrationState.registered,
            token: 'device-token',
          ),
        );
      },
    );

    test('a DECLINED prompt is recorded as denied, not merely logged', () async {
      // iOS shows its dialog once per install. After this, no rebuild and no
      // re-prompt recovers — only the Settings app does, and nothing could say
      // so while this was a debugPrint.
      source
        ..tokenOnlyAfterPermission = true
        ..permissionGranted = false;
      final auth = FakeAuthRepository(initialUser: user);
      final container = containerFor(auth);
      final sync = container.read(pushTokenSyncProvider.notifier);
      await pumpEventQueue();

      await sync.promptForPermissionAndRegister();

      expect(
        container.read(pushTokenSyncProvider).state,
        PushRegistrationState.denied,
      );
      expect(container.read(pushTokenSyncProvider).needsSystemSettings, isTrue);
    });

    test('permission held but no token settles on awaitingDeviceToken', () async {
      // The signature of the one runtime link ADR-042 left UNVERIFIED: APNs
      // never hands over a device token, so all six ADR-044 attempts fail.
      // `statusOverride` is what makes this case DISTINCT from a decline — the
      // exhausted loop asks the OS rather than guessing, precisely so a denied
      // phone is never labelled "allowed, just not finished yet".
      source
        ..statusOverride = PushPermission.granted
        ..notReadyForFirst = 9999;
      final auth = FakeAuthRepository(initialUser: user);
      final container = containerFor(auth);
      container.read(pushTokenSyncProvider);
      await pumpEventQueue();

      expect(
        container.read(pushTokenSyncProvider).state,
        PushRegistrationState.awaitingDeviceToken,
      );
      expect(container.read(pushTokenSyncProvider).token, isNull);
    });

    test(
      'a registration that THROWS is awaitingDeviceToken, not registered',
      () async {
        // The device has an address and the server does not. Same remedy, same
        // sentence to the user — and emphatically not "on".
        repository.failWith = Exception('callable refused');
        final auth = FakeAuthRepository(initialUser: user);
        final container = containerFor(auth);
        container.read(pushTokenSyncProvider);
        await pumpEventQueue();

        expect(
          container.read(pushTokenSyncProvider).state,
          PushRegistrationState.awaitingDeviceToken,
        );
        expect(container.read(pushTokenSyncProvider).isRegistered, isFalse);
      },
    );

    test('sign-out clears the state as well as the token', () async {
      final auth = FakeAuthRepository(initialUser: user);
      final container = containerFor(auth);
      container.read(pushTokenSyncProvider);
      await pumpEventQueue();
      expect(container.read(pushTokenSyncProvider).isRegistered, isTrue);

      auth.emit(null);
      await pumpEventQueue();

      expect(container.read(pushTokenSyncProvider), PushRegistration.unknown);
      expect(repository.unregistered, ['device-token']);
    });
  });

  test(
    'a LATE failure never demotes a registration that already landed',
    () async {
      // Two captures can be in flight: the boot one, and the fresh one
      // `promptForPermissionAndRegister` deliberately starts rather than joining
      // (joining would spend the user's tap on a run that began before the
      // grant). The boot run can finish EMPTY a moment after the prompt's run
      // succeeded — and without a guard it overwrites `registered` with
      // `awaitingDeviceToken`, showing a Try again button to a phone that is
      // already reachable.
      final auth = FakeAuthRepository(initialUser: user);
      final container = containerFor(auth);
      final sync = container.read(pushTokenSyncProvider.notifier);
      await pumpEventQueue();
      expect(container.read(pushTokenSyncProvider).isRegistered, isTrue);

      // Now make every subsequent capture fail, and drive one.
      source
        ..notReadyForFirst = 9999
        ..statusOverride = PushPermission.denied;
      await sync.refresh();

      expect(
        container.read(pushTokenSyncProvider).state,
        PushRegistrationState.registered,
        reason: 'a token already registered is the strongest evidence there is',
      );
      expect(container.read(pushTokenSyncProvider).token, 'device-token');
    },
  );

  group('refresh (ADR-046 D1/D5)', () {
    test('READS the permission and never prompts', () async {
      // The load-bearing property of the whole slice. `refresh()` runs on every
      // paired-home resume and every settings mount; if it could prompt, simply
      // opening Settings would spend iOS's one-per-install dialog.
      source.tokenOnlyAfterPermission = true;
      final auth = FakeAuthRepository(initialUser: user);
      final container = containerFor(auth);
      final sync = container.read(pushTokenSyncProvider.notifier);
      await pumpEventQueue();

      await sync.refresh();
      await sync.refresh();

      expect(source.permissionCalls, 0);
      expect(source.statusCalls, greaterThan(0));
    });

    test('a DENIED permission read settles on denied', () async {
      source
        ..tokenOnlyAfterPermission = true
        ..statusOverride = PushPermission.denied;
      final auth = FakeAuthRepository(initialUser: user);
      final container = containerFor(auth);
      final sync = container.read(pushTokenSyncProvider.notifier);
      await pumpEventQueue();

      expect((await sync.refresh()).state, PushRegistrationState.denied);
    });

    test('a NEVER-ASKED permission read settles on notDetermined', () async {
      source
        ..tokenOnlyAfterPermission = true
        ..statusOverride = PushPermission.notDetermined;
      final auth = FakeAuthRepository(initialUser: user);
      final container = containerFor(auth);
      final sync = container.read(pushTokenSyncProvider.notifier);
      await pumpEventQueue();

      expect((await sync.refresh()).state, PushRegistrationState.notDetermined);
      expect(repository.registered, isEmpty);
    });

    test(
      'the trip to iOS Settings and back: denied -> granted registers on resume',
      () async {
        // THE scenario this ADR exists for. A user who declined on build 116 is
        // permanently denied; the only cure is the Settings app, and the only
        // moment the app can notice is the resume afterwards.
        source
          ..tokenOnlyAfterPermission = true
          ..statusOverride = PushPermission.denied;
        final auth = FakeAuthRepository(initialUser: user);
        final container = containerFor(auth);
        final sync = container.read(pushTokenSyncProvider.notifier);
        await pumpEventQueue();

        expect((await sync.refresh()).state, PushRegistrationState.denied);
        expect(repository.registered, isEmpty);

        // The user flips the switch in iOS Settings and comes back.
        source
          ..statusOverride = PushPermission.granted
          ..tokenOnlyAfterPermission = false;

        final settled = await sync.refresh();

        expect(settled.state, PushRegistrationState.registered);
        expect(settled.token, 'device-token');
        expect(repository.registered, ['device-token']);
        // And it got there without ever asking — iOS's one dialog is untouched.
        expect(source.permissionCalls, 0);
      },
    );

    test('a bounded capture that gave up is RETRIED by a later refresh', () async {
      // ADR-046 D5: bounded is not once-only. The old code gave up after ~7.5s
      // and stayed given-up for the life of the process.
      // NOT `tokenOnlyAfterPermission`: this test is about APNs readiness, and
      // the fake gates that on an actual `ensurePermission()` call. Permission
      // is already held here — which is exactly the case ADR-046 D5 covers, a
      // grant whose capture window closed before the platform was ready.
      source
        ..statusOverride = PushPermission.granted
        ..notReadyForFirst = 9999;
      final auth = FakeAuthRepository(initialUser: user);
      final container = containerFor(auth);
      final sync = container.read(pushTokenSyncProvider.notifier);
      await pumpEventQueue();

      expect(
        (await sync.refresh()).state,
        PushRegistrationState.awaitingDeviceToken,
      );

      // The phone finishes its APNs registration a moment later.
      source.notReadyForFirst = 0;

      expect((await sync.refresh()).state, PushRegistrationState.registered);
      expect(repository.registered, ['device-token']);
    });

    test(
      'a refresh on a device that is already registered is a no-op',
      () async {
        final auth = FakeAuthRepository(initialUser: user);
        final container = containerFor(auth);
        final sync = container.read(pushTokenSyncProvider.notifier);
        await pumpEventQueue();
        final before = source.statusCalls;

        await sync.refresh();

        expect(source.statusCalls, before);
        expect(repository.registered, ['device-token']);
      },
    );

    test(
      'a refresh while SIGNED OUT reports unknown and registers nothing',
      () async {
        final auth = FakeAuthRepository();
        final container = containerFor(auth);
        final sync = container.read(pushTokenSyncProvider.notifier);
        await pumpEventQueue();

        expect(await sync.refresh(), PushRegistration.unknown);
        expect(source.statusCalls, 0);
        expect(repository.registered, isEmpty);
      },
    );

    test('a THROWING status read never escapes and changes nothing', () async {
      source
        ..tokenOnlyAfterPermission = true
        ..statusThrows = Exception('no notification centre');
      final auth = FakeAuthRepository(initialUser: user);
      final container = containerFor(auth);
      final sync = container.read(pushTokenSyncProvider.notifier);
      await pumpEventQueue();
      final before = container.read(pushTokenSyncProvider);

      expect(await sync.refresh(), before);
    });
  });

  // ADR-049. The four device-side failures ADR-046 named on the PHONE, reported
  // where a session can read them. What is under test is the DISCRIMINATION — a
  // report that cannot tell "the callable threw" from "APNs never answered" is
  // the ambiguity this whole field exists to end — and the three rules that stop
  // the field from lying: no `unknown`, no overwrite of a specific fact by a
  // vague one, and no report attributed to the wrong account.
  group('the device reports what happened (ADR-049)', () {
    test('success is stated out loud, not implied', () async {
      final auth = FakeAuthRepository(initialUser: user);
      final container = containerFor(auth);
      container.read(pushTokenSyncProvider);
      await pumpEventQueue();

      expect(recorder.uids, [uid]);
      expect(recorder.diagnostics, [
        const PushDiagnostic(state: PushRegistrationState.registered),
      ]);
    });

    test(
      'a refused permission request records that the prompt path RAN',
      () async {
        source
          ..tokenOnlyAfterPermission = true
          ..permissionGranted = false;
        final auth = FakeAuthRepository(initialUser: user);
        final container = containerFor(auth);
        final sync = container.read(pushTokenSyncProvider.notifier);
        await pumpEventQueue();
        recorder.recorded.clear();

        await sync.promptForPermissionAndRegister();
        await pumpEventQueue();

        // `permissionRequestRefused`, not "the user declined": iOS answers from its
        // standing record after the first dialog, so a tap cannot be inferred.
        expect(recorder.diagnostics, [
          const PushDiagnostic(
            state: PushRegistrationState.denied,
            detail: PushDiagnosticDetail.permissionRequestRefused,
          ),
        ]);
      },
    );

    // THE #219 DISCRIMINATION. Both of these settle the SCREEN on
    // awaitingDeviceToken — ADR-046 D2 merged them deliberately, because the
    // remedy and the sentence are identical for the person holding the phone.
    // For a session they are two different broken links, and telling them apart
    // is what cost 37 hours.
    test(
      'a failed callable is recorded as registerFailed, not as an APNs stall',
      () async {
        repository.failWith = Exception('callable unreachable');
        final auth = FakeAuthRepository(initialUser: user);
        final container = containerFor(auth);
        container.read(pushTokenSyncProvider);
        await pumpEventQueue();

        expect(recorder.diagnostics, [
          const PushDiagnostic(
            state: PushRegistrationState.awaitingDeviceToken,
            detail: PushDiagnosticDetail.registerFailed,
          ),
        ]);
      },
    );

    test(
      'an exhausted capture with permission held is recorded as captureExhausted',
      () async {
        source
          ..tokenOnlyAfterPermission = true
          ..statusOverride = PushPermission.granted;
        final auth = FakeAuthRepository(initialUser: user);
        final container = containerFor(auth);
        container.read(pushTokenSyncProvider);
        await pumpEventQueue();

        expect(recorder.diagnostics, [
          const PushDiagnostic(
            state: PushRegistrationState.awaitingDeviceToken,
            detail: PushDiagnosticDetail.captureExhausted,
          ),
        ]);
      },
    );

    // A permission read that THREW is two links away from an APNs stall, and the
    // capture loop settles on the same state for both. Without a distinct detail
    // the report would blame APNs for a broken plugin seam — the ADR's own defect
    // reintroduced one level down.
    test('a THROWING permission read outranks captureExhausted', () async {
      source
        ..tokenOnlyAfterPermission = true
        ..statusThrows = Exception('no notification centre');
      final auth = FakeAuthRepository(initialUser: user);
      final container = containerFor(auth);
      container.read(pushTokenSyncProvider);
      await pumpEventQueue();

      expect(recorder.diagnostics, [
        const PushDiagnostic(
          state: PushRegistrationState.awaitingDeviceToken,
          detail: PushDiagnosticDetail.permissionUnreadable,
        ),
      ]);
    });

    // refresh()'s own catch used to emit NOTHING, so a broken messaging seam was
    // invisible even on the phone. It now reports — without demoting the last
    // successful measurement, because a read that failed is not evidence that a
    // known `denied` has become "waiting".
    test(
      'a throwing refresh reports the seam WITHOUT demoting a known denial',
      () async {
        source
          ..tokenOnlyAfterPermission = true
          ..statusOverride = PushPermission.denied;
        final auth = FakeAuthRepository(initialUser: user);
        final container = containerFor(auth);
        final sync = container.read(pushTokenSyncProvider.notifier);
        await pumpEventQueue();
        expect(
          container.read(pushTokenSyncProvider).state,
          PushRegistrationState.denied,
        );
        recorder.recorded.clear();

        source.statusThrows = Exception('no notification centre');
        await sync.refresh();
        await pumpEventQueue();

        expect(recorder.diagnostics, [
          const PushDiagnostic(
            state: PushRegistrationState.denied,
            detail: PushDiagnosticDetail.permissionUnreadable,
          ),
        ]);
        expect(
          container.read(pushTokenSyncProvider).state,
          PushRegistrationState.denied,
        );
      },
    );

    // ⚠️ WHAT THIS PROVES, AND WHAT IT DOES NOT. It proves the SIGN-OUT half:
    // once the account is gone there is nothing to annotate, and the write is not
    // attempted — a write there could only earn a permission-denied to swallow.
    //
    // It does NOT prove the `unknown` guard in `_record`. A mutation run deleted
    // that line and this suite stayed green, because both sites that emit
    // `unknown` (the sign-out removal and the signed-out `refresh`) already run
    // with a null uid, so the uid check turns them away first. The guard is a
    // second line of defence against a future emit of `unknown` while signed in,
    // and this suite cannot falsify it — said here rather than left as a green
    // tick that measures nothing.
    test(
      'sign-out records NOTHING — there is no account left to annotate',
      () async {
        final auth = FakeAuthRepository(initialUser: user);
        final container = containerFor(auth);
        container.read(pushTokenSyncProvider);
        await pumpEventQueue();
        final afterSignIn = recorder.recorded.length;

        auth.emit(null);
        await pumpEventQueue();

        expect(recorder.recorded, hasLength(afterSignIn));
        expect(
          recorder.diagnostics.map((d) => d.state),
          everyElement(isNot(PushRegistrationState.unknown)),
        );
      },
    );

    test('reports once per observation, not once per resume', () async {
      source
        ..tokenOnlyAfterPermission = true
        ..statusOverride = PushPermission.denied;
      final auth = FakeAuthRepository(initialUser: user);
      final container = containerFor(auth);
      final sync = container.read(pushTokenSyncProvider.notifier);
      await pumpEventQueue();
      final afterBoot = recorder.recorded.length;

      await sync.refresh();
      await sync.refresh();
      await pumpEventQueue();

      expect(recorder.recorded, hasLength(afterBoot));
    });

    // The rule that keeps the single most valuable fact alive: a later, vaguer
    // observation of the SAME state must not erase the one that named how the
    // device got there.
    test('a vague repeat never overwrites a specific report', () async {
      source
        ..tokenOnlyAfterPermission = true
        ..permissionGranted = false
        ..statusOverride = PushPermission.denied;
      final auth = FakeAuthRepository(initialUser: user);
      final container = containerFor(auth);
      final sync = container.read(pushTokenSyncProvider.notifier);
      await pumpEventQueue();
      await sync.promptForPermissionAndRegister();
      await pumpEventQueue();
      expect(
        recorder.diagnostics.last.detail,
        PushDiagnosticDetail.permissionRequestRefused,
      );

      await sync.refresh();
      await pumpEventQueue();

      expect(
        recorder.diagnostics.last.detail,
        PushDiagnosticDetail.permissionRequestRefused,
      );
    });

    // A uid change with no sign-out between it (a token swap, a credential link)
    // still starts B's reporting from nothing — otherwise B's document stays
    // silent about a device that measured itself, purely because A happened to be
    // in the same state.
    test(
      'a second account reports for itself even in the same state',
      () async {
        repository.failWith = Exception('callable unreachable');
        final auth = FakeAuthRepository(initialUser: user);
        final container = containerFor(auth);
        container.read(pushTokenSyncProvider);
        await pumpEventQueue();

        auth.emit(other);
        await pumpEventQueue();

        expect(recorder.uids, [uid, other.uid]);
        expect(
          recorder.diagnostics.map((d) => d.detail),
          everyElement(PushDiagnosticDetail.registerFailed),
        );
      },
    );

    test(
      'a THROWING recorder never escapes and never costs a registration',
      () async {
        recorder.failWith = Exception('firestore unreachable');
        final auth = FakeAuthRepository(initialUser: user);
        final container = containerFor(auth);
        container.read(pushTokenSyncProvider);
        await pumpEventQueue();

        expect(repository.registered, ['device-token']);
        expect(container.read(pushTokenSyncProvider).isRegistered, isTrue);
      },
    );

    // The 60-widget-test trap, in the one place it would have been reintroduced:
    // the base provider throws by design, and an unguarded resolve here would
    // take every container that builds the app without wiring notifications red.
    test('an UNWIRED recorder is a logged no-op, not a failure', () async {
      final auth = FakeAuthRepository(initialUser: user);
      final container = containerFor(auth, wireRecorder: false);
      container.read(pushTokenSyncProvider);
      await pumpEventQueue();

      expect(repository.registered, ['device-token']);
      expect(container.read(pushTokenSyncProvider).isRegistered, isTrue);
    });
  });

  test('a second user signing in registers for that user', () async {
    final auth = FakeAuthRepository(initialUser: user);
    final container = containerFor(auth);
    container.read(pushTokenSyncProvider);
    await pumpEventQueue();

    auth.emit(other);
    await pumpEventQueue();

    expect(repository.registered, ['device-token', 'device-token']);
  });
}
