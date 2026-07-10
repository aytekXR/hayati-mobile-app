// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Drives the auth state machine (docs/resume-prompt.md M1.1).
///
/// Precedence contract: while a manual operation (sign-in/sign-out) is in
/// flight it owns the state — repository stream emissions are ignored until
/// it settles, so Firebase's mid-flight emissions can't clobber
/// [AuthSigningIn] or race the operation's terminal state. When idle, the
/// stream is the single source of truth (session restore, remote sign-out).

@ProviderFor(AuthController)
const authControllerProvider = AuthControllerProvider._();

/// Drives the auth state machine (docs/resume-prompt.md M1.1).
///
/// Precedence contract: while a manual operation (sign-in/sign-out) is in
/// flight it owns the state — repository stream emissions are ignored until
/// it settles, so Firebase's mid-flight emissions can't clobber
/// [AuthSigningIn] or race the operation's terminal state. When idle, the
/// stream is the single source of truth (session restore, remote sign-out).
final class AuthControllerProvider
    extends $NotifierProvider<AuthController, AuthState> {
  /// Drives the auth state machine (docs/resume-prompt.md M1.1).
  ///
  /// Precedence contract: while a manual operation (sign-in/sign-out) is in
  /// flight it owns the state — repository stream emissions are ignored until
  /// it settles, so Firebase's mid-flight emissions can't clobber
  /// [AuthSigningIn] or race the operation's terminal state. When idle, the
  /// stream is the single source of truth (session restore, remote sign-out).
  const AuthControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authControllerHash();

  @$internal
  @override
  AuthController create() => AuthController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AuthState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AuthState>(value),
    );
  }
}

String _$authControllerHash() => r'43d544a55e6b848db44c0084569cf92d10238c02';

/// Drives the auth state machine (docs/resume-prompt.md M1.1).
///
/// Precedence contract: while a manual operation (sign-in/sign-out) is in
/// flight it owns the state — repository stream emissions are ignored until
/// it settles, so Firebase's mid-flight emissions can't clobber
/// [AuthSigningIn] or race the operation's terminal state. When idle, the
/// stream is the single source of truth (session restore, remote sign-out).

abstract class _$AuthController extends $Notifier<AuthState> {
  AuthState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AuthState, AuthState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AuthState, AuthState>,
              AuthState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
