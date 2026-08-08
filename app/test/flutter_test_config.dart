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

  // Discovered from the bundled FontManifest rather than hard-coded, so this
  // file cannot disagree with pubspec.yaml about which faces exist. It did:
  // the four Rubik weights were listed here by hand, so when #176 added
  // Rubik-Light the goldens would have kept rendering the question at Regular
  // and the diff would have read as "no visual change" — the change being
  // invisible to the instrument, not absent.
  await _loadManifestFamily('Rubik');
  await _loadManifestFamily('Noto Sans');
  // The Arabic fallback is a SEPARATE family: fallback resolution in tests
  // mirrors runtime, so without this every Arabic code point renders as tofu.
  await _loadManifestFamily('Noto Sans Arabic');

  // MaterialIcons backs the RTL mirror net-proof: arrow_back must draw a real
  // directional glyph, not a symmetric placeholder box (a flipped box looks
  // identical, which would silently defeat the net). Its asset ships in the
  // framework, so discover it from the bundled FontManifest rather than
  // hard-coding a path.
  await _loadManifestFamily('MaterialIcons');

  await testMain();
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
  // Loudly, not silently. A family that is absent from the manifest loads
  // nothing, every glyph falls back to the flutter_test placeholder, and the
  // goldens still pass — a green suite that measured the wrong pixels.
  throw StateError(
    'FontManifest.json declares no family "$family"; goldens would render it '
    'in the flutter_test placeholder font. Check pubspec.yaml `fonts:`.',
  );
}
