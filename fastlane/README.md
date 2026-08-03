# fastlane — Hayati

Status: **LIVE** (ADR-032, S047). The lane signs and ships from CI: run
`30193322224` archived `com.beyondkaira.hayati` and uploaded **build 109** to
TestFlight. From `main`, `git tag vX.Y.Z && git push --tags` is the whole
release ritual — no Mac needed. There is no Android block yet (M6.5, ADR-006).

## Lanes

| Lane | Platform | Does |
|---|---|---|
| `build_debug` | iOS | Unsigned debug build (`flutter build ios --no-codesign --debug`) — mirrors the `ci.yml` iOS build smoke. Runnable with zero secrets. |
| `beta` | iOS | fastlane **`match`** installs the stored Apple Distribution certificate + App Store profile, `update_code_signing_settings` pins **Manual**, then prod-flavor `flutter build ipa --release` archives against an explicit `ExportOptions.plist` → `pilot` (TestFlight). Fails closed via `ensure_release_credentials!`. |
| `store_metadata` | iOS | `deliver(skip_binary_upload: true)` — pushes `fastlane/metadata` per locale, no binary. Fails closed via `ensure_asc_credentials!`. |
| `store_screenshots` | iOS | `deliver(skip_metadata: true, skip_screenshots: false)` — pushes `fastlane/screenshots` only. Separate from `store_metadata` on purpose: the copy is awaiting native review, the images are not. |

**The two credential checks are deliberately different (ADR-032 D5).**
`ensure_asc_credentials!` requires the App Store Connect key alone
(`ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_API_KEY_P8_BASE64`);
`ensure_release_credentials!` delegates to it and adds the match inputs
(`MATCH_GIT_URL`, `MATCH_PASSWORD`). `store_metadata` signs nothing, so
requiring match inputs of it was a real defect, not a harmless extra: it made
the lane abort before `deliver` on **every** release, inside a
`continue-on-error: true` step that then reported success. Store metadata was
never once delivered until S047. `tool/release_lane_lint.dart` now pins which
lane calls which, per-PR.

**Signing model: `match`, not cloud signing.** ADR-021 D5's API-key cloud
signing (`-allowProvisioningUpdates` + the
`~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8` auto-discovery path)
**cannot work on a GitHub-hosted runner**: it has no Xcode-managed Apple ID and
an empty keychain, so the archive fails *"No valid code signing certificates
were found."* Cloud signing can fetch a profile; it cannot conjure the
certificate's private key. `match` clones an encrypted certs repo
(`MATCH_GIT_URL`), decrypts it with `MATCH_PASSWORD`, and installs the identity
into a temporary keychain. It runs **`readonly`** unless the one-shot
`MATCH_BOOTSTRAP` repo variable is set, so CI **cannot mint** a certificate —
which is what closed issue #99 (Apple caps Apple Distribution certs at 3).

**Honesty bound (ADR-021 D5) — now DISCHARGED by a real run.** The
signing/upload half was unverifiable from the Linux dev box, and everything it
listed as unproven is proven: Apple accepts the signing, the App Store Connect
app record exists, and the upload lands (build 109). Issue **#99** is closed —
not by watching runs accumulate, but because `match(readonly: true)` removes
the certificate-minting mechanism outright.

**What is still not verified from Linux**, and deliberately not asserted:
whether the `write App Store Connect API key` step in `release.yml` is read by
anything at all under manual signing. The evidence says no. It is kept anyway
(ADR-032 D4) on the same principle ADR-029 D2 used when it refused to touch
`CODE_SIGN_IDENTITY`: a blind edit to a working signing path from a box with no
Mac is exactly what this bound forbids. A session that can watch a real run
should delete it and confirm.

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

### Screenshots — rendered from the app, on Linux, at Apple's exact size

No longer a manual job on somebody's phone, and no longer un-uploadable:
`store_metadata` keeps `skip_screenshots: true`, and a second lane owns them.

```sh
tool/ci/appstore_screenshots.sh          # → app/build/appstore/screenshots/{tr,en}/
```

Twelve PNGs at **1290×2796** — six screens × the two listing locales — which is
the whole iPhone requirement: App Store Connect takes the 6.9" set and scales
every smaller device down from it, and the app is iPhone-only since #179, so
there is no 13" iPad set to produce.

**No Mac, no simulator, no device.** `flutter test` rasterises widgets on the
host, so `app/screenshots/appstore_screenshots_test.dart` renders real pixels of
real screens from the same fakes and the same shipped question packs the goldens
use — the surface size comes from `APPSTORE_SCREENSHOT_SURFACE`, which
`golden_harness.dart` reads and which is UNSET everywhere else, so the 390×844
goldens stay byte-identical. The store listing and the tested product cannot
drift apart, because they are renders of one widget tree.

**Uploading them** is the `appstore-screenshots` workflow — dispatch only, never
a step in `release.yml`, and `upload: false` by default so the cheap half
(render + verify + artifact) is what you get without thinking. It runs the
`store_screenshots` lane, which is deliberately **separate from
`store_metadata`**: every store string here is AI-drafted and awaiting native
review, so a lane that pushed both would make uploading an image an implicit
publish of unreviewed Turkish copy.

Measured 2026-08-03 via `--store-status` before any of this was built:

```
1.0  state=PREPARE_FOR_SUBMISSION  platform=IOS   <-- editable
    en-US: no screenshots
```

So there **is** a version to write to — and **only `en-US` exists on it**. The
`tr` version localization has never been created, which means
`fastlane/metadata/tr/` has never landed either. Turkish screenshots have
nowhere to go until that locale exists, by one of two routes, both the founder's
call: add Turkish in App Store Connect by hand, or run `store_metadata` and
accept that it publishes the un-reviewed Turkish copy at the same time.

Three things the render lane learned the hard way, all pinned in code:

- **`matchesGoldenFile` cannot produce a store asset.** With the view at
  1290×2796 @3 it writes a **430×932** file — it captures at the logical size
  and ignores `devicePixelRatio`. Right for a diff, useless for Apple. Hence
  `writeSurfacePng`, which captures the boundary at an explicit DPR.
- **`flutter_test_config.dart` is found by walking up from the TEST file.** A
  generator outside `test/` never sees the suite's font loader, and the failure
  is silent in the worst way: right size, right colours, right layout, green
  run — and every glyph an empty box. `screenshots/flutter_test_config.dart`
  delegates to the suite's rather than copying its font list.
- **The generator's exit code proves nothing about the pixels.** It is a widget
  test; it goes green whenever it does not throw, including if the surface
  override were ignored entirely. The script re-reads every PNG's IHDR and fails
  on a wrong size or an empty output directory.

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

**Both are now DECIDED — the founder exercised them (ADR-032 D6).**

- **App Store name** is **`İkimiz`**, one of ADR-020 D1's own vetted
  alternates, matching the live App Store Connect record. It is **pinned** in
  `tool/release_lane_lint.dart`, because `deliver(force: true)` skips the
  confirmation prompt: a drifted `name.txt` silently **renames the live
  listing** on the next release. Change the pin and every `name.txt` in one
  commit.
- **`CFBundleDisplayName`** is **`İkimiz`** (PR #118), matching the store record
  and the shipped build. ADR-020 D2 required the discreet-icon honesty copy to
  be re-audited in the same commit; that was missed there and **done in S047**.
  Result: `settingsDiscreetSubtitle` ("The app's name still appears under it")
  names no specific string in any of the three locales, so ADR-018 D6's honesty
  bound holds verbatim under the new name. No copy change was needed.

## Running the lanes

Requires Ruby + bundler, which are **not installed on the dev machine** (see
debt below). Once they exist, from the repo root:

```sh
bundle install
bundle exec fastlane ios build_debug     # unsigned debug build, zero secrets
bundle exec fastlane ios beta            # fails closed without ASC_* + MATCH_* creds
bundle exec fastlane ios store_metadata  # fails closed without ASC_* creds
```

In practice nobody runs `beta` by hand: `git tag vX.Y.Z && git push --tags`
from `main` runs the whole lane in CI.

## Documented debt

**✅ `Gemfile.lock` is COMMITTED (issue #120, S048).** ADR-021 D6 deferred it
"until the signing job first runs"; that happened several releases ago and
nothing noticed the debt had come due, so every release resolved fastlane freshly
within `~> 2.225` — on the lane that owns certificate custody and rewrites the
pbxproj. It now pins **fastlane 2.237.0** and 96 gems.

The original blocker never went away — **there is still no Ruby on the Linux dev
box** — so the lock is not hand-authored. `.github/workflows/gemfile-lock.yml`
(dispatch-only) generates it, and two choices make its output trustworthy rather
than merely present:

1. It resolves on **macos-26 / ruby 3.3**, the same runner and Ruby `sign-upload`
   installs on. A lock resolved on ubuntu can omit the darwin platform entirely
   and `bundle install` then refuses it on macOS.
2. It installs **`--frozen`** before publishing — the `npm ci` of this ecosystem.
   `--frozen` asserts the lock is already coherent instead of rewriting it to fit,
   which is the exact distinction S044 paid for when `npm install` passed 979
   tests and `npm ci` refused the tree. A lock that cannot install frozen never
   becomes an artifact. (`bundle lock --add-platform ruby` is also applied, so a
   future runner-image arch bump does not invalidate it.)

To regenerate after a Gemfile change:

```sh
gh workflow run gemfile-lock.yml --ref main
gh run download <run-id> --name Gemfile.lock --dir .
```

`tool/release_lane_lint.dart` rule 5 keeps the two honest: the lock's resolved
fastlane must satisfy the Gemfile's `~>` constraint, so a deleted lock or a
Gemfile bump without a regen reddens the **cheap ubuntu preflight** instead of
failing inside the release job past a 40-minute macOS leg.

## Secrets policy

Zero credentials in **this** repo (architecture.md §9) — and since ADR-032 D1
that wording is deliberately narrow. Nothing is committed here, but release
signing is no longer keyless: the Apple Distribution certificate **and its
private key** live encrypted in a **separate private repository**
(`MATCH_GIT_URL`), decryptable with `MATCH_PASSWORD`. **Custody moved; it did
not vanish**, and those two secrets compose into the ability to sign as this
team.

`ASC_KEY_ID` / `ASC_ISSUER_ID` are `release` **environment** secrets;
`ASC_API_KEY_P8_BASE64` / `MATCH_GIT_URL` / `MATCH_PASSWORD` are **repository**
secrets (a job with an `environment:` binding sees both). The `.p8` lands on
disk only in a post-gate step, decoded from `ASC_API_KEY_P8_BASE64` — one
secret holds the key, because two encodings of one credential is a rotation
footgun. Fastlane runtime artifacts (`fastlane/report.xml`, `Preview.html`,
`test_output/`) are gitignored so a real lane run does not dirty the tree.
