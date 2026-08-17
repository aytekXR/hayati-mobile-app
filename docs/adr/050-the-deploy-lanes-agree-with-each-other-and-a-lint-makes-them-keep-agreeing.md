# ADR-050: three dispatch-only deploy lanes, three different safety postures — and the two that were weakest were the two that shipped first

- **Status:** Accepted
- **Date:** 2026-08-17 (Session 072)
- **Deciders:** session agent (no operator dependency added or removed; all three lanes remain unarmed until operator 2(e)(iii))
- **Related:** **ADR-041 D5** (`deploy-rules.yml`, the dispatch-only + typed-prod shape this amends), **ADR-048 D1/D10** (`deploy-functions.yml`, the ref pin and the concurrency group this generalizes), **ADR-023** (the legal texts `deploy-site.yml` publishes, byte-synced to the app), **ADR-032** (`release_lane_lint.dart`, the source-sentinel mold), issue **#223**

## Context — the drift is between the lanes, not inside any one of them

Three workflows deploy something a session must not deploy casually:

| lane | since | ref pin | `concurrency` |
|---|---|---|---|
| `deploy-site.yml` | S040 | **none** | **none** |
| `deploy-rules.yml` | S058 (ADR-041) | **none** | **none** |
| `deploy-functions.yml` | S070 (ADR-048) | prod → `main` | per project, no-cancel |

Each was modelled on the one before it, and the newest is the only one that
carries either guard. **The oldest lane guards the least and publishes the most
irreversible thing.** That is not a coincidence: each lane was reviewed against
the state of the art *at the time it was written*, and nothing ever went back.

`deploy-functions.yml` closed both for itself and #223 was filed rather than
folded into that diff — changing an existing lane's safety posture deserves its
own decision, and `deploy-rules.yml` is ADR-041 D5's artifact.

**None of the three has ever executed** — measured 2026-08-17, `gh run list`
returns nothing for all three. All are unarmed until `FIREBASE_SERVICE_ACCOUNT`
(operator 2(e)(iii)). ⚠️ **That is not the same as "none of them has ever
happened":** `https://ikimiz.web.app/i/…` answers **200** today, so the live site
was published by hand. The first real dispatch of `deploy-site.yml` will
therefore *overwrite* a hand-deployed site rather than create one — worth knowing
before the first dispatch, and exactly the class of inherited premise this repo
re-measures rather than assumes.

So this is a fix to make **before** the first real dispatch rather than a live
exposure — and, ⚠️ **it also means this session cannot prove any of it by running
it.** What can be proven is stated in Decision 4; what cannot is stated there too.

## Decision 1 — `deploy-rules.yml`: prod is pinned to `refs/heads/main`

Exactly ADR-048 D1's guard, for exactly its argument, one target over:

```yaml
- name: prod deploys only from main
  if: ${{ inputs.project == 'prod' && github.ref != 'refs/heads/main' }}
```

A `workflow_dispatch` runs against whatever ref the dispatcher picks, and the
typed confirmation does not help: **it confirms which PROJECT, never which
CODE.** `gh workflow run deploy-rules.yml --ref some-branch -f project=prod -f
confirm_prod=hayatiapp-prod` deploys a branch's `firestore.rules` to production
today, and the operator typing the id would have no way to know.

**And the second-order damage is the same shape as the Functions lane's.**
`rules-drift` runs post-merge on `main` and compares the released ruleset against
`main`. A branch deploy therefore *manufactures* drift: the next push to `main`
goes red, **correctly** reporting that production serves something that is not
this ref, and the next reader hunts a discrepancy a dispatch box created on
purpose. ADR-041 D6 argues at length about not reddening a build for things a
reader cannot act on; this is that argument reached from the other end.

Checked **before** the typed confirmation, like ADR-048 D1: a prod dispatch from
a branch is wrong for a reason that has nothing to do with whether the operator
typed the id correctly, and failing on the cheaper, more specific reason is what
sends the reader to the right fix.

**Dev stays free on every lane, deliberately.** Exercising a branch on dev is
what dev is for (`session-context.md` §7), and an asymmetry that is stated is not
an inconsistency.

## Decision 2 — `deploy-site.yml`: `live` is pinned to `main` too, and the issue's own reasoning was too weak

#223 filed this half as *"arguably weaker: the site is regenerated from
`docs/legal/` at deploy time and there is no drift checker to confuse"*. Both
clauses are true and the conclusion does not follow. **The case here is
stronger, for a reason neither clause touches.**

What that lane publishes is the **privacy policy and terms** — the same
`docs/legal/*.md` that ADR-023 byte-syncs into `app/assets/legal/` under a drift
test, precisely so *the app and the repo can never disagree about what the policy
says*. Publishing from a branch puts a **third** version into the world: the
public page Apple's listing points at, saying something the app on the user's
phone does not.

That is the exact failure ADR-023's sync test exists to prevent, routed around
the test rather than through it. And it is worse than rules drift in one respect
that matters: a rules deploy is corrected by another deploy, while a published
legal text has already been fetched — by Apple, by search engines, by whoever
read it.

**One qualification, measured rather than assumed.** `invite_only: true` is
deliberately allowed on `live` — it publishes the invite surface and the Apple
app-site-association and **no legal pages at all**, which is what makes a shared
invite link resolve today while the legal blanks are still open. So the argument
above does not describe *every* live publish. It does not need to: a branch's
`apple-app-site-association` is still the file Apple fetches to decide whether an
invite link opens the app, and getting that from an unmerged ref is the same
class of mistake with a different blast radius.

So `channel: live` requires `refs/heads/main`. **`preview` stays free**, which is
the same dev/prod asymmetry under different names and is what the preview channel
exists for.

**Not adopted: making `live` require a typed confirmation too.** The lane already
gates `live` on a channel choice plus a placeholder refusal that only `preview`
can override, and adding a third ceremony to a lane nobody has run yet is
designing against an operator's patience with no incident behind it. If a
mis-click on `live` ever happens, that is the decision to revisit, and this
paragraph is where to start.

## Decision 3 — All three lanes declare `concurrency`, per target, never cancelling

```yaml
concurrency:
  group: <lane>-<target>
  cancel-in-progress: false
```

Two overlapping dispatches against one target are two clients racing over one
artifact. **`cancel-in-progress: false` is the load-bearing half**: a deploy
killed mid-flight is strictly worse than one that waits, and for Functions
ADR-048 D10 already names why — the partially-applied state the read-back exists
to catch. For rules the window is one API call and the race is narrower, but the
loser still silently wins, and "narrow" is not a property anyone re-measures.

Grouped **per target** — project for rules and functions, channel for the site —
because a dev deploy has no reason to queue behind a prod one.
`testflight-testers.yml`, `appid-capabilities.yml`, `appstore-screenshots.yml`
and `release.yml` already set this shape; these three were the exceptions.

**`github.event.inputs.<name>`, never the bare `inputs` context**, in the
`concurrency` block only. Both resolve at workflow level, and ADR-048 D10 chose
the explicit form for a reason worth restating because it is the kind of detail
that gets "tidied": workflow-level `concurrency` is evaluated **before any job
starts**, so a bad expression there is a **parse** error — and a dispatch-only
lane's first real parse is someone's first dispatch, on a live project, by a
founder. This is not the place to be 85% sure.

## Decision 4 — A lint, because the defect is a lane FORGETTING what its siblings know

Two fixes to two files close #223. They do nothing about the third instance of
the same defect, which is how this repo got here: three lanes, each modelled on
the last, each reviewed once, and the guards only ever added forward.

So `tool/deploy_lane_lint.dart`, on the `release_lane_lint.dart` mold — a
credential-free, dependency-free `dart:io` source sentinel that runs in the
`quality` job before any `pub get`. It asserts, **for every dispatch-only deploy
lane**:

1. the lane declares `concurrency` with an explicit `cancel-in-progress: false`;
2. its group **interpolates** (not a constant — a constant makes dev queue behind
   prod, a new bug rather than a weaker guard) and does so via
   `github.event.inputs.` (D3's parse-risk argument), **keyed on the input that
   selects the target** — a group keyed on some *other* input interpolates
   faithfully and serializes the wrong pairs;
3. a lane whose inputs can select a production target carries a **ref guard**
   whose single `if:` expression asserts **`inputs.<selector> == '<prod>'` and
   `github.ref != 'refs/heads/main'`** — ⚠️ **operators, not just operands.** A
   scan for the four *words* also matches `inputs.project != 'prod' && github.ref
   != 'refs/heads/main'`, which blocks dev from a branch and lets prod through
   from anywhere: the guard inverted into precisely the hole it was added to
   close, passing a lint that only looked for vocabulary. *(Found by the design
   review; the first implementation had exactly this defect, and the test that
   now covers it was confirmed to fail against that form.)*
4. both halves live in **one** expression — two steps each satisfying half guard
   nothing, because the conditions never co-occur;
5. the guard step appears **before** the step that deploys, located by an explicit
   list of publish commands rather than by guessing which step is "the deploy". A
   guard placed after it is not a weaker guard but **decoration**: what it exists
   to prevent has already happened, and the run still reddens, so it reads as
   working. A lane whose publish command the list does not know is **reported**,
   never skipped;
6. and **comments are stripped before any of this is scanned.** Every lane now
   carries a header quoting the very expression rules 3–4 look for, so a lint
   satisfied by prose would go green on the remediation note somebody leaves
   behind when they *delete* the guard — the worst possible moment
   (`release_lane_lint.dart`'s "scan CODE, not commentary", same reasoning).

**The lane list is derived, not hand-maintained.** The lint globs
`.github/workflows/deploy-*.yml`, so a fourth deploy lane is guarded the day it
is added rather than the day someone remembers this ADR. A derived list that
resolves to nothing is itself a failure (`exit 64`, "could not check"), because a
sentinel over an empty set is the greenest thing in this repo and measures
nothing.

**What this proves and what it cannot.** It proves the guards are *present and
well-formed in the source*. It cannot prove GitHub honours them, because that
needs a dispatch, which needs the secret, which is operator 2(e)(iii). ⚠️ **Nobody
should read a green lint as "the guard was tested."** `actionlint` is not
installed on this machine and is not being added for one rule; the honest
statement of coverage is this paragraph, and it belongs in the ADR rather than in
a session's summary where it would be lost.

## Decision 5 — The documents that change in the SAME commit (project rule #8)

| document | what changes |
|---|---|
| `.github/workflows/deploy-rules.yml` | the ref pin, the concurrency block, and the comment explaining why the typed confirmation does not cover this |
| `.github/workflows/deploy-site.yml` | the same pair, with D2's argument at the guard |
| `.github/workflows/ci.yml` | the lint + its self-tests in `quality`, pre-`pub get`, with the ⚠️ about what green here does and does not mean |
| `docs/test-suite.md` | the lint's rules, its mutants, and the honest bound on its coverage |
| `docs/architecture.md` §9 | the deploy-lane row, if it enumerates the lanes' guards |

**What deliberately does NOT change:** `deploy-functions.yml` (it already carries
both guards and is the model), the read-back asymmetry in Consequences, and
`operator-expected.md` — this adds no operator dependency and removes none.

## Consequences

**What this buys.** The three lanes stop disagreeing, the two most dangerous
dispatch mistakes become impossible rather than merely undocumented, and the
*next* lane inherits both guards from a test instead of from whoever remembers to
copy them.

**What it costs.** A prod rules deploy and a live site publish must now be
dispatched from `main`. That is one extra step in a flow that already requires
typing a project id, and it is a step in the direction the operator already
wanted — nobody dispatching prod means "from this branch I happen to have open".

**What stays open.** All three lanes remain **unarmed**; none has ever run.
`deploy-rules.yml`'s read-back still runs only on success while
`deploy-functions.yml`'s runs `if: always()`, and that asymmetry is **correct and
deliberate** (ADR-048 D4): a rules release is one atomic call, so there is no
partially-applied state to measure. It is named here so a future reader does not
"fix" the two lanes into agreement on the one axis where they should differ.
