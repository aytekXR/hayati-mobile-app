# Architecture — Hayati

## 1. Stack & rationale

| Layer | Choice | Why |
|---|---|---|
| App | **Flutter** (stable channel), Dart | One codebase for Android-heavy TR + iOS-heavy GCC; first-class RTL; widget-test culture fits our TDD mandate |
| State | Riverpod (+ codegen) | Testable, compile-safe DI, scales from MVP to v2 |
| Backend | **Firebase**: Auth, Cloud Firestore, Cloud Functions (TypeScript), FCM, Remote Config, Crashlytics, App Check | Solo-founder ops budget ≈ zero; offline persistence built-in; Remote Config gives the regional feature flags the GCC strategy requires |
| Payments | **RevenueCat** | Cross-store entitlements, webhooks, experiments; industry default for this exact app category |
| Analytics | Mixpanel (product funnels) + Firebase Analytics (audiences) | Free tiers cover Year 1; funnel tooling for the three gates |
| AI | LLM via **Cloud Function proxy only** | API keys server-side; per-user rate limits; safety filter; model-swappable; cost caps enforceable |
| CI/CD | GitHub Actions + Fastlane | Matches `project-rules.md` (gh CLI, pipeline-green rule) |

Firestore region: **europe-west (multi-region EU)** — defensible latency for both Istanbul and Riyadh, and a conservative posture for KVKK/PDPL cross-border rules. Revisit if KSA data-residency guidance tightens; the repository pattern below keeps a migration survivable.

## 2. Repository & module layout

```
hayati/
  app/                         # Flutter
    lib/
      core/                    # design_system/ l10n/ analytics/ storage/ config/ utils/
      features/
        auth/  pairing/  daily_question/  streak/
        thread/  coach/  paywall/  privacy_lock/  settings/
        # each feature: domain/ (entities, usecases) data/ (repos, dtos) presentation/ (state, widgets)
      app.dart  main_dev.dart  main_prod.dart      # flavors
    test/          # mirrors lib/, unit + widget
    integration_test/
  functions/                   # TS Cloud Functions: coach_proxy, pairing, rc_webhooks, question_rollover, cleanup
  content/                     # question packs as versioned JSON (tr_playful, tr_respectful, ar_msa_gulf, en) + validator script
  docs/                        # this documentation set (source of truth)
  .github/workflows/           # ci.yml, release.yml
  fastlane/
```

Feature-first, clean-ish architecture: `presentation → domain ← data`. Domain layer is pure Dart (no Flutter imports) — this is what makes the 90% domain coverage target in `test-suite.md` cheap.

## 3. Data model (Firestore)

```
users/{uid}: profile, locale, register, coupleId?, fcmTokens, createdAt
couples/{coupleId}: memberUids[2], timezone, packConfig, streak{count, lastMutualDate, graceTokens}, createdAt
couples/{cid}/days/{yyyymmdd}: questionId, answers{uid: {text, at}}, revealedAt, thread[]
questions/{qid}: locale, register, category, depth, seasonalWindow?, text   # read-only, shipped+synced
invites/{code}: coupleId|creatorUid, expiresAt, status
subscriptions/{coupleId}: entitlement mirror via RevenueCat webhook (source of truth = RC)
coach_sessions/{uid}/msgs: rolling window, TTL 30d
```

**Security rules invariants (tested against emulator):** a user reads/writes only their own couple's docs; partner's answer for today is unreadable until requester's answer exists (mutual-reveal enforced server-side, not just UI); invites expire; entitlement docs are function-write-only.

## 4. Key flows

- **Pairing:** Function issues code/deep link → invitee hits preview endpoint (public, rate-limited, exposes question text + *locked* indicator only — never answer content) → on signup, transactional join, second-join races rejected.
- **Daily rollover:** scheduled Function per timezone bucket assigns next unseen question honoring pack/register/seasonal rules; deterministic so client can prefetch offline.
- **Coach:** client → `coach_proxy` → guardrail pre-filter (crisis lexicon TR/AR/EN → localized help response path) → LLM with persona+register system prompt → post-filter → response; per-user daily budget; per-couple monthly token cap; all limits Remote Config-tunable.
- **Entitlements:** RC webhook → Function → `subscriptions/{coupleId}` → both partners unlocked by a single purchase.

## 5. Offline & performance

Firestore offline persistence ON; answers composed offline queue and reveal on sync; question of the day prefetched at prior rollover; image-light UI (mid-range Android budget: cold start <2s, first frame jank-free). Coach requires connectivity — degrade with honest empty-state.

## 6. i18n / RTL

ARB-based l10n; `Directionality` correctness enforced by golden tests in LTR **and** RTL per screen (`test-suite.md`); no hardcoded left/right — logical `start/end` only, lint-enforced; Arabic line-height and font fallback defined in brandkit; dates support Hijri display (v1.5 anniversaries).

## 7. Analytics schema (gate instrumentation)

`install → signup → invite_sent → paired → q_answered{solo|mutual} → reveal_viewed → streak_day → trial_start → paid → churn` plus `share_card_created`, `coach_msg`, locale/register/storefront dimensions on every event. Funnels for Gates 2–3 are built in Mixpanel before launch day, not after.

## 8. Security, privacy, compliance

App Check on all Functions; least-privilege rules; relationship content encrypted at rest (Firestore default) and **excluded from analytics payloads** (event names carry no answer text, ever); PIN/biometric lock local-only; discreet mode = alternate launcher icon (Android activity-alias / iOS alternate icons) + generic notification strings. KVKK+PDPL: consent screens per locale, self-serve export (Function → JSON email) and hard delete (cascade couple data with partner notification), DPA inventory kept in `docs/`. AI: no training on user data (provider flag), 30-day TTL on coach history, disclaimers in-product.

## 9. CI/CD

`ci.yml` on every push/PR: format → analyze → unit+widget tests → coverage gate → build debug. `release.yml` tag-triggered: integration tests (iOS simulator first per iOS-first sequencing (ADR-006); Android emulator matrix added in the Android enablement follow-on, M6.5) → Fastlane build+sign → TestFlight (Play internal deferred to the Android enablement follow-on, M6.5) → store metadata per locale from `fastlane/metadata`. Pipeline-green is a merge requirement (`project-rules.md` #7). Secrets in GitHub OIDC/environment secrets; zero keys in repo.

## 10. Scalability & cost posture

Firestore fan-out is trivial at our shape (couple-scoped docs, no global feeds — a deliberate consequence of the §Social Layer decision in `prd.md`). Cost ceilings: Remote Config caps on coach usage are the only meaningful variable cost; alerting at $ thresholds via budget alerts. 100K couples fits comfortably in this architecture; the first real rework (search, community polls aggregation) is a v2 problem and is isolated behind repositories.

## 11. Decision log

ADRs live in `docs/adr/NNN-*.md` (index: [`adr/README.md`](adr/README.md)); every architectural decision gets one (`project-rules.md` #8). [ADR-001](adr/001-flutter-over-native.md): Flutter over native pair. [ADR-002](adr/002-firebase-over-supabase.md): Firebase over Supabase (offline + FCM + Remote Config maturity outweigh Postgres ergonomics for this shape). [ADR-003](adr/003-revenuecat-for-entitlements.md): RevenueCat. [ADR-004](adr/004-eu-firestore-region.md): EU region. [ADR-005](adr/005-couple-scoped-data-model.md): couple-scoped data model, no global social graph. [ADR-006](adr/006-ios-first-release-sequencing.md): iOS-first release/validation sequencing (M1–M6 validate on iOS and iOS ships first; Android build/test/release hardening is a follow-on milestone, M6.5 — single Flutter codebase retained per ADR-001).
