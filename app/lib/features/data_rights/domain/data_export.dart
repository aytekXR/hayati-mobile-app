import 'dart:convert';

/// The typed envelope returned by the `exportData` callable (ADR-019 Decision 5).
///
/// The wire contract is frozen by the committed server half: `{ formatVersion,
/// generatedAt (ISO string), uid, data: {…} }`. The app renders [data] AS-IS —
/// answers carry `questionId` only (never question text; the export's own `note`
/// field says so), so the export screen never tries to resolve wording. Only the
/// four envelope fields are typed here; the nested [data] tree is kept as a
/// JSON-safe map so the screen can pretty-print the exact server document.
class DataExport {
  const DataExport({
    required this.formatVersion,
    required this.generatedAt,
    required this.uid,
    required this.data,
  });

  /// The export shape version (Decision 5): `1` today. A future shape change
  /// bumps this, so a renderer can stay honest about what it is showing.
  final int formatVersion;

  /// The ISO-8601 instant the export was generated (server clock).
  final String generatedAt;

  /// The subject uid — the requester's own.
  final String uid;

  /// The scrubbed export body, exactly as the server assembled it, normalized to
  /// JSON-safe types (string keys, num/String/bool/null leaves, lists, maps).
  final Map<String, Object?> data;

  /// The full envelope, pretty-printed for the export screen (selectable,
  /// copyable). Deterministic 2-space indentation over the frozen field order.
  String toPrettyJson() => const JsonEncoder.withIndent('  ').convert({
    'formatVersion': formatVersion,
    'generatedAt': generatedAt,
    'uid': uid,
    'data': data,
  });
}

/// Decodes the `exportData` callable payload into a [DataExport]. Pure and loud:
/// an unexpected envelope shape throws [FormatException] (converted to the sealed
/// unknown member at the data-layer boundary) rather than rendering a half-built
/// document. Every message interpolates ONLY a `.runtimeType` or a field name —
/// never a value — because the export body is the user's own personal data and
/// Crashlytics is on in prod (the coach no-content rule, applied to export).
DataExport dataExportFromCallable(Object? raw) {
  if (raw is! Map) {
    throw FormatException('exportData: expected a map, got ${raw.runtimeType}');
  }
  final formatVersion = raw['formatVersion'];
  // The platform channel decodes JSON integers as int, but accept any num so a
  // value delivered as a double never spuriously fails the map.
  if (formatVersion is! num) {
    throw FormatException(
      'exportData: "formatVersion" is ${formatVersion.runtimeType}',
    );
  }
  final generatedAt = raw['generatedAt'];
  if (generatedAt is! String) {
    throw FormatException(
      'exportData: "generatedAt" is ${generatedAt.runtimeType}',
    );
  }
  final uid = raw['uid'];
  if (uid is! String) {
    throw FormatException('exportData: "uid" is ${uid.runtimeType}');
  }
  final data = raw['data'];
  if (data is! Map) {
    throw FormatException('exportData: "data" is ${data.runtimeType}');
  }
  return DataExport(
    formatVersion: formatVersion.toInt(),
    generatedAt: generatedAt,
    uid: uid,
    data: normalizeExportJson(data)! as Map<String, Object?>,
  );
}

/// Recursively re-keys the channel-decoded tree into JSON-safe Dart types: every
/// map becomes `Map<String, Object?>` (the callable delivers maps as
/// `Map<Object?, Object?>`), lists stay lists, and leaves pass through. Pure and
/// total — needed so [DataExport.toPrettyJson] never trips over a non-String key.
Object? normalizeExportJson(Object? value) {
  if (value is Map) {
    return <String, Object?>{
      for (final entry in value.entries)
        entry.key.toString(): normalizeExportJson(entry.value),
    };
  }
  if (value is List) {
    return <Object?>[for (final item in value) normalizeExportJson(item)];
  }
  return value;
}
