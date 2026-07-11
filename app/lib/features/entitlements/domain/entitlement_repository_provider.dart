import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'entitlement_repository.dart';

part 'entitlement_repository_provider.g.dart';

/// Seam for [EntitlementRepository]: bound to the Firestore implementation at
/// bootstrap (main_dev.dart / main_prod.dart), faked per test container — same
/// throw-until-overridden discipline as `coupleRepositoryProvider`.
@Riverpod(keepAlive: true)
EntitlementRepository entitlementRepository(Ref ref) => throw StateError(
  'entitlementRepositoryProvider must be overridden at bootstrap '
  '(main_dev.dart / main_prod.dart) or per test container.',
);
