import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/core/storage/local_flag_key.dart';
import 'package:hayati_app/features/auth/presentation/state/ritual_preview_seen.dart';
import 'package:hayati_app/features/coach/domain/coach_disclaimer.dart';
import 'package:hayati_app/features/data_rights/presentation/state/couple_ended_seen.dart';
import 'package:hayati_app/features/profile/presentation/state/name_capture_done.dart';
import 'package:hayati_app/features/settings/presentation/widgets/privacy_spotlight_card.dart';

/// The ADR-061 Decision 4 guard: the classification of every device-local flag,
/// and the predicate the account deletion sweeps with.
///
/// **The fixture IS the vocabulary.** Every assertion below iterates
/// `AccountFlag.values` / `DeviceFlag.values` rather than a hand-written copy of
/// them, because a hand-written copy is a fixture derived from its own subject
/// and cannot detect the drift it exists to detect (`session-lessons.md`
/// recurring shape 4; `funnel_event.dart` says the same about itself). Revision
/// 2 of ADR-061 proposed exactly such a list and the design review blocked it.
///
/// **What this file deliberately does NOT do** is check that the app's flags are
/// all *in* the vocabulary. It cannot be evaded, so it does not need to be
/// checked: `LocalFlagStore` takes a [LocalFlagKey], a [LocalFlagKey] is built
/// only from an [AccountFlag] or a [DeviceFlag], and a raw `String` does not
/// compile. That is the whole reason the classification moved out of a test.
void main() {
  // Two uids where the first is a strict string PREFIX of the second. This pair
  // is the point of the file: `key.contains(uid)` — the obvious, wrong
  // predicate — passes every single-uid assertion and fails here, and on a
  // shared device the difference is one account deleting another's data.
  const uid = 'u1';
  const otherUid = 'u12';

  group('the vocabulary is non-empty and split', () {
    // Lesson 110: every assertion below is a loop over these, so an empty
    // vocabulary would make all of them vacuously true.
    test('both enums carry members', () {
      expect(AccountFlag.values, isNotEmpty);
      expect(DeviceFlag.values, isNotEmpty);
      expect(AccountFlag.values, hasLength(9));
      expect(DeviceFlag.values, hasLength(2));
    });

    test('no prefix is shared between the two scopes', () {
      final device = DeviceFlag.values.map((f) => f.value).toSet();
      for (final flag in AccountFlag.values) {
        expect(
          device,
          isNot(contains(flag.prefix)),
          reason:
              '${flag.name} is account-scoped but shares its text with a device '
              'flag — one of the two classifications is wrong',
        );
      }
    });
  });

  group('every ACCOUNT flag is reachable by its own account and no other', () {
    test('the uid lands as a whole dot segment, for every member', () {
      for (final flag in AccountFlag.values) {
        final key = LocalFlagKey.account(flag, uid: uid).value;
        expect(
          key.split('.'),
          contains(uid),
          reason: '${flag.name} did not place the uid as a segment: $key',
        );
        expect(
          localFlagKeyBelongsTo(key, uid),
          isTrue,
          reason: '${flag.name} would SURVIVE its own account deletion: $key',
        );
      }
    });

    test('a uid that is a string prefix of another never claims its keys', () {
      for (final flag in AccountFlag.values) {
        final key = LocalFlagKey.account(flag, uid: otherUid).value;
        expect(
          localFlagKeyBelongsTo(key, uid),
          isFalse,
          reason:
              'deleting "$uid" would take "$otherUid"\'s ${flag.name} flag '
              '($key) — the predicate is matching a substring, not a segment',
        );
      }
    });

    test('trailing coordinates do not detach the uid', () {
      // `parts` is where a coupleId / dayKey / mode goes. The uid must still be
      // its own segment with anything after it.
      for (final flag in AccountFlag.values) {
        final key = LocalFlagKey.account(
          flag,
          uid: uid,
          parts: const ['c1', '20260818', 'solo'],
        ).value;
        expect(localFlagKeyBelongsTo(key, uid), isTrue, reason: key);
        expect(localFlagKeyBelongsTo(key, otherUid), isFalse, reason: key);
      }
    });
  });

  group('every DEVICE flag survives every deletion', () {
    test('no device flag is claimed by an account', () {
      // Firebase uids are 28 characters of [A-Za-z0-9]; the short ones are the
      // shapes this repo's own tests use.
      const uids = [
        'u1',
        'u12',
        'uid-1',
        'aBcDeFgHiJkLmNoPqRsTuVwXyZ01',
        '9U4VUVRV3kQm2Zx7Lp0aWnTdEjHb',
      ];
      for (final flag in DeviceFlag.values) {
        for (final candidate in uids) {
          expect(
            localFlagKeyBelongsTo(flag.value, candidate),
            isFalse,
            reason:
                '${flag.name} (${flag.value}) would be deleted with account '
                '"$candidate" — a device flag must carry no account segment',
          );
        }
      }
    });

    test(
      'the bound: a uid EQUAL to a literal key segment would match, and cannot '
      'happen',
      () {
        // Found by this file's first draft, which used 'analytics' as a
        // candidate uid and went red. The predicate matches dot SEGMENTS, so an
        // account whose uid were literally `analytics` or `install` would take
        // `analytics.install` with it. Asserted rather than deleted, because a
        // silent property is how the next author rediscovers it: the guarantee
        // is not "device flags are unreachable", it is "no Firebase uid is a
        // word", and those are different sentences.
        expect(localFlagKeyBelongsTo('analytics.install', 'analytics'), isTrue);
        expect(localFlagKeyBelongsTo('analytics.install', 'install'), isTrue);
        // Checked over BOTH vocabularies, not just the device one. The
        // collision is symmetric — an AccountFlag prefix segment that could be
        // a uid would take another account's key on the same device — and a
        // guard that covers one path and is silent on the other is
        // `session-lessons.md` recurring shape 5.
        final segments = [
          for (final flag in DeviceFlag.values) ...flag.value.split('.'),
          for (final flag in AccountFlag.values) ...flag.prefix.split('.'),
        ];
        expect(segments, hasLength(greaterThan(11)));
        for (final segment in segments) {
          expect(
            segment,
            matches(RegExp(r'^[a-z][A-Za-z]*$')),
            reason:
                '"$segment" could be mistaken for a Firebase uid (28 chars of '
                '[A-Za-z0-9]); the collision above stops being hypothetical',
          );
          expect(segment.length, lessThan(28));
        }
      },
    );
  });

  group('the predicate refuses the degenerate case', () {
    test('an empty uid matches nothing, including empty segments', () {
      expect(localFlagKeyBelongsTo('analytics.install', ''), isFalse);
      expect(localFlagKeyBelongsTo('coachDisclaimerAck.u1', ''), isFalse);
      // A key that somehow carried an empty segment must not become a wildcard.
      expect(localFlagKeyBelongsTo('analytics..install', ''), isFalse);
    });

    test('a uid is not matched inside a longer segment', () {
      expect(localFlagKeyBelongsTo('coachDisclaimerAck.xu1', uid), isFalse);
      expect(localFlagKeyBelongsTo('coachDisclaimerAck.u1x', uid), isFalse);
      expect(localFlagKeyBelongsTo('coachDisclaimerAck.u1', uid), isTrue);
    });

    test('a whole-key match still counts', () {
      // Not a shape the app produces, but the predicate must not depend on
      // there being text on either side.
      expect(localFlagKeyBelongsTo(uid, uid), isTrue);
    });
  });

  group('every key text is the one already on real devices', () {
    // The byte-for-byte pin, and the reason this group is not a formality:
    // these keys live in SharedPreferences ACROSS app updates. A one-character
    // drift in a prefix does not fail — it silently re-shows the coach
    // disclaimer, the name step or the privacy spotlight to every existing
    // user, and re-emits a once-only funnel event for each of them, on the
    // version that "fixed" it. `analytics_test.dart` pins the six analytics
    // keys the same way through the emitter, independently of this table.
    test('every AccountFlag prefix is the shipped text', () {
      const shipped = <AccountFlag, String>{
        AccountFlag.signup: 'analytics.signup',
        AccountFlag.paired: 'analytics.paired',
        AccountFlag.qAnswered: 'analytics.q',
        AccountFlag.revealViewed: 'analytics.reveal',
        AccountFlag.streakDay: 'analytics.streak',
        AccountFlag.coachDisclaimerAck: 'coachDisclaimerAck',
        AccountFlag.coupleEndedSeen: 'coupleEndedSeen',
        AccountFlag.nameCaptureDone: 'nameCaptureDone',
        AccountFlag.privacySpotlightSeen: 'privacySpotlightSeen',
      };
      // The vocabulary is the subject, so the TABLE must be checked against it
      // rather than the other way round: a new member with no row here is a
      // key nobody pinned.
      expect(
        shipped.keys.toSet(),
        AccountFlag.values.toSet(),
        reason:
            'teach this table about every AccountFlag — an unpinned prefix is '
            'a key that can drift silently',
      );
      shipped.forEach((flag, text) {
        expect(flag.prefix, text, reason: '${flag.name} changed its key text');
      });
    });

    test('every DeviceFlag value is the shipped text', () {
      const shipped = <DeviceFlag, String>{
        DeviceFlag.install: 'analytics.install',
        DeviceFlag.ritualPreviewSeen: 'ritualPreviewSeen',
      };
      expect(shipped.keys.toSet(), DeviceFlag.values.toSet());
      shipped.forEach((flag, text) {
        expect(flag.value, text, reason: '${flag.name} changed its key text');
      });
    });
  });

  group('every key BUILDER produces its shipped text', () {
    // Restored and widened after the built-diff review. The rewrite that
    // introduced the typed vocabulary DROPPED `expect(coachDisclaimerAckKey('u1'),
    // 'coachDisclaimerAck.u1')` and replaced it with a pin on
    // `AccountFlag.coachDisclaimerAck.prefix` — which is not the same
    // assertion. The enum pin proves the VOCABULARY is intact; it says nothing
    // about which member a builder passes. A `coachDisclaimerAckKey` rewired to
    // `AccountFlag.nameCaptureDone` would have kept every test green, and every
    // user who had acknowledged the "not therapy" note would have been shown it
    // again.
    //
    // The behavioural tests cannot cover this: `coach_screen_test.dart` seeds
    // with `coachDisclaimerAckKey(_uid).value` and asserts with the same
    // function — a fixture derived from its own subject (`session-lessons.md`
    // recurring shape 4), which passes for the wrong key as happily as the
    // right one. Lesson 117: where a value is a persisted CONTRACT rather than
    // an implementation detail, assert the value.
    const uid = 'u1';

    test('every builder is pinned here', () {
      // The builders are the subject, so this count is what stops a new one
      // from being added with no pin at all. Six: five uid-keyed plus the
      // device-scoped preview flag.
      expect(_builderPins(uid), hasLength(6));
    });

    test('each builder produces exactly its shipped key', () {
      _builderPins(uid).forEach((label, pair) {
        expect(
          pair.$1,
          pair.$2,
          reason:
              '$label drifted — every device that already holds the old key '
              'would be treated as if it had never set the flag',
        );
      });
    });
  });

  group('the key text is the persisted text', () {
    test('account keys join prefix, uid and parts with dots', () {
      expect(
        LocalFlagKey.account(AccountFlag.signup, uid: 'u1').value,
        'analytics.signup.u1',
      );
      expect(
        LocalFlagKey.account(
          AccountFlag.paired,
          uid: 'u1',
          parts: const ['c1'],
        ).value,
        'analytics.paired.u1.c1',
      );
      expect(
        LocalFlagKey.account(
          AccountFlag.qAnswered,
          uid: 'u1',
          parts: const ['20260818', 'solo'],
        ).value,
        'analytics.q.u1.20260818.solo',
      );
    });

    test('device keys are the enum text verbatim', () {
      expect(
        LocalFlagKey.device(DeviceFlag.install).value,
        'analytics.install',
      );
      expect(
        LocalFlagKey.device(DeviceFlag.ritualPreviewSeen).value,
        'ritualPreviewSeen',
      );
    });

    test('two keys with the same text are equal', () {
      expect(
        LocalFlagKey.account(AccountFlag.signup, uid: 'u1'),
        LocalFlagKey.account(AccountFlag.signup, uid: 'u1'),
      );
      expect(
        LocalFlagKey.account(AccountFlag.signup, uid: 'u1'),
        isNot(LocalFlagKey.account(AccountFlag.signup, uid: 'u2')),
      );
    });
  });
}

/// Every key builder in the app, called with [uid], beside the exact text it
/// has been writing to real devices. `(actual, expected)`.
///
/// Deliberately built from the BUILDERS rather than from [AccountFlag] /
/// [DeviceFlag]: the enums are pinned separately, and the gap this table closes
/// is a builder reaching for the wrong member.
Map<String, (String, String)> _builderPins(String uid) => {
  'coachDisclaimerAckKey': (
    coachDisclaimerAckKey(uid).value,
    'coachDisclaimerAck.u1',
  ),
  'nameCaptureDoneKey': (nameCaptureDoneKey(uid).value, 'nameCaptureDone.u1'),
  'privacySpotlightSeenKey': (
    privacySpotlightSeenKey(uid).value,
    'privacySpotlightSeen.u1',
  ),
  'coupleEndedSeenKey': (
    coupleEndedSeenKey(
      uid,
      DateTime.fromMillisecondsSinceEpoch(1752000000000),
    ).value,
    'coupleEndedSeen.u1.1752000000000',
  ),
  'ritualPreviewSeenKey': (ritualPreviewSeenKey.value, 'ritualPreviewSeen'),
  // `analytics.install` and the five uid-keyed analytics keys are built inside
  // the emitter rather than by a named builder, and `analytics_test.dart` pins
  // all six character for character through it — deliberately untouched by the
  // diff that could have broken them.
  'analytics (see analytics_test.dart)': (
    LocalFlagKey.device(DeviceFlag.install).value,
    'analytics.install',
  ),
};
