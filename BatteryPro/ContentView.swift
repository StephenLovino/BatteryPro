//
//  ContentView.swift
//  AlDente
//
//  Created by David Wernhart on 09.02.20.
//  Copyright © 2020 David Wernhart. All rights reserved.
//

import LaunchAtLogin
import SwiftUI

private struct ModernButtonStyle: ButtonStyle {
    var isActive: Bool = false
    
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .foregroundColor(isActive ? .white : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isActive ? Theme.Colors.accent : Color(.controlBackgroundColor))
            )
            .overlay(
                Capsule()
                    .stroke(Color(.separatorColor), lineWidth: 0.5)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

private struct IconButtonStyle: ButtonStyle {
    var isActive: Bool = false
    
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .foregroundColor(isActive ? .white : .primary)
            .padding(10)
            .background(
                Circle()
                    .fill(isActive ? Theme.Colors.accent : Color(.controlBackgroundColor))
            )
            .overlay(
                Circle()
                    .stroke(Color(.separatorColor), lineWidth: 0.5)
            )
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

private struct Settings: View {
    @State private var launchAtLogin: Bool
    @State private var oldKey = PersistanceManager.instance.oldKey
    @ObservedObject private var presenter = SMCPresenter.shared
    @Binding var showSettings: Bool
    
    init(showSettings: Binding<Bool>) {
        PersistanceManager.instance.load()
        let savedValue = PersistanceManager.instance.launchOnLogin ?? LaunchAtLogin.isEnabled
        _launchAtLogin = State(initialValue: savedValue)
        if LaunchAtLogin.isEnabled != savedValue {
            LaunchAtLogin.isEnabled = savedValue
        }
        _showSettings = showSettings
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Settings")
                    .font(.headline)
                Spacer()
                Button(action: { showSettings = false }) {
                    Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal)
            .padding(.top)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: Binding(
                    get: { launchAtLogin },
                    set: { newValue in
                        launchAtLogin = newValue
                        LaunchAtLogin.isEnabled = newValue
                        PersistanceManager.instance.launchOnLogin = newValue
                        PersistanceManager.instance.save()
                    }
                )) {
                    Text("Launch at login")
                }
                
                if(!Helper.instance.appleSilicon!){
                    Toggle(isOn: Binding(
                        get: { oldKey },
                        set: { newValue in
                            oldKey = newValue
                            PersistanceManager.instance.oldKey = oldKey
                            PersistanceManager.instance.save()
                            Helper.instance.setStatusString()
                            if(newValue){
                                Helper.instance.enableCharging()
                                Helper.instance.enableSleep()
                            }
                            else{
                                presenter.setValue(value: 100)
                            }
                        }
                    )) {
                        Text("Use Classic SMC Key (Intel)")
                    }
                }
            }
            .padding(.horizontal)
            
            Button(action: {
                Helper.instance.installHelper()
            }) {
                Text("Reinstall Helper")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ModernButtonStyle())
            .padding(.horizontal)
            
            Divider()
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
                    Text("BatteryPro \(version ?? "")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .frame(width: 450, height: 400)
        .background(Color(.windowBackgroundColor))
    }

    private func openURL(_ string: String) {
        let url = URL(string: string)!
        NSWorkspace.shared.open(url)
    }
}

struct ContentView: View {
    @State private var showSettings = false
    @State private var isDischarging = false

    @ObservedObject private var presenter = SMCPresenter.shared

    init() {
        Helper.instance.delegate = presenter
    }

    var body: some View {
        Group {
            if showSettings {
                Settings(showSettings: $showSettings)
                    .onAppear {
                        NotificationCenter.default.post(name: NSNotification.Name("UpdatePopoverSize"), object: nil, userInfo: ["width": 450, "height": 140])
                    }
            } else {
                VStack(spacing: 0) {
                    // Top button row
                    HStack(spacing: 6) {
                        // Limit Input (Editable, disabled during boost)
                        HStack(spacing: 2) {
                            Text(presenter.boostChargeEnabled ? "Boost:" : "Limit:")
                                .font(.system(size: 12, weight: .medium))
                                .fixedSize()
                            
                            if presenter.boostChargeEnabled {
                                // During boost, show static "100" (non-editable)
                                Text("100")
                                    .font(.system(size: 12, weight: .bold))
                                    .frame(width: 26)
                            } else {
                                TextField("80", text: Binding(
                                    get: { String(Int(presenter.value)) },
                                    set: { newValue in
                                        if let val = Int(newValue), val >= 20 && val <= 100 {
                                            presenter.setValue(value: Float(val))
                                        }
                                    }
                                ))
                                .font(.system(size: 12, weight: .bold))
                                .multilineTextAlignment(.center)
                                .textFieldStyle(PlainTextFieldStyle())
                                .frame(width: 26)
                            }
                            
                            Text("%")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundColor(.white) // Active style
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(presenter.boostChargeEnabled ? Color.orange : Theme.Colors.accent)
                        )
                        .overlay(
                            Capsule()
                                .stroke(Color(.separatorColor), lineWidth: 0.5)
                        )
                        
                        // Discharge button
                        Button(action: {
                            isDischarging.toggle()
                            if isDischarging {
                                Helper.instance.disableCharging()
                            } else {
                                Helper.instance.enableCharging()
                            }
                        }) {
                            HStack(spacing: 4) {
                                Text("Discharge")
                                    .font(.system(size: 12, weight: .medium))
                                    .fixedSize()
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 12))
                            }
                        }
                        .buttonStyle(ModernButtonStyle(isActive: isDischarging))
                        
                        // Boost Charge button (Top Up)
                        Button(action: {
                            if presenter.boostChargeEnabled {
                                presenter.stopBoostCharge()
                            } else {
                                presenter.startBoostCharge()
                            }
                        }) {
                            HStack(spacing: 4) {
                                Text("Boost Charge")
                                    .font(.system(size: 12, weight: .medium))
                                    .fixedSize()
                                Image(systemName: presenter.boostChargeEnabled ? "bolt.fill" : "plus.circle.fill")
                                    .font(.system(size: 12))
                            }
                        }
                        .buttonStyle(ModernButtonStyle(isActive: presenter.boostChargeEnabled))
                        
                        Spacer()
                        
                        // Manual Bypass Button
                        Button(action: {
                            presenter.setBypass(enabled: !presenter.bypassEnabled)
                        }) {
                            Image(systemName: "powerplug.fill")
                                .font(.system(size: 14))
                        }
                        .buttonStyle(IconButtonStyle(isActive: presenter.bypassEnabled))
                        .help("Manual Bypass")
                        
                        // Full Window button (4-square grid icon)
                        Button(action: {
                            if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                                appDelegate.openMainWindow()
                            } else {
                                NotificationCenter.default.post(name: NSNotification.Name("OpenMainWindow"), object: nil)
                            }
                        }) {
                            Image(systemName: "square.grid.2x2")
                                .font(.system(size: 14))
                        }
                        .buttonStyle(IconButtonStyle())
                        .help("Open Overview")
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    
                    Divider()
                    
                    // Slider
                    VStack(spacing: 4) {
                        Slider(
                            value: Binding(
                                get: { Float(presenter.boostChargeEnabled ? 100 : presenter.value) },
                                set: { newValue in
                                    if newValue >= 20 && newValue <= 100 {
                                        presenter.setValue(value: newValue)
                                    }
                                }
                            ),
                            in: 20...100
                        )
                        .accentColor(presenter.boostChargeEnabled ? Color.orange : Theme.Colors.accent)
                        .disabled(presenter.boostChargeEnabled)
                        
                        Text(presenter.boostChargeEnabled ? "Boost active - charging to 100%" : "Set maximum charge limit")
                            .font(.caption)
                            .foregroundColor(presenter.boostChargeEnabled ? .orange : .secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 8)
                }
                .frame(width: 450, height: 110)
                .onAppear {
                    NotificationCenter.default.post(name: NSNotification.Name("UpdatePopoverSize"), object: nil, userInfo: ["width": 450, "height": 140])
                }
            }
        }
    }
}

public final class SMCPresenter: ObservableObject, HelperDelegate {

    static let shared = SMCPresenter()

    @Published var value: UInt8 = 0
    @Published var bypassEnabled: Bool = false
    @Published var boostChargeEnabled: Bool = false
    @Published var status: String = ""
    private var timer: Timer?
    private var accuracyTimer: Timer?
    private var savedLimitBeforeBoost: UInt8 = 80  // Stores original limit during boost

    func OnMaxBatRead(value: UInt8) {
        if(PersistanceManager.instance.oldKey){
            DispatchQueue.main.async {
                self.value = value
            }
        }
    }
    
    func updateStatus(status:String){
        DispatchQueue.main.async {
            self.status = status
        }
    }
    
    public func setBypass(enabled: Bool) {
        DispatchQueue.main.async {
            self.bypassEnabled = enabled
            if enabled {
                // Bypass and Boost are mutually exclusive
                if self.boostChargeEnabled {
                    self.boostChargeEnabled = false
                    self.value = self.savedLimitBeforeBoost
                    PersistanceManager.instance.chargeVal = Int(self.savedLimitBeforeBoost)
                    PersistanceManager.instance.save()
                    print("MANUAL BYPASS: Auto-disabled Boost Charge, restored limit to \(self.savedLimitBeforeBoost)%")
                }
                
                Helper.instance.disableCharging()
                print("MANUAL BYPASS: Charging Disabled")
            } else {
                print("MANUAL BYPASS: Disabled, re-evaluating limit")
                // Re-trigger the limit logic
                self.setValue(value: Float(self.value))
            }
        }
    }
    
    public func loadValue(){
        PersistanceManager.instance.load()
        if let chargeVal = PersistanceManager.instance.chargeVal, chargeVal > 0 {
            self.value = UInt8(chargeVal)
        } else {
            self.value = 50
            PersistanceManager.instance.chargeVal = 50
            PersistanceManager.instance.save()
        }
        print("loaded max charge val: ",self.value," old key:",PersistanceManager.instance.oldKey)
        if(PersistanceManager.instance.oldKey){
            writeValue()
        }
    }
    
    // MARK: - Boost Charge
    
    public func startBoostCharge() {
        DispatchQueue.main.async {
            // Boost and Bypass are mutually exclusive - disable bypass first
            if self.bypassEnabled {
                self.bypassEnabled = false
                print("BOOST CHARGE: Auto-disabled Manual Bypass")
            }
            
            // Save the current limit before boosting
            self.savedLimitBeforeBoost = self.value
            self.boostChargeEnabled = true
            
            // Set limit to 100 and enable charging
            self.value = 100
            PersistanceManager.instance.chargeVal = 100
            PersistanceManager.instance.save()
            
            Helper.instance.enableCharging()
            print("BOOST CHARGE: Started - Saved limit \(self.savedLimitBeforeBoost)%, now charging to 100%")
        }
    }
    
    public func stopBoostCharge() {
        DispatchQueue.main.async {
            self.boostChargeEnabled = false
            
            // Restore the original limit
            self.value = self.savedLimitBeforeBoost
            PersistanceManager.instance.chargeVal = Int(self.savedLimitBeforeBoost)
            PersistanceManager.instance.save()
            
            print("BOOST CHARGE: Stopped - Restored limit to \(self.savedLimitBeforeBoost)%")
            
            // Re-evaluate charging based on restored limit
            if Helper.instance.isInitialized {
                Helper.instance.getChargingInfo { (Name, Capacity, IsCharging, MaxCapacity) in
                    let target = Int(self.value)
                    if Capacity >= target {
                        Helper.instance.disableCharging()
                        print("BOOST CHARGE OFF: Disabled charging - Capacity \(Capacity) >= Target \(target)")
                    }
                }
            }
        }
    }
    
    /// Get the effective target (100 if boost is active, otherwise the set limit)
    public var effectiveTarget: Int {
        return boostChargeEnabled ? 100 : Int(value)
    }

    func setValue(value: Float, isUserAction: Bool = true) {
        DispatchQueue.main.async {
            // If user manually changes the limit, turn off boost charge
            if isUserAction && self.boostChargeEnabled {
                self.boostChargeEnabled = false
                print("BOOST CHARGE: Auto-disabled due to manual limit change")
            }
            
            self.value = UInt8(value)
            PersistanceManager.instance.chargeVal = Int(value)
            PersistanceManager.instance.save()
            self.writeValue()
            
            // Immediately check and apply charge limiting
            if Helper.instance.isInitialized && !PersistanceManager.instance.oldKey {
                // If Manual Bypass is ON, keep charging disabled
                if self.bypassEnabled {
                    if !Helper.instance.chargeInhibited {
                        Helper.instance.disableCharging()
                    }
                    return
                }
                
                Helper.instance.getChargingInfo { (Name, Capacity, IsCharging, MaxCapacity) in
                    let target = Int(self.value)
                    if Capacity >= target {
                        // Battery is at or above target, disable charging
                        if !Helper.instance.chargeInhibited {
                            Helper.instance.disableCharging()
                            print("IMMEDIATE: Disabled charging - Capacity \(Capacity) >= Target \(target)")
                        }
                    } else {
                        // Battery is below target, enable charging
                        if Helper.instance.chargeInhibited {
                            Helper.instance.enableCharging()
                            print("IMMEDIATE: Enabled charging - Capacity \(Capacity) < Target \(target)")
                        }
                    }
                }
            }
        }
        timer?.invalidate()
        accuracyTimer?.invalidate()        
    }
    
    func writeValue(){
        if(PersistanceManager.instance.oldKey){
            print("should write bclm value: ", self.value)
            Helper.instance.writeMaxBatteryCharge(setVal: self.value)
        }
    }

}
