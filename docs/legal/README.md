# Legal documents — ikimiz

This directory holds the in-app privacy policy and terms, one document per locale, plus this control file. The six documents are the app's real legal texts: they render in-app (sign-in footer, consent gate links, paywall links row, and the Settings legal hub) and are byte-copied into `app/assets/legal/`.

They are AI-drafted and **review-PENDING**. Until the native register owners and the founder's lawyer pass them, they are honest descriptions of what the app does but are not validated legal instruments. See ADR-023 for the full rationale.

## Version

The single source of version truth for the whole legal bundle:

version: 2

This exact `version:` line is read by the three-way source-sentinel test alongside the app's `currentLegalVersion` Dart const and the Functions `CURRENT_LEGAL_VERSION` constant. All three must match, or CI fails red.

Effective date of version 2: 26 July 2026.

**A version-3 DRAFT is waiting in `proposed/`** — three revised privacy policies correcting what version 2 says about notifications and about analytics (issue #226, ADR-058). It is **not in force**, it bumps nothing, and landing it is a founder/lawyer decision because it re-prompts every existing user for consent. `proposed/README.md` carries the delta and the exact landing diff; a structural test (`app/test/features/legal/legal_proposal_test.dart`) holds the draft to this file's authoring rules and asserts it has not landed.

## Review status (PENDING)

Each document needs a native/register review and a legal review before launch. Nothing here is signed off.

| Document | Native / register reviewer | Legal reviewer | Status |
|---|---|---|---|
| `privacy-policy.tr.md` | Founders (TR-respectful register) | Founder's lawyer | PENDING |
| `terms.tr.md` | Founders (TR-respectful register) | Founder's lawyer | PENDING |
| `privacy-policy.ar.md` | Gulf reviewer (MSA, family-safe) | Founder's lawyer | PENDING |
| `terms.ar.md` | Gulf reviewer (MSA, family-safe) | Founder's lawyer | PENDING |
| `privacy-policy.en.md` | Founder (plain EN) | Founder's lawyer | PENDING |
| `terms.en.md` | Founder (plain EN) | Founder's lawyer | PENDING |

### Lawyer questions carried into the legal review

These **six** questions are the load-bearing legal ambiguities recorded and implemented conservatively. They must be settled by the founder's lawyer, and the answers can relax or confirm the drafts. **A, B and C** come from ADR-023 and are about the documents in force; **D and E** are new with the version-3 draft in `proposed/` (ADR-058) and **F** with its consent-record bullet (ADR-068) — none of the last three blocks reading it.

- Question A — special-category classification. The drafts treat free-text reflections, shared answers, and coach messages as special-category personal data, so the only realistic basis is explicit consent. Is that classification right, or are they ordinary personal data on the contract basis? Relaxing this in a future version is cheap; adding a missing consent later is expensive, which is why the conservative reading shipped first.
- Question B — consent as a condition of service. The reflective features are gated on the one consent, but the copy states plainly why it is required (the content is the service itself) and a decliner keeps sign-out, data export, and account deletion directly from the gate. Does this satisfy the freely-given / anti-bundling rules?
- Question C — what withdrawal must do to the stored corpus. The drafts implement the prospective reading: withdrawing consent pauses the reflective features but leaves already-stored reflections in place until the subject deletes them, with the deletion path offered right beside the withdraw action. Does KVKK/PDPL withdrawal of the sole special-category basis compel controller-initiated erasure, or does the prospective reading plus an adjacent self-serve erasure path suffice?
- Question D — does naming the analytics provider at its own opt-in discharge the aydınlatma obligation for that processing? The version-3 draft states that product analytics is off, that connecting it needs a separate unbundled opt-in, and that the provider will be named in that opt-in before any event leaves the device. If that satisfies the duty to inform, an analytics adapter can land without touching this notice. If a new named recipient in the notice requires its own version bump regardless, then the adapter re-prompts every user a second time. **The conservative default stands until you relax it: assume the adapter bumps.** ADR-058 Decision 1 records why the alternative — naming a provider we have not contracted with — was rejected as its own false statement.
- Question E — on the notification leg, is Apple a processor or an independent controller? The register already treats Apple as an independent controller for App Store data, but APNs is a different leg under different terms. `dpa-inventory.md` enters the role as *to be confirmed* rather than asserting it, because asserting it would be playing counsel. The answer changes what the notice must say about Apple and whether a transfer safeguard is needed for that leg specifically.
- Question F — must the **age attestation** be named separately in the collection list, or folded into the consent record? `users/{uid}.consent` stores three things: which legal version was accepted, a server timestamp of when, and `ageAttested` — a recorded assertion **about the person** rather than about a document. The version-3 draft now names all three in one bullet (ADR-068 D1). A reader scanning *"what does this app know about me"* would not expect an age confirmation under consent bookkeeping, which is the argument for naming it separately; the argument for folding it is that it is one act of consent recorded once. **This is a drafting judgement, not an engineering one**, and the bullet is written so approving it is a decision rather than a rewrite. Engineering has no preference and will implement either.

### Placeholders the founder must fill before these ship

The drafts deliberately leave three bracketed placeholders rather than invent facts:

- `[FOUNDER LEGAL ENTITY — to be completed by the founder]` (and its TR/AR equivalents) — the controller's legal identity, in every privacy policy and every terms document.
- `[CONTACT ADDRESS — to be completed by the founder]` (and its TR/AR equivalents) — the privacy contact point, in every privacy policy.
- `[GOVERNING LAW — to be determined by the founder's lawyer]` (and its TR/AR equivalents) — the governing law, in every terms document.

## Bump procedure (a material change)

A material change to any document — for example, naming the AI provider at M5.3, adding an analytics or marketing opt-in, or any change that alters purposes, recipients, the transfer mechanism, or the data-location split — requires a coordinated version bump so every returning user re-consents:

1. Edit the affected document(s) here, and update the byte-identical copies in `app/assets/legal/` in the same diff (or regenerate them). The byte-equality drift test fails red otherwise.
2. Raise all three version sources by the same step, in the same diff:
   - the `version:` line in this file,
   - the app's `currentLegalVersion` Dart const,
   - the Functions `CURRENT_LEGAL_VERSION` constant.
   The three-way source-sentinel test fails red on any partial bump — both the app-ahead brick direction and the silent under-gate direction (documents changed but no re-consent fires).
3. **Update the two places the sentinel does NOT cover** (added S042, each found the hard way when the v1→v2 bump left them behind):
   - **`shippedPolicyVersionLine`** in `app/test/features/legal/presentation/legal_document_screen_test.dart` — it pins a line of the *shipped asset* (`Version N. Effective <date>.`) to prove the bundle seam delivered the real document, so it is outside the constant-pin by design but still reddens on every bump.
   - **The goldens.** The version string and the processors notice RENDER, so a bump moves the `legal_screen`, `legal_document_screen` and `consent_gate_screen` golden sets. **Declare the expected set before regenerating** (ADR-025's goldens rule) and diff the actual changed set against your declaration — anything outside it is a defect, not churn. Goldens are **Linux-canonical**: they cannot be produced correctly on a macOS box (this is why PR #95 arrived red).
4. Deploy ordering: the Functions constant must deploy **before, or together with**, the app binary that raises the gate's expectation. This is moot today — nothing is deployed anywhere, and the first deploy ships rules, functions, and binary together — but it is binding for the deploy era, so the gate never expects a version the server has not yet stamped.
5. Record, in the pull request and in the ADR/operator trail, what changed and why re-consent is needed. A non-material fix (typo, clarification that changes no substance) does not bump the version and does not re-gate.

## Authoring rules (the in-app renderer is plain)

The six documents render through a minimal in-app renderer with no markdown library. It understands only this subset — anything else is treated as plain body text, so nothing throws, but formatting you expect will be lost:

- `#` on the first line — the document title (exactly one per document).
- `##` lines — section headings.
- `- ` lines — single-level bullet rows. No nested bullets, no numbered lists.
- blank-line-separated blocks — body paragraphs.

Do not use links, tables, bold, italics, inline code, block quotes, or images in the six documents. Keep each privacy policy around 100–160 lines and each terms document around 70–120 lines. The three locales must carry the same substantive content — not word-for-word translation, but no locale may promise anything another does not.

This README is not bundled and is not subject to the renderer subset; it may use tables and emphasis freely.
