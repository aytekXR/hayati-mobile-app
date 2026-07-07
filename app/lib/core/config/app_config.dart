/// The single place brand strings live. The working title is pending a
/// trademark/store-name search (docs/frontend-brandkit.md §1) — renaming the
/// brand must only ever require touching `core/config/`.
const String kBrandName = 'Hayati';

/// Build flavors. Wired through the Dart entrypoints `main_dev.dart` and
/// `main_prod.dart`; store-level flavor split (Gradle productFlavors / Xcode
/// schemes) lands with the CI/Fastlane work in M0.2 where it can be validated
/// on real toolchains.
enum AppFlavor { dev, prod }

/// Immutable environment configuration for the running flavor.
class AppConfig {
  const AppConfig({required this.flavor, this.appName = kBrandName});

  final AppFlavor flavor;
  final String appName;

  bool get isProd => flavor == AppFlavor.prod;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppConfig && other.flavor == flavor && other.appName == appName;

  @override
  int get hashCode => Object.hash(flavor, appName);
}
