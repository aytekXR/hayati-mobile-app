import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LengthLimitingTextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/spacing_tokens.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/storage/local_flag_store.dart';
import '../../auth/domain/auth_exception.dart';
import '../../auth/domain/auth_repository_provider.dart';
import '../../auth/domain/auth_user.dart';
import 'state/name_capture_done.dart';

/// Display-name auth-record cap: generous for real names and endearments,
/// tight enough that the invite preview's hero line never has to elide a
/// novel. Enforced silently at entry (no counter chrome — one warm field).
const int nameCaptureMaxLength = 50;

/// The name-capture onboarding step (redesign QW-6, ui-ux §6.1): one field,
/// one Continue, between sign-in and profile capture. Collects the display
/// name the zero-auth invite preview resolves from the AUTH record — so a
/// phone sign-up's invitation says "{name} invited you", never the no-name
/// fallback (the reluctant-husband activation moment, roadmap G2).
///
/// Pre-filled from the Auth displayName when present (Apple/Google), so most
/// users just confirm. Nicknames are explicitly welcome (the placeholder says
/// so); any non-empty string is valid — no error states beyond the save
/// failing. Continue writes the name to the auth record FIRST, then sets the
/// device-local done flag and bumps [nameCaptureDoneProvider], whose change
/// re-evaluates the gate on to profile capture (the CoupleEndedNoticeScreen
/// acknowledge idiom). A failed write keeps the user here with honest retry
/// copy — the same contract as the profile save it sits beside.
class NameCaptureScreen extends ConsumerStatefulWidget {
  const NameCaptureScreen({super.key, required this.user});

  /// The signed-in user: carries the uid the done flag is keyed by and the
  /// provider-supplied displayName the field pre-fills from.
  final AuthUser user;

  @override
  ConsumerState<NameCaptureScreen> createState() => _NameCaptureScreenState();
}

class _NameCaptureScreenState extends ConsumerState<NameCaptureScreen> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.user.displayName ?? '',
  );

  bool _saving = false;
  AuthException? _failure;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// The canonical name the save persists: surrounding whitespace never
  /// counts (the solo-answer `_entry` precedent).
  String get _entry => _controller.text.trim();

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _failure = null;
    });
    try {
      // Auth record FIRST (the durable, server-visible half), then the local
      // done flag — so the gate never routes past a name that was not saved.
      await ref.read(authRepositoryProvider).updateDisplayName(_entry);
    } on AuthException catch (failure) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _failure = failure;
      });
      return;
    }
    if (!mounted) return;
    await ref
        .read(localFlagStoreProvider)
        .set(nameCaptureDoneKey(widget.user.uid));
    if (!mounted) return;
    // The reactive bump AFTER the durable write: the gate re-reads the now-set
    // flag and swaps this screen for profile capture.
    ref.read(nameCaptureDoneProvider.notifier).markDone();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: SpacingTokens.screenGutter,
            vertical: SpacingTokens.x6,
          ),
          children: [
            Text(l10n.nameCaptureTitle, style: theme.textTheme.headlineMedium),
            const SizedBox(height: SpacingTokens.x3),
            // The honest reason we ask, as a Mist caption (theme bodySmall).
            Text(l10n.nameCaptureHelper, style: theme.textTheme.bodySmall),
            const SizedBox(height: SpacingTokens.x6),
            TextField(
              controller: _controller,
              enabled: !_saving,
              autocorrect: false,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              inputFormatters: [
                LengthLimitingTextInputFormatter(nameCaptureMaxLength),
              ],
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) {
                if (_entry.isNotEmpty && !_saving) _save();
              },
              decoration: InputDecoration(hintText: l10n.nameCaptureHint),
            ),
            if (_failure != null) ...[
              const SizedBox(height: SpacingTokens.x4),
              // Error copy in the theme's alert colour (alert-on-night OK).
              Text(
                switch (_failure!) {
                  AuthNetworkException() => l10n.errorNetworkRetry,
                  _ => l10n.errorGeneric,
                },
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
      // The sole primary action pinned to the viewport bottom — the ADR-025
      // slice-3 CTA-anchor pattern shared with ProfileCaptureScreen, which
      // this step precedes (visual continuity between the two capture forms).
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: SpacingTokens.x6),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SpacingTokens.screenGutter,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_saving) ...[
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: SpacingTokens.x4),
              ],
              FilledButton(
                // Disabled ONLY while empty or in-flight (ui-ux §6.1: any
                // non-empty string is valid — nicknames welcome).
                onPressed: (_entry.isEmpty || _saving) ? null : _save,
                child: Text(l10n.continueAction),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
