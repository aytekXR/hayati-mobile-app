import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'couple_day_repository.dart';

part 'couple_day_repository_provider.g.dart';

/// Seam for [CoupleDayRepository]: bound to the Firestore implementation at
/// bootstrap (main_dev.dart / main_prod.dart), faked per test container —
/// same throw-until-overridden discipline as `profileRepositoryProvider`.
@Riverpod(keepAlive: true)
CoupleDayRepository coupleDayRepository(Ref ref) => throw StateError(
  'coupleDayRepositoryProvider must be overridden at bootstrap '
  '(main_dev.dart / main_prod.dart) or per test container.',
);
