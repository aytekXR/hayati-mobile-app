// ═══════════════════════════════════════════════════════════════════════════
// HARD CONSTRAINT — READ BEFORE EDITING THIS FILE (ADR-018 Decision 3; review
// findings SEC-7 / FLUTTER-1).
//
// The LockScreen sits ABOVE the app's only Navigator: it is a Stack sibling of
// the child `MaterialApp.builder` receives. It therefore has **NO Navigator and
// NO Overlay ancestor**. So NOTHING in this file — or in any widget it mounts —
// may call `showDialog`, `showModalBottomSheet`, `showMenu`, `Navigator.of`, or
// use `Tooltip`, `Autocomplete`, `DropdownButton`, or a text-selection-enabled
// field. Each of those looks up an Overlay and THROWS when it finds none, and on
// the recovery path that crash IS the lockout: the user would be stuck behind a
// lock screen that cannot sign them out.
//
// That is why the recovery confirmation below is an INLINE two-phase widget
// state (the keypad column swaps for a scrim + card this screen draws itself),
// not a dialog. The settings screen's PIN-verify dialog is a different story: it
// is pushed INSIDE the Navigator and may use `showDialog` normally (Decision 7).
//
// This screen also provides its OWN `Material` — there is no Scaffold above it.
// ═══════════════════════════════════════════════════════════════════════════

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/color_tokens.dart';
import '../../../core/design_system/radius_tokens.dart';
import '../../../core/design_system/spacing_tokens.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../../auth/domain/auth_state.dart';
import '../../auth/presentation/state/auth_controller.dart';
import '../../daily_question/domain/solo_clock.dart';
import '../domain/pin_hasher.dart';
import '../domain/pin_lock_attempt_result.dart';
import '../domain/pin_lock_cooldown.dart';
import 'state/privacy_lock_controller.dart';
import 'widgets/pin_keypad.dart';

/// The lock overlay (ADR-018 Decision 3): dots-only PIN echo, an LTR-pinned
/// keypad, the optional biometric accelerator, and the always-visible
/// sign-out recovery. Rendered full-bleed by `PrivacyGuard` whenever the lock
/// state is `PrivacyLocked` — over `home`, over every pushed route, over
/// whatever a deep link rendered.
///
/// No PIN digit, salt, or hash appears in any string, exception, or log this
/// file produces (the no-content rule, architecture §8).
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  /// The digits entered so far. Widget-local and never persisted, logged, or
  /// rendered — only its LENGTH reaches the UI (the dots).
  String _pin = '';

  /// The last WRONG verdict, for the "n tries left" line. Cleared the moment the
  /// user starts typing again.
  PinLockAttemptWrong? _wrong;

  /// A `verifyPin` is in flight: the pad is inert until the awaited persist
  /// lands (the increment-before-verdict ordering, Decision 4/SEC-4B).
  bool _verifying = false;

  /// Phase two of the recovery flow — the inline confirm panel is up.
  bool _recovering = false;

  /// The recovery sign-out is in flight.
  bool _signingOut = false;

  /// The recovery sign-out FAILED (auth landed on `AuthError`): nothing was
  /// wiped, the overlay is still locked, and the honest retry line shows
  /// (Decision 4 — the lock never drops on an unconfirmed sign-out).
  bool _recoveryFailed = false;

  /// Drives the cooldown countdown's re-render / re-enable. Only alive while a
  /// cooldown is actually running (see [_syncCooldownTimer]).
  Timer? _cooldownTicker;

  @override
  void initState() {
    super.initState();
    // Decision 1: before biometric is offered, the platform's enrollment state
    // is compared to the one captured at enable time — a mismatch AUTO-REVOKES
    // the accelerator rather than prompting. Nothing is offered until this
    // answers.
    unawaited(
      ref
          .read(privacyLockControllerProvider.notifier)
          .refreshBiometricAvailability(),
    );
  }

  @override
  void dispose() {
    _cooldownTicker?.cancel();
    super.dispose();
  }

  /// Keeps a 1s ticker alive exactly while a cooldown is running, so the copy
  /// counts down and the pad re-enables itself without a keypress. Called from
  /// `build` — it only creates/cancels a timer, never calls `setState`
  /// synchronously, so it cannot re-enter the build it was called from.
  void _syncCooldownTimer(bool cooling) {
    if (cooling && _cooldownTicker == null) {
      _cooldownTicker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!cooling && _cooldownTicker != null) {
      _cooldownTicker!.cancel();
      _cooldownTicker = null;
    }
  }

  void _onDigit(String digit) {
    if (_verifying || _pin.length >= kPinLength) return;
    setState(() {
      _wrong = null;
      _pin += digit;
    });
    if (_pin.length == kPinLength) unawaited(_submit());
  }

  void _onBackspace() {
    if (_verifying || _pin.isEmpty) return;
    setState(() {
      _wrong = null;
      _pin = _pin.substring(0, _pin.length - 1);
    });
  }

  Future<void> _submit() async {
    setState(() => _verifying = true);
    final result = await ref
        .read(privacyLockControllerProvider.notifier)
        .verifyPin(_pin);
    if (!mounted) return;
    setState(() {
      _verifying = false;
      // The PIN is dropped from memory on EVERY verdict, accepted included.
      _pin = '';
      switch (result) {
        // Accepted: the gate un-mounts us on the next frame — render nothing.
        // Aborted: the op was dropped (re-entrant) or the lock was wiped
        // mid-flight by the sign-out path. Nothing was decided, so there is
        // nothing honest to say.
        case PinLockAttemptAccepted():
        case PinLockAttemptAborted():
        case PinLockAttemptCooldown():
          // A cooldown verdict needs no line of its own: the deadline is in the
          // state, and the cooldown copy below renders from it.
          _wrong = null;
        case PinLockAttemptWrong():
          _wrong = result;
      }
    });
  }

  Future<void> _authenticateBiometric() async {
    final l10n = AppLocalizations.of(context);
    // Failure, cancel, or an unavailable sensor all fall back silently to the
    // keypad (Decision 1) — and a biometric failure is NOT a PIN attempt: it
    // consumes no attempt and starts no cooldown.
    await ref
        .read(privacyLockControllerProvider.notifier)
        .authenticateBiometric(reason: l10n.lockBiometricReason);
  }

  /// The recovery flow (ADR-018 Decision 4; review finding DVUX-3).
  ///
  /// ORDERING IS LOAD-BEARING: sign out FIRST, with the overlay still LOCKED.
  /// We never wipe first — a wipe-then-sign-out ordering, with a sign-out that
  /// throws, would drop the overlay on a still-signed-in app and paint couple
  /// content.
  ///
  /// But the wipe must NOT depend on the root listener's auth TRANSITION firing,
  /// and this is the subtle part (post-implementation review, SPEC-1 — the one
  /// defect in this layer that could brick a device permanently):
  ///
  /// `ref.listen(authControllerProvider, …)` in `app.dart` fires on a state
  /// CHANGE. `AuthSignedOut` is value-equal, so signing out while ALREADY signed
  /// out re-enters an identical state, Riverpod suppresses the notification, and
  /// the listener never runs. That is not a hypothetical: the ORPHANED-RECORD
  /// edge (a lock that outlived its session because the wipe's `clear()` threw —
  /// ADR-018 D1/D8) boots exactly there, lock screen up, auth already signed out.
  /// Riding the listener alone would leave the record un-wiped, the overlay up,
  /// and NO error shown — with no escape, because reinstalling does not clear the
  /// Keychain (D2's whole point). Permanent brick.
  ///
  /// So: sign out, then read the SETTLED auth state, and wipe on the STATE, not
  /// on the transition. `wipe()` is idempotent (generation bump + clear + state
  /// mutation), so the normal path — where the listener already wiped during the
  /// await — is a harmless second call.
  Future<void> _confirmRecovery() async {
    setState(() {
      _signingOut = true;
      _recoveryFailed = false;
    });
    try {
      await ref.read(authControllerProvider.notifier).signOut();
    } catch (_) {
      // The controller maps AuthException → AuthError itself; this catch is the
      // belt for anything else. Either way: nothing was wiped, we stay locked.
    }
    if (!mounted) return;

    if (ref.read(authControllerProvider) is AuthSignedOut) {
      // Confirmed signed out — the only condition under which the lock may drop
      // (Decision 4). Idempotent by construction.
      await ref.read(privacyLockControllerProvider.notifier).wipe();
      return; // The state flip to `disabled` un-mounts this overlay.
    }

    setState(() {
      _signingOut = false;
      _recoveryFailed = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = ref.watch(privacyLockControllerProvider);
    final locked = state is PrivacyLocked ? state : null;

    final nowMs = ref.watch(soloClockProvider)().millisecondsSinceEpoch;
    final until = locked?.lockoutUntilMs;
    final remaining = until == null || until <= nowMs
        ? null
        : Duration(milliseconds: until - nowMs);
    _syncCooldownTimer(remaining != null);

    return Material(
      color: ColorTokens.night,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SpacingTokens.screenGutter,
            vertical: SpacingTokens.x4,
          ),
          child: _recovering
              ? _RecoveryPanel(
                  busy: _signingOut,
                  failed: _recoveryFailed,
                  onCancel: _signingOut
                      ? null
                      : () => setState(() {
                          _recovering = false;
                          _recoveryFailed = false;
                        }),
                  onConfirm: _signingOut ? null : _confirmRecovery,
                )
              : _KeypadColumn(
                  filled: _pin.length,
                  enabled: !_verifying && remaining == null,
                  status: _statusLine(l10n, theme, locked, remaining),
                  biometricAvailable: locked?.biometricAvailable ?? false,
                  onDigit: _onDigit,
                  onBackspace: _onBackspace,
                  onBiometric: _authenticateBiometric,
                  onForgot: () => setState(() => _recovering = true),
                ),
        ),
      ),
    );
  }

  /// The one honest line under the dots. Precedence: a running cooldown beats a
  /// wrong-attempt count (the cooldown is what the user must act on) beats the
  /// biometric-revoked notice.
  Widget _statusLine(
    AppLocalizations l10n,
    ThemeData theme,
    PrivacyLocked? locked,
    Duration? remaining,
  ) {
    final String? text;
    if (remaining != null) {
      text = _cooldownCopy(l10n, remaining);
    } else if (_wrong != null) {
      text = l10n.lockWrongPin(_wrong!.remainingBeforeCooldown);
    } else if (locked?.biometricRevoked ?? false) {
      text = l10n.lockBiometricRevoked;
    } else {
      text = null;
    }
    if (text == null) return const SizedBox(height: SpacingTokens.x6);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SpacingTokens.x1),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall?.copyWith(color: ColorTokens.alert),
      ),
    );
  }
}

/// TIER-ACCURATE cooldown copy (ADR-018 Decision 4; review finding DVUX-5): one
/// shared "about a minute" string would understate the 5-minute tier 5× — an
/// over-claim the honest-states rule forbids — so the copy is picked from
/// [PinLockCooldownTier], never from a single string.
///
/// The tier is derived from the time still REMAINING rather than from the tier
/// the attempt landed in, for two reasons: (a) on a COLD START into a running
/// cooldown the lock state carries only the deadline (`lockoutUntilMs`), never
/// the counter — deriving from the deadline is the only information we have; and
/// (b) rounding UP to the smallest tier that still covers the wait can never
/// understate it, which is the property DVUX-5 actually protects. At the instant
/// a cooldown starts, the two agree exactly (30s→30s, 60s→1m, 300s→5m).
String _cooldownCopy(AppLocalizations l10n, Duration remaining) =>
    switch (_tierFor(remaining)) {
      PinLockCooldownTier.thirtySeconds => l10n.lockCooldownThirtySeconds,
      PinLockCooldownTier.oneMinute => l10n.lockCooldownOneMinute,
      PinLockCooldownTier.fiveMinutes => l10n.lockCooldownFiveMinutes,
    };

PinLockCooldownTier _tierFor(Duration remaining) {
  if (remaining <= const Duration(seconds: 30)) {
    return PinLockCooldownTier.thirtySeconds;
  }
  if (remaining <= const Duration(minutes: 1)) {
    return PinLockCooldownTier.oneMinute;
  }
  return PinLockCooldownTier.fiveMinutes;
}

/// Phase one: the dots, the pad, the accelerator, the recovery entry.
class _KeypadColumn extends StatelessWidget {
  const _KeypadColumn({
    required this.filled,
    required this.enabled,
    required this.status,
    required this.biometricAvailable,
    required this.onDigit,
    required this.onBackspace,
    required this.onBiometric,
    required this.onForgot,
  });

  final int filled;
  final bool enabled;
  final Widget status;
  final bool biometricAvailable;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onBiometric;
  final VoidCallback onForgot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(),
        const Icon(
          Icons.lock_outline,
          color: ColorTokens.sand,
          size: SpacingTokens.x8,
        ),
        const SizedBox(height: SpacingTokens.x3),
        Text(
          l10n.lockTitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: SpacingTokens.x2),
        Text(
          l10n.lockPrompt,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: SpacingTokens.x5),
        PinDots(filled: filled),
        status,
        const SizedBox(height: SpacingTokens.x3),
        PinKeypad(onDigit: onDigit, onBackspace: onBackspace, enabled: enabled),
        const SizedBox(height: SpacingTokens.x2),
        if (biometricAvailable)
          TextButton.icon(
            onPressed: onBiometric,
            icon: const Icon(Icons.face_outlined),
            label: Text(l10n.lockBiometricCta),
          ),
        // ALWAYS visible (Decision 4): a user who has forgotten the PIN must
        // never have to guess their way to the escape hatch.
        TextButton(onPressed: onForgot, child: Text(l10n.lockForgotPin)),
        const Spacer(),
      ],
    );
  }
}

/// Phase two: the inline recovery confirmation — a scrim + card this screen
/// DRAWS, not a dialog it shows (see the file header: there is no Overlay to
/// host one, and the throw would be the lockout).
class _RecoveryPanel extends StatelessWidget {
  const _RecoveryPanel({
    required this.busy,
    required this.failed,
    required this.onCancel,
    required this.onConfirm,
  });

  final bool busy;
  final bool failed;
  final VoidCallback? onCancel;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Center(
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(SpacingTokens.cardPadding),
          decoration: const BoxDecoration(
            color: ColorTokens.nightRaised,
            borderRadius: RadiusTokens.cardRadius,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.lockRecoveryTitle, style: theme.textTheme.titleMedium),
              const SizedBox(height: SpacingTokens.x3),
              Text(l10n.lockRecoveryBody, style: theme.textTheme.bodyMedium),
              if (failed) ...[
                const SizedBox(height: SpacingTokens.x3),
                Text(
                  l10n.lockRecoveryFailed,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: ColorTokens.alert,
                  ),
                ),
              ],
              const SizedBox(height: SpacingTokens.x5),
              FilledButton(
                onPressed: onConfirm,
                child: Text(l10n.lockRecoveryConfirm),
              ),
              const SizedBox(height: SpacingTokens.x2),
              TextButton(
                onPressed: onCancel,
                child: Text(l10n.lockRecoveryCancel),
              ),
              if (busy) ...[
                const SizedBox(height: SpacingTokens.x3),
                const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
