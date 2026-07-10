import '../../profile/domain/relationship_profile.dart';
import 'question.dart';

/// Loads the bundled solo question pack for a content language (M2.4;
/// generalized M3.1 — the solo pack is a [QuestionPack] like any other, this
/// seam just resolves it by language and holds the solo-only guarantees).
/// The only implementation wraps the generic asset repository over the
/// validator-synced assets under `app/assets/content/`.
abstract interface class SoloQuestionPackRepository {
  /// Loads and validates the solo pack for [language]. Throws
  /// [FormatException] on a malformed or non-7-question pack — a packaging
  /// bug, surfaced loudly through the provider's error state rather than
  /// silently truncating the cycle.
  Future<QuestionPack> loadPack(ContentLanguage language);
}
