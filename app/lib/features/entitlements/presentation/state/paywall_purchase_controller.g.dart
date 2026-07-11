// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'paywall_purchase_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Drives [PurchasesRepository.purchase]/[PurchasesRepository.restore] with the
/// same manual-op discipline as `SoloAnswerController`: re-entrant calls are
/// dropped while one is in flight, and every await is followed by a
/// `ref.mounted` guard (Riverpod 3). autoDispose + family by coupleId.
///
/// On success the durable [PendingPurchase] flag is marked and the state returns
/// to idle — a cancelled sheet returns to idle silently (not an error), a typed
/// failure surfaces it, and a foreign error is mapped through the taxonomy.

@ProviderFor(PaywallPurchaseController)
const paywallPurchaseControllerProvider = PaywallPurchaseControllerFamily._();

/// Drives [PurchasesRepository.purchase]/[PurchasesRepository.restore] with the
/// same manual-op discipline as `SoloAnswerController`: re-entrant calls are
/// dropped while one is in flight, and every await is followed by a
/// `ref.mounted` guard (Riverpod 3). autoDispose + family by coupleId.
///
/// On success the durable [PendingPurchase] flag is marked and the state returns
/// to idle — a cancelled sheet returns to idle silently (not an error), a typed
/// failure surfaces it, and a foreign error is mapped through the taxonomy.
final class PaywallPurchaseControllerProvider
    extends $NotifierProvider<PaywallPurchaseController, PaywallPurchaseState> {
  /// Drives [PurchasesRepository.purchase]/[PurchasesRepository.restore] with the
  /// same manual-op discipline as `SoloAnswerController`: re-entrant calls are
  /// dropped while one is in flight, and every await is followed by a
  /// `ref.mounted` guard (Riverpod 3). autoDispose + family by coupleId.
  ///
  /// On success the durable [PendingPurchase] flag is marked and the state returns
  /// to idle — a cancelled sheet returns to idle silently (not an error), a typed
  /// failure surfaces it, and a foreign error is mapped through the taxonomy.
  const PaywallPurchaseControllerProvider._({
    required PaywallPurchaseControllerFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'paywallPurchaseControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$paywallPurchaseControllerHash();

  @override
  String toString() {
    return r'paywallPurchaseControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  PaywallPurchaseController create() => PaywallPurchaseController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PaywallPurchaseState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PaywallPurchaseState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is PaywallPurchaseControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$paywallPurchaseControllerHash() =>
    r'84512a4f986257fdcbae921ea35ac88d7eb3da80';

/// Drives [PurchasesRepository.purchase]/[PurchasesRepository.restore] with the
/// same manual-op discipline as `SoloAnswerController`: re-entrant calls are
/// dropped while one is in flight, and every await is followed by a
/// `ref.mounted` guard (Riverpod 3). autoDispose + family by coupleId.
///
/// On success the durable [PendingPurchase] flag is marked and the state returns
/// to idle — a cancelled sheet returns to idle silently (not an error), a typed
/// failure surfaces it, and a foreign error is mapped through the taxonomy.

final class PaywallPurchaseControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          PaywallPurchaseController,
          PaywallPurchaseState,
          PaywallPurchaseState,
          PaywallPurchaseState,
          String
        > {
  const PaywallPurchaseControllerFamily._()
    : super(
        retry: null,
        name: r'paywallPurchaseControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Drives [PurchasesRepository.purchase]/[PurchasesRepository.restore] with the
  /// same manual-op discipline as `SoloAnswerController`: re-entrant calls are
  /// dropped while one is in flight, and every await is followed by a
  /// `ref.mounted` guard (Riverpod 3). autoDispose + family by coupleId.
  ///
  /// On success the durable [PendingPurchase] flag is marked and the state returns
  /// to idle — a cancelled sheet returns to idle silently (not an error), a typed
  /// failure surfaces it, and a foreign error is mapped through the taxonomy.

  PaywallPurchaseControllerProvider call({required String coupleId}) =>
      PaywallPurchaseControllerProvider._(argument: coupleId, from: this);

  @override
  String toString() => r'paywallPurchaseControllerProvider';
}

/// Drives [PurchasesRepository.purchase]/[PurchasesRepository.restore] with the
/// same manual-op discipline as `SoloAnswerController`: re-entrant calls are
/// dropped while one is in flight, and every await is followed by a
/// `ref.mounted` guard (Riverpod 3). autoDispose + family by coupleId.
///
/// On success the durable [PendingPurchase] flag is marked and the state returns
/// to idle — a cancelled sheet returns to idle silently (not an error), a typed
/// failure surfaces it, and a foreign error is mapped through the taxonomy.

abstract class _$PaywallPurchaseController
    extends $Notifier<PaywallPurchaseState> {
  late final _$args = ref.$arg as String;
  String get coupleId => _$args;

  PaywallPurchaseState build({required String coupleId});
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(coupleId: _$args);
    final ref = this.ref as $Ref<PaywallPurchaseState, PaywallPurchaseState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<PaywallPurchaseState, PaywallPurchaseState>,
              PaywallPurchaseState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
