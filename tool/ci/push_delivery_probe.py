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
    parser.add_argument("--uid", default="", help="which account to send to")
    parser.add_argument("--from-firebase-cli", action="store_true", required=True)
    args = parser.parse_args(argv)

    try:
        api = Api(token_from_firebase_cli())
        docs = f"{FIRESTORE_API}projects/{args.project}/databases/(default)/documents"
        status, body = api.call(f"{docs}/users?pageSize=100")
        if status != 200:
            raise MeasurementError(f"users read returned HTTP {status}")
    except MeasurementError as exc:
        print(f"could not measure: {exc}", file=sys.stderr)
        return EXIT_CANNOT_MEASURE

    all_docs = body.get("documents") or []
    holders = registered_accounts(all_docs)
    print(f"{args.project}: {len(holders)}/{len(all_docs)} account(s) have registered a device")
    for uid, tokens in holders:
        print(f"  {uid}: {len(tokens)} token(s)")

    if not holders:
        print("\nFINDING: no device has ever registered. The chain cannot be exercised —\n"
              "  install the current TestFlight build, open it to the paired home screen,\n"
              "  and accept the notification prompt. Then re-run this.")
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
