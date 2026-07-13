# ADR-021: The release lane — tag-triggered `release.yml`, App Store Connect API-key cloud signing, and a fail-closed loud boundary where secrets don't exist yet

- **Status:** Accepted
- **Date:** 2026-07-13 (Session 022, M6.3)
- **Deciders:** session agent, per resume-prompt M6.3
- **Related:** ADR-006 (iOS-first), `docs/architecture.md` §9, `docs/test-suite.md` (release-lane E2E promise), `docs/agent-workflows.md` W7, `fastlane/README.md`, operator-expected item 4

## Context

The open M6 accept line is *"`release.yml` produces signed builds to TestFlight."* The honest boundary (session-rules §1.5): signing and upload need the founder's Apple Developer enrollment (operator item 4, pending) and signing secrets that do not exist — `gh secret list` and the environments API both return empty. The realistic scope is a lane **built and provable to the boundary**: pre-signing stages green on a branch dispatch, and a **loud, explanatory failure** exactly where secrets are required — never a skip that renders green (resume-prompt: "never a silent skip that looks green").

Existing doc promises that constrain the shape (verbatim inventory in the scout record): tag `vX.Y.Z` trigger; stage order integration suite → build → sign → upload → store metadata per locale from `fastlane/metadata`; secrets from GitHub environment secrets, zero keys in repo; iOS-only until M6.5. `test-suite.md` additionally promises an E2E simulator matrix (current-1/current) with three E2E scenarios — of which E2E-2 (sandbox purchase → premium on both devices) is **impossible before operator items 0+4** and none exist as test files yet.

House CI rules that bind: pinned versions everywhere (Flutter 3.44.5 via a single `env` var, macos-15, Xcode 16.4 + lowest-runtime sim recipe, Temurin 21, Node 20, firebase-tools 15.22.4 with the jar cache), least-privilege `permissions`, explicit `timeout-minutes`, W4 determinism (no silent retries, no `|| true`, quarantines are annotated), and the Fastfile's own fail-closed idiom (`UI.user_error!` with a doc-pointing message).

Alternatives considered for signing:

- **(a) fastlane match** — needs a certificates repo, a match passphrase, and an enrolled account to mint into it. Most secrets, most founder ceremony, and nothing can be pre-staged before enrollment.
- **(b) Manual cert/profile secrets** (base64 .p12 + provisioning profile + keychain scripting) — the classic recipe, 4–5 secrets, requires the founder to export and re-export artifacts Xcode manages implicitly; brittle at exactly the operator-skill boundary this project keeps hitting.
- **(c) App Store Connect API-key cloud signing** — Xcode 13+ `-allowProvisioningUpdates` with `-authenticationKeyPath/-authenticationKeyID/-authenticationKeyIssuerID` lets xcodebuild mint/refresh certs and profiles on a throwaway CI keychain. **Three secrets total** (`ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_API_KEY_P8`), all copy-paste from one App Store Connect page, and the same key authenticates the TestFlight upload and the metadata deliver.

## Decision 1 — Triggers: `push` on tags `v*.*.*` plus `workflow_dispatch`; the dispatch run IS the boundary proof — and it necessarily happens AFTER the merge (rev 2)

Tag push is the release path (W7). `workflow_dispatch` exists so the lane can be proven end-to-end-to-the-boundary without cutting a tag. There is deliberately **no dry-run input that skips the signing job**: a skipped boundary can't prove it fails closed, and an input-gated skip is one typo from a silent-green release lane. A dispatch without secrets is EXPECTED to end red at the named boundary step with a message that says exactly why and what to do — that red is the honest state of the M6 accept line itself (signed-build half operator-blocked), and it is proven, not asserted.

**Rev 2 (review finding REL-1, blocking):** GitHub registers a `workflow_dispatch` workflow only once its file exists on the **default branch** — a first-time `release.yml` cannot be dispatched from its own feature branch (`gh workflow run release.yml --ref <branch>` 404s; the ci.yml "prove green on a branch" precedent works only because ci.yml is already on main). The acceptance proof is therefore re-sequenced: pre-merge, the PR carries syntax-level validation (actionlint-equivalent review + the preflight tool runs in ci.yml's quality job); the acceptance dispatch runs **immediately after the squash-merge, this same session**, as `gh workflow run release.yml --ref main` — pre-signing stages green, honest red at the boundary. If a pre-signing stage is red on that run, the fix lands as a same-session follow-up commit (session-rules §3.5's quick-fix lane). The resume-prompt's literal "on a branch dispatch" is impossible for a first-time workflow; this deviation is recorded here and in past-prompts, not silently reinterpreted. Future edits to `release.yml` CAN use branch dispatches (the workflow will then exist on main), restoring the ci.yml pattern.

## Decision 2 — Stage order and job graph: `preflight` (ubuntu) → `integration` (macOS) ∥ `build-report` (macOS) → `sign-upload` (macOS, the boundary)

- **`preflight`** (ubuntu, cheap, fails fast): store-metadata lint (`tool/store_metadata_lint.dart --allow-empty-urls tr en-US`), tag↔pubspec version consistency (Decision 3) on tag runs, and YAML-reachable sanity (checkout + tool run proves the tree). No macOS minute is spent if metadata or versioning is broken.
- **`integration`** (macOS): the existing `integration_test/` suites against auth/firestore/functions emulators — the ci.yml `integration-emulator` recipe reused verbatim (same Xcode 16.4 pin, fresh-sim lowest-runtime boot, serialized suites, quarantine annotation for issue #15). This is the strongest signal that exists today. The promised **E2E matrix (current-1/current) and E2E-1/2/3 scenario files do not exist and are NOT faked**: E2E-2 requires a sandbox store (items 0+4). Recorded as a deferral in `test-suite.md` in this same change — the matrix enters when the scenarios can honestly run (Mac/sandbox era).
- **`build-report`** (macOS, parallel with integration — it needs no emulators): `flutter build ios --release --no-codesign -t lib/main_prod.dart` with `--analyze-size`, producing the size table in the job log, the size JSON as an artifact, and the budget check via `tool/build_size_report.dart` (ADR-022 Decision 4). Prod entrypoint deliberately: TestFlight builds carry prod config (operator runbook), so the size that matters is prod's.
- **`sign-upload`** (macOS, `needs: [preflight, integration, build-report]`): the boundary job. Its FIRST step is the secrets gate (Decision 4). Only after the gate: Ruby/bundler setup, `bundle install` (Gemfile pins fastlane ~> 2.225), and the implemented `beta` lane — `flutter build ipa --release -t lib/main_prod.dart` via cloud signing, `upload_to_testflight`, then `deliver(skip_binary_upload: true, force: true)` pushing `fastlane/metadata` per locale.

Concurrency group `release-${{ github.ref }}` without `cancel-in-progress` on tag runs (a half-cancelled upload is worse than a queued one); `permissions: contents: read` throughout; every job has an explicit timeout.

## Decision 3 — Version discipline: the tag must equal pubspec's `X.Y.Z`; the build number is pubspec's `+N`; mismatch fails preflight

One source of truth (`app/pubspec.yaml` `version: 0.1.0+1`), already the operator runbook's mental model ("every later upload needs the build number after the `+` bumped"). On a `v*` run, preflight greps pubspec and hard-fails on mismatch with both values printed. No auto-increment magic in CI: a lane that invents build numbers hides state in App Store Connect, and idempotent re-runs of the same tag should produce the same build number (TestFlight rejects duplicates loudly — that rejection is the correct signal, not something to engineer around).

## Decision 4 — The fail-closed boundary: one named gate step, all-or-nothing, message points at operator item 4

The `sign-upload` job's first step ("signing secrets gate") checks **all three** ASC secrets. Any missing → `exit 1` with a message that names the missing secret(s), states plainly that the signed-build/TestFlight half of M6 is operator-blocked on Apple Developer enrollment (item 4), and points at the runbook section for creating the API key. Design rules:

- **Rev 2 (review finding REL-2, serious): the job declares `environment: release`.** Architecture §9 designates GitHub *environment* secrets, and environment secrets are only exposed to jobs that declare the binding — without it, `secrets.ASC_*` silently resolve against repository secrets and read empty even after the founder configures the environment, turning a configured lane into a permanent boundary-red with a misleading "missing secrets" message. Referencing a not-yet-existing environment is safe (GitHub auto-creates it on first run; with no secrets the gate fails closed exactly as designed). The operator instruction (item 4 at close) says explicitly: the three secrets go into **Settings → Environments → `release`**, where the founder can also add protection rules later.

- **All-or-nothing:** a partial secret set (key id without the .p8) must not reach fastlane to die with an opaque auth error — the gate reports the full missing set at once.
- **No `if:` conditionals on the signing steps** — a step skipped by an expression renders grey-green in the UI. The gate is an ordinary step that fails; everything after it simply never runs. (GitHub cannot read secret presence in job-level `if:` reliably anyway; secrets are only testable inside a step.)
- The gate never echoes secret VALUES (only names), and the .p8 lands on disk only in the post-gate step, written to the runner temp dir from the secret, never checked in — architecture §9's "zero keys in repo" invariant.
- Fastlane-level redundancy: the `beta` lane itself re-asserts the env vars with `UI.user_error!` (the Fastfile's existing idiom) so running the lane locally on the founder's Mac without env gives the same honest message, not an xcodebuild stack trace.

## Decision 5 — What `beta` does the day secrets exist (designed now, verifiable then — recorded as such)

`app_store_connect_api_key(key_id:, issuer_id:, key_content:)` → write the .p8 to `~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8` (xcodebuild's documented auto-discovery location — this, not an export-options key, is how the API key reaches the ARCHIVE step's cloud signing; rev 2 precision from the review's skeptic pass: `flutter build ipa` already passes `-allowProvisioningUpdates` to both archive and export unconditionally, so no xcargs plumbing is needed) → `sh("cd ../app && flutter build ipa --release -t lib/main_prod.dart")` → `upload_to_testflight(api_key:, skip_waiting_for_build_processing: true)` → `deliver(api_key:, skip_binary_upload: true, skip_screenshots: true, force: true)`. **Honesty bound, recorded:** this half is UNVERIFIABLE from a Linux session with zero secrets — the first real tag run after enrollment may need a Mac-era fix (likeliest candidate: the automatic-signing `DEVELOPMENT_TEAM` build setting, which no secret currently carries). **Post-implementation review addendum:** the ipa path is passed to `upload_to_testflight` explicitly (`../app/build/ios/ipa/*.ipa`, fail-closed when absent) because the raw-`sh` build leaves `lane_context` without `IPA_OUTPUT_PATH` and pilot's glob fallback searches the wrong directory — a near-certain first-run failure the review caught before it could trap the first release session. That risk is accepted over inventing a fake verification; the fail-closed gate guarantees the failure mode is loud, attributed, and cannot look like success. The first-real-run checklist is added to operator item 4 at close.

## Decision 6 — Fastlane hygiene: `Gemfile.lock` debt stands; fastlane runtime artifacts get gitignored now

No Ruby exists on the dev box, so the documented `Gemfile.lock` debt ("committed the first time fastlane is exercised") technically survives this session — the pre-signing stages never run Ruby, and the signing job (which does) is blocked at the gate. The lock lands the first time `sign-upload` actually executes bundler (first enrolled run or founder's Mac). Meanwhile the standard fastlane runtime artifacts (`fastlane/report.xml`, `fastlane/Preview.html`, `fastlane/test_output/`) join the root `.gitignore` — the scout confirmed none are ignored today, and the first real lane run must not dirty the tree. `fastlane/metadata/**` stays tracked (it is the store-copy source of truth).

## Consequences

**Positive:**

- The M6 accept line's buildable half is done and *provable this session*: green pre-signing stages on the post-merge main dispatch + a demonstrated, correctly-worded failure at the boundary (rev 2: the dispatch necessarily follows the merge — Decision 1).
- Three copy-paste secrets is the smallest possible founder ceremony; the same key drives signing, TestFlight, and metadata.
- Version truth stays in one greppable place; a re-run of a tag is idempotent.
- No doc promise is silently broken: the E2E-matrix deferral is written into `test-suite.md` with its reason, not left to drift.

**Negative / accepted trade-offs:**

- The dispatch proof ends in a red job by design; anyone reading the Actions tab must read the boundary message, not the color. Accepted: the alternative (green skip) is the exact dishonesty the acceptance criteria forbid.
- The first-ever acceptance dispatch runs against merged main, so a pre-signing-stage defect surfaces post-merge and is fixed forward same-session (Decision 1 rev 2). Accepted: a first-time `workflow_dispatch` workflow gives no pre-merge alternative, and the pre-signing stages reuse recipes ci.yml already proves.

## Pre-code adversarial review record (Session 022 — eight-for-eight)

5 lenses (over-claim, release-engineering, Apple-domain, app-runtime, governing-docs) × 2 verifiers (refuting skeptic + governing-docs adjudicator) over the rev-1 text of ADR-020/021/022: 15 raw findings, 10 after dedup — **2 blocking + 2 serious CONFIRMED by both verifiers** (REL-1 dispatch-registration re-sequence and REL-2 environment binding fixed above; the other two landed in ADR-022 rev 2), 3 REFUTED (the `flutter build ipa` cloud-signing "category error" — refuted against pinned flutter_tools source, which passes `-allowProvisioningUpdates` unconditionally, with the skeptic's precision folded into Decision 5; the "verbatim ci.yml reuse breaks under tag triggers" — refuted, "verbatim" scopes to the recipe steps, not job-level `if:`/`needs`; the "empty URL files clobber founder values via deliver" — refuted against pinned deliver source), 3 minors hand-adjudicated into ADR-020 rev 2.

## Post-implementation review record (same session, over the built diff — ninth consecutive pass with real findings)

Same 5-lens × 2-verifier shape over `git diff main...HEAD`: **zero blocking/serious** (the pre-code pass had already taken the four real defects), 2 minors, both hand-adjudicated CONFIRMED and fixed pre-merge: the `upload_to_testflight` ipa-path gap (fixed in the Fastfile + recorded in Decision 5's addendum above) and the operator-expected Phase D export-compliance note going stale against the shipped plist key (fixed in the close-time refresh).
- Cloud signing is unverified until enrollment; the first real run may need fixes. Accepted and recorded (Decision 5) — the failure will be loud, not silent.
- Tag runs re-run the integration suite on 10×-billed macOS minutes (~binds a release to ~30-40 min of runner time). Accepted: a release without the strongest available signal would be cheaper and worse.
- `deliver`'s metadata push is gated behind the same boundary, so store copy cannot reach App Store Connect from CI until enrollment — consistent with the copy being native-review-gated anyway.
