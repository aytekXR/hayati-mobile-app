import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'push_diagnostic.dart';

part 'push_diagnostic_recorder_provider.g.dart';

/// Provides the app's [PushDiagnosticRecorder].
///
/// Unimplemented at the base, on the `pushTokenRepositoryProvider` mold: the
/// flavor entrypoints override it with the Firestore-backed implementation and
/// tests override it per container with a fake.
///
/// **Reading it therefore THROWS wherever nothing overrode it**, which is every
/// widget test that builds the app without wiring notifications — so
/// `PushTokenSync` resolves it inside a guard and treats a failure as a logged
/// no-op, exactly as it already does for `pushTokenSourceProvider`. That is not
/// defensive habit: an unguarded resolve here would take 60 unrelated widget
/// tests red, which is a mistake this file's neighbours have already made once.
@Riverpod(keepAlive: true)
PushDiagnosticRecorder pushDiagnosticRecorder(Ref ref) => throw StateError(
  'pushDiagnosticRecorderProvider must be overridden at bootstrap '
  '(main_dev.dart / main_prod.dart) or per test container.',
);
