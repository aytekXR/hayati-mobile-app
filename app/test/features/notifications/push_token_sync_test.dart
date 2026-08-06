import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/auth/domain/auth_repository_provider.dart';
import 'package:hayati_app/features/auth/domain/auth_user.dart';
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

  final StreamController<String> refreshes =
      StreamController<String>.broadcast();

  Future<void> dispose() => refreshes.close();

  @override
  Future<String?> currentToken() async {
    currentTokenCalls++;
    if (currentTokenThrows != null) throw currentTokenThrows!;
    return token;
  }

  @override
  Stream<String> tokenRefreshes() => refreshes.stream;
}

void main() {
  const uid = 'uid-1';
  const user = AuthUser(uid: uid);
  const other = AuthUser(uid: 'uid-2');

  late _FakeRepository repository;
  late _FakeSource source;

  ProviderContainer containerFor(FakeAuthRepository auth) {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWith((ref) => auth),
        pushTokenRepositoryProvider.overrideWith((ref) => repository),
        pushTokenSourceProvider.overrideWith((ref) => source),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(auth.dispose);
    return container;
  }

  setUp(() {
    repository = _FakeRepository();
    source = _FakeSource();
  });

  tearDown(() => source.dispose());

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

  test('a throwing token source never escapes', () async {
    source.currentTokenThrows = Exception('no APNs token');
    final auth = FakeAuthRepository(initialUser: user);
    final container = containerFor(auth);

    container.read(pushTokenSyncProvider);
    await pumpEventQueue();

    expect(repository.registered, isEmpty);
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
