/// The crisis category the server may attach to a help-path response — its wire
/// names match the server's `CrisisCategory` union (`'selfHarm'` / `'violence'`,
/// `functions/src/coach/crisis-lexicon.ts`). Display-only: it may tune the help
/// card's copy but NEVER drives client-side detection — the safety verdict stays
/// server-owned (ADR-017 Decision 2). An unknown wire string maps to null (a
/// display-only field must never make the response mapper throw).
enum CoachCrisisCategory { selfHarm, violence }

/// Which path produced a [CoachReply] — the frozen `kind` discriminator
/// (ADR-016 Decision 1). [reply] is a persona turn; [help] is the safety
/// system's static help response and must NEVER render as a persona bubble
/// (ADR-017 Decision 8: help rendering is structurally distinct).
enum CoachReplyKind { reply, help }

/// The point-in-time quota hint echoed on every capped path (ADR-016
/// Decisions 6/7). Display-only and stale the moment a partner reserves against
/// the shared monthly bucket — never a gate (ADR-017 Decision 6). Value
/// semantics; both fields are plain counts (never conversation content).
class CoachRemaining {
  const CoachRemaining({required this.daily, required this.monthly});

  final int daily;
  final int monthly;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CoachRemaining &&
          other.daily == daily &&
          other.monthly == monthly;

  @override
  int get hashCode => Object.hash(daily, monthly);

  @override
  String toString() => 'CoachRemaining(daily: $daily, monthly: $monthly)';
}

/// A decoded `coachProxy` response (the frozen contract, ADR-016 Decision 1):
/// a [kind] discriminator, the response [text], an optional crisis [category]
/// (help path only), and an optional [remaining] quota hint (capped paths only).
///
/// No-content rule (ADR-017 Decision 5): [toString] deliberately omits the raw
/// [text] — coach reply text can carry crisis disclosures and the global error
/// hooks forward `toString()` to Crashlytics, so no coach state that could
/// escape may render conversation content. Equality still compares [text]
/// (value semantics); only the debug string is redacted to its length.
class CoachReply {
  const CoachReply({
    required this.kind,
    required this.text,
    this.category,
    this.remaining,
  });

  final CoachReplyKind kind;
  final String text;
  final CoachCrisisCategory? category;
  final CoachRemaining? remaining;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CoachReply &&
          other.kind == kind &&
          other.text == text &&
          other.category == category &&
          other.remaining == remaining;

  @override
  int get hashCode => Object.hash(kind, text, category, remaining);

  @override
  String toString() =>
      'CoachReply(kind: $kind, category: $category, remaining: $remaining, '
      'textLength: ${text.length})';
}
