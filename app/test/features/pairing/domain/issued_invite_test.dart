import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/pairing/domain/issued_invite.dart';

void main() {
  final expiresAt = DateTime(2026, 7, 11, 15, 30);

  IssuedInvite invite({
    String code = 'ABCD2345',
    DateTime? expiresAt,
    bool reused = false,
  }) => IssuedInvite(
    code: code,
    expiresAt: expiresAt ?? DateTime(2026, 7, 11, 15, 30),
    reused: reused,
  );

  test('invites with the same fields are value-equal', () {
    expect(invite(), invite());
    expect(invite().hashCode, invite().hashCode);
    expect(invite(), invite(expiresAt: expiresAt));
  });

  test('any differing field breaks equality', () {
    expect(invite(), isNot(invite(code: 'WXYZ6789')));
    expect(invite(), isNot(invite(expiresAt: DateTime(2026, 7, 12))));
    expect(invite(), isNot(invite(reused: true)));
  });

  test('toString surfaces the code for diagnostics', () {
    expect(invite(reused: true).toString(), contains('ABCD2345'));
  });
}
