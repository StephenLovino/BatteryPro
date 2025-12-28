#!/bin/bash

# Script to automatically update Info.plist files with correct code signing requirements
# This extracts the designated requirements from the built app and helper tool

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_PLIST="${PROJECT_DIR}/BatteryPro/Info.plist"
HELPER_PLIST="${PROJECT_DIR}/com.stephenlovino.BattProHelper/Helper-Info.plist"

# Check if paths were provided as arguments
if [ -n "$1" ]; then
    BUILD_PATH="$1"
    if [ -n "$2" ]; then
        HELPER_PATH_OVERRIDE="$2"
    fi
else
    # Find the build directory automatically
    BUILD_DIR="${HOME}/Library/Developer/Xcode/DerivedData"
    PROJECT_NAME="BatteryPro"
    
    # Try to find the most recent build (prefer Release, then Debug)
    BUILD_PATH=$(find "${BUILD_DIR}" -name "${PROJECT_NAME}.app" -type d -path "*/Release/*" -maxdepth 4 2>/dev/null | head -1)
    if [ -z "$BUILD_PATH" ]; then
        BUILD_PATH=$(find "${BUILD_DIR}" -name "${PROJECT_NAME}.app" -type d -maxdepth 4 2>/dev/null | head -1)
    fi
    
    if [ -z "$BUILD_PATH" ]; then
        echo "Error: Could not find built app. Please build the project in Xcode first."
        echo "Or specify the path to the built app as the first argument:"
        echo "  ./update_code_signing.sh /path/to/AlDente.app [optional: /path/to/helper]"
        exit 1
    fi
fi

# Try to find helper tool - could be embedded in app or standalone
if [ -n "$HELPER_PATH_OVERRIDE" ]; then
    HELPER_PATH="$HELPER_PATH_OVERRIDE"
elif [ -f "${BUILD_PATH}/Contents/Library/LaunchServices/com.stephenlovino.BattProHelper" ]; then
    HELPER_PATH="${BUILD_PATH}/Contents/Library/LaunchServices/com.stephenlovino.BattProHelper"
else
    # Try to find standalone helper tool in the same build directory
    BUILD_DIR=$(dirname "${BUILD_PATH}")
    HELPER_PATH=$(find "${BUILD_DIR}" -name "com.stephenlovino.BattProHelper" -type f 2>/dev/null | head -1)
    
    if [ -z "$HELPER_PATH" ] || [ ! -f "$HELPER_PATH" ]; then
        echo "Error: Helper tool not found."
        echo "  Tried: ${BUILD_PATH}/Contents/Library/LaunchServices/com.stephenlovino.BattProHelper"
        echo "  Tried: Searching in ${BUILD_DIR}"
        echo ""
        echo "Please ensure the helper tool has been built. You can also specify the helper path as the second argument:"
        echo "  ./update_code_signing.sh /path/to/BatteryPro.app /path/to/com.stephenlovino.BattProHelper"
        exit 1
    fi
fi

echo "Found app at: ${BUILD_PATH}"
echo "Found helper at: ${HELPER_PATH}"
echo ""

# Extract designated requirements
echo "Extracting designated requirements..."
APP_REQ=$(codesign -d --requirements - "${BUILD_PATH}" 2>&1 | grep -E "^designated =>" | sed 's/^designated => //' | head -1)
HELPER_REQ=$(codesign -d --requirements - "${HELPER_PATH}" 2>&1 | grep -E "^designated =>" | sed 's/^designated => //' | head -1)

# If we only got a cdhash, try to get the full requirement using -r
if [ -z "$APP_REQ" ] || [[ "$APP_REQ" == cdhash* ]]; then
    echo "App has cdhash format, trying to extract full requirement..."
    APP_REQ=$(codesign -d -r- "${BUILD_PATH}" 2>&1 | grep -A 1 "designated" | tail -1 | sed 's/^[[:space:]]*//')
fi

if [ -z "$HELPER_REQ" ] || [[ "$HELPER_REQ" == cdhash* ]]; then
    echo "Helper has cdhash format, trying to extract full requirement..."
    HELPER_REQ=$(codesign -d -r- "${HELPER_PATH}" 2>&1 | grep -A 1 "designated" | tail -1 | sed 's/^[[:space:]]*//')
fi

if [ -z "$APP_REQ" ] || [[ "$APP_REQ" == *cdhash* ]] || [[ "$APP_REQ" == \#* ]]; then
    echo ""
    echo "❌ Error: The app is not properly code signed."
    echo "   The app appears to be ad-hoc signed (cdhash only), which won't work for helper tool installation."
    echo ""
    echo "   To fix this:"
    echo "   1. Open the project in Xcode"
    echo "   2. Select the BatteryPro target → Signing & Capabilities"
    echo "   3. Make sure 'Automatically manage signing' is checked, or manually select your Team"
    echo "   4. Build the app (Product → Build or Archive)"
    echo "   5. Run this script again with the newly built app"
    echo ""
    echo "   Current signing info:"
    codesign -d --requirements - "${BUILD_PATH}" 2>&1 | head -3
    exit 1
fi

if [ -z "$HELPER_REQ" ] || [[ "$HELPER_REQ" == *cdhash* ]] || [[ "$HELPER_REQ" == \#* ]]; then
    echo ""
    echo "❌ Error: The helper tool is not properly code signed."
    echo "   The helper appears to be ad-hoc signed (cdhash only), which won't work."
    echo ""
    echo "   To fix this:"
    echo "   1. Open the project in Xcode"
    echo "   2. Select the com.stephenlovino.BattProHelper target → Signing & Capabilities"
    echo "   3. Make sure 'Automatically manage signing' is checked, or manually select your Team"
    echo "   4. Build the app (Product → Build or Archive)"
    echo "   5. Run this script again with the newly built app"
    echo ""
    echo "   Current signing info:"
    codesign -d --requirements - "${HELPER_PATH}" 2>&1 | head -3
    exit 1
fi

echo "App designated requirement:"
echo "  ${APP_REQ}"
echo ""
echo "Helper designated requirement:"
echo "  ${HELPER_REQ}"
echo ""

# Update App Info.plist (SMPrivilegedExecutables should match helper's requirement)
echo "Updating ${APP_PLIST}..."
if [ -f "$APP_PLIST" ]; then
    # Use Python to update the plist (more reliable than sed for XML)
    python3 << EOF
import plistlib
import sys

plist_path = "${APP_PLIST}"
helper_req = "${HELPER_REQ}"

try:
    with open(plist_path, 'rb') as f:
        plist = plistlib.load(f)
    
    if 'SMPrivilegedExecutables' not in plist:
        plist['SMPrivilegedExecutables'] = {}
    
    plist['SMPrivilegedExecutables']['com.stephenlovino.BattProHelper'] = helper_req
    
    with open(plist_path, 'wb') as f:
        plistlib.dump(plist, f)
    
    print("✓ Updated SMPrivilegedExecutables in app Info.plist")
except Exception as e:
    print(f"Error updating app Info.plist: {e}")
    sys.exit(1)
EOF
else
    echo "Error: App Info.plist not found at ${APP_PLIST}"
    exit 1
fi

# Update Helper Info.plist (SMAuthorizedClients should match app's requirement)
echo "Updating ${HELPER_PLIST}..."
if [ -f "$HELPER_PLIST" ]; then
    python3 << EOF
import plistlib
import sys

plist_path = "${HELPER_PLIST}"
app_req = "${APP_REQ}"

try:
    with open(plist_path, 'rb') as f:
        plist = plistlib.load(f)
    
    plist['SMAuthorizedClients'] = [app_req]
    
    with open(plist_path, 'wb') as f:
        plistlib.dump(plist, f)
    
    print("✓ Updated SMAuthorizedClients in helper Info.plist")
except Exception as e:
    print(f"Error updating helper Info.plist: {e}")
    sys.exit(1)
EOF
else
    echo "Error: Helper Info.plist not found at ${HELPER_PLIST}"
    exit 1
fi

echo ""
echo "✓ Successfully updated both Info.plist files!"
echo ""
echo "Next steps:"
echo "1. Rebuild the app in Xcode (Product → Clean Build Folder, then Build)"
echo "2. The helper tool should now install correctly when you run the app"
echo ""

