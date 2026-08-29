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
cp "$HOME/gp/cupsexec/filter/rastertogutenprint.5.3" "$RUNTIME_DIR/bin/"
cp -R "$HOME/gp/share/gutenprint/5.3/xml/" "$RUNTIME_DIR/share/gutenprint/5.3/xml/"
cp "$REPO_ROOT/G2010_gutenprint/stp-bjc-G2000-series.5.3.ppd" "$RUNTIME_DIR/ppd/"

# 7. Bundle IPP Server (ippeveprinter + relocated dylibs)
echo "→ Bundling ippeveprinter & CUPS dylibs..."
cp /opt/homebrew/opt/cups/bin/ippeveprinter "$RUNTIME_DIR/bin/"
cp /opt/homebrew/Cellar/cups/2.4.19/lib/libcups.2.dylib "$RUNTIME_DIR/lib/"
cp /opt/homebrew/opt/openssl@3/lib/libssl.3.dylib "$RUNTIME_DIR/lib/"
cp /opt/homebrew/opt/openssl@3/lib/libcrypto.3.dylib "$RUNTIME_DIR/lib/"

# 8. Bundle SANE Scanner (scanimage + libsane + pixma backend + libusb)
echo "→ Bundling SANE scanner engine & backends..."
cp /opt/homebrew/bin/scanimage "$RUNTIME_DIR/bin/"
cp /opt/homebrew/Cellar/sane-backends/1.4.0_2/lib/libsane.1.dylib "$RUNTIME_DIR/lib/"
cp /opt/homebrew/Cellar/sane-backends/1.4.0_2/lib/sane/libsane-pixma.1.so "$RUNTIME_DIR/lib/sane/"
cp /opt/homebrew/opt/libusb/lib/libusb-1.0.0.dylib "$RUNTIME_DIR/lib/"
cp /opt/homebrew/opt/libpng/lib/libpng16.16.dylib "$RUNTIME_DIR/lib/"
cp /opt/homebrew/opt/jpeg-turbo/lib/libjpeg.8.dylib "$RUNTIME_DIR/lib/"
cp /opt/homebrew/etc/sane.d/pixma.conf "$RUNTIME_DIR/etc/sane.d/"
echo "pixma" > "$RUNTIME_DIR/etc/sane.d/dll.conf"

# Ensure write permissions for install_name_tool
chmod -R u+w "$APP_BUNDLE"

# 9. Relocate dylibs with install_name_tool
echo "→ Rewriting dynamic library load paths..."
# ippeveprinter
install_name_tool -change /opt/homebrew/Cellar/cups/2.4.19/lib/libcups.2.dylib @executable_path/../lib/libcups.2.dylib "$RUNTIME_DIR/bin/ippeveprinter"
install_name_tool -change /opt/homebrew/opt/cups/lib/libcups.2.dylib @loader_path/libcups.2.dylib "$RUNTIME_DIR/lib/libcups.2.dylib"
install_name_tool -change /opt/homebrew/opt/openssl@3/lib/libssl.3.dylib @loader_path/libssl.3.dylib "$RUNTIME_DIR/lib/libcups.2.dylib"
install_name_tool -change /opt/homebrew/opt/openssl@3/lib/libcrypto.3.dylib @loader_path/libcrypto.3.dylib "$RUNTIME_DIR/lib/libcups.2.dylib"
install_name_tool -change /opt/homebrew/opt/openssl@3/lib/libcrypto.3.dylib @loader_path/libcrypto.3.dylib "$RUNTIME_DIR/lib/libssl.3.dylib"

# scanimage
install_name_tool -change /opt/homebrew/Cellar/sane-backends/1.4.0_2/lib/libsane.1.dylib @executable_path/../lib/libsane.1.dylib "$RUNTIME_DIR/bin/scanimage"
install_name_tool -change /opt/homebrew/opt/libusb/lib/libusb-1.0.0.dylib @executable_path/../lib/libusb-1.0.0.dylib "$RUNTIME_DIR/bin/scanimage"
install_name_tool -change /opt/homebrew/opt/libpng/lib/libpng16.16.dylib @executable_path/../lib/libpng16.16.dylib "$RUNTIME_DIR/bin/scanimage"
install_name_tool -change /opt/homebrew/opt/jpeg-turbo/lib/libjpeg.8.dylib @executable_path/../lib/libjpeg.8.dylib "$RUNTIME_DIR/bin/scanimage"

# libsane & backends
install_name_tool -change /opt/homebrew/opt/sane-backends/lib/libsane.1.dylib @loader_path/libsane.1.dylib "$RUNTIME_DIR/lib/libsane.1.dylib"
install_name_tool -change /opt/homebrew/opt/libusb/lib/libusb-1.0.0.dylib @loader_path/libusb-1.0.0.dylib "$RUNTIME_DIR/lib/libsane.1.dylib"
install_name_tool -change /opt/homebrew/opt/libusb/lib/libusb-1.0.0.dylib @loader_path/libusb-1.0.0.dylib "$RUNTIME_DIR/lib/libusb-1.0.0.dylib"
install_name_tool -change /opt/homebrew/opt/jpeg-turbo/lib/libjpeg.8.dylib @loader_path/../libjpeg.8.dylib "$RUNTIME_DIR/lib/sane/libsane-pixma.1.so"
install_name_tool -change /opt/homebrew/opt/libusb/lib/libusb-1.0.0.dylib @loader_path/../libusb-1.0.0.dylib "$RUNTIME_DIR/lib/sane/libsane-pixma.1.so"

# 10. Codesign all components ad-hoc
echo "→ Ad-hoc codesigning all binaries & libraries..."
find "$APP_BUNDLE" -type f \( -name "*.dylib" -o -name "*.so" -o -perm +111 \) -exec codesign -s - -f {} + 2>/dev/null || true
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
