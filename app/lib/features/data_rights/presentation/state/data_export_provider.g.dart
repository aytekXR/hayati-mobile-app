// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'data_export_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The self-serve export future (ADR-019 Decision 5). AutoDispose: the callable
/// is invoked exactly while the export screen watches it, and a retry after a
/// failure is a plain `ref.invalidate` → fresh call. The server derives the
/// subject uid from the auth token, so this takes no argument.

@ProviderFor(dataExport)
const dataExportProvider = DataExportProvider._();

/// The self-serve export future (ADR-019 Decision 5). AutoDispose: the callable
/// is invoked exactly while the export screen watches it, and a retry after a
/// failure is a plain `ref.invalidate` → fresh call. The server derives the
/// subject uid from the auth token, so this takes no argument.

final class DataExportProvider
    extends
        $FunctionalProvider<
          AsyncValue<DataExport>,
          DataExport,
          FutureOr<DataExport>
        >
    with $FutureModifier<DataExport>, $FutureProvider<DataExport> {
  /// The self-serve export future (ADR-019 Decision 5). AutoDispose: the callable
  /// is invoked exactly while the export screen watches it, and a retry after a
  /// failure is a plain `ref.invalidate` → fresh call. The server derives the
  /// subject uid from the auth token, so this takes no argument.
  const DataExportProvider._()
    : super(
        from: null,
        argument: null,
        retry: _noRetry,
        name: r'dataExportProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dataExportHash();

  @$internal
  @override
  $FutureProviderElement<DataExport> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<DataExport> create(Ref ref) {
    return dataExport(ref);
  }
}

String _$dataExportHash() => r'0b5bd6d285dde7506a4ea5958732da8a78fde559';
