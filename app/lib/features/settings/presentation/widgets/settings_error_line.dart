import 'package:flutter/material.dart';

import '../../../../core/design_system/color_tokens.dart';
import '../../../../core/design_system/spacing_tokens.dart';
import '../../../../core/l10n/gen/app_localizations.dart';

/// One honest failure line under the row (or action) that produced it, or
/// nothing. The house idiom for localized, per-row failure copy on the settings
/// surface (ADR-018 D7); reused by the ADR-019 data-rights screens. [resolve] is
/// a deferred `String Function(AppLocalizations)?` resolved against l10n at render
/// time, so callers can hold an error without a BuildContext.
class SettingsErrorLine extends StatelessWidget {
  const SettingsErrorLine({super.key, required this.resolve});

  final String Function(AppLocalizations)? resolve;

  @override
  Widget build(BuildContext context) {
    final resolve = this.resolve;
    if (resolve == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: SpacingTokens.cardPadding,
        end: SpacingTokens.cardPadding,
        bottom: SpacingTokens.x3,
      ),
      child: Text(
        resolve(AppLocalizations.of(context)),
        style: theme.textTheme.bodySmall?.copyWith(color: ColorTokens.alert),
      ),
    );
  }
}
