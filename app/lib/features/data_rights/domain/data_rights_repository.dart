import 'data_export.dart';

/// The app's port to the M6.2 data-rights callables (ADR-019 Decisions 2/5/6).
/// Every method is TOTAL over [DataRightsException]: the implementation maps
/// every failure crossing this boundary into that taxonomy, and a malformed
/// export body never escapes as a half-built document.
abstract interface class DataRightsRepository {
  /// Invokes the hard cascade `deleteAccount` callable (Decision 2). The frozen
  /// `{ confirm: 'DELETE' }` literal is sent by the implementation — never typed
  /// by a user — so no client bug can invoke deletion by accident. Re-driving is
  /// safe (the cascade is idempotent). Throws only [DataRightsException].
  Future<void> deleteAccount();

  /// Fetches the self-serve export (Decision 5) as a typed [DataExport] envelope.
  /// Throws only [DataRightsException].
  Future<DataExport> exportData();

  /// Sets or clears the per-user discreet-notification override (Decision 6):
  /// `true` writes `notificationPrivacy: 'discreet'`, `false` deletes it. Throws
  /// only [DataRightsException].
  Future<void> updateNotificationPrivacy({required bool discreet});

  /// Records or withdraws the special-category consent (ADR-023 Decision 4) via
  /// the `recordConsent` callable. `withdraw: false` GRANTS — the server stamps
  /// its own `CURRENT_LEGAL_VERSION`, `acceptedAt`, and `ageAttested` (the client
  /// sends no version). `withdraw: true` CLEARS the stored consent. The gate/hub
  /// react only to the streamed `users/{uid}.consent` field this write produces —
  /// there is no optimistic local grant. Throws only [DataRightsException].
  Future<void> recordConsent({required bool withdraw});
}
