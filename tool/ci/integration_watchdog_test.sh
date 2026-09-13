#!/usr/bin/env bash
#
# integration_watchdog_test.sh — the self-test for integration_watchdog.sh
# (ADR-055, issue #208).
#
# Runs in the ubuntu `quality` job (bash + python3 only; no Dart, no simulator,
# no emulator). Hermetic: every "suite" here is a `sleep` or an `echo`.
#
# WHAT THIS SUITE IS FOR, stated because the obvious version of it is useless.
# "The watchdog exits 124 on a hang" is satisfied by a script that exits 124 on
# EVERYTHING, and this repo has a standing habit of finding exactly that. So the
# three exit paths are asserted against each other:
#
#   * a passing command must exit 0 and its output must appear ONCE (the wrapper
#     tees live; an implementation that also dumped the capture file at the end
#     would double thousands of log lines, and only a count catches that);
#   * a failing command must keep ITS OWN status — 3, not 124 — or the watchdog
#     has converted every red suite into a fake timeout and destroyed the
#     diagnosis it exists to provide;
#   * only the wedged command may reach 124.
#
# THE ARITHMETIC GUARD at the bottom is the load-bearing one, and it is not
# about this script at all. The watchdog only works if it can fire BEFORE
# `timeout-minutes` cancels the job — that is the entire mechanism (ADR-055 D1:
# a cancelled job sends no Slack notification, a failed one does). If the
# configured bounds ever sum past the job timeout, the watchdog becomes
# unreachable and the job silently reverts to being CANCELLED with no
# notification — green tooling, dead guard, which is this repo's most familiar
# failure. So the sum is asserted against the workflow's own numbers, parsed
# from ci.yml rather than restated here.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCRIPT="$SCRIPT_DIR/integration_watchdog.sh"
WORKFLOW="$REPO_ROOT/.github/workflows/ci.yml"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pass=0
fail=0
ok()  { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n' "$1" >&2; [ $# -lt 2 ] || printf '       %s\n' "$2" >&2; }

# Runs the watchdog. stdout+stderr -> $OUT, exit code -> $CODE.
run() {
  OUT="$TMP/out"
  WATCHDOG_HEARTBEAT_SECONDS="${HB:-1}" bash "$SCRIPT" "$@" >"$OUT" 2>&1
  CODE=$?
}

echo "integration_watchdog_test"

# ---------------------------------------------------------------------------
# 1. The success path must be transparent.
# ---------------------------------------------------------------------------
run 10 ok-suite bash -c 'echo alpha; echo beta'
if [ "$CODE" -ne 0 ]; then
  bad "success: exits 0" "code=$CODE"
else
  ok "success: exits 0"
fi
alpha_count="$(grep -c '^alpha$' "$OUT" || true)"
if [ "$alpha_count" != "1" ]; then
  bad "success: child output appears exactly ONCE (tee, not tee+cat)" "saw $alpha_count"
else
  ok "success: child output appears exactly once"
fi
if ! grep -q 'finished in' "$OUT"; then
  bad "success: reports its own duration"
else
  ok "success: reports its own duration"
fi

# ---------------------------------------------------------------------------
# 2. A red suite keeps its own status. A watchdog that returns 124 here has
#    replaced every real failure with a fake timeout.
# ---------------------------------------------------------------------------
run 10 red-suite bash -c 'echo boom >&2; exit 3'
if [ "$CODE" -ne 3 ]; then
  bad "failure: propagates the child's OWN exit code" "want 3, got $CODE"
else
  ok "failure: propagates the child's own exit code (3, not 124)"
fi
if ! grep -q 'boom' "$OUT"; then
  bad "failure: the child's stderr still reaches the log"
else
  ok "failure: the child's stderr still reaches the log"
fi

# ---------------------------------------------------------------------------
# 3. The wedge. A SYNTHETIC hang — the real one is not reproducible, which
#    ADR-055 says out loud rather than implying this proves the incident.
# ---------------------------------------------------------------------------
run 3 wedged-suite bash -c 'echo starting; sleep 300'
if [ "$CODE" -ne 124 ]; then
  bad "hang: exits 124" "code=$CODE"
else
  ok "hang: exits 124"
fi
if ! grep -q "wedged-suite" "$OUT"; then
  bad "hang: NAMES the suite (the incident named nothing)"
else
  ok "hang: names the suite"
fi
if ! grep -q 'silent for' "$OUT"; then
  bad "hang: reports time-since-last-output, not just elapsed"
else
  ok "hang: reports time-since-last-output ('slow' vs 'wedged')"
fi
if ! grep -q 'last output line : starting' "$OUT"; then
  bad "hang: quotes the last line the suite produced" "$(tail -3 "$OUT")"
else
  ok "hang: quotes the last line the suite produced"
fi
if ! grep -q '::error title=' "$OUT"; then
  bad "hang: emits a GitHub error annotation"
else
  ok "hang: emits a GitHub error annotation"
fi
if ! grep -q 'emulator ports' "$OUT"; then
  bad "hang: probes the two things that can wedge"
else
  ok "hang: probes simulator + emulator state"
fi

# ---------------------------------------------------------------------------
# 4. The heartbeat, which is the whole answer to "38 minutes of silence".
#    A silent child must still produce lines.
# ---------------------------------------------------------------------------
beats="$(grep -c 'watchdog: wedged-suite —' "$OUT" || true)"
if [ "$beats" -lt 2 ]; then
  bad "heartbeat: a SILENT child still produces periodic lines" "saw $beats"
else
  ok "heartbeat: a silent child still produces periodic lines ($beats)"
fi

# ---------------------------------------------------------------------------
# 5. Argument validation fails LOUD (2), never silently succeeds. A watchdog
#    that accepts a bad bound and runs unbounded is worse than none: it reads
#    as protection.
# ---------------------------------------------------------------------------
for args in "0 lbl true" "abc lbl true" "-5 lbl true"; do
  # shellcheck disable=SC2086  # deliberate word-splitting of the arg fixture.
  run $args
  if [ "$CODE" -ne 2 ]; then
    bad "args: '$args' is rejected with 2" "got $CODE"
  else
    ok "args: '$args' is rejected with 2"
  fi
done
run 5 only-label
if [ "$CODE" -ne 2 ]; then
  bad "args: a missing command is rejected with 2" "got $CODE"
else
  ok "args: a missing command is rejected with 2"
fi

# ---------------------------------------------------------------------------
# 5b. THE BOUNDARY RACE, found by the ADR-055 design review.
#
# `kill -0` is tested at the top of the loop and then the loop sleeps a second,
# so a child that finished DURING that sleep — at an elapsed time that also
# crosses the bound — was reported as WEDGED. Measured before the fix: a command
# running 1.9s under a 2s bound and exiting 42 returned 124, three times out of
# three. A watchdog that calls a PASSING suite wedged reddens main for no reason
# and teaches everyone to distrust it, which is worse than not having one.
# ---------------------------------------------------------------------------
run 2 boundary-suite bash -c 'sleep 1.9; echo done; exit 42'
if [ "$CODE" -ne 42 ]; then
  bad "boundary: a child finishing just under the bound keeps ITS status" "want 42, got $CODE"
else
  ok "boundary: a child finishing just under the bound keeps its status (42, not 124)"
fi
# ...and the wedge must still be caught, or the fix has simply disabled the
# timeout. Asserted right here so the two can never drift apart.
run 2 boundary-wedge bash -c 'echo starting; sleep 300'
if [ "$CODE" -ne 124 ]; then
  bad "boundary: a genuine hang at the same bound is STILL 124" "got $CODE"
else
  ok "boundary: a genuine hang at the same bound is still 124"
fi

# ---------------------------------------------------------------------------
# 5c. The heartbeat interval is VALIDATED, like the timeout argument.
#
# Also from the review. The next-beat loop advances by this value, so 0 never
# passes `elapsed` and the watchdog spins forever — a job that hangs until
# `timeout-minutes` CANCELS it, i.e. exactly the outcome ADR-055 exists to
# prevent, produced by the tool meant to prevent it. Failure shape 5: a guard
# strict about one input and silent about another.
# ---------------------------------------------------------------------------
for hb in 0 abc -5; do
  OUT="$TMP/out"
  WATCHDOG_HEARTBEAT_SECONDS="$hb" timeout 8 bash "$SCRIPT" 10 hb-suite bash -c 'sleep 1' >"$OUT" 2>&1
  CODE=$?
  if [ "$CODE" -ne 2 ]; then
    bad "heartbeat: WATCHDOG_HEARTBEAT_SECONDS='$hb' is rejected with 2" "got $CODE"
  else
    ok "heartbeat: WATCHDOG_HEARTBEAT_SECONDS='$hb' is rejected with 2"
  fi
done

# EMPTY is NOT an error, and this asserts the distinction rather than leaving it
# to whichever behaviour the parameter expansion happened to give. `${VAR:-30}`
# treats empty exactly like unset, so `WATCHDOG_HEARTBEAT_SECONDS=` in a
# workflow means "use the default" — benign, and the opposite of `0`, which is
# a value the caller actively chose and which would spin forever.
OUT="$TMP/out"
WATCHDOG_HEARTBEAT_SECONDS="" timeout 8 bash "$SCRIPT" 10 hb-empty bash -c 'sleep 1' >"$OUT" 2>&1
CODE=$?
if [ "$CODE" -ne 0 ]; then
  bad "heartbeat: an EMPTY value falls back to the default, it is not an error" "got $CODE"
else
  ok "heartbeat: an empty value falls back to the default (unset, not zero)"
fi

# ---------------------------------------------------------------------------
# 5d. SILENCE IS THE GUARD (ADR-055 D2 revised).
#
# The wall-clock bound could not discriminate: runner speed alone moved the auth
# suite across 513/540/640/936 seconds — a 1.82x spread — while the incident
# differed from a healthy run by 7.6x on SILENCE (2280s vs 299s). These three
# assertions are the whole revision, and the middle one is the point: a slow
# runner must never be killed, however slow, as long as it is still printing.
# ---------------------------------------------------------------------------
OUT="$TMP/out"
WATCHDOG_HEARTBEAT_SECONDS=1 WATCHDOG_SILENCE_SECONDS=3 \
  bash "$SCRIPT" 9999 silent-suite bash -c 'echo starting; sleep 300' >"$OUT" 2>&1
CODE=$?
if [ "$CODE" -ne 124 ]; then
  bad "silence: a SILENT child is caught even with a huge wall-clock bound" "code=$CODE"
else
  ok "silence: a silent child is caught even with a huge wall-clock bound"
fi
if ! grep -q 'SILENT for' "$OUT"; then
  bad "silence: the report says SILENT, not 'exceeded its bound'" "$(tail -3 "$OUT")"
else
  ok "silence: the report distinguishes SILENT from a wall-clock overrun"
fi

# ⚠️ THE FALSE POSITIVE THAT MOTIVATED THE REVISION. This child runs far longer
# than the silence bound but never goes quiet. Under the old wall-clock guard a
# slow runner was reported as wedged; under this one it must survive.
OUT="$TMP/out"
WATCHDOG_HEARTBEAT_SECONDS=1 WATCHDOG_SILENCE_SECONDS=3 \
  bash "$SCRIPT" 9999 slow-suite bash -c 'for i in 1 2 3 4 5 6 7 8; do echo tick $i; sleep 1; done' >"$OUT" 2>&1
CODE=$?
if [ "$CODE" -ne 0 ]; then
  bad "silence: a SLOW but chatty child is NOT killed" "code=$CODE"
else
  ok "silence: a slow but chatty child is not killed (8s run, 3s silence bound)"
fi

# The wall-clock backstop must still exist — silence-only would let a suite that
# prints forever run to the ceiling and be CANCELLED, the original defect.
OUT="$TMP/out"
WATCHDOG_HEARTBEAT_SECONDS=1 WATCHDOG_SILENCE_SECONDS=9999 \
  bash "$SCRIPT" 3 backstop-suite bash -c 'while true; do echo tick; sleep 1; done' >"$OUT" 2>&1
CODE=$?
if [ "$CODE" -ne 124 ]; then
  bad "backstop: a forever-chatty child still hits the wall-clock bound" "code=$CODE"
else
  ok "backstop: a forever-chatty child still hits the wall-clock bound"
fi
if ! grep -q 'wall-clock backstop' "$OUT"; then
  bad "backstop: names itself as the backstop, not as silence" "$(tail -3 "$OUT")"
else
  ok "backstop: names itself as the backstop, not as silence"
fi

for sv in 0 abc; do
  OUT="$TMP/out"
  WATCHDOG_SILENCE_SECONDS="$sv" timeout 8 bash "$SCRIPT" 10 s bash -c 'sleep 1' >"$OUT" 2>&1
  CODE=$?
  if [ "$CODE" -ne 2 ]; then
    bad "silence: WATCHDOG_SILENCE_SECONDS='$sv' is rejected with 2" "got $CODE"
  else
    ok "silence: WATCHDOG_SILENCE_SECONDS='$sv' is rejected with 2"
  fi
done

# ---------------------------------------------------------------------------
# 5b. ⚠️ THE DEVICE-LOG CAPTURE (ADR-078).
#
# This box has no `xcrun` and a wedge cannot be scheduled — three occurrences in
# ~80 runs — so the capture is proven against a STUB `xcrun` placed first on
# PATH, exactly as D3 says. The stub records its arguments and prints a scripted
# device log, so the assertions below are about what the watchdog ASKED FOR and
# what it CONCLUDED, not about a real simulator.
#
# ⚠️ The mutations these exist to catch were enumerated in ADR-078 D3 BEFORE the
# guard was written (S102's lesson, paid for twice): delete the `log show` call;
# point it at a discovered device instead of $DEVICE_ID; swallow its output; let
# a missing `xcrun` escape as a non-124 exit; and — the one that decides whether
# ADR-078 is an instrument or a regression — let a HANGING `xcrun` block the
# path to `exit 124`.
# ---------------------------------------------------------------------------
stub_dir="$TMP/stub"
mkdir -p "$stub_dir"

# Runs the watchdog with a stubbed `xcrun` first on PATH and a fixed DEVICE_ID.
# GITHUB_WORKSPACE is redirected into $TMP so the capture file never lands in
# the repo during a test run.
run_stubbed() {
  OUT="$TMP/out"
  PATH="$stub_dir:$PATH" \
  DEVICE_ID="${STUB_DEVICE:-DEADBEEF-1234}" \
  GITHUB_WORKSPACE="$TMP" \
  WATCHDOG_HEARTBEAT_SECONDS=1 \
  WATCHDOG_SILENCE_SECONDS="${STUB_SILENCE:-2}" \
  WATCHDOG_DIAG_BOUND_SECONDS="${STUB_BOUND:-3}" \
  WATCHDOG_APP_BUNDLE_ID=com.example.stub \
    bash "$SCRIPT" 60 stub-suite bash -c 'sleep 30' >"$OUT" 2>&1
  CODE=$?
}

write_stub() {  # $1 = the device-log body the stub prints for `log show`
  cat >"$stub_dir/xcrun" <<STUB
#!/usr/bin/env bash
echo "\$*" >> "$TMP/xcrun-args"
case "\$*" in
  *"log show"*) cat <<'BODY'
$1
BODY
    ;;
  *launchctl*) echo "$STUB_LAUNCHCTL" ;;
  *) echo "(stub xcrun: \$*)" ;;
esac
STUB
  chmod +x "$stub_dir/xcrun"
}

# --- 5b.1 the URI line IS there -> the reader missed it -------------------
rm -f "$TMP/xcrun-args"
STUB_LAUNCHCTL="123 0 com.example.stub" write_stub 'app start
The Dart VM Service is listening on http://127.0.0.1:51234/abc=/
com.example.stub did a thing'
STUB_LAUNCHCTL="123 0 com.example.stub" run_stubbed

if [ "$CODE" -ne 124 ]; then
  bad "device-log: still exits 124 with the capture in place" "code=$CODE"
else
  ok "device-log: still exits 124 with the capture in place"
fi
if ! grep -q "log show" "$TMP/xcrun-args" 2>/dev/null; then
  bad "device-log: the timeout path asks for the device log" "$(cat "$TMP/xcrun-args" 2>/dev/null)"
else
  ok "device-log: the timeout path asks for the device log"
fi
# ⚠️ THE DEVICE MUST BE THE ONE IT WAS GIVEN. `simctl list devices booted` can
# return more than one, and the wrong simulator's log answers "no URI line" with
# total confidence about the wrong machine.
if ! grep -q "DEADBEEF-1234" "$TMP/xcrun-args" 2>/dev/null; then
  bad "device-log: queries \$DEVICE_ID, not a discovered device" "$(cat "$TMP/xcrun-args" 2>/dev/null)"
else
  ok "device-log: queries \$DEVICE_ID, not a discovered device"
fi
if ! grep -q "'VM Service listening': 1" "$OUT"; then
  bad "device-log: reports the URI line when it is present" "$(grep -i 'VM Service' "$OUT" || echo '(absent)')"
else
  ok "device-log: reports the URI line when it is present"
fi
# D1.2 — the control. Without these a broken query reads as a negative result.
if ! grep -q "lines (filtered)" "$OUT" || ! grep -q "lines (unfiltered)" "$OUT" \
   || ! grep -q "lines from the app" "$OUT"; then
  bad "device-log: prints the line counts that control the verdict (D1.2)" "$(grep -i 'lines' "$OUT" || echo '(absent)')"
else
  ok "device-log: prints the line counts that control the verdict (D1.2)"
fi
# D1.1 — the window must be DERIVED. A literal 300 would mean someone restored
# the `--last 5m` that misses the launch entirely.
if ! grep -qE "device log, last [0-9]+s" "$OUT"; then
  bad "device-log: prints the window it used (D1.1)" "$(grep -i 'device log' "$OUT" || echo '(absent)')"
else
  ok "device-log: prints the window it used (D1.1)"
fi

# --- 5b.2 no URI line -> the other rows -----------------------------------
# The app's own process is `Runner` — the count is over the PROCESS, not the
# bundle id, because on the first real wedge the bundle id appeared ZERO times
# in 770920 lines while the app was demonstrably running (ADR-078 D1.3).
rm -f "$TMP/xcrun-args"
NOWTS2="$(date -u '+%Y-%m-%d %H:%M:%S')"
STUB_LAUNCHCTL="" write_stub "$NOWTS2 Df Runner[9:9] app start, and nothing else happened"
STUB_LAUNCHCTL="" run_stubbed
if ! grep -q "'VM Service listening': 0" "$OUT"; then
  bad "device-log: reports ZERO when the URI line is absent" "$(grep -i 'VM Service' "$OUT" || echo '(absent)')"
else
  ok "device-log: reports ZERO when the URI line is absent"
fi
if ! grep -q "lines from the app   : 1" "$OUT"; then
  bad "device-log: counts the app's own lines" "$(grep -i 'from the app' "$OUT" || echo '(absent)')"
else
  ok "device-log: counts the app's own lines"
fi

# --- 5b.2b ⚠️ A CAPTURE THAT ENDS BEFORE THE SILENCE SAYS SO (ADR-078 D1.3) --
#
# THE lesson of the first real wedge. On run 34759401891 the capture asked for
# the right window, was killed by its own 30s bound mid-stream, and — because
# `log show` emits oldest-first — kept the slice FURTHEST from the launch. It
# then answered "no URI line" about a period it had never seen, while the line
# count (770920) satisfied the control. Asking for a window and GETTING it are
# two claims, and only the delivered timestamps can tell them apart.
rm -f "$TMP/xcrun-args"
STUB_LAUNCHCTL="123 0 com.example.stub" write_stub '1999-01-01 00:00:01 Df something[1:1] an ancient line'
STUB_LAUNCHCTL="123 0 com.example.stub" run_stubbed
if ! grep -q "CANNOT MEASURE" "$OUT"; then
  bad "device-log: a capture ending before the silence says CANNOT MEASURE" "$(grep -i verdict "$OUT" || echo '(no verdict line)')"
else
  ok "device-log: a capture ending before the silence says CANNOT MEASURE"
fi
if ! grep -q "window DELIVERED" "$OUT"; then
  bad "device-log: prints the DELIVERED window, not only the requested one" "$(grep -i window "$OUT" || echo '(absent)')"
else
  ok "device-log: prints the DELIVERED window, not only the requested one"
fi

# --- 5b.2c a capture that DOES cover the silence gives a real verdict -----
rm -f "$TMP/xcrun-args"
NOWTS="$(date -u '+%Y-%m-%d %H:%M:%S')"
STUB_LAUNCHCTL="123 0 com.example.stub" write_stub "$NOWTS Df Runner[9:9] The Dart VM Service is listening on http://127.0.0.1:1/x=/"
STUB_LAUNCHCTL="123 0 com.example.stub" run_stubbed
if grep -q "CANNOT MEASURE" "$OUT"; then
  bad "device-log: a covering capture is NOT reported as unmeasurable" "$(grep -i verdict "$OUT")"
elif ! grep -q "the app DID announce the VM Service" "$OUT"; then
  bad "device-log: a covering capture with the URI says the reader missed it" "$(grep -i verdict "$OUT" || echo '(absent)')"
else
  ok "device-log: a covering capture with the URI blames the reader, not the app"
fi

# --- 5b.3 ⚠️ A HANGING xcrun MUST NOT COST THE 124 (ADR-078 D2.1) ---------
#
# THE case. Every diagnostic runs against the same simulator that is already
# wedged. If one hangs, this script never reaches `exit 124`, the job runs to
# `timeout-minutes`, GitHub reports `cancelled`, and slack_notify.sh sends
# nothing BY DESIGN (ADR-024 D2) — the exact outcome ADR-055 exists to remove,
# reintroduced by the instrument built to explain it. `|| true` does not help:
# it swallows a status, it does not bound a hang.
rm -f "$TMP/xcrun-args"
cat >"$stub_dir/xcrun" <<'STUB'
#!/usr/bin/env bash
sleep 3600
STUB
chmod +x "$stub_dir/xcrun"
hang_start="$(date +%s)"
STUB_BOUND=2 run_stubbed
hang_elapsed=$(( $(date +%s) - hang_start ))
if [ "$CODE" -ne 124 ]; then
  bad "device-log: a HANGING xcrun still exits 124 (D2.1)" "code=$CODE after ${hang_elapsed}s"
else
  ok "device-log: a HANGING xcrun still exits 124 (D2.1)"
fi
if ! grep -q "stub-suite" "$OUT"; then
  bad "device-log: a hanging xcrun still NAMES the suite" "$(head -3 "$OUT")"
else
  ok "device-log: a hanging xcrun still NAMES the suite"
fi
# The bound must actually bound: three diagnostics x 2s, plus the 5s kill grace,
# must not approach the suite's own 60s wall clock.
if [ "$hang_elapsed" -ge 40 ]; then
  bad "device-log: the diagnostic bound actually bounds" "took ${hang_elapsed}s"
else
  ok "device-log: the diagnostic bound actually bounds (${hang_elapsed}s)"
fi

# --- 5b.4 no xcrun at all -> the ADR-055 guarantee is unchanged -----------
rm -f "$stub_dir/xcrun"
run_stubbed
if [ "$CODE" -ne 124 ]; then
  bad "device-log: no xcrun at all still exits 124" "code=$CODE"
else
  ok "device-log: no xcrun at all still exits 124"
fi

# --- 5b.5 no DEVICE_ID -> SKIP loudly, never guess a device ---------------
OUT="$TMP/out"
GITHUB_WORKSPACE="$TMP" WATCHDOG_HEARTBEAT_SECONDS=1 WATCHDOG_SILENCE_SECONDS=2 \
  bash "$SCRIPT" 60 stub-suite bash -c 'sleep 30' >"$OUT" 2>&1
CODE=$?
if [ "$CODE" -ne 124 ]; then
  bad "device-log: no DEVICE_ID still exits 124" "code=$CODE"
elif ! grep -q "DEVICE_ID is not set" "$OUT"; then
  bad "device-log: no DEVICE_ID says so instead of guessing a device" "$(tail -5 "$OUT")"
else
  ok "device-log: no DEVICE_ID says so instead of guessing a device"
fi

# ---------------------------------------------------------------------------
# 6. ⚠️ THE ARITHMETIC GUARD (ADR-055 D2).
#
#    The watchdog can only convert `cancelled` into `failure` if its bounds fire
#    before `timeout-minutes`. This parses BOTH numbers out of ci.yml — the
#    workflow is the source of truth, not a constant restated here, or the guard
#    would pass while the workflow drifted underneath it.
# ---------------------------------------------------------------------------
guard_out="$(python3 - "$WORKFLOW" <<'PYEOF'
import re, sys, os, glob

text = open(sys.argv[1]).read()
job = text.split('\n  integration-emulator:\n', 1)
if len(job) != 2:
    print('FAIL could not locate the integration-emulator job in ci.yml')
    raise SystemExit(0)
body = re.split(r'\n  [a-z0-9-]+:\n', job[1])[0]

def num(name):
    m = re.search(name + r':\s*(\d+)', body)
    return int(m.group(1)) if m else None

tmo, silence = num('timeout-minutes'), num('WATCHDOG_SILENCE_SECONDS')
first, later = num('WATCHDOG_FIRST_SUITE_SECONDS'), num('WATCHDOG_LATER_SUITE_SECONDS')
setup = num('WATCHDOG_SETUP_ALLOWANCE_MINUTES')
missing = [n for n, v in (('timeout-minutes', tmo), ('WATCHDOG_SILENCE_SECONDS', silence),
                          ('WATCHDOG_FIRST_SUITE_SECONDS', first),
                          ('WATCHDOG_LATER_SUITE_SECONDS', later),
                          ('WATCHDOG_SETUP_ALLOWANCE_MINUTES', setup)) if v is None]
if missing:
    print('FAIL ci.yml is missing: ' + ', '.join(missing))
    raise SystemExit(0)

repo = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(sys.argv[1]))))
running = [x for x in sorted(glob.glob(os.path.join(repo, 'app/integration_test/*_test.dart')))
           if 'phone_auth' not in os.path.basename(x)]
if len(running) < 2:
    print('FAIL found only %d integration suites - the glob is broken, not the tree empty'
          % len(running))
    raise SystemExit(0)

# THE GUARANTEE, restated for ADR-055 D2 REVISED. What must hold is that a WEDGE
# is detected before `timeout-minutes` can cancel the job, because a cancelled
# job sends no Slack notification and a failed one does. SILENCE is what detects
# a wedge, so the assertion is about silence - not about the sum of the
# wall-clock backstops, which are deliberately loose and may exceed the ceiling.
budget_s = (tmo - setup) * 60
print('INFO suites=%d silence=%ds first=%ds later=%ds setup=%dm ceiling=%dm'
      % (len(running), silence, first, later, setup, tmo))
if silence >= budget_s:
    print('FAIL silence bound %ds >= usable budget %ds (ceiling %dm minus setup %dm) - a wedge '
          'could not be detected before the job is CANCELLED' % (silence, budget_s, tmo, setup))
elif silence * 2 >= budget_s:
    print('FAIL silence bound %ds leaves under 2x margin inside the usable budget %ds - a wedge '
          'in a later suite may not be caught in time' % (silence, budget_s))
else:
    print('OK a wedge is detected in %ds, inside the %ds usable budget (%.1fx margin)'
          % (silence, budget_s, budget_s / silence))
PYEOF
)"
printf '       %s\n' "$guard_out"
if grep -q '^FAIL' <<<"$guard_out"; then
  bad "arithmetic: a wedge is detected before the ceiling can cancel" "$(grep '^FAIL' <<<"$guard_out")"
elif ! grep -q '^OK' <<<"$guard_out"; then
  bad "arithmetic: the guard produced no verdict" "$guard_out"
else
  ok "arithmetic: a wedge is detected before the ceiling can cancel the job"
fi

# ---------------------------------------------------------------------------
echo
if [ "$fail" -gt 0 ]; then
  printf 'integration_watchdog_test: %d passed, %d FAILED\n' "$pass" "$fail" >&2
  exit 1
fi
printf 'integration_watchdog_test: %d passed.\n' "$pass"
