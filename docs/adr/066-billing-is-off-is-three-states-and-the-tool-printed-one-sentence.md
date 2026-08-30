# ADR-066: "billing is off" is three states, and the tool printed one sentence

- **Status:** Accepted — **revision 2** (2026-08-30, Session 090), after the design pass; still **before** the code
- **Date:** 2026-08-30 (Session 090)
- **Deciders:** session agent (a reporting change to a local/CI instrument; no credential, no deploy, no schema)
- **Related:** **ADR-063** (the rebuild that made `prod_pulse` able to report *during* an outage — **D4 is the decision this completes**), **ADR-064 D2b** (the watcher lane and `EXTRA_FINDINGS`, which is where this sentence would go to Slack), **ADR-041** (the 0/1/2 exit taxonomy, **untouched here**), issues **#267** (this one), **#219** and **#263** (the two outages whose cost this class of defect carries)

> **Review status.** Revision 1 was written and committed **before** the code
> (`session-context.md` §5 item 1, lesson **115**). **The design pass has now
> run** — 4 lenses × 2 independent verifiers + a completeness critic, **13
> agents, 0 errored, 0 empty results, 0 skipped**; 4 lens findings + 1 critic
> finding, **all 4 surfaced (both verifiers real on every one), 0 refuted, 0
> dropped unverified**. Revision 2 is what it produced.
>
> ⚠️ **It found a BLOCKING self-contradiction: revision 1 was unimplementable as
> written.** D1 required `billing_findings` to receive the account name, and D2
> forbade touching `verdict()` — but `verdict()` is `billing_findings`'s only
> production caller, so the parameter cannot reach it without passing through.
> Re-measured myself before accepting it (lesson **123**): `grep -n
> billing_findings tool/ci/prod_pulse.py` returns the definition at 179, **one
> call at 242 — inside `verdict()`** — and a comment at 585. `main()` never calls
> it. Revision 1's Consequences said the opposite in as many words.

## Context — measured 2026-08-30, and the state has moved since S088

`prod_pulse.py` is the instrument that answers *"is the daily loop actually
running?"*, and its output is the instruction the founder acts on
(`operator-expected.md` item 1). Today it prints this, verbatim:

```
hayatiapp-prod (europe-west1)
  billing account: billingAccounts/012195-7EF76F-3A9083
  FINDING: BILLING IS OFF for this project — no billing account is linked. …
```

**Those two lines contradict each other, and the finding is the wrong one.** Read
directly through the tool's own helpers, both projects:

```
hayatiapp-prod  billingEnabled=False  billingAccountName=billingAccounts/012195-7EF76F-3A9083  account open=False
hayatiapp-dev   billingEnabled=False  billingAccountName=billingAccounts/012195-7EF76F-3A9083  account open=False
```

The account **is** linked. It is **closed**, and `billingEnabled` has now flipped
to `false` as well.

### Finding 1 — this is a state that did not exist when the code was written

ADR-063 D4's whole subject was the *disagreement*: `billingEnabled` read **`true`**
for the entire 2026-08-22 outage while the account behind it was `"open": false`.
That is why the tool learned to read the account rather than the link.

Between 2026-08-28 (S088 measured `true`) and 2026-08-30 it became **`false`**.
Google has now switched billing off at the **project**, not only at the card. So
the pair `(billing_enabled=False, account_open=False)` is new, and it is exactly
the pair the reporting has no sentence for.

### Finding 2 — the fact is measured, in hand, and thrown away by the reporting

`main()` probes the account whenever one is *named*, regardless of
`billingEnabled` (`prod_pulse.py:578-589`) — the gate is `account_name is None`,
not the enabled flag. So `account_open=False` was measured successfully in the
same run that printed *"no billing account is linked"*.

`billing_findings()` (`prod_pulse.py:179-206`) then does this:

```python
if not billing_enabled:
    return ["BILLING IS OFF for this project — no billing account is linked. …"]
if account_open is False:
    return ["the linked billing account is CLOSED. …"]
return []
```

The first branch **returns before `account_open` is ever consulted**. This is
ADR-063's own defect one layer up: D2 stopped the *measurement* from discarding
facts it already held, and the *reporting* still does.

### Finding 3 — the sentence is load-bearing, in two places

1. **The founder.** `operator-expected.md` item 1 tells them to *"reopen the
   account with a working payment method, or link both projects to an open one"*
   and names this command as how they will know it worked. A reader told **no
   account is linked** goes looking for a link that is already there.
2. **Slack.** `--notifier-findings` puts findings into `EXTRA_FINDINGS`
   (ADR-064 D2b), so whatever this says is what the watcher posts once operator
   item 4's secret exists. The armed path has never run; its first output should
   not be a sentence that denies a fact in the line above it.

### Finding 4 — `billing_findings` cannot tell the states apart, by signature

It takes `billing_enabled` and `account_open` and **not the account name**, so
"unlinked" and "linked but disabled" are the same input to it: `account_open` is
`None` in the unlinked case *and* in the could-not-read case. The function is
being asked to distinguish three states through two booleans and a tri-state,
with the discriminator absent. That is why the defect is a missing branch rather
than a wrong string.

## Decision 1 — `billing_findings` receives the account name, and answers four states

The signature gains `account_name: str | None`, which is the discriminator
`main()` already holds — **and the design review found that "already holds" is
not the same as "can hand over"**. The chain is:

```
main()  ──account_name──>  verdict()  ──account_name──>  billing_findings()
  (has it, line 579)        (does NOT have it today)      (needs it)
```

`billing_findings` has exactly **one** production caller and it is `verdict()`
(`prod_pulse.py:242`), not `main()`. So **`verdict()` grows a pass-through
`account_name` parameter too**, and `main()` passes the value it already holds.
Revision 1 specified the destination and not the route, and asserted a caller
that does not exist; a builder following it would have hit D2's prohibition on
their first edit.

The states, in the order the function tests them:

| `billing_enabled` | `account_name` | `account_open` | what it says |
|---|---|---|---|
| `False` | `None` | — | **not linked**: *"no billing account is linked"* — the sentence that is correct only here |
| `False` | named | `False` | **linked to a CLOSED account** — today's state. Names the account and says *reopen it or link an open one* |
| `False` | named | `None` (gap) | **billing off, and the account's own state could not be read** — the gap is named, never assumed |
| `False` | named | `True` | **billing off at the PROJECT although the account it names is open** — enable billing on this project, or wait: this is what a reopened account looks like before it has propagated |
| `True` | named | `False` | unchanged: *"the linked billing account is CLOSED"* (ADR-063 D4's case) |
| `True` | any | `True` / `None` | unchanged: healthy, or a gap for the caller to name |

**Every `billing_enabled=False` row is a finding**, including the fourth — the
project cannot serve, whatever the account says. What changes is only *which
sentence*, and every sentence now matches a state the reader can act on.

**The fourth row's wording was wrong in revision 1 and the adversarial lens was
right about it.** It said *"the project link itself has been removed or disabled;
re-link it"* — but the row's own precondition is that an account **is named**,
and the name is only known *because the link exists*. Telling the founder to
re-link something already linked sends them to the console to look for a missing
link that is there. The row is about billing being off **at the project** while
the account behind it is fine, so the action is *enable billing on the project*,
or *wait for propagation*.

⚠️ **Its reachability is NOT measured, and that is stated rather than implied.**
Revision 1 called it *"what a successful recovery looks like halfway through"* as
if that had been observed. It has not: reaching this state means reopening a
closed billing account, which is operator item 1 ① and no session's to perform,
and the only production account available is the one currently closed. So row 4
is a **defensive** branch — argued from the two fields being independent, not
from a captured API response. If it turns out to be unreachable, the cost is one
test case for a state that cannot occur; if it is reachable and absent, the cost
is the founder being told to re-link a linked project at the exact moment they
are half-way to fixing it. That asymmetry is why it stays.

## Decision 2 — the exit-code taxonomy is untouched, and so is the gap rule

ADR-041's `0 / 1 drift / 2 could not measure` is binding, and the local operator
command depends on it. **Every branch above is still exit 1**, because every one
of them is a finding; nothing here moves a code, adds a code, or changes when a
gap wins.

⚠️ **Revision 1 expressed that as "if `verdict()` changes, this ADR has been
misread", and that sentence is deleted rather than softened** — it was false and
it made D1 unimplementable. `verdict()` **does** change: it gains one
pass-through parameter (D1). What must not change is what it *decides*. The
invariant, stated so it can be checked instead of trusted:

* **no branch in `verdict()` returns a different exit code than it does today**
  for any input that was expressible before this change;
* **the gap logic is untouched** — `"billing" in gaps` still short-circuits, and
  a gap still cannot produce a green;
* the only new behaviour is **which sentence** a finding carries.

A diff to `verdict()` that does more than thread one argument is the signal that
this ADR has been misread. That is a check a reviewer can run; the old sentence
was not.

ADR-063's rule holds without amendment: **a gap is a named gap, never an
assumption.** Row 3 above is the one place this ADR could have guessed — it does
not; it says billing is off *and* says the account's state is unknown, which is
two true statements rather than one convenient one.

## Decision 3 — the proof is the state production is actually in

`prod_pulse_test.py`'s `test_linked_is_not_open` already covers `(True, True)`,
`(True, False)`, `(False, None)` and `(True, None)`. **There is no case where
`billing_enabled` and `account_open` are both `False`** — which is why the defect
shipped: the pair that production has been in since 2026-08-30 was never an input
to a test.

1. **The four `billing_enabled=False` rows each get a named assertion**, and each
   asserts the *distinguishing* words rather than merely that a finding exists —
   "no billing account is linked" must appear in the unlinked case and **must not
   appear** in the other three. A test that only counts findings would have
   passed on the shipped code.
2. **The account id appears in the linked-but-off sentences**, so the founder can
   act without a second lookup.
3. **Mutation-checked**: restoring the old early `return` must redden a *named*
   assertion, and the mutant is confirmed to change behaviour rather than be a
   no-op (lesson **112**).
4. **The notifier text is asserted, not only the report** (Decision 4).
5. **A floor on the case table** (lesson **110**): the number of states walked is
   asserted, so a table that shrank cannot report a clean zero.

## Decision 4 — the Slack sentence is asserted at its own seam

`findings_for_notifier` is what `--notifier-findings` prints, and ADR-064 D2b
makes that the watcher's whole output. The existing suite asserts the *shape*
(`production:` vs `production (unmeasurable):`) and the survival of the text
through `slack_notify.sh`; it does not assert that the billing sentence inside it
is the right one. It does now, for today's state — because the armed lane's first
real output should not be the sentence this ADR exists to remove.

## Consequences

* **The founder's instruction becomes correct for the state they are in**, which
  is the entire point: this is the command `operator-expected.md` names as how
  they will know billing is restored.
* **A recovery in progress is now legible.** Row 4 turns the intermediate state
  (account reopened, project not yet re-linked) from a wrong sentence into the
  remaining step.
* **`billing_findings` grows a parameter, and so does `verdict()`.** Revision 1
  said *"there is one caller, in `main()`"*, which is **false** — the production
  caller is `verdict()` (`prod_pulse.py:242`) and `main()` reaches it only
  through that. Three sites change: `main()` passes the value it holds,
  `verdict()` threads it, `billing_findings()` uses it, plus the test file's
  direct calls. A deliberate cost, accepted over inferring "linked" from
  `account_open is not None` — which would silently conflate the unlinked case
  with the unreadable one, i.e. rebuild Finding 4.
* **This is a reporting change only.** No credential, no scope, no exit code, no
  deploy. The CI lane's `PULSE_SCOPE` pin and ADR-064 D3's `logging.read`-only
  credential are untouched.
* **It cannot be observed against a healthy production**, and that is stated
  rather than hidden: the branch is only reachable while billing is off. Once the
  founder restores it, the fixtures are the only proof, which is why Decision 3
  makes them the acceptance criterion rather than a supplement to a live run.

## Alternatives rejected

| | why not |
|---|---|
| **Infer "linked" from `account_open is not None`** | Conflates *unlinked* with *account unreadable* — the two states Finding 4 says are already indistinguishable. It would rebuild the defect with a different symptom. |
| **Keep one sentence and soften it** ("billing is off for this project") | True in all four states and actionable in none. The founder's next move differs per state; a sentence that cannot say which is a sentence that sends them to the console to guess. |
| **Make the unlinked case exit 2** | It is a measured fact, not a gap. ADR-041's taxonomy is about whether we could *look*, not about what we found. |
| **Report the raw API fields and let the reader decide** | This is the instrument that exists because raw fields were misread for six days — `billingEnabled: true` was the raw field. Its job is the interpretation. |
| **Fix `operator-expected.md` only and leave the tool** | Already done at S089 as containment, and it is not a fix: the tool is also the Slack watcher's voice and the next session's first command. A document that corrects a tool is a note that goes stale. |

## What the design pass changed

4 lenses × 2 verifiers + a completeness critic; **13 agents, 0 errored, 0 empty
results, 0 skipped**; **2 lenses considered-empty** (both ran fully — one of them
ran the live probe to confirm the defect); 4 lens findings, **all 4 real to BOTH
verifiers, 0 refuted, 0 dropped unverified**; 1 critic finding, a duplicate of
the second.

| from | finding | what changed |
|---|---|---|
| lens *mechanism* (**blocking**) | D1 and D2 contradict — `billing_findings`'s caller is `verdict()`, so the parameter cannot arrive without `verdict()` changing, which D2 forbade | D1 now states the whole chain; D2's prohibition is replaced by three checkable invariants |
| lens *mechanism* (major) | Consequences named `main()` as the caller. It is not | corrected, with the line number |
| lens *adversarial* (minor) | Row 4 said *"re-link it"* for a state whose precondition is that the link exists | reworded to *enable billing on the project, or wait for propagation* |
| lens *mechanism* (minor) | Row 4's reachability was asserted, not measured | now stated as **defensive and unmeasured**, with the reason it stays anyway |
| **critic** | duplicate of the caller-chain error | — |

**Both verifiers said real on all four.** Unlike ADR-065's design pass, the
aggregation and my own re-measurement agreed — the difference being that this
panel's verifiers were told, in the prompt, that "no rule requires this" is not a
refutation (lesson **137**).

**What this pass could not check.** No lens ran the test suite (forbidden to
sub-agents, `session-context.md` §3), so every claim here about a test *passing*
is still a claim. The built-diff pass and the runs the diff itself performs are
what settle them.
