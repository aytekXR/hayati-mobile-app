import 'dart:convert';

import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../domain/question.dart';
import '../domain/question_pack_repository.dart';
import 'question_pack_dto.dart';

/// Loads bundled question packs from `app/assets/content/<packId>.json`
/// (M3.1 — the generalized successor of the M2.4 solo asset loader; the
/// assets are the validator-synced copies of `content/packs/`, ADR-010).
/// The bundle is injectable so the plain test VM can feed fixture bytes;
/// production uses [rootBundle].
///
/// Beyond the schema-shape validation in [questionPackFromJson], this
/// enforces the id contract: the loaded document's `packId` must be the one
/// requested — a swapped or misnamed asset must not serve another pack's
/// content under this id.
class AssetQuestionPackRepository implements QuestionPackRepository {
  const AssetQuestionPackRepository({this._bundle});

  final AssetBundle? _bundle;

  static String assetPathFor(String packId) => 'assets/content/$packId.json';

  @override
  Future<QuestionPack> loadPack(String packId) async {
    final bundle = _bundle ?? rootBundle;
    final String raw;
    try {
      raw = await bundle.loadString(assetPathFor(packId));
    } on FlutterError {
      // AssetBundle throws FlutterError for an absent key: that is the M3.3
      // pack-lag state (a day doc referencing a pack this install does not
      // bundle), typed so the paired home can render it honestly instead of
      // as a generic packaging error.
      throw UnknownQuestionPackException(packId);
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw FormatException(
        'question pack asset "$packId": expected a JSON object, '
        'got ${decoded.runtimeType}',
      );
    }
    final pack = questionPackFromJson(decoded);
    if (pack.packId != packId) {
      throw FormatException(
        'question pack asset "$packId": document declares packId '
        '"${pack.packId}" — asset name and packId must agree',
      );
    }
    return pack;
  }
}
