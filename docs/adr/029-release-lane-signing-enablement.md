# ADR-029: Release-lane signing enablement — the committed `DEVELOPMENT_TEAM`, explicitly-pinned automatic signing, and a signing source-sentinel

- **Status:** Accepted (**rev 2** — six pre-code review findings applied; see the review record at the end). **D2's RATIONALE amended and D4 closed by [ADR-032](032-release-signing-on-fastlane-match.md):** the `CODE_SIGN_STYLE = Automatic` pin stands, but it no longer defends ADR-021 D5's cloud signing — the lane now writes `Manual` into the checked-out pbxproj on purpose every run, so what the committed value protects is the dev box and the cable rig. D4's fresh-runner certificate-cap risk (issue #99) is **closed**: `match` runs readonly and CI cannot mint a certificate.
- **Date:** 2026-07-26 (Session 041)
- **Numbering note:** drafted as ADR-028 and renumbered to **029** on discovery that the concurrent session's open PR #95 (the M5.3 live coach adapter) had already claimed 028 four hours earlier. Per the S038 addendum, ordinals collide across trees; the earlier-created number wins.
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

1. **This repo already commits it, in four prior documents.** `docs/adr/027-bundle-id-rename-hayati-app-squatted.md`, `docs/adr/README.md`, `docs/operator-expected.md` and `docs/past-prompts.md` all print `UH7MXG7Z94` in plain text (`grep -rln UH7MXG7Z94`, run before this ADR existed). Refusing to write the same string into `project.pbxproj` on secrecy grounds would be incoherent with what the repo already publishes — **and the repo is public** (`gh repo view` → `PUBLIC`). The string is already on the internet, published by this project, on purpose. *(Rev 2, review finding F5: the count is stated as "four prior documents" deliberately. "Four times" was self-falsifying — the moment this ADR is committed the grep returns five, and citing this document as evidence that the string was already committed would be circular.)*
2. **Apple publishes it in every artifact the team ships.** The Team ID is the `AppIdentifierPrefix` / `com.apple.developer.team-identifier` inside the embedded provisioning profile of every distributed IPA, and this same team already ships `com.beyondkaira.ballast` on the App Store. It is not a secret that leaks; it is a public fact about a published app.
3. **It grants nothing.** Signing requires a private key — the `.p8` (a GitHub environment secret) or a certificate's private key. The Team ID is the *subject* of an authorization decision, never the authorization. An attacker holding it holds nothing they can sign, upload, or read with.
4. **Withholding it costs a new operator dependency.** Keeping it out of the repo means a **fourth secret** (`APPLE_TEAM_ID`) the founder must create — re-blocking a lane they just unblocked, in order to hide a string the repo already prints four times. That trade is strictly negative in both directions.

**Scope of the posture change — deliberately narrow.** `architecture.md` §9's invariant is **"zero keys in repo"** and it is *untouched*: no key, certificate, `.p8`, password or token moves into the repo, now or by this precedent. What narrows is a **comment block in `fastlane/Appfile`**, which grouped `team_id` with `apple_id` and `itc_team_id` under a single *"do NOT commit values"*. That grouping was over-broad, and the three are not equivalent:

| Identifier | What it is | Committable? |
|---|---|---|
| `apple_id` | the founder's **email address** | **No** — PII, and a phishing / credential-stuffing target |
| `itc_team_id` | an internal App Store Connect numeric id | **No** — no public artifact carries it; no reason to |
| `team_id` (`DEVELOPMENT_TEAM`) | the Developer-portal Team ID | **Yes** — published in every shipped IPA; already in four repo docs |

The `apple_id` and `itc_team_id` stubs **stay commented out** in the `Appfile`, because **App Store Connect API-key auth needs none of them** (the key is team-scoped). The `team_id` stub is **deleted**: its value is now committed where `xcodebuild` actually reads it (`DEVELOPMENT_TEAM` in `project.pbxproj`), so leaving a commented stub behind would read as *still pending*. Nothing is *added*, and the comment is rewritten to say why the three are not equivalent, so the next reader does not re-derive an over-broad rule from a stale line. *(Rev 2, built-diff finding: rev 1 claimed "all three nevertheless stay commented out" and "only its comment is corrected" — both false of the actual diff, which removes one stub. An ADR mis-describing its own diff is the very class this ADR corrects in ADR-027, so it is corrected here rather than explained away.)*

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

So between two releases, a signing setting can be deleted by one Xcode click and **every required check stays green**. The failure would surface as a red release lane, weeks later, on the day someone wants to ship — the worst possible moment to discover it. That is the identical argument `device_privacy_channel_parity_test.dart` makes for the platform channel, and this ADR reuses its **motivation** and its "all THREE build configs" *shape* (*"a missing one ships a build where the discreet icon does not exist"*) — but **deliberately NOT its global-count mechanism.** See the rev-2 note below: for these settings a global count is wrong in both directions.

### Rev 2 (review finding F1, blocking) — the mechanism is **per-block parsing**, never a file-wide count

The mold counts `RegExp(...).allMatches(pbxproj).length == 3`. That is sound **for the mold's own key**: `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES` occurs at lines 398/579/603, all three in Runner app-target blocks and none in `RunnerTests` — so the global count *is* the Runner count.

**`CODE_SIGN_STYLE = Automatic;` is the exact inverse**, and verified in the file today: it occurs at lines 421/438/453 — **all three in `RunnerTests` blocks (`331C8088`/`331C8089`/`331C808A`), and zero times in any Runner block.** A naive `expect(count, 3)` therefore:

- **passes vacuously today**, before the fix exists — it can never be red-first, which strict TDD (project-rules #6) requires;
- **fails on the correctly-fixed file**, where the global count becomes **6**;
- and **passes again** on a post-fix regression that strips the setting from all three Runner blocks, returning the count to 3.

A test that is green when broken, red when correct, and green when re-broken is worse than no test. This is the project's vacuous-guard failure mode (S038 addendum 13) in a new costume, and the mold cannot be followed literally here.

**Prescribed mechanism, binding on the implementation:** split `project.pbxproj` into its `XCBuildConfiguration` blocks, classify each block by the `PRODUCT_BUNDLE_IDENTIFIER` *inside that block*, and assert within the classified sets. Identification is by **what the target is** (its bundle id), never by a UUID Xcode could regenerate. Verified block census of the file today: 9 `XCBuildConfiguration` blocks — 3 app-target (`com.beyondkaira.hayati`: Debug `97C147061…`, Release `97C147071…`, Profile `249021D4…`), 3 `RunnerTests`, 3 project-level with no bundle id.

**What it asserts:**

1. Exactly **3** blocks carry `PRODUCT_BUNDLE_IDENTIFIER = com.beyondkaira.hayati;` and exactly **3** carry `…hayati.RunnerTests;` (a deleted, added or renamed config is a defect, not churn).
2. **Every app-target block** carries `DEVELOPMENT_TEAM = UH7MXG7Z94;`.
3. **Every app-target block** carries `CODE_SIGN_STYLE = Automatic;`.
4. **No app-target block** carries a `DEVELOPMENT_TEAM` other than `UH7MXG7Z94`, and **no app-target block** carries `CODE_SIGN_STYLE = Manual`.
5. `com.hayati.app` occurs **nowhere** in the file — the ADR-027 rename, which on the iOS-project side is asserted by nothing at all today.

Assertions 2–4 are **scoped to app-target blocks** (rev 2, review finding F4). Rev 1 wrote assertion 4 file-wide, which contradicted rev 1's own "must NOT red" mutation case: a team id on a `RunnerTests` block is harmless, but a file-wide "no other team value" check would redden on it. Scoping resolves it, and the scoping is what makes the must-NOT-red case meaningful rather than decorative.

**Mutation matrix (the deliverable, per the standing addendum — both directions of every axis):**

| # | Mutation | Expected |
|---|---|---|
| 1 | `DEVELOPMENT_TEAM` deleted from **one** app-target block | RED |
| 2 | `DEVELOPMENT_TEAM` deleted from **all three** | RED |
| 3 | `DEVELOPMENT_TEAM` value corrupted in one app-target block | RED |
| 4 | `CODE_SIGN_STYLE` flipped to `Manual` in one app-target block | RED |
| 5 | `CODE_SIGN_STYLE` deleted from one app-target block | RED |
| 6 | an app-target `PRODUCT_BUNDLE_IDENTIFIER` reverted to `com.hayati.app` | RED |
| 7 | an entire app-target config block deleted | RED |
| 8 | a **4th** app-target config block added | RED |
| 9 | `DEVELOPMENT_TEAM = UH7MXG7Z94;` added to a **`RunnerTests`** block | **GREEN** — harmless, and the case that proves the scope is real rather than vacuous |
| 10 | `CODE_SIGN_STYLE = Manual` added to a **`RunnerTests`** block | **GREEN** — same reason (RunnerTests signs nothing) |
| 11 | the pbxproj's block **shape** broken so the parser matches nothing | RED — the `setUpAll` census guard fires; without it every scoped assertion would iterate an empty set and pass |

Axes 9 and 10 are the ones that distinguish a genuinely scoped test from a file-wide grep wearing a scope's clothing; a file-wide implementation passes 1–8 and fails 9–10 identically to a correct one on the first eight. Axis 11 guards the *scope itself*: a per-block test whose parser silently matches nothing is the most complete vacuity available to it, so the census assertion is part of the guard, not decoration. *(Rev 2, built-diff finding: rev 1 listed ten rows here while `test-suite.md` and the ADR index both said eleven — the eleventh was executed but never written into the table it belonged in.)*

**Bound, recorded:** the sentinel proves the settings are present and correctly valued. It **cannot** prove Apple accepts them — only the lane run does, and its verdict rides operator item 4.

**Where it is recorded (rev 2, review finding F6).** `docs/test-suite.md` is this repo's authoritative inventory of sentinels-with-mutation-matrices (**§4 Policies** names the lock-screen forbidden-API sentinel, the brandkit token-parity test and the frozen-sentence digest; **§2 CI validation** names ADR-022's entrypoint await-set sentinel — §2 is the right home for this one because its whole argument is about which CI job can and cannot see the regression). *(Rev 2, built-diff finding: rev 1 said §1 for the three sentinels; they are in §4.)* A new sentinel that is recorded only in its own ADR is a guard a future session will not know to keep — so §2 gains an entry naming the file, the per-block scoping mechanism (**not** a global count, and why), and the eleven-row matrix. project-rules #8: docs-with-code, same commit.

## Decision 4 — the first run's known risk is **recorded, not pre-solved**: fresh-runner distribution certificates

Every `sign-upload` run gets a **clean macOS keychain**. `xcodebuild -allowProvisioningUpdates` with an ASC API key, finding no Apple Distribution certificate, is expected to **create one** — and Apple caps Apple Distribution certificates at **3 per account**. A lane that mints a fresh certificate every run therefore exhausts the cap in about three releases and then fails, with an error about certificate limits that will not obviously point back here.

Deliberately **not** solved this session:

- **It is recoverable.** Certificates are revocable in the Developer portal — unlike a published Play `applicationId` (ADR-027 D2) or Family Sharing (ADR-015), this is not a one-way door.
- **The fix is a real design, not a flag.** fastlane `match` with a private certificate repo, or importing a certificate + private key from new secrets, introduces **new private-key custody** into a repo whose stated invariant is "zero keys in repo". That deserves its own ADR, not a guess bolted onto a lane that has never run once.
- **Whether it even happens is observable on the first run and unknowable from Linux.** This project does not assert what it has not seen — ADR-021 D5's honesty bound and ADR-022's refusal of the fake CI cold-start assertion are the same principle. The first run's log decides.

Filed as **issue #99** with the expected symptom named (*one* new Apple Distribution certificate after the first run is expected and fine; a *second* after the second run is the bug), so the next session recognises it instead of re-deriving it.

## Decision 5 — three stale claims about **ADR-027's own diff** are corrected in this diff

Verified this session, two independent ways:

- **Live:** both Firebase projects carry a **`Hayati iOS (beyondkaira)`** app whose `apps:sdkconfig` reports `BUNDLE_ID = com.beyondkaira.hayati` — dev `1:870954957461:ios:98d074e9af5ced5c17f99c`, prod `1:419979715508:ios:c8c0e5c1fdfadf9d64c8e1`. Every value in `firebase_options_{dev,prod}.dart` (`appId`, `apiKey`, `iosBundleId`), `google_sign_in_config.dart` (both iOS client ids) and the Info.plist `CFBundleURLSchemes` (both `REVERSED_CLIENT_ID`s) matches those configs **byte-for-byte**.
- **Historical:** `git show ce80908` shows the iOS `appId` and `iosBundleId` changing to the new values, plus `google_sign_in_config.dart`, `Info.plist` and `firebase_bootstrap_test.dart`, **inside ADR-027's own commit**.

So ADR-027's "Phase 2" **landed inside ADR-027's own merge**. **Four** surfaces still claim otherwise, and a stale claim is worse than no claim (standing addendum 10: *an ADR's promises about its own diff are guarantee surfaces*):

1. **ADR-027 D3** — *"Until that Phase 2 lands, those files knowingly retain `com.hayati.app`"* was false as of its own merge. Amended with a dated rev note. The two-phase *reasoning* is kept, because it is why the change was safe; only the outcome is stated.
2. **`docs/adr/README.md`**'s ADR-027 row repeats the same pending framing — corrected.
3. **`firebase_options_dev.dart` and `firebase_options_prod.dart`** both credit the change to **"(ADR-026)"** — which is *seasonal question windows*, an unrelated document. A comment naming the wrong ADR sends the next reader to the wrong place; this project has already recorded that exact class (S039's four Dart comments naming a retired API — addendum 15, *"a comment that names a retired API misleads the next reader of a security path"*, and *"the rule you just invoked applies to you"*). Both comments also describe the change as *"hand-updated"* where D3 specified regeneration; the **values are correct either way** (verified above), so what is corrected is the ADR pointer and the stale expectation — not the values, and not a claim about which command S037 ran.
4. **`docs/operator-expected.md` lines 40–42** (rev 2, review finding F3) — the Session 037 callout still reads *"the only added work is two Firebase iOS-app registrations + a Dart config regen (a session does the code half)"*. **Both halves are done**: the founder registered the two iOS apps (verified live), and the Dart regen landed in `ce80908`. This is the **worst** of the four to leave stale, because it is the canonical founder checklist — the one document the founder reads instead of the session log — and it asks them for work that is already finished. Rev 1 found three surfaces and applied the "a stale claim is worse than no claim" principle to them while leaving a fourth standing in the founder-facing file; that is the *"the rule you just invoked applies to you"* addendum firing on this ADR, caught by the review rather than by a reader.

`docs/past-prompts.md` was checked for the same drift and is **correct** — the Session 037-B entry already records *"Both phases are in"*. It needs no change, and is cited here so a later session does not re-audit it.

## Decision 6 — `architecture.md` §9's "this private repo" is a factual error and is corrected; the cost decisions it motivated are **not** reopened

§9 justifies two cost decisions with *"macOS minutes bill at 10× on this **private** repo (~100–140 billed minutes per run)"*. `gh repo view` reports **`PUBLIC`**, and GitHub-hosted **standard runners — macOS included — are free for public repositories**.

The claim is load-bearing in reasoning a future session inherits, and it is the reason *this* session can run the first release lane without a spend decision, so it is corrected. The **decisions** are deliberately left standing: `integration-emulator` main-only and the cheap ubuntu `preflight` ahead of the macOS legs are still defensible on **latency and queue time** (macOS runners queue far longer than ubuntu), and re-litigating a cost posture is not this session's objective. Filed as **issue #100** instead: *whether any of §9's cost-motivated gates should be relaxed now that the minutes are free* — including the observation that relaxing `integration-emulator` to per-PR would make part of ADR-024 D8's fragility moot, and the warning that the corrected §9 sentence becomes wrong again if the repo is ever made private.

## Consequences

**Positive:**

- The single **uncommitted project setting** that blocked the archive and export steps is removed, and the removal is **defended by a test** rather than by the memory of the session that made it.

  *Rev 2, review finding F2 — the scoping in that sentence is load-bearing and rev 1 got it wrong.* Rev 1 claimed this was "the single setting standing between 'the founder added three secrets' and 'a signed build reaches their phone'". That is **false**, and falsely reassuring in the founder-facing direction: `fastlane/Fastfile` calls `upload_to_testflight(ipa:)` with no `app_identifier` override, so `pilot` resolves the app by the `Appfile`'s bundle id and **hard-fails with "No app found with bundle identifier com.beyondkaira.hayati"** if the **App Store Connect app record does not exist** — which is operator roadmap **Step 2**, and nothing in this ADR checks for it. `deliver` in the `store_metadata` lane needs the same record. So the honest statement is: this ADR removes the last *repo-side* blocker to a signed archive; whether a build reaches TestFlight additionally depends on an **operator-owned** prerequisite this session cannot verify from Linux (no ASC credential is readable here). The first lane run resolves it either way — a green upload proves the record exists, and a `pilot` "No app found" proves it does not and names the exact operator step. That is a guarantee-vs-mechanism gap the review caught before the founder could read the ADR and conclude the lane was ready.
- The `com.beyondkaira.hayati` rename gains its **first iOS-project-side assertion**. ADR-027's rename was previously protected on the Dart side (`firebase_bootstrap_test.dart`) and nowhere on the Xcode side.
- Two long-standing predictions (ADR-021 D5, ADR-027 D3) are **closed by outcome** rather than left as open parentheses in old documents.
- **Four** stale claims and one factual error leave the docs, none of which a build would ever have caught — including one sitting in the founder-facing checklist asking for work already done.

**Negative / accepted trade-offs:**

- **A Team ID is now committed.** Judged an identifier, not a credential, on four verified grounds — but it is a genuine narrowing of the `Appfile`'s comment posture and is recorded as such so the founder can reverse it (the reversal costs one secret and one workflow step).
- **The distribution-certificate cap (Decision 4) is a known, unresolved risk** shipping into the first run. Accepted: recoverable, observable, and cheaper to see than to guess.
- **The sentinel pins a specific team id**, so a founder who changes Apple teams must update the test with the pbxproj. That is the intended cost of a source-sentinel; the alternative (assert *a* team exists) would pass with a wrong team, which is the failure that actually happens.
- The first lane run may still fail for a reason this ADR did not predict. Accepted, and by ADR-021 D4's design the failure will be **loud and attributed** rather than a silent green.

## Acceptance

1. `grep -c 'DEVELOPMENT_TEAM = UH7MXG7Z94;' app/ios/Runner.xcodeproj/project.pbxproj` → `3`.
2. `flutter test test/release/signing_sentinel_test.dart` green; the full app suite green; coverage gate ≥ 68; `flutter analyze` clean; `dart format` clean.
3. The **eleven-row** mutation matrix in Decision 3 executed and recorded: mutants 1–8 and 11 each kill the test, and mutants **9–10 leave it GREEN** — the two rows that prove the scoping is real. A run where 9 and 10 also redden means the test is a file-wide grep and the scope is decorative.
4. `release.yml` dispatched on `main` and its outcome **read and recorded**, whatever it is. A red that names a missing Apple-side prerequisite is a successful session outcome (it converts an unknown into a named operator step); a green that puts a build in TestFlight is the M6 accept line's signing half, proven.
5. All four stale surfaces from Decision 5 corrected in this diff, and `grep -rn 'ADR-026' app/lib/core/firebase/` returns nothing (the misattribution is gone, not merely described as gone — standing addendum 10).

## Pre-code adversarial review record (Session 041 — twenty-fourth consecutive pass with real findings)

4 lenses (over-claim/honesty, Apple & release-engineering domain, governing-docs consistency, test-integrity/mutation-soundness) × 2 independent verifiers (a refuting skeptic + a governing-docs adjudicator), aggregated so a finding surfaces when **either** verifier says real (S030 addendum). **6 raw findings, 6 deduped, 5 verified (1 minor deferred by the verification cap and hand-adjudicated), ZERO refuted.** All six applied above:

- **F1 (blocking, test-integrity — both verifiers CONFIRMED).** The mold's global-count mechanism would have produced a test that is **green when broken, red when correct, and green when re-broken**, because `CODE_SIGN_STYLE = Automatic` already occurs 3× in `RunnerTests` and 0× in Runner — the exact inverse of the mold's own key. Decision 3 now prescribes per-block parsing and explains why the mold cannot be followed literally. *This is the single most valuable finding of the pass: rev 1 would have shipped a vacuous guard while citing the project's own anti-vacuity addendum.*
- **F2 (serious, Apple/release-eng — both CONFIRMED).** The Consequences over-claimed an end-to-end guarantee ("a signed build reaches their phone") that `upload_to_testflight` cannot honour without an operator-owned App Store Connect app record. Scoped honestly; the operator prerequisite is named.
- **F3 (serious, governing-docs — both CONFIRMED).** Decision 5 corrected three stale Phase-2 surfaces and **left a fourth standing in `operator-expected.md`** — the founder-facing one. Now four.
- **F4 (serious, test-integrity — SPLIT: skeptic REFUTED, adjudicator CONFIRMED).** The valuable split. The skeptic was right that a careful reader of rev 1's *assertion text* would infer per-block scoping and the contradiction would dissolve; the adjudicator was right that rev 1's file-wide assertion 4 still reddened on the "must NOT red" mutation, so the matrix contradicted the assertions as written. Both are correct about different halves — assertions 2–4 are now explicitly scoped, and the matrix gained a second must-stay-green row.
- **F5 (minor, over-claim — both CONFIRMED).** "Four times" was self-falsifying the moment this ADR was committed. Reworded to "four prior documents" rather than "five", because citing this document as evidence that the string was already committed is circular.
- **F6 (minor, governing-docs — deferred by the cap, hand-adjudicated CONFIRMED).** A sentinel recorded only in its own ADR is a guard the next session will not know to keep; `test-suite.md` §2 gains the entry.

Not raised by any lens and worth recording as **checked**: `app/ios/Flutter/{Debug,Release}.xcconfig` contain only `#include "Generated.xcconfig"` and carry no signing settings, so the pbxproj is the sole source for these values and no xcconfig can shadow them.

## Post-implementation review record (same session, over the built diff — the review-twice rule, and it earned itself again)

Same 4-lens shape (test-integrity, ADR-self-claims, release-engineering, docs-consistency) over `git diff main...HEAD`. **9 raw findings, 7 distinct after dedup, all 7 REAL on inspection.**

**Verification honesty, recorded rather than glossed:** the verify phase's **ten agents all died on an API session limit**, so the workflow returned an empty `surfaced` list and everything landed in its `refuted` bucket. **That is an artifact, not a refutation** — an empty verdict is *unverified*, and reading it as "nothing real" would have discarded seven true findings. Each was therefore hand-adjudicated by direct inspection (every claim below was confirmed with a grep or a file read before it was applied). Recorded because the next session will hit the same trap: **a review whose verifiers died is a review with no verdict, and the tooling's default rendering says the opposite.**

Findings, all fixed pre-merge:

- **G1 (serious, docs-consistency) — the half-correction, and the third time this session that "the rule you just invoked applies to you" fired.** D6 corrected §9's false *"10× billed on this private repo"* premise in exactly one sentence and left the identical claim standing in **six `ci.yml` comments** (one of which says *"on private repos"* outright), a second clause of the **same architecture.md paragraph**, `test-suite.md` §2, `release.yml`'s `preflight` comment, and two other ADRs. A false premise corrected in one place and left in nine is worse than one corrected nowhere, because it now looks handled. Swept: every live surface reframed on latency, the two ADRs given dated rev notes, `past-prompts.md` deliberately untouched (project-rules #2 — prior entries are immutable history, and history is allowed to record what was believed then).
- **G2 (serious, docs-consistency) — `operator-expected.md` still told the founder the `ASC_*` secrets were missing**, in three places: the TL;DR row (*"still absent"*), the item-4 heading, and *"verified at Session 038's close, the `release` environment still holds **zero** secrets."* All false since 23:36Z, in the one file the founder reads instead of the session log — the exact defect D5 had just corrected elsewhere in the same document. Corrected with the real timestamp, plus what genuinely does remain for them (the App Store Connect app record) and the issue-#99 symptom to watch.
- **G3 (serious, ADR-self-claims) — D1 mis-described its own diff.** It said *"All three nevertheless stay commented out in the `Appfile`"* and *"Nothing is added to the `Appfile`; only its comment is corrected"*. The diff **deletes** the `# team_id("...")` stub, and the new `Appfile` header said *"All three stay COMMENTED"* above only two stubs. Both corrected, and the deletion is now justified rather than merely described (a commented stub for a value that is committed elsewhere reads as *still pending*).
- **G4 (serious, test-integrity) — the matrix count contradicted itself inside one commit.** D3's table listed ten rows and the acceptance criterion said "ten-row", while `test-suite.md` and the ADR index both said **eleven** — the eleventh (parser-integrity) mutant was *executed* but never written into the table it belonged to. Row 11 added; both counts corrected.
- **G5 (minor, test-integrity) — the parser census was a lower bound.** `greaterThanOrEqualTo(9)` catches an *under*-matching parser but lets an **over**-matching one through, and over-matching is a real regex failure mode. Tightened to exactly **9** (3 project-level + 3 RunnerTests + 3 app-target) with a reason that tells a future maintainer to update the census *with* the pbxproj rather than relax it. **The whole eleven-row matrix was re-run after this change** — changing a guard invalidates the matrix that proved it, and re-running is not optional: 11/11 again, pbxproj byte-identical to the pre-mutation backup.
- **G6 (minor, docs-consistency) — `fastlane/README.md` still carried the prediction this ADR discharges** (*"the first real tag run … may need a Mac-era fix (likeliest: an automatic-signing `DEVELOPMENT_TEAM` build setting no secret currently carries)"*). Updated to say the prediction came true and was resolved, and — more usefully — to enumerate what is *still* unverified from Linux (Apple accepting the signature, the app record, issue #99).
- **G7 (minor, docs-consistency) — a factual error in this ADR's own reasoning:** F6 justified placing the sentinel entry in `test-suite.md` §2 by citing "§1 names the lock-screen forbidden-API sentinel, the brandkit token-parity test and the frozen-sentence digest". Those three are in **§4 Policies**. Corrected, and the §2 choice is now argued on its merits (this sentinel's whole point is *which CI job can and cannot see the regression*, which is §2's subject).

**Pattern worth carrying forward.** Four of the seven (G1–G4) are the same species: **a document making a claim about its own diff, or about a premise it just corrected, that the diff does not support.** Two passes in one session both found it, in different files, on different claims. The pre-code pass caught three surfaces and left a fourth; the built-diff pass caught the fourth *and* a correction that had been applied in one place out of ten. The lesson is narrower and more actionable than "review twice": **when a diff corrects a claim, grep the whole repo for that claim before declaring it corrected** — the same discipline S039's addendum 15 recorded for principles, applied to facts.
