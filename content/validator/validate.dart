// Question-pack validator — PLACEHOLDER (M0.1).
//
// The real validator is scheduled for milestone M3 (docs/implementation-plan.md)
// and will enforce content/schema/question-pack.schema.json plus the checks a
// JSON Schema cannot express: id uniqueness across packs, register/locale
// consistency, reviewedBy present on shippable packs, and the GCC-safety
// checklist flags for intimacy-adjacent packs (docs/agent-workflows.md W9).
//
// This is intentionally not wired into any build step yet; it exists so the
// content pipeline location and contract are fixed from day one.

import 'dart:io';

void main(List<String> args) {
  stderr.writeln(
    'question-pack validator: NOT IMPLEMENTED YET (scheduled for M3 — '
    'see docs/implementation-plan.md). Schema contract lives at '
    'content/schema/question-pack.schema.json.',
  );
  exitCode = 1;
}
