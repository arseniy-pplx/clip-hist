#!/usr/bin/env bash
# Generate AppIcon.icns from rendered PNGs.
# Step 1: scripts/make-icon.py renders the iconset PNGs (cross-platform via Pillow).
# Step 2: iconutil packs them into a .icns (macOS only).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ICONSET="$ROOT/scripts/build/AppIcon.iconset"
ICNS="$ROOT/scripts/build/AppIcon.icns"

python3 "$ROOT/scripts/make-icon.py"

if ! command -v iconutil >/dev/null 2>&1; then
  echo "iconutil not found — skipping .icns assembly (expected on non-macOS)." >&2
  exit 0
fi

iconutil --convert icns --output "$ICNS" "$ICONSET"
echo ">>> Built: $ICNS"
