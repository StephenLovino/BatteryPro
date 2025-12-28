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
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .foregroundColor(.primary)
            .padding(10)
            .background(
                Circle()
                    .fill(Color(.controlBackgroundColor))
            )
            .overlay(
                Circle()
                    .stroke(Color(.separatorColor), lineWidth: 0.5)
            )
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// ... (Restoring Settings struct) ...

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
        .frame(width: 560, height: 400)
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
    @State private var isToppingUp = false

    @ObservedObject private var presenter = SMCPresenter.shared

    init() {
        Helper.instance.delegate = presenter
    }

    var body: some View {
        Group {
            if showSettings {
                Settings(showSettings: $showSettings)
                    .onAppear {
                        NotificationCenter.default.post(name: NSNotification.Name("UpdatePopoverSize"), object: nil, userInfo: ["width": 560, "height": 140])
                    }
            } else {
                VStack(spacing: 0) {
                    // Top button row
                    HStack(spacing: 6) {
                        // Limit Input (Editable)
                        HStack(spacing: 2) {
                            Text("Limit:")
                                .font(.system(size: 12, weight: .medium))
                                .fixedSize()
                            
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
                            
                            Text("%")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundColor(.white) // Active style
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(Theme.Colors.accent)
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
                        
                        // Top Up button
                        Button(action: {
                            isToppingUp.toggle()
                            if isToppingUp {
                                Helper.instance.enableCharging()
                                presenter.setValue(value: 100)
                            } else {
                                presenter.setValue(value: Float(presenter.value))
                            }
                        }) {
                            HStack(spacing: 4) {
                                Text("Boost Charge")
                                    .font(.system(size: 12, weight: .medium))
                                    .fixedSize()
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 12))
                            }
                        }
                        .buttonStyle(ModernButtonStyle(isActive: isToppingUp))
                        
                        Spacer()
                        
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
                                get: { Float(presenter.value) },
                                set: { newValue in
                                    if newValue >= 20 && newValue <= 100 {
                                        presenter.setValue(value: newValue)
                                    }
                                }
                            ),
                            in: 20...100
                        )
                        .accentColor(Theme.Colors.accent)
                        
                        Text("Set maximum charge limit")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 8)
                }
                .frame(width: 560, height: 110)
                .onAppear {
                    NotificationCenter.default.post(name: NSNotification.Name("UpdatePopoverSize"), object: nil, userInfo: ["width": 560, "height": 140])
                }
            }
        }
    }
}

// ... (Rest of file) ...

public final class SMCPresenter: ObservableObject, HelperDelegate {

    static let shared = SMCPresenter()

    @Published var value: UInt8 = 0
    @Published var bypassEnabled: Bool = false
    @Published var status: String = ""
    private var timer: Timer?
    private var accuracyTimer: Timer?

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

    func setValue(value: Float) {
        DispatchQueue.main.async {
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
