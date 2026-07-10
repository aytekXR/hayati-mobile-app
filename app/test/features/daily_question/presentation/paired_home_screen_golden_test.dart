import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/daily_question/data/asset_question_pack_repository.dart';
import 'package:hayati_app/features/daily_question/domain/couple.dart';
import 'package:hayati_app/features/daily_question/domain/couple_answer.dart';
import 'package:hayati_app/features/daily_question/domain/couple_answers_repository_provider.dart';
import 'package:hayati_app/features/daily_question/domain/couple_day.dart';
import 'package:hayati_app/features/daily_question/domain/couple_day_assignment.dart';
import 'package:hayati_app/features/daily_question/domain/couple_day_repository_provider.dart';
import 'package:hayati_app/features/daily_question/domain/couple_repository_provider.dart';
import 'package:hayati_app/features/daily_question/domain/question_pack_repository_provider.dart';
import 'package:hayati_app/features/daily_question/domain/solo_clock.dart';
import 'package:hayati_app/features/daily_question/presentation/paired_home_screen.dart';
// flutter_riverpod's curated export omits Override; riverpod_annotation
// exposes it — same seam the other golden tests use.
import 'package:riverpod_annotation/riverpod_annotation.dart' show Override;

import '../../../support/fake_couple_answers_repository.dart';
import '../../../support/fake_couple_day_repository.dart';
import '../../../support/fake_couple_repository.dart';
import '../../../support/golden/golden_harness.dart';
import '../../../support/static_asset_bundle.dart';

const _coupleId = 'couple-1';
const _ownUid = 'uid-1';
const _partnerUid = 'uid-2';

/// The couple's stored IANA zone keys the day (ADR-011 — NEVER the device
/// zone). Istanbul is UTC+3, so [_now] falls on 2026-07-10 local → dayKey
/// `20260710` (asserted by couple_day_key_test.dart's parity fixture).
const _timezone = 'Europe/Istanbul';

/// Pinned wall clock so the couple's local dayKey is deterministic.
final _now = DateTime.utc(2026, 7, 10, 9);

/// The dayKey the screen resolves per build — the real [coupleDayKey] over
/// the stored zone, not a hard-coded literal, so a mirror/tzdata regression
/// re-keys the seeds instead of hiding behind a stale constant.
final _dayKey = coupleDayKey(_now, _timezone);

const _couple = Couple(
  id: _coupleId,
  memberUids: [_ownUid, _partnerUid],
  timezone: _timezone,
);

/// The couple bank is `solo_tr` until W9 (ADR-011 placeholder), so the day
/// doc assigns from it — every cell renders the REAL shipped `solo_tr`
/// question regardless of the profile locale (the locale only drives the UI
/// chrome + direction). Rendering the actual asset means an accidental
/// content edit surfaces as an intentional-golden-change question (W4 flag),
/// not silent drift — same discipline as the solo goldens.
const _assignment = CoupleDayAssignment(
  questionId: 'solo_tr_001',
  packId: 'solo_tr',
  packVersion: 1,
);

/// Short, deliberately mundane saved answers for the answered/revealed
/// states. Turkish on purpose: the placeholder couple bank is `solo_tr`, so
/// the shipped question is Turkish and matching-language answers read true.
const _ownAnswerText = 'Kahvaltıda birlikte gülmemiz.';
const _partnerAnswerText = 'Sabah çayını birlikte içmemiz.';

void main() {
  final shippedPacks = shippedSoloPackBundle();

  /// Seeds the paired read chain: couple always present; the day assignment,
  /// own answer, and partner answer are opted in per state. Answers carry a
  /// non-null [FakeCoupleAnswersRepository.answeredAtStamp] — the server ack
  /// that opens the partner-slot gate exactly as a committed write would.
  List<Override> arrange({
    bool seedDay = false,
    CoupleAnswer? ownAnswer,
    CoupleAnswer? partnerAnswer,
  }) {
    final couples = FakeCoupleRepository(initialCouples: {_coupleId: _couple});
    final days = FakeCoupleDayRepository(
      initialDays: seedDay
          ? {FakeCoupleDayRepository.keyFor(_coupleId, _dayKey): _assignment}
          : null,
    );
    final answers = FakeCoupleAnswersRepository(
      initialAnswers: {
        // Null-aware entries: an unseeded author drops out, leaving its
        // answer doc genuinely absent (the locked/waiting inputs).
        FakeCoupleAnswersRepository.keyFor(_coupleId, _dayKey, _ownUid):
            ?ownAnswer,
        FakeCoupleAnswersRepository.keyFor(_coupleId, _dayKey, _partnerUid):
            ?partnerAnswer,
      },
    );
    addTearDown(couples.dispose);
    addTearDown(days.dispose);
    addTearDown(answers.dispose);
    return [
      coupleRepositoryProvider.overrideWith((ref) => couples),
      coupleDayRepositoryProvider.overrideWith((ref) => days),
      coupleAnswersRepositoryProvider.overrideWith((ref) => answers),
      // Real by-id pack over the shipped bundle (fake-async-safe): the
      // generic seam mirrors the solo golden's asset wiring.
      questionPackRepositoryProvider.overrideWith(
        (ref) => AssetQuestionPackRepository(bundle: shippedPacks),
      ),
      soloClockProvider.overrideWith(
        (ref) =>
            () => _now,
      ),
    ];
  }

  CoupleAnswer answerOf(String text) => CoupleAnswer(
    questionId: _assignment.questionId,
    text: text,
    answeredAt: FakeCoupleAnswersRepository.answeredAtStamp,
  );

  // No day doc yet: the rollover has not landed today's assignment (honest
  // waiting state, never a client-side prediction; ADR-011).
  for (final cell in sixCells) {
    testWidgets('no_day_yet ${cell.suffix}', (tester) async {
      final overrides = arrange();

      await pumpGolden(
        tester,
        const PairedHomeScreen(uid: _ownUid, coupleId: _coupleId),
        locale: cell.locale,
        direction: cell.direction,
        overrides: overrides,
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(PairedHomeScreen),
        matchesGoldenFile(
          goldenFile('paired_home_screen', 'no_day_yet', cell.suffix),
        ),
      );
    });
  }

  // Day + pack resolved, own answer absent: empty entry, partner slot locked
  // (the partner watch is never attached before the own answer is acked).
  for (final cell in sixCells) {
    testWidgets('locked ${cell.suffix}', (tester) async {
      final overrides = arrange(seedDay: true);

      await pumpGolden(
        tester,
        const PairedHomeScreen(uid: _ownUid, coupleId: _coupleId),
        locale: cell.locale,
        direction: cell.direction,
        overrides: overrides,
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(PairedHomeScreen),
        matchesGoldenFile(
          goldenFile('paired_home_screen', 'locked', cell.suffix),
        ),
      );
    });
  }

  // Own answer acked, partner absent: entry seeded + saved caption, partner
  // slot waiting.
  for (final cell in sixCells) {
    testWidgets('waiting ${cell.suffix}', (tester) async {
      final overrides = arrange(
        seedDay: true,
        ownAnswer: answerOf(_ownAnswerText),
      );

      await pumpGolden(
        tester,
        const PairedHomeScreen(uid: _ownUid, coupleId: _coupleId),
        locale: cell.locale,
        direction: cell.direction,
        overrides: overrides,
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(PairedHomeScreen),
        matchesGoldenFile(
          goldenFile('paired_home_screen', 'waiting', cell.suffix),
        ),
      );
    });
  }

  // Both answered: the reveal. Entry collapses to the read-only own card
  // (rules freeze both docs), partner slot shows the partner's answer.
  for (final cell in sixCells) {
    testWidgets('revealed ${cell.suffix}', (tester) async {
      final overrides = arrange(
        seedDay: true,
        ownAnswer: answerOf(_ownAnswerText),
        partnerAnswer: answerOf(_partnerAnswerText),
      );

      await pumpGolden(
        tester,
        const PairedHomeScreen(uid: _ownUid, coupleId: _coupleId),
        locale: cell.locale,
        direction: cell.direction,
        overrides: overrides,
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(PairedHomeScreen),
        matchesGoldenFile(
          goldenFile('paired_home_screen', 'revealed', cell.suffix),
        ),
      );
    });
  }

  // Dynamic-type probe on the busiest interactive state (entry + slot),
  // natural directions only (same convention as solo's scale130 naturals).
  for (final cell in naturalCells) {
    testWidgets('locked scale130 ${cell.suffix}', (tester) async {
      final overrides = arrange(seedDay: true);

      await pumpGolden(
        tester,
        const PairedHomeScreen(uid: _ownUid, coupleId: _coupleId),
        locale: cell.locale,
        direction: cell.direction,
        overrides: overrides,
        textScale: 1.3,
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(PairedHomeScreen),
        matchesGoldenFile(
          goldenFile('paired_home_screen', 'locked_scale130', cell.suffix),
        ),
      );
    });
  }
}
