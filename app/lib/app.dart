import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// flutter_riverpod's curated export surface omits the Override type;
// riverpod_annotation (already a direct dependency) exposes it.
import 'package:riverpod_annotation/riverpod_annotation.dart' show Override;

import 'core/config/app_config.dart';
import 'core/config/app_config_provider.dart';
import 'core/design_system/hayati_theme.dart';
import 'core/l10n/gen/app_localizations.dart';
import 'core/observability/crash_reporter.dart';
import 'core/observability/error_hooks.dart';
import 'features/auth/presentation/sign_in_screen.dart';
import 'features/entitlements/presentation/state/purchases_identity_sync.dart';
import 'features/pairing/presentation/state/pending_invite.dart';

/// Boots the app for the given flavor [config]. Called only by the flavor
/// entrypoints (`main_dev.dart` / `main_prod.dart`), which pass the
/// environment bindings (e.g. the Firebase-backed auth repository) as
/// [extraOverrides] so widget tests can compose fakes the same way. The
/// entrypoints also pass the Crashlytics-backed [crashReporter]; when it is
/// null (widget tests, or a reporter-less boot) no channel-bound error hooks
/// are installed, keeping those paths off the Crashlytics channel
/// (docs/resume-prompt.md M1.3).
void runHayati(
  AppConfig config, {
  List<Override> extraOverrides = const [],
  CrashReporter? crashReporter,
}) {
  if (crashReporter != null) {
    installErrorHooks(crashReporter);
  }
  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(config),
        ...extraOverrides,
      ],
      child: const HayatiApp(),
    ),
  );
}

class HayatiApp extends ConsumerWidget {
  const HayatiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    // Activate the pending-invite watcher from the first frame (it is
    // keepAlive) so a cold-start hayati://invite/<code> link — captured before
    // any pairing screen mounts — is held, not dropped. State only this
    // session; the join flow (M2.3) reads the code from pendingInviteProvider.
    ref.listen(pendingInviteProvider, (_, _) {});
    // Activate the RevenueCat identity sync from the first frame (keepAlive) so
    // a warm start's restored session logs into RC before any purchase — the
    // app root is the only always-mounted widget (ADR-014 Decision 2). Lazy by
    // design: a signed-out lifecycle never resolves the purchases seam.
    ref.listen(purchasesIdentitySyncProvider, (_, _) {});
    return MaterialApp(
      // Brand name stays sourced from core/config (never the ARBs) so a
      // rename touches one place (docs/frontend-brandkit.md §1).
      title: config.appName,
      // ARB-based l10n (docs/architecture.md §6): tr/ar/en, RTL derived from
      // the locale by the framework; unsupported device locales resolve to
      // EN (preferred-supported-locales) like bootstrapContentLanguage.
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // MVP ships dark-first only, single brand theme built from the design
      // tokens (core/design_system). 'en' is the pre-locale default; the
      // builder below rebuilds it against the RESOLVED locale so the Arabic
      // body line-height (1.7 vs 1.5) follows the actual language.
      theme: hayatiTheme(languageCode: 'en'),
      builder: (context, child) => Theme(
        // The builder sits below MaterialApp's Localizations, so localeOf
        // resolves the device-negotiated locale here.
        data: hayatiTheme(
          languageCode: Localizations.localeOf(context).languageCode,
        ),
        child: child ?? const SizedBox.shrink(),
      ),
      home: const SignInScreen(),
    );
  }
}
