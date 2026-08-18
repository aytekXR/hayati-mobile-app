import 'dart:ui' show PlatformDispatcher;

import 'package:hayati_app/core/analytics/analytics_dimensions.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../auth/domain/auth_state.dart';
import '../../../auth/presentation/state/auth_controller.dart';
import '../../domain/relationship_profile.dart';
import 'profile_providers.dart';

/// Maps the settled profile (or its absence) to the §7 dimensions — ADR-057 D3.
///
/// Pure, so the pre-profile window is a testable case rather than a widget-test
/// accident. The two halves of the funnel that fire before a profile exists —
/// `install` at first launch and `signup` at auth completion, *before* capture —
/// take the [deviceLanguageCode] branch, and carry **no register**: the user has
/// not had that choice yet, and a default would be a fabricated value in the one
/// language where the split is product-meaningful.
AnalyticsDimensions analyticsDimensionsFor({
  required RelationshipProfile? profile,
  required String? deviceLanguageCode,
}) {
  if (profile == null) {
    return AnalyticsDimensions(locale: analyticsLocaleFor(deviceLanguageCode));
  }
  return AnalyticsDimensions(
    locale: switch (profile.contentLanguage) {
      ContentLanguage.tr => AnalyticsLocale.tr,
      ContentLanguage.ar => AnalyticsLocale.ar,
      ContentLanguage.en => AnalyticsLocale.en,
    },
    register: switch (profile.register) {
      ContentRegister.playful => AnalyticsRegister.playful,
      ContentRegister.respectful => AnalyticsRegister.respectful,
    },
  );
  // storefront stays null: the app has no storefront source at all (ADR-057
  // D3). The server half carries it off the RC event (#242).
}

/// The override `app.dart` installs over `analyticsDimensionsProvider`.
///
/// It lives HERE rather than in `core/analytics/` because nothing under
/// `app/lib/core/` imports `app/lib/features/` — 0 of 631 files — and analytics
/// is not the place to be the first. The core provider ships a working
/// device-locale default; this replaces it with the profile-aware one at the
/// composition root.
///
/// **Guarded, and the guard is not defensive habit.** `authControllerProvider`
/// resolves `authRepositoryProvider`, which THROWS when unoverridden — the state
/// of every widget test that does not wire auth. An unguarded resolve here would
/// therefore take those tests red for touching analytics, which is the trap
/// `push_diagnostic_recorder_provider.dart` records having already been sprung
/// once. On any failure the device locale is the answer, which is exactly what a
/// signed-out user's dimensions are anyway.
AnalyticsDimensions profileAnalyticsDimensions(Ref ref) {
  final deviceLanguageCode = PlatformDispatcher.instance.locale.languageCode;
  try {
    final auth = ref.watch(authControllerProvider);
    if (auth is! AuthSignedIn) {
      return AnalyticsDimensions(
        locale: analyticsLocaleFor(deviceLanguageCode),
      );
    }
    return analyticsDimensionsFor(
      profile: ref.watch(profileStreamProvider(auth.user.uid)).value,
      deviceLanguageCode: deviceLanguageCode,
    );
  } on Object {
    return AnalyticsDimensions(locale: analyticsLocaleFor(deviceLanguageCode));
  }
}
