import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/core/config/app_config.dart';
import 'package:hayati_app/core/firebase/firebase_bootstrap.dart';
import 'package:hayati_app/core/firebase/firebase_options_dev.dart';
import 'package:hayati_app/core/firebase/firebase_options_prod.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  group('firebaseOptionsFor', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('dev on Android selects the dev Android options', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(firebaseOptionsFor(AppFlavor.dev), DevFirebaseOptions.android);
      // demo- prefix keeps the Auth emulator credential-free pre-provisioning.
      expect(firebaseOptionsFor(AppFlavor.dev).projectId, 'demo-hayati');
    });

    test('dev on iOS selects the dev iOS options', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(firebaseOptionsFor(AppFlavor.dev), DevFirebaseOptions.ios);
      expect(firebaseOptionsFor(AppFlavor.dev).iosBundleId, 'com.hayati.app');
    });

    test('prod on Android selects the prod Android options', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(firebaseOptionsFor(AppFlavor.prod), ProdFirebaseOptions.android);
      expect(firebaseOptionsFor(AppFlavor.prod).projectId, 'hayati-prod');
    });

    test('prod on iOS selects the prod iOS options', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(firebaseOptionsFor(AppFlavor.prod), ProdFirebaseOptions.ios);
      expect(firebaseOptionsFor(AppFlavor.prod).iosBundleId, 'com.hayati.app');
    });

    test('dev and prod never share a Firebase project', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(
        firebaseOptionsFor(AppFlavor.dev).projectId,
        isNot(firebaseOptionsFor(AppFlavor.prod).projectId),
      );
    });

    test('unsupported platforms fail loudly', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      expect(() => firebaseOptionsFor(AppFlavor.dev), throwsUnsupportedError);
    });
  });

  group('initializeFirebase', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('boots the dev flavor without throwing', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await initializeFirebase(const AppConfig(flavor: AppFlavor.dev));
      expect(Firebase.apps, isNotEmpty);
    });

    test('boots the prod flavor without throwing', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await initializeFirebase(const AppConfig(flavor: AppFlavor.prod));
      expect(Firebase.apps, isNotEmpty);
    });
  });
}
