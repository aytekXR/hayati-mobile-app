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

  > **Rev note (S042) — the precedent covers only half of this path.** The `RC_WEBHOOK_TOKEN` attempt (S040) proved the **missing-secret** direction: the deploy stopped with *"Secret … not found or has no versions"*. It never reached the **present-secret** direction, because that secret still does not exist. `LLM_API_KEY` **does** exist, so `coachProxy`'s deploy takes a path this repo has never exercised: firebase-tools must grant `roles/secretmanager.secretAccessor` on the secret to the runtime service account before the revision can bind the env var. That auto-grant is documented firebase-tools behaviour, **not an in-repo finding** — stated as knowledge, not as precedent. If it fails, the adapter fails closed to `unconfigured` (a coach that honestly says "unavailable"), so the failure mode is safe but **silent from the app's side**: it must be confirmed by reading the deploy output and the function's revision, not inferred from the app.
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
- The `consentProcessors` text change moves goldens, which need regeneration on the **Linux golden platform** — they cannot be produced correctly on the macOS dev box, where all goldens fail environmentally. **This is why the PR arrived red.**

  > **Rev note — 2026-07-26 (Session 042): the sentence above originally named the WRONG widget and the WRONG golden set, and the review caught it.** It said *"alters the sign-in `ProviderActions` footer goldens"*. Both halves are false: `ProviderActions` renders `l10n.legalFooterLine` (unchanged by this diff), and `consentProcessors` is rendered in exactly **one** place — `consent_gate_screen.dart:133`. **Zero `sign_in_screen` goldens moved.** The set that actually moved, regenerated and verified on Linux in commit `ecf5561`, is **18** files: `consent_gate_screen` **9** (× 3 locales × 2 directions, plus 3 `scale130`), `legal_document_screen` **3** (the privacy policy, whose body carries the version line and the Anthropic paragraphs), and `legal_screen` **6** (the hub, which renders each document's version line). A session following the original sentence would have regenerated `sign_in_screen`, left the consent-gate golden stale, and shipped an undetected visual regression on **the one screen that discloses special-category processing to the user**. Recorded rather than quietly corrected, because this is the project's own highest-value defect class (ADR-029 addendum: *an ADR's promises about its own diff are guarantee surfaces*).
- The whole legal bundle stays **review-PENDING** (native + lawyer review — operator items 1/9); this version's wording joins that gate.
- The live coach still needs the **★ crisis-content native review** before its first real-device use (operator ★ gate), and the `LLM_API_KEY` secret set + a deploy, before it actually answers.

## Post-implementation review record (Session 042 — added by the session that adopted this ADR's PR)

This ADR shipped **without a review record**, alone among recent ADRs touching a special-category path (023, 024, 025, 026 and 029 all carry one). The review's own verdict on that: the ADR README does not *mandate* a record (the skeptic's ground for refuting it) but the adjudicator confirmed it as a real gap, and the evidence favours the adjudicator — **the absence is the proximate reason the wrong-goldens error above survived to merge day.** A record is added now, by the session that finished the work.

**Shape:** 5 lenses (frozen-port obligations, re-consent completeness, ADR-self-claims, safety-and-cost, deploy-and-ops) × 2 independent verifiers (refuting skeptic + governing-docs adjudicator), aggregated so a finding surfaces when either verifier says real. **7 findings, 7 real, ZERO refuted, 2 split verdicts** — both splits of the same shape: the skeptic correctly noting no governing doc *mandates* the thing, the adjudicator correctly holding it a real defect anyway.

Fixed pre-merge:

1. **(blocking) The wrong-goldens claim** — corrected in the rev note above.
2. **(serious) The load-bearing no-leak test was VACUOUS.** *"NEVER lets upstream text reach the mapped error message"* fed `classifyUpstream` a **plain `Error`**, which classifies as `unknown` — the one branch that provably cannot carry an SDK response body whatever the implementation does. It asserted the safe path and left the dangerous one untested. Now parameterised over every branch, each fed a real error **of the type that branch exists for**, each carrying the same sentinel.
3. **Then a mutation matrix found two more vacuities the lens had not seen, in this session's own replacement** — which is the argument for mutating rather than reading:
   - `JSON.stringify` is useless as a leak scan. `Error`'s `message`/`stack` are **non-enumerable**, so `JSON.stringify({cause: err})` is `{"cause":{}}`; a mutant attaching the upstream error as `cause` leaked the response body with the test **green**. Replaced with a recursive collector that reads `Error`'s non-enumerable fields and follows `cause` chains.
   - The provider fixture used **invented enum values** (`personaId: 'perisi'`, `register: 'siz'`) behind an `as unknown as` cast, so `buildPersonaSystemPrompt` threw *inside* the try block and **every case classified as `unknown` without the SDK ever being reached** — the leak assertions were scanning an error the adapter raised about its own arguments. Real enum members, no cast, and `expect(create).toHaveBeenCalledTimes(1)` so "the SDK was reached" is asserted rather than assumed. *A cast that silences the compiler on a test fixture silences the one check that would have caught this.*
   - Also added: a **throw-site** test (the mapping being leak-free does not prove the provider only ever throws the mapped error — the guarantee lives at the throw site) and a **request-time-key** happy path, which is what kills a module-load-read mutant.
   - **Matrix: 7/7 killed** — throw site interpolates `error.message`; mapped error carries the upstream as `cause`; key read at module load; `classifyUpstream` reads `.message` instead of branching on type; refusal treated as a normal reply; text-block check dropped; and the author's own empty-key guard (which his test already caught — a mutant that reddened against expectation, in the good direction).
4. **(serious in effect, filed minor) A SAFETY gap: the crisis post-filter truncated the reply.** Step 7 ran `detect([truncateForScan(reply.text)])`. `SCAN_CHAR_LIMIT` is 4,000 and its own comment justifies itself as *"double the 2,000-char legit maximum"* — it is calibrated for **user input**, where it bounds a hostile payload. A model reply is bounded by `COACH_MAX_TOKENS` (1024), which can exceed 4,000 characters, so **the tail of a long reply was never scanned by the crisis filter**. Fixed: the reply is scanned in full (there is no hostile-payload risk on text that came from our own token-bounded call). `truncateForScan`'s doc comment now says *user input only, do not reuse on a reply*, and an emulator regression test puts the crisis phrase past the old cap — mutation-verified: restoring the truncation reddens exactly that test.
5. **`stop_reason: 'max_tokens'` with a text block was untested**, so delivering the truncated reply was an accident rather than a decision. Pinned by a test with the reasoning: a cut-off reply is still a usable warm turn, and discarding it would fake an outage *and* burn the user's cap — and it is now scanned end-to-end by (4).
6. **(minor) The `RC_WEBHOOK_TOKEN` precedent covers only half this path** — corrected in the rev note under Decision 3.
7. **(minor) `docs/architecture.md` §4 and §8 were stale** the moment this shipped (§4 still said the adapter *"waits on operator item 6"*; §8 called the no-training claim *"a contractual requirement binding the provider when operator item 6 selects one"*). Updated — docs-with-code, project-rules #8.

**Bound this review did NOT discharge:** it verified the mechanism, not the *wording*. The whole legal bundle in three languages stays native-review-PENDING (operator items 1/9), and the **★ crisis-content review** still gates the coach's first real-device use. Neither is a code defect; both are recorded gates.
