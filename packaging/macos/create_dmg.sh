#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APP_VERSION="${APP_VERSION:-$(sed -n 's/^version: \([^+]*\).*/\1/p' "$ROOT_DIR/pubspec.yaml")}"
RELEASE_DIR="$ROOT_DIR/build/macos/Build/Products/Release"
DIST_DIR="$ROOT_DIR/dist"
STAGING_DIR="$ROOT_DIR/build/macos-dmg/Sitzplan"
DMG_PATH="$DIST_DIR/Sitzplan-${APP_VERSION}-macos.dmg"

APP_PATH="$(find "$RELEASE_DIR" -maxdepth 1 -name '*.app' -print -quit)"
if [[ -z "$APP_PATH" ]]; then
  echo "No macOS .app bundle found in $RELEASE_DIR" >&2
  exit 1
fi

MACHINE_ARCH="$(uname -m)"
FFMPEG_ARCH="x64"
if [[ "$MACHINE_ARCH" == "arm64" ]]; then
  FFMPEG_ARCH="arm64"
fi
"$ROOT_DIR/packaging/bundle_ffmpeg.sh" \
  "$APP_PATH/Contents/Resources" \
  "darwin-$FFMPEG_ARCH"
mv "$APP_PATH/Contents/Resources/ffmpeg" "$APP_PATH/Contents/MacOS/ffmpeg"
codesign --force --sign - \
  --entitlements "$ROOT_DIR/macos/Runner/Ffmpeg.entitlements" \
  "$APP_PATH/Contents/MacOS/ffmpeg"
codesign --force --sign - \
  --entitlements "$ROOT_DIR/macos/Runner/Release.entitlements" \
  "$APP_PATH"
codesign --verify --deep --strict "$APP_PATH"

rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR" "$DIST_DIR"
cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

rm -f "$DMG_PATH"
hdiutil create \
  -volname "Sitzplan ${APP_VERSION}" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"
