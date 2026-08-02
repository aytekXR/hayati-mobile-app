import 'dart:async';

import '../test/flutter_test_config.dart' as suite;

/// Font loading for the screenshot lane, DELEGATED to the suite's config.
///
/// `flutter_test_config.dart` is discovered by walking up from the test file's
/// own directory, so `test/flutter_test_config.dart` — which loads the real
/// Rubik / Noto TTFs — is invisible to anything outside `test/`. Without this
/// file the lane renders every glyph as the flutter_test placeholder box, and
/// the failure is silent in the worst way: the images are the right size, the
/// right colours and the right layout, and the run is green. The first render
/// of this lane produced exactly that.
///
/// Delegated rather than copied ON PURPOSE. A second font list would drift from
/// the suite's the first time a weight or a fallback family is added, and the
/// symptom would be store screenshots whose typography no golden has ever
/// checked — which is the one guarantee this lane exists to keep.
Future<void> testExecutable(FutureOr<void> Function() testMain) =>
    suite.testExecutable(testMain);
