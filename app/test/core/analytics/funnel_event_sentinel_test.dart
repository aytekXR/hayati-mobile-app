import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/core/analytics/funnel_event.dart';

/// **Sentinel A** (ADR-057 Decision 6): the funnel vocabulary and
/// `docs/architecture.md` §7 cannot silently disagree.
///
/// It reads the sibling tree from the `app/` test cwd — the
/// `legal_version_sentinel_test` / `device_privacy_channel_parity_test`
/// precedent.
///
/// ## Three things this does that revision 1 of ADR-057 did not
///
/// 1. **Set equality, BOTH directions.** Revision 1 asserted only doc ⊆ code
///    (*"adding a thirteenth event turns the suite red"*). An event **deleted**
///    from §7 while the emitter kept it would have passed, and the emitter would
///    accumulate events the architecture no longer claims. Every parity test in
///    this repo compares sets (`schema_enum_parity`,
///    `push_diagnostic_vocabulary_parity`); so does this one.
///
/// 2. **A floor assertion BEFORE the comparison** — lesson **110**: *a scan
///    whose glob matches nothing reports the same clean zero as a scan that
///    passed.* Rename the §7 heading and a naive parser finds nothing, compares
///    ∅ to ∅, and goes green over a document it never read.
///
/// 3. **An explicit grammar, not a backtick sweep.** §7's paragraph contains
///    backticked identifiers that are NOT events — `logCoachEvent`, `coupleId` —
///    and a naive scan would demand the emitter implement them. The parse reads
///    the FIRST SENTENCE only, where every backticked span is an event name.
///
/// If §7 is reworded so this grammar no longer fits, the floor is what says so.
/// Re-anchor the parser; do not lower the floor.
void main() {
  const architecture = '../docs/architecture.md';

  /// The §7 event names, parsed from the document.
  Set<String> documentedEvents() {
    final source = File(architecture).readAsStringSync();

    // 1. the §7 section, from its heading to the next `## `.
    final heading = RegExp(
      r'^##\s*7\.\s*Analytics schema.*$',
      multiLine: true,
    ).firstMatch(source);
    expect(
      heading,
      isNotNull,
      reason:
          'the "## 7. Analytics schema" heading was renamed or moved in '
          '$architecture — re-anchor this parser rather than deleting it',
    );
    final rest = source.substring(heading!.end);
    final nextHeading = RegExp(r'^##\s', multiLine: true).firstMatch(rest);
    final section = nextHeading == null
        ? rest
        : rest.substring(0, nextHeading.start);

    // 2. the FIRST SENTENCE of it. Everything after it is prose ABOUT the
    //    events (the ADR-016 binding note), and that prose backticks
    //    `logCoachEvent` and `coupleId`, which are not events.
    final body = section.trim();
    final sentenceEnd = body.indexOf('. ');
    final firstSentence = sentenceEnd == -1
        ? body
        : body.substring(0, sentenceEnd);

    // 3. every backticked span in that sentence.
    final spans = RegExp(
      '`([^`]+)`',
    ).allMatches(firstSentence).map((m) => m.group(1)!).toList();
    expect(
      spans,
      isNotEmpty,
      reason:
          'no backticked span in §7\'s first sentence — the paragraph was '
          'restructured',
    );

    // 4. the first span is the arrow chain; the rest are single names. A
    //    brace alternation is ONE event with a dimension, so
    //    `q_answered{solo|mutual}` contributes `q_answered`.
    final names = <String>{};
    for (final (index, span) in spans.indexed) {
      final parts = index == 0 ? span.split('→') : <String>[span];
      for (final part in parts) {
        final name = part.replaceAll(RegExp(r'\{[^}]*\}'), '').trim();
        expect(
          RegExp(r'^[a-z][a-z_]*$').hasMatch(name),
          isTrue,
          reason:
              '"$name" parsed out of §7 is not an event name — the grammar no '
              'longer fits the paragraph',
        );
        names.add(name);
      }
    }
    return names;
  }

  test('the parser reads a REAL document, and reads enough of it', () {
    // The floor, before any comparison. Twelve is the count ADR-057 D1 records
    // and the count the partition arithmetic depends on.
    expect(
      File(architecture).existsSync(),
      isTrue,
      reason: '$architecture not found from the app/ test cwd',
    );
    expect(
      documentedEvents().length,
      greaterThanOrEqualTo(12),
      reason:
          'parsed only ${documentedEvents().length} event names out of §7 — '
          'the heading moved or the paragraph was restructured. The parser is '
          'broken, not the vocabulary clean.',
    );
  });

  test('the vocabulary and §7 are the SAME SET — additions AND deletions', () {
    expect(
      FunnelEvent.values.map((e) => e.wire).toSet(),
      documentedEvents(),
      reason:
          'architecture.md §7 and FunnelEvent disagree. An event added to the '
          'document needs a FunnelEvent (and an emitter row); an event removed '
          'from it needs removing here, or the app carries a funnel step the '
          'architecture no longer claims.',
    );
  });

  test('the three-way partition covers §7 exactly once (ADR-057 D1)', () {
    final documented = documentedEvents();
    final client = <String>{};
    final server = <String>{};
    final notBuilt = <String>{};
    for (final event in FunnelEvent.values) {
      switch (event.emitter) {
        case AnalyticsEmitter.client:
          client.add(event.wire);
        case AnalyticsEmitter.server:
          server.add(event.wire);
        case AnalyticsEmitter.notBuilt:
          notBuilt.add(event.wire);
      }
    }
    expect(client.union(server).union(notBuilt), documented);
    expect(
      client.length + server.length + notBuilt.length,
      documented.length,
      reason: 'the partition overlaps — an event is in two rows',
    );
    // The ADR states the arithmetic; here it is, against the document.
    expect(client, hasLength(8));
    expect(server, hasLength(3));
    expect(notBuilt, hasLength(1));
  });

  test('every CLIENT event has its derived payload type in the source', () {
    // Closes the chain the type system cannot: a payload subclass cannot exist
    // without a FunnelEvent (it must implement `name`), and this asserts the
    // reverse — every client name has a payload declared for it.
    final source = File(
      'lib/core/analytics/analytics_event.dart',
    ).readAsStringSync();
    expect(
      source.length,
      greaterThan(1000),
      reason:
          'analytics_event.dart read as ${source.length} chars — the path '
          'moved',
    );
    for (final event in FunnelEvent.values.where(
      (e) => e.emitter == AnalyticsEmitter.client,
    )) {
      expect(
        source,
        contains('final class ${event.payloadTypeName} extends AnalyticsEvent'),
        reason: '${event.wire} has no ${event.payloadTypeName} payload type',
      );
    }
  });

  test('the SERVER events have no client payload type — they are not ours', () {
    final source = File(
      'lib/core/analytics/analytics_event.dart',
    ).readAsStringSync();
    for (final event in FunnelEvent.values.where(
      (e) => e.emitter != AnalyticsEmitter.client,
    )) {
      expect(
        source,
        isNot(contains('class ${event.payloadTypeName}')),
        reason:
            '${event.wire} is ${event.emitter.name}, but a client payload type '
            'exists for it — either the emitter row is wrong or the app is '
            'about to claim an event it cannot honestly observe',
      );
    }
  });
}
