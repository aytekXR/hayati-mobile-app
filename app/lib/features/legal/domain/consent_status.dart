import '../../profile/domain/relationship_profile.dart';
import 'legal_version.dart';

/// Whether [profile] carries a valid consent AT OR ABOVE the version this app
/// binary expects (ADR-023 Decision 3/4) — the sole predicate the
/// `OnboardingGate` consent branch reads.
///
/// Pure and total: a null [Consent] (absent OR junk-shaped, per the fail-closed
/// parse in `profile_dto.dart`) is not-consented, so the gate shows. A stored
/// version BELOW `currentLegalVersion` (a material policy revision the user has
/// not re-consented to) is also not-consented — the version-bump re-gate.
///
/// The boundary is `>=`, deliberately: a consent stamped at exactly the current
/// version passes. (This `>=` is mutation-checked: tightening it to `>` must
/// turn the version-equals-const test red.)
bool hasCurrentConsent(RelationshipProfile profile) {
  final consent = profile.consent;
  return consent != null && consent.version >= currentLegalVersion;
}
