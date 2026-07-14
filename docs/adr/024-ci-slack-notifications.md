# ADR-024: CI → Slack notifications — one tested notifier script, fail-quiet without the secret, and a noise policy that protects the one message that matters (the post-merge main red)

- **Status:** Accepted
- **Date:** 2026-07-14 (Session 025)
- **Deciders:** session agent, per founder directive 2026-07-14 ("integrate Slack to the CI — look at the ams-pulse project's CI"); the webhook itself is founder-owned (new operator item)
- **Related:** ADR-021 (the release lane + the `environment: release` secrets boundary — the S022 "environment secrets are invisible without `environment:`" lesson is load-bearing here), ADR-006 (iOS-first: why `integration-emulator` is main-only), ci-debt #17 (the docs-only skip that shapes `needs.*.result`), issue #39 (the annotation-noise class this ADR must not re-open), `docs/architecture.md` §9, `docs/project-rules.md` #5/#7

## Context

The founder installed Slack notifications on the sibling **ams-pulse** repo and directed the same for Hayati, naming that repo's CI as the model. This ADR records what is copied, what is deliberately changed, and the two things the reference implementation gets wrong for *this* repo.

**What Hayati's CI actually looks like** (the shape any notifier must survive):

| workflow | jobs | trigger shape |
|---|---|---|
| `ci.yml` | `quality`, `functions-rules`, `ios-build-smoke`, `integration-emulator` | PR (all types incl. `ready_for_review`), push to **main only**, `workflow_dispatch` |
| `release.yml` | `preflight`, `integration`, `build-report`, `sign-upload` | tag `v*.*.*`, `workflow_dispatch` |

Two structural facts drive every decision below:

1. **`integration-emulator` is a POST-MERGE signal by cost design.** macOS minutes bill at 10×, so the full simulator+emulator leg runs on main and on dispatch — never on a PR (ci.yml header; Session-004 billing incident). The session agent watches `gh pr checks` and then merges; the main run concludes *after* the session's attention has moved on. **A red `integration-emulator` on main is the one CI event in this repo that currently has no reader.** That is the message Slack exists to deliver. Everything else in this ADR is in service of it arriving un-muted.
2. **The repo has no secrets at all** (`gh secret list` is empty; the three `ASC_*` release secrets are still operator item 4). `SLACK_WEBHOOK_URL` does not exist and cannot be created by any session — Slack app creation is founder-owned. So the notifier ships into a repo where its secret is **absent for an unknown number of runs**, and its behaviour in that state is a first-class design question, not an edge case.

**The reference implementation (ams-pulse `ci.yml` / `e2e.yml` / `release.yml` / `ams-version-matrix.yml`)** — what it does, verbatim: a terminal `slack-notify` job with `needs: [<every job>]` and `if: always()`, holding two steps — success (`!contains(needs.*.result,'failure') && !contains(needs.*.result,'cancelled')`) and failure (`contains(needs.*.result,'failure')`) — each building a `{"text": …}` payload with `jq -n --arg` and POSTing it with `curl -sf`, suffixed `|| echo "::warning::Slack … notification failed"`. The commit subject reaches the shell through a `COMMIT_MESSAGE` **env var**, never inline `${{ }}` interpolation.

Three properties of that reference are **right and are kept**: the terminal `if: always()` fan-in job (one message per run, not per job); `jq -n --arg` for payload construction (a commit subject containing `"` or a newline cannot corrupt the JSON); and env-passing the commit message (inline `${{ github.event.head_commit.message }}` inside a `run:` block is a **script-injection** hole — a commit subject is attacker-controlled text in the general case).

Three properties are **wrong for Hayati** and are changed (D1–D3).

## Decision 1 — One tested script (`tool/ci/slack_notify.sh`), not the same 30 lines pasted into every workflow

ams-pulse carries that notification block **four times**, and the copies have already drifted: `ci.yml` and `e2e.yml` compute the failed-job list from `toJson(needs)`, while `release.yml` and `ams-version-matrix.yml` report `$GITHUB_JOB` (the *notifying* job's own name — which in a fan-in job is the notifier itself, not what broke). That is the predictable end state of copy-paste CI: the fix lands in one copy.

Hayati extracts the notifier into **`tool/ci/slack_notify.sh`**, invoked from both workflows. This follows the established house convention — `tool/` scripts with self-tests that the cheap ubuntu `quality` job runs (`coverage_gate.dart`, `rtl_lint.dart`, `store_metadata_lint.dart` + `store_metadata_lint_test.dart`). Every input arrives by **environment variable**; the script takes no positional arguments and interpolates no `${{ }}`.

**`tool/ci/slack_notify_test.sh` runs in `quality`** (bash + jq only — no pubspec, so it sits with the other pre-`pub get` self-tests). `SLACK_DRY_RUN=1` makes the script print the payload to stdout and POST nothing, which is what makes the notifier testable at all. The suite pins the properties that a shell notifier silently loses:

- absent secret → exit 0, no POST, no warning annotation (D3);
- payload is well-formed JSON for a commit subject containing `"`, `\`, a newline, `$(id)` and backticks — and the metacharacters survive as **literal text** (no command substitution, no JSON break-out);
- only the **first line** of a multi-line commit subject is sent;
- the failure payload names the **failed jobs** (D1's drift bug, pinned) and carries the run URL;
- **anti-leak sentinel:** with a webhook set, the webhook value appears in neither stdout nor stderr — the notifier is the one script in the repo that holds a secret in a variable, so "it never prints it" is a guarantee that gets a test, not a promise (the S020 *assert the mechanism* rule);
- a POST failure (connection refused against a dead port — hermetic, no network) → `::warning::` + **exit 0**, never a red (D3).

## Decision 2 — Noise policy: **failures always; successes only on `main` / `workflow_dispatch` / release**. PR successes are silent.

ams-pulse notifies on **every** run of every workflow, success included — PRs too. Copying that here would post a ✅ for each of the 5–10 PR pushes a session makes (this repo's PRs are agent-driven and the session already watches them with `gh pr checks --watch`), and the founder would be reading ✅ messages about builds that already had a reader. The predictable outcome of a channel that is 90% noise is that it gets muted — and the muted channel then swallows the *one* message this integration exists to deliver (the post-merge `integration-emulator` red, Context §1). **A notification policy that gets the channel muted is a failed notification policy**, however faithfully it copies the reference.

So:

| event | success | failure |
|---|---|---|
| `pull_request` (`ci.yml`) | **silent** — the session is watching | **notify** (rare: the agent runs the gates locally before pushing, so a PR red is genuinely interesting) |
| `push` to `main` (`ci.yml`) | **notify** — carries the post-merge `integration-emulator` verdict | **notify** ← *the reason this ADR exists* |
| `workflow_dispatch` (`ci.yml`) | **notify** — a dispatch is a deliberate question; it deserves its answer | **notify** |
| `release.yml` (tag or dispatch) | **notify** — a release build is always worth a line | **notify** (incl. the `sign-upload` fail-closed secrets gate, ADR-021) |
| **cancelled** (any) | **never** | **never** — `cancel-in-progress: true` makes superseded runs routine; they are not events |

This is a deliberate, recorded deviation from the reference. It is also a **one-line flip**: the success step's `if:` carries the event allowlist, so if the founder wants ams-pulse's every-run behaviour, delete the `github.event_name != 'pull_request'` clause. Recorded as a revisit trigger, not a permanent verdict.

## Decision 3 — Absent secret = a **clean, quiet skip**. The notifier can never fail a build, and never annotates a run it cannot serve.

The secret does not exist yet and will not until the founder acts (operator item). The reference's `curl -sf … "$SLACK_WEBHOOK_URL" || echo "::warning::…"` would, with an empty URL, fail `curl` on **every run** and stamp a `::warning::` annotation on **every green build** until the founder gets around to it. That is precisely the annotation-noise class Session 024 just spent a slice cleaning up (issue #39, the Node-20 deprecation warnings) — re-introducing it as the *first* act of the next session would be self-refuting.

Therefore:

- **Empty/unset `SLACK_WEBHOOK_URL` → `::notice::` + `exit 0`.** Not a warning. Not a failure. A repo with no webhook configured is not a broken repo; it is a repo with no webhook configured. Fork PRs (where secrets are structurally unavailable) take the same silent path by construction.
- **A POST that fails once the secret exists** (revoked webhook, Slack 5xx, DNS) → `::warning::` + `exit 0`. Visible, never fatal.
- **`jq` or `curl` missing** → `::warning::` + `exit 0`.
- **`--max-time 15 --retry 2 --retry-delay 1`** on the POST: a hung Slack must not hold a runner (the reference has no timeout at all — an unbounded `curl` in an `if: always()` job is a 6-hour job-timeout waiting to happen).

The invariant, stated once and binding: **the notifier is a side-channel; it has no vote on whether the build passed.** A notifier that can red a green build is a worse defect than a missed message, and the branch-protection facts make this safe to assert — the required contexts are exactly `quality`, `ios-build-smoke`, `functions-rules`, so the new `slack-notify` job is not a required check and cannot deadlock a merge even if it somehow hung.

## Decision 4 — The secret is a **repository** secret, not an environment secret

`release.yml`'s `sign-upload` binds `environment: release` (ADR-021 rev 2), and the S022 lesson is written in the standing toolchain note: **environment secrets are invisible to jobs without an `environment:` binding.** The `slack-notify` job in `release.yml` deliberately has no environment (it must post on failures *from any job*, including a `sign-upload` that fail-closed on missing `ASC_*` secrets — binding it to the same environment would be circular). So `SLACK_WEBHOOK_URL` must be a **repository-level** secret:

```
gh secret set SLACK_WEBHOOK_URL --body 'https://hooks.slack.com/services/…'   # repo-level; NOT --env release
```

Written into the operator item verbatim, because "set it in the release environment" is the silently-green failure mode this repo has already paid for once.

## Decision 5 — Payload contract: a classic Incoming Webhook and a plain `{"text": …}` body

`{"text": …}` is the classic Incoming-Webhook contract, and it is what the reference posts. It is recorded here because the operator instruction depends on it: the founder must create an **Incoming Webhook** (api.slack.com/apps → *your app* → Incoming Webhooks → Add New Webhook to Workspace), **not** a Workflow-Builder webhook trigger — the latter validates the body against a declared variable schema and would reject `{"text": …}`. Same webhook URL for both workflows; the channel is bound to the webhook at creation (Slack's model), so channel routing is a founder choice made in Slack, not a repo config.

Message content is repo metadata only — repo, workflow, branch, actor, short SHA, the commit subject's first line, the run URL, UTC time, and on failure the failed job names. **No log excerpts** are ever included: CI logs in this repo touch emulator fixtures and env-shaped values, and a notifier that scrapes them into a chat channel is an exfiltration path wearing a helmet.

## Decision 6 — Wiring: a terminal `slack-notify` job in both workflows

- **`ci.yml`:** `needs: [quality, functions-rules, ios-build-smoke, integration-emulator]`, `if: always()`, `runs-on: ubuntu-latest`, `permissions: contents: read` (it checks out — the script lives in the repo; that is the cost of D1's single source, ~5s on ubuntu), `timeout-minutes: 5`.
- **`release.yml`:** `needs: [preflight, integration, build-report, sign-upload]`, same shape.

**Skipped ≠ failed**, and this repo skips jobs constantly by design (`ios-build-smoke` on drafts and docs-only pushes; `integration-emulator` on every PR; `sign-upload` never skips — it fails closed). `contains(needs.*.result, 'failure')` reads `skipped` as what it is, so a PR run whose `integration-emulator` never ran still reports success — and a run where `quality` failed and everything downstream went `skipped` still reports **failure**, naming `quality`. Both are pinned by the self-test's fixture payloads.

## Decision 7 — What this ADR does NOT claim (the honest acceptance bound)

The end-to-end proof — a real message in a real Slack channel — **cannot be produced by this session**: it requires a webhook that only the founder can mint. What ships is the *mechanism*, proven by the self-tests and a dry-run in CI; what does not ship is the *guarantee* that Slack is receiving anything.

Docs therefore say **"wired; fail-quiet until `SLACK_WEBHOOK_URL` exists"** — never "Slack notifications are live". The live proof is an operator-gated acceptance recorded in `operator-expected.md`: the founder sets the secret, and the **next push to main** posts the first message. If it does not, the run's `slack-notify` job log carries the `::notice::`/`::warning::` that says why, by construction. (Guarantee-vs-mechanism separation — the S020 rule, and the reason this ADR refuses to write a green checkmark it has not earned.)

## Consequences

- **Gains:** the post-merge main red finally has a reader; the release lane's fail-closed signing boundary announces itself; one tested notifier instead of four drifting copies; the repo's first CI-owned secret arrives with its scope (repository, not environment) written down before it is set wrong.
- **Costs:** one extra ubuntu job per run (~15s, checkout + POST); a new founder task (mint the webhook) that blocks nothing.
- **Risks accepted:** (1) the noise policy is a judgment call — if the founder wants PR successes too, it is a one-line `if:` edit (D2). (2) The notifier's live path is unexercised until the secret exists — mitigated by the dry-run self-tests, and bounded honestly in D7. (3) A webhook URL is a bearer credential: anyone holding it can post to the channel. It lives in GitHub Actions secrets (masked in logs, unreadable by fork PRs) and the anti-leak sentinel pins that the script never prints it; rotation, if ever needed, is `gh secret set` over the same name.
