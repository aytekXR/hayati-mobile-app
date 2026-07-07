# ADR-007: Build de-gated from content validation (personal-use-first)

- **Status:** Accepted
- **Date:** 2026-07-08
- **Deciders:** Founder
- **Related:** [ADR-006](006-ios-first-release-sequencing.md) (iOS-first sequencing — unchanged and reinforced); `roadmap.md` (Phase 0/1 decoupling note); `feasibility-report.md` §10 (the original gate framework, retained as decision instruments); `prd.md` header; `docs/resume-prompt.md` standing notes

## Context

The original plan (Session 000, `feasibility-report.md`) gated MVP build investment on **Gate 1** — TR/AR TikTok content virality (60 test posts, ≥3 >100K views per language) — with explicit NO-GO kill criteria. `roadmap.md` Phase 0 was "no product code beyond scaffold," and the resume-prompt carried a standing note blocking every post-M0 session on Gate 1.

A founder directive (2026-07-08, after M0 completed) supersedes that coupling: *"skip tiktok parts. focus on developing app. even if no one uses the app, I and my wife will use it. continue developing the app iOS-first."* The founder commits to personal-device testing (Mac + Xcode, personal iPhone) as the build proceeds.

Two facts frame the decision:

- **The floor is no longer zero.** The original gate logic treated "nobody wants this" as a fatal risk to be de-risked *before* build spend. The directive re-prices that risk: the guaranteed baseline user is the founder couple itself, and the build cost is founder time, not cash. Dogfooding by a real married couple in the exact target culture is itself a validation instrument the original plan didn't price in.
- **The gates were built for spend decisions, not engineering sequencing.** Gate 2 (activation) and Gate 3 (monetization) govern marketing spend, GCC push, and paid UA — decisions that remain future and unaffected by build order.

## Decision

1. **Engineering proceeds immediately.** Milestones M1→M6 are scheduled without any content-ops precondition, iOS-first per [ADR-006](006-ios-first-release-sequencing.md) (unchanged). Session 003 = M1.1 (Firebase + Auth foundation).
2. **Gate 1 is decoupled from engineering.** TikTok/content-ops work (Phase 0 content infra, slideshow production, account matrix — `roadmap.md`, `agent-workflows.md` W8) leaves the coding-session pipeline entirely. It may run in parallel if the founder chooses; no session is scheduled against it and no session is blocked by it.
3. **Gates 1–3 are retained as decision instruments, not build blockers.** Their thresholds still inform: content/marketing spend (Gate 1), soft-launch iteration and feature-freeze exit (Gate 2), paid UA / GCC push / Android timing (Gate 3, per ADR-006 M6.5). The NO-GO kill criteria no longer halt the build — they inform go-to-market posture only.
4. **Personal-use-first quality bar.** The dogfood couple (founder + spouse, TR locale, iOS) is the first release target: closed-loop usability on two real devices outranks growth instrumentation until the founder re-activates go-to-market work.
5. **Content packs remain product work.** The daily-question core loop still needs authored packs; they are now authored as product/dogfood content (validator and pack pipeline live where they always did — M3), not as growth content feeding a TikTok pipeline.

## Consequences

**Positive**

- Immediate, uninterrupted product progress; no idle engineering capacity waiting on external content metrics.
- A guaranteed, culturally-native dogfooding couple exercises the real core loop (pairing, daily question, reveal, streak) continuously from M2 onward — earlier and deeper qualitative signal than view-count proxies.
- The Session 002 resume-prompt ambiguity (what to build while Gate 1 pends) disappears; the milestone plan (M1→M6) is the schedule again.

**Negative / accepted trade-offs**

- **Market risk is un-hedged.** The feasibility report's core caution — building before demand evidence — is knowingly accepted. The spend at risk is founder time; the kill criteria stop governing build, so the month-6/month-12 standing decision points in `roadmap.md` become the honest checkpoints against sunk-cost drift.
- The Gate 2/3 funnels lose their pre-warmed audience: without Phase 0 content ops, soft-launch traffic must be rebuilt later if/when go-to-market resumes. Accepted; recorded here rather than papered over.
- Session 003's previously-written objective (content pack validator v1, scheduled solely as Gate-1-serving tooling) is superseded before execution — the validator returns to its original home (M3). No code was built against the superseded objective.

**Neutral**

- ADR-006 (iOS-first) is unchanged and reinforced: iOS remains the build-and-validate platform; M6.5 (Android) remains the follow-on, its timing now a founder decision informed by Gate 3 rather than hard-gated on it.
- `feasibility-report.md` is a historical analysis and is not edited; this ADR supersedes its gating *application*, not its findings.
