import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'solo_clock.g.dart';

/// The app's single wall-clock seam (M2.4). Unlike the repository seams this
/// has a safe pure default — the real clock — so the entrypoints don't
/// override it; tests do, to pin day-N and `soloDayKey` deterministically
/// (the "day 3 on day 3" acceptance proof must not depend on the test host's
/// clock). keepAlive: a clock has no per-screen lifetime.
@Riverpod(keepAlive: true)
DateTime Function() soloClock(Ref ref) => DateTime.now;
