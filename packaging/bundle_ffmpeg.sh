#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 || $# -gt 3 ]]; then
  echo "Usage: $0 TARGET_DIR PLATFORM_ARCH [EXECUTABLE_NAME]" >&2
  exit 2
fi

TARGET_DIR="$1"
PLATFORM_ARCH="$2"
EXECUTABLE_NAME="${3:-ffmpeg}"
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT

case "$PLATFORM_ARCH" in
  win32-x64)
    ARCHIVE_NAME="ffmpeg-n9.0.1-27-g9b0578816c-win64-gpl-9.0.zip"
    ARCHIVE_URL="https://github.com/BtbN/FFmpeg-Builds/releases/download/autobuild-2026-09-08-23-15/$ARCHIVE_NAME"
    ARCHIVE_SHA256="97f63a0d966351031c4fd9bd8c74d67cb42093907594add2a62ae59c9abd3e7e"
    SOURCE_NAME="BtbN FFmpeg Builds"
    ;;
  linux-x64)
    ARCHIVE_NAME="ffmpeg-n9.0.1-27-g9b0578816c-linux64-gpl-9.0.tar.xz"
    ARCHIVE_URL="https://github.com/BtbN/FFmpeg-Builds/releases/download/autobuild-2026-09-08-23-15/$ARCHIVE_NAME"
    ARCHIVE_SHA256="6483bb419026c92ba6776d79f5dd651189748c0b61e2c704af50692fe720aa5d"
    SOURCE_NAME="BtbN FFmpeg Builds"
    ;;
  darwin-x64)
    ARCHIVE_NAME="ffmpeg-9.0.1.zip"
    ARCHIVE_URL="https://evermeet.cx/ffmpeg/$ARCHIVE_NAME"
    ARCHIVE_SHA256="8a8c9e549983409fe6604b9aa665648b7a5def9407fe814c39c8b2ea7f64a48f"
    SOURCE_NAME="evermeet.cx"
    ;;
  *)
    echo "Unsupported FFmpeg platform: $PLATFORM_ARCH" >&2
    exit 2
    ;;
esac

mkdir -p "$TARGET_DIR"
curl --fail --location --retry 3 \
  --output "$TEMP_DIR/$ARCHIVE_NAME" \
  "$ARCHIVE_URL"

if command -v sha256sum >/dev/null 2>&1; then
  printf '%s  %s\n' "$ARCHIVE_SHA256" "$TEMP_DIR/$ARCHIVE_NAME" | sha256sum --check --status
else
  ACTUAL_SHA256="$(shasum -a 256 "$TEMP_DIR/$ARCHIVE_NAME" | awk '{print $1}')"
  [[ "$ACTUAL_SHA256" == "$ARCHIVE_SHA256" ]]
fi

mkdir -p "$TEMP_DIR/extracted"
tar -xf "$TEMP_DIR/$ARCHIVE_NAME" -C "$TEMP_DIR/extracted"
FFMPEG_PATH="$(find "$TEMP_DIR/extracted" -type f \( -name ffmpeg -o -name ffmpeg.exe \) -print -quit)"
if [[ -z "$FFMPEG_PATH" ]]; then
  echo "FFmpeg executable missing from $ARCHIVE_NAME" >&2
  exit 1
fi
cp "$FFMPEG_PATH" "$TARGET_DIR/$EXECUTABLE_NAME"
chmod +x "$TARGET_DIR/$EXECUTABLE_NAME"

curl --fail --location --retry 3 \
  --output "$TARGET_DIR/FFMPEG-LICENSE.txt" \
  "https://raw.githubusercontent.com/FFmpeg/FFmpeg/n9.0.1/COPYING.GPLv3"
{
  echo "Bundled FFmpeg 9.0.1 camera runtime"
  echo "Binary source: $SOURCE_NAME"
  echo "Archive: $ARCHIVE_URL"
  echo "Archive SHA-256: $ARCHIVE_SHA256"
  echo "Corresponding source: https://github.com/FFmpeg/FFmpeg/tree/n9.0.1"
  echo "Build project: https://github.com/BtbN/FFmpeg-Builds"
  echo "License: GPL-3.0-or-later (see FFMPEG-LICENSE.txt)"
} > "$TARGET_DIR/FFMPEG-README.txt"

"$TARGET_DIR/$EXECUTABLE_NAME" -hide_banner -version
