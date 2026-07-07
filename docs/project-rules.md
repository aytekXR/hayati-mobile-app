# Project Rules

This document defines immutable project rules.

1. Every development session must execute ONLY the task described in `resume-prompt.md`.

2. After completing that task:

* update `past-prompts.md`
* update `resume-prompt.md`

3. Before generating the next `resume-prompt.md`:

* inspect `roadmap.md`
* inspect project progress
* determine the highest priority remaining task

4. Every completed session must end with:

* git add
* git commit
* git push

5. GitHub access is available through the GitHub CLI (`gh`).

After every push:

* inspect GitHub Actions
* inspect CI status
* inspect workflow failures

If a failure is:

* quick to fix → fix immediately
* large or architectural → document it and postpone it to a future session

6. The project follows strict Test-Driven Development.

Every feature must include tests before implementation whenever practical.

7. Every push must pass the entire GitHub Actions pipeline.

8. Documentation is considered source code.

Every architectural decision must be documented.

9. Never introduce technical debt silently.

Document every compromise.

10. Prefer long-term maintainability over short-term speed.
