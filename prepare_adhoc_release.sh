#!/bin/bash
set -e

# Path to the app we want to fix
APP_PATH="$1"

if [ -z "$APP_PATH" ]; then
    echo "Usage: ./prepare_adhoc_release.sh /path/to/BatteryPro.app"
    exit 1
fi

echo "🔧 Preparing Ad-Hoc Release for: $APP_PATH"

# Define Paths
HELPER_PATH="$APP_PATH/Contents/Library/LaunchServices/com.stephenlovino.BattProHelper"
APP_INFO_PLIST="$APP_PATH/Contents/Info.plist"
HELPER_INFO_PLIST="$HELPER_PATH/Contents/Info.plist"

# Define the "Ad-Hoc" requirements
# When signed with ad-hoc (-), the requirement is just the identifier.
APP_REQ='identifier "com.stephenlovino.BatteryPro"'
HELPER_REQ='identifier "com.stephenlovino.BattProHelper"'

echo "1️⃣  Updating Info.plist requirements -> Ad-Hoc..."

# Update App's expectation of Helper
# We use Python here safely to handle the dictionary structure
python3 << EOF
import plistlib
import sys

try:
    with open("$APP_INFO_PLIST", 'rb') as f:
        plist = plistlib.load(f)
    
    # Update SMPrivilegedExecutables
    if 'SMPrivilegedExecutables' not in plist:
        plist['SMPrivilegedExecutables'] = {}
    
    plist['SMPrivilegedExecutables']['com.stephenlovino.BattProHelper'] = '$HELPER_REQ'
    
    with open("$APP_INFO_PLIST", 'wb') as f:
        plistlib.dump(plist, f)
    print("   ✓ Updated App Info.plist")
except Exception as e:
    print(f"   ❌ Error updating App Info.plist: {e}")
    sys.exit(1)
EOF

# Update Helper's expectation of App
# We check if file exists first just in case
if [ -f "$HELPER_INFO_PLIST" ]; then
    python3 << EOF
import plistlib
import sys

try:
    with open("$HELPER_INFO_PLIST", 'rb') as f:
        plist = plistlib.load(f)
    
    # Update SMAuthorizedClients array
    plist['SMAuthorizedClients'] = ['$APP_REQ']
    
    with open("$HELPER_INFO_PLIST", 'wb') as f:
        plistlib.dump(plist, f)
    print("   ✓ Updated Helper Info.plist")
except Exception as e:
    print(f"   ❌ Error updating Helper Info.plist: {e}")
    sys.exit(1)
EOF
fi

echo "2️⃣  Re-signing with Ad-Hoc Identity (-)..."

# Sign Helper first
if [ -f "$HELPER_PATH" ]; then
    echo "   Signing Helper..."
    codesign --force --sign - --identifier "com.stephenlovino.BattProHelper" --generate-entitlement-der "$HELPER_PATH"
fi


# Sign LaunchAtLogin Helper (New in v5)
LAL_HELPER_PATH="$APP_PATH/Contents/Library/LoginItems/LaunchAtLoginHelper.app"
if [ -d "$LAL_HELPER_PATH" ]; then
    echo "   Signing LaunchAtLogin Helper..."
    codesign --force --sign - --generate-entitlement-der "$LAL_HELPER_PATH"
fi

# Sign Main App
echo "   Signing Main App..."
codesign --force --sign - --identifier "com.stephenlovino.BatteryPro" --generate-entitlement-der "$APP_PATH"

echo "✅ Ad-Hoc Preparation Complete!"
echo "   Constraint: 'Unidentified Developer'"
echo "   Benefit: Users can Right Click > Open or accept in Privacy Settings (No more 'Damaged')"
