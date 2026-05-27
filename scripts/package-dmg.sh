#!/usr/bin/env bash
# Packages build/ClipHist.app into a polished installer .dmg.
#
# Uses `create-dmg` (https://github.com/create-dmg/create-dmg) for the layout —
# it positions ClipHist.app and the Applications shortcut side by side over a
# custom background image with a "drag to install" hint.
#
# Requires Homebrew on the build runner: `brew install create-dmg`.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/ClipHist.app"
DMG_DIR="$ROOT/build"
DMG="$DMG_DIR/ClipHist.dmg"
BG="$ROOT/scripts/build/dmg-background.png"
ICON="$ROOT/scripts/build/AppIcon.icns"

if [[ ! -d "$APP" ]]; then
  echo "ClipHist.app not found. Run scripts/build-app.sh first." >&2
  exit 1
fi

# Regenerate background + icon (idempotent, cheap).
python3 "$ROOT/scripts/make-dmg-background.py" >/dev/null
bash "$ROOT/scripts/make-icon.sh" >/dev/null || true

rm -f "$DMG"

if ! command -v create-dmg >/dev/null 2>&1; then
  echo "create-dmg not installed — falling back to plain hdiutil DMG." >&2
  STAGE="$DMG_DIR/dmg-stage"
  rm -rf "$STAGE"
  mkdir -p "$STAGE"
  cp -R "$APP" "$STAGE/"
  ln -s /Applications "$STAGE/Applications"
  hdiutil create -volname "ClipHist" -srcfolder "$STAGE" -ov -format UDZO "$DMG"
  rm -rf "$STAGE"
  echo ">>> DMG: $DMG"
  exit 0
fi

CREATE_DMG_ARGS=(
  --volname "ClipHist Installer"
  --window-pos 200 120
  --window-size 540 380
  --icon-size 96
  --icon "ClipHist.app" 140 210
  --hide-extension "ClipHist.app"
  --app-drop-link 400 210
  --no-internet-enable
)

if [[ -f "$BG" ]]; then
  CREATE_DMG_ARGS+=(--background "$BG")
fi
if [[ -f "$ICON" ]]; then
  CREATE_DMG_ARGS+=(--volicon "$ICON")
fi

create-dmg "${CREATE_DMG_ARGS[@]}" "$DMG" "$APP"

echo ">>> DMG: $DMG"
