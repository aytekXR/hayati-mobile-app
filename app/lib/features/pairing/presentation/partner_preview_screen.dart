import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/spacing_tokens.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/widgets/soft_unfold_reveal.dart';
import '../../auth/domain/auth_state.dart';
import '../../auth/presentation/state/auth_controller.dart';
import '../../auth/presentation/widgets/provider_actions.dart';
import '../domain/invite_exception.dart';
import '../domain/invite_preview.dart';
import '../domain/normalize_invite_code.dart';
import 'state/invite_preview_controller.dart';
import 'state/join_invite_controller.dart';
import 'state/pending_invite.dart';

/// The invitee's side of pairing (M2.3): shows WHO invited them (from the
/// zero-auth `invitePreview`) before — and after — they sign in, then redeems
/// the code via `joinInvite`. Reached three ways, all landing here with the
/// same states:
///  - `SignInScreen` (NOT signed in) when a deep-link code is pending — the
///    activation moment, so the join CTA becomes the shared sign-in actions;
///  - `OnboardingGate` (signed in, profile saved, still solo) when a code is
///    pending — the join CTA redeems the code;
///  - a manual `Navigator.push` from the invite share screen ("Have a code?"),
///    for the invitee who only got a WhatsApp code and no deep link.
///
/// Crucially the screen must NOT drive its own visibility: at the first two
/// mounts the parent routes on `pendingInviteProvider` — the very state the
/// screen would otherwise clear to re-offer entry — so clearing it there
/// unmounts the screen (gate → share screen, sign-in → auth shell) and in-place
/// re-entry becomes unreachable. "Enter another code" therefore flips a LOCAL
/// [_PartnerPreviewScreenState._manualMode] instead, swapping to manual entry
/// in place while the pending code stays put. The effective code is: manual
/// mode → what was typed (null → the entry form); otherwise the pending
/// deep-link code, falling back to an earlier manual entry (the pushed mount,
/// where nothing is pending). A NEW deep link always supersedes manual mode
/// (the provider's last-wins doctrine); only the deliberate "not now" dismiss
/// clears the pending invite.
///
/// Brand styling comes from the theme (core/design_system) plus the spacing
/// tokens; logical-direction only (RTL-safe). Each state view brings its own
/// Scaffold, mirroring `InviteShareScreen`, so this screen can be returned
/// directly by the gate or pushed as a route.
class PartnerPreviewScreen extends ConsumerStatefulWidget {
  const PartnerPreviewScreen({super.key});

  @override
  ConsumerState<PartnerPreviewScreen> createState() =>
      _PartnerPreviewScreenState();
}

class _PartnerPreviewScreenState extends ConsumerState<PartnerPreviewScreen> {
  /// A manually typed, already-normalized code (null until the user submits
  /// one). In [_manualMode] this IS the active code; otherwise it is only the
  /// fallback behind the pending deep-link code (the pushed "Have a code?"
  /// mount, where nothing is pending).
  String? _manualCode;

  /// True once the user chose "enter another code": force the manual-entry UI
  /// in place, independent of the still-pending deep-link code, so the two
  /// provider-routing parents (gate / sign-in) don't unmount us. A fresh deep
  /// link clears it (last wins).
  bool _manualMode = false;

  @override
  Widget build(BuildContext context) {
    // A fresh deep link supersedes an in-place re-entry: last wins, so drop out
    // of manual mode straight onto the new code's preview.
    ref.listen(pendingInviteProvider, (previous, next) {
      if (next != null && _manualMode) {
        setState(() => _manualMode = false);
      }
    });
    final pending = ref.watch(pendingInviteProvider);
    // Manual mode shows exactly what was typed (null → the entry form);
    // otherwise the pending code leads, with an earlier manual entry (the
    // pushed mount) as the fallback.
    final code = _manualMode ? _manualCode : (pending ?? _manualCode);
    if (code == null) {
      return _ManualCodeEntry(onSubmit: _useCode);
    }
    return _PreviewFlow(code: code, onReenter: _reenter, onDismiss: _dismiss);
  }

  void _useCode(String code) => setState(() => _manualCode = code);

  /// Switches to manual entry IN PLACE — from the unavailable state, or a
  /// terminal join failure where this code will never work. It deliberately
  /// does NOT clear `pendingInviteProvider`: the gate / sign-in parents route
  /// on that state, so clearing it would unmount this screen before the user
  /// could type again. A later deep link still supersedes this mode (see
  /// [build]).
  void _reenter() => setState(() {
    _manualMode = true;
    _manualCode = null;
  });

  /// Post-auth "not now": the deliberate exit of the flow. Clears the pending
  /// invite so `OnboardingGate` falls back to the share screen, or pops back to
  /// it when we were pushed on top.
  void _dismiss() {
    final navigator = Navigator.of(context);
    ref.read(pendingInviteProvider.notifier).clear();
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      setState(() {
        _manualMode = false;
        _manualCode = null;
      });
    }
  }
}

/// EMPTY state: brand-toned invitation to enter the 8-char code by hand, for the
/// invitee who has no pending deep-link code (or who chose to re-enter). The
/// entry is normalized via [normalizeInviteCode] — the same client-side source
/// of truth as deep-link parsing — and an off-alphabet/wrong-length entry
/// surfaces inline honest validation copy rather than a silent no-op.
class _ManualCodeEntry extends ConsumerStatefulWidget {
  const _ManualCodeEntry({required this.onSubmit});

  /// Called with the canonical code once entry passes [normalizeInviteCode].
  final ValueChanged<String> onSubmit;

  @override
  ConsumerState<_ManualCodeEntry> createState() => _ManualCodeEntryState();
}

class _ManualCodeEntryState extends ConsumerState<_ManualCodeEntry> {
  final _controller = TextEditingController();

  /// True once a submit failed normalization, so the inline validation line
  /// shows; cleared on the next edit so the user isn't scolded while retyping.
  bool _invalid = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final code = normalizeInviteCode(_controller.text);
    if (code == null) {
      setState(() => _invalid = true);
      return;
    }
    widget.onSubmit(code);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      // An empty app bar carries the back affordance only when we were pushed
      // (share screen "Have a code?"); at the root (gate/sign-in mount) it
      // auto-hides the leading button, so nothing to dismiss shows.
      appBar: AppBar(),
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
                  l10n.joinHaveCodeTitle,
                  style: theme.textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: SpacingTokens.x3),
                Text(l10n.joinHaveCodeBody, textAlign: TextAlign.center),
                const SizedBox(height: SpacingTokens.x6),
                if (_invalid) ...[
                  // Validation copy in the theme's alert colour (alert-on-night
                  // 4.94:1 OK).
                  Text(
                    l10n.inviteCodeInvalid,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: SpacingTokens.x4),
                ],
                TextField(
                  controller: _controller,
                  autocorrect: false,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.done,
                  // The invite code is a fixed 8-char LTR token, so the INPUT is
                  // pinned LTR and centred to match the share screen's code card
                  // — otherwise the ar locale enters it right-aligned / RTL-
                  // origin. The label stays locale-directional (only the edited
                  // text is forced).
                  textDirection: TextDirection.ltr, // rtl-ok
                  textAlign: TextAlign.center,
                  onChanged: (_) {
                    if (_invalid) setState(() => _invalid = false);
                  },
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: l10n.inviteCodeFieldLabel,
                  ),
                ),
                const SizedBox(height: SpacingTokens.x6),
                FilledButton(
                  onPressed: _submit,
                  child: Text(l10n.joinCheckCode),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Fetches and renders the preview for [code]. The three preview states fall
/// straight out of the family AsyncValue (same precedence idiom as
/// `InviteShareScreen`: in-flight → spinner; settled error → retry; settled
/// data → route on status), and an expired/unknown RESULT is still data (the
/// code simply isn't joinable) rather than an error.
class _PreviewFlow extends ConsumerWidget {
  const _PreviewFlow({
    required this.code,
    required this.onReenter,
    required this.onDismiss,
  });

  final String code;
  final VoidCallback onReenter;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = ref.watch(invitePreviewProvider(code));
    // isLoading first (Riverpod 3 keeps the previous error across a retry
    // reload, so this keeps the spinner up during ref.invalidate re-fetches).
    if (preview.isLoading) {
      return const _PreviewLoading();
    }
    if (preview.error != null) {
      return _PreviewError(code: code);
    }
    final result = preview.value!;
    return switch (result.status) {
      InvitePreviewStatus.valid => _ValidPreview(
        code: code,
        result: result,
        onReenter: onReenter,
        onDismiss: onDismiss,
      ),
      // The server collapses expired / already-joined / malformed into one
      // opaque outcome, and 'unknown' (no such code) reads the same to a human,
      // so both share a single honest state that offers a re-entry.
      InvitePreviewStatus.expired ||
      InvitePreviewStatus.unknown => _UnavailablePreview(onReenter: onReenter),
    };
  }
}

class _PreviewLoading extends StatelessWidget {
  const _PreviewLoading();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

/// VALID state: names the inviter (with a graceful no-name fallback), frames the
/// invite, reserves the M3 question slot, and offers the join CTA.
class _ValidPreview extends StatelessWidget {
  const _ValidPreview({
    required this.code,
    required this.result,
    required this.onReenter,
    required this.onDismiss,
  });

  final String code;
  final InvitePreviewResult result;
  final VoidCallback onReenter;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final name = result.creatorDisplayName;
    // Graceful no-name fallback: the server may resolve no display name, so the
    // hero never renders a blank or a literal "null".
    final invitedBy = (name != null && name.isNotEmpty)
        ? l10n.invitePreviewInvitedBy(name)
        : l10n.invitePreviewInvitedBySomeone;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: SpacingTokens.screenGutter,
              vertical: SpacingTokens.x6,
            ),
            // The activation moment (brandkit §6/§9.3): the invitee's first
            // sight of who invited them softly unfolds (fade + a gentle rise),
            // the pairing-flow sibling of slice 2's daily reveal. Transient —
            // no golden captures it (settles pixel-neutral); proven by
            // soft_unfold_reveal_test.dart. Wraps the whole card so the
            // headline, body and join CTA rise together as one moment; when the
            // invitee is not yet signed in the CTA is the shared [ProviderActions]
            // (unchanged, still one widget with its legal footer by construction).
            child: SoftUnfoldReveal(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    invitedBy,
                    style: theme.textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: SpacingTokens.x3),
                  Text(
                    l10n.invitePreviewValidBody,
                    textAlign: TextAlign.center,
                  ),
                  const _QuestionSlot(),
                  const SizedBox(height: SpacingTokens.x6),
                  _JoinActions(
                    code: code,
                    onReenter: onReenter,
                    onDismiss: onDismiss,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Structural slot where the M3 daily question (the invite's `questionText`)
/// will render on a valid preview. Empty by design until the server projects
/// `questionText` into `InvitePreviewResult` (see invite_preview.dart) — a
/// reserved position for the reveal, not user-visible placeholder text.
class _QuestionSlot extends StatelessWidget {
  const _QuestionSlot();

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// The join CTA area, whose shape depends on the session:
///  - NOT signed in → the shared [ProviderActions]. The invitee saw who invited
///    them first; signing in is the commitment (the activation moment).
///  - signed in → the [joinInviteControllerProvider]-driven Accept button:
///    idle → enabled; in-flight OR joined-and-waiting → disabled + progress; a
///    terminal-code failure swaps in a re-enter affordance; a retryable failure
///    keeps Accept. The post-auth "not now" dismiss shows until success.
///
/// Success is a hand-off, not a navigation: `joinInvite` stamps `coupleId`
/// server-side and the live `users/{uid}` stream re-routes the gate to the
/// paired home (coupleId wins the gate precedence). We deliberately do NOT clear
/// the pending invite on success — at the gate mount (`canPop` false) the gate
/// would re-evaluate BEFORE the stream delivers coupleId and transiently flash
/// the share screen, so instead we hold a waiting indicator until coupleId lands
/// (the stale pending code is unreachable behind coupleId's precedence). When we
/// were PUSHED we pop to uncover the re-routed gate underneath (mirrors
/// PhoneSignInScreen's pop-on-signin). The autoDispose join controller may drop
/// its success value on that teardown — deliberately fine, because nothing reads
/// the coupleId from it.
class _JoinActions extends ConsumerWidget {
  const _JoinActions({
    required this.code,
    required this.onReenter,
    required this.onDismiss,
  });

  final String code;
  final VoidCallback onReenter;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final signedIn = ref.watch(authControllerProvider) is AuthSignedIn;
    if (!signedIn) {
      return const ProviderActions();
    }

    // Success hand-off: if we were PUSHED, pop to uncover the re-routed gate
    // underneath (mirrors PhoneSignInScreen's pop-on-signin). We do NOT clear
    // the pending invite — at the gate mount that would re-route before the
    // users-doc stream lands coupleId and flash the share screen (finding 3).
    ref.listen(joinInviteControllerProvider, (previous, next) {
      // A settled, non-null coupleId is the success terminal (idle is
      // data(null); loading/error never carry one), so this fires exactly once.
      final coupleId = next.value;
      if (!next.isLoading && coupleId != null) {
        final navigator = Navigator.of(context);
        if (navigator.canPop()) navigator.pop();
      }
    });

    final join = ref.watch(joinInviteControllerProvider);
    final error = join.error;
    // A settled non-null coupleId means the join landed; at the gate mount we
    // stay put and hold a waiting indicator until coupleId re-routes the gate.
    final joined = !join.isLoading && join.value != null;
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (error != null) ...[
          // Per-exception honest copy in the theme's alert colour.
          Text(
            _joinErrorCopy(l10n, error),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
          const SizedBox(height: SpacingTokens.x4),
        ],
        if (_isTerminalCode(error))
          // This code will never work (expired/consumed/self/…): re-entering a
          // different code is the only honest next step, so Accept is replaced.
          FilledButton(
            onPressed: onReenter,
            child: Text(l10n.joinEnterAnotherCode),
          )
        else if (join.isLoading || joined)
          // In-flight, or joined and waiting for the gate to re-route: a
          // disabled progress button either way.
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
            onPressed: () => unawaited(
              ref.read(joinInviteControllerProvider.notifier).join(code),
            ),
            child: Text(l10n.joinAcceptButton),
          ),
        // The "not now" exit disappears once the join succeeds — dismissing a
        // completed pairing makes no sense.
        if (!joined) ...[
          const SizedBox(height: SpacingTokens.x4),
          TextButton(onPressed: onDismiss, child: Text(l10n.joinSkipForNow)),
        ],
      ],
    );
  }
}

/// True for a join failure that condemns THIS code (so the UI offers a fresh
/// code rather than a pointless retry). Network/permission/unknown are retryable
/// and profile-missing is fixed elsewhere, so they keep the Accept button.
bool _isTerminalCode(Object? error) =>
    error is InviteJoinUnknownCodeException ||
    error is InviteJoinExpiredException ||
    error is InviteJoinConsumedException ||
    error is InviteJoinSelfJoinException ||
    error is InviteJoinAlreadyPairedException;

/// Maps each sealed [InviteException] member to its honest localized join copy.
/// Exhaustive over the sealed type — a new member is a compile error here, which
/// is the point: every join failure must have a considered surface.
String _joinErrorCopy(AppLocalizations l10n, Object error) {
  if (error is! InviteException) return l10n.errorGeneric;
  return switch (error) {
    InviteJoinUnknownCodeException() => l10n.joinErrorUnknownCode,
    InviteJoinExpiredException() => l10n.joinErrorExpired,
    InviteJoinConsumedException() => l10n.joinErrorConsumed,
    InviteJoinSelfJoinException() => l10n.joinErrorSelfJoin,
    InviteJoinAlreadyPairedException() => l10n.joinErrorAlreadyPaired,
    InviteJoinProfileMissingException() => l10n.joinErrorProfileMissing,
    InviteNetworkException() => l10n.errorNetworkRetry,
    // A stale/out-of-contract session and any unclassified failure share the
    // generic surface (neither is a per-code condition the user can act on).
    InvitePermissionException() => l10n.errorGeneric,
    InviteUnknownException() => l10n.errorGeneric,
  };
}

/// EXPIRED-OR-UNKNOWN state: a single honest surface for a code that isn't
/// joinable, offering a re-entry (the server keeps expired/used/malformed/absent
/// indistinguishable, so the copy makes no false promises).
class _UnavailablePreview extends StatelessWidget {
  const _UnavailablePreview({required this.onReenter});

  final VoidCallback onReenter;

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
                  l10n.invitePreviewUnavailableTitle,
                  style: theme.textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: SpacingTokens.x3),
                Text(
                  l10n.invitePreviewUnavailableBody,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: SpacingTokens.x6),
                FilledButton(
                  onPressed: onReenter,
                  child: Text(l10n.joinEnterAnotherCode),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ERROR state: the preview FETCH failed (network / off-contract), distinct from
/// an expired/unknown result — retryable by re-fetching the family entry.
class _PreviewError extends ConsumerWidget {
  const _PreviewError({required this.code});

  final String code;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: SpacingTokens.screenGutter,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Error copy in the theme's alert colour (alert-on-night OK).
                Text(
                  l10n.invitePreviewFailedBody,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
                const SizedBox(height: SpacingTokens.x6),
                FilledButton(
                  onPressed: () => ref.invalidate(invitePreviewProvider(code)),
                  child: Text(l10n.tryAgain),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
