# app/ — Hayati Flutter Application

The product code. Everything about *what* to build and *how* lives in the
repo-root [`docs/`](../docs/) — start with `docs/project-rules.md` and
`docs/architecture.md` §2 for this module's layout.

## Quick start

```sh
flutter pub get
flutter test                                   # unit + widget tests
flutter analyze                                # strict lints (analysis_options.yaml)
dart ../tool/rtl_lint.dart lib                 # logical start/end guard
flutter run -t lib/main_dev.dart               # dev flavor
flutter run -t lib/main_prod.dart              # prod flavor
```

## Firebase (M1.1 state: emulator-only)

Real Firebase projects are not provisioned yet (issue #5) — the committed
per-flavor options (`lib/core/firebase/firebase_options_*.dart`) are
placeholders, and the dev flavor's `demo-hayati` projectId runs the local
emulator credential-free. Until provisioning, all auth work happens against
the **Auth emulator** (`firebase.json` at the repo root):

```sh
# terminal 1 — repo root
npx firebase-tools emulators:start --only auth --project demo-hayati

# terminal 2 — app/, any device/simulator
flutter run -t lib/main_dev.dart --dart-define=USE_AUTH_EMULATOR=true
# physical device: add --dart-define=AUTH_EMULATOR_HOST=<your LAN IP>

# auth round-trip integration test (device/simulator only; ci-debt #6)
flutter test integration_test --dart-define=USE_AUTH_EMULATOR=true -d <device>
```

Once M1.2 provisions `hayati-dev`/`hayati-prod` and `flutterfire configure`
replaces the placeholders, the dev flavor without the dart-define talks to
the real `hayati-dev` project; sign-in additionally needs the iOS
`REVERSED_CLIENT_ID` URL scheme / Android `serverClientId` (issue #5).

## Conventions

- Flavors are Dart entrypoints (`main_dev.dart` / `main_prod.dart`) overriding
  `appConfigProvider`; store-level flavor split arrives with CI/Fastlane (M0.2).
- Brand strings live only in `lib/core/config/` (working title pending
  trademark search — `docs/frontend-brandkit.md` §1).
- Riverpod codegen: generated `*.g.dart` files are committed so a fresh clone
  tests green without a build step; regenerate with
  `dart run build_runner build --delete-conflicting-outputs`.
- Layout code uses logical `start`/`end` only — enforced by `tool/rtl_lint.dart`.
