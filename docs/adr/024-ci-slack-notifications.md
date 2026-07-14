# ADR-024: CI → Slack notifications — one tested notifier script, fail-quiet without the secret, and a noise policy that protects the one message that matters (the post-merge main red)

- **Status:** Accepted (**rev 2** — 4 blocking + 6 serious + 8 minor defects folded from the pre-code adversarial review, Session 025; rev 1 is in git history)
- **Date:** 2026-07-14 (Session 025)
- **Deciders:** session agent, per founder directive 2026-07-14 ("integrate Slack to the CI — look at the ams-pulse project's CI"); the webhook itself is founder-owned (new operator item)
- **Related:** ADR-021 (the release lane + the `environment: release` secrets boundary — the S022 "environment secrets are invisible without `environment:`" lesson is load-bearing here), ADR-006 (iOS-first: why `integration-emulator` is main-only), **`docs/agent-workflows.md` W4** (the no-silent-retries / no-`|| true` CI rule this ADR takes a *bounded, recorded* exception to — see D3.1), ci-debt #17 (the docs-only skip that shapes `needs.*.result`), issue #39 (the annotation-noise class this ADR must not re-open), `docs/architecture.md` §9, `docs/project-rules.md` #5/#7/#9

## Context

The founder installed Slack notifications on the sibling **ams-pulse** repo and directed the same for Hayati, naming that repo's CI as the model. This ADR records what is copied, what is deliberately changed, and the things the reference implementation gets wrong for *this* repo.

**What Hayati's CI actually looks like** (the shape any notifier must survive):

| workflow | jobs | trigger shape |
|---|---|---|
| `ci.yml` | `quality`, `functions-rules`, `ios-build-smoke`, `integration-emulator` | PR (all types incl. `ready_for_review`), push to **main only**, `workflow_dispatch` |
| `release.yml` | `preflight`, `integration`, `build-report`, `sign-upload` | tag `v*.*.*`, `workflow_dispatch` |

Three structural facts drive every decision below:

1. **`integration-emulator` is a POST-MERGE signal by cost design.** macOS minutes bill at 10×, so the full simulator+emulator leg runs on main and on dispatch — never on a PR (ci.yml header; Session-004 billing incident). The session agent watches `gh pr checks` and then merges; the main run concludes *after* the session's attention has moved on. **A red `integration-emulator` on main is the one CI event in this repo that currently has no reader.** That is the message Slack exists to deliver. Everything else in this ADR is in service of it arriving un-muted.
2. **The repo has no secrets at all** (`gh secret list` is empty; the three `ASC_*` release secrets are still operator item 4). `SLACK_WEBHOOK_URL` does not exist and cannot be created by any session — Slack app creation is founder-owned. So the notifier ships into a repo where its secret is **absent for an unknown number of runs**, and its behaviour in that state is a first-class design question, not an edge case.
3. **The session end-sequence pushes a docs commit to main minutes after the merge** (session-rules §3.4). Under ci.yml's `concurrency: cancel-in-progress: true` keyed on `${{ github.workflow }}-${{ github.ref }}`, that second push **cancels the merge run that carries `integration-emulator`** — and the superseding docs-only run *skips* `integration-emulator` (`code_changed=false`, ci-debt #17). This is not hypothetical: **two of the last five main runs are `cancelled`** (`3407f03`, `e6144ab`), and S023 had to hand-fire `gh workflow run ci.yml --ref main` to recover the verdict. A notifier bolted onto this concurrency would deliver *nothing* for exactly the event it exists to deliver. **D8 fixes the cancellation; without D8 this ADR's premise is false.**

**The reference implementation (ams-pulse `ci.yml` / `e2e.yml` / `release.yml` / `ams-version-matrix.yml`)** — what it does, verbatim: a terminal `slack-notify` job with `needs: [<every job>]` and `if: always()`, holding two steps — success (`!contains(needs.*.result,'failure') && !contains(needs.*.result,'cancelled')`) and failure (`contains(needs.*.result,'failure')`) — each building a `{"text": …}` payload with `jq -n --arg` and POSTing it with `curl -sf`, suffixed `|| echo "::warning::Slack … notification failed"`. The commit subject reaches the shell through a `COMMIT_MESSAGE` **env var**, never inline `${{ }}` interpolation.

Three properties of that reference are **right and are kept**: the terminal `if: always()` fan-in job (one message per run, not per job); `jq -n --arg` for payload construction (a commit subject containing `"` or a newline cannot corrupt the JSON); and env-passing the commit message (inline `${{ github.event.head_commit.message }}` inside a `run:` block is a **script-injection** hole — a commit subject is attacker-controlled text in the general case).

**The injection rule, stated completely** (rev 2 — the reference and rev 1 both named only the commit subject): **every** attacker-influenced field must arrive by env var and reach the payload through `jq --arg`, never through `${{ }}` inside a `run:` block and never interpolated into the **jq program string**. Those fields are: the commit subject, **the PR title** (on `pull_request` events `github.event.head_commit` does not exist — an implementer who wires only the commit subject finds it blank on PRs and reaches for inline `${{ github.event.pull_request.title }}`, re-opening the exact hole), **the branch name**, and **the actor**. The env expression that covers both event shapes is named verbatim in D6 so the implementer has no decision left to make.

The rest of the reference is **wrong for Hayati** and is changed (D1–D3, D8).

## Decision 1 — One tested script (`tool/ci/slack_notify.sh`), not the same 30 lines pasted into every workflow

ams-pulse carries that notification block **four times**, and the copies have already drifted: `ci.yml` and `e2e.yml` compute the failed-job list from `toJson(needs)`, while `release.yml` and `ams-version-matrix.yml` report `$GITHUB_JOB` (the *notifying* job's own name — which in a fan-in job is the notifier itself, not what broke). That is the predictable end state of copy-paste CI: the fix lands in one copy.

Hayati extracts the notifier into **`tool/ci/slack_notify.sh`**, invoked from both workflows. Every input arrives by **environment variable**; the script takes no positional arguments and interpolates no `${{ }}`.

**`tool/ci/` is a new subdirectory** — a deliberate, recorded deviation from the flat Dart-only `tool/*.dart` convention, justified by the language boundary: this is a CI utility that must run **before `pub get`** with no Dart SDK involvement. Two consequences of that boundary, recorded per rule #9 rather than implied away:

- `dart format --set-exit-if-changed … tool …` (quality job) formats `*.dart` and **silently ignores `*.sh`**. Bash gets no formatter.
- Bash gets no `dart analyze` either — so **`shellcheck` is added to the `quality` job** (pre-installed on `ubuntu-latest`, and present on the dev box). It catches the SC2086-class unquoted-expansion and word-splitting bugs that a behavioural test suite only catches if someone remembers to extend the fixtures. The static gate and the behavioural gate are both required; neither subsumes the other.

**`tool/ci/slack_notify_test.sh` runs in `quality`** (bash + jq + python3 only — no pubspec, so it sits with the other pre-`pub get` self-tests). `SLACK_DRY_RUN=1` makes the script print the payload to stdout and POST nothing. The suite pins the properties that a shell notifier silently loses:

- absent secret → stdout contains **`::notice::`** (positive assertion — "no warning annotation" alone is satisfied by a script that prints nothing), no `::warning::`, no POST, exit 0;
- payload is well-formed JSON for a commit subject containing `"`, `\`, a newline, `$(id)` and backticks — and the metacharacters survive as **literal text** (no command substitution, no JSON break-out). **The same fixture is applied to the PR title, the branch name, and the actor** — all four attacker-influenced fields, so `--arg` protection is mutation-checkable on each;
- only the **first line** of a multi-line commit subject is sent, and multibyte TR/AR subjects survive intact;
- the failure payload names the **failed jobs and ONLY the failed jobs** — the fixture has `quality=failure` with the rest `skipped`, and the test asserts `quality` **is** present *and* that a skipped job name is **absent**. (A one-sided "is quality there?" assertion passes an implementation that dropped `select(.value.result == "failure")` and lists every job — which is precisely the ams-pulse drift bug this decision exists to prevent.)
- the **PR-event SHA** is the branch head, not the ephemeral merge commit (D5);
- **the outcome derivation** — `failure` when any need failed (even alongside a `skipped` cascade), `cancelled` when any need was cancelled and none failed, `success` otherwise;
- **the noise policy itself** — a successful `pull_request` run → silent, no POST; the same needs on a `push` → payload; a `cancelled` run → silent (D2 lives in the script precisely so these lines exist);
- **anti-leak sentinel:** with a webhook set, the webhook value appears in neither stdout nor stderr — the notifier is the one script in the repo that holds a secret in a variable, so "it never prints it" is a guarantee that gets a test, not a promise (the S020 *assert the mechanism* rule);
- **`jq` missing → `::warning::` + exit 0** (PATH-shadow fixture), so D3's tool-missing invariant is pinned rather than merely asserted;
- a POST failure (connection refused against a dead port — hermetic, no network) → `::warning::` + **exit 0**, never a red (D3);
- **a REAL curl POST against a hermetic local listener** (python3 `http.server` on an ephemeral port; no network, no Slack): the captured request must be `POST`, carry `Content-Type: application/json`, and its body must be valid JSON with a `text` key. Without this, every test runs under `SLACK_DRY_RUN=1` or against a refused TCP connect — **neither executes curl's HTTP flags at all**, so a missing `-H`, a broken `--data @-` handoff, or a wrong method passes the whole suite and fails silently on the founder's first real message with nothing but a `::warning::` in a log nobody reads.

## Decision 2 — Noise policy: **failures always; successes only on `main` / `workflow_dispatch` / release**. PR successes are silent. The policy lives IN THE SCRIPT.

ams-pulse notifies on **every** run of every workflow, success included — PRs too. Copying that here would post a ✅ for each of the 5–10 PR pushes a session makes (this repo's PRs are agent-driven and the session already watches them with `gh pr checks --watch`), and the founder would be reading ✅ messages about builds that already had a reader. The predictable outcome of a channel that is 90% noise is that it gets muted — and the muted channel then swallows the *one* message this integration exists to deliver (the post-merge `integration-emulator` red, Context §1). **A notification policy that gets the channel muted is a failed notification policy**, however faithfully it copies the reference.

| event | success | failure |
|---|---|---|
| `pull_request` (`ci.yml`) | **silent** — the session is watching | **notify** (rare: the agent runs the gates locally before pushing, so a PR red is genuinely interesting) |
| `push` to `main` (`ci.yml`) | **notify** — carries the post-merge `integration-emulator` verdict **when `code_changed=true`**; on a docs-only push both macOS jobs are `skipped` (ci-debt #17) and the message says so, because it prints the per-job result line (D5) | **notify** ← *the reason this ADR exists* |
| `workflow_dispatch` (`ci.yml`) | **notify** — a dispatch is a deliberate question; it deserves its answer | **notify** |
| `release.yml` (tag or dispatch) | **notify** — a release build is always worth a line | **notify** (incl. the `sign-upload` fail-closed secrets gate, ADR-021) |
| **cancelled** (any) | **never** | **never** — a superseded run is not an event. **D8 is what makes this safe:** before D8, the run most likely to be cancelled was the one carrying the `integration-emulator` verdict. |

**Where the policy lives is itself a decision (rev 2).** Rev 1 put the event allowlist in the YAML step's `if:` — which the shell self-test *cannot see*. A one-line edit dropping `github.event_name != 'pull_request'` would have re-enabled PR-success spam with all self-tests still green: a noise policy whose entire justification is channel-health, protected by nothing.

So **the whole policy moves into the script**, and the YAML keeps *no* outcome logic at all — not even the success/failure split. The script reads `NEEDS_JSON` (`toJson(needs)`) and derives the outcome itself: **failure** if any need failed, else **cancelled** if any was cancelled, else **success**; then it applies the PR-success suppression. This is why there is **one** notifier step with **no** `if:` condition, rather than the reference's success/failure pair. The alternative — two steps whose `if:` expressions carry `contains(needs.*.result, 'cancelled')` — would leave the *cancelled* rule sitting in YAML, untestable, which is the identical defect this decision exists to close. Every branch of the table above is now a line in D1's suite.

It remains a **one-line flip**: to get ams-pulse's every-run behaviour, delete the pull-request guard *in the script* — a deletion the self-test fails on immediately, which is the point. Recorded as a revisit trigger, not a permanent verdict.

## Decision 3 — Absent secret = a **clean, quiet skip**. The notifier can never fail a build, and never annotates a run it cannot serve.

The secret does not exist yet and will not until the founder acts (operator item). The reference's `curl -sf … "$SLACK_WEBHOOK_URL" || echo "::warning::…"` would, with an empty URL, fail `curl` on **every run** and stamp a `::warning::` annotation on **every green build** until the founder gets around to it. That is precisely the annotation-noise class Session 024 just spent a slice cleaning up (issue #39, the Node-20 deprecation warnings) — re-introducing it as the *first* act of the next session would be self-refuting.

Therefore:

- **Empty/unset `SLACK_WEBHOOK_URL` → `::notice::` + `exit 0`.** Not a warning. Not a failure. A repo with no webhook configured is not a broken repo; it is a repo with no webhook configured. Fork PRs (where secrets are structurally unavailable) take the same silent path by construction.
- **A POST that fails once the secret exists** (revoked webhook, Slack 5xx, DNS) → `::warning::` + `exit 0`. Visible, never fatal.
- **`jq` or `curl` missing** → `::warning::` + `exit 0` (pinned by a PATH-shadow test, D1).
- **`--max-time 15 --retry 2 --retry-delay 1 --retry-max-time 30`** on the POST. `--max-time` **resets on each retry attempt**, so `--max-time 15 --retry 2` alone bounds the notifier at ~47s, not 15 — three attempts plus delays. `--retry-max-time 30` is the flag that actually caps the total. (`--retry` covers transient 5xx/429/timeouts, which is what a webhook realistically hits; a connection-refused is *not* retried by default, which is why the dead-port test in D1 is fast and hermetic.) `timeout-minutes: 5` on the job is the outer backstop.

**The invariant, stated once and binding: the notifier is a side-channel; it has no vote on whether the build passed.**

**That guarantee needs enforcement at TWO levels, and rev 1 only had one** (the review's blocking find). The script's `exit 0` paths cover everything that happens *after the script starts*. They cannot cover what happens *before* it: `actions/checkout` failing on a transient API blip, runner provisioning failure, or the job timeout expiring. Any of those turns the `slack-notify` job red — and a red job makes the **workflow run** red, whatever branch protection thinks. Branch protection (required contexts: `quality`, `ios-build-smoke`, `functions-rules`) only governs *merging*; **project-rules #7 — "every push must pass the entire GitHub Actions pipeline" — is a separate binding contract**, and under it a green build with a failed checkout in the notifier is a red pipeline that a session must stop and investigate (session-rules §3.5). So:

- **`continue-on-error: true` on the `slack-notify` job** (D6, both workflows). It is the only mechanism that delivers "no vote" for pre-script failures. Note it is *not* the same as `if: always()` — `always()` controls whether the job **runs**; `continue-on-error` controls whether its failure **counts**.
- This is **not** an `|| true` in disguise: the job still renders **failed** in the Actions UI and in `gh run view --log-failed`. What is suppressed is only the *cascade* to the run's conclusion. A broken notifier stays visible; it just cannot halt a session.

### D3.1 — The W4 exception, recorded and bounded

W4 (`agent-workflows.md`) is the house CI-discipline rule — *no silent retries, no `|| true`* — and it is cited eight times across the two workflow files. This ADR's fail-open (`exit 0` on every error path) and `--retry 2` are, read literally, exceptions to it. Rev 1 never named W4, which would have left an implementer or Reviewer sub-agent unable to tell whether the rule was **considered and overridden** or simply **missed**. Naming it:

**W4 governs steps that produce a primary CI signal** — a build, a test, a lint — where swallowing a failure hides a real code outcome and lets a broken commit read green. **The notifier produces no primary signal and can mask no test result.** A missed POST is a missed *notification*, not a hidden failure; the build's verdict is unchanged and still sits in the Actions UI. `--retry 2` targets transient Slack-side 5xx (an HTTP-client concern), not flaky tests.

**The exception is bounded, and the bound is the rule:** `exit 0`-on-error is permitted **only** in `tool/ci/slack_notify.sh`, and **never** on any step that produces a primary CI signal. If a future session finds itself writing `|| exit 0` anywhere else in CI, W4 applies unmodified and this ADR is not a precedent for it.

## Decision 4 — The secret is a **repository** secret, not an environment secret

`release.yml`'s `sign-upload` binds `environment: release` (ADR-021 rev 2), and the S022 lesson is written in the standing toolchain note: **environment secrets are invisible to jobs without an `environment:` binding.** The `slack-notify` job in `release.yml` deliberately has no environment (it must post on failures *from any job*, including a `sign-upload` that fail-closed on missing `ASC_*` secrets — binding it to the same environment would be circular). So `SLACK_WEBHOOK_URL` must be a **repository-level** secret:

```
gh secret set SLACK_WEBHOOK_URL --body '<the webhook URL>'    # repo-level; NOT --env release
```

Written into the operator item verbatim, because "set it in the release environment" is the silently-green failure mode this repo has already paid for once.

## Decision 5 — Payload contract: a classic Incoming Webhook, a plain `{"text": …}` body, and an explicit per-message field list

`{"text": …}` is the classic Incoming-Webhook contract, and it is what the reference posts. It is recorded here because the operator instruction depends on it: the founder must create an **Incoming Webhook**, **not** a Workflow-Builder webhook trigger — the latter validates the body against a declared variable schema and would reject `{"text": …}` with a 400 that surfaces only as a `::warning::`. Same webhook URL for both workflows; the channel is bound to the webhook at creation (Slack's model), so channel routing is a founder choice made in Slack, not a repo config.

**Fields, per message type** (rev 2 — rev 1's single flat list let an implementer start from the ams-pulse *success* printf, which carries no run URL, no branch and no actor, and ship a success message with no clickable link while every test passed):

- **success:** repo · workflow · branch · actor · short SHA · commit subject (first line) · **run URL** · UTC time · **the per-job result line**.
- **failure:** all of the above **plus the failed job names**.
- **the per-job result line** (`quality ✅ · functions-rules ✅ · ios-build-smoke ⏭ · integration-emulator ⏭`) is what keeps D2's main-push row honest: a docs-only close commit skips both macOS jobs, and the message *shows* that instead of implying an `integration-emulator` verdict it never had.

**The SHA field must be `${{ github.event.pull_request.head.sha || github.sha }}`.** On `pull_request` events `GITHUB_SHA` is the **ephemeral merge commit** GitHub synthesizes for the check run: it appears in no branch, no PR commit list, and no `git log` the founder can run. A failure message whose SHA cannot be looked up anywhere is worse than no SHA. Pinned by a D1 fixture.

Message content is **repo metadata only** — no log excerpts, ever: CI logs in this repo touch emulator fixtures and env-shaped values, and a notifier that scrapes them into a chat channel is an exfiltration path wearing a helmet. (The commit subject *is* repo content; it is included deliberately and is the only such field.)

## Decision 6 — Wiring: a terminal `slack-notify` job in both workflows, and one new step in `quality`

- **`ci.yml`:** `needs: [quality, functions-rules, ios-build-smoke, integration-emulator]`, `if: always()`, **`continue-on-error: true`** (D3), `runs-on: ubuntu-latest`, `permissions: contents: read` (it checks out — the script lives in the repo; that is the cost of D1's single source, ~5s on ubuntu), `timeout-minutes: 5`.
- **`release.yml`:** `needs: [preflight, integration, build-report, sign-upload]`, same shape.
- **`quality` gains two pre-`pub get` steps** — `shellcheck tool/ci/*.sh` and `bash tool/ci/slack_notify_test.sh`. **This is the mechanism that makes D1's "runs in `quality`" true.** Rev 1 specified the new job but never said to touch `quality`; an implementer reading D6 as the wiring spec would have shipped a test file that CI never executes, leaving every "pinned" property in D1 un-pinned.

The notifier job holds **one step with no `if:`** (D2: all outcome logic lives in the script). Its `env:` stanza, verbatim — the injection rule of the Context section, made executable:

```yaml
env:
  SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
  NEEDS_JSON:   ${{ toJson(needs) }}                  # the script derives success/failure/cancelled
  COMMIT_TITLE: ${{ github.event.head_commit.message || github.event.pull_request.title || '' }}
  HEAD_SHA:     ${{ github.event.pull_request.head.sha || github.sha }}
```

Everything else the payload needs (`GITHUB_REPOSITORY`, `GITHUB_WORKFLOW`, `GITHUB_REF_NAME`, `GITHUB_ACTOR`, `GITHUB_RUN_ID`, `GITHUB_SERVER_URL`, `GITHUB_EVENT_NAME`) is already in the runner's default environment — no `${{ }}` needed, so none is written.

**Skipped ≠ failed**, and this repo skips jobs constantly by design (`ios-build-smoke` on drafts and docs-only pushes; `integration-emulator` on every PR; `sign-upload` never skips — it fails closed). `contains(needs.*.result, 'failure')` reads `skipped` as what it is, so a PR run whose `integration-emulator` never ran still reports success — and a run where `quality` failed and everything downstream went `skipped` still reports **failure**, naming `quality`. Both are pinned by the self-test's fixture payloads.

## Decision 7 — What this ADR does NOT claim (the honest acceptance bound)

The end-to-end proof — a real message in a real Slack channel — **cannot be produced by this session**: it requires a webhook that only the founder can mint. What ships is the *mechanism*, proven by the self-tests (including a real curl POST against a hermetic local listener, D1); what does not ship is the *guarantee* that Slack is receiving anything.

Docs therefore say **"wired; fail-quiet until `SLACK_WEBHOOK_URL` exists"** — never "Slack notifications are live". The live proof is an operator-gated acceptance, delivered through the session-close `operator-expected.md` refresh (session-rules §3.3): the founder rotates + sets the secret, and the **next push to main** posts the first message. If it does not, the run's `slack-notify` job log carries the `::notice::`/`::warning::` that says why — for script-level failures. (Honest residual: a *wrong curl flag* would surface only as a generic POST-failed `::warning::`, indistinguishable from a revoked webhook without reading the log. The hermetic-listener test in D1 exists to make that class not happen.)

**Two further bounds, recorded rather than papered over:**

1. **What "the main red has a reader" does and does not mean.** With D8 in place, a *code* push to main runs `integration-emulator` to completion and the notifier reports it. A **docs-only** push to main skips it by design (ci-debt #17) — the message says so via the per-job line rather than implying a verdict. And with **no webhook set**, none of this reaches anyone: the Consequences section below states the gain in the conditional, not the present tense.
2. **`shellcheck` + the behavioural suite are the bash quality gate — there is no `dart analyze` equivalent.** A future edit that introduces a new payload field without a test fixture is caught by shellcheck only if it is a *syntactic* hazard (SC2086-class). A semantically wrong-but-well-quoted field is caught by nothing until someone reads a message. Recorded per rule #9.

## Decision 8 — Stop the session-close push from cancelling the run that carries the verdict (ci.yml concurrency)

**This decision is load-bearing for the ADR's entire premise** and was absent from rev 1.

`ci.yml` groups concurrency on `${{ github.workflow }}-${{ github.ref }}` with `cancel-in-progress: true`. On a PR ref that is exactly right: a rapid re-push should kill the superseded run and save billed minutes (the Session-004 rule). **On `main` it is actively harmful**, because two *distinct commits* share the ref:

1. the session merges the code PR → main run A starts, `integration-emulator` boots (~25–50 min);
2. ~10–20 min later the session pushes its close commit (past-prompts/resume-prompt/operator-expected, §3.4) → main run B starts and **cancels run A**;
3. run B is docs-only → `code_changed=false` → **`integration-emulator` skips**.

The verdict for the merged code is destroyed, and no notification fires either way (D2: cancelled is never an event). The repo's own history confirms it — `3407f03` and `e6144ab` are both `cancelled` main runs, and S023 recovered by hand-dispatching the workflow.

**Fix:** key the concurrency group on the **commit** for push events, and keep ref-keying everywhere else:

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}-${{ github.event_name == 'push' && github.sha || 'ref' }}
  cancel-in-progress: true
```

A push to main now occupies its own group, so a later main push cannot cancel it; PR re-pushes are unaffected (same ref, same group → still cancelled, billing protection intact). The added cost is bounded and small: the extra main run that now survives is the *docs-only* one, which skips both 10×-billed macOS jobs by construction (ci-debt #17).

Alternatives rejected: **(a)** reorder session-rules §3 so the session watches the main run to completion *before* pushing the close commit — correct in spirit, but it makes a durable CI guarantee depend on an agent remembering a procedure (this repo prefers the mechanism to the promise), and it forces every session to idle 25–50 min; it is recorded in `session-rules.md` as *good practice*, not as the mechanism. **(b)** `cancel-in-progress: false` outright — throws away the PR billing protection Session 004 was burned into.

## Decision 9 — The pre-existing hardcoded webhook: superseded, and it must be ROTATED

A local, **never-pushed** branch `chore/slack-notifications` (commit `13f1e6d`) adds a `slack-notify` job to `ci.yml` with a **live Slack webhook URL hardcoded in plaintext in the workflow file** — not a secret reference. The pre-code review surfaced it; it is recorded here because it changes two things:

- **The branch is superseded by this ADR and must not be merged or pushed.** Its design is the ams-pulse copy-paste (both defects of D1, plus the URL in the clear).
- **That webhook is a compromised bearer credential and the founder must rotate it** — a webhook URL in a git object is a credential in a git object, whether or not the branch ever reached a remote. The operator item asks for a **fresh** webhook, and the old one revoked in Slack. The session does not delete the branch (it holds the evidence of *which* webhook to revoke, and it is not the session's credential to destroy).

This is the concrete argument for D4's shape: the URL belongs in Actions secrets (masked in logs, unavailable to fork PRs, rotatable in one `gh secret set`), never in a file.

## Consequences

- **Gains (stated conditionally — the S020 rule):** *once the founder sets `SLACK_WEBHOOK_URL`*, the post-merge main red has a reader — and D8 is what makes that verdict survive the session's own close commit. The release lane's fail-closed signing boundary announces itself. One tested notifier instead of four drifting copies. The repo's first CI-owned secret arrives with its scope (repository, not environment) written down before it is set wrong, and the hardcoded one gets rotated.
- **Costs:** one extra ubuntu job per run (~15s, checkout + POST); two extra `quality` steps (~5s); a new founder task (rotate + mint the webhook) that blocks nothing.
- **Risks accepted:** (1) the noise policy is a judgment call — if the founder wants PR successes too, it is a one-line deletion in the script (D2). (2) The notifier's live path is unexercised against *Slack itself* until the secret exists — mitigated by the hermetic-listener POST test (D1), bounded honestly in D7. (3) A webhook URL is a bearer credential: anyone holding it can post to the channel. It lives in GitHub Actions secrets (masked in logs, unreadable by fork PRs) and the anti-leak sentinel pins that the script never prints it; rotation is `gh secret set` over the same name.
- **Docs that must change in the same diff (rule #8):** `architecture.md` §9 (the terminal `slack-notify` job in both workflows, its fail-open side-channel role, `continue-on-error`, the D8 concurrency change), `test-suite.md` (the new bash self-test suite in `quality`), `session-rules.md` (the D8 alternative-(a) note: watch the main run before the close push), `operator-expected.md` (the new founder item: **rotate**, mint, `gh secret set` — repo-level — then confirm the first message).
