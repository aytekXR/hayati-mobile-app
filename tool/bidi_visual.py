#!/usr/bin/env python3
"""Show how a string ACTUALLY renders under the Unicode bidi algorithm.

WHY THIS EXISTS. Issue #136 asks whether a partner's name, interpolated into
localized push copy, renders correctly in a notification shade. That question was
answered three times by three sessions with three different guesses, because
reading UAX #9 and reasoning about it is much harder than it looks: this tool's
author got the Arabic case backwards twice before running it.

There is no Flutter here — the renderer is the OS notification shade — so
ADR-033's app-side evidence and its instrument do not transfer. So drive the
REFERENCE IMPLEMENTATION instead: FriBidi, which is already on the box as
`libfribidi.so.0` and needs no install, no network and no npm dependency added to
`functions/`.

THE CONTROL MATTERS MORE THAN THE TOOL. Before believing any output, run
`--control`. It feeds in the string ADR-033 records as the visible form of issue
#133 and checks that FriBidi reproduces it. A bidi harness that cannot reproduce
a defect we already had is a harness whose green means nothing (lesson 65: prove
the instrument works on a case you know is non-empty).

NOT A CI GATE, deliberately. Nothing in `.github/workflows/` runs this. The
measurement is made once, recorded in ADR-059, and what ships is the invariant it
established — asserted in `functions/test/unit/sanitize-push-name.test.ts`, which
needs no bidi implementation to check. This file exists so a later session can
re-derive that invariant, or answer #136's device question the day a device
exists, without rebuilding the instrument.

Usage:
    python3 tool/bidi_visual.py --control
    python3 tool/bidi_visual.py 'أجاب Aylin Y.'
    python3 tool/bidi_visual.py --base rtl 'أيلين answered today.'
    python3 tool/bidi_visual.py --push        # every shipped push string
"""

from __future__ import annotations

import argparse
import ctypes
import ctypes.util
import sys

# FriBidi ParType constants, from fribidi-bidi-types.h. `ON` is the neutral mask
# and is what FriBidi treats as "auto-detect from the first strong character" —
# the P2/P3 default, and what a `dir="auto"` renderer does.
PAR_LTR = 0x00000110
PAR_RTL = 0x00000111
PAR_ON = 0x00000040

BASES = {"auto": PAR_ON, "ltr": PAR_LTR, "rtl": PAR_RTL}

# The string ADR-033's `bidi_isolate.dart` records as the VISIBLE form of #133 —
# a Turkish answer inside Arabic chrome, its final stop leading the sentence.
CONTROL_INPUT = "إجابة شريكك: Kahvaltıda birlikte gülmemiz."
CONTROL_EXPECTED_PREFIX = ".Kahvaltıda birlikte gülmemiz"


def _load():
    path = ctypes.util.find_library("fribidi")
    if path is None:
        sys.exit(
            "libfribidi not found. On Debian/Ubuntu: apt-get install libfribidi0\n"
            "This tool deliberately has no pip/npm dependency; it drives the "
            "system's reference implementation."
        )
    lib = ctypes.CDLL(path)
    lib.fribidi_log2vis.restype = ctypes.c_int
    lib.fribidi_log2vis.argtypes = [
        ctypes.POINTER(ctypes.c_uint32),
        ctypes.c_int,
        ctypes.POINTER(ctypes.c_uint32),
        ctypes.POINTER(ctypes.c_uint32),
        ctypes.POINTER(ctypes.c_int),
        ctypes.POINTER(ctypes.c_int),
        ctypes.POINTER(ctypes.c_byte),
    ]
    return lib


_LIB = _load()


def visual(text: str, base: int = PAR_ON) -> tuple[str, list[int], int]:
    """The visual reordering of `text`, its per-character embedding levels, and
    the paragraph direction that was resolved (which is the interesting output
    when `base` is auto)."""
    n = len(text)
    src = (ctypes.c_uint32 * (n + 1))(*[ord(c) for c in text], 0)
    dst = (ctypes.c_uint32 * (n + 1))()
    l2v = (ctypes.c_int * (n + 1))()
    v2l = (ctypes.c_int * (n + 1))()
    levels = (ctypes.c_byte * (n + 1))()
    pbase = ctypes.c_uint32(base)
    if not _LIB.fribidi_log2vis(src, n, ctypes.byref(pbase), dst, l2v, v2l, levels):
        raise RuntimeError("fribidi_log2vis failed")
    return (
        "".join(chr(dst[i]) for i in range(n)),
        [levels[i] for i in range(n)],
        pbase.value,
    )


def report(label: str, text: str, base: int = PAR_ON) -> str:
    vis, levels, resolved = visual(text, base)
    direction = {PAR_RTL: "RTL", PAR_LTR: "LTR"}.get(resolved, hex(resolved))
    print(f"{label}")
    print(f"  logical : {text}")
    print(f"  visual  : {vis}")
    print(f"  base    : {direction}   levels: {''.join(str(x) for x in levels)}")
    return vis


def run_control() -> int:
    print("CONTROL — the visible form of issue #133, which ADR-033 exists to fix.")
    print("If this does not reproduce, no other output from this tool means anything.\n")
    vis = report("#133", CONTROL_INPUT)
    ok = vis.startswith(CONTROL_EXPECTED_PREFIX)
    print()
    if ok:
        print(f"PASS — reproduced {CONTROL_EXPECTED_PREFIX!r}: the period leads the sentence.")
        return 0
    print(f"FAIL — expected the visual form to start with {CONTROL_EXPECTED_PREFIX!r}.")
    print("Either FriBidi changed, or this is not the string ADR-033 recorded.")
    return 1


# Every shipped push string that interpolates something, with the names that
# matter: a Latin name inside Arabic copy, an Arabic name inside Latin copy, and
# the trailing-neutral case that started #136. Kept in sync BY HAND with
# functions/src/notifications/payload-policy.ts — this is a scratch instrument,
# not a gate, and a drifted copy here misleads nobody but its reader.
PUSH_SAMPLES: list[tuple[str, str]] = [
    ("ar partnerAnswered title", "أجاب {name}"),
    ("ar partnerAnswered body", "أجاب {name} عن سؤال اليوم. افتح ikimiz وأضف إجابتك."),
    ("en partnerAnswered title (fixed)", "Your partner {name} answered"),
    ("en partnerAnswered body (fixed)", "Your partner {name} answered today's question. Open ikimiz to add yours."),
    ("en partnerAnswered title (BEFORE)", "{name} answered"),
    ("tr partnerAnswered title (fixed)", "Partnerin {name} cevapladı"),
    ("tr partnerAnswered title (BEFORE)", "{name} cevapladı"),
]

PUSH_NAMES = ["Aylin", "Aylin Y.", "Aylin (", "أيلين", "أيلين."]


def run_push() -> int:
    for label, template in PUSH_SAMPLES:
        for name in PUSH_NAMES:
            report(f"{label}  name={name!r}", template.replace("{name}", name))
            print()
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("text", nargs="?", help="the logical string to render")
    parser.add_argument("--base", choices=sorted(BASES), default="auto",
                        help="paragraph direction: auto (first-strong, the UAX #9 default), ltr, or rtl")
    parser.add_argument("--control", action="store_true", help="reproduce the #133 defect and exit")
    parser.add_argument("--push", action="store_true", help="report every shipped push string")
    args = parser.parse_args()

    if args.control:
        return run_control()
    if args.push:
        return run_push()
    if args.text is None:
        parser.print_help()
        return 2
    report("input", args.text, BASES[args.base])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
