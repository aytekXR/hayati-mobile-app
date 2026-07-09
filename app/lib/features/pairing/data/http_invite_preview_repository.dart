import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../../core/firebase/firebase_bootstrap.dart';
import '../domain/invite_exception.dart';
import '../domain/invite_preview.dart';
import '../domain/invite_preview_repository.dart';

/// [InvitePreviewRepository] over a plain `package:http` [http.Client] and a
/// pre-derived [baseUri] (see [invitePreviewUri]). The preview is an
/// unauthenticated HTTP GET — NOT a callable — so it carries no App Check /
/// auth plumbing; every transport failure crossing this boundary is mapped
/// into the [InviteException] taxonomy, anything else escaping is a bug.
class HttpInvitePreviewRepository implements InvitePreviewRepository {
  HttpInvitePreviewRepository({required this._client, required this._baseUri});

  final http.Client _client;
  final Uri _baseUri;

  @override
  Future<InvitePreviewResult> preview(String code) async {
    final uri = _baseUri.replace(
      queryParameters: <String, String>{
        ..._baseUri.queryParameters,
        'code': code,
      },
    );
    final http.Response response;
    try {
      response = await _client.get(uri);
    } on SocketException catch (failure) {
      throw InviteNetworkException(message: '$failure');
    } on http.ClientException catch (failure) {
      throw InviteNetworkException(message: '$failure');
    }
    return _mapResponse(response);
  }

  InvitePreviewResult _mapResponse(http.Response response) {
    final status = response.statusCode;
    if (status == 200) {
      try {
        return invitePreviewResultFromBody(response.body);
      } on FormatException catch (failure) {
        // A 200 with an unparseable/off-contract body is not the user's fault
        // and not retryable — surface it as unknown, keeping a diagnostic code.
        throw InviteUnknownException(
          code: 'malformed-preview',
          message: '$failure',
        );
      }
    }
    // Rate limit (429, the preview's per-IP window) and any 5xx are transient:
    // retrying is honest advice. Everything else (4xx contract violations)
    // keeps its raw status under the generic surface.
    if (status == 429 || status >= 500) {
      throw InviteNetworkException(message: 'HTTP $status');
    }
    throw InviteUnknownException(code: 'http-$status');
  }
}

/// Pure, loud parse of the `invitePreview` 200 body — the mirror of the
/// server's `InvitePreview` projection. An off-contract shape (bad JSON,
/// non-map, unknown `status`, non-string `creatorDisplayName`) throws
/// [FormatException] rather than yielding a half-built result; the boundary
/// turns that into [InviteUnknownException].
InvitePreviewResult invitePreviewResultFromBody(String body) {
  final decoded = jsonDecode(body);
  if (decoded is! Map) {
    throw FormatException(
      'invitePreview: expected a map, got ${decoded.runtimeType}',
    );
  }
  final status = switch (decoded['status']) {
    'valid' => InvitePreviewStatus.valid,
    'expired' => InvitePreviewStatus.expired,
    'unknown' => InvitePreviewStatus.unknown,
    final other => throw FormatException('invitePreview: "status" is "$other"'),
  };
  final rawName = decoded['creatorDisplayName'];
  if (rawName != null && rawName is! String) {
    throw FormatException(
      'invitePreview: "creatorDisplayName" is ${rawName.runtimeType}',
    );
  }
  return InvitePreviewResult(
    status: status,
    creatorDisplayName: rawName as String?,
  );
}

/// Derives the `invitePreview` HTTP endpoint. Pure over its inputs (the
/// defaults read the emulator constants from `firebase_bootstrap.dart`) so both
/// branches are unit-testable without a running app:
///
/// - emulator ([useEmulator]) → `http://{host}:{port}/demo-hayati/{region}/
///   invitePreview`. The functions emulator routes by URL PATH and serves ONLY
///   the `demo-hayati` project (PR #23 lesson), whatever the flavor's real id.
/// - production → `https://{region}-{projectId}.cloudfunctions.net/
///   invitePreview`, with `projectId` taken from [firebaseOptionsFor].
Uri invitePreviewUri({
  required AppFlavor flavor,
  bool useEmulator = kUseFunctionsEmulator,
  String emulatorHost = kAuthEmulatorHost,
  int emulatorPort = kFunctionsEmulatorPort,
}) {
  if (useEmulator) {
    return Uri.parse(
      'http://$emulatorHost:$emulatorPort'
      '/demo-hayati/$kFunctionsRegion/invitePreview',
    );
  }
  final projectId = firebaseOptionsFor(flavor).projectId;
  return Uri.parse(
    'https://$kFunctionsRegion-$projectId.cloudfunctions.net/invitePreview',
  );
}
