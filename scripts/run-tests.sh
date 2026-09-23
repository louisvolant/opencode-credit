#!/usr/bin/env bash
#
# Compiles and runs the unit tests for the core logic. Uses the same
# dependency-free approach as build.sh: a single swiftc call.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$ROOT/build/tests"
BINARY="$OUT_DIR/OpenCodeCreditTests"
ARCH="${ARCH:-arm64}"
DEPLOYMENT_TARGET="${DEPLOYMENT_TARGET:-13.0}"

mkdir -p "$OUT_DIR"

SWIFT_FILES=()
while IFS= read -r -d '' file; do
  SWIFT_FILES+=("$file")
done < <(find "$ROOT/Sources/Core" "$ROOT/Tests" -name '*.swift' -print0)

echo "Compiling ${#SWIFT_FILES[@]} files for tests..."
xcrun swiftc \
  -swift-version 5 \
  -target "${ARCH}-apple-macos${DEPLOYMENT_TARGET}" \
  -framework Security \
  "${SWIFT_FILES[@]}" \
  -o "$BINARY"

"$BINARY"
