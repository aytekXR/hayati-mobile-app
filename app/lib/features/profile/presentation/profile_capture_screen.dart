import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/gen/app_localizations.dart';
import '../domain/content_language_bootstrap.dart';
import '../domain/profile_exception.dart';
import '../domain/relationship_profile.dart';
import 'state/profile_capture_controller.dart';

/// Onboarding profile capture (docs/prd.md F1): relationship status,
/// content language (bootstrapped from the locale, user-overridable) and —
/// for Turkish only — the dual tone register. Unstyled pre-brandkit,
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
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          children: [
            Text(
              l10n.onboardingTitle,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 24),
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
            const SizedBox(height: 24),
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
              const SizedBox(height: 24),
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
              const SizedBox(height: 24),
              _SaveErrorView(failure: failure),
            ],
            const SizedBox(height: 32),
            if (saving) ...[
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 16),
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
        const SizedBox(height: 12),
        // Wrap flows with text direction and never overflows, whatever the
        // locale's label lengths — safer than a segmented row pre-brandkit.
        Wrap(
          spacing: 8,
          runSpacing: 8,
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
    final l10n = AppLocalizations.of(context);
    final detail = switch (failure) {
      ProfileNetworkException() => l10n.errorNetworkRetry,
      ProfilePermissionException() ||
      ProfileUnknownException() => l10n.errorGeneric,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.profileSaveFailedTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(detail),
      ],
    );
  }
}
