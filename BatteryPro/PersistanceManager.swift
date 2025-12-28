//
//  PersistanceManager.swift
//  AlDente
//
//  Created by David Wernhart on 07.02.21.
//  Copyright © 2021 David Wernhart. All rights reserved.
//

import Foundation

class PersistanceManager{
    static let instance = PersistanceManager()
    
    public var launchOnLogin: Bool?
    public var chargeVal: Int?
    public var oldKey: Bool = false
    
    // New features (all unlocked for development)
    public var sailingModeEnabled: Bool = false
    public var sailingModeTarget: Int = 50
    public var heatProtectionEnabled: Bool = false
    public var heatProtectionMaxTemp: Double = 40.0 // Celsius
    public var powerMode: String = "normal" // "normal", "low", "high"
    public var calibrationModeEnabled: Bool = false
    public var intelModeEnabled: Bool = false
    
    public func load(){
        launchOnLogin = UserDefaults.standard.bool(forKey: "launchOnLogin")
        oldKey = UserDefaults.standard.bool(forKey: "oldKey")
        chargeVal = UserDefaults.standard.integer(forKey: "chargeVal")
        
        // Load new features
        sailingModeEnabled = UserDefaults.standard.bool(forKey: "sailingModeEnabled")
        sailingModeTarget = UserDefaults.standard.integer(forKey: "sailingModeTarget")
        if sailingModeTarget == 0 { sailingModeTarget = 50 }
        
        heatProtectionEnabled = UserDefaults.standard.bool(forKey: "heatProtectionEnabled")
        heatProtectionMaxTemp = UserDefaults.standard.double(forKey: "heatProtectionMaxTemp")
        if heatProtectionMaxTemp == 0 { heatProtectionMaxTemp = 40.0 }
        
        powerMode = UserDefaults.standard.string(forKey: "powerMode") ?? "normal"
        calibrationModeEnabled = UserDefaults.standard.bool(forKey: "calibrationModeEnabled")
        intelModeEnabled = UserDefaults.standard.bool(forKey: "intelModeEnabled")
    }
    
    public func save(){
        UserDefaults.standard.set(launchOnLogin, forKey: "launchOnLogin")
        UserDefaults.standard.set(chargeVal, forKey: "chargeVal")
        UserDefaults.standard.set(oldKey, forKey: "oldKey")
        
        // Save new features
        UserDefaults.standard.set(sailingModeEnabled, forKey: "sailingModeEnabled")
        UserDefaults.standard.set(sailingModeTarget, forKey: "sailingModeTarget")
        UserDefaults.standard.set(heatProtectionEnabled, forKey: "heatProtectionEnabled")
        UserDefaults.standard.set(heatProtectionMaxTemp, forKey: "heatProtectionMaxTemp")
        UserDefaults.standard.set(powerMode, forKey: "powerMode")
        UserDefaults.standard.set(calibrationModeEnabled, forKey: "calibrationModeEnabled")
        UserDefaults.standard.set(intelModeEnabled, forKey: "intelModeEnabled")
    }
}
