import { existsSync, readFileSync, readdirSync } from 'node:fs';
import * as path from 'node:path';
import { fileURLToPath } from 'node:url';

import { describe, expect, it } from 'vitest';

import { loadQuestionPack } from '../../src/rollover/pack-loader';

// Build-artifact guard (ADR-011): `npm run build` must leave lib/content/packs
// a byte-identical copy of content/packs (scripts/bundle-packs.mjs), the same
// discipline the validator enforces for app/assets/content (ADR-010). The
// full suite always runs after a build (the functions emulator require()s
// lib/index.js, so CI and the documented local command both build first) —
// if lib/ is missing, fail with the fix, never skip.

const REPO_PACKS_DIR = fileURLToPath(new URL('../../../content/packs', import.meta.url));
const LIB_PACKS_DIR = fileURLToPath(new URL('../../lib/content/packs', import.meta.url));

describe('bundled packs (lib/content/packs)', () => {
  it('exist after a build', () => {
    expect(
      existsSync(LIB_PACKS_DIR),
      `missing ${LIB_PACKS_DIR} — run \`npm run build\` (tsc + bundle-packs) first`,
    ).toBe(true);
  });

  it('are byte-identical to the authoring tree, with no orphans', () => {
    const authored = readdirSync(REPO_PACKS_DIR).filter((name) => name.endsWith('.json')).sort();
    const bundled = readdirSync(LIB_PACKS_DIR).filter((name) => name.endsWith('.json')).sort();
    expect(bundled).toEqual(authored);
    for (const name of authored) {
      const source = readFileSync(path.join(REPO_PACKS_DIR, name));
      const copy = readFileSync(path.join(LIB_PACKS_DIR, name));
      expect(copy.equals(source), `${name} drifted from content/packs — rebuild`).toBe(true);
    }
  });

  it('every bundled pack loads through the strict parser', () => {
    for (const name of readdirSync(LIB_PACKS_DIR).filter((n) => n.endsWith('.json'))) {
      const packId = name.replace(/\.json$/, '');
      expect(loadQuestionPack(packId, LIB_PACKS_DIR).packId).toBe(packId);
    }
  });
});
