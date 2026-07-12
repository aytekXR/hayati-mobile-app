import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/core/storage/local_flag_store.dart';
import 'package:hayati_app/features/auth/domain/auth_repository_provider.dart';
import 'package:hayati_app/features/auth/domain/auth_user.dart';
import 'package:hayati_app/features/coach/domain/coach_disclaimer.dart';
import 'package:hayati_app/features/coach/domain/coach_reply.dart';
import 'package:hayati_app/features/coach/domain/coach_repository_provider.dart';
import 'package:hayati_app/features/coach/presentation/coach_screen.dart';
import 'package:hayati_app/features/daily_question/domain/solo_clock.dart';
import 'package:hayati_app/features/entitlements/domain/couple_entitlement.dart';
import 'package:hayati_app/features/entitlements/domain/entitlement_repository_provider.dart';
import 'package:hayati_app/features/entitlements/domain/purchases_repository_provider.dart';
import 'package:hayati_app/features/profile/domain/profile_repository_provider.dart';
import 'package:hayati_app/features/profile/domain/relationship_profile.dart';
// flutter_riverpod's curated export omits Override; riverpod_annotation exposes
// it — same seam the other golden tests use.
import 'package:riverpod_annotation/riverpod_annotation.dart' show Override;

import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_coach_repository.dart';
import '../../../support/fake_entitlement_repository.dart';
import '../../../support/fake_local_flag_store.dart';
import '../../../support/fake_profile_repository.dart';
import '../../../support/fake_purchases_repository.dart';
import '../../../support/golden/golden_harness.dart';
import '../../../support/localized_app.dart';

const _coupleId = 'couple-1';
const _uid = 'uid-1';
const _user = AuthUser(uid: _uid, displayName: 'Aytek');

/// Pinned clock so the premium expiry check is deterministic.
final _now = DateTime.utc(2026, 7, 11, 12);

/// The wire language is the profile's contentLanguage: arrange it to match each
/// cell's locale so the persona reply and user bubble render real script.
ContentLanguage _langFor(Locale locale) => switch (locale.languageCode) {
  'tr' => ContentLanguage.tr,
  'ar' => ContentLanguage.ar,
  _ => ContentLanguage.en,
};

/// The user's message, per wire language (so the user bubble is real script).
const _userText = <ContentLanguage, String>{
  ContentLanguage.tr: 'Bu hafta sonu için güzel bir buluşma fikri var mı?',
  ContentLanguage.ar: 'هل لديك فكرة موعد جميلة لهذا الأسبوع؟',
  ContentLanguage.en: 'Any nice date idea for this weekend?',
};

/// The canned persona reply, per wire language.
const _replyText = <ContentLanguage, String>{
  ContentLanguage.tr:
      'Birlikte küçük bir plan yapalım: bir yürüyüş ve sevdiğiniz bir kahve.',
  ContentLanguage.ar: 'لنضع خطة صغيرة معًا: نزهة قصيرة وقهوة تحبّانها.',
  ContentLanguage.en:
      "Let's make a small plan together: a short walk and a coffee you both love.",
};

/// The REAL server help-path copy (functions/src/coach/help-content.ts),
/// hardcoded per wire language so the help golden shows the true crisis-help
/// rendering — the state a real crisis leaves behind (latched paused panel).
const _helpText = <ContentLanguage, String>{
  ContentLanguage.en:
      "It sounds like you're carrying something really heavy right now, and I'm glad you "
      'said it out loud. This is bigger than I can hold with you here. Please reach out '
      'to your local emergency number, or to someone trained to help, right away — a doctor, '
      'a mental-health professional, or a crisis line in your country. If you can, tell '
      "someone you trust what you're going through, and let them stay with you. You matter, "
      "and you don't have to carry this alone.",
  ContentLanguage.tr:
      'Şu anda çok ağır bir şey taşıyor gibisin ve bunu söyleyebildiğine sevindim. Bu, '
      'burada seninle birlikte taşıyabileceğimden daha büyük. Lütfen hemen yerel acil '
      'yardım numaranı ara ya da yardım edebilecek birine ulaş — bir doktor, bir ruh '
      'sağlığı uzmanı ya da ülkendeki bir kriz destek hattı. Mümkünse güvendiğin birine '
      'neler yaşadığını anlat ve yanında kalmasını iste. Sen değerlisin ve bunu tek başına '
      'taşımak zorunda değilsin.',
  ContentLanguage.ar:
      'يبدو أنك تحمل شيئًا ثقيلًا جدًا الآن، وأنا سعيد لأنك قلته بصوت عالٍ. هذا أكبر مما '
      'أستطيع أن أحمله معك هنا. أرجوك تواصل فورًا مع رقم الطوارئ المحلي لديك، أو مع شخص '
      'مؤهل لمساعدتك — طبيب، أو مختص في الصحة النفسية، أو خط دعم للأزمات في بلدك. وإن '
      'استطعت، أخبر شخصًا تثق به بما تمر به، ودعه يبقى بجانبك. أنت مهم، ولست مضطرًا أن '
      'تحمل هذا وحدك.',
};

enum _Mode { disclaimer, conversation, help }

void main() {
  RelationshipProfile profileFor(ContentLanguage language) =>
      RelationshipProfile(
        status: RelationshipStatus.married,
        contentLanguage: language,
        register: ContentRegister.respectful,
        coupleId: _coupleId,
      );

  List<Override> arrange(Locale locale, _Mode mode) {
    final lang = _langFor(locale);
    final coach = FakeCoachRepository();
    switch (mode) {
      case _Mode.disclaimer:
        break;
      case _Mode.conversation:
        coach.onSendMessage = (call) async => CoachReply(
          kind: CoachReplyKind.reply,
          text: _replyText[lang]!,
          remaining: const CoachRemaining(daily: 12, monthly: 300),
        );
      case _Mode.help:
        coach.onSendMessage = (call) async => CoachReply(
          kind: CoachReplyKind.help,
          text: _helpText[lang]!,
          category: CoachCrisisCategory.selfHarm,
        );
    }
    final mirrors = FakeEntitlementRepository(
      initialMirrors: {
        _coupleId: CoupleEntitlement(
          entitled: true,
          expiresAt: _now.add(const Duration(days: 30)),
        ),
      },
    );
    final auth = FakeAuthRepository(initialUser: _user);
    final profiles = FakeProfileRepository(
      initialProfiles: {_uid: profileFor(lang)},
    );
    final flags = FakeLocalFlagStore(
      initial: mode == _Mode.disclaimer ? null : {coachDisclaimerAckKey(_uid)},
    );
    addTearDown(mirrors.dispose);
    addTearDown(auth.dispose);
    addTearDown(profiles.dispose);
    return [
      coachRepositoryProvider.overrideWith((ref) => coach),
      entitlementRepositoryProvider.overrideWith((ref) => mirrors),
      authRepositoryProvider.overrideWith((ref) => auth),
      profileRepositoryProvider.overrideWith((ref) => profiles),
      purchasesRepositoryProvider.overrideWith(
        (ref) => FakePurchasesRepository(),
      ),
      localFlagStoreProvider.overrideWithValue(flags),
      soloClockProvider.overrideWith(
        (ref) =>
            () => _now,
      ),
    ];
  }

  /// Drives one send so the transcript carries the canned reply/help turn.
  Future<void> send(WidgetTester tester, Locale locale) async {
    final l10n = l10nFor(locale);
    await tester.enterText(
      find.byType(TextField),
      _userText[_langFor(locale)]!,
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, l10n.coachSend));
    await tester.pumpAndSettle();
  }

  Future<void> pump(
    WidgetTester tester,
    GoldenCell cell,
    _Mode mode, {
    double textScale = 1.0,
  }) async {
    await pumpGolden(
      tester,
      const CoachScreen(uid: _uid, coupleId: _coupleId),
      locale: cell.locale,
      direction: cell.direction,
      overrides: arrange(cell.locale, mode),
      textScale: textScale,
    );
    await tester.pumpAndSettle();
    if (mode != _Mode.disclaimer) await send(tester, cell.locale);
  }

  final states = <String, _Mode>{
    'disclaimer': _Mode.disclaimer,
    'conversation': _Mode.conversation,
    'help_path': _Mode.help,
  };

  for (final state in states.entries) {
    for (final cell in sixCells) {
      testWidgets('${state.key} ${cell.suffix}', (tester) async {
        await pump(tester, cell, state.value);
        await expectLater(
          find.byType(CoachScreen),
          matchesGoldenFile(goldenFile('coach_screen', state.key, cell.suffix)),
        );
      });
    }

    // Dynamic-type probe, natural directions only.
    for (final cell in naturalCells) {
      testWidgets('${state.key} scale130 ${cell.suffix}', (tester) async {
        await pump(tester, cell, state.value, textScale: 1.3);
        await expectLater(
          find.byType(CoachScreen),
          matchesGoldenFile(
            goldenFile('coach_screen', '${state.key}_scale130', cell.suffix),
          ),
        );
      });
    }
  }
}
