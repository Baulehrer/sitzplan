#!/usr/bin/env bash
set -euo pipefail

ARCH="${ARCH:-x86_64}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APP_VERSION="${APP_VERSION:-$(sed -n 's/^version: \([^+]*\).*/\1/p' "$ROOT_DIR/pubspec.yaml")}"
BUNDLE_DIR="$ROOT_DIR/build/linux/x64/release/bundle"
APPDIR="$ROOT_DIR/build/appimage/Sitzplan.AppDir"
DIST_DIR="$ROOT_DIR/dist"
APPIMAGETOOL="$ROOT_DIR/build/appimage/appimagetool-${ARCH}.AppImage"

if [[ ! -x "$BUNDLE_DIR/sitzplan" ]]; then
  echo "Linux release bundle not found at $BUNDLE_DIR" >&2
  exit 1
fi

rm -rf "$APPDIR"
mkdir -p "$APPDIR/opt/sitzplan" "$APPDIR/usr/share/applications" "$APPDIR/usr/share/icons/hicolor/512x512/apps" "$DIST_DIR"

cp -a "$BUNDLE_DIR/." "$APPDIR/opt/sitzplan/"
cp "$ROOT_DIR/packaging/linux/de.kaufmann.sitzplan.desktop" "$APPDIR/de.kaufmann.sitzplan.desktop"
cp "$ROOT_DIR/packaging/linux/de.kaufmann.sitzplan.desktop" "$APPDIR/usr/share/applications/de.kaufmann.sitzplan.desktop"
cp "$ROOT_DIR/web/icons/Icon-512.png" "$APPDIR/de.kaufmann.sitzplan.png"
cp "$ROOT_DIR/web/icons/Icon-512.png" "$APPDIR/usr/share/icons/hicolor/512x512/apps/de.kaufmann.sitzplan.png"

cat > "$APPDIR/AppRun" <<'EOF'
#!/usr/bin/env bash
HERE="$(dirname "$(readlink -f "$0")")"
cd "$HERE/opt/sitzplan"
exec "$HERE/opt/sitzplan/sitzplan" "$@"
EOF
chmod +x "$APPDIR/AppRun"

if [[ ! -x "$APPIMAGETOOL" ]]; then
  mkdir -p "$(dirname "$APPIMAGETOOL")"
  curl -L -o "$APPIMAGETOOL" "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-${ARCH}.AppImage"
  chmod +x "$APPIMAGETOOL"
fi

OUTPUT="$DIST_DIR/Sitzplan-${APP_VERSION}-${ARCH}.AppImage"
rm -f "$OUTPUT"
APPIMAGE_EXTRACT_AND_RUN=1 ARCH="$ARCH" "$APPIMAGETOOL" "$APPDIR" "$OUTPUT"
chmod +x "$OUTPUT"
