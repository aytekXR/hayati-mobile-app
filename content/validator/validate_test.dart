/// Self-checking tests for the question-pack validator (M3.1).
///
/// Runner decision (docs/test-suite.md §1 "pack validator"): `content/` has
/// no pubspec, so `package:test` can't run here without inventing one; this
/// is a plain-`dart` self-checking script in the `tool/`-script mold —
/// every `_check` is an assertion, any failure exits non-zero, and CI runs
/// it right before the validator itself (ubuntu `quality` job).
///
///     dart content/validator/validate_test.dart
library;

import 'dart:convert';
import 'dart:io';

import 'validate.dart';
import 'validator_core.dart';

var _passed = 0;
final List<String> _failures = [];

void _check(String name, bool condition) {
  if (condition) {
    _passed++;
  } else {
    _failures.add(name);
  }
}

/// True when [issues] contains an issue of [severity] whose text (where +
/// message) contains every fragment — the field-precise-message contract.
bool _hasIssue(
  List<PackIssue> issues,
  IssueSeverity severity,
  List<String> fragments,
) => issues.any(
  (i) =>
      i.severity == severity &&
      fragments.every((f) => i.toString().contains(f)),
);

Map<String, dynamic> _validPack({
  String packId = 'solo_tr',
  String locale = 'tr',
  int questionCount = 7,
  String? reviewedBy = 'Founder TR (test fixture)',
}) => {
  'packId': packId,
  'version': 1,
  'locale': locale,
  'register': 'neutral',
  if (reviewedBy != null) 'reviewedBy': reviewedBy,
  'questions': [
    for (var i = 1; i <= questionCount; i++)
      {
        'id': '${packId}_q$i',
        'category': knownCategories[i % knownCategories.length],
        'depth': (i % maxDepth) + 1,
        'text': 'Question $i?',
      },
  ],
};

List<PackIssue> _validate(
  Map<String, dynamic> pack, {
  String? path,
  bool strictReview = false,
}) => validatePackSource(
  relativePath: path ?? 'content/packs/${pack['packId']}.json',
  source: jsonEncode(pack),
  strictReview: strictReview,
).issues;

void _coreTests() {
  _check('valid pack has no issues', _validate(_validPack()).isEmpty);

  _check(
    'invalid JSON is an error',
    _hasIssue(
      validatePackSource(
        relativePath: 'content/packs/broken.json',
        source: '{not json',
      ).issues,
      IssueSeverity.error,
      ['invalid JSON'],
    ),
  );
  _check(
    'non-object root is an error',
    _hasIssue(
      validatePackSource(relativePath: 'p.json', source: '[1]').issues,
      IssueSeverity.error,
      ['root must be a JSON object'],
    ),
  );
  _check(
    'unknown pack field is an error naming the field',
    _hasIssue(_validate(_validPack()..['surprise'] = 1), IssueSeverity.error, [
      'unknown field "surprise"',
    ]),
  );
  for (final field in requiredPackFields) {
    _check(
      'missing required pack field "$field" is an error naming it',
      _hasIssue(_validate(_validPack()..remove(field)), IssueSeverity.error, [
        'missing required field "$field"',
      ]),
    );
  }
  _check(
    'bad packId pattern is an error',
    _hasIssue(
      _validate(
        _validPack()..['packId'] = 'Solo-TR',
        path: 'content/packs/Solo-TR.json',
      ),
      IssueSeverity.error,
      ['"packId"', 'pattern'],
    ),
  );
  _check(
    'non-integer version is an error',
    _hasIssue(_validate(_validPack()..['version'] = 1.5), IssueSeverity.error, [
      '"version" must be an integer',
    ]),
  );
  _check(
    'version < 1 is an error',
    _hasIssue(_validate(_validPack()..['version'] = 0), IssueSeverity.error, [
      '"version" must be >= 1',
    ]),
  );
  _check(
    'unknown locale is an error',
    _hasIssue(_validate(_validPack()..['locale'] = 'de'), IssueSeverity.error, [
      '"locale" must be one of',
    ]),
  );
  _check(
    'unknown register is an error',
    _hasIssue(
      _validate(_validPack()..['register'] = 'formal'),
      IssueSeverity.error,
      ['"register" must be one of'],
    ),
  );

  _check(
    'missing reviewedBy is a WARNING pre-launch (ADR-007/W9)',
    _hasIssue(_validate(_validPack(reviewedBy: null)), IssueSeverity.warning, [
      'reviewedBy is missing',
    ]),
  );
  _check(
    'PENDING reviewedBy is a WARNING pre-launch',
    _hasIssue(
      _validate(_validPack(reviewedBy: 'PENDING native review')),
      IssueSeverity.warning,
      ['reviewedBy'],
    ),
  );
  _check(
    'missing reviewedBy has no ERROR tier by default',
    _validate(_validPack(reviewedBy: null)).every((i) => !i.isError),
  );
  _check(
    '--strict-review promotes reviewedBy to an error',
    _hasIssue(
      _validate(_validPack(reviewedBy: null), strictReview: true),
      IssueSeverity.error,
      ['reviewedBy'],
    ),
  );
  _check(
    'non-string reviewedBy is an error',
    _hasIssue(
      _validate(_validPack()..['reviewedBy'] = 7),
      IssueSeverity.error,
      ['"reviewedBy" must be a string'],
    ),
  );

  _check(
    'filename must be <packId>.json',
    _hasIssue(
      _validate(_validPack(), path: 'content/packs/renamed.json'),
      IssueSeverity.error,
      ['filename "renamed.json"', 'solo_tr.json'],
    ),
  );
  _check(
    'packId must carry its locale as a segment',
    _hasIssue(
      _validate(
        _validPack(packId: 'solo_tr', locale: 'en'),
        path: 'content/packs/solo_tr.json',
      ),
      IssueSeverity.error,
      ['packId "solo_tr"', 'locale "en"'],
    ),
  );
  _check(
    'locale-only packId (en) carries its locale',
    !_hasIssue(
      _validate(_validPack(packId: 'en', locale: 'en')),
      IssueSeverity.error,
      ['packId↔locale'],
    ),
  );

  _check(
    'empty questions array is an error',
    _hasIssue(
      _validate(_validPack()..['questions'] = <Object>[]),
      IssueSeverity.error,
      ['"questions" must be a non-empty array'],
    ),
  );
  _check(
    'non-object question entry is an error',
    _hasIssue(
      _validate(_validPack()..['questions'] = ['nope']),
      IssueSeverity.error,
      ['questions[0] must be an object'],
    ),
  );

  Map<String, dynamic> packWithQuestion(Map<String, dynamic> question) =>
      _validPack()..['questions'] = [question];
  Map<String, dynamic> question() => {
    'id': 'solo_tr_q1',
    'category': 'fun',
    'depth': 1,
    'text': 'Q?',
  };

  _check(
    'unknown question field is an error',
    _hasIssue(
      _validate(packWithQuestion(question()..['bonus'] = true)),
      IssueSeverity.error,
      ['unknown field "bonus"'],
    ),
  );
  for (final field in requiredQuestionFields) {
    _check(
      'missing question field "$field" is an error naming it',
      _hasIssue(
        _validate(packWithQuestion(question()..remove(field))),
        IssueSeverity.error,
        ['missing required field "$field"'],
      ),
    );
  }
  _check(
    'bad question id pattern is an error',
    _hasIssue(
      _validate(packWithQuestion(question()..['id'] = 'Q-1')),
      IssueSeverity.error,
      ['"id" "Q-1"', 'pattern'],
    ),
  );
  _check(
    'unknown category is an error',
    _hasIssue(
      _validate(packWithQuestion(question()..['category'] = 'spicy')),
      IssueSeverity.error,
      ['"category" must be one of'],
    ),
  );
  _check(
    'non-integer depth is an error',
    _hasIssue(
      _validate(packWithQuestion(question()..['depth'] = '3')),
      IssueSeverity.error,
      ['"depth" must be an integer'],
    ),
  );
  _check(
    'depth below $minDepth is an error',
    _hasIssue(
      _validate(packWithQuestion(question()..['depth'] = 0)),
      IssueSeverity.error,
      ['"depth" must be $minDepth-$maxDepth'],
    ),
  );
  _check(
    'depth above $maxDepth is an error',
    _hasIssue(
      _validate(packWithQuestion(question()..['depth'] = 6)),
      IssueSeverity.error,
      ['"depth" must be $minDepth-$maxDepth'],
    ),
  );
  _check(
    'empty text is an error',
    _hasIssue(
      _validate(packWithQuestion(question()..['text'] = '')),
      IssueSeverity.error,
      ['"text" must be a non-empty string'],
    ),
  );
  _check(
    'empty seasonalWindow is an error',
    _hasIssue(
      _validate(packWithQuestion(question()..['seasonalWindow'] = '')),
      IssueSeverity.error,
      ['"seasonalWindow"'],
    ),
  );
  _check(
    'seasonalWindow "ramadan" is valid',
    _validate(
      packWithQuestion(question()..['seasonalWindow'] = 'ramadan'),
    ).isEmpty,
  );
  _check(
    'duplicate question id within a pack is an error',
    _hasIssue(
      _validate(_validPack()..['questions'] = [question(), question()]),
      IssueSeverity.error,
      ['duplicate question id "solo_tr_q1"', 'within the pack'],
    ),
  );

  final packA = validatePackSource(
    relativePath: 'content/packs/solo_tr.json',
    source: jsonEncode(_validPack()),
  ).pack!;
  final packB = validatePackSource(
    relativePath: 'content/packs/solo_en.json',
    source: jsonEncode(
      _validPack(packId: 'solo_en', locale: 'en')
        ..['questions'] = [
          {
            'id': 'solo_tr_q1', // collides with packA
            'category': 'fun',
            'depth': 1,
            'text': 'Q?',
          },
        ],
    ),
  ).pack!;
  _check(
    'duplicate question id ACROSS packs is an error naming both files',
    _hasIssue(validateAcrossPacks([packA, packB]), IssueSeverity.error, [
      'question id "solo_tr_q1"',
      'content/packs/solo_tr.json',
      'unique across packs',
    ]),
  );
  final packACopy = validatePackSource(
    relativePath: 'content/packs/copy.json',
    source: jsonEncode(_validPack()),
  ).pack!;
  _check(
    'duplicate packId across files is an error',
    _hasIssue(validateAcrossPacks([packA, packACopy]), IssueSeverity.error, [
      'duplicate packId "solo_tr"',
    ]),
  );
}

void _schemaAgreementTests(String schemaSource) {
  _check(
    'validator agrees with the shipped JSON Schema',
    validateSchemaAgreement(schemaSource).isEmpty,
  );
  final tampered = jsonDecode(schemaSource) as Map<String, dynamic>;
  ((tampered['properties'] as Map<String, dynamic>)['locale']
      as Map<String, dynamic>)['enum'] = [
    'tr',
    'ar',
  ];
  _check(
    'schema drift (locale enum) is an error',
    _hasIssue(
      validateSchemaAgreement(jsonEncode(tampered)),
      IssueSeverity.error,
      ['"locale" enum', 'update both together'],
    ),
  );
}

/// Shell tests against a temp repo root: the acceptance-criteria violation
/// classes (schema field, duplicate id across packs, locale/filename
/// mismatch, drifted app copy) each exit non-zero with a field-precise
/// message, the shipped-shape happy path exits 0, and --sync regenerates.
void _shellTests(String schemaSource) {
  final temp = Directory.systemTemp.createTempSync('hayati_validator_test');
  try {
    File('${temp.path}/content/schema/question-pack.schema.json')
      ..createSync(recursive: true)
      ..writeAsStringSync(schemaSource);
    final packsDir = Directory('${temp.path}/content/packs')
      ..createSync(recursive: true);
    final appDir = Directory('${temp.path}/app/assets/content')
      ..createSync(recursive: true);

    void write(String tree, String name, Map<String, dynamic> pack) => File(
      '${tree == 'packs' ? packsDir.path : appDir.path}/$name',
    ).writeAsStringSync(jsonEncode(pack));
    (int, String, String) run(List<String> args) {
      final out = StringBuffer();
      final err = StringBuffer();
      final code = runValidator(args, out: out, err: err, root: temp.path);
      return (code, out.toString(), err.toString());
    }

    // Happy path: authored + synced byte-identically.
    write('packs', 'solo_tr.json', _validPack());
    write('packs', 'solo_en.json', _validPack(packId: 'solo_en', locale: 'en'));
    write('app', 'solo_tr.json', _validPack());
    write('app', 'solo_en.json', _validPack(packId: 'solo_en', locale: 'en'));
    var (code, out, err) = run([]);
    _check('valid synced trees exit 0', code == 0);
    _check('valid run reports OK', out.contains('question packs OK'));

    // Violation class: schema field (bad depth) in an authored pack.
    final badDepth = _validPack(packId: 'solo_ar', locale: 'ar');
    (((badDepth['questions'] as List)[0]) as Map<String, dynamic>)['depth'] = 9;
    write('packs', 'solo_ar.json', badDepth);
    (code, out, err) = run([]);
    _check('schema-field violation exits non-zero', code != 0);
    _check(
      'schema-field violation names the field and file',
      err.contains('solo_ar.json') && err.contains('"depth" must be 1-5'),
    );
    _check(
      'sync refuses an invalid authoring tree',
      run(['--sync']).$1 != 0 &&
          !File('${appDir.path}/solo_ar.json').existsSync(),
    );
    File('${packsDir.path}/solo_ar.json').deleteSync();

    // Violation class: duplicate question id across packs.
    final clash = _validPack(packId: 'solo_ar', locale: 'ar')
      ..['questions'] = [
        {'id': 'solo_tr_q1', 'category': 'fun', 'depth': 1, 'text': 'Q?'},
      ];
    write('packs', 'solo_ar.json', clash);
    (code, out, err) = run([]);
    _check('cross-pack duplicate id exits non-zero', code != 0);
    _check(
      'cross-pack duplicate id names both packs',
      err.contains('solo_tr_q1') && err.contains('unique across packs'),
    );
    File('${packsDir.path}/solo_ar.json').deleteSync();

    // Violation class: locale/filename mismatch.
    write('packs', 'solo_ar.json', _validPack(packId: 'solo_tr'));
    (code, out, err) = run([]);
    _check('filename mismatch exits non-zero', code != 0);
    _check(
      'filename mismatch message is field-precise',
      err.contains('filename "solo_ar.json"') && err.contains('solo_tr.json'),
    );
    File('${packsDir.path}/solo_ar.json').deleteSync();

    // Violation class: drifted app copy (authored text edited, not synced).
    final edited = _validPack();
    (((edited['questions'] as List)[0]) as Map<String, dynamic>)['text'] =
        'Edited without sync?';
    write('packs', 'solo_tr.json', edited);
    (code, out, err) = run([]);
    _check('drifted app copy exits non-zero', code != 0);
    _check(
      'drift message points at --sync',
      err.contains('drifted') && err.contains('--sync'),
    );

    // --sync regenerates the drifted copy and removes orphans.
    File('${appDir.path}/orphan_en.json').writeAsStringSync(
      jsonEncode(_validPack(packId: 'orphan_en', locale: 'en')),
    );
    (code, out, err) = run(['--sync']);
    _check('--sync exits 0 on a valid authoring tree', code == 0);
    _check(
      '--sync makes the copy byte-identical',
      File('${appDir.path}/solo_tr.json').readAsStringSync() ==
          File('${packsDir.path}/solo_tr.json').readAsStringSync(),
    );
    _check(
      '--sync removes orphans',
      !File('${appDir.path}/orphan_en.json').existsSync(),
    );
    _check('post-sync check passes', run([]).$1 == 0);

    // Orphan without --sync is a drift error.
    File('${appDir.path}/orphan_en.json').writeAsStringSync(
      jsonEncode(_validPack(packId: 'orphan_en', locale: 'en')),
    );
    (code, out, err) = run([]);
    _check('orphan bundled pack exits non-zero', code != 0);
    _check('orphan message names the file', err.contains('orphan_en.json'));
    File('${appDir.path}/orphan_en.json').deleteSync();

    // Violation class: authored pack with NO bundled copy at all (a new pack
    // whose --sync was forgotten — the copy==null drift branch, distinct from
    // the byte-drift branch above; review finding, Session 011).
    File('${appDir.path}/solo_en.json').deleteSync();
    (code, out, err) = run([]);
    _check('missing bundled copy exits non-zero', code != 0);
    _check(
      'missing-copy message names the file and --sync',
      err.contains('missing bundled copy') &&
          err.contains('solo_en.json') &&
          err.contains('--sync'),
    );
    (code, out, err) = run(['--sync']);
    _check(
      '--sync restores the missing copy',
      code == 0 && File('${appDir.path}/solo_en.json').existsSync(),
    );

    _check('unknown argument exits 64', run(['--nope']).$1 == 64);
  } finally {
    temp.deleteSync(recursive: true);
  }
}

void main() {
  final schemaFile = File.fromUri(
    Platform.script.resolve('../schema/question-pack.schema.json'),
  );
  final schemaSource = schemaFile.readAsStringSync();

  _coreTests();
  _schemaAgreementTests(schemaSource);
  _shellTests(schemaSource);

  if (_failures.isEmpty) {
    stdout.writeln('validator self-tests: $_passed checks passed');
  } else {
    stderr.writeln(
      'validator self-tests: ${_failures.length} FAILED, $_passed passed',
    );
    for (final name in _failures) {
      stderr.writeln('  FAIL: $name');
    }
    exitCode = 1;
  }
}
