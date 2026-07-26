import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/core/design_system/elevation_tokens.dart';

/// Elevation is a redesign ui-ux §9.3 *rule* realised as code constants
/// (ADR-025 D5.ii status — same as MotionTokens): plum-tinted, never black,
/// three pinned levels. This test is its checked, citable home.
void main() {
  group('ElevationTokens (ui-ux §9.3)', () {
    test('the shadow base is the plum #160E22, never black', () {
      expect(ElevationTokens.shadowBase, const Color(0xFF160E22));
    });

    test('level 1 — cards: y2 blur8 at 28%', () {
      final s = ElevationTokens.level1.single;
      expect(s.offset, const Offset(0, 2));
      expect(s.blurRadius, 8);
      expect(s.color.a, closeTo(0.28, 0.005));
      expect(s.color.toARGB32() & 0x00FFFFFF, 0x160E22);
    });

    test('level 2 — sheets/dialogs: y6 blur24 at 36%', () {
      final s = ElevationTokens.level2.single;
      expect(s.offset, const Offset(0, 6));
      expect(s.blurRadius, 24);
      expect(s.color.a, closeTo(0.36, 0.005));
      expect(s.color.toARGB32() & 0x00FFFFFF, 0x160E22);
    });

    test('level 3 — milestone overlay: y12 blur40 at 44%', () {
      final s = ElevationTokens.level3.single;
      expect(s.offset, const Offset(0, 12));
      expect(s.blurRadius, 40);
      expect(s.color.a, closeTo(0.44, 0.005));
      expect(s.color.toARGB32() & 0x00FFFFFF, 0x160E22);
    });
  });
}
