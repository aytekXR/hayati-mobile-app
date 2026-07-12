import 'package:hayati_app/features/data_rights/domain/data_export.dart';
import 'package:hayati_app/features/data_rights/domain/data_rights_repository.dart';

/// Hand-written fake backing the data-rights domain/presentation tests, in the
/// [FakeCoachRepository] recorder style: ordered call logs prove what was sent,
/// and the `on*` knobs override the outcome (throw a [DataRightsException], gate
/// on a Completer, …). Defaults are inert-but-loud where a missing arrangement
/// would otherwise hang.
class FakeDataRightsRepository implements DataRightsRepository {
  /// Behaviour of the next [deleteAccount]; default returns normally (success).
  Future<void> Function()? onDeleteAccount;

  /// Behaviour of the next [exportData]; default returns [cannedExport].
  Future<DataExport> Function()? onExportData;

  /// Behaviour of the next [updateNotificationPrivacy]; default returns normally.
  Future<void> Function(bool discreet)? onUpdateNotificationPrivacy;

  int deleteAccountCalls = 0;
  int exportDataCalls = 0;

  /// The ordered `discreet` arguments passed to [updateNotificationPrivacy].
  final List<bool> notificationPrivacyCalls = [];

  /// A minimal, valid export document for the happy path.
  static const DataExport cannedExport = DataExport(
    formatVersion: 1,
    generatedAt: '2026-07-12T09:00:00.000Z',
    uid: 'uid-1',
    data: {
      'profile': {'status': 'married', 'contentLanguage': 'tr'},
      'soloAnswers': <Object?>[],
      'note': 'Question text is referenced by questionId only.',
    },
  );

  @override
  Future<void> deleteAccount() {
    deleteAccountCalls++;
    final handler = onDeleteAccount;
    if (handler != null) return handler();
    return Future<void>.value();
  }

  @override
  Future<DataExport> exportData() {
    exportDataCalls++;
    final handler = onExportData;
    if (handler != null) return handler();
    return Future<DataExport>.value(cannedExport);
  }

  @override
  Future<void> updateNotificationPrivacy({required bool discreet}) {
    notificationPrivacyCalls.add(discreet);
    final handler = onUpdateNotificationPrivacy;
    if (handler != null) return handler(discreet);
    return Future<void>.value();
  }
}
