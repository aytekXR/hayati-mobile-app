# Resume Prompt

> This file contains ONE and only ONE objective. Every session executes ONLY this file. (See `project-rules.md` #1, `session-rules.md`.)
>
> **Standing gate note:** Gate 1 (content validation, `roadmap.md` Phase 0) must PASS before any session beyond milestone M0 is scheduled here.
>
> **Standing sequencing note (ADR-006):** iOS-first — milestones validate and ship on iOS first; Android work is re-sequenced into M6.5.

## Objective — Session 002: M0.2 — GitHub Actions CI, branch protection, repo process skeleton

Stand up the validation pipeline per `implementation-plan.md` M0 item 2 and `architecture.md` §9:

1. `.github/workflows/ci.yml` on every push/PR (ubuntu runner is sufficient — all M0 checks are platform-neutral): `dart format --set-exit-if-changed` → `flutter analyze` → `dart tool/rtl_lint.dart app/lib` → `flutter test --coverage` → coverage gate ≥60% (ratchet note: +2%/milestone per `test-suite.md` §3) → `flutter build ios --no-codesign --debug` on a macos runner as the iOS-first build smoke (ADR-006).
2. Branch protection on `main` via `gh api`: require the `ci.yml` checks, no force pushes. (Solo-founder: self-merge allowed, green required — `project-rules.md` #7.)
3. PR template with the W3 sections: Objective (resume-prompt link) / Tests added / Docs touched / Screens (goldens both directions) / Risk.
4. ADR skeleton: `docs/adr/README.md` (format note) + backfill ADR-001..005 as short records from `architecture.md` §11 (ADR-006 already exists).
5. Fastlane init: minimal `fastlane/` skeleton with iOS lane stub only (ADR-006 — Android lanes come with M6.5); no signing secrets in repo.

**Acceptance criteria:** a pushed PR shows all checks running and green; a deliberately failing test on a branch blocks merge (prove it, then remove the failing test); `gh run watch` green on `main` after merge; coverage gate demonstrably enforced (job fails below threshold); ADR files exist and are linked from `architecture.md` §11.

**Files likely to change:** `.github/workflows/ci.yml`, `.github/pull_request_template.md`, `docs/adr/README.md`, `docs/adr/001..005-*.md`, `fastlane/`, `docs/architecture.md` (§11 links), `docs/past-prompts.md`, this file.

**Validation steps:** local `flutter test` + `flutter analyze` + `dart tool/rtl_lint.dart app/lib` before push; then the failing-test branch-protection proof; then `gh run watch`.

**Complexity:** medium (CI matrix + macos runner quirks are the risk). **Estimated duration:** one session (1–3 h).

**Stopping conditions:** if the macos iOS build smoke proves flaky or slow beyond ~15 min of fixing, drop it to a follow-up issue (`ci-debt` label) and keep the ubuntu pipeline as the merge gate — do not let the session overflow; if branch-protection API needs plan permissions the account lacks, document and defer that single item.

**Explicitly out of scope this session:** Firebase wiring (M1), any feature code, store-level flavor split (arrives with Fastlane release work, not `ci.yml`), `release.yml` (that belongs to M6/M6.5 release hardening).

On completion, follow `session-rules.md` §3: append to `past-prompts.md`, regenerate this file with the next single objective (expected: M1.1 — Firebase project + Auth foundation, *only if Gate 1 status permits per the standing gate note; otherwise the highest-priority unblocked M0/Phase-0 task*), commit, push, verify CI via `gh run watch`.
