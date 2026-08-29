#!/bin/bash
# create-dmg.sh — Build standalone G2010 Manager.app and package into a self-contained .dmg
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
REPO_ROOT="$(dirname "$PROJECT_DIR")"
BUILD_DIR="$PROJECT_DIR/.build/release"
STAGING="$PROJECT_DIR/.build/dmg-staging"
APP_NAME="G2010 Manager"
APP_BUNDLE="$STAGING/$APP_NAME.app"
RUNTIME_DIR="$APP_BUNDLE/Contents/Resources/runtime"
DMG_NAME="G2010-Manager-1.0.0"
DMG_PATH="$PROJECT_DIR/$DMG_NAME.dmg"

fail() { echo "ERROR: $*" >&2; exit 1; }
require_file() {
  [ -e "$1" ] || fail "$1 not found — $2"
}

# Resolve Homebrew artifact paths dynamically (no hardcoded Cellar versions).
BREW_PREFIX="$(brew --prefix)"
CUPS_CELLAR="$(brew --cellar cups 2>/dev/null)" || fail "Homebrew formula 'cups' not installed (brew install cups)"
CUPS_VER_DIR="$(ls -d "$CUPS_CELLAR"/*/ 2>/dev/null | head -1)"
CUPS_LIB="$CUPS_VER_DIR/lib/libcups.2.dylib"
SANE_CELLAR="$(brew --cellar sane-backends 2>/dev/null)" || fail "Homebrew formula 'sane-backends' not installed"
SANE_VER_DIR="$(ls -d "$SANE_CELLAR"/*/ 2>/dev/null | head -1)"
SANE_LIB="$SANE_VER_DIR/lib/libsane.1.dylib"
SANE_PIXMA="$SANE_VER_DIR/lib/sane/libsane-pixma.1.so"
OSSL_LIB="$(brew --prefix openssl@3)/lib"
LIBUSB_LIB="$(ls "$BREW_PREFIX/opt/libusb/lib/"libusb-1.0.*.dylib 2>/dev/null | head -1)"
PNG_LIB="$(ls "$BREW_PREFIX/opt/libpng/lib/"libpng16.*.dylib 2>/dev/null | head -1)"
JPEG_LIB="$(ls "$BREW_PREFIX/opt/jpeg-turbo/lib/"libjpeg.*.dylib 2>/dev/null | head -1)"
GP_DIR="${GUTENPRINT_PREFIX:-$HOME/gp}"

echo "=================================================="
echo "  Packaging Self-Contained G2010 Manager (v1.0.0)"
echo "=================================================="

# 1. Build release binary
echo "→ Building release binary with Xcode SDK..."
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build -c release --package-path "$PROJECT_DIR"

# 2. Clean previous staging
rm -rf "$STAGING"
rm -f "$DMG_PATH"

# 3. Create .app bundle structure
echo "→ Creating .app bundle structure..."
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"
mkdir -p "$RUNTIME_DIR/bin"
mkdir -p "$RUNTIME_DIR/lib/sane"
mkdir -p "$RUNTIME_DIR/etc/sane.d"
mkdir -p "$RUNTIME_DIR/share/gutenprint/5.3/xml"
mkdir -p "$RUNTIME_DIR/ppd"
mkdir -p "$RUNTIME_DIR/scripts"
mkdir -p "$RUNTIME_DIR/spool"

# 4. Copy app binary & Info.plist
cp "$BUILD_DIR/G2010Manager" "$APP_BUNDLE/Contents/MacOS/G2010Manager"
cp "$SCRIPT_DIR/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

# 5. Generate app icon
echo "→ Generating AppIcon.icns..."
bash "$SCRIPT_DIR/create-icon.sh" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

# 6. Bundle Gutenprint 5.3.3 Raster Filter & XML Database
echo "→ Bundling Gutenprint 5.3.3 filter & XML database..."
require_file "$GP_DIR/cupsexec/filter/rastertogutenprint.5.3" "build Gutenprint first (docs/06-BUILD-NOTES.md)"
require_file "$GP_DIR/share/gutenprint/5.3/xml" "Gutenprint XML data missing after build"
cp "$GP_DIR/cupsexec/filter/rastertogutenprint.5.3" "$RUNTIME_DIR/bin/"
cp -R "$GP_DIR/share/gutenprint/5.3/xml/" "$RUNTIME_DIR/share/gutenprint/5.3/xml/"
cp "$REPO_ROOT/G2010_gutenprint/stp-bjc-G2000-series.5.3.ppd" "$RUNTIME_DIR/ppd/"

# 7. Bundle IPP Server (ippeveprinter + relocated dylibs)
echo "→ Bundling ippeveprinter & CUPS dylibs..."
require_file "$BREW_PREFIX/opt/cups/bin/ippeveprinter" "brew install cups (keg-only)"
require_file "$CUPS_LIB" "libcups not found in $CUPS_CELLAR"
cp "$BREW_PREFIX/opt/cups/bin/ippeveprinter" "$RUNTIME_DIR/bin/"
cp "$CUPS_LIB" "$RUNTIME_DIR/lib/"
cp "$OSSL_LIB/libssl.3.dylib" "$RUNTIME_DIR/lib/"
cp "$OSSL_LIB/libcrypto.3.dylib" "$RUNTIME_DIR/lib/"

# 8. Bundle SANE Scanner (scanimage + libsane + pixma backend + libusb)
echo "→ Bundling SANE scanner engine & backends..."
require_file "$BREW_PREFIX/bin/scanimage" "brew install sane-backends"
require_file "$SANE_LIB" "libsane not found in $SANE_CELLAR"
require_file "$SANE_PIXMA" "pixma backend not found in $SANE_CELLAR"
require_file "$LIBUSB_LIB" "brew install libusb"
require_file "$PNG_LIB" "brew install libpng"
require_file "$JPEG_LIB" "brew install jpeg-turbo"
cp "$BREW_PREFIX/bin/scanimage" "$RUNTIME_DIR/bin/"
cp "$SANE_LIB" "$RUNTIME_DIR/lib/"
cp "$SANE_PIXMA" "$RUNTIME_DIR/lib/sane/"
cp "$LIBUSB_LIB" "$RUNTIME_DIR/lib/"
cp "$PNG_LIB" "$RUNTIME_DIR/lib/"
cp "$JPEG_LIB" "$RUNTIME_DIR/lib/"
cp "$BREW_PREFIX/etc/sane.d/pixma.conf" "$RUNTIME_DIR/etc/sane.d/"
echo "pixma" > "$RUNTIME_DIR/etc/sane.d/dll.conf"

LIBUSB_NAME="$(basename "$LIBUSB_LIB")"
PNG_NAME="$(basename "$PNG_LIB")"
JPEG_NAME="$(basename "$JPEG_LIB")"

# Ensure write permissions for install_name_tool
chmod -R u+w "$APP_BUNDLE"

# relink <binary> <recorded-name-substring> <new-path>
# Finds the actual recorded load path via otool so the rewrite matches whatever
# Cellar version produced the binary.
relink() {
  local bin="$1" match="$2" new="$3" old
  old="$(otool -L "$bin" | awk '{print $1}' | grep -F "$match" | head -1)"
  [ -n "$old" ] || { echo "  (no '$match' recorded in $bin — skipped)"; return 0; }
  echo "  $bin: $old -> $new"
  install_name_tool -change "$old" "$new" "$bin"
}

# 9. Relocate dylibs with install_name_tool
echo "→ Rewriting dynamic library load paths..."
# ippeveprinter
relink "$RUNTIME_DIR/bin/ippeveprinter" "libcups.2.dylib" "@executable_path/../lib/libcups.2.dylib"
relink "$RUNTIME_DIR/lib/libcups.2.dylib" "libcups.2.dylib" "@loader_path/libcups.2.dylib"
relink "$RUNTIME_DIR/lib/libcups.2.dylib" "libssl.3.dylib" "@loader_path/libssl.3.dylib"
relink "$RUNTIME_DIR/lib/libcups.2.dylib" "libcrypto.3.dylib" "@loader_path/libcrypto.3.dylib"
relink "$RUNTIME_DIR/lib/libssl.3.dylib" "libcrypto.3.dylib" "@loader_path/libcrypto.3.dylib"

# scanimage
relink "$RUNTIME_DIR/bin/scanimage" "libsane.1.dylib" "@executable_path/../lib/libsane.1.dylib"
relink "$RUNTIME_DIR/bin/scanimage" "libusb-1.0" "@executable_path/../lib/$LIBUSB_NAME"
relink "$RUNTIME_DIR/bin/scanimage" "libpng16" "@executable_path/../lib/$PNG_NAME"
relink "$RUNTIME_DIR/bin/scanimage" "libjpeg" "@executable_path/../lib/$JPEG_NAME"

# libsane & backends
relink "$RUNTIME_DIR/lib/libsane.1.dylib" "libsane.1.dylib" "@loader_path/libsane.1.dylib"
relink "$RUNTIME_DIR/lib/libsane.1.dylib" "libusb-1.0" "@loader_path/$LIBUSB_NAME"
relink "$RUNTIME_DIR/lib/$LIBUSB_NAME" "libusb-1.0" "@loader_path/$LIBUSB_NAME"
relink "$RUNTIME_DIR/lib/sane/libsane-pixma.1.so" "libjpeg" "@loader_path/../$JPEG_NAME"
relink "$RUNTIME_DIR/lib/sane/libsane-pixma.1.so" "libusb-1.0" "@loader_path/../$LIBUSB_NAME"

# 10. Codesign all components ad-hoc
echo "→ Ad-hoc codesigning all binaries & libraries..."
find "$APP_BUNDLE" -type f \( -name "*.dylib" -o -name "*.so" -o -perm +111 \) -print0 \
  | while IFS= read -r -d '' item; do
      codesign -s - -f "$item" >/dev/null
    done
codesign -s - -f "$APP_BUNDLE"

# 11. Create Applications symlink for drag-to-install
echo "→ Creating Applications symlink..."
ln -s /Applications "$STAGING/Applications"

# 12. Create the final compressed DMG
echo "→ Creating compressed DMG..."
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGING" \
    -ov \
    -format UDZO \
    -imagekey zlib-level=9 \
    "$DMG_PATH"

# 13. Clean staging
rm -rf "$STAGING"

echo ""
echo "=================================================="
echo "  ✅ Self-Contained DMG Built Successfully!"
echo "  Location: $DMG_PATH"
echo "  Size:     $(du -h "$DMG_PATH" | cut -f1)"
echo "=================================================="
