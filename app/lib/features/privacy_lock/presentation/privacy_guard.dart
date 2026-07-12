import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'lock_screen.dart';
import 'privacy_shield_cover.dart';
import 'state/privacy_lock_controller.dart';

/// The root gate (ADR-018 Decision 3). Mounted in `MaterialApp.builder` — the
/// single point above `home` AND every `Navigator.push` route — so the entire
/// surface sits behind ONE state machine and the bypass surface is structural,
/// not per-screen vigilance. (The scout-verified bypass inventory: every
/// event-driven navigation in this app is a POP; every push is a user tap. So
/// nothing can route around a wrapper here.)
///
/// It is a `ConsumerStatefulWidget` because it OWNS THE LIFECYCLE OBSERVER
/// (review finding FLUTTER-6): `HayatiApp` is a stateless `ConsumerWidget` and
/// cannot host one. This widget is always mounted, disposed with the app, and
/// drivable in tests via `tester.binding.handleAppLifecycleStateChanged`.
///
/// Two mechanisms, one Stack:
///
/// * **The lock.** While locked, the app subtree is `Offstage` — it keeps ALL
///   its state (the Navigator stack, form fields, providers) but does not paint,
///   cannot be hit-tested, and leaves the semantics tree (closing the VoiceOver
///   readback a mere paint-over cover would have left open). `TickerMode(false)`
///   freezes animations beneath it. A deep link arriving while locked still
///   lands in `pendingInviteProvider` and renders OFFSTAGE: captured, invisible,
///   untappable — and revealed intact on unlock.
/// * **The shield.** An opaque neutral cover on `inactive`/`hidden`/`paused`, so
///   the OS never images couple content for the app-switcher card (Decision 5).
///
/// **Full-bleed is pinned, not assumed (review finding FLUTTER-4):** the Stack
/// is `fit: StackFit.expand` and both covers are `SizedBox.expand`-ed. A loose
/// Stack with a content-sized cover would leave app content painted AROUND the
/// cover during `inactive` — when the subtree is NOT offstage — and that is
/// exactly the frame iOS snapshots.
class PrivacyGuard extends ConsumerStatefulWidget {
  const PrivacyGuard({super.key, required this.child});

  /// The whole app below the gate: `MaterialApp`'s Navigator.
  final Widget child;

  @override
  ConsumerState<PrivacyGuard> createState() => _PrivacyGuardState();
}

class _PrivacyGuardState extends ConsumerState<PrivacyGuard>
    with WidgetsBindingObserver {
  /// Local widget state — the shield is a pure lifecycle affordance and never
  /// touches the lock's state machine.
  bool _shieldUp = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = ref.read(privacyLockControllerProvider.notifier);
    switch (state) {
      case AppLifecycleState.inactive:
        // Shield ONLY. `.inactive` must NOT start the grace clock (Decision 3):
        // control-centre pulls, notification-shade peeks, permission dialogs,
        // the share sheet — and the biometric prompt itself — all pass through
        // inactive without the user ever leaving the app. Locking on it would
        // fight the user, and would fight the biometric flow that unlocks us.
        _raiseShield();
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        // The user actually left. iOS fires `hidden` before `paused`; the
        // controller keeps the FIRST stamp, so calling on both is safe and
        // either alone is enough.
        _raiseShield();
        controller.noteBackgrounded();
      case AppLifecycleState.resumed:
        if (_shieldUp) setState(() => _shieldUp = false);
        // Re-locks iff the grace window elapsed — and runs the degraded-boot
        // reconcile (Decision 2's one-shot re-read).
        unawaited(controller.noteResumed());
      case AppLifecycleState.detached:
        break;
    }
  }

  void _raiseShield() {
    if (!_shieldUp) setState(() => _shieldUp = true);
  }

  @override
  Widget build(BuildContext context) {
    final locked = ref.watch(privacyLockControllerProvider) is PrivacyLocked;

    // Drop focus the moment the gate engages (review finding LOCKBYPASS-4).
    // `Offstage` stops paint and hit-testing, but it does NOT move focus: a
    // TextField the user was typing an answer into stays focused underneath, so
    // the soft keyboard rides up OVER the lock screen — and a hardware keyboard
    // (or the keyboard's own predictive-text bar, which can surface the field's
    // recent content) keeps talking to couple content the lock is supposed to
    // have closed. Unfocusing is the only thing that severs it.
    if (locked) {
      final focus = FocusManager.instance.primaryFocus;
      if (focus != null) {
        // Post-frame: we are inside build, and unfocus mutates the focus tree.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted &&
              ref.read(privacyLockControllerProvider) is PrivacyLocked) {
            FocusManager.instance.primaryFocus?.unfocus();
          }
        });
      }
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        TickerMode(
          enabled: !locked,
          child: Offstage(offstage: locked, child: widget.child),
        ),
        if (locked) const SizedBox.expand(child: LockScreen()),
        if (_shieldUp) const SizedBox.expand(child: PrivacyShieldCover()),
      ],
    );
  }
}
