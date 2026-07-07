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

## Session 002 — 2026-07-08 — M0.2: GitHub Actions CI, branch protection, repo process skeleton

**Objective (from resume-prompt.md):** M0.2 — `ci.yml` (format → analyze → RTL lint → test --coverage → coverage gate ≥60% → iOS build smoke per ADR-006), branch protection on `main`, PR template (W3 sections), ADR skeleton (README + 001..005 backfill), Fastlane init (iOS stub only).

**Outcome:** done. **M0 is complete.**
- `ci.yml`: `quality` job (ubuntu; the five-step gate sequence) + `ios-build-smoke` (macos-15, `flutter build ios --no-codesign --debug --target lib/main_dev.dart`). Cost containment on the 10×-billed macOS leg: draft PRs skip it, `needs: quality` fail-fasts it, concurrency cancels superseded runs; `pull_request` types include `ready_for_review` so a draft→ready flip re-fires the required check. Push trigger is main-only (every change lands via PR per W3; avoids double-billed duplicate runs). Timings with warm cache: quality ~1m, iOS smoke ~2m37s (~26 billed macOS min/run — sustainable).
- `tool/coverage_gate.dart`: zero-dep lcov gate (PASS 0 / FAIL 1 / usage+zero-LF 64; zero-LF is an explicit error so an empty report can't silently pass). Baseline coverage 87.50% (LF 32, LH 28) vs the 60% floor.
- Branch protection via `gh api` (NOT plan-gated — worked on this private repo): required contexts `quality` + `ios-build-smoke`, `enforce_admins`, linear history, no force pushes/deletions, no review requirement (solo self-merge, green required — rule #7). Repo set to squash-merge-only + delete-branch-on-merge (W3).
- Acceptance proofs (PR #2, draft, closed unmerged): (1) deliberately failing test → `quality` FAILURE → `mergeStateStatus: BLOCKED` (run 28905568279); (2) gate raised to `--min 99` → job fails at the coverage step, `87.50% is below the 99% threshold` → BLOCKED (run 28905881305). `ios-build-smoke` correctly SKIPPED on the draft both times.
- iOS smoke earned its keep on first contact: caught that the scaffold has no `lib/main.dart` (flavors are Dart entrypoints, Session 001) — fixed with explicit `--target`. Not reproducible locally (no macOS).
- ADR-001..005 backfilled from `architecture.md` §11 in the ADR-006 format (provenance noted per file); `adr/README.md` format note + index; §11 now links all six records.
- Fastlane skeleton: iOS lanes only (`build_debug` mirrors the CI smoke; `beta` fails fast pointing to M6); Appfile `com.hayati.app`, zero secrets; root Gemfile pins fastlane `~> 2.225`.
- **Founder directive mid-session:** brand kit v1.0 dropped at `brandkit/` (logos incl. AR lockup, tokens css/json, app icons incl. discreet-mode alt, TR/AR/EN social/store graphics) — committed straight to `main` (75ba8cb + 473842a) with a pointer added in `frontend-brandkit.md`; kept out of the M0.2 PR (scope guard). All future design work sources from it.

**Commits:** PR #1 → squash `d0b0a00` on main; brandkit `75ba8cb` + `473842a`; session-close docs PR (this commit).
**CI:** green (PR #1 both checks; post-merge main run watched green via `gh run watch`).
**Docs touched:** adr/README.md + adr/001..005 (new), architecture.md §11, frontend-brandkit.md (brandkit pointer), resume-prompt.md, past-prompts.md.
**Notes / debt logged (none silent):**
- `Gemfile.lock` intentionally absent until fastlane first runs for real (M6) — no ruby/bundler on the dev machine. Documented in `Gemfile` + `fastlane/README.md`.
- Docs-only PRs run the full pipeline including the macOS smoke: `paths-ignore` on a required check would deadlock merges ("expected" forever), so it was deliberately not used. Revisit only if the Actions minute budget tightens.
- Coverage ratchet: floor stays 60% in `ci.yml`; first bump to 62% lands when M1 closes (test-suite §3).
**Next objective written to resume-prompt.md:** Session 003 — content pack validator v1 (Phase-0-parallel content tooling; Gate 1 standing note honored — M1.1 stays blocked until Gate 1 passes). *[Superseded before execution by the 2026-07-08 de-gating directive — see the Directive entry below and ADR-007.]*

## Directive — 2026-07-08 — De-gate build from content validation (ADR-007)

**Trigger (founder, verbatim intent):** "skip tiktok parts. focus on developing app. even if no one uses the app, I and my wife will use it. continue developing the app iOS-first." Founder additionally commits personal-device testing (Mac + Xcode, personal iPhone) on request.

**Resolution:** recorded as **ADR-007**. Engineering M1→M6 proceeds immediately, iOS-first (ADR-006 unchanged); Gate 1 decoupled from engineering; Gates 1–3 retained as marketing/spend/launch decision instruments only; TikTok/content-ops leave the session pipeline; content packs re-scoped as product/dogfood content (validator back to M3); personal-use-first quality bar (founder couple = first release target).

**Docs touched:** adr/007 (new), adr/README.md (index), architecture.md §11, roadmap.md (de-gating note + Phase 0 header), prd.md (status line), implementation-plan.md (M6.5 gate wording), resume-prompt.md (regenerated: Session 003 = M1.1 Firebase foundation + Auth domain, superseding the unexecuted validator objective).

**Outcome:** docs-only change, merged via PR with green pipeline.
**Next objective in resume-prompt.md:** Session 003 — M1.1 Firebase foundation + Auth domain (external dependencies noted: founder `firebase login` at session start; Apple Developer Program status to confirm for M1.2 provider work).
