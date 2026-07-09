// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'invite_preview_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Fetches the zero-auth [InvitePreviewResult] for [code] so the join screen
/// can show who invited the user before they sign in. A family keyed by code:
/// each code gets its own cached AsyncValue, so previewing a second code never
/// clobbers the first. autoDispose (screen-scoped) — the preview is released
/// when the screen stops watching it.
///
/// The three screen states fall straight out of the returned AsyncValue
/// (loading → data | error); an [InvitePreviewStatus.unknown]/expired RESULT is
/// still `AsyncData`, not an error (the code simply isn't joinable).

@ProviderFor(invitePreview)
const invitePreviewProvider = InvitePreviewFamily._();

/// Fetches the zero-auth [InvitePreviewResult] for [code] so the join screen
/// can show who invited the user before they sign in. A family keyed by code:
/// each code gets its own cached AsyncValue, so previewing a second code never
/// clobbers the first. autoDispose (screen-scoped) — the preview is released
/// when the screen stops watching it.
///
/// The three screen states fall straight out of the returned AsyncValue
/// (loading → data | error); an [InvitePreviewStatus.unknown]/expired RESULT is
/// still `AsyncData`, not an error (the code simply isn't joinable).

final class InvitePreviewProvider
    extends
        $FunctionalProvider<
          AsyncValue<InvitePreviewResult>,
          InvitePreviewResult,
          FutureOr<InvitePreviewResult>
        >
    with
        $FutureModifier<InvitePreviewResult>,
        $FutureProvider<InvitePreviewResult> {
  /// Fetches the zero-auth [InvitePreviewResult] for [code] so the join screen
  /// can show who invited the user before they sign in. A family keyed by code:
  /// each code gets its own cached AsyncValue, so previewing a second code never
  /// clobbers the first. autoDispose (screen-scoped) — the preview is released
  /// when the screen stops watching it.
  ///
  /// The three screen states fall straight out of the returned AsyncValue
  /// (loading → data | error); an [InvitePreviewStatus.unknown]/expired RESULT is
  /// still `AsyncData`, not an error (the code simply isn't joinable).
  const InvitePreviewProvider._({
    required InvitePreviewFamily super.from,
    required String super.argument,
  }) : super(
         retry: _noRetry,
         name: r'invitePreviewProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$invitePreviewHash();

  @override
  String toString() {
    return r'invitePreviewProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<InvitePreviewResult> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<InvitePreviewResult> create(Ref ref) {
    final argument = this.argument as String;
    return invitePreview(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is InvitePreviewProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$invitePreviewHash() => r'1f2cd18ed4159afefa28f671498d057e91fc4271';

/// Fetches the zero-auth [InvitePreviewResult] for [code] so the join screen
/// can show who invited the user before they sign in. A family keyed by code:
/// each code gets its own cached AsyncValue, so previewing a second code never
/// clobbers the first. autoDispose (screen-scoped) — the preview is released
/// when the screen stops watching it.
///
/// The three screen states fall straight out of the returned AsyncValue
/// (loading → data | error); an [InvitePreviewStatus.unknown]/expired RESULT is
/// still `AsyncData`, not an error (the code simply isn't joinable).

final class InvitePreviewFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<InvitePreviewResult>, String> {
  const InvitePreviewFamily._()
    : super(
        retry: _noRetry,
        name: r'invitePreviewProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Fetches the zero-auth [InvitePreviewResult] for [code] so the join screen
  /// can show who invited the user before they sign in. A family keyed by code:
  /// each code gets its own cached AsyncValue, so previewing a second code never
  /// clobbers the first. autoDispose (screen-scoped) — the preview is released
  /// when the screen stops watching it.
  ///
  /// The three screen states fall straight out of the returned AsyncValue
  /// (loading → data | error); an [InvitePreviewStatus.unknown]/expired RESULT is
  /// still `AsyncData`, not an error (the code simply isn't joinable).

  InvitePreviewProvider call(String code) =>
      InvitePreviewProvider._(argument: code, from: this);

  @override
  String toString() => r'invitePreviewProvider';
}
