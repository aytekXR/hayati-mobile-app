import 'coach_transcript_entry.dart';

/// The window bounds, mirroring the functions `coach-core` `MAX_MESSAGES` /
/// `MAX_MESSAGE_CHARS` (frozen contract, ADR-016 Decision 1). The server
/// validates message length in UTF-16 code units (`raw.text.length` in JS) and
/// Dart's `String.length` counts the SAME units — so the client gates and
/// truncates in the same unit.
const int kCoachWindowMaxMessages = 20;
const int kCoachMessageMaxChars = 2000;

/// One message in the window sent to `coachProxy` — the port shape (`role` is
/// `'user'` | `'assistant'`). No-content rule (ADR-017 Decision 5): [toString]
/// omits [text]; equality still compares it (value semantics).
class CoachMessage {
  const CoachMessage({required this.role, required this.text});

  final String role;
  final String text;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CoachMessage && other.role == role && other.text == text;

  @override
  int get hashCode => Object.hash(role, text);

  @override
  String toString() => 'CoachMessage(role: $role, textLength: ${text.length})';
}

/// Builds the client-owned window sent to `coachProxy` from a persona's
/// transcript plus the new user message (ADR-017 Decision 2, rules 1/2/5). Pure,
/// no I/O:
///
/// - **Help turns NEVER enter** (rule 1) — they are safety-system UI artifacts,
///   not conversation turns; a help text in an `assistant` slot would be forged
///   conversation and could trip the post-filter lexicons on later turns.
/// - **User turns are role `'user'`, verbatim** — never truncated (rule 2:
///   crisis turns are retained; they already conform to the send gate). This
///   includes a user turn that previously drew a help response — the builder
///   applies NO crisis-aware filtering.
/// - **Persona turns are role `'assistant'`, truncated** to
///   [kCoachMessageMaxChars] UTF-16 code units (rule 5) — server-generated text
///   carries no length contract, and context loss on a pathological reply is
///   benign.
/// - The new user message is appended LAST (always role `'user'`).
/// - Only the LAST [kCoachWindowMaxMessages] eligible turns survive, trimmed
///   oldest-first (rule 5 bounds, enforced in wire units).
List<CoachMessage> buildCoachWindow({
  required List<CoachTranscriptEntry> entries,
  required String newUserText,
}) {
  final messages = <CoachMessage>[];
  for (final entry in entries) {
    final message = switch (entry) {
      CoachUserTurn(:final text) => CoachMessage(role: 'user', text: text),
      CoachPersonaTurn(:final text) => CoachMessage(
        role: 'assistant',
        text: _truncateAssistant(text),
      ),
      // Help turns are excluded by TYPE — never sent as an assistant message.
      CoachHelpTurn() => null,
    };
    if (message != null) messages.add(message);
  }
  messages.add(CoachMessage(role: 'user', text: newUserText));
  if (messages.length > kCoachWindowMaxMessages) {
    // Oldest-first trimming: keep only the last kCoachWindowMaxMessages.
    return messages.sublist(messages.length - kCoachWindowMaxMessages);
  }
  return messages;
}

/// Truncates a persona reply to the wire bound in UTF-16 code units.
/// `substring` is code-unit indexed (like the server's `slice`), so an
/// emoji/surrogate pair straddling the boundary is cut in the SAME unit the
/// server would have rejected on.
String _truncateAssistant(String text) => text.length > kCoachMessageMaxChars
    ? text.substring(0, kCoachMessageMaxChars)
    : text;
