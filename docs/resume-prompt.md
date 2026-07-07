# Resume Prompt

> This file contains ONE and only ONE objective. Every session executes ONLY this file. (See `project-rules.md` #1, `session-rules.md`.)
>
> **Standing gate note:** Gate 1 (content validation, `roadmap.md` Phase 0) must PASS before any session beyond milestone M0 is scheduled here. Gate 1 had not passed as of 2026-07-08 (Phase 0 content ops just starting), so M1.1 remains unscheduled; this objective is Phase-0-parallel content tooling, allowed by `implementation-plan.md` cross-cutting rules ("the pack validator is the only code dependency" of content authoring) and `agent-workflows.md` W8 (product questions and TikTok hooks share one pipeline through `content/` packs).
>
> **Standing sequencing note (ADR-006):** iOS-first — milestones validate and ship on iOS first; Android work is re-sequenced into M6.5.

## Objective — Session 003: Content pack validator v1 (Phase-0 content-ops tooling)

Replace the `content/validator/validate.dart` placeholder (exits 1 by design, unwired) with a real validator, TDD throughout (domain logic — test-first is mandatory per `session-rules.md` §2):

1. **Validation rules** against `content/schema/question-pack.schema.json` and `content/README.md`: pack metadata well-formed (locale ∈ {tr, ar, en}; register enums incl. dual-register TR per `prd.md`); question ids unique within a pack and across packs of the same locale; non-empty question text; category/depth within schema ranges; `seasonalWindow` well-formed when present; duplicate question text per locale rejected; pack filename ↔ metadata consistency. Implement only the JSON-Schema subset our schema actually uses — this is a pack linter, not a spec-complete validator.
2. **Testability**: structure so the rules are unit-tested (small package with `pubspec.yaml` + `test/`, or equivalent — session's design call). Red → green per rule class.
3. **Fixtures**: one valid pack + one invalid fixture per violation class under a test fixtures dir; validator exits 0 on clean, 1 with an actionable per-error report (file, question id, rule) on violations.
4. **CI wiring**: add one step to the `quality` job in `.github/workflows/ci.yml` (after `rtl lint`): run the validator over `content/packs/`. `content/packs/en.example.json` must pass (fix it if the schema tightened).
5. **Docs-with-code**: update `content/README.md` (rules list, how to run); note the validator's arrival in `docs/implementation-plan.md` M3 item (it lands early, Phase-0-parallel — M3 will consume, not build, it).

**Acceptance criteria:** `flutter test`/`dart test` green including validator unit tests; each invalid fixture class rejected with an actionable message (demonstrated in tests); example pack passes; CI `quality` job runs the validator and stays green; coverage gate still ≥60%; docs updated in the same PR.

**Files likely to change:** `content/validator/` (real implementation + tests + pubspec), `content/packs/en.example.json`, `content/README.md`, `.github/workflows/ci.yml` (one step), `docs/implementation-plan.md` (M3 note), `docs/past-prompts.md`, this file.

**Validation steps:** local validator run over `content/packs/` (clean + seeded-violation fixtures); full local gate sequence (`dart format` → `flutter analyze` → `dart tool/rtl_lint.dart app/lib` → `flutter test --coverage` → `dart tool/coverage_gate.dart --min 60 app/coverage/lcov.info`); push PR; `gh pr checks --watch`; squash-merge; `gh run watch` on main.

**Complexity:** low-medium. **Estimated duration:** one session (1–3 h).

**Stopping conditions:** if schema-conformance checking balloons toward full JSON-Schema semantics, implement only the subset our schema uses and file a `ci-debt` issue for the rest; if the dual-register/locale enum set is ambiguous in the docs, validate the uncontested subset and file a docs issue rather than inventing enum values.

**Explicitly out of scope this session:** remote pack sync and in-app bundling (M3); authoring real TR/AR packs (content ops, non-code); Firebase/M1 anything (Gate 1 standing note); Ramadan window *logic* (M3 rollover — only the `seasonalWindow` *shape* is validated here).

On completion, follow `session-rules.md` §3: append to `past-prompts.md`, regenerate this file with the next single objective (expected: M1.1 — Firebase project + Auth foundation, *only if Gate 1 has passed per the standing gate note; otherwise the highest-priority unblocked Phase-0 task, e.g. TikTok slideshow-generation tooling from the `brandkit/` question-card templates*), commit, push, verify CI via `gh run watch`.
