#!/usr/bin/env bash
set -euo pipefail

APP_BUNDLE="${1:?usage: embed_sparkle.sh <app-bundle>}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ARCH="$(uname -m)"
case "$ARCH" in
  arm64|x86_64) ;;
  *) echo "unsupported macOS architecture: $ARCH" >&2; exit 2 ;;
esac

ARTIFACTS="$ROOT/.build/artifacts"
FRAMEWORK_SOURCE="$(find "$ARTIFACTS" -type d -path '*/Sparkle.xcframework/*/Sparkle.framework' -print -quit 2>/dev/null || true)"
if [[ -z "$FRAMEWORK_SOURCE" ]]; then
  echo "Sparkle.framework missing from SwiftPM artifacts; run swift build first" >&2
  exit 1
fi

FRAMEWORK_DEST="$APP_BUNDLE/Contents/Frameworks/Sparkle.framework"
mkdir -p "$APP_BUNDLE/Contents/Frameworks"
rm -rf "$FRAMEWORK_DEST"
/usr/bin/ditto "$FRAMEWORK_SOURCE" "$FRAMEWORK_DEST"

while IFS= read -r -d '' binary; do
  if ! lipo "$binary" -verify_arch "$ARCH" 2>/dev/null; then
    echo "Sparkle binary does not support $ARCH: $binary" >&2
    exit 1
  fi
  if [[ "$(lipo -archs "$binary")" != "$ARCH" ]]; then
    lipo "$binary" -thin "$ARCH" -output "$binary"
  fi
done < <(find "$FRAMEWORK_DEST/Versions" -type f -perm -u+x -print0)

rm -rf "$FRAMEWORK_DEST/Headers" "$FRAMEWORK_DEST/PrivateHeaders" "$FRAMEWORK_DEST/Modules" \
  "$FRAMEWORK_DEST/Versions/B/Headers" "$FRAMEWORK_DEST/Versions/B/PrivateHeaders" "$FRAMEWORK_DEST/Versions/B/Modules"
