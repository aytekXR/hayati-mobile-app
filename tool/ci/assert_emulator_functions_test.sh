#!/usr/bin/env bash
#
# assert_emulator_functions_test.sh — the self-test for
# assert_emulator_functions.sh (ADR-055, issue #208).
#
# Runs in the ubuntu `quality` job. Hermetic: it drives the script against a
# REAL local HTTP listener whose status codes it controls, the same shape
# `slack_notify_test.sh` uses — because a probe asserted only against
# "connection refused" would pass an implementation that never parsed a status
# code at all.
#
# The codes are not invented. Measured against a live functions emulator:
#   createInvite (callable, loaded)   -> 400   (it wants a POST body)
#   exportData   (callable, loaded)   -> 400
#   answerReveal (Firestore trigger)  -> 404   (never HTTP-addressable)
#   doesNotExist                      -> 404
# so "not 404" is the loaded test, and triggers must never be probed.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$SCRIPT_DIR/assert_emulator_functions.sh"
TMP="$(mktemp -d)"
SERVER_PID=""
cleanup() {
  [ -n "$SERVER_PID" ] && kill "$SERVER_PID" 2>/dev/null
  rm -rf "$TMP"
}
trap cleanup EXIT

pass=0
fail=0
ok()  { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n' "$1" >&2; [ $# -lt 2 ] || printf '       %s\n' "$2" >&2; }

echo "assert_emulator_functions_test"

# A listener that answers 400 for names in LOADED and 404 for everything else —
# i.e. it impersonates the emulator's measured behaviour rather than a guess.
cat >"$TMP/server.py" <<'PY'
import http.server, os, sys

LOADED = set(os.environ.get('LOADED', '').split())

class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        name = self.path.rstrip('/').split('/')[-1]
        self.send_response(400 if name in LOADED else 404)
        self.end_headers()
    def log_message(self, *a):
        pass

port = int(sys.argv[1])
http.server.HTTPServer(('127.0.0.1', port), H).serve_forever()
PY

PORT=8931
LOADED="createInvite exportData" python3 "$TMP/server.py" "$PORT" &
SERVER_PID=$!
for _ in $(seq 1 50); do
  curl -s -o /dev/null "http://127.0.0.1:$PORT/x/y/z" && break
  sleep 0.1
done

BASE="http://127.0.0.1:$PORT"

run() {
  OUT="$TMP/out"
  bash "$SCRIPT" "$@" >"$OUT" 2>&1
  CODE=$?
}

# ---------------------------------------------------------------------------
# 1. The healthy case. Asserted FIRST and separately, because a script that
#    always exited 1 would pass every "detects the failure" check below.
# ---------------------------------------------------------------------------
run "$BASE" demo-hayati europe-west1 createInvite exportData
if [ "$CODE" -ne 0 ]; then
  bad "loaded callables -> exit 0" "code=$CODE: $(cat "$OUT")"
else
  ok "loaded callables -> exit 0"
fi
if ! grep -q 'loaded' "$OUT"; then
  bad "healthy path says which callables it checked"
else
  ok "healthy path says which callables it checked"
fi

# ---------------------------------------------------------------------------
# 2. The failure this exists for: the emulator serving NOTHING.
# ---------------------------------------------------------------------------
run "$BASE" demo-hayati europe-west1 createInvite notLoadedAtAll
if [ "$CODE" -ne 1 ]; then
  bad "an unloaded callable -> exit 1" "code=$CODE"
else
  ok "an unloaded callable -> exit 1"
fi
if ! grep -q 'notLoadedAtAll' "$OUT"; then
  bad "the failure NAMES the missing function" "$(cat "$OUT")"
else
  ok "the failure names the missing function"
fi
if ! grep -q 'discovery timeout\|Cannot determine backend' "$OUT"; then
  bad "the failure points at the real cause, not just the symptom"
else
  ok "the failure points at the real cause (discovery timeout)"
fi
if ! grep -q '::error title=' "$OUT"; then
  bad "emits a GitHub error annotation"
else
  ok "emits a GitHub error annotation"
fi
# The loaded one must still be reported as loaded — a probe that gave up on the
# first miss would hide how much is actually broken.
if ! grep -q 'createInvite -> HTTP 400  loaded' "$OUT"; then
  bad "probes EVERY name, not just up to the first failure" "$(cat "$OUT")"
else
  ok "probes every name, not just up to the first failure"
fi

# ---------------------------------------------------------------------------
# 3. An unreachable emulator is a DIFFERENT failure from a loaded-nothing one,
#    and must not be silently reported as the same thing.
# ---------------------------------------------------------------------------
run "http://127.0.0.1:9" demo-hayati europe-west1 createInvite
if [ "$CODE" -ne 1 ]; then
  bad "an unreachable emulator -> exit 1" "code=$CODE"
else
  ok "an unreachable emulator -> exit 1"
fi
if ! grep -q 'unreachable' "$OUT"; then
  bad "an unreachable emulator says 'unreachable', not 'not loaded'" "$(cat "$OUT")"
else
  ok "an unreachable emulator is named as unreachable, not as unloaded"
fi

# ---------------------------------------------------------------------------
# 4. Usage errors fail loud (2), never 0. A precondition that silently passes
#    when misconfigured is worse than absent: it reads as verification.
# ---------------------------------------------------------------------------
run "$BASE" demo-hayati europe-west1
if [ "$CODE" -ne 2 ]; then
  bad "no callables listed -> exit 2" "code=$CODE"
else
  ok "no callables listed -> exit 2"
fi

# ---------------------------------------------------------------------------
echo
if [ "$fail" -gt 0 ]; then
  printf 'assert_emulator_functions_test: %d passed, %d FAILED\n' "$pass" "$fail" >&2
  exit 1
fi
printf 'assert_emulator_functions_test: %d passed.\n' "$pass"
