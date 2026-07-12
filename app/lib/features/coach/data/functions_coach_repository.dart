import 'package:cloud_functions/cloud_functions.dart';

import '../../../core/firebase/firebase_bootstrap.dart';
import '../../profile/domain/relationship_profile.dart';
import '../domain/coach_exception.dart';
import '../domain/coach_persona.dart';
import '../domain/coach_register.dart';
import '../domain/coach_reply.dart';
import '../domain/coach_repository.dart';
import '../domain/coach_window.dart';

/// [CoachRepository] backed by the `coachProxy` callable (ADR-016 Decision 1,
/// ADR-017 Decision 5). Thin adapter: the wire encode is trivial and every
/// failure crossing this boundary is mapped into the [CoachException] taxonomy —
/// nothing but a [CoachException] escapes the data layer (the controller catches
/// only that), and a malformed body never renders as a persona reply. The
/// parse/map logic lives in the pure top-level functions below so it is
/// exhaustively unit-testable without a live callable (the M2.2 thin-adapter
/// precedent: the adapter itself is untested, the mappers are fully tested).
class FunctionsCoachRepository implements CoachRepository {
  /// [functions] defaults to the region-scoped instance the emulator wiring in
  /// `firebase_bootstrap.dart` also resolves (instanceFor caches per
  /// app+region), so a `USE_FUNCTIONS_EMULATOR` run reaches the emulator
  /// without any extra plumbing here.
  FunctionsCoachRepository({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: kFunctionsRegion);

  final FirebaseFunctions _functions;

  @override
  Future<CoachReply> sendMessage({
    required String coupleId,
    required CoachPersonaId personaId,
    required ContentLanguage language,
    required CoachRegister register,
    required List<CoachMessage> messages,
  }) async {
    try {
      final result = await _functions.httpsCallable('coachProxy').call<Object?>({
        'coupleId': coupleId,
        'personaId': personaId.name,
        'language': language.name,
        'register': register.wire,
        'messages': [
          for (final message in messages)
            {'role': message.role, 'text': message.text},
        ],
      });
      return decodeOrThrowCoachException(result.data);
    } on CoachException {
      // A malformed-body conversion (decodeOrThrowCoachException) is already in
      // the taxonomy — rethrow it unchanged rather than re-wrapping it as
      // 'unexpected' via the generic mapper below.
      rethrow;
    } catch (failure) {
      throw mapCoachFailure(failure);
    }
  }
}

/// Decodes the callable payload into a [CoachReply], converting a parse
/// [FormatException] to a [CoachException] INSIDE the data layer (ADR-017
/// Decision 5): the controller catches only [CoachException], so a raw
/// [FormatException] must never escape. The conversion drops the FormatException
/// text entirely — [CoachUnknownException.message] stays null (belt-and-suspenders
/// on the no-content rule; the message would only ever hold runtimeTypes anyway).
CoachReply decodeOrThrowCoachException(Object? data) {
  try {
    return coachReplyFromCallable(data);
  } on FormatException {
    throw const CoachUnknownException(code: 'malformed-response');
  }
}

/// Wire mapping for the `coachProxy` response (`{kind, category?, text,
/// remaining?}`, ADR-016 Decision 1). Pure and loud: an unexpected shape throws
/// [FormatException] (converted to [CoachUnknownException] at the boundary)
/// rather than returning a bogus reply. Every [FormatException] message
/// interpolates ONLY `.runtimeType` or a field name — NEVER a value (ADR-017
/// Decision 5 no-content rule; Crashlytics is on in prod).
///
/// `kind`/`text` are STRICT (`'reply'|'help'`, a non-empty String). `category`
/// is lenient — a display-only field must never make the mapper throw, so an
/// unknown/absent category maps to null. `remaining`, when present, must be a
/// `{daily:num, monthly:num}` shape (a malformed shape throws).
CoachReply coachReplyFromCallable(Object? data) {
  if (data is! Map) {
    throw FormatException('coachProxy: expected a map, got ${data.runtimeType}');
  }
  final kind = data['kind'];
  final kindEnum = switch (kind) {
    'reply' => CoachReplyKind.reply,
    'help' => CoachReplyKind.help,
    _ => throw FormatException('coachProxy: "kind" is ${kind.runtimeType}'),
  };
  final text = data['text'];
  if (text is! String) {
    throw FormatException('coachProxy: "text" is ${text.runtimeType}');
  }
  if (text.isEmpty) {
    throw const FormatException('coachProxy: "text" is empty');
  }
  return CoachReply(
    kind: kindEnum,
    text: text,
    category: _categoryFromCallable(data['category']),
    remaining: _remainingFromCallable(data['remaining']),
  );
}

/// Maps the optional `category` field: the two known crisis categories, or null
/// for absent/unknown (never throws — display-only, ADR-017 Decision 2).
CoachCrisisCategory? _categoryFromCallable(Object? raw) => switch (raw) {
  'selfHarm' => CoachCrisisCategory.selfHarm,
  'violence' => CoachCrisisCategory.violence,
  _ => null,
};

/// Maps the optional `remaining` hint: absent/null → null; a
/// `{daily:num, monthly:num}` map → ints; any other present shape throws
/// [FormatException] (a malformed hint is a contract break, unlike a lenient
/// display-only category). Accepts any `num` so a value delivered as a double
/// over the channel never spuriously fails.
CoachRemaining? _remainingFromCallable(Object? raw) {
  if (raw == null) return null;
  if (raw is! Map) {
    throw FormatException('coachProxy: "remaining" is ${raw.runtimeType}');
  }
  final daily = raw['daily'];
  final monthly = raw['monthly'];
  if (daily is! num) {
    throw FormatException('coachProxy: "remaining.daily" is ${daily.runtimeType}');
  }
  if (monthly is! num) {
    throw FormatException(
      'coachProxy: "remaining.monthly" is ${monthly.runtimeType}',
    );
  }
  return CoachRemaining(daily: daily.toInt(), monthly: monthly.toInt());
}

/// Boundary enforcement for the callable error surface (ADR-017 Decision 5),
/// code-first with a `details.reason` refinement second. Every frozen wire
/// outcome lands in exactly one member; a dropped `details.reason` degrades to
/// honest-generic copy, never to a wrong claim.
CoachException mapCoachFailure(Object failure) {
  if (failure is FirebaseFunctionsException) {
    final reason = _reasonOf(failure.details);
    return switch (failure.code) {
      'permission-denied' => const CoachNotMemberException(),
      // failed-precondition maps to not-premium on CODE alone (reason is
      // confirmation, not requirement) — the server emits no other
      // failed-precondition here, and the mapping must survive a dropped detail.
      'failed-precondition' => const CoachNotPremiumException(),
      'resource-exhausted' => switch (reason) {
        'cap-daily' => const CoachDailyCapException(),
        'cap-monthly' => const CoachMonthlyCapException(),
        'rate-limited' => const CoachRateLimitedException(),
        // Reason absent or junk: the channel dropped the discriminator — claim
        // neither "tomorrow" nor "this month".
        _ => const CoachLimitReachedException(),
      },
      'unavailable' || 'deadline-exceeded' => const CoachUnavailableException(),
      // invalid-argument, internal, unauthenticated, … keep the raw code +
      // static server message under the generic surface.
      _ => CoachUnknownException(code: failure.code, message: failure.message),
    };
  }
  // Deliberate deviation from the pairing mold (ADR-017 Decision 5): the mold's
  // terminal fallback stringifies '$failure', which for the coach could carry
  // conversation content into Crashlytics via the error hooks. Record ONLY the
  // runtimeType — never the throwable's stringification.
  return CoachUnknownException(
    code: 'unexpected',
    message: failure.runtimeType.toString(),
  );
}

/// Defensively extracts the `reason` discriminator from a callable's `details`
/// payload: it crosses the platform channel as a plain `Map` (never typed), so
/// a non-map or a non-string `reason` yields null rather than throwing (the
/// pairing `_reasonOf` mold).
String? _reasonOf(Object? details) {
  if (details is Map) {
    final reason = details['reason'];
    if (reason is String) return reason;
  }
  return null;
}
