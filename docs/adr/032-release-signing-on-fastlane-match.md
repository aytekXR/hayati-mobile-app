# ADR-032: Release signing on fastlane `match` — certificate custody, manual signing, and where version truth lives

- **Status:** Accepted
- **Date:** 2026-07-26
- **Deciders:** Session 047 (writing the record for a change merged as PR #117 by a concurrent operator session)
- **Related:** [ADR-021](021-release-lane-fail-closed-signing-boundary.md) — **D5 superseded**, **D3's build-number clause superseded**, D3's tag↔pubspec clause **restored**; [ADR-029](029-release-lane-signing-enablement.md) — **D2's rationale amended**, **D4 closed**; [ADR-020](020-store-identity-and-metadata-posture.md) — D1/D2 resolved by the founder; [ADR-006](006-ios-first-release-sequencing.md); issues **#99** (closed by D2), #100 (deliberately untouched)

## Context

**This ADR is written after the fact, and that is the first thing to say plainly.** PR #117 replaced the
entire iOS release-signing mechanism and merged without one. `project-rules.md` #8 requires an ADR for every
architectural decision and `agent-workflows.md` W6 requires it *in the same commit as the change*. Neither
happened. The record is late.

Lateness is not the interesting part; the cost is. For four days `main` carried an `architecture.md` §9, an
ADR-021 and an ADR-029 that all described a signing mechanism the repo no longer used — and **four real
defects lived in the gap between the documented design and the shipped one**, three of them invisible to
every check the project owns. A stale design document is not a tidiness problem. It is where defects hide.

### What changed, mechanically

ADR-021 D5 designed **App Store Connect API-key cloud signing**: the `.p8` lands at xcodebuild's
`~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8` auto-discovery path, `flutter build ipa` passes
`-allowProvisioningUpdates` unconditionally, and xcodebuild fetches or mints the profile itself. ADR-029 D2
then pinned `CODE_SIGN_STYLE = Automatic` explicitly *because that mechanism is inert under manual signing*.

It does not work on a GitHub-hosted runner. A hosted macOS runner has no Xcode-managed Apple ID and an empty
keychain, and the archive fails with **"No valid code signing certificates were found."** Cloud signing can
fetch a *profile*; it cannot conjure the *distribution certificate's private key*.

PR #117 rebuilt the lane on **fastlane `match`**, following the pattern already proven in the founder's
sibling app: the Apple Distribution certificate **and its private key**, plus the App Store provisioning
profile, live **encrypted (OpenSSL symmetric, `MATCH_PASSWORD`) in a private git repository** (`MATCH_GIT_URL`
→ `aytekXR/hayati-match-certs`). CI clones it, decrypts into a temporary keychain, and the build signs
**manually** against the installed identity. Verified end to end: run `30193322224` archived
`com.beyondkaira.hayati`, exported a 37.9 MB IPA, and uploaded **build 109** to TestFlight.

The mechanism works and is not re-litigated here. What was never decided in writing is everything that
travelled with it.

## Decision

### Decision 1 — Custody is `match` over a private encrypted repo, and §9's "zero keys in repo" is restated honestly

`match` stays. The alternatives are worse: importing cert+key from two new GitHub secrets is the same custody
problem with less tooling and no rotation story; a self-hosted macOS runner is a machine the founder must own
and patch for one build a week; manual Mac builds are the exact thing the founder asked to stop doing (they
develop on Linux).

**What is decided here is the honesty of the record.** `architecture.md` §9 said:

> **zero keys in repo** — an invariant that still holds exactly: no key, certificate, `.p8`, password or
> token is committed.

That sentence is still literally true of *this* repository, and it is now a **misleading half-truth about the
system**. It is amended to say what is true:

> No key, certificate, `.p8`, password or token is committed **to this repository** — that invariant is
> intact, and every credential still arrives from GitHub secrets at run time. But release signing is no
> longer keyless: since ADR-032 the Apple Distribution certificate **and its private key** live encrypted in
> a **separate private repository** (`MATCH_GIT_URL`), decryptable with `MATCH_PASSWORD`. **Custody moved; it
> did not vanish**, and two secrets now compose into the ability to sign as this team.

That is the whole point of the amendment. A reader who trusted the old wording would conclude the project
holds no signing key anywhere and would price a leaked `MATCH_PASSWORD` wrong. Issue #99 anticipated exactly
this: it said a `match` design *"introduces new private-key custody into a repo whose stated invariant is
'zero keys in repo'"* and *"deserves its own ADR."*

**Recorded, not solved.** Read access to the match repo is granted to CI by a fine-grained PAT; that repo's
compromise *plus* `MATCH_PASSWORD` equals the ability to sign as this team. Scheduled certificate rotation and
moving the match remote off GitHub are the available mitigations, deliberately not built this session and not
urgent pre-launch. The requirement is that a reader can *see* the exposure — which the old sentence prevented.

### Decision 2 — `match` runs `readonly` in CI, which closes #99 by removing the mechanism

#99 asked whether a fresh runner keychain makes xcodebuild mint a **new** Apple Distribution certificate per
run, exhausting Apple's cap of three. Under cloud signing that was a real, unbounded risk, and ADR-029 D4
recorded it as observable-only-on-a-real-run.

`match` removes the mechanism rather than mitigating it. The lane runs
`readonly: ENV["MATCH_BOOTSTRAP"] != "true"`, and `MATCH_BOOTSTRAP` was deleted after the single bootstrap run
(verified: it is absent from the repository variables). In readonly mode `match` **never creates** anything —
it installs the stored identity or fails loudly with "No code signing identity found." CI therefore cannot
mint a certificate at all, whatever the keychain state.

#99 closes on that argument, not on an accumulation of green runs. The residual is named rather than implied:
**setting `MATCH_BOOTSTRAP=true` again re-arms minting**, so it is a one-shot bootstrap variable, not a toggle
to leave lying around.

### Decision 3 — The build **name** comes from `pubspec.yaml`; the build **number** is CI-synthesized

Two halves, decided in opposite directions, because the evidence points in opposite directions.

**The build name returns to pubspec — ADR-021 D3's first clause is RESTORED.** `preflight` hard-fails when a
tag's `X.Y.Z` disagrees with `app/pubspec.yaml`, for the stated reason that pubspec is the one source of
version truth. PR #117 then passed `--build-name=0.1.0` as a **literal**, so the gate began guarding a string
the build does not read. Today they agree by coincidence (pubspec is `0.1.0+4`). Tag `v0.2.0` against pubspec
`0.2.0` and preflight goes green while TestFlight receives a binary stamped **0.1.0**. The fix is a
**deletion**: drop the flag and `flutter build ipa` reads pubspec, exactly as it did before #117.

**The build number stays synthesized — ADR-021 D3's second clause is SUPERSEDED.** D3 said:

> No auto-increment magic in CI: a lane that invents build numbers hides state in App Store Connect, and
> idempotent re-runs of the same tag should produce the same build number (TestFlight rejects duplicates
> loudly — that rejection is the correct signal, not something to engineer around).

That was reasoned before anyone had run the lane. The run history is the counter-argument: **six consecutive
release runs failed before one succeeded**, each needing a fresh build number, and under pubspec-`+N` every
retry would have cost a commit *and* a re-tag to produce one. A release lane whose retry path costs a commit
is a lane people force-move tags around. `100 + GITHUB_RUN_NUMBER` is monotonic by construction.

**The cost is real and accepted explicitly:** re-running the same tag now produces a *different* build number,
so D3's idempotency is genuinely gone and App Store Connect — not this repo — answers "which build was tag
`v0.1.0`?". The mitigation is that the version *name* is pubspec's again, so a tag still maps to exactly one
version string; only the build integer floats.

**A trap that must be written down:** the highest build already uploaded for version `0.1.0` is **109**, while
`app/pubspec.yaml` reads `+4`. pubspec's build number is therefore no longer the release build number, and
both places that still describe it as one — `release.yml`'s preflight comment and `architecture.md` §9 — are
corrected in this diff. Anyone who "restores" D3 by deleting the synthesis would ship build 4 into a version
whose builds already reach 109, and App Store Connect would reject it.

### Decision 4 — The fail-closed gate checks what the job consumes; the `.p8` step is deliberately NOT touched

ADR-021 D4's guarantee is that `sign-upload`'s **first** step fails closed, names the **full** missing set at
once, and ensures *"a partial secret set must not reach fastlane to die on an opaque auth error."* The match
swap left it checking `ASC_KEY_ID` / `ASC_ISSUER_ID` / `ASC_API_KEY_P8` while the job also consumes
`ASC_API_KEY_P8_BASE64`, `MATCH_GIT_URL` and `MATCH_PASSWORD`. A missing `MATCH_PASSWORD` sailed through the
gate and died inside fastlane — precisely the outcome D4 was written to prevent. The gate now checks all six.

**The "write App Store Connect API key" step is KEPT, though the evidence says nothing reads it.** Under
manual signing, xcodebuild's `~/.appstoreconnect/private_keys` auto-discovery path is consulted only by
`-allowProvisioningUpdates`, and fastlane receives the key through `app_store_connect_api_key(key_content:)`
instead — so the step looks inert, and deleting it would drop a private key off the runner's disk and retire a
redundant secret.

It is kept anyway, on this project's own precedent. ADR-029 D2 left `CODE_SIGN_IDENTITY` alone for exactly
this reason:

> Changing it is not required, not proven necessary, and would be a blind edit to a signing path from a Linux
> box with no Mac — exactly what ADR-021 D5's honesty bound forbids.

The lane demonstrably works *with* the step. "Very likely dead" is not "proven dead", and the cost of being
wrong is a broken release the founder cannot debug from their side. The observation is recorded as an issue
for a session that can watch a real run, and `ASC_API_KEY_P8` stays legitimately in the gate because the job
genuinely still consumes it.

### Decision 5 — `store_metadata` gets its own, narrower credential check

`store_metadata` pushes `fastlane/metadata` with `deliver(skip_binary_upload: true)`. It needs the App Store
Connect API key and nothing else: it signs nothing and touches no certificate. PR #117 nonetheless routed it
through `ensure_release_credentials!`, which requires the two `MATCH_*` inputs — and `release.yml` passes only
the three ASC values to that step.

**So the lane aborted before `deliver` on every single release**, and because the step is
`continue-on-error: true` — correct, per ADR-020 D8, since store copy is native-review-gated and must never
fail a build whose binary already shipped — the job reported **success**. Verified in run `30193322224`:

```
[!] Release signing is not configured: MATCH_GIT_URL, MATCH_PASSWORD are unset.
[08:15:36]: fastlane finished with errors
##[error]Process completed with exit code 1
```

inside a `sign-upload` job whose conclusion is `success`. **Store metadata has never once been delivered**,
and nothing anywhere said so.

This is this repo's own recorded lesson repeating — *a bound justified by one caller's constraints is not safe
for another caller* (S042 addendum 25, where a 4,000-character limit justified for user input was reused on a
model reply and stopped scanning the tail of long replies). The helper splits:
`ensure_asc_credentials!` for `store_metadata`, `ensure_release_credentials!` (which delegates to it, then
adds the match inputs) for `beta`.

### Decision 6 — The store name becomes **İkimiz**, in the same diff as Decision 5, never after it

`fastlane/metadata/{tr,en-US}/name.txt` said `Hayati`. The App Store Connect record and the shipped
`CFBundleDisplayName` say **`İkimiz`**. `deliver(force: true)` skips the confirmation prompt, so the moment
Decision 5 lets `store_metadata` run, the next release would **rename the founder's live App Store listing
from İkimiz back to Hayati**.

That coupling *is* the decision: fixing the credential bug alone converts a silent no-op into a silent
regression on a live storefront. The two changes are one change, and a lint now pins the name so they cannot
drift apart again.

**This is not a session spending a founder decision.** ADR-020 D1 recorded the store name as *provisional*
pending a trademark/availability search, listing **İkimiz** among its own vetted alternates, and ADR-020 D2
reserved `CFBundleDisplayName` as founder-owned. The founder exercised both — they created the App Store
record as İkimiz and renamed the binary (PR #118). The repo is being reconciled to a decision already made,
which is the cheap one-line metadata edit ADR-020 D1 promised it would be.

ADR-020 D2 attached a condition to any label change: *"whichever the founder picks, the discreet-icon honesty
copy must be re-audited in the same commit."* PR #118 did not do that, so it is done here. **The finding is
that the copy is unaffected:** `settingsDiscreetSubtitle` reads *"The app's name still appears under it"* in
all three locales and names no specific string, so ADR-018 D6's honesty bound holds verbatim under the new
name. The audit is recorded even though it changed nothing — afterwards, a check that was never run and a
check that found nothing are indistinguishable unless one of them is written down.

### Decision 7 — ADR-029 D2's pin stays; its recorded reason is amended, because the reason inverted

ADR-029 D2 pinned `CODE_SIGN_STYLE = Automatic` on all three app-target configs, defended by
`signing_sentinel_test.dart`, justified thus: *"the entire signing mechanism of ADR-021 D5 rests on automatic
(cloud) signing… a one-word flip of this setting silently invalidates ADR-021 D5."*

The lane now **performs that exact flip on purpose, every run** —
`update_code_signing_settings(use_automatic_signing: false)` writes `Manual` into the checked-out pbxproj
before archiving (visible in the run log: *"Successfully updated project settings to use Code Sign Style =
'Manual'"*). The stated reason is not merely stale; it is inverted.

**The pin stays**, for a reason that is still true: `Automatic` is correct for the **committed** project,
which is what the founder's Mac and the cable rig build with, and it gives the CI mutation a known starting
state. What changes is the justification — in this ADR, in the sentinel's test reason, and in
`architecture.md` §9. This repo has paid for the inverse before: a safety claim in a code comment is a
guarantee surface, and a comment naming a retired mechanism misleads the next reader.

## Consequences

### Positive

- The release lane's documentation describes the release lane. For four days on `main` it did not.
- Two silent failures become impossible: a store-metadata push that never ran while reporting success, and a
  version-name gate guarding a string the build ignored.
- ADR-021 D4's fail-closed guarantee is true again as written.
- #99 closes on a mechanism argument rather than an accumulation of green runs.
- `tool/release_lane_lint.dart` makes the lane's self-agreement a **per-PR** check on cheap ubuntu minutes.
  `release.yml` runs only on a tag or a dispatch, so between two releases its internals could drift with every
  required check green — which is exactly what happened. The lint's rule 3b is deliberately **per step**,
  because the real defect was green at job level: the job *did* pass the match inputs, to a different step.
- The `--build-name` fix is a deletion, and deletions cannot drift.

### Negative / accepted trade-offs

- **Signing authority is now two composable secrets** (`MATCH_GIT_URL` access + `MATCH_PASSWORD`) rather than
  an Apple-side key alone. That is the price of hosted-runner signing, now stated rather than implied.
- **Re-running a tag produces a different build number.** ADR-021 D3's idempotency is genuinely lost.
- **A likely-dead step survives**, on the honesty bound rather than on evidence (D4).
- **`Gemfile.lock` is still absent.** ADR-021 D6 tied the debt's discharge to *"the first time fastlane is
  exercised"* — which has now happened three times — but the original blocker stands: there is no Ruby on the
  Linux dev box, so no faithful lock can be generated here, and hand-authoring one is worse than none. Every
  release run therefore resolves fastlane fresh within `~> 2.225`, on a signing path. Tracked as its own issue
  rather than carried silently (`project-rules.md` #9).
- **This ADR is late.** The precedent it sets is that a decision merged without a record gets one written
  against the merged code, with the gap named — not that the requirement is optional.

### Neutral

- The `release` environment's `ASC_API_KEY_P8` stays in use (D4); no founder action is requested.
- #100 (CI cost posture on a public repo) is untouched. It is a separate decision with its own measurement,
  and bundling it here would be the "one decision per file" violation the ADR README forbids.
