#!/usr/bin/env bash
# Build the distributable packages for Linux, macOS, Windows and the web.
#
# Requirements (macOS build host):
#   - Godot 4.7.2 with the export templates installed
#   - NSIS (makensis) for the Windows installer. NSIS 3.13 crashes with
#     std::bad_alloc on any Unicode script on macOS (upstream bug #1333); set
#     MAKENSIS to a patched build, see docs/DISTRIBUTION.md.
#   - hdiutil, ditto, zip, shasum (macOS system tools)
#   - Python 3.11+
#
# Artifacts are written to dist/ (ignored by git). The script never touches
# the canonical data or the Godot project; it exports into build/ at the
# repository root, outside the Godot project so build artifacts are not
# scanned and packed again.
#
# Optional code signing (without it the OS warns on first launch):
#   EC_MACOS_IDENTITY  "Developer ID Application: Name (TEAMID)"
#   EC_NOTARY_PROFILE  keychain profile created with notarytool store-credentials
#   EC_WINDOWS_PFX     .pfx for the Windows installer (needs osslsigncode)
#   EC_WINDOWS_PASSWORD password of that .pfx
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT_BIN="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
MAKENSIS_BIN="${MAKENSIS:-makensis}"
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
if ! command -v "$MAKENSIS_BIN" >/dev/null && [[ ! -x "$MAKENSIS_BIN" ]]; then
  fail "makensis (NSIS) not found: $MAKENSIS_BIN (set MAKENSIS)"
fi
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
MACOS_IDENTITY="${EC_MACOS_IDENTITY:-}"
NOTARY_PROFILE="${EC_NOTARY_PROFILE:-}"
NOTARIZED=0

# Keep the licence files inside the bundle so they travel with the app.
stage_licenses "$APP/Contents/Resources/licenses"

# Staging happens outside the iCloud-synced project folder, otherwise macOS
# re-adds FinderInfo to the bundle and codesign --strict rejects it.
xattr -cr "$APP"
if [[ -n "$MACOS_IDENTITY" ]]; then
  say "Signing macOS bundle as $MACOS_IDENTITY"
  codesign --force --options runtime --timestamp --sign "$MACOS_IDENTITY" "$APP" \
    || fail "Developer ID signing failed"
else
  # Ad-hoc signature: the bundle launches, but Gatekeeper rejects it because no
  # Developer ID backs it. Users must allow it once in Privacy & Security.
  echo "No EC_MACOS_IDENTITY: signing ad-hoc, Gatekeeper will warn on first launch."
  codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || fail "codesign failed"
fi
codesign --verify --deep --strict "$APP" || fail "codesign verification failed"

# Notarise before packaging so the stapled ticket travels inside the DMG.
if [[ -n "$MACOS_IDENTITY" && -n "$NOTARY_PROFILE" ]]; then
  say "Notarizing macOS app (this can take a few minutes)"
  ditto -c -k --sequesterRsrc --keepParent "$APP" "$WORK/notarize.zip"
  xcrun notarytool submit "$WORK/notarize.zip" --keychain-profile "$NOTARY_PROFILE" --wait \
    || fail "notarization failed; check EC_NOTARY_PROFILE"
  xcrun stapler staple "$APP" || fail "stapling the app failed"
  spctl -a -vvv -t exec "$APP" || fail "Gatekeeper still rejects the app after notarization"
  NOTARIZED=1
fi

ditto -c -k --sequesterRsrc --keepParent "$APP" "$OUT/$NAME-$VERSION-macOS-universal.zip"

DMGROOT="$STAGE/dmg"
mkdir -p "$DMGROOT"
cp -R "$APP" "$DMGROOT/"
ln -s /Applications "$DMGROOT/Applications"
if [[ "$NOTARIZED" == "1" ]]; then
  cat > "$DMGROOT/LEGGIMI.txt" <<EOF
$NAME $VERSION - macOS

La build e' firmata con Developer ID e notarizzata da Apple: trascina
$NAME in Applicazioni e avviala con un doppio clic.

Requisiti: macOS 10.15 o successivo.
EOF
else
  cat > "$DMGROOT/LEGGIMI.txt" <<EOF
$NAME $VERSION - macOS

Questa build NON e' notarizzata: al primo avvio macOS la blocca con un
avviso tipo "Apple non puo' verificare l'app" o "in attesa di controllo".
E' una protezione del sistema, non un errore dell'app.

Per aprirla:
 1. trascina $NAME nella cartella Applicazioni;
 2. aprilo una volta e chiudi l'avviso;
 3. Impostazioni di Sistema > Privacy e Sicurezza, scorri fino al
    messaggio su $NAME e premi "Apri comunque";
    su macOS 13 e precedenti: tasto destro sull'app > Apri > Apri.

In alternativa, dal Terminale:
  xattr -dr com.apple.quarantine /Applications/$NAME.app

Il messaggio sparisce per sempre dopo il primo avvio consentito.
Se hai scaricato lo ZIP, la stessa procedura vale per l'app scompattata.
EOF
fi
hdiutil create -quiet -volname "$NAME" -srcfolder "$DMGROOT" -ov -format UDZO \
  "$OUT/$NAME-$VERSION-macOS-universal.dmg"
if [[ "$NOTARIZED" == "1" ]]; then
  # The DMG itself must be signed and notarised, otherwise Gatekeeper refuses
  # the disk image before the (already notarised) app is ever copied out.
  codesign --force --timestamp --sign "$MACOS_IDENTITY" "$OUT/$NAME-$VERSION-macOS-universal.dmg" \
    || fail "signing the DMG failed"
  xcrun notarytool submit "$OUT/$NAME-$VERSION-macOS-universal.dmg" \
    --keychain-profile "$NOTARY_PROFILE" --wait || fail "notarizing the DMG failed"
  xcrun stapler staple "$OUT/$NAME-$VERSION-macOS-universal.dmg" || fail "stapling the DMG failed"
fi

say "Packaging Windows (portable zip and NSIS installer)"
WIN_DIR="$STAGE/windows/$NAME"
mkdir -p "$WIN_DIR"
cp "$BUILD/windows/$NAME.exe" "$BUILD/windows/$NAME.pck" "$WIN_DIR/"

# Optional Authenticode signature: SmartScreen only stops warning about an
# installer whose publisher is trusted.
sign_windows() {
  local target="$1"
  if [[ -z "${EC_WINDOWS_PFX:-}" ]]; then
    return 0
  fi
  command -v osslsigncode >/dev/null || fail "osslsigncode is required to sign with EC_WINDOWS_PFX"
  local signed="$target.signed"
  osslsigncode sign -pkcs12 "$EC_WINDOWS_PFX" -pass "${EC_WINDOWS_PASSWORD:-}" \
    -n "$NAME" -i "https://github.com/MaestroLivio/ElephantCoding" \
    -t "http://timestamp.digicert.com" -in "$target" -out "$signed" \
    || fail "signing $(basename "$target") failed"
  mv "$signed" "$target"
}
sign_windows "$WIN_DIR/$NAME.exe"
stage_licenses "$WIN_DIR/licenses"
(cd "$STAGE/windows" && zip -qr -X "$OUT/$NAME-$VERSION-Windows-x86_64-portable.zip" "$NAME")

if ! "$MAKENSIS_BIN" -V2 \
  -DPRODUCT_VERSION="$VERSION" \
  -DSOURCE_DIR="$WIN_DIR" \
  -DOUTPUT="$OUT/$NAME-$VERSION-Windows-x86_64-Setup.exe" \
  -DICON="$ROOT/godot/assets/icons/icon.ico" \
  "$ROOT/tools/dist/windows_installer.nsi"; then
  fail "makensis failed. NSIS 3.13 aborts with std::bad_alloc on Unicode scripts\
 on macOS 14 and later (upstream bug #1333); build a patched makensis and pass\
 it with MAKENSIS, see docs/DISTRIBUTION.md"
fi
sign_windows "$OUT/$NAME-$VERSION-Windows-x86_64-Setup.exe"

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
