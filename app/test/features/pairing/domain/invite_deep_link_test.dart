import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/pairing/domain/invite_deep_link.dart';

void main() {
  String? parse(String uri) => inviteCodeFromUri(Uri.parse(uri));

  group('accepts a well-formed hayati://invite/<code> link', () {
    test('returns the code from the happy path', () {
      expect(parse('hayati://invite/ABCD2345'), 'ABCD2345');
    });

    test('uppercases a lowercase code', () {
      expect(parse('hayati://invite/abcd2345'), 'ABCD2345');
    });

    test('is case-insensitive on the scheme and host', () {
      expect(parse('HAYATI://INVITE/ABCD2345'), 'ABCD2345');
    });

    test('ignores a query string', () {
      expect(parse('hayati://invite/ABCD2345?ref=whatsapp'), 'ABCD2345');
    });
  });

  group('rejects anything that is not an invite link', () {
    test('wrong scheme', () {
      expect(parse('https://invite/ABCD2345'), isNull);
      expect(parse('otherapp://invite/ABCD2345'), isNull);
    });

    test('wrong host', () {
      expect(parse('hayati://join/ABCD2345'), isNull);
      expect(parse('hayati://profile/ABCD2345'), isNull);
    });

    test('zero path segments', () {
      expect(parse('hayati://invite'), isNull);
      expect(parse('hayati://invite/'), isNull);
    });

    test('extra path segments', () {
      expect(parse('hayati://invite/ABCD2345/extra'), isNull);
    });
  });

  group('rejects codes that fail the alphabet contract', () {
    test('ambiguous characters (0, O, 1, I, L) are not in the alphabet', () {
      expect(parse('hayati://invite/ABCDEF0G'), isNull); // 0
      expect(parse('hayati://invite/ABCDEFOG'), isNull); // O
      expect(parse('hayati://invite/ABCDEF1G'), isNull); // 1
      expect(parse('hayati://invite/ABCDEFIG'), isNull); // I
      expect(parse('hayati://invite/ABCDEFLG'), isNull); // L
    });

    test('a 7-character code is too short', () {
      expect(parse('hayati://invite/ABCD234'), isNull);
    });

    test('a 9-character code is too long', () {
      expect(parse('hayati://invite/ABCD23456'), isNull);
    });
  });
}
