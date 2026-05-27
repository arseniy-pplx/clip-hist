#!/usr/bin/env bash
# Packages build/ClipHist.app into a distributable .dmg.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/ClipHist.app"
DMG="$ROOT/build/ClipHist.dmg"
STAGE="$ROOT/build/dmg-stage"

if [[ ! -d "$APP" ]]; then
  echo "ClipHist.app not found. Run scripts/build-app.sh first." >&2
  exit 1
fi

rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

hdiutil create \
  -volname "ClipHist" \
  -srcfolder "$STAGE" \
  -ov \
  -format UDZO \
  "$DMG"

rm -rf "$STAGE"
echo ">>> DMG: $DMG"
