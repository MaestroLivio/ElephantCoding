#!/usr/bin/env bash
# Build the distributable packages for Linux, macOS, Windows and the web.
#
# Requirements (macOS build host):
#   - Godot 4.7.2 with the export templates installed
#   - NSIS (makensis) for the Windows installer
#   - hdiutil, ditto, zip, shasum (macOS system tools)
#   - Python 3.11+
#
# Artifacts are written to dist/ (ignored by git). The script never touches
# the canonical data or the Godot project; it exports into build/ at the
# repository root, outside the Godot project so build artifacts are not
# scanned and packed again.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT_BIN="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
VERSION="$(sed -n 's/^config\/version="\(.*\)"/\1/p' "$ROOT/godot/project.godot" | head -1)"
NAME="ElephantCoding"
BUILD="$ROOT/build/dist"
DIST="$ROOT/dist"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/elephantcoding-dist.XXXXXX")"
STAGE="$WORK/stage"
OUT="$WORK/out"
trap 'rm -rf "$WORK"' EXIT

say() { printf '\n==> %s\n' "$*"; }
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

[[ -x "$GODOT_BIN" ]] || fail "Godot not found: $GODOT_BIN (set GODOT_BIN)"
command -v makensis >/dev/null || fail "makensis (NSIS) not found"
command -v hdiutil >/dev/null || fail "hdiutil not found (macOS required)"
command -v python3 >/dev/null || fail "python3 not found"
[[ -f "$ROOT/godot/assets/icons/icon.ico" ]] || fail "missing godot/assets/icons/icon.ico"
[[ -n "$VERSION" ]] || fail "cannot read config/version from project.godot"

rm -rf "$BUILD"
mkdir -p "$BUILD"/{macos,windows,linux,web,icons} "$STAGE" "$DIST" "$OUT"
rm -f "$DIST/$NAME-$VERSION"-* "$DIST/SHA256SUMS.txt"

say "Building helper icons (Linux desktop icon)"
python3 "$ROOT/tools/dist/make_icons.py" \
  --source "$ROOT/godot/assets/icons/icon.svg" \
  --png "$BUILD/icons/elephantcoding-256.png"

export_release() {
  local preset="$1"
  local output="$2"
  local log="$BUILD/export-$preset.log"
  mkdir -p "$(dirname "$output")"
  say "Exporting $preset"
  if ! "$GODOT_BIN" --headless --path "$ROOT/godot" --export-release "$preset" "$output" >"$log" 2>&1; then
    tail -40 "$log" >&2
    fail "export failed for preset $preset"
  fi
  if grep -qiE '^ERROR|Project export .* failed' "$log"; then
    grep -iE '^ERROR|Project export .* failed' "$log" >&2
    fail "export reported errors for preset $preset"
  fi
}

export_release "Linux" "$BUILD/linux/$NAME.x86_64"
export_release "macOS" "$BUILD/macos/$NAME.zip"
export_release "Windows" "$BUILD/windows/$NAME.exe"
export_release "Web" "$BUILD/web/index.html"

LICENSES=(LICENSE THIRD_PARTY_NOTICES.md README.md docs/ATTRIBUTION.md docs/TEACHER_GUIDE.md)

stage_licenses() {
  local target="$1"
  mkdir -p "$target"
  local file
  for file in "${LICENSES[@]}"; do
    cp "$ROOT/$file" "$target/"
  done
}

say "Packaging macOS (app, zip, dmg)"
MACOS_DIR="$STAGE/macos"
mkdir -p "$MACOS_DIR"
ditto -x -k "$BUILD/macos/$NAME.zip" "$MACOS_DIR"
APP="$MACOS_DIR/$NAME.app"
[[ -d "$APP" ]] || fail "macOS export did not contain $NAME.app"

# Keep the licence files inside the bundle so they travel with the app.
stage_licenses "$APP/Contents/Resources/licenses"

# Ad-hoc signature: the bundle is distributable but not notarised.  Staging
# happens outside the iCloud-synced project folder, otherwise macOS re-adds
# FinderInfo to the bundle and codesign --strict rejects it.
if command -v codesign >/dev/null 2>&1; then
  xattr -cr "$APP"
  codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || fail "codesign failed"
  codesign --verify --deep --strict "$APP" || fail "codesign verification failed"
fi

ditto -c -k --sequesterRsrc --keepParent "$APP" "$OUT/$NAME-$VERSION-macOS-universal.zip"

DMGROOT="$STAGE/dmg"
mkdir -p "$DMGROOT"
cp -R "$APP" "$DMGROOT/"
ln -s /Applications "$DMGROOT/Applications"
hdiutil create -quiet -volname "$NAME" -srcfolder "$DMGROOT" -ov -format UDZO \
  "$OUT/$NAME-$VERSION-macOS-universal.dmg"

say "Packaging Windows (portable zip and NSIS installer)"
WIN_DIR="$STAGE/windows/$NAME"
mkdir -p "$WIN_DIR"
cp "$BUILD/windows/$NAME.exe" "$BUILD/windows/$NAME.pck" "$WIN_DIR/"
stage_licenses "$WIN_DIR/licenses"
(cd "$STAGE/windows" && zip -qr -X "$OUT/$NAME-$VERSION-Windows-x86_64-portable.zip" "$NAME")

makensis -V2 \
  -DPRODUCT_VERSION="$VERSION" \
  -DSOURCE_DIR="$WIN_DIR" \
  -DOUTPUT="$OUT/$NAME-$VERSION-Windows-x86_64-Setup.exe" \
  -DICON="$ROOT/godot/assets/icons/icon.ico" \
  "$ROOT/tools/dist/windows_installer.nsi"

say "Packaging Linux (portable tar.gz and .deb)"
LINUX_DIR="$STAGE/linux/$NAME"
mkdir -p "$LINUX_DIR"
cp "$BUILD/linux/$NAME.x86_64" "$LINUX_DIR/$NAME"
chmod 0755 "$LINUX_DIR/$NAME"
cp "$BUILD/linux/$NAME.pck" "$LINUX_DIR/"
stage_licenses "$LINUX_DIR/licenses"
cp "$ROOT/tools/dist/linux/install.sh" "$LINUX_DIR/install.sh"
chmod 0755 "$LINUX_DIR/install.sh"
cp "$ROOT/tools/dist/linux/elephantcoding.desktop" "$LINUX_DIR/"
cp "$BUILD/icons/elephantcoding-256.png" "$LINUX_DIR/elephantcoding.png"
cat > "$LINUX_DIR/LEGGIMI.txt" <<EOF
ElephantCoding $VERSION - Linux x86_64

Avvio senza installazione:
  ./ElephantCoding

Installazione per l'utente corrente (~/.local):
  ./install.sh

Requisiti: distribuzione Linux x86_64 con X11 o Wayland, OpenGL 3.3,
driver audio ALSA/PulseAudio. Il gioco non richiede connessione di rete.
La build non e' firmata digitalmente: verifica SHA256SUMS.txt.
EOF
tar -C "$STAGE/linux" -czf "$OUT/$NAME-$VERSION-Linux-x86_64.tar.gz" "$NAME"

DEBROOT="$STAGE/deb"
mkdir -p "$DEBROOT/opt/elephantcoding" \
  "$DEBROOT/usr/bin" \
  "$DEBROOT/usr/share/applications" \
  "$DEBROOT/usr/share/icons/hicolor/256x256/apps" \
  "$DEBROOT/usr/share/doc/elephantcoding"
install -m 0755 "$BUILD/linux/$NAME.x86_64" "$DEBROOT/opt/elephantcoding/$NAME"
install -m 0644 "$BUILD/linux/$NAME.pck" "$DEBROOT/opt/elephantcoding/$NAME.pck"
stage_licenses "$DEBROOT/usr/share/doc/elephantcoding"
install -m 0644 "$ROOT/tools/dist/linux/elephantcoding.desktop" \
  "$DEBROOT/usr/share/applications/elephantcoding.desktop"
install -m 0644 "$BUILD/icons/elephantcoding-256.png" \
  "$DEBROOT/usr/share/icons/hicolor/256x256/apps/elephantcoding.png"
cat > "$DEBROOT/usr/bin/elephantcoding" <<'EOF'
#!/bin/sh
exec /opt/elephantcoding/ElephantCoding "$@"
EOF
chmod 0755 "$DEBROOT/usr/bin/elephantcoding"
python3 "$ROOT/tools/dist/build_deb.py" \
  --root "$DEBROOT" --out "$OUT/$NAME-$VERSION-Linux-x86_64.deb" \
  --version "$VERSION" --arch amd64

say "Packaging Web (static hosting zip)"
WEB_DIR="$STAGE/web"
mkdir -p "$WEB_DIR"
cp -R "$BUILD/web/." "$WEB_DIR/"
rm -f "$WEB_DIR"/*.import
stage_licenses "$WEB_DIR/licenses"
(cd "$WEB_DIR" && zip -qr -X "$OUT/$NAME-$VERSION-Web.zip" .)

say "Android (optional debug/sideload APK)"
ANDROID_KEYSTORE="$HOME/Library/Application Support/Godot/keystores/debug.keystore"
if [[ -d "$HOME/Library/Android/sdk" && -f "$ANDROID_KEYSTORE" ]]; then
  mkdir -p "$BUILD/android"
  if "$GODOT_BIN" --headless --path "$ROOT/godot" --export-debug "Android" \
      "$BUILD/android/$NAME.apk" >"$BUILD/export-Android.log" 2>&1; then
    cp "$BUILD/android/$NAME.apk" "$OUT/$NAME-$VERSION-Android-arm64-debug.apk"
    cat > "$OUT/$NAME-$VERSION-Android-LEGGIMI.txt" <<EOF
ElephantCoding $VERSION - Android arm64 (debug/sideload)

APK firmato con la chiave di debug di Godot, adatto all'installazione
manuale su tablet e telefoni Android (Android 6 o successivo).

Installazione:
  adb install $NAME-$VERSION-Android-arm64-debug.apk
oppure copia l'APK sul dispositivo e aprilo, consentendo l'installazione
da origini sconosciute per il file manager.

Questa build non e' destinata a Google Play e non e' firmata con una
chiave di distribuzione: per pubblicare sullo store servono una chiave
di release e una build AAB firmata dall'autore.
EOF
  else
    echo "WARNING: Android export failed; see $BUILD/export-Android.log" >&2
    [[ "${EC_REQUIRE_ANDROID:-0}" == "1" ]] && fail "Android export required but failed"
  fi
else
  echo "Android export skipped: Android SDK or debug keystore not configured."
  [[ "${EC_REQUIRE_ANDROID:-0}" == "1" ]] && fail "Android export required but prerequisites are missing"
fi

say "Publishing artifacts to dist/"
cp "$OUT"/* "$DIST"/

say "Checksums"
(cd "$DIST" && shasum -a 256 "$NAME-$VERSION"-* > SHA256SUMS.txt)

say "Done"
ls -lh "$DIST"
