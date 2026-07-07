// DELIBERATELY FAILING TEST — branch-protection proof for M0.2 (Session 002).
// Exists only on the test/branch-protection-proof branch to prove a red
// `quality` check blocks merge (resume-prompt.md acceptance criteria).
// This file must NEVER land on main; the proof PR is closed, not merged.
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('M0.2 proof: a deliberately failing test must block merge', () {
    expect(1 + 1, 3, reason: 'Intentional failure — proving the merge gate.');
  });
}
