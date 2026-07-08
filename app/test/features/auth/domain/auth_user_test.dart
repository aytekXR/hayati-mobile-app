import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/auth/domain/auth_user.dart';

void main() {
  group('AuthUser', () {
    const user = AuthUser(
      uid: 'uid-1',
      displayName: 'Aytek',
      email: 'a@example.com',
      photoUrl: 'https://example.com/p.png',
    );

    test('equal for identical field values', () {
      const same = AuthUser(
        uid: 'uid-1',
        displayName: 'Aytek',
        email: 'a@example.com',
        photoUrl: 'https://example.com/p.png',
      );
      expect(user, same);
      expect(user.hashCode, same.hashCode);
    });

    test('unequal when any field differs', () {
      expect(user, isNot(const AuthUser(uid: 'uid-2')));
      expect(
        user,
        isNot(
          const AuthUser(
            uid: 'uid-1',
            displayName: 'Other',
            email: 'a@example.com',
            photoUrl: 'https://example.com/p.png',
          ),
        ),
      );
    });

    test('optional fields default to null', () {
      const minimal = AuthUser(uid: 'uid-3');
      expect(minimal.displayName, isNull);
      expect(minimal.email, isNull);
      expect(minimal.photoUrl, isNull);
    });

    test('toString identifies the user by uid', () {
      expect(user.toString(), contains('uid-1'));
    });
  });
}
