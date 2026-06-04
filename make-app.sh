#!/usr/bin/env bash
# Assemble PrimeEye.app from the SPM release binary + Info.plist, then ad-hoc sign.
# Every input is plain text in this repo - no Xcode project, no third-party tooling.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP="$ROOT/PrimeEye.app"
BIN_NAME="PrimeEye"

# --show-bin-path only prints the computed path (no build), so resolve it first, then build once.
BIN_DIR="$(swift build -c release --package-path "$ROOT" --show-bin-path)"
echo "==> swift build -c release"
swift build -c release --package-path "$ROOT"
BUILT="$BIN_DIR/$BIN_NAME"
if [[ ! -x "$BUILT" ]]; then
  echo "ERROR: built binary not found at $BUILT" >&2
  exit 1
fi

echo "==> assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BUILT" "$APP/Contents/MacOS/$BIN_NAME"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"

# Prefer the stable self-signed identity (so the camera TCC grant survives rebuilds).
# Falls back to ad-hoc ("-") if it is not installed - run ./create-signing-identity.sh once.
IDENTITY="PrimeEye Self-Signed"
# Detect via find-certificate (by name): a self-signed cert is usable by `codesign --sign`
# even though it is untrusted and therefore hidden from `find-identity -p codesigning`.
if security find-certificate -c "$IDENTITY" >/dev/null 2>&1; then
  SIGN="$IDENTITY"
  echo "==> codesign with '$IDENTITY' (stable identity)"
else
  SIGN="-"
  echo "==> ad-hoc codesign (run ./create-signing-identity.sh for a stable camera grant)"
fi
codesign --force --deep --sign "$SIGN" "$APP"

echo "==> built $APP"
echo "Run it with:  open \"$APP\"   (or:  \"$APP/Contents/MacOS/$BIN_NAME\")"
