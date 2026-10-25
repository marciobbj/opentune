#!/usr/bin/env bash
set -euo pipefail

# Builds the macOS drag-and-drop installer disk image (OpenTune-macOS.dmg).
# When opened, the user sees OpenTune.app on the left and Applications on the right.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

OUTPUT_DMG="${1:-OpenTune-macOS.dmg}"
RELEASE_DIR="build/macos/Build/Products/Release"

if [ -d "$RELEASE_DIR/OpenTune.app" ]; then
  APP_BUNDLE="$RELEASE_DIR/OpenTune.app"
elif [ -d "$RELEASE_DIR/opentune.app" ]; then
  echo "Staging $RELEASE_DIR/opentune.app as $RELEASE_DIR/OpenTune.app..."
  rm -rf "$RELEASE_DIR/OpenTune.app"
  cp -R "$RELEASE_DIR/opentune.app" "$RELEASE_DIR/OpenTune.app"
  APP_BUNDLE="$RELEASE_DIR/OpenTune.app"
else
  echo "Error: Could not find built macOS .app bundle in $RELEASE_DIR" >&2
  echo "Run 'flutter build macos --release' first." >&2
  exit 1
fi

# Ensure ad-hoc signature is valid while preserving Release.entitlements
# (sandbox + user-selected file read/write + security-scoped bookmarks)
codesign --force --deep --sign - "$APP_BUNDLE"
if [ -f "$ROOT_DIR/macos/Runner/Release.entitlements" ]; then
  codesign --force --sign - --entitlements "$ROOT_DIR/macos/Runner/Release.entitlements" "$APP_BUNDLE"
fi

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

# 1. Use the compiled AppIcon.icns from the .app bundle for the DMG volume icon
ICON_ICNS="$APP_BUNDLE/Contents/Resources/AppIcon.icns"

# 2. Generate custom dark background PNG (660x400) with a sleek drag-to-Applications arrow
BG_PNG="$WORK_DIR/dmg_background.png"
python3 - "$BG_PNG" <<'PYEOF'
import math
import struct
import sys
import zlib

out_path = sys.argv[1]
W, H = 660, 400

rows = []
cx, cy = W // 2, 190

for y in range(H):
    row = bytearray([0])  # PNG filter type 0
    t_y = y / (H - 1)
    # Dark slate/navy vertical gradient (#0E1422 -> #161F33)
    base_r = int(14 + 8 * t_y)
    base_g = int(20 + 11 * t_y)
    base_b = int(34 + 17 * t_y)

    for x in range(W):
        r, g, b = base_r, base_g, base_b

        # Subtle radial glow in center
        dx = (x - cx) / 260.0
        dy = (y - cy) / 160.0
        dist2 = dx * dx + dy * dy
        if dist2 < 1.0:
            glow = (1.0 - dist2) ** 2
            r = min(255, int(r + 12 * glow))
            g = min(255, int(g + 22 * glow))
            b = min(255, int(b + 40 * glow))

        # Draw modern arrow pointing right in the center (x in [292, 368], y around 190)
        # Shaft: x in [294, 350], |y - cy| <= 4
        # Chevron head: tip at (368, cy), arms of length 22 at 40 degrees
        in_arrow = False
        alpha = 0.0

        # Rounded shaft
        if 294 <= x <= 354 and abs(y - cy) <= 4.5:
            dist_edge = 4.5 - abs(y - cy)
            alpha = max(alpha, min(1.0, dist_edge))

        # Chevron upper and lower arms meeting at (366, cy)
        # Line from (344, cy - 20) to (366, cy) and (344, cy + 20) to (366, cy)
        for sign in (-1, 1):
            x0, y0 = 344.0, cy + sign * 20.0
            x1, y1 = 366.0, float(cy)
            vx, vy = x1 - x0, y1 - y0
            wx, wy = x - x0, y - y0
            seg_len2 = vx * vx + vy * vy
            proj = max(0.0, min(1.0, (wx * vx + wy * vy) / seg_len2))
            px, py = x0 + proj * vx, y0 + proj * vy
            d = math.hypot(x - px, y - py)
            if d <= 4.5:
                alpha = max(alpha, min(1.0, 4.5 - d))

        if alpha > 0:
            # Accent cyan/blue arrow (#58A6FF)
            ar, ag, ab = 110, 175, 255
            r = int(r * (1.0 - alpha) + ar * alpha)
            g = int(g * (1.0 - alpha) + ag * alpha)
            b = int(b * (1.0 - alpha) + ab * alpha)

        row.extend((r, g, b))
    rows.append(bytes(row))

raw_data = b"".join(rows)

def png_chunk(chunk_type: bytes, data: bytes) -> bytes:
    crc = zlib.crc32(chunk_type + data) & 0xFFFFFFFF
    return struct.pack(">I", len(data)) + chunk_type + data + struct.pack(">I", crc)

ihdr = struct.pack(">IIBBBBB", W, H, 8, 2, 0, 0, 0)
idat = zlib.compress(raw_data, 9)
png = (
    b"\x89PNG\r\n\x1a\n"
    + png_chunk(b"IHDR", ihdr)
    + png_chunk(b"IDAT", idat)
    + png_chunk(b"IEND", b"")
)

with open(out_path, "wb") as f:
    f.write(png)
PYEOF

# 3. Install dmgbuild inside a temporary venv if not already available
if command -v dmgbuild >/dev/null 2>&1; then
  DMGBUILD_CMD="dmgbuild"
else
  echo "Setting up dmgbuild in temporary Python environment..."
  python3 -m venv "$WORK_DIR/venv"
  "$WORK_DIR/venv/bin/pip" install --quiet dmgbuild
  DMGBUILD_CMD="$WORK_DIR/venv/bin/dmgbuild"
fi

rm -f "$OUTPUT_DMG"
echo "Building $OUTPUT_DMG..."
"$DMGBUILD_CMD" \
  -s "$ROOT_DIR/scripts/dmg_settings.py" \
  -D app_path="$APP_BUNDLE" \
  -D background_path="$BG_PNG" \
  -D icon_path="$ICON_ICNS" \
  "OpenTune" \
  "$OUTPUT_DMG"

echo "Successfully created macOS installer: $OUTPUT_DMG"
