import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/auth/domain/auth_exception.dart';
import 'package:hayati_app/features/auth/domain/auth_repository_provider.dart';
import 'package:hayati_app/features/auth/domain/auth_state.dart';
import 'package:hayati_app/features/auth/domain/auth_user.dart';
import 'package:hayati_app/features/auth/domain/phone_sign_in_session.dart';
import 'package:hayati_app/features/auth/domain/phone_sign_in_state.dart';
import 'package:hayati_app/features/auth/presentation/state/auth_controller.dart';
import 'package:hayati_app/features/auth/presentation/state/phone_sign_in_controller.dart';

import '../../../../support/fake_auth_repository.dart';

const testUser = AuthUser(uid: 'uid-1', displayName: 'Aytek');
const session = PhoneSignInSession('vid-1', resendToken: 5);

void main() {
  (ProviderContainer, FakeAuthRepository) makeContainer() {
    final fake = FakeAuthRepository();
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWith((ref) => fake)],
    );
    addTearDown(container.dispose);
    addTearDown(fake.dispose);
    return (container, fake);
  }

  // Subscribes to the controller so the autoDispose provider stays alive
  // across awaits, and records every state it passes through.
  List<PhoneSignInState> record(ProviderContainer container) {
    final states = <PhoneSignInState>[];
    container.listen<PhoneSignInState>(
      phoneSignInControllerProvider,
      (_, next) => states.add(next),
      fireImmediately: true,
    );
    return states;
  }

  test('starts in PhoneEntry', () {
    final (container, _) = makeContainer();
    expect(container.read(phoneSignInControllerProvider), const PhoneEntry());
  });

  group('sendCode', () {
    test('transitions entry -> sending -> code-sent', () async {
      final (container, fake) = makeContainer();
      fake.onSendPhoneCode = (_, {resendFrom}) async => session;
      final states = record(container);

      await container
          .read(phoneSignInControllerProvider.notifier)
          .sendCode('+905551112233');

      expect(states, const [
        PhoneEntry(),
        PhoneSending(),
        PhoneCodeSent(session),
      ]);
      expect(fake.sendPhoneCodeCalls, 1);
    });

    test(
      'a failure surfaces as PhoneSignInFailure without a session',
      () async {
        final (container, fake) = makeContainer();
        fake.onSendPhoneCode = (_, {resendFrom}) async {
          throw const AuthUnknownException(code: 'invalid-phone-number');
        };
        final states = record(container);

        await container
            .read(phoneSignInControllerProvider.notifier)
            .sendCode('+900');

        expect(states, const [
          PhoneEntry(),
          PhoneSending(),
          PhoneSignInFailure(
            AuthUnknownException(code: 'invalid-phone-number'),
          ),
        ]);
      },
    );

    test(
      'overlapping calls are debounced to a single repository call',
      () async {
        final (container, fake) = makeContainer();
        final completer = Completer<PhoneSignInSession>();
        fake.onSendPhoneCode = (_, {resendFrom}) => completer.future;
        record(container);

        final notifier = container.read(phoneSignInControllerProvider.notifier);
        unawaited(notifier.sendCode('+905551112233'));
        unawaited(notifier.sendCode('+905551112233'));
        await pumpEventQueue();

        expect(fake.sendPhoneCodeCalls, 1);
        completer.complete(session);
        await pumpEventQueue();
        expect(
          container.read(phoneSignInControllerProvider),
          const PhoneCodeSent(session),
        );
      },
    );
  });

  group('resend', () {
    test('re-requests the code, threading the prior session token', () async {
      final (container, fake) = makeContainer();
      const resent = PhoneSignInSession('vid-2');
      PhoneSignInSession? seenResendFrom;
      var call = 0;
      fake.onSendPhoneCode = (_, {resendFrom}) async {
        call++;
        if (call == 1) return session;
        seenResendFrom = resendFrom;
        return resent;
      };
      final states = record(container);
      final notifier = container.read(phoneSignInControllerProvider.notifier);

      await notifier.sendCode('+905551112233');
      await notifier.resend();

      expect(seenResendFrom, session);
      expect(states, const [
        PhoneEntry(),
        PhoneSending(),
        PhoneCodeSent(session),
        PhoneCodeSent(session, resending: true),
        PhoneCodeSent(resent),
      ]);
    });

    test('is a no-op when no code has been sent yet', () async {
      final (container, fake) = makeContainer();
      record(container);

      await container.read(phoneSignInControllerProvider.notifier).resend();

      expect(container.read(phoneSignInControllerProvider), const PhoneEntry());
      expect(fake.sendPhoneCodeCalls, 0);
    });

    test('a failed resend keeps the prior session so the already-received '
        'code can still be entered', () async {
      final (container, fake) = makeContainer();
      const failure = AuthUnknownException(code: 'too-many-requests');
      var call = 0;
      fake.onSendPhoneCode = (_, {resendFrom}) async {
        call++;
        if (call == 1) return session;
        throw failure;
      };
      final notifier = container.read(phoneSignInControllerProvider.notifier);

      await notifier.sendCode('+905551112233');
      await notifier.resend();

      // The resend failed, so it never replaced the prior verificationId:
      // retaining it keeps the user on code entry instead of restarting.
      expect(
        container.read(phoneSignInControllerProvider),
        const PhoneSignInFailure(failure, session: session),
      );
    });

    test('a failed first send retains no session and restarts from '
        'phone entry', () async {
      final (container, fake) = makeContainer();
      const failure = AuthNetworkException();
      fake.onSendPhoneCode = (_, {resendFrom}) async => throw failure;

      await container
          .read(phoneSignInControllerProvider.notifier)
          .sendCode('+905551112233');

      expect(
        container.read(phoneSignInControllerProvider),
        const PhoneSignInFailure(failure),
      );
    });
  });

  group('confirm', () {
    Future<void> reachCodeSent(
      ProviderContainer container,
      FakeAuthRepository fake,
    ) async {
      fake.onSendPhoneCode = (_, {resendFrom}) async => session;
      await container
          .read(phoneSignInControllerProvider.notifier)
          .sendCode('+905551112233');
    }

    test('confirms and leaves the global AuthState untouched', () async {
      final (container, fake) = makeContainer();
      // Global controller is idle and signed-out; the phone flow must not
      // touch it — the terminal AuthSignedIn arrives via authStateChanges.
      expect(container.read(authControllerProvider), const AuthSignedOut());
      await reachCodeSent(container, fake);

      String? seenCode;
      PhoneSignInSession? seenSession;
      fake.onConfirmPhoneCode = (s, code) async {
        seenSession = s;
        seenCode = code;
        return testUser;
      };
      final states = record(container);

      await container
          .read(phoneSignInControllerProvider.notifier)
          .confirm('123456');

      expect(seenSession, session);
      expect(seenCode, '123456');
      expect(fake.confirmPhoneCodeCalls, 1);
      // Enters PhoneConfirming and stays there; success is signalled globally.
      expect(states, const [PhoneCodeSent(session), PhoneConfirming(session)]);
      expect(container.read(authControllerProvider), const AuthSignedOut());
    });

    test('a wrong code retains the session for inline retry', () async {
      final (container, fake) = makeContainer();
      await reachCodeSent(container, fake);
      fake.onConfirmPhoneCode = (_, _) async {
        throw const AuthInvalidCodeException();
      };
      final states = record(container);

      await container
          .read(phoneSignInControllerProvider.notifier)
          .confirm('000000');

      expect(states, const [
        PhoneCodeSent(session),
        PhoneConfirming(session),
        PhoneSignInFailure(AuthInvalidCodeException(), session: session),
      ]);
    });

    test('an expired session drops the session to restart the flow', () async {
      final (container, fake) = makeContainer();
      await reachCodeSent(container, fake);
      fake.onConfirmPhoneCode = (_, _) async {
        throw const AuthSessionExpiredException();
      };
      final states = record(container);

      await container
          .read(phoneSignInControllerProvider.notifier)
          .confirm('123456');

      expect(states, const [
        PhoneCodeSent(session),
        PhoneConfirming(session),
        PhoneSignInFailure(AuthSessionExpiredException()),
      ]);
    });

    test('a generic failure keeps the session for retry', () async {
      final (container, fake) = makeContainer();
      await reachCodeSent(container, fake);
      fake.onConfirmPhoneCode = (_, _) async {
        throw const AuthNetworkException(message: 'off');
      };
      final states = record(container);

      await container
          .read(phoneSignInControllerProvider.notifier)
          .confirm('123456');

      expect(states, const [
        PhoneCodeSent(session),
        PhoneConfirming(session),
        PhoneSignInFailure(
          AuthNetworkException(message: 'off'),
          session: session,
        ),
      ]);
    });

    test('recovers after a wrong code using the retained session', () async {
      final (container, fake) = makeContainer();
      await reachCodeSent(container, fake);
      var attempt = 0;
      fake.onConfirmPhoneCode = (_, _) async {
        attempt++;
        if (attempt == 1) throw const AuthInvalidCodeException();
        return testUser;
      };
      final notifier = container.read(phoneSignInControllerProvider.notifier);

      await notifier.confirm('000000');
      expect(
        container.read(phoneSignInControllerProvider),
        const PhoneSignInFailure(AuthInvalidCodeException(), session: session),
      );

      await notifier.confirm('123456');
      expect(fake.confirmPhoneCodeCalls, 2);
      expect(
        container.read(phoneSignInControllerProvider),
        const PhoneConfirming(session),
      );
    });

    test('is a no-op when there is no session to confirm against', () async {
      final (container, fake) = makeContainer();
      record(container);

      await container
          .read(phoneSignInControllerProvider.notifier)
          .confirm('123456');

      expect(container.read(phoneSignInControllerProvider), const PhoneEntry());
      expect(fake.confirmPhoneCodeCalls, 0);
    });
  });
}
