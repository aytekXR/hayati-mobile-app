import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/legal/presentation/legal_renderer.dart';

/// The minimal deterministic renderer (ADR-023 D5). The PARSER is a TOTAL
/// function over the closed subset — headers, bullets, paragraphs — and every
/// unrecognised line falls through to body text; it can never throw.
void main() {
  group('parseLegalMarkdown', () {
    test('a `# ` line is the title', () {
      expect(parseLegalMarkdown('# Privacy Policy'), [
        const LegalBlock(LegalBlockKind.title, 'Privacy Policy'),
      ]);
    });

    test('a `## ` line is a section (checked before `# `)', () {
      expect(parseLegalMarkdown('## Your rights'), [
        const LegalBlock(LegalBlockKind.section, 'Your rights'),
      ]);
    });

    test('a `- ` line is a bullet', () {
      expect(parseLegalMarkdown('- invite records'), [
        const LegalBlock(LegalBlockKind.bullet, 'invite records'),
      ]);
    });

    test('a plain line is body text', () {
      expect(parseLegalMarkdown('This is a paragraph.'), [
        const LegalBlock(LegalBlockKind.body, 'This is a paragraph.'),
      ]);
    });

    test('blank lines separate paragraphs; contiguous lines join into one', () {
      const source = 'First line\nsame paragraph\n\nSecond paragraph';
      expect(parseLegalMarkdown(source), [
        const LegalBlock(LegalBlockKind.body, 'First line same paragraph'),
        const LegalBlock(LegalBlockKind.body, 'Second paragraph'),
      ]);
    });

    test('a full document parses to the expected block sequence', () {
      const source = '''
# Title

Intro paragraph.

## Section

- bullet one
- bullet two

Closing line.''';
      expect(parseLegalMarkdown(source), [
        const LegalBlock(LegalBlockKind.title, 'Title'),
        const LegalBlock(LegalBlockKind.body, 'Intro paragraph.'),
        const LegalBlock(LegalBlockKind.section, 'Section'),
        const LegalBlock(LegalBlockKind.bullet, 'bullet one'),
        const LegalBlock(LegalBlockKind.bullet, 'bullet two'),
        const LegalBlock(LegalBlockKind.body, 'Closing line.'),
      ]);
    });

    test('GARBAGE lines render as body — TOTALITY, never throws', () {
      // A bare `#` (no space), a table pipe, an emphasis run, a blockquote —
      // none are in the subset, so all become body text.
      const garbage = '#nospace\n| a | b |\n***bold***\n> quote';
      final blocks = parseLegalMarkdown(garbage);
      expect(blocks.every((b) => b.kind == LegalBlockKind.body), isTrue);
      // All four glued into one paragraph (no blank lines between them).
      expect(blocks.single.text, '#nospace | a | b | ***bold*** > quote');
    });

    test('CRLF and CR line endings split the same as LF', () {
      expect(parseLegalMarkdown('# A\r\n\r\n- b\rplain'), [
        const LegalBlock(LegalBlockKind.title, 'A'),
        const LegalBlock(LegalBlockKind.bullet, 'b'),
        const LegalBlock(LegalBlockKind.body, 'plain'),
      ]);
    });

    test('empty source → no blocks (never throws)', () {
      expect(parseLegalMarkdown(''), isEmpty);
      expect(parseLegalMarkdown('\n\n\n'), isEmpty);
    });

    test('the real shipped documents all parse without throwing', () {
      // The drift test proves docs ↔ assets equality; here we prove the renderer
      // survives every real document (a `# ` title, `## ` sections, `- ` bullets,
      // and prose) with a non-empty block list.
      for (final doc in const ['privacy-policy', 'terms']) {
        for (final locale in const ['tr', 'ar', 'en']) {
          final source = _readAsset('assets/legal/$doc.$locale.md');
          final blocks = parseLegalMarkdown(source);
          expect(blocks, isNotEmpty, reason: '$doc.$locale.md parsed empty');
          expect(
            blocks.first.kind,
            LegalBlockKind.title,
            reason: '$doc.$locale.md must open with a `# ` title',
          );
        }
      }
    });
  });
}

String _readAsset(String path) => File(path).readAsStringSync();
