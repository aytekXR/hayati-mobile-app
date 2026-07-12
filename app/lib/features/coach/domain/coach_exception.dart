/// Domain taxonomy for the `coachProxy` callable (ADR-017 Decision 5), mapped in
/// ONE data-layer choke point (`mapCoachFailure`, the pairing `mapJoinFailure` /
/// `_reasonOf` mold) by CODE first, `details.reason` refinement second. Every
/// frozen wire outcome (ADR-016 Decision 1) has exactly one member here so the
/// UI can speak to each precisely; the callable boundary translates its errors
/// into exactly these, and anything else escaping is a bug.
///
/// CRITICAL — the app-side no-content rule (ADR-017 Decision 5, ADR-016
/// Decision 8's client twin). Crashlytics collection is ON in prod and the
/// global error hooks forward every uncaught error's `toString()`. So NO member
/// of this family may ever carry conversation content: coach message text, reply
/// text, or window content must never appear in an exception message or any
/// `toString()`. Concretely, every member below is FIELDLESS except
/// [CoachUnknownException], whose [message] carries ONLY server-originated static
/// strings (`FirebaseFunctionsException.message`, static by ADR-016 Decision 8)
/// or null — never a stringified request/reply and never a `'$failure'`
/// interpolation of an arbitrary throwable.
sealed class CoachException implements Exception {
  const CoachException();
}

/// `permission-denied`: the caller is not a member of this couple. Should be
/// unreachable (the screen only mounts with the caller's own coupleId) — surfaced
/// as an honest generic error if it ever fires.
final class CoachNotMemberException extends CoachException {
  const CoachNotMemberException();

  @override
  bool operator ==(Object other) => other is CoachNotMemberException;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'CoachNotMemberException()';
}

/// `failed-precondition` (any reason): the coach is a premium feature and this
/// couple is not entitled. Drives a paywall push (ADR-017 Decision 5 table).
/// Mapped on CODE alone — the server emits no other `failed-precondition` here,
/// and the mapping must survive a dropped `details`.
final class CoachNotPremiumException extends CoachException {
  const CoachNotPremiumException();

  @override
  bool operator ==(Object other) => other is CoachNotPremiumException;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'CoachNotPremiumException()';
}

/// `resource-exhausted` + reason `'cap-daily'`: this user's daily allotment is
/// used — "come back tomorrow" is the honest, actionable copy.
final class CoachDailyCapException extends CoachException {
  const CoachDailyCapException();

  @override
  bool operator ==(Object other) => other is CoachDailyCapException;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'CoachDailyCapException()';
}

/// `resource-exhausted` + reason `'cap-monthly'`: the couple-shared monthly
/// limit is reached.
final class CoachMonthlyCapException extends CoachException {
  const CoachMonthlyCapException();

  @override
  bool operator ==(Object other) => other is CoachMonthlyCapException;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'CoachMonthlyCapException()';
}

/// `resource-exhausted` + reason `'rate-limited'`: too many requests too fast —
/// slow-down copy, immediate retry is honest.
final class CoachRateLimitedException extends CoachException {
  const CoachRateLimitedException();

  @override
  bool operator ==(Object other) => other is CoachRateLimitedException;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'CoachRateLimitedException()';
}

/// `resource-exhausted` with the reason absent or unrecognised: the channel
/// dropped the discriminator, so the client claims neither "tomorrow" nor "this
/// month" — a neutral "a limit was reached" (never over-claim on a dropped
/// detail).
final class CoachLimitReachedException extends CoachException {
  const CoachLimitReachedException();

  @override
  bool operator ==(Object other) => other is CoachLimitReachedException;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'CoachLimitReachedException()';
}

/// `unavailable` / `deadline-exceeded`: provider outage and transport outage are
/// indistinguishable client-side and share the honest unavailable + retry UX.
final class CoachUnavailableException extends CoachException {
  const CoachUnavailableException();

  @override
  bool operator ==(Object other) => other is CoachUnavailableException;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'CoachUnavailableException()';
}

/// Anything else: `invalid-argument`, `internal`, `unauthenticated`, a
/// non-Functions throw, or a malformed response body. [code] carries the raw
/// callable code (or `'unexpected'` / `'malformed-response'`) for diagnostics;
/// [message] carries ONLY a server-originated static string or null — never a
/// stringified failure and never conversation content (the no-content rule).
final class CoachUnknownException extends CoachException {
  const CoachUnknownException({this.code, this.message});

  final String? code;
  final String? message;

  @override
  bool operator ==(Object other) =>
      other is CoachUnknownException &&
      other.code == code &&
      other.message == message;

  @override
  int get hashCode => Object.hash(code, message);

  @override
  String toString() => 'CoachUnknownException(code: $code, message: $message)';
}
