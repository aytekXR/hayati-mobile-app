import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/pairing/domain/invite_deep_link.dart';

void main() {
  String? parse(String uri) => inviteCodeFromUri(Uri.parse(uri));

  group('accepts the universal link that ships today (ADR-036)', () {
    test('returns the code from the happy path', () {
      expect(parse('https://ikimiz.beyondkaira.com/i/ABCD2345'), 'ABCD2345');
    });

    test('uppercases a lowercase code', () {
      expect(parse('https://ikimiz.beyondkaira.com/i/abcd2345'), 'ABCD2345');
    });

    test('ignores a query string, as the custom scheme does', () {
      expect(
        parse('https://ikimiz.beyondkaira.com/i/ABCD2345?utm=whatsapp'),
        'ABCD2345',
      );
    });

    test('the host is matched case-insensitively', () {
      expect(parse('https://IKIMIZ.BeyondKaira.com/i/ABCD2345'), 'ABCD2345');
    });

    test('another host on the same path shape is rejected', () {
      // Anyone can serve /i/<code>; only our host may claim an invite.
      expect(parse('https://evil.example.com/i/ABCD2345'), isNull);
    });

    test('a different path prefix is rejected', () {
      expect(parse('https://ikimiz.beyondkaira.com/x/ABCD2345'), isNull);
    });

    test('the bare host, and the prefix with no code, are rejected', () {
      expect(parse('https://ikimiz.beyondkaira.com'), isNull);
      expect(parse('https://ikimiz.beyondkaira.com/i'), isNull);
      expect(parse('https://ikimiz.beyondkaira.com/i/'), isNull);
    });

    test('an extra segment is rejected rather than truncated', () {
      expect(parse('https://ikimiz.beyondkaira.com/i/ABCD2345/extra'), isNull);
    });

    test('http is NOT accepted — universal links are https only', () {
      expect(parse('http://ikimiz.beyondkaira.com/i/ABCD2345'), isNull);
    });

    test('a malformed code is still rejected on the new host', () {
      // normalizeInviteCode remains the single source of truth for the alphabet.
      expect(parse('https://ikimiz.beyondkaira.com/i/ABCD01IO'), isNull);
    });
  });

  group('inviteLinkFor builds what the parser accepts', () {
    test('round-trips', () {
      // The share sheet and the parser used to be able to drift; one
      // constructor plus this round-trip is what stops that.
      expect(
        inviteCodeFromUri(Uri.parse(inviteLinkFor('ABCD2345'))),
        'ABCD2345',
      );
    });

    test('is an https link on the published host', () {
      expect(
        inviteLinkFor('ABCD2345'),
        'https://ikimiz.beyondkaira.com/i/ABCD2345',
      );
    });
  });

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
