#!/usr/bin/env bash
#
# Builds the app and produces a distributable zip in dist/.
# Also prints the SHA-256 of the zip (the Homebrew tap recomputes it
# automatically from the release).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST="$ROOT/dist"

"$ROOT/build.sh"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/Resources/Info.plist")"
APP="$ROOT/build/OpenCode Credit.app"
ZIP="$DIST/OpenCodeCredit-$VERSION.zip"

mkdir -p "$DIST"
rm -f "$ZIP"

# ditto keeps the bundle structure and metadata intact.
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"

echo "Packaged $ZIP"
echo "SHA-256: $(shasum -a 256 "$ZIP" | awk '{print $1}')"
