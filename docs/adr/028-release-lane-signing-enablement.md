# ADR-028: Release-lane signing enablement — the committed `DEVELOPMENT_TEAM`, explicitly-pinned automatic signing, and a signing source-sentinel

- **Status:** Accepted
- **Date:** 2026-07-26 (Session 041)
- **Deciders:** session agent. The founder's action — adding the three `ASC_*` secrets — is what unblocked this; the identifier-vs-credential judgement in Decision 1 is recorded explicitly so the founder can overturn it with one line if they disagree.
- **Related:** ADR-021 (the release lane and its fail-closed boundary — **D5's named "likeliest Mac-era fix" is this ADR's subject**), ADR-027 (**D3 parked the `DEVELOPMENT_TEAM` commit question "until the release lane's signing is wired"** — that is now), ADR-006 (iOS-first), ADR-020 (store identity — the metadata `deliver` this lane also runs), ADR-022 (the refusal to assert what CI cannot see), `docs/architecture.md` §9, operator-expected item 4

## Context

At **2026-07-25T23:36Z** the founder created `ASC_KEY_ID`, `ASC_ISSUER_ID` and `ASC_API_KEY_P8` in the GitHub **`release` environment**. Verified this session: `gh api repos/:owner/:repo/environments/release/secrets` → `total_count: 3` (Session 040 read `0` at its close, five hours earlier).

Consequence: `release.yml`'s `sign-upload` job will pass its fail-closed secrets gate **for the first time in this project's history**, and `bundle exec fastlane ios beta` will actually execute.

**It will fail at the archive.** `app/ios/Runner.xcodeproj/project.pbxproj` carries **no `DEVELOPMENT_TEAM`** — the string does not occur anywhere in the file — on any of the Runner target's three build configurations (Debug `97C147061CF9000F007C117D`, Release `97C147071CF9000F007C117D`, Profile `249021D4217E4FDB00AE95B9`). Automatic signing with no team is the canonical `xcodebuild` error *"Signing for 'Runner' requires a development team. Select a development team in the Signing & Capabilities editor."*

This is not a surprise, and that is the point. It is:

- the **exact** failure ADR-021 D5 named a session in advance — *"the first real tag run after enrollment may need a Mac-era fix (likeliest candidate: the automatic-signing `DEVELOPMENT_TEAM` build setting, which no secret currently carries)"*; and
- the **exact** decision ADR-027 D3 parked — *"`DEVELOPMENT_TEAM = UH7MXG7Z94` remains a local-only working-tree edit (not committed) … whether to commit it is revisited when the release lane's signing is wired (ADR-021, release.yml note)."*

That revisit is this ADR. Two prior predictions coming true on schedule is the cheapest possible way to arrive at a decision, and neither is re-litigated here — only resolved.

## Decision 1 — `DEVELOPMENT_TEAM = UH7MXG7Z94` is **committed**, to all three Runner build configs

A Team ID is an **identifier, not a credential**. Four independent reasons, each verified rather than asserted:

1. **This repo already commits it, four times.** `docs/adr/027-bundle-id-rename-hayati-app-squatted.md`, `docs/adr/README.md`, `docs/operator-expected.md` and `docs/past-prompts.md` all print `UH7MXG7Z94` in plain text today (`grep -rn UH7MXG7Z94`). Refusing to write the same string into `project.pbxproj` on secrecy grounds would be incoherent with what the repo already publishes — **and the repo is public** (`gh repo view` → `PUBLIC`). The string is already on the internet, published by this project, on purpose.
2. **Apple publishes it in every artifact the team ships.** The Team ID is the `AppIdentifierPrefix` / `com.apple.developer.team-identifier` inside the embedded provisioning profile of every distributed IPA, and this same team already ships `com.beyondkaira.ballast` on the App Store. It is not a secret that leaks; it is a public fact about a published app.
3. **It grants nothing.** Signing requires a private key — the `.p8` (a GitHub environment secret) or a certificate's private key. The Team ID is the *subject* of an authorization decision, never the authorization. An attacker holding it holds nothing they can sign, upload, or read with.
4. **Withholding it costs a new operator dependency.** Keeping it out of the repo means a **fourth secret** (`APPLE_TEAM_ID`) the founder must create — re-blocking a lane they just unblocked, in order to hide a string the repo already prints four times. That trade is strictly negative in both directions.

**Scope of the posture change — deliberately narrow.** `architecture.md` §9's invariant is **"zero keys in repo"** and it is *untouched*: no key, certificate, `.p8`, password or token moves into the repo, now or by this precedent. What narrows is a **comment block in `fastlane/Appfile`**, which grouped `team_id` with `apple_id` and `itc_team_id` under a single *"do NOT commit values"*. That grouping was over-broad, and the three are not equivalent:

| Identifier | What it is | Committable? |
|---|---|---|
| `apple_id` | the founder's **email address** | **No** — PII, and a phishing / credential-stuffing target |
| `itc_team_id` | an internal App Store Connect numeric id | **No** — no public artifact carries it; no reason to |
| `team_id` (`DEVELOPMENT_TEAM`) | the Developer-portal Team ID | **Yes** — published in every shipped IPA; already in four repo docs |

All three nevertheless stay commented out in the `Appfile`, because **App Store Connect API-key auth needs none of them** (the key is team-scoped). Nothing is added to the `Appfile`; only its comment is corrected to say *why* the three are not equivalent, so the next reader does not re-derive an over-broad rule from a stale line.

**Why all three configs, not only Release.** This is what Xcode itself writes when a team is selected in the Signing & Capabilities pane. `flutter build ipa --release` reads **Release**; `--profile` reads **Profile**; the founder's cable-install rig (operator-expected appendix) reads **Debug**. A team present in one config and absent in the other two is a trap that fires on whichever path is used next. `--no-codesign` builds — `ci.yml`'s `ios-build-smoke` runs `flutter build ios --no-codesign --debug` — pass `CODE_SIGNING_ALLOWED=NO`, so the setting is inert there and cannot regress that job.

**`RunnerTests` is deliberately left alone.** It builds for the simulator only, needs no signing, and `flutter build ipa` never builds it. Adding a team there would be noise that the Decision-3 sentinel would then have to tolerate.

## Decision 2 — `CODE_SIGN_STYLE = Automatic` is written **explicitly**, though the default already is Automatic

Absent the key, `CODE_SIGN_STYLE` defaults to Automatic and the archive would sign fine. This line is therefore **not needed to make the build pass** — it is written because the entire signing mechanism of ADR-021 D5 rests on automatic (cloud) signing:

> `flutter build ipa` passes `-allowProvisioningUpdates` to both archive and export unconditionally, and `xcodebuild` auto-discovers the API key at `~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8`.

Under **manual** signing that whole mechanism is inert: `-allowProvisioningUpdates` does nothing, the API key is never consulted for provisioning, and the lane would need a profile and certificate delivered from somewhere that does not exist. So **a one-word flip of this setting silently invalidates ADR-021 D5** — and both Xcode's "Fix Issues" flow and a single click in the Signing & Capabilities pane are one step from writing `CODE_SIGN_STYLE = Manual` into this file, on the founder's Mac, with no red anywhere.

A default that a guarantee depends on should be **written where a test can read it**. Decision 3 is that test. This is the same reasoning ADR-023 used for the three-way legal-version source-sentinel and ADR-022 for the pre-frame await set: an invariant that lives only in a default is an invariant nothing defends.

Two deliberate non-changes:

- **The legacy `TargetAttributes.ProvisioningStyle` key is NOT added.** The build-config-level `CODE_SIGN_STYLE` supersedes it; two sources for one fact is precisely the drift this repo keeps paying for (ADR-024 D1's four-copy notifier, ADR-025's `MASTER.md`).
- **`CODE_SIGN_IDENTITY[sdk=iphoneos*] = "iPhone Developer"` is left as-is.** It is the stock Flutter template value, present at project level in all three configs. With automatic signing the archive resolves it against the profile xcodebuild fetches, and `flutter build ipa`'s **export** step re-signs for distribution from the export-options `method`. Changing it is not required, not proven necessary, and would be a blind edit to a signing path from a Linux box with no Mac — exactly what ADR-021 D5's honesty bound forbids.

## Decision 3 — the signing settings get a source-sentinel test, in the mold this repo already uses

New: `app/test/release/signing_sentinel_test.dart`, reading `ios/Runner.xcodeproj/project.pbxproj`.

**Why a test rather than a comment.** Nothing in the per-PR merge gate can see a signing regression:

- `flutter analyze` and `flutter test` never read the pbxproj.
- `ci.yml`'s `ios-build-smoke` builds with `--no-codesign` — it compiles the Swift, but signing is *disabled*, so it is structurally incapable of noticing that signing is broken.
- `release.yml` runs only on a `v*.*.*` tag or a manual dispatch.

So between two releases, a signing setting can be deleted by one Xcode click and **every required check stays green**. The failure would surface as a red release lane, weeks later, on the day someone wants to ship — the worst possible moment to discover it. That is the identical argument `device_privacy_channel_parity_test.dart` makes for the platform channel, and this ADR reuses its mold on purpose, including its count-based assertion shape (*"must be declared in all THREE build configs — a missing one ships a build where the discreet icon does not exist"*).

**What it asserts** — identifying the app target by *what it is* (its bundle id) rather than by a UUID that Xcode could regenerate:

1. Exactly **3** `XCBuildConfiguration` blocks carry `PRODUCT_BUNDLE_IDENTIFIER = com.beyondkaira.hayati;` (the app target's Debug/Release/Profile), and exactly **3** carry `…hayati.RunnerTests;`.
2. **Every** app-target block carries `DEVELOPMENT_TEAM = UH7MXG7Z94;`.
3. **Every** app-target block carries `CODE_SIGN_STYLE = Automatic;`.
4. `CODE_SIGN_STYLE = Manual` occurs **nowhere** in the file, and no block carries a `DEVELOPMENT_TEAM` value other than `UH7MXG7Z94`.
5. `com.hayati.app` occurs **nowhere** in the file — the ADR-027 rename, which on the iOS project side is currently asserted by nothing at all.

**Mutation matrix (the deliverable, per the standing addendum — both directions of every drift axis):** team deleted from one config / from all three; team value corrupted; `CODE_SIGN_STYLE` flipped to `Manual` in one config; `CODE_SIGN_STYLE` deleted; a bundle id reverted to `com.hayati.app`; a Runner config block deleted; a `DEVELOPMENT_TEAM` added to a *non*-app target (must NOT red — the test scopes to the app target by design, and a vacuous scope would read identically to a real one).

**Bound, recorded:** the sentinel proves the settings are present and correctly valued. It **cannot** prove Apple accepts them — only the lane run does, and its verdict rides operator item 4.

## Decision 4 — the first run's known risk is **recorded, not pre-solved**: fresh-runner distribution certificates

Every `sign-upload` run gets a **clean macOS keychain**. `xcodebuild -allowProvisioningUpdates` with an ASC API key, finding no Apple Distribution certificate, is expected to **create one** — and Apple caps Apple Distribution certificates at **3 per account**. A lane that mints a fresh certificate every run therefore exhausts the cap in about three releases and then fails, with an error about certificate limits that will not obviously point back here.

Deliberately **not** solved this session:

- **It is recoverable.** Certificates are revocable in the Developer portal — unlike a published Play `applicationId` (ADR-027 D2) or Family Sharing (ADR-015), this is not a one-way door.
- **The fix is a real design, not a flag.** fastlane `match` with a private certificate repo, or importing a certificate + private key from new secrets, introduces **new private-key custody** into a repo whose stated invariant is "zero keys in repo". That deserves its own ADR, not a guess bolted onto a lane that has never run once.
- **Whether it even happens is observable on the first run and unknowable from Linux.** This project does not assert what it has not seen — ADR-021 D5's honesty bound and ADR-022's refusal of the fake CI cold-start assertion are the same principle. The first run's log decides.

Filed as an issue at close with the **expected symptom named**, so the next session recognises it instead of re-deriving it.

## Decision 5 — three stale claims about **ADR-027's own diff** are corrected in this diff

Verified this session, two independent ways:

- **Live:** both Firebase projects carry a **`Hayati iOS (beyondkaira)`** app whose `apps:sdkconfig` reports `BUNDLE_ID = com.beyondkaira.hayati` — dev `1:870954957461:ios:98d074e9af5ced5c17f99c`, prod `1:419979715508:ios:c8c0e5c1fdfadf9d64c8e1`. Every value in `firebase_options_{dev,prod}.dart` (`appId`, `apiKey`, `iosBundleId`), `google_sign_in_config.dart` (both iOS client ids) and the Info.plist `CFBundleURLSchemes` (both `REVERSED_CLIENT_ID`s) matches those configs **byte-for-byte**.
- **Historical:** `git show ce80908` shows the iOS `appId` and `iosBundleId` changing to the new values, plus `google_sign_in_config.dart`, `Info.plist` and `firebase_bootstrap_test.dart`, **inside ADR-027's own commit**.

So ADR-027's "Phase 2" **landed inside ADR-027's own merge**. Three surfaces still claim otherwise, and a stale claim is worse than no claim (standing addendum 10: *an ADR's promises about its own diff are guarantee surfaces*):

1. **ADR-027 D3** — *"Until that Phase 2 lands, those files knowingly retain `com.hayati.app`"* was false as of its own merge. Amended with a dated rev note. The two-phase *reasoning* is kept, because it is why the change was safe; only the outcome is stated.
2. **`docs/adr/README.md`**'s ADR-027 row repeats the same pending framing — corrected.
3. **`firebase_options_dev.dart` and `firebase_options_prod.dart`** both credit the change to **"(ADR-026)"** — which is *seasonal question windows*, an unrelated document. A comment naming the wrong ADR sends the next reader to the wrong place; this project has already recorded that exact class (S039's four Dart comments naming a retired API — addendum 15, *"a comment that names a retired API misleads the next reader of a security path"*, and *"the rule you just invoked applies to you"*). Both comments also describe the change as *"hand-updated"* where D3 specified regeneration; the **values are correct either way** (verified above), so what is corrected is the ADR pointer and the stale expectation — not the values, and not a claim about which command S037 ran.

## Decision 6 — `architecture.md` §9's "this private repo" is a factual error and is corrected; the cost decisions it motivated are **not** reopened

§9 justifies two cost decisions with *"macOS minutes bill at 10× on this **private** repo (~100–140 billed minutes per run)"*. `gh repo view` reports **`PUBLIC`**, and GitHub-hosted **standard runners — macOS included — are free for public repositories**.

The claim is load-bearing in reasoning a future session inherits, and it is the reason *this* session can run the first release lane without a spend decision, so it is corrected. The **decisions** are deliberately left standing: `integration-emulator` main-only and the cheap ubuntu `preflight` ahead of the macOS legs are still defensible on **latency and queue time** (macOS runners queue far longer than ubuntu), and re-litigating a cost posture is not this session's objective. Filed as an issue instead: *whether any of §9's cost-motivated gates should be relaxed now that the minutes are free.*

## Consequences

**Positive:**

- The single setting standing between "the founder added three secrets" and "a signed build reaches their phone" is removed, and the removal is **defended by a test** rather than by the memory of the session that made it.
- The `com.beyondkaira.hayati` rename gains its **first iOS-project-side assertion**. ADR-027's rename was previously protected on the Dart side (`firebase_bootstrap_test.dart`) and nowhere on the Xcode side.
- Two long-standing predictions (ADR-021 D5, ADR-027 D3) are **closed by outcome** rather than left as open parentheses in old documents.
- Three stale claims and one factual error leave the docs, none of which a build would ever have caught.

**Negative / accepted trade-offs:**

- **A Team ID is now committed.** Judged an identifier, not a credential, on four verified grounds — but it is a genuine narrowing of the `Appfile`'s comment posture and is recorded as such so the founder can reverse it (the reversal costs one secret and one workflow step).
- **The distribution-certificate cap (Decision 4) is a known, unresolved risk** shipping into the first run. Accepted: recoverable, observable, and cheaper to see than to guess.
- **The sentinel pins a specific team id**, so a founder who changes Apple teams must update the test with the pbxproj. That is the intended cost of a source-sentinel; the alternative (assert *a* team exists) would pass with a wrong team, which is the failure that actually happens.
- The first lane run may still fail for a reason this ADR did not predict. Accepted, and by ADR-021 D4's design the failure will be **loud and attributed** rather than a silent green.

## Acceptance

1. `grep -c 'DEVELOPMENT_TEAM = UH7MXG7Z94;' app/ios/Runner.xcodeproj/project.pbxproj` → `3`.
2. `flutter test test/release/signing_sentinel_test.dart` green; the full app suite green; coverage gate ≥ 68; `flutter analyze` clean; `dart format` clean.
3. The mutation matrix in Decision 3 executed and recorded — every mutant killed, and the one deliberate non-firing case (a team on a non-app target) confirmed non-firing.
4. `release.yml` dispatched on `main` and its outcome **read and recorded**, whatever it is. A red that names a missing Apple-side prerequisite is a successful session outcome (it converts an unknown into a named operator step); a green that puts a build in TestFlight is the M6 accept line's signing half, proven.
