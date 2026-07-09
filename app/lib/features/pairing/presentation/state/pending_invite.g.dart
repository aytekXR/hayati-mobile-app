// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pending_invite.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The invite code captured from a `hayati://invite/<code>` deep link, or null
/// when none is pending. keepAlive + activated from the app root (app.dart) so
/// a cold-start link — delivered before any pairing screen mounts — is caught
/// and held, not dropped. State only this session: the join flow (M2.3)
/// consumes the code from here.
///
/// [build] subscribes to warm links and, in parallel, resolves the cold-start
/// link (same stream-in-build + `ref.onDispose` discipline as `AuthController`).
/// Every URL runs through [inviteCodeFromUri]; a valid code replaces the state
/// (last wins) and an invalid one is ignored.

@ProviderFor(PendingInvite)
const pendingInviteProvider = PendingInviteProvider._();

/// The invite code captured from a `hayati://invite/<code>` deep link, or null
/// when none is pending. keepAlive + activated from the app root (app.dart) so
/// a cold-start link — delivered before any pairing screen mounts — is caught
/// and held, not dropped. State only this session: the join flow (M2.3)
/// consumes the code from here.
///
/// [build] subscribes to warm links and, in parallel, resolves the cold-start
/// link (same stream-in-build + `ref.onDispose` discipline as `AuthController`).
/// Every URL runs through [inviteCodeFromUri]; a valid code replaces the state
/// (last wins) and an invalid one is ignored.
final class PendingInviteProvider
    extends $NotifierProvider<PendingInvite, String?> {
  /// The invite code captured from a `hayati://invite/<code>` deep link, or null
  /// when none is pending. keepAlive + activated from the app root (app.dart) so
  /// a cold-start link — delivered before any pairing screen mounts — is caught
  /// and held, not dropped. State only this session: the join flow (M2.3)
  /// consumes the code from here.
  ///
  /// [build] subscribes to warm links and, in parallel, resolves the cold-start
  /// link (same stream-in-build + `ref.onDispose` discipline as `AuthController`).
  /// Every URL runs through [inviteCodeFromUri]; a valid code replaces the state
  /// (last wins) and an invalid one is ignored.
  const PendingInviteProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pendingInviteProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pendingInviteHash();

  @$internal
  @override
  PendingInvite create() => PendingInvite();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$pendingInviteHash() => r'3d77221890523914da88e8997ed65ee4aad7055e';

/// The invite code captured from a `hayati://invite/<code>` deep link, or null
/// when none is pending. keepAlive + activated from the app root (app.dart) so
/// a cold-start link — delivered before any pairing screen mounts — is caught
/// and held, not dropped. State only this session: the join flow (M2.3)
/// consumes the code from here.
///
/// [build] subscribes to warm links and, in parallel, resolves the cold-start
/// link (same stream-in-build + `ref.onDispose` discipline as `AuthController`).
/// Every URL runs through [inviteCodeFromUri]; a valid code replaces the state
/// (last wins) and an invalid one is ignored.

abstract class _$PendingInvite extends $Notifier<String?> {
  String? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<String?, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String?, String?>,
              String?,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
