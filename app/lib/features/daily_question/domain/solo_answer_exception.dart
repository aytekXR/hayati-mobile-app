/// Failure taxonomy for solo-answer persistence (M2.4), mirroring
/// `ProfileException`: network → retry is honest advice; permission → the
/// rules said no (retry is not); unknown keeps the raw code for diagnostics.
/// The data layer's `mapSoloAnswerFailure` is the single choke point that
/// produces these — anything else escaping the repository is a bug.
sealed class SoloAnswerException implements Exception {
  const SoloAnswerException();
}

final class SoloAnswerNetworkException extends SoloAnswerException {
  const SoloAnswerNetworkException({this.message});

  final String? message;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SoloAnswerNetworkException && other.message == message;

  @override
  int get hashCode => Object.hash(runtimeType, message);

  @override
  String toString() => 'SoloAnswerNetworkException(message: $message)';
}

final class SoloAnswerPermissionException extends SoloAnswerException {
  const SoloAnswerPermissionException({this.message});

  final String? message;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SoloAnswerPermissionException && other.message == message;

  @override
  int get hashCode => Object.hash(runtimeType, message);

  @override
  String toString() => 'SoloAnswerPermissionException(message: $message)';
}

final class SoloAnswerUnknownException extends SoloAnswerException {
  const SoloAnswerUnknownException({this.code, this.message});

  final String? code;
  final String? message;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SoloAnswerUnknownException &&
          other.code == code &&
          other.message == message;

  @override
  int get hashCode => Object.hash(runtimeType, code, message);

  @override
  String toString() =>
      'SoloAnswerUnknownException(code: $code, message: $message)';
}
