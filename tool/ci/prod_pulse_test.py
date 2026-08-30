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

ADDED BY ADR-063 (S087), after the outage RECURRED on 2026-08-22 and this tool
answered `could not measure`:

* **A gap can never produce a green.** The single most dangerous output this file
  can fail to forbid is exit 0 while the decisive fact was never read. Billing
  healthy + scheduler ENABLED + Logging unreadable must be **2**, not 0.
* **A gap is not an absence.** `job_state=None` means *"I looked and there is no
  job"*; a scheduler that 403'd must NOT produce that finding, or the report
  invents a cause. Same for the sweep.
* **Findings still beat gaps.** A closed billing account plus an unreadable
  scheduler is exit **1**, because something real was found — with the gap
  printed on its own line beside it.
* **linked ≠ open.** `billingInfo.billingEnabled` was `true` throughout the
  2026-08-22 outage while the ACCOUNT behind it was closed and Cloud Run refused
  every invocation. A test replays that exact pair.
* **`main()` is exercised, not just `verdict()`.** Every assertion in revision 1
  targeted the pure function; both defects lived in the wiring around it.

ADDED BY ADR-064 (S088), when this tool gained a CI lane:

* **The notifier text is a pure function, and exit 2 does not read as an outage.**
  D2c says a finding and a could-not-measure must reach a human as DIFFERENT
  sentences; the distinction is worthless if the lane collapses them, so it is
  computed here and asserted here.
* **A green sends nothing.** The lane runs every 6h; if exit 0 produced text the
  channel would carry four empty messages a day and get muted — which is the
  outcome ADR-024 exists to prevent, arrived at from the other side.
* **The CI credential is scoped to LOGGING ONLY.** ADR-064 D3: this repo is
  public, and `roles/billing.viewer` carries `getPaymentInfo`,
  `getSpendingInformation`, `credits.list`, `getIamPolicy` and an inventory of
  every project on the account. The scope constant is pinned so widening it is a
  deliberate act with a red test, not a convenience edit.
"""
from __future__ import annotations

import datetime as dt
import os
import sys

from prod_pulse import (
    DEFAULT_LOOKBACK_HOURS,
    PULSE_SCOPE,
    PULSE_SECRET,
    findings_for_notifier,
    EXIT_CANNOT_MEASURE,
    EXIT_FINDING,
    EXIT_OK,
    billing_findings,
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



# --------------------------------------------------------------------------
# ADR-063: the gap rules. Everything below is about the 2026-08-22 recurrence.
# --------------------------------------------------------------------------

def test_a_gap_can_never_produce_a_green() -> None:
    """THE one output this tool must never produce.

    Billing reads healthy, the scheduler reads ENABLED and punctual, and the
    Logging API cannot be read — so the sweep age, the only fact that answers
    the question in the tool's title, was never measured. Revision 1's exit rule
    made this exit 0 and printed "the daily loop is running".
    """
    code, lines = verdict(
        billing_enabled=True,
        billing_account_open=True,
        job_state="ENABLED",
        job_status_code=0,
        last_sweep=None,
        last_summary=None,
        gaps={"sweep": "logging.googleapis.com returned HTTP 403"},
        now=NOW,
    )
    check("gap-green/exit", code == EXIT_CANNOT_MEASURE,
          f"a green with an unmeasured decisive fact got {code}, must be 2")
    joined = " ".join(lines)
    check("gap-green/named", "COULD NOT MEASURE sweep" in joined,
          "the gap must be named in the report, not implied by the exit code")
    check("gap-green/no-false-claim", "the daily loop is running" not in joined,
          "a tool that could not look must not claim the loop is running")


def test_a_gap_is_not_an_absence() -> None:
    """A scheduler that 403'd must not be reported as a scheduler that is missing.

    Without this, the fix is WORSE than the bug: today's 403 arrives as
    job_state=None and prints "no Cloud Scheduler job — the sweep has no
    trigger", which is a confidently stated false cause.
    """
    code, lines = verdict(
        billing_enabled=True,
        billing_account_open=True,
        job_state=None,                 # could not look, NOT "there is no job"
        job_status_code=0,
        last_sweep=NOW - dt.timedelta(minutes=10),
        last_summary=None,
        gaps={"scheduler": "cloudscheduler.googleapis.com returned HTTP 403"},
        now=NOW,
    )
    joined = " ".join(lines)
    check("gap-absence/no-invented-cause",
          "no Cloud Scheduler job" not in joined and "no trigger" not in joined,
          "an unreadable scheduler must not be reported as a missing one")
    check("gap-absence/named", "COULD NOT MEASURE scheduler" in joined)
    check("gap-absence/exit", code == EXIT_CANNOT_MEASURE,
          f"nothing found and one fact unread must be 2, got {code}")


def test_a_gap_does_not_suppress_a_real_finding() -> None:
    """TODAY's run, replayed: closed account + unreadable scheduler.

    Findings beat gaps. The closed account is a real, measured finding and must
    produce exit 1 — with the scheduler gap printed beside it, not instead of it.
    """
    code, lines = verdict(
        billing_enabled=True,           # the project is still LINKED...
        billing_account_open=False,     # ...to a CLOSED account
        job_state=None,
        job_status_code=0,
        last_sweep=None,
        last_summary=None,
        gaps={"scheduler": "cloudscheduler.googleapis.com returned HTTP 403"},
        now=NOW,
    )
    check("today/exit", code == EXIT_FINDING,
          f"a measured finding must beat a gap; got {code}")
    joined = " ".join(lines)
    check("today/names-closed-account", "CLOSED" in joined,
          "the closed account is the cause and must be named")
    check("today/keeps-the-gap-line", "COULD NOT MEASURE scheduler" in joined,
          "the gap must still be reported next to the finding")


ACCOUNT = "billingAccounts/012195-7EF76F-3A9083"


def test_linked_is_not_open() -> None:
    """The exact pair that made the shipped tool report health during an outage.

    `billingInfo.billingEnabled` was true for the whole 2026-08-22 outage. The
    account behind it was closed and Cloud Run refused every invocation.
    """
    findings = billing_findings(
        billing_enabled=True, account_name=ACCOUNT, account_open=True)
    check("linked-open/healthy", findings == [],
          f"linked AND open is healthy; got {findings}")

    closed = billing_findings(
        billing_enabled=True, account_name=ACCOUNT, account_open=False)
    check("linked-closed/is-a-finding", len(closed) == 1,
          "linked-but-closed must be a finding of its own")
    check("linked-closed/names-both",
          any("CLOSED" in f for f in closed),
          f"the finding must say the account is closed; got {closed}")

    unlinked = billing_findings(
        billing_enabled=False, account_name=None, account_open=None)
    check("unlinked/is-a-finding", len(unlinked) == 1,
          "an unlinked project is still a finding")

    # Unreadable account document: NOT an assumption in either direction.
    unknown = billing_findings(
        billing_enabled=True, account_name=ACCOUNT, account_open=None)
    check("linked-unknown/no-finding", unknown == [],
          "an unreadable account must be a gap for the caller, never a finding here")


def test_billing_off_is_not_the_same_as_unlinked() -> None:
    """ADR-066, issue #267 — the state production has actually been in.

    The shipped code returned early on `not billing_enabled` with *"no billing
    account is linked"* and never consulted `account_open`, which `main()` had
    already measured in the same run. Measured 2026-08-30 on BOTH projects:

        billingEnabled=False  billingAccountName=billingAccounts/012195-...  open=False

    so the report printed "no billing account is linked" directly beneath a line
    naming the linked account. That sentence is the instruction the founder acts
    on (`operator-expected.md` item 1) and the text the watcher would post
    (ADR-064 D2b), and it sent them looking for a link that was already there.

    ⚠️ **Every case here asserts the DISTINGUISHING words, not the count.** All
    four states produce exactly one finding, so a test that counted findings
    would have passed on the shipped code — which is precisely how this shipped.
    """
    UNLINKED = "no billing account is linked"

    # 1. Not linked at all. The ONLY state where the old sentence is correct.
    not_linked = billing_findings(
        billing_enabled=False, account_name=None, account_open=None)
    check("billing-off/unlinked/is-a-finding", len(not_linked) == 1,
          f"an unlinked project is a finding; got {not_linked}")
    check("billing-off/unlinked/says-unlinked",
          any(UNLINKED in f for f in not_linked),
          f"this is the one state that sentence fits; got {not_linked}")

    # 2. Linked to a CLOSED account, billing off at the project. TODAY'S STATE.
    closed = billing_findings(
        billing_enabled=False, account_name=ACCOUNT, account_open=False)
    check("billing-off/closed/is-a-finding", len(closed) == 1,
          f"billing off with a closed account is a finding; got {closed}")
    check("billing-off/closed/does-NOT-say-unlinked",
          not any(UNLINKED in f for f in closed),
          f"the account IS linked — this is the defect #267 is; got {closed}")
    check("billing-off/closed/says-closed", any("CLOSED" in f for f in closed),
          f"it must name the actual cause; got {closed}")
    check("billing-off/closed/names-the-account", any(ACCOUNT in f for f in closed),
          f"the founder must not need a second lookup; got {closed}")

    # 3. Linked, billing off, and the account document could not be read.
    #    A gap is a NAMED gap, never an assumption in either direction (ADR-063).
    unknown = billing_findings(
        billing_enabled=False, account_name=ACCOUNT, account_open=None)
    check("billing-off/unknown/is-a-finding", len(unknown) == 1,
          f"billing being off is a finding whatever the account says; got {unknown}")
    check("billing-off/unknown/does-NOT-say-unlinked",
          not any(UNLINKED in f for f in unknown),
          f"an account is named, so it is linked; got {unknown}")
    check("billing-off/unknown/does-NOT-claim-closed",
          not any("CLOSED" in f for f in unknown),
          f"unread is not closed — that would invent a cause; got {unknown}")

    # 4. Linked, account OPEN, billing off at the PROJECT. Defensive: this is
    #    what a reopened account may look like before it propagates. NOT
    #    measured — reaching it means reopening a closed account (operator item
    #    1), which no session can do (ADR-066 D1).
    at_project = billing_findings(
        billing_enabled=False, account_name=ACCOUNT, account_open=True)
    check("billing-off/at-project/is-a-finding", len(at_project) == 1,
          f"the project cannot serve, whatever the account says; got {at_project}")
    check("billing-off/at-project/does-NOT-say-unlinked",
          not any(UNLINKED in f for f in at_project),
          f"the link exists — the name came from it; got {at_project}")
    check("billing-off/at-project/does-NOT-say-relink",
          not any("re-link" in f or "relink" in f for f in at_project),
          "telling them to re-link a linked project sends them to look for "
          f"something that is there (ADR-066 D1, revision 2); got {at_project}")

    # A FLOOR on the table (lesson 110): four states, four distinct sentences.
    # A refactor that collapsed two of them would otherwise pass every check
    # above except the one it broke.
    sentences = {
        not_linked[0], closed[0], unknown[0], at_project[0],
    }
    check("billing-off/four-distinct-sentences", len(sentences) == 4,
          f"the four states must not collapse into fewer; got {len(sentences)}")


def test_the_notifier_carries_the_right_billing_sentence() -> None:
    """ADR-066 D4. What the watcher would POST, not only what the report prints.

    `--notifier-findings` puts findings into EXTRA_FINDINGS (ADR-064 D2b), so
    this text is the armed lane's entire output — and the armed path has never
    run. Its first real output must not be the sentence #267 exists to remove.
    """
    text = findings_for_notifier(
        EXIT_FINDING,
        ["FINDING: " + f for f in billing_findings(
            billing_enabled=False, account_name=ACCOUNT, account_open=False)],
    )
    check("notifier/billing/prefix", text.startswith("production:"),
          f"exit 1 is prefixed 'production:'; got {text[:40]!r}")
    check("notifier/billing/does-NOT-say-unlinked",
          "no billing account is linked" not in text,
          f"the account is linked; this is what Slack would have posted: {text!r}")
    check("notifier/billing/says-closed", "CLOSED" in text,
          f"the posted text must carry the cause; got {text!r}")


def test_main_reports_a_finding_when_one_probe_fails() -> None:
    """`main()` is the wiring, and the wiring is where both defects lived.

    Replays 2026-08-27 exactly: billing reads (project linked, account CLOSED),
    the scheduler raises, logging returns a stale sweep. The shipped code threw
    the closed account away and returned 2.
    """
    import prod_pulse

    class FakeApi:
        server_now = NOW

        def __init__(self, *_a, **_k) -> None:
            pass

    calls: list[str] = []

    def fake_billing(_api, _project):
        calls.append("billing")
        return True, "billingAccounts/012195-7EF76F-3A9083"

    def fake_account(_api, _name):
        calls.append("account")
        return False                                  # CLOSED

    def fake_job(_api, _project, _region):
        calls.append("job")
        raise prod_pulse.MeasurementError("cloudscheduler returned HTTP 403")

    def fake_sweep(_api, _project, _hours):
        calls.append("sweep")
        return NOW - dt.timedelta(hours=55), None

    def fake_refusal(_api, _project, _hours):
        calls.append("refusal")
        return NOW - dt.timedelta(minutes=59), "billing is disabled for this project"

    saved = (prod_pulse.GoogleApi, prod_pulse.token_from_firebase_cli,
             prod_pulse.measure_billing, prod_pulse.measure_billing_account,
             prod_pulse.measure_job, prod_pulse.measure_last_sweep,
             prod_pulse.measure_last_refusal)
    prod_pulse.GoogleApi = FakeApi
    prod_pulse.token_from_firebase_cli = lambda: "t"
    prod_pulse.measure_billing = fake_billing
    prod_pulse.measure_billing_account = fake_account
    prod_pulse.measure_job = fake_job
    prod_pulse.measure_last_sweep = fake_sweep
    prod_pulse.measure_last_refusal = fake_refusal
    try:
        code = prod_pulse.main(["--from-firebase-cli"])
    finally:
        (prod_pulse.GoogleApi, prod_pulse.token_from_firebase_cli,
         prod_pulse.measure_billing, prod_pulse.measure_billing_account,
         prod_pulse.measure_job, prod_pulse.measure_last_sweep,
         prod_pulse.measure_last_refusal) = saved

    check("main/exit", code == EXIT_FINDING,
          f"a measured closed account must survive a failing sibling probe; got {code}")
    check("main/kept-going-after-the-raise", "sweep" in calls,
          f"a raise in one probe must not skip the others; ran {calls}")
    check("main/read-the-account", "account" in calls,
          "the account's open flag is the authoritative billing fact (ADR-063 D4)")


def test_main_cannot_measure_only_when_it_found_nothing() -> None:
    """Everything readable is healthy, one probe raises -> 2, never 0."""
    import prod_pulse

    class FakeApi:
        server_now = NOW

        def __init__(self, *_a, **_k) -> None:
            pass

    def raising(*_a, **_k):
        raise prod_pulse.MeasurementError("logging returned HTTP 403")

    saved = (prod_pulse.GoogleApi, prod_pulse.token_from_firebase_cli,
             prod_pulse.measure_billing, prod_pulse.measure_billing_account,
             prod_pulse.measure_job, prod_pulse.measure_last_sweep,
             prod_pulse.measure_last_refusal)
    prod_pulse.GoogleApi = FakeApi
    prod_pulse.token_from_firebase_cli = lambda: "t"
    prod_pulse.measure_billing = lambda *_a: (True, "billingAccounts/x")
    prod_pulse.measure_billing_account = lambda *_a: True
    prod_pulse.measure_job = lambda *_a: ("ENABLED", 0)
    prod_pulse.measure_last_sweep = raising
    prod_pulse.measure_last_refusal = raising
    try:
        code = prod_pulse.main(["--from-firebase-cli"])
    finally:
        (prod_pulse.GoogleApi, prod_pulse.token_from_firebase_cli,
         prod_pulse.measure_billing, prod_pulse.measure_billing_account,
         prod_pulse.measure_job, prod_pulse.measure_last_sweep,
         prod_pulse.measure_last_refusal) = saved

    check("main/no-green-over-a-gap", code == EXIT_CANNOT_MEASURE,
          f"healthy-so-far plus an unread decisive fact must be 2, got {code}")


def test_no_credential_is_still_exit_2() -> None:
    """The one case that legitimately measures NOTHING keeps its old meaning."""
    import prod_pulse

    def no_token():
        raise prod_pulse.MeasurementError("no firebase CLI credential")

    saved = prod_pulse.token_from_firebase_cli
    prod_pulse.token_from_firebase_cli = no_token
    try:
        code = prod_pulse.main(["--from-firebase-cli"])
    finally:
        prod_pulse.token_from_firebase_cli = saved
    check("main/no-credential", code == EXIT_CANNOT_MEASURE, f"got {code}")


def test_the_lookback_outlives_an_outage() -> None:
    """ADR-063 D6. The 2026-08-22 outage was 55h old when it was found.

    At the shipped 48h default the tool could say "none in the window" but not
    WHEN the loop stopped, and the date is what an operator instruction is
    built from.
    """
    check("lookback/covers-a-week", DEFAULT_LOOKBACK_HOURS >= 168,
          f"a 55h-old outage must be datable; default is {DEFAULT_LOOKBACK_HOURS}h")


def test_the_refusal_reason_is_reported_with_its_timestamp() -> None:
    """ADR-063 D5. A reason with no time cannot be placed against the last sweep."""
    code, lines = verdict(
        billing_enabled=True,
        billing_account_open=False,
        job_state="ENABLED",
        job_status_code=13,
        last_sweep=NOW - dt.timedelta(hours=55),
        last_summary=None,
        last_refusal=(NOW - dt.timedelta(minutes=59),
                      "The request failed because billing is disabled for this project."),
        now=NOW,
    )
    joined = " ".join(lines)
    check("refusal/exit", code == EXIT_FINDING, f"got {code}")
    check("refusal/quoted", "billing is disabled" in joined,
          "the function's own words are the diagnosis; print them")
    check("refusal/timestamped", (NOW - dt.timedelta(minutes=59)).isoformat() in joined,
          "a reason with no timestamp cannot be placed against the last sweep")



# --------------------------------------------------------------------------
# ADR-064: the notifier text, and the credential the CI lane is allowed to hold.
# --------------------------------------------------------------------------

def test_a_green_sends_nothing() -> None:
    """Four runs a day that each post 'all fine' is how a channel gets muted."""
    check("notifier/green-is-silent", findings_for_notifier(EXIT_OK, ["the daily loop is running.", "billing: enabled"]) == "",
          "exit 0 must produce no notifier text at all")


def test_a_finding_and_a_gap_are_DIFFERENT_sentences() -> None:
    """ADR-064 D2c. Both reach a human; only one claims production is down."""
    finding = findings_for_notifier(EXIT_FINDING, [
        "FINDING: the linked billing account is CLOSED. …",
        "FINDING: the last COMPLETED sweep was 55.3h ago …",
        "COULD NOT MEASURE scheduler: … HTTP 403",
    ])
    gap = findings_for_notifier(EXIT_CANNOT_MEASURE, [
        "no finding in what could be read — but SOMETHING COULD NOT BE READ, so this is not a green.",
        "COULD NOT MEASURE sweep: … HTTP 403",
    ])
    check("notifier/finding-prefix", finding.startswith("production:"),
          f"exit 1 must be prefixed 'production:'; got {finding[:40]!r}")
    check("notifier/gap-prefix", gap.startswith("production (unmeasurable):"),
          f"exit 2 must say it could not look; got {gap[:40]!r}")
    check("notifier/prefixes-differ", finding.split(":")[0] != gap.split(":")[0],
          "the two must not collapse into one sentence — that is the whole of D2c")
    # The one thing a could-not-measure line must never do.
    check("notifier/gap-does-not-claim-an-outage",
          "FINDING" not in gap and "is CLOSED" not in gap,
          f"a gap must not read as an outage; got {gap!r}")
    # ...and the one thing a finding must always do.
    check("notifier/finding-carries-the-cause", "CLOSED" in finding,
          "the finding text must carry the cause, not just say 'there is a finding'")
    check("notifier/finding-carries-the-gap-too", "COULD NOT MEASURE scheduler" in finding,
          "a gap beside a finding must still reach the reader (ADR-063 D2)")


def test_the_notifier_text_survives_slack() -> None:
    """It is interpolated into a JSON payload and rendered as Slack text.

    A finding is one line per fact; embedded newlines are the format, but a
    payload-breaking character is not. Assert the shape rather than trusting it.
    """
    text = findings_for_notifier(EXIT_FINDING, ["FINDING: a\nb", "COULD NOT MEASURE x: y"])
    check("notifier/no-cr", "\r" not in text, "a CR would split the line in the payload")
    check("notifier/nonempty", text.strip() != "")
    check("notifier/is-text-not-json", not text.lstrip().startswith("{"),
          "the notifier takes text; emitting JSON here would render as JSON to a human")


def test_the_ci_credential_cannot_read_billing() -> None:
    """ADR-064 D3, pinned as a constant because widening it must be deliberate.

    This repository is PUBLIC. `roles/billing.viewer` — measured — carries
    getPaymentInfo, getSpendingInformation, credits.list, getIamPolicy and an
    inventory of every project on the billing account. The CI lane is therefore
    scoped to LOGGING ONLY, and the billing-account read stays on the local
    firebase-CLI path where no key is stored anywhere.
    """
    check("scope/logging-only", PULSE_SCOPE == "https://www.googleapis.com/auth/logging.read",
          f"the CI scope must be logging-read only; got {PULSE_SCOPE!r}")
    for forbidden in ("cloud-platform", "billing", "firebase.readonly"):
        check(f"scope/excludes({forbidden})", forbidden not in PULSE_SCOPE,
              f"{forbidden!r} must not appear in the CI scope — ADR-064 D3")
    check("scope/secret-name", PULSE_SECRET == "PROD_PULSE_VIEWER_SA",
          f"got {PULSE_SECRET!r}")
    # A DIFFERENT secret from the rules/functions viewer, deliberately: that one
    # carries firebase.readonly, which cannot read Logging at all, and reusing
    # its name would make an operator think one grant armed both.
    from rules_drift import VIEWER_SECRET
    check("scope/distinct-from-rules-viewer", PULSE_SECRET != VIEWER_SECRET,
          "reusing the rules-viewer secret would hide that this needs a different grant")


def test_a_malformed_secret_is_a_named_error_not_a_crash() -> None:
    """The likeliest way this lane is ever mis-armed: a truncated paste.

    `json.loads` raises JSONDecodeError, which `main()` does not catch — the
    process would die with a traceback and an EMPTY stdout, and in
    --notifier-findings mode the lane captures stdout, so the watcher would post
    NOTHING while appearing to have run. A watcher that watches nothing is the
    exact failure this lane exists to end, so it must be a MeasurementError.
    """
    import prod_pulse

    class Args:
        access_token = None
        sa_file = None
        from_firebase_cli = False

    saved = dict(os.environ)
    for junk, label in (("{not json", "truncated"), ('"a string"', "not an object"), ("", "empty")):
        os.environ.clear()
        os.environ.update(saved)
        os.environ.pop("PROD_PULSE_ACCESS_TOKEN", None)
        os.environ[PULSE_SECRET] = junk
        try:
            prod_pulse.resolve_credential(Args())
            # An empty string is falsy, so it falls through to the no-credential
            # error — also a MeasurementError, which is the point.
            check(f"malformed/{label}", False, "expected MeasurementError")
        except prod_pulse.MeasurementError as exc:
            check(f"malformed/{label}-names-source",
                  PULSE_SECRET in str(exc),
                  f"the error must name WHERE the bad credential came from; got {exc!r}")
            check(f"malformed/{label}-does-not-echo",
                  junk not in str(exc) or junk == "",
                  "the error must never echo the credential value")
        except Exception as exc:  # noqa: BLE001 — the whole point of the test
            check(f"malformed/{label}", False,
                  f"raised {type(exc).__name__}, not MeasurementError — this is the crash")
    os.environ.clear()
    os.environ.update(saved)


def test_no_credential_names_the_operator_item() -> None:
    """A tool that cannot run must say which grant is missing, not just fail."""
    import prod_pulse

    class Args:
        access_token = None
        sa_file = None
        from_firebase_cli = False

    saved = dict(os.environ)
    os.environ.pop(PULSE_SECRET, None)
    os.environ.pop("PROD_PULSE_ACCESS_TOKEN", None)
    try:
        prod_pulse.resolve_credential(Args())
        check("credential/none-raises", False, "expected MeasurementError")
    except prod_pulse.MeasurementError as exc:
        msg = str(exc)
        check("credential/names-the-secret", PULSE_SECRET in msg, f"got {msg!r}")
        check("credential/names-the-local-path", "--from-firebase-cli" in msg, f"got {msg!r}")
        check("credential/does-not-pretend", "pretend" in msg or "cannot run" in msg,
              f"it must say it will not pretend to pass; got {msg!r}")
    finally:
        os.environ.clear()
        os.environ.update(saved)


for name, fn in list(globals().items()):
    if name.startswith("test_"):
        section(name, fn)

if failures:
    print(f"prod_pulse_test: {len(failures)} FAILED", file=sys.stderr)
    for f in failures:
        print("  - " + f, file=sys.stderr)
    sys.exit(1)
print("prod_pulse_test: all checks passed")
