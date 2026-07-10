// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'question_pack_repository_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Seam for the generic by-packId [QuestionPackRepository] (M3.3 — the
/// paired home resolves the day's question text by the day doc's `packId`;
/// the solo path keeps its own locale-keyed specialization seam). Bound to
/// the asset-backed implementation at bootstrap, faked per test container —
/// same throw-until-overridden discipline as `profileRepositoryProvider`.

@ProviderFor(questionPackRepository)
const questionPackRepositoryProvider = QuestionPackRepositoryProvider._();

/// Seam for the generic by-packId [QuestionPackRepository] (M3.3 — the
/// paired home resolves the day's question text by the day doc's `packId`;
/// the solo path keeps its own locale-keyed specialization seam). Bound to
/// the asset-backed implementation at bootstrap, faked per test container —
/// same throw-until-overridden discipline as `profileRepositoryProvider`.

final class QuestionPackRepositoryProvider
    extends
        $FunctionalProvider<
          QuestionPackRepository,
          QuestionPackRepository,
          QuestionPackRepository
        >
    with $Provider<QuestionPackRepository> {
  /// Seam for the generic by-packId [QuestionPackRepository] (M3.3 — the
  /// paired home resolves the day's question text by the day doc's `packId`;
  /// the solo path keeps its own locale-keyed specialization seam). Bound to
  /// the asset-backed implementation at bootstrap, faked per test container —
  /// same throw-until-overridden discipline as `profileRepositoryProvider`.
  const QuestionPackRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'questionPackRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$questionPackRepositoryHash();

  @$internal
  @override
  $ProviderElement<QuestionPackRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  QuestionPackRepository create(Ref ref) {
    return questionPackRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(QuestionPackRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<QuestionPackRepository>(value),
    );
  }
}

String _$questionPackRepositoryHash() =>
    r'22e58ff487a002165c61c0a28956be3fe6eb7073';
