#!/usr/bin/env python3
"""Hermetic self-tests for tool/ci/prod_pulse.py. No network, no credential.

WHAT WOULD MAKE THIS GATE WORTHLESS. A health check that returns "healthy"
whenever the platform answers at all would have passed every hour of the
2026-08-09→11 outage, because the platform answered every hour: Cloud Scheduler
was ENABLED, it fired punctually, and `firebase functions:log` printed a line at
:00 each time. That is exactly the reading `docs/operator-expected.md` published
as *"Your app is running."*

So the assertions below aim at the DISCRIMINATION, not at the happy path:

* **The outage's real signature is replayed** (billing off, job ENABLED, last
  attempt gRPC 13, no completed sweep) and must be exit 1. This is the fixture
  that a naive "did the job fire?" implementation cannot pass.
* **ENABLED + punctual + stale-sweep must still fail.** Dropping the sweep-age
  check — the single likeliest "simplification" — reddens a named check.
* **A completed sweep older than the threshold is a finding**, so the tool
  cannot be satisfied by a sweep that succeeded once, days ago.
* **exit 1 and exit 2 are asserted as distinct.** Both are non-zero scalars
  (lesson 76); collapsing them turns "I could not look" into "I looked and it is
  broken", which sends the founder to the wrong place.
* **The cause is reported alongside the consequence**: billing-off must not
  silently swallow the stale-sweep line, because the reader needs to know the
  loop stopped, not only that the card expired.
"""
from __future__ import annotations

import datetime as dt
import sys

from prod_pulse import (
    EXIT_CANNOT_MEASURE,
    EXIT_FINDING,
    EXIT_OK,
    parse_http_date,
    sweep_age_minutes,
    verdict,
)

NOW = dt.datetime(2026, 8, 11, 7, 0, tzinfo=dt.timezone.utc)
failures: list[str] = []


def check(name: str, condition: bool, detail: str = "") -> None:
    if not condition:
        failures.append(f"{name}: {detail or 'assertion failed'}")


def section(name: str, fn) -> None:
    try:
        fn()
    except Exception as exc:  # a raise is a named failure, never a dead run
        failures.append(f"{name}: raised {type(exc).__name__}: {exc}")


# --------------------------------------------------------------------------

def test_healthy() -> None:
    code, lines = verdict(
        billing_enabled=True,
        job_state="ENABLED",
        job_status_code=0,
        last_sweep=NOW - dt.timedelta(minutes=20),
        last_summary={"message": "question_rollover: sweep complete", "assigned": 1,
                      "existing": 0, "failed": 0},
        now=NOW,
    )
    check("healthy/exit", code == EXIT_OK, f"got {code}")
    check("healthy/summary-shown", any("assigned=1" in line for line in lines),
          "the sweep summary must be printed, not just the verdict")
    check("healthy/no-finding", not any(line.startswith("FINDING") for line in lines))


def test_the_actual_outage() -> None:
    """The 2026-08-09→11 signature, replayed exactly."""
    code, lines = verdict(
        billing_enabled=False,
        job_state="ENABLED",          # it WAS enabled the whole time
        job_status_code=13,           # gRPC INTERNAL, every hour
        last_sweep=None,              # and not one sweep completed
        last_summary=None,
        now=NOW,
    )
    check("outage/exit", code == EXIT_FINDING, f"got {code}")
    joined = " ".join(lines)
    check("outage/names-billing", "BILLING IS OFF" in joined,
          "the cause must be named, not only the symptom")
    check("outage/names-missing-sweep", "has not completed once" in joined,
          "the consequence must be reported alongside the cause")


def test_enabled_and_punctual_is_not_health() -> None:
    """The whole point: a live scheduler over a dead backend must NOT read green."""
    code, _ = verdict(
        billing_enabled=True,     # billing could even be restored...
        job_state="ENABLED",      # ...and the job enabled...
        job_status_code=0,        # ...and its last attempt fine...
        last_sweep=NOW - dt.timedelta(hours=37),   # ...and the loop still dead.
        last_summary=None,
        now=NOW,
    )
    check("liveness/stale-sweep-is-a-finding", code == EXIT_FINDING,
          "a 37h-old sweep with a healthy scheduler must be exit 1")


def test_threshold_edges() -> None:
    fresh = verdict(billing_enabled=True, job_state="ENABLED", job_status_code=0,
                    last_sweep=NOW - dt.timedelta(minutes=89), last_summary=None,
                    now=NOW, max_age_minutes=90)[0]
    stale = verdict(billing_enabled=True, job_state="ENABLED", job_status_code=0,
                    last_sweep=NOW - dt.timedelta(minutes=91), last_summary=None,
                    now=NOW, max_age_minutes=90)[0]
    check("threshold/under", fresh == EXIT_OK, f"89m under a 90m threshold got {fresh}")
    check("threshold/over", stale == EXIT_FINDING, f"91m over a 90m threshold got {stale}")


def test_paused_job() -> None:
    code, lines = verdict(billing_enabled=True, job_state="PAUSED", job_status_code=0,
                          last_sweep=NOW - dt.timedelta(minutes=10), last_summary=None,
                          now=NOW)
    check("paused/exit", code == EXIT_FINDING, f"got {code}")
    check("paused/named", any("PAUSED" in line for line in lines))
    missing = verdict(billing_enabled=True, job_state=None, job_status_code=0,
                      last_sweep=NOW - dt.timedelta(minutes=10), last_summary=None,
                      now=NOW)
    check("no-job/exit", missing[0] == EXIT_FINDING, f"got {missing[0]}")
    check("no-job/named", any("no trigger" in line or "no Cloud Scheduler" in line
                              for line in missing[1]))


def test_exit_codes_are_distinct() -> None:
    check("taxonomy/distinct",
          len({EXIT_OK, EXIT_FINDING, EXIT_CANNOT_MEASURE}) == 3,
          "'could not measure' must not collapse into 'broken'")
    check("taxonomy/values", (EXIT_OK, EXIT_FINDING, EXIT_CANNOT_MEASURE) == (0, 1, 2))


def test_sweep_age() -> None:
    check("age/none", sweep_age_minutes(None, NOW) is None)
    check("age/value",
          abs(sweep_age_minutes(NOW - dt.timedelta(minutes=42), NOW) - 42) < 1e-6)


def test_http_date_is_the_clock() -> None:
    """`now` comes from Google's Date header, never the local box.

    Both operands of the age must come from ONE clock. A local clock running
    slow against Google's would age a stale sweep as fresh — the tool reporting
    green over a dead loop, which is the single outcome it must not produce.
    """
    parsed = parse_http_date("Tue, 11 Aug 2026 10:52:35 GMT")
    check("date/parsed", parsed == dt.datetime(2026, 8, 11, 10, 52, 35, tzinfo=dt.timezone.utc),
          f"got {parsed!r}")
    check("date/aware", parsed is not None and parsed.tzinfo is not None,
          "a naive datetime would raise when subtracted from an aware log timestamp")
    for junk in (None, "", "not a date", "Tue, 99 Xxx 2026 99:99:99 GMT"):
        check(f"date/junk({junk!r})", parse_http_date(junk) is None,
              "unparseable must be None so the caller falls back and SAYS SO")

    # The skew that matters, made concrete: a sweep 3.5h stale, judged by a local
    # clock running 3.5h slow, would read as 0m old and pass.
    stale = dt.datetime(2026, 8, 11, 7, 19, tzinfo=dt.timezone.utc)
    server_now = parse_http_date("Tue, 11 Aug 2026 10:52:35 GMT")
    skewed_local = dt.datetime(2026, 8, 11, 7, 27, tzinfo=dt.timezone.utc)
    check("date/skew-is-caught",
          verdict(billing_enabled=True, job_state="ENABLED", job_status_code=0,
                  last_sweep=stale, last_summary=None, now=server_now)[0] == EXIT_FINDING,
          "Google's clock must expose the 3.5h-stale sweep")
    check("date/skew-would-have-hidden-it",
          verdict(billing_enabled=True, job_state="ENABLED", job_status_code=0,
                  last_sweep=stale, last_summary=None, now=skewed_local)[0] == EXIT_OK,
          "fixture check: the skewed local clock really would have passed it — "
          "which is why the Date header is not optional")


for name, fn in list(globals().items()):
    if name.startswith("test_"):
        section(name, fn)

if failures:
    print(f"prod_pulse_test: {len(failures)} FAILED", file=sys.stderr)
    for f in failures:
        print("  - " + f, file=sys.stderr)
    sys.exit(1)
print("prod_pulse_test: all checks passed")
