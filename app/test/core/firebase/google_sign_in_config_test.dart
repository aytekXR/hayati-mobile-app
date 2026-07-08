import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/core/config/app_config.dart';
import 'package:hayati_app/core/firebase/google_sign_in_config.dart';

void main() {
  group('googleSignInConfigFor', () {
    test('selects the dev config for the dev flavor', () {
      expect(
        identical(googleSignInConfigFor(AppFlavor.dev), GoogleSignInConfig.dev),
        isTrue,
      );
    });

    test('selects the prod config for the prod flavor', () {
      expect(
        identical(
          googleSignInConfigFor(AppFlavor.prod),
          GoogleSignInConfig.prod,
        ),
        isTrue,
      );
    });
  });
}
