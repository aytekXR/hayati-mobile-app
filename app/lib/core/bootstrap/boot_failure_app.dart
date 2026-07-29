import 'package:flutter/material.dart';

import '../design_system/hayati_theme.dart';
import '../design_system/spacing_tokens.dart';
import '../l10n/gen/app_localizations.dart';

/// The last resort of the cold-start path (ADR-039): the app the flavor
/// entrypoints run when the pre-first-frame bootstrap throws.
///
/// **What it replaces.** `main()` awaits four things before `runHayati` (ADR-022
/// Decision 1). If any of them threw, the exception escaped `main()`, `runApp`
/// was never called, and iOS kept the launch storyboard — the centred wordmark on
/// white — on screen FOREVER. No frame, no error, no crash report (Crashlytics is
/// itself one of the four), no way out but force-quit, and force-quitting starts
/// the same sequence again. To the person holding the phone that is not a crash;
/// it is "the loading screen is always on", which is precisely how it gets
/// reported and precisely why it is hard to act on.
///
/// So the boot now always ends in a FRAME. The individual steps degrade in place
/// where degrading is meaningful (App Check, Crashlytics and RevenueCat each
/// fail open and continue), and this screen catches whatever is left — chiefly a
/// `Firebase.initializeApp` failure, which nothing downstream can work without.
///
/// **Deliberately dependency-free.** No `ProviderScope`, no Firebase, no
/// repository seam: it is rendered on the path where the bootstrap those things
/// live in has already failed, so anything it touched could throw again and
/// return the user to the blank screen this exists to abolish. It needs only the
/// generated l10n (pure Dart) and the theme (pure token composition).
///
/// **[retry] re-runs `main()`.** Every bootstrap step is idempotent by
/// construction — `ensureInitialized` is a no-op when initialized,
/// `initializeFirebase` already absorbs `duplicate-app` (a hot restart hits the
/// same path), and the three fail-open steps return early once configured — so
/// re-entering is safe, and it is the only recovery a user with no other
/// affordance can perform. A success calls `runApp` again and replaces this
/// screen wholesale.
void runBootFailureApp({
  required Object failure,
  required Future<void> Function() retry,
}) => runApp(BootFailureApp(failure: failure, retry: retry));

class BootFailureApp extends StatelessWidget {
  const BootFailureApp({super.key, required this.failure, required this.retry});

  /// The bootstrap throwable, rendered under the details expander. Platform text
  /// — a Firebase code, a channel error — never user content, so the no-content
  /// rule (architecture §8) is untouched by showing it. Showing it is the whole
  /// difference between a tester reporting "it does not open" and a tester
  /// reporting something a session can act on.
  final Object failure;

  /// Re-runs the flavor entrypoint's `main()`.
  final Future<void> Function() retry;

  @override
  Widget build(BuildContext context) => MaterialApp(
    // No `title` from AppConfig: the config const is trivially available, but
    // this screen deliberately holds no app state at all (see the class doc).
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: hayatiTheme(languageCode: 'en'),
    builder: (context, child) => Theme(
      // Same resolved-locale rebuild as the real app root, so the Arabic body
      // line-height follows the device language here too.
      data: hayatiTheme(
        languageCode: Localizations.localeOf(context).languageCode,
      ),
      child: child ?? const SizedBox.shrink(),
    ),
    home: _BootFailureScreen(failure: failure, retry: retry),
  );
}

class _BootFailureScreen extends StatefulWidget {
  const _BootFailureScreen({required this.failure, required this.retry});

  final Object failure;
  final Future<void> Function() retry;

  @override
  State<_BootFailureScreen> createState() => _BootFailureScreenState();
}

class _BootFailureScreenState extends State<_BootFailureScreen> {
  /// A retry is in flight. Re-entrant taps are dropped (the repo's manual-op
  /// discipline) — a second `main()` racing the first would double every
  /// bootstrap step.
  bool _retrying = false;

  Future<void> _retry() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    try {
      await widget.retry();
      // On success `runApp` has replaced this widget; nothing to do. On the
      // failure path `main()` calls runBootFailureApp again with the NEW
      // throwable, which likewise replaces this widget — so the only state that
      // has to survive is "no longer retrying", for the case where main()
      // returns without doing either.
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: SpacingTokens.screenGutter,
              vertical: SpacingTokens.x6,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.bootFailedTitle,
                  style: theme.textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: SpacingTokens.x3),
                Text(l10n.bootFailedBody, textAlign: TextAlign.center),
                const SizedBox(height: SpacingTokens.x6),
                if (_retrying)
                  const FilledButton(
                    onPressed: null,
                    child: SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  FilledButton(onPressed: _retry, child: Text(l10n.tryAgain)),
                const SizedBox(height: SpacingTokens.x4),
                // Collapsed by default: the screen stays calm for the user who
                // only wants the button, and stays diagnosable for the tester
                // who is about to send a screenshot.
                Theme(
                  // The default ExpansionTile divider would draw a hairline
                  // across an otherwise quiet screen.
                  data: theme.copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    title: Text(
                      l10n.bootFailedDetails,
                      style: theme.textTheme.bodySmall,
                    ),
                    children: [
                      SelectableText(
                        '${widget.failure}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
