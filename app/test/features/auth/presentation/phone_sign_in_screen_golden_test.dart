import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/auth/domain/auth_repository_provider.dart';
import 'package:hayati_app/features/auth/domain/phone_sign_in_session.dart';
import 'package:hayati_app/features/auth/presentation/phone_sign_in_screen.dart';

import '../../../support/fake_auth_repository.dart';
import '../../../support/golden/golden_harness.dart';
import '../../../support/localized_app.dart';

// The PhoneSending / PhoneConfirming spinner states are deliberately NOT
// golden'd (indeterminate animation, no stable frame); the behavioural tests in
// phone_sign_in_screen_test.dart cover them.
void main() {
  for (final cell in sixCells) {
    testWidgets('entry ${cell.suffix}', (tester) async {
      final fake = FakeAuthRepository();
      addTearDown(fake.dispose);

      await pumpGolden(
        tester,
        const PhoneSignInScreen(),
        locale: cell.locale,
        direction: cell.direction,
        overrides: [authRepositoryProvider.overrideWith((ref) => fake)],
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(PhoneSignInScreen),
        matchesGoldenFile(
          goldenFile('phone_sign_in_screen', 'entry', cell.suffix),
        ),
      );
    });

    testWidgets('code_sent ${cell.suffix}', (tester) async {
      final fake = FakeAuthRepository();
      addTearDown(fake.dispose);
      fake.onSendPhoneCode = (_, {resendFrom}) async =>
          const PhoneSignInSession('vid-1', resendToken: 5);

      await pumpGolden(
        tester,
        const PhoneSignInScreen(),
        locale: cell.locale,
        direction: cell.direction,
        overrides: [authRepositoryProvider.overrideWith((ref) => fake)],
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '+905551112233');
      await tester.tap(find.text(l10nFor(cell.locale).sendCode));
      await tester.pumpAndSettle();
      // enterText focused the SMS field; a blinking caret is nondeterministic,
      // so drop focus before capturing.
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(PhoneSignInScreen),
        matchesGoldenFile(
          goldenFile('phone_sign_in_screen', 'code_sent', cell.suffix),
        ),
      );
    });
  }
}
