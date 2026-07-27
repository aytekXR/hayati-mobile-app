import 'package:flutter/material.dart';

import '../l10n/bidi_isolate.dart';

/// A [Text] for **content** — a string whose script the app does not control:
/// the daily question (the pack's language is a separate profile field from the
/// UI locale), either partner's free-text answer, a coach turn, a store price.
///
/// It bidi-isolates its data so trailing punctuation binds to the sentence
/// rather than to the surrounding chrome (ADR-033, issue #133). Chrome —
/// anything from `AppLocalizations` — must keep using plain [Text]: its
/// sentence direction already matches the paragraph, so isolating it is a
/// measured no-op that would only churn goldens.
///
/// The accessibility tree gets the **pristine** string via [Text.semanticsLabel],
/// so the isolate characters never reach a screen reader.
class ContentText extends StatelessWidget {
  const ContentText(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  /// The content string, exactly as authored. Never pre-isolated by callers —
  /// isolation happens here and nowhere else, so nothing persisted, exported or
  /// shared can ever carry the control characters (ADR-033 D4).
  final String data;

  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    return Text(
      isolate(data),
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      semanticsLabel: data.isEmpty ? null : data,
    );
  }
}
