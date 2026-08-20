#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 || $# -gt 3 ]]; then
  echo "Usage: $0 TARGET_DIR PLATFORM_ARCH [EXECUTABLE_NAME]" >&2
  exit 2
fi

TARGET_DIR="$1"
PLATFORM_ARCH="$2"
EXECUTABLE_NAME="${3:-ffmpeg}"
BASE_URL="https://github.com/eugeneware/ffmpeg-static/releases/latest/download"
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT

mkdir -p "$TARGET_DIR"
curl --fail --location --retry 3 \
  --output "$TEMP_DIR/ffmpeg.gz" \
  "$BASE_URL/ffmpeg-${PLATFORM_ARCH}.gz"
gzip --decompress --stdout "$TEMP_DIR/ffmpeg.gz" > "$TARGET_DIR/$EXECUTABLE_NAME"
chmod +x "$TARGET_DIR/$EXECUTABLE_NAME"

curl --fail --location --retry 3 \
  --output "$TARGET_DIR/FFMPEG-LICENSE.txt" \
  "$BASE_URL/${PLATFORM_ARCH}.LICENSE"
curl --fail --location --retry 3 \
  --output "$TARGET_DIR/FFMPEG-README.txt" \
  "$BASE_URL/${PLATFORM_ARCH}.README"
