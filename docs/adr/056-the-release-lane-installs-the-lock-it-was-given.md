# ADR-056: the release lane installs the lock it was given, and the lock is verified against itself

- **Status:** Accepted
- **Date:** 2026-08-18 (Session 080)
- **Deciders:** session agent (no operator dependency for the change; its final confirmation rides the founder's next release)
- **Related:** **ADR-021 D6** / issue **#120** (the lock's absence, since discharged), **ADR-032** (manual signing via `match`), **ADR-029 D2** (the honesty bound this ADR obeys for #121), issues **#129** and **#121**

> Written and committed **before** the implementation, per `session-context.md` §5
> item 1 — and reviewed **twice**, per item 3, which S076–S078 were each skipping
> while citing the section by number (lesson 115).

## Context

`release.yml`'s `sign-upload` job carries this:

```yaml
      - name: bundle install
        # Gemfile pins fastlane ~> 2.225 (repo root). Gemfile.lock is documented
        # debt (fastlane/README.md, ADR-021 D6): no Ruby on the dev box means no
        # faithful lock until the first real lane run, so bundler resolves fresh
        # here and there is no lock to key a bundler-cache on.
        run: bundle install
```

**Three of its four clauses are false.** The first — *"Gemfile pins fastlane ~> 2.225"* — is **true** (`Gemfile:21`). The draft of this ADR said *"every clause is false"*; the design review counted. That is the same over-claim shape this session has already filed twice (lessons 111, 115), caught here before it reached code. S048 closed #120 by generating, verifying and
committing `Gemfile.lock`; `fastlane/README.md` opens its debt section with
*"✅ `Gemfile.lock` is COMMITTED"*, and ADR-032 records the debt as
**DISCHARGED**. S048 corrected the claim in the ADR and the README and left the
workflow asserting the opposite — standing addendum 19 (*when a diff corrects a
claim, grep the WHOLE repo for that claim*) broken again.

### The larger half, and a gap in the thing that was supposed to close it

Without `--frozen`, bundler may silently re-resolve when the `Gemfile` and the
lock disagree, instead of failing. `gemfile-lock.yml` — the generator — does use
`bundle install --frozen`, and its header explains why:

> *"`bundle install --frozen` is the `npm ci` of this ecosystem: it asserts the
> lock is already coherent instead of quietly rewriting it to fit."*

The consumer does not. That asymmetry is #129's point.

**But the generator does not verify the committed lock either, and that is new.**
Reading it in full: it runs `bundle lock`, then `bundle lock --add-platform ruby`,
then installs `--frozen` — so it verifies **the lock it just regenerated**, never
the file in the repo. The checksum bracket around the install is honest about
being a self-comparison (*"the lock is UNTRACKED at this point, so a diff against
HEAD sees nothing and would pass vacuously"*). So the repo has had **no check at
all** that the committed `Gemfile.lock` can be installed frozen, and #129's
sharpest observation — *"no release run has ever executed with the committed
lock"* — understates it: **nothing** ever has.

### Measured today, which changes the risk #129 assumed

#129 calls `--frozen` *"the riskier half"* and says it *"should land on a run
someone is watching, not blind"*. A session cannot watch a release run (§7 — the
lane uploads a real binary). But `gemfile-lock.yml` is `workflow_dispatch`-only
with a read-only token that never commits, so a session **may** run it, and did
(run `32087803351`, 2026-08-18):

| | |
|---|---|
| release lane's `bundle install` runs in | `sign-upload`, **macos-26**, Ruby 3.3 |
| `gemfile-lock.yml` runs on | **macos-26**, Ruby 3.3 — deliberately mirrored |
| runner platform reported today | **`arm64-darwin-23`** |
| committed lock `PLATFORMS` | **`arm64-darwin-23`**, `ruby` |
| fastlane resolved today | **2.237.0** |
| fastlane pinned in the committed lock | **2.237.0** |
| `bundle install --frozen` today | **passed**, lock byte-identical after |

So the identical command, on the identical image, Ruby, **platform** and fastlane
version, passed today. `--frozen` is no longer a blind edit; it is a measured one.

⚠️ Worth recording because the generator's own comment predicted otherwise: it
warns that *"a future image bump (arm64-darwin-24 → -25) makes `bundle install`
refuse it"*. **macos-26 still reports `darwin23`.** The mitigation (`--add-platform
ruby`) is in place and remains correct, but the drift it guards has not happened.

## Decision 1 — Delete the false comment, and say what replaced it

The comment is rewritten to describe what is true: the lock is committed, the
lane installs it frozen, and `gemfile-lock.yml` regenerates it.

## Decision 2 — The release lane installs `--frozen`

`bundle install` becomes `bundle install --frozen`, on the measurement above.

The intended consequence is exactly the one #129 names: a `Gemfile` edit that is
not accompanied by a regenerated lock now **fails the release lane loudly**
instead of being silently re-resolved at release time. That is the point, not a
side effect.

## Decision 3 — Verify the COMMITTED lock in `ci.yml`, as a VISIBLY SKIPPED job

Decision 2 alone would move the first real exercise of the committed lock onto the
founder's next release — the thing #129 warns against, merely narrowed. So the gap
is closed at the source.

**A new `gemfile-lock-verify` job in `ci.yml`**, on `macos-26` + Ruby 3.3,
installs the **committed** lock frozen and then runs
`bundle exec fastlane lanes`. It is gated on a computed `ruby_changed` output
so that on a PR touching no Ruby files it appears as **`skipped`**, never absent.

### Why not the paths-filtered `pull_request` trigger this ADR first proposed

Because it contradicts a decision this repo made in Session 002 and records in
`ci.yml`:

> *"per-job paths filters don't exist and workflow-level `paths-ignore` would
> **deadlock required checks** (Session 002 decision)"*

The repo has **zero** paths-filtered workflows, deliberately. And a paths filter
is worse than the skipped-job shape `rules-drift` already uses: a skipped job is
an honest gap **visible in the checks list on every run**, whereas a filtered-out
workflow is simply *absent* — a reviewer cannot tell "the lock was verified" from
"this PR didn't touch `Gemfile*`", and branch protection cannot require a check
that may not appear. **The design review caught this before it was written.**

### Why in `ci.yml` and NOT as a second mode of `gemfile-lock.yml`

The first draft put a `verify` mode inside the generator. Three reasons not to:

1. **The generator would have to not regenerate**, and a mis-wired `if:` would
   leave `bundle lock` running before the frozen install — verifying the lock it
   had just created. That is failure shape **4**, and it is precisely the defect
   this ADR is fixing in that same file. A separate job cannot make that mistake.
2. `gemfile-lock.yml` is **`workflow_dispatch`-only**, and that is load-bearing
   elsewhere: **ADR-036 D4 cites it as the model** — *"`deploy-site.yml` is
   `workflow_dispatch` only, in `gemfile-lock.yml`'s shape"* — and
   `fastlane/README.md:209` calls it *"(dispatch-only)"*. Adding a
   `pull_request` trigger would silently falsify both.
3. Generating and verifying are different acts with different triggers. Keeping
   them in one file is what let the generator quietly verify its own output.

### Why the same runner, and why it runs `fastlane lanes` too

A lock is a claim about a **platform**: the committed `PLATFORMS` is
`arm64-darwin-23` plus generic `ruby`, so verifying on Linux would exercise the
generic fallback and prove the wrong thing — green here, red on the release.

And installing is not the whole claim. The generator already proves the lock is
*usable* (`bundle exec fastlane lanes`) rather than merely installable, because
the release lane runs `bundle exec fastlane ios beta`, which loads the Fastfile
and its plugins. **The verifier must not prove less than the generator**, so it
runs the same check.

## Decision 4 — #121: the App Store Connect key step STAYS, and the trigger is sharpened

#121 asks to confirm the `write App Store Connect API key` step is dead under
manual signing and delete it. The reasoning for its deadness is strong and
already written in the step's own comment: fastlane authenticates from
`ASC_API_KEY_P8_BASE64` via `app_store_connect_api_key(key_content:)`, `match`,
`pilot` and `deliver` all receive that object, and an explicit
`ExportOptions.plist` names the profile so `-allowProvisioningUpdates` has
nothing to resolve.

**It is not deleted, and the reason is the step's own precondition:**

> *"A session that can watch a real run should delete it and confirm."*

This session cannot watch a release run. ADR-029 D2 refused to touch
`CODE_SIGN_IDENTITY` on identical grounds — *"a blind edit to a signing path from
a Linux box with no Mac"* — and the asymmetry has not changed: the lane
demonstrably works **with** the step, and the cost of being wrong is a broken
release the founder cannot debug from their side.

*"Very likely dead" is not "proven dead", and this ADR declines to convert one
into the other by writing it down more confidently.*

### The experiment that settles it, named rather than run

The design review proposed a better instrument than "wait for someone to try
deleting it", and it is recorded here as the method for whoever can watch a run:
**move the key to a path nothing could auto-discover** (e.g.
`$HOME/.hayati-unused/AuthKey_<KEY_ID>.p8`) rather than removing the step. If
nothing reads it, the lane behaves identically and the step is proven dead. If
something does, xcodebuild fails with a *missing key at the auto-discovery path*
— an attributable, re-runnable error rather than a cryptic signing failure.

**It is not run now**, and the reason is timing rather than principle: a failed
release today costs more than usual, because a build is the single thing blocking
push-notification testing (`operator-expected.md`, item 1). This is a controlled
experiment worth doing on a release the founder is already watching, not one
they need.

So the trigger is now specific: **#121 is waiting on a founder-watched release
run, with the canary-path experiment as the method** — not on further analysis.

## Consequences

**What this buys.** The lane stops lying in a comment; a `Gemfile`/lock
divergence fails loudly instead of silently re-resolving; and for the first time
the **committed** lock is verified installable, on the platform that installs it,
on the PR that changes it.

**What it costs.** One macOS job in `ci.yml`, which runs only when `Gemfile*` changes and is **visibly skipped** otherwise — so the checks list distinguishes *verified* from *not applicable*.

**⚠️ VISIBLE, NOT ENFORCING — and the build-diff review caught this ADR claiming
otherwise.** Branch protection requires exactly `quality`, `ios-build-smoke` and
`functions-rules` (read from the API, not assumed). `gemfile-lock-verify` is not
among them, so a red result shows on the PR and **does not block the merge**.
Earlier drafts of this ADR and of both workflow comments said such a lock *"never
reaches main"*; that does not follow from a non-required check. Making it required
is a single repo setting and is recorded as an operator action rather than
asserted here as if it were already true.

**⚠️ A deprecation the measurement itself printed.** This ADR cites run
`32087803351` as evidence that a frozen install passes on the release image — and
that run's log also says `--frozen` is **deprecated** in bundler 2.5.22, advising
`bundle config set frozen true`. The run was quoted for its platform and version
facts while its warnings went unread, which is the same defect as citing an
instrument without saying what it reported. All three workflows now use the
config form.

**⚠️ What is still unproven, stated plainly.** That the release lane *as a whole*
succeeds with `--frozen`. Decision 3 verifies the same command on the same image,
which is as close as anything can get without dispatching the lane — but the
lane also builds, signs and uploads, and only the founder can run it. **The first
real release after this merges is the confirmation.** If it fails at
`bundle install`, that is `--frozen` doing its job, and the remedy is to dispatch
`gemfile-lock.yml` and commit the artifact it produces.

**What #121 leaves open.** A step that is very probably dead stays in a signing
path. That is deliberate, and the asymmetry is stated rather than resolved:
removing it blind risks a release the founder cannot debug; keeping it costs one
file write.
