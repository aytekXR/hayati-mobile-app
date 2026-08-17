#!/usr/bin/env python3
"""Did the tap work — and if not, WHICH link broke? (#219)

WHY THIS EXISTS. `registerPushToken` has never been called by a device, so the
last two links of the notification chain have never run:

    device mints a token -> callable stores it -> FCM delivers it via APNs

Everything upstream is verified. These two are not, and one of them —
**whether the APNs `.p8` was ever uploaded to Firebase** — is not readable from
any Google API (six endpoints tried, 2026-08-11). It can only be observed at the
moment of a real send, and until now that moment was "tomorrow at 09:00", with
silence as the only symptom and no way to tell the causes apart.

That ambiguity is the actual defect this feature keeps dying of. Twice already a
build shipped, the founder tapped Allow, nothing arrived, and it took a session
of log archaeology to learn why — because every distinct failure presents
identically as *nothing happened*.

So this tool does two things and refuses to guess:

  DEFAULT (read-only)  report whether any account has registered a token yet.
  --send-test          deliver ONE real notification to a registered token and
                       NAME the outcome, mapping FCM's error taxonomy onto the
                       link that is actually broken.

`--send-test` puts a real notification on a real person's phone, so it is gated
behind the literal `--confirm SEND` (the `appid_capability_enable.py` shape) and
refuses outright when more than one account holds tokens unless a `--uid` names
one. It is a diagnostic, not a broadcast.

EXIT CODES (the `rules_drift.py` taxonomy):

    0   healthy for what was asked (a token exists; or the test push delivered)
    1   FINDING — no token registered yet, or the send failed
    2   COULD NOT MEASURE — no credential, an API error, a bad response shape
"""
from __future__ import annotations

import argparse
import json
import sys
import urllib.error
import urllib.parse
import urllib.request

from rules_drift import MeasurementError, token_from_firebase_cli

FIRESTORE_API = "https://firestore.googleapis.com/v1/"
FCM_API = "https://fcm.googleapis.com/v1/"

EXIT_OK = 0
EXIT_FINDING = 1
EXIT_CANNOT_MEASURE = 2

# FCM's error taxonomy, mapped onto the LINK each one indicts. The point of the
# tool: "nothing arrived" is four different bugs, and these are their names.
FCM_DIAGNOSIS = {
    "THIRD_PARTY_AUTH_ERROR": (
        "APNs CREDENTIALS. FCM holds no valid APNs key for this app, so it cannot "
        "hand the push to Apple. The token and the server are fine.\n"
        "       FIX: console.firebase.google.com/project/{project}/settings/cloudmessaging\n"
        "       -> Apple app configuration -> upload the .p8. No rebuild needed."),
    "UNREGISTERED": (
        "THE TOKEN IS DEAD. It was valid once; the app was deleted, restored to a "
        "new device, or the token rotated. The device must register again "
        "(re-open the app) — nothing is wrong server-side."),
    "SENDER_ID_MISMATCH": (
        "WRONG PROJECT. The token was minted against a different Firebase project "
        "than the one sending. Check the app's firebase_options against this project."),
    "INVALID_ARGUMENT": (
        "MALFORMED REQUEST OR TOKEN. The stored value is not a usable FCM "
        "registration token — suspect what wrote it, not the delivery path."),
    "QUOTA_EXCEEDED": ("RATE LIMIT. Transient; retry."),
    "UNAVAILABLE": ("FCM IS DOWN OR THROTTLING. Transient; retry."),
}


# What the DEVICE says about itself (ADR-049), mapped onto the link each state
# indicts — the same discipline as FCM_DIAGNOSIS above, applied to the half of
# the chain no server-side API can see.
#
# ⚠️ THIS IS A CLAIM, NOT EVIDENCE. `fcmTokens` is server-owned, written from a
# token the server verified, and is the only thing that proves reachability. This
# field is written by the device, about the device. It is the one instrument for
# "did the app ever reach the prompt, and what did it do?", and it is worth
# exactly that and nothing more.
DEVICE_DIAGNOSIS = {
    "notDetermined": (
        "THE PROMPT NEVER RAN on this install. iOS has never shown its "
        "notification dialog, so there is nothing to decline and no address to "
        "capture.\n"
        "       FIX: open the app to the PAIRED HOME screen — that is where it "
        "asks (ADR-042 D6) — or use the Notifications row in Settings."),
    "denied": (
        "PERMISSION IS OFF, AND NO BUILD FIXES IT. iOS shows its dialog once per "
        "install and answers from its standing record thereafter, without showing "
        "anything.\n"
        "       FIX: iOS Settings -> Notifications -> ikimiz -> Allow "
        "Notifications ON, then reopen the app. Nothing else works."),
    "awaitingDeviceToken": (
        "PERMISSION IS HELD AND THE DEVICE HAS NO ADDRESS. Either APNs has not "
        "answered yet (ordinary and transient) or it never will. Read the DETAIL "
        "line: it names which of two very different links this is."),
    "registered": (
        "THE DEVICE BELIEVES IT REGISTERED. Cross-check the token count above — "
        "that is the server-owned evidence; this line is only the phone's claim. "
        "They disagree legitimately when the phone later signed into another "
        "account (ADR-042 D1 evicts a token from every other user document)."),
    "unknown": (
        "NOTHING MEASURED. The app reached no conclusion — signed out, or no push "
        "source wired. Not a failure, and the client is not supposed to write it."),
}

# The resolution the SCREEN deliberately does not have (ADR-046 D2 merged two of
# these into one state on purpose: the person holding the phone gets the same
# remedy either way). A session needs them apart — one indicts APNs and one
# indicts the callable, and confusing those two is what made #219 take 37 hours.
DETAIL_DIAGNOSIS = {
    "permissionRequestRefused": (
        "the app CALLED requestPermission() and was not granted — so the prompt "
        "path RAN. (Not 'the user tapped no': after the first dialog iOS answers "
        "from its standing record without showing anything.)"),
    "captureExhausted": (
        "ADR-044's bounded capture ran to its END with no token — APNs never "
        "answered. Suspect the .p8 upload or the swizzling ADR-046 D6 hardened."),
    "registerFailed": (
        "a token EXISTED and the registerPushToken callable THREW. The device is "
        "fine; the server leg is not. This is the #219 shape, and it is invisible "
        "in fcmTokens precisely because the write that would record it failed."),
    "permissionUnreadable": (
        "reading the OS permission state ITSELF threw. Suspect the messaging "
        "plugin seam rather than any link beyond it."),
}


def device_reports(documents: list) -> list[tuple[str, str | None, str | None, str | None]]:
    """(uid, state, detail, at) for EVERY account — including the silent ones.

    Junk-safe by construction: a missing key, a non-map, a non-string state or a
    non-string timestamp all read as absent. The account writing this field is
    the account being diagnosed, so a malformed self-report must never be able to
    crash the instrument that reads it — and must never read as a diagnosis.

    Pure: the wire shape (measured 2026-08-17) is
    `{"mapValue": {"fields": {"state": {"stringValue": ...}, ...}}}`.
    """
    out = []
    for doc in documents:
        uid = str(doc.get("name", "")).rsplit("/", 1)[-1]
        field = (doc.get("fields") or {}).get("pushDiagnostic") or {}
        fields = ((field.get("mapValue") or {}).get("fields") or {})

        def typed(key: str, wire: str) -> str | None:
            raw = fields.get(key)
            if not isinstance(raw, dict):
                return None
            value = raw.get(wire)
            return value if isinstance(value, str) else None

        state = typed("state", "stringValue")
        at = typed("at", "timestampValue")
        # A report with no state, or no trustworthy time, is not a report. The
        # rules make both mandatory, so this only fires on pre-rule residue or a
        # deliberately malformed write — either way it is unreadable, not a
        # diagnosis.
        if state is None or at is None:
            out.append((uid, None, None, None))
            continue
        out.append((uid, state, typed("detail", "stringValue"), at))
    return out


def diagnose_device(state: str | None, detail: str | None) -> str:
    """What the device's self-report means. Unknown vocabulary stays unknown."""
    if state is None:
        return (
            "NO REPORT. Either no build carrying the diagnostic has ever run on "
            "this account's phone, or the app has never reached the point of "
            "measuring itself. THOSE ARE NOT DISTINGUISHABLE from here, and "
            "neither one is evidence of anything (lesson 65). The last build was "
            "cut 2026-08-09; ADR-049 merged after it.")
    text = DEVICE_DIAGNOSIS.get(state)
    if text is None:
        text = (f"UNMAPPED state {state!r} — the phone is running a build whose "
                "vocabulary this tool does not know. Read firestore.rules and the "
                "PushRegistrationState enum; do NOT read this as an absence.")
    if detail is not None:
        sharper = DETAIL_DIAGNOSIS.get(
            detail,
            f"UNMAPPED detail {detail!r} — a newer build than this tool. The "
            "state above still stands.")
        text = f"{text}\n       DETAIL: {sharper}"
    return text


def diagnose(error_code: str | None, project: str) -> str:
    """Map an FCM errorCode onto the broken link. Unknown codes stay unknown."""
    if error_code is None:
        return ("UNRECOGNISED FAILURE — FCM returned no errorCode. Treat as "
                "'could not tell', never as a healthy send.")
    text = FCM_DIAGNOSIS.get(error_code)
    if text is None:
        return f"UNMAPPED FCM errorCode {error_code!r} — read the raw response below."
    return text.format(project=project)


def fcm_error_code(body: dict) -> str | None:
    """The errorCode out of an FCM v1 error body, from the details array."""
    for detail in ((body.get("error") or {}).get("details") or []):
        if isinstance(detail, dict) and detail.get("errorCode"):
            return str(detail["errorCode"])
    return None


def registered_accounts(documents: list) -> list[tuple[str, list[str]]]:
    """(uid, tokens) for every account carrying at least one token. Pure."""
    found = []
    for doc in documents:
        uid = str(doc.get("name", "")).rsplit("/", 1)[-1]
        field = (doc.get("fields") or {}).get("fcmTokens") or {}
        values = (field.get("arrayValue") or {}).get("values") or []
        tokens = [v["stringValue"] for v in values
                  if isinstance(v, dict) and isinstance(v.get("stringValue"), str)]
        if tokens:
            found.append((uid, tokens))
    return found


class Api:
    def __init__(self, access_token: str) -> None:
        self._token = access_token

    def call(self, url: str, payload: dict | None = None) -> tuple[int, dict]:
        data = json.dumps(payload).encode() if payload is not None else None
        headers = {"Authorization": "Bearer " + self._token}
        if data:
            headers["Content-Type"] = "application/json"
        req = urllib.request.Request(url, data=data, headers=headers)
        try:
            with urllib.request.urlopen(req, timeout=60) as resp:
                return resp.status, json.load(resp)
        except urllib.error.HTTPError as exc:
            try:
                return exc.code, json.load(exc)
            except Exception:
                return exc.code, {}
        except (OSError, json.JSONDecodeError) as exc:
            raise MeasurementError(f"{url.split('?')[0]} unreachable: {exc}") from None


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--project", default="hayatiapp-prod")
    parser.add_argument("--send-test", action="store_true",
                        help="deliver ONE real notification to a registered token")
    parser.add_argument("--confirm", default="",
                        help="must be the literal SEND when --send-test is used")
    parser.add_argument("--uid", default="",
                        help="narrow the device report to one account (and, with "
                             "--send-test, the account to send to)")
    parser.add_argument("--from-firebase-cli", action="store_true", required=True)
    args = parser.parse_args(argv)

    try:
        api = Api(token_from_firebase_cli())
        docs = f"{FIRESTORE_API}projects/{args.project}/databases/(default)/documents"
        status, body = api.call(f"{docs}/users?pageSize=100")
        if status != 200:
            raise MeasurementError(f"users read returned HTTP {status}")
        named_doc = None
        if args.uid:
            # A NAMED uid is fetched DIRECTLY rather than filtered out of the
            # listing above. The listing is capped at 100 with no pagination, so
            # filtering would print a confident "no diagnostic" for an account
            # this tool never looked at — an absence manufactured by pagination,
            # which is lesson 65's failure with an extra step.
            named_status, named_doc = api.call(f"{docs}/users/{urllib.parse.quote(args.uid)}")
            if named_status == 404:
                print(f"could not measure: no account {args.uid!r} in {args.project}",
                      file=sys.stderr)
                return EXIT_CANNOT_MEASURE
            if named_status != 200:
                raise MeasurementError(f"users/{args.uid} read returned HTTP {named_status}")
    except MeasurementError as exc:
        print(f"could not measure: {exc}", file=sys.stderr)
        return EXIT_CANNOT_MEASURE

    all_docs = body.get("documents") or []
    holders = registered_accounts(all_docs)
    print(f"{args.project}: {len(holders)}/{len(all_docs)} account(s) have registered a device")
    for uid, tokens in holders:
        print(f"  {uid}: {len(tokens)} token(s)")
    if body.get("nextPageToken"):
        print("\n  NOTE: more than 100 accounts exist and only the first page was read.\n"
              "  The verdict below covers that page only. A named --uid is read directly\n"
              "  and is therefore unaffected.")

    # ADR-049. What each phone says about ITSELF — the half of the chain no
    # server-side API can see. `--uid` narrows what is PRINTED and never what is
    # judged: the exit code keeps answering "has any device registered?", because
    # a lane greps the exit and a human reads the report.
    reports = device_reports([named_doc] if named_doc is not None else all_docs)
    scope = f" for {args.uid}" if args.uid else ""
    print(f"\nwhat the device says about itself{scope} "
          "(ADR-049 — a CLAIM; fcmTokens above is the evidence):")
    for uid, state, detail, at in reports:
        headline = "no report" if state is None else (
            f"{state}{'' if detail is None else ' / ' + detail}  —  {at}")
        print(f"  {uid}: {headline}")
    # When NOTHING has reported — today's state, and the state until a build
    # carrying ADR-049 ships — the explanation is the same for every account, so
    # it is said once. Four identical paragraphs read as four findings.
    if all(state is None for _, state, _, _ in reports):
        print(f"\n  {diagnose_device(None, None)}")
        reports = []
    for uid, state, detail, at in reports:
        print(f"\n  {uid}:\n       {diagnose_device(state, detail)}")
        if state == "registered" and uid not in {u for u, _ in holders}:
            print("       ⚠️  DISAGREEMENT: this phone claims it registered and the "
                  "server holds\n"
                  "       no token for this account. Usually legitimate — a phone that "
                  "later signed\n"
                  "       into another account has its token evicted from this one "
                  "(ADR-042 D1).\n"
                  "       Printed, not scored: a red nobody can ever clear is a red "
                  "nobody reads.")

    if not holders:
        print("\nFINDING: no device has ever registered. The chain cannot be exercised —\n"
              "  install the current TestFlight build, open it to the paired home screen,\n"
              "  and accept the notification prompt. Then re-run this.\n"
              "  Read the device reports above FIRST: since ADR-049 they can say whether\n"
              "  the prompt path ever ran, and which link broke if it did.")
        return EXIT_FINDING

    if not args.send_test:
        print("\nA device is registered. Re-run with --send-test --confirm SEND to prove\n"
              "delivery end to end (this puts ONE real notification on that phone).")
        return EXIT_OK

    if args.confirm != "SEND":
        print("\nrefusing: --send-test delivers a real notification to a real phone. "
              "Pass --confirm SEND.", file=sys.stderr)
        return EXIT_CANNOT_MEASURE

    targets = [h for h in holders if h[0] == args.uid] if args.uid else holders
    if not targets:
        print(f"\nrefusing: --uid {args.uid!r} holds no tokens.", file=sys.stderr)
        return EXIT_CANNOT_MEASURE
    if len(targets) > 1:
        print("\nrefusing: more than one account holds tokens — name one with --uid. "
              "This is a diagnostic, not a broadcast.", file=sys.stderr)
        return EXIT_CANNOT_MEASURE

    uid, tokens = targets[0]
    worst = EXIT_OK
    for token in tokens:
        status, res = api.call(
            f"{FCM_API}projects/{args.project}/messages:send",
            {"message": {"token": token,
                         "notification": {"title": "ikimiz",
                                          "body": "Bildirimler çalışıyor ✓"}}})
        if status == 200:
            print(f"\n  SENT -> {res.get('name', '(no name)')}")
            print("  Delivery accepted by FCM AND by APNs. Notifications work.")
            continue
        worst = EXIT_FINDING
        code = fcm_error_code(res)
        print(f"\n  FAILED (HTTP {status}, errorCode={code})")
        print(f"  {diagnose(code, args.project)}")
        print(f"  raw: {json.dumps(res)[:400]}")
    return worst


if __name__ == "__main__":
    sys.exit(main())
