# Test Suite Strategy — Hayati

Strict TDD (rule #6). The pyramid, tooling, and gates below are enforced by CI, not by good intentions.

## 1. Layers

### Unit tests (`test/`, mirrors `lib/`) — the wide base
Pure-Dart domain layer makes these cheap and fast. Mandatory targets: streak engine (property-based: gaps, grace tokens, timezone edges, DST, Ramadan quiet-window interactions); pairing state machine (races, expiry, re-pair attempts); question selection (register/seasonal/no-repeat determinism); entitlement mapping (one purchase → two partners; expiry → both); pack validator; crisis-lexicon matcher (TR/AR/EN seed lists). Tools: `flutter_test`, `mocktail`, fakes over mocks for repositories, builder-pattern test data (`aCouple().paired().withStreak(12).build()`).

### Widget tests — every screen, every language, both directions
Each screen: states (loading/empty/error/content) + interaction contracts. **Golden tests per key screen in a 6-cell matrix: {TR, AR, EN} × {LTR, RTL-where-applicable}, plus dynamic-type 130% variants for onboarding, question card, paywall, reveal.** Goldens are the RTL regression net — an un-mirrored arrow fails the build, not the Riyadh user. Golden updates require an explicit flag in the PR (see `agent-workflows.md` W4).

### Integration tests (`integration_test/` + Firebase Emulator Suite)
Security rules suite (the invariants in `architecture.md` §3 — especially *partner answer unreadable before own answer* and *preview endpoint never leaks answer content*); auth→pair two-device flow; answer→reveal→thread round trip; delete-cascade with partner notification; RevenueCat sandbox/StoreKit-test purchase → entitlement mirror; coach_proxy contract tests against recorded LLM fixtures + live safety tests (seeded crisis phrases in all three languages must route to the help path).

### End-to-end (Patrol) — critical paths only, release-gated
E2E-1 fresh install → signup → invite → (second device) preview → join → both answer → reveal → streak=1. E2E-2 trial start → sandbox purchase → premium unlocked on *both* devices. E2E-3 PIN lock + discreet icon behavior. Run in `release.yml`, not on every push (cost/flake budget).

### Smoke (post-build, physical devices)
Signed artifact checklist on mid-range Android (TR locale) + iPhone (AR locale): cold start <2s, push received, purchase sheet opens, RTL sanity, crash-free session. 10 minutes, every release candidate.

## 2. CI validation

`ci.yml` (every push/PR): format → analyze (RTL lint included) → unit + widget (incl. goldens) → coverage gate → debug build. `release.yml` (tags): emulator integration suite → E2E on emulator/simulator matrix (Android API 30/34; iOS current-1/current) → signed builds → distribute. Branch protection: no green, no merge (rule #7).

## 3. Coverage goals

| Scope | Target | Gate |
|---|---|---|
| `domain/` (all features) | 90% | Hard fail <85% |
| Functions (TS) | 85% | Hard fail <80% |
| Overall Dart | 70% by M6 | Ratchet: starts 60%, +2%/milestone, never lowered |
| Screens with goldens | 100% of P0 screens | PR checklist |

Coverage is a floor, not a goal — acceptance criteria in `implementation-plan.md` define sufficiency.

## 4. Policies

Flaky test → quarantined same day with an issue; >2 quarantined = next session objective is stabilization. Bug fix → regression test in the same commit, named after the issue. Test speed budget: unit+widget suite <90s locally — protect it (fakes over emulators at unit level). LLM-dependent tests never call live models in CI (fixtures only); safety-path tests are the exception and run against the proxy's filter layer, which is deterministic. No test reads real user data, ever.
