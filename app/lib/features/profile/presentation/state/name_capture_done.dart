import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/storage/local_flag_key.dart';

part 'name_capture_done.g.dart';

/// The device-local "name capture completed" flag key (redesign QW-6), keyed
/// per uid so the flag never leaks across accounts on a shared device (the
/// coach-ack / coupleEndedSeen precedent). Set once the capture screen has
/// written the display name to the AUTH record — the gate then routes on to
/// profile capture and never shows the step again on this device. A reinstall
/// mid-onboarding re-shows the (pre-filled) step, which is honest and cheap;
/// an already-onboarded profile (`profile != null`) never reaches the step at
/// all, so existing users see nothing new.
LocalFlagKey nameCaptureDoneKey(String uid) =>
    LocalFlagKey.account(AccountFlag.nameCaptureDone, uid: uid);

/// The reactive CHANGE signal beside the durable flag — the exact
/// [CoupleEndedSeen] idiom: the gate reads the flag off [LocalFlagStore]
/// synchronously and watches this notifier so completing the capture
/// re-evaluates the gate without a restart. [markDone] bumps a version AFTER
/// the durable write lands.
@Riverpod(keepAlive: true)
class NameCaptureDone extends _$NameCaptureDone {
  @override
  int build() => 0;

  /// Bumps the version — call AFTER the durable [LocalFlagStore] write completes.
  void markDone() => state = state + 1;
}
