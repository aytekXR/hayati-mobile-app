# ADR-034: Advisories are gated on what a change INTRODUCES, not on what the tree contains

- **Status:** Accepted
- **Date:** 2026-07-27 (Session 053)
- **Deciders:** session agent (no founder input needed for the code decision; one **operator** action falls out of it — see D8)
- **Related:** issue **#131** (this ADR closes it), **ADR-024** (the notifier with *no vote on the build*, and the lesson this decision leans on hardest), **ADR-025 D8** (a declaration nothing enforces is discipline, not a gate — the reason there is no baseline file), **ADR-030** (Node 22) and **ADR-031** (`firebase-admin` v14 — the pin `npm audit` wants to undo), **#140** (the merged-vs-deployed gap, whose shape recurs here), `docs/architecture.md` §9, `docs/test-suite.md` §2

## Context

`functions/` reported **14 vulnerabilities (7 moderate, 7 high)**, seven of them
high with `fixAvailable: true`, and nothing in CI had ever looked.

### The headline count is not the number of problems

`npm audit` emits one `vulnerabilities` entry per **affected package**, so one
advisory deep in a chain produces one real entry plus a *"depends on a
vulnerable version of X"* wrapper for every package above it. Keyed on GHSA id,
which is the only stable identifier here:

| | npm's headline | Distinct advisories |
|---|---|---|
| before | 14 (7 moderate, 7 high) | **4** — 3 high + 1 moderate |
| after `npm audit fix` | 12 (7 moderate, 5 high) | **2** — 1 high + 1 moderate |

The three high advisories were `fast-xml-parser`, `postcss` and
`brace-expansion`; `glob`, `google-gax`, `minimatch` and `rimraf` were wrappers.
All seven moderates are **one** advisory, in `uuid`.

**Issue #131's own title ("7 high-severity npm advisories") counts wrappers**, and
so did the first draft of this session's design brief. Recorded because the
inflated number is what makes an audit report feel urgent and unactionable at
the same time.

### `npm audit fix` cleared two of three, not seven of seven

The issue said npm "claims all seven are non-breaking." Verified rather than
trusted (acceptance criterion 1): **false**. It moved `fast-xml-parser`
5.9.3→5.10.1, `postcss` 8.5.16→8.5.23, the top-level `brace-expansion`
5.0.7→5.0.8 and `nanoid` 3.3.15→3.3.16, and pulled in three sub-packages that
`fast-xml-parser@5.10.1` decomposed into upstream (`@nodable/entities`,
`is-unsafe`, `xml-naming`). Those three were checked against the registry rather
than assumed: all are published by `amitgupta <amitgupta.gwl@gmail.com>`,
`fast-xml-parser`'s own maintainer, and `xml-naming` was already in the tree
before this change.

`npm ci` — the command CI actually runs, not the one that produced the tree —
accepts the result (exit 0, verified in an isolated copy). That check exists
because S044 saw `npm install` succeed and `npm ci` then refuse the same tree.

## Decision 1 — The one remaining high advisory cannot be fixed, and that was measured

The five packages npm still reports high are **one chain with one vulnerable
leaf**:

```
firebase-admin@14.2.0 -> @google-cloud/firestore@8.7.0 -> google-gax@5.0.8
  -> rimraf@5.0.10 -> glob@10.5.0 -> minimatch@9.0.9 -> brace-expansion@2.1.2
```

The leaf is **GHSA-mh99-v99m-4gvg**, range `<=5.0.7`. There is no patched 2.x
line — the only clean version published is **5.0.8**, three majors above the
`^2.0.2` that `minimatch@9.0.9` requires.

npm nonetheless reports `fixAvailable: true`. **It is wrong, and an override
would convert a DoS advisory into a hard runtime failure inside Firestore's own
dependency chain.** Measured in an isolated tree, with a control that passes:

```
CONTROL    minimatch@9.0.9 + natural brace-expansion 2.1.2
           minimatch("abc","a{b,x}c") = true          <- control PASSES

TREATMENT  minimatch@9.0.9 + overrides brace-expansion@5.0.8
           BREAKS AT RUNTIME: (0 , brace_expansion_1.default) is not a function
```

Cause: `brace-expansion@5.0.8` is `"type": "module"` and its CommonJS entry
exports an **object** (`{EXPANSION_MAX, EXPANSION_MAX_LENGTH, expand}`), while
`minimatch@9` does `const expand = require('brace-expansion')` and calls it.

**And the chain is never loaded.** `google-gax@5.0.8` *declares* `rimraf: ^5.0.1`
and never imports it: across the shipped package the string `rimraf` appears in
exactly two files, `google-gax/package.json` and `@grpc/proto-loader/package.json`
— i.e. only in dependency declarations, never in any shipped `.js` — and
`build/src` contains no computed `require()` that could hide it.

## Decision 2 — The downgrade is refused; the `uuid` override works and is still declined

The moderate is **GHSA-w5hq-g745-h8pq** (`uuid <11.1.1`, missing buffer bounds
check in **v3/v5/v6 when `buf` is provided**), reached via
`firebase-admin -> @google-cloud/storage@7.21.0 -> gaxios|teeny-request -> uuid@9.0.1`.

npm's only offer is `firebase-admin@10.3.0`, which would undo ADR-031 and
conflict with ADR-030. **Refused** (acceptance criterion 2), and `--force` was
never run.

**There is no forward fix either:** `firebase-admin@14.2.0` *is* the latest,
`@google-cloud/firestore@8.7.0` is the latest and pins `google-gax ^5.0.1`, and
`google-gax@5.0.8` is the latest stable (5.1.x/6.x are `-rc`/`-experimental`).

An `overrides: {"uuid": "^11.1.1"}` **does** work — measured, gaxios still loads
and `uuid.v4()` still returns. It is declined anyway, and the reason is that it
buys nothing real while diverging from the dependency combination Google tests:

1. `@google-cloud/storage` is an **optionalDependency**, loaded lazily on
   `admin.storage()`. This codebase never calls it — the only `firebase-admin`
   imports in `functions/src` are `firestore` (22), `auth` (5), `messaging` (1)
   and `app` (1).
2. The only uuid API any consumer calls is **`v4`** (one site, in `teeny-request`).
   The advisory is about v3/v5/v6.
3. Swept across all **293** packages in the `--omit=dev` tree: **zero** calls to
   `uuid.v3/v5/v6`.

Both advisories are therefore recorded as open and unreachable rather than
papered over. Under project-rules #9 the ADR record *is* the documentation of a
compromise; what #9 forbids is leaving it **silent**.

## Decision 3 — CI gates on the DELTA, not on the tree's absolute advisory set

This is the answer to acceptance criterion 3, and it is deliberately not
`npm audit --audit-level=high`.

**The asymmetry that decides it:** `npm audit`'s absolute output changes for
reasons **no commit caused**. A third party publishes an advisory against a
lockfile nobody touched and the build turns red — for something the session did
not do, cannot fix that hour, and which (as D1 and D2 show) may not be reachable
at all. ADR-024 chose a notifier with no vote on the build precisely to avoid
manufacturing that kind of red; the same argument transfers, and reaching for
the stricter-looking option here would be adding a gate because gates feel
responsible.

So `tool/ci/npm_audit_delta.py` compares **two points in time** instead of one
threshold: the **base** and **head** lockfiles, audited in the *same run*
against the *same registry*, moments apart.

**The property that makes this a guarantee rather than a nuisance falls out of
the symmetry: a newly-published advisory appears on BOTH sides and cancels.**
The check is structurally incapable of firing for a publication event. It can
fail only when the diff itself brings a new advisory in — which is exactly the
case a human can act on, in the PR that caused it.

Mechanically it runs in `functions-rules` (which already has Node) *before*
`npm ci`, because `npm audit --package-lock-only` needs no `node_modules` and
no `package.json` — only the lockfile bytes, which is what makes auditing a
historical revision cheap. The job's checkout gains `fetch-depth: 0` for the
same reason the `quality` job already carries it.

**Threshold: `high` and above, introduced only.** An introduced *moderate* is
printed but does not fail. That line is a judgement, not a law; it is a flag.

## Decision 4 — What is deliberately NOT built, and why each was rejected

- **No committed baseline file.** It was proposed and the design review killed
  it correctly: a file listing "accepted" advisories is **ADR-025 D8's shape** —
  a declaration nothing enforces, which rots quietly and then lies. Git history
  is already the baseline, and it cannot go stale.
- **No cron.** A scheduled sweep was the design's other half until the review
  produced the fact that kills it: **GitHub disables scheduled workflows after
  60 days without repository activity.** A cron intended to watch a quiet
  period switches *itself* off during exactly that quiet period. Worse than no
  cron, because it looks like coverage.
- **No Slack routing.** `tool/ci/slack_notify.sh` builds a fixed pass/fail
  payload with no field for advisory content, and ADR-024 D2's noise policy
  would suppress a successful scheduled run outright. Wiring this through it
  would have produced either silence or a weekly *"12 vulnerabilities"* message
  — the trained-to-ignore outcome this ADR exists to avoid.
- **No `npm audit` in `release.yml`.** The release lane's gate is signing
  (ADR-021/032); adding a second, differently-shaped advisory check there would
  restate this one from a worse position.

## Decision 5 — Keyed on GHSA id, and fail-closed on its own failure

The tool collapses npm's per-package entries to distinct advisories (Context
above). A report that says *"2 advisories"* is actionable; *"12 vulnerabilities"*
is not, and the difference is entirely presentational noise.

If the audit cannot be run, or the base lockfile cannot be read, the tool exits
**2** and says why — never 0. A gate that passes when it could not measure is
the `store_metadata` failure shape this repo has already paid for twice (S047)
and the shape of #140. An unknown severity string ranks **above** `critical`
for the same reason: a vocabulary npm adds later must not slip under a
threshold.

**Which base ref is used is policy, and it lives in the tool, not the YAML.**
The workflow step passes *candidates* and decides nothing; `resolve_base_ref`
takes the first git can resolve:

| Event | Candidate | Why |
|---|---|---|
| `pull_request` | `github.event.pull_request.base.sha` | checkout gives the *merge* ref, so head-vs-base is exactly "what merging this PR introduces" |
| `push` | `github.event.before` | the previous tip; all-zeros on a first/force-push, treated as a **non-candidate** rather than an error |
| `workflow_dispatch`, anything else | `FETCH_HEAD` (a depth-1 fetch of `main`) | so a dispatched branch run is a real check rather than a silent no-op |

This ordering sat in an inline shell branch in the first version of this diff,
and the build-diff review was right that it was wrong to leave it there — not
because the shell was buggy, but because **ADR-024 D1 already settled this**:
outcome logic a self-test cannot see is unprotected. Moved into the tool, it is
now covered by `test_base_ref_resolution_order`.

**The one honest skip:** when *no* candidate resolves, there is genuinely
nothing to compare, so the tool emits a `::notice::` and exits 0. That is a real
hole, it is narrow, and it is named here rather than left for someone to
discover. It is also **not reachable by misconfiguration**: a missing lockfile
is checked *before* base resolution and exits 2, because resolving first would
let a repo with no base ref skip past a wrong `--lockfile` path and report
success — the silent-pass shape this tool exists to refuse. That ordering was
itself a bug in the first version, caught by this suite rather than by review.

## Decision 6 — The mutation check, in both directions and against real npm

Acceptance criterion 4 asks for proof the instrument goes red on a **seeded**
advisory, not merely that it runs.

| Check | Result |
|---|---|
| Seed `minimist@1.2.0` into a real lockfile; real npm, real registry | **exit 1**, `GHSA-xvch-5gv4-984h` named as blocking |
| This branch's own real lockfile change vs `main` | **exit 0**, 2 resolved (`fast-xml-parser`, `postcss`), 0 introduced |
| Same advisory present on base AND head (the publication event) | introduces nothing, blocks nothing |
| Introduced `moderate` at threshold `high` / at threshold `moderate` | does not block / **does** block |
| `npm audit` output with no `vulnerabilities` key, or unparseable | raises, exits 2 |
| Unchanged lockfile | exits 0, and the test asserts **npm is never invoked** |
| Changed lockfile | the test asserts npm **is** invoked, so a short-circuit could not pass |
| No candidate base ref resolves | exits 0 **and** emits the skip notice — asserted on the *output*, because exit code alone cannot tell "skipped" from "compared and found nothing" |
| A candidate *does* resolve | reaches the comparison and does **not** emit the skip notice |
| Missing lockfile | exits 2 even when no base ref resolves |
| Two URL-less advisories on one package | stay distinct (the fallback key is title-derived, not package-derived) |

The hermetic half (14 self-tests, `tool/ci/npm_audit_delta_test.py`) runs in
`quality` with the other tool self-tests — no npm, no network, no emulator. The
real-npm half is recorded here because it cannot run in that job.

**Bound, stated honestly:** the cancel-out property is proven against synthetic
payloads, not against an actual advisory publication — that event cannot be
manufactured. What the real-npm runs prove is detection and the absence of false
positives on a genuine change.

## Decision 7 — The other half of the problem is Dependabot, and it is an operator action

A lockfile-delta check covers "this change introduced an advisory." It does
**not** cover "an advisory was published against a lockfile nobody touched" —
the case the rejected cron was aimed at.

That case has a platform-native answer this repo is simply not using.
**Dependabot alerts are disabled** (`gh api …/dependabot/alerts` → *"Dependabot
alerts are disabled for this repository"*; `automated-security-fixes` →
`{"enabled":false}`; no `.github/dependabot.yml`), and the repo is **public**, so
they are free. They cannot rot, cannot auto-disable after 60 days, and watch
**every** ecosystem here — `functions/` npm, `app/` pub, the `Gemfile.lock`, and
GitHub Actions versions — rather than the one lockfile this tool reads.

Enabling them changes repository settings and starts mailing a real person, so
it is the founder's call and not a session's. Recorded in
`docs/operator-expected.md`. **Alerts, not automated security-fix PRs** — the
latter would open PRs proposing exactly the `firebase-admin@10.3.0` downgrade
D2 refuses.

## Decision 8 — "Unreachable" is a snapshot, and is not what the gate depends on

D1 and D2 lean on reachability, and the completeness critic was right that a
static sweep proves *today*, not *always*: `google-gax` could import `rimraf` in
a patch release, and `admin.storage()` is one call away from loading the uuid
chain.

This is survivable **because nothing enforcing depends on it.** Reachability is
the reason those two advisories are *accepted as open* — a judgement recorded in
this ADR, re-derivable in one command. The gate itself keys on introduction, not
reachability, so a future change that pulls the storage path in would arrive as
a lockfile change and be measured then. No invariant test was added to pin
`rimraf`'s absence: it would assert a third party's internal structure, which is
theirs to change and not a contract we can hold them to.

## Pre-code review outcome (2026-07-27, the 28th consecutive pre-code pass)

Five lenses × two independent verifiers (a refuting skeptic + a governing-docs
adjudicator) plus a completeness critic; 20 agents, 0 errors, 27 distinct
findings. What it changed:

- **It killed the baseline file and the cron** — both were in the proposal put
  to it (D4). The 60-day auto-disable fact came from the review; the design
  would have shipped a cron that turns itself off.
- **It killed the Slack routing** on the notifier's actual payload shape.
- **The completeness critic proposed the lockfile-change trigger** that became
  D3, which none of the five lenses reached.
- **The measurement-skeptic lens returned zero findings** after 79 independent
  tool calls re-checking the rimraf sweep, dynamic-require patterns, the uuid
  reachability claim and the minimatch module shape. Per S041's addendum an
  empty verdict is *unverified* until you look — its transcript was read, it
  did the work, and the measurements survive.
- **What the panel missed, all six of them: Dependabot.** It was found by
  querying the platform instead of reasoning about options (D7). Addendum:
  N expert sweeps can all miss the same thing.
- Two findings were **overridden**: that leaving advisories unfixed violates
  project-rules #9 (the ADR record *is* the documentation #9 asks for), and that
  the gate should carry an invariant test pinning `rimraf`'s absence (D8).

## Build-diff review outcome (2026-07-28)

Same shape, run on the built diff: five lenses × two verifiers + a completeness
critic; 24 agents, 0 errors, 9 findings, **all nine verified** (none dropped).
Three surfaced, and two were real defects in code already committed:

- **The base-ref logic was policy sitting in YAML** — found via the observation
  that a `workflow_dispatch` run has neither `pull_request.base.sha` nor
  `github.event.before`, so it skipped with a notice that misleadingly blamed
  "first push or force-push". Fixed by moving resolution into the tool with a
  `main` fallback (D5), which makes a dispatched run a real check.
- **A surviving mutant.** The reviewer copied the tool to a temp dir, changed
  the URL-less fallback key from title-derived to package-derived, and showed
  the suite still passed — then demonstrated the consequence: two advisories on
  one package collapse into one. Closed, and the fix was re-verified by
  re-running the mutation (control passes, mutant now fails two checks).
- **`operator-expected.md` still listed #131 as open** — both verifiers agreed.
  Corrected in the session-close refresh.

**Fixing the first finding introduced a second bug, which the suite caught, not
the reviewers:** moving base resolution ahead of the lockfile-existence check
let a missing lockfile *skip* instead of failing closed. The order is now
load-bearing and commented as such.

The **ADR-claim auditor returned zero findings** after checking every count,
path and exit code in this document — independently reproducing the 293-package
sweep, the import counts and the test registration. Six findings were killed by
both verifiers, including a *blocking* claim that a PR checkout cannot see its
base commit (refuted: `fetch-depth: 0` fetches the base branch too) and a claim
that `test_publication_event_cancels_out` is vacuous (refuted: it is paired with
the wrapper-collapse assertion, so mutating `distinct_advisories` to return `{}`
is caught).

## Consequences

- A PR that introduces a high or critical advisory into `functions/` now fails
  `functions-rules`, a required check, with the GHSA id named.
- A PR that does not touch `functions/package-lock.json` costs one string
  comparison and no network.
- A third-party advisory publication **cannot** redden this repo. It is also
  therefore invisible to CI — deliberately, with D7 as the answer.
- The two open advisories are accepted, recorded, and reachable-by-nothing as
  measured today. If either becomes reachable, the event that makes it so will
  be a dependency change, which is the event this gate watches.
- `npm audit` in `functions/` will continue to print **12 vulnerabilities**.
  That number is expected and is not a regression; it is two advisories and ten
  wrappers.
