#!/bin/bash

# Script to create a distributable DMG for BatteryPro

set -e

PROJECT_NAME="BatteryPro"
DMG_NAME="BatteryPro_Installer.dmg"
VOL_NAME="BatteryPro Installer"
BUILD_DIR="${HOME}/Library/Developer/Xcode/DerivedData"

# 1. Find the built app
if [ -n "$1" ]; then
    BUILD_PATH="$1"
    echo "🎯 Using specified app: ${BUILD_PATH}"
else
    echo "🔍 Searching for built Release app..."
    # Try to find the most recent build (prefer Release, then Debug)
    BUILD_PATH=$(find "${BUILD_DIR}" -name "${PROJECT_NAME}.app" -type d -path "*/Release/*" -not -path "*Index.noindex*" -maxdepth 6 2>/dev/null | head -1)

    if [ -z "$BUILD_PATH" ]; then
        echo "⚠️  Release build not found, checking for any build..."
        BUILD_PATH=$(find "${BUILD_DIR}" -name "${PROJECT_NAME}.app" -type d -not -path "*Index.noindex*" -maxdepth 6 2>/dev/null | head -1)
    fi
fi

if [ -z "$BUILD_PATH" ]; then
    echo "❌ Error: Could not find built app."
    echo "Usage: ./create_dmg.sh [path/to/BatteryPro.app]"
    exit 1
fi

echo "✅ Found app at: ${BUILD_PATH}"

# 2. Prepare source folder
echo "📂 Preparing source folder..."
# Use /tmp to avoid external drive permission issues
TEMP_DIR="/tmp/BatteryPro_DMG_Build_$(date +%s)"
STAGING_DIR="${TEMP_DIR}/staging"
mkdir -p "${STAGING_DIR}"

# Copy App
echo "©️  Copying ${PROJECT_NAME}.app to staging..."
# Use -R to copy recursively, do NOT use -L as it breaks bundle signatures by dereferencing symlinks
cp -R "${BUILD_PATH}" "${STAGING_DIR}/"

# Clean up any extended attributes (quarantine, etc) from the copy to avoid "Damaged" errors
echo "🧹 Removing extended attributes from staging..."
xattr -cr "${STAGING_DIR}/${PROJECT_NAME}.app"

# Verify copy
if [ ! -f "${STAGING_DIR}/${PROJECT_NAME}.app/Contents/Info.plist" ]; then
    echo "❌ Error: App copy failed. contents not found in staging."
    ls -R "${STAGING_DIR}"
    exit 1
fi

# Create /Applications link
echo "🔗 Creating Applications link..."
ln -s /Applications "${STAGING_DIR}/Applications"

# 3. Create DMG
echo "💿 Creating DMG..."
# Remove existing file in current dir if it exists
if [ -f "${DMG_NAME}" ]; then
    rm "${DMG_NAME}"
fi

# Create DMG in the temp dir first
TEMP_DMG="${TEMP_DIR}/${DMG_NAME}"

hdiutil create -volname "${VOL_NAME}" \
    -srcfolder "${STAGING_DIR}" \
    -ov -format UDZO \
    "${TEMP_DMG}"

# Move the DMG back to the current directory
echo "🚚 Moving DMG to project folder..."
mv "${TEMP_DMG}" "./${DMG_NAME}"

# 4. Cleanup
echo "🧹 Cleaning up..."
rm -rf "${TEMP_DIR}"

echo ""
echo "🎉 DMG Created Successfully!"
echo "📍 Location: $(pwd)/${DMG_NAME}"
