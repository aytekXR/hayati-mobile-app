/// Domain taxonomy for the M6.2 data-rights callables (`deleteAccount`,
/// `exportData`, `updateNotificationPrivacy` — ADR-019 Decisions 2/5/6), mapped
/// in ONE data-layer choke point (`mapDataRightsFailure`, the coach
/// `mapCoachFailure` / `_reasonOf` mold) by CODE first, `details.reason`
/// refinement second. Every failure crossing the boundary lands here; anything
/// else escaping is a bug.
///
/// CRITICAL — the no-content rule (ADR-019 D2 / ADR-016 D8 / ADR-017 D5's client
/// twin). Deletion and export are special-category-adjacent: the delete request
/// carries a uid+coupleId and the export body is the user's own personal data.
/// Crashlytics collection is ON in prod and the global error hooks forward every
/// uncaught error's `toString()`, so NO member of this family may carry payload
/// text. Every member below is FIELDLESS except [DataRightsUnknownException],
/// whose [message] holds ONLY a server-originated static string (the callable's
/// static message, ADR-019 D2) or null — never a stringified throwable and never
/// export content.
sealed class DataRightsException implements Exception {
  const DataRightsException();
}

/// `unavailable` / `deadline-exceeded`: provider outage and transport outage are
/// indistinguishable client-side and share the honest unavailable + retry UX.
final class DataRightsNetworkException extends DataRightsException {
  const DataRightsNetworkException();

  @override
  bool operator ==(Object other) => other is DataRightsNetworkException;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'DataRightsNetworkException()';
}

/// `failed-precondition` + reason `'profile-missing'`: the callable ran without a
/// `users/{uid}` doc (the Decision 2 callable-surface guard). On export it means
/// there is nothing to export; it is not expected on delete (the caller is a
/// signed-in user standing in settings) but is mapped for completeness.
final class DataRightsProfileMissingException extends DataRightsException {
  const DataRightsProfileMissingException();

  @override
  bool operator ==(Object other) => other is DataRightsProfileMissingException;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'DataRightsProfileMissingException()';
}

/// Anything else: `internal`, `invalid-argument`, `unauthenticated`, a
/// non-Functions throw, or a malformed response body. [code] carries the raw
/// callable code (or `'unexpected'` / `'malformed-response'`) for diagnostics;
/// [message] carries ONLY a server-originated static string or null — never a
/// stringified failure and never export content (the no-content rule).
final class DataRightsUnknownException extends DataRightsException {
  const DataRightsUnknownException({this.code, this.message});

  final String? code;
  final String? message;

  @override
  bool operator ==(Object other) =>
      other is DataRightsUnknownException &&
      other.code == code &&
      other.message == message;

  @override
  int get hashCode => Object.hash(code, message);

  @override
  String toString() =>
      'DataRightsUnknownException(code: $code, message: $message)';
}
