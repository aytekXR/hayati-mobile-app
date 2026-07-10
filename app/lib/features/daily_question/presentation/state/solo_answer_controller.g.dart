// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'solo_answer_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Drives [SoloAnswersRepository.saveAnswer] with the same manual-op
/// discipline as `ProfileCaptureController`: re-entrant saves are dropped
/// while one is in flight, and every await is followed by a `ref.mounted`
/// guard (Riverpod 3).

@ProviderFor(SoloAnswerController)
const soloAnswerControllerProvider = SoloAnswerControllerProvider._();

/// Drives [SoloAnswersRepository.saveAnswer] with the same manual-op
/// discipline as `ProfileCaptureController`: re-entrant saves are dropped
/// while one is in flight, and every await is followed by a `ref.mounted`
/// guard (Riverpod 3).
final class SoloAnswerControllerProvider
    extends $NotifierProvider<SoloAnswerController, SoloSaveState> {
  /// Drives [SoloAnswersRepository.saveAnswer] with the same manual-op
  /// discipline as `ProfileCaptureController`: re-entrant saves are dropped
  /// while one is in flight, and every await is followed by a `ref.mounted`
  /// guard (Riverpod 3).
  const SoloAnswerControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'soloAnswerControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$soloAnswerControllerHash();

  @$internal
  @override
  SoloAnswerController create() => SoloAnswerController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SoloSaveState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SoloSaveState>(value),
    );
  }
}

String _$soloAnswerControllerHash() =>
    r'c472213e9b145a86c8e7489b2e5f6e610ed69e17';

/// Drives [SoloAnswersRepository.saveAnswer] with the same manual-op
/// discipline as `ProfileCaptureController`: re-entrant saves are dropped
/// while one is in flight, and every await is followed by a `ref.mounted`
/// guard (Riverpod 3).

abstract class _$SoloAnswerController extends $Notifier<SoloSaveState> {
  SoloSaveState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<SoloSaveState, SoloSaveState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SoloSaveState, SoloSaveState>,
              SoloSaveState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
