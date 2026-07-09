import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    environment: 'node',
    // Emulator-backed suites share one firestore emulator and clear it between
    // files; parallel files would race each other's clearFirestore().
    fileParallelism: false,
    // The contended-transaction tests (concurrent createInvite) involve a
    // server-side lock wait + the admin SDK's ABORTED retry backoff (~1s
    // initial delay) — on a 2-core CI runner that legitimately exceeds the
    // 5s default (observed: PR #20 first run). Unit tests finish in ms
    // regardless, so one generous ceiling beats per-test annotations.
    testTimeout: 30_000,
    coverage: {
      provider: 'v8',
      include: ['src/**/*.ts'],
      // index.ts is runtime wiring (initializeApp + re-exports) that only
      // executes inside the Functions emulator/runtime process, which v8
      // coverage cannot observe. Everything with logic lives in modules that
      // ARE covered in-process.
      exclude: ['src/index.ts'],
      reporter: ['text', 'lcov'],
      // test-suite.md §3: Functions target 85%, HARD FAIL below 80. Thresholds
      // here are the hard gate; the 85% target is reviewed per PR, not enforced.
      thresholds: {
        lines: 80,
        functions: 80,
        branches: 80,
        statements: 80,
      },
    },
  },
});
