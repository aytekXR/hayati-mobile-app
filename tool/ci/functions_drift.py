#!/usr/bin/env python3
"""Is the Cloud Functions code that PRODUCTION RUNS the code on this ref? (#166)

WHY THIS EXISTS. `ci.yml`'s `functions-rules` job proves `functions/` against
the emulator on every PR, honestly — but the emulator loads the WORKING TREE.
It guards code the runtime never executes. That cost S063 the entire push
feature: the whole stack merged, every check green, two builds shipped, and
production was still running Functions from before #190, so the callables the
app invokes DID NOT EXIST. Nothing in the repository could have said so.
ADR-041 built this comparison for firestore rules and deliberately left
Functions out, because no endpoint returns a deployed function's source.

WHAT MAKES IT POSSIBLE ANYWAY. `firebase-functions-hash`, the label the CLI
stamps on every function it deploys, is not opaque. Its derivation was read out
of the INSTALLED firebase-tools (never out of documentation — the vendor's code
is the only thing that can refute a vendor's behaviour) and reproduces all 13
production hashes exactly:

    sourceHash   = sha1( sorted([ sha1(bytes) for each packaged file ]).join("") )
    envHash      = sha1( JSON.stringify(backend.environmentVariables) )
    secretsHash  = sha1( JSON.stringify({ secretName: boundVersion, ... }) )
    endpointHash = sha1( [sourceHash, envHash, secretsHash].filter(truthy).join("") )

    firebase-tools/lib/deploy/functions/cache/hash.js
    firebase-tools/lib/deploy/functions/cache/applyHash.js
    firebase-tools/lib/deploy/functions/prepareFunctionsUpload.js  (packageSource)
    firebase-tools/lib/fsAsync.js                                  (readdirRecursive)

`sourceHash` digests a sorted MULTISET OF PER-FILE DIGESTS, not the zip bytes.
That is the whole reason this works: a zip carries mtimes, entry order and
compressor state; a sorted list of content hashes is content-addressed.

TWO VERDICTS, DELIBERATELY SEPARATE (ADR-043 D2). They fail for different
reasons and have different remedies, so collapsing them would lose the
diagnosis — the same mistake as collapsing exit 1 into exit 2:

  * the SET comparison — every function `functions/src/index.ts` exports must be
    deployed, and nothing else. No hashing, no build, no credential beyond the
    listing. THIS is the check whose absence cost S063 the push feature.
  * the HASH comparison — per function, per the derivation above.

THE REFERENCE IS A CLEAN TREE, AND THE WORKING TREE IS THE DIAGNOSIS
(ADR-043 D3). The CLI packages the DIRECTORY; it does not consult git. Of the
275 files in production's digest, 62 are gitignored machine-local debris. So
the verdict is computed over `tracked ∪ build output` — what a clean checkout
plus `npm ci && npm run build` has — and the working-tree digest is computed
too, only so the report can tell these apart:

    DRIFT, working tree does not match either -> production runs code that is
        not this ref. Alarming.
    DRIFT, but the working tree DOES match    -> production runs this ref's
        code, hand-deployed from a directory carrying N foreign files. A
        process gap.

FAIL-CLOSED, ALWAYS. Exit codes are a taxonomy, not a boolean:

    0   every deployed function is a clean build of this ref, and the deployed
        set is exactly the exported set
    1   DRIFT — it looked, and they differ. This is the finding.
    2   COULD NOT MEASURE — no CLI, no credential, an unparseable listing, an
        unbuilt functions/lib, a barrel this parser refuses, an environment
        component it could not reconstruct. NEVER 0.

Run (a session on the founder's box, reusing the logged-in firebase CLI):
    python3 tool/ci/functions_drift.py --project hayatiapp-prod --project hayatiapp-dev

Run (CI, read-only service account — ADR-043 D7):
    GOOGLE_APPLICATION_CREDENTIALS=sa.json \
      python3 tool/ci/functions_drift.py --project hayatiapp-prod
"""

from __future__ import annotations

import argparse
import fnmatch
import hashlib
import json
import os
import pathlib
import re
import subprocess
import sys

EXIT_OK = 0
EXIT_DRIFT = 1
EXIT_CANNOT_MEASURE = 2

# The derivation above was read out of this version. A major bump could rewrite
# it, and this tool would then compute confident nonsense — so a different major
# is exit 2, not a guess (ADR-043 D9).
VERIFIED_CLI_VERSION = "15.22.4"
VERIFIED_CLI_MAJOR = 15

# packageSource(): `const ignore = config.ignore || ["node_modules", ".git"]`,
# then it pushes the debug logs and CONFIG_DEST_FILE. Reproduced, not invented.
DEFAULT_IGNORE = ["node_modules", ".git"]
ALWAYS_IGNORE = ["firebase-debug.log", "firebase-debug.*.log", ".runtimeconfig.json"]

# loadFirebaseEnvs() injects exactly these two, and functions/env.js refuses them
# in a user dotenv (they are RESERVED_KEYS), which is why reconstructing the
# backend environment cannot collide with a user value.
RESERVED_ENV_KEYS = ("FIREBASE_CONFIG", "GCLOUD_PROJECT")


class MeasurementError(Exception):
    """Raised whenever the tool cannot establish what is deployed. Always exit 2."""


# --------------------------------------------------------------------------
# the primitives, transcribed from firebase-tools
# --------------------------------------------------------------------------


def sha1(data) -> str:
    digest = hashlib.sha1()
    digest.update(data if isinstance(data, bytes) else data.encode())
    return digest.hexdigest()


def js_stringify(obj) -> str:
    """`JSON.stringify` for the shapes this tool hashes.

    Compact separators and `ensure_ascii=False` match V8 for objects of plain
    strings, which is all that reaches here (project ids and a JSON blob). It is
    NOT a general JSON.stringify: no `undefined` elision, no `toJSON`, no
    surrogate handling. Nothing else may be passed to it.
    """
    return json.dumps(obj, separators=(",", ":"), ensure_ascii=False)


def is_ignored(path: str, patterns: list[str]) -> bool:
    """`minimatch(p, glob, {matchBase: true, dot: true})`.

    `matchBase` means a pattern containing NO slash is matched against the
    basename only, and none of the patterns this tool accepts contains one —
    `read_functions_config` refuses a config that introduces a slashed pattern
    rather than silently applying the wrong semantics to it.
    """
    base = os.path.basename(path)
    return any(fnmatch.fnmatchcase(base, pattern) for pattern in patterns)


def walk_packaged(source_dir: str, patterns: list[str]) -> list[str]:
    """`fsAsync.readdirRecursive` — every file the CLI would put in the archive.

    Directories that match are pruned, exactly as the CLI prunes them (the
    filter runs on directory entries before recursion). Symlinks are followed,
    because `ignoreSymlinks` is not set on the deploy path.
    """
    found: list[str] = []
    try:
        entries = sorted(os.listdir(source_dir))
    except OSError as exc:
        raise MeasurementError(f"cannot read {source_dir}: {exc.strerror}") from None
    for entry in entries:
        path = os.path.join(source_dir, entry)
        if is_ignored(path, patterns):
            continue
        if os.path.isfile(path):
            found.append(path)
        elif os.path.isdir(path):
            found.extend(walk_packaged(path, patterns))
        elif not os.path.exists(path):
            # A broken symlink: the CLI's statSync would throw here, so the
            # deploy this tool is modelling could not have happened. Failing
            # closed beats hashing a set the CLI would have refused.
            raise MeasurementError(f"{path} is a broken symlink — the CLI would refuse this tree")
    return found


def source_hash(files: list[str]) -> str:
    """`packageSource`: sha1 over the SORTED per-file sha1s, joined."""
    digests = []
    for path in files:
        try:
            with open(path, "rb") as handle:
                digests.append(sha1(handle.read()))
        except OSError as exc:
            raise MeasurementError(f"cannot read {path}: {exc.strerror}") from None
    return sha1("".join(sorted(digests)))


def endpoint_hash(src: str, env: str, secrets: str) -> str:
    """`getEndpointHash` — falsy components are dropped BEFORE joining."""
    return sha1("".join(part for part in (src, env, secrets) if part))


def secrets_hash(secret_env_vars: list[dict] | None) -> str:
    """`getSecretsHash(endpoint)` via `getSecretVersions`: {secret: version|""}."""
    mapping: dict[str, str] = {}
    for sev in secret_env_vars or []:
        if not isinstance(sev, dict) or "secret" not in sev:
            raise MeasurementError(f"unexpected secretEnvironmentVariables entry: {sev!r}")
        mapping[sev["secret"]] = sev.get("version") or ""
    return sha1(js_stringify(mapping))


def env_hash(user_envs: dict[str, str], firebase_config: str, project: str) -> str:
    """`getEnvironmentVariablesHash(wantBackend)` where the backend env is
    `{...userEnvs, ...loadFirebaseEnvs(firebaseConfig, projectId)}`.

    `firebase_config` is taken VERBATIM from the deployed function's own
    environment: it carries the project's default storage bucket, which is a
    remote fact this repository cannot derive, and the deployed value IS the
    string the CLI hashed. That is a reconstruction, not a guess (ADR-043 D4).
    """
    combined = dict(user_envs)
    combined["FIREBASE_CONFIG"] = firebase_config
    combined["GCLOUD_PROJECT"] = project
    return sha1(js_stringify(combined))


# --------------------------------------------------------------------------
# the local side
# --------------------------------------------------------------------------


def read_functions_config(firebase_json_path: str) -> tuple[str, str, list[str]]:
    """(source dir, codebase, ignore patterns) from firebase.json. Fails closed."""
    try:
        config = json.loads(pathlib.Path(firebase_json_path).read_text())
    except OSError as exc:
        raise MeasurementError(f"cannot read {firebase_json_path}: {exc.strerror}") from None
    except json.JSONDecodeError as exc:
        raise MeasurementError(f"{firebase_json_path} is not valid JSON: {exc}") from None

    functions = config.get("functions")
    if isinstance(functions, list):
        # A second codebase has its own source directory and its own sourceHash.
        # Comparing only the first would be silently partial — this tool's own
        # failure mode, one level down (ADR-041's named-database guard).
        if len(functions) != 1:
            raise MeasurementError(
                f"firebase.json declares {len(functions)} functions codebases; this check "
                "compares one. Failing closed rather than reporting a partial green.")
        functions = functions[0]
    if not isinstance(functions, dict):
        raise MeasurementError("firebase.json has no `functions` configuration")

    src = functions.get("source")
    if not src:
        raise MeasurementError("firebase.json's `functions` block declares no `source`")
    codebase = functions.get("codebase") or "default"

    patterns = list(functions.get("ignore") or DEFAULT_IGNORE) + list(ALWAYS_IGNORE)
    slashed = [p for p in patterns if "/" in p]
    if slashed:
        # minimatch's matchBase shortcut stops applying to a slashed pattern, and
        # this tool implements only the shortcut. Refusing beats applying the
        # wrong semantics and reporting a hash nobody can explain.
        raise MeasurementError(
            "firebase.json's functions.ignore contains path patterns this check does not "
            f"implement ({', '.join(slashed)}) — it reproduces minimatch's matchBase form only")
    return src, codebase, patterns


def build_output_dir(source_dir: str) -> str:
    """The build directory, read out of package.json's `main` — never hardcoded.

    Same reason `app_icons.py` reads its target list out of `Contents.json`
    (lesson 66): a hardcoded `lib/` and a moved build output would drift apart
    in silence, and the reference set would then be missing every compiled file
    while the report named no cause.
    """
    pkg_path = os.path.join(source_dir, "package.json")
    try:
        pkg = json.loads(pathlib.Path(pkg_path).read_text())
    except OSError as exc:
        raise MeasurementError(f"cannot read {pkg_path}: {exc.strerror}") from None
    except json.JSONDecodeError as exc:
        raise MeasurementError(f"{pkg_path} is not valid JSON: {exc}") from None
    main = pkg.get("main")
    if not main or "/" not in main:
        raise MeasurementError(
            f"{pkg_path} declares main={main!r}; this check derives the build output "
            "directory from it and cannot proceed without a directory component")
    return os.path.join(source_dir, main.split("/", 1)[0])


def git_tracked(source_dir: str, repo_root: str) -> set[str]:
    try:
        out = subprocess.run(
            ["git", "-C", repo_root, "ls-files", "-z", "--", source_dir],
            capture_output=True, text=True, timeout=60, check=False)
    except (OSError, subprocess.SubprocessError) as exc:
        raise MeasurementError(f"`git ls-files` failed: {exc}") from None
    if out.returncode != 0:
        raise MeasurementError(f"`git ls-files` exited {out.returncode}: {out.stderr.strip()}")
    return {os.path.join(repo_root, p) for p in out.stdout.split("\0") if p}


def git_dirty(source_dir: str, repo_root: str) -> list[str]:
    """Tracked files under `source_dir` that differ from HEAD. A note, not a verdict."""
    try:
        out = subprocess.run(
            ["git", "-C", repo_root, "status", "--porcelain", "--", source_dir],
            capture_output=True, text=True, timeout=60, check=False)
    except (OSError, subprocess.SubprocessError) as exc:
        raise MeasurementError(f"`git status` failed: {exc}") from None
    if out.returncode != 0:
        raise MeasurementError(f"`git status` exited {out.returncode}: {out.stderr.strip()}")
    return [line[3:] for line in out.stdout.splitlines() if line and not line.startswith("??")]


class Partition:
    """The packaged set, split against git. The reference is what a clean
    checkout plus a build would carry; `foreign` is everything else."""

    def __init__(self, packaged: list[str], tracked: set[str], build_dir: str) -> None:
        build_prefix = os.path.join(os.path.abspath(build_dir), "")
        self.packaged = sorted(packaged)
        self.tracked = sorted(p for p in self.packaged if p in tracked)
        self.build = sorted(
            p for p in self.packaged
            if p not in tracked and os.path.abspath(p).startswith(build_prefix))
        self.foreign = sorted(
            set(self.packaged) - set(self.tracked) - set(self.build))
        self.reference = sorted(set(self.tracked) | set(self.build))


def parse_barrel(index_ts: str) -> list[str]:
    """The names `functions/src/index.ts` re-exports. Fails closed on anything else.

    The file is a pure re-export barrel and only that form is accepted. `export
    *` cannot be resolved without following imports, and a parser that quietly
    returned 12 of 13 names would reproduce this tool's own subject defect one
    level down — so an unexpected export form raises rather than under-counting.
    """
    try:
        text = pathlib.Path(index_ts).read_text()
    except OSError as exc:
        raise MeasurementError(f"cannot read {index_ts}: {exc.strerror}") from None

    stripped = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    stripped = re.sub(r"//[^\n]*", "", stripped)

    names: list[str] = []
    index = 0
    for match in re.finditer(r"\bexport\b", stripped):
        if match.start() < index:
            continue
        rest = stripped[match.end():]
        lead = rest.lstrip()
        if not lead.startswith("{"):
            form = lead.split("\n", 1)[0].strip()[:40]
            raise MeasurementError(
                f"{index_ts} contains an export form this check refuses: 'export {form}…'. "
                "Only `export {{ … }} from '…'` is resolvable without following imports; "
                "counting the resolvable ones and staying silent about the rest is the "
                "defect this tool exists to find.")
        offset = match.end() + (len(rest) - len(lead))
        close = stripped.find("}", offset)
        if close == -1:
            raise MeasurementError(f"{index_ts}: unterminated export block")
        after = stripped[close + 1:].lstrip()
        if not after.startswith("from"):
            raise MeasurementError(
                f"{index_ts}: `export {{ … }}` with no `from` clause is a local re-export "
                "this check cannot attribute to a deployed function")
        for raw in stripped[offset + 1:close].split(","):
            name = raw.strip()
            if not name:
                continue
            if " as " in name:
                name = name.split(" as ", 1)[1].strip()
            if name.startswith("type "):
                continue
            names.append(name)
        index = close
    if not names:
        raise MeasurementError(f"{index_ts} exports nothing this check can read")
    duplicates = {n for n in names if names.count(n) > 1}
    if duplicates:
        raise MeasurementError(f"{index_ts} exports {sorted(duplicates)} more than once")
    return sorted(names)


# --------------------------------------------------------------------------
# the deployed side
# --------------------------------------------------------------------------


def cli_version(firebase_bin: str) -> str:
    try:
        out = subprocess.run([firebase_bin, "--version"], capture_output=True,
                             text=True, timeout=120, check=False)
    except FileNotFoundError:
        raise MeasurementError(
            f"`{firebase_bin}` is not installed. This check cannot run without it and "
            "will not pretend to pass.") from None
    except (OSError, subprocess.SubprocessError) as exc:
        raise MeasurementError(f"`{firebase_bin} --version` failed: {exc}") from None
    if out.returncode != 0:
        raise MeasurementError(f"`{firebase_bin} --version` exited {out.returncode}")
    # firebase-tools can print an update banner alongside the version, and which
    # side it lands on is not ours to assume. Take the lines that LOOK like a
    # version and refuse if that is not exactly one — picking `[0]` or `[-1]`
    # would silently pin this check to a banner the day the layout changes, and
    # a derivation validated against the wrong version is the exact failure this
    # guard exists to prevent.
    candidates = [ln.strip() for ln in out.stdout.splitlines()
                  if re.match(r"^\d+\.\d+\.\d+", ln.strip())]
    if len(candidates) != 1:
        raise MeasurementError(
            f"`{firebase_bin} --version` printed {len(candidates)} version-shaped line(s); "
            f"expected exactly one. Output was: {out.stdout.strip()[:200]!r}")
    return candidates[0]


def assert_supported_cli(version: str) -> list[str]:
    """Returns note lines. A different MAJOR is exit 2 (ADR-043 D9)."""
    match = re.match(r"^(\d+)\.(\d+)\.(\d+)", version)
    if not match:
        raise MeasurementError(
            f"could not parse the firebase CLI version from {version!r} — refusing to "
            f"assume it computes hashes the way {VERIFIED_CLI_VERSION} does")
    major = int(match.group(1))
    if major != VERIFIED_CLI_MAJOR:
        raise MeasurementError(
            f"firebase-tools {version} is a different MAJOR than the {VERIFIED_CLI_VERSION} "
            "this check's hash derivation was read out of. The algorithm lives in "
            "lib/deploy/functions/cache/hash.js and lib/deploy/functions/"
            "prepareFunctionsUpload.js — re-read them and re-pin before trusting a result.")
    if version != VERIFIED_CLI_VERSION:
        return [f"note: firebase-tools {version}; derivation verified against "
                f"{VERIFIED_CLI_VERSION} (same major)"]
    return []


# The four load-bearing shapes of the derivation, as they appear in the vendor's
# own source. A version pin catches a MAJOR rewrite; this catches the case a pin
# cannot — the algorithm moving inside a version range we still accept.
#
# `rules_drift.py` reads the installed CLI at runtime for the same reason ("so
# that a firebase-tools upgrade which rotates or moves them produces a clear
# error instead of a silent 401"). Here the failure mode is worse than a 401: a
# tool that computes confident nonsense and calls production drifted.
VENDOR_SHAPES = [
    ("lib/deploy/functions/cache/hash.js",
     r"getEndpointHash[\s\S]{0,200}?\[\s*sourceHash\s*,\s*envHash\s*,\s*secretsHash\s*\]"
     r"[\s\S]{0,120}?\.join\(\s*\"\"\s*\)",
     "getEndpointHash still joins [sourceHash, envHash, secretsHash]"),
    ("lib/deploy/functions/cache/hash.js",
     r"createHash\([\s\S]{0,80}?algorithm\s*=\s*\"sha1\"",
     "the digest is still sha1"),
    ("lib/deploy/functions/prepareFunctionsUpload.js",
     r"createHash\(\"sha1\"\)\s*\.update\(\s*hashes\.sort\(\)\.join\(\"\"\)\s*\)",
     "sourceHash is still sha1 over the SORTED per-file hashes"),
    ("lib/functions/secrets.js",
     r"getSecretVersions[\s\S]{0,300}?memo\[secret\]\s*=\s*version\s*\|\|\s*\"\"",
     "getSecretVersions still maps {secret: version}"),
]


def assert_vendor_derivation(firebase_tools_root: str) -> list[str]:
    """Fail closed if the installed CLI no longer computes hashes the way this
    tool transcribes. Exit 2, never a wrong answer stated confidently."""
    notes: list[str] = []
    for rel, pattern, claim in VENDOR_SHAPES:
        path = os.path.join(firebase_tools_root, rel)
        try:
            text = pathlib.Path(path).read_text()
        except OSError as exc:
            raise MeasurementError(
                f"cannot read the installed firebase-tools at {rel} ({exc.strerror}) — this "
                "check verifies its hash derivation against the vendor's source before "
                "trusting a comparison") from None
        if not re.search(pattern, text):
            raise MeasurementError(
                f"the installed firebase-tools no longer matches the derivation this check "
                f"transcribed: {claim} — not found in {rel}. Re-read that file and re-pin "
                "before trusting any result; a hash computed from a stale transcription "
                "would report drift that is not drift.")
        notes.append(f"  vendor check: {claim}")
    return notes


def find_firebase_tools_root(firebase_bin: str) -> str:
    """Locate the INSTALLED firebase-tools package (the authority on the algorithm)."""
    import shutil

    candidates: list[str] = []
    try:
        root = subprocess.run(["npm", "root", "-g"], capture_output=True, text=True,
                              timeout=60, check=False).stdout.strip()
        if root:
            candidates.append(os.path.join(root, "firebase-tools"))
    except (OSError, subprocess.SubprocessError):
        pass
    exe = shutil.which(firebase_bin)
    if exe:
        base = os.path.dirname(os.path.dirname(os.path.realpath(exe)))
        candidates.append(os.path.join(base, "lib", "node_modules", "firebase-tools"))
        candidates.append(base)
    for candidate in candidates:
        if os.path.isfile(os.path.join(candidate, "lib", "deploy", "functions", "cache", "hash.js")):
            return candidate
    raise MeasurementError(
        "could not locate the installed firebase-tools package. This check reads its hash "
        "derivation out of the vendor's own source rather than trusting a transcription, "
        "and will not proceed without it.")


def run_listing(project: str, firebase_bin: str, cwd: str) -> dict:
    try:
        out = subprocess.run(
            [firebase_bin, "functions:list", "--project", project, "--json"],
            capture_output=True, text=True, timeout=300, check=False, cwd=cwd)
    except FileNotFoundError:
        raise MeasurementError(f"`{firebase_bin}` is not installed") from None
    except (OSError, subprocess.SubprocessError) as exc:
        raise MeasurementError(f"`{firebase_bin} functions:list` failed: {exc}") from None
    if not out.stdout.strip():
        # An empty result is UNVERIFIED, not "no functions" (lesson 65).
        raise MeasurementError(
            f"`{firebase_bin} functions:list --project {project} --json` printed nothing "
            f"(exit {out.returncode}) — that is an unverified read, not an empty project")
    try:
        return json.loads(out.stdout)
    except json.JSONDecodeError:
        raise MeasurementError(
            f"`functions:list --json` for {project} did not return JSON — first line: "
            f"{out.stdout.strip().splitlines()[0][:160]}") from None


def parse_listing(payload: dict, project: str, codebase: str) -> dict[str, dict]:
    """Deployed functions by id. Fails closed on every shape it did not verify."""
    if not isinstance(payload, dict):
        raise MeasurementError(f"functions:list for {project} returned {type(payload).__name__}, not an object")
    status = payload.get("status")
    if status != "success":
        raise MeasurementError(
            f"functions:list for {project} reported status={status!r}: "
            f"{payload.get('error') or '(no error text)'}")
    result = payload.get("result")
    if not isinstance(result, list):
        raise MeasurementError(f"functions:list for {project} returned no `result` array")

    deployed: dict[str, dict] = {}
    for fn in result:
        if not isinstance(fn, dict) or not fn.get("id"):
            raise MeasurementError(f"functions:list for {project} returned an entry with no id: {fn!r}")
        fid = fn["id"]
        if fn.get("codebase") not in (None, codebase):
            raise MeasurementError(
                f"{project}/{fid} belongs to codebase {fn.get('codebase')!r}, not {codebase!r} — "
                "a second codebase has its own source directory and its own hash; failing "
                "closed rather than comparing it against the wrong tree")
        if fn.get("platform") != "gcfv2":
            raise MeasurementError(
                f"{project}/{fid} is platform {fn.get('platform')!r}. The hash derivation this "
                "check implements is the gcfv2 one; gcfv1 takes functionsSourceV1Hash and can "
                "fold a runtimeConfig hash into the source component "
                "(applyHash.js: `isV2 ? sourceV2Hash : sourceV1Hash`), and is out of contract")
        if (fn.get("eventTrigger") or {}).get("dataConnectGraphqlTrigger") or \
                fn.get("dataConnectGraphqlTrigger"):
            # prepare.js feeds schemaFilePath into packageSource as an
            # `additionalSources` entry, whose per-file hash joins the source
            # digest from OUTSIDE functions/. This tool walks functions/ only.
            raise MeasurementError(
                f"{project}/{fid} is DataConnect-triggered. The CLI folds its GraphQL schema "
                "file — which lives outside the functions source directory — into the source "
                "digest, and this check does not walk it. Failing closed rather than "
                "reporting drift that is only a missing input")
        if fid in deployed:
            raise MeasurementError(f"{project} lists {fid} twice — this check compares one region per function")
        deployed[fid] = fn
    return deployed


# --------------------------------------------------------------------------
# the environment reconstruction
# --------------------------------------------------------------------------


def env_file_candidates(source_dir: str, project: str, firebaserc_path: str) -> list[str]:
    """The dotenv files `findEnvfiles` would consider for `project`.

    Every alias in `.firebaserc` that maps to this project is included, because
    the tool cannot know which spelling the deploy used — and a candidate that
    exists is a reason to stop, not to choose.
    """
    names = [".env", f".env.{project}"]
    try:
        rc = json.loads(pathlib.Path(firebaserc_path).read_text())
        for alias, target in (rc.get("projects") or {}).items():
            if target == project:
                names.append(f".env.{alias}")
    except OSError:
        pass
    except json.JSONDecodeError as exc:
        raise MeasurementError(f"{firebaserc_path} is not valid JSON: {exc}") from None
    return [os.path.join(source_dir, n) for n in names if os.path.exists(os.path.join(source_dir, n))]


def load_user_envs(source_dir: str, project: str, firebaserc_path: str) -> dict[str, str]:
    """`loadUserEnvs` — but this check refuses rather than reimplements.

    firebase-tools parses dotenv with its own strict parser (quoting, escapes,
    multi-line values, reserved-key rejection). Reimplementing it would put a
    parser nothing validates on the critical path of a hash comparison, and a
    parser that is subtly wrong produces a false RED that reads exactly like
    real drift. No dotenv binds for either project today, so the honest move is
    to fail closed the day one appears (ADR-043 D4).
    """
    present = env_file_candidates(source_dir, project, firebaserc_path)
    if present:
        raise MeasurementError(
            "these dotenv files bind for " + project + " and participate in the deployed "
            "hash: " + ", ".join(os.path.basename(p) for p in present) + ". This check "
            "deliberately does not reimplement firebase-tools' strict dotenv parser — a "
            "subtly wrong one would produce a false RED indistinguishable from real drift. "
            "Extend `load_user_envs` (and its self-tests) before relying on this result.")
    return {}


def deployed_firebase_config(fn: dict, project: str) -> str:
    env = fn.get("environmentVariables")
    if not isinstance(env, dict) or not env.get("FIREBASE_CONFIG"):
        raise MeasurementError(
            f"{project}/{fn.get('id')} carries no FIREBASE_CONFIG in its environment. "
            "That string is an input to the deployed hash and cannot be derived from this "
            "repository, so the comparison would be against a value this check invented")
    return env["FIREBASE_CONFIG"]


# --------------------------------------------------------------------------
# comparison
# --------------------------------------------------------------------------


def compare_project(project: str, deployed: dict[str, dict], exported: list[str],
                    part: Partition, source_dir: str, firebaserc_path: str
                    ) -> tuple[bool, list[str], str]:
    """(matches, report lines, one-line summary). Raises if it could not look."""
    lines: list[str] = []
    drifted = False

    if not deployed and exported:
        # Lesson 65: an empty result is UNVERIFIED, not negative. Zero deployed
        # functions on a project this ref expects functions on is EITHER maximal
        # drift OR a credential that can reach the API but cannot see them. Both
        # are red; reporting the wrong one sends the next reader to the wrong
        # place, so the tool reports that it could not tell.
        raise MeasurementError(
            f"{project} lists ZERO deployed functions while this ref exports {len(exported)}. "
            "That is either a project with nothing deployed (maximal drift) or a credential "
            "that can call the API but cannot see the functions. This check cannot tell those "
            "apart from the listing alone and will not report the wrong one — confirm with "
            f"`firebase functions:list --project {project}` under a credential you trust")

    # --- verdict 1: the set comparison (no hashing, no build) ---------------
    missing = sorted(set(exported) - set(deployed))
    extra = sorted(set(deployed) - set(exported))
    lines.append(f"  deployed     : {len(deployed)} function(s); this ref exports {len(exported)}")
    if missing:
        drifted = True
        lines.append(f"  DRIFT: exported but NOT DEPLOYED — {', '.join(missing)}")
        lines.append("         the app calls these and they do not exist. This is the S063 shape.")
    if extra:
        drifted = True
        lines.append(f"  DRIFT: deployed but not exported by this ref — {', '.join(extra)}")

    inactive = sorted(fid for fid, fn in deployed.items() if fn.get("state") not in (None, "ACTIVE"))
    if inactive:
        drifted = True
        for fid in inactive:
            lines.append(f"  DRIFT: {fid} is state={deployed[fid].get('state')}, not ACTIVE")

    # --- verdict 2: the hash comparison -------------------------------------
    user_envs = load_user_envs(source_dir, project, firebaserc_path)
    ref_src = source_hash(part.reference)
    work_src = source_hash(part.packaged)
    lines.append(f"  reference    : {ref_src[:16]}…  ({len(part.reference)} files: "
                 f"{len(part.tracked)} tracked + {len(part.build)} built)")
    if part.foreign:
        lines.append(f"  working tree : {work_src[:16]}…  (+{len(part.foreign)} foreign files "
                     "that a clean checkout does not have)")

    mismatched: list[str] = []
    hand_deployed: list[str] = []
    for fid in sorted(deployed):
        fn = deployed[fid]
        stamped = fn.get("hash") or (fn.get("labels") or {}).get("firebase-functions-hash")
        if not stamped:
            # Deployed by a CLI that predates the label, or by something else
            # entirely. Absence is UNVERIFIED, not "matches" (lesson 65).
            raise MeasurementError(
                f"{project}/{fid} carries no firebase-functions-hash. Nothing can be "
                "concluded about its source — this is an unmeasurable function, not a "
                "matching one")
        env = env_hash(user_envs, deployed_firebase_config(fn, project), project)
        secrets = secrets_hash(fn.get("secretEnvironmentVariables"))
        if endpoint_hash(ref_src, env, secrets) == stamped:
            continue
        if endpoint_hash(work_src, env, secrets) == stamped:
            hand_deployed.append(fid)
        else:
            mismatched.append(fid)

    if hand_deployed:
        drifted = True
        lines.append(
            f"  DRIFT: {len(hand_deployed)} function(s) match THIS WORKING DIRECTORY but not a "
            "clean checkout of this ref:")
        lines.append(f"         {', '.join(hand_deployed)}")
        lines.append("         Their source is this ref's source. They were deployed by hand from a "
                     "tree carrying")
        lines.append(f"         {len(part.foreign)} file(s) a clean checkout does not have, e.g. "
                     + ", ".join(os.path.relpath(p) for p in part.foreign[:3])
                     + (f" (+{len(part.foreign) - 3} more)" if len(part.foreign) > 3 else ""))
        lines.append("         This is a PROCESS gap, not wrong code running in production.")
    if mismatched:
        drifted = True
        lines.append(f"  DRIFT: {len(mismatched)} function(s) are running source that is NOT this ref:")
        lines.append(f"         {', '.join(mismatched)}")
        lines.append("         The working tree does not explain it either. Deploy this ref, or find "
                     "out what is running.")

    if not drifted:
        lines.append(f"  MATCHES: all {len(deployed)} deployed function(s) are a clean build of this ref")
        return True, lines, ""

    # The one-line summary the CI annotation carries. Ordered worst-first so the
    # annotation names the most serious finding, not the first one found.
    if mismatched:
        why = (f"{len(mismatched)} function(s) run source that is NOT this ref "
               f"({', '.join(mismatched)})")
    elif missing:
        why = (f"{len(missing)} function(s) this ref exports are NOT DEPLOYED "
               f"({', '.join(missing)}) — every deployed function's source matches")
    elif extra:
        why = f"{len(extra)} deployed function(s) are not exported by this ref ({', '.join(extra)})"
    elif inactive:
        why = f"{len(inactive)} function(s) are not ACTIVE ({', '.join(inactive)})"
    else:
        why = (f"{len(hand_deployed)} function(s) run THIS REF'S SOURCE but were deployed "
               f"from a dirty tree ({len(part.foreign)} foreign files) — a process gap, "
               "not wrong code")
    return False, lines, why


# --------------------------------------------------------------------------


def main(argv: list[str] | None = None, listing_loader=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--project", action="append", default=[], help="project id; repeatable")
    parser.add_argument("--root", default=None, help="repo root (default: this file's ../..)")
    parser.add_argument("--firebase-bin", default="firebase")
    parser.add_argument("--skip-version-check", action="store_true",
                        help="self-tests only: the derivation is pinned to a CLI major")
    args = parser.parse_args(argv)

    if not args.project:
        print("::error::functions_drift: no --project given")
        return EXIT_CANNOT_MEASURE

    repo_root = args.root or os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    loader = listing_loader or (lambda project: run_listing(project, args.firebase_bin, repo_root))

    try:
        if not args.skip_version_check:
            for note in assert_supported_cli(cli_version(args.firebase_bin)):
                print(note)
            # A version pin catches a MAJOR rewrite. This catches what a pin
            # cannot: the algorithm moving inside a range we still accept.
            assert_vendor_derivation(find_firebase_tools_root(args.firebase_bin))
        source_rel, codebase, patterns = read_functions_config(os.path.join(repo_root, "firebase.json"))
        source_dir = os.path.join(repo_root, source_rel)
        build_dir = build_output_dir(source_dir)
        if not os.path.isdir(build_dir):
            raise MeasurementError(
                f"{os.path.relpath(build_dir, repo_root)} does not exist — the deployed source "
                "contains the COMPILED output, so nothing can be compared until `npm run build` "
                "has run in " + source_rel)
        exported = parse_barrel(os.path.join(source_dir, "src", "index.ts"))
        tracked = git_tracked(source_rel, repo_root)
        missing_on_disk = sorted(p for p in tracked if not os.path.exists(p))
        if missing_on_disk:
            raise MeasurementError(
                f"{len(missing_on_disk)} file(s) tracked under {source_rel} are absent from disk "
                f"(e.g. {os.path.relpath(missing_on_disk[0], repo_root)}) — the reference set is "
                "what a CLEAN checkout carries, and this tree cannot produce it")
        part = Partition(walk_packaged(source_dir, patterns), tracked, build_dir)
        dirty = git_dirty(source_rel, repo_root)
        firebaserc = os.path.join(repo_root, ".firebaserc")
    except MeasurementError as exc:
        print(f"::error::functions_drift could not measure: {exc}")
        return EXIT_CANNOT_MEASURE

    print(f"exports in {source_rel}/src/index.ts: {len(exported)} "
          f"({', '.join(exported)})")
    print(f"packaged from {source_rel}/: {len(part.packaged)} files "
          f"= {len(part.tracked)} tracked + {len(part.build)} built + {len(part.foreign)} foreign")
    if dirty:
        print(f"note: {len(dirty)} tracked file(s) under {source_rel} differ from HEAD, so the "
              "reference below is this WORKING COPY of them, not HEAD's")

    drifted: list[tuple[str, str]] = []
    for project in args.project:
        print(f"\n=== {project} ===")
        try:
            listing = loader(project)
            deployed = parse_listing(listing, project, codebase)
            matches, lines, why = compare_project(project, deployed, exported, part,
                                                  source_dir, firebaserc)
        except MeasurementError as exc:
            print(f"  {exc}")
            print(f"::error::functions_drift could not measure {project}: {exc}")
            return EXIT_CANNOT_MEASURE
        for line in lines:
            print(line)
        if not matches:
            drifted.append((project, why))

    print()
    if drifted:
        for project, why in drifted:
            # Say what actually drifted. "not a clean build" over a project whose
            # every deployed function matches, and whose only finding is a
            # function that is absent, sends the reader to redeploy code that is
            # already correct.
            print(f"::error::{project}: {why}. Cloud Functions have no deploy lane "
                  "(#166's residual, re-filed), so this is a manual `firebase deploy "
                  "--only functions`" + ("" if project.endswith("-dev") else
                  " — and a PROD deploy is a founder ask (session-context.md §7)") + ".")
        return EXIT_DRIFT
    print(f"no drift: {len(args.project)} project(s) run a clean build of this ref "
          f"({', '.join(args.project)})")
    return EXIT_OK


if __name__ == "__main__":
    raise SystemExit(main())
