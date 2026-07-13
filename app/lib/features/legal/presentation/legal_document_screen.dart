import 'package:flutter/material.dart';

import '../../../core/design_system/spacing_tokens.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../domain/legal_document.dart';
import 'legal_renderer.dart';

/// Renders ONE legal document (ADR-023 Decision 5) — the surface the sign-in
/// footer, the consent gate's links, the paywall links row, and the Settings
/// legal hub all open DIRECTLY. Documents only: this screen carries NO consent
/// controls (the reached-from-Settings discriminator keeps Withdraw off every
/// pre-consent and subscription path).
///
/// The body is loaded from `assets/legal/<doc>.<locale>.md` (resolved locale, EN
/// fallback) through an INJECTED [AssetBundle] seam (ADR-023 D5, finding
/// `testability-3`): production passes null → `DefaultAssetBundle.of(context)`;
/// widget tests and goldens inject a `StaticAssetBundle` / `shippedLegalBundle()`
/// off-disk reader, because a real `rootBundle` load never completes inside the
/// widget-test fake-async zone and would wedge `pumpAndSettle`.
class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({super.key, required this.document, this.bundle});

  final LegalDocument document;

  /// Test/golden seam — null in production (falls back to the ambient bundle).
  final AssetBundle? bundle;

  String _title(AppLocalizations l10n) => switch (document) {
    LegalDocument.privacyPolicy => l10n.legalPrivacyTitle,
    LegalDocument.terms => l10n.legalTermsTitle,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final languageCode = Localizations.localeOf(context).languageCode;
    final assetBundle = bundle ?? DefaultAssetBundle.of(context);
    final path = legalAssetPath(document, languageCode);

    return Scaffold(
      appBar: AppBar(title: Text(_title(l10n))),
      body: SafeArea(
        child: FutureBuilder<String>(
          // `key` on the path so a locale change (never expected mid-view, but
          // cheap insurance) re-runs the load rather than showing stale text.
          key: ValueKey(path),
          future: assetBundle.loadString(path),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _LegalLoadError(message: l10n.legalDocumentError);
            }
            final source = snapshot.data;
            if (source == null) {
              return const Center(child: CircularProgressIndicator());
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: SpacingTokens.screenGutter,
                vertical: SpacingTokens.x6,
              ),
              child: legalDocumentColumn(source, Theme.of(context)),
            );
          },
        ),
      ),
    );
  }
}

/// Pushes [document] over the current route — the `showSettings` / `showCoach`
/// exported-helper convention. Every legal-link affordance routes through here,
/// so the four call sites (sign-in footer, consent gate, paywall, legal hub) can
/// never drift on how the document opens.
Future<void> pushLegalDocument(BuildContext context, LegalDocument document) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => LegalDocumentScreen(document: document),
    ),
  );
}

class _LegalLoadError extends StatelessWidget {
  const _LegalLoadError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: SpacingTokens.screenGutter,
        ),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
      ),
    );
  }
}
