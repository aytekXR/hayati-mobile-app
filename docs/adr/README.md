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
| [010](010-content-authoring-home-and-sync.md) | `content/packs/` as the single pack authoring home; validator-owned one-way byte-sync into the app bundle | Accepted |
| [011](011-rollover-pack-source-and-scheduling.md) | Rollover reads build-time-bundled packs; single hourly UTC sweep with timezone buckets; `packConfig {packId}` with `solo_tr` placeholder; evergreen-only selection | Accepted |
| [012](012-reveal-trigger-streak-and-push-policy.md) | Reveal trigger `onDocumentCreated` + transactional `revealedAt` latch; streak with weekly ISO grace refill; push payload policy (quiet hours suppress, discreet default AR-ON, no content in payloads) | Accepted |
| [013](013-revenuecat-webhook-entitlement-mirror.md) | RevenueCat webhook → couple entitlement mirror: verbatim-token auth behind the first env/secret seam (fail-closed), revoke-only-on-EXPIRATION projection, uid→coupleId resolution with the existing-user hard stop, per-subscriber lanes with a `(event_timestamp_ms, id)` LWW total-order guard | Accepted |
| [014](014-paywall-purchases-seam-and-premium-gating.md) | Paywall + purchases seam + premium gating: `PurchasesRepository` speaks the SDK's model types (the fake mints real objects), auth-wired `logIn` with an anonymous-purchase guard, fail-closed unconfigured posture, mirror-is-the-only-unlocker paywall states, one `PremiumGate` widget on `isPremium` with pack selection as the first gated surface | Accepted |
| [015](015-transfer-events-and-the-gift-decision.md) | `TRANSFER` events (a real one is a **400** today — the envelope contract becomes per-type): a transfer never entitles a gainer (the event carries no product/expiry), revoke the loser's lane only on positive evidence the entitlement left the couple, every ambiguity holds; and "gift your partner" is not a store feature — the couple-scoped mirror IS the gift, so no gift UI ships (Family Sharing stays OFF — irreversible) | Accepted |
| [016](016-coach-safety-spine-provider-seam-caps.md) | AI coach v0 safety spine: normalization-based crisis detector (pure, one red lever per fold step), `coachProxy` pipeline with crisis-pre-scan-before-any-rejection, provider-agnostic fail-closed port (fixtures only), transactional caps with a self-read-only daily lane (DV posture), no-text/no-uid log types; the M5.2 wire contract frozen | Accepted |
| [017](017-coach-chat-ui-window-persistence-personas.md) | Coach chat UI: one premium surface with a persona switcher (free tier renders NOTHING — spacer included, free goldens byte-identical), a client-side **help-sticky latch** on the server's `kind:'help'` signal (window retention alone cannot carry the guarantee — the pre-code review's blocking find), ephemeral in-memory threads torn down on sign-out (the private-thread decision — founder owns retention), disclaimer single-homed in ARB behind a new local-flag seam, code-first content-free app taxonomy for the frozen wire, server-side register-aware persona scaffolds with safety lines on the ★ gate | Accepted |
