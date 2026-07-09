import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/pairing/data/functions_invite_repository.dart';
import 'package:hayati_app/features/pairing/domain/invite_exception.dart';

// The plugin's FirebaseFunctionsException constructor is @protected; a subclass
// may still invoke it via super, which is how we fabricate the real exception
// TYPE the boundary switches on without touching a live callable. [details]
// carries the join contract's `{reason: …}` discriminator.
class _FunctionsException extends FirebaseFunctionsException {
  _FunctionsException({
    required super.code,
    super.message = 'boom',
    super.details,
  });
}

void main() {
  group('issuedInviteFromCallable', () {
    test('maps the callable payload into the domain model', () {
      final invite = issuedInviteFromCallable({
        'code': 'ABCD2345',
        'expiresAtMillis': 1799999999000,
        'reused': true,
      });

      expect(invite.code, 'ABCD2345');
      expect(
        invite.expiresAt,
        DateTime.fromMillisecondsSinceEpoch(1799999999000),
      );
      expect(invite.reused, isTrue);
    });

    test('accepts millis delivered as any num (double from the channel)', () {
      final invite = issuedInviteFromCallable({
        'code': 'ABCD2345',
        'expiresAtMillis': 1799999999000.0,
        'reused': false,
      });

      expect(
        invite.expiresAt,
        DateTime.fromMillisecondsSinceEpoch(1799999999000),
      );
    });

    test('rejects a non-map payload loudly', () {
      expect(() => issuedInviteFromCallable('nope'), throwsFormatException);
      expect(() => issuedInviteFromCallable(null), throwsFormatException);
    });

    test('rejects a missing or wrongly-typed field loudly', () {
      expect(
        () => issuedInviteFromCallable({'expiresAtMillis': 1, 'reused': true}),
        throwsFormatException,
      );
      expect(
        () => issuedInviteFromCallable({
          'code': 'ABCD2345',
          'expiresAtMillis': 'soon',
          'reused': true,
        }),
        throwsFormatException,
      );
      expect(
        () => issuedInviteFromCallable({
          'code': 'ABCD2345',
          'expiresAtMillis': 1,
          'reused': 'yes',
        }),
        throwsFormatException,
      );
    });
  });

  group('mapFunctionsFailure', () {
    InviteException map(String code) =>
        mapFunctionsFailure(_FunctionsException(code: code));

    test('transient availability codes become network failures', () {
      expect(map('unavailable'), isA<InviteNetworkException>());
      expect(map('deadline-exceeded'), isA<InviteNetworkException>());
    });

    test('auth denials become permission failures', () {
      expect(map('unauthenticated'), isA<InvitePermissionException>());
      expect(map('permission-denied'), isA<InvitePermissionException>());
    });

    test('resource-exhausted maps to unknown, keeping its code', () {
      final failure = map('resource-exhausted');
      expect(failure, isA<InviteUnknownException>());
      expect((failure as InviteUnknownException).code, 'resource-exhausted');
    });

    test('anything else keeps its raw code for diagnostics', () {
      final failure = map('internal');
      expect(failure, isA<InviteUnknownException>());
      expect((failure as InviteUnknownException).code, 'internal');
    });

    test('a already-mapped InviteException passes through unchanged', () {
      const original = InviteNetworkException(message: 'off');
      expect(mapFunctionsFailure(original), same(original));
    });

    test('non-Firebase throwables are wrapped, never rethrown raw', () {
      expect(
        mapFunctionsFailure(StateError('boom')),
        isA<InviteUnknownException>(),
      );
      expect(
        mapFunctionsFailure(const FormatException('bad payload')),
        isA<InviteUnknownException>(),
      );
    });
  });

  group('coupleIdFromCallable', () {
    test('extracts the coupleId from the callable payload', () {
      expect(coupleIdFromCallable({'coupleId': 'couple-9'}), 'couple-9');
    });

    test('rejects a non-map payload loudly', () {
      expect(() => coupleIdFromCallable('nope'), throwsFormatException);
      expect(() => coupleIdFromCallable(null), throwsFormatException);
    });

    test('rejects a missing or wrongly-typed coupleId loudly', () {
      expect(
        () => coupleIdFromCallable(<String, Object?>{}),
        throwsFormatException,
      );
      expect(
        () => coupleIdFromCallable({'coupleId': 42}),
        throwsFormatException,
      );
    });
  });

  group('mapJoinFailure', () {
    InviteException mapReason(String code, String? reason) => mapJoinFailure(
      _FunctionsException(
        code: code,
        details: reason == null ? null : {'reason': reason},
      ),
    );

    test('not-found becomes the unknown-code join failure', () {
      expect(
        mapReason('not-found', 'unknown'),
        isA<InviteJoinUnknownCodeException>(),
      );
      // Robust to a missing reason — the code alone classifies it.
      expect(
        mapReason('not-found', null),
        isA<InviteJoinUnknownCodeException>(),
      );
    });

    test('each failed-precondition reason maps to its own member', () {
      expect(
        mapReason('failed-precondition', 'expired'),
        isA<InviteJoinExpiredException>(),
      );
      expect(
        mapReason('failed-precondition', 'consumed'),
        isA<InviteJoinConsumedException>(),
      );
      expect(
        mapReason('failed-precondition', 'self-join'),
        isA<InviteJoinSelfJoinException>(),
      );
      expect(
        mapReason('failed-precondition', 'already-paired'),
        isA<InviteJoinAlreadyPairedException>(),
      );
      expect(
        mapReason('failed-precondition', 'profile-missing'),
        isA<InviteJoinProfileMissingException>(),
      );
    });

    test(
      'failed-precondition with a missing/unknown reason keeps its raw code',
      () {
        final missing = mapReason('failed-precondition', null);
        expect(missing, isA<InviteUnknownException>());
        expect((missing as InviteUnknownException).code, 'failed-precondition');

        final unknown = mapReason('failed-precondition', 'brand-new-reason');
        expect(unknown, isA<InviteUnknownException>());
        expect((unknown as InviteUnknownException).code, 'failed-precondition');
      },
    );

    test('a non-map or non-string details never throws — falls through', () {
      expect(
        mapJoinFailure(
          _FunctionsException(code: 'failed-precondition', details: 'oops'),
        ),
        isA<InviteUnknownException>(),
      );
      expect(
        mapJoinFailure(
          _FunctionsException(
            code: 'failed-precondition',
            details: {'reason': 123},
          ),
        ),
        isA<InviteUnknownException>(),
      );
    });

    test('transport codes classify exactly like createInvite', () {
      expect(mapReason('unavailable', null), isA<InviteNetworkException>());
      expect(
        mapReason('deadline-exceeded', null),
        isA<InviteNetworkException>(),
      );
      expect(
        mapReason('unauthenticated', null),
        isA<InvitePermissionException>(),
      );
      expect(
        mapReason('permission-denied', null),
        isA<InvitePermissionException>(),
      );
    });

    test('internal keeps its raw code under the generic surface', () {
      final failure = mapReason('internal', null);
      expect(failure, isA<InviteUnknownException>());
      expect((failure as InviteUnknownException).code, 'internal');
    });

    test('an already-mapped InviteException passes through unchanged', () {
      const original = InviteJoinConsumedException(message: 'used');
      expect(mapJoinFailure(original), same(original));
    });

    test('a parse FormatException is wrapped, never rethrown raw', () {
      expect(
        mapJoinFailure(const FormatException('bad payload')),
        isA<InviteUnknownException>(),
      );
    });
  });
}
