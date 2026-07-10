/// Question-pack validator — thin IO shell (M3.1; core in validator_core.dart).
///
/// Usage (from the repo root; CI runs exactly this in the ubuntu `quality`
/// job — docs/test-suite.md §2):
///
///     dart content/validator/validate.dart              # check everything
///     dart content/validator/validate.dart --sync       # authoring sync
///     dart content/validator/validate.dart --strict-review
///
/// Check mode validates BOTH trees — `content/packs/` (the single authoring
/// home, ADR-010) and `app/assets/content/` (the bundled sync output) — plus
/// the checks between them: byte-identical copies, no orphans either way.
/// `--sync` regenerates the app tree from `content/packs/` (byte-copy,
/// orphan delete) after the authoring tree validates clean; check mode never
/// writes, so CI fails on drift instead of hiding it. `--strict-review`
/// promotes the reviewedBy shippability warning to an error (launch posture,
/// W9/ADR-007). Exit: 0 ok (warnings allowed) · 1 violations/drift · 64
/// usage · 66 missing inputs.
library;

import 'dart:io';

import 'validator_core.dart';

const _packsDir = 'content/packs';
const _appAssetsDir = 'app/assets/content';
const _schemaPath = 'content/schema/question-pack.schema.json';

Future<void> main(List<String> args) async {
  exitCode = runValidator(args, out: stdout, err: stderr);
}

/// In-process entrypoint so the self-tests (`validate_test.dart`) can drive
/// the shell against a temp root without spawning a VM per case. [root] is
/// the repo root; defaults to the current directory.
int runValidator(
  List<String> args, {
  required StringSink out,
  required StringSink err,
  String root = '.',
}) {
  var sync = false;
  var strictReview = false;
  for (final arg in args) {
    switch (arg) {
      case '--sync':
        sync = true;
      case '--strict-review':
        strictReview = true;
      default:
        err.writeln(
          'unknown argument "$arg" — usage: dart content/validator/'
          'validate.dart [--sync] [--strict-review]',
        );
        return 64;
    }
  }

  final schemaFile = File('$root/$_schemaPath');
  final packsDir = Directory('$root/$_packsDir');
  final appDir = Directory('$root/$_appAssetsDir');
  if (!schemaFile.existsSync()) {
    err.writeln('missing $_schemaPath — run from the repo root');
    return 66;
  }
  if (!packsDir.existsSync()) {
    err.writeln('missing $_packsDir/ — run from the repo root');
    return 66;
  }

  final issues = <PackIssue>[];

  // The core's vocabulary and the JSON Schema file must agree before pack
  // results mean anything.
  issues.addAll(validateSchemaAgreement(schemaFile.readAsStringSync()));

  // Authoring tree: per-pack + cross-pack.
  final packFiles = _jsonFiles(packsDir);
  if (packFiles.isEmpty) {
    issues.add(
      const PackIssue(
        IssueSeverity.error,
        _packsDir,
        'no packs found — the app bundles the solo packs from here (ADR-010)',
      ),
    );
  }
  issues.addAll(
    _validateTree(packFiles, prefix: _packsDir, strictReview: strictReview),
  );

  if (issues.any((i) => i.isError)) {
    _report(issues, out: out, err: err);
    if (sync) err.writeln('refusing --sync: the authoring tree is invalid');
    return 1;
  }

  if (sync) {
    if (!appDir.existsSync()) appDir.createSync(recursive: true);
    final authored = {for (final f in packFiles) _basename(f.path)};
    for (final file in packFiles) {
      final target = File('${appDir.path}/${_basename(file.path)}');
      target.writeAsBytesSync(file.readAsBytesSync());
      out.writeln('synced $_appAssetsDir/${_basename(file.path)}');
    }
    for (final file in _jsonFiles(appDir)) {
      if (!authored.contains(_basename(file.path))) {
        file.deleteSync();
        out.writeln('deleted orphan $_appAssetsDir/${_basename(file.path)}');
      }
    }
  }

  // Bundled tree: same per-pack + cross-pack rules (its own id universe —
  // the copies legitimately repeat the authoring tree's ids), then drift.
  if (!appDir.existsSync()) {
    issues.add(
      const PackIssue(
        IssueSeverity.error,
        _appAssetsDir,
        'missing — run with --sync to generate the bundled copies',
      ),
    );
  } else {
    final appFiles = _jsonFiles(appDir);
    // Errors only: the drift check makes the copies byte-identical, so their
    // warnings would just repeat the authoring tree's.
    issues.addAll(
      _validateTree(
        appFiles,
        prefix: _appAssetsDir,
        strictReview: strictReview,
      ).where((i) => i.isError),
    );
    issues.addAll(_driftIssues(packFiles, appFiles));
  }

  _report(issues, out: out, err: err);
  return issues.any((i) => i.isError) ? 1 : 0;
}

List<PackIssue> _validateTree(
  List<File> files, {
  required String prefix,
  required bool strictReview,
}) {
  final issues = <PackIssue>[];
  final parsed = <ParsedPack>[];
  for (final file in files) {
    final result = validatePackSource(
      relativePath: '$prefix/${_basename(file.path)}',
      source: file.readAsStringSync(),
      strictReview: strictReview,
    );
    issues.addAll(result.issues);
    if (result.pack != null) parsed.add(result.pack!);
  }
  issues.addAll(validateAcrossPacks(parsed));
  return issues;
}

List<PackIssue> _driftIssues(List<File> packFiles, List<File> appFiles) {
  final issues = <PackIssue>[];
  final authored = {for (final f in packFiles) _basename(f.path): f};
  final bundled = {for (final f in appFiles) _basename(f.path): f};

  for (final name in authored.keys) {
    final copy = bundled[name];
    if (copy == null) {
      issues.add(
        PackIssue(
          IssueSeverity.error,
          '$_appAssetsDir/$name',
          'missing bundled copy of $_packsDir/$name — run '
              '`dart content/validator/validate.dart --sync`',
        ),
      );
    } else if (!_sameBytes(authored[name]!, copy)) {
      issues.add(
        PackIssue(
          IssueSeverity.error,
          '$_appAssetsDir/$name',
          'drifted from $_packsDir/$name — author under $_packsDir and run '
              '`dart content/validator/validate.dart --sync`',
        ),
      );
    }
  }
  for (final name in bundled.keys) {
    if (!authored.containsKey(name)) {
      issues.add(
        PackIssue(
          IssueSeverity.error,
          '$_appAssetsDir/$name',
          'orphan: no matching $_packsDir/$name — packs are authored under '
              '$_packsDir only (ADR-010); run --sync to remove it',
        ),
      );
    }
  }
  return issues;
}

void _report(
  List<PackIssue> issues, {
  required StringSink out,
  required StringSink err,
}) {
  for (final issue in issues) {
    (issue.isError ? err : out).writeln(issue);
  }
  final errors = issues.where((i) => i.isError).length;
  final warnings = issues.length - errors;
  out.writeln(
    errors == 0
        ? 'question packs OK ($warnings warning${warnings == 1 ? '' : 's'})'
        : 'question packs INVALID: $errors error${errors == 1 ? '' : 's'}, '
              '$warnings warning${warnings == 1 ? '' : 's'}',
  );
}

List<File> _jsonFiles(Directory dir) =>
    dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

String _basename(String path) => path.split(Platform.pathSeparator).last;

bool _sameBytes(File a, File b) {
  final ab = a.readAsBytesSync();
  final bb = b.readAsBytesSync();
  if (ab.length != bb.length) return false;
  for (var i = 0; i < ab.length; i++) {
    if (ab[i] != bb[i]) return false;
  }
  return true;
}
