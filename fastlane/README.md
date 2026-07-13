# fastlane — Hayati

Status: **M6.3**. The iOS lanes are implemented up to the App Store Connect
secrets boundary; nothing signs, uploads, or delivers until Apple Developer
enrollment (operator item 4) supplies the three `ASC_*` credentials. There is
no Android block yet (M6.5, ADR-006).

## Lanes

| Lane | Platform | Does |
|---|---|---|
| `build_debug` | iOS | Unsigned debug build (`flutter build ios --no-codesign --debug`) — mirrors the `ci.yml` iOS build smoke. Runnable with zero secrets. |
| `beta` | iOS | Prod-flavor `flutter build ipa --release` via App Store Connect API-key cloud signing → `upload_to_testflight`. Fails closed if `ASC_KEY_ID` / `ASC_ISSUER_ID` / `ASC_KEY_P8_PATH` are absent. |
| `store_metadata` | iOS | `deliver(skip_binary_upload: true)` — pushes `fastlane/metadata` per locale, no binary. Same fail-closed credentials gate. |

All three share `ensure_asc_credentials!`: any missing `ASC_*` input aborts with
a message that names what is unset and points at operator item 4 — never a
silent skip that looks green (ADR-021 D4). Cloud signing rides
`-allowProvisioningUpdates` (which `flutter build ipa` already passes) plus the
`~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8` auto-discovery location;
`release.yml`'s `sign-upload` job places the key there and exports the path.

**Honesty bound (ADR-021 D5):** the signing/upload half is UNVERIFIABLE from
the Linux dev box (no Ruby, no secrets, no Mac). The first real tag run after
enrollment may need a Mac-era fix (likeliest: an automatic-signing
`DEVELOPMENT_TEAM` build setting no secret currently carries). The fail-closed
gate guarantees that failure is loud and attributed, never a fake green.

No Android platform block. Play tracks, Play app signing, and Play Console
metadata arrive with **M6.5 — Android enablement & Play release** (ADR-006).
The absence is deliberate, not an oversight.

## Store metadata

`fastlane/metadata/{en-US,tr}/` is the store-copy source of truth (ADR-020).
`name`, `subtitle`, `description`, `keywords`, `promotional_text`,
`release_notes`, and the three URL files per locale. Structural drift from
Apple's rules is caught pre-merge by the credential-free lint:

```sh
dart tool/store_metadata_lint.dart --allow-empty-urls tr en-US   # from repo root
```

It enforces required-file presence, Apple char limits (code points), single-line
cleanliness, keyword de-duplication, unknown-filename rejection, and the
empty-URL ratchet (see below). `tool/store_metadata_lint_test.dart` mutation-checks
every rule class. Both run in the ubuntu `quality`/`preflight` jobs, before
`pub get`, like the content validator.

### Native review: PENDING

**Every store string in both locales is AI-drafted and awaits native review by
the founder couple — it joins operator item 1's content-review gate.** This
flag lives here, NOT inside `fastlane/metadata/`, because `deliver` treats
recognized files in a locale dir as content to upload (ADR-020 D8). Inventory
awaiting review:

- **en-US + tr:** `name`, `subtitle`, `description`, `keywords`,
  `promotional_text`, `release_notes`.
- The Info.plist Face ID purpose strings (`{en,tr,ar}.lproj/InfoPlist.strings`)
  ride the same gate.

**Register (ADR-020 D8):** the TR store copy is authored in **TR-respectful**
(formal *-ınız* address, no emoji) — the listing is read by P2's world, not
just P1. The in-app TR keeps both registers; the playful voice stays in the app.
The description reuses the in-app settings/paywall/coach vocabulary
(`settings*`, `paywall*`, `coach*` ARB strings) and must never contradict their
honest bounds (no "hide the app", no "only you can unlock", no "every time you
open it", no screenshots-blocked or cancellation claims).

### URLs ship empty — on purpose

`privacy_url.txt` and `support_url.txt` are EMPTY in both locales: there is no
hosted privacy policy or support page yet (mvp item 12, operator sub-item). A
placeholder URL would be worse than absence (Apple validates reachability; a
wrong privacy URL is a legal statement). The lint treats an empty required URL
as a hard failure unless `--allow-empty-urls` demotes it to a loud, counted
warning — removing that flag is the ratchet once a domain + hosted policy exist
(ADR-020 D5). `marketing_url.txt` is empty and OPTIONAL: Apple never requires it.

### Founder-owned naming (ADR-020 D1/D2)

- **App Store name** is `Hayati` (provisional until the founder's trademark /
  App-Store-availability search — an unrelated vape brand uses "Hayati" in some
  markets; vetted alternates exist). A rename is a one-line metadata edit.
- **`CFBundleDisplayName`** stays **"Hayati App"** this session. Variant (b)
  "Hayati" and a genuinely neutral label are drafted and flagged for the
  founder (ADR-020 D2); whichever is chosen, the discreet-icon honesty copy
  (`settingsDiscreetSubtitle`) must be re-audited in the same commit.

## Running the lanes

Requires Ruby + bundler, which are **not installed on the dev machine** (see
debt below). Once they exist, from the repo root:

```sh
bundle install
bundle exec fastlane ios build_debug     # unsigned debug build, zero secrets
bundle exec fastlane ios beta            # fails closed without ASC_* creds
bundle exec fastlane ios store_metadata  # fails closed without ASC_* creds
```

## Documented debt

`Gemfile.lock` is still intentionally **absent** (ADR-021 D6): no Ruby/bundler
on the dev box means no faithful lock can be generated, and the pre-signing CI
stages never run Ruby. It gets committed the first time `sign-upload` actually
executes `bundle install` — the first enrolled release run, or the founder's
Mac. Also noted in the root `Gemfile`.

## Secrets policy

Zero credentials in the repo (architecture.md §9). The `ASC_*` API-key inputs
are injected from GitHub `release` environment secrets at release time; the
`Appfile` keeps account identifiers as commented placeholders only. The `.p8`
key lands on disk only in a post-gate step, written from the secret to the
runner temp dir, never checked in. Fastlane runtime artifacts
(`fastlane/report.xml`, `Preview.html`, `test_output/`) are gitignored so the
first real lane run does not dirty the tree.
