import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/data_rights/domain/data_export.dart';

/// A well-formed callable payload, delivered as the platform channel delivers it:
/// nested objects typed `Map<Object?, Object?>`, not `Map<String, dynamic>`.
Map<Object?, Object?> wireEnvelope() => <Object?, Object?>{
  'formatVersion': 1,
  'generatedAt': '2026-07-12T09:00:00.000Z',
  'uid': 'uid-A',
  'data': <Object?, Object?>{
    'profile': <Object?, Object?>{'status': 'married', 'contentLanguage': 'tr'},
    'soloAnswers': <Object?>[
      <Object?, Object?>{'dayKey': '2026-07-10', 'questionId': 'q-1'},
    ],
    'coupleContext': null,
    'note': 'Question text is referenced by questionId only.',
  },
};

void main() {
  group('dataExportFromCallable', () {
    test('decodes a well-formed envelope', () {
      final export = dataExportFromCallable(wireEnvelope());
      expect(export.formatVersion, 1);
      expect(export.generatedAt, '2026-07-12T09:00:00.000Z');
      expect(export.uid, 'uid-A');
      expect(export.data['note'], isA<String>());
    });

    test('coerces a formatVersion delivered as a double', () {
      final wire = wireEnvelope()..['formatVersion'] = 1.0;
      expect(dataExportFromCallable(wire).formatVersion, 1);
    });

    test('re-keys the nested tree into JSON-safe Map<String, Object?>', () {
      final export = dataExportFromCallable(wireEnvelope());
      expect(export.data, isA<Map<String, Object?>>());
      final profile = export.data['profile'];
      expect(profile, isA<Map<String, Object?>>());
      expect((profile! as Map)['status'], 'married');
      final solo = export.data['soloAnswers'];
      expect(solo, isA<List<Object?>>());
      expect(((solo! as List).first as Map)['questionId'], 'q-1');
    });

    test('a non-map payload throws FormatException', () {
      expect(() => dataExportFromCallable('nope'), throwsFormatException);
      expect(() => dataExportFromCallable(null), throwsFormatException);
    });

    test('a bad formatVersion / generatedAt / uid / data throws', () {
      expect(
        () => dataExportFromCallable(wireEnvelope()..['formatVersion'] = 'x'),
        throwsFormatException,
      );
      expect(
        () => dataExportFromCallable(wireEnvelope()..['generatedAt'] = 42),
        throwsFormatException,
      );
      expect(
        () => dataExportFromCallable(wireEnvelope()..['uid'] = 42),
        throwsFormatException,
      );
      expect(
        () => dataExportFromCallable(wireEnvelope()..['data'] = 'not-a-map'),
        throwsFormatException,
      );
    });

    test(
      'the FormatException message never leaks a value — only runtimeTypes',
      () {
        try {
          dataExportFromCallable(wireEnvelope()..['uid'] = 12345);
          fail('expected a FormatException');
        } on FormatException catch (e) {
          expect(e.message, isNot(contains('12345')));
          expect(e.message, contains('int'));
        }
      },
    );
  });

  group('toPrettyJson', () {
    test('round-trips to the exact envelope with 2-space indentation', () {
      final export = dataExportFromCallable(wireEnvelope());
      final pretty = export.toPrettyJson();
      // Deterministic indentation, and a faithful re-encode of the whole doc.
      expect(pretty, contains('\n  "formatVersion": 1'));
      expect(jsonDecode(pretty), {
        'formatVersion': 1,
        'generatedAt': '2026-07-12T09:00:00.000Z',
        'uid': 'uid-A',
        'data': {
          'profile': {'status': 'married', 'contentLanguage': 'tr'},
          'soloAnswers': [
            {'dayKey': '2026-07-10', 'questionId': 'q-1'},
          ],
          'coupleContext': null,
          'note': 'Question text is referenced by questionId only.',
        },
      });
    });
  });

  group('normalizeExportJson', () {
    test('passes primitives through and re-keys maps recursively', () {
      expect(normalizeExportJson(7), 7);
      expect(normalizeExportJson('s'), 's');
      expect(normalizeExportJson(null), isNull);
      final out = normalizeExportJson(<Object?, Object?>{
        'a': <Object?, Object?>{'b': 1},
        'c': <Object?>[
          <Object?, Object?>{'d': true},
        ],
      });
      expect(out, isA<Map<String, Object?>>());
      expect((out! as Map)['a'], isA<Map<String, Object?>>());
    });
  });
}
