import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/profile_repository_provider.dart';
import '../../domain/relationship_profile.dart';

part 'profile_providers.g.dart';

/// Riverpod 3 auto-retry disabled: transient Firestore trouble is retried
/// inside the SDK's own listener; an error surfacing here is rules-denial or
/// a malformed doc, where backoff-hammering just pins the gate on a spinner.
/// Recovery is the user-driven `ref.invalidate` on the error view.
Duration? _noRetry(int retryCount, Object error) => null;

/// Live `users/{uid}` profile (null until capture completes). AutoDispose:
/// the subscription lives exactly as long as a widget watches it, and a
/// retry after a stream failure is a plain `ref.invalidate` → fresh
/// subscription (Firestore re-emits current state on listen).
@Riverpod(retry: _noRetry)
Stream<RelationshipProfile?> profileStream(Ref ref, String uid) =>
    ref.watch(profileRepositoryProvider).watchProfile(uid);
