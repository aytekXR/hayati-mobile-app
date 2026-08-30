// Self-tests for tool/adr_index_lint.dart (ADR-067, issue #248).
//
// WHAT WOULD MAKE THIS GATE WORTHLESS. A lint whose whole job is to notice an
// ABSENCE fails in the quiet direction: it stops matching rows, finds nothing to
// compare, and reports a clean index it never read. Every check below is aimed
// at that shape rather than at the happy path:
//
//   * a FIXTURE with a missing row must FAIL — the eighteen-times defect;
//   * a row whose link resolves to the wrong file must FAIL, because it reads
//     correctly and sends the reader to the wrong decision;
//   * an unescaped `|` must FAIL — the defect shipped row 042 has carried since
//     it landed, and the reason assertion 5 exists;
//   * **an index with no parseable rows must be 64, never 0.** This is the
//     dangerous one: if the table's shape ever changes, a lint that returned
//     "no rows, no missing rows, PASS" would be green forever over an index
//     nobody was checking (ADR-041's "never 0 without having compared");
//   * a missing directory must be 64, for the same reason;
//   * and CONTIGUITY must NOT fail — a gap in the numbers is a legal state
//     (ADR-067 Finding 4), and a lint that reddened on one would teach the next
//     session to renumber around it.
//
// Run: dart tool/adr_index_lint_test.dart

import 'dart:io';

import 'adr_index_lint.dart' as lint;

final List<String> failures = <String>[];

void check(String name, bool condition, [String detail = '']) {
  if (!condition) {
    failures.add('$name: ${detail.isEmpty ? 'assertion failed' : detail}');
  } else {
    stdout.writeln('  ok   $name');
  }
}

/// Builds a throwaway repo root: docs/adr/ with the given files and index body.
Directory fixture({
  required List<String> adrFiles,
  required String indexBody,
  bool writeIndex = true,
}) {
  final root = Directory.systemTemp.createTempSync('adr_index_lint_test');
  final adr = Directory('${root.path}/docs/adr')..createSync(recursive: true);
  for (final name in adrFiles) {
    File('${adr.path}/$name').writeAsStringSync('# stub\n');
  }
  if (writeIndex) {
    File('${adr.path}/README.md').writeAsStringSync(indexBody);
  }
  return root;
}

const String _header = '''
# Architecture Decision Records

Some prose. It mentions | pipes | and [links](001-a.md) but is not a table row.

## Index

| ADR | Decision | Status |
|---|---|---|
''';

int run(Directory root, {StringBuffer? out, StringBuffer? err}) =>
    lint.runAdrIndexLint(
      [root.path],
      out: out ?? StringBuffer(),
      err: err ?? StringBuffer(),
    );

void main() {
  // ---------------------------------------------------------------- the happy path
  {
    final root = fixture(
      adrFiles: ['001-a.md', '002-b.md'],
      indexBody:
          '$_header'
          '| [001](001-a.md) | first | Accepted |\n'
          '| [002](002-b.md) | second | Accepted |\n',
    );
    final out = StringBuffer();
    final code = run(root, out: out);
    check('clean/exit-0', code == 0, 'got $code');
    check(
      'clean/reports-the-counts',
      out.toString().contains('2 record(s), 2 row(s)'),
      'the PASS line must say what it compared; got ${out.toString().trim()}',
    );
    root.deleteSync(recursive: true);
  }

  // ------------------------------------------------- the defect this lint exists for
  {
    final root = fixture(
      adrFiles: ['001-a.md', '002-b.md', '003-c.md'],
      indexBody: '$_header| [001](001-a.md) | first | Accepted |\n',
    );
    final err = StringBuffer();
    final code = run(root, err: err);
    check('missing-rows/exit-1', code == 1, 'got $code');
    check(
      'missing-rows/names-each',
      err.toString().contains('ADR-002') && err.toString().contains('ADR-003'),
      'both absent records must be named; got ${err.toString()}',
    );
    check(
      'missing-rows/names-the-file',
      err.toString().contains('002-b.md'),
      'naming the number without the filename makes the reader go looking',
    );
    root.deleteSync(recursive: true);
  }

  // -------------------------------------------- a row that reads right and is wrong
  {
    final root = fixture(
      adrFiles: ['001-a.md', '002-b.md'],
      indexBody:
          '$_header'
          '| [001](001-a.md) | first | Accepted |\n'
          '| [002](001-a.md) | second, but linked to 001 | Accepted |\n',
    );
    final err = StringBuffer();
    final code = run(root, err: err);
    check('wrong-target/exit-1', code == 1, 'got $code');
    check(
      'wrong-target/explains-the-cost',
      err.toString().contains('wrong decision'),
      'the message must say WHY it matters; got ${err.toString()}',
    );
    root.deleteSync(recursive: true);
  }

  // ------------------------------------------------------------- a dangling link
  {
    final root = fixture(
      adrFiles: ['001-a.md'],
      indexBody:
          '$_header'
          '| [001](001-a.md) | first | Accepted |\n'
          '| [002](002-gone.md) | points at nothing | Accepted |\n',
    );
    final err = StringBuffer();
    check('dangling/exit-1', run(root, err: err) == 1);
    check(
      'dangling/names-the-target',
      err.toString().contains('002-gone.md'),
      'got ${err.toString()}',
    );
    root.deleteSync(recursive: true);
  }

  // ------------------------------------------------- the pipe that eats the Status
  {
    final root = fixture(
      adrFiles: ['001-a.md'],
      indexBody:
          '$_header'
          "| [001](001-a.md) | a summary with `{kind:'ok'|'missing'}` in it | Accepted |\n",
    );
    final err = StringBuffer();
    final code = run(root, err: err);
    check('unescaped-pipe/exit-1', code == 1, 'got $code');
    check(
      'unescaped-pipe/says-how-to-fix',
      err.toString().contains(r'\|'),
      'the message must show the escape; got ${err.toString()}',
    );
    root.deleteSync(recursive: true);
  }

  // ...and the ESCAPED one must pass, or the fix for row 042 would not be a fix.
  {
    final root = fixture(
      adrFiles: ['001-a.md'],
      indexBody:
          '$_header'
          "| [001](001-a.md) | a summary with `{kind:'ok'\\|'missing'}` in it | Accepted |\n",
    );
    check(
      'escaped-pipe/exit-0',
      run(root) == 0,
      'an escaped pipe is a literal, not a separator — this is the row-042 fix',
    );
    root.deleteSync(recursive: true);
  }

  // --------------------------------------------------------------- duplicate rows
  {
    final root = fixture(
      adrFiles: ['001-a.md'],
      indexBody:
          '$_header'
          '| [001](001-a.md) | first | Accepted |\n'
          '| [001](001-a.md) | first, again | Accepted |\n',
    );
    final err = StringBuffer();
    check('duplicate-row/exit-1', run(root, err: err) == 1);
    check(
      'duplicate-row/names-both-lines',
      err.toString().contains('two index rows'),
      'got ${err.toString()}',
    );
    root.deleteSync(recursive: true);
  }

  // ------------------------------------------ THE DANGEROUS ONE: nothing to compare
  {
    final root = fixture(
      adrFiles: ['001-a.md', '002-b.md'],
      // A table whose row shape changed — every row silently stops matching.
      indexBody:
          '$_header* [001](001-a.md) — first\n* [002](002-b.md) — second\n',
    );
    final err = StringBuffer();
    final code = run(root, err: err);
    check(
      'no-rows/is-64-not-0',
      code == lint.exUsage,
      'an index it could not read must NEVER report a clean index; got $code',
    );
    check(
      'no-rows/says-it-refused',
      err.toString().contains('never read'),
      'got ${err.toString()}',
    );
    root.deleteSync(recursive: true);
  }

  // ------------------------------------------------------------- cannot even look
  {
    final root = Directory.systemTemp.createTempSync(
      'adr_index_lint_test_empty',
    );
    final err = StringBuffer();
    check('no-directory/is-64', run(root, err: err) == lint.exUsage);
    check(
      'no-directory/says-cannot-check',
      err.toString().contains('cannot check'),
      'got ${err.toString()}',
    );
    root.deleteSync(recursive: true);
  }

  {
    final root = fixture(
      adrFiles: ['001-a.md'],
      indexBody: '',
      writeIndex: false,
    );
    check('no-index-file/is-64', run(root) == lint.exUsage);
    root.deleteSync(recursive: true);
  }

  // ------------------------------- a GAP is legal, and the lint must not invent one
  {
    final root = fixture(
      adrFiles: ['001-a.md', '003-c.md'],
      indexBody:
          '$_header'
          '| [001](001-a.md) | first | Accepted |\n'
          '| [003](003-c.md) | third; 002 was claimed by a concurrent tree and abandoned | Accepted |\n',
    );
    check(
      'gap/is-legal',
      run(root) == 0,
      'ADR-067 Finding 4: contiguity is NOT the check, and a lint that reddened '
          'here would teach the next session to renumber around it',
    );
    root.deleteSync(recursive: true);
  }

  // ------------------------------------------ a non-ADR .md in the directory is fine
  {
    final root = fixture(
      adrFiles: ['001-a.md', 'NOTES.md', 'template.md'],
      indexBody: '$_header| [001](001-a.md) | first | Accepted |\n',
    );
    check(
      'non-adr-file/ignored',
      run(root) == 0,
      'only NNN-*.md files are records; README.md and any notes file are not',
    );
    root.deleteSync(recursive: true);
  }

  // ----------------------------------------------------- the real repo must be clean
  {
    final out = StringBuffer();
    final err = StringBuffer();
    final code = lint.runAdrIndexLint(['.'], out: out, err: err);
    check(
      'this-repo/is-clean',
      code == 0,
      'the lint must pass against the repo it ships in; got $code\n${err.toString()}',
    );
  }

  if (failures.isNotEmpty) {
    stderr.writeln('adr_index_lint_test: ${failures.length} FAILED');
    for (final failure in failures) {
      stderr.writeln('  - $failure');
    }
    exitCode = 1;
    return;
  }
  stdout.writeln('adr_index_lint_test: all checks passed');
}
