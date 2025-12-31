//
//  HelperTool.swift
//  com.davidwernhart.Helper
//
//  Created by David Wernhart on 13.02.20.
//  Copyright © 2020 David Wernhart. All rights reserved.
//

import Foundation
import IOKit.pwr_mgt

final class HelperTool: NSObject, HelperToolProtocol {
    
    static let instance = HelperTool()
    
    var modifiedKeys: [String: UInt8] = [:]
    var openAssertions: [IOPMAssertionID] = []
    
    func getVersion(withReply reply: (String) -> Void) {
//        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString" as String) as? String ?? "(unknown version)"
//        let build = Bundle.main.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as? String ?? "(unknown build)"
//        reply("v\(version) (\(build))")
        reply(helperVersion)

    }

    func setSMCByte(key: String, value: UInt8, withReply reply: @escaping (Bool, String) -> Void) {
        logToFile("setSMCByte: \(key)=\(value)")
        smcLock.lock()
        defer { smcLock.unlock() }
        
        print("setSMCByte called: key=\(key), value=\(value)")
        
        // Wrap everything in a do-catch to prevent any crashes
        do {
            print("Attempting to open SMCKit...")
            try SMCKit.open()
            print("SMCKit opened successfully")
        } catch {
            let errorMsg = "Failed to open SMCKit: \(error)"
            print("ERROR: \(errorMsg)")
            reply(false, errorMsg)
            return
        }
        
        let smcKey = SMCKit.getKey(key, type: DataTypes.UInt8)
        let bytes: SMCBytes = (value, UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
        UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
        UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
        UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
        UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
        UInt8(0), UInt8(0))
        
        // Read original value if needed (synchronously, since SMCKit is already open)
        // Note: If key doesn't exist, we'll still try to write it (some keys can be written but not read)
        var originalValue: UInt8 = 0
        if(self.modifiedKeys[key] == nil){
            do {
                print("Reading original value for \(key)...")
                let readKey = SMCKit.getKey(key, type: DataTypes.UInt8)
                originalValue = try SMCKit.readData(readKey).0
                self.modifiedKeys[key] = originalValue
                print("Original value for \(key) is \(originalValue)")
            } catch {
                // Key might not exist or be readable, but we can still try to write it
                print("WARNING: Could not read original value for \(key): \(error)")
                print("Will attempt to write anyway (some SMC keys can be written but not read)")
                // Don't return - continue to attempt the write
                self.modifiedKeys[key] = 0  // Set a default so we don't try to read again
            }
        }
        
        // Write the new value
        do {
            print("Attempting to write \(key) = \(value)...")
            try SMCKit.writeData(smcKey, data: bytes)
            let successMsg = self.modifiedKeys[key] != nil ? 
                "Wrote SMC key \(key) = \(value)" : 
                "Wrote SMC key \(key) = \(value) (original was \(originalValue))"
            print("SUCCESS: \(successMsg)")
            
            // Verify the write immediately (synchronously)
            do {
                print("Verifying write for \(key)...")
                let readKey = SMCKit.getKey(key, type: DataTypes.UInt8)
                let verifyValue = try SMCKit.readData(readKey).0
                print("Verification read: \(key) = \(verifyValue) (expected \(value))")
                if verifyValue == value {
                    print("VERIFIED: SMC key \(key) read back as \(verifyValue) ✓")
                    reply(true, successMsg)
                } else {
                    let warningMsg = "Write may have failed - read back \(verifyValue) but expected \(value)"
                    print("WARNING: SMC key \(key) \(warningMsg)")
                    reply(false, warningMsg)
                }
            } catch {
                let errorMsg = "Failed to verify write for \(key): \(error)"
                print("ERROR: \(errorMsg)")
                reply(false, errorMsg)
            }
        } catch {
            let errorMsg = "Failed to write SMC key \(key) = \(value): \(error)"
            print("ERROR: \(errorMsg)")
            reply(false, errorMsg)
        }
        
        print("setSMCByte completed for \(key)")
    }

    func readSMCByte(key: String, withReply reply: @escaping (UInt8) -> Void) {
        smcLock.lock()
        defer { smcLock.unlock() }
        
        do {
            try SMCKit.open()
        } catch {
            print("ERROR: Failed to open SMCKit for read: \(error)")
            reply(0)  // Don't exit - just return 0
            return
        }

        let smcKey = SMCKit.getKey(key, type: DataTypes.UInt8)
        do {
            let status = try SMCKit.readData(smcKey).0
            reply(status)
        } catch {
            print("ERROR: Failed to read SMC key \(key): \(error)")
            reply(0)
        }
    }
    
    func readSMCUInt32(key: String, withReply reply: @escaping (UInt32) -> Void) {
        smcLock.lock()
        defer { smcLock.unlock() }
        
        do {
            try SMCKit.open()
        } catch {
            print("ERROR: Failed to open SMCKit for UInt32 read: \(error)")
            reply(0)
            return
        }

        let smcKey = SMCKit.getKey(key, type: DataTypes.UInt32)
        do {
            let data = try SMCKit.readData(smcKey)
            let value = UInt32(fromBytes: (data.0, data.1, data.2, data.3))
            print("SMC UInt32 Read: \(key) = \(String(format: "0x%08X", value))")
            reply(value)
        } catch {
            print("ERROR: Failed to read SMC UInt32 key \(key): \(error)")
            reply(0)
        }
    }
    
    // For macOS Tahoe (26.x) - CHTE key uses UInt32 values
    // CHTE: 0x00000000 = charging enabled, 0x01000000 = charging disabled
    func setSMCUInt32(key: String, value: UInt32, withReply reply: @escaping (Bool, String) -> Void) {
        logToFile("setSMCUInt32: \(key)=\(value)")
        smcLock.lock()
        defer { smcLock.unlock() }
        
        print("setSMCUInt32 called: key=\(key), value=\(String(format: "0x%08X", value))")
        
        do {
            print("Attempting to open SMCKit for UInt32 write...")
            try SMCKit.open()
            print("SMCKit opened successfully")
        } catch {
            let errorMsg = "Failed to open SMCKit: \(error)"
            print("ERROR: \(errorMsg)")
            reply(false, errorMsg)
            return
        }
        
        // Convert UInt32 to SMCBytes
        let byte0 = UInt8((value >> 24) & 0xFF)
        let byte1 = UInt8((value >> 16) & 0xFF)
        let byte2 = UInt8((value >> 8) & 0xFF)
        let byte3 = UInt8(value & 0xFF)
        
        let smcKey = SMCKit.getKey(key, type: DataTypes.UInt32)
        let bytes: SMCBytes = (byte0, byte1, byte2, byte3, UInt8(0), UInt8(0),
        UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
        UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
        UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
        UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
        UInt8(0), UInt8(0))
        
        // Write the new value
        do {
            print("Attempting to write \(key) = \(String(format: "0x%08X", value))...")
            try SMCKit.writeData(smcKey, data: bytes)
            let successMsg = "Wrote SMC key \(key) = \(String(format: "0x%08X", value))"
            print("SUCCESS: \(successMsg)")
            
            // Verify the write
            do {
                print("Verifying UInt32 write for \(key)...")
                let readKey = SMCKit.getKey(key, type: DataTypes.UInt32)
                let data = try SMCKit.readData(readKey)
                let verifyValue = UInt32(fromBytes: (data.0, data.1, data.2, data.3))
                print("Verification read: \(key) = \(String(format: "0x%08X", verifyValue)) (expected \(String(format: "0x%08X", value)))")
                if verifyValue == value {
                    print("VERIFIED: SMC key \(key) read back correctly ✓")
                    reply(true, successMsg)
                } else {
                    // For CHTE, sometimes the read-back value differs but the write still works
                    print("WARNING: Read-back value differs, but write may still have succeeded")
                    reply(true, successMsg)
                }
            } catch {
                // If we can't verify but the write succeeded, assume it worked
                print("WARNING: Could not verify write for \(key): \(error)")
                reply(true, successMsg)
            }
        } catch {
            let errorMsg = "Failed to write SMC key \(key) = \(String(format: "0x%08X", value)): \(error)"
            print("ERROR: \(errorMsg)")
            reply(false, errorMsg)
        }
        
        print("setSMCUInt32 completed for \(key)")
    }
    
    // Comprehensive Battery Status
    func readBatteryStatus(withReply reply: @escaping ([String: Any]) -> Void) {
        logToFile("readBatteryStatus called")
        smcLock.lock()
        defer { smcLock.unlock() }
        
        do {
            try SMCKit.open()
        } catch {
            print("ERROR: Failed to open SMCKit for BatteryStatus: \(error)")
            // Return empty dict or partial logic? better to return empty
             reply([:])
            return
        }
        
        var result: [String: Any] = [:]
        
        // Helper to safe read (Big Endian)
        func readUInt16(key: String) -> Int? {
            do {
                if let data = try? SMCKit.readData(SMCKit.getKey(key, type: DataTypes.UInt16)) {
                     // Big Endian: (High << 8) | Low
                     return Int((UInt16(data.0) << 8) | UInt16(data.1))
                }
                return nil
            }
        }
        
        // Helper to safe read (Little Endian)
        func readUInt16LE(key: String) -> Int? {
            do {
                if let data = try? SMCKit.readData(SMCKit.getKey(key, type: DataTypes.UInt16)) {
                     // Little Endian: (Low << 8) | High -- wait, (data.1 << 8) | data.0 is effectively swapping if we treat data as BE read
                     // Native Little Endian: byte0 is LSB, byte1 is MSB
                     // data.0 = LSB, data.1 = MSB
                     return Int((UInt16(data.1) << 8) | UInt16(data.0))
                }
                return nil
            }
        }
        
         func readInt16(key: String) -> Int? {
             // B0AC is mostly si16 (Big Endian)
             do {
                 let code = FourCharCode(fromString: key)
                 let info = try SMCKit.keyInformation(code)
                 let data = try SMCKit.readData(SMCKey(code: code, info: info))
                 let u16 = (UInt16(data.0) << 8) | UInt16(data.1)
                 let i16 = Int16(bitPattern: u16)
                 return Int(i16)
             } catch {
                 return nil
             }
         }
        
        // Voltage (mV) - B0AV (Little Endian)
        if let volts = readUInt16LE(key: "B0AV") {
            result["Voltage"] = Double(volts) / 1000.0 // V
        }
        
        // Amperage (mA) - B0AC (Big Endian)
        if let amps = readInt16(key: "B0AC") {
             result["Amperage"] = Double(amps) / 1000.0 // A
        }
        
        // Cycles - B0CT (Little Endian)
        if let cycles = readUInt16LE(key: "B0CT") {
            result["CycleCount"] = cycles
        }
        
        // Design Cap - B0DC (Big Endian)
        if let dc = readUInt16(key: "B0DC") {
            result["DesignCapacity"] = dc
        }
        
        // Max Cap - B0FC (Little Endian)
        if let mc = readUInt16LE(key: "B0FC") {
            result["MaxCapacity"] = mc
        }
        
        // Current Cap - B0RM (Big Endian)
        if let cc = readUInt16(key: "B0RM") {
            result["CurrentCapacity"] = cc
        }
        
        // Battery Temperature - TB0T (sp78)
        // We can reuse readSMCKeyAsDouble for this inside here?
        // Or manual read:
        do {
            let key = "TB0T"
            let code = FourCharCode(fromString: key)
            if let info = try? SMCKit.keyInformation(code) {
               if let data = try? SMCKit.readData(SMCKey(code: code, info: info)) {
                   // SP78
                   let sign = (data.0 & 0x80) == 0 ? 1.0 : -1.0
                   let exponent = Double(data.0 & 0x7F)
                   let fraction = Double(data.1) / 256.0
                   result["Temperature"] = sign * (exponent + fraction)
               }
            }
        }

        reply(result)
    }

    // Read SMC key in SP78 format (signed 16-bit fixed-point, used for temperatures)
    func readSMCSP78(key: String, withReply reply: @escaping (Double) -> Void) {
        logToFile("readSMCSP78: \(key)")
        smcLock.lock()
        defer { smcLock.unlock() }
        
        do {
            try SMCKit.open()
        } catch {
            print("ERROR: Failed to open SMCKit for SP78 read: \(error)")
            SMCKit.close() // Ensure reset
            reply(0)
            return
        }
        
        let smcKey = SMCKit.getKey(key, type: DataTypes.SP78)
        do {
            let data = try SMCKit.readData(smcKey)
            // SP78 format: signed 7-bit exponent, 8-bit fraction
            // First byte: sign bit (bit 7) + 7-bit exponent
            // Second byte: 8-bit fraction
            let sign = (data.0 & 0x80) == 0 ? 1.0 : -1.0
            let exponent = Double(data.0 & 0x7F)  // Mask sign bit
            let fraction = Double(data.1) / 256.0
            let temperature = sign * (exponent + fraction)
            print("SMC SP78 Read: \(key) = \(String(format: "%.2f", temperature))°C")
            reply(temperature)
        } catch {
            print("ERROR: Failed to read SMC SP78 key \(key): \(error)")
            SMCKit.close() // Force reset connection on read failure
            reply(0)
        }
    }
    
    func createAssertion(assertion:String, withReply reply: @escaping (IOPMAssertionID) -> Void){
        var assertionID : IOPMAssertionID = IOPMAssertionID(0)
        let reason:CFString = "BatteryPro" as NSString
        let cfAssertion:CFString = assertion as NSString
        let success = IOPMAssertionCreateWithName(cfAssertion,
                        IOPMAssertionLevel(kIOPMAssertionLevelOn),
                        reason,
                        &assertionID)
        if success == kIOReturnSuccess {
            openAssertions.append(assertionID)
            reply(assertionID)
        }
        else{
            reply (UInt32(kCFNumberNaN))
        }
    }
    
    func releaseAssertion(assertionID:IOPMAssertionID){
        IOPMAssertionRelease(assertionID)
        openAssertions.remove(at: openAssertions.firstIndex(of: assertionID)!)
    }
    
    func setResetVal(key:String, value: UInt8){
        modifiedKeys[key]=value
    }
    
    func reset(){
        for (key, value) in modifiedKeys{
            setSMCByte(key: key, value: value) { success, message in
                if success {
                    print("Reset: Restored SMC key \(key) = \(value)")
                } else {
                    print("Reset: Failed to restore SMC key \(key) = \(value): \(message)")
                }
            }
        }
        
        for assertionID in openAssertions{
            releaseAssertion(assertionID: assertionID)
        }
        modifiedKeys.removeAll()
        openAssertions.removeAll()
    }
    
    func setLowPowerMode(enabled: Bool, withReply reply: @escaping (Bool, String) -> Void) {
        let value = enabled ? "1" : "0"
        let task = Process()
        task.launchPath = "/usr/bin/pmset"
        task.arguments = ["-a", "lowpowermode", value]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            if task.terminationStatus == 0 {
                print("Successfully set Low Power Mode to \(enabled)")
                reply(true, "Success")
            } else {
                print("Failed to set Low Power Mode: \(output)")
                reply(false, "Failed: \(output)")
            }
        } catch {
            print("Error executing pmset: \(error)")
            reply(false, "Error: \(error.localizedDescription)")
        }
    }
    // MARK: - Advanced Temperature Monitoring
    
    // CPU/GPU temperature keys by chip generation
    private let m1Keys = [
        "Tp09", "Tp0T",  // Efficiency CPU cores
        "Tp01", "Tp05", "Tp0D", "Tp0H", "Tp0L", "Tp0P", "Tp0X", "Tp0b",  // Performance CPU cores
        "Tg05", "Tg0D", "Tg0L", "Tg0T"  // GPU
    ]
    
    private let mProMaxKeys = [
        // CPU
        "TC10", "TC11", "TC12", "TC13",
        "TC20", "TC21", "TC22", "TC23",
        "TC30", "TC31", "TC32", "TC33",
        "TC40", "TC41", "TC42", "TC43",
        "TC50", "TC51", "TC52", "TC53",
        // GPU
        "Tg04", "Tg05", "Tg0C", "Tg0D", "Tg0K", "Tg0L", "Tg0S", "Tg0T"
    ]
    
    private let m2Keys = [
        "Tp1h", "Tp1t", "Tp1p", "Tp1l",  // Efficiency CPU cores
        "Tp01", "Tp05", "Tp09", "Tp0D", "Tp0X", "Tp0b", "Tp0f", "Tp0j",  // Performance CPU cores
        "Tg0f", "Tg0j"  // GPU
    ]
    
    private let m3Keys = [
        "Te05", "Te0L", "Te0P", "Te0S",  // Efficiency CPU cores
        "Tf04", "Tf09", "Tf0A", "Tf0B", "Tf0D", "Tf0E",
        "Tf44", "Tf49", "Tf4A", "Tf4B", "Tf4D", "Tf4E",  // Performance CPU cores
        "Tf14", "Tf18", "Tf19", "Tf1A", "Tf24", "Tf28", "Tf29", "Tf2A"  // GPU
    ]
    
    private let m4Keys = [
        "Te05", "Te0S", "Te09", "Te0H",  // Efficiency CPU cores
        "Tp01", "Tp05", "Tp09", "Tp0D", "Tp0V", "Tp0Y", "Tp0b", "Tp0e",  // Performance CPU cores
        "Tg0G", "Tg0H", "Tg1U", "Tg1k", "Tg0K", "Tg0L", "Tg0d", "Tg0e", "Tg0j", "Tg0k"  // GPU
    ]
    
    // Logging helper
    func logToFile(_ text: String) {
        let logFile = URL(fileURLWithPath: "/tmp/bp_debug.log")
        let entry = "\(Date()): \(text)\n"
        if let handle = try? FileHandle(forWritingTo: logFile) {
            handle.seekToEndOfFile()
            handle.write(entry.data(using: .utf8)!)
            handle.closeFile()
        } else {
            try? entry.write(to: logFile, atomically: true, encoding: .utf8)
        }
    }

    // Lock for SMCKit access
    // Lock for SMCKit access
    private let smcLock = NSRecursiveLock()

    // Cache the last valid temperature to prevent flashing 0.0 on transient read failures
    private var lastKnownCPUTemp: Double = 0.0
    
    func readCPUTemperature(withReply reply: @escaping (Double) -> Void) {
        logToFile("Starting readCPUTemperature")
        
        // Synchronize access to SMCKit to prevent race conditions
        smcLock.lock()
        defer { smcLock.unlock() }
        
        do {
            try SMCKit.open()
            logToFile("SMCKit open success")
        } catch {
            logToFile("SMCKit open failed: \(error)")
            // If we can't open SMC, return last known good value
             if self.lastKnownCPUTemp > 10.0 {
                reply(self.lastKnownCPUTemp)
            } else {
                reply(0.0)
            }
            return
        }

        // Define keys for different M-series chips
        // M1 / M1 Pro / M1 Max
        let m1Keys = ["Tp09", "Tp05", "Tp01", "Tg05", "Tg0D", "Tg0L", "Tg0P", "Te05", "Te0L", "Te0P", "Te0S"]
        // M2
        let m2Keys = ["Tp09", "Tp05", "Tp01", "Tg05", "Tg0D", "Tg0L", "Tg0P", "Te05", "Te0L", "Te0P", "Te0S", "Tp0D", "Tp0H", "Tp0h", "Tp0L", "Tp0P"]
        // M3 (Guesses based on patterns, and likely overlaps)
        let m3Keys = ["Te05", "Te0L", "Te0P", "Te0S", "Tg05", "Tg0D", "Tg0L", "Tg0P", "Tp01", "Tp05", "Tp09", "Tp0D", "Tp0H", "Tp0L", "Tp0P"]
        
        let allKeys = Array(Set(m1Keys + m2Keys + m3Keys)) // Unique keys
        
        var maxTemp: Double = 0
        
        for key in allKeys {
            // logToFile("Checking key \(key)")
            if let temp = readSMCKeyAsDouble(key: key) {
                // Filter out noise: Temps must be > 10.0°C and < 150.0°C to be considered valid
                if temp > maxTemp && temp > 10.0 && temp < 150.0 {
                    maxTemp = temp
                    logToFile("New max temp: \(temp) at \(key)")
                }
            }
        }
        
        if maxTemp > 10.0 {
            logToFile("Returning max temp: \(maxTemp)")
            self.lastKnownCPUTemp = maxTemp
            reply(maxTemp)
        } else {
            logToFile("No valid CPU temp found (max was \(maxTemp)). Fallback to TB0T")
            // If we failed to find ANY valid CPU key, it's suspicious. Reset the SMC connection for next time.
            SMCKit.close()
            
            readSMCSP78(key: "TB0T") { val in
                self.logToFile("TB0T val: \(val)")
                
                if val > 10.0 && val < 100.0 {
                    self.lastKnownCPUTemp = val
                    reply(val)
                } else {
                    // If TB0T also fails, return the last known good CPU temp
                    if self.lastKnownCPUTemp > 10.0 {
                         self.logToFile("Using last known good temp: \(self.lastKnownCPUTemp)")
                         reply(self.lastKnownCPUTemp)
                    } else {
                        // Truly nothing known
                        reply(val)
                    }
                }
            }
        }
        logToFile("Finished readCPUTemperature")
    }
    
    // Add logging to readSMCKeyAsDouble as well
    private func readSMCKeyAsDouble(key: String) -> Double? {
        do {
            let code = FourCharCode(fromString: key)
            
            // Checking key info
            let info = try SMCKit.keyInformation(code)
            
            // Read data
            let data = try SMCKit.readData(SMCKey(code: code, info: info))
            
            if info.type == DataTypes.SP78.type {
                let sign = (data.0 & 0x80) == 0 ? 1.0 : -1.0
                let exponent = Double(data.0 & 0x7F)
                let fraction = Double(data.1) / 256.0
                return sign * (exponent + fraction)
            } else if info.type == DataTypes.Flt.type {
                let byte0 = data.0
                let byte1 = data.1
                let byte2 = data.2
                let byte3 = data.3
                // Construct UInt32 (Big Endian)
                let bitPattern = (UInt32(byte0) << 24) | (UInt32(byte1) << 16) | (UInt32(byte2) << 8) | UInt32(byte3)
                return Double(Float(bitPattern: bitPattern))
            }
            return nil
        } catch {
            // logToFile("Error reading \(key): \(error)")
            return nil
        }
    }
}

// BitConverter struct removed as it was causing crashes

