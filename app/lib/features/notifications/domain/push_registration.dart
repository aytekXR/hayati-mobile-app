import 'package:flutter/foundation.dart' show immutable;

/// Where this device stands in the notification chain (ADR-046 Decision 2).
///
/// **Each name indicts a different link**, which is the whole point. Before
/// this existed, four distinct device-side failures — never installed, prompt
/// declined, permission held but no token captured, callable threw — all
/// presented identically as *nothing happened*, and every one of them ended in a
/// `debugPrint` that a TestFlight build routes nowhere. Production spent five
/// sessions unable to tell them apart while `registerPushToken` sat at zero
/// invocations (measured 2026-08-16: 4 accounts, no `fcmTokens` on any of them,
/// zero HTTP requests ever reaching the function).
enum PushRegistrationState {
  /// Nothing has been measured yet: signed out, or no [PushTokenSource] wired.
  /// **Not a failure** — it is the ordinary state of a lifecycle that has not
  /// reached the point of asking.
  unknown,

  /// iOS has never shown its permission dialog for this install. Fixable by the
  /// app, by prompting — and iOS allows that exactly once.
  notDetermined,

  /// The user declined. **No build fixes this**: iOS will not show the dialog
  /// again, and `requestPermission()` returns the standing answer without
  /// interrupting anyone. Only the Settings app can change it.
  denied,

  /// Permission is held and no token has been captured yet. Either APNs has not
  /// answered (the ADR-044 window, ordinary and transient) or it never will (the
  /// one runtime link ADR-042 left UNVERIFIED — see ADR-046 D6). A retry is the
  /// honest response to both.
  awaitingDeviceToken,

  /// The server holds this device's address. This is success, and the UI says so
  /// out loud rather than implying it by the absence of a warning (lesson 65).
  registered,
}

/// The notifier value of `PushTokenSync` (ADR-046 D2): the diagnostic [state]
/// **and** the token it registered.
///
/// The token is carried here rather than replaced by the state because it is
/// load-bearing for a privacy control, not for display: sign-out removes *the
/// token this provider registered*, never one re-read at sign-out, because FCM
/// can rotate between the two and removing the new one would leave the old one
/// on the departing user's document (ADR-042 D1). A refactor about what to show
/// on screen must not quietly drop it.
@immutable
final class PushRegistration {
  const PushRegistration({required this.state, this.token});

  /// The pre-sign-in value: nothing measured, nothing registered.
  static const PushRegistration unknown = PushRegistration(
    state: PushRegistrationState.unknown,
  );

  final PushRegistrationState state;

  /// The token last registered with the server, or null. Non-null **only** when
  /// [state] is [PushRegistrationState.registered].
  final String? token;

  /// Whether this device can currently be reached by a notification.
  bool get isRegistered => state == PushRegistrationState.registered;

  /// Whether the only remaining fix is outside the app. `denied` is the one
  /// state a button inside the app cannot resolve — the row must send the user
  /// to iOS Settings rather than offer a prompt that will not appear.
  bool get needsSystemSettings => state == PushRegistrationState.denied;

  PushRegistration copyWith({
    PushRegistrationState? state,
    String? token,
    bool clearToken = false,
  }) => PushRegistration(
    state: state ?? this.state,
    token: clearToken ? null : (token ?? this.token),
  );

  @override
  bool operator ==(Object other) =>
      other is PushRegistration && other.state == state && other.token == token;

  @override
  int get hashCode => Object.hash(state, token);

  @override
  String toString() =>
      'PushRegistration(state: ${state.name}, token: ${token == null ? 'none' : 'present'})';
}
