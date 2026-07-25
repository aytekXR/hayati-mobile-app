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

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    registerDevicePrivacyChannel(engineBridge)
  }

  /// The app's ONE platform channel (ADR-018 Decision 6): `hayati/device_privacy`
  /// carries the whole native half of the privacy layer — the alternate icon and
  /// the biometric enrollment state. One channel, one registration site, one seam
  /// discipline.
  ///
  /// The Dart side (`core/platform/device_privacy_channel.dart`) is the only
  /// caller, and it is reached solely through the `AppIconSwitcher` /
  /// `BiometricAuthenticator` seams — which the entrypoints construct and the
  /// tests never import, so `flutter test` never touches this channel.
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

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
