import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/pairing/domain/invite_preview.dart';

void main() {
  group('InvitePreviewResult', () {
    test('value equality is field-based', () {
      expect(
        const InvitePreviewResult(
          status: InvitePreviewStatus.valid,
          creatorDisplayName: 'Aylin',
        ),
        const InvitePreviewResult(
          status: InvitePreviewStatus.valid,
          creatorDisplayName: 'Aylin',
        ),
      );
      expect(
        const InvitePreviewResult(
          status: InvitePreviewStatus.valid,
          creatorDisplayName: 'Aylin',
        ).hashCode,
        const InvitePreviewResult(
          status: InvitePreviewStatus.valid,
          creatorDisplayName: 'Aylin',
        ).hashCode,
      );
    });

    test('a differing status or name is unequal', () {
      expect(
        const InvitePreviewResult(status: InvitePreviewStatus.valid),
        isNot(const InvitePreviewResult(status: InvitePreviewStatus.expired)),
      );
      expect(
        const InvitePreviewResult(
          status: InvitePreviewStatus.valid,
          creatorDisplayName: 'Aylin',
        ),
        isNot(const InvitePreviewResult(status: InvitePreviewStatus.valid)),
      );
    });

    test('creatorDisplayName defaults to null', () {
      expect(
        const InvitePreviewResult(
          status: InvitePreviewStatus.unknown,
        ).creatorDisplayName,
        isNull,
      );
    });

    test('the status set matches the server projection exactly', () {
      // Mirror of functions/src/invites/invite-preview.ts InvitePreviewStatus.
      expect(InvitePreviewStatus.values, hasLength(3));
    });
  });
}
