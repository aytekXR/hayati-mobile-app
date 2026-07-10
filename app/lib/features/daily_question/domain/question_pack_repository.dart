import 'question.dart';

/// Loads one question pack by its stable [packId] (M3.1). The bundled
/// implementation reads `app/assets/content/<packId>.json`; M3.2's remote
/// sync adds a strategy behind this same seam. Solo loading specializes this
/// via [SoloQuestionPackRepository]-style wrappers rather than widening it.
abstract interface class QuestionPackRepository {
  /// Loads and validates the pack [packId]. Throws [FormatException] on a
  /// malformed pack or a pack whose `packId` field disagrees with the
  /// requested id — a packaging bug, surfaced loudly through the provider's
  /// error state rather than serving the wrong content.
  Future<QuestionPack> loadPack(String packId);
}
