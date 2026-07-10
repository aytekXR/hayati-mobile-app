// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'solo_question_pack_repository_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Seam for [SoloQuestionPackRepository]: bound to the asset-backed
/// implementation at bootstrap (main_dev.dart / main_prod.dart), faked per
/// test container — same throw-until-overridden discipline as
/// `profileRepositoryProvider`.

@ProviderFor(soloQuestionPackRepository)
const soloQuestionPackRepositoryProvider =
    SoloQuestionPackRepositoryProvider._();

/// Seam for [SoloQuestionPackRepository]: bound to the asset-backed
/// implementation at bootstrap (main_dev.dart / main_prod.dart), faked per
/// test container — same throw-until-overridden discipline as
/// `profileRepositoryProvider`.

final class SoloQuestionPackRepositoryProvider
    extends
        $FunctionalProvider<
          SoloQuestionPackRepository,
          SoloQuestionPackRepository,
          SoloQuestionPackRepository
        >
    with $Provider<SoloQuestionPackRepository> {
  /// Seam for [SoloQuestionPackRepository]: bound to the asset-backed
  /// implementation at bootstrap (main_dev.dart / main_prod.dart), faked per
  /// test container — same throw-until-overridden discipline as
  /// `profileRepositoryProvider`.
  const SoloQuestionPackRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'soloQuestionPackRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$soloQuestionPackRepositoryHash();

  @$internal
  @override
  $ProviderElement<SoloQuestionPackRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SoloQuestionPackRepository create(Ref ref) {
    return soloQuestionPackRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SoloQuestionPackRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SoloQuestionPackRepository>(value),
    );
  }
}

String _$soloQuestionPackRepositoryHash() =>
    r'f4951eb58f623777dc5c847ae7e04aaa150d1867';
