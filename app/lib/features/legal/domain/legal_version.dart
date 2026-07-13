/// The current legal-bundle version this app binary expects (ADR-023 Decision 4).
///
/// This is one of THREE version sources pinned together by the app-side
/// three-way source-sentinel test (`legal_version_sentinel_test.dart`):
///
///  1. this Dart const,
///  2. the Functions `CURRENT_LEGAL_VERSION` constant
///     (`functions/src/data-rights/data-rights-core.ts`),
///  3. the `version:` line in `docs/legal/README.md`.
///
/// All three MUST carry the same integer, or CI fails red — in both directions:
/// the app-ahead brick (the gate expects a version the server never stamps) AND
/// the silent under-gate (the documents change but no re-consent fires). A
/// material change to any legal document therefore requires a SAME-DIFF bump of
/// all three sources together (the bump procedure + deploy-ordering rule live in
/// `docs/legal/README.md`); a non-material fix (typo, clarification) bumps
/// nothing and re-gates no one.
///
/// The client never SENDS this version — the `recordConsent` callable stamps the
/// server's own constant onto a grant. This const drives only the gate's
/// `hasCurrentConsent` expectation (the residual skew, app-const-ahead-of-server,
/// surfaces as the gate's persistent stale-after-accept error, never a brick).
const int currentLegalVersion = 1;
