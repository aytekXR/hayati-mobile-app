import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_icon_switcher.g.dart';

/// The alternate icon set's name in `Assets.xcassets` (ADR-018 Decision 6). The
/// Swift half passes exactly this to `setAlternateIconName`; `null` means the
/// primary `AppIcon`.
const String kDiscreetIconName = 'AppIconDiscreet';

/// The discreet-icon seam (ADR-018 Decision 6).
///
/// HONEST BOUND (review finding DVUX-2), which the copy must respect: this
/// changes the icon IMAGE only. The home-screen NAME label
/// (`CFBundleDisplayName`) has no runtime API and does NOT change — it also
/// appears in Settings, Spotlight, the app-switcher chrome, and in the system
/// alert iOS shows on the icon change itself. The settings row is therefore
/// "Discreet app icon", never "hide the app".
abstract interface class AppIconSwitcher {
  /// Whether the platform supports alternate icons at all. False on any error —
  /// the settings row simply does not appear.
  Future<bool> supportsAlternateIcons();

  /// Whether the discreet icon is the one currently applied. False on any error.
  Future<bool> isDiscreet();

  /// Applies (or removes) the discreet icon.
  ///
  /// THROWS [AppIconException] when the OS refuses. The toggle then reverts with
  /// honest error copy: we never render a state the OS did not actually accept
  /// (ADR-018 Decision 7's fail-direction row).
  Future<void> setDiscreet(bool discreet);
}

/// The only thing [AppIconSwitcher.setDiscreet] throws. Carries a short [code]
/// string and NOTHING else — no PIN, no user data, no platform message that
/// might quote one (the no-content rule: Crashlytics forwards `toString()`s).
final class AppIconException implements Exception {
  const AppIconException(this.code);

  /// A short, static discriminator: the platform error code, or `'unsupported'`
  /// / `'channel-error'`. Never free text from the user or the OS.
  final String code;

  @override
  bool operator ==(Object other) =>
      other is AppIconException && other.code == code;

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => 'AppIconException(code: $code)';
}

/// Provides the app's [AppIconSwitcher].
///
/// Deliberately unimplemented at the base (the repository-seam discipline): the
/// flavor entrypoints override it BY VALUE with a `ChannelAppIconSwitcher`, and
/// tests with a `FakeAppIconSwitcher` — so `flutter test` never touches the
/// platform channel.
@Riverpod(keepAlive: true)
AppIconSwitcher appIconSwitcher(Ref ref) => throw StateError(
  'appIconSwitcherProvider must be overridden at bootstrap '
  '(main_dev.dart / main_prod.dart) or per test container.',
);
