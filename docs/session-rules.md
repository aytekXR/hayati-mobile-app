# Session Rules — Hayati

The operating contract for every coding session. `project-rules.md` is the constitution; this is the procedure.

## 1. Start sequence

1. Read `project-rules.md` (skim, it's short and immutable).
2. Read `resume-prompt.md`. It contains exactly one objective. **That objective is the session. Nothing else is.**
3. Read the acceptance criteria of the relevant milestone in `implementation-plan.md`.
4. Orient with **CodeGraph** (founder directive 2026-07-09): `codegraph status` — sync if stale (the previous end sequence should have left it current; a fresh machine runs `codegraph init` once). For symbol/call-path/impact questions during the session, use the `codegraph_explore`/`codegraph_node` MCP tools (CLI fallback: `codegraph explore|node|callers`) instead of raw grep sweeps — and point sub-agents/workflow agents at the same tools (they reach MCP via ToolSearch). The index is machine-local (`.codegraph/`, gitignored).
5. Write a plan of ≤10 bullets before touching code. If the plan reveals the objective is mis-scoped (>1 session of work), split it: do the first coherent slice, and note the remainder for the next `resume-prompt.md` — do not stretch the session.

## 2. During the session

- **TDD:** failing test → minimal implementation → refactor. "Whenever practical" (rule #6) is interpreted strictly: UI polish and build config may skip test-first; all domain logic, Functions, and security rules may not.
- **Scope guard:** unrelated bugs/ideas discovered mid-session go to `gh issue create`, not into the diff. Drive-by refactors are scope creep wearing a helmet.
- **Docs-with-code:** if behavior or architecture changed, the doc changes in the same commit (rule #8). Compromises get a `// DEBT:` comment **and** an issue (rule #9).
- **Quality bar to declare done:** `flutter analyze` clean · all tests green locally · coverage gate satisfied · RTL goldens updated intentionally if UI touched · acceptance criteria demonstrably met.

## 3. End sequence (mandatory, in order)

1. Append a session entry to `past-prompts.md` (template in that file). Never edit prior entries.
2. Regenerate `resume-prompt.md`: inspect `roadmap.md` + current milestone progress + open `ci-debt` issues → choose the single highest-priority next task → write it with concrete acceptance criteria (rule #3). One objective only.
3. Refresh `docs/operator-expected.md` (founder directive, Session 009): what is expected from the founder right now, what becomes blocking soon, and the plan-progress/readiness snapshot. It is the committed, canonical founder checklist — the founder reads it instead of the session log.
4. `git add -A && git commit` (Conventional Commits: `feat(m2): partner preview screen with locked answer state`) `&& git push`.
5. `gh run watch` until the pipeline concludes. Green → session over. Red → quick fix (≤15 min) now and re-push; structural → `gh issue create --label ci-debt` with failing-log excerpt, note it in `past-prompts.md`, and only then end (rule #5). A session never ends with an *unexamined* red pipeline.
6. `codegraph sync` after the merge lands, so the local index reflects merged `main` — the next session's step-4 orientation depends on it (founder directive 2026-07-09).

## 4. Blocked protocol

Blocked on external factor (store review, credentials, waiting on Gate data): document the blocker in `past-prompts.md`, write a `resume-prompt.md` for the highest-priority *unblocked* task, end cleanly. Never idle-improvise features while blocked — that's how OUT-list items sneak in.

## 5. Timebox

A session targets one coherent objective, roughly 1–3 focused hours. If an objective repeatedly overflows, the fix is better slicing in `resume-prompt.md`, not longer sessions.
