#!/usr/bin/env bash
# Assert the functions emulator actually LOADED its functions before a suite
# depends on them (ADR-055, issue #208).
#
# WHY THIS EXISTS. On S077's post-merge run the functions emulator printed:
#
#   ⬢ functions: Failed to load function definition from source: FirebaseError:
#     User code failed to load. Cannot determine backend specification.
#     Timeout after 10000.
#
# and then `emulators:exec` ran the suites anyway against an emulator serving
# ZERO functions. Fifteen minutes later `daily_question_emulator_test.dart`
# failed on "answer → mutual reveal round trip" — because the `answerReveal`
# trigger had never loaded. The test's message said nothing about that; the real
# cause was 200 lines earlier in a different emulator's output.
#
# That is the same defect #208 is about wearing different clothes: the job failed
# for a real reason and reported something else. This turns 15 minutes and a
# misleading test name into an immediate, named precondition failure.
#
# ⚠️ ONLY CALLABLE/HTTP FUNCTIONS CAN BE PROBED. Measured against a live
# emulator: a loaded callable answers a bare GET with **400** (it wants a POST
# body), an unknown name answers **404** — and a *trigger* like `answerReveal`
# also answers 404, because triggers are not HTTP-addressable at all. So probing
# a trigger would fail against a perfectly healthy emulator. Pass callables.
#
# Usage:
#   assert_emulator_functions.sh <base-url> <project> <region> <callable>...
# Example:
#   assert_emulator_functions.sh http://127.0.0.1:5001 demo-hayati europe-west1 createInvite
set -uo pipefail

if [ "$#" -lt 4 ]; then
  echo "usage: $0 <base-url> <project> <region> <callable>..." >&2
  exit 2
fi

base="$1"
project="$2"
region="$3"
shift 3

if ! command -v curl >/dev/null 2>&1; then
  echo "::error title=emulator precondition::curl not available; cannot verify the functions emulator" >&2
  exit 2
fi

missing=()
for fn in "$@"; do
  url="$base/$project/$region/$fn"
  # NOT `curl ... || echo 000`: on a connection failure curl's own -w ALREADY
  # writes 000 and then exits non-zero, so the fallback appended a second one and
  # produced "000000" — which fell through to the not-404 branch and reported an
  # UNREACHABLE emulator as loaded. Caught by this script's own self-test, in the
  # one path that matters when the emulator has died.
  if ! code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 "$url" 2>/dev/null)"; then
    code="000"
  fi
  case "$code" in
    404)
      echo "  $fn -> HTTP 404  NOT LOADED"
      missing+=("$fn")
      ;;
    000)
      echo "  $fn -> no answer  emulator unreachable at $base"
      missing+=("$fn (unreachable)")
      ;;
    *)
      # Anything that is not 404 means the route exists. 400 is the healthy
      # answer to a bare GET on a callable; success codes are fine too.
      echo "  $fn -> HTTP $code  loaded"
      ;;
  esac
done

if [ "${#missing[@]}" -gt 0 ]; then
  {
    echo "::error title=functions emulator loaded nothing::${missing[*]}"
    echo "PRECONDITION FAILED: the functions emulator is not serving ${missing[*]}."
    echo ""
    echo "  This is almost always 'Failed to load function definition from source"
    echo "  ... Cannot determine backend specification. Timeout after 10000' in the"
    echo "  emulator's own output ABOVE — a discovery timeout, not a test failure."
    echo ""
    echo "  Suites are NOT being run, because every callable and trigger they"
    echo "  depend on would fail for this one reason and report it as their own."
    echo "  That is what cost S077's post-merge run 15 minutes and a misleading"
    echo "  failure on 'answer → mutual reveal round trip' (ADR-055, #208)."
  } >&2
  exit 1
fi

echo "functions emulator precondition: all $# probed callables are loaded."
