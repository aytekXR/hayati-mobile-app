#!/usr/bin/env python3
"""Render ikimiz.beyondkaira.com from the repo's single source of truth.

WHY A GENERATOR AND NOT A COMMITTED SITE. `docs/legal/*.md` is already
byte-synced into `app/assets/legal/` under a drift test (ADR-023): the app and
the repo must never disagree about what the policy says. Committing a THIRD
hand-maintained copy as HTML would add a third thing to drift, and drift in a
legal document is the failure this project has already built a test to prevent.
So the public pages are GENERATED from `docs/legal/` at deploy time and the
output directory is gitignored. There is exactly one source.

The Markdown subset is deliberately tiny because the corpus is tiny — measured,
not guessed: h1-h3, unordered lists, one ordered list, tables, **bold**,
_italic_, `code`. There are ZERO links in the corpus, so link syntax is NOT
implemented on purpose: the documents contain `[FOUNDER LEGAL ENTITY — to be
completed by the founder]`, and a link parser would silently eat those brackets
and hide an unfilled placeholder inside an anchor tag.

PLACEHOLDERS ARE A HARD FAILURE. A privacy policy served at a public URL that
the App Store points to must not read "to be completed by the founder".
`--allow-placeholders` exists so the infrastructure can be built and deployed
to a preview channel before the founder fills them in, but the flag has to be
passed on purpose and the build says loudly what it let through.

Usage:
    python3 tool/ci/build_site.py --out web/public [--allow-placeholders]
"""

from __future__ import annotations

import argparse
import html
import json
import pathlib
import re
import sys

# ADR-029 D1: a Team ID is an identifier, not a credential — it is published in
# every distributed IPA's embedded profile. ADR-027: the bundle id stays
# com.beyondkaira.hayati even though the app is now called ikimiz (ADR-035 D5).
TEAM_ID = "UH7MXG7Z94"
BUNDLE_ID = "com.beyondkaira.hayati"

DOMAIN = "ikimiz.beyondkaira.com"
BRAND = "ikimiz"

# Unfilled blanks the founder still owes. Matched as literal fragments rather
# than a generic `\[.*\]` so ordinary bracketed prose can never trip the gate.
PLACEHOLDER_MARKERS = ("to be completed by the founder", "TO BE COMPLETED")

LOCALES = {
    "en": {"dir": "ltr", "lang": "en", "privacy": "Privacy Policy", "terms": "Terms of Service"},
    "tr": {"dir": "ltr", "lang": "tr", "privacy": "Gizlilik Politikası", "terms": "Kullanım Koşulları"},
    "ar": {"dir": "rtl", "lang": "ar", "privacy": "سياسة الخصوصية", "terms": "شروط الاستخدام"},
}

# Brandkit v1.0 tokens (docs/frontend-brandkit.md). Inlined rather than imported
# because this page must render with no network and no build step.
CSS = """
:root{--sand:#F6F1EA;--night:#2A2622;--rose:#B98A6E;--muted:#6E6259;--line:#E4DACE}
@media(prefers-color-scheme:dark){:root{--sand:#1C1917;--night:#F2ECE4;--muted:#A79A8E;--line:#332E29}}
*{box-sizing:border-box}
body{margin:0;background:var(--sand);color:var(--night);
  font:16px/1.7 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,"Helvetica Neue",sans-serif;
  -webkit-text-size-adjust:100%}
.wrap{max-width:44rem;margin:0 auto;padding:2.5rem 1.25rem 5rem}
header{display:flex;align-items:baseline;gap:.75rem;margin-bottom:2.5rem}
.brand{font-size:1.5rem;font-weight:700;letter-spacing:-.01em;color:var(--night);text-decoration:none}
.tag{color:var(--muted);font-size:.9rem}
h1{font-size:1.9rem;line-height:1.25;margin:0 0 1.25rem}
h2{font-size:1.25rem;margin:2.5rem 0 .75rem}
h3{font-size:1.05rem;margin:1.75rem 0 .5rem}
p,li{color:var(--night)}
ul,ol{padding-inline-start:1.4rem}
li{margin:.35rem 0}
code{background:rgba(128,128,128,.14);padding:.1rem .35rem;border-radius:4px;font-size:.9em}
hr{border:0;border-top:1px solid var(--line);margin:2.5rem 0}
table{width:100%;border-collapse:collapse;margin:1rem 0;display:block;overflow-x:auto}
th,td{border:1px solid var(--line);padding:.5rem .65rem;text-align:start}
nav.langs{margin:1.5rem 0 0;font-size:.9rem}
nav.langs a{color:var(--muted);margin-inline-end:.85rem}
footer{margin-top:4rem;padding-top:1.5rem;border-top:1px solid var(--line);color:var(--muted);font-size:.875rem}
a{color:var(--rose)}
.cta{display:inline-block;margin-top:1.5rem;background:var(--night);color:var(--sand);
  padding:.8rem 1.4rem;border-radius:999px;text-decoration:none;font-weight:600}
.code{font-size:2rem;font-weight:700;letter-spacing:.12em;margin:1rem 0}
"""


class BuildError(RuntimeError):
    pass


def _inline(text: str) -> str:
    """Escape, then apply the inline subset. Escaping FIRST is what keeps a
    stray `<` in legal prose from becoming markup."""
    out = html.escape(text, quote=False)
    out = re.sub(r"`([^`]+)`", r"<code>\1</code>", out)
    out = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", out)
    # `_x_` only between word boundaries, so snake_case identifiers survive.
    out = re.sub(r"(?<![\w\\])_([^_]+)_(?!\w)", r"<em>\1</em>", out)
    return out


def markdown_to_html(md: str) -> str:
    """The measured subset. Anything unrecognised becomes a paragraph, which is
    the safe failure: legal text is never silently dropped."""
    lines = md.split("\n")
    out: list[str] = []
    i = 0
    while i < len(lines):
        line = lines[i].rstrip()
        if not line.strip():
            i += 1
            continue
        if line.startswith("### "):
            out.append(f"<h3>{_inline(line[4:])}</h3>")
        elif line.startswith("## "):
            out.append(f"<h2>{_inline(line[3:])}</h2>")
        elif line.startswith("# "):
            out.append(f"<h1>{_inline(line[2:])}</h1>")
        elif line.startswith("---"):
            out.append("<hr>")
        elif line.startswith("|"):
            rows = []
            while i < len(lines) and lines[i].startswith("|"):
                rows.append(lines[i])
                i += 1
            out.append(_table(rows))
            continue
        elif re.match(r"^\s*[-*] ", line):
            items = []
            while i < len(lines) and re.match(r"^\s*[-*] ", lines[i].rstrip()):
                items.append(_inline(re.sub(r"^\s*[-*] ", "", lines[i].rstrip())))
                i += 1
            out.append("<ul>" + "".join(f"<li>{x}</li>" for x in items) + "</ul>")
            continue
        elif re.match(r"^\s*\d+\. ", line):
            items = []
            while i < len(lines) and re.match(r"^\s*\d+\. ", lines[i].rstrip()):
                items.append(_inline(re.sub(r"^\s*\d+\. ", "", lines[i].rstrip())))
                i += 1
            out.append("<ol>" + "".join(f"<li>{x}</li>" for x in items) + "</ol>")
            continue
        else:
            out.append(f"<p>{_inline(line)}</p>")
        i += 1
    return "\n".join(out)


def _table(rows: list[str]) -> str:
    def cells(row: str) -> list[str]:
        return [c.strip() for c in row.strip().strip("|").split("|")]

    body = [r for r in rows if not re.match(r"^\|[\s:|-]+\|?$", r.strip())]
    if not body:
        return ""
    head, rest = body[0], body[1:]
    out = ["<table><thead><tr>"]
    out += [f"<th>{_inline(c)}</th>" for c in cells(head)]
    out.append("</tr></thead><tbody>")
    for r in rest:
        out.append("<tr>" + "".join(f"<td>{_inline(c)}</td>" for c in cells(r)) + "</tr>")
    out.append("</tbody></table>")
    return "".join(out)


def page(title: str, locale: str, body: str, langs: str = "") -> str:
    meta = LOCALES[locale]
    return f"""<!doctype html>
<html lang="{meta['lang']}" dir="{meta['dir']}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>{html.escape(title)} · {BRAND}</title>
<meta name="robots" content="index,follow">
<style>{CSS}</style>
</head>
<body><div class="wrap">
<header><a class="brand" href="/">{BRAND}</a><span class="tag">{html.escape(title)}</span></header>
{body}
{langs}
<footer>{BRAND} · <a href="/privacy">{LOCALES[locale]['privacy']}</a> · <a href="/terms">{LOCALES[locale]['terms']}</a></footer>
</div></body></html>
"""


def lang_nav(kind: str, current: str) -> str:
    names = {"en": "English", "tr": "Türkçe", "ar": "العربية"}
    parts = []
    for loc in ("en", "tr", "ar"):
        href = f"/{kind}" if loc == "en" else f"/{kind}/{loc}"
        label = html.escape(names[loc])
        parts.append(f"<a href='{href}'>{label}</a>" if loc != current else f"<strong>{label}</strong>")
    return "<nav class='langs'>" + " ".join(parts) + "</nav>"


def check_placeholders(name: str, text: str) -> list[str]:
    return [m for m in PLACEHOLDER_MARKERS if m.lower() in text.lower()]


def build(out_dir: pathlib.Path, legal_dir: pathlib.Path, allow_placeholders: bool) -> int:
    out_dir.mkdir(parents=True, exist_ok=True)
    found: list[str] = []

    for kind, stem in (("privacy", "privacy-policy"), ("terms", "terms")):
        for loc in ("en", "tr", "ar"):
            src = legal_dir / f"{stem}.{loc}.md"
            if not src.exists():
                raise BuildError(f"missing legal source: {src}")
            md = src.read_text(encoding="utf-8")
            hits = check_placeholders(src.name, md)
            if hits:
                found.append(f"{src.name}: {hits}")
            title = LOCALES[loc]["privacy"] if kind == "privacy" else LOCALES[loc]["terms"]
            doc = page(title, loc, markdown_to_html(md), lang_nav(kind, loc))
            target = out_dir / kind if loc == "en" else out_dir / kind / loc
            target.mkdir(parents=True, exist_ok=True)
            (target / "index.html").write_text(doc, encoding="utf-8")

    # Apple universal links. Served from /.well-known/ with no extension and
    # `application/json` (firebase.json sets the header) — Apple fetches this
    # over TLS and will not follow a redirect.
    aasa = {
        "applinks": {
            "details": [
                {"appIDs": [f"{TEAM_ID}.{BUNDLE_ID}"], "components": [{"/": "/i/*", "comment": "invite links"}]}
            ]
        }
    }
    wk = out_dir / ".well-known"
    wk.mkdir(parents=True, exist_ok=True)
    (wk / "apple-app-site-association").write_text(json.dumps(aasa, indent=2), encoding="utf-8")

    # The invite landing page. On iOS with the app installed the OS intercepts
    # this URL and the page never renders; everyone else gets the code and a way
    # to install. The code is read from the PATH, never sent anywhere.
    invite = """<h1>You've been invited</h1>
<p>Your invite code is</p>
<div class="code" id="code">…</div>
<p>Open ikimiz and enter this code to pair.</p>
<a class="cta" href="https://apps.apple.com/app/id0000000000">Get ikimiz</a>
<script>
  var m = location.pathname.match(/\\/i\\/([A-Za-z0-9]+)/);
  document.getElementById('code').textContent = m ? m[1].toUpperCase() : 'unknown';
</script>"""
    (out_dir / "invite.html").write_text(page("Invite", "en", invite), encoding="utf-8")

    index = f"""<h1>{BRAND}</h1>
<p>One question a day, for two.</p>
<p><a href="/privacy">Privacy Policy</a> · <a href="/terms">Terms of Service</a></p>"""
    (out_dir / "index.html").write_text(page("ikimiz", "en", index), encoding="utf-8")

    (out_dir / "404.html").write_text(
        page("Not found", "en", "<h1>Not found</h1><p>That page does not exist.</p>"), encoding="utf-8"
    )

    print(f"built {DOMAIN} -> {out_dir}")
    for p in sorted(out_dir.rglob("*")):
        if p.is_file():
            print(f"    {p.relative_to(out_dir)}")

    if found:
        msg = "unfilled placeholders in published legal text:\n  " + "\n  ".join(found)
        if not allow_placeholders:
            print(f"::error::{msg}")
            print("::error::refusing to build a public privacy policy that says "
                  "'to be completed by the founder'. Pass --allow-placeholders to "
                  "build anyway (preview channels only).")
            return 1
        print(f"::warning::{msg}")
        print("::warning::built ANYWAY because --allow-placeholders was passed. "
              "This must not reach the live channel.")
    return 0


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="Build the ikimiz.beyondkaira.com static site.")
    ap.add_argument("--out", default="web/public")
    ap.add_argument("--legal-dir", default="docs/legal")
    ap.add_argument("--allow-placeholders", action="store_true")
    a = ap.parse_args(argv)
    try:
        return build(pathlib.Path(a.out), pathlib.Path(a.legal_dir), a.allow_placeholders)
    except BuildError as exc:
        print(f"::error::{exc}")
        return 2


if __name__ == "__main__":
    sys.exit(main())
