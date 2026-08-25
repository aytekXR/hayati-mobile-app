import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/core/storage/local_flag_store.dart';
import 'package:hayati_app/features/auth/domain/auth_exception.dart';
import 'package:hayati_app/features/auth/domain/auth_repository_provider.dart';
import 'package:hayati_app/features/auth/domain/auth_state.dart';
import 'package:hayati_app/features/auth/domain/auth_user.dart';
import 'package:hayati_app/features/auth/presentation/state/auth_controller.dart';
import 'package:hayati_app/features/data_rights/domain/data_rights_exception.dart';
import 'package:hayati_app/features/data_rights/domain/data_rights_repository_provider.dart';

import '../../../../support/fake_auth_repository.dart';
import '../../../../support/fake_data_rights_repository.dart';
import '../../../../support/fake_local_flag_store.dart';

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

  /// The delete container. [flags] is deliberately OPTIONAL and omitted by the
  /// ADR-019 phase-model tests below: `localFlagStoreProvider` throws when
  /// unoverridden, so leaving it out is not laziness — it is the ADR-061 D3
  /// assertion that a deletion still completes when the flag store cannot be
  /// resolved at all.
  (ProviderContainer, FakeAuthRepository, FakeDataRightsRepository)
  makeDeleteContainer({LocalFlagStore? flags}) {
    final auth = FakeAuthRepository(initialUser: testUser);
    final dataRights = FakeDataRightsRepository();
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWith((ref) => auth),
        dataRightsRepositoryProvider.overrideWith((ref) => dataRights),
        if (flags != null) localFlagStoreProvider.overrideWithValue(flags),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(auth.dispose);
    return (container, auth, dataRights);
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

  // The AuthSigningIn spinner used to have no way out (ADR-039). The sign-in
  // future crosses a native authorization sheet and a Firebase credential
  // exchange, neither of which is guaranteed to call back — and while it was in
  // flight the manual-op gate also suppressed the repository stream, so nothing
  // else could rescue the state either. These run under `testWidgets` for its
  // fake clock: a two-minute bound is not something a plain `test` can advance.
  group('the signing-in state is bounded (ADR-039)', () {
    for (final provider in ['apple', 'google']) {
      testWidgets('$provider: a sign-in that never returns lands on an error', (
        tester,
      ) async {
        final (container, fake) = makeContainer();
        // Never settles — the exact shape of the failure being guarded.
        final never = Completer<AuthUser>();
        fake.onSignInWithApple = () => never.future;
        fake.onSignInWithGoogle = () => never.future;

        final notifier = container.read(authControllerProvider.notifier);
        unawaited(
          provider == 'apple'
              ? notifier.signInWithApple()
              : notifier.signInWithGoogle(),
        );
        await tester.pump();
        expect(container.read(authControllerProvider), const AuthSigningIn());

        // One tick short of the deadline it is still signing in: a real user
        // typing an Apple ID password must not be cancelled out from under.
        await tester.pump(
          kInteractiveSignInTimeout - const Duration(seconds: 1),
        );
        expect(container.read(authControllerProvider), const AuthSigningIn());

        await tester.pump(const Duration(seconds: 1));
        expect(
          container.read(authControllerProvider),
          isA<AuthError>(),
          reason: 'the spinner must not be the terminal state',
        );
      });
    }

    testWidgets('the timeout surfaces as NETWORK, so the copy is actionable', (
      tester,
    ) async {
      final (container, fake) = makeContainer();
      fake.onSignInWithApple = () => Completer<AuthUser>().future;

      unawaited(
        container.read(authControllerProvider.notifier).signInWithApple(),
      );
      await tester.pump(kInteractiveSignInTimeout);

      final state = container.read(authControllerProvider);
      expect(state, isA<AuthError>());
      // Network copy ("Check your connection and try again") rather than the
      // generic "Something went wrong" — see the constant's doc comment.
      expect((state as AuthError).failure, isA<AuthNetworkException>());
    });

    testWidgets('a LATE success is not lost — the gate is released', (
      tester,
    ) async {
      // The load-bearing half of the design. The timeout does not cancel the
      // underlying sign-in; it releases the manual-op gate that was suppressing
      // the repository stream. So if the session does land after the deadline,
      // the stream — now unsuppressed — puts the user straight into the app
      // from under the error view, with no second tap.
      final (container, fake) = makeContainer();
      fake.onSignInWithApple = () => Completer<AuthUser>().future;

      unawaited(
        container.read(authControllerProvider.notifier).signInWithApple(),
      );
      await tester.pump(kInteractiveSignInTimeout);
      expect(container.read(authControllerProvider), isA<AuthError>());

      // Firebase finally reports the restored session on authStateChanges.
      fake.emit(testUser);
      await tester.pump();

      expect(
        container.read(authControllerProvider),
        const AuthSignedIn(testUser),
      );
    });

    testWidgets('a normal sign-in is untouched by the bound', (tester) async {
      final (container, fake) = makeContainer();
      fake.onSignInWithApple = () async => testUser;

      await container.read(authControllerProvider.notifier).signInWithApple();
      await tester.pump(kInteractiveSignInTimeout * 2);

      expect(
        container.read(authControllerProvider),
        const AuthSignedIn(testUser),
      );
    });
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

  group('deleteAccount (ADR-019 D7 phase model)', () {
    test('phase-1 cascade failure leaves the state AuthSignedIn, rethrows the '
        'typed exception, and never attempts teardown', () async {
      final (container, auth, dataRights) = makeDeleteContainer();
      dataRights.onDeleteAccount = () async =>
          throw const DataRightsNetworkException();

      // The typed exception propagates to the screen (it is NOT an
      // AuthException, so the controller's `on AuthException` catch cannot eat
      // it) — and nothing transitions, so nothing pops.
      await expectLater(
        container.read(authControllerProvider.notifier).deleteAccount(),
        throwsA(isA<DataRightsNetworkException>()),
      );

      expect(
        container.read(authControllerProvider),
        const AuthSignedIn(testUser),
      );
      expect(dataRights.deleteAccountCalls, 1);
      expect(auth.signOutAfterAccountDeletionCalls, 0);
    });

    test(
      'success tears down the session and lands an explicit AuthSignedOut',
      () async {
        final (container, auth, dataRights) = makeDeleteContainer();

        final states = <AuthState>[];
        container.listen<AuthState>(
          authControllerProvider,
          (_, next) => states.add(next),
        );

        await container.read(authControllerProvider.notifier).deleteAccount();

        expect(dataRights.deleteAccountCalls, 1);
        expect(auth.signOutAfterAccountDeletionCalls, 1);
        expect(container.read(authControllerProvider), const AuthSignedOut());
        // A value-inequal AuthSignedIn → AuthSignedOut transition fired (the root
        // listener's wipe rides exactly this notification).
        expect(states, contains(const AuthSignedOut()));
      },
    );

    test(
      'the account-scoped local flags go with the account (ADR-061 D1)',
      () async {
        const otherUid = 'uid-12';
        // testUser.uid is 'uid-1', a strict string PREFIX of 'uid-12'. That is
        // the point of the pair: a substring sweep would take the other
        // account's flags off this shared device.
        final mine = [
          for (final flag in AccountFlag.values)
            LocalFlagKey.account(flag, uid: testUser.uid),
        ];
        final theirs = [
          for (final flag in AccountFlag.values)
            LocalFlagKey.account(flag, uid: otherUid),
        ];
        final deviceKeys = [
          for (final f in DeviceFlag.values) LocalFlagKey.device(f),
        ];
        final flags = FakeLocalFlagStore(
          initial: {
            for (final k in [...mine, ...theirs, ...deviceKeys]) k.value,
          },
        );
        final (container, _, _) = makeDeleteContainer(flags: flags);

        await container.read(authControllerProvider.notifier).deleteAccount();

        for (final key in mine) {
          expect(
            flags.isSet(key),
            isFalse,
            reason: '$key survived "delete account and data"',
          );
        }
        for (final key in theirs) {
          expect(
            flags.isSet(key),
            isTrue,
            reason: '$key belongs to another account on this device',
          );
        }
        for (final key in deviceKeys) {
          expect(
            flags.isSet(key),
            isTrue,
            reason: '$key is device state and must outlive the account',
          );
        }
      },
    );

    test(
      'a phase-1 failure clears NOTHING — the account still exists',
      () async {
        final key = LocalFlagKey.account(
          AccountFlag.coachDisclaimerAck,
          uid: testUser.uid,
        );
        final flags = FakeLocalFlagStore(initial: {key.value});
        final (container, _, dataRights) = makeDeleteContainer(flags: flags);
        dataRights.onDeleteAccount = () async =>
            throw const DataRightsNetworkException();

        await expectLater(
          container.read(authControllerProvider.notifier).deleteAccount(),
          throwsA(isA<DataRightsNetworkException>()),
        );

        // The worst outcome available: local data gone, account not deleted.
        expect(flags.isSet(key), isTrue);
      },
    );

    test('a phase-2 sign-out throw still leaves the flags cleared', () async {
      final key = LocalFlagKey.account(
        AccountFlag.privacySpotlightSeen,
        uid: testUser.uid,
      );
      final flags = FakeLocalFlagStore(initial: {key.value});
      final (container, auth, _) = makeDeleteContainer(flags: flags);
      auth.onSignOutAfterAccountDeletion = () async =>
          throw const AuthUnknownException(code: 'internal-error');

      await container.read(authControllerProvider.notifier).deleteAccount();

      // The server cascade completed, so the account is gone either way; only
      // the local teardown threw (ADR-061 D1).
      expect(flags.isSet(key), isFalse);
      expect(
        container.read(authControllerProvider),
        const AuthError(AuthUnknownException(code: 'internal-error')),
      );
    });

    test(
      'a throwing flag store does NOT fail the deletion (ADR-061 D3)',
      () async {
        final (container, auth, dataRights) = makeDeleteContainer(
          flags: _ThrowingLocalFlagStore(),
        );

        await container.read(authControllerProvider.notifier).deleteAccount();

        // The account is deleted and the session torn down; only the local
        // cleanup failed, and the user is never told a completed deletion failed.
        expect(dataRights.deleteAccountCalls, 1);
        expect(auth.signOutAfterAccountDeletionCalls, 1);
        expect(container.read(authControllerProvider), const AuthSignedOut());
      },
    );

    test('an ORDINARY sign-out clears nothing (ADR-061 finding 4)', () async {
      // The regression this design exists to avoid: both a deletion and a
      // sign-out end in AuthSignedOut, so a teardown-side sweep would re-show
      // the coach disclaimer to a user who merely signed out and back in.
      final mine = [
        for (final flag in AccountFlag.values)
          LocalFlagKey.account(flag, uid: testUser.uid),
      ];
      final flags = FakeLocalFlagStore(
        initial: {for (final k in mine) k.value},
      );
      final (container, _, _) = makeDeleteContainer(flags: flags);

      await container.read(authControllerProvider.notifier).signOut();

      expect(container.read(authControllerProvider), const AuthSignedOut());
      for (final key in mine) {
        expect(
          flags.isSet(key),
          isTrue,
          reason: '$key was cleared by a SIGN-OUT, not a deletion',
        );
      }
    });

    test(
      'a phase-2 sign-out throw surfaces as AuthError — protection stays, the '
      'completed deletion self-heals later',
      () async {
        final (container, auth, dataRights) = makeDeleteContainer();
        auth.onSignOutAfterAccountDeletion = () async =>
            throw const AuthUnknownException(code: 'internal-error');

        await container.read(authControllerProvider.notifier).deleteAccount();

        // The server cascade DID run (deletion is complete); only the local
        // teardown threw, so the state is AuthError and the lock (elsewhere)
        // stays — never wiped on an AuthError.
        expect(dataRights.deleteAccountCalls, 1);
        expect(
          container.read(authControllerProvider),
          const AuthError(AuthUnknownException(code: 'internal-error')),
        );
      },
    );
  });
}

/// A [LocalFlagStore] whose sweep fails the way a platform channel can.
class _ThrowingLocalFlagStore implements LocalFlagStore {
  @override
  bool isSet(LocalFlagKey key) => false;

  @override
  Future<void> set(LocalFlagKey key) async {}

  @override
  Future<void> removeAccountScoped(String uid) async =>
      throw StateError('prefs unavailable');
}
