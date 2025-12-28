//
//  HelperToolProtocol.swift
//  AlDente
//
//  Created by David Wernhart on 13.02.20.
//  Copyright © 2020 David Wernhart. All rights reserved.
//

import Foundation
import IOKit.pwr_mgt

let helperVersion: String = "11" //for some reason the integrated version check does not work, so I use this one

@objc(HelperToolProtocol) protocol HelperToolProtocol {
//protocol HelperToolProtocol {
    func getVersion(withReply reply: @escaping (String) -> Void)

    //TODO: more functions for other data types, altough this is sufficient for battery max charge level
    func setSMCByte(key: String, value: UInt8, withReply reply: @escaping (Bool, String) -> Void)
    func readSMCByte(key: String, withReply reply: @escaping (UInt8) -> Void)
    func readSMCUInt32(key: String, withReply reply: @escaping (UInt32) -> Void)
    
    // For macOS Tahoe (26.x) - CHTE key uses UInt32 values
    func setSMCUInt32(key: String, value: UInt32, withReply reply: @escaping (Bool, String) -> Void)
    
    // Read SMC key in SP78 format (for temperature readings)
    func readSMCSP78(key: String, withReply reply: @escaping (Double) -> Void)
    
    func createAssertion(assertion:String, withReply reply: @escaping (IOPMAssertionID) -> Void)
    func releaseAssertion(assertionID:IOPMAssertionID)
    func setResetVal(key:String, value: UInt8)

}
