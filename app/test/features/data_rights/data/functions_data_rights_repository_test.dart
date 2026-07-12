import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/data_rights/data/functions_data_rights_repository.dart';
import 'package:hayati_app/features/data_rights/domain/data_rights_exception.dart';

// The plugin's FirebaseFunctionsException constructor is @protected; a subclass
// may still invoke it via super, fabricating the real exception TYPE the boundary
// switches on without touching a live callable (the coach mold).
class _FunctionsException extends FirebaseFunctionsException {
  _FunctionsException({
    required super.code,
    super.message = 'boom',
    super.details,
  });
}

/// Marker seeded through every failure path — no thrown exception's toString()
/// may ever contain it (the no-content rule; deletion/export are
/// special-category-adjacent).
const _sentinel = 'HAYATI_DATA_RIGHTS_SENTINEL_5f1a';

void main() {
  group('mapDataRightsFailure — code-first taxonomy', () {
    test('unavailable / deadline-exceeded → network', () {
      expect(
        mapDataRightsFailure(_FunctionsException(code: 'unavailable')),
        const DataRightsNetworkException(),
      );
      expect(
        mapDataRightsFailure(_FunctionsException(code: 'deadline-exceeded')),
        const DataRightsNetworkException(),
      );
    });

    test('failed-precondition + reason profile-missing → profile-missing', () {
      expect(
        mapDataRightsFailure(
          _FunctionsException(
            code: 'failed-precondition',
            details: {'reason': 'profile-missing'},
          ),
        ),
        const DataRightsProfileMissingException(),
      );
    });

    test(
      'failed-precondition with a dropped/other reason keeps the raw code under '
      'the generic surface (never a wrong profile-missing claim)',
      () {
        final mapped = mapDataRightsFailure(
          _FunctionsException(code: 'failed-precondition', message: 'static'),
        );
        expect(
          mapped,
          const DataRightsUnknownException(
            code: 'failed-precondition',
            message: 'static',
          ),
        );
      },
    );

    test('internal / invalid-argument / unauthenticated → generic unknown', () {
      for (final code in ['internal', 'invalid-argument', 'unauthenticated']) {
        final mapped = mapDataRightsFailure(
          _FunctionsException(code: code, message: 'static'),
        );
        expect(mapped, isA<DataRightsUnknownException>());
        expect((mapped as DataRightsUnknownException).code, code);
      }
    });

    test('an already-mapped DataRightsException passes through unchanged', () {
      const already = DataRightsUnknownException(code: 'malformed-response');
      expect(identical(mapDataRightsFailure(already), already), isTrue);
    });

    test('a non-Functions throw records ONLY the runtimeType (no-content)', () {
      final mapped =
          mapDataRightsFailure(StateError(_sentinel))
              as DataRightsUnknownException;
      expect(mapped.code, 'unexpected');
      expect(mapped.message, 'StateError');
      expect(mapped.toString(), isNot(contains(_sentinel)));
    });

    test('a malformed details map never throws — degrades to generic', () {
      final mapped = mapDataRightsFailure(
        _FunctionsException(code: 'failed-precondition', details: 'not-a-map'),
      );
      expect(mapped, isA<DataRightsUnknownException>());
    });
  });

  group('decodeOrThrowDataExport', () {
    test('a valid envelope decodes to a DataExport', () {
      final export = decodeOrThrowDataExport(<Object?, Object?>{
        'formatVersion': 1,
        'generatedAt': '2026-07-12T09:00:00.000Z',
        'uid': 'uid-A',
        'data': <Object?, Object?>{'note': 'n'},
      });
      expect(export.uid, 'uid-A');
    });

    test('a malformed body becomes a sealed malformed-response, not a raw '
        'FormatException', () {
      expect(
        () => decodeOrThrowDataExport('nope'),
        throwsA(
          isA<DataRightsUnknownException>().having(
            (e) => e.code,
            'code',
            'malformed-response',
          ),
        ),
      );
    });
  });

  group('the confirm literal is the frozen wire value', () {
    test('kDeleteAccountConfirmLiteral is exactly DELETE', () {
      expect(kDeleteAccountConfirmLiteral, 'DELETE');
    });
  });
}
