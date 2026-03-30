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

echo "==> Preparing distribution build..."
rm -rf "$BUILD_DIR/dist"
mkdir -p "$BUILD_DIR/dist"
DIST_APP="$BUILD_DIR/dist/$APP_NAME.app"
cp -R "$BUILT_APP" "$DIST_APP"

# Create distribution entitlements (no App Group — requires provisioning profile)
DIST_ENTITLEMENTS="$BUILD_DIR/dist-entitlements.plist"
cat > "$DIST_ENTITLEMENTS" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.security.app-sandbox</key>
	<true/>
	<key>com.apple.security.network.client</key>
	<true/>
</dict>
</plist>
PLIST

# Re-sign ad-hoc: widget extension first, then main app
codesign --force --deep --sign - --entitlements "$DIST_ENTITLEMENTS" \
    "$DIST_APP/Contents/PlugIns/GlucoseWidgetExtension.appex"
codesign --force --deep --sign - --entitlements "$DIST_ENTITLEMENTS" "$DIST_APP"

echo "==> Creating GitHub release..."
VERSION=$(date +%Y.%m.%d-%H%M)
ZIP_NAME="GlucoseWidget-${VERSION}.zip"
(cd "$BUILD_DIR/dist" && zip -r -q "../../$ZIP_NAME" "$APP_NAME.app")

# Delete existing release with same tag if it exists
gh release delete "v${VERSION}" --yes 2>/dev/null || true
gh release create "v${VERSION}" "$ZIP_NAME" \
    --title "Glucose Widget ${VERSION}" \
    --notes "Automated build from deploy script. Right-click > Open on first launch to bypass Gatekeeper." \
    --latest

rm -f "$ZIP_NAME"

echo "==> Done. $APP_NAME installed to $INSTALL_DIR and uploaded to GitHub."
