import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'couple_repository.dart';

part 'couple_repository_provider.g.dart';

/// Seam for [CoupleRepository]: bound to the Firestore implementation at
/// bootstrap (main_dev.dart / main_prod.dart), faked per test container —
/// same throw-until-overridden discipline as `profileRepositoryProvider`.
@Riverpod(keepAlive: true)
CoupleRepository coupleRepository(Ref ref) => throw StateError(
  'coupleRepositoryProvider must be overridden at bootstrap '
  '(main_dev.dart / main_prod.dart) or per test container.',
);
