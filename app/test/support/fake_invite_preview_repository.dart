import 'package:hayati_app/features/pairing/domain/invite_preview.dart';
import 'package:hayati_app/features/pairing/domain/invite_preview_repository.dart';

/// Hand-written fake for the preview seam, in the same behaviour-knob style as
/// [FakeInviteRepository]: an [onPreview] hook overrides the outcome (throw an
/// [InviteException], never complete, return an expired/unknown result, …),
/// a [previewCalls] recorder and [previewedCodes] list prove what was fetched,
/// and the default returns [result] so a screen needing a valid preview renders
/// without arrangement.
class FakeInvitePreviewRepository implements InvitePreviewRepository {
  FakeInvitePreviewRepository({InvitePreviewResult? result})
    : result =
          result ??
          const InvitePreviewResult(
            status: InvitePreviewStatus.valid,
            creatorDisplayName: 'Aylin',
          );

  /// The preview returned by [preview] when [onPreview] is unset.
  final InvitePreviewResult result;

  /// Behaviour override for the next [preview] calls; default returns [result].
  Future<InvitePreviewResult> Function(String code)? onPreview;

  int previewCalls = 0;
  final List<String> previewedCodes = [];

  @override
  Future<InvitePreviewResult> preview(String code) {
    previewCalls++;
    previewedCodes.add(code);
    final handler = onPreview;
    if (handler != null) return handler(code);
    return Future<InvitePreviewResult>.value(result);
  }

  Future<void> dispose() async {}
}
