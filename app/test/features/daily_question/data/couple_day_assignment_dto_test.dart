import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/daily_question/data/couple_day_assignment_dto.dart';

/// A boundary-converted `couples/{cid}/days/{yyyymmdd}` document — the
/// repository has already turned the wire Timestamp into a DateTime before
/// calling in. Tests mutate copies to hit each loud branch.
Map<String, dynamic> validAssignment() => {
  'questionId': 'solo_en_003',
  'packId': 'solo_en',
  'packVersion': 1,
  'assignedAt': DateTime.utc(2026, 7, 10, 3),
};

void main() {
  group('coupleDayAssignmentFromMap', () {
    test('maps a boundary-converted document into the domain', () {
      final assignment = coupleDayAssignmentFromMap(validAssignment());

      expect(assignment.questionId, 'solo_en_003');
      expect(assignment.packId, 'solo_en');
      expect(assignment.packVersion, 1);
      expect(assignment.assignedAt, DateTime.utc(2026, 7, 10, 3));
    });

    test('a null assignedAt crosses as null (documented pending window)', () {
      // The rollover writes with the admin SDK, so reads virtually always
      // carry the stamp — but null is legal, not a junk shape.
      final assignment = coupleDayAssignmentFromMap(
        validAssignment()..['assignedAt'] = null,
      );

      expect(assignment.assignedAt, isNull);
    });

    test('rejects a missing, empty or non-string questionId loudly', () {
      expect(
        () =>
            coupleDayAssignmentFromMap(validAssignment()..remove('questionId')),
        throwsFormatException,
      );
      expect(
        () =>
            coupleDayAssignmentFromMap(validAssignment()..['questionId'] = ''),
        throwsFormatException,
      );
      expect(
        () => coupleDayAssignmentFromMap(validAssignment()..['questionId'] = 7),
        throwsFormatException,
      );
    });

    test('rejects a missing, empty or non-string packId loudly', () {
      expect(
        () => coupleDayAssignmentFromMap(validAssignment()..remove('packId')),
        throwsFormatException,
      );
      expect(
        () => coupleDayAssignmentFromMap(validAssignment()..['packId'] = ''),
        throwsFormatException,
      );
      expect(
        () => coupleDayAssignmentFromMap(validAssignment()..['packId'] = 7),
        throwsFormatException,
      );
    });

    test('rejects a missing or non-int packVersion loudly', () {
      expect(
        () => coupleDayAssignmentFromMap(
          validAssignment()..remove('packVersion'),
        ),
        throwsFormatException,
      );
      // A string or double is a corrupt version — the rollover writes an int.
      expect(
        () => coupleDayAssignmentFromMap(
          validAssignment()..['packVersion'] = '1',
        ),
        throwsFormatException,
      );
      expect(
        () => coupleDayAssignmentFromMap(
          validAssignment()..['packVersion'] = 1.5,
        ),
        throwsFormatException,
      );
    });

    test('rejects a raw Timestamp assignedAt loudly (missed boundary '
        'conversion)', () {
      // The repository owns the Timestamp -> DateTime hop; a Firestore type
      // reaching this pure mapper means that hop was skipped.
      expect(
        () => coupleDayAssignmentFromMap(
          validAssignment()
            ..['assignedAt'] = Timestamp.fromMillisecondsSinceEpoch(
              1751980000000,
            ),
        ),
        throwsFormatException,
      );
    });
  });
}
