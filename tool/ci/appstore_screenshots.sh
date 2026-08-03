#!/usr/bin/env bash
# Render the App Store screenshot set from the app's own widgets.
#
# OPERATOR-RUN, not CI-run. It lives under tool/ci/ for one reason: that is the
# directory ci.yml shellchecks, and a release-facing shell script with no static
# check is the ADR-024 lesson this repo already paid for once. Nothing in
# ci.yml calls it.
#
# WHAT IT IS NOT: a simulator, a device farm, or a Mac. `flutter test` renders
# widgets on the host with a software rasterizer, so this produces real pixels
# of real screens on Linux, at exactly the size App Store Connect demands.
#
# Usage:  tool/ci/appstore_screenshots.sh
# Output: app/build/appstore/screenshots/{tr,en}/*.png
set -euo pipefail

# 6.9" iPhone (16/15 Pro Max class). App Store Connect's iPhone slot takes
# 1290x2796 or 1320x2868 and scales every smaller device down from it, so this
# single set is the whole iPhone requirement. The app is iPhone-only since
# #179, so there is no iPad set to render.
SURFACE="${APPSTORE_SCREENSHOT_SURFACE:-1290x2796@3.0}"
EXPECTED_W="${SURFACE%x*}"
rest="${SURFACE#*x}"
EXPECTED_H="${rest%@*}"

cd "$(dirname "$0")/../../app"

echo "rendering at ${SURFACE} ..."
rm -rf build/appstore
APPSTORE_SCREENSHOT_SURFACE="$SURFACE" \
  flutter test screenshots/appstore_screenshots_test.dart

# VERIFY THE PIXELS, not the exit code. The generator is a widget test: it goes
# green whenever it does not throw, including if the surface override were
# silently ignored and every file came out 390x844. App Store Connect would
# then reject the upload hours later with nothing pointing back here. Reading
# the PNG's own IHDR is the only check that cannot agree with a wrong
# assumption — and an empty output directory must fail too, not pass vacuously.
python3 - "$EXPECTED_W" "$EXPECTED_H" <<'PY'
import pathlib
import struct
import sys

want = (int(sys.argv[1]), int(sys.argv[2]))
root = pathlib.Path("build/appstore/screenshots")
files = sorted(root.rglob("*.png"))
if not files:
    sys.exit(f"FAIL: no PNGs under {root} — the generator wrote nothing")

bad = []
for f in files:
    with f.open("rb") as fh:
        got = struct.unpack(">II", fh.read(24)[16:24])
    flag = "ok " if got == want else "BAD"
    if got != want:
        bad.append(f"{f}: {got[0]}x{got[1]}")
    print(f"  {flag} {got[0]}x{got[1]}  {f}")

print(f"\n{len(files)} screenshots at {want[0]}x{want[1]}")
if bad:
    sys.exit("FAIL: wrong size — " + "; ".join(bad))
PY

echo
echo "upload from: app/build/appstore/screenshots/{tr,en}/"

# --stage copies the set where `deliver` looks, applying the ONE mapping that
# differs between the two worlds: the app's locale is `en`, App Store Connect's
# is `en-US` (and `fastlane/metadata/en-US/` already spells it that way). Kept
# here rather than in the workflow so the mapping is reviewed as code, and it
# is opt-in so a plain render never writes outside build/.
if [ "${1:-}" = "--stage" ]; then
  staged="../fastlane/screenshots"
  rm -rf "$staged"
  mkdir -p "$staged/en-US" "$staged/tr"
  cp build/appstore/screenshots/en/*.png "$staged/en-US/"
  cp build/appstore/screenshots/tr/*.png "$staged/tr/"
  echo
  echo "staged for deliver:"
  # shellcheck disable=SC2012  # ls is fine here: our own filenames, no spaces.
  ls "$staged"/*/ | sed 's/^/  /'
fi
