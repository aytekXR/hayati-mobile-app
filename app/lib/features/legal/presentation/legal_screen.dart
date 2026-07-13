import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/spacing_tokens.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../../data_rights/domain/data_rights_exception.dart';
import '../../data_rights/domain/data_rights_repository_provider.dart';
import '../../profile/domain/relationship_profile.dart';
import '../../profile/presentation/state/profile_providers.dart';
import '../../settings/presentation/widgets/settings_error_line.dart';
import '../domain/legal_document.dart';
import 'legal_document_screen.dart';

/// Pushes the legal hub over the current route — the `showSettings` convention.
/// Reached ONLY from the Settings legal tile (the reached-from-Settings
/// discriminator, ADR-023 D5): this is the ONE surface that carries the consent
/// status and the Withdraw action, so a pre-consent gate and a paywall never do.
Future<void> showLegal(BuildContext context, {required String uid}) {
  return Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => LegalScreen(uid: uid)));
}

/// The legal hub (ADR-023 Decision 5): the two document tiles, the consent
/// status line, and the Withdraw action. Withdrawal follows the prospective
/// reading (Decision 4 / Ambiguity 3) — one confirm dialog that states plainly
/// the reflective features pause (the gate returns) and stored reflections
/// REMAIN STORED until deleted; the dialog itself offers nothing destructive.
class LegalScreen extends ConsumerStatefulWidget {
  const LegalScreen({super.key, required this.uid});

  final String uid;

  @override
  ConsumerState<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends ConsumerState<LegalScreen> {
  bool _withdrawing = false;
  String Function(AppLocalizations)? _withdrawError;

  Future<void> _withdraw() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const _WithdrawConsentDialog(),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _withdrawing = true;
      _withdrawError = null;
    });
    try {
      await ref
          .read(dataRightsRepositoryProvider)
          .recordConsent(withdraw: true);
      // The profile stream re-emits with `consent` cleared; the status line
      // updates to "none" and the gate returns when the user navigates back.
    } on DataRightsException {
      if (!mounted) return;
      setState(() => _withdrawError = (l10n) => l10n.legalWithdrawError);
    } finally {
      if (mounted) setState(() => _withdrawing = false);
    }
  }

  String _statusLine(AppLocalizations l10n, Consent? consent) {
    if (consent == null) return l10n.legalConsentStatusNone;
    final acceptedAt = consent.acceptedAt;
    if (acceptedAt == null) {
      return l10n.legalConsentStatusNoDate(consent.version);
    }
    return l10n.legalConsentStatus(acceptedAt, consent.version);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final consent = switch (ref.watch(profileStreamProvider(widget.uid))) {
      AsyncData(:final value) => value?.consent,
      _ => null,
    };

    return Scaffold(
      appBar: AppBar(title: Text(l10n.legalHubTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: SpacingTokens.x4),
          children: [
            ListTile(
              title: Text(l10n.legalPrivacyTitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () =>
                  pushLegalDocument(context, LegalDocument.privacyPolicy),
            ),
            ListTile(
              title: Text(l10n.legalTermsTitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => pushLegalDocument(context, LegalDocument.terms),
            ),
            const Divider(height: SpacingTokens.x8),
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: SpacingTokens.screenGutter,
                end: SpacingTokens.screenGutter,
                bottom: SpacingTokens.x3,
              ),
              child: Text(
                _statusLine(l10n, consent),
                style: theme.textTheme.bodyMedium,
              ),
            ),
            if (consent != null)
              ListTile(
                title: Text(l10n.legalWithdrawTitle),
                subtitle: Text(l10n.legalWithdrawSubtitle),
                trailing: _withdrawing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
                onTap: _withdrawing ? null : _withdraw,
              ),
            SettingsErrorLine(resolve: _withdrawError),
          ],
        ),
      ),
    );
  }
}

/// The single withdraw confirm dialog (ADR-023 D4). Its copy states plainly that
/// the reflective features pause and stored reflections remain stored until
/// deleted — and it offers NOTHING destructive itself (the DV doctrine: a
/// low-friction action must never destroy data; deletion stays a deliberate,
/// separate step reachable from the gate and Settings).
class _WithdrawConsentDialog extends StatelessWidget {
  const _WithdrawConsentDialog();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.legalWithdrawDialogTitle),
      content: Text(l10n.legalWithdrawDialogBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.settingsCancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.legalWithdrawDialogConfirm),
        ),
      ],
    );
  }
}
