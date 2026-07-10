import 'dart:async';

import 'package:hayati_app/features/daily_question/domain/couple_day_assignment.dart';
import 'package:hayati_app/features/daily_question/domain/couple_day_repository.dart';

/// Hand-written fake for the day-assignment watch (M3.3). A missing seeded
/// day replays null — the honest no-day-yet state the paired home renders
/// while the rollover has not assigned today's doc; [emitDay] then models
/// the assignment streaming in live (ADR-011: the server is authoritative).
class FakeCoupleDayRepository implements CoupleDayRepository {
  FakeCoupleDayRepository({Map<String, CoupleDayAssignment>? initialDays})
    : _days = {...?initialDays};

  /// Keyed `'$coupleId/$dayKey'`.
  final Map<String, CoupleDayAssignment> _days;
  final Map<String, StreamController<CoupleDayAssignment?>> _controllers = {};

  static String keyFor(String coupleId, String dayKey) => '$coupleId/$dayKey';

  StreamController<CoupleDayAssignment?> _controllerFor(String key) =>
      _controllers.putIfAbsent(
        key,
        StreamController<CoupleDayAssignment?>.broadcast,
      );

  /// Pushes an external day event (the hourly rollover landing the doc).
  void emitDay(String coupleId, String dayKey, CoupleDayAssignment? day) {
    final key = keyFor(coupleId, dayKey);
    if (day == null) {
      _days.remove(key);
    } else {
      _days[key] = day;
    }
    _controllerFor(key).add(day);
  }

  /// Pushes a stream failure (mapped CoupleDataException) to [watchDay]
  /// listeners.
  void emitError(String coupleId, String dayKey, Object error) {
    _controllerFor(keyFor(coupleId, dayKey)).addError(error);
  }

  @override
  Stream<CoupleDayAssignment?> watchDay(String coupleId, String dayKey) async* {
    final key = keyFor(coupleId, dayKey);
    yield _days[key];
    // await-for (not yield*) so an emitted error TERMINATES this stream,
    // exactly like the real repository's generator.
    await for (final day in _controllerFor(key).stream) {
      yield day;
    }
  }

  Future<void> dispose() async {
    for (final controller in _controllers.values) {
      await controller.close();
    }
  }
}
