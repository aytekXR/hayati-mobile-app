// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'join_invite_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Drives the "redeem a code" action on the join screen. Its state is an
/// `AsyncValue<String?>` mapping the flow's four positions (same AsyncValue
/// idiom as `InviteShareController`, so the screen switches on it directly):
///
/// - idle    — `AsyncData(null)` (the initial [build]; nothing attempted yet).
/// - in-flight — `AsyncLoading` (a join is running).
/// - error   — `AsyncError` carrying the typed [InviteException] the UI speaks
///             to (unknown code, expired, consumed, self-join, already-paired,
///             profile-missing, or the generic network/permission/unknown).
/// - success — `AsyncData(coupleId)` with a non-null `couples/{coupleId}` id.
///
/// autoDispose (screen-scoped, like `InviteShareController`); navigation on
/// success is the UI stage's concern — this controller only exposes the id.

@ProviderFor(JoinInviteController)
const joinInviteControllerProvider = JoinInviteControllerProvider._();

/// Drives the "redeem a code" action on the join screen. Its state is an
/// `AsyncValue<String?>` mapping the flow's four positions (same AsyncValue
/// idiom as `InviteShareController`, so the screen switches on it directly):
///
/// - idle    — `AsyncData(null)` (the initial [build]; nothing attempted yet).
/// - in-flight — `AsyncLoading` (a join is running).
/// - error   — `AsyncError` carrying the typed [InviteException] the UI speaks
///             to (unknown code, expired, consumed, self-join, already-paired,
///             profile-missing, or the generic network/permission/unknown).
/// - success — `AsyncData(coupleId)` with a non-null `couples/{coupleId}` id.
///
/// autoDispose (screen-scoped, like `InviteShareController`); navigation on
/// success is the UI stage's concern — this controller only exposes the id.
final class JoinInviteControllerProvider
    extends $AsyncNotifierProvider<JoinInviteController, String?> {
  /// Drives the "redeem a code" action on the join screen. Its state is an
  /// `AsyncValue<String?>` mapping the flow's four positions (same AsyncValue
  /// idiom as `InviteShareController`, so the screen switches on it directly):
  ///
  /// - idle    — `AsyncData(null)` (the initial [build]; nothing attempted yet).
  /// - in-flight — `AsyncLoading` (a join is running).
  /// - error   — `AsyncError` carrying the typed [InviteException] the UI speaks
  ///             to (unknown code, expired, consumed, self-join, already-paired,
  ///             profile-missing, or the generic network/permission/unknown).
  /// - success — `AsyncData(coupleId)` with a non-null `couples/{coupleId}` id.
  ///
  /// autoDispose (screen-scoped, like `InviteShareController`); navigation on
  /// success is the UI stage's concern — this controller only exposes the id.
  const JoinInviteControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'joinInviteControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$joinInviteControllerHash();

  @$internal
  @override
  JoinInviteController create() => JoinInviteController();
}

String _$joinInviteControllerHash() =>
    r'f10b0e430548179c16b9a06c0d3ed0b800e8f59c';

/// Drives the "redeem a code" action on the join screen. Its state is an
/// `AsyncValue<String?>` mapping the flow's four positions (same AsyncValue
/// idiom as `InviteShareController`, so the screen switches on it directly):
///
/// - idle    — `AsyncData(null)` (the initial [build]; nothing attempted yet).
/// - in-flight — `AsyncLoading` (a join is running).
/// - error   — `AsyncError` carrying the typed [InviteException] the UI speaks
///             to (unknown code, expired, consumed, self-join, already-paired,
///             profile-missing, or the generic network/permission/unknown).
/// - success — `AsyncData(coupleId)` with a non-null `couples/{coupleId}` id.
///
/// autoDispose (screen-scoped, like `InviteShareController`); navigation on
/// success is the UI stage's concern — this controller only exposes the id.

abstract class _$JoinInviteController extends $AsyncNotifier<String?> {
  FutureOr<String?> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<String?>, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<String?>, String?>,
              AsyncValue<String?>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
