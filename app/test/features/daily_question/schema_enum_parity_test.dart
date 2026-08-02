import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/daily_question/domain/question.dart';
import 'package:hayati_app/features/profile/domain/relationship_profile.dart';

/// A CROSS-TREE PARITY test (issue #130), in the shape of
/// `brandkit_token_parity_test.dart` and of the TWO guards that already exist
/// for this same schema — `validateSchemaAgreement` in
/// `content/validator/validator_core.dart` and
/// `functions/test/unit/schema-agreement.test.ts`.
///
/// WHY. ADR-026 D3 guarantees the seasonal vocabulary is closed and "enforced
/// in five places". All five readers do REJECT an unknown value; what did not
/// exist was the parity net keeping them in sync. The validator and both TS
/// readers are checked against `content/schema/question-pack.schema.json`. The
/// APP was not — and the test that looked like the fifth guard,
/// `question_pack_dto_test.dart`'s "accepts every value of the closed seasonal
/// vocabulary", iterated `knownSeasonalWindows` itself: a fixture derived from
/// its own subject, which cannot detect drift because the schema is never read.
///
/// The failure it permitted: add a season to the schema, the validator and both
/// TS readers, forget the Dart list, and CI is **fully green** while the app
/// throws `FormatException` at pack-load time on a real device.
///
/// ## Scope: every enum in the schema, not just seasonalWindow
///
/// The issue asked for the seasonal one and suggested widening. Widening turned
/// up more than the issue listed, so this covers all four and asserts that
/// there are exactly four (see `the schema declares no enum this test has not
/// been taught about`). The four app-side mirrors and what guarded them before:
///
///   | schema enum | app mirror         | guard before this test        |
///   |-------------|--------------------|-------------------------------|
///   | locale      | [ContentLanguage]  | a COUNT (`hasLength(3)`)      |
///   | register    | [QuestionRegister] | a hardcoded list, no schema   |
///   | category    | [QuestionCategory] | a COUNT (`hasLength(5)`)      |
///   | seasonalWindow | [knownSeasonalWindows] | self-referential loop |
///
/// **A count is weaker than it looks**: `expect(QuestionCategory.values,
/// hasLength(5))` passes after renaming `gratitude` to `banter`. Two of the
/// four "guards" were cardinality assertions wearing a vocabulary's clothing.
///
/// **`locale` was not in the issue at all.** Its mirror, [ContentLanguage],
/// lives in `features/profile/`, a different feature from the pack DTO that
/// consumes it — which is exactly why a sweep over `daily_question/` missed it.
///
/// ## The comparison is EXACT and ORDERED, deliberately
///
/// **Ordered**, because the two guards that already exist are: the TS test
/// asserts `toEqual([...tsValues])` and says why in its header ("a reordered
/// enum is a diff worth seeing"), and `validator_core`'s `checkEnum` compares
/// with `_sameList`. Both use `.sort()` in exactly one place — the field-NAME
/// sets, where order carries nothing. A third guard written as a set comparison
/// would be the weakest of the three while looking identical to them.
///
/// **Exact rather than "the app may know a subset"**, and this one is worth
/// stating because the asymmetry sounds like it should favour a subset. It does
/// not. Every one of the four mirrors THROWS on a value it does not recognise
/// (`_questionFromJson`, `_localeField`, `_registerField` in
/// `question_pack_dto.dart`). So an app that knows fewer values than the schema
/// is not "failing closed" in any useful sense — it is a `FormatException` on a
/// real device, waiting for the first pack that uses the new value. The runtime
/// concern that DOES sound like this ("a shipped binary is older than the
/// schema") is real and is a different problem: this test compares the schema
/// and the Dart in the SAME commit, so both sides always move together here.
///
/// If this test fails, do NOT edit whichever side is easier. The schema is the
/// source of truth for the content format; adding a value there is a five-file
/// change (ADR-026 D3) and this test is the thing that now says so out loud.
void main() {
  const schemaPath = '../content/schema/question-pack.schema.json';

  late Map<String, dynamic> schema;

  setUpAll(() {
    final file = File(schemaPath);
    // FAIL, never skip. A parity test that cannot find its source of truth has
    // measured nothing, and reporting green for that is the exact defect this
    // whole class of test exists to prevent (cf. ADR-041's exit-code taxonomy:
    // "could not measure" must never render as "no difference").
    expect(
      file.existsSync(),
      isTrue,
      reason:
          'the schema was renamed or moved rather than this test passing '
          'vacuously — re-point schemaPath and keep the guard',
    );
    schema = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  });

  List<String> enumAt(List<String> path) {
    Object? node = schema;
    for (final key in path) {
      expect(
        node,
        isA<Map<String, dynamic>>(),
        reason: 'schema shape changed: ${path.join('.')} not reachable',
      );
      node = (node! as Map<String, dynamic>)[key];
    }
    expect(
      node,
      isA<Map<String, dynamic>>(),
      reason: 'schema shape changed: ${path.join('.')} is not an object',
    );
    final values = (node! as Map<String, dynamic>)['enum'];
    expect(
      values,
      isA<List<dynamic>>(),
      reason:
          '${path.join('.')} has no enum — the vocabulary was opened up, '
          'which is a content-format decision and not a test failure to patch',
    );
    return (values! as List<dynamic>).cast<String>();
  }

  const localePath = ['properties', 'locale'];
  const registerPath = ['properties', 'register'];
  const categoryPath = [
    'properties',
    'questions',
    'items',
    'properties',
    'category',
  ];
  const seasonalPath = [
    'properties',
    'questions',
    'items',
    'properties',
    'seasonalWindow',
  ];

  group('question-pack schema ↔ app domain vocabularies', () {
    test('seasonalWindow — the gap #130 was filed for', () {
      expect(knownSeasonalWindows, enumAt(seasonalPath));
    });

    test('category — QuestionCategory.name is the wire spelling', () {
      expect(
        QuestionCategory.values.map((c) => c.name).toList(),
        enumAt(categoryPath),
      );
    });

    test('register — QuestionRegister.wire, NOT ContentRegister', () {
      expect(
        QuestionRegister.values.map((r) => r.wire).toList(),
        enumAt(registerPath),
      );
    });

    test('locale — ContentLanguage.name, and it lives in another feature', () {
      expect(
        ContentLanguage.values.map((l) => l.name).toList(),
        enumAt(localePath),
      );
    });

    test('ContentRegister is a DIFFERENT enum and is deliberately not '
        'compared to the schema', () {
      // A trap worth a red test rather than a comment. Two enums in this app
      // are called "register": ContentRegister is the user's captured
      // preference (docs/prd.md F1) and QuestionRegister is the pack's tone.
      // Only the second mirrors the schema. Pointing a parity test at
      // ContentRegister would FAIL and look like it had found real drift, so
      // pin the distinction: if these two ever converge, this test says so and
      // whoever converged them decides what the parity guard should compare.
      expect(
        ContentRegister.values.map((r) => r.name).toList(),
        isNot(QuestionRegister.values.map((r) => r.wire).toList()),
        reason:
            'ContentRegister and QuestionRegister have merged — decide '
            'which one the schema register enum should be compared against',
      );
      expect(ContentRegister.values.map((r) => r.name), [
        'playful',
        'respectful',
      ]);
    });

    test('the schema declares no enum this test has not been taught about', () {
      // Coverage asserted, not assumed. Every check above is a claim about ONE
      // vocabulary; without this, a FIFTH enum added to the schema would be
      // mirrored by nothing, guarded by nothing, and every test here would
      // still be green — the same partial-green shape the guards themselves
      // exist to prevent.
      final found = <String>[];
      void walk(Object? node, String path) {
        if (node is Map<String, dynamic>) {
          if (node.containsKey('enum')) found.add(path);
          node.forEach((k, v) => walk(v, path.isEmpty ? k : '$path.$k'));
        } else if (node is List) {
          for (var i = 0; i < node.length; i++) {
            walk(node[i], '$path[$i]');
          }
        }
      }

      walk(schema, '');
      expect(
        found..sort(),
        [
          categoryPath.join('.'),
          localePath.join('.'),
          registerPath.join('.'),
          seasonalPath.join('.'),
        ]..sort(),
      );
    });
  });
}
