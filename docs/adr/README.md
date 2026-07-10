# Architecture Decision Records

One record per architectural decision. Every architectural decision gets an ADR (`project-rules.md` #8; `agent-workflows.md` W6 — an ADR for anything with alternatives considered, written in the same commit as the change).

## Format

Each record mirrors the structure of [`006-ios-first-release-sequencing.md`](006-ios-first-release-sequencing.md):

- **Title** — `# ADR-NNN: <decision>`
- **Bullets** — Status / Date / Deciders / Related
- **Context** — the forces and the alternatives considered
- **Decision** — what was chosen, stated plainly
- **Consequences** — **Positive**, then **Negative / accepted trade-offs** (an optional **Neutral** section for reference points)

Conventions:

- **Numbering:** zero-padded `NNN`, monotonically increasing, never reused.
- **One decision per file.** Split, don't bundle.
- **Statuses:** `Accepted` · `Superseded (by-NNN)` · `Deprecated`. Records are immutable once accepted — a reversal is a new ADR that supersedes the old one; the old record's status flips to `Superseded (by-NNN)` and its body stays intact.

ADR-001–005 were backfilled at M0.2 (Session 002) from the `architecture.md` §11 decision log; the decisions themselves date to project genesis (Session 000).

## Index

| ADR | Decision | Status |
|---|---|---|
| [001](001-flutter-over-native.md) | Flutter over a native Swift/Kotlin pair — one codebase for both markets | Accepted |
| [002](002-firebase-over-supabase.md) | Firebase over Supabase — offline + FCM + Remote Config maturity outweighs Postgres ergonomics | Accepted |
| [003](003-revenuecat-for-entitlements.md) | RevenueCat for cross-store entitlements, one purchase covers both partners | Accepted |
| [004](004-eu-firestore-region.md) | EU (europe-west multi-region) Firestore region | Accepted |
| [005](005-couple-scoped-data-model.md) | Couple-scoped data model — no global social graph | Accepted |
| [006](006-ios-first-release-sequencing.md) | iOS-first release & validation sequencing — Android re-sequenced to M6.5 | Accepted |
| [007](007-de-gate-build-from-content-validation.md) | Build de-gated from content validation — gates become spend/launch instruments; personal-use-first | Accepted |
| [008](008-apple-signin-via-credential-seam.md) | Sign in with Apple via a credential seam, not `signInWithProvider` — keeps the flow fakeable and emulator-testable | Accepted |
| [009](009-solo-mode-content-and-persistence.md) | Solo mode — bundled schema-shaped packs, `createdAt`-anchored local day rotation, Firestore `soloAnswers` | Accepted |
