import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/pairing/data/functions_invite_repository.dart';
import 'package:hayati_app/features/pairing/domain/invite_exception.dart';

// The plugin's FirebaseFunctionsException constructor is @protected; a subclass
// may still invoke it via super, which is how we fabricate the real exception
// TYPE the boundary switches on without touching a live callable.
class _FunctionsException extends FirebaseFunctionsException {
  _FunctionsException({required super.code, super.message = 'boom'});
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
}
