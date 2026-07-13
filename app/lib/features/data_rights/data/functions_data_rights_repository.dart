import 'package:cloud_functions/cloud_functions.dart';

import '../../../core/firebase/firebase_bootstrap.dart';
import '../domain/data_export.dart';
import '../domain/data_rights_exception.dart';
import '../domain/data_rights_repository.dart';

/// The wire-level literal the `deleteAccount` request carries (ADR-019 D2). It is
/// NEVER typed by a user (no localization / screen-reader surface), so no client
/// bug can invoke deletion by accident — the app SENDS it, the server checks it
/// verbatim, anything else is `invalid-argument`.
const String kDeleteAccountConfirmLiteral = 'DELETE';

/// [DataRightsRepository] backed by the `deleteAccount` / `exportData` /
/// `updateNotificationPrivacy` callables (ADR-019 Decisions 2/5/6). Thin adapter:
/// every failure crossing this boundary is mapped into the [DataRightsException]
/// taxonomy — nothing but a [DataRightsException] escapes the data layer (the
/// controller/screens catch only that), and a malformed export body never renders
/// as a document. The parse/map logic lives in the pure top-level functions here
/// and in `data_export.dart`, so it is exhaustively unit-testable without a live
/// callable (the M2.2 thin-adapter precedent: the adapter is untested, the
/// mappers are fully tested).
class FunctionsDataRightsRepository implements DataRightsRepository {
  /// [functions] defaults to the region-scoped instance the emulator wiring in
  /// `firebase_bootstrap.dart` also resolves (instanceFor caches per app+region),
  /// so a `USE_FUNCTIONS_EMULATOR` run reaches the emulator without any extra
  /// plumbing here.
  FunctionsDataRightsRepository({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: kFunctionsRegion);

  final FirebaseFunctions _functions;

  @override
  Future<void> deleteAccount() async {
    try {
      await _functions.httpsCallable('deleteAccount').call<Object?>({
        'confirm': kDeleteAccountConfirmLiteral,
      });
    } catch (failure) {
      throw mapDataRightsFailure(failure);
    }
  }

  @override
  Future<DataExport> exportData() async {
    try {
      final result = await _functions
          .httpsCallable('exportData')
          .call<Object?>();
      return decodeOrThrowDataExport(result.data);
    } on DataRightsException {
      // A malformed-body conversion (decodeOrThrowDataExport) is already in the
      // taxonomy — rethrow it unchanged rather than re-wrapping via the generic
      // mapper below.
      rethrow;
    } catch (failure) {
      throw mapDataRightsFailure(failure);
    }
  }

  @override
  Future<void> updateNotificationPrivacy({required bool discreet}) async {
    try {
      await _functions.httpsCallable('updateNotificationPrivacy').call<Object?>(
        {'discreet': discreet},
      );
    } catch (failure) {
      throw mapDataRightsFailure(failure);
    }
  }

  @override
  Future<void> recordConsent({required bool withdraw}) async {
    try {
      // The client sends ONLY `{withdraw}` — the server stamps its own
      // CURRENT_LEGAL_VERSION on a grant (ADR-023 D4), so there is no
      // client-claimed version to send or to mismatch.
      await _functions.httpsCallable('recordConsent').call<Object?>({
        'withdraw': withdraw,
      });
    } catch (failure) {
      throw mapDataRightsFailure(failure);
    }
  }
}

/// Decodes the `exportData` payload into a [DataExport], converting a parse
/// [FormatException] to a [DataRightsException] INSIDE the data layer: the caller
/// catches only [DataRightsException], so a raw [FormatException] must never
/// escape. The conversion drops the FormatException text entirely
/// ([DataRightsUnknownException.message] stays null) — belt-and-suspenders on the
/// no-content rule, since the message would only ever hold runtimeTypes/field
/// names anyway.
DataExport decodeOrThrowDataExport(Object? data) {
  try {
    return dataExportFromCallable(data);
  } on FormatException {
    throw const DataRightsUnknownException(code: 'malformed-response');
  }
}

/// Boundary enforcement for the data-rights callable error surface (ADR-019 D2,
/// the coach taxonomy), code-first with a `details.reason` refinement second.
/// Transient availability → network (retry is honest advice); the new
/// `failed-precondition` + `profile-missing` reason (also returned by the tightened
/// `createInvite`) → the typed profile-missing member; everything else keeps its
/// raw code + static server message under the generic surface.
DataRightsException mapDataRightsFailure(Object failure) {
  if (failure is DataRightsException) return failure;
  if (failure is FirebaseFunctionsException) {
    final reason = _reasonOf(failure.details);
    return switch (failure.code) {
      'unavailable' ||
      'deadline-exceeded' => const DataRightsNetworkException(),
      'failed-precondition' when reason == 'profile-missing' =>
        const DataRightsProfileMissingException(),
      _ => DataRightsUnknownException(
        code: failure.code,
        message: failure.message,
      ),
    };
  }
  // The coach no-content posture (deliberate deviation from the invite mold's
  // '$failure' stringification): record ONLY the runtimeType — never the
  // throwable's stringification, which could carry export content or identifiers.
  return DataRightsUnknownException(
    code: 'unexpected',
    message: failure.runtimeType.toString(),
  );
}

/// Defensively extracts the `reason` discriminator from a callable's `details`
/// payload: it crosses the platform channel as a plain `Map` (never typed), so a
/// non-map or a non-string `reason` yields null rather than throwing (the coach
/// `_reasonOf` mold).
String? _reasonOf(Object? details) {
  if (details is Map) {
    final reason = details['reason'];
    if (reason is String) return reason;
  }
  return null;
}
