# ADR-066: "billing is off" is three states, and the tool printed one sentence

- **Status:** Accepted — revision 1 (2026-08-30, Session 090), written and committed **before** the code
- **Date:** 2026-08-30 (Session 090)
- **Deciders:** session agent (a reporting change to a local/CI instrument; no credential, no deploy, no schema)
- **Related:** **ADR-063** (the rebuild that made `prod_pulse` able to report *during* an outage — **D4 is the decision this completes**), **ADR-064 D2b** (the watcher lane and `EXTRA_FINDINGS`, which is where this sentence would go to Slack), **ADR-041** (the 0/1/2 exit taxonomy, **untouched here**), issues **#267** (this one), **#219** and **#263** (the two outages whose cost this class of defect carries)

> **Review status.** Written before the code (`session-context.md` §5 item 1,
> lesson **115**). The design pass has not run yet.

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
`main()` already holds. The states, in the order the function tests them:

| `billing_enabled` | `account_name` | `account_open` | what it says |
|---|---|---|---|
| `False` | `None` | — | **not linked**: *"no billing account is linked"* — the sentence that is correct only here |
| `False` | named | `False` | **linked to a CLOSED account** — today's state. Names the account and says *reopen it or link an open one* |
| `False` | named | `None` (gap) | **billing off, and the account's own state could not be read** — the gap is named, never assumed |
| `False` | named | `True` | **billing off although the account it names is open** — the project link itself has been removed or disabled; re-link it |
| `True` | named | `False` | unchanged: *"the linked billing account is CLOSED"* (ADR-063 D4's case) |
| `True` | any | `True` / `None` | unchanged: healthy, or a gap for the caller to name |

**Every `billing_enabled=False` row is a finding**, including the fourth — the
project cannot serve, whatever the account says. What changes is only *which
sentence*, and every sentence now matches a state the reader can act on.

**The fourth row is not hypothetical padding.** It is what a *successful*
recovery looks like halfway through: the founder reopens the account, and until
the project is re-linked, `billingEnabled` is false while `open` is true. A tool
that told them *"no billing account is linked"* at that moment would be right by
accident; one that says *"the account is open, the project link is not"* tells
them the remaining step.

## Decision 2 — the exit-code taxonomy is untouched, and so is the gap rule

ADR-041's `0 / 1 drift / 2 could not measure` is binding, and the local operator
command depends on it. **Every branch above is still exit 1**, because every one
of them is a finding; nothing here moves a code, adds a code, or changes when a
gap wins. If a change to `verdict()` becomes necessary, that is the signal that
this ADR has been misread.

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
* **`billing_findings` grows a parameter**, so every caller must pass it. There is
  one, in `main()`, and the test file — a deliberate cost accepted over inferring
  "linked" from `account_open is not None`, which would silently conflate the
  unlinked case with the unreadable one, i.e. rebuild Finding 4.
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
