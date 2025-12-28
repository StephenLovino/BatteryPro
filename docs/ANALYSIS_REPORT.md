# AlDente DMG Analysis Report

## App Information
- **Bundle ID**: `com.apphousekitchen.aldente-pro` (vs our `com.davidwernhart.AlDente`)
- **Version**: 1.36.2 (Build 89)
- **Architecture**: Universal Binary (x86_64 + arm64)
- **Helper Tool**: `com.apphousekitchen.aldente-pro.helper`

## Key Features Found

### 1. Charge Control Mechanisms
- **SMC Keys**: Uses `readSMCByte`, `setSMCByte`, `readSMCByte32`, `readSMCByte16`
- **SMCKit**: Uses SMCKit framework for SMC access
- **Helper Tool**: Has privileged helper for SMC operations
- **Energy Mode**: `setEnergyModeOnBatteryWithMode:` method found

### 2. UI Features
- **Sailing Mode**: Feature to discharge battery to a certain level
- **Heat Protection**: Stops charging when battery temperature is high
- **Intel Mode**: Special mode for Intel Macs
- **Calibration Mode**: Rebalancing and recalibration feature
- **SwiftUI Widgets**: 
  - `BatteryInfoWidget`
  - `DesktopBatteryInfoWidget`
- **Siri Shortcuts**: Full Intents support for automation

### 3. Frameworks Used
- Sparkle (auto-updates)
- Paddle (licensing/payments)
- SQLCipher (encrypted database)
- SQLite (database)
- Intents (Siri Shortcuts)

### 4. Localization
- Supports: English, German, Greek, Chinese (Simplified), Japanese

## Charge Control Approach

Based on the strings and symbols found:

1. **SMC Access**: Uses SMCKit to read/write SMC keys
2. **Helper Tool**: Privileged helper for low-level SMC operations
3. **Energy Mode**: Can set energy mode on battery
4. **Multiple Methods**: 
   - SMC byte writes (like our CH0B/BCLM)
   - Energy mode settings
   - Temperature-based protection

## Differences from Our Implementation

1. **Bundle ID**: Different (com.apphousekitchen.aldente-pro vs com.davidwernhart.AlDente)
2. **Helper Tool**: Different bundle ID
3. **Features**: Has Sailing Mode, Heat Protection, Calibration
4. **UI**: Uses SwiftUI widgets, has more advanced UI
5. **Frameworks**: Uses Sparkle, Paddle, SQLCipher (we don't)

## Recommendations

1. **Charge Control**: The approach seems similar (SMC keys), but may use additional methods
2. **UI/UX**: Can extract UI structure from storyboard/nib files
3. **Features**: Can implement similar features (Sailing Mode, Heat Protection)
4. **Architecture**: Should build universal binary for both Intel and Apple Silicon

