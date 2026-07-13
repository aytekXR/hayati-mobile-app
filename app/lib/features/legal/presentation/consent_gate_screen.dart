import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/color_tokens.dart';
import '../../../core/design_system/spacing_tokens.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../../auth/presentation/state/auth_controller.dart';
import '../../data_rights/domain/data_rights_exception.dart';
import '../../data_rights/domain/data_rights_repository_provider.dart';
import '../../data_rights/presentation/delete_account_screen.dart';
import '../../data_rights/presentation/export_screen.dart';
import '../../profile/presentation/state/profile_providers.dart';
import '../../settings/presentation/widgets/settings_error_line.dart';
import '../domain/consent_status.dart';
import '../domain/legal_document.dart';
import 'legal_document_screen.dart';

/// The special-category consent gate (ADR-023 Decision 3). Rendered BY the
/// `OnboardingGate` as a gate child — never a pushed route — so it cannot be
/// popped back to (the `CoupleEndedNoticeScreen` mold). It collects EXACTLY ONE
/// explicit consent (Decision 1) to process the user's reflections, shared
/// answers, and coach messages, and it never traps a decliner: sign-out, export,
/// and account deletion are all reachable directly from here (blocking finding
/// `appflow-1`).
///
/// The gate clears ONLY via the streamed `users/{uid}.consent` field — there is
/// no optimistic local grant (Decision 3): tapping the CTA calls `recordConsent`
/// and then WAITS for the profile stream to deliver a consent that satisfies
/// `hasCurrentConsent`, at which point `OnboardingGate` routes on. If the callable
/// succeeds but a subsequent snapshot still fails `hasCurrentConsent` (an app
/// binary ahead of the deployed server constant — the stale-after-accept state),
/// the screen shows a persistent honest error instead of re-offering the CTA
/// loop (finding `appflow-3`).
class ConsentGateScreen extends ConsumerStatefulWidget {
  const ConsentGateScreen({super.key, required this.uid});

  final String uid;

  @override
  ConsumerState<ConsentGateScreen> createState() => _ConsentGateScreenState();
}

class _ConsentGateScreenState extends ConsumerState<ConsentGateScreen> {
  /// The `recordConsent` grant call is in flight.
  bool _submitting = false;

  /// A grant call has succeeded; we are now waiting for the streamed profile to
  /// deliver the consent that clears the gate (no optimistic local grant).
  bool _accepted = false;

  /// A post-accept snapshot arrived that still fails `hasCurrentConsent` — the
  /// stale-after-accept state. Persistent: the CTA is never re-offered.
  bool _stale = false;

  /// The transient failure line after a failed grant call (offline / callable
  /// error), resolved against l10n at render time (the settings-row idiom).
  String Function(AppLocalizations)? _error;

  Future<void> _consent() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(dataRightsRepositoryProvider)
          .recordConsent(withdraw: false);
      if (!mounted) return;
      // Success does NOT clear the gate — the streamed profile does. Hold a
      // confirming spinner until the gate routes away (or turns stale).
      setState(() {
        _submitting = false;
        _accepted = true;
      });
    } on DataRightsException {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = (l10n) => l10n.consentError;
      });
    }
  }

  void _signOut() => ref.read(authControllerProvider.notifier).signOut();

  Future<void> _openExport() => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const ExportScreen()));

  Future<void> _openDelete() => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const DeleteAccountScreen()));

  @override
  Widget build(BuildContext context) {
    // Watch the same profile the gate reads: a post-accept snapshot that STILL
    // fails hasCurrentConsent is the stale-after-accept state. A snapshot that
    // satisfies it never lands here — `OnboardingGate` routes away and unmounts
    // this screen first. `ref.listen` (not watch) so the check runs on genuine
    // subsequent emissions only, never on the current value during the wait.
    ref.listen(profileStreamProvider(widget.uid), (previous, next) {
      if (!_accepted || _stale) return;
      final value = next.value;
      if (next.hasValue && value != null && !hasCurrentConsent(value)) {
        setState(() => _stale = true);
      }
    });

    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final busy = _submitting || _accepted;
    // The escapes re-enable in the terminal stale state: a user held at the
    // gate by an app-ahead-of-server skew must keep sign-out/export/delete
    // (post-impl review finding `xcut-2` — the appflow-1 trap re-created).
    final escapesBusy = _submitting || (_accepted && !_stale);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: SpacingTokens.screenGutter,
            vertical: SpacingTokens.x6,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.consentTitle, style: theme.textTheme.titleLarge),
              const SizedBox(height: SpacingTokens.x5),
              Text(l10n.consentIntro, style: theme.textTheme.bodyMedium),
              const SizedBox(height: SpacingTokens.x3),
              Text(l10n.consentDataLocation, style: theme.textTheme.bodyMedium),
              const SizedBox(height: SpacingTokens.x3),
              Text(l10n.consentProcessors, style: theme.textTheme.bodyMedium),
              const SizedBox(height: SpacingTokens.x3),
              Text(l10n.consentRights, style: theme.textTheme.bodyMedium),
              const SizedBox(height: SpacingTokens.x4),
              // Documents open DIRECTLY (Decision 5) — no consent controls there.
              Wrap(
                spacing: SpacingTokens.x4,
                children: [
                  TextButton(
                    onPressed: () =>
                        pushLegalDocument(context, LegalDocument.privacyPolicy),
                    child: Text(l10n.legalLinkPrivacy),
                  ),
                  TextButton(
                    onPressed: () =>
                        pushLegalDocument(context, LegalDocument.terms),
                    child: Text(l10n.legalLinkTerms),
                  ),
                ],
              ),
              const SizedBox(height: SpacingTokens.x4),
              // The 18+ eligibility statement — a Terms CONDITION, deliberately
              // its OWN paragraph and severed from the consent-button sentence
              // (finding `legal-5`: an eligibility declaration, not a processing
              // consent).
              Text(
                l10n.consentAgeStatement,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: SpacingTokens.x6),
              if (_stale)
                Text(
                  l10n.consentStaleError,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: ColorTokens.alert,
                  ),
                )
              else ...[
                if (busy)
                  const FilledButton(
                    onPressed: null,
                    child: SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  FilledButton(
                    onPressed: _consent,
                    child: Text(l10n.consentCta),
                  ),
                SettingsErrorLine(resolve: _error),
              ],
              const SizedBox(height: SpacingTokens.x5),
              // The three escape affordances — a decliner keeps every right
              // (finding `appflow-1`). Disabled only while a grant is in
              // flight or confirming; the terminal stale state keeps them
              // live (finding `xcut-2`).
              TextButton(
                onPressed: escapesBusy ? null : _signOut,
                child: Text(l10n.settingsSignOut),
              ),
              TextButton(
                onPressed: escapesBusy ? null : _openExport,
                child: Text(l10n.dataRightsExportRowTitle),
              ),
              TextButton(
                onPressed: escapesBusy ? null : _openDelete,
                child: Text(l10n.dataRightsDeleteRowTitle),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
