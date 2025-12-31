//
//  Helper.swift
//  AlDente
//
//  Created by David Wernhart on 14.02.20.
//  Copyright © 2020 David Wernhart. All rights reserved.
//

import Foundation
import ServiceManagement
import IOKit.pwr_mgt
import IOKit.ps

protocol HelperDelegate {
    func OnMaxBatRead(value: UInt8)
    func updateStatus(status:String)
}

final class Helper {

    static let instance = Helper()

    public var delegate: HelperDelegate?
    
    private var key: String?
    
    private var preventSleepID: IOPMAssertionID?
    
    public var appleSilicon:Bool?
    public var chargeInhibited: Bool = false
    public var isInitialized:Bool = false
    
    public var statusString:String = ""


    lazy var helperToolConnection: NSXPCConnection = {
        let connection = NSXPCConnection(machServiceName: "com.stephenlovino.BattProHelper.mach", options: .privileged)
        connection.remoteObjectInterface = NSXPCInterface(with: HelperToolProtocol.self)

        connection.interruptionHandler = {
            print("Helper connection interrupted")
            self.isInitialized = false
        }
        
        connection.invalidationHandler = {
            print("Helper connection invalidated")
            self.isInitialized = false
        }

        connection.resume()
        print("Helper XPC connection created and resumed")
        return connection
    }()

    func setPlatformKey() {
        let s:String! = ProcessInfo.init().machineHardwareName
        if(s != nil){
            if(s.elementsEqual("x86_64")){
                print("intel cpu!")
                appleSilicon = false;
            }
            else if(s.elementsEqual("arm64")){
                print("arm cpu!")
                appleSilicon = true;
                // On Apple Silicon, use CH0B/CHWA/CH0C mode (charge inhibit) not BCLM
                // Disable BCLM mode for Apple Silicon if it was enabled
                if PersistanceManager.instance.oldKey {
                    print("   Disabling BCLM mode for Apple Silicon (using charge inhibit instead)")
                    PersistanceManager.instance.oldKey = false
                    PersistanceManager.instance.save()
                }
            }
            
        }
    }
    
    // Store which key works for this Mac
    public var workingChargeKey: String? = nil
    // Flag to indicate if this Mac uses CHTE (macOS Tahoe) or legacy keys
    public var usesTahoeKeys: Bool = false
    
    public var chargeControlReady: Bool = false
    
    // Check which SMC keys are available for charge control on this Mac
    func checkChargeControlAvailability(completion: @escaping (String?) -> Void) {
        print("Testing available charge control keys...")
        
        // Strategy:
        // 1. If Apple Silicon -> Prefer BCLM (Limit Mode) over CHTE (Inhibit Mode)
        // 2. If Intel -> Try CH0B/CH0C first, then BCLM
        
        // Wrap completion to ensure we set the ready flag
        let internalCompletion: (String?) -> Void = { key in
            self.chargeControlReady = true
            completion(key)
        }
        
        let isArm = appleSilicon ?? false
        
        if isArm {
            // Apple Silicon Strategy: Try BCLM first
            SMCWriteByte(key: "BCLM", value: 80) { success, _ in
                if success {
                    print("✓ BCLM key is available (Apple Silicon Limit Mode)")
                    // Reset to 100 to avoid stuck limit during test
                    self.SMCWriteByte(key: "BCLM", value: 100) { _,_ in }
                    
                    self.workingChargeKey = "BCLM"
                    self.usesTahoeKeys = false
                    
                    // Enable BCLM mode in persistence
                    DispatchQueue.main.async {
                        PersistanceManager.instance.oldKey = true
                        PersistanceManager.instance.save()
                    }
                    
                    internalCompletion("BCLM")
                } else {
                    // Fallback to CHTE for Apple Silicon if BCLM fails
                    self.checkTahoeKeys(completion: internalCompletion)
                }
            }
        } else {
            // Intel Strategy: Check Tahoe (some T2 Macs) -> Legacy
            self.checkTahoeKeys(completion: internalCompletion)
        }
    }
    
    private func checkTahoeKeys(completion: @escaping (String?) -> Void) {
        // Try CHTE first (macOS Tahoe/Sequoia)
        SMCReadUInt32(key: "CHTE") { value in
             print("CHTE read returned: \(value)")
             self.SMCWriteUInt32(key: "CHTE", value: 0x00000000) { success, message in
                 if success {
                     print("✓ CHTE key is available (macOS Tahoe/Sequoia mode)")
                     self.workingChargeKey = "CHTE"
                     self.usesTahoeKeys = true
                     completion("CHTE")
                 } else {
                     self.checkLegacyChargeKeys(completion: completion)
                 }
             }
        }
    }
    
    // Check legacy SMC keys (for older macOS / Intel Macs)
    private func checkLegacyChargeKeys(completion: @escaping (String?) -> Void) {
        // Try CH0B first (most common on Intel)
        SMCWriteByte(key: "CH0B", value: 00) { success, message in
            if success {
                print("✓ CH0B key is available (legacy mode)")
                self.workingChargeKey = "CH0B"
                self.usesTahoeKeys = false
                completion("CH0B")
                return
            }
            
            // Try CH0C
            self.SMCWriteByte(key: "CH0C", value: 00) { success2, _ in
                if success2 {
                    print("✓ CH0C key is available")
                    self.workingChargeKey = "CH0C"
                    self.usesTahoeKeys = false
                    completion("CH0C")
                    return
                }
                
                // Try BCLM as last resort
                self.SMCWriteByte(key: "BCLM", value: 100) { success3, _ in
                    if success3 {
                        print("✓ BCLM key is available")
                        self.workingChargeKey = "BCLM"
                        self.usesTahoeKeys = false
                        completion("BCLM")
                    } else {
                        print("✗ No charge control keys available")
                        print("   Tried: CHTE, CH0B, CH0C, BCLM")
                        completion(nil)
                    }
                }
            }
        }
    }
    
    // Write a UInt32 value to SMC (for CHTE key on Tahoe)
    @objc func SMCWriteUInt32(key: String, value: UInt32, completion: ((Bool, String) -> Void)? = nil) {
        let helper = helperToolConnection.remoteObjectProxyWithErrorHandler {
            let e = $0 as NSError
            print("Remote proxy error \(e.code): \(e.localizedDescription) \(e.localizedRecoverySuggestion ?? "---")")
            completion?(false, "XPC connection error: \(e.localizedDescription)")
        } as? HelperToolProtocol

        helper?.setSMCUInt32(key: key, value: value) { success, message in
            if success {
                print("✓ SMC UInt32 Write Success: \(message)")
                completion?(true, message)
            } else {
                print("✗ SMC UInt32 Write Failed: \(message)")
                completion?(false, message)
            }
        }
    }
    
    // Legacy check for BCLM
    func checkBCLMAvailability(completion: @escaping (Bool) -> Void) {
        SMCWriteByte(key: "BCLM", value: 100) { success, message in
            if success {
                print("✓ BCLM key is available and writable")
                completion(true)
            } else {
                print("✗ BCLM key not available: \(message)")
                completion(false)
            }
        }
    }
    
    // Check if CH0B key exists on this Mac by attempting a read
    // Note: This is a best-effort check - SMCReadByte returns 0 if key doesn't exist
    // but also returns 0 if key exists with value 0, so we can't be 100% sure
    func checkCH0BAvailability(completion: @escaping (Bool) -> Void) {
        // Try to read CH0B - if it fails completely, the key doesn't exist
        // But since SMCReadByte returns 0 on error, we can't distinguish
        // For now, we'll just log that we're checking
        SMCReadByte(key: "CH0B") { value in
            // If we get here, the read completed (even if value is 0)
            // We'll assume the key exists if we can read it
            // The real test will be when we try to write
            completion(true)
        }
    }
    func setStatusString(){
        // Don't check charging status immediately - trust our internal state
        // checkCharging() can be called separately when needed
        var sleepDisabled:Bool = !(preventSleepID == nil)
        statusString = ""
        if(PersistanceManager.instance.oldKey){
            statusString = "BCLM Key Mode. Final charge value can differ by up to 5%"
        }
        else{
            statusString = "Charge Inhibit: "+String(chargeInhibited)+" | Prevent Sleep: "+String(sleepDisabled)+" | Helper v"+String(helperVersion)+": \(self.isInitialized ? "found" : "not found")"
        }
        
        
        self.delegate?.updateStatus(status: statusString)
    }

    
    func enableSleep(){
        if(self.preventSleepID != nil){
            print("RELEASING PREVENT SLEEP ASSERTION WITH ID: ",preventSleepID!)
            releaseAssertion(assertionId: self.preventSleepID!)
            self.preventSleepID = nil
        }
    }
    
    func disableSleep(){
        createAssertion(assertion: kIOPMAssertionTypePreventSystemSleep){ id in
            if(self.preventSleepID == nil){
                print("PREVENT SLEEP ASSERTION CREATED! ID: ",id)
                self.preventSleepID = id
            }
        }
    }
    
    func enableCharging(){
        // Use the working key if we found one
        if let key = workingChargeKey {
            print("ATTEMPTING TO ENABLE CHARGING via \(key)...")
            
            if key == "CHTE" {
                // macOS Tahoe mode - use UInt32 value 0x00000000 to enable charging
                SMCWriteUInt32(key: key, value: 0x00000000) { success, message in
                    self.chargeInhibited = false
                    if success {
                        print("✓ CHARGING ENABLED via CHTE (Tahoe mode)")
                    } else {
                        print("⚠ Failed to enable charging via CHTE: \(message)")
                    }
                }
            } else {
                // Legacy mode - use byte value
                SMCWriteByte(key: key, value: 00) { success, message in
                    self.chargeInhibited = false
                    if success {
                        print("✓ CHARGING ENABLED via \(key)")
                    } else {
                        print("⚠ Failed to enable charging via \(key): \(message)")
                    }
                }
            }
            return
        }
        
        // No known working key, try CHTE first (for Tahoe), then legacy keys
        print("ATTEMPTING TO ENABLE CHARGING (no cached key, trying all)...")
        
        // Try CHTE first (macOS Tahoe)
        SMCWriteUInt32(key: "CHTE", value: 0x00000000) { success, message in
            if success {
                self.chargeInhibited = false
                self.workingChargeKey = "CHTE"
                self.usesTahoeKeys = true
                print("✓ CHARGING ENABLED via CHTE (Tahoe mode)")
                return
            }
            
            // Try CH0B (Intel/legacy)
            self.SMCWriteByte(key: "CH0B", value: 00) { success2, _ in
                self.chargeInhibited = false
                if success2 {
                    self.workingChargeKey = "CH0B"
                    print("✓ CHARGING ENABLED via CH0B")
                } else {
                    // Try CH0C
                    self.SMCWriteByte(key: "CH0C", value: 00) { success3, _ in
                        self.chargeInhibited = false
                        if success3 {
                            self.workingChargeKey = "CH0C"
                            print("✓ CHARGING ENABLED via CH0C")
                        } else {
                            print("⚠ No charge control key found")
                        }
                    }
                }
            }
        }
    }
    
    func disableCharging(){
        // Use the working key if we found one
        if let key = workingChargeKey {
            print("ATTEMPTING TO DISABLE CHARGING via \(key)...")
            
            if key == "CHTE" {
                // macOS Tahoe mode - use UInt32 value 0x01000000 to disable charging
                SMCWriteUInt32(key: key, value: 0x01000000) { success, message in
                    if success {
                        self.chargeInhibited = true
                        print("✓ CHARGING DISABLED via CHTE (Tahoe mode)")
                    } else {
                        print("✗ Failed to disable charging via CHTE: \(message)")
                        self.chargeInhibited = false
                    }
                }
            } else {
                // Legacy mode - use byte value (02 for CH0B/CH0C, 01 for others)
                let value: UInt8 = (key == "CH0B" || key == "CH0C") ? 02 : 01
                SMCWriteByte(key: key, value: value) { success, message in
                    if success {
                        self.chargeInhibited = true
                        print("✓ CHARGING DISABLED via \(key)")
                    } else {
                        print("✗ Failed to disable charging via \(key): \(message)")
                        self.chargeInhibited = false
                    }
                }
            }
            return
        }
        
        // No known working key, try CHTE first (for Tahoe), then legacy keys
        print("ATTEMPTING TO DISABLE CHARGING (no cached key, trying all)...")
        
        // Try CHTE first (macOS Tahoe) - use UInt32 value 0x01000000
        SMCWriteUInt32(key: "CHTE", value: 0x01000000) { success, message in
            if success {
                self.chargeInhibited = true
                self.workingChargeKey = "CHTE"
                self.usesTahoeKeys = true
                print("✓ CHARGING DISABLED via CHTE (Tahoe mode)")
                return
            }
            
            // Try CH0B (Intel/legacy)
            self.SMCWriteByte(key: "CH0B", value: 02) { success2, _ in
                if success2 {
                    self.chargeInhibited = true
                    self.workingChargeKey = "CH0B"
                    print("✓ CHARGING DISABLED via CH0B")
                } else {
                    // Try CH0C
                    self.SMCWriteByte(key: "CH0C", value: 02) { success3, _ in
                        if success3 {
                            self.chargeInhibited = true
                            self.workingChargeKey = "CH0C"
                            print("✓ CHARGING DISABLED via CH0C")
                        } else {
                            print("✗ No charge control key found")
                            print("   Charge limiting may not work on this Mac model")
                            self.chargeInhibited = false
                        }
                    }
                }
            }
        }
    }
    
    func checkCharging(){
        // Use the working key if found, otherwise default to CH0B for legacy behavior
        if let key = workingChargeKey {
            if key == "CHTE" {
                // macOS Tahoe mode - read UInt32
                Helper.instance.SMCReadUInt32(key: key) { value in
                    // In CHTE mode: 0 = Charging Enabled, 1 = Charging Disabled (Inhibited)
                    // We check if value != 0 (so 1 means inhibited)
                    self.chargeInhibited = (value != 0)
                    print("CHARGE INHIBITED (CHTE): " + String(self.chargeInhibited))
                }
            } else {
                // Legacy mode (CH0B, CH0C, BCLM) - read Byte
                Helper.instance.SMCReadByte(key: key) { value in
                    // In Legacy mode: 00 = Charging Enabled, 02 (or non-zero) = Disabled
                     self.chargeInhibited = (value != 00)
                     print("CHARGE INHIBITED (\(key)): " + String(self.chargeInhibited))
                }
            }
        } else {
            // Fallback for when workingChargeKey is not yet set
            Helper.instance.SMCReadByte(key: "CH0B") { value in
                self.chargeInhibited = !(value == 00)
                print("CHARGE INHIBITED (Fallback CH0B): "+String(self.chargeInhibited))
            }
        }
        
        if(PersistanceManager.instance.oldKey){
            Helper.instance.readMaxBatteryCharge()
        }

    }
    
    func getChargingInfo(withReply reply: (String,Int,Bool,Int) -> Void){
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as Array
        if sources.count > 0 {
            let info = IOPSGetPowerSourceDescription(snapshot, sources[0]).takeUnretainedValue() as! [String: AnyObject]

            if let name = info[kIOPSNameKey] as? String,
                let capacity = info[kIOPSCurrentCapacityKey] as? Int,
                let isCharging = info[kIOPSIsChargingKey] as? Bool,
                let max = info[kIOPSMaxCapacityKey] as? Int {
                reply(name,capacity,isCharging,max)
                return
            }
        }
        reply("Unknown", 0, false, 0)
    }

    func getDetailedBatteryInfo(withReply reply: @escaping ([String: Any]) -> Void) {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as Array
        var result: [String: Any] = [:]
        
        if sources.count > 0 {
            let info = IOPSGetPowerSourceDescription(snapshot, sources[0]).takeUnretainedValue() as! [String: AnyObject]
            
            // Standard Keys
            result["Name"] = info[kIOPSNameKey] ?? "Unknown"
            result["CurrentCapacity"] = info[kIOPSCurrentCapacityKey] ?? 0
            result["MaxCapacity"] = info[kIOPSMaxCapacityKey] ?? 0
            result["PowerSourceState"] = info[kIOPSPowerSourceStateKey] ?? "Unknown" // "AC Power" or "Battery Power"
            result["DesignCapacity"] = info["DesignCapacity"] ?? 0
            result["ByDesignCapacity"] = info["DesignCapacity"] ?? 0 // Alt key
            result["CycleCount"] = info["Cycle Count"] ?? 0
            result["Voltage"] = info["Voltage"] ?? 0
            result["Amperage"] = info["Amperage"] ?? 0
            result["IsCharging"] = info[kIOPSIsChargingKey] ?? false
            result["TimeRemaining"] = info[kIOPSTimeToEmptyKey] ?? -1
            result["Serial"] = info["Serial"] ?? "Unknown"
            result["Manufacturer"] = info["Manufacturer"] ?? "Apple"
            result["ManufactureDate"] = info["ManufactureDate"] ?? Date() // Format might vary
            result["Temperature"] = info["Temperature"] ?? 0
            
            // Power Adapter
            result["AdapterDetails"] = info["AdapterDetails"]
            result["Wattage"] = info["Wattage"] // Sometimes available directly
        }
        
        // Async Temperature fetch (override if successful)
        getBatteryTemperature { temp in
            result["Temperature"] = temp
            reply(result)
        }
    }
    
    // MARK: - New Feature Methods
    
    func getBatteryTemperature(withReply reply: @escaping (Double) -> Void) {
        // Read battery temperature from SMC (key: TB0T uses SP78 format)
        // SP78 is a signed 16-bit fixed-point format used for temperatures
        let helper = helperToolConnection.remoteObjectProxyWithErrorHandler {
            let e = $0 as NSError
            print("Remote proxy error \(e.code): \(e.localizedDescription)")
            reply(25.0) // Return default on error
        } as? HelperToolProtocol
        
        helper?.readSMCSP78(key: "TB0T") { temp in
            if temp > -10 && temp < 100 {
                // Valid temperature range
                reply(temp)
            } else {
                // Invalid temperature, return default
                print("WARNING: Invalid temperature reading: \(temp)°C, using default 25°C")
                reply(25.0)
            }
        }
    }
    
    func getCPUTemperature(withReply reply: @escaping (Double) -> Void) {
        let helper = helperToolConnection.remoteObjectProxyWithErrorHandler {
            let e = $0 as NSError
            print("Remote proxy error \(e.code): \(e.localizedDescription)")
            reply(0.0)
        } as? HelperToolProtocol
        
        helper?.readCPUTemperature { temp in
            reply(temp)
        }
    }
    
    func toggleLowPowerMode(enabled: Bool, completion: @escaping (Bool) -> Void) {
        let helper = helperToolConnection.remoteObjectProxyWithErrorHandler {
            let e = $0 as NSError
            print("Remote proxy error \(e.code): \(e.localizedDescription)")
            completion(false)
        } as? HelperToolProtocol
        
        helper?.setLowPowerMode(enabled: enabled) { success, message in
            DispatchQueue.main.async {
                print("Low Power Mode toggle result: \(success) - \(message)")
                completion(success)
            }
        }
    }
    
    func checkLowPowerMode(completion: @escaping (Bool) -> Void) {
        // We can check this directly via ProcessInfo
        if #available(macOS 12.0, *) {
            let isEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
            completion(isEnabled)
        } else {
            // Low Power Mode API not available on macOS < 12
            completion(false)
        }
    }
    
    func startCalibration() {
        print("Starting battery calibration...")
        PersistanceManager.instance.calibrationModeEnabled = true
        PersistanceManager.instance.calibrationStep = 0
        PersistanceManager.instance.save()
    }
    
    func stopCalibration() {
        print("Stopping battery calibration...")
        PersistanceManager.instance.calibrationModeEnabled = false
        PersistanceManager.instance.calibrationStep = 0
        PersistanceManager.instance.save()
        // Reset charging state
        enableCharging()
    }
    
    func startDischarge(to target: Int) {
        print("Starting discharge to \(target)%...")
        PersistanceManager.instance.isDischarging = true
        PersistanceManager.instance.dischargeTarget = target
        PersistanceManager.instance.save()
    }
    
    func stopDischarge() {
        print("Stopping discharge...")
        PersistanceManager.instance.isDischarging = false
        PersistanceManager.instance.save()
        enableCharging()
    }
    
    func getSMCCharge(withReply reply: @escaping (Float)->Void){
        Helper.instance.SMCReadUInt32(key: "BRSC") { value in
            let smcval = Float(value >> 16)
            reply(smcval)
        }
    }
    
    @objc func createAssertion(assertion: String, withReply reply: @escaping (IOPMAssertionID) -> Void){
        let helper = helperToolConnection.remoteObjectProxyWithErrorHandler {
            let e = $0 as NSError
            print("Remote proxy error \(e.code): \(e.localizedDescription) \(e.localizedRecoverySuggestion ?? "---")")
        } as? HelperToolProtocol

        helper?.createAssertion(assertion: assertion, withReply: { id in
            reply(id)
        })
    }
    
    @objc func releaseAssertion(assertionId: IOPMAssertionID){
        let helper = helperToolConnection.remoteObjectProxyWithErrorHandler {
            let e = $0 as NSError
            print("Remote proxy error \(e.code): \(e.localizedDescription) \(e.localizedRecoverySuggestion ?? "---")")
        } as? HelperToolProtocol

        helper?.releaseAssertion(assertionID: assertionId)
    }
    
    // MARK: - Sleep Management
    
    // We reuse preventSleepID (defined in class) to ensure unified state
    
    func checkSleepAssertion(currentCharge: Int = 0) {
        // Condition: Enabled in Settings AND (Calibration Active OR (DisableUntilLimit AND Current < Target))
        // Note: We use the passed currentCharge, or 0 if not provided (though for this logic relevant mostly when > 0)
        let shouldDisableSleep = PersistanceManager.instance.calibrationModeEnabled ||
                                 (PersistanceManager.instance.disableSleepUntilChargeLimit &&
                                  Float(currentCharge) < Float(PersistanceManager.instance.chargeVal ?? 80))
        
        if shouldDisableSleep {
            if preventSleepID == nil {
                print("Acquiring Sleep Assertion...")
                createAssertion(assertion: "PreventUserIdleSystemSleep") { [weak self] id in
                    self?.preventSleepID = id
                    print("Sleep Assertion Acquired: \(id)")
                }
            }
        } else {
            if let id = preventSleepID {
                print("Releasing Sleep Assertion: \(id)")
                releaseAssertion(assertionId: id)
                preventSleepID = nil
            }
        }
    }
    
    // enableSleep() was duplicated. Logic merged into existing methods or replaced if needed.
    // The existing enableSleep at line 247 covers basic functionality.
    
    // We keep checkSleepAssertion as it's new.

    
    // disableCharging() was duplicated here. Removed to use the robust implementation at line 328.

    func enforceLowPowerMode() {
        let policy = PersistanceManager.instance.lowPowerModePolicy
        // 0: Always Off, 1: Always On, 2: Auto
        
        checkLowPowerMode { [weak self] isEnabled in
            guard let self = self else { return }
            
            var shouldBeEnabled = false
            switch policy {
            case 0: shouldBeEnabled = false
            case 1: shouldBeEnabled = true
            case 2:
                // Auto: Enabled if on Battery
                // Check power source
                 let powerSource = IOPSGetProvidingPowerSourceType(nil)?.takeRetainedValue() as String?
                 if powerSource == kIOPMBatteryPowerKey {
                     shouldBeEnabled = true
                 } else {
                     shouldBeEnabled = false
                 }
            default: break
            }
            
            if isEnabled != shouldBeEnabled {
                print("Enforcing Low Power Mode: \(shouldBeEnabled) (Policy: \(policy))")
                self.toggleLowPowerMode(enabled: shouldBeEnabled) { success in
                    // Log result
                }
            }
        }
    }

    func getTopEnergyConsumers(completion: @escaping ([String]) -> Void) {
        // Run top command to get power usage
        // top -l 1 -o power -n 10 -stats command,power
        let task = Process()
        task.launchPath = "/usr/bin/top"
        // -l 1: single sample
        // -o power: sort by power
        // -n 10: top 10
        // -stats command,power: only output these columns to make parsing easier
        task.arguments = ["-l", "1", "-n", "10", "-stats", "command,power", "-o", "power"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run() // Deprecated but simple. Or use run() available on macOS 10.13+
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                var apps: [String] = []
                let lines = output.components(separatedBy: "\n")
                // Header usually: COMMAND POWER
                var startParsing = false
                
                for line in lines {
                    if line.contains("COMMAND") && line.contains("POWER") {
                        startParsing = true
                        continue
                    }
                    if startParsing {
                        let parts = line.split(separator: " ", omittingEmptySubsequences: true)
                        // Should be: [COMMAND, POWER]
                        // Note: COMMAND might truncate or contain spaces if not careful, but top -stats usually safe-ish
                        // Actually, COMMAND with spaces will be split.
                        // But POWER is always the last column.
                        if let powerStr = parts.last, let power = Double(powerStr) {
                             let command = parts.dropLast().joined(separator: " ")
                             
                             let thresholdVal = PersistanceManager.instance.energyThreshold == 0 ? 5.0 : (PersistanceManager.instance.energyThreshold == 1 ? 20.0 : 50.0)
                             
                             if power > thresholdVal {
                                 apps.append("\(command) (\(Int(power)))")
                             }
                        }
                    }
                }
                completion(apps)
            } else {
                completion([])
            }
        } catch {
            print("Failed to run top: \(error)")
            completion([])
        }
    }

    @objc func installHelper() {
        print("trying to install helper!")
        var status = noErr
        let helperID = "com.stephenlovino.BattProHelper" as CFString // Prefs.helperID as CFString

        var authItem = kSMRightBlessPrivilegedHelper.withCString {
            AuthorizationItem(name: $0, valueLength: 0, value: nil, flags: 0)
        }
        var authRights = withUnsafeMutablePointer(to: &authItem) {
            AuthorizationRights(count: 1, items: $0)
        }
        let authFlags: AuthorizationFlags = [.interactionAllowed, .preAuthorize, .extendRights]
        var authRef: AuthorizationRef?
        status = AuthorizationCreate(&authRights, nil, authFlags, &authRef)
        if status != errAuthorizationSuccess {
            print(SecCopyErrorMessageString(status, nil) ?? "")
            print("Error: \(status)")
        }

        var error: Unmanaged<CFError>?
        SMJobBless(kSMDomainSystemLaunchd, helperID, authRef, &error)
        if let e = error?.takeRetainedValue() {
            print("Domain: ", CFErrorGetDomain(e) ?? "")
            print("Code: ", CFErrorGetCode(e))
            print("UserInfo: ", CFErrorCopyUserInfo(e) ?? "")
            print("Description: ", CFErrorCopyDescription(e) ?? "")
            print("Reason: ", CFErrorCopyFailureReason(e) ?? "")
            print("Suggestion: ", CFErrorCopyRecoverySuggestion(e) ?? "")
        }
        
        if(error == nil){
            print("helper installed successfully!")
            restart()
        }
    }
    
    func restart(){
        let url = URL(fileURLWithPath: Bundle.main.resourcePath!)
        let path = url.deletingLastPathComponent().deletingLastPathComponent().path
        print("Restarting app at: \(path)")
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = ["-n", path]
        task.launch()
        exit(0)
    }
    
    @objc func setResetValues(){
        let helper = helperToolConnection.remoteObjectProxyWithErrorHandler {
            let e = $0 as NSError
            print("Remote proxy error \(e.code): \(e.localizedDescription) \(e.localizedRecoverySuggestion ?? "---")")

        } as? HelperToolProtocol
        
        helper?.setResetVal(key: "CH0B", value: 00)
    }

    @objc func writeMaxBatteryCharge(setVal: UInt8) {
        // Try to write BCLM - if it fails, SMCWriteByte will detect and switch modes
        SMCWriteByte(key: "BCLM", value: setVal) { success, message in
            if success {
                print("✓ BCLM write succeeded: max charge set to \(setVal)%")
            } else {
                print("✗ BCLM write failed: \(message)")
            }
        }
    }

    @objc func readMaxBatteryCharge() {
        SMCReadByte(key: "BCLM") { value in
            print("OLD KEY MAX CHARGE: "+String(value))
            self.delegate?.OnMaxBatRead(value: value)
        }
    }
    
    @objc func enableCharging(enabled: Bool) {
        if(enabled){
            SMCWriteByte(key: "CH0B", value: 00) { success, message in
                if success {
                    self.chargeInhibited = false
                }
            }
        }
        else{
            SMCWriteByte(key: "CH0B", value: 02) { success, message in
                if success {
                    self.chargeInhibited = true
                }
            }
        }

    }

    @objc func checkHelperVersion(withReply reply: @escaping (Bool) -> Void) {
        print("checking helper version")
        let helper = helperToolConnection.remoteObjectProxyWithErrorHandler {
            let e = $0 as NSError
            print("Remote proxy error \(e.code): \(e.localizedDescription) \(e.localizedRecoverySuggestion ?? "---")")
            reply(false)
            return()

        } as? HelperToolProtocol

        helper?.getVersion { version in
            print("helperVersion:", helperVersion, " version from helper:", version)
            if !helperVersion.elementsEqual(version) {
                reply(false)
                return()
            }
            else{
                self.isInitialized = true
                reply(true)
                return()
            }
        }
    }

    @objc func SMCReadByte(key: String, withReply reply: @escaping (UInt8) -> Void) {
        let helper = helperToolConnection.remoteObjectProxyWithErrorHandler {
            let e = $0 as NSError
            print("Remote proxy error \(e.code): \(e.localizedDescription) \(e.localizedRecoverySuggestion ?? "---")")

        } as? HelperToolProtocol

        helper?.readSMCByte(key: key) {
            reply($0)
        }
    }
    
    @objc func SMCReadUInt32(key: String, withReply reply: @escaping (UInt32) -> Void) {
        let helper = helperToolConnection.remoteObjectProxyWithErrorHandler {
            let e = $0 as NSError
            print("Remote proxy error \(e.code): \(e.localizedDescription) \(e.localizedRecoverySuggestion ?? "---")")

        } as? HelperToolProtocol

        helper?.readSMCUInt32(key: key) {
            reply($0)
        }
    }

    @objc func SMCWriteByte(key: String, value: UInt8, completion: ((Bool, String) -> Void)? = nil) {
        let helper = helperToolConnection.remoteObjectProxyWithErrorHandler {
            let e = $0 as NSError
            print("Remote proxy error \(e.code): \(e.localizedDescription) \(e.localizedRecoverySuggestion ?? "---")")
            completion?(false, "XPC connection error: \(e.localizedDescription)")

        } as? HelperToolProtocol

        helper?.setSMCByte(key: key, value: value) { success, message in
            if success {
                if key != "BCLM" || value != 0 { // Don't spam logs for failed BCLM writes
                    print("✓ SMC Write Success: \(message)")
                }
                completion?(true, message)
            } else {
                // If BCLM write fails, it means BCLM doesn't exist - switch to CH0B mode
                if key == "BCLM" {
                    print("⚠ BCLM key not found - this Mac doesn't support BCLM mode")
                    print("   Switching to CH0B mode (charge inhibit)")
                    // Auto-disable BCLM mode
                    DispatchQueue.main.async {
                        if PersistanceManager.instance.oldKey {
                            PersistanceManager.instance.oldKey = false
                            PersistanceManager.instance.save()
                            print("   BCLM mode disabled, using CH0B mode instead")
                        }
                    }
                } else {
                    print("✗ SMC Write Failed: \(message)")
                }
                completion?(false, message)
            }
        }
    }
    
    // MARK: - SMC Battery Stats (Using SP78 Hack for 2-byte reads)
    
    // Reads any 2-byte key by abusing the SP78 read function
    // SP78 returns: sign * (exp + frac/256)
    // We reverse this to get original bytes
    func SMCReadWord(key: String, withReply reply: @escaping (UInt16) -> Void) {
        let helper = helperToolConnection.remoteObjectProxyWithErrorHandler { _ in
            reply(0)
        } as? HelperToolProtocol
        
        helper?.readSMCSP78(key: key) { val in
            // Reconstruct bytes from Double
            // Note: This is an approximation/hack. Ideally we'd modify HelperTool to expose raw reads.
            // But if val = sign * (exp + frac/256)
            // Absolute value = exp + frac/256
            
            let sign = val < 0 ? UInt8(0x80) : UInt8(0)
            let absVal = abs(val)
            let exp = UInt8(Int(absVal))
            let frac = UInt8(round((absVal - Double(exp)) * 256.0))
            
            // Reconstruct the 2 bytes consistent with SP78 definition in SMC.swift
            // SP78: (Bit 7: Sign, Bits 0-6: Int Part), (Bits 0-7: Frac Part)
            // So byte0 = sign | (exp & 0x7F)
            let byte0 = sign | (exp & 0x7F)
            let byte1 = frac
            
            let word = (UInt16(byte0) << 8) | UInt16(byte1)
            reply(word)
        }
    }
    
    // Reads signed 16-bit integer (e.g. Amperage)
    func SMCReadInt16(key: String, withReply reply: @escaping (Int16) -> Void) {
        SMCReadWord(key: key) { word in
            reply(Int16(bitPattern: word))
        }
    }
    
    // Reads 2-byte key and swaps bytes (Little Endian)
    func SMCReadWordSwapped(key: String, withReply reply: @escaping (UInt16) -> Void) {
        SMCReadWord(key: key) { word in
            // Swap: (AB) -> (BA)
            let swapped = (word >> 8) | (word << 8)
            reply(swapped)
        }
    }
    
    func getSMCBatteryInfo(withReply reply: @escaping ([String: Any]) -> Void) {
        let helper = helperToolConnection.remoteObjectProxyWithErrorHandler { _ in 
             DispatchQueue.main.async { reply([:]) }
        } as? HelperToolProtocol
        
        helper?.readBatteryStatus { status in
            DispatchQueue.main.async {
                var result = status
                
                // Static Strings (Fallback)
                if result["Manufacturer"] == nil { result["Manufacturer"] = "Apple" }
                if result["Serial"] == nil { result["Serial"] = "Protected" }
                if result["ManufactureDate"] == nil { result["ManufactureDate"] = Date() }
                
                // Derived Fields
                var amps = result["Amperage"] as? Double ?? 0
                var volts = result["Voltage"] as? Double ?? 0
                
                // Fix Amperage Sign for Apple Silicon
                // Experimentally determined: On M1/M2, Negative Amps = Charging
                if let isAppleSilicon = self.appleSilicon, isAppleSilicon {
                    amps = -amps
                    result["Amperage"] = amps
                }
                
                result["IsCharging"] = amps > 0
                result["PowerConsumption"] = amps * volts // W
                
                // Adapter Defaults
                if amps > 0 {
                    result["AdapterConnected"] = true
                    result["AdapterWattage"] = 60 
                    result["AdapterName"] = "Power Adapter"
                } else {
                    result["AdapterConnected"] = false
                    result["AdapterWattage"] = 0
                    result["AdapterName"] = "Not Connected"
                }
                
                reply(result)
            }
        }
    }
}

// MARK: - Thermal Pressure Reader (Embedded)

/// Defines the thermal pressure levels
enum ThermalPressure: String {
    case nominal = "Nominal"
    case moderate = "Moderate"
    case heavy = "Heavy"
    case critical = "Critical"
    case unknown = "Unknown"
    
    var isThrottling: Bool {
        return self == .heavy || self == .critical
    }
}

/// Reads thermal pressure level directly from the system using Darwin notifications.
/// This provides the same 5-level granularity as `powermetrics -s thermal` without
/// requiring root privileges or a helper daemon.
final class ThermalPressureReader {
    static let shared = ThermalPressureReader()

    private var token: Int32 = 0
    private var isRegistered = false

    private init() {
        register()
    }

    deinit {
        if isRegistered {
            _ = notify_cancel(token)
        }
    }

    private func register() {
        // "com.apple.system.thermalpressurelevel" is a private notification used by macOS
        let result = notify_register_check("com.apple.system.thermalpressurelevel", &token)
        isRegistered = (result == notifyStatusOK)
        if !isRegistered {
            print("Failed to register for thermal pressure notifications")
        }
    }

    /// Reads the current thermal pressure level.
    /// Returns nil if the notification system is unavailable.
    func readPressure() -> ThermalPressure {
        guard isRegistered else { return .unknown }

        var state: UInt64 = 0
        let result = notify_get_state(token, &state)

        guard result == notifyStatusOK else { return .unknown }

        switch state {
        case 0: return .nominal
        case 1: return .moderate
        case 2: return .heavy
        case 3, 4: return .critical
        default: return .unknown
        }
    }
}

// MARK: - Darwin notify functions headers

// Since we can't import private headers, we define the signatures here to link against libSystem
@_silgen_name("notify_register_check")
private func notify_register_check(
    _ name: UnsafePointer<CChar>,
    _ token: UnsafeMutablePointer<Int32>
) -> UInt32

@_silgen_name("notify_get_state")
private func notify_get_state(
    _ token: Int32,
    _ state: UnsafeMutablePointer<UInt64>
) -> UInt32

@_silgen_name("notify_cancel")
private func notify_cancel(_ token: Int32) -> UInt32

private let notifyStatusOK: UInt32 = 0
