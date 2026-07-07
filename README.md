# Hayati (حياتي / Hayatım) — Project Repository

**A daily-ritual app for couples, built for Turkey, the GCC, and Arabic-speaking users.**
Working title: *Hayati* — "my life / my darling," a term of endearment that works natively in both Arabic (حياتي) and Turkish (hayatım). Trademark search pending; see `frontend-brandkit.md` for alternates.

## Verdict

**GO WITH CAUTION** — full reasoning in `feasibility-report.md`.

The mechanic is validated twice over (Paired: 8M+ downloads; Flame: $10K MRR in 8 months on organic TikTok alone). The Turkish and Arabic markets have massive short-form audiences and **no localized incumbent** in the "already-coupled" category — the Arabic app stores are saturated with *matchmaking* apps (Soudfa, Muzz, Oolfa) that all abandon the user at the wedding. Hayati begins where Muzz ends.

Caution because: (1) content-market fit in Turkish/Arabic is assumed, not proven — **Gate 1 must pass before serious build**, (2) Turkish ARPU is weak, so GCC must carry revenue, (3) there is no product moat; the moat is distribution velocity + cultural depth.

## The three gates

| Gate | Test | Pass criteria | If it fails |
|---|---|---|---|
| **G1 — Content** | 3 weeks, 60 test slideshows (30 TR / 30 AR) across 6 fresh accounts | ≥3 posts >100K views from <5K-follower accounts, per language | Kill or re-scope to the language that passed |
| **G2 — Activation** | TR soft launch | ≥40% of signups paired within 7 days, D7 couple retention ≥25% | Fix pairing loop before any spend |
| **G3 — Monetization** | Paywall live 4+ weeks | Trial→paid ≥30%, install→paid ≥2% | Rework pricing/paywall before GCC push |

## How to use this repository

This project runs on an agentic development loop. The rules are absolute:

1. Read `project-rules.md` — immutable.
2. Every coding session executes **only** the single objective in `resume-prompt.md`.
3. Every session ends by appending to `past-prompts.md`, regenerating `resume-prompt.md` from `roadmap.md`, and pushing green CI.

## Repository layout

| Path | Contents |
|---|---|
| `docs/` | The documentation set below — the single source of truth |
| `docs/adr/` | Architecture Decision Records (ADR-006: iOS-first release sequencing) |
| `app/` | Flutter application — see `app/README.md` |
| `content/` | Question packs: JSON schema, packs, validator (validator ships in M3) |
| `tool/` | Repo tooling (`rtl_lint.dart` — logical `start`/`end` guard) |

## File index (`docs/`)

| File | Purpose |
|---|---|
| `feasibility-report.md` | Investment-grade analysis, market data, unit economics, verdict |
| `prd.md` | Product requirements: personas, features, metrics |
| `mvp.md` | Strict MVP scope — everything else is postponed |
| `architecture.md` | Stack, modules, data model, CI/CD, compliance |
| `frontend-brandkit.md` | Brand, colors, typography, RTL, design principles |
| `roadmap.md` | Phase plan from validation to v2 |
| `implementation-plan.md` | Engineering milestones with acceptance criteria |
| `agent-workflows.md` | Every workflow: sessions, PRs, testing, releases, content ops |
| `project-rules.md` | Immutable rules (verbatim) |
| `session-rules.md` | The contract for every coding session |
| `test-suite.md` | TDD strategy, coverage goals, CI validation |
| `resume-prompt.md` | The ONE objective for the next session |
| `past-prompts.md` | Append-only session history |
