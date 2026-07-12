import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/data_export.dart';
import '../../domain/data_rights_repository_provider.dart';

part 'data_export_provider.g.dart';

/// Riverpod 3 auto-retry disabled (the `coupleProvider` idiom): a failed export
/// is a rules/precondition/transport error, and recovery is the user tapping
/// "Try again" on the honest error view (a plain `ref.invalidate`), never a
/// backoff-hammer of the callable.
Duration? _noRetry(int retryCount, Object error) => null;

/// The self-serve export future (ADR-019 Decision 5). AutoDispose: the callable
/// is invoked exactly while the export screen watches it, and a retry after a
/// failure is a plain `ref.invalidate` → fresh call. The server derives the
/// subject uid from the auth token, so this takes no argument.
@Riverpod(retry: _noRetry)
Future<DataExport> dataExport(Ref ref) =>
    ref.watch(dataRightsRepositoryProvider).exportData();
