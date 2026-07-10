// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'phone_sign_in_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Screen-scoped driver for the phone sign-in flow (docs/resume-prompt.md
/// M1.3). autoDispose: it is bound to the phone screen's lifetime and reset
/// on every fresh entry.
///
/// Precedence contract: this controller NEVER writes the global `AuthState`.
/// The phone flow has a user-input gap between sending and confirming the code
/// so it cannot be one atomic operation, and injecting intermediate states
/// into the global machine would corrupt its stream-vs-manual precedence. On a
/// successful confirm the controller deliberately stays in [PhoneConfirming]:
/// the terminal `AuthSignedIn` arrives on the `authStateChanges` stream while
/// the global `AuthController` is idle, and the screen is torn down then
/// (brief-3.md DESIGN).
///
/// [confirm]'s two purposeful branches: [AuthInvalidCodeException] keeps the
/// session so the user can re-enter the code inline; [AuthSessionExpiredException]
/// discards it so the UI restarts from phone entry.

@ProviderFor(PhoneSignInController)
const phoneSignInControllerProvider = PhoneSignInControllerProvider._();

/// Screen-scoped driver for the phone sign-in flow (docs/resume-prompt.md
/// M1.3). autoDispose: it is bound to the phone screen's lifetime and reset
/// on every fresh entry.
///
/// Precedence contract: this controller NEVER writes the global `AuthState`.
/// The phone flow has a user-input gap between sending and confirming the code
/// so it cannot be one atomic operation, and injecting intermediate states
/// into the global machine would corrupt its stream-vs-manual precedence. On a
/// successful confirm the controller deliberately stays in [PhoneConfirming]:
/// the terminal `AuthSignedIn` arrives on the `authStateChanges` stream while
/// the global `AuthController` is idle, and the screen is torn down then
/// (brief-3.md DESIGN).
///
/// [confirm]'s two purposeful branches: [AuthInvalidCodeException] keeps the
/// session so the user can re-enter the code inline; [AuthSessionExpiredException]
/// discards it so the UI restarts from phone entry.
final class PhoneSignInControllerProvider
    extends $NotifierProvider<PhoneSignInController, PhoneSignInState> {
  /// Screen-scoped driver for the phone sign-in flow (docs/resume-prompt.md
  /// M1.3). autoDispose: it is bound to the phone screen's lifetime and reset
  /// on every fresh entry.
  ///
  /// Precedence contract: this controller NEVER writes the global `AuthState`.
  /// The phone flow has a user-input gap between sending and confirming the code
  /// so it cannot be one atomic operation, and injecting intermediate states
  /// into the global machine would corrupt its stream-vs-manual precedence. On a
  /// successful confirm the controller deliberately stays in [PhoneConfirming]:
  /// the terminal `AuthSignedIn` arrives on the `authStateChanges` stream while
  /// the global `AuthController` is idle, and the screen is torn down then
  /// (brief-3.md DESIGN).
  ///
  /// [confirm]'s two purposeful branches: [AuthInvalidCodeException] keeps the
  /// session so the user can re-enter the code inline; [AuthSessionExpiredException]
  /// discards it so the UI restarts from phone entry.
  const PhoneSignInControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'phoneSignInControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$phoneSignInControllerHash();

  @$internal
  @override
  PhoneSignInController create() => PhoneSignInController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PhoneSignInState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PhoneSignInState>(value),
    );
  }
}

String _$phoneSignInControllerHash() =>
    r'0f2151fea4c794fccf0d6acc51f761a7aa8776cf';

/// Screen-scoped driver for the phone sign-in flow (docs/resume-prompt.md
/// M1.3). autoDispose: it is bound to the phone screen's lifetime and reset
/// on every fresh entry.
///
/// Precedence contract: this controller NEVER writes the global `AuthState`.
/// The phone flow has a user-input gap between sending and confirming the code
/// so it cannot be one atomic operation, and injecting intermediate states
/// into the global machine would corrupt its stream-vs-manual precedence. On a
/// successful confirm the controller deliberately stays in [PhoneConfirming]:
/// the terminal `AuthSignedIn` arrives on the `authStateChanges` stream while
/// the global `AuthController` is idle, and the screen is torn down then
/// (brief-3.md DESIGN).
///
/// [confirm]'s two purposeful branches: [AuthInvalidCodeException] keeps the
/// session so the user can re-enter the code inline; [AuthSessionExpiredException]
/// discards it so the UI restarts from phone entry.

abstract class _$PhoneSignInController extends $Notifier<PhoneSignInState> {
  PhoneSignInState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<PhoneSignInState, PhoneSignInState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<PhoneSignInState, PhoneSignInState>,
              PhoneSignInState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
