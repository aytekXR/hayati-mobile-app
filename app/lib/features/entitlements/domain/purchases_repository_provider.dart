import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'purchases_repository.dart';

part 'purchases_repository_provider.g.dart';

/// Seam for [PurchasesRepository]: bound to the RevenueCat adapter at bootstrap
/// (main_dev.dart / main_prod.dart), faked per test container — same
/// throw-until-overridden discipline as `entitlementRepositoryProvider`. A
/// signed-out lifecycle never resolves it (the identity sync reads it lazily,
/// only when a sync action fires), so a signed-out pump needs no override.
@Riverpod(keepAlive: true)
PurchasesRepository purchasesRepository(Ref ref) => throw StateError(
  'purchasesRepositoryProvider must be overridden at bootstrap '
  '(main_dev.dart / main_prod.dart) or per test container.',
);
