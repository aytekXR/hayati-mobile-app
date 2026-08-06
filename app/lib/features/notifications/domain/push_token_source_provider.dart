import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'push_token_source.dart';

part 'push_token_source_provider.g.dart';

/// Provides the device's [PushTokenSource].
///
/// **Nothing overrides this yet, and that is the design** (ADR-042 D2). The FCM
/// implementation needs `firebase_messaging`, which needs `aps-environment`,
/// which needs the Push Notifications capability on the App ID — measured ABSENT
/// on 2026-08-06. Until the flavor entrypoints override it, [PushTokenSync] is
/// wired, tested and inert: reading it throws, so `PushTokenSync` never resolves
/// it on a device that has no source, and the app behaves exactly as it does
/// today.
@Riverpod(keepAlive: true)
PushTokenSource pushTokenSource(Ref ref) => throw StateError(
  'pushTokenSourceProvider must be overridden at bootstrap once '
  'firebase_messaging lands (ADR-042 D2 step 4), or per test container.',
);
