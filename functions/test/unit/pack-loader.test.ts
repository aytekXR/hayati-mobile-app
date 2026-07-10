import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import * as path from 'node:path';
import { fileURLToPath } from 'node:url';

import { afterAll, describe, expect, it } from 'vitest';

import {
  PackParseError,
  UnknownPackError,
  bundledPacksDir,
  loadQuestionPack,
  parseQuestionPack,
} from '../../src/rollover/pack-loader';

// M3.2 pack consumption edge (ADR-011): the validator (content/validator/) is
// the single content GATE, CI-enforced on every push; this parser is
// defense-in-depth at the point of consumption, mirroring the app's loud
// questionPackFromJson (question_pack_dto.dart). Every deviation from
// content/schema/question-pack.schema.json must throw, never coerce.

const REPO_PACKS_DIR = fileURLToPath(new URL('../../../content/packs', import.meta.url));

// A minimal schema-valid pack; reject-cases mutate copies of it.
function validPack(): Record<string, unknown> {
  return {
    packId: 'solo_tr',
    version: 1,
    locale: 'tr',
    register: 'neutral',
    questions: [
      { id: 'solo_tr_001', category: 'gratitude', depth: 1, text: 'Soru?' },
      { id: 'solo_tr_002', category: 'deep', depth: 3, text: 'Derin soru?', seasonalWindow: 'ramadan' },
    ],
  };
}

function expectParseError(mutate: (pack: Record<string, unknown>) => void, pattern: RegExp): void {
  const pack = validPack();
  mutate(pack);
  expect(() => parseQuestionPack(pack, 'solo_tr.json')).toThrowError(PackParseError);
  expect(() => parseQuestionPack(pack, 'solo_tr.json')).toThrowError(pattern);
}

describe('parseQuestionPack', () => {
  it('parses a schema-valid pack, carrying seasonalWindow verbatim', () => {
    const pack = parseQuestionPack(validPack(), 'solo_tr.json');
    expect(pack.packId).toBe('solo_tr');
    expect(pack.version).toBe(1);
    expect(pack.locale).toBe('tr');
    expect(pack.register).toBe('neutral');
    expect(pack.questions).toHaveLength(2);
    expect(pack.questions[0]).toEqual({
      id: 'solo_tr_001',
      category: 'gratitude',
      depth: 1,
      text: 'Soru?',
      seasonalWindow: undefined,
    });
    expect(pack.questions[1].seasonalWindow).toBe('ramadan');
  });

  it('accepts an optional reviewedBy string', () => {
    const raw = validPack();
    raw.reviewedBy = 'someone';
    expect(parseQuestionPack(raw, 'solo_tr.json').packId).toBe('solo_tr');
  });

  it('rejects a non-object root', () => {
    expect(() => parseQuestionPack('nope', 'solo_tr.json')).toThrowError(PackParseError);
    expect(() => parseQuestionPack(null, 'solo_tr.json')).toThrowError(/not a JSON object/);
    expect(() => parseQuestionPack([1], 'solo_tr.json')).toThrowError(/not a JSON object/);
  });

  it('rejects unknown pack-level fields (additionalProperties: false)', () => {
    expectParseError((p) => {
      p.surprise = true;
    }, /unknown pack field 'surprise'/);
  });

  it('rejects unknown question fields', () => {
    expectParseError((p) => {
      (p.questions as Record<string, unknown>[])[0].extra = 1;
    }, /unknown question field 'extra'/);
  });

  it('rejects a missing or mistyped packId', () => {
    expectParseError((p) => {
      delete p.packId;
    }, /packId/);
    expectParseError((p) => {
      p.packId = 'Solo-TR';
    }, /packId/);
  });

  it('rejects a non-integer or sub-1 version (1.0 doubles included)', () => {
    expectParseError((p) => {
      p.version = 1.5;
    }, /version/);
    expectParseError((p) => {
      p.version = 0;
    }, /version/);
    expectParseError((p) => {
      p.version = '1';
    }, /version/);
  });

  it('rejects out-of-vocabulary locale, register, and category', () => {
    expectParseError((p) => {
      p.locale = 'de';
    }, /locale/);
    expectParseError((p) => {
      p.register = 'formal';
    }, /register/);
    expectParseError((p) => {
      (p.questions as Record<string, unknown>[])[0].category = 'romance';
    }, /category/);
  });

  it('rejects depth outside 1..5 or non-integer', () => {
    expectParseError((p) => {
      (p.questions as Record<string, unknown>[])[0].depth = 0;
    }, /depth/);
    expectParseError((p) => {
      (p.questions as Record<string, unknown>[])[0].depth = 6;
    }, /depth/);
    expectParseError((p) => {
      (p.questions as Record<string, unknown>[])[0].depth = 1.5;
    }, /depth/);
  });

  it('rejects empty or mistyped question text and ids', () => {
    expectParseError((p) => {
      (p.questions as Record<string, unknown>[])[0].text = '';
    }, /text/);
    expectParseError((p) => {
      (p.questions as Record<string, unknown>[])[0].id = 'UPPER';
    }, /question id/);
  });

  it('rejects an empty seasonalWindow (absent means evergreen, empty is junk)', () => {
    expectParseError((p) => {
      (p.questions as Record<string, unknown>[])[1].seasonalWindow = '';
    }, /seasonalWindow/);
  });

  it('rejects duplicate question ids within the pack', () => {
    expectParseError((p) => {
      const questions = p.questions as Record<string, unknown>[];
      questions[1].id = questions[0].id;
    }, /duplicate question id/);
  });

  it('rejects an empty questions array', () => {
    expectParseError((p) => {
      p.questions = [];
    }, /questions/);
  });

  it('rejects a mistyped reviewedBy', () => {
    expectParseError((p) => {
      p.reviewedBy = 42;
    }, /reviewedBy/);
  });
});

describe('loadQuestionPack', () => {
  it('loads every real authored pack through the strict parser', () => {
    for (const packId of ['solo_tr', 'solo_ar', 'solo_en']) {
      const pack = loadQuestionPack(packId, REPO_PACKS_DIR);
      expect(pack.packId).toBe(packId);
      expect(pack.version).toBeGreaterThanOrEqual(1);
      expect(pack.questions.length).toBe(7);
    }
  });

  it('throws UnknownPackError for a packId with no bundled file', () => {
    expect(() => loadQuestionPack('no_such_pack', REPO_PACKS_DIR)).toThrowError(UnknownPackError);
    expect(() => loadQuestionPack('no_such_pack', REPO_PACKS_DIR)).toThrowError(/no_such_pack/);
  });

  describe('with corrupt fixture files', () => {
    const fixtureDir = mkdtempSync(path.join(tmpdir(), 'hayati-packs-'));
    afterAll(() => {
      rmSync(fixtureDir, { recursive: true, force: true });
    });

    it('throws PackParseError on invalid JSON', () => {
      writeFileSync(path.join(fixtureDir, 'broken.json'), '{ not json');
      expect(() => loadQuestionPack('broken', fixtureDir)).toThrowError(PackParseError);
      expect(() => loadQuestionPack('broken', fixtureDir)).toThrowError(/invalid JSON/);
    });

    it('throws when the file content declares a different packId (filename contract)', () => {
      const impostor = validPack();
      writeFileSync(path.join(fixtureDir, 'imposter.json'), JSON.stringify(impostor));
      expect(() => loadQuestionPack('imposter', fixtureDir)).toThrowError(
        /declares packId 'solo_tr'/,
      );
    });
  });
});

describe('bundledPacksDir', () => {
  it('points at lib/content/packs under the functions root', () => {
    expect(bundledPacksDir().endsWith(path.join('lib', 'content', 'packs'))).toBe(true);
  });
});
