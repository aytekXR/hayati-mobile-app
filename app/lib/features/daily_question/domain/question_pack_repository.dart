import 'question.dart';

/// The requested pack is not bundled at all (M3.3): distinct from a
/// malformed pack because the remedies differ — a day doc referencing a
/// pack this install does not carry means the deployed Function outpaced
/// the app ("update the app", no point retrying), while [FormatException]
/// stays a packaging bug (loud error + retry).
class UnknownQuestionPackException implements Exception {
  const UnknownQuestionPackException(this.packId);

  final String packId;

  @override
  String toString() => 'UnknownQuestionPackException(packId: $packId)';
}

/// Loads one question pack by its stable [packId] (M3.1). The bundled
/// implementation reads `app/assets/content/<packId>.json`; M3.2's remote
/// sync adds a strategy behind this same seam. Solo loading specializes this
/// via [SoloQuestionPackRepository]-style wrappers rather than widening it.
abstract interface class QuestionPackRepository {
  /// Loads and validates the pack [packId]. Throws
  /// [UnknownQuestionPackException] when no such pack is bundled (M3.3
  /// pack-lag state), and [FormatException] on a malformed pack or a pack
  /// whose `packId` field disagrees with the requested id — a packaging
  /// bug, surfaced loudly through the provider's error state rather than
  /// serving the wrong content.
  Future<QuestionPack> loadPack(String packId);
}
