import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/core/storage/local_flag_store.dart';
import 'package:hayati_app/features/auth/domain/auth_repository_provider.dart';
import 'package:hayati_app/features/auth/domain/auth_user.dart';
import 'package:hayati_app/features/coach/domain/coach_disclaimer.dart';
import 'package:hayati_app/features/coach/domain/coach_exception.dart';
import 'package:hayati_app/features/coach/domain/coach_reply.dart';
import 'package:hayati_app/features/coach/domain/coach_repository_provider.dart';
import 'package:hayati_app/features/coach/presentation/coach_screen.dart';
import 'package:hayati_app/features/daily_question/domain/solo_clock.dart';
import 'package:hayati_app/features/entitlements/domain/couple_entitlement.dart';
import 'package:hayati_app/features/entitlements/domain/entitlement_repository_provider.dart';
import 'package:hayati_app/features/entitlements/domain/purchases_repository_provider.dart';
import 'package:hayati_app/features/entitlements/presentation/paywall_screen.dart';
import 'package:hayati_app/features/profile/domain/profile_repository.dart';
import 'package:hayati_app/features/profile/domain/profile_repository_provider.dart';
import 'package:hayati_app/features/profile/domain/relationship_profile.dart';
// flutter_riverpod's curated export omits Override; riverpod_annotation exposes
// it — the seam the other tests use.
import 'package:riverpod_annotation/riverpod_annotation.dart' show Override;

import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_coach_repository.dart';
import '../../../support/fake_entitlement_repository.dart';
import '../../../support/fake_local_flag_store.dart';
import '../../../support/fake_profile_repository.dart';
import '../../../support/fake_purchases_repository.dart';
import '../../../support/localized_app.dart';

const _coupleId = 'couple-1';
const _uid = 'uid-1';
const _user = AuthUser(uid: _uid, displayName: 'Aytek');
final _now = DateTime.utc(2026, 7, 11, 12);

/// A settled, premium-couple English profile — the composer's language/register
/// source (contentLanguage.name over the wire; register via coachRegisterFor).
const _profile = RelationshipProfile(
  status: RelationshipStatus.married,
  contentLanguage: ContentLanguage.en,
  register: ContentRegister.respectful,
  coupleId: _coupleId,
);

CoupleEntitlement _entitled() =>
    CoupleEntitlement(entitled: true, expiresAt: _now.add(const Duration(days: 30)));

FakeEntitlementRepository _premiumMirror() =>
    FakeEntitlementRepository(initialMirrors: {_coupleId: _entitled()});

/// A profile repository whose stream never emits — the genuine loading state
/// (the seeded [FakeProfileRepository] yields its initial value immediately, so
/// it can only reach settled-null, never loading).
class _PendingProfileRepository implements ProfileRepository {
  final StreamController<RelationshipProfile?> _controller =
      StreamController<RelationshipProfile?>.broadcast();

  @override
  Stream<RelationshipProfile?> watchProfile(String uid) => _controller.stream;

  @override
  Future<void> saveProfile(String uid, RelationshipProfile profile) async {}

  Future<void> dispose() => _controller.close();
}

void main() {
  final en = l10nFor(const Locale('en'));

  ({
    List<Override> overrides,
    FakeCoachRepository coach,
    FakeEntitlementRepository mirrors,
    FakeLocalFlagStore flags,
    FakeAuthRepository auth,
  })
  arrange({
    bool acknowledged = true,
    FakeCoachRepository? coach,
    FakeEntitlementRepository? mirrors,
    FakeAuthRepository? auth,
    ProfileRepository? profiles,
    RelationshipProfile? profile = _profile,
  }) {
    final c = coach ?? FakeCoachRepository();
    final m = mirrors ?? _premiumMirror();
    final a = auth ?? FakeAuthRepository(initialUser: _user);
    final f = FakeLocalFlagStore(
      initial: acknowledged ? {coachDisclaimerAckKey(_uid)} : null,
    );
    final p =
        profiles ??
        FakeProfileRepository(
          initialProfiles: profile == null ? null : {_uid: profile},
        );
    addTearDown(m.dispose);
    addTearDown(a.dispose);
    if (p is FakeProfileRepository) addTearDown(p.dispose);
    if (p is _PendingProfileRepository) addTearDown(p.dispose);
    return (
      overrides: [
        coachRepositoryProvider.overrideWith((ref) => c),
        entitlementRepositoryProvider.overrideWith((ref) => m),
        authRepositoryProvider.overrideWith((ref) => a),
        profileRepositoryProvider.overrideWith((ref) => p),
        purchasesRepositoryProvider.overrideWith((ref) => FakePurchasesRepository()),
        localFlagStoreProvider.overrideWithValue(f),
        soloClockProvider.overrideWith(
          (ref) =>
              () => _now,
        ),
      ],
      coach: c,
      mirrors: m,
      flags: f,
      auth: a,
    );
  }

  Future<void> pumpCoach(WidgetTester tester, List<Override> overrides) {
    return tester.pumpWidget(
      localizedApp(
        const CoachScreen(uid: _uid, coupleId: _coupleId),
        overrides: overrides,
      ),
    );
  }

  /// Types [text] then taps send (settling the canned/onSendMessage reply).
  Future<void> sendMessage(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, en.coachSend));
    await tester.pumpAndSettle();
  }

  group('disclaimer gate', () {
    testWidgets('gates the chat until the CTA, then persists and reveals it', (
      tester,
    ) async {
      final env = arrange(acknowledged: false);
      await pumpCoach(tester, env.overrides);
      await tester.pumpAndSettle();

      // The disclaimer is shown; nothing is sendable.
      expect(find.text(en.coachDisclaimerTitle), findsOneWidget);
      expect(find.text(en.coachDisclaimerBody), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.text(en.coachEmptyState), findsNothing);

      await tester.tap(find.widgetWithText(FilledButton, en.coachDisclaimerCta));
      await tester.pumpAndSettle();

      // The chat now renders and the ack is persisted.
      expect(find.text(en.coachDisclaimerTitle), findsNothing);
      expect(find.text(en.coachEmptyState), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(env.flags.isSet(coachDisclaimerAckKey(_uid)), isTrue);
    });

    testWidgets('a pre-set ack flag skips the disclaimer entirely', (
      tester,
    ) async {
      final env = arrange(); // acknowledged: true
      await pumpCoach(tester, env.overrides);
      await tester.pumpAndSettle();

      expect(find.text(en.coachDisclaimerTitle), findsNothing);
      expect(find.text(en.coachEmptyState), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });
  });

  group('profile settle', () {
    testWidgets('a loading profile shows a spinner and no composer', (
      tester,
    ) async {
      final pending = _PendingProfileRepository();
      final env = arrange(profiles: pending);
      await pumpCoach(tester, env.overrides);
      // Let the entitlement stream settle premium (so the gate is unlocked) but
      // leave the never-emitting profile stream loading.
      await tester.pump();
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('a null/error profile shows the honest error state with retry', (
      tester,
    ) async {
      // No seeded profile → the stream yields null → settled error state.
      final env = arrange(profile: null);
      await pumpCoach(tester, env.overrides);
      await tester.pumpAndSettle();

      expect(find.text(en.errorGeneric), findsOneWidget);
      expect(find.widgetWithText(FilledButton, en.tryAgain), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });
  });

  group('send flow', () {
    testWidgets('renders the user bubble and the persona bubble from the reply', (
      tester,
    ) async {
      final env = arrange();
      await pumpCoach(tester, env.overrides);
      await tester.pumpAndSettle();

      await sendMessage(tester, 'How do we plan a date?');

      expect(find.text('How do we plan a date?'), findsOneWidget);
      expect(find.byType(CoachUserBubble), findsOneWidget);
      expect(find.text(FakeCoachRepository.cannedReply.text), findsOneWidget);
      expect(find.byType(CoachPersonaBubble), findsOneWidget);
      // A reply is not the help path.
      expect(find.byType(CoachHelpCard), findsNothing);
      expect(env.coach.callLog, hasLength(1));
    });

    testWidgets('a help reply renders the help card TYPE, never a persona '
        'bubble, latches the paused panel, blocks further sends, and hides the '
        'quota caption', (tester) async {
      final env = arrange();
      // Post-filter help shape (carries a remaining hint) — proves the caption
      // is suppressed even when lastRemaining is set.
      env.coach.onSendMessage = (call) async => const CoachReply(
        kind: CoachReplyKind.help,
        text: 'Please reach out to someone you trust.',
        category: CoachCrisisCategory.selfHarm,
        remaining: CoachRemaining(daily: 5, monthly: 100),
      );
      await pumpCoach(tester, env.overrides);
      await tester.pumpAndSettle();

      await sendMessage(tester, 'I feel hopeless.');

      // Structurally distinct: the help card TYPE, never a persona bubble.
      expect(find.byType(CoachHelpCard), findsOneWidget);
      expect(find.text('Please reach out to someone you trust.'), findsOneWidget);
      expect(find.byType(CoachPersonaBubble), findsNothing);
      // Latched: the composer is gone, the paused panel is present.
      expect(find.byType(CoachPausedPanel), findsOneWidget);
      expect(find.text(en.coachPausedBody), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      // The quota caption is suppressed while latched (lastRemaining IS set).
      expect(find.text(en.coachQuotaRemaining(5)), findsNothing);

      // No further send is possible — the call log stays pinned at one.
      expect(env.coach.callLog, hasLength(1));
    });

    testWidgets('the paused panel new-conversation clears the transcript and '
        'restores the composer', (tester) async {
      final env = arrange();
      env.coach.onSendMessage = (call) async => const CoachReply(
        kind: CoachReplyKind.help,
        text: 'Please reach out to someone you trust.',
      );
      await pumpCoach(tester, env.overrides);
      await tester.pumpAndSettle();
      await sendMessage(tester, 'I feel hopeless.');
      expect(find.byType(CoachPausedPanel), findsOneWidget);

      await tester.tap(
        find.widgetWithText(FilledButton, en.coachNewConversation),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CoachPausedPanel), findsNothing);
      expect(find.byType(CoachHelpCard), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text(en.coachEmptyState), findsOneWidget);
    });
  });

  group('app-bar reset + persona isolation', () {
    testWidgets('the reset button appears only with entries and clears only the '
        'active persona; persona chips swap transcripts', (tester) async {
      final env = arrange();
      await pumpCoach(tester, env.overrides);
      await tester.pumpAndSettle();

      // Empty: no reset affordance.
      expect(find.byIcon(Icons.refresh), findsNothing);

      // Send as Coach (the default persona).
      await sendMessage(tester, 'Coach message.');
      expect(find.text('Coach message.'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);

      // Switch to Date Genie → its transcript is empty (independent family).
      await tester.tap(
        find.widgetWithText(ChoiceChip, en.coachPersonaDateGenie),
      );
      await tester.pumpAndSettle();
      expect(find.text('Coach message.'), findsNothing);
      expect(find.text(en.coachEmptyState), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsNothing);

      // Switch back to Coach → its history is intact.
      await tester.tap(find.widgetWithText(ChoiceChip, en.coachPersonaCoach));
      await tester.pumpAndSettle();
      expect(find.text('Coach message.'), findsOneWidget);

      // The reset clears ONLY the active (Coach) persona.
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();
      expect(find.text('Coach message.'), findsNothing);
      expect(find.text(en.coachEmptyState), findsOneWidget);
    });
  });

  group('error copy', () {
    final cases = <String, ({CoachException failure, String Function() copy})>{
      'unavailable': (
        failure: const CoachUnavailableException(),
        copy: () => en.coachErrorUnavailable,
      ),
      'rate-limited': (
        failure: const CoachRateLimitedException(),
        copy: () => en.coachErrorRateLimited,
      ),
      'cap-daily': (
        failure: const CoachDailyCapException(),
        copy: () => en.coachErrorCapDaily,
      ),
      'cap-monthly': (
        failure: const CoachMonthlyCapException(),
        copy: () => en.coachErrorCapMonthly,
      ),
      'limit': (
        failure: const CoachLimitReachedException(),
        copy: () => en.coachErrorLimit,
      ),
      'not-member': (
        failure: const CoachNotMemberException(),
        copy: () => en.coachErrorGeneric,
      ),
      'unknown': (
        failure: const CoachUnknownException(code: 'internal'),
        copy: () => en.coachErrorGeneric,
      ),
    };

    for (final entry in cases.entries) {
      testWidgets('${entry.key} renders its distinct inline copy and keeps the '
          'draft', (tester) async {
        final env = arrange();
        env.coach.onSendMessage = (call) async => throw entry.value.failure;
        await pumpCoach(tester, env.overrides);
        await tester.pumpAndSettle();

        await sendMessage(tester, 'A message.');

        expect(find.text(entry.value.copy()), findsWidgets);
        // Failure keeps the draft in the composer (stage-1 contract).
        expect(find.byType(TextField), findsOneWidget);
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'A message.',
        );
      });
    }

    testWidgets('cap-daily and cap-monthly are asserted DISTINCT strings', (
      tester,
    ) async {
      expect(en.coachErrorCapDaily, isNot(en.coachErrorCapMonthly));
    });

    testWidgets('a not-premium failure pushes the paywall', (tester) async {
      final env = arrange();
      env.coach.onSendMessage =
          (call) async => throw const CoachNotPremiumException();
      await pumpCoach(tester, env.overrides);
      await tester.pumpAndSettle();

      await sendMessage(tester, 'A message.');

      expect(find.byType(PaywallScreen), findsOneWidget);
    });
  });

  group('quota caption', () {
    testWidgets('is absent before the first response, then renders daily-only '
        'and keeps input enabled', (tester) async {
      final env = arrange();
      await pumpCoach(tester, env.overrides);
      await tester.pumpAndSettle();

      // Before the first response: no caption.
      expect(find.text(en.coachQuotaRemaining(29)), findsNothing);

      // The canned reply carries remaining.daily == 29.
      await sendMessage(tester, 'A message.');
      expect(find.text(en.coachQuotaRemaining(29)), findsOneWidget);
      // Input stays enabled.
      expect(find.byType(TextField), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);
    });

    testWidgets('renders coachQuotaExhausted at daily 0 without disabling input', (
      tester,
    ) async {
      final env = arrange();
      env.coach.onSendMessage = (call) async => const CoachReply(
        kind: CoachReplyKind.reply,
        text: 'A reply.',
        remaining: CoachRemaining(daily: 0, monthly: 40),
      );
      await pumpCoach(tester, env.overrides);
      await tester.pumpAndSettle();

      await sendMessage(tester, 'A message.');

      expect(find.text(en.coachQuotaExhausted), findsOneWidget);
      // Never renders the monthly figure.
      expect(find.textContaining('40'), findsNothing);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);
    });
  });

  group('guards', () {
    testWidgets('a remote sign-out self-pops the pushed coach screen', (
      tester,
    ) async {
      final auth = FakeAuthRepository(initialUser: _user);
      final env = arrange(auth: auth);
      await tester.pumpWidget(
        localizedApp(
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          const CoachScreen(uid: _uid, coupleId: _coupleId),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
          overrides: env.overrides,
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(CoachScreen), findsOneWidget);

      auth.emit(null);
      await tester.pumpAndSettle();
      expect(find.byType(CoachScreen), findsNothing);
    });

    testWidgets('an entry over 2000 code units disables send and shows the '
        'too-long caption', (tester) async {
      final env = arrange();
      await pumpCoach(tester, env.overrides);
      await tester.pumpAndSettle();

      // 1001 emoji: 1001 graphemes (passes the grapheme formatter) but 2002
      // UTF-16 code units — the gate counts code units (ADR D2 rule 5).
      await tester.enterText(find.byType(TextField), '😀' * 1001);
      await tester.pump();

      expect(find.text(en.coachInputTooLong), findsOneWidget);
      final sendButton = find.widgetWithText(FilledButton, en.coachSend);
      expect(tester.widget<FilledButton>(sendButton).onPressed, isNull);
    });

    testWidgets('a re-entrant double-tap send issues exactly one repository '
        'call', (tester) async {
      final env = arrange();
      final gate = Completer<CoachReply>();
      env.coach.onSendMessage = (call) => gate.future;
      await pumpCoach(tester, env.overrides);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'A message.');
      await tester.pump();

      // Two taps before any rebuild settles the sending state: the first starts
      // the send (state → sending), the second is dropped by the controller.
      final sendButton = find.widgetWithText(FilledButton, en.coachSend);
      await tester.tap(sendButton, warnIfMissed: false);
      await tester.tap(sendButton, warnIfMissed: false);
      gate.complete(FakeCoachRepository.cannedReply);
      await tester.pumpAndSettle();

      expect(env.coach.callLog, hasLength(1));
    });
  });
}
