#!/usr/bin/env python3
"""Hermetic self-tests for tool/ci/functions_drift.py. No network, no credential.

WHAT MAKES THIS GATE EASY TO FAKE, AND WHAT IS DONE ABOUT IT. A drift checker
that reported "no drift" unconditionally would pass a smoke test while guarding
nothing — which is literally the defect (#166, and #140 before it) the tool was
written to end. So the assertions below aim at MECHANISMS:

* **The hash primitives are pinned to values MEASURED FROM PRODUCTION**, not to
  values this tool produced. `PROD_*` below were read off `hayatiapp-prod` with
  `firebase functions:list --json` on 2026-08-09; the tool must reproduce them
  from the recorded inputs. A fixture derived from its own subject proves
  nothing, and this fixture could not be — Google computed it.
* **`js_stringify` was checked DIFFERENTIALLY against V8** on ten inputs
  covering control characters, U+2028/9, astral-plane code points and key
  ordering. The goldens below are V8's output, so "simplifying" the separators
  or letting `ensure_ascii` default reddens a named check.
* **The walk is checked against an enumeration the test builds itself**, never
  against the tool's own walk.
* **The reference/working-tree split is seeded with a real divergence** — the
  fixture carries a foreign file — so swapping which digest is the verdict
  cannot pass. That mutation is the whole of ADR-043 D3.
* **"could not measure" (exit 2) is asserted as distinct from "drift" (exit 1)**
  at every fail-closed path, and the MESSAGE is asserted too: exit 2 is a scalar
  many paths produce (lesson 76), so a mutation that broke all parsing would
  otherwise satisfy every one of them.

Checks are grouped into sections that run independently: a mutation that makes
the tool *raise* is recorded as a named failure of its section rather than
killing the run, because a red that names nothing is a poor diagnostic and this
file's whole job is to say WHICH property moved (lesson 75).
"""

from __future__ import annotations

import hashlib
import io
import json
import os
import shutil
import subprocess
import sys
import tempfile
import traceback
from contextlib import redirect_stderr, redirect_stdout

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import functions_drift as D  # noqa: E402

FAILURES: list[str] = []
CHECKS = 0
SECTIONS: list = []


def check(name: str, condition: bool, detail: str = "") -> None:
    global CHECKS
    CHECKS += 1
    if not condition:
        FAILURES.append(f"{name}{(': ' + detail) if detail else ''}")


def section(fn):
    SECTIONS.append(fn)
    return fn


def run_cli(argv: list[str]) -> tuple[int, str]:
    out, err = io.StringIO(), io.StringIO()
    with redirect_stdout(out), redirect_stderr(err):
        code = D.main(argv + ["--skip-version-check"], listing_loader=RUN_LISTING[0])
    return code, out.getvalue() + err.getvalue()


RUN_LISTING: list = [None]


# --------------------------------------------------------------------------
# Measured from hayatiapp-prod on 2026-08-09. Google computed these, not us.
# --------------------------------------------------------------------------

PROD_SOURCE_HASH = "b29f795fb34e29e67ab39f9690eff06df0d064d2"
PROD_FIREBASE_CONFIG = (
    '{"projectId":"hayatiapp-prod",'
    '"storageBucket":"hayatiapp-prod.firebasestorage.app"}'
)
PROD_ENV_HASH = "8d3596e351f14e61a02ad860be83a486e8b7cc3f"
PROD_HASH_NO_SECRETS = "fb789b160cab7febc561eb7573a404e2367363cd"
PROD_HASH_COACH_PROXY = "3e869aa35704dee93174f63a37f9d4eb65e34a66"
PROD_HASH_RC_WEBHOOK = "476a433c7d505562abdae149aa459482bc464317"

# V8's own JSON.stringify output, captured by running node against byte-identical
# input. Not reformatted by hand.
V8_GOLDENS = [
    ({}, "{}"),
    ({"LLM_API_KEY": "1"}, '{"LLM_API_KEY":"1"}'),
    ({"a": "1", "b": ""}, '{"a":"1","b":""}'),
    ({"b": "2", "a": "1"}, '{"b":"2","a":"1"}'),
    ({"quote": 'a"b', "backslash": "a\\b"}, '{"quote":"a\\"b","backslash":"a\\\\b"}'),
    ({"newline": "a\nb", "tab": "a\tb", "cr": "a\rb"},
     '{"newline":"a\\nb","tab":"a\\tb","cr":"a\\rb"}'),
    ({"bel": "a\x07b"}, '{"bel":"a\\u0007b"}'),
    ({"latin": "café", "emoji": "☕"}, '{"latin":"café","emoji":"☕"}'),
]


# --------------------------------------------------------------------------
# 1. js_stringify is V8's JSON.stringify, not Python's json.dumps
# --------------------------------------------------------------------------


@section
def js_stringify_matches_v8():
    for obj, expected in V8_GOLDENS:
        check(f"js_stringify: V8 emits {expected}", D.js_stringify(obj) == expected,
              f"got {D.js_stringify(obj)!r}")
    check("js_stringify: no space after ':' or ','  (Python's default would add both)",
          " " not in D.js_stringify({"a": "1", "b": "2"}))
    check("js_stringify: key order is INSERTION order, never sorted",
          D.js_stringify({"b": "2", "a": "1"}) == '{"b":"2","a":"1"}')
    check("js_stringify: non-ASCII is emitted RAW, never \\uXXXX-escaped",
          "\\u" not in D.js_stringify({"k": "é"}))


# --------------------------------------------------------------------------
# 2. The primitives, each pinned to a value the tool did not invent
# --------------------------------------------------------------------------


@section
def primitives():
    check("sha1: the empty string is the published constant",
          D.sha1("") == "da39a3ee5e6b4b0d3255bfef95601890afd80709")
    check("sha1: accepts bytes and str identically",
          D.sha1(b"abc") == D.sha1("abc"))

    check("secrets_hash: no secrets hashes the EMPTY OBJECT",
          D.secrets_hash(None) == D.sha1("{}"))
    check("secrets_hash: [] and None agree", D.secrets_hash([]) == D.secrets_hash(None))
    check("secrets_hash: maps {secret: version}, not the whole entry",
          D.secrets_hash([{"secret": "S", "version": "3", "key": "S",
                           "projectId": "p"}]) == D.sha1('{"S":"3"}'))
    check("secrets_hash: a missing version becomes the empty string, not null",
          D.secrets_hash([{"secret": "S"}]) == D.sha1('{"S":""}'))

    check("endpoint_hash: an EMPTY component is dropped before joining",
          D.endpoint_hash("aa", "", "cc") == D.sha1("aacc"))
    # `""` alone cannot distinguish `filter(Boolean).join("")` from plain
    # concatenation — for strings they are the same expression, so a mutation
    # replacing one with the other would pass unseen. `None` is what makes the
    # vendor's filter load-bearing: applyHash.js hands `getEndpointHash` an
    # `undefined` sourceHash whenever the endpoint's platform has no packaged
    # source, and `[undefined,…].filter(Boolean)` drops it rather than
    # stringifying it.
    check("endpoint_hash: an ABSENT component is DROPPED, never stringified",
          D.endpoint_hash("aa", None, "cc") == D.sha1("aacc"))
    check("endpoint_hash: an absent SOURCE component is dropped too",
          D.endpoint_hash(None, "bb", "cc") == D.sha1("bbcc"))
    check("endpoint_hash: it is sha1 of the CONCATENATION, not of a list",
          D.endpoint_hash("aa", "bb", "cc") == D.sha1("aabbcc"))
    check("endpoint_hash: component ORDER is source, env, secrets",
          D.endpoint_hash("a", "b", "c") != D.endpoint_hash("c", "b", "a"))

    check("env_hash: FIREBASE_CONFIG and GCLOUD_PROJECT are appended, in that order",
          D.env_hash({}, "FC", "proj")
          == D.sha1('{"FIREBASE_CONFIG":"FC","GCLOUD_PROJECT":"proj"}'))
    check("env_hash: user envs come FIRST (JS spread keeps insertion order)",
          D.env_hash({"Z": "1"}, "FC", "proj")
          == D.sha1('{"Z":"1","FIREBASE_CONFIG":"FC","GCLOUD_PROJECT":"proj"}'))


# --------------------------------------------------------------------------
# 3. THE anchor: reproduce production, from inputs production reported
# --------------------------------------------------------------------------


@section
def reproduces_production():
    env = D.env_hash({}, PROD_FIREBASE_CONFIG, "hayatiapp-prod")
    check("prod: envHash reproduces the measured value", env == PROD_ENV_HASH, env)

    got = D.endpoint_hash(PROD_SOURCE_HASH, env, D.secrets_hash(None))
    check("prod: the eleven no-secret functions reproduce EXACTLY",
          got == PROD_HASH_NO_SECRETS, got)

    got = D.endpoint_hash(PROD_SOURCE_HASH, env,
                          D.secrets_hash([{"secret": "LLM_API_KEY", "version": "1"}]))
    check("prod: coachProxy reproduces EXACTLY", got == PROD_HASH_COACH_PROXY, got)

    got = D.endpoint_hash(PROD_SOURCE_HASH, env,
                          D.secrets_hash([{"secret": "RC_WEBHOOK_TOKEN", "version": "1"}]))
    check("prod: revenueCatWebhook reproduces EXACTLY", got == PROD_HASH_RC_WEBHOOK, got)

    # The consequence ADR-043 D0 states out loud: a rotation moves the hash with
    # no code change. If this ever stops holding, D4's whole reason for taking
    # the secret version from the DEPLOYMENT evaporates.
    rotated = D.endpoint_hash(PROD_SOURCE_HASH, env,
                              D.secrets_hash([{"secret": "LLM_API_KEY", "version": "2"}]))
    check("prod: a secret VERSION bump moves the hash with no source change",
          rotated != PROD_HASH_COACH_PROXY)


# --------------------------------------------------------------------------
# 4. The walk, against an enumeration this test builds itself
# --------------------------------------------------------------------------


def independent_source_hash(paths: list[str]) -> str:
    """Deliberately NOT D.source_hash: a slow, obvious restatement of
    `packageSource`, so the two can disagree."""
    digests = []
    for path in paths:
        with open(path, "rb") as handle:
            digests.append(hashlib.sha1(handle.read()).hexdigest())
    digests.sort()
    return hashlib.sha1("".join(digests).encode()).hexdigest()


@section
def walk_and_source_hash():
    root = tempfile.mkdtemp()
    try:
        wanted = {
            "index.js": b"one",
            "sub/deep/two.js": b"two",
            ".env.demo": b"three",          # dotfiles ARE packaged (dot: true)
            ".hidden/four.js": b"four",     # a dot DIRECTORY is packaged too
            "firebase-debug.other": b"five",  # near-miss: must NOT be ignored
        }
        ignored = {
            "node_modules/pkg/i.js": b"x",
            ".git/config": b"x",
            "firebase-debug.log": b"x",
            "firebase-debug.2026.log": b"x",
            ".runtimeconfig.json": b"x",
            "sub/node_modules/nested.js": b"x",   # pruned at ANY depth
        }
        for rel, data in {**wanted, **ignored}.items():
            path = os.path.join(root, rel)
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, "wb") as handle:
                handle.write(data)

        patterns = list(D.DEFAULT_IGNORE) + list(D.ALWAYS_IGNORE)
        walked = D.walk_packaged(root, patterns)
        rel_walked = sorted(os.path.relpath(p, root) for p in walked)
        check("walk: packages exactly the expected set",
              rel_walked == sorted(wanted), f"got {rel_walked}")
        for rel in ignored:
            check(f"walk: {rel} is NOT packaged", rel not in rel_walked)
        check("walk: a dot-directory is descended into (dot: true)",
              ".hidden/four.js" in rel_walked)
        check("walk: 'firebase-debug.other' is kept — the glob is .log, not a prefix",
              "firebase-debug.other" in rel_walked)
        check("walk: node_modules is pruned at depth, not only at the root",
              "sub/node_modules/nested.js" not in rel_walked)

        expected = independent_source_hash([os.path.join(root, r) for r in wanted])
        check("source_hash: agrees with an INDEPENDENT re-implementation",
              D.source_hash(walked) == expected, D.source_hash(walked))

        # The sort is over the DIGESTS, not the paths. Feeding the same files in
        # a different order must not move the hash; a version that sorted paths
        # instead would still pass an order test but differ from the CLI.
        check("source_hash: is order-independent (it sorts the DIGESTS)",
              D.source_hash(walked) == D.source_hash(list(reversed(walked))))
        one, two = walked[0], walked[1]
        check("source_hash: two files with the same bytes are NOT deduplicated",
              D.source_hash([one, one]) != D.source_hash([one]))
        check("source_hash: changing one byte moves it",
              D.source_hash([one]) != D.source_hash([two]))
    finally:
        shutil.rmtree(root, ignore_errors=True)


@section
def slashed_ignore_pattern_is_refused():
    root = tempfile.mkdtemp()
    try:
        with open(os.path.join(root, "firebase.json"), "w") as handle:
            json.dump({"functions": {"source": "functions",
                                     "ignore": ["node_modules", "src/**/*.map"]}}, handle)
        try:
            D.read_functions_config(os.path.join(root, "firebase.json"))
            check("config: a slashed ignore pattern is REFUSED", False, "it was accepted")
        except D.MeasurementError as exc:
            check("config: a slashed ignore pattern is REFUSED", True)
            check("config: the refusal names matchBase", "matchBase" in str(exc), str(exc))
    finally:
        shutil.rmtree(root, ignore_errors=True)


@section
def multi_codebase_is_refused():
    root = tempfile.mkdtemp()
    try:
        with open(os.path.join(root, "firebase.json"), "w") as handle:
            json.dump({"functions": [{"source": "a", "codebase": "a"},
                                     {"source": "b", "codebase": "b"}]}, handle)
        try:
            D.read_functions_config(os.path.join(root, "firebase.json"))
            check("config: two codebases are REFUSED", False, "it was accepted")
        except D.MeasurementError as exc:
            check("config: two codebases are REFUSED", True)
            check("config: the refusal says it is failing closed rather than partial",
                  "partial green" in str(exc), str(exc))
    finally:
        shutil.rmtree(root, ignore_errors=True)


@section
def build_dir_comes_from_package_json():
    root = tempfile.mkdtemp()
    try:
        with open(os.path.join(root, "package.json"), "w") as handle:
            json.dump({"main": "dist/server.js"}, handle)
        check("build dir: read from package.json's main, never hardcoded to lib/",
              D.build_output_dir(root) == os.path.join(root, "dist"),
              D.build_output_dir(root))

        with open(os.path.join(root, "package.json"), "w") as handle:
            json.dump({"main": "index.js"}, handle)
        try:
            D.build_output_dir(root)
            check("build dir: a main with no directory is exit 2", False, "accepted")
        except D.MeasurementError:
            check("build dir: a main with no directory is exit 2", True)
    finally:
        shutil.rmtree(root, ignore_errors=True)


# --------------------------------------------------------------------------
# 5. The barrel parser
# --------------------------------------------------------------------------


def write_barrel(root: str, body: str) -> str:
    path = os.path.join(root, "index.ts")
    with open(path, "w") as handle:
        handle.write(body)
    return path


@section
def barrel_parser():
    root = tempfile.mkdtemp()
    try:
        names = D.parse_barrel(write_barrel(root, """
// a comment mentioning export * which must not be parsed
import { initializeApp } from 'firebase-admin/app';
initializeApp();
export { alpha } from './a';
export {
  beta,
  gamma,
} from './b';
export { delta as epsilon } from './d';
"""))
        check("barrel: reads single-line, multi-line and aliased re-exports",
              names == ["alpha", "beta", "epsilon", "gamma"], str(names))
        check("barrel: an alias exports the NEW name, not the original",
              "delta" not in names and "epsilon" in names)

        for bad, label in [
            ("export * from './a';", "export *"),
            ("export default foo;", "export default"),
            ("export const x = 1;", "export const"),
            ("export function f() {}", "export function"),
        ]:
            try:
                D.parse_barrel(write_barrel(root, "export { ok } from './o';\n" + bad))
                check(f"barrel: `{label}` is REFUSED", False, "it was accepted")
            except D.MeasurementError as exc:
                check(f"barrel: `{label}` is REFUSED", True)
                # Exit 2 alone is satisfiable by a mutation that breaks ALL
                # parsing (lesson 76) — the message must name the form it saw.
                check(f"barrel: the refusal for `{label}` QUOTES the offending form",
                      label.split()[1] in str(exc), str(exc))

        try:
            D.parse_barrel(write_barrel(root, "export { a } from './x';\nexport { a } from './y';"))
            check("barrel: a duplicate export name is REFUSED", False, "accepted")
        except D.MeasurementError as exc:
            check("barrel: a duplicate export name is REFUSED", True)
            check("barrel: the duplicate refusal names the symbol", "'a'" in str(exc).replace('"', "'"),
                  str(exc))

        try:
            D.parse_barrel(os.path.join(root, "nope.ts"))
            check("barrel: a missing file is exit 2", False, "accepted")
        except D.MeasurementError:
            check("barrel: a missing file is exit 2", True)
    finally:
        shutil.rmtree(root, ignore_errors=True)


# --------------------------------------------------------------------------
# 6. Parsing the deployed listing: every fail-closed path, with its message
# --------------------------------------------------------------------------


def fn(fid: str, **over) -> dict:
    base = {
        "id": fid, "platform": "gcfv2", "region": "europe-west1", "state": "ACTIVE",
        "codebase": "default", "hash": "deadbeef",
        "environmentVariables": {"FIREBASE_CONFIG": PROD_FIREBASE_CONFIG,
                                 "GCLOUD_PROJECT": "p"},
    }
    base.update(over)
    return base


def refuses(label: str, payload, must_say: str, codebase: str = "default") -> None:
    try:
        D.parse_listing(payload, "p", codebase)
        check(f"listing: {label} is REFUSED", False, "it was accepted")
    except D.MeasurementError as exc:
        check(f"listing: {label} is REFUSED", True)
        check(f"listing: the refusal for {label} says why", must_say in str(exc), str(exc))


@section
def listing_fail_closed():
    ok = {"status": "success", "result": [fn("a")]}
    check("listing: a well-formed success parses", list(D.parse_listing(ok, "p", "default")) == ["a"])

    refuses("status=error", {"status": "error", "error": "boom"}, "boom")
    refuses("a missing status", {"result": []}, "status")
    refuses("a missing result array", {"status": "success"}, "result")
    refuses("an entry with no id", {"status": "success", "result": [{"platform": "gcfv2"}]}, "no id")
    refuses("gcfv1", {"status": "success", "result": [fn("a", platform="gcfv1")]},
            "out of contract")
    refuses("another codebase", {"status": "success", "result": [fn("a", codebase="other")]},
            "second codebase")
    refuses("a DataConnect trigger",
            {"status": "success",
             "result": [fn("a", eventTrigger={"dataConnectGraphqlTrigger": {"schemaFilePath": "s"}})]},
            "outside the functions source directory")
    refuses("a duplicated id", {"status": "success", "result": [fn("a"), fn("a")]}, "twice")

    # Google's own field is `hash`; the same value is mirrored into labels. Both
    # are accepted, absence is not.
    only_label = {"status": "success",
                  "result": [fn("a", hash=None, labels={"firebase-functions-hash": "abc"})]}
    parsed = D.parse_listing(only_label, "p", "default")
    check("listing: a hash carried only in labels is still readable",
          (parsed["a"].get("labels") or {}).get("firebase-functions-hash") == "abc")


# --------------------------------------------------------------------------
# 7. The end-to-end fixture: a real git repo, a real divergence
# --------------------------------------------------------------------------


def git(root: str, *argv: str) -> None:
    """Every setting the fixture depends on is pinned on the command line.

    A runner with no global git identity, a different `init.defaultBranch`, or
    commit signing turned on must produce the SAME fixture as this laptop —
    otherwise a red here would be about the runner's git config rather than
    about the tool, which is the least useful red there is.
    """
    subprocess.run(
        ["git", "-c", "user.email=t@t", "-c", "user.name=t", "-c", "commit.gpgsign=false",
         "-c", "init.defaultBranch=main", "-c", "core.autocrlf=false",
         "-c", "core.excludesFile=/dev/null", "-C", root, *argv],
        capture_output=True, text=True, check=True, timeout=60)


def build_fixture(foreign: bool = True) -> str:
    """A miniature repo: two tracked sources, one built file, one FOREIGN file."""
    root = tempfile.mkdtemp()
    src = os.path.join(root, "functions")
    os.makedirs(os.path.join(src, "src"))
    os.makedirs(os.path.join(src, "lib"))
    with open(os.path.join(root, "firebase.json"), "w") as handle:
        json.dump({"functions": {"source": "functions", "codebase": "default"}}, handle)
    with open(os.path.join(root, ".firebaserc"), "w") as handle:
        json.dump({"projects": {"default": "p"}}, handle)
    with open(os.path.join(src, "package.json"), "w") as handle:
        json.dump({"main": "lib/index.js"}, handle)
    with open(os.path.join(src, "src", "index.ts"), "w") as handle:
        handle.write("export { alpha } from './a';\nexport { beta } from './b';\n")
    # lib/ and coverage/ are gitignored here exactly as they are in the real
    # repo — that is what makes one of them BUILD OUTPUT and the other FOREIGN.
    with open(os.path.join(src, ".gitignore"), "w") as handle:
        handle.write("lib/\ncoverage/\n")
    git(root, "init", "-q")
    git(root, "add", "-A")
    git(root, "commit", "-qm", "fixture")
    with open(os.path.join(src, "lib", "index.js"), "w") as handle:
        handle.write("exports.alpha = 1;\n")
    if foreign:
        # gitignored debris, exactly the shape production carries
        os.makedirs(os.path.join(src, "coverage"))
        with open(os.path.join(src, "coverage", "lcov.html"), "w") as handle:
            handle.write("<html>a coverage report</html>")
    return root


def fixture_hashes(root: str) -> tuple[str, str, D.Partition]:
    src = os.path.join(root, "functions")
    patterns = list(D.DEFAULT_IGNORE) + list(D.ALWAYS_IGNORE)
    part = D.Partition(D.walk_packaged(src, patterns),
                       D.git_tracked("functions", root),
                       os.path.join(src, "lib"))
    return D.source_hash(part.reference), D.source_hash(part.packaged), part


def listing_for(source_digest: str, ids=("alpha", "beta")) -> dict:
    env = D.env_hash({}, PROD_FIREBASE_CONFIG, "p")
    stamped = D.endpoint_hash(source_digest, env, D.sha1("{}"))
    return {"status": "success", "result": [fn(i, hash=stamped) for i in ids]}


@section
def verdict_uses_the_reference_not_the_working_tree():
    root = build_fixture(foreign=True)
    try:
        ref, work, part = fixture_hashes(root)
        check("fixture: the reference and the working tree genuinely DIVERGE",
              ref != work, "the fixture proves nothing if they agree")
        check("fixture: the foreign file is partitioned as foreign, not tracked",
              len(part.foreign) == 1 and part.foreign[0].endswith("lcov.html"),
              str(part.foreign))
        check("fixture: the built file is partitioned as build output",
              len(part.build) == 1 and part.build[0].endswith("lib/index.js"), str(part.build))
        check("fixture: the reference is tracked + built, and excludes the foreign file",
              len(part.reference) == len(part.tracked) + len(part.build))

        RUN_LISTING[0] = lambda p: listing_for(ref)
        code, text = run_cli(["--project", "p", "--root", root])
        check("verdict: a deployment matching the REFERENCE is exit 0",
              code == D.EXIT_OK, f"exit {code}\n{text}")
        check("verdict: exit 0 says the deployment is a clean build",
              "clean build of this ref" in text, text)

        # THE mutation this fixture exists for (ADR-043 D3): if the verdict were
        # computed from the working tree, this would be exit 0.
        RUN_LISTING[0] = lambda p: listing_for(work)
        code, text = run_cli(["--project", "p", "--root", root])
        check("verdict: a deployment matching only the WORKING TREE is DRIFT, not clean",
              code == D.EXIT_DRIFT, f"exit {code}\n{text}")
        check("verdict: and it is diagnosed as a hand-deploy, not as wrong code",
              "THIS WORKING DIRECTORY" in text and "PROCESS gap" in text, text)
        check("verdict: the hand-deploy diagnosis NAMES a foreign file",
              "lcov.html" in text, text)
        annotation = next((ln for ln in text.splitlines() if ln.startswith("::error::")), "")
        check("annotation: a hand-deploy is annotated as a process gap, not wrong code",
              "process gap, not wrong code" in annotation, annotation)

        # Neither digest: genuinely wrong code. The report must NOT say process gap.
        RUN_LISTING[0] = lambda p: listing_for("0" * 40)
        code, text = run_cli(["--project", "p", "--root", root])
        check("verdict: a deployment matching NEITHER digest is DRIFT",
              code == D.EXIT_DRIFT, f"exit {code}")
        check("verdict: wrong code is reported as wrong code, NOT as a process gap",
              "NOT this ref" in text and "PROCESS gap" not in text, text)
    finally:
        RUN_LISTING[0] = None
        shutil.rmtree(root, ignore_errors=True)


@section
def set_comparison_is_independent_of_the_hash():
    root = build_fixture(foreign=False)
    try:
        ref, work, _ = fixture_hashes(root)
        check("fixture: with no foreign file the two digests COINCIDE", ref == work)

        # A function the ref exports that is not deployed: S063's exact shape.
        RUN_LISTING[0] = lambda p: listing_for(ref, ids=("alpha",))
        code, text = run_cli(["--project", "p", "--root", root])
        check("set: an exported-but-undeployed function is DRIFT even when every "
              "deployed hash matches", code == D.EXIT_DRIFT, f"exit {code}\n{text}")
        check("set: the report NAMES the missing function", "beta" in text, text)
        check("set: and calls it out as the S063 shape", "S063" in text, text)
        # The CI annotation is the one line most readers see. It must describe
        # THIS finding: telling someone to redeploy source that already matches
        # sends them to fix the wrong thing.
        annotation = next((ln for ln in text.splitlines() if ln.startswith("::error::")), "")
        check("annotation: names the missing function, not a source mismatch",
              "NOT DEPLOYED" in annotation and "beta" in annotation, annotation)
        check("annotation: explicitly says the deployed source DOES match",
              "every deployed function's source matches" in annotation, annotation)
        check("annotation: does NOT claim wrong code is running",
              "NOT this ref" not in annotation, annotation)

        RUN_LISTING[0] = lambda p: listing_for(ref, ids=("alpha", "beta", "orphan"))
        code, text = run_cli(["--project", "p", "--root", root])
        check("set: a deployed-but-unexported function is DRIFT", code == D.EXIT_DRIFT, f"exit {code}")
        check("set: the report NAMES the orphan", "orphan" in text, text)

        RUN_LISTING[0] = lambda p: {"status": "success",
                                    "result": [fn("alpha", hash=D.endpoint_hash(
                                        ref, D.env_hash({}, PROD_FIREBASE_CONFIG, "p"),
                                        D.sha1("{}"))),
                                        fn("beta", state="DEPLOYING", hash=D.endpoint_hash(
                                            ref, D.env_hash({}, PROD_FIREBASE_CONFIG, "p"),
                                            D.sha1("{}")))]}
        code, text = run_cli(["--project", "p", "--root", root])
        check("set: a non-ACTIVE function is DRIFT even with a matching hash",
              code == D.EXIT_DRIFT, f"exit {code}")
        check("set: the report names the state it saw", "DEPLOYING" in text, text)
    finally:
        RUN_LISTING[0] = None
        shutil.rmtree(root, ignore_errors=True)


@section
def cannot_measure_is_never_drift_and_never_clean():
    root = build_fixture(foreign=False)
    try:
        ref, _, _ = fixture_hashes(root)

        RUN_LISTING[0] = lambda p: {"status": "success", "result": []}
        code, text = run_cli(["--project", "p", "--root", root])
        check("exit 2: ZERO deployed functions is 'could not measure', not drift "
              "(lesson 65 — an empty result is unverified)",
              code == D.EXIT_CANNOT_MEASURE, f"exit {code}\n{text}")
        check("exit 2: and it names both readings it cannot tell apart",
              "cannot tell those apart" in text, text)

        RUN_LISTING[0] = lambda p: {"status": "success",
                                    "result": [fn("alpha", hash=None), fn("beta", hash=None)]}
        code, text = run_cli(["--project", "p", "--root", root])
        check("exit 2: a function with NO firebase-functions-hash is unmeasurable, "
              "not matching", code == D.EXIT_CANNOT_MEASURE, f"exit {code}\n{text}")
        check("exit 2: and says nothing can be concluded about its source",
              "unmeasurable function, not a matching one" in text, text)

        RUN_LISTING[0] = lambda p: listing_for(ref)
        code, text = run_cli(["--project", "p", "--root", root])
        check("exit 2: no --project at all", run_cli(["--root", root])[0] == D.EXIT_CANNOT_MEASURE)

        # An unbuilt lib/ is exit 2: the deployed source contains the COMPILED
        # output, so a comparison against a tree without it is meaningless.
        shutil.rmtree(os.path.join(root, "functions", "lib"))
        code, text = run_cli(["--project", "p", "--root", root])
        check("exit 2: an unbuilt functions/lib is 'could not measure', not drift",
              code == D.EXIT_CANNOT_MEASURE, f"exit {code}\n{text}")
        check("exit 2: and it says npm run build", "npm run build" in text, text)
    finally:
        RUN_LISTING[0] = None
        shutil.rmtree(root, ignore_errors=True)


@section
def a_binding_dotenv_stops_the_check():
    root = build_fixture(foreign=False)
    try:
        ref, _, _ = fixture_hashes(root)
        with open(os.path.join(root, "functions", ".env.p"), "w") as handle:
            handle.write("SOMETHING=1\n")
        RUN_LISTING[0] = lambda p: listing_for(ref)
        code, text = run_cli(["--project", "p", "--root", root])
        check("exit 2: a dotenv that binds for the project stops the check rather "
              "than being silently ignored", code == D.EXIT_CANNOT_MEASURE, f"exit {code}\n{text}")
        check("exit 2: and it explains that a wrong parser would look like real drift",
              "false RED" in text, text)

        os.remove(os.path.join(root, "functions", ".env.p"))
        # An ALIAS dotenv binds just as hard — .firebaserc maps default -> p.
        with open(os.path.join(root, "functions", ".env.default"), "w") as handle:
            handle.write("SOMETHING=1\n")
        code, text = run_cli(["--project", "p", "--root", root])
        check("exit 2: an ALIAS dotenv (.env.<alias> from .firebaserc) binds too",
              code == D.EXIT_CANNOT_MEASURE, f"exit {code}\n{text}")
    finally:
        RUN_LISTING[0] = None
        shutil.rmtree(root, ignore_errors=True)


@section
def a_deployment_with_no_firebase_config_cannot_be_compared():
    root = build_fixture(foreign=False)
    try:
        ref, _, _ = fixture_hashes(root)
        RUN_LISTING[0] = lambda p: {"status": "success",
                                    "result": [fn("alpha", environmentVariables={}),
                                               fn("beta")]}
        code, text = run_cli(["--project", "p", "--root", root])
        check("exit 2: a deployed function with no FIREBASE_CONFIG cannot be compared",
              code == D.EXIT_CANNOT_MEASURE, f"exit {code}\n{text}")
        check("exit 2: and says the comparison would be against an invented value",
              "invented" in text, text)
    finally:
        RUN_LISTING[0] = None
        shutil.rmtree(root, ignore_errors=True)


# --------------------------------------------------------------------------
# 8. The vendor guard: the algorithm is re-verified against its author
# --------------------------------------------------------------------------


@section
def vendor_derivation_guard():
    root = tempfile.mkdtemp()
    try:
        os.makedirs(os.path.join(root, "lib", "deploy", "functions", "cache"))
        with open(os.path.join(root, "lib", "deploy", "functions", "cache", "hash.js"), "w") as handle:
            handle.write("nothing recognisable here\n")
        try:
            D.assert_vendor_derivation(root)
            check("vendor: a firebase-tools whose hash.js moved is REFUSED", False, "accepted")
        except D.MeasurementError as exc:
            check("vendor: a firebase-tools whose hash.js moved is REFUSED", True)
            check("vendor: the refusal names the claim that stopped matching",
                  "getEndpointHash" in str(exc), str(exc))
            check("vendor: and says a stale transcription would report false drift",
                  "not drift" in str(exc), str(exc))

        for bad, why in [("16.0.0", "a different major"), ("nonsense", "an unparseable version")]:
            try:
                D.assert_supported_cli(bad)
                check(f"vendor: {why} is REFUSED", False, "accepted")
            except D.MeasurementError:
                check(f"vendor: {why} is REFUSED", True)
        check("vendor: the pinned version passes silently",
              D.assert_supported_cli(D.VERIFIED_CLI_VERSION) == [])
        notes = D.assert_supported_cli(f"{D.VERIFIED_CLI_MAJOR}.99.99")
        check("vendor: a same-major difference is a NOTE, not a refusal and not a "
              "::warning:: on a green build (architecture §9)",
              len(notes) == 1 and not notes[0].startswith("::"), str(notes))
    finally:
        shutil.rmtree(root, ignore_errors=True)


# --------------------------------------------------------------------------
# 9. The subprocess seams — hermetic, via a fake `firebase` on disk
# --------------------------------------------------------------------------


def fake_firebase(root: str, stdout: str, code: int = 0) -> str:
    """A stand-in executable. No network, no real CLI, fully deterministic."""
    path = os.path.join(root, "fake-firebase")
    with open(path, "w") as handle:
        handle.write("#!/bin/sh\ncat <<'FAKEEOF'\n" + stdout + "\nFAKEEOF\nexit " + str(code) + "\n")
    os.chmod(path, 0o755)
    return path


@section
def subprocess_seams():
    root = tempfile.mkdtemp()
    try:
        check("cli_version: reads the version the binary prints",
              D.cli_version(fake_firebase(root, "15.22.4")) == "15.22.4")
        # An update banner can print on EITHER side of the version, and which
        # side is not ours to assume — so the version is found by shape, from
        # either position, rather than by index.
        check("cli_version: finds the version under a banner ABOVE it",
              D.cli_version(fake_firebase(root, "Update available!\n15.22.4")) == "15.22.4")
        check("cli_version: finds the version under a banner BELOW it",
              D.cli_version(fake_firebase(root, "15.22.4\nUpdate available!")) == "15.22.4")
        try:
            # A banner that itself carries a version number is the case where
            # picking [0] or [-1] would silently validate the derivation against
            # the WRONG version. Two candidates must be a refusal, not a choice.
            D.cli_version(fake_firebase(root, "15.22.4\n16.0.0 is available"))
            check("cli_version: TWO version-shaped lines is a refusal, not a guess",
                  False, "it picked one")
        except D.MeasurementError as exc:
            check("cli_version: TWO version-shaped lines is a refusal, not a guess", True)
            check("cli_version: and says how many it saw", "2 version-shaped" in str(exc), str(exc))
        try:
            D.cli_version(os.path.join(root, "definitely-not-installed"))
            check("cli_version: an absent binary is 'could not measure'", False, "accepted")
        except D.MeasurementError as exc:
            check("cli_version: an absent binary is 'could not measure'", True)
            check("cli_version: and says it will not pretend to pass",
                  "will not pretend to pass" in str(exc), str(exc))

        payload = json.dumps({"status": "success", "result": []})
        got = D.run_listing("p", fake_firebase(root, payload), root)
        check("run_listing: parses the CLI's JSON", got == {"status": "success", "result": []})

        # Lesson 65: silence is UNVERIFIED. `functions:list` printing nothing
        # must never be read as "this project has no functions".
        try:
            D.run_listing("p", fake_firebase(root, "", code=0), root)
            check("run_listing: EMPTY stdout is an unverified read, not an empty project",
                  False, "accepted")
        except D.MeasurementError as exc:
            check("run_listing: EMPTY stdout is an unverified read, not an empty project", True)
            check("run_listing: and says so in those terms",
                  "unverified read" in str(exc), str(exc))

        try:
            D.run_listing("p", fake_firebase(root, "Error: not logged in"), root)
            check("run_listing: non-JSON output is refused", False, "accepted")
        except D.MeasurementError as exc:
            check("run_listing: non-JSON output is refused", True)
            check("run_listing: and quotes what it saw instead",
                  "not logged in" in str(exc), str(exc))
    finally:
        shutil.rmtree(root, ignore_errors=True)


@section
def walk_follows_symlinks_like_the_cli():
    """`ignoreSymlinks` is NOT set on the deploy path, so the CLI's statSync
    follows them and their targets are packaged. A tool that skipped them would
    compute a hash over a smaller set than the CLI uploaded."""
    root = tempfile.mkdtemp()
    try:
        os.makedirs(os.path.join(root, "real"))
        with open(os.path.join(root, "real", "target.js"), "w") as handle:
            handle.write("payload")
        os.symlink(os.path.join(root, "real", "target.js"), os.path.join(root, "link.js"))
        os.symlink(os.path.join(root, "real"), os.path.join(root, "linkdir"))

        patterns = list(D.DEFAULT_IGNORE) + list(D.ALWAYS_IGNORE)
        rel = sorted(os.path.relpath(p, root) for p in D.walk_packaged(root, patterns))
        check("walk: a symlink to a FILE is packaged (ignoreSymlinks is not set on deploy)",
              "link.js" in rel, str(rel))
        check("walk: a symlink to a DIRECTORY is descended into",
              "linkdir/target.js" in rel, str(rel))

        os.symlink(os.path.join(root, "nowhere"), os.path.join(root, "broken.js"))
        try:
            D.walk_packaged(root, patterns)
            check("walk: a BROKEN symlink is 'could not measure', not silently skipped",
                  False, "accepted")
        except D.MeasurementError as exc:
            check("walk: a BROKEN symlink is 'could not measure', not silently skipped", True)
            check("walk: and says the CLI would refuse this tree",
                  "the CLI would refuse" in str(exc), str(exc))
    finally:
        shutil.rmtree(root, ignore_errors=True)


@section
def partition_and_dirty_notes():
    root = build_fixture(foreign=True)
    try:
        src = os.path.join(root, "functions")
        check("git_dirty: a committed fixture reports NOTHING dirty",
              D.git_dirty("functions", root) == [], str(D.git_dirty("functions", root)))
        with open(os.path.join(src, "src", "index.ts"), "a") as handle:
            handle.write("// edited\n")
        dirty = D.git_dirty("functions", root)
        check("git_dirty: an edited TRACKED file is reported", len(dirty) == 1, str(dirty))
        check("git_dirty: an untracked/ignored file is NOT reported as dirty",
              not any("lcov" in d or "coverage" in d for d in dirty), str(dirty))
        # The note it drives must appear, because the reference below it is then
        # this working copy of the tracked files rather than HEAD's.
        RUN_LISTING[0] = lambda p: listing_for(fixture_hashes(root)[0])
        _, text = run_cli(["--project", "p", "--root", root])
        check("main: an edited tracked file prints the note that the reference is "
              "the WORKING COPY, not HEAD", "differ from HEAD" in text, text)

        # A trailing separator on the build dir must not change membership: the
        # partition compares normalised absolute paths, not raw strings.
        packaged = D.walk_packaged(src, list(D.DEFAULT_IGNORE) + list(D.ALWAYS_IGNORE))
        tracked = D.git_tracked("functions", root)
        plain = D.Partition(packaged, tracked, os.path.join(src, "lib"))
        slashed = D.Partition(packaged, tracked, os.path.join(src, "lib") + os.sep)
        dotted = D.Partition(packaged, tracked, os.path.join(src, ".", "lib"))
        check("Partition: a trailing separator on the build dir changes nothing",
              plain.build == slashed.build, f"{plain.build} vs {slashed.build}")
        check("Partition: a non-normalised build dir changes nothing",
              plain.build == dotted.build, f"{plain.build} vs {dotted.build}")
        check("Partition: the three parts are DISJOINT",
              not (set(plain.tracked) & set(plain.build))
              and not (set(plain.build) & set(plain.foreign))
              and not (set(plain.tracked) & set(plain.foreign)))
    finally:
        RUN_LISTING[0] = None
        shutil.rmtree(root, ignore_errors=True)


# --------------------------------------------------------------------------
# 10. The real repository — the plan must describe the tree it ships with
# --------------------------------------------------------------------------


@section
def repo_reality():
    root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    source_rel, codebase, patterns = D.read_functions_config(os.path.join(root, "firebase.json"))
    check("repo: firebase.json still declares one functions codebase", codebase == "default")
    src = os.path.join(root, source_rel)
    check("repo: the build output directory resolves to functions/lib",
          D.build_output_dir(src) == os.path.join(src, "lib"))

    exported = D.parse_barrel(os.path.join(src, "src", "index.ts"))
    check("repo: the barrel is still a pure re-export barrel this parser accepts",
          len(exported) > 0)
    check("repo: it exports the 13 functions production runs", len(exported) == 13, str(exported))
    for required in ("registerPushToken", "unregisterPushToken", "revenueCatWebhook",
                     "coachProxy", "questionRollover"):
        check(f"repo: {required} is exported", required in exported)

    tracked = D.git_tracked(source_rel, root)
    check("repo: git reports tracked files under functions/", len(tracked) > 50, str(len(tracked)))
    build_dir = D.build_output_dir(src)
    part = D.Partition(D.walk_packaged(src, patterns), tracked, build_dir)
    check("repo: every packaged file lands in exactly one partition",
          len(part.packaged) == len(part.tracked) + len(part.build) + len(part.foreign),
          f"{len(part.packaged)} vs {len(part.tracked)}+{len(part.build)}+{len(part.foreign)}")

    # `quality` runs BEFORE any npm install and never builds functions/, so on a
    # CI runner this repository legitimately has no functions/lib. Asserting
    # "the build output is present" would redden there for a reason that is not
    # a defect — the cry-wolf shape. So assert the CONTRACT in whichever state
    # this tree is actually in, and assert BOTH halves of it: the unbuilt case
    # is the one the runner exercises, and it must be exit 2 with the remedy
    # printed, never a comparison against a tree missing every compiled file.
    if os.path.isdir(build_dir):
        check("repo: functions/lib is built, so the reference set carries build output",
              len(part.build) > 0)
        check("repo: no build-output file is also reported as tracked",
              not (set(part.build) & set(part.tracked)))
    else:
        code, text = D.EXIT_CANNOT_MEASURE, ""
        out, err = io.StringIO(), io.StringIO()
        with redirect_stdout(out), redirect_stderr(err):
            code = D.main(["--project", "unused", "--root", root, "--skip-version-check"],
                          listing_loader=lambda p: {"status": "success", "result": []})
        text = out.getvalue() + err.getvalue()
        check("repo: with functions/lib unbuilt, the tool is 'could not measure' — "
              "never a comparison against a tree missing every compiled file",
              code == D.EXIT_CANNOT_MEASURE, f"exit {code}\n{text}")
        check("repo: and it prints the remedy", "npm run build" in text, text)
        check("repo: an unbuilt tree yields no build-output partition", len(part.build) == 0)


# --------------------------------------------------------------------------

for _section in SECTIONS:
    try:
        _section()
    except Exception:  # a mutation that RAISES must still name the property it broke
        CHECKS += 1
        FAILURES.append(f"{_section.__name__}: raised {traceback.format_exc(limit=0).strip()}")

print(f"functions_drift: {CHECKS} checks, {len(FAILURES)} failed")
for failure in FAILURES:
    print(f"  FAIL {failure}")
sys.exit(1 if FAILURES else 0)
