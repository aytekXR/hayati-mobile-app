#!/usr/bin/env bash
#
# slack_notify.sh — the CI → Slack side-channel notifier (ADR-024).
#
# ONE source for both workflows (ci.yml, release.yml). The reference this was
# modelled on (ams-pulse) pastes the same 30 lines into four workflows, and the
# copies have already drifted — two of them report the NOTIFYING job's name
# instead of what actually broke. Hence one script, with a self-test
# (slack_notify_test.sh) that the ubuntu `quality` job runs.
#
# THE BINDING INVARIANT (ADR-024 D3): this is a side-channel. It has NO VOTE on
# whether the build passed. Every error path here exits 0 — a missed Slack
# message must never turn a green build red. (The other half of that guarantee
# is `continue-on-error: true` on the job, which covers failures BEFORE this
# script starts — a failed checkout, a dead runner. Neither half is sufficient
# alone.)
#
# W4 EXCEPTION, RECORDED (ADR-024 D3.1): agent-workflows.md W4 forbids silent
# retries and `|| true` in CI. W4 governs steps that produce a PRIMARY signal —
# a build, a test, a lint — where swallowing a failure hides a real code
# outcome. A notifier produces no primary signal and can mask no test result: a
# missed POST is a missed notification, not a hidden failure. The exception is
# bounded to THIS FILE and is not a precedent for `exit 0` anywhere else in CI.
#
# ALL INPUT ARRIVES BY ENVIRONMENT VARIABLE. No positional arguments, no `${{ }}`
# interpolation, and no shell variable is ever interpolated into a jq PROGRAM
# string — the commit subject, PR title, branch name and actor are all
# attacker-influenced text, and they reach the payload only through `jq --arg`.
#
# Inputs (all optional unless noted):
#   SLACK_WEBHOOK_URL  the Incoming Webhook. Absent => quiet skip (D3).
#   NEEDS_JSON         `toJson(needs)` — REQUIRED; the outcome is derived from it.
#   COMMIT_TITLE       `head_commit.message || pull_request.title || ''`
#   HEAD_SHA           `pull_request.head.sha || github.sha` (D5: on a PR,
#                      GITHUB_SHA is the ephemeral merge commit — unlookable).
#   SLACK_DRY_RUN=1    build + print the payload, POST nothing (what makes this
#                      testable at all).
#   plus the runner defaults: GITHUB_{REPOSITORY,WORKFLOW,REF_NAME,ACTOR,RUN_ID,
#                      SERVER_URL,EVENT_NAME,SHA}
#
# NOT `set -e`: every failure is handled explicitly and ends in `exit 0`. `set -e`
# would defeat that on the first unhandled non-zero.
set -uo pipefail

# ---------------------------------------------------------------------------
# Annotation helpers. `::notice::` for "nothing to do here" (a repo with no
# webhook is not a broken repo); `::warning::` for "something is wrong but it is
# not the build's fault". NEVER `::error::` — that is a primary-signal channel.
# ---------------------------------------------------------------------------
notice()  { echo "::notice::slack_notify: $*"; }
warn()    { echo "::warning::slack_notify: $*"; }
info()    { echo "slack_notify: $*"; }

# ---------------------------------------------------------------------------
# 1. jq is the payload builder — without it there is nothing safe to construct.
# ---------------------------------------------------------------------------
if ! command -v jq >/dev/null 2>&1; then
  warn "jq not found on PATH — no notification sent."
  exit 0
fi

# ---------------------------------------------------------------------------
# 2. Derive the outcome from needs (ADR-024 D2 — the policy lives HERE, in
#    testable code, not in a YAML `if:` the self-test cannot see).
#
#      failure   any need failed (a `skipped` cascade downstream of it is
#                normal and must not mask it)
#      cancelled no failure, but something was cancelled (a superseded run is
#                not an event)
#      success   everything else — `skipped` reads as what it is, so a PR whose
#                integration-emulator never ran is still a success
# ---------------------------------------------------------------------------
needs_json="${NEEDS_JSON:-}"
if [ -z "$needs_json" ] || ! printf '%s' "$needs_json" | jq -e . >/dev/null 2>&1; then
  warn "NEEDS_JSON is missing or not valid JSON — no notification sent."
  exit 0
fi

results="$(printf '%s' "$needs_json" | jq -r '[.[].result] | join(" ")')"
outcome="success"
case " $results " in
  *" failure "*)   outcome="failure" ;;
  *" cancelled "*) outcome="cancelled" ;;
esac

if [ "$outcome" = "cancelled" ]; then
  info "run was cancelled (superseded or aborted) — not an event, no notification (D2)."
  exit 0
fi

# The noise policy, in one guard (ADR-024 D2): a session watches its own PR with
# `gh pr checks`, so a green PR has a reader already. Posting it anyway is how a
# channel becomes 90% noise and gets muted — and a muted channel swallows the
# post-merge main red this whole integration exists to deliver.
# To get the reference's every-run behaviour, delete this block; the self-test
# will fail immediately, which is the point.
if [ "$outcome" = "success" ] && [ "${GITHUB_EVENT_NAME:-}" = "pull_request" ]; then
  info "PR success — suppressed by the noise policy (D2); the session is already watching."
  exit 0
fi

# ---------------------------------------------------------------------------
# 3. Build the payload. Every dynamic field goes through `jq --arg`; the jq
#    program strings below contain no shell expansion.
# ---------------------------------------------------------------------------

# Per-job result line. This is what keeps the main-push success message honest:
# a docs-only close commit skips both 10x-billed macOS jobs (ci-debt #17), and
# the message SHOWS that rather than implying an integration-emulator verdict it
# never had.
jobs_line="$(printf '%s' "$needs_json" | jq -r '
  to_entries
  | map(.key + " " + (
      if   .value.result == "success"   then "✅"
      elif .value.result == "failure"   then "❌"
      elif .value.result == "skipped"   then "⏭"
      elif .value.result == "cancelled" then "⏹"
      else (.value.result // "?") end))
  | join(" · ")')"

# The failed jobs, and ONLY the failed jobs. Dropping the select() here is the
# exact drift bug in the reference; the self-test asserts both that a failed job
# IS named and that a skipped one is NOT.
failed_jobs="$(printf '%s' "$needs_json" | jq -r '
  [to_entries[] | select(.value.result == "failure") | .key] | join(", ")')"

# First line only, CR stripped (a commit body must not become a Slack essay).
subject="$(printf '%s' "${COMMIT_TITLE:-}" | tr -d '\r' | head -n 1)"
[ -n "$subject" ] || subject="(no commit subject)"

sha="${HEAD_SHA:-${GITHUB_SHA:-}}"
short_sha="${sha:0:7}"
[ -n "$short_sha" ] || short_sha="(unknown)"

run_url="${GITHUB_SERVER_URL:-https://github.com}/${GITHUB_REPOSITORY:-}/actions/runs/${GITHUB_RUN_ID:-}"
stamp="$(date -u '+%Y-%m-%d %H:%M UTC')"

# Two steps, deliberately: `${GITHUB_REPOSITORY##*/}` on an UNSET variable is an
# unbound-variable error under `set -u`, which would kill the command
# substitution below and ship an EMPTY message body while still exiting 0. The
# self-test caught exactly that. Default first, strip second.
repo_full="${GITHUB_REPOSITORY:-}"
repo_name="${repo_full##*/}"

if [ "$outcome" = "failure" ]; then
  headline="❌ CI failed"
else
  headline="✅ CI passed"
fi

text="$(printf '%s — %s / %s\n\nBranch: %s\nCommit: %s — %s\nActor: %s\nJobs: %s' \
  "$headline" "$repo_name" "${GITHUB_WORKFLOW:-}" \
  "${GITHUB_REF_NAME:-}" "$short_sha" "$subject" \
  "${GITHUB_ACTOR:-}" "$jobs_line")"

if [ "$outcome" = "failure" ] && [ -n "$failed_jobs" ]; then
  text="$(printf '%s\nFailed: %s' "$text" "$failed_jobs")"
fi

text="$(printf '%s\nRun: %s\nTime: %s' "$text" "$run_url" "$stamp")"

payload="$(jq -n --arg text "$text" '{text: $text}')"

# ---------------------------------------------------------------------------
# 4. Dry run: print the payload, POST nothing. This is what makes every property
#    above assertable by slack_notify_test.sh. Deliberately BEFORE the secret
#    check, so payload construction is testable without a webhook — and with one
#    set, the anti-leak sentinel proves the URL never reaches stdout/stderr.
# ---------------------------------------------------------------------------
if [ "${SLACK_DRY_RUN:-}" = "1" ]; then
  printf '%s\n' "$payload"
  exit 0
fi

# ---------------------------------------------------------------------------
# 5. No webhook => a clean, quiet skip (ADR-024 D3). NOT a warning: this repo
#    has no SLACK_WEBHOOK_URL until the founder mints one, and stamping a
#    ::warning:: on every green build until then is precisely the annotation
#    noise issue #39 was just cleaned up to remove. Fork PRs take this same path
#    by construction — secrets are structurally unavailable to them.
# ---------------------------------------------------------------------------
if [ -z "${SLACK_WEBHOOK_URL:-}" ]; then
  notice "SLACK_WEBHOOK_URL is not set — no notification sent (see docs/operator-expected.md)."
  exit 0
fi

if ! command -v curl >/dev/null 2>&1; then
  warn "curl not found on PATH — no notification sent."
  exit 0
fi

# --max-time RESETS on each retry attempt, so --max-time + --retry alone would
# bound this at ~47s, not 15 — --retry-max-time is the flag that actually caps
# the total. (--retry covers transient 5xx/429/timeouts; a connection-refused is
# not retried, which is what makes the dead-port self-test hermetic and fast.)
# -f => a 4xx/5xx is a non-zero exit with no body echoed; -s => no progress noise.
# The URL is passed last and never echoed; the payload arrives on stdin (--data @-)
# so it cannot land in a process listing either.
if printf '%s' "$payload" \
  | curl -sf -X POST \
      -H 'Content-Type: application/json' \
      --data @- \
      --max-time 15 --retry 2 --retry-delay 1 --retry-max-time 30 \
      "$SLACK_WEBHOOK_URL" >/dev/null 2>&1
then
  info "notification delivered ($outcome)."
  exit 0
fi

# Visible, never fatal (D3). The cause is not distinguishable here between a
# revoked webhook, a Slack 5xx, and a DNS failure — the job log is where that
# gets diagnosed, and the run stays green either way.
warn "the Slack POST failed (revoked webhook? Slack 5xx? DNS?) — the build result is unaffected."
exit 0
