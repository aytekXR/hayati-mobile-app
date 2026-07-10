// Build-time pack bundling (ADR-011): byte-copies content/packs/*.json into
// lib/content/packs/ so the deployed rollover Function reads the exact bytes
// the validator gated (ADR-010 keeps content/packs/ the single authoring
// home). Runs as part of `npm run build`; test/unit/pack-bundle.test.ts
// fails the suite if this copy ever rots.
import { copyFileSync, mkdirSync, readdirSync, rmSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const functionsDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const sourceDir = path.resolve(functionsDir, '..', 'content', 'packs');
const destDir = path.join(functionsDir, 'lib', 'content', 'packs');

rmSync(destDir, { recursive: true, force: true });
mkdirSync(destDir, { recursive: true });

const packFiles = readdirSync(sourceDir).filter((name) => name.endsWith('.json'));
if (packFiles.length === 0) {
  throw new Error(`no packs found under ${sourceDir}`);
}
for (const name of packFiles) {
  copyFileSync(path.join(sourceDir, name), path.join(destDir, name));
}
console.log(`bundle-packs: copied ${packFiles.length} packs -> ${destDir}`);
