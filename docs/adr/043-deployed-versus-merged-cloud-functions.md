# ADR-043: `firebase-functions-hash` is not opaque — the deployed Functions ARE comparable to `main`, and what stops the comparison being exact is that nobody deploys from a clean tree

- **Status:** Accepted
- **Date:** 2026-08-09 (Session 065)
- **Deciders:** session agent (no founder input needed for the code; **two operator consequences fall out** — see D7 and D8)
- **Related:** issue **#166** (this ADR answers it), **ADR-041** (the rules half — this is its Functions sibling and mirrors its exit taxonomy, its preflight-job shape and its read-only-by-construction rule; **D1's marker-file objection is examined and found NOT to apply**, see D3), **ADR-030** (Node 22), **ADR-013** (`RC_WEBHOOK_TOKEN` in Secret Manager), **ADR-034** (fail-closed, delta-not-absolute), **ADR-024** (all policy in the tool, not the YAML), `docs/architecture.md` §9, `docs/test-suite.md` §2

## Context

`ci.yml` proves `functions/` against the emulator on every PR. The emulator
loads the **working tree**. Nothing compares the code that `hayatiapp-prod` is
actually *running* to the code on `main`.

That is not hypothetical. **It cost S063 the entire push feature**: the whole
stack merged, every PR green, `integration-emulator` green, two builds shipped —
and production was still running Functions from before #190, so
`registerPushToken`, `unregisterPushToken` and the sweep the app depends on
**did not exist**. Nothing in the repository could have said so. Earlier, #140's
closing note recorded the same shape: prod ran pre-coach Node-20 code for weeks,
found by reading `operator-expected.md` rather than by any check.

ADR-041 built the merged-vs-deployed comparison **for firestore rules only**, and
said so: the Rules API returns the released ruleset's *source text*, so the two
sides are directly comparable bytes. **Deployed Cloud Functions expose no
endpoint that returns the running source.** #166 was therefore filed
measurement-first, with "no sound comparison exists — here is the evidence,
closed" written into its acceptance criteria as a legitimate outcome.

## What was measured before anything was designed

Acceptance criterion 1. Everything below is read-only and was obtained from the
founder's local `firebase` CLI login — **no `gcloud`, no ADC, no service
account.**

### The instrument

`firebase functions:list --project <p> --json` returns, per function: `hash`,
`labels`, `source.storageSource.{bucket,object,generation}`, `entryPoint`,
`runtime`, `state`, `environmentVariables` and `secretEnvironmentVariables`.

This **replaces** the audit-log path S064 first found (the `CreateFunction`
AuditLog records reachable through `firebase functions:log`). Same label, far
cleaner instrument, and it does not depend on a deploy being recent enough to
still be in the log retention window.

**Candidate 3 of the issue body — the Cloud Functions v2 admin API — is
unreachable from this machine**, not refuted. `gcloud` is not installed and
there is no application-default credential. That is recorded as a gap in
*reach*, not as a finding about the API.

### The headline: the hash is derivable, and candidate 1 does NOT collapse into candidate 2

The issue asked whether `firebase-functions-hash` is "stable, documented, and
derivable locally from a checkout", and instructed that it be **measured, not
assumed**. It was measured — by reading the algorithm out of the installed
firebase-tools 15.22.4 rather than out of any documentation
(`lib/deploy/functions/cache/hash.js`, `lib/deploy/functions/cache/applyHash.js`,
`lib/deploy/functions/prepareFunctionsUpload.js`, `lib/fsAsync.js`):

```
sourceHash   = sha1( sorted([ sha1(bytes) for each packaged file ]).join("") )
envHash      = sha1( JSON.stringify(backend.environmentVariables) )
secretsHash  = sha1( JSON.stringify({ secretName: boundVersion, … }) )
endpointHash = sha1( [sourceHash, envHash, secretsHash].filter(truthy).join("") )
```

**`sourceHash` is a digest over a multiset of per-file digests — NOT over the
zip bytes.** That single fact is why the whole thing is reproducible: a zip
carries mtimes, entry order and compressor state, and would not be. A sorted
list of content hashes is content-addressed and machine-independent.

**All 13 production hashes were reproduced exactly, on the first attempt**,
including both outliers:

| | reproduced | deployed |
|---|---|---|
| the eleven with no secrets | `fb789b160cab7feb…` | `fb789b160cab7feb…` |
| `coachProxy` | `3e869aa35704dee9…` | `3e869aa35704dee9…` |
| `revenueCatWebhook` | `476a433c7d505562…` | `476a433c7d505562…` |

### D0 corollary — secret VERSIONS participate. Confirmed, not hypothesised

S064 observed that the two outliers are exactly the two functions consuming
secrets and recorded it as *"the obvious hypothesis — test it, do not assume
it."* It is now confirmed **by construction**: their hashes reproduce from
`{"LLM_API_KEY":"1"}` and `{"RC_WEBHOOK_TOKEN":"1"}` respectively, with the same
`sourceHash` and `envHash` as their eleven siblings.

The consequence S064 spelled out is therefore real: **rotating a secret to
version 2 moves the hash with no line of code changing.** A checker built
naively on the hash would report drift that is not drift. D4 is the response.

### The finding that shapes every decision below: prod was deployed from a dirty tree

The reproduction succeeded **only because this laptop's `functions/` still holds
the exact debris it held at deploy time.** The CLI packages the *directory*,
ignoring only `node_modules`, `.git`, `firebase-debug*.log` and
`.runtimeconfig.json`. It does not consult git.

```
packaged into the running production deployment : 275 files
  of which tracked by git                       : 116
  of which build output (functions/lib/)        :  97
  of which FOREIGN — gitignored, machine-local  :  62
        functions/coverage/**            (61 files, an lcov HTML report)
        functions/firestore-debug.log    ( 1 file)
```

Those 62 files are inert — they are not `require`d and do not change behaviour —
but they are **in the digest**. A clean checkout of `main` yields
`sourceHash = 15924a45b475b87f…`; production's is `b29f795fb34e29e6…`.

So the exact answer to #166's question is sharper than either outcome the issue
anticipated:

> The deployed code **is** comparable to `main`, exactly and cheaply. What is
> not currently comparable is *this particular deployment*, because it was made
> by hand from a working directory whose extra contents the repository cannot
> know.

That is a **process** gap, not a measurement gap — and it is the strongest
possible argument for the deploy lane the issue lists as candidate 2.

## Decision 1 — Ask the platform, through the CLI. No committed marker file, and no bespoke OAuth

`tool/ci/functions_drift.py` shells out to `firebase functions:list --json`.

Two rejected alternatives:

* **A committed `last-deployed.sha`.** ADR-041 D1's reasoning transfers intact:
  the lane whose omission *is* the bug is the same lane that would update the
  marker, so it fails in the reassuring direction.
* **Calling `cloudfunctions.googleapis.com` directly**, the way `rules_drift.py`
  calls the Rules API. Rejected: `rules_drift.py` had to, because firebase-tools
  has no `firestore:rules:get`. Here the CLI *does* expose exactly the right
  read, so re-implementing OAuth scope selection would add a second credential
  path to get an answer already on offer — and every one of those guesses is a
  chance to be silently wrong about a scope.

The CLI is a hard dependency of the check. That is honest: it is already a hard
dependency of `functions-rules`, and its absence is **exit 2**, never exit 0.

## Decision 2 — TWO verdicts in one tool, and the cheap one is the one that would have caught S063

The tool emits two independent findings and takes the worse:

1. **The set comparison.** Every function the local `functions/src/index.ts`
   barrel exports must be deployed, and nothing else may be. It needs no
   hashing, no build, and no env reconstruction. **This is the check whose
   absence cost S063 the push feature** — `registerPushToken` was simply not
   there — and it is red on `hayatiapp-dev` today (10 deployed vs 13 exported).
2. **The hash comparison.** Per-function, per D3.

They are reported separately because they fail for different reasons and have
different remedies. Collapsing them into one boolean would lose the diagnosis,
which is the same mistake as collapsing exit 1 into exit 2.

**The barrel parser fails closed.** `functions/src/index.ts` is a pure
re-export barrel; the parser accepts only `export { … } from '…'`. Any other
export form — `export *`, `export default`, `export const` — raises **exit 2**
rather than silently under-counting, because `export *` cannot be resolved
without following imports and a parser that quietly returns 12 of 13 names
reproduces this tool's own subject defect one level down. (That is ADR-041's
named-database `audit_releases` guard, applied to a different surface.)

## Decision 3 — The reference is the CLEAN packaged set, and the working tree is the diagnosis

This is the decision the dirty-tree finding forces.

The tool walks `functions/` exactly as `fsAsync.readdirRecursive` does, then
**partitions** the result against git:

| partition | how it is identified | in the reference set? |
|---|---|---|
| tracked | `git ls-files functions` | **yes** |
| build output | under `package.json`'s `main` directory (`lib/`) | **yes** |
| foreign | everything else | **no** |

* **`referenceHash`** — computed over tracked ∪ build output. This is what the
  CLI *would* package from a clean checkout of this ref plus `npm ci && npm run
  build`, which is precisely what a CI runner or a deploy lane has. It is
  machine-independent, and it is the verdict.
* **`workingTreeHash`** — computed over the whole walk, foreign files included.
  It is **not** the verdict. It exists so that when the reference mismatches,
  the tool can distinguish the two utterly different causes:

```
  DRIFT — and the working tree does not match either
        → production is running code that is not this ref.  Alarming.

  DRIFT — but the working tree DOES match
        → production is running this ref's code, deployed by hand from a
          directory carrying N foreign files.  A process gap.
```

Without that split the tool prints "DRIFT" today and the reader has no way to
tell an emergency from a housekeeping item. **A report that cannot name its own
finding's cause is the next reader's wasted hour** (ADR-041's own words about
its empty-diff case).

**The build-output directory is read from `package.json`'s `main`, never
hardcoded.** Same reason `app_icons.py` reads the iOS target list out of
`Contents.json` (S064, lesson 66): a hardcoded `lib/` and a moved build output
would drift apart silently, and the tool would then be computing a reference
over a set that is missing every compiled file — reporting drift forever, for a
reason nothing in its output would name.

### Stated limitation, not papered over

`referenceHash` assumes `functions/lib/` is a **current, clean** build of
`functions/src/`. `tsc` does not delete outputs for sources that were removed,
so a long-lived laptop checkout can carry stale `lib/` files that a CI runner
would not. The tool cannot detect this and does not pretend to; on CI — the only
place its exit code gates anything — `lib/` is built fresh into an empty
checkout, so the assumption holds where it matters.

## Decision 4 — Reconstruct `envHash` and `secretsHash` from the DEPLOYMENT, and say loudly what that puts out of contract

`endpointHash` folds three components into one sha1, and it is not invertible.
To verify the one component the repository can speak for — the **source** — the
other two must be supplied.

* **`secretsHash`** is built from the deployed function's own
  `secretEnvironmentVariables` (`{secret: version}`). The repository cannot know
  which secret *version* a past deploy bound, and guessing `"1"` would be a
  fabricated input that produces a false red the first time anything rotates
  (D0).
* **`envHash`** is built from `functions/.env*` per the CLI's own precedence,
  plus `FIREBASE_CONFIG` taken **verbatim from the deployed function's own
  environment** and `GCLOUD_PROJECT` set to the project id. `FIREBASE_CONFIG`
  carries the project's default storage bucket, which is a remote fact; the
  deployed value *is* the string the CLI hashed, so taking it is a
  reconstruction, not a guess.

**What this deliberately puts out of contract, named rather than absorbed:**
this check does **not** detect a secret rotation, nor a change to environment
variables. Its subject is the **source**. Taking two components from the
deployed side cannot weaken the third — a different source still yields a
different combined sha1 — it only bounds what the check covers. An unnamed
limitation is the thing that makes a green check a false claim; a named one is a
scope.

**And it fails closed on reconstruction it cannot perform**: a deployed function
with no readable `FIREBASE_CONFIG`, or a `functions/.env*` file that the CLI
would read but git does not track, is **exit 2** — because in both cases the
tool would be comparing against an input it invented.

## Decision 5 — The exit taxonomy is ADR-041's, unchanged

```
0  every deployed function is a clean build of this ref, and the deployed set
   is exactly the exported set
1  DRIFT — it looked, and they differ (wrong source, or a missing/extra
   function). This is the finding.
2  COULD NOT MEASURE — no CLI, no credential, an unparseable listing, an
   unbuilt functions/lib, a barrel this parser refuses, an env component it
   could not reconstruct. NEVER 0.
```

The difference between 1 and 2 is the whole point and is restated here rather
than cross-referenced, because collapsing them is exactly the defect
`functions-rules` had.

## Decision 6 — It runs where `rules-drift` runs, and it is SKIPPED the same way

`functions-drift-preflight` publishes a boolean; `functions-drift` gates on it.
Post-merge on `main` only, never on a PR, and `main` only even for dispatches —
ADR-041 D6's reasoning transfers without amendment: drift is a property of
`main` versus the projects, so a PR going red for last week's undeployed
Functions would redden a build for something its author neither caused nor can
fix (prod Functions deploys are on the never-without-asking list). A job-level
`if:` cannot read `secrets`, and a job whose every step skipped reports **green**
— which is this tool's own subject defect wearing a new hat.

So: **MEASURED (green or red) or visibly SKIPPED. No third outcome** (lesson 77).

The hermetic self-tests are a different matter and run in `quality` on every PR,
beside the other pre-`pub get` self-tests — they need no network, no CLI and no
credential.

## Decision 7 — The credential CI would need, stated precisely

#166 asks whether the question is answerable "with a credential CI could hold".
**Yes.** `firebase functions:list` authenticates through
`GOOGLE_APPLICATION_CREDENTIALS`, so a service-account JSON with
**`roles/cloudfunctions.viewer`** (read-only, on both projects) is sufficient,
and is the direct sibling of the `roles/firebaserules.viewer` account operator
item **2(e)(iv)** already asks for. It is folded into that item rather than given
a new number, so the founder performs one task and arms two checks.

**Read-only by construction, for ADR-041 D4's reason**: this tool must never be
able to cause the drift it reports.

Until that secret exists the job is **SKIPPED**, visibly, on every run — exactly
like `rules-drift`, and for the same reason.

## Decision 8 — This ADR builds the check, NOT the deploy lane

`deploy-rules.yml` and `deploy-site.yml` exist; Functions have no deploy
workflow, so deployment is a manual step nothing tracks. That is the other half
of the problem and it is deliberately **not** in this diff (session-rules §2:
drive-by scope is scope creep wearing a helmet). It is re-filed.

The finding above is its strongest justification: today the check must reason
about foreign files at all *only* because deploys are hand-made. A dispatch-only
`deploy-functions.yml` on a clean checkout would make `referenceHash` and
`workingTreeHash` identical by construction, and D3's whole diagnostic branch
would become dead code — the good kind.

## Decision 9 — The derivation is pinned to a CLI version, and drifts loudly

The algorithm was read out of firebase-tools **15.22.4**. If a future major
rewrites it, this tool would compute confident nonsense. So it reads the
installed CLI's version and **fails closed (exit 2) on a different major**,
printing the four source paths the derivation came from.

A minor/patch difference prints a note and proceeds. It is not a `::warning::`:
architecture §9 forbids one on a green build, and ADR-041 D6.1's exception was
argued for a case this is not.

**A limitation that cannot be engineered away and is therefore stated:** the
tool verifies against the algorithm of the CLI installed *now*, while the hash it
compares against was stamped by whichever CLI performed the deploy. A deploy made
by a version that computed hashes differently would read as drift. The remedy is
a redeploy, and the deploy lane of D8 removes the ambiguity entirely.

## Consequences

* #166's acceptance 1 is answered exhaustively and its acceptance **2** is taken
  — a sound comparison exists. Acceptance 3 (close it as unanswerable) is
  **not** the outcome, but the honest-gap posture it protected is preserved in
  D4's named out-of-contract list and in D9's stated limitation.
* `hayatiapp-dev` is the live positive case: the set comparison is **red** there
  today, for a real reason.
* Production reads as drift until it is redeployed from a clean tree — correctly.
  The redeploy is a **§7 ask** and is not performed by this session.
* The tool is a strictly local instrument until operator 2(e)(iv) lands, at
  which point one secret arms both drift checks.
