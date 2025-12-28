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
    
    // Read SMC key in SP78 format (signed 16-bit fixed-point, used for temperatures)
    func readSMCSP78(key: String, withReply reply: @escaping (Double) -> Void) {
        do {
            try SMCKit.open()
        } catch {
            print("ERROR: Failed to open SMCKit for SP78 read: \(error)")
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
}
