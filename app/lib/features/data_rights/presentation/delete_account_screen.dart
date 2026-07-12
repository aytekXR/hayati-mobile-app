import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/color_tokens.dart';
import '../../../core/design_system/radius_tokens.dart';
import '../../../core/design_system/spacing_tokens.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../../auth/presentation/state/auth_controller.dart';
import '../../privacy_lock/domain/pin_lock_attempt_result.dart';
import '../../privacy_lock/presentation/state/privacy_lock_controller.dart';
import '../../settings/presentation/widgets/pin_verify_dialog.dart';
import '../domain/data_rights_exception.dart';
import 'export_screen.dart';

/// The account-deletion screen (ADR-019 Decision 7), pushed from settings. Never
/// a one-tap accident and honest to the letter: it states, in plain sentences,
/// that deletion is irreversible; that it removes the account, the private
/// reflections, and the ENTIRE shared space (both sides of every answer); what
/// the partner will and won't learn; that it does NOT cancel an App Store
/// subscription; and it offers to download the data first.
///
/// The confirm is a second, deliberate step: the PIN-verify dialog when the lock
/// is on (attempt-bounded, cooldown-aware; PIN-only — no biometric, Invariant C),
/// or a plain destructive dialog naming "permanently" when it is off. On a phase-1
/// cascade failure the screen SURVIVES (the controller leaves the auth state
/// untouched, so the host settings screen's self-pop never fires) and renders
/// retry copy that says the deletion "could not be confirmed" — never "failed",
/// because a lost ack may mean it actually completed (AUTH-3). On success the root
/// listener wipes the lock and the host self-pop handles navigation; this screen
/// adds none of its own.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key, required this.uid});

  final String uid;

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  bool _deleting = false;

  /// Set after a phase-1 cascade failure — the in-place retry surface. The copy
  /// says "could not be confirmed", never "failed" (ADR-019 D7 / AUTH-3).
  bool _couldNotConfirm = false;

  Future<void> _openExport() => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => ExportScreen(uid: widget.uid)),
  );

  Future<void> _confirm() async {
    final lockOn =
        ref.read(privacyLockControllerProvider) is! PrivacyLockDisabled;
    if (lockOn) {
      // PIN re-auth through the existing dialog (Invariant C — PIN only, no
      // biometric). A wrong PIN engages the lock overlay (verifyPin's existing,
      // attempt-bounded behavior) and does NOT proceed; a cooldown/aborted result
      // simply does nothing. Only an accepted PIN reaches the deletion.
      final pin = await showDialog<String>(
        context: context,
        builder: (_) => const PinVerifyDialog(),
      );
      if (pin == null || !mounted) return;
      final result = await ref
          .read(privacyLockControllerProvider.notifier)
          .verifyPin(pin);
      if (!mounted || result is! PinLockAttemptAccepted) return;
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => const _DeleteConfirmDialog(),
      );
      if (confirmed != true || !mounted) return;
    }
    await _runDeletion();
  }

  Future<void> _runDeletion() async {
    setState(() {
      _deleting = true;
      _couldNotConfirm = false;
    });
    try {
      await ref.read(authControllerProvider.notifier).deleteAccount();
      // Success (or a phase-2 AuthError): the host settings screen's auth-loss
      // self-pop tears this route down. We add NO navigation of our own.
    } on DataRightsException {
      // Phase 1 failed: the auth state was left untouched (AuthSignedIn), so the
      // host self-pop never fired and we are still here. Offer an honest retry.
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _couldNotConfirm = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final sentenceStyle = theme.textTheme.bodyMedium;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.dataRightsDeleteTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: SpacingTokens.screenGutter,
            vertical: SpacingTokens.x6,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.dataRightsDeleteIrreversible,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: SpacingTokens.x4),
              Text(l10n.dataRightsDeleteScope, style: sentenceStyle),
              const SizedBox(height: SpacingTokens.x3),
              Text(l10n.dataRightsDeletePartner, style: sentenceStyle),
              const SizedBox(height: SpacingTokens.x3),
              Text(l10n.dataRightsDeleteSubscription, style: sentenceStyle),
              const SizedBox(height: SpacingTokens.x5),
              TextButton(
                onPressed: _deleting ? null : _openExport,
                child: Text(l10n.dataRightsDeleteExportLink),
              ),
              const SizedBox(height: SpacingTokens.x5),
              if (_couldNotConfirm) ...[
                Text(
                  l10n.dataRightsDeleteCouldNotConfirm,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: ColorTokens.alert,
                  ),
                ),
                const SizedBox(height: SpacingTokens.x4),
              ],
              FilledButton(
                onPressed: _deleting ? null : _confirm,
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                  minimumSize: const Size.fromHeight(48),
                  shape: RadiusTokens.stadium,
                ),
                child: _deleting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.dataRightsDeleteConfirmAction),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The plain destructive confirmation shown when no lock is set (ADR-019 D7 step
/// 2). Names the word "permanently" in its body. Pops true on confirm.
class _DeleteConfirmDialog extends StatelessWidget {
  const _DeleteConfirmDialog();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.dataRightsDeleteDialogTitle),
      content: Text(l10n.dataRightsDeleteDialogBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.dataRightsDeleteDialogCancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
          child: Text(l10n.dataRightsDeleteDialogConfirm),
        ),
      ],
    );
  }
}
