# ADR-048: The Functions deploy lane — dispatch-only, clean-tree *enforced* rather than assumed, and a read-back that votes even when the deploy FAILED

- **Status:** Accepted
- **Date:** 2026-08-17 (Session 070)
- **Deciders:** session agent (the lane and its tool changes need no founder input; **two operator consequences fall out** — see D7 and the operator note in Consequences. Firing the lane at `hayatiapp-prod` remains a founder ask, `session-context.md` §7)
- **Related:** issue **#206** (this ADR answers it; split out of **#166** at S065), **ADR-043** (the checker this lane feeds and whose **D8** re-filed exactly this work; D3's dirty-tree branch is the thing this lane makes unnecessary), **ADR-041 D5** (`deploy-rules.yml`, the precedent and the shape — measure → deploy → read back, dispatch-only, typed prod confirmation), **ADR-036** (`deploy-site.yml`, the first dispatch-only lane), **ADR-021 D4** (the fail-closed secrets-gate idiom), **ADR-024 D1** (all policy in the tool, not the YAML), **ADR-034** (fail-closed, and why there is no cron), **ADR-030** (Node 22), **ADR-013** (`RC_WEBHOOK_TOKEN`), `docs/architecture.md` §9, `docs/test-suite.md` §2, lessons **64**, **65**, **71**, **77**, **86**, **92**, **94**

## Context

`deploy-rules.yml` and `deploy-site.yml` exist. **Cloud Functions have no deploy
workflow**, so every Functions deploy this project has ever had was a hand-typed
`firebase deploy` from one laptop, and nothing recorded that it happened.

That gap has already cost this project twice, and both times it cost the same
thing — the belief that merged and green meant running:

* **S063** shipped the entire push feature merged, reviewed, green, with two
  builds in TestFlight, while `registerPushToken` and `unregisterPushToken`
  **did not exist in production** (lesson **86**).
* **S068**'s outage found all **13** deployed functions drifted from `main` at
  once.

ADR-043 built the detector (`tool/ci/functions_drift.py`) and deliberately did
**not** build the lane — session-rules §2, drive-by scope is scope creep wearing
a helmet. Its **D8** stated the residual and made the argument this ADR now
takes:

> A dispatch-only `deploy-functions.yml` on a clean checkout would make
> `referenceHash` and `workingTreeHash` identical by construction, and D3's
> whole diagnostic branch would become dead code — the good kind.

## What was measured before anything was designed

Everything below was re-measured on **2026-08-17** from this box, read-only.
None of it is inherited from the handoff, and **two inherited facts turned out
to be stale** — which is the reason the rule exists.

### The projects

| | measured |
|---|---|
| `hayatiapp-prod`, `functions_drift.py` | **exit 0 — MATCHES.** 13 deployed, 13 exported, `reference c250c5c25611e2fa…` over **213 files = 116 tracked + 97 built + 0 foreign** |
| `hayatiapp-dev` | **exit 1 — DRIFT.** 12 deployed, all ACTIVE, all carrying `1f30803f9ca528e3…`; **none** matches this ref, and `revenueCatWebhook` is **absent** |
| Secret Manager, prod | `LLM_API_KEY`, `RC_WEBHOOK_TOKEN` |
| Secret Manager, dev | `LLM_API_KEY` **only** |
| `gh secret list` | **no `FIREBASE_SERVICE_ACCOUNT`** — the lane ships unarmed |
| Artifact Registry `gcf-artifacts` / `europe-west1`, **both** projects | cleanup policy `firebase-functions-cleanup` present (`tagState: ANY`, `olderThan: 86400s`) |

**The first row is a correction.** ADR-043 measured production as *"running this
ref's code, hand-deployed from a directory carrying 62 foreign files"* (61 under
`functions/coverage/`, plus `firestore-debug.log`), and
`docs/operator-expected.md` still tells the founder that the first armed run of
`functions-drift` will report drift on prod for that reason. **It will not.**
Those files are gone from this working tree, and prod's 13 deployed hashes
reproduce the *clean* reference exactly. `functions/lib` was rebuilt
(`npm run build`) and the reference hash did not move, so the reference is a
current build and not a stale one. The operator page is corrected in this diff —
a stale fact inside an instruction gets executed (lesson **64**).

**The third and fourth rows are the live reason `--only` must exist.** Operator
item **0(c)** is still open: dev has no `RC_WEBHOOK_TOKEN`, so `revenueCatWebhook`
genuinely cannot deploy there. Any lane that can only deploy *everything* cannot
be pointed at dev at all.

### The vendor, read out of the installed firebase-tools 15.22.4

Never out of documentation — ADR-043's own idiom, and it paid four times.

**1. `--only` selectors are parsed in a way that turns a typo into a full
deploy.** `lib/deploy/functions/functionsDeployHelper.js`, `getEndpointFilters`:

```js
const selectors = options.only.split(",");
for (let selector of selectors) {
    if (selector.startsWith("functions:")) {
        selector = selector.replace("functions:", "");
        if (selector.length > 0) filters.push(...parseFunctionSelector(selector, config));
    }
}
if (filters.length === 0) return undefined;   // undefined === NO FILTER
```

Each selector must carry its **own** `functions:` prefix; one that does not is
**silently dropped**. And if every selector is dropped — including the natural
`--only functions:` with an empty list — the function returns `undefined`, which
downstream means *no filter at all*: **deploy everything**.

So `--only functions:a,b` deploys only `a`, and `--only functions:` deploys all
thirteen. An operator asking for one function and receiving a full production
deploy is the worst available failure direction, and it is one comma away.

**2. `--force` silently deletes.** `lib/deploy/functions/prompts.js`,
`promptForFunctionDeletion`: `if (functionsToDelete.length === 0 || options.force) return true;`
— with `--force`, any function present in the project but absent from the source
is deleted **without a prompt**. Without `--force`, a non-interactive run
**aborts** and prints the explicit `firebase functions:delete` commands.

**3. `--force` is one flag meaning four different things.** The same flag also
waves through a new failure policy, a min-instance bill increase, and the
Artifact Registry cleanup policy. They are unrelated decisions sharing one
switch.

**4. The CLI will partially deploy on purpose.** `promptForUnsafeMigration`, in
non-interactive mode, **skips** the unsafe updates, logs a warning and
**continues** with the rest. A functions deploy is not atomic in the way a rules
release is.

**5. A post-release throw that a lane could mistake for a failed deploy.**
`lib/deploy/functions/release/index.js:130` calls `artifacts.checkCleanupPolicy`
**after** the functions are released; if a location has no cleanup policy, the
non-interactive path throws *"Functions successfully deployed but could not set
up cleanup policy"*. Measured above: both projects already carry the policy in
`europe-west1`, so it cannot fire today. It is named, not assumed away, and D4
is what tells the two apart if it ever does.

**6. `answerReveal` sets `retry: true`**, and `promptForFailurePolicies` throws
in non-interactive mode for a **newly** retried endpoint. It is already deployed
with retry on both projects, so `newRetryEndpoints` is empty and it cannot fire
on either project today. On a fresh project it would — named, not assumed.

**7. Secret bindings short-circuit.** `lib/gcp/secretManager.js`,
`checkServiceAgentRole` reads `getIamPolicy` first and returns `[]` when every
required member is already bound, so `setIamPolicy` is **never called** on a
steady-state redeploy. This is what lets D7 ask for a Secret Manager role that
cannot read secret *values*.

### The credential, measured against the IAM API rather than inferred

An operator instruction naming a wrong role gets executed by a human and wastes
their afternoon. So the role set was measured: each candidate role's
`includedPermissions` was read from `iam.googleapis.com/v1/roles/<id>` and
compared against the permissions the deploy actually calls.

**That measurement refuted the documentation.** Firebase's own IAM page says
deploying Functions requires *"permission configurations not included in
standard Firebase predefined roles"* — but `roles/firebase.admin` measurably
**does** carry `cloudfunctions.functions.{get,list,create,update,delete,sourceCodeSet,setIamPolicy}`,
`run.services.{get,update,setIamPolicy}`, `eventarc.triggers.{create,update}`,
`artifactregistry.repositories.get`, `cloudbuild.builds.get` and
`serviceusage.services.get`. What it does **not** carry is the part the doc's
sentence is actually about, and two more nobody's blog post mentions:

| missing from `roles/firebase.admin` | needed because |
|---|---|
| `iam.serviceAccounts.actAs` | the CLI checks it explicitly (`checkIam.js`, `checkServiceAccountIam`) and fails naming it |
| `cloudscheduler.jobs.{get,create,update}` | `questionRollover` is `onSchedule`, and `fabricator.js`'s `upsertScheduleV2` calls `createOrReplaceJob` on **every** deploy, not only the first |
| `secretmanager.secrets.getIamPolicy` | `coachProxy` and `revenueCatWebhook` bind secrets, and the binding is *read* on every deploy (finding 7) |

## Decision 1 — Dispatch-only, and prod is additionally pinned to `refs/heads/main`

Dispatch-only for ADR-041 D5's reason, restated because it is the same argument
one target over: merging to `main` is not consent to change what production
*runs*. The cost is honest and named — between a Functions merge and a dispatch,
production runs something other than `main` — and that window is exactly what
ADR-043's `functions-drift` job makes impossible to forget.

**Beyond the precedent:** a `workflow_dispatch` runs against whatever ref the
dispatcher selects, and `deploy-rules.yml` accepts any of them. For Functions
that is not acceptable: deploying a branch to prod would **manufacture the exact
defect this lane exists to remove.** `functions-drift` on `main` would go red the
next push and correctly report *"running source that is NOT this ref"*, and the
next reader would hunt a drift that a dispatch box created on purpose.

So prod requires `github.ref == 'refs/heads/main'`, checked before anything else.
**Dev is deliberately free** — exercising a branch on dev is the whole point of
dev, and `session-context.md` §7 says so.

`deploy-rules.yml` has no such guard. That is a real gap in the precedent, it is
**filed as #223 rather than fixed here** (session-rules §2) — changing an
existing lane's safety posture deserves its own decision — and this ADR is the
record of why it is worth fixing.

## Decision 2 — The typed prod confirmation, unchanged

`confirm_prod` is a free-text box with no default; prod refuses unless it
contains exactly `hayatiapp-prod`. Checked **before** the secrets gate, so a
mistyped prod dispatch fails on the cheap obvious reason rather than on a
missing credential that would send the reader down the wrong path. That is
ADR-041 D5's shape and it is copied, not re-argued.

## Decision 3 — The subset selector is CONSTRUCTED from validated names, never passed through

Measured finding 1 makes this a safety decision rather than an ergonomic one.

* The `only` input is free text and reaches the shell **through `env:`**, never
  interpolated into a `run:` body — `${{ }}` expands before bash sees the line,
  so a value carrying shell metacharacters would otherwise execute. That rule is
  already written into `testflight-testers.yml` and `appid-capabilities.yml`;
  this lane inherits it.
* **`only` is optional, its default is empty, and empty means every exported
  function** — the lane then passes no `--only` at all, to the CLI or to the
  tool. So there is exactly one way to ask for a full deploy (leave the box
  empty) and exactly one way to ask for a subset (name them), and **neither can
  produce the vendor's silent-full-deploy shape**: the dangerous input is a
  *non-empty* selector that degrades to no filter, and a non-empty box is
  validated before it can.
* A non-empty value is validated against
  `^[A-Za-z][A-Za-z0-9_]*(,[A-Za-z][A-Za-z0-9_]*)*$` and refused otherwise.
  Underscore is allowed because a barrel export is a JS identifier and may carry
  one. **A hyphen is deliberately refused**: `parseFunctionSelector` splits a
  selector on `[-.]` into prefix-matched chunks, so a hyphenated name is not
  compared the way this lane's report would claim it is. Every export is
  camelCase today, so neither case fires — the rule is written down because on
  the day one does not, the failure would be a silent mis-selection.
* The lane then **builds** `functions:a,functions:b` itself, prefix on every
  element. It never emits a bare `--only functions:`, and it never forwards the
  operator's string.
* `functions_drift.py --only` validates the same names **semantically**: a name
  the barrel does not export is **exit 2**, not a silent no-op.

Two layers doing two different jobs: the regex guards the shell, the tool guards
the meaning. Neither is redundant — the regex cannot know that `registerPushTokn`
is not a function, and the tool cannot stop a semicolon reaching bash.

## Decision 4 — Measure BEFORE, deploy, measure AFTER — and the after-measurement runs even when the deploy failed

The first three are ADR-041 D5's sequence: exit **2** on the pre-check aborts
(deploying while blind to the current state is how you find out afterwards that
you overwrote something you never saw), exit **1** is the *normal* reason to be
running this workflow at all, and the read-back votes because a vendor reporting
success is a claim about its own work.

**The fourth is new, and it is the difference between rules and functions.** A
ruleset is one artifact released in one call: it applied or it did not. A
Functions deploy is **N independent operations**, and measured finding 4 shows
firebase-tools will partially apply *on purpose*. The most dangerous state this
lane can produce is a **partially applied deploy that nobody measured**, and that
state exists **only after a failure** — precisely when a normal `steps` sequence
stops running.

So the read-back carries `if: always()` and still votes. Three readings follow
from it, all of which a reader needs and none of which the deploy's own exit
code can give:

```
deploy OK,   read-back MATCHES  -> deployed, and proven.
deploy FAILS, read-back DRIFT   -> nothing landed, or some of it did. The report
                                   names which functions.
deploy FAILS, read-back MATCHES -> every scoped function's source IS this ref,
                                   and the CLI failed at something around or
                                   after the release — measured finding 5's
                                   cleanup policy is exactly this shape.
```

That last row is why finding 5 is recorded rather than dismissed: the design
already diagnoses it.

**The third row says what is true NOW; it does not say the deploy caused it.**
A function already at this ref before the dispatch reads MATCHES whether or not
its update landed — the read-back compares against the *ref*, never against the
pre-deploy state. **The pre-check is what closes that gap**, which is the second
reason it exists: *pre-DRIFT → post-MATCHES* is the deploy landing, and
*pre-MATCHES → post-MATCHES* is a no-op re-deploy. A no-op re-deploy is a
legitimate thing to dispatch — after a secret rotation, or to prove a suspicion —
so it is reported, not failed.

## Decision 5 — Both measurements carry the SAME scope, and a scoped green says so

`functions_drift.py` gains `--only NAME[,NAME…]`, restricting **both** verdicts —
the set comparison and the hash comparison — to the named functions. Exit 0 then
means *"the named functions are a clean build of this ref"*, which is a smaller
claim than the tool's usual one and must never be read as the usual one.

So the scope is printed in the report, the count of exported functions **not
examined** is printed with it, and the `::error::` summary and the success line
both carry it. ADR-043 D4's rule applied to itself: an unnamed limitation makes a
green a false claim; a named one is a scope.

**The rejected alternative was an unscoped pre-check with a scoped read-back.**
It reads better as *"here is everything that is drifted right now"*, and it is
wrong twice: the two reports become incomparable, and an out-of-scope **exit 2**
— an unmeasurable function this dispatch is not about — would abort a deploy that
had nothing to do with it.

**One asymmetry is deliberate.** ADR-043 D5's zero-listing guard (lesson **65**:
an empty result is *unverified*, not negative) is evaluated against the
**unscoped** listing. Zero functions deployed *at all* is genuinely ambiguous —
maximal drift, or a credential that reaches the API and cannot see them. Zero
deployed *within a scope* while others are plainly visible is unambiguous drift.
Collapsing those two would put the tool back where ADR-043 D5 started.

Under a scope, *"deployed but not exported"* is suppressed: a subset deploy makes
no claim about functions outside its subset, and reporting one would be the tool
inventing a finding out of the operator's choice of arguments. **That does leave
a stale, unexported function unreported by this run — and reported by the next
push**, because `functions-drift` runs **unscoped** on `main` (ADR-043 D6) and is
exactly the lane that catches it. The scope narrows one dispatch's claim; it does
not narrow the repository's.

### The rule that makes the scope real, and without which it is decoration

**A function outside the scope is RECORDED but never EXAMINED.** No platform
(`gcfv1`), DataConnect, codebase, hash-label, `FIREBASE_CONFIG` or
secret-binding check runs on it, and **none of them can produce exit 2**.

This has to be said explicitly, because the natural implementation violates it.
ADR-043 D5's three exit-2 cases are raised while *parsing the listing* — before
any comparison — so a tool that parsed first and scoped second would exit 2 over
a `gcfv1` function, or one carrying no hash label, that the dispatch never
mentioned. That is precisely the abort this decision rejects, arrived at through
the back door.

It is also the *correct* reading of ADR-043 D5 rather than an amendment to it:
those three cases are per-function judgements about **measurability**, and a
dispatch naming two functions is not made blind by a third it never named.

Recording the out-of-scope functions rather than dropping them is what keeps the
zero-listing guard above, and the reported deployed count, telling the truth.

## Decision 6 — `--require-clean-tree`: the lane's entire justification, enforced instead of assumed

#206 and ADR-043 D8 both argue that a lane deploying from a clean checkout makes
`referenceHash` and `workingTreeHash` identical **by construction**. "By
construction" is a claim, and this repo's second recurring failure shape is *a
claim that outran its instrument*. A fresh runner is clean today; nothing stops a
future step, cache action or predeploy hook from leaving a file behind, and the
failure would be silent — the deploy would simply carry it into production's
digest, exactly as a laptop's `coverage/` report did (lesson **92**).

So `functions_drift.py` gains `--require-clean-tree`: **exit 2** if the packaged
walk contains any foreign file, naming them.

It runs on the **pre-check only**, and that is a decision rather than an economy.
It is a precondition of deploying, and nothing writes into `functions/` between
the pre-check and the CLI's own walk — `firebase.json` declares **no `predeploy`
hook** for the functions target (measured). Putting it on the read-back as well
would be actively worse: after a *failed* deploy the tree may legitimately carry
debris, and an exit 2 there would replace the drift diagnosis that is the entire
reason the read-back runs `if: always()` (D4).

It also makes the *local* command honest: a session running the lane's exact
command from this laptop is refused the moment `functions/coverage/` comes back,
rather than quietly reproducing the hand-deploy this lane exists to end.

## Decision 7 — The credential is `FIREBASE_SERVICE_ACCOUNT`; item 2(e)(iii) keeps its number and grows its instructions

One secret, three lanes (site, rules, functions). A second secret would be a
second thing the founder has not done — and today they have done neither, which
is the real constraint.

The roles, from the measurement above:

| role | why, and how it was established |
|---|---|
| `roles/firebase.admin` | functions CRUD, source upload, Run services, Eventarc triggers, Artifact Registry read, build status — **and** the hosting and rules deploys this secret already performs. Measured from the role definition, against the documentation's claim to the contrary |
| `roles/iam.serviceAccountUser` | `iam.serviceAccounts.actAs`; measured absent from `firebase.admin`, and the CLI checks it by name |
| `roles/cloudscheduler.admin` | `questionRollover` is `onSchedule`; `upsertScheduleV2` runs on **every** deploy |
| `roles/secretmanager.viewer` | `secrets.getIamPolicy`, which is all a redeploy of an **already-bound** secret needs (finding 7) |

**`roles/secretmanager.admin` is deliberately NOT requested.** It is the only
role carrying `secretmanager.versions.access` — measured — so asking for it would
hand a CI credential the ability to **read `LLM_API_KEY` and `RC_WEBHOOK_TOKEN`**,
in exchange for a permission (`setIamPolicy`) that a steady-state deploy never
calls. ADR-041 D4 split credentials by privilege for the watcher; this is the
same instinct applied to the deployer.

The item **keeps the number 2(e)(iii)** — lesson **71**: it is cited by name from
`deploy-site.yml:95` and `deploy-rules.yml:32,96`, and ADR-041 cites its
read-only sibling **2(e)(iv)** — while its instructions change. An item whose
number survives while its instructions silently grow is how a founder ends up
performing yesterday's task.

**Stated, not buried: this role set is measured for COVERAGE and has not been
EXERCISED.** No service account exists to exercise it with. Three named cases
would need more, and each fails with the missing permission printed:

* a deploy introducing a **new** secret binding needs `secretmanager.secrets.setIamPolicy`;
* a **brand-new project** needs `serviceusage.services.enable` (in none of the
  roles above — both projects already have the APIs on);
* a **new** scheduled function needs `pubsub.topics.create` for its topic
  (`questionRollover`'s exists on both).

The remedy is procedural and is written into the operator item: **point the first
armed dispatch at `hayatiapp-dev`.** A permission error there costs nothing and
names the role. That is ADR-041's own pattern — dev was the live positive case
before prod was ever touched.

## Decision 8 — No `--force`, ever

Measured finding 2 makes this the only defensible choice: `--force` would let a
bad barrel edit **silently delete** `revenueCatWebhook` from production and take
the entitlement mirror down with it. Without it, the same situation **aborts**
and prints the exact `functions:delete` commands, which is fail-closed and
actionable.

The lane accepts the three costs that come with it, all measured above and all
currently inert: a newly-retried endpoint (finding 6), a min-instance bill
increase (this repo reserves none), and an absent cleanup policy (finding 5).
Each throws with an explicit message; none is silent; and D4's unconditional
read-back is what separates "the deploy failed" from "the deploy worked and the
CLI failed afterwards".

**`--non-interactive` is passed explicitly** rather than relied on. firebase-tools
infers it from `!process.stdin.isTTY` (`lib/command.js`, `prepare()`), and a lane
whose deletion-safety depends on a runner's **stdin** not being a terminal is one
runner change away from a prompt that hangs until the job times out.

## Decision 9 — The CLI pin becomes load-bearing in a new way, so it is asserted

ADR-043 D9 recorded a residual it could not engineer away: *"the comparing CLI is
not the deploying CLI"* — the tool verifies the algorithm of the firebase-tools
installed now, while the hash it compares against was stamped by whichever
version performed the deploy.

**Inside this lane those are the same process tree, pinned to the same version,
minutes apart.** For anything deployed through the lane, that residual is gone.

That is true only while the pins agree, and they live in different files:
`VERIFIED_CLI_VERSION` in `tool/ci/functions_drift.py`, and
`npm install -g firebase-tools@…` in four workflows. A silent disagreement would
make the read-back's verdict meaningless in the reassuring direction. So
`functions_drift_test.py`'s repo-reality section gains a hermetic assertion that
**every** `firebase-tools@` pin under `.github/workflows/` equals
`VERIFIED_CLI_VERSION`. It needs no network, no CLI and no credential, and it
runs in `quality` on every PR beside the tool's other self-tests.

## Decision 10 — Concurrency, timeout, and the annotation the tool has to stop printing

* `concurrency: { group: deploy-functions-<project>, cancel-in-progress: false }`.
  Two dispatches against one project would have two CLIs fighting over the same
  thirteen endpoints; queueing is correct and cancelling is not — a deploy killed
  between its fourth and fifth function is the partially-applied state D4 exists
  to catch. Per project, because a dev deploy has no reason to wait on a prod one.
  `testflight-testers.yml` and `appid-capabilities.yml` set the same shape.
* `timeout-minutes: 30`. Thirteen gen-2 functions build containers; the 10 that
  `deploy-rules.yml` uses is a single API call's budget.
* `functions_drift.py`'s own `::error::` line currently ends *"Cloud Functions
  have no deploy lane (#166's residual, re-filed), so this is a manual
  `firebase deploy --only functions`"*. **That sentence becomes false in this
  diff**, and it sits inside an `::error::` string a human reads only at the
  moment their check just went red. It is rewritten to name the lane. Lesson
  **64**, caught in our own tool rather than in someone else's document.

## Decision 11 — What this lane deliberately does not do

Named rather than absorbed, because an unnamed omission reads as coverage:

* **It does not verify that the ref it is deploying is green.** For prod that is
  bounded by D1's `main` pin, which is post-CI by construction; for dev it is
  deliberate, since deploying an unmerged branch to dev is the reason dev exists.
* **It does not delete functions** (D8), rotate secrets, or touch environment
  variables — the same boundary ADR-043 D4 drew for the checker.
* **It does not deploy rules or hosting.** One lane, one artifact class; the
  other two exist and are dispatched separately.
* **There is no auto-deploy on merge and no cron.** ADR-034 D4's finding
  transfers verbatim — GitHub disables scheduled workflows after 60 days of
  inactivity, i.e. during exactly the quiet period one would exist to watch.
* **It cannot deploy `revenueCatWebhook` to dev** until operator **0(c)** lands.
  That is not a lane limitation; it is a missing secret, measured above, and
  `--only` is how the lane stays useful in the meantime.

## Consequences

* **#206 closes.** All six of its acceptance checkboxes are taken, and the
  `--only` one turned out to carry a vendor footgun the issue did not know about
  (measured finding 1).
* **ADR-043 D3's dirty-tree diagnostic branch becomes dead code for anything
  deployed through this lane** — the good kind, as D8 predicted. It **stays**:
  hand deploys remain possible, prod's history contains several, and the branch
  is what tells a process gap from an emergency when one happens.
* **ADR-043 D9's "comparing CLI is not the deploying CLI" residual is removed
  for lane deploys** and is now asserted rather than hoped (D9).
* **The lane ships UNARMED** and fails closed at its secrets gate, exactly as
  `deploy-rules.yml` did and still does. Saying so is the point: ADR-037's
  auto-assignment "never once ran" for precisely this reason. **Neither this
  workflow nor `deploy-rules.yml` has ever executed.**
* **The operator page carries a prediction that is now wrong** — that
  `functions-drift`'s first armed run will report prod drifted because of 62
  foreign files. Prod measures clean. Corrected in this diff, together with item
  2(e)(iii)'s role list and 2(e)(iv)'s closing paragraph.
* **`session-context.md`'s "There is no Functions deploy workflow"** and the same
  claim in `docs/architecture.md` §9 are corrected. `session-lessons.md` **86**
  and `past-prompts.md` are historical record and are **not** rewritten
  (append-only; lesson **71**'s instinct) — §9 and the operator page are where a
  reader goes for current state.
* **A prod dispatch remains a founder ask** (`session-context.md` §7). The typed
  confirmation is a guard, not permission, and D1's `main` pin is not permission
  either.
* **The built-diff review found one real defect in the lane** and it is recorded
  rather than quietly patched: `only` accepted a **newline**, which passes a
  line-by-line `grep`, is then truncated by `IFS=',' read`, and corrupts the
  `GITHUB_OUTPUT` line — so the run would deploy the first function, read back
  the first function, and go **green** while the rest were never deployed. That
  is D3's silent-mis-selection failure arriving through a character the pattern
  never mentions, which is why the guard now asserts the input's **shape** as
  well as its alphabet (lesson **105**).

### Residual risk this design knowingly accepts

**The role set is measured for coverage and unexercised.** D7 names the three
cases that would need more and puts the first armed dispatch on dev, where the
error is free and names the missing role. This cannot be closed from the repo
side; no credential exists.

**A scoped run's green is a smaller claim than an unscoped one.** D5 makes the
scope loud in three places, but a reader who ignores all three can still
misread it. The alternative — refusing to scope at all — would mean the lane
could never be pointed at dev while 0(c) is open, which is worse.

**The lane deploys the ref it was dispatched on, and CI's green is a separate
fact.** D1 bounds it for prod and deliberately does not for dev.

**`--require-clean-tree` proves the tree, not the toolchain.** It cannot detect a
`functions/lib` that is a *stale* build of a *clean* source — ADR-043 D3's stated
limitation, unchanged. On CI `lib/` is built fresh into an empty checkout, which
is the only place this lane's exit code gates anything.

## What the design review moved, recorded rather than quietly folded in

This design was reviewed **before any code existed** (session-context.md §5.1/§5.3):
five lenses — vendor behaviour, blast radius, tool semantics, governing documents,
measurement integrity — each finding then put to **two independent verifiers**, a
refuting skeptic and a governing-docs adjudicator, surfacing when *either* said
real (§5.2). 17 findings raised, 14 verified, **3 dropped unverified and named**
(§5.6), 6 survived. What it changed:

* **The scope rule of D5 was missing its load-bearing half.** The adjudicator
  showed that scoping only the two *verdicts* leaves ADR-043 D5's exit-2 cases
  firing during listing parse, so an out-of-scope `gcfv1` or unlabelled function
  would abort a dispatch that never named it — the exact abort D5 rejects. The
  skeptic argued the ADR already implied it; the adjudicator's point stands
  precisely because a *naive implementation of the stated words* would be wrong.
  D5 now states the rule explicitly, because this ADR is the specification the
  code is written from.
* **`only`'s empty case was undefined** — the regex demanded at least one name
  and nothing said how to ask for a full deploy. D3 now defines it.
* **The regex was wrong in both directions**: it refused `_`, which a JS
  identifier may carry, and said nothing about `-`, which the vendor's own
  selector parser treats as a chunk separator. Both are now decided and argued.
* **D4's third row over-claimed.** "Everything landed" is not what a read-back
  against the *ref* can prove; it proves the source is this ref now. The pre-check
  is what supplies causation, and D4 now says so.
* **Two factual errors**: the CLI's interactivity comes from **stdin**, not
  stdout, and ADR-041 cites **2(e)(iv)**, not 2(e)(iii). The second was one of the
  three findings the cap dropped *unverified* — checked by hand afterwards, and
  real. A dropped finding is not a refuted one (lesson **65**), which is why they
  are listed rather than discarded.
