// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'coach_transcript.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// One persona conversation's transcript (ADR-017 Decisions 2/3/6/8), a
/// `keepAlive` family keyed by `(uid, coupleId, personaId)` (Decision 3):
/// ephemeral in-memory, survives route pop/re-push and a mid-send controller
/// disposal, cleared on app restart, and keyed by `uid` so a second account on
/// the device gets fresh state. Never persists conversation content anywhere.

@ProviderFor(CoachTranscript)
const coachTranscriptProvider = CoachTranscriptFamily._();

/// One persona conversation's transcript (ADR-017 Decisions 2/3/6/8), a
/// `keepAlive` family keyed by `(uid, coupleId, personaId)` (Decision 3):
/// ephemeral in-memory, survives route pop/re-push and a mid-send controller
/// disposal, cleared on app restart, and keyed by `uid` so a second account on
/// the device gets fresh state. Never persists conversation content anywhere.
final class CoachTranscriptProvider
    extends $NotifierProvider<CoachTranscript, CoachTranscriptState> {
  /// One persona conversation's transcript (ADR-017 Decisions 2/3/6/8), a
  /// `keepAlive` family keyed by `(uid, coupleId, personaId)` (Decision 3):
  /// ephemeral in-memory, survives route pop/re-push and a mid-send controller
  /// disposal, cleared on app restart, and keyed by `uid` so a second account on
  /// the device gets fresh state. Never persists conversation content anywhere.
  const CoachTranscriptProvider._({
    required CoachTranscriptFamily super.from,
    required (String, String, CoachPersonaId) super.argument,
  }) : super(
         retry: null,
         name: r'coachTranscriptProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$coachTranscriptHash();

  @override
  String toString() {
    return r'coachTranscriptProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  CoachTranscript create() => CoachTranscript();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CoachTranscriptState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CoachTranscriptState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is CoachTranscriptProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$coachTranscriptHash() => r'ef1ca008b307a15b2af72a5398b76494e26ad271';

/// One persona conversation's transcript (ADR-017 Decisions 2/3/6/8), a
/// `keepAlive` family keyed by `(uid, coupleId, personaId)` (Decision 3):
/// ephemeral in-memory, survives route pop/re-push and a mid-send controller
/// disposal, cleared on app restart, and keyed by `uid` so a second account on
/// the device gets fresh state. Never persists conversation content anywhere.

final class CoachTranscriptFamily extends $Family
    with
        $ClassFamilyOverride<
          CoachTranscript,
          CoachTranscriptState,
          CoachTranscriptState,
          CoachTranscriptState,
          (String, String, CoachPersonaId)
        > {
  const CoachTranscriptFamily._()
    : super(
        retry: null,
        name: r'coachTranscriptProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// One persona conversation's transcript (ADR-017 Decisions 2/3/6/8), a
  /// `keepAlive` family keyed by `(uid, coupleId, personaId)` (Decision 3):
  /// ephemeral in-memory, survives route pop/re-push and a mid-send controller
  /// disposal, cleared on app restart, and keyed by `uid` so a second account on
  /// the device gets fresh state. Never persists conversation content anywhere.

  CoachTranscriptProvider call(
    String uid,
    String coupleId,
    CoachPersonaId personaId,
  ) => CoachTranscriptProvider._(
    argument: (uid, coupleId, personaId),
    from: this,
  );

  @override
  String toString() => r'coachTranscriptProvider';
}

/// One persona conversation's transcript (ADR-017 Decisions 2/3/6/8), a
/// `keepAlive` family keyed by `(uid, coupleId, personaId)` (Decision 3):
/// ephemeral in-memory, survives route pop/re-push and a mid-send controller
/// disposal, cleared on app restart, and keyed by `uid` so a second account on
/// the device gets fresh state. Never persists conversation content anywhere.

abstract class _$CoachTranscript extends $Notifier<CoachTranscriptState> {
  late final _$args = ref.$arg as (String, String, CoachPersonaId);
  String get uid => _$args.$1;
  String get coupleId => _$args.$2;
  CoachPersonaId get personaId => _$args.$3;

  CoachTranscriptState build(
    String uid,
    String coupleId,
    CoachPersonaId personaId,
  );
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args.$1, _$args.$2, _$args.$3);
    final ref = this.ref as $Ref<CoachTranscriptState, CoachTranscriptState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<CoachTranscriptState, CoachTranscriptState>,
              CoachTranscriptState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
