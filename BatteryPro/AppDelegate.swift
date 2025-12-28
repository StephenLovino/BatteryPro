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
        Helper.instance.enableSleep()
        Helper.instance.enableCharging()
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        print("=== BatteryPro Starting ===")
        
        print("Creating ContentView...")
        let contentView = ContentView()
        print("ContentView created")
        
        print("Creating popover...")
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 560, height: 140)
        popover.behavior = .transient
        popover.animates = true
        let hostingController = NSHostingController(rootView: contentView)
        hostingController.view.frame = NSRect(x: 0, y: 0, width: 560, height: 140)
        popover.contentViewController = hostingController
        self.popover = popover
        print("Popover created")

        print("Creating status bar item...")
        let statusBar = NSStatusBar.system
        statusBarItem = statusBar.statusItem(withLength: NSStatusItem.squareLength)
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
        PersistanceManager.instance.load()
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
                // Reload persistence to ensure we have latest values
                PersistanceManager.instance.load()
                
                Helper.instance.getChargingInfo { (Name, Capacity, IsCharging, MaxCapacity) in
                    
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

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
    
    // MARK: - NSWindowDelegate
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    // MARK: - Charge Control Logic
    private func processChargeControlWithModes(Capacity: Int, IsCharging: Bool, actionMsg: inout String?) {
        // Check Sailing Mode
        if PersistanceManager.instance.sailingModeEnabled {
            let target = PersistanceManager.instance.sailingModeTarget
            if Capacity > target {
                // Battery is above target, discharge it
                if !Helper.instance.chargeInhibited {
                    Helper.instance.disableCharging()
                    print("SAILING MODE: Disabled charging - Capacity \(Capacity)% > Target \(target)%")
                }
                Helper.instance.enableSleep() // Allow sleep during discharge
                return // Don't process normal charge control in sailing mode
            } else if Capacity <= target {
                // Battery is at or below target, keep it there
                if Helper.instance.chargeInhibited {
                    Helper.instance.enableCharging()
                    print("SAILING MODE: Enabled charging - Capacity \(Capacity)% <= Target \(target)%")
                }
                Helper.instance.disableSleep() // Prevent sleep to maintain level
                return // Don't process normal charge control in sailing mode
            }
        }
        
        // Normal charge control (if not in sailing mode)
        processChargeControl(Capacity: Capacity, IsCharging: IsCharging, actionMsg: &actionMsg)
    }
    
    private func processChargeControl(Capacity: Int, IsCharging: Bool, actionMsg: inout String?) {
        if(!PersistanceManager.instance.oldKey){
            // CH0B mode (Intel Macs) - charge inhibit approach
            let target = Int(SMCPresenter.shared.value)
            if(Capacity < target){
                actionMsg = "NEED TO CHARGE"
                if(Helper.instance.chargeInhibited){
                    Helper.instance.enableCharging()
                }
                Helper.instance.disableSleep()
 
            }
            else{
                actionMsg = "IS PERFECT - STOPPING CHARGE"
                if(!Helper.instance.chargeInhibited){
                    Helper.instance.disableCharging()
                    print("DISABLING CHARGE - Capacity \(Capacity) >= Target \(target)")
                }
                Helper.instance.enableSleep()
                
            }
            print("TARGET: ",target,
                  " CURRENT: ",String(Capacity),
                  " ISCHARGING: ",String(IsCharging),
                  " CHARGE INHIBITED: ",String(Helper.instance.chargeInhibited),
                  " ACTION: ",actionMsg ?? "NONE")
        }
        else{
            // BCLM mode (Apple Silicon or Intel with BCLM support)
            // Write the charge limit directly to BCLM key
            let target = Int(SMCPresenter.shared.value)
            
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
}
