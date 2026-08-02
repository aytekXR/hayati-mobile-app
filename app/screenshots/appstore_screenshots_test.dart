// App Store screenshot generator. NOT a test, despite the `_test.dart` name and
// the `testWidgets` bodies — it asserts nothing and it WRITES FILES.
//
// WHY IT LIVES OUTSIDE `test/`. `flutter test` with no path runs `test/` and
// only `test/`, so this never enters the merge gate, never enters the coverage
// number, and never fails a PR. It is driven explicitly:
//
//     tool/appstore_screenshots.sh
//
// WHY IT REUSES THE GOLDEN FAKES INSTEAD OF ITS OWN. Every state below is
// arranged the same way its golden test arranges it, from the same fakes and
// the same shipped question packs. A screenshot built from a bespoke mock is a
// picture of something no test has ever checked; drift between the store
// listing and the product would then be invisible in both directions. What is
// deliberately NOT shared is the *selection*: the goldens capture every state
// including `error` and `loading`, and this file curates the six that tell the
// product's story.
//
// The surface comes from APPSTORE_SCREENSHOT_SURFACE (see golden_harness.dart),
// so these render at 1290×2796 @3 — App Store Connect's 6.9" iPhone slot — from
// the identical widget tree the 390×844 goldens pin.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/core/storage/local_flag_store.dart';
import 'package:hayati_app/core/storage/pin_lock_store.dart';
import 'package:hayati_app/features/auth/domain/auth_repository_provider.dart';
import 'package:hayati_app/features/auth/domain/auth_user.dart';
import 'package:hayati_app/features/auth/presentation/ritual_preview_screen.dart';
import 'package:hayati_app/features/coach/domain/coach_disclaimer.dart';
import 'package:hayati_app/features/coach/domain/coach_reply.dart';
import 'package:hayati_app/features/coach/domain/coach_repository_provider.dart';
import 'package:hayati_app/features/coach/presentation/coach_screen.dart';
import 'package:hayati_app/features/daily_question/data/asset_question_pack_repository.dart';
import 'package:hayati_app/features/daily_question/data/asset_solo_question_pack_repository.dart';
import 'package:hayati_app/features/daily_question/domain/couple.dart';
import 'package:hayati_app/features/daily_question/domain/couple_answer.dart';
import 'package:hayati_app/features/daily_question/domain/couple_answers_repository_provider.dart';
import 'package:hayati_app/features/daily_question/domain/couple_day.dart';
import 'package:hayati_app/features/daily_question/domain/couple_day_assignment.dart';
import 'package:hayati_app/features/daily_question/domain/couple_day_repository_provider.dart';
import 'package:hayati_app/features/daily_question/domain/couple_repository_provider.dart';
import 'package:hayati_app/features/daily_question/domain/question_pack_repository_provider.dart';
import 'package:hayati_app/features/daily_question/domain/solo_answer.dart';
import 'package:hayati_app/features/daily_question/domain/solo_answers_repository_provider.dart';
import 'package:hayati_app/features/daily_question/domain/solo_clock.dart';
import 'package:hayati_app/features/daily_question/domain/solo_day.dart';
import 'package:hayati_app/features/daily_question/domain/solo_question_pack_repository_provider.dart';
import 'package:hayati_app/features/daily_question/presentation/paired_home_screen.dart';
import 'package:hayati_app/features/daily_question/presentation/solo_home_screen.dart';
import 'package:hayati_app/features/entitlements/domain/couple_entitlement.dart';
import 'package:hayati_app/features/entitlements/domain/entitlement_repository_provider.dart';
import 'package:hayati_app/features/entitlements/domain/purchases_repository_provider.dart';
import 'package:hayati_app/features/pairing/domain/invite_repository_provider.dart';
import 'package:hayati_app/features/pairing/domain/invite_share_launcher.dart';
import 'package:hayati_app/features/privacy_lock/domain/biometric_authenticator.dart';
import 'package:hayati_app/features/privacy_lock/presentation/lock_screen.dart';
import 'package:hayati_app/features/profile/domain/profile_repository_provider.dart';
import 'package:hayati_app/features/profile/domain/relationship_profile.dart';
import 'package:hayati_app/features/settings/presentation/widgets/privacy_spotlight_card.dart';

import '../test/support/fake_auth_repository.dart';
import '../test/support/fake_biometric_authenticator.dart';
import '../test/support/fake_coach_repository.dart';
import '../test/support/fake_couple_answers_repository.dart';
import '../test/support/fake_couple_day_repository.dart';
import '../test/support/fake_couple_repository.dart';
import '../test/support/fake_entitlement_repository.dart';
import '../test/support/fake_invite_repository.dart';
import '../test/support/fake_invite_share_launcher.dart';
import '../test/support/fake_local_flag_store.dart';
import '../test/support/fake_pin_lock_store.dart';
import '../test/support/fake_profile_repository.dart';
import '../test/support/fake_purchases_repository.dart';
import '../test/support/fake_solo_answers_repository.dart';
import '../test/support/golden/golden_harness.dart';
import '../test/support/localized_app.dart';
import '../test/support/pin_lock_fixtures.dart';
import '../test/support/static_asset_bundle.dart';

/// The store listing's locales — `fastlane/metadata/` carries exactly `en-US`
/// and `tr`. Arabic is a SHIPPED app locale with full goldens but has no
/// listing, so rendering it here would produce files with nowhere to go.
const _locales = <String, Locale>{'tr': Locale('tr'), 'en': Locale('en')};

const _coupleId = 'couple-1';
const _ownUid = 'uid-1';
const _partnerUid = 'uid-2';
const _user = AuthUser(uid: _ownUid, displayName: 'Aytek');
const _timezone = 'Europe/Istanbul';

/// Pinned clocks, copied from the golden tests they mirror — the paired chain
/// keys its day in the couple's stored zone (ADR-011), the solo chain in UTC.
final _pairedNow = DateTime.utc(2026, 7, 10, 9);
final _soloNow = DateTime(2026, 7, 10, 12);
final _dayKey = coupleDayKey(_pairedNow, _timezone);

const _couple = Couple(
  id: _coupleId,
  memberUids: [_ownUid, _partnerUid],
  timezone: _timezone,
  streak: CoupleStreak(count: 4, lastMutualDate: '20260709', graceTokens: 1),
);

const _assignment = CoupleDayAssignment(
  questionId: 'solo_tr_001',
  packId: 'solo_tr',
  packVersion: 1,
);

/// The couple bank is `solo_tr` until W9, so the rendered question is Turkish
/// in every locale — the same thing the paired goldens capture, and the same
/// thing a real user on this build sees. Answers are Turkish to match.
const _ownAnswerText = 'Kahvaltıda birlikte gülmemiz.';
const _partnerAnswerText = 'Sabah çayını birlikte içmemiz.';

const _soloAnswers = {
  'tr': 'Birlikte sakin bir sabah.',
  'en': 'A quiet morning together.',
};

/// THREE coach turns, not one. The transcript is bottom-anchored like any
/// chat, so a single exchange renders two bubbles under two thirds of empty
/// canvas at 6.9" — technically correct, useless as a store asset. Three fills
/// the frame with what the surface actually looks like in use.
///
/// Deliberately ordinary planning talk: the coach's crisis path is a safety
/// gate (ADR-028), not a marketing surface, and it is not shown here.
const _coachTurns = <String, List<(String, String)>>{
  'tr': [
    (
      'Bu hafta sonu için güzel bir buluşma fikri var mı?',
      'Birlikte küçük bir plan yapalım: bir yürüyüş ve sevdiğiniz bir kahve.',
    ),
    (
      'Yürüyüşü nerede yapalım?',
      'Kalabalık olmayan bir sahil ya da park iyi olur — konuşmak kolaylaşır.',
    ),
    (
      'Sonrasında ne yapabiliriz?',
      'Eve dönünce bugünün sorusunu birlikte cevaplayın; gün böyle kapanır.',
    ),
  ],
  'en': [
    (
      'Any nice date idea for this weekend?',
      "Let's make a small plan together: a short walk and a coffee you both love.",
    ),
    (
      'Where should we walk?',
      'A quiet shoreline or park works well — it makes talking easier.',
    ),
    (
      'And after that?',
      "Back home, answer today's question together. That closes the day well.",
    ),
  ],
};

void main() {
  final shippedSolo = shippedSoloPackBundle();
  final shippedCouple = shippedSoloPackBundle();

  /// Where the PNGs land. `build/` is already git-ignored by the Flutter
  /// scaffold, so a generated store asset can never be committed by accident —
  /// the deliverable is a folder the founder uploads, not repo content.
  String out(String locale, String name) =>
      'build/appstore/screenshots/$locale/$name.png';

  // ---- 1. The reveal: today's question with both answers, streak running ----
  _locales.forEach((tag, locale) {
    testWidgets('01 reveal $tag', (tester) async {
      final couples = FakeCoupleRepository(
        initialCouples: {_coupleId: _couple},
      );
      final days = FakeCoupleDayRepository(
        initialDays: {
          FakeCoupleDayRepository.keyFor(_coupleId, _dayKey): _assignment,
        },
      );
      CoupleAnswer answerOf(String text) => CoupleAnswer(
        questionId: _assignment.questionId,
        text: text,
        answeredAt: FakeCoupleAnswersRepository.answeredAtStamp,
      );
      final answers = FakeCoupleAnswersRepository(
        initialAnswers: {
          FakeCoupleAnswersRepository.keyFor(_coupleId, _dayKey, _ownUid):
              answerOf(_ownAnswerText),
          FakeCoupleAnswersRepository.keyFor(_coupleId, _dayKey, _partnerUid):
              answerOf(_partnerAnswerText),
        },
      );
      final mirrors = FakeEntitlementRepository();
      addTearDown(couples.dispose);
      addTearDown(days.dispose);
      addTearDown(answers.dispose);
      addTearDown(mirrors.dispose);

      await pumpGolden(
        tester,
        const PairedHomeScreen(uid: _ownUid, coupleId: _coupleId),
        locale: locale,
        direction: TextDirection.ltr,
        overrides: [
          coupleRepositoryProvider.overrideWith((ref) => couples),
          coupleDayRepositoryProvider.overrideWith((ref) => days),
          coupleAnswersRepositoryProvider.overrideWith((ref) => answers),
          entitlementRepositoryProvider.overrideWith((ref) => mirrors),
          questionPackRepositoryProvider.overrideWith(
            (ref) => AssetQuestionPackRepository(bundle: shippedCouple),
          ),
          soloClockProvider.overrideWith(
            (ref) =>
                () => _pairedNow,
          ),
        ],
      );
      await tester.pumpAndSettle();

      await writeSurfacePng(tester, out(tag, '01-reveal'));
    });
  });

  // ---- 2. Before the reveal: your answer written, partner's still sealed ----
  _locales.forEach((tag, locale) {
    testWidgets('02 waiting $tag', (tester) async {
      final couples = FakeCoupleRepository(
        initialCouples: {_coupleId: _couple},
      );
      final days = FakeCoupleDayRepository(
        initialDays: {
          FakeCoupleDayRepository.keyFor(_coupleId, _dayKey): _assignment,
        },
      );
      final answers = FakeCoupleAnswersRepository(
        initialAnswers: {
          FakeCoupleAnswersRepository.keyFor(
            _coupleId,
            _dayKey,
            _ownUid,
          ): CoupleAnswer(
            questionId: _assignment.questionId,
            text: _ownAnswerText,
            answeredAt: FakeCoupleAnswersRepository.answeredAtStamp,
          ),
        },
      );
      final mirrors = FakeEntitlementRepository();
      addTearDown(couples.dispose);
      addTearDown(days.dispose);
      addTearDown(answers.dispose);
      addTearDown(mirrors.dispose);

      await pumpGolden(
        tester,
        const PairedHomeScreen(uid: _ownUid, coupleId: _coupleId),
        locale: locale,
        direction: TextDirection.ltr,
        overrides: [
          coupleRepositoryProvider.overrideWith((ref) => couples),
          coupleDayRepositoryProvider.overrideWith((ref) => days),
          coupleAnswersRepositoryProvider.overrideWith((ref) => answers),
          entitlementRepositoryProvider.overrideWith((ref) => mirrors),
          questionPackRepositoryProvider.overrideWith(
            (ref) => AssetQuestionPackRepository(bundle: shippedCouple),
          ),
          soloClockProvider.overrideWith(
            (ref) =>
                () => _pairedNow,
          ),
        ],
      );
      await tester.pumpAndSettle();

      await writeSurfacePng(tester, out(tag, '02-waiting'));
    });
  });

  // ---- 3. The promise, as onboarding states it ----
  _locales.forEach((tag, locale) {
    testWidgets('03 ritual $tag', (tester) async {
      await pumpGolden(
        tester,
        const RitualPreviewScreen(),
        locale: locale,
        direction: TextDirection.ltr,
      );
      await tester.pumpAndSettle();

      await writeSurfacePng(tester, out(tag, '03-ritual'));
    });
  });

  // ---- 4. It works before your partner joins ----
  _locales.forEach((tag, locale) {
    testWidgets('04 solo $tag', (tester) async {
      final answers = FakeSoloAnswersRepository(
        initialAnswers: {
          FakeSoloAnswersRepository.keyFor(
            _ownUid,
            soloDayKey(_soloNow),
          ): SoloAnswer(
            questionId: 'solo_${locale.languageCode}_003',
            text: _soloAnswers[tag]!,
            answeredAt: FakeSoloAnswersRepository.answeredAtStamp,
          ),
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

      await pumpGolden(
        tester,
        SoloHomeScreen(
          uid: _ownUid,
          profile: RelationshipProfile(
            status: RelationshipStatus.married,
            contentLanguage: ContentLanguage.values.byName(locale.languageCode),
            register: ContentRegister.respectful,
            createdAt: DateTime(2026, 7, 8),
          ),
        ),
        locale: locale,
        direction: TextDirection.ltr,
        overrides: [
          soloQuestionPackRepositoryProvider.overrideWith(
            (ref) => AssetSoloQuestionPackRepository(bundle: shippedSolo),
          ),
          soloAnswersRepositoryProvider.overrideWith((ref) => answers),
          soloClockProvider.overrideWith(
            (ref) =>
                () => _soloNow,
          ),
          profileRepositoryProvider.overrideWith((ref) => profiles),
          authRepositoryProvider.overrideWith((ref) => auth),
          inviteRepositoryProvider.overrideWith((ref) => invites),
          inviteShareLauncherProvider.overrideWith((ref) => launcher),
          localFlagStoreProvider.overrideWithValue(
            FakeLocalFlagStore(initial: {privacySpotlightSeenKey(_ownUid)}),
          ),
        ],
      );
      await tester.pumpAndSettle();

      await writeSurfacePng(tester, out(tag, '04-solo'));
    });
  });

  // ---- 5. The coach, mid-conversation ----
  //
  // NOT the pack-selection screen, which was here first. Rendered at 6.9" that
  // screen is a centred lock icon over two thirds of empty canvas — a paywall
  // pitch, not a feature. The coach transcript is the differentiator, and it
  // fills the frame.
  _locales.forEach((tag, locale) {
    testWidgets('05 coach $tag', (tester) async {
      final language = tag == 'tr' ? ContentLanguage.tr : ContentLanguage.en;
      final turns = _coachTurns[tag]!;
      var turn = 0;
      final coach = FakeCoachRepository();
      // Each send answers with ITS OWN reply: a fake returning one canned line
      // three times would render a transcript no user could ever see.
      coach.onSendMessage = (call) async => CoachReply(
        kind: CoachReplyKind.reply,
        text: turns[turn++].$2,
        remaining: CoachRemaining(daily: 12 - turn, monthly: 300),
      );
      final mirrors = FakeEntitlementRepository(
        initialMirrors: {
          _coupleId: CoupleEntitlement(
            entitled: true,
            expiresAt: _pairedNow.add(const Duration(days: 30)),
          ),
        },
      );
      final auth = FakeAuthRepository(initialUser: _user);
      final profiles = FakeProfileRepository(
        initialProfiles: {
          _ownUid: RelationshipProfile(
            status: RelationshipStatus.married,
            contentLanguage: language,
            register: ContentRegister.respectful,
            coupleId: _coupleId,
          ),
        },
      );
      addTearDown(mirrors.dispose);
      addTearDown(auth.dispose);
      addTearDown(profiles.dispose);

      await pumpGolden(
        tester,
        const CoachScreen(uid: _ownUid, coupleId: _coupleId),
        locale: locale,
        direction: TextDirection.ltr,
        overrides: [
          coachRepositoryProvider.overrideWith((ref) => coach),
          entitlementRepositoryProvider.overrideWith((ref) => mirrors),
          authRepositoryProvider.overrideWith((ref) => auth),
          profileRepositoryProvider.overrideWith((ref) => profiles),
          purchasesRepositoryProvider.overrideWith(
            (ref) => FakePurchasesRepository(),
          ),
          // Disclaimer already acknowledged: the store shot is the working
          // surface, not the one-time consent panel that sits in front of it.
          localFlagStoreProvider.overrideWithValue(
            FakeLocalFlagStore(initial: {coachDisclaimerAckKey(_ownUid)}),
          ),
          soloClockProvider.overrideWith(
            (ref) =>
                () => _pairedNow,
          ),
        ],
      );
      await tester.pumpAndSettle();

      // REAL sends, so the transcript is a genuine round trip through the
      // screen's own send path rather than hand-placed bubbles.
      for (final (ask, _) in turns) {
        await tester.enterText(find.byType(TextField), ask);
        await tester.pump();
        await tester.tap(
          find.widgetWithText(FilledButton, l10nFor(locale).coachSend),
        );
        await tester.pumpAndSettle();
      }

      await writeSurfacePng(tester, out(tag, '05-coach'));
    });
  });

  // ---- 6. It stays private: PIN + biometrics ----
  _locales.forEach((tag, locale) {
    testWidgets('06 lock $tag', (tester) async {
      final record = lockRecord(
        biometricEnabled: true,
        enrollment: 'enrollment-v1',
      );
      final auth = FakeAuthRepository(initialUser: _user);
      addTearDown(auth.dispose);

      await pumpGolden(
        tester,
        const LockScreen(),
        locale: locale,
        direction: TextDirection.ltr,
        overrides: [
          pinLockStoreProvider.overrideWithValue(
            FakePinLockStore(initial: record),
          ),
          initialLockSnapshotProvider.overrideWithValue(
            PinLockSnapshot(record: record),
          ),
          biometricAuthenticatorProvider.overrideWithValue(
            FakeBiometricAuthenticator(enrollment: 'enrollment-v1'),
          ),
          authRepositoryProvider.overrideWith((ref) => auth),
          soloClockProvider.overrideWith(
            (ref) =>
                () => _pairedNow,
          ),
        ],
      );
      await tester.pumpAndSettle();

      await writeSurfacePng(tester, out(tag, '06-lock'));
    });
  });
}
