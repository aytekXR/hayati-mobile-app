/// Self-checking tests for the store-metadata lint (M6.3, ADR-020 D6).
///
/// Runner decision (mirrors content/validator/validate_test.dart): `tool/` has
/// no pubspec, so `package:test` can't run here without inventing one; this is
/// a plain-`dart` self-checking script — every `_check` is an assertion, any
/// failure exits non-zero. Each rule class is mutation-checked against a temp
/// `fastlane/metadata` tree: the shipped-shape happy path passes, and each
/// violation class fails with a field-precise message.
///
///     dart tool/store_metadata_lint_test.dart
library;

import 'dart:io';

import 'store_metadata_lint.dart';

var _passed = 0;
final List<String> _failures = [];

void _check(String name, bool condition) {
  if (condition) {
    _passed++;
  } else {
    _failures.add(name);
  }
}

/// The shipped-shape field set for one locale. A `null` override omits that
/// file; an override key not in the base set writes an extra file (e.g. an
/// unknown-filename typo). URLs default empty, like the real tree.
const Map<String, String> _base = {
  'name': 'Hayati',
  'subtitle': 'One question a day, for two',
  'description': 'A private daily ritual for two.',
  'keywords': 'couples,marriage,partner',
  'promotional_text': 'Now in closed beta.',
  'release_notes': 'First closed-beta build.',
  'privacy_url': '',
  'support_url': '',
  'marketing_url': '',
};

void _writeLocale(
  String root,
  String locale, {
  Map<String, String?> overrides = const {},
}) {
  final dir = Directory('$root/fastlane/metadata/$locale')
    ..createSync(recursive: true);
  _base.forEach((stem, value) {
    final resolved = overrides.containsKey(stem) ? overrides[stem] : value;
    if (resolved == null) return; // omit this file
    File('${dir.path}/$stem.txt').writeAsStringSync(resolved);
  });
  overrides.forEach((stem, value) {
    if (!_base.containsKey(stem) && value != null) {
      File('${dir.path}/$stem.txt').writeAsStringSync(value);
    }
  });
}

void _reset(String root) {
  final dir = Directory('$root/fastlane/metadata');
  if (dir.existsSync()) dir.deleteSync(recursive: true);
  dir.createSync(recursive: true);
}

(int, String, String) _run(String root, List<String> args) {
  final out = StringBuffer();
  final err = StringBuffer();
  final code = runStoreMetadataLint(args, out: out, err: err, root: root);
  return (code, out.toString(), err.toString());
}

void main() {
  final temp = Directory.systemTemp.createTempSync('hayati_metadata_lint_test');
  try {
    final root = temp.path;

    // Happy path: valid en-US + tr, empty URLs accepted under the flag.
    _reset(root);
    _writeLocale(root, 'en-US');
    _writeLocale(root, 'tr');
    var (code, out, err) = _run(root, ['--allow-empty-urls', 'en-US', 'tr']);
    _check('happy path exits 0', code == 0);
    _check('happy path reports PASS', out.contains('PASS'));
    _check('happy path counts URL warnings', err.contains('WARNING'));

    // Missing flag: empty required URLs are a hard failure without the flag.
    (code, out, err) = _run(root, ['en-US', 'tr']);
    _check('empty URLs without the flag exit 1', code == 1);
    _check(
      'empty-URL failure names the field',
      err.contains('privacy_url.txt') && err.contains('empty URL'),
    );

    // Oversize name.
    _reset(root);
    _writeLocale(root, 'en-US', overrides: {'name': 'H' * 31});
    (code, out, err) = _run(root, ['--allow-empty-urls', 'en-US']);
    _check('oversize name exits 1', code == 1);
    _check(
      'oversize name names the limit',
      err.contains('name.txt') && err.contains('exceeds the 30 limit'),
    );

    // Trailing whitespace in a single-line field.
    _reset(root);
    _writeLocale(root, 'en-US', overrides: {'subtitle': 'One a day '});
    (code, out, err) = _run(root, ['--allow-empty-urls', 'en-US']);
    _check('trailing space exits 1', code == 1);
    _check(
      'trailing space is named',
      err.contains('subtitle.txt') && err.contains('whitespace'),
    );

    // Internal newline in a single-line field.
    _reset(root);
    _writeLocale(root, 'en-US', overrides: {'name': 'Hay\nati'});
    (code, out, err) = _run(root, ['--allow-empty-urls', 'en-US']);
    _check('internal newline exits 1', code == 1);
    _check('internal newline is named', err.contains('internal newline'));

    // Duplicate keyword term (case-insensitive).
    _reset(root);
    _writeLocale(root, 'en-US', overrides: {'keywords': 'couples,Couples'});
    (code, out, err) = _run(root, ['--allow-empty-urls', 'en-US']);
    _check('duplicate keyword exits 1', code == 1);
    _check(
      'duplicate keyword is named',
      err.contains('duplicate keyword term'),
    );

    // Empty keyword term (a stray comma).
    _reset(root);
    _writeLocale(root, 'en-US', overrides: {'keywords': 'couples,,partner'});
    (code, out, err) = _run(root, ['--allow-empty-urls', 'en-US']);
    _check('empty keyword term exits 1', code == 1);
    _check('empty keyword term is named', err.contains('empty keyword term'));

    // Unknown .txt filename in a locale dir.
    _reset(root);
    _writeLocale(root, 'en-US', overrides: {'subtile': 'typo'});
    (code, out, err) = _run(root, ['--allow-empty-urls', 'en-US']);
    _check('unknown file exits 1', code == 1);
    _check(
      'unknown file is named',
      err.contains('subtile.txt') && err.contains('unknown metadata file'),
    );

    // Missing required text file.
    _reset(root);
    _writeLocale(root, 'en-US', overrides: {'description': null});
    (code, out, err) = _run(root, ['--allow-empty-urls', 'en-US']);
    _check('missing required file exits 1', code == 1);
    _check(
      'missing required file is named',
      err.contains('description.txt is missing'),
    );

    // Missing required URL file.
    _reset(root);
    _writeLocale(root, 'en-US', overrides: {'privacy_url': null});
    (code, out, err) = _run(root, ['--allow-empty-urls', 'en-US']);
    _check('missing required URL file exits 1', code == 1);
    _check(
      'missing required URL file is named',
      err.contains('privacy_url.txt is missing'),
    );

    // marketing_url is optional: absent is fine.
    _reset(root);
    _writeLocale(root, 'en-US', overrides: {'marketing_url': null});
    (code, out, err) = _run(root, ['--allow-empty-urls', 'en-US']);
    _check('absent marketing_url still passes', code == 0);

    // ...but a present, malformed marketing_url is still checked.
    _reset(root);
    _writeLocale(root, 'en-US', overrides: {'marketing_url': 'https://x '});
    (code, out, err) = _run(root, ['--allow-empty-urls', 'en-US']);
    _check('malformed marketing_url exits 1', code == 1);
    _check(
      'malformed marketing_url is named',
      err.contains('marketing_url.txt') && err.contains('whitespace'),
    );

    // A locale dir on disk that is not in the allowlist.
    _reset(root);
    _writeLocale(root, 'en-US');
    _writeLocale(root, 'de'); // not passed to the lint
    (code, out, err) = _run(root, ['--allow-empty-urls', 'en-US']);
    _check('unlisted locale dir exits 1', code == 1);
    _check(
      'unlisted locale dir is named',
      err.contains('fastlane/metadata/de') && err.contains('allowlist'),
    );

    // An allowlisted locale with no dir on disk.
    _reset(root);
    _writeLocale(root, 'en-US');
    (code, out, err) = _run(root, ['--allow-empty-urls', 'en-US', 'tr']);
    _check('missing allowlisted locale exits 1', code == 1);
    _check(
      'missing allowlisted locale is named',
      err.contains('fastlane/metadata/tr') && err.contains('missing'),
    );

    // Usage errors: no locale, unknown flag, duplicate locale.
    _reset(root);
    _writeLocale(root, 'en-US');
    _check('no locale exits 64', _run(root, ['--allow-empty-urls']).$1 == 64);
    _check('unknown flag exits 64', _run(root, ['--nope', 'en-US']).$1 == 64);
    _check(
      'duplicate locale exits 64',
      _run(root, ['en-US', 'en-US']).$1 == 64,
    );

    // Missing metadata dir is an input error, never a green pass.
    final bare = Directory.systemTemp.createTempSync('hayati_metadata_bare');
    try {
      _check(
        'missing metadata dir exits 64',
        runStoreMetadataLint(
              ['en-US'],
              out: StringBuffer(),
              err: StringBuffer(),
              root: bare.path,
            ) ==
            64,
      );
    } finally {
      bare.deleteSync(recursive: true);
    }
  } finally {
    temp.deleteSync(recursive: true);
  }

  if (_failures.isEmpty) {
    stdout.writeln('store_metadata_lint self-tests: $_passed checks passed');
  } else {
    stderr.writeln(
      'store_metadata_lint self-tests: ${_failures.length} FAILED, '
      '$_passed passed',
    );
    for (final name in _failures) {
      stderr.writeln('  FAIL: $name');
    }
    exitCode = 1;
  }
}
