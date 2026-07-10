import 'dart:async';

import 'package:hayati_app/features/daily_question/domain/couple.dart';
import 'package:hayati_app/features/daily_question/domain/couple_repository.dart';

/// Hand-written fake backing the paired-home tests (M3.3). Same contract
/// fidelity as [FakeProfileRepository]: [watchCouple] replays the CURRENT
/// value immediately on listen, then live updates — the paired home depends
/// on that first emission to leave its loading state.
class FakeCoupleRepository implements CoupleRepository {
  FakeCoupleRepository({Map<String, Couple>? initialCouples})
    : _couples = {...?initialCouples};

  final Map<String, Couple> _couples;
  final Map<String, StreamController<Couple?>> _controllers = {};

  StreamController<Couple?> _controllerFor(String coupleId) =>
      _controllers.putIfAbsent(coupleId, StreamController<Couple?>.broadcast);

  /// Pushes an external couple event (e.g. a server-side field change).
  void emitCouple(String coupleId, Couple? couple) {
    if (couple == null) {
      _couples.remove(coupleId);
    } else {
      _couples[coupleId] = couple;
    }
    _controllerFor(coupleId).add(couple);
  }

  /// Pushes a stream failure (mapped CoupleDataException) to [watchCouple]
  /// listeners — the paired home's error state.
  void emitError(String coupleId, Object error) {
    _controllerFor(coupleId).addError(error);
  }

  @override
  Stream<Couple?> watchCouple(String coupleId) async* {
    yield _couples[coupleId];
    // await-for (not yield*) so an emitted error TERMINATES this stream,
    // exactly like the real repository's generator.
    await for (final couple in _controllerFor(coupleId).stream) {
      yield couple;
    }
  }

  Future<void> dispose() async {
    for (final controller in _controllers.values) {
      await controller.close();
    }
  }
}
