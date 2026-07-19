import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A SOURCE-SENTINEL test — it reads the lock screen's widget sources from disk
/// and asserts the absence of calls, in the exact shape of
/// `no_invalidate_sentinel_test.dart` and `biometric_only_contract_test.dart`.
///
/// THE INVARIANT (ADR-018 Decision 3; blocking review findings SEC-7 /
/// FLUTTER-1; ADR-025 D5.i, issue #61):
/// `LockScreen` sits ABOVE the app's only Navigator — it is a Stack sibling of
/// the child `MaterialApp.builder` receives — so it has **NO Navigator, NO
/// Overlay and NO Scaffold ancestor**. Every API below looks up one of those
/// ancestors and THROWS when it finds none. On the recovery path that crash IS
/// the lockout: the user is stuck behind a lock screen that cannot sign them
/// out. This is the ONE of ADR-018's four lock invariants that had no mechanism
/// — it lived in a file-header comment plus a single behavioural assertion on
/// the recovery path (`lock_screen_test.dart`), so any NEW interaction path
/// introducing one of these would have shipped green.
///
/// WHY a source sentinel and not a widget test: a widget test can only prove the
/// paths it drives. The failure mode here is a path nobody thought to drive —
/// a cooldown tooltip, a biometric-error dialog, a long-pressable countdown.
/// Only reading the source can assert "not anywhere, on any path".
///
/// If this test fails, do not delete it and do not weaken the list. The
/// recovery confirmation is an INLINE two-phase widget state precisely so that
/// none of this is needed (ADR-018 D3). The settings screen's PIN-verify dialog
/// is a different story — it is pushed INSIDE the Navigator and may use
/// `showDialog` normally (ADR-018 D7).
void main() {
  /// The root of the lock-screen widget subtree.
  const rootPath = 'lib/features/privacy_lock/presentation/lock_screen.dart';

  /// The files the scan set MUST contain. ADR-025 D5.i specified a
  /// hand-maintained two-file list and recorded the resulting gap as an accepted
  /// negative ("a future widget mounted by LockScreen and not added to the list
  /// is unguarded"). Slice 0 implements the stronger form the ADR asked for but
  /// judged uncomputable: the set is DERIVED (see [_scanSet]) from the real
  /// import graph, so a shared widget added tomorrow is scanned tomorrow. These
  /// two are kept as the floor — the sentinel-of-the-sentinel — so a derivation
  /// that silently returns nothing (a rename, a refactor, a bug in the walker)
  /// fails LOUDLY instead of passing vacuously over an empty set.
  const mustContain = <String>[
    rootPath,
    'lib/features/privacy_lock/presentation/widgets/pin_keypad.dart',
  ];

  /// Every API that looks up an ancestor `LockScreen` does not have.
  ///
  /// `tooltip:` (lowercase) is listed alongside `Tooltip` deliberately, and
  /// `IconButton` is banned outright: `IconButton`, `PopupMenuButton` and
  /// friends BUILD a `Tooltip` internally when handed a `tooltip:` argument, so
  /// a sentinel scanning only for the class name would miss the single most
  /// natural way to introduce this crash (the ADR-025 pre-code review's
  /// MECH-2). The safe alternatives — `TextButton.icon`, a bare `InkWell` —
  /// never perform an Overlay lookup.
  ///
  /// The text-selection family is ADR-018 D3's own co-equal entry ("or a
  /// text-selection-enabled field", `lock_screen.dart`): a selection toolbar
  /// mounts into an Overlay, so a long-press on a `SelectableText` countdown
  /// crashes exactly like a dialog would.
  ///
  /// `ScaffoldMessenger.of` is an ADDITION beyond ADR-018 D3's written list,
  /// made here because it is the same failure in the same class: this screen
  /// provides its own `Material` and has no `Scaffold` above it, so a snackbar
  /// would throw for the same reason. Recorded in ADR-025 rather than smuggled.
  const forbidden = <String, String>{
    'showDialog': 'needs an Overlay; there is none above LockScreen',
    'showModalBottomSheet': 'needs an Overlay; there is none above LockScreen',
    'showMenu': 'needs an Overlay; there is none above LockScreen',
    'Navigator.of': 'LockScreen sits ABOVE the app\'s only Navigator',
    'Tooltip': 'mounts into an Overlay when shown',
    'tooltip:': 'IconButton/PopupMenuButton build a Tooltip from this argument',
    'IconButton': 'builds a Tooltip internally when given tooltip:',
    'Autocomplete': 'renders its options list in an Overlay',
    'DropdownButton': 'renders its menu in an Overlay',
    'SelectableText': 'its selection toolbar mounts into an Overlay',
    'TextField': 'text selection mounts a toolbar into an Overlay',
    'TextFormField': 'text selection mounts a toolbar into an Overlay',
    'EditableText': 'text selection mounts a toolbar into an Overlay',
    'ScaffoldMessenger.of': 'there is no Scaffold above LockScreen either',
  };

  /// Walks the transitive closure of RELATIVE imports from [rootPath] and keeps
  /// the files that declare a widget. Package and dart: imports are not
  /// followed — Flutter's own sources are not ours to police, and the guarantee
  /// is about what WE mount.
  ///
  /// Filtering to widget-declaring files is what keeps this precise: the raw
  /// import closure also reaches generated localizations, domain models and
  /// repositories, none of which contribute widgets to this subtree — and the
  /// generated `app_localizations_*.dart` files carry arbitrary translated
  /// prose, which is exactly where a false positive would come from.
  List<String> scanSet() {
    final widgetDecl = RegExp(
      r'extends\s+(StatelessWidget|StatefulWidget|ConsumerWidget|'
      r'ConsumerStatefulWidget|ConsumerState|State)\b',
    );
    final importLine = RegExp("^import '([^']+)';", multiLine: true);

    final seen = <String>{};
    final queue = <String>[rootPath];
    final widgets = <String>[];

    while (queue.isNotEmpty) {
      final path = _normalize(queue.removeAt(0));
      if (!seen.add(path)) continue;
      final file = File(path);
      if (!file.existsSync()) continue;

      final source = file.readAsStringSync();
      if (widgetDecl.hasMatch(source)) widgets.add(path);

      for (final match in importLine.allMatches(source)) {
        final target = match.group(1)!;
        if (target.startsWith('package:') || target.startsWith('dart:')) {
          continue;
        }
        queue.add('${_dirname(path)}/$target');
      }
    }
    return widgets..sort();
  }

  late List<String> scanned;

  setUpAll(() {
    expect(
      File(rootPath).existsSync(),
      isTrue,
      reason:
          'the sentinel must fail loudly if the lock screen is renamed or moved '
          'rather than pass vacuously — re-point rootPath and keep the pin',
    );
    scanned = scanSet();
  });

  test('the derived scan set covers the known lock-screen widget files', () {
    // The sentinel-of-the-sentinel. Without this, a walker that returns an
    // empty list would make every assertion below pass over nothing.
    for (final required in mustContain) {
      expect(
        scanned,
        contains(required),
        reason:
            'the import-graph walk must reach $required — an empty or shrunken '
            'scan set makes this whole sentinel vacuous (ADR-025 D5.i)',
      );
    }
  });

  test(
    'no lock-screen widget calls an API that needs a missing ancestor (D3)',
    () {
      for (final path in scanned) {
        // Strip comment lines first: `lock_screen.dart`'s HARD CONSTRAINT header
        // NAMES every forbidden call in prose, so an unstripped scan would match
        // its own explanation and fail vacuously — the same reason
        // `no_invalidate_sentinel_test.dart` strips before scanning.
        final code = File(path)
            .readAsStringSync()
            .split('\n')
            .where((line) => !line.trimLeft().startsWith('//'))
            .join('\n');

        forbidden.forEach((token, why) {
          expect(
            code,
            isNot(contains(token)),
            reason:
                '$path uses `$token` — $why. On the recovery path that crash IS '
                'the lockout (ADR-018 D3). Use the inline two-phase widget '
                'state instead; see the HARD CONSTRAINT header in '
                '$rootPath.',
          );
        });
      }
    },
  );
}

String _dirname(String path) {
  final i = path.lastIndexOf('/');
  return i < 0 ? '.' : path.substring(0, i);
}

/// Collapses `a/b/../c` to `a/c` so the same file reached by two import paths is
/// visited once. Kept local (and POSIX-only) because these are Dart import
/// strings, which always use forward slashes regardless of host platform —
/// `path.normalize` would introduce backslashes on Windows and break the
/// `mustContain` comparison.
String _normalize(String path) {
  final out = <String>[];
  for (final part in path.split('/')) {
    if (part == '.' || part.isEmpty) continue;
    if (part == '..') {
      if (out.isNotEmpty && out.last != '..') {
        out.removeLast();
      } else {
        out.add(part);
      }
      continue;
    }
    out.add(part);
  }
  return out.join('/');
}
