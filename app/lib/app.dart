import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_config.dart';
import 'core/config/app_config_provider.dart';
import 'core/design_system/color_tokens.dart';

/// Boots the app for the given flavor [config]. Called only by the flavor
/// entrypoints (`main_dev.dart` / `main_prod.dart`).
void runHayati(AppConfig config) {
  runApp(
    ProviderScope(
      overrides: [appConfigProvider.overrideWithValue(config)],
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
      title: config.appName,
      // MVP ships dark-first only, single theme (docs/mvp.md OUT list).
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: ColorTokens.pomegranate,
          brightness: Brightness.dark,
          surface: ColorTokens.night,
        ),
        scaffoldBackgroundColor: ColorTokens.night,
      ),
      home: Scaffold(body: Center(child: Text(config.flavor.name))),
    );
  }
}
