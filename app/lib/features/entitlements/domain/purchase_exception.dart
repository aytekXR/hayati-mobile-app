/// Failure taxonomy for the purchases seam (M4.2, ADR-014 Decision 1),
/// mirroring `EntitlementDataException`: user cancel is a flow state (not an
/// error), the SDK being unconfigured or the platform refusing is unavailable,
/// an un-identified customer is the pre-purchase guard, and store/network
/// problems keep their honest advice; unknown keeps the raw code. The data
/// layer's `mapPurchasesFailure` is the single choke point that produces these
/// — anything else escaping the repository is a bug.
sealed class PurchaseException implements Exception {
  const PurchaseException();
}

/// The user dismissed the store sheet — a flow outcome, never an error. The
/// controller returns to idle silently on this (ADR-014 Decision 3).
final class PurchaseCancelledException extends PurchaseException {
  const PurchaseCancelledException();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is PurchaseCancelledException;

  @override
  int get hashCode => (PurchaseCancelledException).hashCode;

  @override
  String toString() => 'PurchaseCancelledException()';
}

/// The SDK is unconfigured (no API key at bootstrap) or the platform refuses —
/// the fail-closed posture (ADR-014 Decision 2): the paywall renders an honest
/// unavailable state rather than a broken sheet.
final class PurchasesUnavailableException extends PurchaseException {
  const PurchasesUnavailableException();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is PurchasesUnavailableException;

  @override
  int get hashCode => (PurchasesUnavailableException).hashCode;

  @override
  String toString() => 'PurchasesUnavailableException()';
}

/// A purchase/restore was attempted before `Purchases.logIn(firebaseUid)` bound
/// the RC identity (the adapter's `isAnonymous` guard, ADR-014 Decision 2). An
/// anonymous purchase would leave the webhook unable to resolve the couple, so
/// it is made structurally impossible through our UI.
final class PurchaseNotIdentifiedException extends PurchaseException {
  const PurchaseNotIdentifiedException();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is PurchaseNotIdentifiedException;

  @override
  int get hashCode => (PurchaseNotIdentifiedException).hashCode;

  @override
  String toString() => 'PurchaseNotIdentifiedException()';
}

/// A transient connectivity failure (offerings fetch or purchase) — retry is
/// honest advice. Offerings fetch failures collapse here so the paywall shows
/// the standard network-retry view (ADR-014 Decision 3).
final class PurchaseNetworkException extends PurchaseException {
  const PurchaseNetworkException();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is PurchaseNetworkException;

  @override
  int get hashCode => (PurchaseNetworkException).hashCode;

  @override
  String toString() => 'PurchaseNetworkException()';
}

/// A store/billing problem (store unavailable, not-allowed, payment pending,
/// product state) — the user should retry or check their store account.
final class PurchaseStoreException extends PurchaseException {
  const PurchaseStoreException();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is PurchaseStoreException;

  @override
  int get hashCode => (PurchaseStoreException).hashCode;

  @override
  String toString() => 'PurchaseStoreException()';
}

/// Anything the mapper cannot place in a known bucket, keeping the raw [code]
/// and [message] for diagnostics — the total-by-construction fallback.
final class PurchaseUnknownException extends PurchaseException {
  const PurchaseUnknownException({this.code, this.message});

  final String? code;
  final String? message;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PurchaseUnknownException &&
          other.code == code &&
          other.message == message;

  @override
  int get hashCode => Object.hash(runtimeType, code, message);

  @override
  String toString() =>
      'PurchaseUnknownException(code: $code, message: $message)';
}

/// Offerings loaded but are unusable — no current offering, or a current
/// offering with an empty package list (an unconfigured dashboard). Thrown by
/// `derivePaywallOffering` so the paywall renders the honest error state rather
/// than an empty sheet (ADR-014 Decision 3).
final class PaywallUnavailableException extends PurchaseException {
  const PaywallUnavailableException();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is PaywallUnavailableException;

  @override
  int get hashCode => (PaywallUnavailableException).hashCode;

  @override
  String toString() => 'PaywallUnavailableException()';
}
