import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/color_tokens.dart';
import '../../../core/design_system/spacing_tokens.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../domain/data_export.dart';
import 'state/data_export_provider.dart';

/// The self-serve export screen (ADR-019 Decision 5, the `PinSetupScreen` mold):
/// loading → calls the repository → renders the versioned JSON document,
/// selectable and copy-to-clipboard. Honest states only — a failure shows a plain
/// retry (never a half-built document), and the copy says "your data" with no
/// completeness over-claim. The document is rendered AS-IS: answers carry
/// `questionId` only (the export's own `note` says so), so the screen never
/// resolves question wording.
class ExportScreen extends ConsumerWidget {
  const ExportScreen({super.key, required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final export = ref.watch(dataExportProvider);
    final loaded = switch (export) {
      AsyncData(:final value) => value,
      _ => null,
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.dataRightsExportTitle),
        actions: [
          if (loaded != null)
            IconButton(
              icon: const Icon(Icons.copy_outlined),
              tooltip: l10n.dataRightsExportCopy,
              onPressed: () => _copy(context, l10n, loaded),
            ),
        ],
      ),
      body: SafeArea(
        child: switch (export) {
          AsyncData(:final value) => _Document(value: value),
          AsyncError() => _ErrorView(
            onRetry: () => ref.invalidate(dataExportProvider),
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }

  void _copy(BuildContext context, AppLocalizations l10n, DataExport export) {
    Clipboard.setData(ClipboardData(text: export.toPrettyJson()));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.dataRightsExportCopied)));
  }
}

class _Document extends StatelessWidget {
  const _Document({required this.value});

  final DataExport value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.screenGutter,
        vertical: SpacingTokens.x5,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.dataRightsExportIntro, style: theme.textTheme.bodyMedium),
          const SizedBox(height: SpacingTokens.x5),
          // The document is data, not prose — a selectable block so the reader
          // can copy any part by hand as well as via the copy action. Rendered in
          // the body font (no forced monospace) so it stays readable in every
          // script the app ships.
          SelectableText(
            value.toPrettyJson(),
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: SpacingTokens.screenGutter,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.dataRightsExportError,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: ColorTokens.alert,
              ),
            ),
            const SizedBox(height: SpacingTokens.x6),
            FilledButton(onPressed: onRetry, child: Text(l10n.tryAgain)),
          ],
        ),
      ),
    );
  }
}
