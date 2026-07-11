// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pending_purchase.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The durable post-purchase "processing" signal for a couple (M4.2, ADR-014
/// Decision 3). keepAlive per coupleId so it survives the autoDispose paywall
/// controller dying on route pop: in the webhook-undeployed window `isPremium`
/// never flips, and an ephemeral banner would resurrect the buy buttons on
/// re-push. Set by a completed purchase/restore ([mark]); auto-clears the moment
/// the watched mirror flips `isPremium` true. The banner renders from
/// `flag ∧ !isPremium`, so it survives rebuilds and pop/re-push for the session.

@ProviderFor(PendingPurchase)
const pendingPurchaseProvider = PendingPurchaseFamily._();

/// The durable post-purchase "processing" signal for a couple (M4.2, ADR-014
/// Decision 3). keepAlive per coupleId so it survives the autoDispose paywall
/// controller dying on route pop: in the webhook-undeployed window `isPremium`
/// never flips, and an ephemeral banner would resurrect the buy buttons on
/// re-push. Set by a completed purchase/restore ([mark]); auto-clears the moment
/// the watched mirror flips `isPremium` true. The banner renders from
/// `flag ∧ !isPremium`, so it survives rebuilds and pop/re-push for the session.
final class PendingPurchaseProvider
    extends $NotifierProvider<PendingPurchase, bool> {
  /// The durable post-purchase "processing" signal for a couple (M4.2, ADR-014
  /// Decision 3). keepAlive per coupleId so it survives the autoDispose paywall
  /// controller dying on route pop: in the webhook-undeployed window `isPremium`
  /// never flips, and an ephemeral banner would resurrect the buy buttons on
  /// re-push. Set by a completed purchase/restore ([mark]); auto-clears the moment
  /// the watched mirror flips `isPremium` true. The banner renders from
  /// `flag ∧ !isPremium`, so it survives rebuilds and pop/re-push for the session.
  const PendingPurchaseProvider._({
    required PendingPurchaseFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'pendingPurchaseProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$pendingPurchaseHash();

  @override
  String toString() {
    return r'pendingPurchaseProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  PendingPurchase create() => PendingPurchase();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is PendingPurchaseProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$pendingPurchaseHash() => r'c9119876eef148f288a2d41e8f048d3fda77c05c';

/// The durable post-purchase "processing" signal for a couple (M4.2, ADR-014
/// Decision 3). keepAlive per coupleId so it survives the autoDispose paywall
/// controller dying on route pop: in the webhook-undeployed window `isPremium`
/// never flips, and an ephemeral banner would resurrect the buy buttons on
/// re-push. Set by a completed purchase/restore ([mark]); auto-clears the moment
/// the watched mirror flips `isPremium` true. The banner renders from
/// `flag ∧ !isPremium`, so it survives rebuilds and pop/re-push for the session.

final class PendingPurchaseFamily extends $Family
    with $ClassFamilyOverride<PendingPurchase, bool, bool, bool, String> {
  const PendingPurchaseFamily._()
    : super(
        retry: null,
        name: r'pendingPurchaseProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// The durable post-purchase "processing" signal for a couple (M4.2, ADR-014
  /// Decision 3). keepAlive per coupleId so it survives the autoDispose paywall
  /// controller dying on route pop: in the webhook-undeployed window `isPremium`
  /// never flips, and an ephemeral banner would resurrect the buy buttons on
  /// re-push. Set by a completed purchase/restore ([mark]); auto-clears the moment
  /// the watched mirror flips `isPremium` true. The banner renders from
  /// `flag ∧ !isPremium`, so it survives rebuilds and pop/re-push for the session.

  PendingPurchaseProvider call({required String coupleId}) =>
      PendingPurchaseProvider._(argument: coupleId, from: this);

  @override
  String toString() => r'pendingPurchaseProvider';
}

/// The durable post-purchase "processing" signal for a couple (M4.2, ADR-014
/// Decision 3). keepAlive per coupleId so it survives the autoDispose paywall
/// controller dying on route pop: in the webhook-undeployed window `isPremium`
/// never flips, and an ephemeral banner would resurrect the buy buttons on
/// re-push. Set by a completed purchase/restore ([mark]); auto-clears the moment
/// the watched mirror flips `isPremium` true. The banner renders from
/// `flag ∧ !isPremium`, so it survives rebuilds and pop/re-push for the session.

abstract class _$PendingPurchase extends $Notifier<bool> {
  late final _$args = ref.$arg as String;
  String get coupleId => _$args;

  bool build({required String coupleId});
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(coupleId: _$args);
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
