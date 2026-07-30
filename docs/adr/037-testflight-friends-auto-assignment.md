# ADR-037: Every build reaches the Friends group automatically — the deliberate exception

- **Status:** Accepted
- **Date:** 2026-07-28 (Session 054)
- **Deciders:** founder (that external testers should get every build); session agent (upload-fast/assign-separately, and the non-blocking posture)
- **Related:** **#139** (the S052 lane that created the group), **ADR-032** (the release lane), **ADR-034** (why a third party's schedule must not redden a build), **ADR-040** (the build this ADR's guarantee was first measured on), `tool/ci/testflight_testers.py`

> ## ⚠️ Correction — 2026-07-30 (Session 056): this ADR's central guarantee did not hold on its first execution
>
> **The title claim was false for two days and nothing said so.** ADR-037 was
> written in S054; the release that followed it (build 112, run `30502948416`) was
> the **first** release run to reach the assignment step at all — build 110's
> release predates this ADR — and that step **failed**:
>
> ```
> ModuleNotFoundError: No module named 'jwt'
> ##[error]Process completed with exit code 1
> ```
>
> The `sign-upload` job had no `actions/setup-python`, so bare `pip install` and
> `python3` resolved to **different interpreters** on `macos-15`. The install
> reported success. The import did not exist. And because Decision 3 makes the
> step `continue-on-error` — still the right call — **the release reported
> success while no build was attached to anything.** Build 112 had to be assigned
> by a separate `testflight-testers.yml` dispatch, exactly the manual step this
> ADR exists to remove.
>
> Fixed by pinning the interpreter (`actions/setup-python` + `python3 -m pip`, so
> installer and runner are the same by **construction**, not by PATH order) and by
> asserting the import *before* the 25-minute Apple wait, so a missing dependency
> fails loudly at a named line instead of silently inside a tolerated step.
>
> **The lesson is not "continue-on-error was wrong".** It is that **non-blocking
> must not mean unread** — a tolerated failure still needs a reader, and this one
> had none. Decision 3's reasoning stands; Decision 3's *verification* was
> missing, and that is the gap. It is the #140 shape (a green check that guards
> nothing) inside the very lane ADR-037 built, met for the fourth recorded time.

## Context

S052 built `testflight-testers.yml` as **manual-dispatch only**, and said why:
*"adding an external tester emails a real person, and that must not be a side
effect of a merge."*

The founder has now asked that the **Friends** group receive every new build,
including the latest one. That is a direct instruction which overrides the
default — and the exception is worth naming rather than quietly reversing the
earlier reasoning.

## Decision 1 — This is an exception to the no-emails-on-merge rule, not a repeal of it

Assignment now runs on **every release**. The rule S052 wrote still stands for
everything else — *creating* testers and *adding* people to groups remains
dispatch-only, because that is what emails a **new** person. What runs
automatically is attaching an already-approved build to an already-existing
group of people who have already opted in.

## Decision 2 — NOT `pilot(distribute_external: true)`

The obvious implementation is one line in the `Fastfile`. It is wrong here.

`pilot` currently uploads with `skip_waiting_for_build_processing: true`.
External distribution requires that to be **false**, which parks the **macOS**
job — the most expensive runner in the pipeline — in Apple's processing queue
for the entire wait, on every release.

So the upload stays fast and the assignment waits **separately**, on ubuntu,
after `fastlane beta`. `tool/ci/testflight_testers.py` gains
`--assign-build-number` + `--wait-minutes`, which polls until Apple reports the
build `VALID`.

**Why polling at all:** a build still `PROCESSING` has no installable asset.
Attaching it would report success while delivering nothing — the failure shape
this repo has now met three times (`store_metadata` in S047, the rules-deploy
gap in #140, and the reason ADR-034's gate fails closed). `INVALID`/`FAILED`
stops immediately rather than burning the timeout.

## Decision 3 — Non-blocking, because Apple's queue is not our correctness

The step is `continue-on-error: true`. The binary already shipped in the step
above; a slow processing queue is a third party's schedule, and reddening a
release for it is the cries-wolf mistake ADR-034 rejected. A timeout prints how
to re-run rather than failing:

> `build 110 did not reach VALID within 25 min — NOT assigned. Re-run this
> workflow, or use --assign-latest-build once processing finishes.`

`await_build` returning `None` on timeout is therefore a **contract**, not an
oversight, and it is asserted in both directions: VALID returns the build,
PROCESSING-then-VALID waits and returns, INVALID gives up at once, timeout
returns `None`, an **expired** build is refused, and the match is by build
**number** rather than by position — the newest build is not necessarily ours.

## Decision 4 — The honest bound: this still does not deliver anything by itself

Apple gates external testers behind **Beta App Review**, and review needs the
**Test Information** page — beta description, feedback email, contact details.
That is founder-owned copy that no script can write.

The tool already reports the gaps by name (`review_readiness`), and prints them
after every assignment. Until they are filled, the honest description of this
lane is *"every build is attached to the group, and the group receives nothing"*
— which is exactly why the operator page states it in those words rather than
claiming the request is done.

**Internal testers are unaffected** and keep getting every build instantly.

## Consequences

- Every release attaches its build to Friends and prints the review gaps.
- The five testers receive a build only once Test Information is filled and
  review passes — the one part of the founder's request a session cannot finish.
- `--assign-latest-build` remains the manual twin, for the existing latest build
  and for re-runs after a timeout.
