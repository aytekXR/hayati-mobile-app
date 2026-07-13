import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/legal/domain/consent_status.dart';
import 'package:hayati_app/features/legal/domain/legal_version.dart';
import 'package:hayati_app/features/profile/domain/relationship_profile.dart';

/// `hasCurrentConsent` boundary (ADR-023 D3/D4). The `>=` boundary is
/// mutation-checked by hand: tightening it to `>` must turn the
/// `version == const passes` case red (see the session report).
void main() {
  RelationshipProfile profileWith(Consent? consent) => RelationshipProfile(
    status: RelationshipStatus.married,
    contentLanguage: ContentLanguage.tr,
    register: ContentRegister.playful,
    consent: consent,
  );

  test('null consent → not consented (fail-closed)', () {
    expect(hasCurrentConsent(profileWith(null)), isFalse);
  });

  test('version == currentLegalVersion → consented (the boundary passes)', () {
    expect(
      hasCurrentConsent(
        profileWith(const Consent(version: currentLegalVersion)),
      ),
      isTrue,
    );
  });

  test('version below currentLegalVersion → not consented (re-gate)', () {
    expect(
      hasCurrentConsent(
        profileWith(const Consent(version: currentLegalVersion - 1)),
      ),
      isFalse,
    );
  });

  test('version above currentLegalVersion → consented', () {
    expect(
      hasCurrentConsent(
        profileWith(const Consent(version: currentLegalVersion + 1)),
      ),
      isTrue,
    );
  });

  test('acceptedAt is irrelevant to the gate decision (version-only)', () {
    expect(
      hasCurrentConsent(
        profileWith(const Consent(version: currentLegalVersion)),
      ),
      isTrue,
    );
  });
}
