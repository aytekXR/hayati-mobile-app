# ADR-037: Every build reaches the Friends group automatically — the deliberate exception

- **Status:** Accepted
- **Date:** 2026-07-28 (Session 054)
- **Deciders:** founder (that external testers should get every build); session agent (upload-fast/assign-separately, and the non-blocking posture)
- **Related:** **#139** (the S052 lane that created the group), **ADR-032** (the release lane), **ADR-034** (why a third party's schedule must not redden a build), `tool/ci/testflight_testers.py`

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
