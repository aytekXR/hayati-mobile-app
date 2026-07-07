# content/ — Question Packs

Versioned question packs as JSON, shipped bundled and synced remotely (see
`docs/architecture.md` §2–3, `docs/prd.md` §7).

- `schema/question-pack.schema.json` — the pack contract (stub as of M0.1; the
  enforcing validator ships in M3).
- `packs/` — one file per pack: `tr_playful`, `tr_respectful`, `ar_msa_gulf`,
  `en`. Only `en.example.json` exists for now; it is an **example of shape, not
  shippable content**.
- `validator/validate.dart` — validator script placeholder (M3).

Authoring rules (binding, from `docs/prd.md` §7 and `docs/agent-workflows.md`
W9): content is culturally **authored, never machine-translated**; AI-assisted
drafting is allowed with mandatory native register-owner review (Gulf reviewer
for AR packs) recorded in `reviewedBy`; launch bank targets 400 TR / 300 AR /
300 EN.
