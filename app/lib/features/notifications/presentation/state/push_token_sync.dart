import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../auth/domain/auth_state.dart';
import '../../../auth/presentation/state/auth_controller.dart';
import '../../domain/push_registration.dart';
import '../../domain/push_token_repository_provider.dart';
import '../../domain/push_token_source.dart';
import '../../domain/push_token_source_provider.dart';

part 'push_token_sync.g.dart';

/// Keeps the device's FCM registration token in lockstep with the auth state
/// (ADR-042 Decision 1/D6), on the `PurchasesIdentitySync` mold — and, since
/// ADR-046, publishes **why** it has no token when it has none.
///
/// [build] reads the CURRENT auth state and syncs it, THEN listens for
/// transitions — because `ref.listen` never fires for the value already present
/// and `AuthController.build()` seeds `AuthSignedIn` synchronously on a restored
/// session. A listen-only design would skip registration on every warm start,
/// which is the shape of the bug `PurchasesIdentitySync` was written to avoid.
///
/// **The value is a [PushRegistration], not a token (ADR-046 D2).** Four
/// distinct device-side failures — never prompted, declined, granted-but-no-token,
/// callable threw — used to be indistinguishable from each other and from
/// success, because every one of them ended in a `debugPrint` that a TestFlight
/// build routes nowhere. Each now has a name a screen can render and a user can
/// act on. The token is still carried inside that value, because it is
/// load-bearing for the privacy control below and must not be lost to a refactor
/// that was about display.
///
/// **The sign-out removal is a privacy control, not a cleanup task.** A token
/// that outlives a sign-out delivers the NEXT user's pushes to the PREVIOUS
/// user's phone. It is best-effort all the same: `registerPushToken` evicts the
/// token from every other user document server-side (ADR-042 D1), so the property
/// survives a sign-out whose cleanup never ran — a killed app, a revoked session,
/// a phone in a drawer. Registration is authoritative; this is the prompt path,
/// not the load-bearing one.
///
/// **It removes the token it registered, not one re-read at sign-out.** FCM can
/// rotate a token between sign-in and sign-out, and removing the new one would
/// leave the old one on the departing user's document — the exact leak the call
/// exists to prevent.
///
/// Nothing here can take down the tree or block a frame: ADR-039 D1 makes the
/// boot fail-open and D2 bounds every wait on the launch→paired path. A device
/// with no token yet is the normal pre-permission state, not an error, and a
/// failure to obtain or register one is a logged no-op exactly as App Check and
/// Crashlytics fail open where they stand.
///
/// Resolving [pushTokenSourceProvider] is deferred to the moment a sync actually
/// fires, so a signed-out lifecycle never touches it at all.
@Riverpod(keepAlive: true)
class PushTokenSync extends _$PushTokenSync {
  String? _syncedUid;

  /// Guards RE-ENTRANCY, not repetition (ADR-044 D3).
  ///
  /// This used to latch `true` *before* permission was even requested, so a
  /// capture that failed — which on iOS was the likely outcome, see
  /// [_captureAndRegister] — was permanent for the life of the process. It now
  /// only stops two prompts running at once; a granted permission whose capture
  /// did not produce a token stays retryable, and since ADR-046 D5 there are two
  /// ordinary things that retry it: an app resume on the paired home, and the
  /// user tapping *Try again* in Settings.
  ///
  /// Re-asking is cheap: iOS shows its dialog once per install and thereafter
  /// `requestPermission()` returns the standing answer without interrupting
  /// anyone, so this is a read rather than a second prompt.
  ///
  /// ⚠️ **It deliberately does NOT guard [_captureAndRegister].** A single
  /// shared guard reads as tidier and silently breaks the one call that matters:
  /// the boot-path capture runs for up to ~7.5s (ADR-044 D2), the paired home
  /// mounts inside that window, and a shared lock would make its
  /// [promptForPermissionAndRegister] return early — so the user would **never
  /// see the permission dialog at all** on the launch that was supposed to ask.
  /// Two concurrent captures are merely wasteful; a skipped prompt is the whole
  /// feature.
  bool _promptInFlight = false;

  /// Guards [refresh] against stacking. A resume and a settings mount can land
  /// in the same frame, and neither needs the other's answer.
  bool _refreshInFlight = false;

  /// The capture currently running, if any — so a second caller JOINS it rather
  /// than starting a duplicate.
  ///
  /// The boot capture (fired from `build()`) and the settings row's mount
  /// `refresh()` land in the same frame, and without this they both walked the
  /// loop and both registered the same token. Harmless on the server (ADR-042 D1
  /// de-duplicates and caps) and pure noise everywhere else — including in a
  /// test, where two identical registrations are indistinguishable from a bug.
  Future<void>? _capturing;

  /// The value [build] must return, kept in step with [state].
  ///
  /// A notifier may not assign `state` while `build()` is on the stack, and the
  /// initial sync is issued from there — so every transition goes through
  /// [_emit], which writes this field always and `state` only once building is
  /// over.
  PushRegistration _current = PushRegistration.unknown;

  /// True only while [build] is on the stack.
  ///
  /// **A flag rather than an `initial` parameter threaded through every path,**
  /// because the two are not the same question and the parameter answered the
  /// wrong one. The sign-out path emits SYNCHRONOUSLY from `build()` and must
  /// not touch `state`; the capture path is async, so its first `await` returns
  /// control to `build()` long before it emits — and gating it on the same
  /// `initial` flag meant a warm start registered a token and **never published
  /// it**, which was invisible while nothing read the value and is a blank
  /// settings row now that something does.
  bool _building = false;

  /// The token this provider last registered — the one sign-out must remove.
  String? get _registeredToken => _current.token;

  StreamSubscription<String>? _refreshes;

  @override
  PushRegistration build() {
    _building = true;
    try {
      _syncFrom(ref.read(authControllerProvider));
      ref.listen(authControllerProvider, (_, next) => _syncFrom(next));
      ref.onDispose(() {
        unawaited(_refreshes?.cancel());
        _refreshes = null;
      });
    } finally {
      _building = false;
    }
    return _current;
  }

  void _emit(PushRegistration next) {
    _current = next;
    if (!_building) state = next;
  }

  /// Emit a NON-success state, unless a token has already been registered.
  ///
  /// **Two captures can be in flight at once and only one of them can be right.**
  /// `promptForPermissionAndRegister` deliberately starts a FRESH run rather than
  /// joining the boot capture (joining would spend the user's tap on a run that
  /// began before the grant and may be on its last attempt) — so the boot run can
  /// finish, empty, a moment AFTER the prompt's run succeeded. Without this
  /// guard it would then overwrite `registered` with `awaitingDeviceToken` and
  /// show a **Try again** button to a phone that is already reachable.
  ///
  /// A late failure never demotes a success: the token is the evidence, and
  /// nothing here produced better evidence than the run that got one.
  void _emitUnlessRegistered(PushRegistrationState next) {
    if (_registeredToken != null) return;
    _emit(PushRegistration(state: next));
  }

  void _syncFrom(AuthState authState) {
    if (authState is AuthSignedIn) {
      final uid = authState.user.uid;
      if (_syncedUid == uid) return;
      _syncedUid = uid;
      _listenForRefreshes();
      unawaited(_captureAndRegister());
    } else if (authState is AuthSignedOut) {
      if (_syncedUid == null) return;
      _syncedUid = null;
      unawaited(_removeRegistered());
    }
    // AuthSigningIn / AuthError are transient and drive no action — the same
    // rule PurchasesIdentitySync applies, and here it also keeps a token read
    // off the sign-in critical path.
  }

  /// Subscribes once. A rotation invalidates the previous token, so each event is
  /// a full re-registration rather than an addition — the server de-duplicates
  /// and caps regardless (ADR-042 D1), so a redundant register is cheap and a
  /// missed one is not.
  void _listenForRefreshes() {
    if (_refreshes != null) return;
    try {
      _refreshes = ref
          .read(pushTokenSourceProvider)
          .tokenRefreshes()
          .listen(
            (token) => unawaited(_register(token)),
            onError: (Object failure) {
              debugPrint('PushTokenSync.tokenRefreshes failed: $failure');
            },
          );
    } catch (failure) {
      // No source overridden yet, or the plugin failed to initialize. Either
      // way: no pushes, no crash.
      debugPrint('PushTokenSync.tokenRefreshes unavailable: $failure');
    }
  }

  /// Re-read where this device stands, WITHOUT asking the user anything
  /// (ADR-046 D1/D5).
  ///
  /// **Safe on every mount and every resume**, which is the point:
  /// `permissionStatus()` reads the standing answer and shows no dialog, so this
  /// can run on the dominant path back from the iOS Settings app — the one route
  /// by which a `denied` permission ever becomes `granted` — and pick the
  /// capture back up where the bounded retry left it.
  ///
  /// Returns the settled state, for callers that want to render on it.
  Future<PushRegistration> refresh() async {
    if (_refreshInFlight) return _current;
    _refreshInFlight = true;
    try {
      return await _refresh();
    } finally {
      _refreshInFlight = false;
    }
  }

  Future<PushRegistration> _refresh() async {
    if (_syncedUid == null) {
      _emit(PushRegistration.unknown);
      return _current;
    }
    if (_registeredToken != null) return _current;

    final PushTokenSource source;
    try {
      source = ref.read(pushTokenSourceProvider);
    } catch (failure) {
      debugPrint('PushTokenSync.refresh: no push token source: $failure');
      return _current;
    }

    final PushPermission permission;
    try {
      permission = await source.permissionStatus();
    } catch (failure) {
      debugPrint('PushTokenSync.refresh failed: ${failure.runtimeType}');
      return _current;
    }

    switch (permission) {
      case PushPermission.denied:
        _emitUnlessRegistered(PushRegistrationState.denied);
      case PushPermission.notDetermined:
        _emitUnlessRegistered(PushRegistrationState.notDetermined);
      case PushPermission.granted:
        // Permission is held and there is still no token: this is the ADR-044
        // window, or the link ADR-046 D6 hardened. Either way the honest
        // response is another bounded attempt, not a shrug — joining one that is
        // already running if there is one.
        await _captureAndRegister();
    }
    return _current;
  }

  /// Ask for notification permission, and register the token if it is granted.
  ///
  /// **The call that makes the rest of this file do anything on iOS.** Without a
  /// permission grant `getToken()` returns nothing, so every other piece —
  /// entitlement, plugin, callables, sweeps — is correct and silent.
  ///
  /// Called from the paired home screen, per ADR-042 D6: after pairing, on a
  /// screen that has shown the user what the app is for, and never during boot.
  /// Fire-and-forget by contract — it must never block a frame (ADR-039 D2) and
  /// it never throws.
  ///
  /// **A decline is now recorded, not just logged** (ADR-046 D2). iOS shows its
  /// dialog once per install; after a decline this method can never succeed
  /// again, and the only remaining fix is the Settings app. Leaving that as a
  /// `debugPrint` is what made five sessions unable to tell a declined prompt
  /// from a build nobody installed.
  ///
  /// Returns whether permission is now held, for callers that want to render
  /// differently; the registration is the side effect that matters.
  Future<bool> promptForPermissionAndRegister() async {
    // Already holding a token: nothing to ask and nothing to do.
    if (_registeredToken != null) return true;
    if (_promptInFlight) return false;
    _promptInFlight = true;
    try {
      final granted = await ref
          .read(pushTokenSourceProvider)
          .ensurePermission();
      if (!granted) {
        // A user who declines is an ordinary outcome, not a failure — the app
        // works exactly as it did before push existed. It is nevertheless a
        // state worth NAMING, because it is the one no future build can undo.
        debugPrint('PushTokenSync: notification permission not granted');
        _emitUnlessRegistered(PushRegistrationState.denied);
        return false;
      }
      // Permission is what was missing; the token can be captured now — but on
      // iOS not necessarily THIS instant, which is what the bounded retry is
      // for. The refresh subscription was already attached at sign-in.
      //
      // A FRESH run, deliberately not joining an in-flight one: the boot capture
      // started BEFORE this grant and may be on its last attempt, so joining it
      // would spend the user's tap on a run that was already doomed and leave
      // them looking at "try again" one second after they said yes.
      await _capture();
      return _registeredToken != null;
    } catch (failure) {
      debugPrint(
        'PushTokenSync.promptForPermission failed: ${failure.runtimeType}',
      );
      return false;
    } finally {
      _promptInFlight = false;
    }
  }

  /// How many times capture is attempted before giving up, and the base of the
  /// linear backoff between attempts (ADR-044 D2).
  ///
  /// **Bounded, because ADR-039 D2 requires every wait on the launch→paired path
  /// to be** — worst case 0.5+1.0+1.5+2.0+2.5 ≈ 7.5s, issued `unawaited` from a
  /// post-frame callback, so it can never delay a frame. A device that will
  /// never produce a token pays that once, in the background, and stops.
  ///
  /// **Bounded is not once-only** (ADR-046 D5): exhausting the loop leaves the
  /// state at [PushRegistrationState.awaitingDeviceToken], and an app resume or
  /// a *Try again* tap starts a fresh bounded run. An unbounded background loop
  /// was the rejected alternative — it turns a provable cost into a timer that
  /// outlives every screen.
  ///
  /// Overridable so the retry is PROVEN in milliseconds rather than asserted.
  @visibleForTesting
  static int tokenCaptureAttempts = 6;
  @visibleForTesting
  static Duration tokenCaptureBackoff = const Duration(milliseconds: 500);

  /// Capture the token once the platform can actually produce one, then register.
  ///
  /// **This is the fix for the bug that kept the whole feature at zero
  /// (ADR-044).** iOS mints an FCM token only after APNs answers, which happens
  /// *after* the permission grant returns — so the old single call, issued the
  /// instant permission was granted, sat inside the exact window where iOS
  /// guarantees `getToken()` throws. It caught, logged, and never tried again.
  ///
  /// A throw is therefore **"not yet", never "never"**: the loop asks the port
  /// whether the platform is ready, and treats both a throw and a null token as
  /// a reason to wait rather than a reason to stop.
  Future<void> _captureAndRegister() {
    final running = _capturing;
    if (running != null) return running;
    late final Future<void> started;
    started = _capture().whenComplete(() {
      if (identical(_capturing, started)) _capturing = null;
    });
    _capturing = started;
    return started;
  }

  Future<void> _capture() async {
    // Resolving the SOURCE is not a transient failure and must not be retried.
    // There is either an implementation wired at bootstrap or there is not, and
    // no amount of backoff conjures one — every widget test that builds the app
    // without overriding it lands here.
    //
    // Keeping this inside the loop scheduled five pointless timers in exactly
    // those containers, and `pumpAndSettle` never settles while a timer is
    // pending: it took 60 unrelated widget tests red. The retry below is for a
    // source that EXISTS and is not ready yet, which is a different thing.
    final PushTokenSource source;
    try {
      source = ref.read(pushTokenSourceProvider);
    } catch (failure) {
      debugPrint('PushTokenSync: no push token source: $failure');
      return;
    }
    for (var attempt = 0; attempt < tokenCaptureAttempts; attempt++) {
      try {
        if (await source.isReadyForToken()) {
          final token = await source.currentToken();
          if (token != null && token.isNotEmpty) {
            await _register(token);
            return;
          }
        }
      } catch (failure) {
        // Includes the iOS `apns-token-not-set` throw this loop exists for.
        debugPrint(
          'PushTokenSync.currentToken attempt $attempt failed: $failure',
        );
      }
      // A signed-out user mid-retry has nothing left to register to; stop rather
      // than hold a timer open for an account that is gone.
      if (_syncedUid == null) return;
      if (attempt < tokenCaptureAttempts - 1) {
        await Future<void>.delayed(tokenCaptureBackoff * (attempt + 1));
      }
    }
    debugPrint(
      'PushTokenSync: no push token after $tokenCaptureAttempts attempts — '
      'the device has no APNs registration yet, or permission was declined',
    );
    // ⚠️ ASK, do not assume. That sentence names TWO different failures and the
    // loop cannot tell them apart — so this used to emit `awaitingDeviceToken`
    // unconditionally, which labels a DECLINED phone "allowed, just not finished
    // yet" and offers it a Try again button that can never work. Putting a
    // confident wrong answer where the honest one was missing is the defect this
    // whole ADR is about, reintroduced one level down.
    //
    // It also makes the settled state independent of ORDERING: a concurrent
    // `refresh()` that already wrote `denied` is no longer overwritten by this
    // loop finishing a moment later.
    _emitUnlessRegistered(await _stateForCurrentPermission(source));
  }

  /// The honest state for a device that has no token, read from the OS.
  Future<PushRegistrationState> _stateForCurrentPermission(
    PushTokenSource source,
  ) async {
    try {
      return switch (await source.permissionStatus()) {
        PushPermission.denied => PushRegistrationState.denied,
        PushPermission.notDetermined => PushRegistrationState.notDetermined,
        // Permission is held and there is still no address: the ADR-044 window,
        // or the link ADR-046 D6 hardened. A retry is the honest offer.
        PushPermission.granted => PushRegistrationState.awaitingDeviceToken,
      };
    } catch (failure) {
      debugPrint(
        'PushTokenSync.permissionStatus failed: ${failure.runtimeType}',
      );
      return PushRegistrationState.awaitingDeviceToken;
    }
  }

  Future<void> _register(String token) async {
    // A refresh that arrives while signed out must register nothing: the
    // callable would attach the token to whoever happens to be signed in next.
    if (_syncedUid == null) return;
    try {
      await ref.read(pushTokenRepositoryProvider).register(token);
      _emit(
        PushRegistration(state: PushRegistrationState.registered, token: token),
      );
    } catch (failure) {
      debugPrint('PushTokenSync.register failed: ${failure.runtimeType}');
      // The device HAS an address and the server does not. That is a different
      // failure from "no address yet", but it has the same remedy — try again —
      // and the same user-facing sentence, so it shares the state rather than
      // inventing a fifth one nobody could act on differently.
      _emitUnlessRegistered(PushRegistrationState.awaitingDeviceToken);
    }
  }

  Future<void> _removeRegistered() async {
    final token = _registeredToken;
    _emit(PushRegistration.unknown);
    if (token == null) return;
    try {
      await ref.read(pushTokenRepositoryProvider).unregister(token);
    } catch (failure) {
      debugPrint('PushTokenSync.unregister failed: ${failure.runtimeType}');
    }
  }
}
