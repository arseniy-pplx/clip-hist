#!/usr/bin/env bash
# Builds ClipHist as a release-mode universal binary and wraps it into a .app bundle.
#
# Usage: scripts/build-app.sh [--arch arm64|x86_64|universal]
# Default arch: universal (arm64 + x86_64)
set -euo pipefail

ARCH="universal"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --arch) ARCH="$2"; shift 2 ;;
    *) echo "unknown flag: $1" >&2; exit 1 ;;
  esac
done

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT/build"
APP_DIR="$BUILD_DIR/ClipHist.app"
CONTENTS="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RES_DIR="$CONTENTS/Resources"

rm -rf "$BUILD_DIR"
mkdir -p "$MACOS_DIR" "$RES_DIR"

echo ">>> Building ClipHist (arch=$ARCH)"
cd "$ROOT"

build_one() {
  local triple="$1"
  swift build -c release --arch "$triple" 1>&2
  swift build -c release --arch "$triple" --show-bin-path
}

case "$ARCH" in
  arm64)
    BIN_DIR="$(build_one arm64)"
    cp "$BIN_DIR/ClipHist" "$MACOS_DIR/ClipHist"
    ;;
  x86_64)
    BIN_DIR="$(build_one x86_64)"
    cp "$BIN_DIR/ClipHist" "$MACOS_DIR/ClipHist"
    ;;
  universal)
    ARM_DIR="$(build_one arm64)"
    X86_DIR="$(build_one x86_64)"
    lipo -create -output "$MACOS_DIR/ClipHist" "$ARM_DIR/ClipHist" "$X86_DIR/ClipHist"
    ;;
  *) echo "invalid --arch: $ARCH" >&2; exit 1 ;;
esac

chmod +x "$MACOS_DIR/ClipHist"
cp "$ROOT/Resources/Info.plist" "$CONTENTS/Info.plist"

# Ad-hoc sign so the app runs without "damaged" warnings on the build machine.
codesign --force --deep --sign - "$APP_DIR" || true

echo ">>> Built: $APP_DIR"
ls -la "$APP_DIR/Contents/MacOS"
