# ADR-069: the deletion clause rides a revision that is already open

- **Status:** Accepted — revision 1 (2026-08-30, Session 093), written and committed **before** the code
- **Date:** 2026-08-30 (Session 093)
- **Deciders:** session agent (a one-clause draft edit; the landing is the founder's and the lawyer's and is not touched here)
- **Related:** **ADR-061 D5** (*"the legal draft is checked, survives, and gets a note rather than an edit"* — the decision this one revisits, and the only reason this ADR exists), **ADR-068** (S092's edit to the same draft, which is the change of circumstance), **ADR-058** (the version-3 draft), **ADR-023** (the three-way legal-version sentinel), **ADR-060 D6** (the decision this session honoured rather than overturned — see the appendix), issues **#258** (this one), **#246**, **#249**, **#226**

> **Review status.** Written before the code (`session-context.md` §5 item 1,
> lesson **115**). The design pass has not run yet.

## Context — why this needs a record at all

This is **one clause, in a draft, whose exact wording issue #258 already
proposes.** It would not deserve an ADR except for one thing: **ADR-061 Decision 5
decided not to make it**, and it decided that after a review pass.

> **ADR-061 D5.** *"So the draft is **not** re-opened… Widening a revision the
> founder is about to review is scope creep (`session-rules.md` §2); telling them
> what changed underneath it is not."*

**A session that quietly does the thing a recorded decision declined is worse
than one that does nothing**, and this session had already refused, an hour
earlier, to overturn ADR-060 D6 on #242 for exactly that reason. The same
standard has to survive being inconvenient.

### Finding 1 — the sentence is TRUE, and that is why D5 was right at the time

`docs/legal/proposed/` says the on-device milestone markers *"go when you remove
the app"*. After #246 landed (ADR-061), **"Delete account and data" also removes
every account-scoped marker** — `analytics.signup.<uid>` and its four uid-keyed
siblings, plus `coachDisclaimerAck`, `coupleEndedSeen`, `nameCaptureDone`,
`privacySpotlightSeen`. `analytics.install` and `ritualPreviewSeen` carry no uid
and stay: device state, not account state.

**Removing the app still clears them, so the sentence did not become false.** The
notice promises **less** than the app does — the safe direction, and the exact
opposite of #226's defect. D5's judgement that this is a note rather than a
correction stands on its own terms and is not overturned here.

### Finding 2 — what changed is the cost, and I am the one who changed it

D5's argument was **not** *"the clause is wrong"*. It was *"do not widen a
revision the founder is about to review."* That cost is **already paid**:
**ADR-068 widened it yesterday**, adding the consent-record bullet for #249 —
after which `operator-expected.md` item 16 was rewritten to present **#226, #249
and #258 as one decision**, so that one lawyer round settles all three.

**Two of the three are drafted and the third is not.** A bundle presented as one
decision, one third of which has no proposed wording, makes the lawyer do the
drafting for the remainder — which is the thing ADR-058 built this draft to avoid.

⚠️ **The change of circumstance is one this session's predecessor created, and
that is worth saying rather than dressing up.** *"I opened the door yesterday, so
I may as well walk through it"* is a rationalisation, and the last three sessions
were each caught making an argument that flattered what they wanted to do. So the
test applied here is the counterfactual: **if ADR-068 had not landed, would this
clause go in?** **No.** D5 would stand untouched. The justification rests entirely
on the draft already being open, and that is stated plainly so a reader can reject
it rather than having to reconstruct it.

### Finding 3 — the decisive asymmetry is that drafting does not commit anyone

**A drafted clause the founder does not want costs them one word: "no".** An
undrafted clause costs them a second lawyer round, or the inference stands
uncorrected until someone opens the question again.

Nothing here lands: `CURRENT_LEGAL_VERSION` stays **2**, `app/assets/legal/` is
untouched, no user is re-prompted. **The founder keeps every choice they had
before**, and gains one they did not — settling #258 in the round they are
already planning.

## Decision 1 — the clause goes in, in three locales, and D5 is amended rather than contradicted

The analytics paragraph's sentence gains one clause, in the wording #258
proposes:

> …they are ordinary app data on your phone: they go when you remove the app —
> **and deleting your account removes the ones tied to it** — and, like the rest
> of your app data, they are included in your device's own backups if you use
> them.

**ADR-061 D5 is amended, not overturned**, and the distinction is the whole of
this record: D5 decided *not to widen a revision under review*. The revision is
under review and **has already been widened**. D5's reasoning is intact; its
premise is not.

## Decision 2 — this ADR does NOT touch what D5 got right

* The sentence was **true** before this clause and is true after it. This is a
  **clarity** change, not a correction, and the draft's README note plus #258
  stay as the record of when it was found.
* **No new fact is disclosed.** Every marker named is already covered by the
  paragraph; the clause tells the reader that a second, already-shipped action
  clears the account-scoped ones.
* **`ritualPreviewSeen` and `analytics.install` are deliberately not mentioned.**
  They survive account deletion because they are device state; naming the
  exceptions in a user-facing notice trades a wrong inference for a confusing
  one, and the paragraph's *"they go when you remove the app"* already covers
  them accurately.

## Decision 3 — the shape guard is run, not asserted

`legal_proposal_test.dart` pins the draft's line bounds (90–160), section parity
across locales, the localised version line, the v2 anchors' absence, and — for
Arabic — **exactly one `U+200F`**. The files are at **105** lines after ADR-068;
an in-line clause adds **no** line. The test is **run and its result quoted**,
which ADR-065 D5 made an acceptance criterion after a review pointed out that
*"it continues to pass"* was a claim about code that did not exist yet.

## Consequences

* **Item 16's bundle is complete**: all three disclosure items now have proposed
  wording, so one lawyer round can settle all three or reject any of them.
* **ADR-061 D5's principle survives for the next session** — do not widen a
  revision under review — with one recorded exception whose premise is stated so
  it cannot be cited as general licence.
* **The draft has now been corrected four times without landing** (ADR-058 wrote
  it; ADR-059, ADR-065 D5, ADR-068 and this each changed it — so this is the
  fourth *correction*). ADR-068's Consequences already said it: **if the count
  keeps climbing, the thing to question is the landing, not the corrections.**
  This is the count climbing.
* **Nothing lands.** Version 2 remains in force.

## Appendix — the decision this session did NOT overturn, recorded for symmetry

S093's `resume-prompt.md` named **#242** as the objective and asserted that
emitting the three money events into the existing port was unblocked. **ADR-060
D6 had already decided otherwise**, accepting #242's own framing that *"there is
no reason to build a server emitter before there is somewhere for it to emit"* —
and its condition is still unmet, measured today: no vendor sink exists, and
**#226 and #247 are both open**.

So the emitter was **not** built, and the reason is on the issue. **The defect was
in the prompt**: it was written from #242's title and the priority list without
reading the ADR that owns the objective. **A resume prompt is a claim like any
other** (lesson **145**).

## Alternatives rejected

| | why not |
|---|---|
| **Leave it to the note, per ADR-061 D5** | D5's premise — a revision not yet widened — is false as of ADR-068. Keeping the conclusion after its premise has gone is how a decision rots into a habit. |
| **Fold in the exceptions too** (`analytics.install`, `ritualPreviewSeen`) | Trades a wrong inference for a confusing one. The paragraph already describes them accurately; Decision 2. |
| **Ask the founder whether to fold #258 in** | It is a draft. Drafting preserves every choice they have and costs them one word to decline, while the question costs a round-trip and leaves the bundle incomplete meanwhile. Finding 3. |
| **Edit the shipped notice** | Bumps `CURRENT_LEGAL_VERSION` and re-gates every user (ADR-023). Never a session's call, and this is a *clarity* change — the weakest possible reason to re-prompt thousands of people. |
| **Build #242 instead, as the prompt said** | ADR-060 D6, whose condition is unmet. See the appendix. |
