import 'package:flutter/material.dart';

import '../../../core/design_system/spacing_tokens.dart';

/// The kind of a parsed legal-document block (ADR-023 Decision 5). The renderer
/// understands only this closed subset; every other line is [body].
enum LegalBlockKind {
  /// The single `# ` document title (headline style).
  title,

  /// A `## ` section heading.
  section,

  /// A `- ` single-level bullet row.
  bullet,

  /// A blank-line-separated paragraph — and, by TOTALITY, ANY line the subset
  /// does not recognise (a stray `***`, a table pipe, `#nospace`). Garbage
  /// renders as plain body text; the parser never throws.
  body,
}

/// One parsed block: its [kind] and the text with any marker prefix stripped.
class LegalBlock {
  const LegalBlock(this.kind, this.text);

  final LegalBlockKind kind;
  final String text;

  @override
  bool operator ==(Object other) =>
      other is LegalBlock && other.kind == kind && other.text == text;

  @override
  int get hashCode => Object.hash(kind, text);

  @override
  String toString() => 'LegalBlock($kind, "$text")';
}

/// Parses [source] markdown into the closed [LegalBlock] subset (ADR-023 D5).
/// A minimal, TOTAL parser — no markdown dependency, never throws:
///
///  - a `## ` line → [LegalBlockKind.section] (checked before `# `);
///  - a `# ` line  → [LegalBlockKind.title];
///  - a `- ` line  → [LegalBlockKind.bullet];
///  - blank lines separate paragraphs; consecutive non-marker lines join (with a
///    space) into ONE [LegalBlockKind.body] paragraph;
///  - anything the subset does not recognise falls through to body text.
///
/// Kept pure (no widgets) so the header/bullet/paragraph/garbage matrix is
/// exhaustively unit-testable without a widget tree.
List<LegalBlock> parseLegalMarkdown(String source) {
  final blocks = <LegalBlock>[];
  final paragraph = <String>[];

  void flushParagraph() {
    if (paragraph.isEmpty) return;
    blocks.add(LegalBlock(LegalBlockKind.body, paragraph.join(' ')));
    paragraph.clear();
  }

  for (final rawLine in source.split(RegExp(r'\r\n|\r|\n'))) {
    final line = rawLine.trimRight();
    if (line.trim().isEmpty) {
      flushParagraph();
    } else if (line.startsWith('## ')) {
      flushParagraph();
      blocks.add(LegalBlock(LegalBlockKind.section, line.substring(3).trim()));
    } else if (line.startsWith('# ')) {
      flushParagraph();
      blocks.add(LegalBlock(LegalBlockKind.title, line.substring(2).trim()));
    } else if (line.startsWith('- ')) {
      flushParagraph();
      blocks.add(LegalBlock(LegalBlockKind.bullet, line.substring(2).trim()));
    } else {
      paragraph.add(line.trim());
    }
  }
  flushParagraph();
  return blocks;
}

/// Builds the rendered document body from [source] (ADR-023 D5), inside the
/// established `SingleChildScrollView → Column(Text…)` mold. RTL-safe: a bullet
/// row is a plain [Row] (which lays out in the reading direction) with a
/// directional gap — no physical-direction API, so `rtl_lint` stays clean.
Column legalDocumentColumn(String source, ThemeData theme) {
  final blocks = parseLegalMarkdown(source);
  final children = <Widget>[];
  for (var i = 0; i < blocks.length; i++) {
    final block = blocks[i];
    if (i > 0) {
      children.add(
        SizedBox(
          height: block.kind == LegalBlockKind.section
              ? SpacingTokens.x5
              : SpacingTokens.x3,
        ),
      );
    }
    children.add(_blockWidget(block, theme));
  }
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: children,
  );
}

Widget _blockWidget(LegalBlock block, ThemeData theme) {
  final textTheme = theme.textTheme;
  switch (block.kind) {
    case LegalBlockKind.title:
      return Text(block.text, style: textTheme.headlineSmall);
    case LegalBlockKind.section:
      return Text(block.text, style: textTheme.titleMedium);
    case LegalBlockKind.bullet:
      final bodyStyle = textTheme.bodyMedium;
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('•', style: bodyStyle),
          const SizedBox(width: SpacingTokens.x2),
          Expanded(child: Text(block.text, style: bodyStyle)),
        ],
      );
    case LegalBlockKind.body:
      return Text(block.text, style: textTheme.bodyMedium);
  }
}
