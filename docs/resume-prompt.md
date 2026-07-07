# Resume Prompt

> This file contains ONE and only ONE objective. Every session executes ONLY this file. (See `project-rules.md` #1, `session-rules.md`.)
>
> **Standing gate note:** Gate 1 (content validation, `roadmap.md` Phase 0) must PASS before any session beyond milestone M0 is scheduled here.

## Objective — Session 001: M0.1 — Initialize repository scaffold

Create the Flutter project skeleton exactly per `architecture.md` §2:

1. Flutter app in `app/` with flavors `dev`/`prod` (`main_dev.dart`, `main_prod.dart`), org id `com.hayati.app` (placeholder pending trademark decision — keep bundle id trivially renameable, no hardcoded brand strings outside `core/config/`).
2. Folder structure: `core/` (design_system, l10n, analytics, storage, config, utils) and empty `features/` per the layout; Riverpod + codegen wired with one example provider.
3. Lint setup: `analysis_options.yaml` strict; custom lint or analyzer rule note enforcing logical `start/end` over `left/right`.
4. One example domain entity + failing-then-passing unit test proving the TDD harness works (`flutter test` green).
5. `content/` directory with the question-pack JSON schema stub + validator script placeholder.
6. Root `README` pointer to `docs/` (this documentation set moves into the repo as `docs/`).

**Acceptance criteria:** fresh clone → `flutter pub get && flutter test` green on both flavors; folder tree matches `architecture.md` §2; lint passes; no TODOs without linked issues.

**Explicitly out of scope this session:** CI pipeline (that is Session 002 / M0.2), Firebase wiring, any feature code.

On completion, follow `session-rules.md` §3: append to `past-prompts.md`, regenerate this file with the next single objective (expected: M0.2 — GitHub Actions CI + branch protection), commit, push, verify CI status via `gh` (noting CI does not exist until M0.2 — record that explicitly rather than skipping the step silently).
