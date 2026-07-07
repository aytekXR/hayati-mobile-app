# Past Prompts — Append-Only Session History

> Rule: append new entries at the bottom. Never edit or delete prior entries (`project-rules.md` #2). Template:
>
> ```
> ## Session NNN — YYYY-MM-DD — <objective title>
> **Objective (from resume-prompt.md):** …
> **Outcome:** done / partial (what remains) / blocked (why)
> **Commits:** <hashes or PR link>
> **CI:** green / red→fixed / red→deferred (issue #)
> **Docs touched:** …
> **Notes / debt logged:** …
> **Next objective written to resume-prompt.md:** …
> ```

---

## Session 000 — 2026-07-08 — Incubation: idea challenge, market research, project genesis

**Objective:** Evaluate the brief ("copy an already-working app" — reference case: Flame, couples daily-ritual app) for Turkey/GCC/Arabic markets; challenge, redesign, decide; if positive, generate the full project documentation set.

**Outcome:** done.
- Challenged the "copy" framing → reframed as localization arbitrage on a twice-validated mechanic (Paired, Flame); original brand/content/code explicitly not copied; all packs to be culturally authored.
- Research performed (sources logged in `feasibility-report.md`): Paired US revenue estimates (~$200K/mo iOS + ~$100K/mo Play, Sensor Tower), 8M downloads; Turkey 40.2M adult TikTok users (61.6% adult reach); Egypt/Iraq/KSA TikTok 41.3M/34.3M/34.1M; GCC download growth 2.6% YoY vs 0.5% global; Saudi app/digital spend >$4.5B growing ~15%/yr; Arabic store saturated with matchmaking (Soudfa 10M+, Muzz 800K marriages) — post-marriage category empty in AR and TR.
- Key redesigns vs. reference: marriage-companion positioning; one-subscription-covers-both-partners; discreet mode + PIN as headline features; dual-register TR content; AR authored MSA-Gulf; Ramadan mode; social layer restricted to intra-couple + anonymous polls (stranger flirting rejected — decision record in `prd.md` §6); pomegranate brand system; dual pricing (TR volume / GCC margin).
- **Verdict: GO WITH CAUTION**, gated: G1 content virality (60 TR/AR test posts, 3 weeks) → G2 activation (pair ≥40%, D7 ≥25%) → G3 monetization (trial→paid ≥30%, install→paid ≥2%). Kill criteria documented.

**Commits:** n/a (repository not yet initialized — Session 001 = M0.1 scaffold).
**CI:** n/a.
**Docs produced:** README, feasibility-report, prd, mvp, architecture, frontend-brandkit, roadmap, implementation-plan, agent-workflows, project-rules, session-rules, test-suite, resume-prompt, past-prompts.
**Notes / debt logged:** working title "Hayati" pending trademark/store-name search (alternates listed in brandkit); Gate 1 content ops (Phase 0) runs before/alongside M0 only; no paid UA before Gate 3.
**Next objective written to resume-prompt.md:** Session 001 — M0.1 repository scaffold.

## Session 001 — 2026-07-08 — M0.1: Repository scaffold + iOS-first re-sequencing (founder directive)

**Objective (from resume-prompt.md):** M0.1 — initialize repository scaffold: Flutter app in `app/` with dev/prod flavors, `core/`+`features/` layout per `architecture.md` §2, Riverpod+codegen with example provider, strict lint + RTL `start/end` guard, example domain entity with failing-then-passing test, `content/` schema stub + validator placeholder, root README pointer to `docs/`.

**Outcome:** done. Additionally executed a founder directive received at session start: **iOS-first release sequencing** ("implement iOS-first; after successful completion we will continue with Android"). Resolution: Flutter stack retained (ADR-001 stands); iOS-first is release/validation sequencing, recorded as **ADR-006** with Android re-sequenced into **M6.5 — Android enablement & Play release** (gated on Gate 3). 24 doc edits applied across mvp/roadmap/implementation-plan/architecture/test-suite/prd/agent-workflows (multi-agent analyze→consolidate→adversarial-verify pass; all edits verified against gate/scope/pricing invariants).

**Scaffold details:** Flutter 3.44.5 stable; `app/` created with org `com.hayati`, bundle id normalized to `com.hayati.app` (iOS pbxproj + Android gradle); flavors as Dart entrypoints (`main_dev.dart`/`main_prod.dart`) overriding `appConfigProvider`; brand strings confined to `core/config/` (`kBrandName`); brandkit palette as `core/design_system/color_tokens.dart`; strict `analysis_options.yaml` (strict-casts/inference/raw-types + curated rules); RTL logical-direction guard at `tool/rtl_lint.dart` (no analyzer rule exists — line-scan script with `// rtl-ok` escape hatch); TDD proven red→green: `AppConfig` entity + provider + both-flavor widget smoke tests written first (3 failing files), then implemented (9/9 green); Riverpod 3 note: provider-body errors arrive wrapped, so the un-overridden-provider test asserts on the contract message, not the raw `StateError` type; generated `*.g.dart` committed so fresh clone → `flutter pub get && flutter test` is green without a build step; `content/` schema stub + example pack + validator placeholder (exits 1 by design, unwired).

**Commits:** single commit on `main`, 2026-07-08 (`feat(m0.1): ...` — this commit).
**CI:** n/a — pipeline does not exist until M0.2. Recorded explicitly per the Session 001 resume prompt rather than skipped: post-push `gh run list` returns no workflow runs.
**Docs touched:** mvp.md, roadmap.md, implementation-plan.md, architecture.md, test-suite.md, prd.md, agent-workflows.md, README.md (root + app/ + content/), adr/006-ios-first-release-sequencing.md (new), resume-prompt.md, past-prompts.md.
**Notes / debt logged (none silent):**
- Store-level flavor split (Gradle productFlavors / Xcode schemes, per-flavor bundle-id suffix) deferred to M0.2 (CI/Fastlane) where real toolchains can validate it; Dart-entrypoint flavors satisfy M0.1. Noted in `app/README.md` and `core/config/app_config.dart`.
- ADR-001..005 backfill files under `docs/adr/` belong to M0.2's "ADR skeleton" item (summaries already live in `architecture.md` §11).
- Gate 2 first read will be TR-iOS-cohort-only (directional) until M6.5 — the honest trade-off of iOS-first; recorded in ADR-006, mvp.md scope-change log, roadmap Phase 2.
- Flutter SDK on the dev machine lives at `~/flutter` (3.44.5 stable), installed this session.

**Next objective written to resume-prompt.md:** Session 002 — M0.2 GitHub Actions CI + branch protection + PR template + ADR skeleton + Fastlane init.
