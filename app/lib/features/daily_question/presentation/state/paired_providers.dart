import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/couple.dart';
import '../../domain/couple_answer.dart';
import '../../domain/couple_answers_repository_provider.dart';
import '../../domain/couple_data_exception.dart';
import '../../domain/couple_day_assignment.dart';
import '../../domain/couple_day_repository_provider.dart';
import '../../domain/couple_repository_provider.dart';
import '../../domain/question.dart';
import '../../domain/question_pack_repository_provider.dart';
import 'partner_slot.dart';

part 'paired_providers.g.dart';

/// Riverpod 3 auto-retry disabled (same rationale as `solo_providers.dart`):
/// an error here is corrupt server state, a malformed bundle, or a rules
/// denial — backoff-hammering just pins the screen on a spinner. Recovery is
/// the user-driven `ref.invalidate` on the error view.
Duration? _noRetry(int retryCount, Object error) => null;

/// The answer watches get ONE narrow exception: a bounded permission-only
/// retry. The partner listen is gated on the own answer's server ack, so a
/// denial "should" be unreachable — but a lost exists()-race (e.g. rules
/// evaluated against a replica that hasn't seen the own-answer commit)
/// would otherwise latch a dead stream into a forever-locked card, because
/// the SDK never retries a denied listen. Three quick re-subscribes
/// self-heal that; everything else keeps the `_noRetry` philosophy.
Duration? _permissionBoundedRetry(int retryCount, Object error) {
  if (error is CoupleDataPermissionException && retryCount < 3) {
    return Duration(seconds: 1 << retryCount);
  }
  return null;
}

/// Live `couples/{coupleId}` doc (M3.3 — the app's first couple read; the
/// doc carries the timezone that keys the day). Null = corrupt state
/// (`users.coupleId` pointing at nothing) — the screen's error view owns it.
@Riverpod(retry: _noRetry)
Stream<Couple?> couple(Ref ref, String coupleId) =>
    ref.watch(coupleRepositoryProvider).watchCouple(coupleId);

/// Live `days/{dayKey}` assignment (null = no-day-yet: pre-first-rollover,
/// deploy lag, or the ≤1h post-midnight window — an honest waiting state,
/// never a client-side prediction; ADR-011).
@Riverpod(retry: _noRetry)
Stream<CoupleDayAssignment?> coupleDayAssignment(
  Ref ref,
  String coupleId,
  String dayKey,
) => ref.watch(coupleDayRepositoryProvider).watchDay(coupleId, dayKey);

/// The bundled pack by the day doc's packId (generic by-id seam — the
/// paired bank is whatever the rollover assigned from, `solo_tr` until W9).
@Riverpod(retry: _noRetry)
Future<QuestionPack> pairedQuestionPack(Ref ref, String packId) =>
    ref.watch(questionPackRepositoryProvider).loadPack(packId);

/// Live answer doc of one author (own uid or partner uid). For the partner
/// this is the reveal-gated read — attach it ONLY through
/// [partnerSlotProvider], which waits for the own answer's server ack.
@Riverpod(retry: _permissionBoundedRetry)
Stream<CoupleAnswer?> coupleAnswer(
  Ref ref,
  String coupleId,
  String dayKey,
  String authorUid,
) => ref
    .watch(coupleAnswersRepositoryProvider)
    .watchAnswer(coupleId, dayKey, authorUid);

/// The client half of the reveal invariant (M3.3): never subscribes to the
/// partner's answer until the OWN answer is server-acked (`answeredAt !=
/// null` — the pending serverTimestamp of a local echo crosses as null, so
/// a non-null stamp is a commit ack). A permission denial on the partner
/// watch maps to Locked as defense-in-depth (plus the bounded retry above),
/// never to an error card.
@Riverpod(retry: _noRetry)
PartnerSlot partnerSlot(
  Ref ref, {
  required String coupleId,
  required String dayKey,
  required String ownUid,
  required String partnerUid,
}) {
  final own = ref.watch(coupleAnswerProvider(coupleId, dayKey, ownUid));
  // .value is null while loading/errored (fine: both map to Locked) — and
  // also when the answer doc is legitimately absent.
  final ownAnswer = own.value;
  if (ownAnswer == null || ownAnswer.answeredAt == null) {
    return const PartnerSlotLocked();
  }
  final partner = ref.watch(coupleAnswerProvider(coupleId, dayKey, partnerUid));
  if (partner.hasError) {
    final error = partner.error;
    if (error is CoupleDataPermissionException) {
      return const PartnerSlotLocked();
    }
    return PartnerSlotFailure(
      error is CoupleDataException
          ? error
          : CoupleDataUnknownException(code: 'unexpected', message: '$error'),
    );
  }
  final answer = partner.value;
  if (answer == null) return const PartnerSlotWaiting();
  return PartnerSlotRevealed(answer);
}
