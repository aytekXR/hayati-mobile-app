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

    0   EVERY fact was measured and none of them is a finding. The loop is
        running, and we looked at all of it.
    1   FINDING — the sweep is stale/absent, or billing is off, or the job is
        paused/erroring. Findings BEAT gaps: a real finding is reported at 1
        even when some other fact could not be read, with the gap printed
        beside it.
    2   COULD NOT MEASURE — no credential, or nothing was found AND at least
        one fact could not be read. NEVER 0.

⚠️ **A GAP CAN NEVER PRODUCE A GREEN, AND A GAP IS NOT AN ABSENCE** (ADR-063,
after this tool met the identical outage on 2026-08-22 and returned exit 2).

Revision 1 measured all three facts inside ONE `try`, so the first failure threw
away every fact already in hand. On 2026-08-27 that meant: `measure_billing`
SUCCEEDED, `measure_job` raised HTTP 403, `measure_last_sweep` never ran — and
the tool printed `could not measure` while holding the answer. Worse, the 403 was
not bad luck: **Cloud Scheduler returns 403 BECAUSE billing is off** ("This API
method requires billing to be enabled"), so the one state this tool exists to
detect was the one state that guaranteed it could not report. A health check
whose blind spot is its own subject (lesson 114).

Two rules follow, and both are asserted in the test file:

  * a fact that could not be measured **can never contribute to a green** — no
    finding plus any gap is **2**, never 0 (ADR-041: "never 0 without having
    compared");
  * a gap is **not** an absence — `job_state=None` means "I looked and there is
    no job", so an unreadable scheduler must NOT raise that finding, or the
    report invents a cause.

⚠️ **`billingEnabled` IS NOT WHETHER BILLING WORKS.** It says the project is
LINKED to an account. Through the whole 2026-08-22 outage it read `true` while
the account behind it was `"open": false` and Cloud Run refused every invocation
with "billing is disabled for this project". Healthy is **linked AND open**;
linked-but-closed is its own finding.

CREDENTIAL — TWO PATHS, AND THEY SEE DIFFERENT THINGS (ADR-064 D3/D4).

⚠️ This section said `--from-firebase-cli` ONLY, and that the service-account path
was *"deliberately NOT wired here"* because `firebase.readonly` cannot read Cloud
Logging, Scheduler or Billing. **That was a statement about that ROLE, not about
service accounts**, and it went stale the moment a CI lane needed one — the exact
class ADR-063 D7 made a rule against, left in the file whose own ADR wrote the rule.

  * `--from-firebase-cli` — the founder's logged-in CLI, which carries
    `cloud-platform` and is therefore the ONLY path that can read the billing
    ACCOUNT's `open` flag. **Local only**, and the richer report.
  * `--sa-file` / `$PROD_PULSE_VIEWER_SA` — the CI lane, scoped to
    **`logging.read` and nothing else** (see PULSE_SCOPE below for why that is a
    security decision on a PUBLIC repo, not minimalism). It reads the sweep's own
    completion record and the refusal reason, which is the whole verdict; billing
    and scheduler become NAMED GAPS, and a gap can never produce a green.

Same credential plumbing either way: `rules_drift.py` owns the OAuth dance and
takes the scope as a parameter, so one place learns that firebase-tools moved its
constants.
"""
from __future__ import annotations

import argparse
import datetime as dt
import os
import pathlib
import email.utils as eut
import json
import sys
import urllib.error
import urllib.parse
import urllib.request

# The credential plumbing is rules_drift's, imported rather than re-implemented:
# one place learns that firebase-tools moved its OAuth constants.
from rules_drift import MeasurementError, token_from_firebase_cli, token_from_service_account

BILLING_API = "https://cloudbilling.googleapis.com/v1/"
SCHEDULER_API = "https://cloudscheduler.googleapis.com/v1/"
LOGGING_API = "https://logging.googleapis.com/v2/"

EXIT_OK = 0
EXIT_FINDING = 1
EXIT_CANNOT_MEASURE = 2

# The sweep is hourly (`schedule: '0 * * * *'`). One missed hour plus slack for a
# cold start is a real finding; anything under that is ordinary jitter.
DEFAULT_MAX_AGE_MINUTES = 90

# How far back to SEARCH for the last completed sweep. Deliberately much wider
# than DEFAULT_MAX_AGE_MINUTES, which is what decides the verdict: the window
# only decides whether the report can say WHEN the loop stopped. At the old 48h
# the 2026-08-22 outage (55h old when it was found) could only be reported as
# "none in the searched window" — true, and useless for writing the operator
# instruction, which is built from the date (ADR-063 D6).
DEFAULT_LOOKBACK_HOURS = 168

# Emitted by question-rollover.ts after the assignment pass returns. Matching the
# message rather than the severity is deliberate: an ERROR line and an INFO line
# both carry the function's name, and only this string carries its COMPLETION.
SWEEP_COMPLETE = "question_rollover: sweep complete"

# Cloud Run lowercases the function name into the service label. This is the
# label the REFUSALS carry — they are emitted by the serving layer before the
# container starts, so they carry no jsonPayload.message at all.
SWEEP_SERVICE = "questionrollover"

# ---------------------------------------------------------------------------
# The CI credential (ADR-064 D3). LOGGING ONLY, and that is a security decision
# rather than a minimalism preference.
#
# THIS REPOSITORY IS PUBLIC. A leaked key is a leaked key, so the question is not
# "can this role write" but "what does it let a reader SEE". Measured against the
# IAM API on 2026-08-28, `roles/billing.viewer` — the obvious grant, and the one
# an earlier draft of ADR-064 asked for — carries:
#
#     billing.accounts.getPaymentInfo         billing.accounts.getIamPolicy
#     billing.accounts.getSpendingInformation billing.resourceAssociations.list
#     billing.credits.list
#
# i.e. the founder's payment metadata, their spend, and an inventory of every
# project attached to that billing account. It has no write permissions at all,
# which is exactly why checking it for writes and stopping was not enough.
#
# The lane does not need it. The fact it must report — WHY the loop stopped — is
# in Cloud Logging in the platform's own words ("The request failed because
# billing is disabled for this project"), and under ADR-063 D2 the billing and
# scheduler probes then degrade to NAMED GAPS rather than to silence, and a gap
# can never produce a green. The reduced credential can only make this lane say
# LESS, out loud.
#
# The billing-account read stays on `--from-firebase-cli`, where the founder's
# own credential already has it and no key is stored anywhere. If CI precision is
# ever wanted, the path is a CUSTOM role carrying only `billing.accounts.get`
# (measured: customRolesSupportLevel = SUPPORTED), never `billing.viewer`.
PULSE_SCOPE = "https://www.googleapis.com/auth/logging.read"

# Deliberately NOT `FIREBASE_RULES_VIEWER_SA`. That secret carries
# `firebase.readonly`, which cannot read Cloud Logging at all — sharing the name
# would let an operator believe one grant armed both lanes.
PULSE_SECRET = "PROD_PULSE_VIEWER_SA"


# --------------------------------------------------------------------------
# pure verdict logic (everything below the network, and all of what is tested)
# --------------------------------------------------------------------------

def sweep_age_minutes(last_sweep: dt.datetime | None, now: dt.datetime) -> float | None:
    """Minutes since the last COMPLETED sweep; None when there has never been one."""
    if last_sweep is None:
        return None
    return (now - last_sweep).total_seconds() / 60.0


# What Cloud Run does in every "billing is off" state. Written once because it
# is the same consequence four times over; only the CAUSE and the next action
# differ, and those are what the four branches below are for.
_REFUSAL = (
    "Cloud Run will refuse every invocation at the serving layer (HTTP 500, "
    "container never starts) and nothing else here can be true until it is "
    "restored."
)


def billing_findings(
    *,
    billing_enabled: bool,
    account_name: str | None,
    account_open: bool | None,
) -> list[str]:
    """The billing verdict, as a list of findings (empty = healthy).

    THREE facts, and each shipped revision has had one fewer than it needed.

    `billingEnabled` says the project is LINKED to a billing account; `open` says
    that account still pays for anything. On 2026-08-22 they disagreed for six
    days — linked, closed, and every Cloud Run invocation refused — which is why
    the reassuring one is not the authoritative one (ADR-063 D4).

    ⚠️ **`account_name` is the third, and without it this function cannot tell
    "not linked" from "linked and switched off"** (ADR-066, #267). Revision 2
    returned early on `not billing_enabled` with *"no billing account is
    linked"*, never consulting `account_open` — which `main()` had already
    measured in the same run. Measured 2026-08-30 on both projects:
    `billingEnabled=False`, `billingAccountName=billingAccounts/012195-…`,
    `open=False`, so the report printed that sentence directly beneath a line
    naming the linked account. It is the instruction the founder acts on
    (`operator-expected.md` item 1) and the text the watcher posts (ADR-064 D2b),
    and it sent them looking for a link that was already there. This is ADR-063's
    own defect one layer up: D2 stopped the MEASUREMENT discarding facts it held;
    the REPORTING still did.

    `account_open is None` means the account document could not be read. That is
    a GAP — named, never assumed in either direction. With billing ON it raises
    no finding at all (the caller names the gap); with billing OFF it is still a
    finding, because billing being off is itself the finding, but the sentence
    says the account state is unknown rather than inventing one.
    """
    if not billing_enabled:
        if account_name is None:
            return [
                "BILLING IS OFF for this project — no billing account is linked. "
                + _REFUSAL
            ]
        if account_open is False:
            return [
                f"BILLING IS OFF for this project, and the account it is linked to "
                f"({account_name}) is CLOSED. Reopen that account with a working "
                f"payment method, or link this project to an open one — then check "
                f"the project shows billing enabled again. " + _REFUSAL
            ]
        if account_open is None:
            return [
                f"BILLING IS OFF for this project. It is linked to {account_name}, "
                f"whose own open/closed state COULD NOT BE READ, so the cause is "
                f"not established here — check that account first. " + _REFUSAL
            ]
        return [
            f"BILLING IS OFF for this project even though the account it is linked "
            f"to ({account_name}) is OPEN — so this is the project's own billing "
            f"switch, not the card. Enable billing on this project; if you have "
            f"just reopened the account, it may still be propagating. " + _REFUSAL
        ]
    if account_open is False:
        return [
            "the linked billing account is CLOSED. The project still reports "
            "billingEnabled:true — that only means it is LINKED — while Cloud Run "
            "refuses every invocation with 'billing is disabled for this project'. "
            "Nothing else here can be true until the account is reopened or the "
            "project is linked to an open one."
        ]
    return []


def verdict(
    *,
    billing_enabled: bool,
    job_state: str | None,
    job_status_code: int,
    last_sweep: dt.datetime | None,
    last_summary: dict | None,
    now: dt.datetime,
    max_age_minutes: float = DEFAULT_MAX_AGE_MINUTES,
    billing_account_open: bool | None = None,
    billing_account_name: str | None = None,
    last_refusal: tuple[dt.datetime, str] | None = None,
    gaps: dict[str, str] | None = None,
) -> tuple[int, list[str]]:
    """The whole decision, as a pure function of measured facts AND named gaps.

    Findings accumulate — a paused job AND a stale sweep are two lines, not one,
    because the second is the consequence and the first is the cause, and a
    report that prints only the consequence sends the reader to the wrong place.

    `gaps` maps a fact name ("billing", "account", "scheduler", "sweep",
    "refusal") to the reason it could not be measured. A fact named there is
    NEVER turned into a finding: `job_state=None` means "I looked and there is
    no job", and reporting that for a scheduler that merely returned 403 invents
    a cause. The gap is printed on its own line instead.
    """
    findings: list[str] = []
    notes: list[str] = []
    gaps = gaps or {}

    # --- billing -----------------------------------------------------------
    if "billing" in gaps:
        pass  # named below; no assumption in either direction
    else:
        # ⚠️ THREE arguments, not two. `billing_findings` needs the account NAME
        # to tell "not linked" from "linked and switched off" (ADR-066 #267);
        # `verdict` carries it for no other reason and decides nothing with it.
        billing = billing_findings(
            billing_enabled=billing_enabled,
            account_name=billing_account_name,
            account_open=billing_account_open,
        )
        findings.extend(billing)
        if not billing:
            if billing_account_open is True:
                notes.append("billing: linked to an OPEN account")
            elif "account" in gaps:
                notes.append("billing: linked (the account's open flag is a gap below)")
            else:
                notes.append("billing: enabled")

    # --- the scheduler job -------------------------------------------------
    if "scheduler" in gaps:
        pass
    elif job_state is None:
        findings.append(
            "no Cloud Scheduler job for questionRollover — the sweep has no trigger.")
    elif job_state != "ENABLED":
        findings.append(f"Cloud Scheduler job is {job_state}, not ENABLED — it will not fire.")
    else:
        notes.append("scheduler job: ENABLED")

    # gRPC status on the LAST attempt. 0/absent is success; 13 (INTERNAL) is what
    # the billing refusal produced for 38 consecutive hours.
    if "scheduler" not in gaps and job_status_code:
        findings.append(
            f"the scheduler's LAST attempt failed (gRPC status {job_status_code}). "
            "Note this is the ATTEMPT, not the sweep — see the age line below for "
            "whether any sweep has since completed.")

    # --- the sweep itself, which is the question in this tool's title -------
    age = sweep_age_minutes(last_sweep, now)
    if "sweep" in gaps:
        pass
    elif age is None:
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

    # --- WHY, in the function's own words ----------------------------------
    # The absence says the loop stopped; only this says what stopped it. Printed
    # WITH its timestamp so a reader can place it against the last sweep instead
    # of having to trust that it is current (ADR-063 D5).
    if last_refusal is not None:
        when, message = last_refusal
        notes.append(f"most recent refusal ({when.isoformat()}): {message}")

    # --- the exit rule (ADR-063 D2) ----------------------------------------
    # A fact that could not be measured can never contribute to a green.
    for name in sorted(gaps):
        notes.append(f"COULD NOT MEASURE {name}: {gaps[name]}")

    if findings:
        return EXIT_FINDING, ["FINDING: " + f for f in findings] + notes
    if gaps:
        return EXIT_CANNOT_MEASURE, [
            "no finding in what could be read — but SOMETHING COULD NOT BE READ, "
            "so this is not a green."
        ] + notes
    return EXIT_OK, ["the daily loop is running."] + notes


def findings_for_notifier(code: int, lines: list[str]) -> str:
    """The text the CI lane hands `slack_notify.sh` as EXTRA_FINDINGS (ADR-064 D2c).

    Pure, so the one distinction that matters can be asserted hermetically:

      * exit 0 -> **the empty string**. The lane runs four times a day; a green
        that posts anything is four messages a day into a channel that then gets
        muted, and a muted channel swallows the `integration-emulator` red this
        whole integration exists to deliver (ADR-024 D2).
      * exit 1 -> prefixed `production:` — this IS an outage, and the cause rides
        along verbatim.
      * exit 2 -> prefixed `production (unmeasurable):` — a human is still told,
        because a watcher that silently watches nothing is the failure this lane
        was built after. But it must not read as an outage, because it is not
        one: it is the same *"I looked and it is broken"* versus *"I could not
        look"* pair ADR-041 made a taxonomy and ADR-063 D2 wrote into `verdict()`.
    """
    if code == EXIT_OK:
        return ""
    prefix = "production:" if code == EXIT_FINDING else "production (unmeasurable):"
    body = " · ".join(line.strip().replace("\r", " ").replace("\n", " ")
                      for line in lines if line.strip())
    return f"{prefix} {body}".strip()


def _service_account_json(raw: str, source: str) -> dict:
    """Parse a service-account key, and fail as a MEASUREMENT ERROR, not a crash.

    A truncated paste into a repository secret is the likeliest way this lane is
    ever mis-armed, and `json.loads` raises `JSONDecodeError` — which `main()`
    does NOT catch, so the process would die with a traceback on stderr and an
    EMPTY stdout. In `--notifier-findings` mode the lane captures stdout, so the
    watcher would post nothing while appearing to have run: a watcher that
    watches nothing, which is the failure this whole lane exists to end.

    The message deliberately names the SOURCE and never echoes the value.
    """
    try:
        parsed = json.loads(raw)
    except (json.JSONDecodeError, TypeError):
        raise MeasurementError(
            f"the credential in {source} is not valid JSON — a service-account key is "
            "a JSON document; check it was pasted whole") from None
    if not isinstance(parsed, dict):
        raise MeasurementError(
            f"the credential in {source} parsed as {type(parsed).__name__}, not an object "
            "— it is not a service-account key")
    return parsed


def resolve_credential(args: argparse.Namespace) -> str:
    """First credential that resolves, most explicit first. No default.

    `--from-firebase-cli` was `required=True` until ADR-064 D4, and the module
    docstring said a service-account path was *"deliberately NOT wired here"*
    because `firebase.readonly` cannot read Logging, Scheduler or Billing. That
    was true, and it was a statement about **that role**, not about service
    accounts: a key scoped to `logging.read` reads exactly the fact this tool's
    verdict is keyed on.
    """
    if getattr(args, "access_token", None):
        return args.access_token
    if os.environ.get("PROD_PULSE_ACCESS_TOKEN"):
        return os.environ["PROD_PULSE_ACCESS_TOKEN"]
    if getattr(args, "sa_file", None):
        return token_from_service_account(
            _service_account_json(pathlib.Path(args.sa_file).read_text(), args.sa_file),
            scope=PULSE_SCOPE)
    if os.environ.get(PULSE_SECRET):
        return token_from_service_account(
            _service_account_json(os.environ[PULSE_SECRET], f"${PULSE_SECRET}"),
            scope=PULSE_SCOPE)
    if getattr(args, "from_firebase_cli", False):
        return token_from_firebase_cli()
    raise MeasurementError(
        "no credential. This check cannot run without one and it will not pretend "
        f"to pass: set the {PULSE_SECRET} repository secret (a service account with "
        "roles/logging.viewer on both projects — see docs/operator-expected.md), or "
        "pass --from-firebase-cli on a box where the firebase CLI is logged in.")


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


def measure_billing(api: GoogleApi, project: str) -> tuple[bool, str | None]:
    """Whether the project is LINKED, and to WHICH account.

    Deliberately NOT the whole billing answer — see measure_billing_account. This
    call is the one that reads `true` while the account behind it is closed.
    """
    info = api.call(f"{BILLING_API}projects/{project}/billingInfo")
    return bool(info.get("billingEnabled")), info.get("billingAccountName") or None


def measure_billing_account(api: GoogleApi, account_name: str) -> bool:
    """Whether the linked account is still OPEN — the authoritative fact.

    `account_name` is the resource path billingInfo returned
    ("billingAccounts/012195-7EF76F-3A9083"), never a hand-built id.
    """
    account = api.call(f"{BILLING_API}{account_name}")
    return bool(account.get("open"))


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
    return _entry_time(entry), entry.get("jsonPayload") or None


def _entry_time(entry: dict) -> dt.datetime:
    stamp = entry.get("timestamp")
    try:
        return dt.datetime.fromisoformat(stamp.replace("Z", "+00:00"))
    except (AttributeError, ValueError):
        raise MeasurementError(f"log entry carried an unparseable timestamp: {stamp!r}") from None


def measure_last_refusal(
    api: GoogleApi, project: str, lookback_hours: int
) -> tuple[dt.datetime, str] | None:
    """The most recent ERROR the sweep's own service emitted, and when.

    The absence of a completion says the loop stopped; only this says WHAT
    stopped it, and it says it in the platform's own words — on 2026-08-22 that
    was "The request failed because billing is disabled for this project."
    Returned WITH its timestamp (ADR-063 D5): a reason with no time cannot be
    placed against the last completed sweep, and a stale reason read as current
    is how a fixed outage gets re-diagnosed.
    """
    since = (dt.datetime.now(dt.timezone.utc) - dt.timedelta(hours=lookback_hours))
    body = {
        "resourceNames": [f"projects/{project}"],
        "filter": (
            f'timestamp >= "{since.strftime("%Y-%m-%dT%H:%M:%SZ")}" AND '
            f'resource.labels.service_name="{SWEEP_SERVICE}" AND severity>=ERROR'
        ),
        "orderBy": "timestamp desc",
        "pageSize": 1,
    }
    entries = api.call(f"{LOGGING_API}entries:list", body).get("entries") or []
    if not entries:
        return None
    entry = entries[0]
    payload = entry.get("textPayload")
    if not isinstance(payload, str) or not payload.strip():
        json_payload = entry.get("jsonPayload") or {}
        payload = str(json_payload.get("message") or json_payload or "").strip()
    return _entry_time(entry), payload or "(an error with no message)"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--project", default="hayatiapp-prod")
    parser.add_argument("--region", default="europe-west1")
    parser.add_argument("--max-age-minutes", type=float, default=DEFAULT_MAX_AGE_MINUTES)
    parser.add_argument("--lookback-hours", type=int, default=DEFAULT_LOOKBACK_HOURS)
    parser.add_argument("--from-firebase-cli", action="store_true",
                        help="mint from the logged-in firebase CLI (the local path; "
                             "the ONLY one that can read the billing account)")
    parser.add_argument("--sa-file", help=f"service-account JSON; scoped to {PULSE_SCOPE}")
    parser.add_argument("--access-token", help="a pre-minted OAuth token (testing)")
    parser.add_argument("--notifier-findings", action="store_true",
                        help="print ONLY the EXTRA_FINDINGS text for the CI lane "
                             "(empty when healthy) — the report still goes to stderr")
    args = parser.parse_args(argv)

    # The credential is the ONE thing whose absence really does mean "nothing
    # could be measured". Everything after it is measured independently.
    try:
        api = GoogleApi(resolve_credential(args))
    except MeasurementError as exc:
        print(f"could not measure: {exc}", file=sys.stderr)
        return EXIT_CANNOT_MEASURE

    gaps: dict[str, str] = {}

    def probe(name: str, fn, *fn_args, default):
        """Measure one fact. A failure is a NAMED GAP, never a discarded run.

        This is the whole of ADR-063 D2. The shipped version ran all three
        measurements inside one `try`, so `measure_job`'s HTTP 403 on 2026-08-27
        threw away a `measure_billing` that had already succeeded — and the 403
        was CAUSED by the very thing that billing read would have revealed.
        """
        try:
            return fn(*fn_args)
        except MeasurementError as exc:
            gaps[name] = str(exc)
            return default

    billing_enabled, account_name = probe(
        "billing", measure_billing, api, args.project, default=(False, None))
    if "billing" in gaps:
        account_open = None
    elif account_name is None:
        # Not linked at all: there is no account document to ask about, and
        # billing_findings already calls the unlinked project a finding.
        account_open = None
    else:
        account_open = probe(
            "account", measure_billing_account, api, account_name, default=None)

    state, status = probe(
        "scheduler", measure_job, api, args.project, args.region, default=(None, 0))
    last, summary = probe(
        "sweep", measure_last_sweep, api, args.project, args.lookback_hours,
        default=(None, None))
    refusal = probe(
        "refusal", measure_last_refusal, api, args.project, args.lookback_hours,
        default=None)

    now = api.server_now or dt.datetime.now(dt.timezone.utc)
    code, lines = verdict(
        billing_enabled=billing_enabled,
        billing_account_open=account_open,
        billing_account_name=account_name,
        job_state=state,
        job_status_code=status,
        last_sweep=last,
        last_summary=summary,
        last_refusal=refusal,
        gaps=gaps,
        now=now,
        max_age_minutes=args.max_age_minutes,
    )
    # In --notifier-findings mode the REPORT goes to stderr and stdout carries
    # only the EXTRA_FINDINGS text, so a lane can capture stdout without parsing
    # anything. A healthy run prints an empty stdout, which is the signal that
    # nothing should be sent (ADR-064 D2c).
    out = sys.stderr if args.notifier_findings else sys.stdout
    print(f"{args.project} ({args.region})", file=out)
    if account_name:
        print(f"  billing account: {account_name}", file=out)
    if api.server_now is None:
        print("  note: no Date header on the API response — aged against the LOCAL clock", file=out)
    for line in lines:
        print("  " + line, file=out)
    if args.notifier_findings:
        print(findings_for_notifier(code, lines))
    return code


if __name__ == "__main__":
    sys.exit(main())
