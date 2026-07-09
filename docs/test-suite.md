# Test Suite Strategy — Hayati

Strict TDD (rule #6). The pyramid, tooling, and gates below are enforced by CI, not by good intentions.

## 1. Layers

### Unit tests (`test/`, mirrors `lib/`) — the wide base
Pure-Dart domain layer makes these cheap and fast. Mandatory targets: streak engine (property-based: gaps, grace tokens, timezone edges, DST, Ramadan quiet-window interactions); pairing state machine (races, expiry, re-pair attempts); question selection (register/seasonal/no-repeat determinism); entitlement mapping (one purchase → two partners; expiry → both); pack validator; crisis-lexicon matcher (TR/AR/EN seed lists). Tools: `flutter_test`, `mocktail`, fakes over mocks for repositories, builder-pattern test data (`aCouple().paired().withStreak(12).build()`).

### Widget tests — every screen, every language, both directions
Each screen: states (loading/empty/error/content) + interaction contracts. **Golden tests per key screen in a 6-cell matrix: {TR, AR, EN} × {LTR, RTL-where-applicable}, plus dynamic-type 130% variants for onboarding, question card, paywall, reveal.** **Live since M1.4** for the M1 auth/profile screens (sign-in, phone sign-in, onboarding gate, profile capture, invite placeholder), including the 130% dynamic-type onboarding variant and a mirror-net self-test that fails the build if an arrow renders un-mirrored in RTL. Goldens are the RTL regression net — an un-mirrored arrow fails the build, not the Riyadh user. Golden updates require an explicit flag in the PR (see `agent-workflows.md` W4).

### Integration tests (`integration_test/` + Firebase Emulator Suite)
Security rules suite (the invariants in `architecture.md` §3 — especially *partner answer unreadable before own answer* and *preview endpoint never leaks answer content*); auth→pair two-device flow; answer→reveal→thread round trip; delete-cascade with partner notification; RevenueCat sandbox/StoreKit-test purchase → entitlement mirror; coach_proxy contract tests against recorded LLM fixtures + live safety tests (seeded crisis phrases in all three languages must route to the help path).

### End-to-end (Patrol) — critical paths only, release-gated
E2E-1 fresh install → signup → invite → (second device) preview → join → both answer → reveal → streak=1. E2E-2 trial start → sandbox purchase → premium unlocked on *both* devices. E2E-3 PIN lock + discreet icon behavior. Run in `release.yml`, not on every push (cost/flake budget).

### Smoke (post-build, physical devices)
Signed artifact checklist on iPhone in TR + AR locales (TR = the iOS soft-launch cohort, AR = RTL sanity): cold start <2s, push received, purchase sheet opens, RTL sanity, crash-free session. 10 minutes, every release candidate. **iOS-first (ADR-006): the iPhone smoke gates the release pre-Android; the mid-range Android (TR locale) smoke re-enters as a release gate in the Android enablement follow-on (M6.5).**

### Golden harness (M1.4)
Plain `flutter_test` `matchesGoldenFile` + a small in-repo harness (`app/test/support/golden/`), zero added deps. eBay's `golden_toolkit` is discontinued; Betterment's `alchemist` was evaluated (2026-07) and is maintained, but its cross-OS block-text mode defeats the real-font rendering we want and its gallery ergonomics don't pay for a dependency at our screen count. Real bundled brand fonts (Rubik + Noto Sans / Noto Sans Arabic) are loaded once in `app/test/flutter_test_config.dart`, so goldens exercise real Arabic shaping and the 1.5/1.7 line-heights — never Ahem. Goldens are **Linux-canonical**: rendered on the Linux dev box, verified in the ubuntu `quality` job. macOS renders text differently (antialiasing/hinting), so macOS machines must **never** run `flutter test --update-goldens` — re-baseline happens on Linux or via CI. Comparison is exact (no tolerance comparator), which makes goldens engine-version-sensitive: expect intentional churn on a Flutter upgrade, re-baselined behind the explicit W4 golden-update flag. Mismatch diffs land in `failures/` next to the test (gitignored) and upload as CI artifacts.

## 2. CI validation

`ci.yml` (every push/PR): format → analyze (RTL lint included) → unit + widget (incl. goldens) → coverage gate → debug build. `release.yml` (tags): emulator integration suite → E2E on the iOS simulator matrix (current-1/current) — iOS-first (ADR-006): the Android API 30/34 emulator matrix re-enters this release gate in the Android enablement follow-on (M6.5) → signed builds → distribute. Branch protection: no green, no merge (rule #7).

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
