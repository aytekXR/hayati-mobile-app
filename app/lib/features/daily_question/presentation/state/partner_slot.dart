import '../../domain/couple_answer.dart';
import '../../domain/couple_data_exception.dart';

/// The partner half of the mutual-reveal card, as a sealed state so the
/// attach-gate logic lives in ONE provider (`partnerSlotProvider`) and is
/// unit-testable against the fakes — the client mirror of the server-side
/// reveal invariant (M3.3, docs/architecture.md §3).
sealed class PartnerSlot {
  const PartnerSlot();
}

/// Own answer absent or not yet server-acked: the partner watch is never
/// attached (a listen before the own answer commits would be denied and the
/// SDK never retries a denied listen), and rules would deny it anyway.
final class PartnerSlotLocked extends PartnerSlot {
  const PartnerSlotLocked();
}

/// Own answer server-acked, partner answer not there yet (fresh watch still
/// loading maps here too — a spinner mid-card would just flash).
final class PartnerSlotWaiting extends PartnerSlot {
  const PartnerSlotWaiting();
}

/// Both answered: the reveal state.
final class PartnerSlotRevealed extends PartnerSlot {
  const PartnerSlotRevealed(this.answer);

  final CoupleAnswer answer;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PartnerSlotRevealed && other.answer == answer;

  @override
  int get hashCode => Object.hash(runtimeType, answer);
}

/// The partner watch failed for a non-permission reason (permission maps to
/// [PartnerSlotLocked] — for this doc a denial means "still locked").
final class PartnerSlotFailure extends PartnerSlot {
  const PartnerSlotFailure(this.failure);

  final CoupleDataException failure;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PartnerSlotFailure && other.failure == failure;

  @override
  int get hashCode => Object.hash(runtimeType, failure);
}
