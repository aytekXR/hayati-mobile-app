import 'package:hayati_app/features/daily_question/domain/question.dart';
import 'package:hayati_app/features/daily_question/domain/question_pack_repository.dart';

/// Hand-written fake for the generic by-id pack seam (M3.3 paired home).
/// Serves only what is seeded; an unseeded id throws
/// [UnknownQuestionPackException] exactly like the asset repository's
/// absent-asset path, so the pack-lag state is the fake's default for a
/// typo'd id rather than a silent fixture.
class FakeQuestionPackRepository implements QuestionPackRepository {
  FakeQuestionPackRepository({Map<String, QuestionPack>? packs})
    : _packs = {...?packs};

  final Map<String, QuestionPack> _packs;

  /// Behaviour override for the next [loadPack] calls (failure /
  /// never-completing states).
  Future<QuestionPack> Function(String packId)? onLoadPack;

  int loadCalls = 0;

  void seedPack(QuestionPack pack) => _packs[pack.packId] = pack;

  @override
  Future<QuestionPack> loadPack(String packId) {
    loadCalls++;
    final handler = onLoadPack;
    if (handler != null) return handler(packId);
    final pack = _packs[packId];
    if (pack == null) {
      return Future.error(UnknownQuestionPackException(packId));
    }
    return Future.value(pack);
  }
}
