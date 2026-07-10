// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'solo_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The bundled solo pack for the profile's content language (M2.4). A family
/// keyed by [ContentLanguage] — same idiom as `invitePreviewProvider`.
/// AutoDispose: released when the solo home leaves the tree.

@ProviderFor(soloQuestionPack)
const soloQuestionPackProvider = SoloQuestionPackFamily._();

/// The bundled solo pack for the profile's content language (M2.4). A family
/// keyed by [ContentLanguage] — same idiom as `invitePreviewProvider`.
/// AutoDispose: released when the solo home leaves the tree.

final class SoloQuestionPackProvider
    extends
        $FunctionalProvider<
          AsyncValue<SoloQuestionPack>,
          SoloQuestionPack,
          FutureOr<SoloQuestionPack>
        >
    with $FutureModifier<SoloQuestionPack>, $FutureProvider<SoloQuestionPack> {
  /// The bundled solo pack for the profile's content language (M2.4). A family
  /// keyed by [ContentLanguage] — same idiom as `invitePreviewProvider`.
  /// AutoDispose: released when the solo home leaves the tree.
  const SoloQuestionPackProvider._({
    required SoloQuestionPackFamily super.from,
    required ContentLanguage super.argument,
  }) : super(
         retry: _noRetry,
         name: r'soloQuestionPackProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$soloQuestionPackHash();

  @override
  String toString() {
    return r'soloQuestionPackProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<SoloQuestionPack> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<SoloQuestionPack> create(Ref ref) {
    final argument = this.argument as ContentLanguage;
    return soloQuestionPack(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is SoloQuestionPackProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$soloQuestionPackHash() => r'6f93bd47f7ac994ed62d8a4533cfc18701896caa';

/// The bundled solo pack for the profile's content language (M2.4). A family
/// keyed by [ContentLanguage] — same idiom as `invitePreviewProvider`.
/// AutoDispose: released when the solo home leaves the tree.

final class SoloQuestionPackFamily extends $Family
    with
        $FunctionalFamilyOverride<FutureOr<SoloQuestionPack>, ContentLanguage> {
  const SoloQuestionPackFamily._()
    : super(
        retry: _noRetry,
        name: r'soloQuestionPackProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The bundled solo pack for the profile's content language (M2.4). A family
  /// keyed by [ContentLanguage] — same idiom as `invitePreviewProvider`.
  /// AutoDispose: released when the solo home leaves the tree.

  SoloQuestionPackProvider call(ContentLanguage language) =>
      SoloQuestionPackProvider._(argument: language, from: this);

  @override
  String toString() => r'soloQuestionPackProvider';
}

/// Live `users/{uid}/soloAnswers/{dayKey}` answer (null while unanswered).
/// A family keyed by uid + day key, mirroring `profileStreamProvider`'s
/// stream-consumer idiom.

@ProviderFor(soloAnswer)
const soloAnswerProvider = SoloAnswerFamily._();

/// Live `users/{uid}/soloAnswers/{dayKey}` answer (null while unanswered).
/// A family keyed by uid + day key, mirroring `profileStreamProvider`'s
/// stream-consumer idiom.

final class SoloAnswerProvider
    extends
        $FunctionalProvider<
          AsyncValue<SoloAnswer?>,
          SoloAnswer?,
          Stream<SoloAnswer?>
        >
    with $FutureModifier<SoloAnswer?>, $StreamProvider<SoloAnswer?> {
  /// Live `users/{uid}/soloAnswers/{dayKey}` answer (null while unanswered).
  /// A family keyed by uid + day key, mirroring `profileStreamProvider`'s
  /// stream-consumer idiom.
  const SoloAnswerProvider._({
    required SoloAnswerFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: _noRetry,
         name: r'soloAnswerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$soloAnswerHash();

  @override
  String toString() {
    return r'soloAnswerProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $StreamProviderElement<SoloAnswer?> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<SoloAnswer?> create(Ref ref) {
    final argument = this.argument as (String, String);
    return soloAnswer(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is SoloAnswerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$soloAnswerHash() => r'729520f69187b195093a722069a204b840ebbc65';

/// Live `users/{uid}/soloAnswers/{dayKey}` answer (null while unanswered).
/// A family keyed by uid + day key, mirroring `profileStreamProvider`'s
/// stream-consumer idiom.

final class SoloAnswerFamily extends $Family
    with $FunctionalFamilyOverride<Stream<SoloAnswer?>, (String, String)> {
  const SoloAnswerFamily._()
    : super(
        retry: _noRetry,
        name: r'soloAnswerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Live `users/{uid}/soloAnswers/{dayKey}` answer (null while unanswered).
  /// A family keyed by uid + day key, mirroring `profileStreamProvider`'s
  /// stream-consumer idiom.

  SoloAnswerProvider call(String uid, String dayKey) =>
      SoloAnswerProvider._(argument: (uid, dayKey), from: this);

  @override
  String toString() => r'soloAnswerProvider';
}
