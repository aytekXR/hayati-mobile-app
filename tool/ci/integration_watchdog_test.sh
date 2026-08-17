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
# 6. ⚠️ THE ARITHMETIC GUARD (ADR-055 D2).
#
#    The watchdog can only convert `cancelled` into `failure` if its bounds fire
#    before `timeout-minutes`. This parses BOTH numbers out of ci.yml — the
#    workflow is the source of truth, not a constant restated here, or the guard
#    would pass while the workflow drifted underneath it.
# ---------------------------------------------------------------------------
guard_out="$(python3 - "$WORKFLOW" <<'PY'
import re, sys

text = open(sys.argv[1]).read()

job = text.split('\n  integration-emulator:\n', 1)
if len(job) != 2:
    print('FAIL could not locate the integration-emulator job in ci.yml')
    raise SystemExit(0)
body = re.split(r'\n  [a-z0-9-]+:\n', job[1])[0]

tmo = re.search(r'timeout-minutes:\s*(\d+)', body)
first = re.search(r'WATCHDOG_FIRST_SUITE_SECONDS:\s*(\d+)', body)
later = re.search(r'WATCHDOG_LATER_SUITE_SECONDS:\s*(\d+)', body)
setup = re.search(r'WATCHDOG_SETUP_ALLOWANCE_MINUTES:\s*(\d+)', body)
if not (tmo and first and later and setup):
    missing = [n for n, m in (('timeout-minutes', tmo),
                              ('WATCHDOG_FIRST_SUITE_SECONDS', first),
                              ('WATCHDOG_LATER_SUITE_SECONDS', later),
                              ('WATCHDOG_SETUP_ALLOWANCE_MINUTES', setup)) if not m]
    print('FAIL ci.yml is missing: ' + ', '.join(missing))
    raise SystemExit(0)

# The suite count is DERIVED from the tree, not hardcoded: adding a sixth suite
# must move this arithmetic, and the comment in ci.yml claimed "four" while five
# were running (ADR-055 context).
import glob, os
repo = os.path.dirname(os.path.dirname(os.path.abspath(sys.argv[1])))
repo = os.path.dirname(repo)  # .github/workflows -> repo root
suites = sorted(glob.glob(os.path.join(repo, 'app/integration_test/*_test.dart')))
running = [s for s in suites if 'phone_auth' not in os.path.basename(s)]
if len(running) < 2:
    print(f'FAIL found only {len(running)} integration suites — the glob is broken, not the tree empty')
    raise SystemExit(0)

worst = int(first.group(1)) + (len(running) - 1) * int(later.group(1))
worst_min = worst / 60 + int(setup.group(1))
budget = int(tmo.group(1))
print(f'INFO suites={len(running)} first={first.group(1)}s later={later.group(1)}s '
      f'setup={setup.group(1)}m worst={worst_min:.1f}m budget={budget}m')
if worst_min >= budget:
    print(f'FAIL worst-case {worst_min:.1f}m >= timeout-minutes {budget} — the watchdog '
          f'cannot fire before the job is CANCELLED, so it guards nothing')
else:
    print(f'OK worst case {worst_min:.1f}m fits inside timeout-minutes {budget} '
          f'({budget - worst_min:.1f}m slack)')
PY
)"
printf '       %s\n' "$guard_out"
if grep -q '^FAIL' <<<"$guard_out"; then
  bad "arithmetic: the bounds fit inside timeout-minutes" "$(grep '^FAIL' <<<"$guard_out")"
elif ! grep -q '^OK' <<<"$guard_out"; then
  bad "arithmetic: the guard produced no verdict" "$guard_out"
else
  ok "arithmetic: the bounds fit inside timeout-minutes, so the watchdog can fire"
fi

# ---------------------------------------------------------------------------
echo
if [ "$fail" -gt 0 ]; then
  printf 'integration_watchdog_test: %d passed, %d FAILED\n' "$pass" "$fail" >&2
  exit 1
fi
printf 'integration_watchdog_test: %d passed.\n' "$pass"
