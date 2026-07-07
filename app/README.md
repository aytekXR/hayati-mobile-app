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

## Conventions

- Flavors are Dart entrypoints (`main_dev.dart` / `main_prod.dart`) overriding
  `appConfigProvider`; store-level flavor split arrives with CI/Fastlane (M0.2).
- Brand strings live only in `lib/core/config/` (working title pending
  trademark search — `docs/frontend-brandkit.md` §1).
- Riverpod codegen: generated `*.g.dart` files are committed so a fresh clone
  tests green without a build step; regenerate with
  `dart run build_runner build --delete-conflicting-outputs`.
- Layout code uses logical `start`/`end` only — enforced by `tool/rtl_lint.dart`.
