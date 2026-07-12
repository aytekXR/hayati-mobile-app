import 'coach_reply.dart';

/// One rendered turn in a persona's transcript (ADR-017 Decision 8). A sealed
/// family so help turns are STRUCTURALLY distinct from persona turns — a help
/// text may never be mistaken for (or re-bubbled as) a persona reply, and the
/// window builder can exclude help turns by TYPE (Decision 2 rule 1).
///
/// No-content rule (ADR-017 Decision 5): [toString] omits the raw [text] — these
/// entries can carry crisis disclosures and the global error hooks forward
/// `toString()` to Crashlytics. Equality still compares [text] (value semantics);
/// only the debug string is redacted to a length.
sealed class CoachTranscriptEntry {
  const CoachTranscriptEntry(this.text);

  final String text;
}

/// A confirmed user turn — sent verbatim into the window as role `'user'`
/// (never truncated: it already conforms to the 2,000-char send gate).
final class CoachUserTurn extends CoachTranscriptEntry {
  const CoachUserTurn(super.text);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is CoachUserTurn && other.text == text;

  @override
  int get hashCode => Object.hash(CoachUserTurn, text);

  @override
  String toString() => 'CoachUserTurn(textLength: ${text.length})';
}

/// A persona reply turn (`kind:'reply'`) — re-enters the window as role
/// `'assistant'`, truncated defensively to the wire bound.
final class CoachPersonaTurn extends CoachTranscriptEntry {
  const CoachPersonaTurn(super.text);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is CoachPersonaTurn && other.text == text;

  @override
  int get hashCode => Object.hash(CoachPersonaTurn, text);

  @override
  String toString() => 'CoachPersonaTurn(textLength: ${text.length})';
}

/// A safety help turn (`kind:'help'`) — a UI artifact of the safety system, not
/// a conversation turn. NEVER enters the window (Decision 2 rule 1). [category]
/// is the server's display-only crisis category, or null.
final class CoachHelpTurn extends CoachTranscriptEntry {
  const CoachHelpTurn(super.text, {this.category});

  final CoachCrisisCategory? category;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CoachHelpTurn && other.text == text && other.category == category;

  @override
  int get hashCode => Object.hash(CoachHelpTurn, text, category);

  @override
  String toString() =>
      'CoachHelpTurn(category: $category, textLength: ${text.length})';
}
