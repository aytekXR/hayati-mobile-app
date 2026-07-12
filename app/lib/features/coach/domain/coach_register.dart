import '../../profile/domain/relationship_profile.dart';

/// The brandkit register ids the coach wire accepts (ADR-017 Decision 1),
/// mirroring the server's closed union `COACH_REGISTERS` in
/// `functions/src/coach/provider-port.ts`. [wire] is the hyphenated schema
/// spelling — `.name` CANNOT be the wire value here (a Dart identifier admits no
/// hyphen), so the enum carries an explicit [wire] string, exactly the
/// `QuestionRegister.msaGulf` / `'msa_gulf'` precedent. A naive `.name` send
/// would be rejected by `validateCoachRequest` (`bad-register`).
enum CoachRegister {
  trPlayful('tr-playful'),
  trRespectful('tr-respectful'),
  arGulfRespectful('ar-gulf-respectful'),
  enNeutral('en-neutral');

  const CoachRegister(this.wire);

  final String wire;
}

/// Maps the profile's ([ContentLanguage], [ContentRegister]) pair to the single
/// [CoachRegister] the wire accepts (ADR-017 Decision 1). Total over the full
/// 3×2 product: Turkish splits on register (playful vs respectful); Arabic
/// always resolves to the Gulf-respectful register and English to neutral (both
/// ship a single register, so [register] is not consulted for them). Pure — the
/// composer is only constructible from a settled non-null profile, so every send
/// has a derivable register by construction.
CoachRegister coachRegisterFor(
  ContentLanguage language,
  ContentRegister register,
) => switch (language) {
  ContentLanguage.tr => register == ContentRegister.playful
      ? CoachRegister.trPlayful
      : CoachRegister.trRespectful,
  ContentLanguage.ar => CoachRegister.arGulfRespectful,
  ContentLanguage.en => CoachRegister.enNeutral,
};
