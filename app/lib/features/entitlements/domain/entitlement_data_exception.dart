/// Failure taxonomy for the entitlement mirror read (M4.1), mirroring
/// `CoupleDataException`: network → retry is honest advice; permission → the
/// rules said no (a stale session or a client out of contract with
/// `firestore.rules`); unknown keeps the raw code. The data layer's
/// `mapEntitlementDataFailure` is the single choke point that produces these —
/// anything else escaping the repository is a bug.
sealed class EntitlementDataException implements Exception {
  const EntitlementDataException();
}

final class EntitlementDataNetworkException extends EntitlementDataException {
  const EntitlementDataNetworkException({this.message});

  final String? message;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EntitlementDataNetworkException && other.message == message;

  @override
  int get hashCode => Object.hash(runtimeType, message);

  @override
  String toString() => 'EntitlementDataNetworkException(message: $message)';
}

final class EntitlementDataPermissionException
    extends EntitlementDataException {
  const EntitlementDataPermissionException({this.message});

  final String? message;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EntitlementDataPermissionException && other.message == message;

  @override
  int get hashCode => Object.hash(runtimeType, message);

  @override
  String toString() => 'EntitlementDataPermissionException(message: $message)';
}

final class EntitlementDataUnknownException extends EntitlementDataException {
  const EntitlementDataUnknownException({this.code, this.message});

  final String? code;
  final String? message;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EntitlementDataUnknownException &&
          other.code == code &&
          other.message == message;

  @override
  int get hashCode => Object.hash(runtimeType, code, message);

  @override
  String toString() =>
      'EntitlementDataUnknownException(code: $code, message: $message)';
}
