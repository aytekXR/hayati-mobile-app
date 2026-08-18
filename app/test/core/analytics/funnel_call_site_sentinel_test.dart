import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/core/analytics/funnel_event.dart';

/// **Sentinel B** (ADR-057 Decision 6): every client event is actually EMITTED
/// somewhere, not merely declared.
///
/// ## Why there are two sentinels and not one
///
/// Revision 1 of ADR-057 proposed a single list sentinel and claimed it answered
/// *"each screen emits an event is satisfied by twelve hand-written call sites
/// that drift apart"*. It does not: a vocabulary check proves the event **type**
/// exists. An emitter that declared all eight types and called none of them
/// would have passed it — which is ADR-025 D8's own error (*a declaration
/// nothing enforces reads as coverage*) committed inside the decision citing it.
/// `card_surface_sentinel_test.dart` already says this in its own header: *"WHY
/// IT IS NOT 'each screen has a shadow'"*.
///
/// So this one asks the TREE, in that sentinel's idiom: for each client event,
/// is there a `.<emitterMethodName>(` under `lib/features/` or in
/// `lib/app.dart`? The method name is DERIVED from the §7 wire name
/// ([FunnelEvent.emitterMethodName]), never hand-mapped, so this cannot drift
/// from the vocabulary Sentinel A pins to the document.
///
/// ## What it deliberately cannot see, recorded rather than discovered
///
/// **That the call site is on the right PATH.** An `invite_sent` emitted from an
/// error branch satisfies this test. Per-call-site behaviour — the happy path
/// emits, the failure path does not — is `funnel_call_sites_test.dart`'s job,
/// and every event here has a pair of tests there.
void main() {
  /// The source the app could plausibly emit from: every feature file, plus the
  /// composition root (where the three state-transition events live).
  ///
  /// `lib/core/analytics/` is EXCLUDED on purpose — it is where the methods are
  /// *defined*, and including it would let a definition masquerade as a call.
  List<File> emitterSites() {
    final files = <File>[
      File('lib/app.dart'),
      ...Directory('lib/features')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart')),
    ];
    return files.where((f) => f.existsSync()).toList();
  }

  test('the scan reads a real tree', () {
    // Lesson 110: a scan whose glob matches nothing reports the same clean zero
    // as a scan that passed. Every assertion below is a `contains` over this
    // corpus, so an empty corpus would make all of them vacuously true.
    final sites = emitterSites();
    expect(
      sites.length,
      greaterThan(100),
      reason:
          'scanned only ${sites.length} files under lib/features + lib/app.dart '
          '— the walker is broken, not the tree clean',
    );
    expect(
      sites.any((f) => f.path.endsWith('app.dart')),
      isTrue,
      reason: 'lib/app.dart is where install/signup/paired are wired',
    );
  });

  test('every CLIENT event has at least one call site', () {
    final sources = {
      for (final file in emitterSites()) file.path: file.readAsStringSync(),
    };

    for (final event in FunnelEvent.values.where(
      (e) => e.emitter == AnalyticsEmitter.client,
    )) {
      final needle = '.${event.emitterMethodName}(';
      final callers = sources.entries
          .where((entry) => entry.value.contains(needle))
          .map((entry) => entry.key)
          .toList();
      expect(
        callers,
        isNotEmpty,
        reason:
            '${event.wire} is a CLIENT event with no `$needle` anywhere under '
            'lib/features or lib/app.dart. Either wire it, or move it out of '
            'the client row in funnel_event.dart with a reason.',
      );
    }
  });

  test('the not-built exclusion is EXACTLY share_card_created, and it is '
      'justified by mvp.md', () {
    // A one-name exclusion list that can quietly grow is how an unwired funnel
    // step becomes permanent. Adding a second one turns this red and forces the
    // justification to be written somewhere a reviewer will read it.
    final notBuilt = FunnelEvent.values
        .where((e) => e.emitter == AnalyticsEmitter.notBuilt)
        .map((e) => e.wire)
        .toList();
    expect(notBuilt, ['share_card_created']);

    final mvp = File('../docs/mvp.md').readAsStringSync();
    expect(
      mvp.length,
      greaterThan(1000),
      reason: 'docs/mvp.md read as ${mvp.length} chars — the path moved',
    );
    final out = mvp.substring(mvp.indexOf('## OUT'));
    expect(
      out,
      contains('shareable result cards'),
      reason:
          'share_card_created is excluded because mvp.md lists share cards as '
          'OUT. If that changed, the exclusion has lost its justification and '
          'the event needs a call site.',
    );
  });

  test('no SERVER event is emitted from the client', () {
    // The other direction: if someone wires a `paid` on the device, the whole
    // reason for ADR-057 D1 has been undone — that event would timestamp the
    // moment the phone noticed, not the moment money moved.
    final sources = {
      for (final file in emitterSites()) file.path: file.readAsStringSync(),
    };
    for (final event in FunnelEvent.values.where(
      (e) => e.emitter == AnalyticsEmitter.server,
    )) {
      final needle = '.${event.emitterMethodName}(';
      final callers = sources.entries
          .where((entry) => entry.value.contains(needle))
          .map((entry) => entry.key)
          .toList();
      expect(
        callers,
        isEmpty,
        reason:
            '${event.wire} is a SERVER event (ADR-013 / ADR-057 D1) but is '
            'called from $callers. The app learns entitlement from a mirror; a '
            'client emitter here would be a lie about when it happened.',
      );
    }
  });
}
