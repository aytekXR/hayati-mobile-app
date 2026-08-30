// ADR-index lint — fails CI when `docs/adr/README.md`'s index and the ADR files
// on disk disagree (ADR-067, issue #248).
//
// WHY THIS EXISTS AS A GATE RATHER THAN A HABIT. The index fell **eighteen**
// records behind (049–066) before anyone counted, and it was priority 1 in three
// consecutive session prompts, deferred each time for something correctly more
// urgent. A process that depends on remembering, at the end, after the
// interesting part, is not a process. ADR-025 D8 reached the opposite conclusion
// for golden declarations — *discipline, not a CI gate* — and that was right for
// a judgement a machine cannot make. This is a set comparison.
//
// WHAT IT ASSERTS — a BIJECTION between the files and the rows (ADR-067 D2):
//   1. every `docs/adr/NNN-*.md` has exactly one index row;
//   2. every row's link resolves to a file that exists;
//   3. a row's number matches the file its link points at — `[051](052-….md)`
//      reads correctly and sends the reader to the wrong decision;
//   4. no number appears in two rows;
//   5. every row has exactly THREE cells. ⚠️ This one was added while building
//      the lint, because the shipped index already violated it: row 042 carries
//      an unescaped `|` inside a code span (`{kind:'ok'|'profile-missing'}`) and
//      GitHub-flavored markdown does NOT let backticks protect a pipe in a
//      table — so that row renders with its summary truncated and "Accepted"
//      pushed into a fourth column. A row that silently loses its Status is the
//      same class of defect as a row that is missing.
//
// WHAT IT DELIBERATELY DOES NOT ASSERT (ADR-067 D2):
//   * CONTIGUITY of the numbers. A hole harms nobody; an unindexed file harms
//     every session looking for precedent. Asserting a neighbouring property
//     that merely happens to be true makes the guard the thing that is wrong the
//     first time a renumbering is legitimate (ADR-029).
//   * anything about the summary TEXT. A minimum length is satisfiable with
//     padding, and padding is worse than absence because it looks like coverage.
//     **The lint guards presence; a review guards meaning.**
//
// Usage:   dart tool/adr_index_lint.dart [<repo-root>]
// Exit codes: 0 = clean (PASS), 1 = violations (FAIL), 64 = usage/input error
//             (missing directory or no index table — "could not check" must
//             never read as green; ADR-020 D6's taxonomy, ADR-041's rule).
//
// Pure `dart:io`, no package imports, so it runs in the `quality` job before any
// `pub get` — the property that makes this whole lint family cheap.

import 'dart:io';

const int exUsage = 64;

/// A row parsed out of the index table.
class IndexRow {
  IndexRow(this.lineNumber, this.number, this.target, this.cellCount);
  final int lineNumber;
  final String number;
  final String target;
  final int cellCount;
}

/// Pipes that actually separate cells: a `\|` is an escaped literal, not a
/// separator. Getting this wrong in either direction is how a lint reports a
/// well-formed row as broken, or misses the one row that is.
int unescapedPipes(String s) {
  var count = 0;
  for (var i = 0; i < s.length; i++) {
    if (s[i] == '|' && (i == 0 || s[i - 1] != r'\')) count++;
  }
  return count;
}

/// The index rows, identified by the shape every one of them has: a line
/// beginning `| [NNN](target)`. Deliberately narrow — the Format section above
/// the table is prose and must not parse as a row.
final RegExp _rowPattern = RegExp(r'^\| \[(\d{3})\]\(([^)]+)\)');

/// An ADR file. `README.md` is the index itself and is not a record.
final RegExp _filePattern = RegExp(r'^(\d{3})-.+\.md$');

void main(List<String> args) {
  exitCode = runAdrIndexLint(args, out: stdout, err: stderr);
}

/// The lint proper, with its output sinks injected so the self-tests can drive
/// it without a subprocess - the shape `store_metadata_lint.dart` established.
int runAdrIndexLint(
  List<String> args, {
  required StringSink out,
  required StringSink err,
}) {
  final root = args.isEmpty ? '.' : args.first;
  final adrDir = Directory('$root/docs/adr');
  final indexFile = File('$root/docs/adr/README.md');

  if (!adrDir.existsSync()) {
    err.writeln(
      'adr-index lint: ${adrDir.path} does not exist — cannot check.',
    );
    return exUsage;
  }
  if (!indexFile.existsSync()) {
    err.writeln(
      'adr-index lint: ${indexFile.path} does not exist — cannot check.',
    );
    return exUsage;
  }

  final files = <String, String>{}; // number -> filename
  final duplicateFiles = <String>[];
  for (final entity in adrDir.listSync()) {
    if (entity is! File) continue;
    final name = entity.uri.pathSegments.last;
    final match = _filePattern.firstMatch(name);
    if (match == null) continue;
    final number = match.group(1)!;
    if (files.containsKey(number)) {
      duplicateFiles.add('$number: ${files[number]} and $name');
    }
    files[number] = name;
  }

  final lines = indexFile.readAsLinesSync();
  final rows = <IndexRow>[];
  for (var i = 0; i < lines.length; i++) {
    final match = _rowPattern.firstMatch(lines[i]);
    if (match == null) continue;
    final body = lines[i].trim();
    final inner = body.startsWith('|') && body.endsWith('|')
        ? body.substring(1, body.length - 1)
        : body;
    rows.add(
      IndexRow(
        i + 1,
        match.group(1)!,
        match.group(2)!,
        unescapedPipes(inner) + 1,
      ),
    );
  }

  if (rows.isEmpty) {
    err.writeln(
      'adr-index lint: no index rows found in ${indexFile.path} — the table is '
      'missing or its shape changed. Refusing to report a clean index that was '
      'never read.',
    );
    return exUsage;
  }

  final violations = <String>[];

  // 4. no number twice
  final seen = <String, int>{};
  for (final row in rows) {
    if (seen.containsKey(row.number)) {
      violations.add(
        'ADR-${row.number} has two index rows (lines ${seen[row.number]} and ${row.lineNumber}).',
      );
    } else {
      seen[row.number] = row.lineNumber;
    }
  }

  // 2 + 3. the link resolves, and to the file the number names
  for (final row in rows) {
    if (!File('${adrDir.path}/${row.target}').existsSync()) {
      violations.add(
        'line ${row.lineNumber}: ADR-${row.number}\'s link points at "${row.target}", '
        'which does not exist in docs/adr/.',
      );
      continue;
    }
    if (!row.target.startsWith('${row.number}-')) {
      violations.add(
        'line ${row.lineNumber}: the row says ADR-${row.number} but links to '
        '"${row.target}" — it reads correctly and sends the reader to the wrong decision.',
      );
    }
  }

  // 5. exactly three cells
  for (final row in rows) {
    if (row.cellCount != 3) {
      violations.add(
        'line ${row.lineNumber}: ADR-${row.number}\'s row has ${row.cellCount} cells, not 3 — '
        'an unescaped "|" (escape it as \\| even inside backticks; GFM does not '
        'let a code span protect a pipe in a table). The Status column is being '
        'silently lost.',
      );
    }
  }

  // 1. every file has a row — the failure that happened eighteen times
  final indexed = rows.map((r) => r.number).toSet();
  final missing = files.keys.where((n) => !indexed.contains(n)).toList()
    ..sort();
  for (final number in missing) {
    violations.add(
      'ADR-$number (${files[number]}) has NO row in the index. '
      'Add it in the same commit as the ADR — that is the whole point of this lint (ADR-067).',
    );
  }

  for (final duplicate in duplicateFiles) {
    violations.add('two ADR files claim the same number — $duplicate');
  }

  if (violations.isNotEmpty) {
    err.writeln('adr-index lint: FAIL (${violations.length} violation(s))');
    for (final violation in violations) {
      err.writeln('  - $violation');
    }
    return 1;
  }

  out.writeln(
    'adr-index lint: PASS (${files.length} record(s), ${rows.length} row(s), bijection holds)',
  );
  return 0;
}
