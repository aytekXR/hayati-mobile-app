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
      //
      // notifications/fcm-adapter.ts is the same class of runtime-only wiring:
      // the production MessagingPort over firebase-admin/messaging (getMessaging
      // has no emulator), so its send() is never observed in-process — the
      // in-process suites inject a fake MessagingPort instead (ADR-012). All
      // decidable notification logic lives in the covered pure modules
      // (payload-policy, local-hour, recipients).
      exclude: ['src/index.ts', 'src/notifications/fcm-adapter.ts'],
      reporter: ['text', 'lcov'],
      // ADR-079 D4. PER-METRIC, because one number for all four is what made
      // the old table unusable: measured 2026-09-13 the suite is
      // 97.43 stmts / 92.81 branches / 97.78 funcs / 97.68 lines, so BRANCHES is
      // the binding metric at 92.81 and lines at 97.68 is not. A single 80
      // hid that.
      //
      // ⚠️ These were 80/80/80/80 against a suite at ~97 — 17.7 points of slack
      // on lines, and the same shape as the app gate ADR-079 is about: a
      // threshold so far below the measurement that it cannot catch a
      // regression. test-suite.md §3 also named an "85% target" that existed in
      // NO config; it is gone rather than carried forward, because a target
      // nothing measures is how §3 came to promise a `domain/` gate that was
      // never built.
      //
      // ⚠️ ASYMMETRY, recorded rather than left to be discovered: the Dart gate
      // polices its own currency (`coverage_gate.dart --max-slack` fails when
      // the floor drifts too far below reality). Vitest has no such concept, so
      // THESE NUMBERS CAN GO STALE THE OLD WAY. Parity would mean wrapping
      // vitest the way coverage_gate.dart wraps lcov; not done here.
      thresholds: {
        lines: 95,
        functions: 95,
        branches: 90,
        statements: 95,
      },
    },
  },
});
