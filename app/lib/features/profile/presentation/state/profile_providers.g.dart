// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Live `users/{uid}` profile (null until capture completes). AutoDispose:
/// the subscription lives exactly as long as a widget watches it, and a
/// retry after a stream failure is a plain `ref.invalidate` → fresh
/// subscription (Firestore re-emits current state on listen).

@ProviderFor(profileStream)
const profileStreamProvider = ProfileStreamFamily._();

/// Live `users/{uid}` profile (null until capture completes). AutoDispose:
/// the subscription lives exactly as long as a widget watches it, and a
/// retry after a stream failure is a plain `ref.invalidate` → fresh
/// subscription (Firestore re-emits current state on listen).

final class ProfileStreamProvider
    extends
        $FunctionalProvider<
          AsyncValue<RelationshipProfile?>,
          RelationshipProfile?,
          Stream<RelationshipProfile?>
        >
    with
        $FutureModifier<RelationshipProfile?>,
        $StreamProvider<RelationshipProfile?> {
  /// Live `users/{uid}` profile (null until capture completes). AutoDispose:
  /// the subscription lives exactly as long as a widget watches it, and a
  /// retry after a stream failure is a plain `ref.invalidate` → fresh
  /// subscription (Firestore re-emits current state on listen).
  const ProfileStreamProvider._({
    required ProfileStreamFamily super.from,
    required String super.argument,
  }) : super(
         retry: _noRetry,
         name: r'profileStreamProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$profileStreamHash();

  @override
  String toString() {
    return r'profileStreamProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<RelationshipProfile?> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<RelationshipProfile?> create(Ref ref) {
    final argument = this.argument as String;
    return profileStream(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ProfileStreamProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$profileStreamHash() => r'43a9183270a3a148a426ed41e719dd2982420744';

/// Live `users/{uid}` profile (null until capture completes). AutoDispose:
/// the subscription lives exactly as long as a widget watches it, and a
/// retry after a stream failure is a plain `ref.invalidate` → fresh
/// subscription (Firestore re-emits current state on listen).

final class ProfileStreamFamily extends $Family
    with $FunctionalFamilyOverride<Stream<RelationshipProfile?>, String> {
  const ProfileStreamFamily._()
    : super(
        retry: _noRetry,
        name: r'profileStreamProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Live `users/{uid}` profile (null until capture completes). AutoDispose:
  /// the subscription lives exactly as long as a widget watches it, and a
  /// retry after a stream failure is a plain `ref.invalidate` → fresh
  /// subscription (Firestore re-emits current state on listen).

  ProfileStreamProvider call(String uid) =>
      ProfileStreamProvider._(argument: uid, from: this);

  @override
  String toString() => r'profileStreamProvider';
}
