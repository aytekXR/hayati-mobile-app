import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/spacing_tokens.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../domain/content_language_bootstrap.dart';
import '../domain/profile_exception.dart';
import '../domain/relationship_profile.dart';
import 'state/profile_capture_controller.dart';

/// Onboarding profile capture (docs/prd.md F1): relationship status,
/// content language (bootstrapped from the locale, user-overridable) and —
/// for Turkish only — the dual tone register. Brand styling comes from the
/// theme (core/design_system/hayati_theme.dart) plus the spacing tokens below;
/// logical-direction only (RTL-safe).
class ProfileCaptureScreen extends ConsumerStatefulWidget {
  const ProfileCaptureScreen({super.key, required this.uid});

  final String uid;

  @override
  ConsumerState<ProfileCaptureScreen> createState() =>
      _ProfileCaptureScreenState();
}

class _ProfileCaptureScreenState extends ConsumerState<ProfileCaptureScreen> {
  RelationshipStatus? _status;
  ContentLanguage? _languageOverride;
  ContentRegister _register = ContentRegister.respectful;

  ContentLanguage _language(BuildContext context) =>
      _languageOverride ??
      // The app locale is already device-resolved against the same tr/ar/en
      // set (EN fallback), so it is the honest bootstrap input here; the
      // precedence contract itself is unit-tested in the domain.
      bootstrapContentLanguage(
        deviceLanguageCode: Localizations.localeOf(context).languageCode,
      );

  void _save(BuildContext context) {
    final language = _language(context);
    final profile = RelationshipProfile(
      status: _status!,
      contentLanguage: language,
      // The register choice is only surfaced for Turkish (dual-register
      // packs, docs/prd.md); other languages store the calm default.
      register: language == ContentLanguage.tr
          ? _register
          : ContentRegister.respectful,
    );
    unawaited(
      ref
          .read(profileCaptureControllerProvider.notifier)
          .save(widget.uid, profile),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final capture = ref.watch(profileCaptureControllerProvider);
    final saving = capture is CaptureSaving;
    final language = _language(context);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: SpacingTokens.screenGutter,
            vertical: SpacingTokens.x6,
          ),
          children: [
            Text(
              l10n.onboardingTitle,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: SpacingTokens.x6),
            _ChoiceSection<RelationshipStatus>(
              label: l10n.relationshipStatusLabel,
              values: RelationshipStatus.values,
              selected: _status,
              labelFor: (status) => switch (status) {
                RelationshipStatus.dating => l10n.statusDating,
                RelationshipStatus.engaged => l10n.statusEngaged,
                RelationshipStatus.married => l10n.statusMarried,
              },
              enabled: !saving,
              onSelected: (status) => setState(() => _status = status),
            ),
            const SizedBox(height: SpacingTokens.x6),
            _ChoiceSection<ContentLanguage>(
              label: l10n.contentLanguageLabel,
              values: ContentLanguage.values,
              selected: language,
              labelFor: (value) => switch (value) {
                ContentLanguage.tr => l10n.languageTurkish,
                ContentLanguage.ar => l10n.languageArabic,
                ContentLanguage.en => l10n.languageEnglish,
              },
              enabled: !saving,
              onSelected: (value) => setState(() => _languageOverride = value),
            ),
            if (language == ContentLanguage.tr) ...[
              const SizedBox(height: SpacingTokens.x6),
              _ChoiceSection<ContentRegister>(
                label: l10n.registerLabel,
                values: ContentRegister.values,
                selected: _register,
                labelFor: (register) => switch (register) {
                  ContentRegister.playful => l10n.registerPlayful,
                  ContentRegister.respectful => l10n.registerRespectful,
                },
                enabled: !saving,
                onSelected: (register) => setState(() => _register = register),
              ),
            ],
            if (capture case CaptureFailure(:final failure)) ...[
              const SizedBox(height: SpacingTokens.x6),
              _SaveErrorView(failure: failure),
            ],
          ],
        ),
      ),
      // The screen's sole primary action is pinned to the viewport bottom rather
      // than floating at the tail of the ListView (which wraps its children, so
      // the button rendered mid-screen over a large empty void). Anchoring the
      // one CTA gives it the spatial authority brandkit §4 ("one primary action
      // per screen") implies, completes the composition with no new elements
      // (§9.5 restraint), and keeps it reachable at 130% text scale. The
      // in-flight spinner rides above it; the save guard and _save call are
      // unchanged (behaviour frozen). ADR-025 slice 3.
      bottomNavigationBar: SafeArea(
        // Bottom inset only: Scaffold already strips the top padding from the
        // bottomNavigationBar slot, but pinning top:false makes "no status-bar
        // dead space above the button" explicit rather than implicit.
        top: false,
        minimum: const EdgeInsets.only(bottom: SpacingTokens.x6),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SpacingTokens.screenGutter,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (saving) ...[
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: SpacingTokens.x4),
              ],
              FilledButton(
                onPressed: (_status == null || saving)
                    ? null
                    : () => _save(context),
                child: Text(l10n.continueAction),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoiceSection<T> extends StatelessWidget {
  const _ChoiceSection({
    required this.label,
    required this.values,
    required this.selected,
    required this.labelFor,
    required this.enabled,
    required this.onSelected,
  });

  final String label;
  final List<T> values;
  final T? selected;
  final String Function(T value) labelFor;
  final bool enabled;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: SpacingTokens.x3),
        // Wrap flows with text direction and never overflows, whatever the
        // locale's label lengths — safer than a segmented row pre-brandkit.
        Wrap(
          spacing: SpacingTokens.x2,
          runSpacing: SpacingTokens.x2,
          children: [
            for (final value in values)
              ChoiceChip(
                label: Text(labelFor(value)),
                selected: value == selected,
                onSelected: enabled ? (_) => onSelected(value) : null,
              ),
          ],
        ),
      ],
    );
  }
}

class _SaveErrorView extends StatelessWidget {
  const _SaveErrorView({required this.failure});

  final ProfileException failure;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final detail = switch (failure) {
      ProfileNetworkException() => l10n.errorNetworkRetry,
      ProfilePermissionException() ||
      ProfileUnknownException() => l10n.errorGeneric,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.profileSaveFailedTitle, style: theme.textTheme.titleMedium),
        const SizedBox(height: SpacingTokens.x2),
        // Error copy in the theme's alert colour (alert-on-night 4.94:1 OK).
        Text(
          detail,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
      ],
    );
  }
}
