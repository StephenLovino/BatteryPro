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
    public var sailingModeDifference: Int = 5 // Hysteresis (Drift)
    
    public var heatProtectionEnabled: Bool = false
    public var heatProtectionMaxTemp: Double = 40.0 // Celsius
    public var powerMode: String = "normal" // "normal", "low", "high"
    
    // Discharge Feature
    public var isDischarging: Bool = false
    public var dischargeTarget: Int = 0
    
    public var calibrationModeEnabled: Bool = false
    public var calibrationStep: Int = 0 // 0: Idle, 1: ChargeTo100, 2: DischargeTo15, 3: ChargeTo100Again, 4: Done
    
    public var intelModeEnabled: Bool = false

    // General Settings (Unlocked)
    public var showDockIcon: Bool = false
    public var hardwareBatteryPercentage: Bool = false
    public var reduceTransparency: Bool = false
    public var appearanceMode: Int = 0 // 0: System, 1: Light, 2: Dark
    
    // LED / MagSafe Settings
    public var indicateChargeLimit: Bool = false
    public var blinkOrangeDischarge: Bool = false
    
    // Sleep Mode Settings
    public var disableSleepUntilChargeLimit: Bool = false
    public var stopChargingWhenSleeping: Bool = false
    public var stopChargingWhenAppClosed: Bool = false
    
    // Energy Monitor
    public var lowPowerModePolicy: Int = 0 // 0: Always Off, 1: Always On, 2: Auto
    public var backgroundUpdates: Bool = true
    public var energyThreshold: Int = 1 // 0: Low, 1: Medium, 2: High
    
    // Onboarding
    public var hasCompletedOnboarding: Bool = false
    
    public func load(){
        launchOnLogin = UserDefaults.standard.bool(forKey: "launchOnLogin")
        oldKey = UserDefaults.standard.bool(forKey: "oldKey")
        chargeVal = UserDefaults.standard.integer(forKey: "chargeVal")
        
        // Load new features
        sailingModeEnabled = UserDefaults.standard.bool(forKey: "sailingModeEnabled")
        sailingModeTarget = UserDefaults.standard.integer(forKey: "sailingModeTarget")
        if sailingModeTarget == 0 { sailingModeTarget = 50 }
        
        sailingModeDifference = UserDefaults.standard.integer(forKey: "sailingModeDifference")
        if sailingModeDifference == 0 { sailingModeDifference = 5 }
        
        heatProtectionEnabled = UserDefaults.standard.bool(forKey: "heatProtectionEnabled")
        heatProtectionMaxTemp = UserDefaults.standard.double(forKey: "heatProtectionMaxTemp")
        if heatProtectionMaxTemp == 0 { heatProtectionMaxTemp = 40.0 }
        
        powerMode = UserDefaults.standard.string(forKey: "powerMode") ?? "normal"
        
        isDischarging = UserDefaults.standard.bool(forKey: "isDischarging")
        dischargeTarget = UserDefaults.standard.integer(forKey: "dischargeTarget")
        
        calibrationModeEnabled = UserDefaults.standard.bool(forKey: "calibrationModeEnabled")
        calibrationStep = UserDefaults.standard.integer(forKey: "calibrationStep")
        
        intelModeEnabled = UserDefaults.standard.bool(forKey: "intelModeEnabled")
        
        // Load General Settings
        showDockIcon = UserDefaults.standard.bool(forKey: "showDockIcon")
        hardwareBatteryPercentage = UserDefaults.standard.bool(forKey: "hardwareBatteryPercentage")
        reduceTransparency = UserDefaults.standard.bool(forKey: "reduceTransparency")
        appearanceMode = UserDefaults.standard.integer(forKey: "appearanceMode")
        
        // Load LED Settings
        indicateChargeLimit = UserDefaults.standard.bool(forKey: "indicateChargeLimit")
        blinkOrangeDischarge = UserDefaults.standard.bool(forKey: "blinkOrangeDischarge")
        
        // Load Sleep Mode Settings
        disableSleepUntilChargeLimit = UserDefaults.standard.bool(forKey: "disableSleepUntilChargeLimit")
        stopChargingWhenSleeping = UserDefaults.standard.bool(forKey: "stopChargingWhenSleeping")
        stopChargingWhenAppClosed = UserDefaults.standard.bool(forKey: "stopChargingWhenAppClosed")
        
        // Load Energy Monitor
        lowPowerModePolicy = UserDefaults.standard.integer(forKey: "lowPowerModePolicy")
        if UserDefaults.standard.object(forKey: "backgroundUpdates") != nil {
            backgroundUpdates = UserDefaults.standard.bool(forKey: "backgroundUpdates")
        } else {
            backgroundUpdates = true // Default On
        }
        energyThreshold = UserDefaults.standard.integer(forKey: "energyThreshold")
        if UserDefaults.standard.object(forKey: "energyThreshold") == nil {
            energyThreshold = 1 // Default Medium
        }
        
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    }
    
    public func save(){
        UserDefaults.standard.set(launchOnLogin, forKey: "launchOnLogin")
        UserDefaults.standard.set(chargeVal, forKey: "chargeVal")
        UserDefaults.standard.set(oldKey, forKey: "oldKey")
        
        // Save new features
        UserDefaults.standard.set(sailingModeEnabled, forKey: "sailingModeEnabled")
        UserDefaults.standard.set(sailingModeTarget, forKey: "sailingModeTarget")
        UserDefaults.standard.set(sailingModeDifference, forKey: "sailingModeDifference")
        
        UserDefaults.standard.set(heatProtectionEnabled, forKey: "heatProtectionEnabled")
        UserDefaults.standard.set(heatProtectionMaxTemp, forKey: "heatProtectionMaxTemp")
        
        UserDefaults.standard.set(disableSleepUntilChargeLimit, forKey: "disableSleepUntilChargeLimit")
        UserDefaults.standard.set(stopChargingWhenSleeping, forKey: "stopChargingWhenSleeping")
        UserDefaults.standard.set(stopChargingWhenAppClosed, forKey: "stopChargingWhenAppClosed")
        
        UserDefaults.standard.set(lowPowerModePolicy, forKey: "lowPowerModePolicy")
        UserDefaults.standard.set(backgroundUpdates, forKey: "backgroundUpdates")
        UserDefaults.standard.set(energyThreshold, forKey: "energyThreshold")
        UserDefaults.standard.set(powerMode, forKey: "powerMode")
        
        UserDefaults.standard.set(isDischarging, forKey: "isDischarging")
        UserDefaults.standard.set(dischargeTarget, forKey: "dischargeTarget")
        
        UserDefaults.standard.set(calibrationModeEnabled, forKey: "calibrationModeEnabled")
        UserDefaults.standard.set(calibrationStep, forKey: "calibrationStep")
        
        UserDefaults.standard.set(intelModeEnabled, forKey: "intelModeEnabled")
        
        // Save General Settings
        UserDefaults.standard.set(showDockIcon, forKey: "showDockIcon")
        UserDefaults.standard.set(hardwareBatteryPercentage, forKey: "hardwareBatteryPercentage")
        UserDefaults.standard.set(reduceTransparency, forKey: "reduceTransparency")
        UserDefaults.standard.set(appearanceMode, forKey: "appearanceMode")
        
        // Save LED Settings
        UserDefaults.standard.set(indicateChargeLimit, forKey: "indicateChargeLimit")
        UserDefaults.standard.set(blinkOrangeDischarge, forKey: "blinkOrangeDischarge")
        
        UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding")
    }
}
