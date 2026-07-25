# ADR-028: The live coach adapter (M5.3) — Anthropic Claude (Sonnet 5) behind the frozen port, and the re-consent it triggers

- **Status:** Accepted
- **Date:** 2026-07-26 (Session 037)
- **Deciders:** session agent + founder (the founder chose Anthropic direct over aggregators/routers, and Sonnet 5 over Haiku/Opus on the cost/quality balance)
- **Related:** ADR-016 (coach safety spine + the provider-agnostic port), ADR-017 (persona system prompts), ADR-023 (consent surface + the *recorded* M5.3 re-consent trigger), operator-expected item 6, `docs/dpa-inventory.md` (the Anthropic row)

## Context

M5.1/M5.2 built the coach safety spine and chat UI behind a **frozen, provider-agnostic port** (ADR-016 Decision 5): the only two providers were `UnconfiguredCoachProvider` (fail-closed) and `FixtureCoachProvider` (tests). No vendor was named in code, deliberately — the port shape is ours, smaller than any vendor API, so any provider can adapt to it, and the choice is reversible. M5.3 is the live adapter, and it was the last MVP code unit, blocked only on the founder's provider decision (operator item 6). ADR-023 pre-recorded that M5.3 is a **re-consent trigger**, so this session inherited that as binding, not as a discovery.

## Decision 1 — Provider: **Anthropic (Claude API), direct** — not an aggregator/router

The founder chose Anthropic directly over OpenRouter-style routers. For a coach that handles **special-category** relationship content (ADR-023), a router is a *second* processor in the data path — more DPA/cross-border surface, a downstream provider that can vary per request, harder KVKK/PDPL analysis, and a silent-failover risk to a different model with different safety behavior. Direct = one processor, one clear DPA/SCC leg, model pinning for the safety spine, and lower latency. Routers remain useful for *evaluating* models; for the shipped, compliance-sensitive coach, direct wins. *(Transparency: the session recommending Anthropic is itself Claude; the decision is the founder's, the project's own operator doc had already priced Anthropic, and the seam is provider-agnostic — a later switch is one adapter.)*

## Decision 2 — Model: **Sonnet 5** (`claude-sonnet-5`), thinking **disabled**

The founder chose Sonnet 5 (the operator doc's reference tier, ≈$0.014/msg) over Haiku 4.5 (cheaper) and Opus 4.8 (higher quality) — balancing Gulf-Arabic + Turkish quality (the stated differentiator) against the shipped caps (30/day per person, 1,000/month per couple) that bound worst-case spend. **Thinking is disabled:** a coach reply is a brief, warm conversational turn, not a hard reasoning task; the safety lives in the crisis detector, not the model. Disabling keeps latency low (chat UX) and cost predictable (thinking tokens bill as output). Both are one-line changes (`COACH_MODEL`, the `thinking` param) — the seam stays agnostic.

## Decision 3 — The adapter honors the port's two obligations by construction (ADR-016 D5)

`AnthropicCoachProvider` (official `@anthropic-ai/sdk`) reads `LLM_API_KEY` at request time (absent → fail-closed `unconfigured`, so the callable deploys safely before the secret exists), builds the persona system prompt from the closed enums (ADR-017 — no user content reaches prompt construction), calls the Messages API, and returns the reply text.

- **Never copies upstream text into an error.** `classifyUpstream` branches on the error *type* only; the thrown `ProviderUnavailableError`'s message is a static literal keyed by the classification enum. A `refusal` stop reason or an empty completion is treated as an **outage** (`upstream-error`), not a crisis — the crisis pre-scan already ran before the reserve — so the handler refunds the reserved cap and returns `unavailable`. The crisis **post-filter** (handler step 7) runs all three lexicons over the reply; the adapter does no filtering.
- **Secret binding:** `coachProxy` declares `secrets: ['LLM_API_KEY']` (the `RC_WEBHOOK_TOKEN` precedent). The deploy **fails closed and loud** until the secret exists — never a silent green.
- The risky pure logic (classification, refusal/empty handling) is factored into exported helpers and unit-tested, including the load-bearing invariant: *no upstream string can reach a log through the mapped error*.

## Decision 4 — The re-consent (ADR-023's recorded M5.3 trigger), done at zero user cost

Naming Anthropic introduces a **new special-category recipient** and a **new cross-border leg** — a material change under KVKK (ADR-023 Decision 1). Per ADR-023 Decision 4 and the S023 handoff, this session, in one diff:

- bumps `CURRENT_LEGAL_VERSION` **1 → 2** across all three sentinel sources (app `currentLegalVersion`, functions `CURRENT_LEGAL_VERSION`, `docs/legal/README.md` `version:`) — the three-way source-sentinel fails CI red on any partial bump;
- names Anthropic in the six legal docs' privacy policies (EN/TR/AR) and in the in-app `consentProcessors` notice, re-stamping the **frozen-sentence digest** deliberately (a `consent*` change is a legal-version event, exactly what the digest exists to force);
- syncs the six documents byte-for-byte into `app/assets/legal/` (the drift test);
- re-gates every returning user (their stored `consent.version` of 1 now fails `hasCurrentConsent`).

**Timing:** no user exists yet — nothing is deployed to users and there is no TestFlight build — so the re-gate costs nothing. Introducing the provider now, before launch, is the ideal moment: the re-consent trigger is free.

The wording is deliberately honest about its bounds: it claims **we** store nothing and Anthropic **does not train** on the data (both true under Anthropic's commercial API terms) but does **not** claim "Anthropic retains nothing" — its default API retention is limited-but-nonzero unless zero-data-retention is enabled. The founder can strengthen that line by enabling ZDR on the Anthropic org.

## Consequences

**Positive:**

- The coach's one remaining code piece (M5.3) is built — the whole MVP feature set is now code-complete.
- The provider seam held under its own test: a live adapter dropped in behind the frozen port without touching the safety spine, the caps, the crisis detector, or the wire contract.
- Re-consent executed at **zero user cost** (pre-launch), exactly as ADR-023 anticipated.

**Negative / accepted trade-offs:**

- Anthropic is a **US-based processor** — a new non-EU cross-border leg. The founder must accept Anthropic's DPA, sign a KVKK standard-contract leg + **file it with the Kurum within 5 business days**, and add a PDPL TRA leg before the first KSA user (recorded in `dpa-inventory.md`, not discharged here).
- The `consentProcessors` text change alters the sign-in `ProviderActions` footer goldens; these need regeneration on the **CI/Linux golden platform** (a W4 golden-update item — they cannot be produced correctly on the macOS dev box, where all goldens fail environmentally).
- The whole legal bundle stays **review-PENDING** (native + lawyer review — operator items 1/9); this version's wording joins that gate.
- The live coach still needs the **★ crisis-content native review** before its first real-device use (operator ★ gate), and the `LLM_API_KEY` secret set + a deploy, before it actually answers.
