#!/usr/bin/env bash
# Run ONE integration suite under a wall-clock bound, with a heartbeat, and turn
# a wedge into a NAMED FAILURE (ADR-055, issue #208).
#
# WHY THIS EXISTS, and it is not "catch the hang sooner".
#
# `integration-emulator` was killed at `timeout-minutes: 50` after 38 minutes of
# COMPLETE SILENCE, and GitHub reported the conclusion as `cancelled`.
# `slack_notify.sh` deliberately sends nothing for `cancelled` — a superseded run
# is not an event (ADR-024 D2), and that policy is correct. But GitHub spends the
# same word on a superseded run and a timed-out job, so the ONE control that
# exists to surface a post-merge red on this main-only job is silent by design
# for exactly the outcome a timeout produces.
#
# So the point of this wrapper is to FAIL before the job timeout can CANCEL.
# A failure reaches Slack through the path that already works, and needs no
# change to the notifier's supersede policy. Catching the hang ~34 minutes
# earlier is the side effect, not the goal.
#
# ⚠️ THE BOUND THAT DISCRIMINATES IS SILENCE, NOT ELAPSED TIME (ADR-055 D2
# revised). Measured: a healthy run's longest gap between log lines is 299s (the
# cold Xcode build); the #208 incident was silent for 2280s — a 7.6x separation.
# Total duration separates the same two cases by only 1.82x, because runner speed
# varies that much on its own (auth has been observed at 513, 540, 640 and 936
# seconds). A slow runner still PRINTS; a wedged one does not.
#
# So WATCHDOG_SILENCE_SECONDS is the real guard and the wall-clock bound is a
# loose backstop — it no longer has to be tight, so it can be safe.
#
# Usage:
#   integration_watchdog.sh <timeout-seconds> <label> <command> [args...]
#
# Exit codes:
#   0    the command succeeded
#   1    the command failed on its own terms (its output is the diagnosis)
#   124  the command exceeded <timeout-seconds> — the wedge case, and the reason
#        this file exists. 124 matches GNU coreutils `timeout`, which macOS does
#        NOT ship; this script implements the bound in portable bash rather than
#        depending on `brew install coreutils` inside a CI job.
set -uo pipefail

HEARTBEAT_SECONDS="${WATCHDOG_HEARTBEAT_SECONDS:-30}"
SILENCE_SECONDS="${WATCHDOG_SILENCE_SECONDS:-600}"

# VALIDATED, because the timeout argument is. An unvalidated 0 here is not a
# cosmetic hole: the next-beat loop below advances by this value, so 0 never
# passes `elapsed` and the watchdog spins forever — producing a job that hangs
# until `timeout-minutes` CANCELS it, which is precisely the outcome this script
# exists to prevent. A guard that is strict about one input and silent about
# another is this repo's failure shape 5; found by the ADR-055 design review.
case "$HEARTBEAT_SECONDS" in
  '' | *[!0-9]*)
    echo "watchdog: WATCHDOG_HEARTBEAT_SECONDS must be whole seconds, got '$HEARTBEAT_SECONDS'" >&2
    exit 2
    ;;
esac
if [ "$HEARTBEAT_SECONDS" -le 0 ]; then
  echo "watchdog: WATCHDOG_HEARTBEAT_SECONDS must be > 0, got '$HEARTBEAT_SECONDS'" >&2
  exit 2
fi

case "$SILENCE_SECONDS" in
  '' | *[!0-9]*)
    echo "watchdog: WATCHDOG_SILENCE_SECONDS must be whole seconds, got '$SILENCE_SECONDS'" >&2
    exit 2
    ;;
esac
if [ "$SILENCE_SECONDS" -le 0 ]; then
  echo "watchdog: WATCHDOG_SILENCE_SECONDS must be > 0, got '$SILENCE_SECONDS'" >&2
  exit 2
fi

if [ "$#" -lt 3 ]; then
  echo "usage: $0 <timeout-seconds> <label> <command> [args...]" >&2
  exit 2
fi

timeout_s="$1"
label="$2"
shift 2

case "$timeout_s" in
  '' | *[!0-9]*)
    echo "watchdog: timeout must be whole seconds, got '$timeout_s'" >&2
    exit 2
    ;;
esac
if [ "$timeout_s" -le 0 ]; then
  echo "watchdog: timeout must be > 0, got '$timeout_s'" >&2
  exit 2
fi

# The command's output is TEE'd rather than swallowed: CI must still see the
# suite's own log live. The copy exists so the timeout path can quote the last
# line it produced — "what was it doing when it stopped" is the single most
# useful fact the incident did not have.
out_file="$(mktemp -t watchdog.XXXXXX)"
# shellcheck disable=SC2317  # invoked by the EXIT trap below, not inline.
cleanup() { rm -f "$out_file"; }
trap cleanup EXIT

started_at="$(date +%s)"

# Process substitution, not a pipeline: `cmd | tee` would make $! the pid of
# `tee`, so the kill path below would leave the wedged process running and
# `wait` would report tee's status instead of the suite's.
#
# `set -m` (job control) puts the child in its OWN PROCESS GROUP, which is what
# lets the kill path below take the whole tree rather than the direct child.
# `flutter test` spawns a dartvm and a simctl, and the incident's log ends with
# the runner reporting "Terminate orphan process" for exactly those two — i.e.
# GitHub had to clean up what the job left behind.
#
# ⚠️ NOT demonstrated by this repo's own harness: an interactive shell reaps the
# whole group when the wrapping command returns, so a leak is invisible locally
# whether or not it would happen on a runner. This is written from the orphan
# lines in the incident log, not from a local measurement.
# ---------------------------------------------------------------------------
# BOUNDED DIAGNOSTIC RUNNER (ADR-078 D2.1).
#
# ⚠️ WHY THIS EXISTS, and it is the load-bearing part of the whole addition.
# Everything the timeout path runs happens AFTER the silence bound has fired —
# i.e. on a runner that has already proved something is wedged — and it talks to
# the same simulator that is wedged. If one of those commands HANGS, this script
# never reaches `exit 124`; the job runs to `timeout-minutes`, GitHub reports
# `cancelled`, and `slack_notify.sh` sends nothing by design (ADR-024 D2).
# That is exactly the outcome ADR-055 exists to eliminate, reintroduced by the
# instrument built to explain it.
#
# ⚠️ `|| true` IS NOT A DEFENCE. It swallows a non-zero status; it does not bound
# a hang. The pre-ADR-078 block relied on `|| true` and was protected against the
# wrong failure mode.
#
# macOS ships no coreutils `timeout` (ADR-055's header says so, which is why the
# main bound is implemented in bash here rather than depending on `brew install
# coreutils` inside a CI job). So this is the same pattern as the main loop, at a
# smaller scale: own process group, poll, kill the GROUP on the bound.
DIAG_BOUND_SECONDS="${WATCHDOG_DIAG_BOUND_SECONDS:-30}"

# The app under test, for filtering the device log. Overridable so the self-test
# can drive it, and named here rather than inline so the two greps below cannot
# drift apart from each other (lesson 162's shape).
APP_BUNDLE_ID="${WATCHDOG_APP_BUNDLE_ID:-com.beyondkaira.hayati}"

run_bounded() {
  local bound="$1"; shift
  local tmp; tmp="$(mktemp)"
  set -m
  "$@" >"$tmp" 2>&1 &
  local pid=$!
  set +m
  local waited=0
  while kill -0 "$pid" 2>/dev/null; do
    if [ "$waited" -ge "$bound" ]; then
      kill -TERM -"$pid" 2>/dev/null || kill -TERM "$pid" 2>/dev/null || true
      sleep 1
      kill -KILL -"$pid" 2>/dev/null || kill -KILL "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
      cat "$tmp" 2>/dev/null || true
      rm -f "$tmp"
      echo "(watchdog: '$1' exceeded its ${bound}s diagnostic bound and was killed)"
      return 124
    fi
    sleep 1
    waited=$((waited + 1))
  done
  wait "$pid" 2>/dev/null || true
  cat "$tmp" 2>/dev/null || true
  rm -f "$tmp"
  return 0
}

set -m
"$@" > >(tee "$out_file") 2>&1 &
cmd_pid=$!
set +m

# The heartbeat runs in THIS shell rather than a second background process, so
# there is no third pid to leak if the job is killed anyway.
last_size=0
last_change="$started_at"
next_beat="$HEARTBEAT_SECONDS"
while kill -0 "$cmd_pid" 2>/dev/null; do
  sleep 1
  now="$(date +%s)"
  elapsed=$((now - started_at))

  size="$(wc -c <"$out_file" 2>/dev/null || echo 0)"
  size="${size// /}"
  if [ "$size" != "$last_size" ]; then
    last_size="$size"
    last_change="$now"
  fi

  # ⚠️ RE-CHECK THE CHILD BEFORE DECLARING A TIMEOUT. `kill -0` is tested at the
  # top of the loop, then we sleep a second — so a child that finished DURING
  # that sleep, at an elapsed time that also crosses the bound, would otherwise
  # be reported as wedged. Measured before this line existed: a command that ran
  # 1.9s under a 2s bound and exited 42 was reported as 124, three times out of
  # three. A watchdog that calls a PASSING suite wedged reddens main for no
  # reason and teaches everyone to distrust it. Found by the ADR-055 review.
  if ! kill -0 "$cmd_pid" 2>/dev/null; then
    break
  fi

  silent_for=$((now - last_change))

  # SILENCE first — it is the guard that discriminates. Elapsed time is the
  # backstop behind it, deliberately loose (ADR-055 D2 revised).
  reason=""
  if [ "$silent_for" -ge "$SILENCE_SECONDS" ]; then
    reason="SILENT for ${silent_for}s (bound ${SILENCE_SECONDS}s)"
  elif [ "$timeout_s" -gt 0 ] && [ "$elapsed" -ge "$timeout_s" ]; then
    reason="exceeded its ${timeout_s}s wall-clock backstop"
  fi

  if [ -n "$reason" ]; then
    {
      echo "::error title=integration suite wedged::$label $reason"
      echo "WATCHDOG: '$label' $reason (ADR-055, #208)."
      echo "  elapsed          : ${elapsed}s"
      echo "  silent for       : ${silent_for}s   <- 'slow' and 'wedged' differ HERE"
      echo "  silence bound    : ${SILENCE_SECONDS}s"
      echo "  bytes of output  : ${size}"
      echo "  last output line : $(tail -n 1 "$out_file" 2>/dev/null || echo '(none)')"
      echo ""
      echo "  This job is FAILING rather than being cancelled at timeout-minutes,"
      echo "  so it reaches Slack. See ADR-055 for why that distinction is the"
      echo "  whole point."
    } >&2

    # Diagnosis, best-effort and never fatal: the two things that can wedge are
    # the simulator and the emulators. Absent tools must not turn a useful
    # timeout report into a second failure.
    #
    # ⚠️ EVERY CALL HERE IS BOUNDED, and that is a CORRECTION rather than a new
    # precaution (ADR-078 D2.1). `xcrun simctl list devices booted` was
    # unbounded from the day this block was written, and it talks to the same
    # simulator the suite has just been declared wedged against. A `simctl` that
    # never returns meant this script never reached `exit 124` — the job would
    # run to `timeout-minutes`, GitHub would call it `cancelled`, and
    # `slack_notify.sh` sends nothing for `cancelled` BY DESIGN (ADR-024 D2).
    #
    # So the guard ADR-055 built to stop a hang being silent could itself be
    # silenced by a hang, in the one situation it exists for. `|| true` never
    # protected against this: it swallows a STATUS, not a HANG.
    #
    # Measured, not reasoned: with a stubbed `xcrun` that sleeps forever, this
    # block held the script for the full harness timeout and the suite's 124
    # never arrived. The self-test now pins exactly that case.
    {
      echo "--- simulator state ---"
      if command -v xcrun >/dev/null 2>&1; then
        run_bounded "$DIAG_BOUND_SECONDS" xcrun simctl list devices booted | head -20
      else
        echo "(xcrun not available)"
      fi
      echo "--- emulator ports ---"
      for port in 8080 9099 5001; do
        if command -v nc >/dev/null 2>&1; then
          # `-w 2` as well as the outer bound: nc's own connect timeout is the
          # cheap guard, run_bounded is the one that cannot be argued with.
          if run_bounded "$DIAG_BOUND_SECONDS" nc -z -w 2 127.0.0.1 "$port" >/dev/null; then
            echo "  127.0.0.1:$port  ANSWERING"
          else
            echo "  127.0.0.1:$port  no answer   <- the app could not have reached it"
          fi
        else
          echo "  (nc not available; cannot probe $port)"
        fi
      done
    } >&2 || true

    # ------------------------------------------------------------------
    # THE APP-TO-TOOL LINK (ADR-078 D1). Everything above measures the
    # ENVIRONMENT — and in the incident this was written for, run 34042187123,
    # every bit of it was HEALTHY: the simulator Booted, all three ports
    # ANSWERING. The tool then said `No tests ran` beside "Error waiting for a
    # debug connection: The log reader failed unexpectedly".
    #
    # Read from flutter_tools (ios/simulators.dart, IOSSimulator.startApp) that
    # sentence is the NULL branch of `await vmServiceDiscovery?.uri`, and
    # ProtocolDiscovery documents the null as "returns null if the log reader
    # shuts down before any uri is found". The reader is literally
    # `xcrun simctl spawn <id> log stream --style json --predicate ...`.
    #
    # So the question that splits the failure is: DID THE APP EVER PRINT THE
    # URI? Two failures with opposite remedies were arriving as one silence —
    # ADR-074's shape, one layer out.
    if [ -n "${DEVICE_ID:-}" ] && command -v xcrun >/dev/null 2>&1; then
      # ⚠️ THE WINDOW IS DERIVED, NOT CHOSEN (ADR-078 D1.1). At this moment the
      # launch is already SILENCE_SECONDS old — the silence clock starts at the
      # last line of output, and the last line of output IS the launch. A fixed
      # `--last 5m` would have reached back to ten minutes AFTER the thing it
      # exists to capture and reported "no URI line", which is the same answer
      # it gives when the app never printed one (lesson 150).
      win=$((elapsed + 120))
      log_file="${GITHUB_WORKSPACE:-$PWD}/watchdog-device-log.txt"
      {
        echo "--- device log, last ${win}s (ADR-078) ---"
        echo "  device   : $DEVICE_ID"
        echo "  full log : $log_file"
      } >&2
      run_bounded "$DIAG_BOUND_SECONDS" \
        xcrun simctl spawn "$DEVICE_ID" log show --last "${win}s" --style compact \
        >"$log_file" 2>&1 || true

      # ⚠️ `grep -c` EXITS 1 WHEN THE COUNT IS ZERO, so the obvious
      # `$(grep -c … || echo 0)` prints the count AND the fallback — "0\n0" —
      # and the number beside the label stops being a number. Found by running
      # this against a stub rather than by reading it (lesson 153: the command
      # beside a number has to be the one that produced it, and it has to have
      # produced only that). `|| true` keeps the count and drops the status.
      count_in() { local n; n="$(grep -c "$2" "$1" 2>/dev/null || true)"; echo "${n:-0}" | head -1 | tr -d ' '; }
      total_lines="$(wc -l <"$log_file" 2>/dev/null || echo 0)"; total_lines="${total_lines// /}"
      app_lines="$(count_in "$log_file" "$APP_BUNDLE_ID")"
      uri_lines="$(count_in "$log_file" 'VM Service is listening on\|Observatory listening on')"
      {
        # ⚠️ THE COUNTS ARE THE CONTROL (ADR-078 D1.2). `log show` reads a ring
        # buffer and nothing here has established that a seventeen-minute-old
        # line survives it. Without these, "no URI line" has a THIRD cause — the
        # line aged out — and the instrument collapses the worlds it exists to
        # separate. ZERO TOTAL LINES on a booted simulator that just built and
        # launched an app is a BROKEN MEASUREMENT, not an answer.
        echo "  lines in window      : $total_lines   <- 0 means the QUERY failed, not that the app was silent"
        echo "  lines from the app   : $app_lines     ($APP_BUNDLE_ID)"
        echo "  'VM Service listening': $uri_lines"
      } >&2

      echo "--- is the app process alive? ---" >&2
      run_bounded "$DIAG_BOUND_SECONDS" \
        xcrun simctl spawn "$DEVICE_ID" launchctl list 2>/dev/null \
        | grep -i "hayati" | head -10 >&2 || echo "  (no hayati process in launchctl list)" >&2

      # The crash report is the diagnosis when the app announced itself and then
      # died — the row that did NOT exist until the design review added it.
      echo "--- newest crash reports ---" >&2
      ls -t "$HOME/Library/Logs/DiagnosticReports/"*.ips 2>/dev/null | head -3 >&2 \
        || echo "  (none)" >&2
    elif [ -z "${DEVICE_ID:-}" ]; then
      # ⚠️ NEVER GUESS A DEVICE. `simctl list devices booted` can return more
      # than one, and the wrong device's log is worse than no log — it would
      # answer "no URI line" with total confidence about the wrong simulator.
      echo "--- device log: SKIPPED, DEVICE_ID is not set (ADR-078 D2) ---" >&2
    fi

    # THE PROCESS GROUP, not the pid. `kill -TERM -<pid>` addresses the group
    # `set -m` created above, so the dartvm and simctl children die with the
    # suite instead of being left for the runner to report as orphans. The
    # bare-pid form stays as a fallback for when the group has already gone.
    kill -TERM -"$cmd_pid" 2>/dev/null || kill -TERM "$cmd_pid" 2>/dev/null || true
    sleep 5
    kill -KILL -"$cmd_pid" 2>/dev/null || kill -KILL "$cmd_pid" 2>/dev/null || true
    wait "$cmd_pid" 2>/dev/null || true

    # NOT re-printed: tee already streamed it live. Dumping it here would
    # double every line of a suite log that may be thousands long.
    exit 124
  fi

  # Heartbeat. The incident produced NOTHING for 38 minutes; this guarantees a
  # line every HEARTBEAT_SECONDS whatever the child does, and carries the
  # time-since-last-output that the raw log could never show.
  #
  # Compared against a NEXT-BEAT deadline rather than `elapsed % N == 0`: the
  # modulo form silently skips a beat whenever an iteration overruns a second,
  # and a loaded-or-wedged runner is exactly when that happens and exactly when
  # the heartbeat is the only thing being read.
  if [ "$elapsed" -ge "$next_beat" ]; then
    echo "watchdog: $label — ${elapsed}s elapsed, $((now - last_change))s since last output, ${size} bytes"
    while [ "$next_beat" -le "$elapsed" ]; do
      next_beat=$((next_beat + HEARTBEAT_SECONDS))
    done
  fi
done

wait "$cmd_pid"
status=$?

finished_at="$(date +%s)"
echo "watchdog: $label finished in $((finished_at - started_at))s with status $status"
exit "$status"
