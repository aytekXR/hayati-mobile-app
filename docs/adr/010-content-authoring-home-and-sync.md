# ADR-010: Question-pack authoring home and deterministic bundle sync

- **Status:** Accepted
- **Date:** 2026-07-10
- **Deciders:** Session 011 (per `docs/resume-prompt.md` M3.1 "decide + document" mandate)
- **Related:** [ADR-009](009-solo-mode-content-and-persistence.md) (interim single-authoring-location under `app/assets/content/`, with the explicit promise that M3 moves authoring back under `content/`); [ADR-007](007-de-gate-build-from-content-validation.md) (reviewedBy stays a warning pre-launch); `docs/architecture.md` §2–3; `docs/test-suite.md` §1–2; `docs/agent-workflows.md` W9

## Context

M2.4 shipped the first real packs directly under `app/assets/content/` because no
validation/sync pipeline existed and a second copy would have been unguarded
drift (ADR-009). M3.1 builds that pipeline, so the deferred decisions came due:

1. **Where packs are authored.** Candidates: (a) keep `app/assets/content/` as
   the only location — no sync step, but repo-root `content/` (the documented
   content home since M0, and the place content-ops (W9) works without touching
   app code) stays a stub, and Functions-side consumers (M3.2 rollover) would
   read content out of the app tree; (b) author under `content/packs/` and
   deterministically sync into `app/assets/content/`.
2. **What performs the sync.** Candidates: (a) a separate sync script;
   (b) a `--sync` mode on the validator itself; (c) build-time asset
   generation (pubspec cannot reference files outside `app/`, so this means
   codegen — heavy for a byte-copy).
3. **What happens to `content/packs/en.example.json`.** Candidates: keep as a
   marked non-shippable example, or delete in favor of the real packs.

## Decision

1. **`content/packs/` is the single authoring home.** Every pack edit happens
   there; `app/assets/content/` is generated output the app bundles (one file
   per pack, `<packId>.json`). The sync direction is one-way, always
   `content/packs/ → app/assets/content/`, never the reverse.
2. **The validator owns the sync** (`dart content/validator/validate.dart
   --sync`): after the authoring tree validates clean, it byte-copies every
   pack into `app/assets/content/` and deletes orphans there. Default (check)
   mode **never writes** — it validates both trees and fails on any byte
   difference or orphan, and that check-only invocation is what CI runs
   (ubuntu `quality` job), so authoring↔bundle drift turns the pipeline red
   instead of shipping stale content. One tool holds the whole contract:
   schema enforcement, cross-pack invariants, and copy integrity cannot drift
   apart because they are the same run.
3. **`en.example.json` is deleted.** The schema file is the contract, the
   three real solo packs are the living shape reference, and the validator
   self-tests carry synthetic fixtures for every violation class. A committed
   "example" pack would either rot unvalidated or need permanent special-casing
   in the cross-pack checks ("valid but not shippable") for zero benefit.

## Consequences

**Positive**

- Content-ops (W9) authors in `content/packs/` without touching the app tree,
  and the M3.2 rollover Function can read pack content from repo-root
  `content/` — the layout `architecture.md` §2 promised since M0.
- Drift is structurally impossible to merge: CI compares bytes on every
  push/PR, and the fix is always the same mechanical `--sync`.
- The byte-copy keeps bundled assets bit-identical to what was validated —
  no formatting/normalization step that could itself introduce differences.

**Negative / accepted**

- Two committed copies of every pack (~1.5 KB each today). Accepted: the copy
  is machine-verified on every push, and Flutter can only bundle files under
  `app/`, so *some* copy must exist there.
- Pack edits are a two-step (edit + `--sync`) — the drift error message names
  the exact command, and forgetting it cannot survive CI.

## Follow-ups

- M3.2+ remote pack sync (Remote Config / Firestore) layers on top of the
  same validated `content/packs/` source; the bundled copies remain the
  offline fallback.
- `--strict-review` (reviewedBy → error) becomes part of the launch checklist
  when ADR-007's Gate 3 posture flips to public launch.
