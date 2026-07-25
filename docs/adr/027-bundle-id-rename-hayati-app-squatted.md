# ADR-027: iOS bundle-id rename — `com.hayati.app` → `com.beyondkaira.hayati` (the working-title id was squatted on Apple); Android id decision stays deferred to M6.5

- **Status:** Accepted
- **Date:** 2026-07-25 (Session 037)
- **Deciders:** session agent + founder (the founder confirmed `UH7MXG7Z94` is their only Apple Developer account and chose the rename over pursuing the squatted id)
- **Related:** ADR-001 (Flutter scaffold, where `com.hayati.app` was set as the working-title id), ADR-006 (iOS-first release sequencing — the Android deferral this ADR leans on), ADR-008 (Apple sign-in via the credential seam — a paid-team capability the rename restores access to), ADR-020 (store identity — the *name* "Hayati" is separately provisional; the bundle id is not user-facing), operator-expected items 0/3/4 and the Session 037 note there

## Context

`com.hayati.app` was the working-title bundle id from the scaffold (Session 001), deliberately flagged renameable (`android/app/build.gradle.kts` comment; `frontend-brandkit.md` §1 trademark caveat). It was pinned in the Xcode project and `fastlane/Appfile`, and Session 004 (issue #5) registered it as the iOS **and** Android app on both real Firebase projects (`hayatiapp-dev`, `hayatiapp-prod`).

During the first physical-device install (2026-07-22), Apple's Developer portal **refused to register `com.hayati.app`** to team `UH7MXG7Z94` — *"cannot be registered to your development team because it is not available"* — i.e. **another Apple team already owns it**. This is the same squatting pattern already recorded for the `hayati-dev` GCP project id (past-prompts, issue #5 cleanup notes). Session 037 confirmed with the founder that `UH7MXG7Z94` (AYTEKIN ERDOGAN, Individual, paid) is their **only** Apple Developer account, so the id is not merely under a second login — it is a third-party squat and is unrecoverable without a purchase/dispute the founder does not want to pursue.

The id blocks the entire Apple path: App ID registration (roadmap Step 1), the App Store Connect record (Step 2), the Sign-in-with-Apple capability, and real-device Google/Apple auth (the Firebase iOS app + OAuth clients are bound to the id). A temporary local install had already used `com.beyondkaira.hayati.dev` as a workaround. **Nothing user-facing depends on the exact bundle-id string** — it is invisible in the store and the app; the public *name* "Hayati" is a separate, still-provisional decision (ADR-020 D1).

## Decision 1 — Rename the iOS bundle id to `com.beyondkaira.hayati`

`com.beyondkaira.*` is the founder's own namespace (the shipped **Ballast** app is `com.beyondkaira.ballast`; the temp dev-install id was `com.beyondkaira.hayati.dev`), so registration on `UH7MXG7Z94` is guaranteed. A **single** id serves both flavors, preserving the existing architecture (one Runner; flavor = Dart entrypoint + Firebase project, not a per-flavor bundle id — architecture.md §2). Per-flavor ids (a side-by-side dev/prod install) were **not** adopted: that is a separate architecture change, out of scope for unblocking.

Renamed this session (deterministic, no console dependency): `project.pbxproj` (app target + `…RunnerTests` → `com.beyondkaira.hayati` / `com.beyondkaira.hayati.RunnerTests`), `fastlane/Appfile`, the `Info.plist` invite `CFBundleURLName` (`com.beyondkaira.hayati.invite`), and the two `integration_test/*_emulator_test.dart` demo fixtures.

## Decision 2 — Android stays `com.hayati.app`; its id decision is deferred to M6.5 with the platform

The squat is **Apple-only** — Play package-name uniqueness is a separate registry, and `com.hayati.app` may well be free there. A Play `applicationId` is **permanent once published**, so choosing it is a one-way door best walked at the Android-enablement slice (ADR-006) with the Play Console open, not pre-committed now. Renaming Android today would also move a Kotlin package + source directory (`kotlin/com/hayati/app/MainActivity.kt`) and risk the Android CI build for **zero TestFlight benefit**. The iOS/Android id divergence is acceptable (independent namespaces) and is recorded as explicit M6.5 debt; whoever does M6.5 decides whether Android matches `com.beyondkaira.hayati` or keeps `com.hayati.app`.

## Decision 3 — Firebase-minted values are **regenerated**, not hand-edited (a deliberate two-phase change)

`firebase_options_{dev,prod}.dart` (iOS `appId`/`apiKey`/`iosBundleId`), `google_sign_in_config.dart` (per-flavor iOS `clientId`), and the `Info.plist` `REVERSED_CLIENT_ID` URL schemes are all bound to the Firebase iOS-app registration for the *old* id. They are **not** string-patched: the founder registers a **new iOS app `com.beyondkaira.hayati` in both** `hayatiapp-dev` and `hayatiapp-prod`, then a session regenerates via `flutterfire configure` / `apps:sdkconfig` and flips the `firebase_bootstrap_test.dart` expectation. Until that Phase 2 lands, those files knowingly retain `com.hayati.app` — a transient split that **never ships**: no commit is made until the regen is in and `flutter test` is green. The old Firebase iOS apps are left orphaned (harmless; the web `serverClientId` is project-level and unchanged); optional console cleanup noted, not required.

## Consequences

**Positive:**

- The whole Apple/TestFlight path is unblocked with an id the founder actually controls; roadmap Step 1 now registers successfully.
- The rename is cheap precisely because the bundle id was never load-bearing in user-facing copy — unlike the store name (ADR-020), no marketing artifact or in-app string embeds it.

**Negative / accepted trade-offs:**

- **iOS/Android bundle-id divergence** until M6.5 — accepted, recorded, and revisited when Android ships.
- The **two-phase** shape (deterministic rename now, Firebase regen after the founder's console work) leaves the working tree briefly inconsistent; mitigated by not committing until Phase 2 verifies green.
- **Orphaned** old `com.hayati.app` Firebase iOS apps on both projects — harmless, optional cleanup.
- The operator roadmap's "register `com.hayati.app`" instructions were wrong the moment the squat was found; corrected in `docs/operator-expected.md` (Session 037 note) in the same change.
- `DEVELOPMENT_TEAM = UH7MXG7Z94` remains a **local-only** working-tree edit (not committed), consistent with the zero-account-identifiers Appfile posture (architecture.md §9); whether to commit it is revisited when the release lane's signing is wired (ADR-021, release.yml note).
