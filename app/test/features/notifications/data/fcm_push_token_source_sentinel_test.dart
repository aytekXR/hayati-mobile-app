import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// SOURCE-SENTINEL over one control-flow property inside
/// `FcmPushTokenSource.isReadyForToken()` — **the catch after `getAPNSToken()`
/// must not `return`** (ADR-077 D1; the defect ADR-077 D2 explains).
///
/// ## Why a sentinel, and not a test
///
/// Three barriers, each checked rather than assumed (S102):
///
/// 1. The branch sits behind `if (!Platform.isIOS) return true;`, and
///    `Platform.isIOS` is `dart:io`'s — `static final bool isIOS =
///    (operatingSystem == "ios")`, read from the host OS. It is **not**
///    `debugDefaultTargetPlatformOverride`, which moves Flutter's
///    `TargetPlatform` and is a different thing; and `IOOverrides` covers
///    `File`/`Directory`/`Socket`, not `Platform`. On a Linux runner the branch
///    is unreachable, full stop.
/// 2. The change is **invisible above the port.** `PushTokenSource.isReadyForToken`
///    returns `Future<bool>`, and the throw path returned `false` before this
///    fix and returns `false` after it. What changed is a fire-and-forget side
///    effect the port does not expose, so no fake and no seam can observe it.
/// 3. The fake in `push_token_sync_test.dart` cannot even produce the input:
///    it models `currentTokenThrows`, and nothing for `isReadyForToken`,
///    because the port never specified that state.
///
/// So the only thing that can stand in front of a re-introduction on this box
/// is an assertion over the source. That is the same trade
/// `signing_sentinel_test.dart` and `device_privacy_channel_parity_test.dart`
/// already make for surfaces `flutter test` cannot reach — applied here to a
/// **control-flow property inside one method** rather than to a file's
/// contents, which is the new shape.
///
/// ⚠️ **It is deliberately fragile.** If the method is restructured, these
/// assertions should break and a human should re-establish the invariant rather
/// than a regex quietly following the code somewhere it no longer means
/// anything.
void main() {
  const sourcePath =
      'lib/features/notifications/data/fcm_push_token_source.dart';

  late String source;
  late String catchBody;

  setUpAll(() {
    final file = File(sourcePath);
    expect(
      file.existsSync(),
      isTrue,
      reason:
          '$sourcePath is missing — if the adapter moved, this sentinel moves '
          'with it. Do not let it pass vacuously.',
    );
    source = file.readAsStringSync();

    // Anchor on the method, then on the call whose throw this is about, then on
    // the catch that follows it. Every step asserts, so a structural change
    // fails loudly here instead of silently widening the window below.
    final methodStart = source.indexOf('Future<bool> isReadyForToken()');
    expect(
      methodStart,
      isNot(-1),
      reason: 'isReadyForToken() is gone or renamed — re-point this sentinel',
    );
    final apnsRead = source.indexOf('getAPNSToken()', methodStart);
    expect(
      apnsRead,
      isNot(-1),
      reason:
          'isReadyForToken() no longer reads getAPNSToken() — the invariant '
          'below is about THAT read, so re-derive it rather than re-pointing',
    );
    const catchOpener = '} catch (_) {';
    final catchStart = source.indexOf(catchOpener, apnsRead);
    expect(
      catchStart,
      isNot(-1),
      reason:
          'no `$catchOpener` after the getAPNSToken() read — the catch this '
          'invariant is about has been rewritten; re-read ADR-077 D1',
    );
    final bodyStart = catchStart + catchOpener.length;
    final bodyEnd = source.indexOf('}', bodyStart);
    expect(
      bodyEnd,
      greaterThan(bodyStart),
      reason: 'the catch block is not closed — unparseable, not passing',
    );
    catchBody = source.substring(bodyStart, bodyEnd);

    // ⚠️ ANTI-VACUITY. The scan above stops at the first `}`, which is the
    // catch's own closing brace ONLY while the body contains no nested block
    // and no `}` inside a comment or string. If one ever appears, the window
    // shrinks to a prefix and every assertion below would pass over a fragment
    // — green, and measuring nothing. So: no `{` in the extracted body.
    expect(
      catchBody,
      isNot(contains('{')),
      reason:
          'the catch body now contains a nested block or a brace in prose, so '
          'this sentinel can no longer see all of it. Extract it properly '
          '(match braces) before trusting the assertions below.',
    );
  });

  test('the getAPNSToken catch does NOT return — it falls through (ADR-077 D1)', () {
    // THE INVARIANT. A `return` here is what shipped in build 121: the branch
    // whose own comment says *"Not 'no' — 'cannot tell'"* was the only branch
    // that never asked APNs for an address, which is the state where asking
    // matters most.
    //
    // Matches a return STATEMENT (`return;`, `return false;`) at the start of a
    // line, not the word "return" in the prose that explains why there is none.
    final hasReturn = RegExp(
      r'^\s*return[\s;]',
      multiLine: true,
    ).hasMatch(catchBody);
    expect(
      hasReturn,
      isFalse,
      reason:
          'the catch after getAPNSToken() returns early again. A throw there '
          'is *cannot tell whether we have an address*, and ADR-076 D1 exists '
          'to make the app ASK for one in exactly that state. Fall through to '
          'the request below (ADR-077 D1).',
    );
  });

  test('the request the fall-through exists to reach is still made', () {
    // The other half: falling through is worth nothing if the call it falls
    // through to is gone.
    //
    // ⚠️ It asserts the CALL SITE — `unawaited(_askApnsToRegister())` — and not
    // the bare name, and that is a correction rather than a flourish. Scoping
    // to "up to the next `@override`" does not end at this method: the private
    // `_askApnsToRegister` helper has no annotation, so it falls inside the
    // window and its own DECLARATION satisfies a `contains('_askApnsToRegister()')`.
    // Deleting the call and keeping the helper left this test green — measured
    // by mutation at S102, which is the only reason it is written this way.
    final methodStart = source.indexOf('Future<bool> isReadyForToken()');
    final afterMethod = source.indexOf('@override', methodStart);
    final window = source.substring(
      methodStart,
      afterMethod == -1 ? source.length : afterMethod,
    );
    expect(
      window,
      contains('unawaited(_askApnsToRegister())'),
      reason:
          'isReadyForToken() no longer asks APNs to register, which is '
          'ADR-076 D1 itself — not just this fall-through',
    );
  });

  test('the catch still EXPLAINS itself (documentation is source code)', () {
    // ⚠️ What this does and does not guard. An empty catch body satisfies the
    // invariant above perfectly — falling through is exactly what it does — so
    // this is NOT an anti-vacuity check, and saying so is the point.
    //
    // It guards the reader. The defect is INVISIBLE: an early `return false`
    // in a catch reads as ordinary defensive code, it is what the first version
    // did, and nothing at the call site looks wrong. The only thing that would
    // stop the next editor restoring it is the sentence saying why it is not
    // there. `project-rules.md` #8 makes that sentence part of the
    // implementation, so it is pinned like one.
    expect(
      catchBody,
      contains('FALLS THROUGH'),
      reason:
          'the explanation for the fall-through is gone from the catch block. '
          'It is load-bearing prose: the invariant it protects is the ABSENCE '
          'of a statement, which nothing else in the file can show.',
    );
  });
}
