import '../../profile/domain/relationship_profile.dart';
import 'solo_question.dart';

/// Loads the bundled solo question pack for a content language (M2.4). The
/// only implementation reads the schema-shaped JSON assets under
/// `app/assets/content/`; M3's pack pipeline (validator + remote sync)
/// replaces the loading strategy behind this same seam.
abstract interface class SoloQuestionPackRepository {
  /// Loads and validates the pack for [language]. Throws [FormatException]
  /// on a malformed or non-7-question pack — a packaging bug, surfaced loudly
  /// through the provider's error state rather than silently truncating the
  /// cycle.
  Future<SoloQuestionPack> loadPack(ContentLanguage language);
}
