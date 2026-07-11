import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../domain/purchase_exception.dart';

/// Boundary enforcement for the `purchases_flutter` error surface (ADR-014
/// Decision 1), total by construction. `PurchasesErrorHelper.getErrorCode`
/// itself is NOT total — it `num.parse`s the exception code and indexes the
/// enum with only an upper-bound guard, so a non-numeric code (`'channel-error'`)
/// throws `FormatException` and a negative one throws `RangeError`. This mapper
/// reimplements the lookup safely behind an `int.tryParse` guard and never
/// throws.
///
/// The single choke point for the seam — an already-typed [PurchaseException]
/// passes through unchanged. Bucket table (`PurchasesErrorCode` → taxonomy;
/// anything not listed → [PurchaseUnknownException] with the raw code/message):
///
/// | code                              | maps to                          |
/// |-----------------------------------|----------------------------------|
/// | purchaseCancelledError            | PurchaseCancelledException       |
/// | networkError, offlineConnectionError, apiEndpointBlocked, productRequestTimeout | PurchaseNetworkException |
/// | storeProblemError, purchaseNotAllowedError, purchaseInvalidError, productNotAvailableForPurchaseError, productAlreadyPurchasedError, paymentPendingError, ineligibleError, insufficientPermissionsError, receiptAlreadyInUseError, receiptInUseByOtherSubscriberError | PurchaseStoreException |
/// | configurationError                | PurchasesUnavailableException    |
///
/// [MissingPluginException] (the plugin channel is not connected — never a
/// `PlatformException`) maps to [PurchasesUnavailableException]; any other
/// non-platform object falls to [PurchaseUnknownException].
PurchaseException mapPurchasesFailure(Object failure) {
  if (failure is PurchaseException) return failure;
  if (failure is MissingPluginException) {
    return const PurchasesUnavailableException();
  }
  if (failure is PlatformException) {
    final index = int.tryParse(failure.code);
    if (index == null ||
        index < 0 ||
        index >= PurchasesErrorCode.values.length) {
      return PurchaseUnknownException(
        code: failure.code,
        message: failure.message,
      );
    }
    return switch (PurchasesErrorCode.values[index]) {
      PurchasesErrorCode.purchaseCancelledError =>
        const PurchaseCancelledException(),
      PurchasesErrorCode.networkError ||
      PurchasesErrorCode.offlineConnectionError ||
      PurchasesErrorCode.apiEndpointBlocked ||
      PurchasesErrorCode.productRequestTimeout =>
        const PurchaseNetworkException(),
      PurchasesErrorCode.storeProblemError ||
      PurchasesErrorCode.purchaseNotAllowedError ||
      PurchasesErrorCode.purchaseInvalidError ||
      PurchasesErrorCode.productNotAvailableForPurchaseError ||
      PurchasesErrorCode.productAlreadyPurchasedError ||
      PurchasesErrorCode.paymentPendingError ||
      PurchasesErrorCode.ineligibleError ||
      PurchasesErrorCode.insufficientPermissionsError ||
      PurchasesErrorCode.receiptAlreadyInUseError ||
      PurchasesErrorCode.receiptInUseByOtherSubscriberError =>
        const PurchaseStoreException(),
      PurchasesErrorCode.configurationError =>
        const PurchasesUnavailableException(),
      _ => PurchaseUnknownException(
        code: failure.code,
        message: failure.message,
      ),
    };
  }
  return PurchaseUnknownException(message: '$failure');
}
