// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'solo_answers_repository_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Seam for [SoloAnswersRepository]: bound to the Firestore implementation at
/// bootstrap (main_dev.dart / main_prod.dart), faked per test container —
/// same throw-until-overridden discipline as `profileRepositoryProvider`.

@ProviderFor(soloAnswersRepository)
const soloAnswersRepositoryProvider = SoloAnswersRepositoryProvider._();

/// Seam for [SoloAnswersRepository]: bound to the Firestore implementation at
/// bootstrap (main_dev.dart / main_prod.dart), faked per test container —
/// same throw-until-overridden discipline as `profileRepositoryProvider`.

final class SoloAnswersRepositoryProvider
    extends
        $FunctionalProvider<
          SoloAnswersRepository,
          SoloAnswersRepository,
          SoloAnswersRepository
        >
    with $Provider<SoloAnswersRepository> {
  /// Seam for [SoloAnswersRepository]: bound to the Firestore implementation at
  /// bootstrap (main_dev.dart / main_prod.dart), faked per test container —
  /// same throw-until-overridden discipline as `profileRepositoryProvider`.
  const SoloAnswersRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'soloAnswersRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$soloAnswersRepositoryHash();

  @$internal
  @override
  $ProviderElement<SoloAnswersRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SoloAnswersRepository create(Ref ref) {
    return soloAnswersRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SoloAnswersRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SoloAnswersRepository>(value),
    );
  }
}

String _$soloAnswersRepositoryHash() =>
    r'91964cfabfc2ae731de9e2c211e669d2dd4b962e';
