import '../../profile/domain/relationship_profile.dart';
import 'coach_persona.dart';
import 'coach_register.dart';
import 'coach_reply.dart';
import 'coach_window.dart';

/// The app's port to the `coachProxy` callable (ADR-017 Decisions 1/5). The
/// caller derives [language] (`profile.contentLanguage`) and [register]
/// (`coachRegisterFor`) from the settled profile and passes the already-built
/// window ([messages], via `buildCoachWindow`). The send path is TOTAL over
/// [CoachException]: the implementation maps every failure crossing this
/// boundary into that taxonomy, and a malformed response never escapes as a
/// persona reply.
abstract interface class CoachRepository {
  Future<CoachReply> sendMessage({
    required String coupleId,
    required CoachPersonaId personaId,
    required ContentLanguage language,
    required CoachRegister register,
    required List<CoachMessage> messages,
  });
}
