// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'paired_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Live `couples/{coupleId}` doc (M3.3 — the app's first couple read; the
/// doc carries the timezone that keys the day). Null = corrupt state
/// (`users.coupleId` pointing at nothing) — the screen's error view owns it.

@ProviderFor(couple)
const coupleProvider = CoupleFamily._();

/// Live `couples/{coupleId}` doc (M3.3 — the app's first couple read; the
/// doc carries the timezone that keys the day). Null = corrupt state
/// (`users.coupleId` pointing at nothing) — the screen's error view owns it.

final class CoupleProvider
    extends $FunctionalProvider<AsyncValue<Couple?>, Couple?, Stream<Couple?>>
    with $FutureModifier<Couple?>, $StreamProvider<Couple?> {
  /// Live `couples/{coupleId}` doc (M3.3 — the app's first couple read; the
  /// doc carries the timezone that keys the day). Null = corrupt state
  /// (`users.coupleId` pointing at nothing) — the screen's error view owns it.
  const CoupleProvider._({
    required CoupleFamily super.from,
    required String super.argument,
  }) : super(
         retry: _noRetry,
         name: r'coupleProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$coupleHash();

  @override
  String toString() {
    return r'coupleProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<Couple?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<Couple?> create(Ref ref) {
    final argument = this.argument as String;
    return couple(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is CoupleProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$coupleHash() => r'd651b6fd2e565fba0799d5467e5cc50eec5798f9';

/// Live `couples/{coupleId}` doc (M3.3 — the app's first couple read; the
/// doc carries the timezone that keys the day). Null = corrupt state
/// (`users.coupleId` pointing at nothing) — the screen's error view owns it.

final class CoupleFamily extends $Family
    with $FunctionalFamilyOverride<Stream<Couple?>, String> {
  const CoupleFamily._()
    : super(
        retry: _noRetry,
        name: r'coupleProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Live `couples/{coupleId}` doc (M3.3 — the app's first couple read; the
  /// doc carries the timezone that keys the day). Null = corrupt state
  /// (`users.coupleId` pointing at nothing) — the screen's error view owns it.

  CoupleProvider call(String coupleId) =>
      CoupleProvider._(argument: coupleId, from: this);

  @override
  String toString() => r'coupleProvider';
}

/// Live `days/{dayKey}` assignment (null = no-day-yet: pre-first-rollover,
/// deploy lag, or the ≤1h post-midnight window — an honest waiting state,
/// never a client-side prediction; ADR-011).

@ProviderFor(coupleDayAssignment)
const coupleDayAssignmentProvider = CoupleDayAssignmentFamily._();

/// Live `days/{dayKey}` assignment (null = no-day-yet: pre-first-rollover,
/// deploy lag, or the ≤1h post-midnight window — an honest waiting state,
/// never a client-side prediction; ADR-011).

final class CoupleDayAssignmentProvider
    extends
        $FunctionalProvider<
          AsyncValue<CoupleDayAssignment?>,
          CoupleDayAssignment?,
          Stream<CoupleDayAssignment?>
        >
    with
        $FutureModifier<CoupleDayAssignment?>,
        $StreamProvider<CoupleDayAssignment?> {
  /// Live `days/{dayKey}` assignment (null = no-day-yet: pre-first-rollover,
  /// deploy lag, or the ≤1h post-midnight window — an honest waiting state,
  /// never a client-side prediction; ADR-011).
  const CoupleDayAssignmentProvider._({
    required CoupleDayAssignmentFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: _noRetry,
         name: r'coupleDayAssignmentProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$coupleDayAssignmentHash();

  @override
  String toString() {
    return r'coupleDayAssignmentProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $StreamProviderElement<CoupleDayAssignment?> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<CoupleDayAssignment?> create(Ref ref) {
    final argument = this.argument as (String, String);
    return coupleDayAssignment(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is CoupleDayAssignmentProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$coupleDayAssignmentHash() =>
    r'798b155ce33f483bef718d72bae474cfd1e43396';

/// Live `days/{dayKey}` assignment (null = no-day-yet: pre-first-rollover,
/// deploy lag, or the ≤1h post-midnight window — an honest waiting state,
/// never a client-side prediction; ADR-011).

final class CoupleDayAssignmentFamily extends $Family
    with
        $FunctionalFamilyOverride<
          Stream<CoupleDayAssignment?>,
          (String, String)
        > {
  const CoupleDayAssignmentFamily._()
    : super(
        retry: _noRetry,
        name: r'coupleDayAssignmentProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Live `days/{dayKey}` assignment (null = no-day-yet: pre-first-rollover,
  /// deploy lag, or the ≤1h post-midnight window — an honest waiting state,
  /// never a client-side prediction; ADR-011).

  CoupleDayAssignmentProvider call(String coupleId, String dayKey) =>
      CoupleDayAssignmentProvider._(argument: (coupleId, dayKey), from: this);

  @override
  String toString() => r'coupleDayAssignmentProvider';
}

/// The bundled pack by the day doc's packId (generic by-id seam — the
/// paired bank is whatever the rollover assigned from, `solo_tr` until W9).

@ProviderFor(pairedQuestionPack)
const pairedQuestionPackProvider = PairedQuestionPackFamily._();

/// The bundled pack by the day doc's packId (generic by-id seam — the
/// paired bank is whatever the rollover assigned from, `solo_tr` until W9).

final class PairedQuestionPackProvider
    extends
        $FunctionalProvider<
          AsyncValue<QuestionPack>,
          QuestionPack,
          FutureOr<QuestionPack>
        >
    with $FutureModifier<QuestionPack>, $FutureProvider<QuestionPack> {
  /// The bundled pack by the day doc's packId (generic by-id seam — the
  /// paired bank is whatever the rollover assigned from, `solo_tr` until W9).
  const PairedQuestionPackProvider._({
    required PairedQuestionPackFamily super.from,
    required String super.argument,
  }) : super(
         retry: _noRetry,
         name: r'pairedQuestionPackProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$pairedQuestionPackHash();

  @override
  String toString() {
    return r'pairedQuestionPackProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<QuestionPack> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<QuestionPack> create(Ref ref) {
    final argument = this.argument as String;
    return pairedQuestionPack(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is PairedQuestionPackProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$pairedQuestionPackHash() =>
    r'f2d686ffbda3123cb0e26ecdbd4ee9537ba6bef1';

/// The bundled pack by the day doc's packId (generic by-id seam — the
/// paired bank is whatever the rollover assigned from, `solo_tr` until W9).

final class PairedQuestionPackFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<QuestionPack>, String> {
  const PairedQuestionPackFamily._()
    : super(
        retry: _noRetry,
        name: r'pairedQuestionPackProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The bundled pack by the day doc's packId (generic by-id seam — the
  /// paired bank is whatever the rollover assigned from, `solo_tr` until W9).

  PairedQuestionPackProvider call(String packId) =>
      PairedQuestionPackProvider._(argument: packId, from: this);

  @override
  String toString() => r'pairedQuestionPackProvider';
}

/// Live answer doc of one author (own uid or partner uid). For the partner
/// this is the reveal-gated read — attach it ONLY through
/// [partnerSlotProvider], which waits for the own answer's server ack.

@ProviderFor(coupleAnswer)
const coupleAnswerProvider = CoupleAnswerFamily._();

/// Live answer doc of one author (own uid or partner uid). For the partner
/// this is the reveal-gated read — attach it ONLY through
/// [partnerSlotProvider], which waits for the own answer's server ack.

final class CoupleAnswerProvider
    extends
        $FunctionalProvider<
          AsyncValue<CoupleAnswer?>,
          CoupleAnswer?,
          Stream<CoupleAnswer?>
        >
    with $FutureModifier<CoupleAnswer?>, $StreamProvider<CoupleAnswer?> {
  /// Live answer doc of one author (own uid or partner uid). For the partner
  /// this is the reveal-gated read — attach it ONLY through
  /// [partnerSlotProvider], which waits for the own answer's server ack.
  const CoupleAnswerProvider._({
    required CoupleAnswerFamily super.from,
    required (String, String, String) super.argument,
  }) : super(
         retry: _permissionBoundedRetry,
         name: r'coupleAnswerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$coupleAnswerHash();

  @override
  String toString() {
    return r'coupleAnswerProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $StreamProviderElement<CoupleAnswer?> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<CoupleAnswer?> create(Ref ref) {
    final argument = this.argument as (String, String, String);
    return coupleAnswer(ref, argument.$1, argument.$2, argument.$3);
  }

  @override
  bool operator ==(Object other) {
    return other is CoupleAnswerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$coupleAnswerHash() => r'bb3763ebdc2d659b1416657f367c57b071aac0bc';

/// Live answer doc of one author (own uid or partner uid). For the partner
/// this is the reveal-gated read — attach it ONLY through
/// [partnerSlotProvider], which waits for the own answer's server ack.

final class CoupleAnswerFamily extends $Family
    with
        $FunctionalFamilyOverride<
          Stream<CoupleAnswer?>,
          (String, String, String)
        > {
  const CoupleAnswerFamily._()
    : super(
        retry: _permissionBoundedRetry,
        name: r'coupleAnswerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Live answer doc of one author (own uid or partner uid). For the partner
  /// this is the reveal-gated read — attach it ONLY through
  /// [partnerSlotProvider], which waits for the own answer's server ack.

  CoupleAnswerProvider call(String coupleId, String dayKey, String authorUid) =>
      CoupleAnswerProvider._(
        argument: (coupleId, dayKey, authorUid),
        from: this,
      );

  @override
  String toString() => r'coupleAnswerProvider';
}

/// The client half of the reveal invariant (M3.3): never subscribes to the
/// partner's answer until the OWN answer is server-acked (`answeredAt !=
/// null` — the pending serverTimestamp of a local echo crosses as null, so
/// a non-null stamp is a commit ack). A permission denial on the partner
/// watch maps to Locked as defense-in-depth (plus the bounded retry above),
/// never to an error card.

@ProviderFor(partnerSlot)
const partnerSlotProvider = PartnerSlotFamily._();

/// The client half of the reveal invariant (M3.3): never subscribes to the
/// partner's answer until the OWN answer is server-acked (`answeredAt !=
/// null` — the pending serverTimestamp of a local echo crosses as null, so
/// a non-null stamp is a commit ack). A permission denial on the partner
/// watch maps to Locked as defense-in-depth (plus the bounded retry above),
/// never to an error card.

final class PartnerSlotProvider
    extends $FunctionalProvider<PartnerSlot, PartnerSlot, PartnerSlot>
    with $Provider<PartnerSlot> {
  /// The client half of the reveal invariant (M3.3): never subscribes to the
  /// partner's answer until the OWN answer is server-acked (`answeredAt !=
  /// null` — the pending serverTimestamp of a local echo crosses as null, so
  /// a non-null stamp is a commit ack). A permission denial on the partner
  /// watch maps to Locked as defense-in-depth (plus the bounded retry above),
  /// never to an error card.
  const PartnerSlotProvider._({
    required PartnerSlotFamily super.from,
    required ({
      String coupleId,
      String dayKey,
      String ownUid,
      String partnerUid,
    })
    super.argument,
  }) : super(
         retry: _noRetry,
         name: r'partnerSlotProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$partnerSlotHash();

  @override
  String toString() {
    return r'partnerSlotProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $ProviderElement<PartnerSlot> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PartnerSlot create(Ref ref) {
    final argument =
        this.argument
            as ({
              String coupleId,
              String dayKey,
              String ownUid,
              String partnerUid,
            });
    return partnerSlot(
      ref,
      coupleId: argument.coupleId,
      dayKey: argument.dayKey,
      ownUid: argument.ownUid,
      partnerUid: argument.partnerUid,
    );
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PartnerSlot value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PartnerSlot>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is PartnerSlotProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$partnerSlotHash() => r'c8d841f1fc5f3c0c60ff6cfbeb17148690e4bcca';

/// The client half of the reveal invariant (M3.3): never subscribes to the
/// partner's answer until the OWN answer is server-acked (`answeredAt !=
/// null` — the pending serverTimestamp of a local echo crosses as null, so
/// a non-null stamp is a commit ack). A permission denial on the partner
/// watch maps to Locked as defense-in-depth (plus the bounded retry above),
/// never to an error card.

final class PartnerSlotFamily extends $Family
    with
        $FunctionalFamilyOverride<
          PartnerSlot,
          ({String coupleId, String dayKey, String ownUid, String partnerUid})
        > {
  const PartnerSlotFamily._()
    : super(
        retry: _noRetry,
        name: r'partnerSlotProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The client half of the reveal invariant (M3.3): never subscribes to the
  /// partner's answer until the OWN answer is server-acked (`answeredAt !=
  /// null` — the pending serverTimestamp of a local echo crosses as null, so
  /// a non-null stamp is a commit ack). A permission denial on the partner
  /// watch maps to Locked as defense-in-depth (plus the bounded retry above),
  /// never to an error card.

  PartnerSlotProvider call({
    required String coupleId,
    required String dayKey,
    required String ownUid,
    required String partnerUid,
  }) => PartnerSlotProvider._(
    argument: (
      coupleId: coupleId,
      dayKey: dayKey,
      ownUid: ownUid,
      partnerUid: partnerUid,
    ),
    from: this,
  );

  @override
  String toString() => r'partnerSlotProvider';
}
