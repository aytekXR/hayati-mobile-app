/// Failure taxonomy for the couple daily-loop reads/writes (M3.3),
/// mirroring `SoloAnswerException`: network → retry is honest advice;
/// permission → the rules said no (for the partner answer specifically,
/// permission means "still locked", by design); unknown keeps the raw code.
/// The data layer's `mapCoupleDataFailure` is the single choke point that
/// produces these — anything else escaping a couple repository is a bug.
sealed class CoupleDataException implements Exception {
  const CoupleDataException();
}

final class CoupleDataNetworkException extends CoupleDataException {
  const CoupleDataNetworkException({this.message});

  final String? message;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CoupleDataNetworkException && other.message == message;

  @override
  int get hashCode => Object.hash(runtimeType, message);

  @override
  String toString() => 'CoupleDataNetworkException(message: $message)';
}

final class CoupleDataPermissionException extends CoupleDataException {
  const CoupleDataPermissionException({this.message});

  final String? message;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CoupleDataPermissionException && other.message == message;

  @override
  int get hashCode => Object.hash(runtimeType, message);

  @override
  String toString() => 'CoupleDataPermissionException(message: $message)';
}

final class CoupleDataUnknownException extends CoupleDataException {
  const CoupleDataUnknownException({this.code, this.message});

  final String? code;
  final String? message;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CoupleDataUnknownException &&
          other.code == code &&
          other.message == message;

  @override
  int get hashCode => Object.hash(runtimeType, code, message);

  @override
  String toString() =>
      'CoupleDataUnknownException(code: $code, message: $message)';
}
