# content/ — Question Packs

Versioned question packs as JSON, shipped bundled and synced remotely (see
`docs/architecture.md` §2–3, `docs/prd.md` §7).

- `schema/question-pack.schema.json` — the pack contract (stub as of M0.1; the
  enforcing validator ships in M3).
- `packs/` — one file per pack: `tr_playful`, `tr_respectful`, `ar_msa_gulf`,
  `en`. Only `en.example.json` exists for now; it is an **example of shape, not
  shippable content**.
- `validator/validate.dart` — validator script placeholder (M3).

**M2.4 interim note (ADR-009):** the first shippable packs — the three solo
packs (`solo_tr` / `solo_ar` / `solo_en`, schema-shaped, register `neutral`) —
live at `app/assets/content/` because the app bundles them directly and no
sync step exists yet. Until the M3 pipeline lands, that directory is their
single authoring location (no copy here, deliberately — no dual-source
drift); M3 moves authoring back under `content/` with validation + sync.
Their `reviewedBy` is `PENDING…`: native register-owner review (Gulf reviewer
for AR) is mandatory before public launch (W9, `docs/operator-expected.md`).

Authoring rules (binding, from `docs/prd.md` §7 and `docs/agent-workflows.md`
W9): content is culturally **authored, never machine-translated**; AI-assisted
drafting is allowed with mandatory native register-owner review (Gulf reviewer
for AR packs) recorded in `reviewedBy`; launch bank targets 400 TR / 300 AR /
300 EN.
