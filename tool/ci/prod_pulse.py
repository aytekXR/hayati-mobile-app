#!/usr/bin/env python3
"""Is the daily loop actually RUNNING in production? (#219)

WHY THIS EXISTS. Between 2026-08-09T18:00Z and 2026-08-11T07:19Z the
`questionRollover` sweep did not run once. Cloud Run refused all 38 invocations
at the serving layer — `HTTP 500 "The request failed because billing is disabled
for this project."`, latency 0s, the container never started — so no day doc was
created, no couple got a question on 2026-08-10, and no push was ever composed.
Nothing noticed. The founder did, two days later.

THE MISTAKE THIS TOOL EXISTS TO MAKE IMPOSSIBLE. `docs/operator-expected.md`
reported the opposite that whole time — *"Your app is running. The hourly job
fired all day, most recently 21:00 UTC today"* — because a session read
`firebase functions:log` and saw a line at every hour. Every one of those lines
was the ERROR. An invocation ATTEMPT and a completed sweep are different events,
and the log stream shows both under the same function name, one letter apart
(`I` vs `E`).

So the verdict here is keyed on the sweep's OWN completion record —
`question_rollover: sweep complete`, which only `question-rollover.ts` can emit
and only after `runQuestionRollover` has returned — and never on the scheduler
having attempted anything. `state: ENABLED` with a fresh `lastAttemptTime` is
precisely what a dead backend looks like: Cloud Scheduler was ENABLED and firing
punctually for all 38 of those failures.

EXIT CODES ARE A TAXONOMY (the `rules_drift.py` rule, restated):

    0   the sweep completed within --max-age-minutes. The loop is running.
    1   FINDING — it did not, or billing is off, or the job is paused/erroring.
    2   COULD NOT MEASURE — no credential, an API error, an unparseable
        response. NEVER 0.

CREDENTIAL. `--from-firebase-cli` only. The service-account path `rules_drift`
offers is deliberately NOT wired here: its `firebase.readonly` scope cannot read
Cloud Logging, Cloud Scheduler or Cloud Billing, so wiring it would produce a
confident exit 2 on every CI run. The founder's logged-in CLI carries
`cloud-platform`, which is why this is a local instrument — the same one, and
the same credential plumbing, `rules_drift.py --from-firebase-cli` already uses.
"""
from __future__ import annotations

import argparse
import datetime as dt
import email.utils as eut
import json
import sys
import urllib.error
import urllib.parse
import urllib.request

# The credential plumbing is rules_drift's, imported rather than re-implemented:
# one place learns that firebase-tools moved its OAuth constants.
from rules_drift import MeasurementError, token_from_firebase_cli

BILLING_API = "https://cloudbilling.googleapis.com/v1/"
SCHEDULER_API = "https://cloudscheduler.googleapis.com/v1/"
LOGGING_API = "https://logging.googleapis.com/v2/"

EXIT_OK = 0
EXIT_FINDING = 1
EXIT_CANNOT_MEASURE = 2

# The sweep is hourly (`schedule: '0 * * * *'`). One missed hour plus slack for a
# cold start is a real finding; anything under that is ordinary jitter.
DEFAULT_MAX_AGE_MINUTES = 90

# Emitted by question-rollover.ts after the assignment pass returns. Matching the
# message rather than the severity is deliberate: an ERROR line and an INFO line
# both carry the function's name, and only this string carries its COMPLETION.
SWEEP_COMPLETE = "question_rollover: sweep complete"


# --------------------------------------------------------------------------
# pure verdict logic (everything below the network, and all of what is tested)
# --------------------------------------------------------------------------

def sweep_age_minutes(last_sweep: dt.datetime | None, now: dt.datetime) -> float | None:
    """Minutes since the last COMPLETED sweep; None when there has never been one."""
    if last_sweep is None:
        return None
    return (now - last_sweep).total_seconds() / 60.0


def verdict(
    *,
    billing_enabled: bool,
    job_state: str | None,
    job_status_code: int,
    last_sweep: dt.datetime | None,
    last_summary: dict | None,
    now: dt.datetime,
    max_age_minutes: float = DEFAULT_MAX_AGE_MINUTES,
) -> tuple[int, list[str]]:
    """The whole decision, as a pure function of measured facts.

    Findings accumulate — a paused job AND a stale sweep are two lines, not one,
    because the second is the consequence and the first is the cause, and a
    report that prints only the consequence sends the reader to the wrong place.
    """
    findings: list[str] = []
    notes: list[str] = []

    if not billing_enabled:
        findings.append(
            "BILLING IS OFF for this project. Cloud Run will refuse every invocation "
            "at the serving layer (HTTP 500, container never starts) and nothing else "
            "here can be true until it is restored.")
    else:
        notes.append("billing: enabled")

    if job_state is None:
        findings.append(
            "no Cloud Scheduler job for questionRollover — the sweep has no trigger.")
    elif job_state != "ENABLED":
        findings.append(f"Cloud Scheduler job is {job_state}, not ENABLED — it will not fire.")
    else:
        notes.append("scheduler job: ENABLED")

    # gRPC status on the LAST attempt. 0/absent is success; 13 (INTERNAL) is what
    # the billing refusal produced for 38 consecutive hours.
    if job_status_code:
        findings.append(
            f"the scheduler's LAST attempt failed (gRPC status {job_status_code}). "
            "Note this is the ATTEMPT, not the sweep — see the age line below for "
            "whether any sweep has since completed.")

    age = sweep_age_minutes(last_sweep, now)
    if age is None:
        findings.append(
            f"no {SWEEP_COMPLETE!r} record found in the searched window — the sweep "
            "has not completed once. An hourly line in `functions:log` is NOT this.")
    elif age > max_age_minutes:
        findings.append(
            f"the last COMPLETED sweep was {age / 60:.1f}h ago "
            f"({last_sweep.isoformat()}), over the {max_age_minutes:.0f}m threshold. "
            "The daily question is not being assigned.")
    else:
        notes.append(f"last completed sweep: {age:.0f}m ago ({last_sweep.isoformat()})")

    if last_summary:
        notes.append(
            "last sweep summary: "
            + ", ".join(f"{k}={last_summary[k]}" for k in sorted(last_summary)
                        if k not in ("message", "at")))

    if findings:
        return EXIT_FINDING, ["FINDING: " + f for f in findings] + notes
    return EXIT_OK, ["the daily loop is running."] + notes


# --------------------------------------------------------------------------
# the API surface
# --------------------------------------------------------------------------

class GoogleApi:
    """Every response also yields GOOGLE's clock, which is the one that matters.

    The verdict is "how long since the last sweep", and both operands must come
    from the same clock. The log timestamps are Google's; taking `now` from the
    local box compares two clocks and silently mis-ages the result by whatever
    they differ by — a slow local clock makes a dead loop look freshly swept,
    which is the failure direction this whole tool exists to refuse. So `now` is
    read off the `Date` response header of a call we are already making, and the
    local clock is only the fallback for a response that carried none.
    """

    def __init__(self, access_token: str) -> None:
        self._token = access_token
        self.server_now: dt.datetime | None = None

    def call(self, url: str, payload: dict | None = None) -> dict:
        data = json.dumps(payload).encode() if payload is not None else None
        headers = {"Authorization": "Bearer " + self._token}
        if data:
            headers["Content-Type"] = "application/json"
        try:
            with urllib.request.urlopen(
                urllib.request.Request(url, data=data, headers=headers), timeout=60
            ) as resp:
                self.server_now = parse_http_date(resp.headers.get("Date"))
                return json.load(resp)
        except urllib.error.HTTPError as exc:
            raise MeasurementError(f"{url.split('?')[0]} returned HTTP {exc.code}") from None
        except (OSError, json.JSONDecodeError) as exc:
            raise MeasurementError(f"{url.split('?')[0]} unreachable/unparseable: {exc}") from None


def parse_http_date(value: str | None) -> dt.datetime | None:
    """RFC 7231 `Date` header → aware UTC datetime; None on absent/unparseable."""
    if not value:
        return None
    try:
        parsed = eut.parsedate_to_datetime(value)
    except (TypeError, ValueError):
        return None
    if parsed is None:
        return None
    return parsed if parsed.tzinfo else parsed.replace(tzinfo=dt.timezone.utc)


def measure_billing(api: GoogleApi, project: str) -> bool:
    info = api.call(f"{BILLING_API}projects/{project}/billingInfo")
    return bool(info.get("billingEnabled"))


def measure_job(api: GoogleApi, project: str, region: str) -> tuple[str | None, int]:
    listing = api.call(f"{SCHEDULER_API}projects/{project}/locations/{region}/jobs")
    for job in listing.get("jobs") or []:
        if "questionRollover" in job.get("name", ""):
            return job.get("state"), int((job.get("status") or {}).get("code") or 0)
    return None, 0


def measure_last_sweep(
    api: GoogleApi, project: str, lookback_hours: int
) -> tuple[dt.datetime | None, dict | None]:
    """The most recent COMPLETED sweep, from the function's own log record."""
    since = (dt.datetime.now(dt.timezone.utc) - dt.timedelta(hours=lookback_hours))
    body = {
        "resourceNames": [f"projects/{project}"],
        "filter": (
            f'timestamp >= "{since.strftime("%Y-%m-%dT%H:%M:%SZ")}" AND '
            f'jsonPayload.message = "{SWEEP_COMPLETE}"'
        ),
        "orderBy": "timestamp desc",
        "pageSize": 1,
    }
    entries = api.call(f"{LOGGING_API}entries:list", body).get("entries") or []
    if not entries:
        return None, None
    entry = entries[0]
    stamp = entry.get("timestamp")
    try:
        when = dt.datetime.fromisoformat(stamp.replace("Z", "+00:00"))
    except (AttributeError, ValueError):
        raise MeasurementError(f"log entry carried an unparseable timestamp: {stamp!r}") from None
    return when, entry.get("jsonPayload") or None


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--project", default="hayatiapp-prod")
    parser.add_argument("--region", default="europe-west1")
    parser.add_argument("--max-age-minutes", type=float, default=DEFAULT_MAX_AGE_MINUTES)
    parser.add_argument("--lookback-hours", type=int, default=48)
    parser.add_argument("--from-firebase-cli", action="store_true", required=True,
                        help="the only supported credential; see the module docstring")
    args = parser.parse_args(argv)

    try:
        api = GoogleApi(token_from_firebase_cli())
        billing = measure_billing(api, args.project)
        state, status = measure_job(api, args.project, args.region)
        last, summary = measure_last_sweep(api, args.project, args.lookback_hours)
    except MeasurementError as exc:
        print(f"could not measure: {exc}", file=sys.stderr)
        return EXIT_CANNOT_MEASURE

    now = api.server_now or dt.datetime.now(dt.timezone.utc)
    code, lines = verdict(
        billing_enabled=billing,
        job_state=state,
        job_status_code=status,
        last_sweep=last,
        last_summary=summary,
        now=now,
        max_age_minutes=args.max_age_minutes,
    )
    print(f"{args.project} ({args.region})")
    if api.server_now is None:
        print("  note: no Date header on the API response — aged against the LOCAL clock")
    for line in lines:
        print("  " + line)
    return code


if __name__ == "__main__":
    sys.exit(main())
