import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/purchases_failure_mapper.dart';
import '../../domain/purchase_exception.dart';
import '../../domain/purchases_repository_provider.dart';
import 'pending_purchase.dart';

part 'paywall_purchase_controller.g.dart';

/// Which flow a [PaywallPurchaseInFlight] is running.
enum PaywallPurchaseKind { purchase, restore }

/// Purchase-flow state for the paywall (idle → in-flight → idle | failure).
/// Success needs no state of its own: a completed purchase marks the durable
/// [PendingPurchase] flag and returns to idle, and the banner is driven by
/// `flag ∧ !isPremium` (ADR-014 Decision 3) — the mirror is the only unlocker.
sealed class PaywallPurchaseState {
  const PaywallPurchaseState();
}

final class PaywallPurchaseIdle extends PaywallPurchaseState {
  const PaywallPurchaseIdle();
}

final class PaywallPurchaseInFlight extends PaywallPurchaseState {
  const PaywallPurchaseInFlight(this.kind);

  final PaywallPurchaseKind kind;
}

final class PaywallPurchaseFailure extends PaywallPurchaseState {
  const PaywallPurchaseFailure(this.exception);

  final PurchaseException exception;
}

/// Drives [PurchasesRepository.purchase]/[PurchasesRepository.restore] with the
/// same manual-op discipline as `SoloAnswerController`: re-entrant calls are
/// dropped while one is in flight, and every await is followed by a
/// `ref.mounted` guard (Riverpod 3). autoDispose + family by coupleId.
///
/// On success the durable [PendingPurchase] flag is marked and the state returns
/// to idle — a cancelled sheet returns to idle silently (not an error), a typed
/// failure surfaces it, and a foreign error is mapped through the taxonomy.
@riverpod
class PaywallPurchaseController extends _$PaywallPurchaseController {
  @override
  PaywallPurchaseState build({required String coupleId}) =>
      const PaywallPurchaseIdle();

  Future<void> purchase(Package package) async {
    if (state is PaywallPurchaseInFlight) return;
    state = const PaywallPurchaseInFlight(PaywallPurchaseKind.purchase);
    try {
      await ref.read(purchasesRepositoryProvider).purchase(package);
      if (!ref.mounted) return;
      ref.read(pendingPurchaseProvider(coupleId: coupleId).notifier).mark();
      state = const PaywallPurchaseIdle();
    } on PurchaseCancelledException {
      if (!ref.mounted) return;
      state = const PaywallPurchaseIdle();
    } on PurchaseException catch (failure) {
      if (!ref.mounted) return;
      state = PaywallPurchaseFailure(failure);
    } catch (failure) {
      if (!ref.mounted) return;
      state = PaywallPurchaseFailure(mapPurchasesFailure(failure));
    }
  }

  Future<void> restore() async {
    if (state is PaywallPurchaseInFlight) return;
    state = const PaywallPurchaseInFlight(PaywallPurchaseKind.restore);
    try {
      await ref.read(purchasesRepositoryProvider).restore();
      if (!ref.mounted) return;
      ref.read(pendingPurchaseProvider(coupleId: coupleId).notifier).mark();
      state = const PaywallPurchaseIdle();
    } on PurchaseCancelledException {
      if (!ref.mounted) return;
      state = const PaywallPurchaseIdle();
    } on PurchaseException catch (failure) {
      if (!ref.mounted) return;
      state = PaywallPurchaseFailure(failure);
    } catch (failure) {
      if (!ref.mounted) return;
      state = PaywallPurchaseFailure(mapPurchasesFailure(failure));
    }
  }

  /// Dismisses a surfaced failure back to idle.
  void dismissError() {
    if (state is PaywallPurchaseFailure) state = const PaywallPurchaseIdle();
  }
}
