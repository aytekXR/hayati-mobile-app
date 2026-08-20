import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/legal/domain/legal_version.dart';

/// STRUCTURAL guard over the version-3 DRAFT in `docs/legal/proposed/`
/// (ADR-058 Decision 8, issue #226).
///
/// **This file is deleted by the diff that lands the revision.** Its first
/// assertion is that `docs/legal/proposed/` exists, so the two are coupled on
/// purpose: a bump that moves the draft into force cannot leave a stale guard
/// behind. The same applies if a DIFFERENT revision becomes version 3 first —
/// see `docs/legal/proposed/README.md`, which carries both paths.
///
/// **What this guards is SHAPE, and that bound is deliberate.** It does not
/// review the law, does not check translation fidelity, does not know whether a
/// disclosure is adequate, and cannot tell a good notice from a bad one. The
/// founder and the founder's lawyer guard substance; a green run here says
/// nothing about them.
///
/// Every content assertion below is paired with a **non-empty control** on the
/// SHIPPED document (lesson 110: a scan whose input is empty reports the same
/// clean zero as a scan that passed). The floors in the first group exist for
/// the same reason.
void main() {
  // Under `flutter test` the CWD is app/, so the sibling trees are one level up.
  const proposedDir = '../docs/legal/proposed';
  const shippedDir = '../docs/legal';
  const locales = ['tr', 'ar', 'en'];

  /// The version line is LOCALISED. A literal `Version N.` match would guard one
  /// locale of three — the "a gate written in one language guards one language"
  /// shape (`session-lessons.md`, recurring shape 5), caught by the ADR-058
  /// design review before this file was written rather than after.
  const versionPattern = <String, String>{
    'en': r'^Version (\d+)\.',
    'tr': r'^Sürüm (\d+)\.',
    'ar': r'^الإصدار (\d+)\.',
  };

  /// The exact sentences this revision exists to correct. Asserted PRESENT in
  /// the shipped document (the control) and ABSENT from the draft.
  const anchors = <String, List<String>>{
    'en': [
      'ikimiz does not send push notifications today.',
      'There is no analytics or tracking product in the app today',
    ],
    'tr': [
      'ikimiz bugün anlık bildirim (push) göndermez.',
      'Uygulamada bugün herhangi bir analitik veya takip ürünü bulunmamaktadır',
    ],
    'ar': [
      'لا يرسل ikimiz إشعارات فورية اليوم.',
      'ولا يوجد في التطبيق اليوم أيّ منتج تحليلات أو تتبّع',
    ],
  };

  String proposedPath(String locale) =>
      '$proposedDir/privacy-policy.$locale.md';
  String shippedPath(String locale) => '$shippedDir/privacy-policy.$locale.md';

  String readProposed(String locale) =>
      File(proposedPath(locale)).readAsStringSync();
  String readShipped(String locale) =>
      File(shippedPath(locale)).readAsStringSync();

  List<String> sectionsOf(String source) => source
      .split('\n')
      .where((line) => line.startsWith('## '))
      .map((line) => line.substring(3).trim())
      .toList();

  int declaredVersion(String source, String locale) {
    final match = RegExp(
      versionPattern[locale]!,
      multiLine: true,
    ).firstMatch(source);
    expect(
      match,
      isNotNull,
      reason:
          'no localised version line matching ${versionPattern[locale]} — the '
          '$locale document must open with its own "version N" line',
    );
    return int.parse(match!.group(1)!);
  }

  group('the draft exists and is a closed set', () {
    test('$proposedDir holds exactly the four expected files', () {
      final directory = Directory(proposedDir);
      expect(
        directory.existsSync(),
        isTrue,
        reason:
            '$proposedDir is missing. If the revision LANDED, this test file '
            'must be deleted in that same diff (ADR-058 Decision 8); if it was '
            'superseded, delete both — see docs/legal/proposed/README.md.',
      );

      final names =
          directory
              .listSync()
              .map((entity) => entity.uri.pathSegments.last)
              .toList()
            ..sort();
      expect(
        names,
        equals([
          'README.md',
          'privacy-policy.ar.md',
          'privacy-policy.en.md',
          'privacy-policy.tr.md',
        ]),
        reason:
            'the proposal is a CLOSED set: three privacy policies and the '
            'landing procedure. A locale that went missing must be a red, not a '
            'clean zero. The terms are deliberately not part of this revision '
            '(ADR-058 Decision 3).',
      );
    });

    for (final locale in locales) {
      test('privacy-policy.$locale.md clears the input floor', () {
        final lines = readProposed(locale).split('\n');
        // docs/legal/README.md's authoring rules: ~100-160 lines per policy.
        expect(
          lines.length,
          greaterThanOrEqualTo(90),
          reason:
              'a truncated draft would pass every content assertion below by '
              'having nothing left to fail on',
        );
        expect(lines.length, lessThanOrEqualTo(160));
        expect(
          sectionsOf(readProposed(locale)).length,
          greaterThanOrEqualTo(9),
        );
      });
    }
  });

  group('the draft is exactly one version ahead and has NOT landed', () {
    test('currentLegalVersion is still 2 — the bump is a founder decision', () {
      expect(
        currentLegalVersion,
        equals(2),
        reason:
            'the version-3 draft is in docs/legal/proposed/ precisely because '
            'landing it re-gates consent for EVERY existing user (ADR-023 D4). '
            'If the bump has happened, this whole test file and the proposal '
            'directory go with it (ADR-058 Decision 8).',
      );
    });

    for (final locale in locales) {
      test('privacy-policy.$locale.md declares version '
          '${currentLegalVersion + 1}', () {
        expect(
          declaredVersion(readShipped(locale), locale),
          equals(currentLegalVersion),
          reason:
              'CONTROL: the shipped $locale document must declare the version '
              'the app expects. If this fails, the drift is in the shipped '
              'bundle, not in the proposal.',
        );
        expect(
          declaredVersion(readProposed(locale), locale),
          equals(currentLegalVersion + 1),
          reason:
              'the draft must be exactly ONE version ahead of what shipped — '
              'not two, and not equal',
        );
      });
    }
  });

  group('the draft obeys the in-app renderer subset', () {
    // docs/legal/README.md: the renderer understands `#` (once, first line),
    // `##`, `- `, and blank-line-separated paragraphs. Anything else renders as
    // plain body text, so formatting is LOST SILENTLY rather than throwing —
    // which is exactly why it needs a test rather than a review.
    const forbidden = <String, String>{
      r'\|': 'table',
      r'\]\(': 'link',
      r'\*\*': 'bold',
      // Deliberately NOT `(?<!\w)_[^_\n]+_(?!\w)`. Dart's `\w` is `[A-Za-z0-9_]`
      // and matches no Arabic or Turkish letter, so the word-boundary lookarounds
      // succeed around Arabic text and fail around English — the SAME
      // "guards one language" defect (recurring shape 5) the version pattern
      // above was fixed for, one pattern over. A legal document has no business
      // containing an underscore pair at all, so the bare form is both simpler
      // and symmetric across the three locales.
      r'_[^_\n]+_': 'italic',
      '`': 'inline code',
      r'^>': 'block quote',
      r'^!\[': 'image',
      r'^[ \t]*\d+\.\s': 'numbered list',
      // `[ \t]`, NOT `\s`: `\s` matches the newline, so `^\s+- ` fires on every
      // ordinary bullet that follows a blank line. Caught by running it.
      r'^[ \t]+- ': 'nested bullet',
    };

    for (final locale in locales) {
      test('privacy-policy.$locale.md uses no unsupported markdown', () {
        final source = readProposed(locale);
        forbidden.forEach((pattern, name) {
          final match = RegExp(pattern, multiLine: true).firstMatch(source);
          expect(
            match,
            isNull,
            reason:
                'found $name syntax in privacy-policy.$locale.md at offset '
                '${match?.start}: the in-app renderer does not understand it, '
                'so it would ship as literal characters in a legal document',
          );
        });
      });

      test('privacy-policy.$locale.md has exactly one `#` title, first', () {
        final lines = readProposed(locale).split('\n');
        expect(lines.first.startsWith('# '), isTrue);
        expect(lines.where((line) => line.startsWith('# ')).length, equals(1));
      });
    }
  });

  group('the draft keeps the shipped structure and the locales agree', () {
    test('all three locales carry the same sections, in the same order', () {
      // Headings are LOCALISED, so the three lists cannot be compared as
      // strings. The SHIPPED documents are the interlingua: each locale's
      // shipped headings are already parallel, so projecting each proposed
      // heading onto its index in that locale's shipped list yields a
      // language-free sequence that IS comparable across locales.
      //
      // Comparing `.length` alone — which this test did until the built-diff
      // review — passes for three documents whose sections are entirely
      // different as long as the counts match. That is a vacuous assertion
      // wearing the name of a real one (recurring shapes 1 and 5).
      final shapes = <String, List<int>>{};
      for (final locale in locales) {
        final shipped = sectionsOf(readShipped(locale));
        expect(
          shipped,
          isNotEmpty,
          reason: 'CONTROL: the shipped $locale document must have sections',
        );
        shapes[locale] = [
          for (final heading in sectionsOf(readProposed(locale)))
            shipped.indexOf(heading),
        ];
      }

      for (final entry in shapes.entries) {
        expect(
          entry.value,
          isNot(contains(-1)),
          reason:
              'a section in the ${entry.key} draft matches no heading in the '
              '${entry.key} shipped document. Either it was renamed (which the '
              'lawyer must see as a rename, not as churn) or it is a NEW '
              'section — and a new section must be added to all three locales '
              'and to this test deliberately.',
        );
      }

      expect(
        // `.join`, not the lists themselves: Dart `List` has identity equality,
        // so a Set of three structurally identical lists has length 3 and this
        // assertion would fail on every correct input. Found by running it.
        shapes.values.map((shape) => shape.join(',')).toSet(),
        hasLength(1),
        reason:
            'the three locales must carry the same substantive content — not '
            'word-for-word, but no locale may promise anything another does '
            'not (docs/legal/README.md). The section skeleton is the part of '
            'that a machine can check; the rest is the native review. '
            'Projected onto the shipped headings the three drafts differ: '
            '$shapes',
      );
    });

    for (final locale in locales) {
      test('privacy-policy.$locale.md drops no shipped section', () {
        final shipped = sectionsOf(readShipped(locale));
        final proposed = sectionsOf(readProposed(locale));
        expect(
          shipped,
          isNotEmpty,
          reason: 'CONTROL: the shipped $locale document must have sections',
        );

        // Every shipped heading must still be present, in the same relative
        // order. Additions are allowed; deletions and renames are not.
        var cursor = 0;
        for (final heading in shipped) {
          final index = proposed.indexOf(heading, cursor);
          expect(
            index,
            greaterThanOrEqualTo(0),
            reason:
                'the shipped section "$heading" is missing from (or reordered '
                'in) the $locale draft. A revision may ADD a section; silently '
                'dropping one is how "How long we keep your data" disappears.',
          );
          cursor = index + 1;
        }
      });
    }
  });

  group('the sentences this revision exists to correct are gone', () {
    for (final locale in locales) {
      test('privacy-policy.$locale.md corrects both anchors', () {
        final shipped = readShipped(locale);
        final proposed = readProposed(locale);
        for (final anchor in anchors[locale]!) {
          // The CONTROL half. If this fails, the shipped text moved and the
          // proposal's premise moved with it — which is the message a later
          // session needs, and is why the absence assertion below is evidence
          // rather than a vacuous pass.
          expect(
            shipped.contains(anchor),
            isTrue,
            reason:
                'the shipped $locale document no longer contains "$anchor". '
                'This guard can no longer see what it was written to watch — '
                're-derive the proposal against the current shipped text before '
                'trusting it (#226, ADR-058).',
          );
          expect(
            proposed.contains(anchor),
            isFalse,
            reason:
                'the $locale draft still contains "$anchor" — the sentence '
                'issue #226 exists to correct',
          );
        }
      });
    }
  });

  group('the draft carries its blanks, and the Arabic keeps its bidi mark', () {
    // The same span shape tool/ci/build_site.py refuses to publish. Four, not
    // three: the effective date joins the legal entity and the two contact
    // addresses, and is REQUIRED to be a placeholder — nobody can know the day
    // the founder says go (ADR-058 Decision 4).
    final placeholderSpan = RegExp(r'\[[^\[\]\n]*—[^\[\]\n]*\]');

    for (final locale in locales) {
      test('privacy-policy.$locale.md carries four unfilled placeholders', () {
        final proposed = readProposed(locale);
        expect(
          placeholderSpan.allMatches(proposed),
          hasLength(4),
          reason:
              'expected the three inherited blanks plus the effective date. A '
              'filled-in blank in a DRAFT means someone invented a fact '
              '(session-context.md §7); a fifth means a new one appeared '
              'unannounced.',
        );
        expect(
          placeholderSpan.allMatches(readShipped(locale)),
          hasLength(3),
          reason:
              'CONTROL: the shipped document carries three. If this changed, '
              'the blanks were filled or added upstream and the draft needs '
              're-deriving.',
        );
      });
    }

    test('the Arabic draft keeps exactly one U+200F, as the shipped one does', () {
      // The shipped ar document carries a single RLM, immediately after the
      // `(` that opens the Latin-script processor list — without it the neutral
      // paren resolves to the wrong side in an RTL paragraph. It is INVISIBLE,
      // it sits inside the one bullet this revision edits, and nothing else in
      // the repo would notice it being dropped.
      const rlm = '‏';
      expect(
        rlm.allMatches(readShipped('ar')).length,
        equals(1),
        reason: 'CONTROL: the shipped Arabic policy carries exactly one RLM',
      );
      expect(
        rlm.allMatches(readProposed('ar')).length,
        equals(1),
        reason:
            'the Arabic draft must carry the same single RLM. Dropping it '
            'renders the processor list\'s opening parenthesis on the wrong '
            'side, and no other check in this repo can see that.',
      );
      expect(
        readProposed('ar').contains('(${rlm}Firebase Authentication'),
        isTrue,
        reason:
            'the RLM must sit where it does in the shipped document — '
            'immediately after the paren that opens the Latin run',
      );
    });
  });
}
