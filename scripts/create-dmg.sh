#!/bin/bash
set -euo pipefail

APP_NAME="Debounce"
DERIVED_DATA="$HOME/Library/Developer/Xcode/DerivedData"

if [ $# -ne 1 ]; then
    echo "Usage: $0 <version>"
    echo "Example: $0 1.1"
    exit 1
fi

VERSION="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"
DMG_NAME="$APP_NAME-$VERSION.dmg"

# Find the Release build in DerivedData
APP_PATH=$(find "$DERIVED_DATA" -path "*/$APP_NAME-*/Build/Products/Release/$APP_NAME.app" -maxdepth 5 2>/dev/null | head -1)

if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
    echo "Error: Release build not found in DerivedData."
    echo "Build the app in Xcode with Product > Archive or Product > Build (Release) first."
    exit 1
fi

echo "Found app: $APP_PATH"

# Create staging directory
STAGING_DIR=$(mktemp -d)
trap 'rm -rf "$STAGING_DIR"' EXIT

echo "Staging DMG contents..."
cp -R "$APP_PATH" "$STAGING_DIR/$APP_NAME.app"
ln -s /Applications "$STAGING_DIR/Applications"

# Create output directory
mkdir -p "$BUILD_DIR"
DMG_PATH="$BUILD_DIR/$DMG_NAME"

# Remove existing DMG if present
rm -f "$DMG_PATH"

echo "Creating DMG..."
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

echo ""
echo "Created: $DMG_PATH"
echo "Size: $(du -h "$DMG_PATH" | cut -f1)"
