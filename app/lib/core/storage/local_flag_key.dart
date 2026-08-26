/// The CLOSED vocabulary of device-local flags, split by who owns them
/// (ADR-061 Decision 4).
///
/// The split is two enums rather than one enum with a `scope` field on purpose:
/// a field needs an `assert` to bind the key constructor to the scope, and an
/// `assert` is a debug-only guarantee. Two types are a compile-time one. A flag
/// cannot reach [LocalFlagStore] without a [LocalFlagKey], and a [LocalFlagKey]
/// cannot exist without a value from one of these — so **adding a flag without
/// answering "account or device?" does not compile**, which is the whole point:
/// the previous design put that question in a test, and the design review found
/// four of six key-builder files that the test could not see.
library;

/// A flag an ACCOUNT owns.
///
/// Every one of these is removed from this device when that account is deleted
/// (ADR-061 D1). Adding a value here IS the act of classifying it — there is no
/// second list to keep in sync, and `local_flag_key_test.dart` iterates
/// [values] rather than a hand-written copy of them.
///
/// The string is the key's PREFIX; [LocalFlagKey.account] appends the uid as its
/// own dot segment. Changing one of these strings changes a key that already
/// exists on real devices — see the byte-for-byte pin in `analytics_test.dart`.
enum AccountFlag {
  signup('analytics.signup'),
  paired('analytics.paired'),
  qAnswered('analytics.q'),
  revealViewed('analytics.reveal'),
  streakDay('analytics.streak'),
  coachDisclaimerAck('coachDisclaimerAck'),
  coupleEndedSeen('coupleEndedSeen'),
  nameCaptureDone('nameCaptureDone'),
  privacySpotlightSeen('privacySpotlightSeen');

  const AccountFlag(this.prefix);

  /// The key text before the uid segment.
  final String prefix;
}

/// A flag the DEVICE owns, which SURVIVES an account deletion — deliberately.
///
/// Both members carry no identifier and describe the phone rather than a person:
/// this device did install the app once, and did see the pre-sign-in preview
/// once. Clearing either would be a counting error (a second `install` from one
/// phone) or a re-shown first-launch pitch, and would delete nothing personal.
///
/// The string is the WHOLE key: a device flag has no uid segment to append, and
/// that is why the deletion sweep cannot reach one by construction.
enum DeviceFlag {
  install('analytics.install'),
  ritualPreviewSeen('ritualPreviewSeen');

  const DeviceFlag(this.value);

  /// The complete key text.
  final String value;
}

/// A key for [LocalFlagStore] — and the only way to make one (ADR-061 D4).
final class LocalFlagKey {
  /// A device flag. Survives an account deletion.
  LocalFlagKey.device(DeviceFlag flag) : value = flag.value;

  /// An account flag.
  ///
  /// [uid] is placed as its own dot segment, and [parts] follow it. That is not
  /// a convention this constructor happens to follow — it is the only shape it
  /// can produce, which is what makes [localFlagKeyBelongsTo], and therefore the
  /// deletion sweep, TOTAL rather than best-effort.
  ///
  /// [parts] are event coordinates (a coupleId, a dayKey, an answer mode), never
  /// uids. The predicate cannot tell the difference, so a `parts` entry that
  /// happened to equal ANOTHER account's uid would take this key with it —
  /// Firestore auto-ids are 20 characters and Firebase uids 28, so they do not
  /// collide today (ADR-061 D4, recorded bound).
  LocalFlagKey.account(
    AccountFlag flag, {
    required String uid,
    List<String> parts = const [],
  }) : value = [flag.prefix, uid, ...parts].join('.');

  /// The persisted key text. Byte-identical to what shipped before ADR-061.
  final String value;

  @override
  bool operator ==(Object other) =>
      other is LocalFlagKey && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

/// Whether [key] is a flag the account [uid] owns — the single definition the
/// store, both implementations and the tests all read (the ADR-052 idiom).
///
/// A key belongs to a uid when the uid is one of its **dot-delimited segments**.
/// Both sides are wrapped in dots so a uid that is a string PREFIX of another
/// cannot match it: `u1` must not claim `coachDisclaimerAck.u12`, and on a
/// shared device that difference is one account deleting another's data.
///
/// An empty [uid] matches nothing — a wildcard here would be the worst outcome
/// available (ADR-061 D3).
bool localFlagKeyBelongsTo(String key, String uid) =>
    uid.isNotEmpty && '.$key.'.contains('.$uid.');
