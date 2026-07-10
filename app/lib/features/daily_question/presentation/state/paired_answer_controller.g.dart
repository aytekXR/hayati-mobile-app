// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'paired_answer_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Drives [CoupleAnswersRepository.saveAnswer] with the same manual-op
/// discipline as `SoloAnswerController`: re-entrant saves are dropped while
/// one is in flight, and every await is followed by a `ref.mounted` guard.

@ProviderFor(PairedAnswerController)
const pairedAnswerControllerProvider = PairedAnswerControllerProvider._();

/// Drives [CoupleAnswersRepository.saveAnswer] with the same manual-op
/// discipline as `SoloAnswerController`: re-entrant saves are dropped while
/// one is in flight, and every await is followed by a `ref.mounted` guard.
final class PairedAnswerControllerProvider
    extends $NotifierProvider<PairedAnswerController, PairedSaveState> {
  /// Drives [CoupleAnswersRepository.saveAnswer] with the same manual-op
  /// discipline as `SoloAnswerController`: re-entrant saves are dropped while
  /// one is in flight, and every await is followed by a `ref.mounted` guard.
  const PairedAnswerControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pairedAnswerControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pairedAnswerControllerHash();

  @$internal
  @override
  PairedAnswerController create() => PairedAnswerController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PairedSaveState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PairedSaveState>(value),
    );
  }
}

String _$pairedAnswerControllerHash() =>
    r'13f061964e6837e4d5dbcbf02ec293bfd7f35a0f';

/// Drives [CoupleAnswersRepository.saveAnswer] with the same manual-op
/// discipline as `SoloAnswerController`: re-entrant saves are dropped while
/// one is in flight, and every await is followed by a `ref.mounted` guard.

abstract class _$PairedAnswerController extends $Notifier<PairedSaveState> {
  PairedSaveState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<PairedSaveState, PairedSaveState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<PairedSaveState, PairedSaveState>,
              PairedSaveState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
