# content/ — Question Packs

Versioned question packs as JSON, authored here, validated + synced into the
app bundle by the M3.1 pipeline (see `docs/architecture.md` §2–3,
`docs/prd.md` §7, ADR-010).

- `schema/question-pack.schema.json` — the pack contract (JSON Schema). The
  validator enforces it and cross-checks its own vocabulary against this file
  on every run, so the schema and the enforcement cannot drift apart.
- `packs/` — **the single authoring home** (ADR-010): one file per pack,
  named `<packId>.json`. Currently the three solo packs
  (`solo_tr` / `solo_ar` / `solo_en`); the couple-pack bank
  (`tr_playful`, `tr_respectful`, `ar_msa_gulf`, `en`) arrives with W9
  content-ops authoring.
- `validator/validate.dart` — the enforcing validator (M3.1). From the repo
  root:

  ```sh
  dart content/validator/validate.dart          # check both trees (CI runs this)
  dart content/validator/validate.dart --sync   # regenerate app/assets/content/
  dart content/validator/validate_test.dart     # self-tests (CI runs this first)
  ```

  Check mode enforces the schema (fields, patterns, enums, depth bounds) plus
  what JSON Schema can't express — question-id uniqueness ACROSS packs,
  `packId`↔filename↔`locale` consistency, register vocabulary — on BOTH
  `content/packs/` and the bundled `app/assets/content/` copies, and fails on
  any byte drift between them. Missing/`PENDING` `reviewedBy` is a **warning**
  pre-launch (ADR-007; `--strict-review` promotes it to an error for launch
  posture). Runs in the ubuntu `quality` CI job on every push/PR — a red pack
  blocks merge.

**Authoring flow:** edit or add packs under `packs/`, run `--sync`, commit
both trees. `app/assets/content/` is generated output — never edit it
directly (CI fails on drift either way). A content edit intentionally shows
up as a golden change in CI when it touches what the solo home renders.

Authoring rules (binding, from `docs/prd.md` §7 and `docs/agent-workflows.md`
W9): content is culturally **authored, never machine-translated**; AI-assisted
drafting is allowed with mandatory native register-owner review (Gulf reviewer
for AR packs) recorded in `reviewedBy` — the solo packs still carry
`PENDING…` (operator item, `docs/operator-expected.md`). Launch bank targets
400 TR / 300 AR / 300 EN.
