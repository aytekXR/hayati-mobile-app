#!/usr/bin/env bash
#
# slack_notify_test.sh — the self-test for slack_notify.sh (ADR-024 D1).
#
# Runs in the ubuntu `quality` job, before `pub get` (bash + jq + python3 only,
# no Dart SDK, no pubspec). Hermetic: no network, no Slack, no secrets.
#
# This suite is the ONLY thing standing between the notifier and the classic
# shell-script failure mode — it works on the author's machine, ships, and then
# silently posts nothing (or posts garbage) for months, because nothing in CI
# ever executed it. Every property ADR-024 claims is asserted here, and each
# assertion is written to FAIL against a plausible wrong implementation, not
# merely to pass against the right one:
#
#   - the absent-secret path asserts ::notice:: is PRESENT (a "no ::warning::"
#     check alone is satisfied by a script that prints nothing at all);
#   - the failed-jobs assertion checks a failed job IS named AND a skipped job
#     is NOT (a one-sided check passes an implementation that dropped the
#     select() filter and lists every job — the reference's actual drift bug);
#   - the POST path is exercised against a REAL local HTTP listener, because
#     dry-run and connection-refused both bypass curl's HTTP flags entirely: a
#     missing Content-Type header or a broken --data handoff would pass a
#     suite built only from those two.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$SCRIPT_DIR/slack_notify.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pass=0
fail=0

ok()   { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad()  { fail=$((fail + 1)); printf '  FAIL %s\n' "$1" >&2; [ $# -lt 2 ] || printf '       %s\n' "$2" >&2; }

# Runs the notifier with a clean environment: only what the caller passes.
# stdout -> $OUT, stderr -> $ERR, exit code -> $CODE.
run() {
  OUT="$TMP/out"; ERR="$TMP/err"
  env -i PATH="$PATH" HOME="$HOME" "$@" bash "$SCRIPT" >"$OUT" 2>"$ERR"
  CODE=$?
  STDOUT="$(cat "$OUT")"
  STDERR="$(cat "$ERR")"
}

# A needs fixture: all four ci.yml jobs, results as given.
needs() {
  jq -n --arg q "$1" --arg f "$2" --arg i "$3" --arg e "$4" '{
    quality: {result: $q}, "functions-rules": {result: $f},
    "ios-build-smoke": {result: $i}, "integration-emulator": {result: $e}}'
}

ALL_GREEN="$(needs success success success success)"
# The shape a real docs-only push to main produces (ci-debt #17).
DOCS_ONLY="$(needs success success skipped skipped)"
# The shape a red `quality` produces: everything downstream is SKIPPED, not failed.
QUALITY_RED="$(needs failure skipped skipped skipped)"
CANCELLED="$(needs success cancelled cancelled skipped)"

# The metacharacter fixture, applied to every attacker-influenced field. If any
# of these reaches a shell or a jq program unquoted, this string is what breaks
# it: quote, backslash, command substitution, backticks, newline.
# The single quotes are the whole point — this text must stay LITERAL here and
# all the way through the notifier, so it is exactly what must NOT expand.
# shellcheck disable=SC2016
NASTY='he said "hi" \ $(id) `whoami` && rm -rf /
second line of the body'

echo "slack_notify_test: $SCRIPT"

# ---------------------------------------------------------------------------
# 1. Absent secret => ::notice::, no POST, exit 0. (D3)
# ---------------------------------------------------------------------------
run NEEDS_JSON="$ALL_GREEN" GITHUB_EVENT_NAME=push GITHUB_REF_NAME=main
if [ "$CODE" -ne 0 ]; then
  bad "absent secret: exits 0" "exit=$CODE"
elif ! grep -q '::notice::' <<<"$STDOUT"; then
  bad "absent secret: emits ::notice::" "stdout=$STDOUT"
elif grep -q '::warning::' <<<"$STDOUT$STDERR"; then
  bad "absent secret: emits NO ::warning:: (issue #39's annotation-noise class)" "stdout=$STDOUT"
else
  ok "absent secret => ::notice:: + exit 0, no warning annotation"
fi

# ---------------------------------------------------------------------------
# 2. Payload is well-formed JSON, and every metacharacter survives as LITERAL
#    text — in the commit subject, the branch name and the actor alike. (D1)
# ---------------------------------------------------------------------------
run SLACK_DRY_RUN=1 NEEDS_JSON="$ALL_GREEN" GITHUB_EVENT_NAME=push \
    COMMIT_TITLE="$NASTY" GITHUB_REF_NAME="$NASTY" GITHUB_ACTOR="$NASTY" \
    GITHUB_REPOSITORY="aytek/hayati" GITHUB_WORKFLOW="ci" HEAD_SHA="abc1234def"
if [ "$CODE" -ne 0 ]; then
  bad "metacharacters: exits 0" "exit=$CODE / stderr=$STDERR"
elif ! jq -e . >/dev/null 2>&1 <<<"$STDOUT"; then
  bad "metacharacters: payload is valid JSON" "stdout=$STDOUT"
else
  text="$(jq -r '.text' <<<"$STDOUT")"
  # The needles are single-quoted on purpose: they must stay LITERAL. A directive
  # in front of the `if` covers the whole compound command (it is not valid in
  # front of an individual elif branch).
  # shellcheck disable=SC2016
  if ! grep -qF '$(id)' <<<"$text"; then
    bad "metacharacters: \$(id) survives as literal text (no command substitution)" "text=$text"
  elif ! grep -qF '`whoami`' <<<"$text"; then
    bad "metacharacters: backticks survive as literal text" "text=$text"
  elif ! grep -qF 'he said "hi"' <<<"$text"; then
    bad "metacharacters: double quotes survive (no JSON break-out)" "text=$text"
  elif grep -q 'uid=' <<<"$text"; then
    bad "metacharacters: COMMAND SUBSTITUTION EXECUTED — injection hole" "text=$text"
  else
    ok "metacharacters in subject/branch/actor => valid JSON, literal text, no execution"
  fi
fi

# ---------------------------------------------------------------------------
# 3. Only the FIRST line of a multi-line commit subject is sent, and multibyte
#    TR/AR text survives. (This repo's commit subjects are Turkish and Arabic.)
# ---------------------------------------------------------------------------
run SLACK_DRY_RUN=1 NEEDS_JSON="$ALL_GREEN" GITHUB_EVENT_NAME=push \
    COMMIT_TITLE=$'feat(m6): oturum başlığı — عربى ✅\n\nbody line that must not ship'
text="$(jq -r '.text' <<<"$STDOUT" 2>/dev/null)"
if ! grep -qF 'oturum başlığı — عربى ✅' <<<"$text"; then
  bad "first-line: multibyte TR/AR subject survives intact" "text=$text"
elif grep -qF 'body line that must not ship' <<<"$text"; then
  bad "first-line: the commit BODY is not sent" "text=$text"
else
  ok "first line only; multibyte TR/AR subject intact"
fi

# ---------------------------------------------------------------------------
# 4. The failure payload names the failed jobs AND ONLY the failed jobs.
#    (The reference's drift bug, pinned in both directions.)
# ---------------------------------------------------------------------------
run SLACK_DRY_RUN=1 NEEDS_JSON="$QUALITY_RED" GITHUB_EVENT_NAME=push \
    GITHUB_REPOSITORY="aytek/hayati" GITHUB_RUN_ID=123 GITHUB_SERVER_URL="https://github.com"
text="$(jq -r '.text' <<<"$STDOUT" 2>/dev/null)"
failed_line="$(grep '^Failed:' <<<"$text")"
if ! grep -q '❌' <<<"$text"; then
  bad "failure: a red quality with a skipped cascade reports FAILURE" "text=$text"
elif ! grep -qF 'quality' <<<"$failed_line"; then
  bad "failure: names the failed job" "failed=$failed_line"
elif grep -qF 'functions-rules' <<<"$failed_line"; then
  bad "failure: names ONLY failed jobs — a skipped job leaked into the failed list" "failed=$failed_line"
elif ! grep -qF 'https://github.com/aytek/hayati/actions/runs/123' <<<"$text"; then
  bad "failure: carries the run URL" "text=$text"
else
  ok "failure names the failed jobs and only those; carries the run URL"
fi

# ---------------------------------------------------------------------------
# 5. The per-job result line — what keeps the main-push success message honest
#    on a docs-only push (both macOS jobs skipped, ci-debt #17).
# ---------------------------------------------------------------------------
run SLACK_DRY_RUN=1 NEEDS_JSON="$DOCS_ONLY" GITHUB_EVENT_NAME=push
text="$(jq -r '.text' <<<"$STDOUT" 2>/dev/null)"
if ! grep -qF 'integration-emulator ⏭' <<<"$text"; then
  bad "per-job line: a SKIPPED integration-emulator is shown as skipped, not implied green" "text=$text"
elif ! grep -qF 'quality ✅' <<<"$text"; then
  bad "per-job line: a successful job is shown" "text=$text"
else
  ok "per-job result line distinguishes skipped from green (the docs-only push)"
fi

# ---------------------------------------------------------------------------
# 6. The noise policy (D2) — the whole reason this lives in the script and not
#    in a YAML `if:` the self-test cannot see.
# ---------------------------------------------------------------------------
run SLACK_DRY_RUN=1 NEEDS_JSON="$ALL_GREEN" GITHUB_EVENT_NAME=pull_request
if [ "$CODE" -ne 0 ]; then
  bad "noise policy: PR success exits 0" "exit=$CODE"
elif [ -n "$(jq -r '.text' <<<"$STDOUT" 2>/dev/null)" ]; then
  bad "noise policy: a SUCCESSFUL PR run must produce NO payload" "stdout=$STDOUT"
else
  ok "noise policy: PR success is silent (the session already watches gh pr checks)"
fi

run SLACK_DRY_RUN=1 NEEDS_JSON="$ALL_GREEN" GITHUB_EVENT_NAME=push
if ! jq -e '.text' >/dev/null 2>&1 <<<"$STDOUT"; then
  bad "noise policy: the SAME needs on a push to main DOES notify" "stdout=$STDOUT"
else
  ok "noise policy: push success notifies (it carries the post-merge verdict)"
fi

run SLACK_DRY_RUN=1 NEEDS_JSON="$QUALITY_RED" GITHUB_EVENT_NAME=pull_request
if ! jq -e '.text' >/dev/null 2>&1 <<<"$STDOUT"; then
  bad "noise policy: a FAILING PR always notifies" "stdout=$STDOUT"
else
  ok "noise policy: PR failure notifies (failures are never suppressed)"
fi

run SLACK_DRY_RUN=1 NEEDS_JSON="$CANCELLED" GITHUB_EVENT_NAME=push
if [ "$CODE" -ne 0 ]; then
  bad "noise policy: a cancelled run exits 0" "exit=$CODE"
elif [ -n "$(jq -r '.text' <<<"$STDOUT" 2>/dev/null)" ]; then
  bad "noise policy: a cancelled run is not an event — no payload" "stdout=$STDOUT"
else
  ok "noise policy: cancelled runs are silent"
fi

# ---------------------------------------------------------------------------
# 7. The PR-event SHA is the branch head, not the ephemeral merge commit. (D5)
#    GITHUB_SHA on a pull_request run points at a commit that exists in no
#    branch and no `git log` the founder can run.
# ---------------------------------------------------------------------------
run SLACK_DRY_RUN=1 NEEDS_JSON="$QUALITY_RED" GITHUB_EVENT_NAME=pull_request \
    GITHUB_SHA="ffffffffffffffff" HEAD_SHA="a1b2c3d4e5f6"
text="$(jq -r '.text' <<<"$STDOUT" 2>/dev/null)"
if grep -qF 'fffffff' <<<"$text"; then
  bad "PR SHA: the ephemeral MERGE commit must not be reported" "text=$text"
elif ! grep -qF 'a1b2c3d' <<<"$text"; then
  bad "PR SHA: the branch head SHA is reported" "text=$text"
else
  ok "PR SHA is the branch head, not the unlookable merge commit"
fi

# ---------------------------------------------------------------------------
# 8. ANTI-LEAK SENTINEL. This is the one script in the repo that holds a secret
#    in a variable; "it never prints it" is a guarantee that gets a test.
#
#    It is asserted on EVERY path that holds the secret, not just the dry-run
#    one. A dry-run-only sentinel is theatre: dry-run exits BEFORE the POST, so
#    it never executes the lines where the URL is actually in scope. Mutation
#    testing proved exactly that — a mutant appending "$SLACK_WEBHOOK_URL" to the
#    post-delivery log line SURVIVED a dry-run-only sentinel. The canary is
#    therefore re-checked on the successful-POST path (test 11) and the
#    failed-POST path (test 10) below.
# ---------------------------------------------------------------------------
CANARY="xxxxSECRETxxxxLEAKCANARY"
SECRET_URL="https://hooks.slack.com/services/T00LEAKTEST/B00LEAKTEST/$CANARY"

# assert_no_leak <label> — the current $STDOUT/$STDERR must not contain the
# webhook, in whole or in part.
assert_no_leak() {
  if grep -qF "$SECRET_URL" <<<"$STDOUT$STDERR" || grep -qF "$CANARY" <<<"$STDOUT$STDERR"; then
    bad "anti-leak ($1): the webhook must appear in NEITHER stdout NOR stderr" "LEAKED"
    return 1
  fi
  return 0
}

run SLACK_DRY_RUN=1 SLACK_WEBHOOK_URL="$SECRET_URL" NEEDS_JSON="$QUALITY_RED" GITHUB_EVENT_NAME=push
if assert_no_leak "dry-run"; then
  ok "anti-leak sentinel (dry-run path): the webhook value never reaches stdout or stderr"
fi

# ---------------------------------------------------------------------------
# 9. jq missing => ::warning:: + exit 0. (D3's tool-missing invariant, pinned
#    rather than merely asserted. PATH is emptied; every command before the jq
#    check is a bash builtin, so this reaches the guard.)
# ---------------------------------------------------------------------------
OUT="$TMP/out"; ERR="$TMP/err"
# "$BASH" (the absolute path of the running shell), not `bash`: with PATH emptied,
# `env` itself could not FIND bash and would exit 127 before the script ever ran —
# which would make this test pass for the wrong reason on a broken script and fail
# on a correct one.
env -i PATH="/nonexistent" NEEDS_JSON="$ALL_GREEN" GITHUB_EVENT_NAME=push \
  "$BASH" "$SCRIPT" >"$OUT" 2>"$ERR"
CODE=$?
if [ "$CODE" -ne 0 ]; then
  bad "jq missing: exits 0 (never reds the build)" "exit=$CODE"
elif ! grep -q '::warning::' "$OUT"; then
  bad "jq missing: emits ::warning::" "stdout=$(cat "$OUT")"
elif ! grep -qi 'jq' "$OUT"; then
  # The warning must NAME jq. Without the explicit guard the script still warns
  # and exits 0 — but via the NEEDS_JSON parse check, blaming "NEEDS_JSON is not
  # valid JSON" for what is really a missing binary. Mutation testing found that
  # equivalence; a misleading diagnostic sends the next session hunting the wrong
  # bug, so the message is pinned, not just the exit code.
  bad "jq missing: the warning must NAME jq, not blame NEEDS_JSON" "stdout=$(cat "$OUT")"
else
  ok "jq missing => ::warning:: naming jq + exit 0"
fi

# ---------------------------------------------------------------------------
# 10. A POST that fails => ::warning:: + exit 0, never a red. Hermetic: port 9
#     (discard) refuses the connection immediately; curl does not retry a
#     connection-refused, so this is fast and offline.
# ---------------------------------------------------------------------------
run SLACK_WEBHOOK_URL="http://127.0.0.1:9/$CANARY" NEEDS_JSON="$QUALITY_RED" GITHUB_EVENT_NAME=push
if [ "$CODE" -ne 0 ]; then
  bad "POST failure: exits 0 — a notifier must never red a green build (D3)" "exit=$CODE"
elif ! grep -q '::warning::' <<<"$STDOUT"; then
  bad "POST failure: emits ::warning:: (visible, never fatal)" "stdout=$STDOUT"
elif assert_no_leak "failed-POST path"; then
  # curl's own error text is the classic leak vector here — it is happy to echo
  # the URL it could not reach.
  ok "POST failure => ::warning:: + exit 0, and the URL does not leak via curl's error output"
fi

# ---------------------------------------------------------------------------
# 11. THE REAL POST PATH, against a hermetic local listener.
#     Every other test here runs under SLACK_DRY_RUN=1 (curl never invoked) or
#     against a refused connect (curl dies before sending a byte). Neither
#     exercises curl's HTTP flags — so a missing Content-Type, a wrong method,
#     or a broken `--data @-` handoff would pass this entire suite and then fail
#     silently, with nothing but a ::warning:: in a log nobody reads, on the
#     founder's very first real message.
# ---------------------------------------------------------------------------
CAPTURE="$TMP/captured.json"
PORTFILE="$TMP/port"
python3 - "$CAPTURE" "$PORTFILE" <<'PY' &
import http.server, json, sys

capture_path, port_path = sys.argv[1], sys.argv[2]

class H(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        n = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(n).decode('utf-8', 'replace')
        with open(capture_path, 'w') as f:
            json.dump({'method': self.command,
                       'ctype': self.headers.get('Content-Type', ''),
                       'body': body}, f)
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b'ok')

    def log_message(self, *a):
        pass

srv = http.server.HTTPServer(('127.0.0.1', 0), H)
# A BOUND, not a nicety: handle_request() blocks forever if the notifier never
# POSTs (a broken script, a missing curl). Without this the suite would HANG the
# quality job to its 20-minute timeout instead of failing it in seconds — a
# hanging test is worse than a failing one. On timeout the handler simply never
# runs, no capture file is written, and the assertion below fails loudly.
srv.timeout = 20
with open(port_path, 'w') as f:
    f.write(str(srv.server_port))
srv.handle_request()
PY
LISTENER=$!

for _ in $(seq 1 50); do [ -s "$PORTFILE" ] && break; sleep 0.1; done
PORT="$(cat "$PORTFILE" 2>/dev/null)"

if [ -z "$PORT" ]; then
  bad "real POST: could not start the local listener" "no port"
else
  # The URL carries the canary so the SUCCESSFUL-POST path is anti-leak checked
  # too — that is the path a dry-run test can never reach, and the one a mutant
  # actually escaped through.
  run SLACK_WEBHOOK_URL="http://127.0.0.1:$PORT/services/$CANARY" NEEDS_JSON="$QUALITY_RED" \
      GITHUB_EVENT_NAME=push COMMIT_TITLE="real post path" GITHUB_REPOSITORY="aytek/hayati"
  wait "$LISTENER" 2>/dev/null

  if [ "$CODE" -ne 0 ]; then
    bad "real POST: exits 0" "exit=$CODE / stderr=$STDERR"
  elif grep -q '::warning::' <<<"$STDOUT"; then
    bad "real POST: a 200 response must not warn" "stdout=$STDOUT"
  elif ! assert_no_leak "successful-POST path"; then
    : # assert_no_leak already reported it
  elif [ ! -s "$CAPTURE" ]; then
    bad "real POST: the listener received NOTHING — curl never sent the request" ""
  else
    method="$(jq -r '.method' "$CAPTURE")"
    ctype="$(jq -r '.ctype' "$CAPTURE")"
    body="$(jq -r '.body' "$CAPTURE")"
    if [ "$method" != "POST" ]; then
      bad "real POST: HTTP method is POST" "method=$method"
    elif [ "$ctype" != "application/json" ]; then
      bad "real POST: Content-Type: application/json (Slack rejects anything else)" "ctype=$ctype"
    elif ! jq -e '.text' >/dev/null 2>&1 <<<"$body"; then
      bad "real POST: the body is valid JSON carrying a .text key" "body=$body"
    elif ! grep -qF 'real post path' <<<"$body"; then
      bad "real POST: the body carries the actual payload" "body=$body"
    else
      ok "real POST: correct method, Content-Type and JSON body reach the wire"
    fi
  fi
fi

# ---------------------------------------------------------------------------
echo
if [ "$fail" -gt 0 ]; then
  printf 'slack_notify_test: %d passed, %d FAILED\n' "$pass" "$fail" >&2
  exit 1
fi
printf 'slack_notify_test: %d passed.\n' "$pass"
