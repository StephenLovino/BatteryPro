# Testing Charge Limiting

## Prerequisites
1. ✅ Helper tool is installed (found at `/Library/PrivilegedHelperTools/com.davidwernhart.Helper`)
2. ⚠️ Helper needs to be running (will start when app runs)

## How to Test

### Step 1: Run the App
1. Build and run the app in Xcode, or run the built app
2. The helper tool should connect automatically
3. Check Console.app for messages like:
   - `"helper found!"` - Helper connected successfully
   - `"Helper not initialized yet, waiting..."` - Still connecting

### Step 2: Set a Charge Limit
1. Click the AlDente icon in the menu bar
2. Set a charge limit (e.g., 50% or 80%)
3. You should see immediate action in the console:
   - `"IMMEDIATE: Enabled/Disabled charging"` messages

### Step 3: Monitor the Behavior

**In Console.app, you should see every 5 seconds:**
```
TARGET: 50 CURRENT: 45 ISCHARGING: true CHARGE INHIBITED: false ACTION: NEED TO CHARGE
```

**When battery reaches the limit:**
```
TARGET: 50 CURRENT: 50 ISCHARGING: false CHARGE INHIBITED: true ACTION: IS PERFECT - STOPPING CHARGE
```

### Step 4: Verify Physical Behavior

**Test Case 1: Battery Below Limit**
- Set limit to 50%
- If battery is at 45%:
  - ✅ Should be charging
  - ✅ System should show "Charging" in battery menu
  - ✅ Console shows `CHARGE INHIBITED: false`

**Test Case 2: Battery At/Above Limit**
- Set limit to 50%
- If battery reaches 50%:
  - ✅ Charging should stop
  - ✅ System should show "Not Charging" (even with charger connected)
  - ✅ Console shows `CHARGE INHIBITED: true`
  - ✅ Battery percentage should stay at or near the limit

**Test Case 3: Change Limit While Charging**
- Battery at 60%, limit set to 50%
- Should immediately stop charging
- Battery at 40%, limit set to 80%
- Should immediately start charging

### Step 5: Check System Battery Status

**In Terminal, run:**
```bash
pmset -g batt
```

**Expected output when limit is reached:**
- `"AC Power"` - Charger connected
- `"Not Charging"` - Battery at limit, charging disabled
- Battery percentage should stabilize at your set limit

## Troubleshooting

### Helper Not Connecting
- Check Console for errors
- Use "Reinstall Helper" button in Settings
- Verify helper is installed: `ls -la /Library/PrivilegedHelperTools/com.davidwernhart.Helper`

### Charging Not Stopping
- Check if `oldKey` mode is enabled (uses BCLM instead of CH0B)
- Verify console shows `CHARGE INHIBITED: true`
- Check that helper is initialized: Console should show `"helper found!"`

### Immediate Response Not Working
- Check console for `"IMMEDIATE:"` messages when changing limit
- Verify `Helper.instance.isInitialized` is true
- Check that `PersistanceManager.instance.oldKey` is false

## Console Monitoring

**To watch the logs in real-time:**
```bash
log stream --predicate 'process == "AlDente"' --level debug | grep -E "(TARGET|CURRENT|CHARGE|ACTION|helper)"
```

**Or use Console.app:**
1. Open Console.app
2. Filter by "AlDente"
3. Look for messages every 5 seconds showing TARGET, CURRENT, and ACTION

## Success Indicators

✅ **Working correctly if:**
- Console shows regular updates every 5 seconds
- `CHARGE INHIBITED` toggles between `true` and `false` appropriately
- Battery stops charging when it reaches your set limit
- Battery starts charging when it drops below your set limit
- System battery menu shows "Not Charging" when at limit (even with charger connected)

❌ **Not working if:**
- Console shows `"Helper not initialized yet, waiting..."` continuously
- `CHARGE INHIBITED` never changes
- Battery continues charging past the limit
- No console messages appear

