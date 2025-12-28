# BatteryPro Technical Documentation

## Table of Contents
1. [Architecture and SMC Interaction](#architecture-and-smc-interaction)
2. [SMC (System Management Controller) Integration](#smc-system-management-controller-integration)
3. [Helper Tool System](#helper-tool-system)
4. [Charge Control Mechanisms](#charge-control-mechanisms)
5. [Key Components](#key-components)
6. [Data Flow](#data-flow)
7. [Development Guide](#development-guide)
8. [Troubleshooting](#troubleshooting)

---

## Architecture and SMC Interaction

BatteryPro is a macOS application that controls battery charging behavior by interfacing with the System Management Controller (SMC) through a privileged helper tool. The app uses a client-server architecture:

```
┌─────────────────────────────────────────────────────────┐
│                    Main Application                      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │  AppDelegate │  │ ContentView  │  │MainWindowView│  │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘  │
│         │                  │                  │          │
│         └──────────────────┼──────────────────┘          │
│                            │                             │
│                    ┌───────▼────────┐                   │
│                    │   Helper.swift  │                   │
│                    │  (XPC Client)  │                   │
│                    └───────┬────────┘                   │
└────────────────────────────┼────────────────────────────┘
                             │
                    XPC Connection
                             │
┌────────────────────────────┼────────────────────────────┐
│                    Helper Tool                          │
│              (Privileged Daemon)                        │
│  ┌──────────────────────────────────────────────────┐  │
│  │         HelperTool.swift                         │  │
│  │  ┌────────────────────────────────────────────┐  │  │
│  │  │         SMCKit Framework                    │  │  │
│  │  │  (SMC.swift - IOKit interface)              │  │  │
│  │  └────────────────────────────────────────────┘  │  │
│  └──────────────────────────────────────────────────┘  │
│                            │                             │
│                    ┌───────▼────────┐                   │
│                    │  AppleSMC.kext │                   │
│                    │  (Kernel Driver)                   │
│                    └───────┬────────┘                   │
└────────────────────────────┼────────────────────────────┘
                             │
                    ┌────────▼────────┐
                    │  SMC Hardware   │
                    │  (On Mac Logic) │
                    └─────────────────┘
```

### Key Design Decisions

1. **Privileged Helper Tool**: SMC access requires root privileges. The helper tool runs as a LaunchDaemon with elevated permissions.
2. **XPC Communication**: Secure inter-process communication between the main app and helper tool.
3. **Platform Detection**: Automatically detects Apple Silicon vs Intel Macs and uses appropriate SMC keys.
4. **macOS Version Support**: Detects macOS Tahoe (26.x) and uses the new `CHTE` key format.

---

## SMC (System Management Controller) Integration

### What is SMC?

The System Management Controller is a microcontroller on Mac computers that manages:
- Thermal management (fans, temperature sensors)
- Power management (battery charging, power states)
- Hardware monitoring
- System configuration

### SMC Key Format

SMC uses 4-character keys to access different hardware parameters:

| Key Type | Format | Example | Purpose |
|----------|--------|---------|---------|
| Temperature | `sp78` (signed 16-bit fixed-point) | `TB0T` | Battery temperature |
| Charge Control | `ui8` (8-bit unsigned) or `ui32` (32-bit unsigned) | `CH0B`, `CHTE` | Charge inhibit control |
| Battery Info | `ui8` or `ui32` | `BCLM`, `BCCM` | Battery charge level, cycle count |
| Power State | `flag` (boolean) | `BATP` | Battery powered state |

### SMC Keys Used by BatteryPro

#### Charge Control Keys (Priority Order)

1. **`CHTE`** (macOS Tahoe/Sequoia 26.x+)
   - **Type**: `UInt32` (4 bytes)
   - **Values**: 
     - `0x00000000` = Charging enabled
     - `0x01000000` = Charging disabled
   - **Platform**: Apple Silicon (M3, M4+)

2. **`CH0B`** (Legacy/Intel)
   - **Type**: `UInt8` (1 byte)
   - **Values**:
     - `0x00` = Charging enabled
     - `0x02` = Charging disabled
   - **Platform**: Intel Macs, older Apple Silicon

3. **`CH0C`** (Alternative)
   - **Type**: `UInt8` (1 byte)
   - **Values**: Same as `CH0B`
   - **Platform**: Some Apple Silicon models

4. **`BCLM`** (Battery Charge Level Max)
   - **Type**: `UInt8` (1 byte)
   - **Values**: `0-100` (percentage)
   - **Platform**: Intel Macs (deprecated on Apple Silicon)

#### Battery Information Keys

- **`TB0T`**: Battery temperature (SP78 format)
- **`BCCM`**: Battery cycle count
- **`BRSC`**: Battery remaining state of charge

#### Discharge Control Keys

- **`CH0I`**: Charge 0 Inhibit (Apple Silicon discharge control)
- **`CHIE`**: Charge Inhibit Enable (some models)
- **`CH0J`**: Alternative discharge control

### SMC Access Flow

```swift
// 1. Main app requests charge control
Helper.instance.disableCharging()

// 2. Helper.swift creates XPC connection
let helper = helperToolConnection.remoteObjectProxyWithErrorHandler { ... }

// 3. Helper tool receives request
helper?.setSMCByte(key: "CHTE", value: 0x01000000) { success, message in
    // 4. HelperTool.swift opens SMC connection
    try SMCKit.open()
    
    // 5. SMCKit uses IOKit to communicate with AppleSMC.kext
    let smcKey = SMCKit.getKey("CHTE", type: DataTypes.UInt32)
    try SMCKit.writeData(smcKey, data: bytes)
    
    // 6. AppleSMC.kext communicates with SMC hardware
    // 7. SMC hardware controls charging circuit
}
```

### SMC Data Types

#### SP78 (Temperature Format)
```swift
// SP78: Signed 16-bit fixed-point
// Byte 0: Sign bit (bit 7) + 7-bit exponent
// Byte 1: 8-bit fraction
let sign = (data.0 & 0x80) == 0 ? 1.0 : -1.0
let exponent = Double(data.0 & 0x7F)  // Mask sign bit
let fraction = Double(data.1) / 256.0
let temperature = sign * (exponent + fraction)
```

#### UInt8 (Single Byte)
```swift
// Direct byte value
let value: UInt8 = 0x02  // Disable charging
```

#### UInt32 (Four Bytes)
```swift
// 32-bit value (used for CHTE on macOS Tahoe)
let value: UInt32 = 0x01000000  // Disable charging
// Byte order: [byte0, byte1, byte2, byte3]
// = [0x01, 0x00, 0x00, 0x00]
```

---

## Helper Tool System

### Architecture

The helper tool is a **LaunchDaemon** that runs with root privileges:

```
/Library/PrivilegedHelperTools/com.davidwernhart.Helper
/Library/LaunchDaemons/com.davidwernhart.Helper.plist
```

### Installation Process

1. **SMJobBless**: Uses Apple's `SMJobBless` API to install the helper
2. **Authorization**: Requires admin password via `AuthorizationCreate`
3. **Code Signing**: Must be properly code-signed with designated requirements
4. **LaunchDaemon**: Automatically starts on system boot

### XPC Communication

The app communicates with the helper via **NSXPCConnection**:

```swift
// Connection setup (in Helper.swift)
lazy var helperToolConnection: NSXPCConnection = {
    let connection = NSXPCConnection(machServiceName: "com.davidwernhart.Helper.mach", options: [])
    connection.remoteObjectInterface = NSXPCInterface(with: HelperToolProtocol.self)
    connection.resume()
    return connection
}()
```

### Helper Tool Protocol

Defined in `Common/HelperToolProtocol.swift`:

```swift
@objc protocol HelperToolProtocol {
    func getVersion(withReply reply: @escaping (String) -> Void)
    func setSMCByte(key: String, value: UInt8, withReply reply: @escaping (Bool, String) -> Void)
    func readSMCByte(key: String, withReply reply: @escaping (UInt8) -> Void)
    func readSMCUInt32(key: String, withReply reply: @escaping (UInt32) -> Void)
    func setSMCUInt32(key: String, value: UInt32, withReply reply: @escaping (Bool, String) -> Void)
    func readSMCSP78(key: String, withReply reply: @escaping (Double) -> Void)
    // ... power management methods
}
```

### Helper Tool Lifecycle

1. **Installation**: First launch prompts for admin password
2. **Activation**: Helper starts automatically via LaunchDaemon
3. **Connection**: Main app connects via XPC on startup
4. **Monitoring**: Helper monitors main app process and exits if app closes
5. **Cleanup**: Helper restores SMC values on exit

---

## Charge Control Mechanisms

### Detection Flow

On app startup, the system detects which SMC keys are available:

```swift
// 1. Try CHTE first (macOS Tahoe)
SMCWriteUInt32(key: "CHTE", value: 0x00000000) { success in
    if success {
        workingChargeKey = "CHTE"
        usesTahoeKeys = true
        return
    }
    
    // 2. Try CH0B (legacy)
    SMCWriteByte(key: "CH0B", value: 0x00) { success in
        if success {
            workingChargeKey = "CH0B"
            return
        }
        // 3. Try CH0C, BCLM, etc.
    }
}
```

### Charge Control Logic

The main charge control loop runs every 5 seconds:

```swift
Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { timer in
    Helper.instance.getChargingInfo { (Name, Capacity, IsCharging, MaxCapacity) in
        let target = Int(SMCPresenter.shared.value)  // User-set limit
        
        if Capacity < target {
            // Battery below limit - enable charging
            Helper.instance.enableCharging()
        } else {
            // Battery at/above limit - disable charging
            Helper.instance.disableCharging()
        }
    }
}
```

### Enable/Disable Charging

```swift
func enableCharging() {
    if let key = workingChargeKey {
        if key == "CHTE" {
            // macOS Tahoe: Use UInt32
            SMCWriteUInt32(key: key, value: 0x00000000) { success, message in
                chargeInhibited = false
            }
        } else {
            // Legacy: Use UInt8
            SMCWriteByte(key: key, value: 0x00) { success, message in
                chargeInhibited = false
            }
        }
    }
}

func disableCharging() {
    if let key = workingChargeKey {
        if key == "CHTE" {
            SMCWriteUInt32(key: key, value: 0x01000000) { success, message in
                chargeInhibited = true
            }
        } else {
            let value: UInt8 = (key == "CH0B" || key == "CH0C") ? 0x02 : 0x01
            SMCWriteByte(key: key, value: value) { success, message in
                chargeInhibited = true
            }
        }
    }
}
```

### Feature Priority

When multiple features are enabled, priority is:

1. **Heat Protection** (highest priority)
   - If temperature > max temp → disable charging
   - Overrides all other controls

2. **Sailing Mode**
   - Discharge battery to target level
   - Uses discharge control keys (`CH0I`, `CHIE`, `CH0J`)

3. **Normal Charge Control**
   - Maintain battery at user-set limit
   - Uses charge inhibit keys (`CHTE`, `CH0B`, `CH0C`)

---

## Key Components

### Main Application

#### `AppDelegate.swift`
- **Role**: Application lifecycle, status bar item, popover management
- **Key Responsibilities**:
  - Initialize helper connection
  - Create status bar menu item
  - Manage main window
  - Run charge control timer loop
  - Handle feature priority (Heat Protection > Sailing Mode > Normal)

#### `ContentView.swift`
- **Role**: Popover menu bar interface
- **Features**:
  - Quick charge limit buttons
  - Discharge/Top Up controls
  - Slider for fine-grained control
  - Button to open full window

#### `MainWindowView.swift`
- **Role**: Full application window
- **Components**:
  - Sidebar navigation
  - Dashboard view (widget grid)
  - Charge Control view
  - Feature views (Sailing Mode, Heat Protection, etc.)

### Helper System

#### `Helper.swift`
- **Role**: XPC client interface
- **Key Methods**:
  - `enableCharging()` / `disableCharging()`
  - `getBatteryTemperature()`
  - `checkChargeControlKeyAvailability()`
  - `getChargingInfo()`

#### `com.davidwernhart.Helper/HelperTool.swift`
- **Role**: XPC server, privileged operations
- **Key Methods**:
  - `setSMCByte()` / `setSMCUInt32()`
  - `readSMCByte()` / `readSMCUInt32()` / `readSMCSP78()`
  - `createAssertion()` / `releaseAssertion()` (power management)

#### `com.davidwernhart.Helper/SMC.swift`
- **Role**: SMCKit framework - low-level SMC access
- **Key Functions**:
  - `SMCKit.open()` - Open connection to AppleSMC.kext
  - `SMCKit.getKey()` - Get SMC key structure
  - `SMCKit.readData()` / `SMCKit.writeData()` - Read/write operations

### Data Models

#### `SMCPresenter.swift`
- **Role**: Observable object for charge limit value
- **Features**:
  - Persists to UserDefaults
  - Notifies UI of changes
  - Triggers immediate charge control on change

#### `PersistanceManager.swift`
- **Role**: User preferences storage
- **Stores**:
  - Charge limit
  - Feature states (Sailing Mode, Heat Protection, etc.)
  - Power mode settings
  - Launch at login preference

#### `BatteryInfo.swift` (in MainWindowView.swift)
- **Role**: Battery statistics
- **Properties**:
  - Design/Max/Current capacity
  - Cycle count
  - Temperature
  - Charging status
  - Condition

---

## Data Flow

### Charge Limit Change Flow

```
User adjusts slider
    ↓
SMCPresenter.setValue()
    ↓
PersistanceManager.save()
    ↓
Helper.instance.disableCharging() / enableCharging()
    ↓
XPC call to HelperTool.setSMCByte() / setSMCUInt32()
    ↓
SMCKit.writeData()
    ↓
AppleSMC.kext → SMC Hardware
    ↓
Charging circuit controlled
```

### Battery Info Update Flow

```
Timer fires (every 5 seconds)
    ↓
Helper.instance.getChargingInfo()
    ↓
IOKit power sources API
    ↓
BatteryInfo.update()
    ↓
UI updates (SwiftUI @Published)
```

### Temperature Reading Flow

```
Helper.instance.getBatteryTemperature()
    ↓
XPC call to HelperTool.readSMCSP78(key: "TB0T")
    ↓
SMCKit.readData() with SP78 format
    ↓
Parse SP78 → Celsius
    ↓
Return to main app
    ↓
Update BatteryInfo.temperature
```

---

## Development Guide

### Adding a New Feature

1. **Add to PersistanceManager**:
```swift
// In PersistanceManager.swift
var newFeatureEnabled: Bool {
    get { UserDefaults.standard.bool(forKey: "newFeatureEnabled") }
    set { UserDefaults.standard.set(newValue, forKey: "newFeatureEnabled") }
}
```

2. **Add to Helper Protocol** (if needs SMC access):
```swift
// In Common/HelperToolProtocol.swift
func newFeatureMethod(withReply reply: @escaping (Bool) -> Void)
```

3. **Implement in HelperTool**:
```swift
// In com.davidwernhart.Helper/HelperTool.swift
func newFeatureMethod(withReply reply: @escaping (Bool) -> Void) {
    // SMC operations here
    reply(true)
}
```

4. **Add UI View**:
```swift
// In MainWindowView.swift
struct NewFeatureView: View {
    // UI implementation
}
```

5. **Integrate into charge control loop** (if affects charging):
```swift
// In AppDelegate.swift timer
if PersistanceManager.instance.newFeatureEnabled {
    // Feature logic
}
```

### Testing SMC Keys

To test if an SMC key exists and is writable:

```swift
Helper.instance.SMCWriteByte(key: "TEST", value: 0x00) { success, message in
    if success {
        print("Key exists and is writable")
    } else {
        print("Key not available: \(message)")
    }
}
```

### Debugging SMC Access

1. **Check helper logs**:
```bash
log show --predicate 'process == "com.davidwernhart.Helper"' --last 5m
```

2. **Verify helper is running**:
```bash
launchctl list | grep davidwernhart
ps aux | grep Helper
```

3. **Check SMC driver**:
```bash
kextstat | grep -i smc
```

4. **Test SMC access directly** (requires root):
```bash
sudo /usr/local/bin/smc -k CHTE -r  # Read CHTE key
```

### Code Signing Requirements

The helper tool **must** be properly code-signed:

1. **Main App**: Developer ID or Development certificate
2. **Helper Tool**: Same certificate as main app
3. **Designated Requirements**: Must match in both app and helper Info.plist

See `update_code_signing.sh` for automated updates.
Example: `update_code_signing.sh /path/to/BatteryPro.app [optional: /path/to/helper]`

---

## Troubleshooting

### Charge Control Not Working

1. **Check helper version**:
   - App checks helper version on startup
   - If mismatch, helper will be reinstalled

2. **Verify SMC key detection**:
   - Check console logs for "Found active charge control key"
   - Try manual key detection in Helper.swift

3. **Check permissions**:
   - Helper must be installed with admin password
   - Verify helper is running: `launchctl list | grep Helper`

4. **Platform-specific issues**:
   - **M4 MacBook Air**: Should use `CHTE` key (macOS Tahoe)
   - **Intel Macs**: Should use `CH0B` or `CH0C`
   - **Older Apple Silicon**: May need `CH0B` fallback

### Temperature Reading Issues

If temperature shows invalid values (e.g., 52155°C):

1. **Check SP78 format parsing**:
   - Temperature uses SP78 format, not UInt32
   - Verify `readSMCSP78` is being used, not `readSMCUInt32`

2. **Sanity check values**:
   - Temperature should be between -10°C and 100°C
   - Invalid values are replaced with default (25°C)

### Helper Tool Not Installing

1. **Code signing**:
   - Both app and helper must be signed
   - Designated requirements must match

2. **Authorization**:
   - User must enter admin password
   - Check System Preferences → Security & Privacy

3. **Manual installation**:
   ```bash
   sudo /path/to/helper --install
   ```

### XPC Connection Errors

1. **Check helper is running**:
   ```bash
   launchctl list | grep Helper
   ```

2. **Restart helper**:
   ```bash
   sudo launchctl unload /Library/LaunchDaemons/com.davidwernhart.Helper.plist
   sudo launchctl load /Library/LaunchDaemons/com.davidwernhart.Helper.plist
   ```

3. **Check Mach service name**:
   - Must match in helper Info.plist and connection code
   - Current: `com.davidwernhart.Helper.mach`

---

## Platform-Specific Notes

### macOS Tahoe (26.x) / Sequoia

- Uses **`CHTE`** key (UInt32 format)
- Values: `0x00000000` (enable), `0x01000000` (disable)
- Detected automatically on startup

### Apple Silicon (M1, M2, M3, M4)

- Primary: `CHTE` (if macOS 26.x+)
- Fallback: `CH0B`, `CH0C`
- Discharge control: `CH0I`, `CHIE`, `CH0J`

### Intel Macs

- Primary: `CH0B`
- Alternative: `CH0C`
- Legacy: `BCLM` (Battery Charge Level Max)

---

## Security Considerations

1. **Privileged Access**: Helper tool runs as root - must be carefully audited
2. **Code Signing**: Required for helper installation
3. **XPC Validation**: All XPC messages should be validated
4. **SMC Safety**: Invalid SMC writes can damage hardware - always validate values
5. **User Consent**: Admin password required for helper installation

---

## References

- [SMCKit Framework](https://github.com/beltex/SMCKit) - Original SMC library
- [Apple IOKit Documentation](https://developer.apple.com/documentation/iokit)
- [SMJobBless API](https://developer.apple.com/documentation/servicemanagement/1501437-smjobbless)
- [NSXPCConnection Documentation](https://developer.apple.com/documentation/foundation/nsxpcconnection)

---

## Contributing

When adding new features:

1. Test on both Intel and Apple Silicon Macs
2. Test on different macOS versions (especially macOS 26.x+)
3. Verify SMC key availability before using
4. Add proper error handling and logging
5. Update this documentation

---

**Last Updated**: December 2025
**Maintainer**: See repository contributors


