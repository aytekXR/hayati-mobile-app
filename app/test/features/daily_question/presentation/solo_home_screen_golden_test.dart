import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/auth/domain/auth_repository_provider.dart';
import 'package:hayati_app/features/auth/domain/auth_user.dart';
import 'package:hayati_app/features/daily_question/data/asset_solo_question_pack_repository.dart';
import 'package:hayati_app/features/daily_question/domain/solo_answer.dart';
import 'package:hayati_app/features/daily_question/domain/solo_answers_repository_provider.dart';
import 'package:hayati_app/features/daily_question/domain/solo_clock.dart';
import 'package:hayati_app/features/daily_question/domain/solo_day.dart';
import 'package:hayati_app/features/daily_question/domain/solo_question.dart';
import 'package:hayati_app/features/daily_question/domain/solo_question_pack_repository_provider.dart';
import 'package:hayati_app/features/daily_question/presentation/solo_home_screen.dart';
import 'package:hayati_app/features/pairing/domain/invite_repository_provider.dart';
import 'package:hayati_app/features/pairing/domain/invite_share_launcher.dart';
import 'package:hayati_app/features/profile/domain/profile_repository_provider.dart';
import 'package:hayati_app/features/profile/domain/relationship_profile.dart';
// flutter_riverpod's curated export omits Override; riverpod_annotation
// exposes it — same seam the other golden tests use.
import 'package:riverpod_annotation/riverpod_annotation.dart' show Override;

import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_invite_repository.dart';
import '../../../support/fake_invite_share_launcher.dart';
import '../../../support/fake_profile_repository.dart';
import '../../../support/fake_solo_answers_repository.dart';
import '../../../support/fake_solo_question_pack_repository.dart';
import '../../../support/golden/golden_harness.dart';
import '../../../support/static_asset_bundle.dart';

const _user = AuthUser(uid: 'uid-1', displayName: 'Aytek');

/// Pinned wall clock so day-N and the yyyymmdd bucket are deterministic.
final _now = DateTime(2026, 7, 10, 12);

/// The content states render the REAL bundled packs (assets/content/, served
/// through the fake-async-safe [shippedSoloPackBundle]): the goldens capture
/// the actual product surface — including Arabic shaping of the shipped
/// questions — and an accidental content edit shows up as an
/// intentional-golden-change question (W4 flag), not a silent drift.
RelationshipProfile _profileFor(GoldenCell cell, {required int day}) =>
    RelationshipProfile(
      status: RelationshipStatus.married,
      contentLanguage: ContentLanguage.values.byName(cell.locale.languageCode),
      register: ContentRegister.respectful,
      // Anchor day-1 on _now's date, day-N N-1 days earlier (July 2026 keeps
      // the arithmetic inside one month).
      createdAt: DateTime(2026, 7, 11 - day),
    );

/// A short, deliberately mundane saved answer per language for the answered
/// state, matching the day-3 question id of the shipped pack.
const _answerTexts = {
  'en': 'A quiet morning together.',
  'tr': 'Birlikte sakin bir sabah.',
  'ar': 'صباح هادئ معًا.',
};

void main() {
  final shippedPacks = shippedSoloPackBundle();

  ({List<Override> overrides, FakeSoloQuestionPackRepository packs}) arrange(
    GoldenCell cell, {
    SoloAnswer? todayAnswer,
    bool fixturePacks = false,
  }) {
    final packs = FakeSoloQuestionPackRepository();
    final answers = FakeSoloAnswersRepository(
      initialAnswers: todayAnswer == null
          ? null
          : {
              FakeSoloAnswersRepository.keyFor(_user.uid, soloDayKey(_now)):
                  todayAnswer,
            },
    );
    final profiles = FakeProfileRepository();
    final auth = FakeAuthRepository(initialUser: _user);
    final invites = FakeInviteRepository();
    final launcher = FakeInviteShareLauncher();
    addTearDown(answers.dispose);
    addTearDown(profiles.dispose);
    addTearDown(auth.dispose);
    addTearDown(invites.dispose);
    addTearDown(launcher.dispose);
    return (
      overrides: [
        soloQuestionPackRepositoryProvider.overrideWith(
          (ref) => fixturePacks
              ? packs
              : AssetSoloQuestionPackRepository(bundle: shippedPacks),
        ),
        soloAnswersRepositoryProvider.overrideWith((ref) => answers),
        soloClockProvider.overrideWith(
          (ref) =>
              () => _now,
        ),
        profileRepositoryProvider.overrideWith((ref) => profiles),
        authRepositoryProvider.overrideWith((ref) => auth),
        inviteRepositoryProvider.overrideWith((ref) => invites),
        inviteShareLauncherProvider.overrideWith((ref) => launcher),
      ],
      packs: packs,
    );
  }

  for (final cell in sixCells) {
    testWidgets('day1 unanswered ${cell.suffix}', (tester) async {
      final fakes = arrange(cell);

      await pumpGolden(
        tester,
        SoloHomeScreen(uid: _user.uid, profile: _profileFor(cell, day: 1)),
        locale: cell.locale,
        direction: cell.direction,
        overrides: fakes.overrides,
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(SoloHomeScreen),
        matchesGoldenFile(
          goldenFile('solo_home_screen', 'day1_unanswered', cell.suffix),
        ),
      );
    });
  }

  for (final cell in sixCells) {
    testWidgets('day3 answered ${cell.suffix}', (tester) async {
      final fakes = arrange(
        cell,
        todayAnswer: SoloAnswer(
          questionId: 'solo_${cell.locale.languageCode}_003',
          text: _answerTexts[cell.locale.languageCode]!,
          answeredAt: FakeSoloAnswersRepository.answeredAtStamp,
        ),
      );

      await pumpGolden(
        tester,
        SoloHomeScreen(uid: _user.uid, profile: _profileFor(cell, day: 3)),
        locale: cell.locale,
        direction: cell.direction,
        overrides: fakes.overrides,
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(SoloHomeScreen),
        matchesGoldenFile(
          goldenFile('solo_home_screen', 'day3_answered', cell.suffix),
        ),
      );
    });
  }

  for (final cell in sixCells) {
    testWidgets('completed ${cell.suffix}', (tester) async {
      final fakes = arrange(cell);

      await pumpGolden(
        tester,
        SoloHomeScreen(uid: _user.uid, profile: _profileFor(cell, day: 8)),
        locale: cell.locale,
        direction: cell.direction,
        overrides: fakes.overrides,
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(SoloHomeScreen),
        matchesGoldenFile(
          goldenFile('solo_home_screen', 'completed', cell.suffix),
        ),
      );
    });
  }

  for (final cell in sixCells) {
    testWidgets('loading ${cell.suffix}', (tester) async {
      // Never-completing pack load → the screen holds its loading state.
      // A single zero-duration pump captures the spinner at t=0
      // (deterministic), never pumpAndSettle (it would hang).
      final fakes = arrange(cell, fixturePacks: true);
      fakes.packs.onLoadPack = (language) =>
          Completer<SoloQuestionPack>().future;

      await pumpGolden(
        tester,
        SoloHomeScreen(uid: _user.uid, profile: _profileFor(cell, day: 1)),
        locale: cell.locale,
        direction: cell.direction,
        overrides: fakes.overrides,
      );
      await tester.pump();

      await expectLater(
        find.byType(SoloHomeScreen),
        matchesGoldenFile(
          goldenFile('solo_home_screen', 'loading', cell.suffix),
        ),
      );
    });
  }

  for (final cell in sixCells) {
    testWidgets('error ${cell.suffix}', (tester) async {
      final fakes = arrange(cell, fixturePacks: true);
      fakes.packs.onLoadPack = (language) async {
        throw const FormatException('broken asset');
      };

      await pumpGolden(
        tester,
        SoloHomeScreen(uid: _user.uid, profile: _profileFor(cell, day: 1)),
        locale: cell.locale,
        direction: cell.direction,
        overrides: fakes.overrides,
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(SoloHomeScreen),
        matchesGoldenFile(goldenFile('solo_home_screen', 'error', cell.suffix)),
      );
    });
  }

  // Dynamic-type probe on the busiest state, natural directions only (same
  // convention as profile_capture's fresh_scale130).
  for (final cell in naturalCells) {
    testWidgets('day1 unanswered scale130 ${cell.suffix}', (tester) async {
      final fakes = arrange(cell);

      await pumpGolden(
        tester,
        SoloHomeScreen(uid: _user.uid, profile: _profileFor(cell, day: 1)),
        locale: cell.locale,
        direction: cell.direction,
        overrides: fakes.overrides,
        textScale: 1.3,
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(SoloHomeScreen),
        matchesGoldenFile(
          goldenFile(
            'solo_home_screen',
            'day1_unanswered_scale130',
            cell.suffix,
          ),
        ),
      );
    });
  }
}
