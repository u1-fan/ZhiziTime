#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION_INPUT="${1:-$(tr -d '[:space:]' < "$ROOT/Sources/ZhiziTime/Resources/VERSION")}"
VERSION="${VERSION_INPUT#v}"
APP_NAME="ZhiziTime"
ARCH="$(uname -m)"
DIST_DIR="$ROOT/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
DMG_NAME="$APP_NAME-v${VERSION}-macOS-${ARCH}.dmg"
FEED_NAME="appcast.xml"
if [[ "$ARCH" == "x86_64" ]]; then FEED_NAME="appcast-x86_64.xml"; fi
DMG_PATH="$DIST_DIR/$DMG_NAME"
CHECKSUM_PATH="$DMG_PATH.sha256"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/zhizitime-package.XXXXXX")"
DMG_ROOT="$WORK_DIR/dmg-root"
trap 'rm -rf "$WORK_DIR"' EXIT

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$ ]]; then
  echo "invalid version: $VERSION_INPUT" >&2
  exit 2
fi
case "$ARCH" in
  arm64|x86_64) ;;
  *) echo "unsupported macOS architecture: $ARCH" >&2; exit 2 ;;
esac

cd "$ROOT"
swift build -c release --product "$APP_NAME"
BUILT_DIR="$(swift build -c release --show-bin-path)"
BUILT_BINARY="$BUILT_DIR/$APP_NAME"
RESOURCE_BUNDLE="$BUILT_DIR/${APP_NAME}_${APP_NAME}.bundle"
[[ -x "$BUILT_BINARY" ]]

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
install -m 755 "$BUILT_BINARY" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
if [[ -d "$RESOURCE_BUNDLE" ]]; then
  /usr/bin/ditto "$RESOURCE_BUNDLE" "$APP_BUNDLE/Contents/Resources/${APP_NAME}_${APP_NAME}.bundle"
fi
install -m 644 "$ROOT/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
install -m 644 "$ROOT/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP_BUNDLE/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "$APP_BUNDLE/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :SUFeedURL https://github.com/u1-fan/ZhiziTime/releases/latest/download/$FEED_NAME" "$APP_BUNDLE/Contents/Info.plist"

PUBLIC_KEY_FILE="$ROOT/config/sparkle-public-key.txt"
if [[ -s "$PUBLIC_KEY_FILE" ]]; then
  PUBLIC_KEY="$(tr -d '[:space:]' < "$PUBLIC_KEY_FILE")"
  /usr/libexec/PlistBuddy -c "Set :SUPublicEDKey $PUBLIC_KEY" "$APP_BUNDLE/Contents/Info.plist" \
    || /usr/libexec/PlistBuddy -c "Add :SUPublicEDKey string $PUBLIC_KEY" "$APP_BUNDLE/Contents/Info.plist"
fi

"$ROOT/scripts/embed_sparkle.sh" "$APP_BUNDLE"
"$ROOT/scripts/sign_macos_app.sh" "$APP_BUNDLE" "${ZHIZI_SIGNING_IDENTITY:--}"

mkdir -p "$DMG_ROOT"
/usr/bin/ditto "$APP_BUNDLE" "$DMG_ROOT/$APP_NAME.app"
ln -s /Applications "$DMG_ROOT/Applications"
rm -f "$DMG_PATH" "$CHECKSUM_PATH"
hdiutil create -volname "$APP_NAME $VERSION" -srcfolder "$DMG_ROOT" -ov -format ULMO "$DMG_PATH"

if [[ "${ZHIZI_SIGNING_IDENTITY:--}" == "Developer ID Application:"* ]]; then
  codesign --force --sign "$ZHIZI_SIGNING_IDENTITY" --timestamp "$DMG_PATH"
  codesign --verify --verbose=2 "$DMG_PATH"
fi

hdiutil verify "$DMG_PATH"
(cd "$DIST_DIR" && shasum -a 256 "$DMG_NAME" > "$DMG_NAME.sha256")
echo "created $DMG_PATH"
