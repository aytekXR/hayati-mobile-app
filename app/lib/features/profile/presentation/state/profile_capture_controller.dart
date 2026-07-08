import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/profile_exception.dart';
import '../../domain/profile_repository_provider.dart';
import '../../domain/relationship_profile.dart';

part 'profile_capture_controller.g.dart';

/// Save-flow state for the capture screen (idle → saving → idle | failure).
/// Success needs no state of its own: the saved doc flows back through
/// `profileStreamProvider` and the OnboardingGate swaps screens.
sealed class CaptureState {
  const CaptureState();
}

final class CaptureIdle extends CaptureState {
  const CaptureIdle();
}

final class CaptureSaving extends CaptureState {
  const CaptureSaving();
}

final class CaptureFailure extends CaptureState {
  const CaptureFailure(this.failure);

  final ProfileException failure;
}

/// Drives [ProfileRepository.saveProfile] with the same manual-op discipline
/// as `AuthController`: re-entrant saves are dropped while one is in flight,
/// and every await is followed by a `ref.mounted` guard (Riverpod 3).
@riverpod
class ProfileCaptureController extends _$ProfileCaptureController {
  @override
  CaptureState build() => const CaptureIdle();

  Future<void> save(String uid, RelationshipProfile profile) async {
    if (state is CaptureSaving) return;
    state = const CaptureSaving();
    try {
      await ref.read(profileRepositoryProvider).saveProfile(uid, profile);
      if (!ref.mounted) return;
      state = const CaptureIdle();
    } on ProfileException catch (failure) {
      if (!ref.mounted) return;
      state = CaptureFailure(failure);
    }
  }
}
