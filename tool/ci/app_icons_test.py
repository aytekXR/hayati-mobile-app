#!/usr/bin/env python3
"""Hermetic self-tests for tool/ci/app_icons.py. No network, no image library.

The gate this file guards is small and unusually easy to fake: a generator that
reported "nothing drifted" unconditionally would pass a smoke test while
guarding nothing — which is literally the defect (lesson **66**) the tool was
written to end. So the assertions below aim at MECHANISMS, not outcomes:

* the resampler is checked **differentially against a slow, obviously-correct
  reference implementation written here**, not against bytes captured from the
  tool itself. A fixture derived from its own subject proves nothing.
* the linear-light claim is pinned by a case where naive sRGB averaging gives a
  visibly different answer, so "simplifying" the transfer function reddens it.
* "could not measure" (exit 2) is asserted as distinct from "drift" (exit 1).

Checks are grouped into sections that run independently: a mutation that makes
the tool *raise* is recorded as a named failure of its section rather than
killing the run, because a red that names nothing is a poor diagnostic and this
file's whole job is to say WHICH property moved (lesson **75**).
"""

from __future__ import annotations

import io
import json
import os
import random
import shutil
import struct
import sys
import tempfile
import traceback
import zlib
from contextlib import redirect_stdout, redirect_stderr
from fractions import Fraction

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import app_icons as A  # noqa: E402

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


# --------------------------------------------------------------------------
# helpers
# --------------------------------------------------------------------------


def raw_png(width: int, height: int, pixels: bytes, colour: int = 2, ftype: int = 0,
            depth: int = 8, interlace: int = 0) -> bytes:
    """Build a PNG with one chosen filter type on every row (encoder-independent)."""
    channels = 3 if colour == 2 else 4
    stride = width * channels
    body = bytearray()
    prev = bytes(stride)
    for y in range(height):
        cur = pixels[y * stride : (y + 1) * stride]
        if ftype == 0:
            enc = cur
        elif ftype == 1:
            enc = bytes((cur[i] - (cur[i - channels] if i >= channels else 0)) & 0xFF for i in range(stride))
        elif ftype == 2:
            enc = bytes((c - p) & 0xFF for c, p in zip(cur, prev))
        elif ftype == 3:
            enc = bytes(
                (cur[i] - (((cur[i - channels] if i >= channels else 0) + prev[i]) >> 1)) & 0xFF
                for i in range(stride)
            )
        elif ftype == 4:
            out = bytearray()
            for i in range(stride):
                a = cur[i - channels] if i >= channels else 0
                b = prev[i]
                c = prev[i - channels] if i >= channels else 0
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pred = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                out.append((cur[i] - pred) & 0xFF)
            enc = bytes(out)
        else:
            raise AssertionError(ftype)
        body += bytes([ftype]) + enc
        prev = cur
    ihdr = struct.pack(">IIBBBBB", width, height, depth, colour, 0, 0, interlace)
    return (
        A.PNG_MAGIC
        + A._chunk(b"IHDR", ihdr)
        + A._chunk(b"IDAT", zlib.compress(bytes(body), 6))
        + A._chunk(b"IEND", b"")
    )


def reference_resize(width: int, height: int, rgb: bytes, out_w: int, out_h: int) -> bytes:
    """Slow, independent area-average in linear light. Exact rational overlap.

    Deliberately written without _spans, without prefix sums and without any
    integer-unit trick: it walks every (source, destination) pair and computes
    the overlap as a Fraction. If this and resize_rgb agree, they do not agree
    by sharing a bug.
    """
    sx = Fraction(width, out_w)
    sy = Fraction(height, out_h)
    out = bytearray(out_w * out_h * 3)
    for j in range(out_h):
        y0, y1 = j * sy, (j + 1) * sy
        for i in range(out_w):
            x0, x1 = i * sx, (i + 1) * sx
            for c in range(3):
                total = Fraction(0)
                for y in range(height):
                    oy = min(y1, y + 1) - max(y0, y)
                    if oy <= 0:
                        continue
                    for x in range(width):
                        ox = min(x1, x + 1) - max(x0, x)
                        if ox <= 0:
                            continue
                        total += ox * oy * A.TO_LINEAR[rgb[(y * width + x) * 3 + c]]
                mean = total / (sx * sy)
                # round-half-up on the integer linear value, as the tool does
                lin = (mean.numerator * 2 + mean.denominator) // (2 * mean.denominator)
                out[(j * out_w + i) * 3 + c] = A.from_linear(lin)
    return bytes(out)


def noise(width: int, height: int, seed: int) -> bytes:
    rng = random.Random(seed)
    return bytes(rng.randrange(256) for _ in range(width * height * 3))


def filter_bytes(blob: bytes, width: int) -> list[int]:
    """The per-row filter type byte of an encoded PNG, in row order."""
    idat = bytearray()
    off = 8
    while off + 8 <= len(blob):
        (length,) = struct.unpack(">I", blob[off : off + 4])
        if blob[off + 4 : off + 8] == b"IDAT":
            idat += blob[off + 8 : off + 8 + length]
        off += 12 + length
    raw = zlib.decompress(bytes(idat))
    return list(raw[:: width * 3 + 1])


def run_cli(argv: list[str]) -> tuple[int, str]:
    out, err = io.StringIO(), io.StringIO()
    with redirect_stdout(out), redirect_stderr(err):
        code = A.main(argv)
    return code, out.getvalue() + err.getvalue()


# --------------------------------------------------------------------------
# 1. sRGB transfer tables
# --------------------------------------------------------------------------


@section
def transfer_tables():
    check(
        "transfer: every code word survives a linear round-trip",
        all(A.from_linear(A.TO_LINEAR[v]) == v for v in range(256)),
        "an inexact round-trip would corrupt the 1024 identity render",
    )
    check("transfer: monotone", all(A.TO_LINEAR[v] < A.TO_LINEAR[v + 1] for v in range(255)))
    check("transfer: endpoints", A.TO_LINEAR[0] == 0 and A.TO_LINEAR[255] == A.LIN_SCALE)


@section
def gamma_correct_mixing():
    # The gamma claim, stated so that removing it reddens. Averaging black and
    # white in sRGB code words gives 128; averaging in linear light gives ~188.
    half = A.resize_rgb(2, 1, bytes([0, 0, 0, 255, 255, 255]), 1, 1)
    check(
        "resample: mixing is done in LINEAR light, not on sRGB code words",
        half[0] >= 180,
        f"black+white averaged to {half[0]}; a naive sRGB average would give 127/128",
    )


# --------------------------------------------------------------------------
# 2. PNG decoding — every filter type, and the refusals
# --------------------------------------------------------------------------


@section
def decode_filters():
    px = noise(9, 7, 1)
    for ftype in range(5):
        w, h, got = A.decode_png(raw_png(9, 7, px, ftype=ftype), f"filter{ftype}")
        check(f"decode: filter type {ftype} reconstructs the image", (w, h, got) == (9, 7, px))

    rgba = bytearray()
    for i in range(0, len(px), 3):
        rgba += px[i : i + 3] + b"\xff"
    w, h, got = A.decode_png(raw_png(9, 7, bytes(rgba), colour=6, ftype=4), "rgba")
    check("decode: an opaque RGBA master drops to RGB", (w, h, got) == (9, 7, px))


@section
def decode_refusals():
    px = noise(9, 7, 1)
    rgba = bytearray()
    for i in range(0, len(px), 3):
        rgba += px[i : i + 3] + b"\xff"
    rgba[3] = 0xFE  # one pixel, one code word off opaque
    try:
        A.decode_png(raw_png(9, 7, bytes(rgba), colour=6), "translucent")
        check("decode: a non-opaque master is refused", False, "it was accepted")
    except A.CannotMeasure as exc:
        check("decode: a non-opaque master is refused", "not opaque" in str(exc), str(exc))

    for label, kwargs in (("16-bit", {"depth": 16}), ("interlaced", {"interlace": 1})):
        try:
            A.decode_png(raw_png(4, 4, noise(4, 4, 2), **kwargs), label)
            check(f"decode: {label} PNG is refused", False, "it was accepted")
        except A.CannotMeasure:
            check(f"decode: {label} PNG is refused", True)

    try:
        A.decode_png(b"not a png at all", "junk")
        check("decode: a non-PNG is refused", False)
    except A.CannotMeasure:
        check("decode: a non-PNG is refused", True)


# --------------------------------------------------------------------------
# 3. PNG encoding — round-trip, determinism, and no alpha
# --------------------------------------------------------------------------


@section
def encode_roundtrip():
    for w, h, seed in ((1, 1, 3), (16, 16, 4), (17, 5, 5)):
        src = noise(w, h, seed)
        blob = A.encode_png(w, h, src)
        check(f"encode: {w}x{h} round-trips through the decoder", A.decode_png(blob, "rt") == (w, h, src))
        check(f"encode: {w}x{h} is deterministic", A.encode_png(w, h, src) == blob)
        colour = struct.unpack(">IIBBBBB", blob[16:29])[3]
        check(f"encode: {w}x{h} carries no alpha channel", colour == 2, f"colour type {colour}")
        check(
            f"encode: {w}x{h} emits no ancillary chunk",
            blob.count(b"tEXt") == 0 and blob.count(b"tIME") == 0,
        )


@section
def encode_filter_choice():
    # Both filter branches must be reachable, or the adaptive choice is decoration.
    flat = filter_bytes(A.encode_png(8, 8, bytes([40, 30, 60] * 64)), 8)
    check("encode: a flat field uses Up on the rows after the first", set(flat[1:]) == {2}, str(flat))
    grad = bytes(v for _ in range(8) for x in range(8) for v in (x * 30 % 256, 0, 0))
    check("encode: a horizontally-varying first row uses None", filter_bytes(A.encode_png(8, 8, grad), 8)[0] == 0)


# --------------------------------------------------------------------------
# 4. Coverage weights
# --------------------------------------------------------------------------


@section
def coverage_weights():
    for src, dst in ((1024, 167), (1024, 20), (40, 7), (7, 7), (13, 5), (256, 256), (9, 1)):
        spans = A._spans(src, dst)
        check(f"spans({src},{dst}): one entry per destination cell", len(spans) == dst)
        check(
            f"spans({src},{dst}): every cell's weights sum to {src}",
            all(sum(weights) == src for _, _, weights in spans),
        )
        check(
            f"spans({src},{dst}): weight count matches the span",
            all(len(weights) == last - first + 1 for first, last, weights in spans),
        )
        covered: dict[int, int] = {}
        for first, _, weights in spans:
            for offset, weight in enumerate(weights):
                covered[first + offset] = covered.get(first + offset, 0) + weight
        check(
            f"spans({src},{dst}): every source cell is covered exactly once over",
            sorted(covered) == list(range(src)) and all(v == dst for v in covered.values()),
            "a gap or an overlap here is a geometric shift in the output",
        )


# --------------------------------------------------------------------------
# 5. Resampling, differentially against the reference
# --------------------------------------------------------------------------


@section
def resample_differential():
    for w, h, ow, oh, seed in ((8, 8, 4, 4, 10), (9, 9, 3, 3, 11), (13, 13, 5, 5, 12),
                               (16, 16, 7, 7, 13), (11, 7, 4, 3, 14), (6, 6, 1, 1, 15)):
        src = noise(w, h, seed)
        check(
            f"resample {w}x{h} -> {ow}x{oh} matches the independent reference",
            A.resize_rgb(w, h, src, ow, oh) == reference_resize(w, h, src, ow, oh),
        )


@section
def resample_identity():
    src = noise(12, 12, 20)
    check("resample: identity returns the input", A.resize_rgb(12, 12, src, 12, 12) == src)
    check(
        "resample: the identity FAST PATH agrees with the general computation",
        A.resize_rgb(12, 12, src, 12, 12) == reference_resize(12, 12, src, 12, 12),
        "the 1024 icon takes the fast path; if it disagrees, that icon is silently different",
    )


@section
def resample_refuses_upscale():
    try:
        A.resize_rgb(8, 8, noise(8, 8, 21), 16, 16)
        check("resample: upscaling is refused", False, "it was accepted")
    except A.CannotMeasure:
        check("resample: upscaling is refused", True)


# --------------------------------------------------------------------------
# 6. iOS targets are read from Contents.json
# --------------------------------------------------------------------------


@section
def targets_from_manifest():
    manifest = {
        "images": [
            {"size": "20x20", "idiom": "iphone", "filename": "a.png", "scale": "2x"},
            {"size": "40x40", "idiom": "ipad", "filename": "a.png", "scale": "1x"},
            {"size": "83.5x83.5", "idiom": "ipad", "filename": "b.png", "scale": "2x"},
            {"size": "1024x1024", "idiom": "ios-marketing", "filename": "c.png", "scale": "1x"},
            {"size": "60x60", "idiom": "iphone", "scale": "3x"},
        ]
    }
    targets = A.ios_targets(manifest, "m")
    check("targets: 83.5x83.5@2x is 167px", targets.get("b.png") == 167)
    check("targets: a shared filename at one size is accepted once", targets.get("a.png") == 40)
    check("targets: the marketing icon is 1024px", targets.get("c.png") == 1024)
    check("targets: a slot with no filename is skipped", len(targets) == 3, str(targets))


@section
def targets_refusals():
    for label, images in (
        ("a filename declared at two different sizes", [
            {"size": "20x20", "filename": "a.png", "scale": "2x"},
            {"size": "60x60", "filename": "a.png", "scale": "1x"},
        ]),
        ("a fractional pixel size", [{"size": "83.5x83.5", "filename": "a.png", "scale": "1x"}]),
        ("an unreadable scale", [{"size": "20x20", "filename": "a.png", "scale": "big"}]),
        ("no images at all", []),
    ):
        try:
            A.ios_targets({"images": images}, "m")
            check(f"targets: {label} is refused", False, "it was accepted")
        except A.CannotMeasure:
            check(f"targets: {label} is refused", True)


# --------------------------------------------------------------------------
# 7. End to end on a fixture tree — the three exit codes
# --------------------------------------------------------------------------


def build_fixture(root: str, manifest_images: list[dict]) -> None:
    os.makedirs(os.path.join(root, os.path.dirname(A.MASTER)), exist_ok=True)
    os.makedirs(os.path.join(root, A.IOS_APPICONSET), exist_ok=True)
    for density in A.ANDROID_MIPMAPS:
        os.makedirs(os.path.join(root, A.ANDROID_RES, density), exist_ok=True)
    with open(os.path.join(root, A.MASTER), "wb") as handle:
        handle.write(A.encode_png(256, 256, noise(256, 256, 30)))
    with open(os.path.join(root, A.IOS_APPICONSET, "Contents.json"), "w", encoding="utf-8") as handle:
        json.dump({"images": manifest_images}, handle)


@section
def end_to_end():
    fixture = tempfile.mkdtemp(prefix="app-icons-test-")
    try:
        build_fixture(fixture, [
            {"size": "20x20", "idiom": "iphone", "filename": "Icon-20@2x.png", "scale": "2x"},
            {"size": "83.5x83.5", "idiom": "ipad", "filename": "Icon-83.5@2x.png", "scale": "2x"},
        ])

        code, _ = run_cli(["--verify", "--root", fixture])
        check("e2e: an unwritten tree is DRIFT, not ok", code == A.EXIT_DRIFT, f"exit {code}")

        code, _ = run_cli(["--write", "--root", fixture])
        check("e2e: --write succeeds", code == A.EXIT_OK, f"exit {code}")

        written = os.path.join(fixture, A.IOS_APPICONSET, "Icon-83.5@2x.png")
        check("e2e: --write actually created the declared file", os.path.exists(written))
        if os.path.exists(written):
            with open(written, "rb") as handle:
                check("e2e: --write emits the declared size", A.decode_png(handle.read(), "w")[0] == 167)

        emitted = {}
        for density, px in A.ANDROID_MIPMAPS.items():
            path = os.path.join(fixture, A.ANDROID_RES, density, "ic_launcher.png")
            if os.path.exists(path):
                with open(path, "rb") as handle:
                    emitted[density] = A.decode_png(handle.read(), density)[0]
        check(
            "e2e: --write emits every Android density at its platform size",
            emitted == A.ANDROID_MIPMAPS,
            f"got {emitted}",
        )

        code, text = run_cli(["--verify", "--root", fixture])
        check("e2e: a freshly written tree verifies clean", code == A.EXIT_OK, f"exit {code}\n{text}")

        if os.path.exists(written):
            with open(written, "rb") as handle:
                w, h, pixels = A.decode_png(handle.read(), "w")

            # Re-deflated, same pixels. This is what a different zlib version
            # produces, and it must NOT read as drift — the gate compares the
            # image, not the compressor.
            with open(written, "wb") as handle:
                handle.write(raw_png(w, h, pixels, ftype=4))
            code, text = run_cli(["--verify", "--root", fixture])
            check(
                "e2e: a re-encoded but pixel-identical icon is NOT drift",
                code == A.EXIT_OK,
                f"exit {code}; a byte comparison would false-red here on another zlib",
            )

            # One wrong pixel, in one file, at one size — the lesson-66 shape.
            stale = bytearray(pixels)
            stale[0] ^= 0xFF
            with open(written, "wb") as handle:
                handle.write(A.encode_png(w, h, bytes(stale)))
            code, text = run_cli(["--verify", "--root", fixture])
            check("e2e: ONE stale size is caught", code == A.EXIT_DRIFT, f"exit {code}")
            check("e2e: the drift report names the stale file", "Icon-83.5@2x.png" in text and "DRIFT" in text)
            check("e2e: the drift report does not accuse the clean files", text.count("DRIFT") == 1, text)

            # A target that is not an 8-bit RGB PNG at all — the shape the five
            # Android launcher icons were in (palette + tRNS) until S064. That is
            # a finding about that file, not an inability to measure.
            with open(written, "wb") as handle:
                handle.write(raw_png(w, h, pixels, depth=16))
            code, text = run_cli(["--verify", "--root", fixture])
            check("e2e: a nonconforming target is DRIFT (1), not could-not-measure (2)",
                  code == A.EXIT_DRIFT, f"exit {code}")
            check("e2e: the report says WHY the target was unreadable", "unreadable" in text, text)

            with open(written, "wb") as handle:
                handle.write(A.encode_png(w, h, pixels))

        # A missing master is "could not measure", never "in sync" and never "drift".
        os.remove(os.path.join(fixture, A.MASTER))
        code, text = run_cli(["--verify", "--root", fixture])
        check("e2e: a missing master is exit 2, not 0 or 1", code == A.EXIT_CANNOT_MEASURE, f"exit {code}")
        check("e2e: exit 2 says so out loud", "could not measure" in text)
    finally:
        shutil.rmtree(fixture, ignore_errors=True)


# --------------------------------------------------------------------------
# 8. The real tree: the plan must account for every committed icon PNG
# --------------------------------------------------------------------------


@section
def repo_plan_covers_disk():
    plan = dict(A.build_plan(A.REPO_ROOT))
    appiconset = os.path.join(A.REPO_ROOT, A.IOS_APPICONSET)
    if not os.path.isdir(appiconset):
        check("repo: AppIcon.appiconset is present", False, appiconset)
        return
    on_disk = {os.path.join(A.IOS_APPICONSET, n) for n in os.listdir(appiconset) if n.endswith(".png")}
    check(
        "repo: no PNG in AppIcon.appiconset is missing from Contents.json",
        on_disk <= set(plan),
        f"orphans: {sorted(on_disk - set(plan))}",
    )
    check(
        "repo: every icon Contents.json declares exists on disk",
        {p for p in plan if p.startswith(A.IOS_APPICONSET)} <= on_disk,
        f"missing: {sorted({p for p in plan if p.startswith(A.IOS_APPICONSET)} - on_disk)}",
    )
    check("repo: the plan covers all 15 iOS icons and 5 Android icons", len(plan) == 20, str(len(plan)))


# --------------------------------------------------------------------------

for _section in SECTIONS:
    try:
        _section()
    except Exception:  # a mutation that RAISES must still name the property it broke
        CHECKS += 1
        FAILURES.append(f"{_section.__name__}: raised {traceback.format_exc(limit=0).strip()}")

print(f"app_icons: {CHECKS} checks, {len(FAILURES)} failed")
for failure in FAILURES:
    print(f"  FAIL {failure}")
sys.exit(1 if FAILURES else 0)
