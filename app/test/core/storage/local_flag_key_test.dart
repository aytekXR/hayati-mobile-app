import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/core/storage/local_flag_key.dart';

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
        for (final flag in DeviceFlag.values) {
          for (final segment in flag.value.split('.')) {
            expect(
              segment,
              matches(RegExp(r'^[a-z][A-Za-z]*$')),
              reason:
                  '${flag.name} has a segment that could be mistaken for a '
                  'Firebase uid (28 chars of [A-Za-z0-9]); the collision above '
                  'stops being hypothetical',
            );
            expect(segment.length, lessThan(28));
          }
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
