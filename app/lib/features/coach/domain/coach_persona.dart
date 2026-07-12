/// The three coach personas (PRD F5), mirroring the server's closed union
/// `COACH_PERSONA_IDS` in `functions/src/coach/provider-port.ts`. The wire value
/// sent to `coachProxy` is the Dart `.name` — a verbatim match with the server
/// union (`'coach'` / `'dateGenie'` / `'giftGenie'`), so renaming a member is a
/// wire-contract migration, not a refactor (the `QuestionCategory` precedent,
/// where the wire names ARE the Dart names).
enum CoachPersonaId { coach, dateGenie, giftGenie }
