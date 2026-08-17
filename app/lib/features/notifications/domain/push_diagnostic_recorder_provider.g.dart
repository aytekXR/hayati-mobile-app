// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'push_diagnostic_recorder_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
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

@ProviderFor(pushDiagnosticRecorder)
const pushDiagnosticRecorderProvider = PushDiagnosticRecorderProvider._();

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

final class PushDiagnosticRecorderProvider
    extends
        $FunctionalProvider<
          PushDiagnosticRecorder,
          PushDiagnosticRecorder,
          PushDiagnosticRecorder
        >
    with $Provider<PushDiagnosticRecorder> {
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
  const PushDiagnosticRecorderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pushDiagnosticRecorderProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pushDiagnosticRecorderHash();

  @$internal
  @override
  $ProviderElement<PushDiagnosticRecorder> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PushDiagnosticRecorder create(Ref ref) {
    return pushDiagnosticRecorder(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PushDiagnosticRecorder value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PushDiagnosticRecorder>(value),
    );
  }
}

String _$pushDiagnosticRecorderHash() =>
    r'a1ddd279f31951bbba7975139f6181e3e1c9df8c';
