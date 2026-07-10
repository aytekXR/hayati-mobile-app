import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/pairing/domain/normalize_invite_code.dart';

void main() {
  group('normalizeInviteCode', () {
    test('returns a well-formed code unchanged', () {
      expect(normalizeInviteCode('ABCD2345'), 'ABCD2345');
    });

    test('uppercases a lowercase code', () {
      expect(normalizeInviteCode('abcd2345'), 'ABCD2345');
    });

    test('trims surrounding whitespace (pasted / autofilled input)', () {
      expect(normalizeInviteCode('  abcd2345\n'), 'ABCD2345');
      expect(normalizeInviteCode('\tABCD2345 '), 'ABCD2345');
    });

    test('rejects ambiguous characters not in the alphabet', () {
      expect(normalizeInviteCode('ABCDEF0G'), isNull); // 0
      expect(normalizeInviteCode('ABCDEFOG'), isNull); // O
      expect(normalizeInviteCode('ABCDEF1G'), isNull); // 1
      expect(normalizeInviteCode('ABCDEFIG'), isNull); // I
      expect(normalizeInviteCode('ABCDEFLG'), isNull); // L
    });

    test('rejects the wrong length', () {
      expect(normalizeInviteCode('ABCD234'), isNull); // 7
      expect(normalizeInviteCode('ABCD23456'), isNull); // 9
      expect(normalizeInviteCode(''), isNull);
    });

    test('rejects interior whitespace or punctuation', () {
      expect(normalizeInviteCode('ABCD 234'), isNull);
      expect(normalizeInviteCode('ABCD-234'), isNull);
    });
  });
}
