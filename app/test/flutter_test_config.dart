import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads the real bundled TTFs once for the whole suite BEFORE any test runs,
/// so goldens capture true Rubik/Noto glyph shaping (incl. Arabic) instead of
/// the flutter_test placeholder font. Family strings MUST equal the pubspec /
/// theme families exactly, or the theme's font lookup misses these variants.
/// Existing behavioural tests are unaffected — they assert finders/types, not
/// pixels.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();

  await _loadFamily('Rubik', const [
    'assets/fonts/Rubik-Regular.ttf',
    'assets/fonts/Rubik-Medium.ttf',
    'assets/fonts/Rubik-SemiBold.ttf',
    'assets/fonts/Rubik-Bold.ttf',
  ]);
  await _loadFamily('Noto Sans', const [
    'assets/fonts/NotoSans-Regular.ttf',
    'assets/fonts/NotoSans-Medium.ttf',
    'assets/fonts/NotoSans-SemiBold.ttf',
    'assets/fonts/NotoSans-Bold.ttf',
  ]);
  // The Arabic fallback is a SEPARATE family: fallback resolution in tests
  // mirrors runtime, so without this every Arabic code point renders as tofu.
  await _loadFamily('Noto Sans Arabic', const [
    'assets/fonts/NotoSansArabic-Regular.ttf',
    'assets/fonts/NotoSansArabic-Medium.ttf',
    'assets/fonts/NotoSansArabic-SemiBold.ttf',
    'assets/fonts/NotoSansArabic-Bold.ttf',
  ]);

  // MaterialIcons backs the RTL mirror net-proof: arrow_back must draw a real
  // directional glyph, not a symmetric placeholder box (a flipped box looks
  // identical, which would silently defeat the net). Its asset ships in the
  // framework, so discover it from the bundled FontManifest rather than
  // hard-coding a path.
  await _loadManifestFamily('MaterialIcons');

  await testMain();
}

Future<void> _loadFamily(String family, List<String> assets) async {
  final loader = FontLoader(family);
  for (final asset in assets) {
    loader.addFont(rootBundle.load(asset));
  }
  await loader.load();
}

Future<void> _loadManifestFamily(String family) async {
  final manifest =
      json.decode(await rootBundle.loadString('FontManifest.json'))
          as List<dynamic>;
  for (final entry in manifest) {
    final map = entry as Map<String, dynamic>;
    if (map['family'] != family) continue;
    final loader = FontLoader(family);
    for (final font in map['fonts'] as List<dynamic>) {
      loader.addFont(
        rootBundle.load((font as Map<String, dynamic>)['asset'] as String),
      );
    }
    await loader.load();
    return;
  }
}
