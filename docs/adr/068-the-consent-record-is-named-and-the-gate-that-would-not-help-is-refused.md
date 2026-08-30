# ADR-068: the consent record is named, and the gate that would not have helped is refused

- **Status:** Accepted — revision 1 (2026-08-30, Session 092), written and committed **before** the code
- **Date:** 2026-08-30 (Session 092)
- **Deciders:** session agent (a draft-text correction plus a recorded refusal to build a guard; the landing is the founder's and the lawyer's and is not touched here)
- **Related:** **ADR-023** (consent is server-owned; the three-way legal-version source sentinel; `docs/legal/` byte-synced to `app/assets/legal/`), **ADR-058** (the version-3 draft, and *"the notice denies a collection the shipped build already attempts"* — the same defect one field over), **ADR-065 D5** (the last correction to this draft, one session's push feature ago), **ADR-067** (the gate built one session ago, whose D2 line between *presence* and *meaning* is the one this ADR applies and then declines), **ADR-034** (why an advisory does not vote), **ADR-054** (the export lane that already shows this record), issues **#249** (this one), **#226**, **#247**, **#258**

> **Review status.** Written before the code (`session-context.md` §5 item 1,
> lesson **115**). The design pass has not run yet.

## Context — measured 2026-08-30

### The record exists, is server-owned, and is already shown to the subject

`users/{uid}.consent` is written by `consent-service.ts:36-38` as exactly three
fields — and the client sends none of them:

```ts
version: CURRENT_LEGAL_VERSION,
acceptedAt: FieldValue.serverTimestamp(),
ageAttested: true,
```

`firestore.rules:78-129` freezes it in both directions (a create may not carry
`consent`; an update may not change it), which is ADR-023's server-ownership in
force. And `data-rights-core.ts:366` projects it into the export, so **a subject
who asks already receives it**.

### Finding 1 — the notice's own collection list does not name it, measured

The v3 draft's *"What we collect, and where it is kept"* section carries **13
bullets** across two groups: reflections and answers, profile, couple details,
coach usage counters, subscription mirror, invite records, notification setup;
then sign-in identifiers, crash diagnostics, App Check, and push delivery.

```
$ grep -ic 'ageAttested\|of age\|age you'  docs/legal/proposed/privacy-policy.en.md   → 0
$ grep -ic 'which version'                 docs/legal/proposed/privacy-policy.en.md   → 0
```

Neither the shipped v2 nor the v3 draft names any of the three fields. **So the
asymmetry is exact: we show it if asked, and do not say we hold it.** That is
ADR-058's sentence, one field over — and this draft has already been corrected
twice for the same class (ADR-058 for push, ADR-065 D5 for the partner's name).

### Finding 2 — `ageAttested` is the one that is different in kind

`version` and `acceptedAt` are facts about a *document* and a *moment*. The third
is a recorded assertion **about the person**: that they attested to being of age.
A reader scanning a collection list for *"what does this app know about me"*
would not expect to find it under a heading about consent bookkeeping, and it is
the one a data-subject request would be most surprised to surface.

Whether it needs naming *separately* — rather than folded into one consent
sentence — is a lawyer question, not an engineering one, and Decision 2 says so
rather than deciding it silently.

### Finding 3 — four issues, one shape, and every one of them blocked on the same person

| | |
|---|---|
| **#226** | the notice denies push and never names `fcmTokens` / `pushDiagnostic` |
| **#247** | the analytics adapter's *"legal change first"* gate — *"Blocked on: #226 (founder + lawyer)"* |
| **#249** | this one — *"the founder/lawyer decide whether it rides #226's bump"* |
| **#258** | deletion under-described once #246 landed — *"Blocked on: founder + lawyer (#226)"* |

Read verbatim from each issue body. **All four were DETECTED** — by review passes
and completeness critics, not by a gate — **filed, and are waiting on a decision
only the founder and the lawyer can make.** That fact decides Decision 3.

## Decision 1 — the bullet lands in the v3 DRAFT, in three locales, and not in the shipped notice

The draft at `docs/legal/proposed/` gains one bullet in the collection list:

> - a record of your consent to this notice: which version you accepted, when you
>   accepted it, and that you confirmed you are old enough to use ikimiz. We keep
>   this because the law we operate under requires us to be able to show it.

The Turkish and Arabic say the same thing. The Arabic needs no extra clause here
— unlike ADR-065 D5's notification bullet, nothing about this record differs by
content language.

**Not the shipped notice**, and the reason is unchanged from ADR-058 and ADR-065
D5: `app/assets/legal/` is version 2, and editing it bumps
`CURRENT_LEGAL_VERSION`, which re-gates consent for **every existing user**
through ADR-023's three-way source sentinel. That is a founder and lawyer
decision. A session may make the un-landed draft honest; it may not re-ask
thousands of people for consent as a side effect of a documentation fix.

## Decision 2 — `ageAttested` is named plainly, and the question about it is asked out loud

The bullet names the age attestation rather than folding it into *"a record of
your consent"*, because Finding 2 says it is a different kind of fact. But
**whether the lawyer wants it named separately, folded, or worded differently is
theirs**, so it goes to them as an explicit question rather than as a fait
accompli — added to `docs/legal/README.md`'s question list, which is the surface
that already carries the other five.

This is the ADR-058 posture: the deliverable is a draft precise enough that
approving it is a decision rather than a rewrite.

## Decision 3 — NO GATE, and the reason is measured rather than a matter of taste

`resume-prompt.md`'s acceptance for this session asks for a guard on any list a
document gains, *"or an explicit refusal"*, citing ADR-067 — which is one session
old and exists because an unguarded index fell eighteen behind.

**The refusal is explicit, and here is why the analogy fails.**

ADR-067's index gate was worth building because the gap was **undetected**: the
index drifted eighteen records with nobody noticing, and a set comparison found
it instantly. **Here, detection is not the failing step.** Finding 3 measures
four gaps of exactly this class; **all four were already found, all four are
filed, and all four are blocked on the founder and the lawyer.** A gate would
have re-reported them and changed nothing about when they land.

Worse, it would redden the build on a **known, blocked** condition — which is
precisely the asymmetry **ADR-034** used to decide that advisories do not vote:
a build that fails for a reason the person reading the failure cannot act on
teaches them to ignore the failure. Every session for the past N weeks would have
opened on a red `quality` job whose message was *"the notice does not name
`fcmTokens`"*, which the founder already knows and cannot fix from a terminal.

**And the honest version of the check is not a set comparison anyway.** The
export carries **72 fields across 15 interfaces** (counted with a regex over
`data-rights-core.ts`, not by eye). Mapping a stored field to *"does this need a
sentence in a privacy notice"* is a legal judgement per field — the very thing
ADR-067 D2 drew a line against automating when it refused to lint the index's
summary text. A registry would move the judgement, not remove it, and it would
need fifty decisions I am not qualified to make.

**What replaces the gate, because "no gate" must not mean "nothing":** operator
item 16 is made to carry **all four** issues as one decision rather than #226
alone, so the lawyer round that is already coming clears the whole class. #249's
own filing makes this argument — *"nearly free while the lawyer already has the
document open; expensive as its own round"* — and it is right.

## Decision 4 — the draft's existing shape guard must still pass, and it is run

`legal_proposal_test.dart` guards the draft's SHAPE: a 90–160 line floor and
ceiling, the localised version line, section parity across locales, the v2 anchor
sentences absent, and — for Arabic — **exactly one `U+200F`**, which sits in the
processor list and which nothing else in the repo would notice being dropped.

The files are at **104 lines** each; one bullet takes them to 105, inside the
bounds. Section parity is unaffected (a bullet is not a section). The Arabic
bullet must not introduce a second RLM. **The test is run against the edited
draft and its result quoted** — ADR-065 D5 made that an acceptance criterion
rather than an aside after a review pointed out that *"it continues to pass"* was
a claim about code that did not exist yet, and the same applies here.

## Consequences

* **The draft becomes honest about the last field it was silent on**, and the
  document the lawyer eventually reads describes the system that exists.
* **The founder is asked once instead of four times.** That is the whole value of
  Decision 3's replacement, and it is worth more than a gate would have been.
* **Nothing lands.** `CURRENT_LEGAL_VERSION` stays 2, no user is re-prompted, and
  the drift test that pins the shipped bytes stays green. A session made a draft
  more accurate; that is all that happened.
* **A future field can still go undisclosed**, and this ADR does not pretend
  otherwise. What it claims is that the *detection* of such a field has never
  been the bottleneck — four times over — and that adding a red build for a
  blocked condition would cost more than it caught.
* **This is the fourth correction to the same draft** (ADR-058 wrote it, ADR-059
  corrected its notification sentence, ADR-065 D5 corrected it again in the
  opposite direction, and this adds the consent record). Each was correct when
  written. If that count reaches a fifth without the draft landing, the thing to
  question is the landing, not the corrections.

## Alternatives rejected

| | why not |
|---|---|
| **Build the disclosure-registry gate** | Decision 3. Detection is not the failing step — four gaps of this exact class are already detected and blocked on the same two people — and the check is a per-field legal judgement, not a set comparison. It would move the judgement, not remove it. |
| **Edit the shipped notice instead of the draft** | Bumps `CURRENT_LEGAL_VERSION` and re-gates consent for every existing user (ADR-023). A session does not re-ask thousands of people for consent to fix a documentation gap. |
| **Fold `ageAttested` into a single "we record your consent" sentence** | It is a recorded assertion about the *person*, not about the document (Finding 2). Folding it is a defensible lawyer choice and an indefensible engineer choice — so it is asked, not assumed. |
| **File it as a lawyer question and change no text** | The draft's whole purpose (ADR-058) is to be precise enough that approving it is a decision rather than a rewrite. A question with no proposed wording makes the lawyer do the drafting. |
| **Wait for #226 to land and add it then** | #226 has been open since S082 and is blocked on the same decision this bullet would ride. Waiting guarantees the bullet is written by whoever is holding the least context. |
