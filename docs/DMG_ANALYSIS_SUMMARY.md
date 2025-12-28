# AlDente DMG Analysis Summary

## Key Findings

### Charge Control Mechanisms

The newer version uses **multiple approaches** for charge control:

1. **SMC Keys** (Same as ours):
   - `readSMCByte`, `setSMCByte`, `readSMCByte32`, `readSMCByte16`
   - Uses SMCKit framework
   - Helper tool for privileged access

2. **Energy Mode** (NEW):
   - `setEnergyModeOnBatteryWithMode:` method
   - Can set different energy modes on battery
   - This might be an additional layer beyond SMC keys

3. **Power Modes** (NEW):
   - Low Power Mode
   - High Power Mode
   - `SetPowerModeIntent` for Siri Shortcuts
   - Widgets for power mode selection

4. **Temperature-Based Protection** (NEW):
   - `HeatProtect` feature
   - Stops charging when battery temperature is high
   - Monitors battery temperature

### UI/UX Structure

1. **SwiftUI Widgets**:
   - `BatteryInfoWidget`
   - `DesktopBatteryInfoWidget`
   - `DashboardCalibrationWidget`
   - `LowPowerModeWidget`
   - `HighLowPowerModeWidget`
   - `CompactLPMPowerModeWidget`
   - `CompactPowerModeWidget`

2. **Storyboard-Based**:
   - `Main.storyboardc` (compiled storyboard)
   - Main menu structure

3. **Features**:
   - Sailing Mode (discharge to a level)
   - Heat Protection
   - Calibration Mode
   - Intel Mode (for Intel Macs)
   - Power Mode Selector

### Architecture Differences

1. **Universal Binary**: Built for both x86_64 and arm64
2. **Frameworks**: Uses Sparkle, Paddle, SQLCipher (we don't need these)
3. **Bundle ID**: Different (`com.apphousekitchen.aldente-pro`)

## What We Can Extract/Implement

### 1. Charge Control Improvements

**Energy Mode Approach**:
- The `setEnergyModeOnBatteryWithMode:` suggests they might be using IOKit power management in addition to SMC
- This could be more reliable than just SMC keys
- We should investigate IOKit power management APIs

**Power Modes**:
- Low Power Mode / High Power Mode
- Could be implemented using IOPowerSources API
- Might provide better control than just SMC

### 2. UI Features to Clone

**SwiftUI Widgets**:
- Battery info widgets
- Power mode widgets
- Calibration widgets

**Features**:
- Sailing Mode (discharge to a level)
- Heat Protection (temperature monitoring)
- Calibration Mode

### 3. Code Structure

The app structure suggests:
- Main app uses SwiftUI for widgets
- Storyboard for main menu
- Helper tool for SMC operations
- Separate components for each feature

## Recommendations

### Immediate Actions

1. **Investigate Energy Mode**:
   - Look into IOKit power management APIs
   - See if we can use `IOPMSetPowerMode` or similar
   - This might be more reliable than SMC on Apple Silicon

2. **Add Temperature Monitoring**:
   - Read battery temperature from SMC
   - Implement heat protection feature
   - Stop charging when temperature is too high

3. **Implement Sailing Mode**:
   - Allow user to set a discharge target
   - Monitor battery level
   - Stop discharging when target is reached

4. **Add Power Modes**:
   - Low Power Mode (reduce system performance)
   - High Power Mode (maximum performance)
   - Use IOKit or pmset commands

### Long-term Improvements

1. **Universal Binary**: Build for both Intel and Apple Silicon
2. **SwiftUI Widgets**: Add macOS widgets for battery info
3. **Siri Shortcuts**: Add Intents support for automation
4. **Calibration**: Implement battery calibration feature

## Next Steps

1. ✅ Extract UI structure from storyboard (if possible)
2. ✅ Analyze helper tool for charge control methods
3. ⏳ Research IOKit energy mode APIs
4. ⏳ Implement temperature monitoring
5. ⏳ Add Sailing Mode feature
6. ⏳ Create SwiftUI widgets

## Files to Examine

- `extracted_app/AlDente.app/Contents/MacOS/AlDente` - Main binary
- `extracted_app/AlDente.app/Contents/Library/LaunchServices/com.apphousekitchen.aldente-pro.helper` - Helper tool
- `extracted_app/AlDente.app/Contents/Resources/Base.lproj/Main.storyboardc` - UI structure
- `extracted_app/AlDente.app/Contents/Resources/en.lproj/Default.strings` - UI strings

