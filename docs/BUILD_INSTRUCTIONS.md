# How to Build BatteryPro in Xcode

## Prerequisites
- **Xcode**: Latest version recommended.
- **Apple Developer Account**: Required for signing executables (Personal Team is fine for local testing, Paid required for distribution/notarization).
- **SwiftLint**: (Optional) for linting.

## Project Setup
1. Open the `.xcodeproj` file in Xcode.
2. Select the **"BatteryPro"** target (the main app target).
3. Go to **Signing & Capabilities**.
4. Select your **Team** (e.g., "Stephen Lovino (Personal Team)").
5. Change the **Bundle Identifier** to something unique if needed (e.g., `com.yourname.BatteryPro`).
   *Note: Using the original bundle ID `com.davidwernhart.AlDente` is fine for personal use but problematic for distribution.*

## Building the Helper Tool
1. In the target selector (top left next to Play/Stop), select **"BattPro Helper"** (or `com.davidwernhart.Helper`).
2. Go to **Signing & Capabilities** for the Helper target.
3. Select your **Team**.
4. Ensure **"Skip Install"** is set to **NO** in Build Settings if you are archiving for release (usually YES for debug).

### Important: Verify Scheme Name
1. Click the scheme selector (top bar).
2. Click **"Manage Schemes..."**.
3. Make sure it says **"BatteryPro"** (not "com.davidwernhart.Helper")
4. If it says the helper, click it and select **"BatteryPro"**

## Build and Run
1. Make sure the scheme is set to **"BatteryPro"**.
2. Press **Cmd+R** or click the Play button.
3. The app should build and launch.

## Troubleshooting: "Helper Not Found"
If the app says "Helper not installed" or you see errors connecting:
1. Uninstall any existing helper:
   ```bash
   sudo launchctl bootout system/com.davidwernhart.Helper
   sudo rm /Library/LaunchDaemons/com.davidwernhart.Helper.plist
   sudo rm /Library/PrivilegedHelperTools/com.davidwernhart.Helper
   ```
2. Build and run **BatteryPro** again.
3. Accept the install prompt.

## Where is the Built App?
If you just build (Cmd+B), it goes to DerivedData:
`~/Library/Developer/Xcode/DerivedData/BatteryPro-*/Build/Products/Debug/BatteryPro.app`

If you Archive (Product -> Archive), it goes to the Organizer window.

## Exporting a Release Build
1. **Product -> Archive**.
2. Assuming code signing is valid, select **Distribute App**.
3. Choose **Copy App** (easiest for testing) or **Mac App Store** (if you have that set up).
4. Save the `.app` to your Desktop.

### Checking the Build
1. Open Terminal.
2. Run:
   ```bash
   codesign -dv --verbose=4 /path/to/BatteryPro.app
   ```
3. You should see `BatteryPro.app` there.

## Common Build Errors

### "Code Signing Failed"
- **Cause**: No team selected or invalid cert.
- **Fix**: Go to Signing & Capabilities, re-select your Team.

### "Embedded Binary Signing Certificate Not Trusted"
- **Cause**: Trying to run a release build locally without trusting the cert.
- **Fix**: Run the Debug build for local testing, or trust your dev cert in Keychain Access.

### "Multiple commands produce..."
- **Cause**: Derived Data stale.
- **Fix**: **Product -> Clean Build Folder** (Cmd+Shift+K), then build again.

### "PhaseScriptExecution failed"
- **Cause**: A script phase (like SwiftLint) failed.
- **Fix**: Check the build logs. If it's SwiftLint and you don't have it, remove the script phase from Build Phases.
r in Finder** in Xcode
- Or run the `update_code_signing.sh` script which will find it automatically
