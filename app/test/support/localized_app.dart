import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hayati_app/core/l10n/gen/app_localizations.dart';
// flutter_riverpod's curated export surface omits the Override type;
// riverpod_annotation (already a direct dependency) exposes it.
import 'package:riverpod_annotation/riverpod_annotation.dart' show Override;

/// Locales exercised by every screen-state widget test (M1 accept criterion:
/// onboarding states in all three).
const supportedTestLocales = [Locale('tr'), Locale('ar'), Locale('en')];

/// Wraps [home] in a localized MaterialApp mirroring HayatiApp's l10n wiring
/// (delegates + supported locales; RTL flows automatically from 'ar').
/// Tests assert against [l10nFor] lookups, never literal copy, so the same
/// test body runs across the tr/ar/en matrix.
Widget localizedApp(
  Widget home, {
  Locale locale = const Locale('en'),
  List<Override> overrides = const [],
}) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  ),
);

/// The string bundle for [locale], resolved exactly like the app resolves it.
AppLocalizations l10nFor(Locale locale) => lookupAppLocalizations(locale);
