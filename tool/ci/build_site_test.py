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

SITE_BODY = "# Page\n\nSome copy.\n"


def _write_site(root: pathlib.Path, body: str = SITE_BODY) -> pathlib.Path:
    d = root / "site"
    d.mkdir(parents=True, exist_ok=True)
    for stem in ("landing", "support"):
        for loc in ("en", "tr", "ar"):
            (d / f"{stem}.{loc}.md").write_text(body, encoding="utf-8")
    return d


def _build(out, legal, allow_placeholders, **kw):
    """Every test builds through here, and the reason is hermeticity.

    `build()` defaults `site_dir` to the REPO's real `docs/site`, which is
    correct in production and wrong in a test: the suite would then read the
    live landing copy and could pass or fail for reasons that have nothing to do
    with the thing under test — and would break the moment a founder edited a
    sentence. Tests that want to exercise the real copy pass `site_dir`
    explicitly and say so.
    """
    out = pathlib.Path(out)
    kw.setdefault("site_dir", _write_site(out.parent))
    return bs.build(out, legal, allow_placeholders, **kw)


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
        rc = _build(root / "out", legal, allow_placeholders=False)
        check("a placeholder FAILS the build", rc, 1)
        rc = _build(root / "out2", legal, allow_placeholders=True)
        check("--allow-placeholders builds anyway", rc, 0)


def test_clean_text_passes_without_the_flag() -> None:
    """The other direction. Without this, a gate that always failed would look
    identical to a gate that works."""
    with tempfile.TemporaryDirectory() as tmp:
        root = pathlib.Path(tmp)
        legal = _write_legal(root, CLEAN)
        check("clean legal text needs no flag", _build(root / "out", legal, False), 0)


def test_placeholder_gate_is_language_independent() -> None:
    """Session 055. The gate used to match two ENGLISH phrases, and was blind to
    four of the six real documents — both Turkish and both Arabic.

    A privacy policy served to this product's PRIMARY market saying
    `[KURUCU/ŞİRKET TÜZEL KİMLİĞİ — kurucu tarafından doldurulacak]` is exactly
    what the gate exists to prevent, and the gate said clean. These are the real
    strings from docs/legal/, not invented ones."""
    real_blanks = {
        "tr-entity": "[KURUCU/ŞİRKET TÜZEL KİMLİĞİ — kurucu tarafından doldurulacak]",
        "tr-contact": "[İLETİŞİM ADRESİ — kurucu tarafından doldurulacak]",
        "tr-law": "[GEÇERLİ HUKUK — kurucunun hukuk danışmanı tarafından belirlenecek]",
        "ar-entity": "[الكيان القانوني للمؤسِّس — يُستكمل من قِبل المؤسِّس]",
        "ar-contact": "[عنوان التواصل — يُستكمل من قِبل المؤسِّس]",
        "ar-law": "[القانون الحاكم — يُحدَّد من قِبل محامي المؤسِّس]",
        "en-entity": "[FOUNDER LEGAL ENTITY — to be completed by the founder]",
        "en-contact": "[CONTACT ADDRESS — to be completed by the founder]",
        # The English blank the OLD rule also missed: "determined", not "completed".
        "en-law": "[GOVERNING LAW — to be determined by the founder's lawyer]",
    }
    for label, blank in real_blanks.items():
        check(f"{label} is detected", bs.check_placeholders("x.md", f"Operated by {blank}."),
              [blank])

    # And each one must actually FAIL a build, not merely be findable.
    with tempfile.TemporaryDirectory() as tmp:
        root = pathlib.Path(tmp)
        legal = _write_legal(root, CLEAN + "\n" + real_blanks["tr-law"] + "\n")
        check("a Turkish-only blank fails the build",
              _build(root / "out", legal, allow_placeholders=False), 1)


def test_placeholder_gate_does_not_cry_wolf() -> None:
    """The other direction, which is the whole reason the old rule was narrow.

    Bracketed prose without an em dash, and em-dashed prose without brackets,
    must both pass — otherwise the fix trades a silent gate for a stuck one."""
    for label, text in (
        ("bracketed prose", "See section [4] and clause [b] of the annex."),
        ("an em dash in prose", "We keep your data — and only your data — in the EU."),
        ("a bracket and a dash on different lines", "See [4]\n\nand — separately — this."),
        ("a filled blank", "ikimiz is operated by Aytek Erdoğan, an individual."),
    ):
        check(f"{label} is NOT a placeholder", bs.check_placeholders("x.md", text), [])

    with tempfile.TemporaryDirectory() as tmp:
        root = pathlib.Path(tmp)
        legal = _write_legal(root, CLEAN + "\nSee clause [4] — it matters.\n")
        check("prose with brackets AND a dash still builds clean",
              _build(root / "out", legal, allow_placeholders=False), 0)


def test_one_blank_is_counted_once() -> None:
    """S053's unit lesson, applied to this tool. The old tuple's second marker
    was a case-insensitive substring of its first, so a single blank reported
    two hits and every count the log printed was doubled."""
    one = "Operated by [FOUNDER LEGAL ENTITY — to be completed by the founder]."
    check("one blank, one hit", len(bs.check_placeholders("x.md", one)), 1)
    twice = one + "\n\n" + one
    check("the same blank twice is still one hit",
          len(bs.check_placeholders("x.md", twice)), 1)
    two_different = one + "\nReach us at [CONTACT ADDRESS — to be completed by the founder]."
    check("two different blanks are two hits",
          len(bs.check_placeholders("x.md", two_different)), 2)


def test_a_blank_without_an_em_dash_is_still_caught() -> None:
    """The belt-and-braces half. The shape rule is the primary net; the phrase
    list catches a blank someone writes without the em dash."""
    check("phrase without brackets",
          bs.check_placeholders("x.md", "Operated by to be completed by the founder."),
          ["to be completed by the founder"])


def test_missing_source_is_an_error_not_an_empty_page() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        root = pathlib.Path(tmp)
        legal = root / "legal"
        legal.mkdir()
        (legal / "privacy-policy.en.md").write_text(CLEAN, encoding="utf-8")
        try:
            _build(root / "out", legal, False)
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
        _build(out, legal, False)
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
        _build(out, legal, False)
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


def test_invite_only_serves_the_link_and_no_legal_text() -> None:
    """--invite-only publishes the invite surface and NOTHING under /privacy.

    Both halves matter. The half that unblocks the product: the invite page and
    the app-site-association file exist, so an invite link resolves and iOS can
    claim it, on a day when a legal document still has a blank in it. The half
    that keeps the gate honest: no legal document is written, so the build is
    not shipping unfinished policy text — it is shipping none.
    """
    with tempfile.TemporaryDirectory() as tmp:
        root = pathlib.Path(tmp)
        # Deliberately UNFILLED legal text: this is the state the flag exists
        # for, and a fixture with clean text would prove nothing.
        legal = _write_legal(root, "# T\n\n[FOUNDER LEGAL ENTITY — to be completed by the founder]\n")
        out = root / "out"
        code = _build(out, legal, False, invite_only=True)

        check("invite-only build succeeds despite the blanks", code, 0)
        check("invite page is served", (out / "invite.html").exists(), True)
        check("aasa is served", (out / ".well-known/apple-app-site-association").exists(), True)
        check("index is served", (out / "index.html").exists(), True)
        check("404 is served", (out / "404.html").exists(), True)

        # The gate's actual rule, asserted as an absence.
        check("no english privacy page", (out / "privacy/index.html").exists(), False)
        check("no turkish privacy page", (out / "privacy/tr/index.html").exists(), False)
        check("no terms page", (out / "terms/index.html").exists(), False)
        check(
            "no unfilled legal text anywhere in the output",
            any(
                "to be completed by the founder" in p.read_text(encoding="utf-8")
                for p in out.rglob("*")
                if p.is_file()
            ),
            False,
        )

        # An index linking to pages this build did not write would hand the
        # invitee a 404 from the site's own navigation.
        index = (out / "index.html").read_text(encoding="utf-8")
        check('index does not link to /privacy', 'href="/privacy"' in index, False)
        check('index does not link to /terms', 'href="/terms"' in index, False)


def test_full_build_still_links_the_legal_pages() -> None:
    """The default build is unchanged — invite-only must not leak into it."""
    with tempfile.TemporaryDirectory() as tmp:
        root = pathlib.Path(tmp)
        legal = _write_legal(root, CLEAN)
        out = root / "out"
        check("clean full build succeeds", _build(out, legal, False), 0)
        index = (out / "index.html").read_text(encoding="utf-8")
        check('index links /privacy', 'href="/privacy"' in index, True)
        check('index links /terms', 'href="/terms"' in index, True)
        check("privacy page written", (out / "privacy/index.html").exists(), True)


def test_invite_page_never_offers_a_dead_app_store_button() -> None:
    """No CTA pointing at an App Store id that does not exist yet.

    The invite page is the ONLY thing most invitees ever see of this product. A
    button that 404s there does not read as "not released yet", it reads as a
    broken product, at the exact moment someone is deciding whether to trust it.
    """
    with tempfile.TemporaryDirectory() as tmp:
        root = pathlib.Path(tmp)
        legal = _write_legal(root, CLEAN)
        out = root / "out"
        _build(out, legal, False, invite_only=True)
        invite = (out / "invite.html").read_text(encoding="utf-8")

        placeholder_is_still_set = not bs.APP_STORE_ID.strip("0")
        check(
            "placeholder id renders honest beta copy, not a link",
            "apps.apple.com" in invite,
            not placeholder_is_still_set,
        )
        if placeholder_is_still_set:
            check("beta copy names the real next step",
                  "TestFlight" in invite, True)
        # Either way the code, and a way to lift it, are always present.
        check("the code element is present", 'id="code"' in invite, True)
        check("a copy affordance is present", 'id="copy"' in invite, True)


# --------------------------------------------------------------------------
# The landing and support pages (S059). The App Store listing declares the SITE
# ROOT as its support URL, and until these existed that URL served a two-line
# stub.
# --------------------------------------------------------------------------

def test_site_pages_exist_in_every_locale() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        root = pathlib.Path(tmp)
        legal = _write_legal(root, CLEAN)
        out = root / "out"
        _build(out, legal, False)
        for rel in ("index.html", "tr/index.html", "ar/index.html",
                    "support/index.html", "support/tr/index.html",
                    "support/ar/index.html"):
            check(f"site route exists: {rel}", (out / rel).exists(), True)
        ar = (out / "support/ar/index.html").read_text(encoding="utf-8")
        check("arabic support page is dir=rtl", 'dir="rtl"' in ar, True)
        tr = (out / "tr/index.html").read_text(encoding="utf-8")
        check("turkish landing is dir=ltr", 'dir="ltr"' in tr, True)


def test_landing_and_support_ship_under_invite_only() -> None:
    """THE decoupling decision, asserted rather than described.

    The legal pages are blocked behind the founder's unfilled legal name. The
    support page is not, contains no legal text, and is what the App Store
    listing points at — so a user needing help must not have to wait on a blank
    in a privacy policy. If someone later "simplifies" the build by moving these
    into the `not invite_only` branch, this goes red.
    """
    with tempfile.TemporaryDirectory() as tmp:
        root = pathlib.Path(tmp)
        legal = _write_legal(root, "# T\n\n[FOUNDER LEGAL ENTITY — to be completed by the founder]\n")
        out = root / "out"
        code = _build(out, legal, False, invite_only=True)
        check("invite-only build still succeeds", code, 0)
        for rel in ("index.html", "tr/index.html", "ar/index.html",
                    "support/index.html", "support/tr/index.html",
                    "support/ar/index.html"):
            check(f"served under --invite-only: {rel}", (out / rel).exists(), True)
        # ...and the legal pages still are NOT, which is what keeps the gate real.
        check("privacy still withheld", (out / "privacy/index.html").exists(), False)
        support = (out / "support/index.html").read_text(encoding="utf-8")
        check("support page does not link the withheld legal pages",
              'href="/privacy"' in support, False)


def test_language_switcher_never_emits_a_protocol_relative_url() -> None:
    """`//tr` is not a path — browsers read it as a protocol-relative URL and
    leave the site. The landing family's routes are `/`, `/tr`, `/ar`, so the
    naive f-string that works for `/privacy/tr` produces exactly that bug."""
    # Viewed FROM Turkish, so English renders as a link rather than <strong> —
    # the current locale is never a link, which is why asserting from "en" would
    # have looked for an href that correctly does not exist.
    nav = bs.lang_nav("", "tr")
    check("no protocol-relative href", "//" in nav, False)
    check("english landing is the bare root", "href='/'" in nav, True)
    check("arabic landing is /ar", "href='/ar'" in nav, True)
    check("the current locale is not a link", "<strong>Türkçe</strong>" in nav, True)
    # The family that already worked must keep working.
    legal_nav = bs.lang_nav("privacy", "en")
    check("privacy nav unchanged", "href='/privacy/tr'" in legal_nav, True)
    check("privacy nav has no protocol-relative href", "//" in legal_nav, False)


def test_site_copy_is_placeholder_gated_too() -> None:
    """A landing page reading "[COMPANY — TBD]" is exactly as bad as a policy
    that does. Unlike the legal loop this gate is NOT skipped by --invite-only,
    because these pages ship in that mode."""
    with tempfile.TemporaryDirectory() as tmp:
        root = pathlib.Path(tmp)
        legal = _write_legal(root, CLEAN)
        blanks = _write_site(root, "# Page\n\n[COMPANY NAME — to be decided]\n")
        check("a blank in SITE copy fails the build",
              bs.build(root / "out", legal, False, site_dir=blanks), 1)
        check("and fails it under --invite-only too, where these pages DO ship",
              bs.build(root / "out2", legal, False, invite_only=True, site_dir=blanks), 1)
        check("clean site copy passes",
              bs.build(root / "out3", legal, False, site_dir=_write_site(root)), 0)


def test_missing_site_source_is_an_error_not_an_empty_page() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        root = pathlib.Path(tmp)
        legal = _write_legal(root, CLEAN)
        empty = root / "nosite"
        empty.mkdir()
        try:
            bs.build(root / "out", legal, False, site_dir=empty)
        except bs.BuildError as exc:
            check("names the missing file", "landing.en.md" in str(exc), True)
        else:
            check("a missing site source raises", False, True)


def test_the_real_site_copy_builds_and_says_nothing_untrue() -> None:
    """The one test that deliberately reads the REAL docs/site copy.

    Hermetic tests prove the machinery; this proves the SHIPPED words. Every
    line below is a claim this repo has already paid for once: the invite code
    is eight characters (invite-code.ts INVITE_CODE_LENGTH), the app is not on
    the App Store, there is no Android build, and push notifications are not
    implemented app-side — so the site must not promise any of them.
    """
    site = pathlib.Path(__file__).resolve().parents[2] / "docs" / "site"
    if not site.exists():  # pragma: no cover - only before the copy lands
        check("docs/site exists", False, True)
        return
    with tempfile.TemporaryDirectory() as tmp:
        root = pathlib.Path(tmp)
        legal = _write_legal(root, CLEAN)
        out = root / "out"
        check("the real copy builds", bs.build(out, legal, False, site_dir=site), 0)
        blob = "\n".join(
            p.read_text(encoding="utf-8")
            for p in out.rglob("*.html")
        ).lower()
        check("never claims an App Store listing", "apps.apple.com" in blob, False)
        check("never mentions Google Play", "play.google.com" in blob, False)
        check("never says six-character", "six-character" in blob, False)
        check("never says six characters", "six characters" in blob, False)
        english = (out / "support/index.html").read_text(encoding="utf-8")
        check("states the real code length", "eight-character" in english, True)
        check("states the real expiry", "48 hours" in english, True)
        check("gives the contact route", "aytek@beyondkaira.com" in english, True)


def test_the_root_page_does_not_print_the_brand_twice() -> None:
    """The chrome prints the page title beside the brand, and the landing page's
    title IS the brand — so passing it through rendered the header
    "ikimizikimiz" and the tab "ikimiz · ikimiz". The old stub index shipped
    exactly that. A page whose subject is the site itself has no subtitle."""
    with tempfile.TemporaryDirectory() as tmp:
        root = pathlib.Path(tmp)
        legal = _write_legal(root, CLEAN)
        out = root / "out"
        _build(out, legal, False)
        index = (out / "index.html").read_text(encoding="utf-8")
        check("tab title is not doubled", "ikimiz · ikimiz" in index, False)
        check("tab title is the brand", "<title>ikimiz</title>" in index, True)
        check("header carries no duplicate tag", 'class="tag"' in index, False)
        # The control: a page that DOES have a subtitle must still show it, or
        # this "fix" would have silently stripped every legal page's heading.
        privacy = (out / "privacy/index.html").read_text(encoding="utf-8")
        check("a real subtitle survives", 'class="tag">Privacy Policy<' in privacy, True)
        check("and its tab title is still qualified",
              "<title>Privacy Policy · ikimiz</title>" in privacy, True)


def test_turkish_site_copy_uses_turkish_orthography() -> None:
    """Turkish without its diacritics is not Turkish.

    This exists because the first draft of this copy was written ASCII-only —
    "hosgoru gunu", "alti karakter" — by an author who GUESSED the generator
    might not handle UTF-8. It does: `docs/legal/privacy-policy.tr.md` has
    carried 53 Turkish diacritics through this same renderer since S054. For a
    Turkish-first product whose beta testers are all Turkish, shipping that to a
    public page is a quality defect, and a guess is not a reason.
    """
    site = pathlib.Path(__file__).resolve().parents[2] / "docs" / "site"
    if not site.exists():  # pragma: no cover
        check("docs/site exists", False, True)
        return
    text = "".join(
        (site / f"{stem}.tr.md").read_text(encoding="utf-8")
        for stem in ("landing", "support")
        if (site / f"{stem}.tr.md").exists()
    )
    check("turkish copy is present", len(text) > 200, True)
    diacritics = sum(text.count(c) for c in "şŞıİğĞçÇöÖüÜ")
    check("turkish copy carries its diacritics (>=20)", diacritics >= 20, True)


def test_invite_only_refuses_the_placeholder_flag() -> None:
    """The two flags are not composable, and saying so beats guessing."""
    check(
        "--invite-only with --allow-placeholders exits 2",
        bs.main(["--out", "/tmp/unused-build-site-test", "--invite-only", "--allow-placeholders"]),
        2,
    )


def main() -> int:
    print("build_site self-tests")
    for fn in (
        test_markdown_subset,
        test_table_path_is_exercised,
        test_prose_is_never_dropped,
        test_html_in_prose_is_escaped,
        test_link_syntax_is_not_implemented,
        test_placeholder_gate_fails_the_build,
        test_placeholder_gate_is_language_independent,
        test_placeholder_gate_does_not_cry_wolf,
        test_one_blank_is_counted_once,
        test_a_blank_without_an_em_dash_is_still_caught,
        test_clean_text_passes_without_the_flag,
        test_missing_source_is_an_error_not_an_empty_page,
        test_routes_and_rtl,
        test_aasa_is_valid_and_points_at_the_real_app,
        test_invite_only_serves_the_link_and_no_legal_text,
        test_full_build_still_links_the_legal_pages,
        test_invite_page_never_offers_a_dead_app_store_button,
        test_invite_only_refuses_the_placeholder_flag,
        test_site_pages_exist_in_every_locale,
        test_landing_and_support_ship_under_invite_only,
        test_language_switcher_never_emits_a_protocol_relative_url,
        test_site_copy_is_placeholder_gated_too,
        test_missing_site_source_is_an_error_not_an_empty_page,
        test_the_real_site_copy_builds_and_says_nothing_untrue,
        test_the_root_page_does_not_print_the_brand_twice,
        test_turkish_site_copy_uses_turkish_orthography,
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
