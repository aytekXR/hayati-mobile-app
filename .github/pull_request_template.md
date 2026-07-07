<!-- One PR = one session = one objective (project-rules #1). If this PR does two things, split it. -->

## Objective

<!-- Link the resume-prompt objective / session entry this PR executes. e.g. Session 002 — M0.2 CI pipeline. -->
Executes: <!-- Session NNN — Mx.y short-name -->

## Tests added

<!-- What was written test-first (session-rules §2 TDD: failing test → minimal impl → refactor).
     Domain logic / Functions / security rules MUST be test-first; UI polish & build config may skip. -->
-

## Docs touched

<!-- Docs are source code (rule #8): any behavior/architecture change edits the doc in the SAME PR.
     ADR for anything with alternatives considered. List them, or state why none. -->
-

## Screens

<!-- UI change ⇒ goldens for every touched screen in BOTH directions, LTR + RTL (test-suite §1).
     An un-mirrored arrow fails the build, not the Riyadh user. Pick exactly one: -->
- [ ] No golden changes (no UI touched)
- [ ] Goldens intentionally updated (W4 golden-intent flag — accidental golden churn is a failure)

<!-- If updated, drop before/after or the diffed cells here: -->

## Risk

<!-- What could break, blast radius, and the rollback note (revert this PR / previous tag). -->
-

---

### Pre-merge checklist (session-rules §2 quality bar)

- [ ] `dart format` + `flutter analyze` clean
- [ ] All tests green locally
- [ ] Coverage gate satisfied (≥ current floor; never lowered — test-suite §3)
- [ ] `dart tool/rtl_lint.dart app/lib` clean
- [ ] Scope guard: no drive-by refactors — unrelated findings filed as `gh issue`, not smuggled into this diff
