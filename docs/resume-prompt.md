# Resume Prompt

> This file contains ONE and only ONE objective. Every session executes ONLY this file. (See `project-rules.md` #1, `session-rules.md`.)
>
> **Standing de-gating note (ADR-007):** engineering milestones M1→M6 proceed without content-ops preconditions. Gates 1–3 are decision instruments for marketing/spend/launch posture, not build blockers. TikTok/content-ops work is out of session scope unless the founder re-activates it. First release target: the founder couple's own devices (personal-use-first).
>
> **Standing sequencing note (ADR-006):** iOS-first — milestones validate and ship on iOS first; Android work is re-sequenced into M6.5.
>
> **Standing tooling note (CodeGraph, founder directive 2026-07-09):** orient with CodeGraph at session start and use it for symbol/call-path/impact navigation throughout — `codegraph_explore`/`codegraph_node` MCP tools (CLI fallback `codegraph explore|node|callers`); sub-agents and workflow agents use the same tools via ToolSearch. Before the session ends, `codegraph sync` after the merge (session-rules §1 step 4 / §3 step 5). The index is machine-local (`.codegraph/`, gitignored).

## Objective — Session 007: M2.1 — Functions workspace + invite Function (pairing code) + rules hardening, emulator-tested (opens M2, the highest-risk milestone)

First slice of M2 (`implementation-plan.md`). M1 closed in Session 006 (PR #18). M2 owns the activation gate: invite → preview → transactional join. This session lands the backend foundation the rest of M2 stands on — the repo's **first Cloud Functions (TypeScript) code** and the pairing data model with its rules invariants:

1. **Functions workspace bootstrap** (`functions/` at the repo root): TypeScript, firebase-functions v2 (Node 20), eslint + vitest/jest, `firebase.json` wiring so `firebase emulators:exec` covers functions alongside auth/firestore. Coverage tooling for TS with the `test-suite.md` §3 gate: Functions 85% target, **hard fail <80%**.
2. **`createInvite` callable Function**: issues a pairing code for the caller — writes `invites/{code}` `{creatorUid, expiresAt, status: 'pending'}` (`architecture.md` §3). Code generation must be collision-safe and unambiguous (property-test charset/length/collision behavior); expiry set server-side; re-issue policy decided and documented (one active invite per creator — revoke-or-return, don't accumulate). App Check posture consistent with M1.3: token plumbed, **enforcement stays OFF** (on-device attestation still unverified — past-prompts Session 005).
3. **Rules hardening** (`firestore.rules`): `invites/{code}` function-write-only (client read limited to what preview needs — decide and document; deny-by-default stands); `couples/{coupleId}` member-only read/write skeleton; the `users/{uid}.createdAt` create-once immutability promised in `architecture.md` §3 (M1.2 stamped it client-side; rules must now enforce it).
4. **Rules + Function tests on the emulator, per-PR on ubuntu**: `@firebase/rules-unit-testing` suite for the §3 invariants touched here (non-member cannot read couple docs; invites are function-write-only; expired invite unusable) + Function unit/integration tests against the emulator. These run on **linux** — add a cheap ubuntu CI job (per-PR, unlike the macOS `integration-emulator` leg) so rules regressions are pre-merge signals.
5. **Docs-with-code:** `architecture.md` §3 (shipped-rules paragraph) + §9 (new CI job), `implementation-plan.md` M2 progress note, ADR only if an alternative was genuinely weighed (e.g. callable vs HTTPS+App Check for `createInvite`).

**Acceptance criteria:** `createInvite` issues a code against the emulator and the write lands in `invites/{code}` with server-set expiry; a second concurrent issue attempt honors the documented re-issue policy; rules tests prove function-write-only invites, member-only couples, create-once `createdAt`, and **fail red when the protecting rule is commented out** (prove the net, don't just assert green); Functions coverage ≥85% with the hard-fail gate wired into CI; the new ubuntu rules/functions CI job runs per-PR and is green; `flutter analyze`/format/rtl lint/coverage 62 gate untouched and green (no app-side code this session unless a shared constant is genuinely needed).

**External dependencies (founder):** none for this session (emulator-first, `demo-hayati` credential-free). **Flag early:** deploying Functions to `hayatiapp-dev`/`hayatiapp-prod` requires the **Blaze plan** — not needed for M2.1 (emulator-only), but a founder decision before M2's first real-device pairing test. Still open from M1.3: enable Apple + Phone providers in both consoles (real-device sign-in only).

**Files likely to change:** `functions/**` (new workspace), `firebase.json`, `firestore.rules`, `.github/workflows/ci.yml` (new ubuntu functions/rules job), `docs/architecture.md`, `docs/implementation-plan.md`, `docs/test-suite.md` (Functions test tooling record), `docs/past-prompts.md`, this file.

**Validation steps:** `npm test` + coverage gate in `functions/`; `firebase emulators:exec --only auth,firestore,functions --project demo-hayati '<rules+function suites>'` locally; full Flutter gate sequence unchanged (`dart format` → `flutter analyze` → `dart tool/rtl_lint.dart app/lib` → `flutter test --coverage` → `dart tool/coverage_gate.dart --min 62 app/coverage/lcov.info`); push PR; `gh pr checks --watch`; squash-merge; `gh run watch` on main.

**Complexity:** medium-high (new toolchain: TS workspace, functions emulator, rules-unit-testing — none exist in the repo yet). **Estimated duration:** one session (1–3 h) — if it overflows, land the workspace + `createInvite` + its rules/tests and slice the `couples/` skeleton rules to the next prompt per session-rules §1.4.

**Stopping conditions:** if the functions emulator proves flaky in CI inside a 30-min timebox, keep the rules suite per-PR (it needs only the firestore emulator, which is proven) and move Function-against-emulator tests to the main-only macOS leg with an issue documenting why; if code-collision math turns into bikeshedding, pick 8 chars from an unambiguous 31-char alphabet (no 0/O/1/I/l) and move on.

**Explicitly out of scope this session:** deep link + WhatsApp share message (M2.2); partner preview endpoint + screen (M2.2/M2.3); transactional join + race rejection (M2.3); solo mode (M2.4); pairing UI in the app; issue #15 (phone emulator suite, needs a Mac); issue #13 (Android instant verification, M6.5); on-device App Attest/APNs/dSYM (Mac slice).

On completion, follow `session-rules.md` §3: append to `past-prompts.md`, regenerate this file with the next single objective (expected: M2.2 — deep link + WhatsApp share + partner preview endpoint), commit, push, verify CI via `gh run watch`, then `codegraph sync`.
