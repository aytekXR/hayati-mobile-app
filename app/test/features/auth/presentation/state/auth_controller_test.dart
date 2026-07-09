import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/auth/domain/auth_exception.dart';
import 'package:hayati_app/features/auth/domain/auth_repository_provider.dart';
import 'package:hayati_app/features/auth/domain/auth_state.dart';
import 'package:hayati_app/features/auth/domain/auth_user.dart';
import 'package:hayati_app/features/auth/presentation/state/auth_controller.dart';

import '../../../../support/fake_auth_repository.dart';

const testUser = AuthUser(uid: 'uid-1', displayName: 'Aytek');

void main() {
  (ProviderContainer, FakeAuthRepository) makeContainer({
    AuthUser? initialUser,
  }) {
    final fake = FakeAuthRepository(initialUser: initialUser);
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWith((ref) => fake)],
    );
    addTearDown(container.dispose);
    addTearDown(fake.dispose);
    return (container, fake);
  }

  group('initial state', () {
    test('signed out when the repository has no current user', () {
      final (container, _) = makeContainer();
      expect(container.read(authControllerProvider), const AuthSignedOut());
    });

    test('signed in when the repository restored a session', () {
      final (container, _) = makeContainer(initialUser: testUser);
      expect(
        container.read(authControllerProvider),
        const AuthSignedIn(testUser),
      );
    });
  });

  group('stream-driven transitions (no operation in flight)', () {
    test('a user emission moves the state to signed in', () async {
      final (container, fake) = makeContainer();
      expect(container.read(authControllerProvider), const AuthSignedOut());

      fake.emit(testUser);
      await pumpEventQueue();
      expect(
        container.read(authControllerProvider),
        const AuthSignedIn(testUser),
      );
    });

    test('a null emission moves the state to signed out', () async {
      final (container, fake) = makeContainer(initialUser: testUser);

      fake.emit(null);
      await pumpEventQueue();
      expect(container.read(authControllerProvider), const AuthSignedOut());
    });
  });

  group('signInWithGoogle', () {
    test(
      'happy path transitions signing-in then signed-in exactly once',
      () async {
        final (container, fake) = makeContainer();
        fake.onSignInWithGoogle = () async => testUser;

        final states = <AuthState>[];
        container.listen<AuthState>(
          authControllerProvider,
          (_, next) => states.add(next),
          fireImmediately: true,
        );

        await container
            .read(authControllerProvider.notifier)
            .signInWithGoogle();
        await pumpEventQueue();

        expect(states, const [
          AuthSignedOut(),
          AuthSigningIn(),
          AuthSignedIn(testUser),
        ]);
        expect(fake.signInCalls, 1);
      },
    );

    test('stream emissions cannot clobber an in-flight sign-in', () async {
      final (container, fake) = makeContainer();
      final completer = Completer<AuthUser>();
      fake.onSignInWithGoogle = () => completer.future;

      final notifier = container.read(authControllerProvider.notifier);
      final pending = notifier.signInWithGoogle();
      await pumpEventQueue();
      expect(container.read(authControllerProvider), const AuthSigningIn());

      // Firebase emits the current user (or null) while the manual operation
      // still owns the state — the emission must be ignored.
      fake.emit(null);
      await pumpEventQueue();
      expect(container.read(authControllerProvider), const AuthSigningIn());

      completer.complete(testUser);
      await pending;
      expect(
        container.read(authControllerProvider),
        const AuthSignedIn(testUser),
      );
    });

    test('cancellation returns to signed out, not error', () async {
      final (container, fake) = makeContainer();
      fake.onSignInWithGoogle = () async {
        throw const AuthCancelledException();
      };

      final states = <AuthState>[];
      container.listen<AuthState>(
        authControllerProvider,
        (_, next) => states.add(next),
        fireImmediately: true,
      );

      await container.read(authControllerProvider.notifier).signInWithGoogle();

      expect(states, const [AuthSignedOut(), AuthSigningIn(), AuthSignedOut()]);
    });

    test('a domain failure surfaces as AuthError', () async {
      final (container, fake) = makeContainer();
      fake.onSignInWithGoogle = () async {
        throw const AuthNetworkException(message: 'offline');
      };

      await container.read(authControllerProvider.notifier).signInWithGoogle();

      expect(
        container.read(authControllerProvider),
        const AuthError(AuthNetworkException(message: 'offline')),
      );
    });

    test(
      'overlapping calls are debounced to a single repository call',
      () async {
        final (container, fake) = makeContainer();
        final completer = Completer<AuthUser>();
        fake.onSignInWithGoogle = () => completer.future;

        final notifier = container.read(authControllerProvider.notifier);
        unawaited(notifier.signInWithGoogle());
        unawaited(notifier.signInWithGoogle());
        await pumpEventQueue();

        expect(fake.signInCalls, 1);

        completer.complete(testUser);
        await pumpEventQueue();
        expect(
          container.read(authControllerProvider),
          const AuthSignedIn(testUser),
        );
      },
    );

    test('a sign-in completing after disposal is dropped silently', () async {
      final fake = FakeAuthRepository();
      addTearDown(fake.dispose);
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWith((ref) => fake)],
      );
      final completer = Completer<AuthUser>();
      fake.onSignInWithGoogle = () => completer.future;

      final pending = container
          .read(authControllerProvider.notifier)
          .signInWithGoogle();
      container.dispose();

      completer.complete(testUser);
      // Must not throw (no state write on a disposed notifier).
      await pending;
    });
  });

  group('signInWithApple', () {
    test(
      'happy path transitions signing-in then signed-in exactly once',
      () async {
        final (container, fake) = makeContainer();
        fake.onSignInWithApple = () async => testUser;

        final states = <AuthState>[];
        container.listen<AuthState>(
          authControllerProvider,
          (_, next) => states.add(next),
          fireImmediately: true,
        );

        await container.read(authControllerProvider.notifier).signInWithApple();
        await pumpEventQueue();

        expect(states, const [
          AuthSignedOut(),
          AuthSigningIn(),
          AuthSignedIn(testUser),
        ]);
        expect(fake.signInWithAppleCalls, 1);
      },
    );

    test('cancellation returns to signed out, not error', () async {
      final (container, fake) = makeContainer();
      fake.onSignInWithApple = () async {
        throw const AuthCancelledException();
      };

      final states = <AuthState>[];
      container.listen<AuthState>(
        authControllerProvider,
        (_, next) => states.add(next),
        fireImmediately: true,
      );

      await container.read(authControllerProvider.notifier).signInWithApple();

      expect(states, const [AuthSignedOut(), AuthSigningIn(), AuthSignedOut()]);
    });

    test('a domain failure surfaces as AuthError', () async {
      final (container, fake) = makeContainer();
      fake.onSignInWithApple = () async {
        throw const AuthNetworkException(message: 'offline');
      };

      await container.read(authControllerProvider.notifier).signInWithApple();

      expect(
        container.read(authControllerProvider),
        const AuthError(AuthNetworkException(message: 'offline')),
      );
    });

    test(
      'overlapping calls are debounced to a single repository call',
      () async {
        final (container, fake) = makeContainer();
        final completer = Completer<AuthUser>();
        fake.onSignInWithApple = () => completer.future;

        final notifier = container.read(authControllerProvider.notifier);
        unawaited(notifier.signInWithApple());
        unawaited(notifier.signInWithApple());
        await pumpEventQueue();

        expect(fake.signInWithAppleCalls, 1);

        completer.complete(testUser);
        await pumpEventQueue();
        expect(
          container.read(authControllerProvider),
          const AuthSignedIn(testUser),
        );
      },
    );
  });

  group('signOut', () {
    test('moves the state to signed out', () async {
      final (container, fake) = makeContainer(initialUser: testUser);

      await container.read(authControllerProvider.notifier).signOut();

      expect(container.read(authControllerProvider), const AuthSignedOut());
      expect(fake.signOutCalls, 1);
    });

    test('redundant stream null after sign-out does not re-notify', () async {
      final (container, fake) = makeContainer(initialUser: testUser);

      final states = <AuthState>[];
      container.listen<AuthState>(
        authControllerProvider,
        (_, next) => states.add(next),
      );

      await container.read(authControllerProvider.notifier).signOut();
      final notifications = states.length;

      fake.emit(null);
      await pumpEventQueue();
      expect(states.length, notifications);
    });

    test('a sign-out failure surfaces as AuthError', () async {
      final (container, fake) = makeContainer(initialUser: testUser);
      fake.onSignOut = () async {
        throw const AuthUnknownException(code: 'internal-error');
      };

      await container.read(authControllerProvider.notifier).signOut();

      expect(
        container.read(authControllerProvider),
        const AuthError(AuthUnknownException(code: 'internal-error')),
      );
    });
  });
}
