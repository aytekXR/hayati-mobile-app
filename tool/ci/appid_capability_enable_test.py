#!/usr/bin/env python3
"""Self-tests for appid_capability_enable.py — the WRITE half.

The read half (appid_capabilities.py) says in its own header that it
deliberately has no code path that could tick a capability, "because a tool
that could do it would also be a tool that could do it by accident."

That reasoning is still correct and this tool does not contradict it — it
answers it. The founder authorised the write on 2026-08-06; the accident
concern is handled the way this repo already handles an irreversible callable,
with a wire-level confirm literal (the ADR-019 `confirm: 'DELETE'` precedent):
nothing here mutates without BOTH an explicit --enable and the literal.

Run: python3 tool/ci/appid_capability_enable_test.py
"""

from __future__ import annotations

import importlib.util
import pathlib
import sys

_HERE = pathlib.Path(__file__).parent
_spec = importlib.util.spec_from_file_location(
    "appid_capability_enable", _HERE / "appid_capability_enable.py"
)
assert _spec is not None and _spec.loader is not None
mod = importlib.util.module_from_spec(_spec)
# Register BEFORE exec: @dataclasses.dataclass resolves the defining module out
# of sys.modules, so a module executed without being registered blows up on its
# first frozen dataclass with a bare AttributeError.
sys.modules.setdefault("appid_capability_enable", mod)
_spec.loader.exec_module(mod)

FAILURES: list[str] = []
BUNDLE_KEY = "ABCDE12345"


def check(name: str, condition: bool, detail: str = "") -> None:
    if condition:
        print(f"  ok   {name}")
    else:
        print(f"  FAIL {name}{(': ' + detail) if detail else ''}")
        FAILURES.append(name)


class FakeCall:
    """Records every (method, path, body) and replays canned responses."""

    def __init__(self, responses: dict | None = None, raises: dict | None = None):
        self.calls: list[tuple[str, str, dict | None]] = []
        self.responses = responses or {}
        self.raises = raises or {}

    def __call__(self, method: str, path: str, body: dict | None = None) -> dict:
        self.calls.append((method, path, body))
        for prefix, error in self.raises.items():
            if path.startswith(prefix) and method == "POST":
                raise error
        for prefix, payload in self.responses.items():
            if path.startswith(prefix):
                return payload
        return {}

    @property
    def writes(self) -> list[tuple[str, str, dict | None]]:
        return [c for c in self.calls if c[0] in {"POST", "DELETE", "PATCH"}]


# --------------------------------------------------------------------------
# the confirm literal


def test_the_confirm_literal_is_required_and_exact() -> None:
    """Nothing mutates without the wire-level literal (ADR-019 precedent).

    A --enable flag alone is one typo away from a capability change on a live
    App ID. The literal is never typed by a human in normal use — CI passes it
    — so it costs nothing and it makes an accidental invocation impossible
    rather than unlikely.
    """
    check("the literal is the documented string", mod.CONFIRM_LITERAL == "ENABLE")

    call = FakeCall()
    result = mod.enable_capability(
        call, BUNDLE_KEY, mod.PUSH_NOTIFICATIONS, confirm="", already_enabled=[]
    )
    check(
        "an empty confirm refuses and writes NOTHING",
        result.exit_code == mod.EXIT_REFUSED and not call.writes,
        f"exit={result.exit_code} writes={call.writes}",
    )

    call = FakeCall()
    result = mod.enable_capability(
        call, BUNDLE_KEY, mod.PUSH_NOTIFICATIONS, confirm="enable", already_enabled=[]
    )
    check(
        "a lowercased confirm refuses (exact match, like DELETE)",
        result.exit_code == mod.EXIT_REFUSED and not call.writes,
    )

    call = FakeCall()
    result = mod.enable_capability(
        call, BUNDLE_KEY, mod.PUSH_NOTIFICATIONS, confirm="ENABLE ", already_enabled=[]
    )
    check(
        "a whitespace-padded confirm refuses rather than being trimmed into a yes",
        result.exit_code == mod.EXIT_REFUSED and not call.writes,
    )


# --------------------------------------------------------------------------
# the vocabulary


def test_an_unknown_capability_is_refused_before_any_request() -> None:
    """The closed vocabulary is a WRITE guard here, not just a spelling check.

    On the read side an unknown value could only produce a false absence. Here
    it would POST an arbitrary string to a live App ID, and Apple would either
    reject it or enable something nobody named.
    """
    call = FakeCall()
    result = mod.enable_capability(
        call, BUNDLE_KEY, "PUSH_NOTIFICATION", confirm=mod.CONFIRM_LITERAL, already_enabled=[]
    )
    check(
        "a near-miss capability name is refused and issues no request at all",
        result.exit_code == mod.EXIT_REFUSED and not call.calls,
        f"calls={call.calls}",
    )


# --------------------------------------------------------------------------
# idempotence


def test_an_already_enabled_capability_is_a_no_op() -> None:
    """Re-running must never issue a second POST.

    Apple returns an error for a duplicate capability, and a tool whose second
    run fails is a tool nobody dares re-run — which matters most in exactly the
    situation where someone is unsure whether the first run landed.
    """
    call = FakeCall()
    result = mod.enable_capability(
        call,
        BUNDLE_KEY,
        mod.PUSH_NOTIFICATIONS,
        confirm=mod.CONFIRM_LITERAL,
        already_enabled=[mod.PUSH_NOTIFICATIONS, mod.APPLE_ID_AUTH],
    )
    check(
        "already ticked -> exit 0 and NO write",
        result.exit_code == mod.EXIT_OK and not call.writes,
        f"exit={result.exit_code} writes={call.writes}",
    )
    check("it says so rather than claiming to have acted", result.already_enabled is True)


# --------------------------------------------------------------------------
# the request Apple actually accepts


def test_the_enable_request_shape() -> None:
    call = FakeCall(responses={"/v1/bundleIdCapabilities": {"data": {"id": "CAP1"}}})
    result = mod.enable_capability(
        call,
        BUNDLE_KEY,
        mod.PUSH_NOTIFICATIONS,
        confirm=mod.CONFIRM_LITERAL,
        already_enabled=[mod.APPLE_ID_AUTH],
    )
    check("a fresh enable succeeds", result.exit_code == mod.EXIT_OK, str(result))
    check("exactly ONE write is issued", len(call.writes) == 1, str(call.writes))

    method, path, body = call.writes[0]
    check("it POSTs", method == "POST")
    check("to the collection, not the relationship", path == "/v1/bundleIdCapabilities", path)
    check(
        "the body is Apple's bundleIdCapabilities create shape",
        body
        == {
            "data": {
                "type": "bundleIdCapabilities",
                "attributes": {"capabilityType": mod.PUSH_NOTIFICATIONS},
                "relationships": {
                    "bundleId": {"data": {"type": "bundleIds", "id": BUNDLE_KEY}}
                },
            }
        },
        str(body),
    )
    check("it records the created id so the change can be UNDONE", result.capability_id == "CAP1")


def test_the_disable_request_shape() -> None:
    """Reversibility is a property of this tool, not a promise about Apple.

    Enabling a capability invalidates provisioning profiles. If the release
    lane cannot regenerate them, the change must be undoable from the same
    place it was made, by someone who has just watched a build fail.
    """
    call = FakeCall()
    result = mod.disable_capability(call, "CAP1", confirm=mod.CONFIRM_LITERAL)
    check("a disable succeeds", result.exit_code == mod.EXIT_OK)
    check("exactly one write", len(call.writes) == 1, str(call.writes))
    method, path, body = call.writes[0]
    check("it DELETEs the capability resource by id", (method, path) == ("DELETE", "/v1/bundleIdCapabilities/CAP1"), f"{method} {path}")
    check("with no body", body is None)

    call = FakeCall()
    result = mod.disable_capability(call, "CAP1", confirm="")
    check(
        "a disable ALSO requires the literal — undo is still a live-config change",
        result.exit_code == mod.EXIT_REFUSED and not call.writes,
    )


# --------------------------------------------------------------------------
# failure is never reported as success


def test_an_apple_rejection_is_a_failure_not_a_shrug() -> None:
    call = FakeCall(
        raises={"/v1/bundleIdCapabilities": mod.AscError("POST /v1/bundleIdCapabilities -> HTTP 403: FORBIDDEN")}
    )
    result = mod.enable_capability(
        call, BUNDLE_KEY, mod.PUSH_NOTIFICATIONS, confirm=mod.CONFIRM_LITERAL, already_enabled=[]
    )
    check("a 403 is exit 2, never 0", result.exit_code == mod.EXIT_FAILED, str(result))
    check("the reason names the HTTP status", "403" in result.reason, result.reason)


def test_a_credential_shaped_string_never_reaches_stdout() -> None:
    """Same anti-leak sentinel as the read half: this tool prints Apple's own
    error bodies, and a failing request carried an Authorization header."""
    leaked = "POST /v1/x -> HTTP 401: Bearer eyJhbGciOiJFUzI1NiJ9.fake.sig rejected"
    call = FakeCall(raises={"/v1/bundleIdCapabilities": mod.AscError(leaked)})
    result = mod.enable_capability(
        call, BUNDLE_KEY, mod.PUSH_NOTIFICATIONS, confirm=mod.CONFIRM_LITERAL, already_enabled=[]
    )
    check("the bearer token is redacted", "eyJhbGciOiJFUzI1NiJ9" not in result.reason, result.reason)
    check("something is still said", "401" in result.reason, result.reason)


# --------------------------------------------------------------------------
# exit taxonomy


def test_the_exit_codes_are_distinct_and_documented() -> None:
    codes = {mod.EXIT_OK, mod.EXIT_REFUSED, mod.EXIT_FAILED}
    check("three distinct codes", len(codes) == 3, str(codes))
    check("0 is success", mod.EXIT_OK == 0)
    check(
        "REFUSED and FAILED are different: 'I would not' is not 'I could not'",
        mod.EXIT_REFUSED != mod.EXIT_FAILED,
    )


def main() -> int:
    for name, fn in sorted(globals().items()):
        if name.startswith("test_") and callable(fn):
            print(f"{name}:")
            fn()
    print()
    if FAILURES:
        print(f"FAILED ({len(FAILURES)}): " + ", ".join(FAILURES))
        return 1
    print("all green")
    return 0


if __name__ == "__main__":
    sys.exit(main())
