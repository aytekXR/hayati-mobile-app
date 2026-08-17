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

  if [ "$timeout_s" -gt 0 ] && [ "$elapsed" -ge "$timeout_s" ]; then
    silent_for=$((now - last_change))
    {
      echo "::error title=integration suite wedged::$label exceeded ${timeout_s}s"
      echo "WATCHDOG: '$label' exceeded its ${timeout_s}s bound (ADR-055, #208)."
      echo "  elapsed          : ${elapsed}s"
      echo "  silent for       : ${silent_for}s   <- 'slow' and 'wedged' differ HERE"
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
    {
      echo "--- simulator state ---"
      if command -v xcrun >/dev/null 2>&1; then
        xcrun simctl list devices booted 2>&1 | head -20 || true
      else
        echo "(xcrun not available)"
      fi
      echo "--- emulator ports ---"
      for port in 8080 9099 5001; do
        if command -v nc >/dev/null 2>&1; then
          if nc -z 127.0.0.1 "$port" 2>/dev/null; then
            echo "  127.0.0.1:$port  ANSWERING"
          else
            echo "  127.0.0.1:$port  no answer   <- the app could not have reached it"
          fi
        else
          echo "  (nc not available; cannot probe $port)"
        fi
      done
    } >&2 || true

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
