// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'couple_answers_repository_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Seam for [CoupleAnswersRepository]: bound to the Firestore implementation
/// at bootstrap (main_dev.dart / main_prod.dart), faked per test container —
/// same throw-until-overridden discipline as `profileRepositoryProvider`.

@ProviderFor(coupleAnswersRepository)
const coupleAnswersRepositoryProvider = CoupleAnswersRepositoryProvider._();

/// Seam for [CoupleAnswersRepository]: bound to the Firestore implementation
/// at bootstrap (main_dev.dart / main_prod.dart), faked per test container —
/// same throw-until-overridden discipline as `profileRepositoryProvider`.

final class CoupleAnswersRepositoryProvider
    extends
        $FunctionalProvider<
          CoupleAnswersRepository,
          CoupleAnswersRepository,
          CoupleAnswersRepository
        >
    with $Provider<CoupleAnswersRepository> {
  /// Seam for [CoupleAnswersRepository]: bound to the Firestore implementation
  /// at bootstrap (main_dev.dart / main_prod.dart), faked per test container —
  /// same throw-until-overridden discipline as `profileRepositoryProvider`.
  const CoupleAnswersRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'coupleAnswersRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$coupleAnswersRepositoryHash();

  @$internal
  @override
  $ProviderElement<CoupleAnswersRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CoupleAnswersRepository create(Ref ref) {
    return coupleAnswersRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CoupleAnswersRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CoupleAnswersRepository>(value),
    );
  }
}

String _$coupleAnswersRepositoryHash() =>
    r'7a0262cb15c7cb956b13d6f4cf0d2db3618c0fb2';
