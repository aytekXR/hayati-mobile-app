// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'invite_share_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Drives the invite share screen. [build] issues the invite once (the
/// resulting `AsyncValue<IssuedInvite>` drives the three screen states, same
/// stream-consumer idiom as the OnboardingGate), [retry] re-runs it, and
/// [share] hands the composed message to the launcher seam.
///
/// autoDispose (screen-scoped like `ProfileCaptureController`): the invite is
/// issued when the screen first watches this and released when it leaves.

@ProviderFor(InviteShareController)
const inviteShareControllerProvider = InviteShareControllerProvider._();

/// Drives the invite share screen. [build] issues the invite once (the
/// resulting `AsyncValue<IssuedInvite>` drives the three screen states, same
/// stream-consumer idiom as the OnboardingGate), [retry] re-runs it, and
/// [share] hands the composed message to the launcher seam.
///
/// autoDispose (screen-scoped like `ProfileCaptureController`): the invite is
/// issued when the screen first watches this and released when it leaves.
final class InviteShareControllerProvider
    extends $AsyncNotifierProvider<InviteShareController, IssuedInvite> {
  /// Drives the invite share screen. [build] issues the invite once (the
  /// resulting `AsyncValue<IssuedInvite>` drives the three screen states, same
  /// stream-consumer idiom as the OnboardingGate), [retry] re-runs it, and
  /// [share] hands the composed message to the launcher seam.
  ///
  /// autoDispose (screen-scoped like `ProfileCaptureController`): the invite is
  /// issued when the screen first watches this and released when it leaves.
  const InviteShareControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: _noRetry,
        name: r'inviteShareControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$inviteShareControllerHash();

  @$internal
  @override
  InviteShareController create() => InviteShareController();
}

String _$inviteShareControllerHash() =>
    r'9a14c26b61b581407a18d6bd234a56967a8adf43';

/// Drives the invite share screen. [build] issues the invite once (the
/// resulting `AsyncValue<IssuedInvite>` drives the three screen states, same
/// stream-consumer idiom as the OnboardingGate), [retry] re-runs it, and
/// [share] hands the composed message to the launcher seam.
///
/// autoDispose (screen-scoped like `ProfileCaptureController`): the invite is
/// issued when the screen first watches this and released when it leaves.

abstract class _$InviteShareController extends $AsyncNotifier<IssuedInvite> {
  FutureOr<IssuedInvite> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<IssuedInvite>, IssuedInvite>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<IssuedInvite>, IssuedInvite>,
              AsyncValue<IssuedInvite>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
