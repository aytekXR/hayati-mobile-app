import '../domain/couple_entitlement.dart';

/// Wire mapping for `subscriptions/{coupleId}` (M4.1, ADR-013 Decision 5).
/// Pure function over a plain map — same boundary discipline as
/// `coupleFromMap`: an absent field falls back to the free/zero-state, a
/// present-but-wrong-typed field fails loudly, and no Firestore type crosses
/// into the domain.
///
/// The webhook (admin SDK) is the sole writer of this doc; the app reads only
/// the summary fields. The server-bookkeeping `lanes` map and the `updatedAt`
/// serverTimestamp are deliberately NOT parsed — the domain model does not
/// consume them (don't map what you don't read).
///
/// `expiresAtMs` is a plain epoch-ms int on the wire (ADR-013:
/// `expiresAtMs: number|null`), NOT a Firestore `Timestamp`. Unlike the
/// profile/day/answer repositories — whose `_domainReady` shim exists only to
/// keep the `Timestamp` SDK type out of the pure mapper — this mapper owns the
/// `int → DateTime.fromMillisecondsSinceEpoch(isUtc: true)` conversion
/// directly and names the wire field in its loud throw. The missed-conversion
/// guard survives in one layer: any non-int (including a drifted `Timestamp`)
/// is rejected loudly rather than silently voiding the expiry.
CoupleEntitlement coupleEntitlementFromMap(Map<String, dynamic> data) =>
    CoupleEntitlement(
      entitled: _boolField(data, 'entitled'),
      productId: _optionalString(data, 'productId'),
      periodType: _optionalString(data, 'periodType'),
      expiresAt: _optionalMsTimestamp(data, 'expiresAtMs'),
      willRenew: _boolField(data, 'willRenew'),
      store: _optionalString(data, 'store'),
      environment: _optionalString(data, 'environment'),
    );

/// Absent (or explicit null) → false, the free/zero-state default: a doc that
/// predates a field reads as un-entitled rather than throwing (ADR-013: absent
/// = free until the webhook proves otherwise). Present but not a bool is drift
/// and fails loudly.
bool _boolField(Map<String, dynamic> data, String field) {
  final raw = data[field];
  if (raw == null) return false;
  if (raw is! bool) {
    throw FormatException(
      'subscriptions doc field "$field": expected a bool, '
      'got ${raw.runtimeType}',
    );
  }
  return raw;
}

/// Absent (or explicit null) → null; present but not a string → loud
/// [FormatException], matching `coupleFromMap`'s field-guard style.
String? _optionalString(Map<String, dynamic> data, String field) {
  final raw = data[field];
  if (raw == null) return null;
  if (raw is! String) {
    throw FormatException(
      'subscriptions doc field "$field": expected a string, '
      'got ${raw.runtimeType}',
    );
  }
  return raw;
}

/// Reads the entitled-until as a wire epoch-ms int and crosses it as a UTC
/// [DateTime]: absent (or explicit null) → null (non-expiring — ADR-013: a
/// null `expiresAtMs` is the non-expiring sentinel); present int → the
/// millisecond instant; anything else (a String, a double, a stray
/// `Timestamp`) is a missed/wrong conversion and fails loudly.
DateTime? _optionalMsTimestamp(Map<String, dynamic> data, String field) {
  final raw = data[field];
  if (raw == null) return null;
  if (raw is! int) {
    throw FormatException(
      'subscriptions doc field "$field": expected an epoch-ms int, '
      'got ${raw.runtimeType}',
    );
  }
  return DateTime.fromMillisecondsSinceEpoch(raw, isUtc: true);
}
