# ADR-041: A check that guards the working tree is not a check on production — compare what is DEPLOYED to what is MERGED

- **Status:** Accepted
- **Date:** 2026-08-01 (Session 058)
- **Deciders:** session agent (the code decisions need no founder input; **two operator actions fall out of it** — see D4 and D8)
- **Related:** issue **#140** (this ADR answers it; the residual is re-filed, see D8), **ADR-034** (the delta-not-absolute posture this leans on hardest, and the one asymmetry that does *not* transfer), **ADR-024** (the notifier with no vote, and "all policy in the tool, not the YAML"), **ADR-025 D8** (a declaration nothing enforces — the reason there is no committed marker file), **ADR-021 D4** (the fail-closed secrets-gate shape), **ADR-036** (`deploy-site.yml`, the worked example of a dispatch-only deploy lane), `docs/architecture.md` §9, `docs/test-suite.md` §2

## Context

`ci.yml`'s `functions-rules` job proves `firestore.rules` against the Firestore
emulator on every PR, honestly and thoroughly. **The emulator loads the
working-tree file.** So the job guards a ruleset the runtime never reads.

Between **2026-07-09** and **2026-07-27**, `hayatiapp-prod` and `hayatiapp-dev`
both served the M2.1 ruleset from `d913722` while six milestones of newer rules
sat merged in the repo and undeployed. `SoloHomeScreen`'s read of
`users/{uid}/soloAnswers/{dayKey}` fell through to the deny-all catch-all →
`permission-denied` → the founder reporting *"the Invite Your Partner screen
shows Something went wrong."* Every one of those six PRs was green.

**A green check that guards nothing is worse than no check, because it is also a
claim.** This is the `store_metadata` shape (S047) met for the fifth time.

### What was measured before anything was designed

Acceptance criterion 1, and it changed two decisions below.

| | prod | dev |
|---|---|---|
| release | `projects/…/releases/cloud.firestore` | same |
| live ruleset | `3702186d-7add-4c80-8c14-08f454d5cfc4` | `fbae0b36-aa8e-41b9-abbb-1fce8c5cbcf2` |
| released at | 2026-07-27T16:16:10Z | 2026-07-27T16:15:59Z |
| vs `main` | **identical** (`sha256:0d59af3a…`) | **identical** |
| releases on the project | **exactly 1** | **exactly 1** |

S052's remediation held; **the defect did not go away with the symptom.** Prod
has had exactly **three rulesets ever** — the 07-08 bootstrap, the 07-09 M2.1
one, and the 07-27 remediation — which is #140's narrative confirmed from the
platform rather than from the issue text.

### The two questions criterion 1 asks, answered plainly

**"What is live?"** — answerable from the founder's box, but **not by a
`firebase` CLI command**: firebase-tools has no `firestore:rules:get`. It is
answerable only by taking the credential the CLI *stores* and calling
`firebaserules.googleapis.com` directly.

**"Can CI ask?"** — **No.** `gh secret list` returns five repository secrets
(three `ASC_*`, two `MATCH_*`) and one environment (`release`) holding seven;
there is no `FIREBASE_*` secret anywhere. `FIREBASE_SERVICE_ACCOUNT` remains
unset, and the working local credential is a **human's OAuth refresh token**,
which must never be copied into CI.

That asymmetry — the answer exists, but only one laptop can obtain it — is the
constraint every decision below is shaped around.

## Decision 1 — Ask the platform. There is no committed marker file

The obvious credential-free alternative is a committed `last-deployed.sha` that
the deploy lane updates and CI diffs against `firestore.rules`. It was
considered and is **rejected**.

It is ADR-025 D8's shape — a declaration nothing enforces — and here it is worse
than usual: **the lane whose omission IS the bug is the same lane that would
update the marker.** No deploy → no marker update → no diff → **green**. It
fails in the reassuring direction, which is the one direction a gate must never
fail in. Only the authority can answer what the authority is serving.

## Decision 2 — Exit codes are a taxonomy, not a boolean

`tool/ci/rules_drift.py` exits **0** (match), **1** (drift — it looked, they
differ), or **2** (**could not measure** — no credential, API error, unreadable
ruleset, unexpected response shape). Never anything else, and **never 0 without
having compared**.

Collapsing 1 and 2 would reintroduce the defect verbatim: a check that reports
success when it could not look is exactly what `functions-rules` was doing.
This restates ADR-034 D5's rule in a second tool, deliberately.

Two properties follow from the same instinct:

- **Byte-exact, no normalization.** A ruleset that differs from the reviewed
  bytes by a trailing space is not the reviewed ruleset, and a whitespace rule
  is a place for a real edit to hide.
- **Coverage is asserted, not assumed.** A Firestore *named database* gets its
  own `cloud.firestore/{db}` release. A tool that only ever read
  `releases/cloud.firestore` would be **silently partial** the day one appeared
  — this tool's own failure mode, one level down — so it lists every release and
  fails **closed** on any second firestore one. Out-of-contract services
  (`firebase.storage/…`) are **reported, not failed**; both directions are
  tested.

## Decision 3 — The trigger, argued against ADR-034 rather than assumed

**ADR-034's asymmetry does not transfer, and that is an argument for a vote.**
`npm audit`'s absolute output moves for reasons no commit caused — a third party
publishes an advisory — so a gate on it would redden `main` for something nobody
did. Drift between merged and deployed is caused by **our own action or
omission** and is **always actionable**. So the check votes.

But the vote does not carry all the way to a per-PR gate, for a reason that
arrives at ADR-034's conclusion by a different road:

- **Never on `pull_request`.** Drift is a property of `main`-vs-the-projects,
  not of a contributor's diff. A PR touching Dart would go red for last week's
  undeployed rules — red for something its author neither caused nor can fix,
  since prod deploys are dispatch-only by design (D5). That is the cry-wolf
  shape ADR-024 and ADR-034 both refuse.
- **`main` only, dispatches included.** A `workflow_dispatch` from a feature
  branch would compare that branch's rules to production and report drift that
  is not drift. A false red is what this job can afford least, because its
  entire value is that its red means something.
- **Every push to `main`, not only rules-touching ones.** This was the closest
  call. The narrower trigger fires once on the offending merge and then goes
  **green on the next unrelated push while production is still stale** — a
  green check making a false claim, which is the sentence this ADR opens with.
  Accuracy wins over quietness: the red persists until the deploy happens, and
  it is always clearable.
- **No cron.** ADR-034 D4's finding transfers verbatim: GitHub disables
  scheduled workflows after 60 days without repository activity, so a cron
  switches *itself* off during exactly the quiet period it would exist to watch.

## Decision 4 — Read-only for the watcher, admin for the deployer

The design-review question worth answering: *a detector that reads a credential
CI holds is only as good as that credential's scope.* Splitting the credentials
is the answer.

- **`FIREBASE_RULES_VIEWER_SA`** — `roles/firebaserules.viewer` on **both**
  projects, a repository secret, used by the automatic `rules-drift` job. It
  requests the `firebase.readonly` scope, which was **verified against the API's
  own discovery document** rather than recalled — it is listed for each of the
  **three** methods this tool calls (`projects.releases.list`,
  `projects.releases.get`, `projects.rulesets.get`; the doc lists it for
  `projects.rulesets.list` too, which this tool does not use).
- **`FIREBASE_SERVICE_ACCOUNT`** — needs `roles/firebaserules.admin` added, and
  is used only by the dispatch-only deploy lane.

**The frequently-run automatic job therefore cannot cause the drift it reports,
and cannot be the thing that lies** — it reads from the authority with a
credential that can only read. Giving a job that runs on every merge the ability
to rewrite production's authorization rules would trade a silent-staleness bug
for a much worse one. The cost is one extra `gh secret set` for the founder; a
single admin secret serving both would be acceptable and is named as such on the
operator page, with the trade-off stated.

## Decision 5 — The deploy path is dispatch-only, and prod must be typed

`deploy-rules.yml`, modelled on `deploy-site.yml` rather than reinvented.

`firestore.rules` is the app's **authorization boundary**. One bad deploy
exposes or destroys couples' data, globally, in seconds, with no staged rollout
and no per-user flag. **Merging to `main` is not consent to change production's
security rules** — `deploy-site.yml`'s reasoning with more at stake.

`project: prod` alone would be one mis-click from rewriting live rules, so prod
**additionally requires typing `hayatiapp-prod`** into a free-text box with no
default — the confirmation shape `testflight-testers.yml` already uses for group
deletion, where typing the name *is* the confirmation and no default can fire by
accident. **Dev is a session's to exercise freely**; the asymmetry is the point.

The lane **measures, deploys, then reads back**:

- *Before*: exit 2 aborts (a blind deploy can overwrite something nobody saw);
  exit 1 does not (drift is the normal reason to be running this).
- *After*: any non-zero fails the run. A vendor reporting success is a claim
  about its own work; the guarantee is the release-time re-read. This is S056's
  AASA lesson — the glob looked fine by reasoning and was only settled by
  fetching the thing.

**The honest cost of dispatch-only is named rather than hidden:** between a
rules merge and a dispatch, production runs something other than `main`. That
window is precisely what D3's job makes impossible to forget.

## Decision 6 — The check either MEASURES or is VISIBLY SKIPPED. There is no third outcome

This is the decision that makes the whole thing more than plumbing, and it is
forced by a GitHub detail: **a job-level `if:` cannot read `secrets`, and a job
whose every step skipped reports GREEN.** The natural implementation — one job
with `if:` on each step — would ship a green check that measured nothing, i.e.
#140's defect wearing a new hat, added by the ADR that closes #140.

So the credential probe is **its own job** (`rules-drift-preflight`) publishing a
boolean, and `rules-drift` gates on it. The outcomes are exhaustive:

| credential | `rules-drift` | what a reader sees |
|---|---|---|
| present, in sync | green | measured |
| present, drifted | **red** | measured |
| present, unreadable | **red** (exit 2) | measured that it could not measure |
| **absent** | **skipped** | an honest gap, on every run, forever |

**A skipped job is an honest gap; a green one is a claim.** The preflight also
emits a `::warning::` naming exactly what is unguarded, and the no-credential
path in the tool is a *specified, tested* exit code rather than an accident.

`rules-drift` joins `slack-notify`'s fan-in: its red arrives after the merge with
no other reader, which is ADR-024's founding case. The notifier is generic over
`needs`, so this costs no script change and renders a skipped check as ⏭.

## Decision 7 — What was proven, and what only the founder can arm

**Proven against the platform, not asserted:**

- the detector against both live projects — in sync, exit 0;
- the detector against the **actual M2.1 bytes** from `d913722` — exit 1 with
  the real diff. Had it existed on 07-10 it would have printed exactly that;
- the deploy **command** the lane runs, exercised against `hayatiapp-dev` —
  `firebase deploy --only firestore:rules --project hayatiapp-dev` → `released
  rules firestore.rules to cloud.firestore`, then an **independent read-back**
  saying MATCHES. **Run from the local CLI, not through the workflow** — the
  workflow cannot run at all until `FIREBASE_SERVICE_ACCOUNT` exists, so what is
  proven is the command and the measure→deploy→verify sequence, *not*
  `deploy-rules.yml` itself. The CLI skipped the upload for identical content
  and re-pointed the release, which is why `live since` moved (`16:15:59Z` →
  `20:54:58Z`) while the ruleset id did not — incidental confirmation that the
  tool reads the **release**, not a cached ruleset;
- 19 hermetic self-test functions, **six mutants each killed by exactly the
  intended checks**, anchor uniqueness asserted before every edit.

**Not proven, and said plainly:** neither `rules-drift`'s measuring path nor
`deploy-rules.yml` has ever executed, because no credential exists to give
either of them. That is the S056
addendum-69 hazard by name — ADR-037's auto-assignment "never once ran" for
exactly this reason. What *is* exercisable today is the skip path, and it is
exercised on the very PR that adds the job. The measuring path is proven at the
tool level against the live API instead. Naming which half is proven by which
instrument is the point; claiming the job works would be the failure.

## Decision 8 — What is deliberately NOT built, and the residual is re-filed rather than closed

- **No deployed-Functions-code check.** #140's closing note flags the same gap
  for Functions (prod ran pre-coach code with nothing comparing it to `main`).
  It is a different artifact with no comparable source-identity read, and
  stretching it into this slice would be the scope creep session-rules §2
  forbids. **Filed as its own issue.**
- **No auto-deploy on merge** (D5).
- **No committed marker** (D1); **no cron** (D3); **no Slack routing beyond the
  existing generic fan-in** (D6).

**#140 is closed, and a narrow successor is opened in the same breath**, because
closing it alone would make the residual invisible — S057 addendum 72's lesson,
which is that a reassuring outcome is the most effective way to lose a real
requirement. What #140 asked for is built: the comparison instrument exists, the
deploy path is decided and shipped, and both are tested. What remains is not
engineering — it is one read-only secret, and it now has an issue, an operator
item (2(e)(iv)) and a `::warning::` on every main run pointing at it.
