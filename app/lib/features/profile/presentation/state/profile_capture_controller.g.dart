// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_capture_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Drives [ProfileRepository.saveProfile] with the same manual-op discipline
/// as `AuthController`: re-entrant saves are dropped while one is in flight,
/// and every await is followed by a `ref.mounted` guard (Riverpod 3).

@ProviderFor(ProfileCaptureController)
const profileCaptureControllerProvider = ProfileCaptureControllerProvider._();

/// Drives [ProfileRepository.saveProfile] with the same manual-op discipline
/// as `AuthController`: re-entrant saves are dropped while one is in flight,
/// and every await is followed by a `ref.mounted` guard (Riverpod 3).
final class ProfileCaptureControllerProvider
    extends $NotifierProvider<ProfileCaptureController, CaptureState> {
  /// Drives [ProfileRepository.saveProfile] with the same manual-op discipline
  /// as `AuthController`: re-entrant saves are dropped while one is in flight,
  /// and every await is followed by a `ref.mounted` guard (Riverpod 3).
  const ProfileCaptureControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'profileCaptureControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$profileCaptureControllerHash();

  @$internal
  @override
  ProfileCaptureController create() => ProfileCaptureController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CaptureState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CaptureState>(value),
    );
  }
}

String _$profileCaptureControllerHash() =>
    r'd075f091041660654aa87a9134d0977696e7eb67';

/// Drives [ProfileRepository.saveProfile] with the same manual-op discipline
/// as `AuthController`: re-entrant saves are dropped while one is in flight,
/// and every await is followed by a `ref.mounted` guard (Riverpod 3).

abstract class _$ProfileCaptureController extends $Notifier<CaptureState> {
  CaptureState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<CaptureState, CaptureState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<CaptureState, CaptureState>,
              CaptureState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
