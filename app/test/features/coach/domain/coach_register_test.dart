import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/coach/domain/coach_persona.dart';
import 'package:hayati_app/features/coach/domain/coach_register.dart';
import 'package:hayati_app/features/profile/domain/relationship_profile.dart';

void main() {
  group('coachRegisterFor — total over ContentLanguage × ContentRegister', () {
    test('Turkish splits on register', () {
      expect(
        coachRegisterFor(ContentLanguage.tr, ContentRegister.playful),
        CoachRegister.trPlayful,
      );
      expect(
        coachRegisterFor(ContentLanguage.tr, ContentRegister.respectful),
        CoachRegister.trRespectful,
      );
    });

    test('Arabic resolves to the Gulf register regardless of register', () {
      expect(
        coachRegisterFor(ContentLanguage.ar, ContentRegister.playful),
        CoachRegister.arGulfRespectful,
      );
      expect(
        coachRegisterFor(ContentLanguage.ar, ContentRegister.respectful),
        CoachRegister.arGulfRespectful,
      );
    });

    test('English resolves to neutral regardless of register', () {
      expect(
        coachRegisterFor(ContentLanguage.en, ContentRegister.playful),
        CoachRegister.enNeutral,
      );
      expect(
        coachRegisterFor(ContentLanguage.en, ContentRegister.respectful),
        CoachRegister.enNeutral,
      );
    });

    test('is total over the full 3×2 product (every pair maps)', () {
      for (final language in ContentLanguage.values) {
        for (final register in ContentRegister.values) {
          // A missing case would be a compile-time switch error; this pins the
          // runtime totality across all six pairs producing a valid member.
          expect(
            CoachRegister.values,
            contains(coachRegisterFor(language, register)),
          );
        }
      }
    });
  });

  group('wire parity with the server union COACH_REGISTERS', () {
    test('the four .wire strings are byte-equal to the server spelling', () {
      expect(CoachRegister.trPlayful.wire, 'tr-playful');
      expect(CoachRegister.trRespectful.wire, 'tr-respectful');
      expect(CoachRegister.arGulfRespectful.wire, 'ar-gulf-respectful');
      expect(CoachRegister.enNeutral.wire, 'en-neutral');
    });

    test('.name is NOT the wire value (hyphens make that impossible)', () {
      // Guards against a regression that drops the explicit [wire] field and
      // sends `.name` — which validateCoachRequest would reject (bad-register).
      for (final register in CoachRegister.values) {
        expect(register.wire, isNot(register.name));
      }
    });
  });

  group('CoachPersonaId wire parity with COACH_PERSONA_IDS', () {
    test('.name matches the server union verbatim', () {
      expect(CoachPersonaId.coach.name, 'coach');
      expect(CoachPersonaId.dateGenie.name, 'dateGenie');
      expect(CoachPersonaId.giftGenie.name, 'giftGenie');
    });
  });
}
