import 'dart:async';

import 'package:flutter/material.dart';

import '../design_system/spacing_tokens.dart';
import '../l10n/gen/app_localizations.dart';

/// How long a blocking load may run before this widget stops being a bare
/// spinner and starts offering a way out (ADR-039).
///
/// Eight seconds is chosen against the thing it guards, not against a feel: the
/// loads behind it are a Firestore document listen and an HTTPS GET, both of
/// which land in well under a second on a working connection and neither of
/// which gets meaningfully more likely to land between second eight and second
/// sixty. Short enough that nobody sits there wondering; long enough that a slow
/// connection is never scolded for being slow.
const Duration kSlowLoadThreshold = Duration(seconds: 8);

/// A blocking-progress screen that CANNOT become a dead end (ADR-039).
///
/// The app used to render `Scaffold(body: Center(child:
/// CircularProgressIndicator()))` at every in-flight gate. That is correct for
/// the first second and a trap thereafter: a Firestore document listener on a
/// doc that is not in the local cache raises NO event at all until the server
/// answers — not an empty snapshot, not an error — so a client that cannot reach
/// the backend leaves `AsyncValue.isLoading` true forever. On `OnboardingGate`,
/// the very first screen after sign-in, that spinner carried no retry, no error
/// and no sign-out: the only exit was deleting the app.
///
/// So the spinner keeps its first [threshold] unchanged — no flicker, no copy, no
/// penalty for an ordinary slow moment — and after it, WITHOUT replacing the
/// spinner (the load may still land, and pulling it would claim a failure that
/// has not happened), reveals honest copy and the caller's [actions].
///
/// The timer is cancelled in `dispose`, so a load that settles normally leaves
/// nothing pending — including under `flutter test`, where a leaked timer fails
/// the test rather than the app.
class SlowLoadEscape extends StatefulWidget {
  const SlowLoadEscape({
    super.key,
    required this.actions,
    this.threshold = kSlowLoadThreshold,
  });

  /// Revealed under the copy once [threshold] elapses. The caller owns these
  /// because the honest escape differs by surface: the post-sign-in gate offers
  /// retry AND sign-out (a user stuck there is holding a session they cannot
  /// use), while a pushed screen may only need a retry.
  final List<Widget> actions;

  final Duration threshold;

  @override
  State<SlowLoadEscape> createState() => _SlowLoadEscapeState();
}

class _SlowLoadEscapeState extends State<SlowLoadEscape> {
  Timer? _timer;
  bool _slow = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.threshold, () {
      if (mounted) setState(() => _slow = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
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
                const CircularProgressIndicator(),
                if (_slow) ...[
                  const SizedBox(height: SpacingTokens.x6),
                  // NOT the alert colour: nothing has failed yet. This is a
                  // status line, and painting it red would assert an error the
                  // app cannot actually claim while the load is still open.
                  Text(
                    l10n.loadingSlowBody,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: SpacingTokens.x4),
                  ...widget.actions,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
