//
//  PerformanceControlView.swift
//  BatteryPro
//
//  Created for Performance Mode Control
//

import SwiftUI

struct PerformanceControlView: View {
    @State private var highPowerModeEnabled: Bool = false
    @State private var isLoading: Bool = true
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Performance Control")
                        .font(Theme.Fonts.header)
                        .foregroundColor(Theme.Colors.textPrimary)
                    
                    Text("Manually override system performance settings.")
                        .font(Theme.Fonts.body)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                
                // Toggle Card
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "speedometer")
                            .font(.system(size: 24))
                            .foregroundColor(Theme.Colors.accent)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("High Power Mode")
                                .font(Theme.Fonts.title)
                                .foregroundColor(Theme.Colors.textPrimary)
                            
                            Text("Maximize performance for sustained workloads.")
                                .font(Theme.Fonts.caption)
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: Binding(
                            get: { self.highPowerModeEnabled },
                            set: { newValue in
                                self.highPowerModeEnabled = newValue
                                Helper.instance.toggleHighPowerMode(enabled: newValue) { success in
                                    // Re-check state to confirm
                                    checkState()
                                }
                            }
                        ))
                        .toggleStyle(SwitchToggleStyle(tint: Theme.Colors.accent))
                        .disabled(isLoading)
                    }
                    
                    if isLoading {
                        Text("Checking status...")
                            .font(Theme.Fonts.caption)
                            .foregroundColor(Theme.Colors.textSecondary)
                    } else {
                        // Helpful note
                        Text("Note: This feature requires a supported Mac (e.g., MacBook Pro with M1/M2/M3 Max). On unsupported devices, this toggle has no effect. So it can't be toggled on")
                            .font(Theme.Fonts.caption)
                            .foregroundColor(Theme.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(24)
                .cardStyle()
                    
                    // Game Mode (Developer)
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "gamecontroller")
                                .font(.system(size: 24))
                                .foregroundColor(Color.purple)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Game Mode (Experimental)")
                                    .font(Theme.Fonts.title)
                                    .foregroundColor(Theme.Colors.textPrimary)
                                
                                Text("Force Game Mode on supported Macs.")
                                    .font(Theme.Fonts.caption)
                                    .foregroundColor(Theme.Colors.textSecondary)
                            }
                            
                            Spacer()
                        }
                        
                        Text("Note: This requires Xcode or Command Line Tools to be installed. It is not a built-in feature of BatteryPro.")
                            .font(Theme.Fonts.caption)
                            .foregroundColor(Theme.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Enable Game Mode:")
                                .font(Theme.Fonts.caption)
                                .foregroundColor(Theme.Colors.textSecondary)
                            
                            HStack {
                                Text("/Applications/Xcode.app/Contents/Developer/usr/bin/gamepolicyctl game-mode set on")
                                    .font(.system(.caption, design: .monospaced))
                                    .padding(8)
                                    .background(Theme.Colors.background)
                                    .cornerRadius(6)
                                    .lineLimit(1)
                                
                                Button(action: {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString("/Applications/Xcode.app/Contents/Developer/usr/bin/gamepolicyctl game-mode set on", forType: .string)
                                }) {
                                    Image(systemName: "doc.on.doc")
                                        .foregroundColor(Theme.Colors.textSecondary)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            
                            Text("Expected Output: \"Game mode enablement policy set to on.\"")
                                .font(Theme.Fonts.caption)
                                .foregroundColor(Theme.Colors.success)
                                .padding(.leading, 4)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Reset to Auto:")
                                .font(Theme.Fonts.caption)
                                .foregroundColor(Theme.Colors.textSecondary)
                            
                            HStack {
                                Text(".../gamepolicyctl game-mode set auto")
                                    .font(.system(.caption, design: .monospaced))
                                    .padding(8)
                                    .background(Theme.Colors.background)
                                    .cornerRadius(6)
                                    .lineLimit(1)
                                
                                Button(action: {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString("/Applications/Xcode.app/Contents/Developer/usr/bin/gamepolicyctl game-mode set auto", forType: .string)
                                }) {
                                    Image(systemName: "doc.on.doc")
                                        .foregroundColor(Theme.Colors.textSecondary)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            
                            Text("Expected Output: \"Game mode enablement policy set to auto.\"")
                                .font(Theme.Fonts.caption)
                                .foregroundColor(Theme.Colors.textSecondary)
                                .padding(.leading, 4)
                        }
                    }
                    .padding(24)
                    .cardStyle()
                    
                    Spacer()
                }
                .padding(32)
            }
            .onAppear {
                checkState()
            }
        }
    
    private func checkState() {
        isLoading = true
        Helper.instance.checkHighPowerMode { enabled in
            highPowerModeEnabled = enabled
            isLoading = false
        }
    }
}
