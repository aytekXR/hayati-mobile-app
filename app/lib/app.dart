import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// flutter_riverpod's curated export surface omits the Override type;
// riverpod_annotation (already a direct dependency) exposes it.
import 'package:riverpod_annotation/riverpod_annotation.dart' show Override;

import 'core/config/app_config.dart';
import 'core/config/app_config_provider.dart';
import 'core/design_system/color_tokens.dart';
import 'core/l10n/gen/app_localizations.dart';
import 'features/auth/presentation/sign_in_screen.dart';

/// Boots the app for the given flavor [config]. Called only by the flavor
/// entrypoints (`main_dev.dart` / `main_prod.dart`), which pass the
/// environment bindings (e.g. the Firebase-backed auth repository) as
/// [extraOverrides] so widget tests can compose fakes the same way.
void runHayati(AppConfig config, {List<Override> extraOverrides = const []}) {
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
    return MaterialApp(
      // Brand name stays sourced from core/config (never the ARBs) so a
      // rename touches one place (docs/frontend-brandkit.md §1).
      title: config.appName,
      // ARB-based l10n (docs/architecture.md §6): tr/ar/en, RTL derived from
      // the locale by the framework; unsupported device locales resolve to
      // EN (preferred-supported-locales) like bootstrapContentLanguage.
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // MVP ships dark-first only, single theme (docs/mvp.md OUT list).
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: ColorTokens.pomegranate,
          brightness: Brightness.dark,
          surface: ColorTokens.night,
        ),
        scaffoldBackgroundColor: ColorTokens.night,
      ),
      home: const SignInScreen(),
    );
  }
}
