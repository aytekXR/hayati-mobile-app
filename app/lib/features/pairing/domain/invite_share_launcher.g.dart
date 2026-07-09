// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'invite_share_launcher.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the app's [InviteShareLauncher].
///
/// Deliberately unimplemented at the base (same contract as
/// `inviteRepositoryProvider`): the flavor entrypoints override it with the
/// share_plus-backed adapter, and tests override it per container with a fake.

@ProviderFor(inviteShareLauncher)
const inviteShareLauncherProvider = InviteShareLauncherProvider._();

/// Provides the app's [InviteShareLauncher].
///
/// Deliberately unimplemented at the base (same contract as
/// `inviteRepositoryProvider`): the flavor entrypoints override it with the
/// share_plus-backed adapter, and tests override it per container with a fake.

final class InviteShareLauncherProvider
    extends
        $FunctionalProvider<
          InviteShareLauncher,
          InviteShareLauncher,
          InviteShareLauncher
        >
    with $Provider<InviteShareLauncher> {
  /// Provides the app's [InviteShareLauncher].
  ///
  /// Deliberately unimplemented at the base (same contract as
  /// `inviteRepositoryProvider`): the flavor entrypoints override it with the
  /// share_plus-backed adapter, and tests override it per container with a fake.
  const InviteShareLauncherProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'inviteShareLauncherProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$inviteShareLauncherHash();

  @$internal
  @override
  $ProviderElement<InviteShareLauncher> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  InviteShareLauncher create(Ref ref) {
    return inviteShareLauncher(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(InviteShareLauncher value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<InviteShareLauncher>(value),
    );
  }
}

String _$inviteShareLauncherHash() =>
    r'6b05cc2a715728123f00e0fd303b976a74e89248';
