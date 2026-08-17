#!/usr/bin/env python3
"""Self-tests for tool/gen_bidi_rtl_ranges.py (repo convention: every tool under
tool/ carries one, run by ci.yml's quality job).

Hermetic: no network, no Dart, no repo write. Every test drives a pure function
or a temp-tree copy, so this sits with the other pre-`pub get` self-tests.

WHAT THESE GUARD, AND WHY EACH ONE EXISTS RATHER THAN "the script runs":

  * `test_check_is_green_on_the_committed_table` is the ONLY test here that
    touches the real repo file, and it is the point of the whole tool — but on
    its own it is worthless, because a `check()` that returned 0 unconditionally
    would pass it. So every guard below is asserted in BOTH directions.

  * `test_unicode_bump_and_hand_edit_print_DIFFERENT_things`. The two ways
    `--check` fails are not the same problem: a stale table is somebody's
    mistake, a Unicode version bump is news. If they printed the same sentence,
    the first Python upgrade would read as corruption and somebody would "fix"
    a correct table. This is the tool's actual diagnostic value and it is the
    thing most likely to rot, because nobody exercises it until it fires — the
    `dispatch-only workflow` shape, one level down.

  * `test_emitted_lines_fit_dart_format`. Two CI gates read this file:
    `dart format --set-exit-if-changed` and `--check`. If the generator emits
    something dart format would reflow, they contradict each other permanently
    and NO edit satisfies both. That trap was hit for real while writing this
    (a 90-character Unicode name), so it is pinned.

  * `test_ranges_coalesces_and_does_not_merge_across_gaps`. The range coalescer
    is where an off-by-one silently swallows a code point that belongs to
    neither class — a wrong answer at a render seam, invisible to review.

Run: python3 tool/gen_bidi_rtl_ranges_test.py
"""

from __future__ import annotations

import importlib.util
import io
import contextlib
import pathlib
import shutil
import sys
import tempfile
import unicodedata

_MODULE_PATH = pathlib.Path(__file__).with_name("gen_bidi_rtl_ranges.py")
_spec = importlib.util.spec_from_file_location("gen_bidi", _MODULE_PATH)
assert _spec is not None and _spec.loader is not None
gen = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(gen)

_REPO_ROOT = _MODULE_PATH.parent.parent

_failures: list[str] = []


def check(label: str, actual: object, expected: object) -> None:
    if actual == expected:
        print(f"  ok   {label}")
    else:
        print(f"  FAIL {label}\n         expected: {expected!r}\n         actual:   {actual!r}")
        _failures.append(label)


def check_in(label: str, needle: str, haystack: str) -> None:
    if needle.lower() in haystack.lower():
        print(f"  ok   {label}")
    else:
        print(f"  FAIL {label}\n         wanted {needle!r} in: {haystack[:400]!r}")
        _failures.append(label)


def check_not_in(label: str, needle: str, haystack: str) -> None:
    if needle.lower() not in haystack.lower():
        print(f"  ok   {label}")
    else:
        print(f"  FAIL {label}\n         {needle!r} present in: {haystack[:400]!r}")
        _failures.append(label)


@contextlib.contextmanager
def _sandbox(contents: str | None):
    """Run `gen` against a throwaway OUT path holding `contents` (None = absent)."""
    original = gen.OUT
    tmp = pathlib.Path(tempfile.mkdtemp())
    try:
        out = tmp / "strong_bidi_ranges.dart"
        if contents is not None:
            out.write_text(contents)
        gen.OUT = str(out)
        yield out
    finally:
        gen.OUT = original
        shutil.rmtree(tmp, ignore_errors=True)


def _run_check() -> tuple[int, str]:
    """`check()` against the current gen.OUT, returning (exit code, stderr)."""
    err = io.StringIO()
    text = gen.render(gen.ranges(("R", "AL")), gen.ranges(("L",)))
    with contextlib.redirect_stderr(err), contextlib.redirect_stdout(io.StringIO()):
        code = gen.check(text)
    return code, err.getvalue()


# --------------------------------------------------------------------------
# the tables themselves


def test_ranges_coalesces_and_does_not_merge_across_gaps() -> None:
    rtl = gen.ranges(("R", "AL"))
    check("ranges are ordered and disjoint", True,
          all(rtl[i][0] > rtl[i - 1][1] for i in range(1, len(rtl))))
    check("no range is inverted", True, all(a <= b for a, b in rtl))
    # A coalescer that merged across a gap would produce FEWER, WIDER ranges and
    # silently claim code points that are not strong-RTL. Spot-check the exact
    # boundary: U+05BE is strong-RTL, U+05BF is NSM (weak) — they must not join.
    check("U+05BE is R/AL", unicodedata.bidirectional("־"), "R")
    check("U+05BF is NOT strong", unicodedata.bidirectional("ֿ"), "NSM")
    check("the two are not coalesced", True, (0x05BE, 0x05BE) in rtl)
    # The count is asserted so a generator that quietly emitted an EMPTY table —
    # the greenest possible input to every other check here — cannot pass.
    total = sum(b - a + 1 for a, b in rtl)
    check("strong-RTL code point count", total, 2962)


def test_the_two_classes_never_overlap() -> None:
    rtl = set()
    for a, b in gen.ranges(("R", "AL")):
        rtl.update(range(a, b + 1))
    ltr = set()
    for a, b in gen.ranges(("L",)):
        ltr.update(range(a, b + 1))
    # Disjointness is what makes `firstStrongDirection` order-independent. It is
    # asserted in the Dart suite too; here it guards the GENERATOR, so a bad
    # class tuple cannot produce a table the Dart test then blesses.
    check("R/AL and L are disjoint", rtl & ltr, set())
    check("L is non-empty", True, len(ltr) > 100000)


# --------------------------------------------------------------------------
# the emitted text


def test_emitted_lines_fit_dart_format() -> None:
    text = gen.render(gen.ranges(("R", "AL")), gen.ranges(("L",)))
    over = [line for line in text.split("\n") if len(line) > gen.LINE_LIMIT]
    check("no emitted line exceeds dart format's column limit", over, [])
    # The truncation must not be silent about itself.
    long_name = [line for line in text.split("\n") if line.endswith("…")]
    check("over-long Unicode names are elided, not dropped", True, len(long_name) >= 1)


def test_uncommented_table_is_one_value_per_line() -> None:
    # dart format splits an uncommented element list one-per-line. If the
    # generator emitted pairs instead, `dart format --set-exit-if-changed` would
    # rewrite the file and `--check` would then call the rewrite stale, forever.
    body = gen.table("t", [(0x41, 0x5A), (0x61, 0x7A)], comment=False)
    check("no comment -> one value per line", body,
          "const List<int> t = <int>[\n  0x0041,\n  0x005A,\n  0x0061,\n  0x007A,\n];\n")


def test_commented_table_keeps_pairs_on_one_line() -> None:
    body = gen.table("t", [(0x05BE, 0x05BE)], comment=True)
    check("comment -> pair stays on one line", body,
          "const List<int> t = <int>[\n"
          "  0x05BE, 0x05BE, // HEBREW PUNCTUATION MAQAF\n];\n")


def test_header_records_the_unicode_version() -> None:
    text = gen.render([(1, 2)], [(3, 4)])
    check_in("header names the Unicode version",
             f"// Unicode {unicodedata.unidata_version}.", text)
    check("and it round-trips back out",
          gen.committed_unicode_version(text), unicodedata.unidata_version)
    check("a file with no version header reads as None",
          gen.committed_unicode_version("// nothing here\n"), None)


# --------------------------------------------------------------------------
# --check, in both directions


def test_check_is_green_on_a_freshly_written_file() -> None:
    with _sandbox(None) as out:
        with contextlib.redirect_stdout(io.StringIO()):
            gen.main()
        check("generator wrote the file", out.exists(), True)
        code, _ = _run_check()
        check("--check exits 0 on its own output", code, 0)


def test_check_fails_on_a_missing_file() -> None:
    with _sandbox(None):
        code, err = _run_check()
        check("--check exits 1 when the table is absent", code, 1)
        check_in("and says it is missing", "missing", err)


def test_unicode_bump_and_hand_edit_print_DIFFERENT_things() -> None:
    real = gen.render(gen.ranges(("R", "AL")), gen.ranges(("L",)))

    # (a) HAND EDIT: same Unicode version, different bytes.
    with _sandbox(real.replace("0x05BE, 0x05BE,", "0x05BE, 0x05BF,", 1)):
        code, edited_err = _run_check()
        check("hand edit exits 1", code, 1)
        check_in("named as not-a-bump", "not a unicode bump", edited_err)
        check_in("and points at the generator", "regenerate", edited_err)

    # (b) UNICODE BUMP: the header claims a version this interpreter is not on.
    bumped = real.replace(f"// Unicode {unicodedata.unidata_version}.",
                          "// Unicode 1.0.0.", 1)
    with _sandbox(bumped):
        code, bump_err = _run_check()
        check("version mismatch exits 1", code, 1)
        check_in("named as a Unicode move", "unicode moved", bump_err)
        check_in("says it is not a defect", "not a defect", bump_err)
        check_in("names the committed version", "1.0.0", bump_err)
        check_in("names the interpreter's version", unicodedata.unidata_version, bump_err)

    # THE ASSERTION THAT MATTERS: the two diagnoses are not the same sentence.
    # If they ever converge, the next Python upgrade reads as corruption.
    check("the two failures are distinguishable", True, bump_err != edited_err)
    check_not_in("a bump is never called a hand edit", "edited by hand", bump_err)


def test_check_is_green_on_the_committed_table() -> None:
    # The one test that reads the real repo file. It proves the committed table
    # is current NOW; on its own it proves nothing about the tool, which is why
    # every check above exists.
    original = gen.OUT
    try:
        gen.OUT = str(_REPO_ROOT / "app/lib/core/l10n/strong_bidi_ranges.dart")
        code, err = _run_check()
        check("the committed table matches its generator", code, 0)
        if code != 0:
            print(f"         {err}")
    finally:
        gen.OUT = original


def main() -> int:
    for fn in (
        test_ranges_coalesces_and_does_not_merge_across_gaps,
        test_the_two_classes_never_overlap,
        test_emitted_lines_fit_dart_format,
        test_uncommented_table_is_one_value_per_line,
        test_commented_table_keeps_pairs_on_one_line,
        test_header_records_the_unicode_version,
        test_check_is_green_on_a_freshly_written_file,
        test_check_fails_on_a_missing_file,
        test_unicode_bump_and_hand_edit_print_DIFFERENT_things,
        test_check_is_green_on_the_committed_table,
    ):
        print(f"\n{fn.__name__}")
        fn()
    print()
    if _failures:
        print(f"FAILED: {len(_failures)} check(s): {', '.join(_failures)}")
        return 1
    print("all checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
