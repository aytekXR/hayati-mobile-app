// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'coach_send_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Drives [CoachRepository.sendMessage] for ONE persona conversation with the
/// manual-op discipline of `SoloAnswerController` (ADR-017 Decision 8). An
/// autoDispose family keyed `(uid, coupleId, personaId)` — the same key as the
/// transcript — so persona A's in-flight send never blocks persona B.
///
/// The transcript append SURVIVES controller disposal: [send] captures the
/// persona's keepAlive [CoachTranscript] notifier AND its current entries BEFORE
/// the await, so a mid-send persona switch (which autoDisposes THIS controller)
/// still lands the paid-for reply — and its latch/hint effects — in the right
/// conversation. `ref.mounted` guards ONLY this controller's OWN state writes.

@ProviderFor(CoachSendController)
const coachSendControllerProvider = CoachSendControllerFamily._();

/// Drives [CoachRepository.sendMessage] for ONE persona conversation with the
/// manual-op discipline of `SoloAnswerController` (ADR-017 Decision 8). An
/// autoDispose family keyed `(uid, coupleId, personaId)` — the same key as the
/// transcript — so persona A's in-flight send never blocks persona B.
///
/// The transcript append SURVIVES controller disposal: [send] captures the
/// persona's keepAlive [CoachTranscript] notifier AND its current entries BEFORE
/// the await, so a mid-send persona switch (which autoDisposes THIS controller)
/// still lands the paid-for reply — and its latch/hint effects — in the right
/// conversation. `ref.mounted` guards ONLY this controller's OWN state writes.
final class CoachSendControllerProvider
    extends $NotifierProvider<CoachSendController, CoachSendState> {
  /// Drives [CoachRepository.sendMessage] for ONE persona conversation with the
  /// manual-op discipline of `SoloAnswerController` (ADR-017 Decision 8). An
  /// autoDispose family keyed `(uid, coupleId, personaId)` — the same key as the
  /// transcript — so persona A's in-flight send never blocks persona B.
  ///
  /// The transcript append SURVIVES controller disposal: [send] captures the
  /// persona's keepAlive [CoachTranscript] notifier AND its current entries BEFORE
  /// the await, so a mid-send persona switch (which autoDisposes THIS controller)
  /// still lands the paid-for reply — and its latch/hint effects — in the right
  /// conversation. `ref.mounted` guards ONLY this controller's OWN state writes.
  const CoachSendControllerProvider._({
    required CoachSendControllerFamily super.from,
    required (String, String, CoachPersonaId) super.argument,
  }) : super(
         retry: null,
         name: r'coachSendControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$coachSendControllerHash();

  @override
  String toString() {
    return r'coachSendControllerProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  CoachSendController create() => CoachSendController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CoachSendState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CoachSendState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is CoachSendControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$coachSendControllerHash() =>
    r'327c2eacf91eb82851233108a3118db3bad2c802';

/// Drives [CoachRepository.sendMessage] for ONE persona conversation with the
/// manual-op discipline of `SoloAnswerController` (ADR-017 Decision 8). An
/// autoDispose family keyed `(uid, coupleId, personaId)` — the same key as the
/// transcript — so persona A's in-flight send never blocks persona B.
///
/// The transcript append SURVIVES controller disposal: [send] captures the
/// persona's keepAlive [CoachTranscript] notifier AND its current entries BEFORE
/// the await, so a mid-send persona switch (which autoDisposes THIS controller)
/// still lands the paid-for reply — and its latch/hint effects — in the right
/// conversation. `ref.mounted` guards ONLY this controller's OWN state writes.

final class CoachSendControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          CoachSendController,
          CoachSendState,
          CoachSendState,
          CoachSendState,
          (String, String, CoachPersonaId)
        > {
  const CoachSendControllerFamily._()
    : super(
        retry: null,
        name: r'coachSendControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Drives [CoachRepository.sendMessage] for ONE persona conversation with the
  /// manual-op discipline of `SoloAnswerController` (ADR-017 Decision 8). An
  /// autoDispose family keyed `(uid, coupleId, personaId)` — the same key as the
  /// transcript — so persona A's in-flight send never blocks persona B.
  ///
  /// The transcript append SURVIVES controller disposal: [send] captures the
  /// persona's keepAlive [CoachTranscript] notifier AND its current entries BEFORE
  /// the await, so a mid-send persona switch (which autoDisposes THIS controller)
  /// still lands the paid-for reply — and its latch/hint effects — in the right
  /// conversation. `ref.mounted` guards ONLY this controller's OWN state writes.

  CoachSendControllerProvider call(
    String uid,
    String coupleId,
    CoachPersonaId personaId,
  ) => CoachSendControllerProvider._(
    argument: (uid, coupleId, personaId),
    from: this,
  );

  @override
  String toString() => r'coachSendControllerProvider';
}

/// Drives [CoachRepository.sendMessage] for ONE persona conversation with the
/// manual-op discipline of `SoloAnswerController` (ADR-017 Decision 8). An
/// autoDispose family keyed `(uid, coupleId, personaId)` — the same key as the
/// transcript — so persona A's in-flight send never blocks persona B.
///
/// The transcript append SURVIVES controller disposal: [send] captures the
/// persona's keepAlive [CoachTranscript] notifier AND its current entries BEFORE
/// the await, so a mid-send persona switch (which autoDisposes THIS controller)
/// still lands the paid-for reply — and its latch/hint effects — in the right
/// conversation. `ref.mounted` guards ONLY this controller's OWN state writes.

abstract class _$CoachSendController extends $Notifier<CoachSendState> {
  late final _$args = ref.$arg as (String, String, CoachPersonaId);
  String get uid => _$args.$1;
  String get coupleId => _$args.$2;
  CoachPersonaId get personaId => _$args.$3;

  CoachSendState build(String uid, String coupleId, CoachPersonaId personaId);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args.$1, _$args.$2, _$args.$3);
    final ref = this.ref as $Ref<CoachSendState, CoachSendState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<CoachSendState, CoachSendState>,
              CoachSendState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
