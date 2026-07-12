import 'package:hayati_app/features/coach/domain/coach_persona.dart';
import 'package:hayati_app/features/coach/domain/coach_register.dart';
import 'package:hayati_app/features/coach/domain/coach_reply.dart';
import 'package:hayati_app/features/coach/domain/coach_repository.dart';
import 'package:hayati_app/features/coach/domain/coach_window.dart';
import 'package:hayati_app/features/profile/domain/relationship_profile.dart';

/// One recorded `sendMessage` invocation — the FULL argument set (incl. the
/// built [messages] window) so a test can assert exactly what was sent (the
/// [buildCoachWindow] output, the derived register, …).
class CoachSendCall {
  const CoachSendCall({
    required this.coupleId,
    required this.personaId,
    required this.language,
    required this.register,
    required this.messages,
  });

  final String coupleId;
  final CoachPersonaId personaId;
  final ContentLanguage language;
  final CoachRegister register;
  final List<CoachMessage> messages;
}

/// Hand-written fake backing the coach data/presentation tests, in the
/// [FakeInviteRepository] recorder style: an ordered [callLog] proves the window
/// and derived fields, and [onSendMessage] overrides the outcome (throw a
/// [CoachException], gate on a Completer, …). The default returns a canned reply
/// so a test that just needs a happy path renders without arrangement.
class FakeCoachRepository implements CoachRepository {
  /// The canned reply returned when [onSendMessage] is unset.
  static const CoachReply cannedReply = CoachReply(
    kind: CoachReplyKind.reply,
    text: 'Fixture coach reply.',
    remaining: CoachRemaining(daily: 29, monthly: 999),
  );

  /// The ordered log of `sendMessage` calls — proves re-entrancy drops,
  /// captured-window contents, and the derived language/register.
  final List<CoachSendCall> callLog = [];

  /// Behaviour override; default returns [cannedReply]. Receives the recorded
  /// call so a test can gate/branch on the arguments.
  Future<CoachReply> Function(CoachSendCall call)? onSendMessage;

  @override
  Future<CoachReply> sendMessage({
    required String coupleId,
    required CoachPersonaId personaId,
    required ContentLanguage language,
    required CoachRegister register,
    required List<CoachMessage> messages,
  }) {
    final call = CoachSendCall(
      coupleId: coupleId,
      personaId: personaId,
      language: language,
      register: register,
      messages: messages,
    );
    callLog.add(call);
    final handler = onSendMessage;
    if (handler != null) return handler(call);
    return Future<CoachReply>.value(cannedReply);
  }
}
