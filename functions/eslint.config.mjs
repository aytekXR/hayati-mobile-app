// Flat config (eslint 10). Lean on typescript-eslint's recommended set; the
// real quality gates are tsc --strict and the vitest coverage thresholds.
import tseslint from 'typescript-eslint';

export default tseslint.config(
  { ignores: ['lib/', 'coverage/', 'node_modules/'] },
  ...tseslint.configs.recommended,
);
