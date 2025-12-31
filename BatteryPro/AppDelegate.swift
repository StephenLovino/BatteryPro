//
//  AppDelegate.swift
//  AlDente
//
//  Created by David Wernhart on 09.02.20.
//  Copyright © 2020 David Wernhart. All rights reserved.
//

import AppKit
import SwiftUI
import LaunchAtLogin
import Foundation
import IOKit.ps
import IOKit.pwr_mgt

extension ProcessInfo {
        /// Returns a `String` representing the machine hardware name or nil if there was an error invoking `uname(_:)` or decoding the response.
        ///
        /// Return value is the equivalent to running `$ uname -m` in shell.
        var machineHardwareName: String? {
                var sysinfo = utsname()
                let result = uname(&sysinfo)
                guard result == EXIT_SUCCESS else { return nil }
                let data = Data(bytes: &sysinfo.machine, count: Int(_SYS_NAMELEN))
                guard let identifier = String(bytes: data, encoding: .ascii) else { return nil }
                return identifier.trimmingCharacters(in: .controlCharacters)
        }
}

@NSApplicationMain
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var window: NSWindow!
    var statusBarItem: NSStatusItem!
    var popover: NSPopover!
    
    func applicationWillTerminate(_ aNotification: Notification) {
        print("Application Terminating...")
        
        // Release any sleep assertions
        Helper.instance.enableSleep()
        
        // Stop Charging behavior
        if PersistanceManager.instance.stopChargingWhenAppClosed {
            print("Stop Charging When App Closed is ENABLED. Disabling charging...")
            Helper.instance.disableCharging()
        } else {
            print("Restoring charging...")
            Helper.instance.enableCharging() // Defaults to BCLM 100 or CH0B 0 (Enable)
        }
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        print("=== BatteryPro Starting ===")
        
        // Setup Sleep Monitoring
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(handleSleep(_:)), name: NSWorkspace.willSleepNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(handleWake(_:)), name: NSWorkspace.didWakeNotification, object: nil)
        
        print("Loading persistence data...")
        PersistanceManager.instance.load() // Load early for correct init state
        
        print("Creating ContentView...")
        let contentView = ContentView()
        print("ContentView created")
        
        print("Creating popover...")
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 450, height: 140)
        popover.behavior = .transient
        popover.animates = true
        let hostingController = NSHostingController(rootView: contentView)
        hostingController.view.frame = NSRect(x: 0, y: 0, width: 450, height: 140)
        popover.contentViewController = hostingController
        self.popover = popover
        print("Popover created")

        print("Creating status bar item...")
        let statusBar = NSStatusBar.system
        statusBarItem = statusBar.statusItem(withLength: NSStatusItem.variableLength)
        if let icon = NSImage(named: "menubaricon") {
            statusBarItem.button?.image = icon
            print("Using custom menubar icon")
        } else {
            // Fallback to system icon if custom icon not found
            statusBarItem.button?.image = NSImage(systemSymbolName: "battery.100", accessibilityDescription: "BatteryPro")
            print("Using system icon fallback")
        }
        statusBarItem.button?.action = #selector(togglePopover(_:))
        print("Status bar item created")

        print("Setting up notifications...")
        // Listen for popover size updates
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("UpdatePopoverSize"),
            object: nil,
            queue: .main
        ) { notification in
            if let userInfo = notification.userInfo,
               let width = userInfo["width"] as? CGFloat,
               let height = userInfo["height"] as? CGFloat {
                self.popover.contentSize = NSSize(width: width, height: height)
                if let hostingController = self.popover.contentViewController {
                    hostingController.view.frame = NSRect(x: 0, y: 0, width: width, height: height)
                }
            }
        }

        // Listen for dock icon visibility updates
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("UpdateDockIconVisibility"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            self.updateDockIcon()
        }
        
        // Listen for open main window requests
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("OpenMainWindow"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            self.openMainWindow()
        }
        
            print("Setting platform key...")
            Helper.instance.setPlatformKey()
            
            // Check which SMC charge control keys are available
            print("Checking available charge control keys...")
            Helper.instance.checkChargeControlAvailability { availableKey in
                if let key = availableKey {
                    print("✓ Charge control available via SMC key: \(key)")
                } else {
                    print("⚠ WARNING: No charge control keys available on this Mac")
                    print("   Tried: CHWA, CH0C, CH0B, BCLM")
                    print("   Charge limiting may not work")
                }
            }

            print("Checking helper version...")
        Helper.instance.checkHelperVersion{(foundHelper) in
            if(foundHelper){
                print("helper found!")
            }
            else{
                print("helper not found, installing...")
                Helper.instance.installHelper()
            }
        }
        
        print("Loading persistence data...")
        // Load persistence data first
        // PersistanceManager.instance.load() // Already loaded at start
        print("Persistence loaded")
        
        print("Loading SMC presenter value...")
        SMCPresenter.shared.loadValue()
        print("SMC presenter loaded")
        
        print("Checking charging status...")
        Helper.instance.checkCharging()
        print("Charging status checked")
        
        var actionMsg:String?

        Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { timer in
            // Always check helper version periodically to ensure connection
            if !Helper.instance.isInitialized {
                Helper.instance.checkHelperVersion { foundHelper in
                    if foundHelper {
                        print("Helper initialized in timer!")
                    }
                }
            }
            
            if(Helper.instance.isInitialized){
                // Gate: Wait for Charge Control to be ready (keys checked)
                if !Helper.instance.chargeControlReady {
                    print("Waiting for charge control initialization...")
                    return
                }
                
                // Reload persistence to ensure we have latest values
                PersistanceManager.instance.load()
                
                Helper.instance.getChargingInfo { (Name, Capacity, IsCharging, MaxCapacity) in
                    
                    // Check Sleep Assertion status (dynamic update)
                    Helper.instance.checkSleepAssertion(currentCharge: Capacity)
                    
                    // Enforce Low Power Mode Policy
                    Helper.instance.enforceLowPowerMode()

                    // Check Heat Protection first (async, so handle it separately)
                    if PersistanceManager.instance.heatProtectionEnabled {
                        Helper.instance.getBatteryTemperature { [weak self] temp in
                            guard let self = self else { return }
                            if temp > PersistanceManager.instance.heatProtectionMaxTemp {
                                if !Helper.instance.chargeInhibited {
                                    Helper.instance.disableCharging()
                                    print("HEAT PROTECTION: Disabled charging - Temperature \(String(format: "%.1f", temp))°C > Max \(String(format: "%.1f", PersistanceManager.instance.heatProtectionMaxTemp))°C")
                                }
                                // Don't process other charge control if heat protection is active
                                return
                            }
                            // Temperature is OK, continue with normal charge control
                            self.processChargeControlWithModes(Capacity: Capacity, IsCharging: IsCharging, actionMsg: &actionMsg)
                        }
                        return // Exit early, will continue in temperature callback if temp is OK
                    }
                    
                    // No heat protection, process normally
                    self.processChargeControlWithModes(Capacity: Capacity, IsCharging: IsCharging, actionMsg: &actionMsg)
                }
                // Update status string without checking charging (to avoid overwriting chargeInhibited)
                DispatchQueue.main.async {
                    Helper.instance.setStatusString()
                }
                
            } else {
                print("Helper not initialized yet, waiting... isInitialized=\(Helper.instance.isInitialized)")
            }
        }
        
    }

    @objc func togglePopover(_ sender: AnyObject?) {
        // Check for Option key to open main window directly
        if let event = NSApp.currentEvent, event.modifierFlags.contains(.option) {
            openMainWindow()
            return
        }
        
        popover.contentViewController?.view.window?.becomeKey()
        Helper.instance.setStatusString()
        if let button = self.statusBarItem.button {
            if popover.isShown {
                popover.performClose(sender)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
    }
    
    func openMainWindow() {
        if window == nil {
            let mainWindowView = MainWindowView()
            let hostingController = NSHostingController(rootView: mainWindowView)
            
            window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 1000, height: 600),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = "BatteryPro"
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            
            // Enable proper transparency for Glass Effect
            window.isOpaque = false
            window.backgroundColor = .clear
            
            window.contentViewController = hostingController
            window.center()
            window.setFrameAutosaveName("Main Window")
            window.isReleasedWhenClosed = false
            window.delegate = self
        }
        
        window.makeKeyAndOrderFront(nil)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    

    
    



    func updateDockIcon() {
        if PersistanceManager.instance.showDockIcon {
             NSApp.setActivationPolicy(.regular)
        } else {
             // Only hide if window is NOT open. If window is open, we need dock icon.
             if window == nil || !window.isVisible {
                 NSApp.setActivationPolicy(.accessory)
             }
        }
    }
    
    // MARK: - NSWindowDelegate
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    // MARK: - Charge Control Logic
    private func processChargeControlWithModes(Capacity: Int, IsCharging: Bool, actionMsg: inout String?) {
        // [NEW] Check Calibration Mode first
        if PersistanceManager.instance.calibrationModeEnabled {
            processCalibrationLogic(Capacity: Capacity, IsCharging: IsCharging, actionMsg: &actionMsg)
            return
        }
    
        // [PRIORITY 1] Check Manual Bypass FIRST - This is a hard override
        // Manual Bypass takes precedence over all other charging modes
        if SMCPresenter.shared.bypassEnabled {
             // Ensure charging is disabled
             if !Helper.instance.chargeInhibited {
                 Helper.instance.disableCharging()
                 print("MANUAL BYPASS LOOP: Ensuring charging disabled")
             }
             Helper.instance.enableSleep() // Allow sleep
             actionMsg = "MANUAL BYPASS ACTIVE"
             return // Skip all other logic including Discharge
        }
        
        // [PRIORITY 2] Check Manual Discharge
        if PersistanceManager.instance.isDischarging {
             let target = PersistanceManager.instance.dischargeTarget
             if Capacity > target {
                 // Still need to discharge
                 if !Helper.instance.chargeInhibited {
                     Helper.instance.disableCharging()
                     print("DISCHARGE MODE: Disabling charge - Capacity \(Capacity)% > Target \(target)%")
                 }
                 Helper.instance.enableSleep()
                 actionMsg = "DISCHARGING TO \(target)%"
                 return
             } else {
                 // Target reached, stop discharging
                 print("DISCHARGE MODE: Target \(target)% reached. Disabling discharge mode.")
                 PersistanceManager.instance.isDischarging = false
                 PersistanceManager.instance.save()
                 // Continue to normal charge control to maintain this level or charge up
             }
        }
        
        // Check Sailing Mode with Hysteresis ("Drift")
        if PersistanceManager.instance.sailingModeEnabled {
            let target = PersistanceManager.instance.sailingModeTarget
            let diff = PersistanceManager.instance.sailingModeDifference
            let lowerBound = max(target - diff, 0)
            
            if Capacity > target {
                 // Above target -> Disable Charge (Coast)
                 if !Helper.instance.chargeInhibited {
                     Helper.instance.disableCharging()
                     print("SAILING MODE: Coasting (Capacity \(Capacity)% > Target \(target)%)")
                 }
                 Helper.instance.enableSleep()
                 actionMsg = "SAILING: COASTING"
                 return
            } else if Capacity <= lowerBound {
                 // Below lower bound -> Enable Charge (Refill)
                 if Helper.instance.chargeInhibited {
                     // Only enable if we are truly below the hysteresis buffer
                     Helper.instance.enableCharging()
                     print("SAILING MODE: Refilling (Capacity \(Capacity)% <= Lower \(lowerBound)%)")
                 }
                 Helper.instance.disableSleep()
                 actionMsg = "SAILING: REFILLING"
                 return
            } else {
                 // Between LowerBound and Target -> Stay in current state (Hysteresis)
                 // If we were charging, keep charging to target. If we were discharging, keep discharging to lower bound.
                 // Ideally we want to "Sail" (Discharge) if we just came from top, and Charge if we came from bottom.
                 // But without keeping state, simple logic:
                 // If IsCharging, let it charge to Target.
                 // If Not Charging, let it discharge to LowerBound.
                 actionMsg = "SAILING: DRIFTING"
                 return
            }
        }
        
        // Normal charge control (if not in sailing mode)
        processChargeControl(Capacity: Capacity, IsCharging: IsCharging, actionMsg: &actionMsg)
    }
    
    private func processCalibrationLogic(Capacity: Int, IsCharging: Bool, actionMsg: inout String?) {
        let step = PersistanceManager.instance.calibrationStep
        
        switch step {
        case 0: // Start
            print("CALIBRATION: Starting... Setting step to 1")
            PersistanceManager.instance.calibrationStep = 1
            PersistanceManager.instance.save()
            
        case 1: // Charge to 100%
            actionMsg = "CALIBRATION: CHARGING TO 100%"
            if Capacity < 100 {
                if Helper.instance.chargeInhibited { Helper.instance.enableCharging() }
                Helper.instance.disableSleep()
            } else {
                // Reached 100%
                print("CALIBRATION: Reached 100%. Moving to Step 2 (Discharge)")
                PersistanceManager.instance.calibrationStep = 2
                PersistanceManager.instance.save()
            }
            
        case 2: // Discharge to 15%
             actionMsg = "CALIBRATION: DISCHARGING TO 15%"
             if Capacity > 15 {
                 if !Helper.instance.chargeInhibited { Helper.instance.disableCharging() }
                 Helper.instance.enableSleep()
             } else {
                 // Reached 15%
                 print("CALIBRATION: Reached 15%. Moving to Step 3 (Charge to 100%)")
                 PersistanceManager.instance.calibrationStep = 3
                 PersistanceManager.instance.save()
             }
             
        case 3: // Charge to 100% Again
            actionMsg = "CALIBRATION: FINAL CHARGE"
             if Capacity < 100 {
                 if Helper.instance.chargeInhibited { Helper.instance.enableCharging() }
                 Helper.instance.disableSleep()
             } else {
                 // Done
                 print("CALIBRATION: Full Cycle Complete!")
                 PersistanceManager.instance.calibrationStep = 0
                 PersistanceManager.instance.calibrationModeEnabled = false // Disable mode
                 PersistanceManager.instance.save()
                 actionMsg = "CALIBRATION COMPLETE"
             }
             
        default:
            break
        }
    }
    
    private func processChargeControl(Capacity: Int, IsCharging: Bool, actionMsg: inout String?) {
        if(!PersistanceManager.instance.oldKey){
            // CH0B/CHTE mode - charge inhibit approach
            // Use effectiveTarget which returns 100 when Boost Charge is active
            let target = SMCPresenter.shared.effectiveTarget
            let boostActive = SMCPresenter.shared.boostChargeEnabled
            
            if(Capacity < target){
                actionMsg = boostActive ? "BOOST CHARGING" : "NEED TO CHARGE"
                if(Helper.instance.chargeInhibited){
                    Helper.instance.enableCharging()
                }
                Helper.instance.disableSleep()
 
            }
            else{
                actionMsg = boostActive ? "BOOST COMPLETE" : "IS PERFECT - STOPPING CHARGE"
                if(!Helper.instance.chargeInhibited){
                    Helper.instance.disableCharging()
                    print("DISABLING CHARGE - Capacity \(Capacity) >= Target \(target)")
                }
                Helper.instance.enableSleep()
                
                // Auto-disable boost when 100% is reached
                if boostActive && Capacity >= 100 {
                    SMCPresenter.shared.stopBoostCharge()
                    print("BOOST CHARGE: Auto-completed at 100%")
                }
            }
            print("TARGET: ",target,
                  " CURRENT: ",String(Capacity),
                  " ISCHARGING: ",String(IsCharging),
                  " CHARGE INHIBITED: ",String(Helper.instance.chargeInhibited),
                  " BOOST: ", boostActive ? "ON" : "OFF",
                  " ACTION: ",actionMsg ?? "NONE")
        }
        else{
            // BCLM mode (Apple Silicon or Intel with BCLM support)
            // Write the charge limit directly to BCLM key
            let target = SMCPresenter.shared.effectiveTarget
            
            // On Apple Silicon, BCLM *can* support precise values, contrary to old beliefs.
            // We'll trust the SMC to handle the value or round it internally if needed.
            // Removing the 80/100 forcing allows targets like 50% or 60%.
            
            let bclmValue = UInt8(min(max(target, 20), 100))
            
            // Log for debugging
            if let isAppleSilicon = Helper.instance.appleSilicon, isAppleSilicon {
               print("BCLM MODE (Apple Silicon): Setting max charge to \(bclmValue)%")
            } else {
               print("BCLM MODE (Intel): Setting max charge to \(bclmValue)%")
            }
            
            Helper.instance.writeMaxBatteryCharge(setVal: bclmValue)
            print("BCLM MODE: Set max charge to \(bclmValue)% (requested \(target)%)")
        }
    }
    
    @objc func handleSleep(_ notification: Notification) {
        print("System is going to sleep...")
        if PersistanceManager.instance.stopChargingWhenSleeping {
             print("Stop Charging When Sleeping is ENABLED. Disabling charging now.")
             Helper.instance.disableCharging()
        }
    }
    
    @objc func handleWake(_ notification: Notification) {
        print("System woke up.")
        // Just trigger a check. The main loop will restore correct state within 5s.
        Helper.instance.checkCharging()
    }
    
    func windowWillClose(_ notification: Notification) {
        if !PersistanceManager.instance.showDockIcon {
             NSApp.setActivationPolicy(.accessory)
        }
    }
}
