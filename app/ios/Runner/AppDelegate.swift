// `FirebaseCore` and `FirebaseMessaging`, NOT the `Firebase` umbrella: this
// project has no Podfile at all — plugins come through
// `FlutterGeneratedPluginSwiftPackage` (SPM) — and firebase-ios-sdk's
// `Package.swift` vends no `Firebase` umbrella product, so `import Firebase`
// does not resolve here even though it is the line every CocoaPods example
// shows. `ios-build-smoke` compiles this file on every PR, which is the only
// reason a Swift change is safe to make from a Linux box (ADR-046 D6).
import FirebaseCore
import FirebaseMessaging
import Flutter
import LocalAuthentication
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// Hand the APNs device token to Firebase Messaging EXPLICITLY (ADR-046
  /// Decision 6).
  ///
  /// **This is the one link in the notification chain that has never been
  /// observed working.** ADR-042 named it and marked it UNVERIFIED: this app
  /// configures Firebase from pure-Dart `FirebaseOptions` with **no
  /// `GoogleService-Info.plist`**, on a scene-based `FlutterImplicitEngineDelegate`
  /// app delegate, and relied entirely on FirebaseCore's method swizzling to
  /// route this callback into `firebase_messaging`. If that swizzling does not
  /// land, `getAPNSToken()` returns nil forever, `isReadyForToken()` is never
  /// true, all six of ADR-044's capture attempts fail, and the result is
  /// **exactly what production shows today**: `registerPushToken` at zero
  /// invocations with every other layer verified working.
  ///
  /// Swizzling is probably fine — `FIRAppDelegateProxy` swizzles the delegate
  /// CLASS rather than depending on Flutter's plugin forwarding. But "probably"
  /// against a link whose only failure mode is silence, and a measured zero, is
  /// not a posture worth keeping. Assigning it here is idempotent with the
  /// swizzled assignment, costs nothing when swizzling works, and removes the
  /// dependency on it when it does not.
  ///
  /// Guarded on a configured `FirebaseApp`: Dart configures Firebase during
  /// engine startup, long before any APNs registration (which cannot happen
  /// before the user grants permission on the paired home screen), but touching
  /// `Messaging.messaging()` before `FirebaseApp.configure()` would fault, and a
  /// crash on a path that exists to make a feature MORE reliable is not a trade.
  ///
  /// `super` is still called: `FlutterAppDelegate` forwards this to every
  /// registered plugin, and dropping that would break anything else that wants
  /// the token.
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    if FirebaseApp.app() != nil {
      Messaging.messaging().apnsToken = deviceToken
    }
    super.application(
      application,
      didRegisterForRemoteNotificationsWithDeviceToken: deviceToken
    )
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    registerDevicePrivacyChannel(engineBridge)
  }

  /// The app's ONE platform channel (ADR-018 Decision 6): `hayati/device_privacy`
  /// carries the whole native half of the privacy layer — the alternate icon and
  /// the biometric enrollment state — plus, since ADR-046 D4, the one door out of
  /// a declined notification permission. One channel, one registration site, one
  /// seam discipline; a third package would have been the alternative and it is
  /// recorded as rejected in that ADR.
  ///
  /// The Dart side (`core/platform/device_privacy_channel.dart`) is the only
  /// caller, and it is reached solely through the `AppIconSwitcher` /
  /// `BiometricAuthenticator` / `NotificationSettingsLauncher` seams — which the
  /// entrypoints construct and the tests never import, so `flutter test` never
  /// touches this channel.
  private func registerDevicePrivacyChannel(_ engineBridge: FlutterImplicitEngineBridge) {
    let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "HayatiDevicePrivacy")
    guard let messenger = registrar?.messenger() else { return }

    let channel = FlutterMethodChannel(
      name: "hayati/device_privacy",
      binaryMessenger: messenger
    )

    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "supportsAlternateIcons":
        result(UIApplication.shared.supportsAlternateIcons)

      case "getAlternateIconName":
        // nil = the primary AppIcon is the one applied.
        result(UIApplication.shared.alternateIconName)

      case "setAlternateIconName":
        // `name` is the asset-catalog set name (`AppIconDiscreet`), or nil to go
        // back to the primary icon. iOS shows its own system alert on the swap —
        // expected, user-initiated, and deliberately NOT suppressed (suppressing
        // it needs private API; App Store safety wins). A failure returns the
        // error through the channel so the Dart side can REVERT the switch:
        // we never render a state the OS refused (Decision 7).
        let arguments = call.arguments as? [String: Any]
        let name = arguments?["name"] as? String
        // UIApplication mutation must happen on the main thread.
        DispatchQueue.main.async {
          UIApplication.shared.setAlternateIconName(name) { error in
            if let error = error {
              result(
                FlutterError(
                  code: "set-alternate-icon-failed",
                  message: error.localizedDescription,
                  details: nil
                )
              )
            } else {
              result(nil)
            }
          }
        }

      case "biometricEnrollmentState":
        // The opaque enrollment state (ADR-018 Decision 1's revocation input): a
        // CHANGE in these bytes means a face or finger was added/removed on this
        // phone since the accelerator was enabled, and the Dart side auto-revokes
        // biometric unlock. nil whenever biometrics cannot be evaluated at all —
        // which the Dart side also treats as a revoke.
        //
        // Two sources, one meaning (ADR-018 rev 5, issue #47). iOS 18 deprecated
        // `evaluatedPolicyDomainState` and names its own replacement in the SDK
        // header: API_DEPRECATED_WITH_REPLACEMENT("domainState.biometry.stateHash").
        // The deployment target is iOS 15, so the legacy branch is live code, not
        // dead weight — and it is the branch that will keep warning until the
        // target rises past 18. The bytes are opaque to Dart either way: it stores
        // and compares them, never parses them, so the two representations differ
        // WITHOUT breaking anything except across an OS upgrade, where the
        // mismatch revokes the accelerator and asks for the PIN — the fail-SAFE
        // direction, recorded in the ADR rather than left to surprise anyone.
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        else {
          result(nil)
          return
        }
        let enrollmentBytes: Data?
        if #available(iOS 18.0, *) {
          enrollmentBytes = context.domainState.biometry.stateHash
        } else {
          enrollmentBytes = context.evaluatedPolicyDomainState
        }
        // nil is NOT an error path to swallow: the Dart side reads it as "cannot
        // validate the accelerator" and revokes. Never substitute a placeholder.
        guard let enrollmentBytes else {
          result(nil)
          return
        }
        result(enrollmentBytes.base64EncodedString())

      case "openNotificationSettings":
        // ADR-046 Decision 4. The ONLY place a declined notification permission
        // can be changed: iOS shows its dialog once per install and never again,
        // so after a decline the app can offer nothing but this door.
        //
        // `openSettingsURLString` opens the app's own Settings page (which on
        // iOS 16+ carries the Notifications section directly). A failure is
        // reported through the channel rather than swallowed — the Dart side
        // throws, and the row says the OS refused. A button that looks like it
        // worked and did nothing is the defect this whole slice removes.
        DispatchQueue.main.async {
          guard let url = URL(string: UIApplication.openSettingsURLString),
                UIApplication.shared.canOpenURL(url)
          else {
            result(
              FlutterError(
                code: "settings-url-unavailable",
                message: "The Settings URL could not be opened.",
                details: nil
              )
            )
            return
          }
          UIApplication.shared.open(url, options: [:]) { opened in
            if opened {
              result(nil)
            } else {
              result(
                FlutterError(
                  code: "settings-open-refused",
                  message: "The system refused to open Settings.",
                  details: nil
                )
              )
            }
          }
        }

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
