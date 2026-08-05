import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../../../core/firebase/firebase_bootstrap.dart';
import '../domain/push_token_repository.dart';

/// [PushTokenRepository] backed by the `registerPushToken` /
/// `unregisterPushToken` callables (ADR-042 Decision 1).
///
/// Thin adapter, on the `FunctionsDataRightsRepository` mold — but with one
/// deliberate difference: **nothing here throws.** Token registration is a
/// background side effect of signing in, never a step a user is waiting on, and
/// ADR-039 D1 makes the boot fail-open. A failed registration must cost the user
/// their pushes until the next attempt, never a frame or an error surface.
///
/// So there is no exception taxonomy to map, and there is deliberately no retry:
/// the app re-registers on every launch and on every token refresh, so a failure
/// is already retried by the next ordinary event rather than by machinery that
/// would have to reason about backoff on a path with no user waiting on it. The
/// cost of that choice is a session where a user gets no pushes and nothing says
/// so — recorded here rather than discovered later.
class FunctionsPushTokenRepository implements PushTokenRepository {
  /// [functions] defaults to the region-scoped instance `firebase_bootstrap.dart`
  /// also resolves (instanceFor caches per app+region), so a
  /// `USE_FUNCTIONS_EMULATOR` run reaches the emulator with no extra plumbing.
  FunctionsPushTokenRepository({
    FirebaseFunctions? functions,
    void Function(String message)? onFailure,
  }) : _functions =
           functions ?? FirebaseFunctions.instanceFor(region: kFunctionsRegion),
       _onFailure = onFailure ?? debugPrint;

  final FirebaseFunctions _functions;
  final void Function(String message) _onFailure;

  @override
  Future<void> register(String token) => _call('registerPushToken', token);

  @override
  Future<void> unregister(String token) => _call('unregisterPushToken', token);

  Future<void> _call(String name, String token) async {
    try {
      await _functions.httpsCallable(name).call<Object?>({'token': token});
    } catch (failure) {
      // Record ONLY the callable name and the failure's runtimeType — never the
      // token and never the throwable's stringification. A token addresses one
      // physical device and is the credential for delivering to it; the server
      // keeps it out of its own logs (ADR-042 D1), so the client must not put it
      // into a crash report on the way past.
      _onFailure('$name failed: ${failure.runtimeType}');
    }
  }
}
