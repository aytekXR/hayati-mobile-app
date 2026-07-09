import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/spacing_tokens.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../domain/auth_exception.dart';
import '../domain/auth_state.dart';
import '../domain/phone_sign_in_state.dart';
import 'state/auth_controller.dart';
import 'state/phone_sign_in_controller.dart';

/// Phone sign-in flow (docs/resume-prompt.md M1.3): phone-number entry →
/// SMS-code entry, driven by [phoneSignInControllerProvider]. Pushed on top of
/// `SignInScreen`; brand styling comes from the theme
/// (core/design_system/hayati_theme.dart) plus the spacing tokens below.
/// Layout is logical-direction only (RTL-safe).
///
/// Signed-in hand-off: the controller never flips the global `AuthState` — a
/// successful confirm surfaces as `AuthSignedIn` on the `authStateChanges`
/// stream (see `PhoneSignInController`). This route sits ABOVE the SignInScreen
/// that already rebuilds into `OnboardingGate` on sign-in, so we pop ourselves
/// to uncover it rather than render the signed-in tree here. Popping (over
/// "let the rebuild own the tree") is required because a pushed route stays in
/// the Navigator stack; without the pop the user would be stranded on the
/// terminal [PhoneConfirming] spinner while onboarding lives underneath.
class PhoneSignInScreen extends ConsumerWidget {
  const PhoneSignInScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(authControllerProvider, (previous, next) {
      if (next is AuthSignedIn) {
        final navigator = Navigator.of(context);
        if (navigator.canPop()) navigator.pop();
      }
    });

    final state = ref.watch(phoneSignInControllerProvider);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.continueWithPhone)),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: SpacingTokens.screenGutter,
            ),
            child: switch (state) {
              PhoneEntry() => const _PhoneNumberEntry(),
              // A failure with no retained session (send failure or an expired
              // verification session) restarts from phone entry.
              PhoneSignInFailure(:final failure, :final session)
                  when session == null =>
                _PhoneNumberEntry(error: failure),
              PhoneSending() ||
              PhoneConfirming() => const CircularProgressIndicator(),
              PhoneCodeSent(:final resending) => _SmsCodeEntry(
                resending: resending,
              ),
              // A failure with a retained session (wrong code, transient) keeps
              // the code screen for an inline retry.
              PhoneSignInFailure(:final failure) => _SmsCodeEntry(
                error: failure,
              ),
            },
          ),
        ),
      ),
    );
  }
}

/// Maps an [AuthException] to phone-flow error copy. Invalid-code and
/// session-expired get their own messages; everything else falls back to the
/// shared network/generic copy.
String _errorCopy(AppLocalizations l10n, AuthException failure) =>
    switch (failure) {
      AuthInvalidCodeException() => l10n.errorInvalidCode,
      AuthSessionExpiredException() => l10n.errorSessionExpired,
      AuthNetworkException() => l10n.errorNetworkRetry,
      AuthCancelledException() || AuthUnknownException() => l10n.errorGeneric,
    };

class _PhoneNumberEntry extends ConsumerStatefulWidget {
  const _PhoneNumberEntry({this.error});

  /// The failure to surface above the field, or null on the first entry.
  final AuthException? error;

  @override
  ConsumerState<_PhoneNumberEntry> createState() => _PhoneNumberEntryState();
}

class _PhoneNumberEntryState extends ConsumerState<_PhoneNumberEntry> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final number = _controller.text.trim();
    if (number.isEmpty) return;
    unawaited(
      ref.read(phoneSignInControllerProvider.notifier).sendCode(number),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final error = widget.error;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (error != null) ...[
          // Error copy in the theme's alert colour (alert-on-night 4.94:1 OK).
          Text(
            _errorCopy(l10n, error),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
          const SizedBox(height: SpacingTokens.x4),
        ],
        TextField(
          controller: _controller,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            labelText: l10n.phoneNumberLabel,
            hintText: l10n.phoneNumberHint,
          ),
        ),
        const SizedBox(height: SpacingTokens.x6),
        FilledButton(onPressed: _submit, child: Text(l10n.sendCode)),
      ],
    );
  }
}

class _SmsCodeEntry extends ConsumerStatefulWidget {
  const _SmsCodeEntry({this.resending = false, this.error});

  /// True while a resend request is in flight, so the code UI stays visible.
  final bool resending;

  /// The failure to surface above the field, or null while awaiting input.
  final AuthException? error;

  @override
  ConsumerState<_SmsCodeEntry> createState() => _SmsCodeEntryState();
}

class _SmsCodeEntryState extends ConsumerState<_SmsCodeEntry> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final code = _controller.text.trim();
    if (code.isEmpty) return;
    unawaited(ref.read(phoneSignInControllerProvider.notifier).confirm(code));
  }

  void _resend() =>
      unawaited(ref.read(phoneSignInControllerProvider.notifier).resend());

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final error = widget.error;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (error != null) ...[
          // Error copy in the theme's alert colour (alert-on-night 4.94:1 OK).
          Text(
            _errorCopy(l10n, error),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
          const SizedBox(height: SpacingTokens.x4),
        ],
        TextField(
          controller: _controller,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(labelText: l10n.smsCodeLabel),
        ),
        const SizedBox(height: SpacingTokens.x6),
        FilledButton(onPressed: _submit, child: Text(l10n.verifyCode)),
        const SizedBox(height: SpacingTokens.x2),
        if (widget.resending)
          const Padding(
            padding: EdgeInsets.all(SpacingTokens.x2),
            child: SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else
          TextButton(onPressed: _resend, child: Text(l10n.resendCode)),
      ],
    );
  }
}
