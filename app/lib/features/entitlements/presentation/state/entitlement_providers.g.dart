// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'entitlement_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Live `subscriptions/{coupleId}` mirror (M4.1 — the app's entitlement read,
/// ADR-013 Decision 5). Null = the doc does not exist yet: the free tier
/// (every couple is free until the webhook writes otherwise — no backfill).

@ProviderFor(entitlementStream)
const entitlementStreamProvider = EntitlementStreamFamily._();

/// Live `subscriptions/{coupleId}` mirror (M4.1 — the app's entitlement read,
/// ADR-013 Decision 5). Null = the doc does not exist yet: the free tier
/// (every couple is free until the webhook writes otherwise — no backfill).

final class EntitlementStreamProvider
    extends
        $FunctionalProvider<
          AsyncValue<CoupleEntitlement?>,
          CoupleEntitlement?,
          Stream<CoupleEntitlement?>
        >
    with
        $FutureModifier<CoupleEntitlement?>,
        $StreamProvider<CoupleEntitlement?> {
  /// Live `subscriptions/{coupleId}` mirror (M4.1 — the app's entitlement read,
  /// ADR-013 Decision 5). Null = the doc does not exist yet: the free tier
  /// (every couple is free until the webhook writes otherwise — no backfill).
  const EntitlementStreamProvider._({
    required EntitlementStreamFamily super.from,
    required String super.argument,
  }) : super(
         retry: _noRetry,
         name: r'entitlementStreamProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$entitlementStreamHash();

  @override
  String toString() {
    return r'entitlementStreamProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<CoupleEntitlement?> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<CoupleEntitlement?> create(Ref ref) {
    final argument = this.argument as String;
    return entitlementStream(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is EntitlementStreamProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$entitlementStreamHash() => r'419ef75fd3cd5934835779ae3247dd661da7dac4';

/// Live `subscriptions/{coupleId}` mirror (M4.1 — the app's entitlement read,
/// ADR-013 Decision 5). Null = the doc does not exist yet: the free tier
/// (every couple is free until the webhook writes otherwise — no backfill).

final class EntitlementStreamFamily extends $Family
    with $FunctionalFamilyOverride<Stream<CoupleEntitlement?>, String> {
  const EntitlementStreamFamily._()
    : super(
        retry: _noRetry,
        name: r'entitlementStreamProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Live `subscriptions/{coupleId}` mirror (M4.1 — the app's entitlement read,
  /// ADR-013 Decision 5). Null = the doc does not exist yet: the free tier
  /// (every couple is free until the webhook writes otherwise — no backfill).

  EntitlementStreamProvider call(String coupleId) =>
      EntitlementStreamProvider._(argument: coupleId, from: this);

  @override
  String toString() => r'entitlementStreamProvider';
}

/// The single premium-gating decision point (M4.1, ADR-013 Decision 5). Free
/// until proven entitled: an in-flight first load, a settled (un-retried)
/// error, or an absent doc all read as NOT premium — the AsyncValue-flag
/// precedence idiom (not the subtype; Riverpod 3 carries a previous value/error
/// across states).
///
/// [CoupleEntitlement.entitled] is never sufficient alone (ADR-013 Decision 5,
/// binding on every consumer): a delayed EXPIRATION leaves the mirror
/// `entitled: true` with a past [CoupleEntitlement.expiresAt] for hours, so the
/// boolean is paired with the future-check against the app's single clock seam
/// (`soloClockProvider`). A null `expiresAt` is the non-expiring sentinel and
/// always passes.

@ProviderFor(isPremium)
const isPremiumProvider = IsPremiumFamily._();

/// The single premium-gating decision point (M4.1, ADR-013 Decision 5). Free
/// until proven entitled: an in-flight first load, a settled (un-retried)
/// error, or an absent doc all read as NOT premium — the AsyncValue-flag
/// precedence idiom (not the subtype; Riverpod 3 carries a previous value/error
/// across states).
///
/// [CoupleEntitlement.entitled] is never sufficient alone (ADR-013 Decision 5,
/// binding on every consumer): a delayed EXPIRATION leaves the mirror
/// `entitled: true` with a past [CoupleEntitlement.expiresAt] for hours, so the
/// boolean is paired with the future-check against the app's single clock seam
/// (`soloClockProvider`). A null `expiresAt` is the non-expiring sentinel and
/// always passes.

final class IsPremiumProvider extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// The single premium-gating decision point (M4.1, ADR-013 Decision 5). Free
  /// until proven entitled: an in-flight first load, a settled (un-retried)
  /// error, or an absent doc all read as NOT premium — the AsyncValue-flag
  /// precedence idiom (not the subtype; Riverpod 3 carries a previous value/error
  /// across states).
  ///
  /// [CoupleEntitlement.entitled] is never sufficient alone (ADR-013 Decision 5,
  /// binding on every consumer): a delayed EXPIRATION leaves the mirror
  /// `entitled: true` with a past [CoupleEntitlement.expiresAt] for hours, so the
  /// boolean is paired with the future-check against the app's single clock seam
  /// (`soloClockProvider`). A null `expiresAt` is the non-expiring sentinel and
  /// always passes.
  const IsPremiumProvider._({
    required IsPremiumFamily super.from,
    required String super.argument,
  }) : super(
         retry: _noRetry,
         name: r'isPremiumProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$isPremiumHash();

  @override
  String toString() {
    return r'isPremiumProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    final argument = this.argument as String;
    return isPremium(ref, coupleId: argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is IsPremiumProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$isPremiumHash() => r'782cf58ad21b2653cd43402b1773e4b7e0d4c74d';

/// The single premium-gating decision point (M4.1, ADR-013 Decision 5). Free
/// until proven entitled: an in-flight first load, a settled (un-retried)
/// error, or an absent doc all read as NOT premium — the AsyncValue-flag
/// precedence idiom (not the subtype; Riverpod 3 carries a previous value/error
/// across states).
///
/// [CoupleEntitlement.entitled] is never sufficient alone (ADR-013 Decision 5,
/// binding on every consumer): a delayed EXPIRATION leaves the mirror
/// `entitled: true` with a past [CoupleEntitlement.expiresAt] for hours, so the
/// boolean is paired with the future-check against the app's single clock seam
/// (`soloClockProvider`). A null `expiresAt` is the non-expiring sentinel and
/// always passes.

final class IsPremiumFamily extends $Family
    with $FunctionalFamilyOverride<bool, String> {
  const IsPremiumFamily._()
    : super(
        retry: _noRetry,
        name: r'isPremiumProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The single premium-gating decision point (M4.1, ADR-013 Decision 5). Free
  /// until proven entitled: an in-flight first load, a settled (un-retried)
  /// error, or an absent doc all read as NOT premium — the AsyncValue-flag
  /// precedence idiom (not the subtype; Riverpod 3 carries a previous value/error
  /// across states).
  ///
  /// [CoupleEntitlement.entitled] is never sufficient alone (ADR-013 Decision 5,
  /// binding on every consumer): a delayed EXPIRATION leaves the mirror
  /// `entitled: true` with a past [CoupleEntitlement.expiresAt] for hours, so the
  /// boolean is paired with the future-check against the app's single clock seam
  /// (`soloClockProvider`). A null `expiresAt` is the non-expiring sentinel and
  /// always passes.

  IsPremiumProvider call({required String coupleId}) =>
      IsPremiumProvider._(argument: coupleId, from: this);

  @override
  String toString() => r'isPremiumProvider';
}
