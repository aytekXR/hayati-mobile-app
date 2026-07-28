#!/usr/bin/env python3
"""Self-tests for tool/ci/build_site.py (repo convention: every tool under
tool/ carries one, run by ci.yml's quality job).

Hermetic: no network, no Firebase, no emulator. Builds into a temp dir from
synthetic Markdown, so it tests the GENERATOR rather than today's copy — a test
whose fixture is the real legal text would go green the moment someone reworded
it, and would never exercise the table path at all (the only table in
docs/legal/ lives in README.md, which is not published).

The load-bearing properties, each asserted in both directions:
  * the placeholder gate FAILS the build, and passes when the text is clean;
  * legal prose is never silently DROPPED — an unrecognised line still reaches
    the output as a paragraph;
  * `[SOMETHING — to be completed]` survives as literal text, because link
    syntax is deliberately not implemented;
  * a raw `<` in prose is escaped, not turned into markup.

Run: python3 tool/ci/build_site_test.py
"""

from __future__ import annotations

import importlib.util
import json
import pathlib
import tempfile

_MODULE_PATH = pathlib.Path(__file__).with_name("build_site.py")
_spec = importlib.util.spec_from_file_location("build_site", _MODULE_PATH)
assert _spec is not None and _spec.loader is not None
bs = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(bs)

_failures: list[str] = []


def check(label: str, actual: object, expected: object) -> None:
    if actual == expected:
        print(f"  ok   {label}")
    else:
        print(f"  FAIL {label}\n         expected: {expected!r}\n         actual:   {actual!r}")
        _failures.append(label)


def _write_legal(root: pathlib.Path, body: str) -> pathlib.Path:
    d = root / "legal"
    d.mkdir(parents=True, exist_ok=True)
    for stem in ("privacy-policy", "terms"):
        for loc in ("en", "tr", "ar"):
            (d / f"{stem}.{loc}.md").write_text(body, encoding="utf-8")
    return d


CLEAN = "# Title\n\nA sentence.\n\n## Section\n\n- one\n- two\n"


# --------------------------------------------------------------------------
# The Markdown subset.
# --------------------------------------------------------------------------

def test_markdown_subset() -> None:
    h = bs.markdown_to_html("# H1\n\n## H2\n\n### H3\n")
    check("h1", "<h1>H1</h1>" in h, True)
    check("h2", "<h2>H2</h2>" in h, True)
    check("h3", "<h3>H3</h3>" in h, True)

    h = bs.markdown_to_html("- a\n- b\n")
    check("unordered list", h, "<ul><li>a</li><li>b</li></ul>")

    h = bs.markdown_to_html("1. a\n2. b\n")
    check("ordered list", h, "<ol><li>a</li><li>b</li></ol>")

    h = bs.markdown_to_html("**bold** and _em_ and `code`")
    check("bold", "<strong>bold</strong>" in h, True)
    check("italic", "<em>em</em>" in h, True)
    check("code", "<code>code</code>" in h, True)


def test_table_path_is_exercised() -> None:
    """The only table in docs/legal/ is in README.md, which is NOT published —
    so without this test the table branch would ship unexercised."""
    h = bs.markdown_to_html("| A | B |\n| --- | --- |\n| 1 | 2 |\n")
    check("table head", "<th>A</th><th>B</th>" in h, True)
    check("table body", "<td>1</td><td>2</td>" in h, True)
    check("separator row is not a data row", "<td>---</td>" in h, False)


def test_prose_is_never_dropped() -> None:
    """build_site's docstring claims an unrecognised line becomes a paragraph.
    That claim is what stops a legal sentence vanishing from a published policy,
    so it gets a test rather than a comment."""
    weird = "   >>> not a construct this parser knows <<<"
    h = bs.markdown_to_html(weird)
    check("unknown line survives", "not a construct this parser knows" in h, True)
    check("as a paragraph", h.startswith("<p>"), True)


def test_html_in_prose_is_escaped() -> None:
    h = bs.markdown_to_html("we store <b>nothing</b> extra & mean it")
    check("angle brackets escaped", "&lt;b&gt;" in h, True)
    check("no live markup injected", "<b>" in h, False)
    check("ampersand escaped", "&amp;" in h, True)


def test_link_syntax_is_not_implemented() -> None:
    """Deliberate: the corpus has ZERO links but DOES have
    `[FOUNDER LEGAL ENTITY — to be completed by the founder]`. A link parser
    would swallow that into an anchor and hide an unfilled blank."""
    h = bs.markdown_to_html("operated by [FOUNDER LEGAL ENTITY — to be completed by the founder].")
    check("no anchor emitted", "<a " in h, False)
    check("placeholder still visible as text", "FOUNDER LEGAL ENTITY" in h, True)


# --------------------------------------------------------------------------
# The placeholder gate — both directions.
# --------------------------------------------------------------------------

def test_placeholder_gate_fails_the_build() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        root = pathlib.Path(tmp)
        legal = _write_legal(root, CLEAN + "\nRun by [ENTITY — to be completed by the founder].\n")
        rc = bs.build(root / "out", legal, allow_placeholders=False)
        check("a placeholder FAILS the build", rc, 1)
        rc = bs.build(root / "out2", legal, allow_placeholders=True)
        check("--allow-placeholders builds anyway", rc, 0)


def test_clean_text_passes_without_the_flag() -> None:
    """The other direction. Without this, a gate that always failed would look
    identical to a gate that works."""
    with tempfile.TemporaryDirectory() as tmp:
        root = pathlib.Path(tmp)
        legal = _write_legal(root, CLEAN)
        check("clean legal text needs no flag", bs.build(root / "out", legal, False), 0)


def test_missing_source_is_an_error_not_an_empty_page() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        root = pathlib.Path(tmp)
        legal = root / "legal"
        legal.mkdir()
        (legal / "privacy-policy.en.md").write_text(CLEAN, encoding="utf-8")
        try:
            bs.build(root / "out", legal, False)
        except bs.BuildError as exc:
            check("a missing locale raises", "missing legal source" in str(exc), True)
            return
        check("a missing locale raises", False, True)


# --------------------------------------------------------------------------
# Output shape.
# --------------------------------------------------------------------------

def test_routes_and_rtl() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        root = pathlib.Path(tmp)
        legal = _write_legal(root, CLEAN)
        out = root / "out"
        bs.build(out, legal, False)
        for rel in ("index.html", "404.html", "invite.html",
                    "privacy/index.html", "privacy/tr/index.html", "privacy/ar/index.html",
                    "terms/index.html", "terms/tr/index.html", "terms/ar/index.html",
                    ".well-known/apple-app-site-association"):
            check(f"route exists: {rel}", (out / rel).exists(), True)
        ar = (out / "privacy/ar/index.html").read_text(encoding="utf-8")
        check("arabic page is dir=rtl", 'dir="rtl"' in ar, True)
        en = (out / "privacy/index.html").read_text(encoding="utf-8")
        check("english page is dir=ltr", 'dir="ltr"' in en, True)


def test_aasa_is_valid_and_points_at_the_real_app() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        root = pathlib.Path(tmp)
        legal = _write_legal(root, CLEAN)
        out = root / "out"
        bs.build(out, legal, False)
        aasa = json.loads((out / ".well-known/apple-app-site-association").read_text())
        details = aasa["applinks"]["details"]
        check("one app entry", len(details), 1)
        # ADR-027: the bundle id stays com.beyondkaira.hayati after the rename.
        check("appID is team.bundle",
              details[0]["appIDs"], ["UH7MXG7Z94.com.beyondkaira.hayati"])
        check("claims the invite path only",
              [c["/"] for c in details[0]["components"]], ["/i/*"])
        check("no file extension (Apple requires none)",
              (out / ".well-known/apple-app-site-association.json").exists(), False)


def main() -> int:
    print("build_site self-tests")
    for fn in (
        test_markdown_subset,
        test_table_path_is_exercised,
        test_prose_is_never_dropped,
        test_html_in_prose_is_escaped,
        test_link_syntax_is_not_implemented,
        test_placeholder_gate_fails_the_build,
        test_clean_text_passes_without_the_flag,
        test_missing_source_is_an_error_not_an_empty_page,
        test_routes_and_rtl,
        test_aasa_is_valid_and_points_at_the_real_app,
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
    raise SystemExit(main())
