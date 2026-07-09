# Agent Workflows — Hayati

How every recurring activity runs. Sub-agents are used wherever the tooling of a session supports them; each workflow lists its delegation points.

## W1 — Idea / feature validation

Trigger: any new feature idea. Steps: (1) write a one-paragraph hypothesis + the gate metric it should move; (2) **Researcher sub-agent**: pull comparable implementations, store reviews, cultural risk scan (TR + AR); (3) score against `prd.md` non-goals and `mvp.md` OUT list — if it's on the OUT list, it needs a scope-change entry, not enthusiasm; (4) verdict logged as an ADR in `docs/adr/` (indexed in `adr/README.md`; `architecture.md` §11 is the running decision log). Nothing enters `roadmap.md` without this.

## W2 — Coding session (the core loop)

Governed by `project-rules.md` + `session-rules.md`. Sequence: read `resume-prompt.md` → orient via **CodeGraph** (`codegraph_explore`/`codegraph_node` MCP tools for symbol/call-path/impact questions; sub-agents use them too, via ToolSearch — session-rules §1) → plan (≤10 bullets) → **Tester sub-agent** drafts failing tests from acceptance criteria → implement to green → **Reviewer sub-agent** pass (diff review against `architecture.md` conventions, security rules, RTL lint) → docs sync → end-of-session sequence (append `past-prompts.md`, regenerate `resume-prompt.md` from `roadmap.md` + progress, `git add/commit/push`, verify CI via `gh run watch`, `codegraph sync` post-merge; fix-fast or log-and-defer per rule #5).

## W3 — PR workflow

Solo-founder discipline substitutes for peer review: feature branches `feat/mX-short-name` (also `fix/`, `docs/`, `chore/`); Conventional Commits; PR template sections = Objective (link to resume-prompt entry) / Tests added / Docs touched / Screens (goldens for UI, both directions) / Risk. **Reviewer sub-agent** must comment before self-merge; squash-merge; branch protection requires green `ci.yml`.

## W4 — Testing workflow

Per `test-suite.md`. Red → green → refactor inside sessions; emulator-suite integration tests pre-merge for backend-touching changes; golden updates require explicit intent flag in the PR (accidental golden churn is treated as a failure); flaky test = quarantined same day with an issue, never silently retried.

## W5 — GitHub / CI workflow

`gh` CLI is the interface (rule #5): after push → `gh run watch` → on failure `gh run view --log-failed`; quick fix (≤15 min) → fix now; structural → `gh issue create --label ci-debt` with log excerpt, defer to a session. Weekly: `gh issue list` triage feeds `resume-prompt.md` prioritization.

## W6 — Documentation workflow

Docs are source code (rule #8): any behavior/architecture change edits the relevant doc *in the same commit*; ADR for anything with alternatives considered; `past-prompts.md` is append-only history; quarterly doc-truth audit session (docs vs. code drift).

## W7 — Release workflow

Tag `vX.Y.Z` → `release.yml` → integration matrix → Fastlane signed builds → TestFlight (iOS ships first; Play internal + the Android device leg deferred to the Android enablement follow-on, M6.5, per ADR-006) → smoke checklist on physical devices (iOS-first: one iPhone TR-locale + one iPhone AR-locale — RTL smoke mandatory; mid-range Android TR-locale device added in the Android enablement follow-on, M6.5) → staged rollout 10%→50%→100% watching crash-free ≥99.5% → store listing updates from `fastlane/metadata` per locale. Rollback = halt staged rollout + previous tag rebuild.

## W8 — Content operations (growth engine)

Weekly loop, same rigor as code: Monday — **Content-Analyst sub-agent** reviews tracking sheet (views, comment-intent per VSC), classifies hooks kill/keep/double; Tuesday–Friday — produce (UGC creators + AI slideshow pipeline), ≥5 posts/day/language across account matrix, every winning product question becomes a candidate hook and vice versa (single pipeline with `content/` packs); Friday — sync learnings into question-bank authoring. **Localizer sub-agent** drafts AR/TR variants; native register owner approves before posting (brandkit principle 4).

## W9 — Content-pack authoring

Draft (AI-assisted allowed) → cultural review (native, register-specific; Gulf reviewer mandatory for AR) → validator script (`content/`) → versioned merge → remote sync. Intimacy-adjacent packs additionally pass the GCC-safety checklist (text-only, both-partner opt-in framing, region flag assigned).

## Sub-agent roster

| Agent | Invoked in | Charter |
|---|---|---|
| Researcher | W1 | Market/competitor/culture evidence, sources cited, facts vs. assumptions separated |
| Tester | W2, W4 | Failing tests first, from acceptance criteria only |
| Reviewer | W2, W3 | Diff review: conventions, security rules, RTL, perf budgets |
| Localizer | W8, W9 | TR/AR drafts in correct register; never machine-translate final copy |
| Content-Analyst | W8 | VSC scoring, hook classification, weekly growth memo |
