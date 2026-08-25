import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/storage/local_flag_key.dart';

part 'ritual_preview_seen.g.dart';

/// The device-local "ritual preview completed" flag key (redesign M-5,
/// ui-ux §5.1 step 1). DEVICE-scoped, not uid-scoped, deliberately: the
/// preview runs BEFORE sign-in, so no uid exists yet — and the 15-second
/// pitch is a first-launch device experience, not an account state. Set when
/// the user leaves the preview by either affordance ("Get started" or the
/// "Sign in" skip); never shown again after that (ui-ux §6.1).
final LocalFlagKey ritualPreviewSeenKey = LocalFlagKey.device(
  DeviceFlag.ritualPreviewSeen,
);

/// The reactive CHANGE signal beside the durable flag — the coupleEndedSeen /
/// nameCaptureDone idiom: `SignInScreen` reads the flag synchronously off
/// [LocalFlagStore] and watches this notifier, so completing the preview
/// swaps in the auth shell without a restart. [markSeen] bumps a version
/// AFTER the durable write lands.
@Riverpod(keepAlive: true)
class RitualPreviewSeen extends _$RitualPreviewSeen {
  @override
  int build() => 0;

  /// Bumps the version — call AFTER the durable [LocalFlagStore] write completes.
  void markSeen() => state = state + 1;
}
