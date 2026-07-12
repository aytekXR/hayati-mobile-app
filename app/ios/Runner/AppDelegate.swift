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
        let context = LAContext()
        var error: NSError?
        guard
          context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error),
          let domainState = context.evaluatedPolicyDomainState
        else {
          result(nil)
          return
        }
        result(domainState.base64EncodedString())

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
