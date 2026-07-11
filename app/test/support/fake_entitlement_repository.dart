import 'dart:async';

import 'package:hayati_app/features/entitlements/domain/couple_entitlement.dart';
import 'package:hayati_app/features/entitlements/domain/entitlement_repository.dart';

/// Hand-written fake backing the entitlement provider tests (M4.1). Same
/// contract fidelity as [FakeCoupleRepository]: [watchEntitlement] replays the
/// CURRENT value immediately on listen, then live updates — the isPremium
/// derivation depends on that first emission to leave its loading state.
class FakeEntitlementRepository implements EntitlementRepository {
  FakeEntitlementRepository({Map<String, CoupleEntitlement?>? initialMirrors})
    : _mirrors = {...?initialMirrors};

  final Map<String, CoupleEntitlement?> _mirrors;
  final Map<String, StreamController<CoupleEntitlement?>> _controllers = {};

  StreamController<CoupleEntitlement?> _controllerFor(String coupleId) =>
      _controllers.putIfAbsent(
        coupleId,
        StreamController<CoupleEntitlement?>.broadcast,
      );

  /// Pushes an external mirror event (e.g. a webhook write, or the doc being
  /// deleted → null = back to the free tier).
  void emit(String coupleId, CoupleEntitlement? entitlement) {
    _mirrors[coupleId] = entitlement;
    _controllerFor(coupleId).add(entitlement);
  }

  /// Pushes a stream failure (mapped EntitlementDataException) to
  /// [watchEntitlement] listeners.
  void emitError(String coupleId, Object error) {
    _controllerFor(coupleId).addError(error);
  }

  @override
  Stream<CoupleEntitlement?> watchEntitlement(String coupleId) async* {
    yield _mirrors[coupleId];
    // await-for (not yield*) so an emitted error TERMINATES this stream,
    // exactly like the real repository's generator.
    await for (final entitlement in _controllerFor(coupleId).stream) {
      yield entitlement;
    }
  }

  Future<void> dispose() async {
    for (final controller in _controllers.values) {
      await controller.close();
    }
  }
}
