# Resume Prompt

> This file contains ONE and only ONE objective. Every session executes ONLY this file. (See `project-rules.md` #1, `session-rules.md`.)
>
> **Standing de-gating note (ADR-007):** engineering milestones M1→M6 proceed without content-ops preconditions. Gates 1–3 are decision instruments for marketing/spend/launch posture, not build blockers. TikTok/content-ops work is out of session scope unless the founder re-activates it. First release target: the founder couple's own devices (personal-use-first).
>
> **Standing sequencing note (ADR-006):** iOS-first — milestones validate and ship on iOS first; Android work is re-sequenced into M6.5.
>
> **Standing tooling note (CodeGraph, founder directive 2026-07-09):** orient with CodeGraph at session start and use it for symbol/call-path/impact navigation throughout — `codegraph_explore`/`codegraph_node` MCP tools (CLI fallback `codegraph explore|node|callers`); sub-agents and workflow agents use the same tools via ToolSearch. Before the session ends, `codegraph sync` after the merge (session-rules §1 step 4 / §3 step 5). The index is machine-local (`.codegraph/`, gitignored).
>
> **Standing toolchain note (M2.1):** the functions/rules emulator suites need Java 21+ on PATH (`~/.local/share/java/jdk-21.0.11+10-jre/bin` on this box — firebase-tools reads PATH only, never JAVA_HOME) and global `firebase-tools@15.22.4`. Build `functions/` first (`npm run build`) — the functions emulator never compiles TS. Full suite: `firebase emulators:exec --only auth,firestore,functions --project demo-hayati 'cd functions && npm run test:ci'` from the repo root.

## Objective — Session 008: M2.2 — invite share flow (deep link + WhatsApp message) + zero-auth partner preview endpoint

Second slice of M2 (`implementation-plan.md`). M2.1 landed in Session 007: `functions/` workspace, `createInvite` callable (europe-west1, one-active-invite policy), hardened rules with a mutation-proven suite, per-PR ubuntu `functions-rules` CI job. This session makes an invite **shareable and previewable**:

1. **`invitePreview` HTTP Function** (`onRequest`, zero-auth by design — the invitee has no account yet): `GET` with a code → `{status: 'valid'|'expired'|'unknown', creatorDisplayName?}`. **Never** exposes `creatorUid`, other invites, or (once M3 content exists) answer content — the §3 invariant "preview never leaks answer content" starts here as "preview exposes exactly the documented fields". Question-text preview is deferred to M3 (no questions exist yet); design the response shape so it can grow that field. Basic abuse posture: uniform response timing/shape for unknown vs expired (no enumeration oracle beyond validity), simple per-IP rate limit if cheap (document the decision either way — a real rate-limit story may need infrastructure that is out of scope).
2. **Deep link decision + wiring (app-side):** pick custom URL scheme (`hayati://invite/<code>`) now — universal links need Apple Developer enrollment + a hosted `apple-app-site-association` (flagged in FOUNDER-ACTIONS; upgrade path documented, ADR if genuinely weighed). Register the scheme in the iOS Runner; parse code from a cold-start/warm link into a pairing-feature entry point (state only — the join flow is M2.3).
3. **Invite share flow (app-side):** the M1 invite placeholder screen becomes real: calls `createInvite` via `cloud_functions` (region `europe-west1`, emulator wiring behind the existing dart-define pattern — `USE_FUNCTIONS_EMULATOR`), renders the code + expiry, share affordance producing the WhatsApp-formatted localized message (TR/AR/EN ARB strings; message = warm one-liner + code + deep link) through the system share sheet (`share_plus` or platform channel — evaluate, don't gold-plate). Widget tests across the six-cell golden matrix for the new screen states (has-code, loading, error).
4. **Tests:** preview endpoint suite in `functions/test/emulator/` (valid/expired/unknown; field-surface assertion — response contains ONLY documented keys; verify no `creatorUid` leak); app-side unit/widget tests for the controller + screen; rules untouched (no new collections). Functions coverage stays ≥85%/hard-fail 80; Flutter coverage gate 62 untouched.
5. **Docs-with-code:** `architecture.md` §3 (preview field surface) + §4 (pairing flow status), `implementation-plan.md` M2 progress note, `test-suite.md` if tooling changes, ADR only if an alternative was genuinely weighed (e.g. custom scheme vs universal links).

**Acceptance criteria:** `invitePreview` returns the documented shape for valid/expired/unknown codes against the emulator and the field-surface test proves nothing else leaks; the app screen (functions-emulator-backed integration test, or widget test with a faked repository seam if the plugin fights the harness — decide and document) shows a real code from `createInvite` and composes the localized share message with the deep link; cold-start deep link parsing is unit-tested; all four CI jobs green per-PR where applicable.

**External dependencies (founder):** none (emulator-first). **Blaze** becomes blocking next session (M2.3 first real-device pairing test) — decision flagged in FOUNDER-ACTIONS.md. Universal-links domain/enrollment question flagged there too (not blocking; custom scheme ships first).

**Files likely to change:** `functions/src/invites/` (+preview), `functions/test/emulator/`, `app/lib/features/pairing/**` (new feature dir), `app/lib/core/firebase/` (functions emulator wiring), iOS `Info.plist` (URL scheme), `app/lib/core/l10n/arb/*`, goldens for the invite screen, `docs/*`, this file.

**Validation steps:** functions suite via `emulators:exec` (see standing toolchain note); full Flutter gate sequence (`dart format` → `flutter analyze` → `dart tool/rtl_lint.dart app/lib` → `flutter test --coverage` → `dart tool/coverage_gate.dart --min 62 app/coverage/lcov.info`); push PR; `gh pr checks --watch`; squash-merge; `gh run watch` on main.

**Complexity:** medium — the functions side is now-familiar tooling; the risky part is `cloud_functions` plugin + emulator wiring in the app and share-sheet ergonomics. **Estimated duration:** one session (1–3 h). If it overflows: land `invitePreview` + its tests + the share-message l10n first; slice deep-link registration/parsing to M2.3 (it's consumed there anyway) per session-rules §1.4.

**Stopping conditions:** if `cloud_functions` emulator wiring fights the integration harness beyond a 30-min timebox, test the app-side repository seam with a fake and cover the real callable only in the functions-emulator suite (document in test-suite.md); if share-sheet plugins misbehave on the simulator, render the composed message with a copy-to-clipboard fallback and file the share-sheet polish as an issue.

**Explicitly out of scope this session:** transactional join + race rejection + preview *screen* (M2.3); solo mode (M2.4); question-text in preview (M3); universal links / associated domains (needs enrollment — FOUNDER-ACTIONS); any Functions deploy (Blaze); issue #15 (needs a Mac); issue #13 (Android, M6.5).

On completion, follow `session-rules.md` §3: append to `past-prompts.md`, regenerate this file with the next single objective (expected: M2.3 — transactional join + race rejection + partner preview screen), commit, push, verify CI via `gh run watch`, then `codegraph sync`.
