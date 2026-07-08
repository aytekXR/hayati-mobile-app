import '../config/app_config.dart';

/// Per-flavor Google Sign-In OAuth client wiring (issue #5, Session 004).
///
/// These OAuth clients were auto-provisioned when the founder enabled the
/// Google provider in the Firebase console (free-tier Auth initialization is
/// console-only — the Identity Toolkit Admin API rejects provider creation
/// without an existing OAuth client id, and `identityPlatform:initializeAuth`
/// is the billing-gated GCIP upgrade). Client ids are identifiers, not
/// secrets — committed like the Firebase options files.
///
/// To re-harvest (e.g. after re-provisioning):
/// - Web client id (→ [serverClientId]):
///   `GET https://identitytoolkit.googleapis.com/admin/v2/projects/{p}/`
///   `defaultSupportedIdpConfigs/google.com` → `clientId`.
/// - iOS client id (→ [iosClientId]) + REVERSED_CLIENT_ID:
///   `npx firebase-tools apps:sdkconfig ios <iosAppId> --project {p}`.
/// - Both flavors' REVERSED_CLIENT_ID values are registered side by side as
///   CFBundleURLTypes URL schemes in `app/ios/Runner/Info.plist` (one Runner
///   serves both Dart-entrypoint flavors).
class GoogleSignInConfig {
  const GoogleSignInConfig({this.iosClientId, this.serverClientId});

  /// iOS OAuth client id, passed to `GoogleSignIn.initialize(clientId:)` —
  /// runtime equivalent of the plist `GIDClientID` key, which a single
  /// Runner shared by two flavors cannot hold per-flavor.
  final String? iosClientId;

  /// Web OAuth client id; Android requires it as `serverClientId` to mint a
  /// Firebase-verifiable id token. (Android sign-in additionally needs the
  /// app's SHA-1 registered — deferred with the rest of Android to M6.5.)
  final String? serverClientId;

  static const GoogleSignInConfig dev = GoogleSignInConfig(
    iosClientId:
        '870954957461-d47kphokdf1vrrtn7g9fvqom7ofikies'
        '.apps.googleusercontent.com',
    serverClientId:
        '870954957461-4inhi2favrm0lo1idc7tobd41a7n5olh'
        '.apps.googleusercontent.com',
  );
  static const GoogleSignInConfig prod = GoogleSignInConfig(
    iosClientId:
        '419979715508-brk62sg117qfj212ig43cfv4da0k5jg0'
        '.apps.googleusercontent.com',
    serverClientId:
        '419979715508-g85p4sgcnoh8ctdfij97rllfuha0jdg8'
        '.apps.googleusercontent.com',
  );
}

/// Pure flavor→config selection, mirroring `firebaseOptionsFor`.
GoogleSignInConfig googleSignInConfigFor(AppFlavor flavor) => switch (flavor) {
  AppFlavor.dev => GoogleSignInConfig.dev,
  AppFlavor.prod => GoogleSignInConfig.prod,
};
