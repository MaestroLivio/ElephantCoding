#!/usr/bin/env bash
# Portable Linux installer: copies ElephantCoding under ~/.local (or $PREFIX)
# and registers a desktop entry. Run it from the unpacked archive:
#   ./install.sh
# Uninstall:
#   rm -rf "$HOME/.local/opt/elephantcoding" \
#          "$HOME/.local/bin/elephantcoding" \
#          "$HOME/.local/share/applications/elephantcoding.desktop" \
#          "$HOME/.local/share/icons/hicolor/256x256/apps/elephantcoding.png"
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
PREFIX="${PREFIX:-$HOME/.local}"
APPDIR="$PREFIX/opt/elephantcoding"
BINDIR="$PREFIX/bin"
APPSDIR="$PREFIX/share/applications"
ICONDIR="$PREFIX/share/icons/hicolor/256x256/apps"

mkdir -p "$APPDIR" "$BINDIR" "$APPSDIR" "$ICONDIR"
cp "$HERE/ElephantCoding" "$HERE/ElephantCoding.pck" "$APPDIR/"
cp -R "$HERE/licenses" "$APPDIR/" 2>/dev/null || true
chmod 0755 "$APPDIR/ElephantCoding"
ln -sf "$APPDIR/ElephantCoding" "$BINDIR/elephantcoding"
cp "$HERE/elephantcoding.png" "$ICONDIR/elephantcoding.png"

cat > "$APPSDIR/elephantcoding.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=ElephantCoding
GenericName=Coding per bambini
Comment=Nilo l'elefantino che programma
Exec="$APPDIR/ElephantCoding"
Icon=elephantcoding
Terminal=false
Categories=Education;Game;
Keywords=coding;programmazione;scuola;bambini;
EOF

if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$APPSDIR" >/dev/null 2>&1 || true
fi

echo "ElephantCoding installato in $APPDIR"
echo "Avvialo dal menu applicazioni oppure con: $BINDIR/elephantcoding"
