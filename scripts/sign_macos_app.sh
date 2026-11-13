#!/usr/bin/env bash
set -euo pipefail

APP_BUNDLE="${1:?usage: sign_macos_app.sh <app-bundle> [identity]}"
IDENTITY="${2:-${ZHIZI_SIGNING_IDENTITY:--}}"

is_developer_id() {
  [[ "$IDENTITY" == "Developer ID Application:"* ]] && return 0
  security find-identity -v -p codesigning 2>/dev/null \
    | grep -Eq "^ *[0-9]+\) *${IDENTITY} *\"Developer ID Application:"
}

SIGN_ARGS=(--force --sign "$IDENTITY")
if [[ "$IDENTITY" != "-" ]] && is_developer_id; then
  SIGN_ARGS+=(--options runtime --timestamp)
fi

SPARKLE_FRAMEWORK="$APP_BUNDLE/Contents/Frameworks/Sparkle.framework"
if [[ -d "$SPARKLE_FRAMEWORK" ]]; then
  SPARKLE_VERSION="$SPARKLE_FRAMEWORK/Versions/B"
  codesign "${SIGN_ARGS[@]}" --preserve-metadata=entitlements "$SPARKLE_VERSION/XPCServices/Installer.xpc"
  codesign "${SIGN_ARGS[@]}" --preserve-metadata=entitlements "$SPARKLE_VERSION/XPCServices/Downloader.xpc"
  codesign "${SIGN_ARGS[@]}" "$SPARKLE_VERSION/Autoupdate"
  codesign "${SIGN_ARGS[@]}" --preserve-metadata=entitlements "$SPARKLE_VERSION/Updater.app"
  # Sign the concrete framework version; the top-level Sparkle.framework path
  # is a symlink bundle and can be reported as an ambiguous format by newer
  # macOS codesign implementations.
  codesign "${SIGN_ARGS[@]}" --preserve-metadata=entitlements "$SPARKLE_VERSION"
fi

codesign "${SIGN_ARGS[@]}" "$APP_BUNDLE"
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
