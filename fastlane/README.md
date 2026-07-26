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

`Gemfile.lock` is still **absent**, and ADR-021 D6's stated discharge condition
has now been MET without discharging it — `sign-upload` has executed
`bundle install` several times. The original blocker stands: **there is no Ruby
on the Linux dev box**, so no faithful lock can be generated here, and
hand-authoring one is worse than none. So every release run resolves fastlane
fresh within `~> 2.225`, **on a signing path**. That is real supply-chain drift
on the most sensitive lane in the repo, recorded rather than carried silently
(`project-rules.md` #9) and tracked as its own issue. Also noted in the root
`Gemfile`.

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
