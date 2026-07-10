import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/couple_data_exception.dart';

/// Boundary enforcement for the Firestore error surface of the three couple
/// repositories (couple / day / answers), mirroring `mapSoloAnswerFailure`:
/// transient availability → network, rules/auth denial → permission (for
/// the partner answer this is the EXPECTED pre-reveal signal, mapped to the
/// locked state upstream), everything else keeps its raw code.
CoupleDataException mapCoupleDataFailure(Object failure) {
  if (failure is CoupleDataException) return failure;
  if (failure is FirebaseException) {
    return switch (failure.code) {
      'unavailable' || 'deadline-exceeded' => CoupleDataNetworkException(
        message: failure.message,
      ),
      'permission-denied' || 'unauthenticated' => CoupleDataPermissionException(
        message: failure.message,
      ),
      _ => CoupleDataUnknownException(
        code: failure.code,
        message: failure.message,
      ),
    };
  }
  return CoupleDataUnknownException(code: 'unexpected', message: '$failure');
}
