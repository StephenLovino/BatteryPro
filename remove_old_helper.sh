#!/bin/bash

# Script to remove the old helper tool so it can be reinstalled with proper permissions

echo "=== Removing old helper tool ==="
echo ""

# Check if helper is installed
if [ -f "/Library/PrivilegedHelperTools/com.davidwernhart.Helper" ]; then
    echo "Found helper tool at /Library/PrivilegedHelperTools/com.davidwernhart.Helper"
    echo ""
    
    # Check if it's running
    if launchctl list | grep -q "com.davidwernhart.Helper"; then
        echo "Helper is running, unloading it..."
        sudo launchctl bootout system/com.davidwernhart.Helper 2>/dev/null || echo "Could not unload (may not be running)"
    fi
    
    echo "Removing helper tool..."
    sudo rm -f /Library/PrivilegedHelperTools/com.davidwernhart.Helper
    
    if [ $? -eq 0 ]; then
        echo "✓ Helper tool removed successfully"
    else
        echo "✗ Failed to remove helper tool (you may need to run with sudo)"
        exit 1
    fi
else
    echo "No helper tool found - nothing to remove"
fi

echo ""
echo "=== Next Steps ==="
echo "1. Rebuild the app in Xcode (Product → Clean Build Folder, then Build)"
echo "2. Run the app - it should now prompt for admin password to install the helper"
echo "3. Enter your password when prompted"
echo ""

