# fastlane — Hayati

Status: **skeleton (M0.2)**. iOS lane stubs only; nothing signs or distributes yet.

## What exists now

| Lane | Platform | Does |
|---|---|---|
| `build_debug` | iOS | Unsigned debug build (`flutter build ios --no-codesign --debug`) — mirrors the `ci.yml` iOS build smoke. Runnable with zero secrets. |
| `beta` | iOS | Fails fast: TestFlight distribution arrives with M6 (see below). |

No Android platform block. Android lanes (Play tracks, Play signing) arrive with
**M6.5 — Android enablement & Play release** (ADR-006). The absence is deliberate,
not an oversight.

## What arrives when

- **M6 (release hardening):** `release.yml` tag-triggered pipeline → signed iOS
  builds → **TestFlight** upload; App Store metadata TR/EN from `fastlane/metadata`.
  Signing credentials come from **GitHub environment secrets** (architecture.md §9).
  The `beta` lane gets implemented here.
- **M6.5 (Android enablement):** `platform :android` block, Play internal/production
  tracks, Play app signing, Play Console metadata TR/EN — gated on iOS MVP
  validation (Gate 3). See `docs/implementation-plan.md` M6.5 and ADR-006.

## Running the stub lanes

Requires Ruby + bundler, which are **not installed on the dev machine yet**
(see debt note below). Once they exist, from the repo root:

```sh
bundle install
bundle exec fastlane ios build_debug   # unsigned debug build
bundle exec fastlane ios beta          # currently errors by design (M6)
```

## Documented debt

`Gemfile.lock` is intentionally **absent**: no Ruby/bundler on the dev machine
means we cannot generate a faithful lock. It gets committed the first time
fastlane is exercised for real, in M6. Also noted in the root `Gemfile`.

## Secrets policy

Zero credentials in the repo (architecture.md §9). All signing keys, Apple IDs,
and team ids are injected from GitHub OIDC / environment secrets at release time.
The `Appfile` keeps these as commented placeholders only.
