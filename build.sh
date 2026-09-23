#!/usr/bin/env bash
#
# Builds the OpenCode Credit menu bar app.
#
# The project intentionally has no Xcode project and no third-party
# dependencies: it only needs the Swift toolchain shipped with Apple's
# Command Line Tools. Everything is compiled with a single `swiftc` call and
# assembled into a regular .app bundle.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${BUILD_DIR:-$ROOT/build}"
APP_NAME="OpenCode Credit"
EXECUTABLE="OpenCodeCredit"
APP_DIR="$BUILD_DIR/$APP_NAME.app"

# Apple Silicon only. Override with ARCH=x86_64 to experiment, but Intel Macs
# are not supported (see README).
ARCH="${ARCH:-arm64}"
DEPLOYMENT_TARGET="${DEPLOYMENT_TARGET:-13.0}"

# Collect every Swift source file, keeping the build resilient while the
# project grows.
SWIFT_FILES=()
while IFS= read -r -d '' file; do
  SWIFT_FILES+=("$file")
done < <(find "$ROOT/Sources" -name '*.swift' -print0)

if [ "${#SWIFT_FILES[@]}" -eq 0 ]; then
  echo "error: no Swift sources found under Sources/" >&2
  exit 1
fi

echo "Compiling ${#SWIFT_FILES[@]} Swift files (${ARCH}, macOS ${DEPLOYMENT_TARGET})..."

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

xcrun swiftc \
  -swift-version 5 \
  -O \
  -target "${ARCH}-apple-macos${DEPLOYMENT_TARGET}" \
  -framework AppKit \
  -framework WebKit \
  -framework ServiceManagement \
  -framework UserNotifications \
  -framework Security \
  "${SWIFT_FILES[@]}" \
  -o "$APP_DIR/Contents/MacOS/$EXECUTABLE"

cp "$ROOT/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"

# Ad-hoc signature: enough for macOS to run the bundle locally without a
# Developer ID. Downloaded copies still need the Gatekeeper workaround
# documented in the README.
codesign --force --deep --sign - "$APP_DIR" >/dev/null 2>&1 || true

echo "Built $APP_DIR"
