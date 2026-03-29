#!/bin/bash
set -euo pipefail

APP_NAME="Glucose Widget"
BUNDLE_ID="com.dexcomwidget.app"
BUILD_DIR="build"
INSTALL_DIR="/Applications"

echo "==> Generating Xcode project..."
xcodegen generate --quiet

echo "==> Building release..."
xcodebuild \
    -project DexcomWidget.xcodeproj \
    -scheme DexcomWidget \
    -configuration Release \
    -destination 'platform=macOS' \
    -derivedDataPath "$BUILD_DIR" \
    -allowProvisioningUpdates \
    build \
    2>&1 | tail -1

BUILT_APP="$BUILD_DIR/Build/Products/Release/$APP_NAME.app"

if [ ! -d "$BUILT_APP" ]; then
    echo "ERROR: Build failed, $APP_NAME.app not found."
    exit 1
fi

echo "==> Stopping running instance..."
pkill -x "$APP_NAME" 2>/dev/null || true
sleep 1

echo "==> Installing to $INSTALL_DIR..."
rm -rf "$INSTALL_DIR/$APP_NAME.app"
cp -R "$BUILT_APP" "$INSTALL_DIR/$APP_NAME.app"

echo "==> Launching..."
open "$INSTALL_DIR/$APP_NAME.app"

echo "==> Done. $APP_NAME installed to $INSTALL_DIR."
