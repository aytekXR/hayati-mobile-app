import '../../../core/storage/local_flag_key.dart';

/// The per-device, per-uid local-flag key under which the coach disclaimer
/// acknowledgement is recorded (ADR-017 Decision 4). uid-namespaced so a second
/// account signing in on the same device is shown the "not therapy" safety note
/// on first open — never silently inheriting the other user's ack (the DV-aware
/// choice analyzed in the ADR: a device-level key would under-show the note to
/// the second partner). Consumed through `LocalFlagStore` by the disclaimer gate.
LocalFlagKey coachDisclaimerAckKey(String uid) =>
    LocalFlagKey.account(AccountFlag.coachDisclaimerAck, uid: uid);
