#!/bin/bash

# Configuration
APP_NAME="BatteryPro"
VOL_NAME="BatteryPro Installer"
DMG_NAME="BatteryPro_Installer_v1.2.3.dmg"
ICON_PATH="BatteryPro/Assets.xcassets/AppIcon.appiconset/icon_512x512.png"

# Argument support for app path
if [ -n "$1" ]; then
    APP_PATH="$1"
else
    # Default fallback
    echo "Usage: ./build_dmg_professional.sh /path/to/BatteryPro.app"
    exit 1
fi

# Clean previous
rm -f "$DMG_NAME"

echo "💿 Creating Professional DMG for: $APP_PATH"

create-dmg \
  --volname "$VOL_NAME" \
  --volicon "$ICON_PATH" \
  --background "dmg_bg_plain_final.png" \
  --window-pos 200 120 \
  --window-size 800 400 \
  --icon-size 100 \
  --icon "$APP_NAME.app" 200 150 \
  --hide-extension "$APP_NAME.app" \
  --app-drop-link 600 175 \
  --icon ".VolumeIcon.icns" 2000 0 \
  "$DMG_NAME" \
  "$APP_PATH"

echo "✅ DMG Created: $DMG_NAME"
