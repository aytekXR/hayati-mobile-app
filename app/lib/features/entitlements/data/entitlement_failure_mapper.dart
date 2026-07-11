import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/entitlement_data_exception.dart';

/// Boundary enforcement for the Firestore error surface of
/// [FirestoreEntitlementRepository], mirroring `mapCoupleDataFailure`:
/// transient availability → network, rules/auth denial → permission,
/// everything else keeps its raw code. The single choke point for the
/// entitlement read — an already-taxonomised failure passes through unchanged.
EntitlementDataException mapEntitlementDataFailure(Object failure) {
  if (failure is EntitlementDataException) return failure;
  if (failure is FirebaseException) {
    return switch (failure.code) {
      'unavailable' || 'deadline-exceeded' => EntitlementDataNetworkException(
        message: failure.message,
      ),
      'permission-denied' || 'unauthenticated' =>
        EntitlementDataPermissionException(message: failure.message),
      _ => EntitlementDataUnknownException(
        code: failure.code,
        message: failure.message,
      ),
    };
  }
  return EntitlementDataUnknownException(
    code: 'unexpected',
    message: '$failure',
  );
}
