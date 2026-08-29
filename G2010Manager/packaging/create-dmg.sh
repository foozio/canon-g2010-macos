#!/bin/bash
# create-dmg.sh — Package G2010 Manager into a distributable .dmg
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/.build/release"
STAGING="$PROJECT_DIR/.build/dmg-staging"
APP_NAME="G2010 Manager"
APP_BUNDLE="$STAGING/$APP_NAME.app"
DMG_NAME="G2010-Manager-1.0.0"
DMG_PATH="$PROJECT_DIR/$DMG_NAME.dmg"

echo "=== Packaging G2010 Manager ==="

# Clean previous staging
rm -rf "$STAGING"
rm -f "$DMG_PATH"

# 1. Create .app bundle structure
echo "→ Creating .app bundle..."
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# 2. Copy binary
cp "$BUILD_DIR/G2010Manager" "$APP_BUNDLE/Contents/MacOS/G2010Manager"

# 3. Copy Info.plist
cp "$SCRIPT_DIR/Info.plist" "$APP_BUNDLE/Contents/"

# 4. Generate app icon if iconutil is available
if [ -f "$SCRIPT_DIR/create-icon.sh" ]; then
    echo "→ Generating app icon..."
    bash "$SCRIPT_DIR/create-icon.sh" "$APP_BUNDLE/Contents/Resources/AppIcon.icns" || true
fi

# 5. Create Applications symlink for drag-install
echo "→ Creating Applications symlink..."
ln -s /Applications "$STAGING/Applications"

# 6. Create the DMG
echo "→ Creating DMG..."
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGING" \
    -ov \
    -format UDZO \
    -imagekey zlib-level=9 \
    "$DMG_PATH"

# 7. Clean staging
rm -rf "$STAGING"

echo ""
echo "✅ DMG created: $DMG_PATH"
echo "   Size: $(du -h "$DMG_PATH" | cut -f1)"
