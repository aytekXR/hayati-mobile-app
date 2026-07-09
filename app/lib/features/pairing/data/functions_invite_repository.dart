import 'package:cloud_functions/cloud_functions.dart';

import '../../../core/firebase/firebase_bootstrap.dart';
import '../domain/invite_exception.dart';
import '../domain/invite_repository.dart';
import '../domain/issued_invite.dart';

/// [InviteRepository] backed by the `createInvite` callable (M2.1). Every
/// failure crossing this boundary is mapped into the [InviteException]
/// taxonomy — anything else escaping is a bug (same discipline as
/// `FirestoreProfileRepository`).
class FunctionsInviteRepository implements InviteRepository {
  /// [functions] defaults to the region-scoped instance the emulator wiring in
  /// `firebase_bootstrap.dart` also resolves (instanceFor caches per
  /// app+region), so a `USE_FUNCTIONS_EMULATOR` run reaches the emulator
  /// without any extra plumbing here.
  FunctionsInviteRepository({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: kFunctionsRegion);

  final FirebaseFunctions _functions;

  @override
  Future<IssuedInvite> createInvite() async {
    try {
      final result = await _functions
          .httpsCallable('createInvite')
          .call<Object?>();
      return issuedInviteFromCallable(result.data);
    } catch (failure) {
      throw mapFunctionsFailure(failure);
    }
  }
}

/// Wire mapping for the `createInvite` response (`{code, expiresAtMillis,
/// reused}`). Pure and loud: an unexpected shape throws [FormatException]
/// (mapped to [InviteUnknownException] at the boundary) rather than silently
/// yielding a half-built invite.
IssuedInvite issuedInviteFromCallable(Object? data) {
  if (data is! Map) {
    throw FormatException(
      'createInvite: expected a map, got ${data.runtimeType}',
    );
  }
  final code = data['code'];
  final expiresAtMillis = data['expiresAtMillis'];
  final reused = data['reused'];
  if (code is! String) {
    throw FormatException('createInvite: "code" is ${code.runtimeType}');
  }
  // The platform channel decodes JSON numbers as int, but accept any num so a
  // large millis value delivered as a double never spuriously fails the map.
  if (expiresAtMillis is! num) {
    throw FormatException(
      'createInvite: "expiresAtMillis" is ${expiresAtMillis.runtimeType}',
    );
  }
  if (reused is! bool) {
    throw FormatException('createInvite: "reused" is ${reused.runtimeType}');
  }
  return IssuedInvite(
    code: code,
    expiresAt: DateTime.fromMillisecondsSinceEpoch(expiresAtMillis.toInt()),
    reused: reused,
  );
}

/// Boundary enforcement for the callable error surface: transient availability
/// → network (retry is honest advice), unauthenticated/permission denial →
/// permission (retry is not), everything else — including the server's
/// `resource-exhausted` — keeps its raw code under the generic surface.
InviteException mapFunctionsFailure(Object failure) {
  if (failure is InviteException) return failure;
  if (failure is FirebaseFunctionsException) {
    return switch (failure.code) {
      'unavailable' ||
      'deadline-exceeded' => InviteNetworkException(message: failure.message),
      'unauthenticated' || 'permission-denied' => InvitePermissionException(
        message: failure.message,
      ),
      _ => InviteUnknownException(code: failure.code, message: failure.message),
    };
  }
  return InviteUnknownException(code: 'unexpected', message: '$failure');
}
