import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

import { describe, expect, it } from 'vitest';

import {
  PACK_LOCALES,
  PACK_REGISTERS,
  QUESTION_CATEGORIES,
  PackParseError,
  parseQuestionPack,
} from '../../src/rollover/pack-loader';
import { SEASONAL_WINDOWS } from '../../src/rollover/seasonal-window';

// Issue #88 — the TS half of the schema-agreement guard.
//
// content/schema/question-pack.schema.json is mirrored by TWO hand-written
// strict parsers. The Dart one (content/validator/validator_core.dart) has
// carried validateSchemaAgreement() since M3.1: every vocabulary and bound it
// enforces is compared against the schema file itself, and drift is a red CI
// gate. This side had nothing. So adding a value to the schema + the Dart
// validator while forgetting pack-loader.ts produced content that passed the
// authoring gate AND CI, then threw PackParseError at rollover time in
// production — the exact failure class the Dart check exists to prevent, one
// language over. (Surfaced while writing ADR-026, which widened the surface by
// one more vocabulary; filed rather than smuggled into that diff.)
//
// SCOPE, decided and recorded (the issue asks for the enums; this covers every
// schema-derived rule the TS parser holds, which is strictly more):
//   - the FOUR vocabularies, compared to the exported constants, ORDER included
//     (the Dart side compares ordered lists too — a reordered enum is a diff
//     worth seeing);
//   - the two field-name sets and the required-field lists;
//   - the depth bounds and the id pattern.
// The last three are asserted BEHAVIOURALLY — driven from the schema's own
// values through parseQuestionPack — rather than by comparing constants,
// because PACK_FIELDS/QUESTION_FIELDS/ID_PATTERN and the depth literals are
// module-private. Exporting parser internals purely so a test can read them
// would put a test seam on the production API for no other caller; driving the
// real parser proves more anyway, since it checks what the parser DOES rather
// than what it declares.

const SCHEMA_PATH = fileURLToPath(
  new URL('../../../content/schema/question-pack.schema.json', import.meta.url),
);

interface SchemaNode {
  type?: string;
  enum?: string[];
  pattern?: string;
  minimum?: number;
  maximum?: number;
  required?: string[];
  properties?: Record<string, SchemaNode>;
  items?: SchemaNode;
}

const schema = JSON.parse(readFileSync(SCHEMA_PATH, 'utf8')) as SchemaNode;

function node(path: string, value: SchemaNode | undefined): SchemaNode {
  if (value === undefined) {
    throw new Error(
      `schema shape changed: ${path} not found in question-pack.schema.json — ` +
        'update this guard with it',
    );
  }
  return value;
}

const packProps = node('properties', schema.properties) as Record<string, SchemaNode>;
const questionSchema = node(
  'properties.questions.items',
  node('properties.questions', packProps.questions).items,
);
const questionProps = node(
  'properties.questions.items.properties',
  questionSchema.properties,
) as Record<string, SchemaNode>;

/**
 * A pack that satisfies the schema and carries EVERY property the schema
 * declares, optional ones included. Carrying them all is what keeps the
 * delete-a-field tests below from going vacuous, and a test asserts the
 * coverage so a future schema field cannot quietly skip this fixture.
 */
function validPack(): Record<string, unknown> {
  return {
    packId: 'solo_tr',
    version: 1,
    locale: 'tr',
    register: 'neutral',
    reviewedBy: 'someone',
    questions: [
      {
        id: 'solo_tr_001',
        category: 'gratitude',
        depth: 1,
        text: 'Soru?',
        seasonalWindow: 'ramadan',
      },
    ],
  };
}

function question(pack: Record<string, unknown>): Record<string, unknown> {
  return (pack.questions as Record<string, unknown>[])[0];
}

function parse(pack: Record<string, unknown>): void {
  parseQuestionPack(pack, 'solo_tr.json');
}

describe('the TS parser agrees with content/schema/question-pack.schema.json', () => {
  it('parses the reference pack this file builds (the guard is not vacuous)', () => {
    expect(() => parse(validPack())).not.toThrow();
  });

  it('the reference pack carries every property the schema declares', () => {
    // The delete-a-field tests below can only prove anything about fields the
    // fixture actually has. Asserting the coverage here means a new schema
    // property forces a fixture update instead of silently thinning them out.
    expect(Object.keys(validPack()).sort()).toEqual(Object.keys(packProps).sort());
    expect(Object.keys(question(validPack())).sort()).toEqual(
      Object.keys(questionProps).sort(),
    );
  });

  const vocabularies: [string, SchemaNode | undefined, readonly string[]][] = [
    ['locale', packProps.locale, PACK_LOCALES],
    ['register', packProps.register, PACK_REGISTERS],
    ['questions.items.category', questionProps.category, QUESTION_CATEGORIES],
    ['questions.items.seasonalWindow', questionProps.seasonalWindow, SEASONAL_WINDOWS],
  ];

  it.each(vocabularies)('schema "%s" enum == the TS constant', (field, schemaNode, tsValues) => {
    const schemaValues = node(field, schemaNode).enum;
    expect(
      schemaValues,
      `schema "${field}" has no enum — update both together`,
    ).toBeDefined();
    expect(
      schemaValues,
      `schema "${field}" enum ${JSON.stringify(schemaValues)} != TS ` +
        `${JSON.stringify(tsValues)} — update both together`,
    ).toEqual([...tsValues]);
  });

  it('covers EVERY enum the schema declares (a new vocabulary cannot slip past)', () => {
    // Without this, adding a fifth enum to the schema would leave the TS side
    // unguarded again and nothing would say so — the same silence this file
    // exists to end.
    const declared: string[] = [];
    for (const [name, value] of Object.entries(packProps)) {
      if (value.enum !== undefined) declared.push(name);
    }
    for (const [name, value] of Object.entries(questionProps)) {
      if (value.enum !== undefined) declared.push(`questions.items.${name}`);
    }
    expect(declared.sort()).toEqual(vocabularies.map(([field]) => field).sort());
  });

  // Each schema field is PUT ON the document with a dummy value: whether the
  // parser then likes the value is irrelevant — what must never happen is
  // "unknown field", which is the parser saying the schema declares something
  // it has never heard of. (The first version of this test looped over the
  // names without setting them, and a mutant that added a schema property
  // sailed through it. Vacuous loops read exactly like real ones.)
  const DUMMY = '__agreement_probe__';

  it('knows every pack field the schema declares, and no others', () => {
    for (const field of Object.keys(packProps)) {
      const pack = validPack();
      pack[field] = DUMMY;
      let message = '';
      try {
        parse(pack);
      } catch (error) {
        message = error instanceof Error ? error.message : String(error);
      }
      expect(
        message,
        `the schema declares pack field "${field}" and the TS parser does not ` +
          'know it — update both together',
      ).not.toMatch(/unknown pack field/);
    }
    const withStranger = validPack();
    withStranger.notInTheSchema = DUMMY;
    expect(() => parse(withStranger)).toThrowError(/unknown pack field/);
  });

  it('knows every question field the schema declares, and no others', () => {
    for (const field of Object.keys(questionProps)) {
      const pack = validPack();
      question(pack)[field] = DUMMY;
      let message = '';
      try {
        parse(pack);
      } catch (error) {
        message = error instanceof Error ? error.message : String(error);
      }
      expect(
        message,
        `the schema declares question field "${field}" and the TS parser does ` +
          'not know it — update both together',
      ).not.toMatch(/unknown question field/);
    }
    const withStranger = validPack();
    question(withStranger).notInTheSchema = DUMMY;
    expect(() => parse(withStranger)).toThrowError(/unknown question field/);
  });

  it('requires every field the schema marks required (pack level)', () => {
    const required = node('required', { required: schema.required }).required ?? [];
    expect(required.length).toBeGreaterThan(0);
    for (const field of required) {
      const pack = validPack();
      delete pack[field];
      expect(() => parse(pack), `the parser accepts a pack missing "${field}"`).toThrowError(
        PackParseError,
      );
    }
  });

  it('requires every field the schema marks required (question level)', () => {
    const required = questionSchema.required ?? [];
    expect(required.length).toBeGreaterThan(0);
    for (const field of required) {
      const pack = validPack();
      delete question(pack)[field];
      expect(
        () => parse(pack),
        `the parser accepts a question missing "${field}"`,
      ).toThrowError(PackParseError);
    }
  });

  it('treats every field the schema marks OPTIONAL as optional', () => {
    // The loosening direction of drift: the schema (and the Dart gate that
    // follows it) says a field may be omitted, while this parser still demands
    // it — content passes authoring and throws at rollover, the same failure
    // this file exists to prevent, running the other way.
    const packOptional = Object.keys(packProps).filter(
      (field) => !(schema.required ?? []).includes(field),
    );
    const questionOptional = Object.keys(questionProps).filter(
      (field) => !(questionSchema.required ?? []).includes(field),
    );
    expect(packOptional.length + questionOptional.length).toBeGreaterThan(0);
    for (const field of packOptional) {
      const pack = validPack();
      delete pack[field];
      expect(
        () => parse(pack),
        `the schema allows a pack without "${field}"; the TS parser requires it ` +
          '— update both together',
      ).not.toThrow();
    }
    for (const field of questionOptional) {
      const pack = validPack();
      delete question(pack)[field];
      expect(
        () => parse(pack),
        `the schema allows a question without "${field}"; the TS parser requires ` +
          'it — update both together',
      ).not.toThrow();
    }
  });

  it('enforces the schema depth bounds exactly', () => {
    const depth = node('questions.items.depth', questionProps.depth);
    const min = depth.minimum;
    const max = depth.maximum;
    expect(min, 'schema depth has no minimum').toBeTypeOf('number');
    expect(max, 'schema depth has no maximum').toBeTypeOf('number');
    for (const inside of [min!, max!]) {
      const pack = validPack();
      question(pack).depth = inside;
      expect(() => parse(pack), `the parser rejects depth ${inside}`).not.toThrow();
    }
    for (const outside of [min! - 1, max! + 1]) {
      const pack = validPack();
      question(pack).depth = outside;
      expect(() => parse(pack), `the parser accepts depth ${outside}`).toThrowError(/depth/);
    }
  });

  it('enforces the schema id pattern on packId and question id', () => {
    const packIdPattern = node('packId', packProps.packId).pattern;
    const questionIdPattern = node('questions.items.id', questionProps.id).pattern;
    expect(packIdPattern).toBe(questionIdPattern);
    const violating = 'Not-Matching';
    expect(new RegExp(packIdPattern!).test(violating)).toBe(false);
    const badPack = validPack();
    badPack.packId = violating;
    expect(() => parse(badPack)).toThrowError(/packId/);
    const badQuestion = validPack();
    question(badQuestion).id = violating;
    expect(() => parse(badQuestion)).toThrowError(/question id/);
  });
});
