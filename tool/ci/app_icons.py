#!/usr/bin/env python3
"""Derive the whole app-icon raster set from the single brandkit master.

The 15 iOS PNGs in ``AppIcon.appiconset`` and the 5 Android ``mipmap-*``
launcher icons had no generator: they were hand-produced, one size at a time,
and the repo's own lesson **66** names the failure mode that invites — *a
generator (or a person) that silently skips one size leaves a stale icon at
exactly one scale factor, which is the one a tester's device will use.* Nothing
in the tree could tell you it had happened. It had: the Android five were still
the default blue Flutter logo from the m0.1 scaffold, through 116 builds.

So this tool is the instrument, not a convenience. Two properties matter:

* **The iOS target list is READ FROM ``Contents.json``**, never hardcoded here.
  A size the asset catalog declares is a size this tool emits, so the two
  cannot drift apart — which is the only way "every size was regenerated" can
  be checked rather than asserted.
* **It is deterministic and dependency-free** (stdlib ``zlib`` only — no
  Pillow, no ImageMagick, no ffmpeg). That is what lets ``--verify`` run as a
  hermetic CI gate: regenerate into memory and compare against what is
  committed. A verify that needed a native image library would be a verify that
  never ran.

``--verify`` compares **decoded pixels**, not file bytes. Two reasons, and the
first is the one that matters: zlib's compressed output is not guaranteed
identical across zlib versions, so a byte comparison would red on a CI runner
for a reason that has nothing to do with any icon — a false red that reads
exactly like a real one. The second is that pixels are the property worth
asserting: the committed icon *is* the correct downscale of the master, however
it happens to be deflated. ``--write`` is likewise pixel-triggered, so re-running
it on another machine does not churn 20 files that are already correct.

Downscaling is an exact area-average box filter computed **in linear light**
(sRGB decoded, averaged, re-encoded). Averaging sRGB code words directly is the
common shortcut and it darkens every edge; at 20px the mark is almost all edge.
All arithmetic is integer, so the output is bit-identical on every machine.

Usage::

    python3 tool/ci/app_icons.py --verify    # default; 0 in sync, 1 drift
    python3 tool/ci/app_icons.py --write     # regenerate in place

Exit codes follow this repo's taxonomy (ADR-041, ``appid_capabilities.py``):
**0** in sync / written · **1** drift · **2** could not measure. "Could not
measure" is a separate outcome on purpose (lesson **81**): a tool that cannot
read its input must say so, never report "no drift". The split is by *which*
input: an unreadable **master or Contents.json** is exit 2, because nothing can
be concluded about any icon. An unreadable **target** is exit 1 — a committed
icon that is not an 8-bit RGB PNG is a nonconforming icon, which is a finding,
not a blind spot.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import struct
import sys
import zlib
from array import array
from bisect import bisect_right

EXIT_OK = 0
EXIT_DRIFT = 1
EXIT_CANNOT_MEASURE = 2

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# The one master. Chosen by the founder on 2026-08-05 from the three candidate
# referents for "the previous icon" (see past-prompts.md S062, lesson 80).
MASTER = "brandkit/branding-assets/icons/hayati-appicon-ios-1024.png"

IOS_APPICONSET = "app/ios/Runner/Assets.xcassets/AppIcon.appiconset"

# Android launcher densities. These are platform constants (mdpi = 48dp @ 1x),
# not a local choice, so unlike the iOS list they have no manifest to read.
ANDROID_MIPMAPS = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}
ANDROID_RES = "app/android/app/src/main/res"

LIN_BITS = 20
LIN_SCALE = 1 << LIN_BITS


class CannotMeasure(Exception):
    """The input could not be read or is not a shape this tool supports."""


# --------------------------------------------------------------------------
# sRGB transfer, as integer lookup tables
# --------------------------------------------------------------------------


def _srgb_to_linear(c: float) -> float:
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


# TO_LINEAR[v] is the linear value of the 8-bit sRGB code word v.
TO_LINEAR = [round(_srgb_to_linear(v / 255.0) * LIN_SCALE) for v in range(256)]

# _THRESH[k] is the linear value exactly half-way between code words k and
# k+1, so bisect_right over it rounds a linear value to the NEAREST code word.
# Round-trip is exact by construction: TO_LINEAR[v] falls strictly inside
# (_THRESH[v-1], _THRESH[v]), so from_linear(TO_LINEAR[v]) == v for all v.
_THRESH = [round(_srgb_to_linear((k + 0.5) / 255.0) * LIN_SCALE) for k in range(255)]


def from_linear(lin: int) -> int:
    return bisect_right(_THRESH, lin)


# --------------------------------------------------------------------------
# PNG decode / encode (8-bit, non-interlaced, truecolour with or without alpha)
# --------------------------------------------------------------------------

PNG_MAGIC = b"\x89PNG\r\n\x1a\n"


def decode_png(data: bytes, origin: str) -> tuple[int, int, bytes]:
    """Return ``(width, height, rgb_bytes)``. Alpha must be fully opaque."""
    if data[:8] != PNG_MAGIC:
        raise CannotMeasure(f"{origin}: not a PNG")
    idat = bytearray()
    ihdr = None
    off = 8
    while off + 8 <= len(data):
        (length,) = struct.unpack(">I", data[off : off + 4])
        ctype = data[off + 4 : off + 8]
        body = data[off + 8 : off + 8 + length]
        if ctype == b"IHDR":
            ihdr = struct.unpack(">IIBBBBB", body)
        elif ctype == b"IDAT":
            idat += body
        off += 12 + length
    if ihdr is None:
        raise CannotMeasure(f"{origin}: no IHDR")
    width, height, depth, colour, compression, filt, interlace = ihdr
    if depth != 8 or colour not in (2, 6) or compression != 0 or filt != 0 or interlace != 0:
        raise CannotMeasure(
            f"{origin}: unsupported PNG (depth={depth} colour={colour} interlace={interlace}); "
            "this tool handles 8-bit non-interlaced RGB/RGBA only"
        )
    channels = 3 if colour == 2 else 4
    stride = width * channels
    try:
        raw = zlib.decompress(bytes(idat))
    except zlib.error as exc:  # pragma: no cover - corrupt input
        raise CannotMeasure(f"{origin}: IDAT is not valid zlib ({exc})") from None
    if len(raw) != height * (stride + 1):
        raise CannotMeasure(f"{origin}: IDAT length {len(raw)} does not match {width}x{height}")

    out = bytearray(height * stride)
    prev = bytearray(stride)
    pos = 0
    for y in range(height):
        ftype = raw[pos]
        pos += 1
        line = bytearray(raw[pos : pos + stride])
        pos += stride
        if ftype == 1:
            for i in range(channels, stride):
                line[i] = (line[i] + line[i - channels]) & 0xFF
        elif ftype == 2:
            for i in range(stride):
                line[i] = (line[i] + prev[i]) & 0xFF
        elif ftype == 3:
            for i in range(stride):
                left = line[i - channels] if i >= channels else 0
                line[i] = (line[i] + ((left + prev[i]) >> 1)) & 0xFF
        elif ftype == 4:
            for i in range(stride):
                a = line[i - channels] if i >= channels else 0
                b = prev[i]
                c = prev[i - channels] if i >= channels else 0
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pred = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[i] = (line[i] + pred) & 0xFF
        elif ftype != 0:
            raise CannotMeasure(f"{origin}: unknown filter type {ftype} on row {y}")
        out[y * stride : (y + 1) * stride] = line
        prev = line

    if channels == 3:
        return width, height, bytes(out)

    # An app icon must be opaque: Apple rejects a marketing icon with an alpha
    # channel outright, and a flatten would have to invent a background colour.
    # Refuse rather than guess one.
    alpha = out[3::4]
    if min(alpha) != 255:
        raise CannotMeasure(
            f"{origin}: {sum(1 for a in alpha if a != 255)} pixels are not opaque; "
            "an app icon master must have no transparency"
        )
    rgb = bytearray(width * height * 3)
    rgb[0::3] = out[0::4]
    rgb[1::3] = out[1::4]
    rgb[2::3] = out[2::4]
    return width, height, bytes(rgb)


def _chunk(ctype: bytes, body: bytes) -> bytes:
    return (
        struct.pack(">I", len(body))
        + ctype
        + body
        + struct.pack(">I", zlib.crc32(ctype + body) & 0xFFFFFFFF)
    )


def encode_png(width: int, height: int, rgb: bytes) -> bytes:
    """Encode 8-bit RGB with per-row adaptive filtering. No ancillary chunks.

    Deterministic: no timestamp, no text, no filter choice that depends on
    anything but the pixels. The output of this function IS the committed
    artefact, which is what makes ``--verify`` a byte comparison.
    """
    stride = width * 3
    lines = bytearray()
    prev = bytes(stride)
    for y in range(height):
        cur = rgb[y * stride : (y + 1) * stride]
        # None and Up only. Sub/Average/Paeth cost a Python-level branch per
        # byte for a few percent; this pair already handles the two structures
        # an icon has (flat fields -> Up, sharp horizontal edges -> None).
        none_cost = sum(b if b < 128 else 256 - b for b in cur)
        up = bytes((c - p) & 0xFF for c, p in zip(cur, prev))
        up_cost = sum(b if b < 128 else 256 - b for b in up)
        if up_cost < none_cost:
            lines += b"\x02" + up
        else:
            lines += b"\x00" + cur
        prev = cur
    return (
        PNG_MAGIC
        + _chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
        + _chunk(b"IDAT", zlib.compress(bytes(lines), 9))
        + _chunk(b"IEND", b"")
    )


# --------------------------------------------------------------------------
# Exact area-average resample, in linear light
# --------------------------------------------------------------------------


def _spans(src: int, dst: int) -> list[tuple[int, int, list[int]]]:
    """Coverage of each destination cell over source cells.

    Working in units where a source cell is ``dst`` wide and a destination cell
    is ``src`` wide, every weight is an integer and each destination cell's
    weights sum to exactly ``src``. Returns ``(first, last, weights)`` per
    destination cell, inclusive of ``last``.
    """
    out = []
    for i in range(dst):
        lo, hi = i * src, (i + 1) * src
        first, last = lo // dst, (hi - 1) // dst
        if first == last:
            out.append((first, last, [hi - lo]))
            continue
        weights = [(first + 1) * dst - lo]
        weights += [dst] * (last - first - 1)
        weights.append(hi - last * dst)
        out.append((first, last, weights))
    return out


def resize_rgb(width: int, height: int, rgb: bytes, out_w: int, out_h: int) -> bytes:
    if out_w == width and out_h == height:
        return rgb
    if out_w > width or out_h > height:
        raise CannotMeasure(
            f"refusing to upscale {width}x{height} -> {out_w}x{out_h}; "
            "the master must be at least as large as every target"
        )

    xspans = _spans(width, out_w)
    yspans = _spans(height, out_h)
    lut = TO_LINEAR

    # Horizontal pass, one source row at a time, via a per-row prefix sum so
    # the cost is O(height * out_w) rather than O(height * width).
    stride = width * 3
    # rows[c][y] -> array of out_w linear sums (each scaled by `width`)
    rows = [[None] * height for _ in range(3)]
    for y in range(height):
        line = rgb[y * stride : (y + 1) * stride]
        for c in range(3):
            vals = [lut[v] for v in line[c::3]]
            pre = array("q", [0] * (width + 1))
            acc = 0
            for x in range(width):
                acc += vals[x]
                pre[x + 1] = acc
            dst = array("q", [0] * out_w)
            for i, (first, last, weights) in enumerate(xspans):
                if first == last:
                    dst[i] = vals[first] * weights[0]
                else:
                    total = vals[first] * weights[0] + vals[last] * weights[-1]
                    if last - first > 1:
                        total += (pre[last] - pre[first + 1]) * out_w
                    dst[i] = total
            rows[c][y] = dst

    # Vertical pass, per destination column, again through a prefix sum.
    denom = width * height
    half = denom // 2
    out = bytearray(out_w * out_h * 3)
    for c in range(3):
        chan = rows[c]
        for i in range(out_w):
            column = [chan[y][i] for y in range(height)]
            pre = array("q", [0] * (height + 1))
            acc = 0
            for y in range(height):
                acc += column[y]
                pre[y + 1] = acc
            for j, (first, last, weights) in enumerate(yspans):
                if first == last:
                    total = column[first] * weights[0]
                else:
                    total = column[first] * weights[0] + column[last] * weights[-1]
                    if last - first > 1:
                        total += (pre[last] - pre[first + 1]) * out_h
                out[(j * out_w + i) * 3 + c] = from_linear((total + half) // denom)
    return bytes(out)


# --------------------------------------------------------------------------
# Targets
# --------------------------------------------------------------------------


def ios_targets(contents: dict, origin: str) -> dict[str, int]:
    """Map ``filename -> pixel size`` from an ``AppIcon.appiconset`` manifest.

    Two entries may legitimately share a filename (iPhone 20x20@2x and iPad
    40x40@1x are both 40px). They must agree on the pixel size; if they do not,
    the catalog itself is broken and no set of PNGs can satisfy it.
    """
    targets: dict[str, int] = {}
    images = contents.get("images")
    if not images:
        raise CannotMeasure(f"{origin}: no 'images' array")
    for entry in images:
        filename = entry.get("filename")
        if not filename:
            continue  # an unassigned slot is legal in an asset catalog
        try:
            base = float(entry["size"].split("x")[0])
            scale = int(entry["scale"].rstrip("x"))
        except (KeyError, ValueError) as exc:
            raise CannotMeasure(f"{origin}: unreadable size/scale in {entry!r} ({exc})") from None
        pixels = base * scale
        if pixels != int(pixels):
            raise CannotMeasure(f"{origin}: {entry['size']}@{entry['scale']} is not a whole pixel size")
        pixels = int(pixels)
        if filename in targets and targets[filename] != pixels:
            raise CannotMeasure(
                f"{origin}: {filename} is declared at both {targets[filename]}px and {pixels}px"
            )
        targets[filename] = pixels
    if not targets:
        raise CannotMeasure(f"{origin}: no image entries carry a filename")
    return targets


def build_plan(root: str) -> list[tuple[str, int]]:
    """Every ``(repo-relative path, pixel size)`` this tool owns."""
    manifest = os.path.join(root, IOS_APPICONSET, "Contents.json")
    try:
        with open(manifest, "rb") as handle:
            contents = json.load(handle)
    except (OSError, ValueError) as exc:
        raise CannotMeasure(f"{manifest}: {exc}") from None
    plan = [
        (os.path.join(IOS_APPICONSET, name), px)
        for name, px in sorted(ios_targets(contents, manifest).items())
    ]
    plan += [
        (os.path.join(ANDROID_RES, density, "ic_launcher.png"), px)
        for density, px in sorted(ANDROID_MIPMAPS.items())
    ]
    return plan


def render(root: str) -> dict[str, tuple[int, bytes]]:
    """Render every target from the master, as ``path -> (pixel size, RGB)``.

    Sizes are rendered once and shared: five of the twenty targets are duplicate
    dimensions (20x20@2x and 40x40@1x are both 40px, and so on).
    """
    master_path = os.path.join(root, MASTER)
    try:
        with open(master_path, "rb") as handle:
            master = handle.read()
    except OSError as exc:
        raise CannotMeasure(f"{master_path}: {exc}") from None
    width, height, rgb = decode_png(master, MASTER)

    plan = build_plan(root)
    cache: dict[int, bytes] = {}
    rendered: dict[str, tuple[int, bytes]] = {}
    for path, px in plan:
        if px not in cache:
            cache[px] = resize_rgb(width, height, rgb, px, px)
        rendered[path] = (px, cache[px])
    return rendered


def read_target(path: str) -> tuple[str, tuple[int, int, bytes] | None]:
    """Decode a committed icon. Returns ``(status, pixels)``; pixels is None on failure.

    An unreadable target is a finding about that target, never a reason to stop
    measuring the other nineteen.
    """
    try:
        with open(path, "rb") as handle:
            blob = handle.read()
    except OSError:
        return "absent", None
    try:
        return "ok", decode_png(blob, path)
    except CannotMeasure as exc:
        return f"unreadable ({exc.args[0].split(': ', 1)[-1]})", None


# --------------------------------------------------------------------------
# CLI
# --------------------------------------------------------------------------


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--verify", action="store_true", help="compare committed bytes to a fresh render (default)")
    mode.add_argument("--write", action="store_true", help="regenerate the icon set in place")
    parser.add_argument("--root", default=REPO_ROOT, help="repository root (default: inferred from this file)")
    args = parser.parse_args(argv)
    writing = args.write

    try:
        rendered = render(args.root)
    except CannotMeasure as exc:
        print(f"::error::could not measure: {exc}", file=sys.stderr)
        return EXIT_CANNOT_MEASURE

    drifted = 0
    for path in sorted(rendered):
        px, fresh = rendered[path]
        absolute = os.path.join(args.root, path)
        status, current = read_target(absolute)
        same = current == (px, px, fresh)
        expected = hashlib.sha256(fresh).hexdigest()[:12]
        if current is None:
            was = status
        elif same:
            was = expected
        else:
            was = f"{current[0]}x{current[1]} {hashlib.sha256(current[2]).hexdigest()[:12]}"
        if writing:
            if not same:
                os.makedirs(os.path.dirname(absolute), exist_ok=True)
                with open(absolute, "wb") as handle:
                    handle.write(encode_png(px, px, fresh))
                drifted += 1
            state = "unchanged" if same else f"WROTE  {was} -> {px}x{px} {expected}"
        else:
            if not same:
                drifted += 1
            state = "ok" if same else f"DRIFT  committed={was} expected={px}x{px} {expected}"
        print(f"{path:72s} {px:5d}px  {state}")

    if writing:
        print(f"\n{drifted} of {len(rendered)} files rewritten from {MASTER}")
        return EXIT_OK
    if drifted:
        print(
            f"\n::error::{drifted} of {len(rendered)} icons are not the pixels of a fresh render of "
            f"{MASTER}. Run: python3 tool/ci/app_icons.py --write",
            file=sys.stderr,
        )
        return EXIT_DRIFT
    print(f"\nall {len(rendered)} icons match {MASTER}")
    return EXIT_OK


if __name__ == "__main__":
    sys.exit(main())
