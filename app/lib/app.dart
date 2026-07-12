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
import 'features/auth/domain/auth_state.dart';
import 'features/auth/presentation/sign_in_screen.dart';
import 'features/auth/presentation/state/auth_controller.dart';
import 'features/coach/presentation/state/coach_transcript.dart';
import 'features/entitlements/presentation/state/purchases_identity_sync.dart';
import 'features/pairing/presentation/state/pending_invite.dart';
import 'features/privacy_lock/presentation/privacy_guard.dart';
import 'features/privacy_lock/presentation/state/privacy_lock_controller.dart';

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
    // Tear down all coach conversation state on any transition away from a
    // signed-in user (ADR-017 Decision 3). The coach transcript family is
    // keepAlive — it survives route pops BY DESIGN — so a sign-out that only
    // popped the route would leave crisis text reachable across a
    // sign-out→sign-in cycle in one process. Invalidating the family wholesale
    // from the always-mounted root (the purchasesIdentitySync mount precedent)
    // makes the ephemeral, retention-zero claim true.
    //
    // The lock wipe (ADR-018 Decision 1) rides the SAME listener with a
    // DELIBERATELY DIFFERENT trigger — read the asymmetry before "fixing" it:
    //
    // * the coach tears down on ANY non-signed-in state, because there
    //   fail-closed means CONTENT IS GONE;
    // * the lock wipes ONLY on `AuthSignedOut`, because here fail-closed means
    //   PROTECTION STAYS. An `AuthError` from a sign-out that threw must not
    //   silently disable a lock the user believes is on — and on the recovery
    //   path (Decision 4) the overlay is holding the app closed precisely until
    //   a REAL sign-out is observed.
    //
    // And never `ref.invalidate(privacyLockControllerProvider)` — anywhere. It
    // is keepAlive and seeded from the by-value boot snapshot, so invalidation
    // replays BOOT state (re-locking after a wipe, or reverting a just-enabled
    // lock). `wipe()` is a generation bump + `store.clear()` + an in-place state
    // mutation, on purpose (review finding FLUTTER-2).
    ref.listen(authControllerProvider, (previous, next) {
      if (next is! AuthSignedIn) {
        ref.invalidate(coachTranscriptProvider);
      }
      if (next is AuthSignedOut) {
        ref.read(privacyLockControllerProvider.notifier).wipe();
      }
    });
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
        // The device-privacy gate (ADR-018 Decision 3). The builder is the one
        // point above `home` AND every pushed route, so ONE overlay covers the
        // whole surface — including whatever a cold-start deep link renders.
        // It also owns the app-switcher snapshot shield (Decision 5).
        child: PrivacyGuard(child: child ?? const SizedBox.shrink()),
      ),
      home: const SignInScreen(),
    );
  }
}
