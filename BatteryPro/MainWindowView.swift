//
//  MainWindowView.swift
//  AlDente
//
//  Created for modern full window interface
//

import SwiftUI
import LaunchAtLogin
import IOKit.ps

// MARK: - Theme (Merged for Project Compatibility)
struct Theme {
    struct Colors {
        
        static func dynamicColor(light: String, dark: String) -> Color {
            return Color(NSColor(name: nil, dynamicProvider: { appearance in
                return appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? NSColor(hex: dark) : NSColor(hex: light)
            }))
        }
    
        // Adaptive Backgrounds
        static let background = dynamicColor(light: "F2F2F7", dark: "1C1C1E") // System Gray 6 (Light) vs Dark
        static let secondaryBackground = dynamicColor(light: "FFFFFF", dark: "2C2C2E") // White (Light) vs Dark Gray
        static let tertiaryBackground = dynamicColor(light: "E5E5EA", dark: "3A3A3C") // System Gray 5
        
        // Adaptive Text
        static let textPrimary = dynamicColor(light: "000000", dark: "FFFFFF") // Black vs White
        static let textSecondary = Color(hex: "8E8E93") // Gray is usually fine for both, or we can tweak
        
        static let accent = Color(hex: "00D2A6") // Vibrant Mint
        static let lockIcon = Color(hex: "8E8E93")
        static let success = Color.green
        static let warning = Color.orange
        static let danger = Color.red
        
        // Gradient for "Locked" cards or special effects
        static let cardGradient = LinearGradient(
            gradient: Gradient(colors: [
                dynamicColor(light: "FFFFFF", dark: "2C2C2E"),
                dynamicColor(light: "F2F2F7", dark: "3A3A3C")
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        // Card Styling
        // Card Styling
        // Updated to use the Accent color with low opacity for a branded feel, instead of the previous white which caused issues
        static let cardBorder = dynamicColor(light: "00D2A64D", dark: "00D2A64D") // Teal 30%
        static let cardShadow = dynamicColor(light: "0000001A", dark: "0000004D") // Black 10% vs Black 30%
    }
    
    struct Layout {
        static let cornerRadius: CGFloat = 16
        static let padding: CGFloat = 16
        static let sidebarWidth: CGFloat = 220
    }
    
    struct Fonts {
        static let header = Font.system(size: 24, weight: .bold, design: .default)
        static let title = Font.system(size: 20, weight: .bold, design: .default)
        static let subheadline = Font.system(size: 18, weight: .semibold, design: .default)
        static let body = Font.system(size: 14, weight: .regular, design: .default)
        static let caption = Font.system(size: 12, weight: .medium, design: .default)
        static let largeNumber = Font.system(size: 32, weight: .bold, design: .rounded)
    }
}

// Extension to allow Hex color initialization
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // RGBA (32-bit) - CHANGED FROM ARGB TO RGBA TO FIX COLOR PARSING
            (r, g, b, a) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// Extension to allow Hex color initialization for NSColor
extension NSColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // RGBA (32-bit) - CHANGED FROM ARGB TO RGBA TO FIX COLOR PARSING
            (r, g, b, a) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            srgbRed: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            alpha: Double(a) / 255
        )
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        visualEffectView.state = .active
        return visualEffectView
    }

    func updateNSView(_ visualEffectView: NSVisualEffectView, context: Context) {
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
    }
}

struct EmbossedDivider: View {
    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(Color.black.opacity(0.5))
                .frame(width: 1)
            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 1)
        }
        .frame(width: 2)
    }
}

struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Theme.Colors.secondaryBackground)
            .cornerRadius(Theme.Layout.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Layout.cornerRadius)
                    .stroke(Theme.Colors.cardBorder, lineWidth: 1)
            )
            .shadow(color: Theme.Colors.cardShadow, radius: 8, x: 0, y: 4)
    }
}

extension View {
    func cardStyle() -> some View {
        self.modifier(CardModifier())
    }
}

// MARK: - Main Structure
struct MainWindowView: View {
    @State private var selectedSection: NavigationSection = .dashboard
    @State private var onboardingIndex: Int = -1 // -1 means inactive
    
    var body: some View {
        ZStack {
            HStack(spacing: 0) {
            // Sidebar
            SidebarView(selectedSection: $selectedSection, activeOnboardingSection: onboardingIndex >= 0 ? onboardingSteps[onboardingIndex].section : nil)
                .frame(width: Theme.Layout.sidebarWidth)
                .background(
                    VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
                        .ignoresSafeArea(.all, edges: .top)
                )
                // Outline for the ScrollView area? No, outline for the whole sidebar
                .overlay(
                    Rectangle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        .ignoresSafeArea(.all, edges: .top)
                        .padding(.trailing, -1) // overlap or adjacent?
                )
                .ignoresSafeArea(.all, edges: .top)
            
            EmbossedDivider()
                .ignoresSafeArea()
            
            // Content
            ZStack {
                VisualEffectView(material: .windowBackground, blendingMode: .behindWindow)
                    .ignoresSafeArea()
                
                switch selectedSection {
                case .dashboard:
                    DashboardView()
                case .chargeControl, .sailingMode, .heatProtection, .calibration:
                    ChargeControlView()
                case .sleepBehavior:
                    SleepBehaviorView()
                case .energyUse:
                    EnergyUseView()
                case .schedule:
                    ScheduleView()
                case .shortcuts:
                    ShortcutsView()
                case .menubar:
                    MenubarView()
                case .popover:
                    PopoverView()
                case .other:
                    OtherView()
                case .settings:
                    SettingsView()
                default:
                    // Placeholder for any unmapped sections
                    VStack {
                        Text(selectedSection.rawValue)
                            .font(Theme.Fonts.header)
                            .foregroundColor(Theme.Colors.textPrimary)
                        Spacer()
                    }
                    .padding()
                }
            }
        } // End HStack
            
        // Onboarding Overlay
        if onboardingIndex >= 0 && onboardingIndex < onboardingSteps.count {
                OnboardingOverlay(
                    step: onboardingSteps[onboardingIndex],
                    totalSteps: onboardingSteps.count,
                    currentIndex: onboardingIndex,
                    onNext: {
                        if onboardingIndex < onboardingSteps.count - 1 {
                            onboardingIndex += 1
                            selectedSection = onboardingSteps[onboardingIndex].section
                        } else {
                            // Finish
                            onboardingIndex = -1
                            PersistanceManager.instance.hasCompletedOnboarding = true
                            PersistanceManager.instance.save()
                        }
                    },
                    onSkip: {
                        onboardingIndex = -1
                        PersistanceManager.instance.hasCompletedOnboarding = true
                        PersistanceManager.instance.save()
                    }
                )
            }
        }
        .frame(minWidth: 1000, minHeight: 650)
        .onAppear {
            // Check if onboarding needed
            if !PersistanceManager.instance.hasCompletedOnboarding {
                // Start onboarding after a slight delay to let UI settle
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.onboardingIndex = 0
                    self.selectedSection = onboardingSteps[0].section
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("StartOnboarding"))) { _ in
            self.onboardingIndex = 0
            self.selectedSection = onboardingSteps[0].section
        }
    }
}

// MARK: - Sidebar View
struct SidebarView: View {
    @Binding var selectedSection: NavigationSection
    var activeOnboardingSection: NavigationSection? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // macOS Traffic Lights spacing
            Color.clear.frame(height: 40)
            
            // Dashboard Button (Primary)
            Button(action: { selectedSection = .dashboard }) {
                HStack {
                    Image(systemName: "square.grid.2x2")
                    Text("Overview")
                        .fontWeight(.medium)
                    Spacer()
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(selectedSection == .dashboard ? Theme.Colors.accent : Color.clear)
                .foregroundColor(selectedSection == .dashboard ? .white : Theme.Colors.textSecondary)
                .cornerRadius(8)
                .opacity((activeOnboardingSection != nil && activeOnboardingSection != .dashboard) ? 0.3 : 1.0)
                .grayscale((activeOnboardingSection != nil && activeOnboardingSection != .dashboard) ? 1.0 : 0.0)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
            
            // Scrollable Menu Sections
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    
                    MenuGroup(title: "Battery Care", items: [
                        .chargeControl, .sleepBehavior, .energyUse
                    ], selected: $selectedSection, activeOnboardingSection: activeOnboardingSection)
                    
                    MenuGroup(title: "Automations", items: [
                        .schedule, .shortcuts
                    ], selected: $selectedSection, activeOnboardingSection: activeOnboardingSection)
                    
                    MenuGroup(title: "Appearance", items: [
                        .popover, .menubar, .other
                    ], selected: $selectedSection, activeOnboardingSection: activeOnboardingSection)
                    
                }
                .padding(.horizontal, 16)
            }
            
            Spacer()
            
            // Bottom Actions (Settings only)
            VStack(spacing: 12) {
                HStack {
                    Button(action: {
                        selectedSection = .settings
                    }) {
                        Image(systemName: "gearshape.circle")
                            .font(.system(size: 20))
                            .foregroundColor(selectedSection == .settings ? Theme.Colors.accent : Theme.Colors.textSecondary)
                    }
                    
                    Spacer()
                }
            }
            .padding(16)
        }
    }
}

struct MenuGroup: View {
    let title: String
    let items: [NavigationSection]
    @Binding var selected: NavigationSection
    var activeOnboardingSection: NavigationSection? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(Theme.Fonts.caption)
                .foregroundColor(Theme.Colors.textSecondary)
                .padding(.leading, 8)
            
            ForEach(items, id: \.self) { item in
                Button(action: { selected = item }) {
                    HStack(spacing: 12) {
                        Image(systemName: item.icon)
                            .frame(width: 16)
                            .font(.system(size: 14))
                        Text(item.rawValue)
                            .font(Theme.Fonts.body)
                        Spacer()
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .contentShape(Rectangle())
                    .background(selected == item ? Theme.Colors.accent : Color.clear)
                    .foregroundColor(selected == item ? .white : Theme.Colors.textSecondary)
                    .cornerRadius(6)
                    .opacity((activeOnboardingSection != nil && activeOnboardingSection != item) ? 0.3 : 1.0)
                    .grayscale((activeOnboardingSection != nil && activeOnboardingSection != item) ? 1.0 : 0.0)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

// MARK: - Dashboard View
struct DashboardView: View {
    // 3 Columns
    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    // Connect to Data
    @StateObject private var batteryInfo = BatteryInfo()
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                // -- Row 1 --
                // 1. Battery Specs
                DashboardWidget(title: "Battery Specs", icon: "bolt.fill") {
                    VStack(spacing: 8) {
                        LabelValueRow(label: "Manufacturer:", value: batteryInfo.manufacturer)
                        LabelValueRow(label: "Serial:", value: batteryInfo.serialNumber)
                        LabelValueRow(label: "Manufactured:", value: batteryInfo.manufactureDate)
                        LabelValueRow(label: "Voltage:", value: String(format: "%.2f V", batteryInfo.voltage))
                    }
                }
                
                // 2. Battery Health
                DashboardWidget(title: "Battery Health", icon: "heart.fill") {
                    VStack(spacing: 8) {
                        LabelValueRow(label: "Design Cap:", value: "\(batteryInfo.designCapacity) mAh")
                        LabelValueRow(label: "Max Cap:", value: "\(batteryInfo.maxCapacity) mAh")
                        LabelValueRow(label: "Cycles:", value: "\(batteryInfo.cycleCount)")
                        LabelValueRow(label: "Condition:", value: batteryInfo.condition, valueColor: batteryInfo.condition == "Normal" ? .green : .orange)
                    }
                }
                
                // 3. Power Adapter Specs
                DashboardWidget(title: "Adapter Specs", icon: "powerplug.fill") {
                    VStack(alignment: .leading, spacing: 8) {
                         Text(batteryInfo.adapterConnected ? "Connected" : "Not Connected")
                             .font(Theme.Fonts.body)
                             .fontWeight(.medium)
                             .foregroundColor(Theme.Colors.textPrimary)
                         
                         LabelValueRow(label: "Wattage:", value: "\(batteryInfo.adapterWattage)W")
                         LabelValueRow(label: "Connected:", value: batteryInfo.adapterConnected ? "Yes" : "No")
                         LabelValueRow(label: "Amperage:", value: String(format: "%.2f A", batteryInfo.amperage))
                    }
                }
                
                // -- Row 2 --
                // 4. Battery Level
                DashboardWidget(title: "Battery Level", icon: "battery.100") {
                    VStack(alignment: .leading, spacing: 4) {
                        let percentage = batteryInfo.maxCapacity > 0 ? Int((Double(batteryInfo.currentCapacity) / Double(batteryInfo.maxCapacity)) * 100) : 0
                        Text("\(percentage)%")
                            .font(Theme.Fonts.largeNumber)
                            .foregroundColor(Theme.Colors.textPrimary)
                        
                        Text(batteryInfo.isCharging ? "Full in: \(batteryInfo.timeRemaining)" : "Empty in: \(batteryInfo.timeRemaining)")
                            .font(Theme.Fonts.caption)
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                }
                
                // 5. Battery Cycles
                DashboardWidget(title: "Battery Cycles", icon: "arrow.triangle.2.circlepath") {
                     VStack(alignment: .leading) {
                        Text("\(batteryInfo.cycleCount) Cycles")
                            .font(Theme.Fonts.title)
                            .fontWeight(.bold)
                            .foregroundColor(Theme.Colors.textPrimary)
                     }
                      .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // 6. Power Flow
                DashboardWidget(title: "Power Flow", icon: "bolt.horizontal.fill") {
                     VStack(alignment: .leading, spacing: 4) {
                         Text("Battery")
                             .font(Theme.Fonts.subheadline)
                             .foregroundColor(Theme.Colors.textSecondary)
                         
                         Text(batteryInfo.isCharging ? "Charging" : (batteryInfo.adapterConnected ? "Plugged In" : "Discharging"))
                             .font(Theme.Fonts.title)
                             .fontWeight(.bold)
                             .foregroundColor(batteryInfo.isCharging ? Theme.Colors.success : (batteryInfo.adapterConnected ? Theme.Colors.textPrimary : Theme.Colors.warning))
                             .lineLimit(1)
                             .minimumScaleFactor(0.8)

                         Text("\(String(format: "%.1f", abs(batteryInfo.powerConsumption))) W")
                            .font(Theme.Fonts.caption)
                            .foregroundColor(Theme.Colors.textSecondary)
                     }
                }
                
                // -- Row 3 --
                // 7. Battery Temperature
                 DashboardWidget(title: "Temperature", icon: "thermometer") {
                     VStack(alignment: .leading) {
                          Text(String(format: "%.1f °C", batteryInfo.temperature))
                            .font(Theme.Fonts.largeNumber)
                            .foregroundColor(Theme.Colors.textPrimary)
                     }
                 }

                // 8. Power Consumption
                 DashboardWidget(title: "Consumption", icon: "bolt.circle") {
                      VStack(alignment: .leading) {
                          Text("\(String(format: "%.1f", batteryInfo.powerConsumption)) W")
                            .font(Theme.Fonts.largeNumber)
                            .foregroundColor(Theme.Colors.textPrimary)
                           Text("Time Remaining: --")
                            .font(Theme.Fonts.caption)
                            .foregroundColor(Theme.Colors.textSecondary)
                      }
                 }
                 
                // 9. Apps Using Energy
                DashboardWidget(title: "Apps Using Energy", icon: "app.badge") {
                     VStack(alignment: .leading, spacing: 6) {
                         if batteryInfo.significantEnergyApps.isEmpty {
                            Text("No apps using significant energy")
                                .font(Theme.Fonts.caption)
                                .foregroundColor(Theme.Colors.textSecondary)
                         } else {
                             ForEach(batteryInfo.significantEnergyApps.prefix(3), id: \.self) { app in
                                 HStack {
                                    Image(systemName: "app.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(Theme.Colors.textSecondary)
                                    Text(app)
                                        .font(Theme.Fonts.caption)
                                        .foregroundColor(Theme.Colors.textPrimary)
                                 }
                             }
                         }
                     }
                }
                 
            }
            .padding(24)
        }
        .onAppear {
            if Helper.instance.isInitialized {
                 batteryInfo.update()
            }
             Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
                if Helper.instance.isInitialized {
                    batteryInfo.update()
                }
            }
        }
    }
}

// MARK: - Reusable Widgets

struct DashboardWidget<Content: View>: View {
    let title: String
    let icon: String
    let accentColor: Color?
    let content: Content
    
    init(title: String, icon: String, accentColor: Color? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.accentColor = accentColor
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(accentColor ?? Theme.Colors.textPrimary)
                    .font(.system(size: 18))
                Text(title)
                    .font(Theme.Fonts.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.Colors.textPrimary)
                Spacer()
            }
            .padding(.bottom, 4)
            
            content
        }
        .padding(Theme.Layout.padding)
        .frame(height: 140)
        .frame(maxWidth: .infinity)
        .background(Theme.Colors.secondaryBackground)
        .cornerRadius(Theme.Layout.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Layout.cornerRadius)
                .stroke(Theme.Colors.cardBorder, lineWidth: 1)
        )
        .shadow(color: Theme.Colors.cardShadow, radius: 8, x: 0, y: 4)
    }
}

struct LabelValueRow: View {
    let label: String
    let value: String
    var valueColor: Color? = nil
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(Theme.Colors.textSecondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .foregroundColor(valueColor ?? Theme.Colors.textPrimary)
                .lineLimit(1)
        }
        .font(Theme.Fonts.caption)
    }
}

struct LockedWidget: View {
    let title: String
    let icon: String
    
    var body: some View {
        ZStack {
            // Blurred Background Content
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: icon)
                    Text(title)
                        .fontWeight(.semibold)
                    Spacer()
                }
                .foregroundColor(Theme.Colors.textSecondary)
                .blur(radius: 4)
                
                Spacer()
            }
            .padding(Theme.Layout.padding)
            
            // Lock Icon
            Image(systemName: "lock.fill")
                .font(.system(size: 24))
                .foregroundColor(Theme.Colors.lockIcon)
        }
        .frame(height: 140)
        .frame(maxWidth: .infinity)
        .background(Theme.Colors.secondaryBackground)
        .cornerRadius(Theme.Layout.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Layout.cornerRadius)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }
}

// MARK: - Reuse Existing Enums/Classes
// We keep NavigationSection and BatteryInfo from the previous file to avoid breaking references

enum NavigationSection: String, CaseIterable {
    case dashboard = "Overview"
    case chargeControl = "Limit Manager"
    case sailingMode = "Drift Mode"
    case heatProtection = "Heat Protection"
    case powerModes = "Power Modes"
    case calibration = "Recalibration"
    case sleepBehavior = "Sleep Mode"
    case energyUse = "Energy Monitor"
    case schedule = "Planner"
    case shortcuts = "Actions"
    case popover = "Mini Control"
    case menubar = "Menu Bar"
    case other = "General"
    case settings = "Settings"
    
    var icon: String {
        switch self {
        case .dashboard: return "square.grid.2x2"
        case .chargeControl: return "bolt.fill"
        case .sailingMode: return "sailboat.fill"
        case .heatProtection: return "thermometer.sun.fill"
        case .powerModes: return "bolt.circle.fill"
        case .calibration: return "arrow.triangle.2.circlepath"
        case .sleepBehavior: return "moon.fill"
        case .energyUse: return "leaf.fill"
        case .schedule: return "calendar"
        case .shortcuts: return "command.circle"
        case .popover: return "rectangle.on.rectangle"
        case .menubar: return "menubar.rectangle"
        case .other: return "cube.fill"
        case .settings: return "gearshape"
        }
    }
}


class BatteryInfo: ObservableObject {
    @Published var designCapacity: Int = 0
    @Published var maxCapacity: Int = 0
    @Published var currentCapacity: Int = 0
    @Published var cycleCount: Int = 0
    @Published var temperature: Double = 0
    @Published var isCharging: Bool = false
    @Published var timeRemaining: String = "--:--" // Changed to String for easy display
    @Published var powerConsumption: Double = 0
    @Published var condition: String = "Normal"
    
    // New Metrics for Unlocked Widgets
    @Published var manufacturer: String = "Apple"
    @Published var serialNumber: String = "Unknown"
    @Published var manufactureDate: String = "Unknown"
    @Published var voltage: Double = 0.0
    @Published var amperage: Double = 0.0
    @Published var adapterWattage: Int = 0
    @Published var adapterName: String = "Not Connected"
    @Published var adapterConnected: Bool = false
    @Published var significantEnergyApps: [String] = [] // Requires complex API, leaving empty for now
    
    func update() {
        guard Helper.instance.isInitialized else { return }
        
        // 1. Fetch Static Info from IOKit (for Strings)
        Helper.instance.getDetailedBatteryInfo { [weak self] iokitInfo in
            guard let self = self else { return }
            
            // 2. Fetch Live Stats from SMC (for accurate numbers)
            Helper.instance.getSMCBatteryInfo { smcInfo in
                DispatchQueue.main.async {
                    // Merge Data: Prefer SMC for numbers, IOKit for Strings
                    
                    // Capacity & Cycles (SMC Preferred)
                    self.currentCapacity = smcInfo["CurrentCapacity"] as? Int ?? iokitInfo["CurrentCapacity"] as? Int ?? 0
                    self.maxCapacity = smcInfo["MaxCapacity"] as? Int ?? iokitInfo["MaxCapacity"] as? Int ?? 100
                    self.designCapacity = smcInfo["DesignCapacity"] as? Int ?? iokitInfo["DesignCapacity"] as? Int ?? 100
                    self.cycleCount = smcInfo["CycleCount"] as? Int ?? iokitInfo["CycleCount"] as? Int ?? 0
                    
                    // Power Flow (SMC Preferred)
                    let mv = smcInfo["Voltage"] as? Double ?? iokitInfo["Voltage"] as? Double ?? 0
                    let ma = smcInfo["Amperage"] as? Double ?? iokitInfo["Amperage"] as? Double ?? 0
                    
                    self.voltage = mv // Already converted to V in Helper
                    self.amperage = ma // Already converted to A in Helper
                    
                    // Power Calc
                    self.powerConsumption = self.voltage * self.amperage
                    self.isCharging = self.amperage > 0
                    
                    // Time Remaining (IOKit only)
                    if let minutes = iokitInfo["TimeRemaining"] as? Int, minutes > 0 && minutes < 65535 {
                        let h = minutes / 60
                        let m = minutes % 60
                        self.timeRemaining = String(format: "%d h %02d m", h, m)
                    } else {
                        self.timeRemaining = "--:--"
                    }
                    
                    // Specs (IOKit Preferred)
                    self.manufacturer = iokitInfo["Manufacturer"] as? String ?? "Apple"
                    self.serialNumber = iokitInfo["Serial"] as? String ?? "Unknown"
                    
                    if let date = iokitInfo["ManufactureDate"] as? Date {
                        let formatter = DateFormatter()
                        formatter.dateStyle = .medium
                        self.manufactureDate = formatter.string(from: date)
                    }
                    
                    // Temperature (SMC Preferred)
                    self.temperature = smcInfo["Temperature"] as? Double ?? 0
                    
                // Adapter (Infer from power)
                let sourceState = iokitInfo["PowerSourceState"] as? String ?? "Unknown"
                if sourceState == "AC Power" || smcInfo["AdapterConnected"] as? Bool ?? false {
                     self.adapterConnected = true
                     self.adapterWattage = 60 // Placeholder or parse details if available
                     self.adapterName = "Power Adapter"
                } else {
                     self.adapterConnected = false
                     self.adapterWattage = 0
                     self.adapterName = "Not Connected"
                }
                
                // Refine Charging Status for UI
                // Logic: 
                // - Battery: Always "Discharging" (mostly)
                // - Adapter: "Charging" (Amps > 0) or "Not Charging" (Amps <= 0 / Inhibited)
                
                // We'll expose this via adapterConnected + isCharging flags in the View
                
                // Condition logic (Simple estimate)
                if self.maxCapacity > 0 && self.designCapacity > 0 {
                    let ratio = Double(self.maxCapacity) / Double(self.designCapacity)
                    if ratio > 0.8 { self.condition = "Good" }
                    else if ratio > 0.5 { self.condition = "Fair" }
                    else { self.condition = "Poor" }
                }

                // Apps Using Energy (High CPU processes)
                self.updateEnergyApps()
            }
        }
    }
}

    private func updateEnergyApps() {
        // Run ps command to find top CPU users
        // ps -Aceo %cpu,comm -r | head -n 5
        let task = Process()
        task.launchPath = "/bin/ps"
        task.arguments = ["-Aceo", "%cpu,comm", "-r"] // All, Command only, Sort by CPU
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readData(ofLength: 1024) // Fixed API Call
            if let output = String(data: data, encoding: .utf8) {
                let lines = output.components(separatedBy: .newlines)
                // First line is header "%CPU COMM"
                // Parse top 3
                var heavyApps: [String] = []
                for line in lines.dropFirst().prefix(10) { // Check top 10
                    let parts = line.trimmingCharacters(in: .whitespaces).components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                    if parts.count >= 2, let cpu = Double(parts[0]), cpu > 10.0 { // >10% CPU
                        let appName = parts.dropFirst().joined(separator: " ")
                        // Filter out system processes usually
                        if !["kernel_task", "WindowServer", "launchd"].contains(appName) {
                            heavyApps.append(appName)
                        }
                    }
                }
                
                // If heavy apps found, update
                if !heavyApps.isEmpty {
                    self.significantEnergyApps = Array(heavyApps.prefix(3))
                } else {
                    self.significantEnergyApps = []
                }
            }
        } catch {
            print("Failed to fetch energy apps: \(error)")
        }
    }
}


struct OtherView: View {
    @State private var appearanceMode = PersistanceManager.instance.appearanceMode
    @State private var ledSetting = "Always On"
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                
                // Header (No header in screenshot, just list items?)
                // Screenshot shows "Hardware Battery Percentage" at top.
                
                VStack(spacing: 0) {
                    // Hardware Battery Percentage
                    HStack {
                        Image(systemName: "gauge")
                            .foregroundColor(Theme.Colors.textSecondary)
                        Text("Hardware Battery Percentage")
                            .foregroundColor(Theme.Colors.textPrimary)
                        Image(systemName: "questionmark.circle")
                            .foregroundColor(Theme.Colors.textSecondary)
                            .font(.caption)
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { PersistanceManager.instance.hardwareBatteryPercentage },
                            set: { newValue in
                                PersistanceManager.instance.hardwareBatteryPercentage = newValue
                                PersistanceManager.instance.save()
                            }
                        ))
                        .labelsHidden()
                        .toggleStyle(SwitchToggleStyle(tint: Theme.Colors.accent))
                    }
                    .padding(Theme.Layout.padding)
                    
                    Divider().background(Theme.Colors.tertiaryBackground)
                    
                    // Show Dock Icon
                    HStack {
                        Image(systemName: "dock.rectangle")
                            .foregroundColor(Theme.Colors.textSecondary)
                        Text("Show Dock Icon")
                            .foregroundColor(Theme.Colors.textPrimary)
                        Image(systemName: "questionmark.circle")
                            .foregroundColor(Theme.Colors.textSecondary)
                            .font(.caption)
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { PersistanceManager.instance.showDockIcon },
                            set: { newValue in
                                PersistanceManager.instance.showDockIcon = newValue
                                PersistanceManager.instance.save()
                                // Notify AppDelegate to update dock icon immediately
                                NotificationCenter.default.post(name: NSNotification.Name("UpdateDockIconVisibility"), object: nil)
                            }
                        ))
                        .labelsHidden()
                        .toggleStyle(SwitchToggleStyle(tint: Theme.Colors.accent))
                    }
                    .padding(Theme.Layout.padding)
                    
                    Divider().background(Theme.Colors.tertiaryBackground)
                    
                    // Reduce Transparency
                    HStack {
                        Image(systemName: "drop")
                            .foregroundColor(Theme.Colors.textSecondary)
                        Text("Reduce Transparency")
                            .foregroundColor(Theme.Colors.textPrimary)
                        Image(systemName: "questionmark.circle")
                            .foregroundColor(Theme.Colors.textSecondary)
                            .font(.caption)
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { PersistanceManager.instance.reduceTransparency },
                            set: { newValue in
                                PersistanceManager.instance.reduceTransparency = newValue
                                PersistanceManager.instance.save()
                            }
                        ))
                        .labelsHidden()
                        .toggleStyle(SwitchToggleStyle(tint: Theme.Colors.accent))
                    }
                    .padding(Theme.Layout.padding)
                    
                    Divider().background(Theme.Colors.tertiaryBackground)
                    
                    // Appearance Mode
                    HStack {
                        Image(systemName: "circle.lefthalf.filled")
                            .foregroundColor(Theme.Colors.textSecondary)
                        Text("Appearance Mode")
                            .foregroundColor(Theme.Colors.textPrimary)
                        
                        Spacer()
                        
                        // Icons: System, Light, Dark
                        HStack(spacing: 16) {
                            // System
                            VStack(spacing: 4) {
                                Image(systemName: "circle.lefthalf.filled")
                                    .font(.title2)
                                    .foregroundColor(appearanceMode == 0 ? Theme.Colors.accent : Theme.Colors.textSecondary)
                                    .onTapGesture { 
                                        appearanceMode = 0 
                                        PersistanceManager.instance.appearanceMode = 0
                                        PersistanceManager.instance.save()
                                    }
                                Text("System")
                                    .font(.caption2)
                                    .foregroundColor(Theme.Colors.textSecondary)
                            }
                            
                            // Light
                            VStack(spacing: 4) {
                                Image(systemName: "circle")
                                    .font(.title2)
                                    .foregroundColor(appearanceMode == 1 ? Theme.Colors.accent : Theme.Colors.textSecondary)
                                    .onTapGesture { 
                                        appearanceMode = 1 
                                        PersistanceManager.instance.appearanceMode = 1
                                        PersistanceManager.instance.save()
                                    }
                                Text("") // Spacing
                                    .font(.caption2)
                            }
                            
                            // Dark
                            VStack(spacing: 4) {
                                Image(systemName: "circle.fill")
                                    .font(.title2)
                                    .foregroundColor(appearanceMode == 2 ? Theme.Colors.accent : Theme.Colors.textSecondary)
                                    .onTapGesture { 
                                        appearanceMode = 2 
                                        PersistanceManager.instance.appearanceMode = 2
                                        PersistanceManager.instance.save()
                                    }
                                Text("")
                                    .font(.caption2)
                            }
                        }
                    }
                    .padding(Theme.Layout.padding)
                    
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                
                // Magsafe LED
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "sun.max") // LED icon
                             .foregroundColor(Theme.Colors.textSecondary)
                        Text("Magsafe LED")
                            .font(Theme.Fonts.subheadline)
                            .foregroundColor(Theme.Colors.textPrimary)
                    }
                    
                    VStack(spacing: 0) {
                        // LED Setting
                        HStack {
                            Image(systemName: "lightbulb")
                                .foregroundColor(Theme.Colors.textSecondary)
                            Text("LED Setting")
                                .foregroundColor(Theme.Colors.textPrimary)
                            Spacer()
                            Picker("", selection: $ledSetting) {
                                Text("Always On").tag("Always On")
                                Text("Always Off").tag("Always Off")
                            }
                            .pickerStyle(MenuPickerStyle())
                            .frame(width: 120)
                        }
                        .padding(Theme.Layout.padding)
                        
                        Divider().background(Theme.Colors.tertiaryBackground)
                        
                        // Indicate Charge Limit
                        HStack {
                            Image(systemName: "slider.horizontal.3")
                                .foregroundColor(Theme.Colors.textSecondary)
                            Text("Indicate Charge Limit")
                                .foregroundColor(Theme.Colors.textPrimary)
                            Image(systemName: "questionmark.circle")
                                .foregroundColor(Theme.Colors.textSecondary)
                                .font(.caption)
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { PersistanceManager.instance.indicateChargeLimit },
                                set: { newValue in
                                    PersistanceManager.instance.indicateChargeLimit = newValue
                                    PersistanceManager.instance.save()
                                }
                            ))
                            .labelsHidden()
                            .toggleStyle(SwitchToggleStyle(tint: Theme.Colors.accent))
                        }
                        .padding(Theme.Layout.padding)
                        
                        Divider().background(Theme.Colors.tertiaryBackground)
                        
                        // Blink Orange during Discharge
                        HStack {
                            Image(systemName: "exclamationmark.circle")
                                .foregroundColor(Theme.Colors.textSecondary)
                            Text("Blink Orange during Discharge")
                                .foregroundColor(Theme.Colors.textPrimary)
                            Image(systemName: "questionmark.circle")
                                .foregroundColor(Theme.Colors.textSecondary)
                                .font(.caption)
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { PersistanceManager.instance.blinkOrangeDischarge },
                                set: { newValue in
                                    PersistanceManager.instance.blinkOrangeDischarge = newValue
                                    PersistanceManager.instance.save()
                                }
                            ))
                            .labelsHidden()
                            .toggleStyle(SwitchToggleStyle(tint: Theme.Colors.accent))
                        }
                        .padding(Theme.Layout.padding)
                    }
                    .cardStyle()
                }
                .padding(.horizontal, 24)
                
                Spacer()
            }
        }
    }
}

struct PopoverView: View {
    @State private var chargeLimit: Double = 68 // Matching screenshot
    
    var body: some View {
        ZStack {
            // Dark HUD Window Style
            VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
            Color.black.opacity(0.5) // Darker tint for contrast
            
            VStack(spacing: 16) {
                // Top Row
                HStack(spacing: 0) {
                    // Limit Button (Blue)
                    Button(action: {}) {
                        Text("Limit: \(Int(chargeLimit))%")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Theme.Colors.accent)
                            .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        // Discharge Button (Dark)
                        Button(action: {}) {
                            HStack(spacing: 6) {
                                Image(systemName: "minus.circle.fill") // Screenshot has solid circle icon? "minus.circle"
                                    .font(.system(size: 14))
                                Text("Discharge")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.4))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Boost Charge Button (Dark)
                        Button(action: {}) {
                            HStack(spacing: 6) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 14))
                                Text("Boost Charge")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.4))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Grid Icon (Circle Dark)
                        Button(action: {}) {
                            Image(systemName: "square.grid.2x2")
                                .font(.system(size: 15))
                                .foregroundColor(.white.opacity(0.8))
                                .frame(width: 32, height: 32)
                                .background(Color.black.opacity(0.4))
                                .clipShape(Circle())
                                .overlay(
                                    Circle().stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                // Slider Row
                VStack(spacing: 8) {
                    Slider(value: $chargeLimit, in: 20...100, step: 1)
                        .accentColor(Theme.Colors.accent)
                    
                    Text("Set maximum charge limit")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            }
            .padding(16)
        }
        .frame(width: 560, height: 140)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        // Center it in the preview area
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SettingsView: View {
    @State private var launchAtLogin: Bool
    @State private var checkAutomatically = false
    
    init() {
        PersistanceManager.instance.load()
        let savedValue = PersistanceManager.instance.launchOnLogin ?? LaunchAtLogin.isEnabled
        _launchAtLogin = State(initialValue: savedValue)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                
                // Quick Action
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "cloud")
                            .foregroundColor(Theme.Colors.textSecondary)
                        Text("Quick Action")
                            .font(Theme.Fonts.subheadline)
                            .foregroundColor(Theme.Colors.textPrimary)
                    }
                    
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            Button(action: {
                                NotificationCenter.default.post(name: NSNotification.Name("StartOnboarding"), object: nil)
                            }) {
                                Text("Onboarding")
                                    .font(.body)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Theme.Colors.tertiaryBackground)
                                    .foregroundColor(Theme.Colors.textPrimary)
                                    .cornerRadius(20)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Button(action: {}) {
                                Text("Save Debug File")
                                    .font(.body)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Theme.Colors.tertiaryBackground)
                                    .foregroundColor(Theme.Colors.textPrimary)
                                    .cornerRadius(20)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        HStack(spacing: 12) {
                            Button(action: {}) {
                                Text("Reset Settings")
                                    .font(.body)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Theme.Colors.tertiaryBackground)
                                    .foregroundColor(Theme.Colors.textPrimary)
                                    .cornerRadius(20)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Button(action: {}) {
                                Text("Remove BatteryPro")
                                    .font(.body)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Theme.Colors.tertiaryBackground)
                                    .foregroundColor(.red)
                                    .cornerRadius(20)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(Theme.Layout.padding)
                    .cardStyle()
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                
                // Manage License
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "checkmark.shield")
                            .foregroundColor(Theme.Colors.textSecondary)
                        Text("Manage License")
                            .font(Theme.Fonts.subheadline)
                            .foregroundColor(Theme.Colors.textPrimary)
                    }
                    
                    HStack {
                        Text("You are currently on the free version")
                            .font(.body)
                            .foregroundColor(Theme.Colors.textPrimary)
                        Spacer()
                        /*
                        Button(action: {
                             // Placeholder or removed
                        }) {
                            Text("Get BatteryPro Pro")
                                .font(.subheadline)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)
                                .background(Theme.Colors.tertiaryBackground)
                                .foregroundColor(Theme.Colors.textPrimary)
                                .cornerRadius(16)
                        }
                        .buttonStyle(PlainButtonStyle())
                        */
                    }
                    .padding(Theme.Layout.padding)
                    .cardStyle()
                }
                .padding(.horizontal, 24)
                
                // Other
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "gearshape") // "sun.max"? Screenshot icon is weird sun/gear
                             .foregroundColor(Theme.Colors.textSecondary)
                        Text("General")
                            .font(Theme.Fonts.subheadline)
                            .foregroundColor(Theme.Colors.textPrimary)
                    }
                    
                    VStack(spacing: 0) {
                        // Check for Updates Row
                        HStack {
                            Button(action: {}) {
                                Text("Check for Updates")
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 16)
                                    .background(Theme.Colors.tertiaryBackground)
                                    .cornerRadius(16)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Spacer()
                            
                            Text("Check Automatically")
                                .font(.body)
                                .foregroundColor(Theme.Colors.textPrimary)
                            
                            Toggle("", isOn: $checkAutomatically)
                                .labelsHidden()
                                .toggleStyle(SwitchToggleStyle(tint: Theme.Colors.accent))
                        }
                        .padding(Theme.Layout.padding)
                        
                        Divider().background(Theme.Colors.tertiaryBackground)
                        
                        // Launch at Login
                        HStack {
                            Image(systemName: "play")
                                .foregroundColor(Theme.Colors.textSecondary)
                            Text("Launch at Login")
                                .font(.body)
                                .foregroundColor(Theme.Colors.textPrimary)
                            Image(systemName: "questionmark.circle")
                                .foregroundColor(Theme.Colors.textSecondary)
                                .font(.caption)
                            
                            Spacer()
                            
                            Toggle("", isOn: Binding(
                                get: { launchAtLogin },
                                set: { newValue in
                                    launchAtLogin = newValue
                                    LaunchAtLogin.isEnabled = newValue
                                    PersistanceManager.instance.launchOnLogin = newValue
                                    PersistanceManager.instance.save()
                                }
                            ))
                            .labelsHidden()
                            .toggleStyle(SwitchToggleStyle(tint: Theme.Colors.accent))
                            
                            // Lock icon removed to unlock feature
                        }
                        .padding(Theme.Layout.padding)
                        
                        Divider().background(Theme.Colors.tertiaryBackground)
                        
                        // Share Technical Data
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "chart.bar")
                                    .foregroundColor(Theme.Colors.textSecondary)
                                Text("Share Technical Data")
                                    .font(.body)
                                    .foregroundColor(Theme.Colors.textPrimary)
                                Image(systemName: "questionmark.circle")
                                    .foregroundColor(Theme.Colors.textSecondary)
                                    .font(.caption)
                                Spacer()
                                // Lock icon removed
                            }
                            
                            Text("Opt in and help improve BatteryPro, fully reversible.")
                                .font(.caption)
                                .foregroundColor(Theme.Colors.textSecondary)
                                .padding(.leading, 24) // Indent to align with text
                        }
                        .padding(Theme.Layout.padding)
                    }
                    .cardStyle()
                }
                .padding(.horizontal, 24)
                
                Spacer()
                
                // Footer
                HStack {
                    Text("BatteryPro Free 1.36.2")
                        .font(.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                    Spacer()
                    Text("made with ♡ by Stephen")
                        .font(.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
        }
    }
}

// MARK: - Energy Use View
// MARK: - Energy Use View
// MARK: - Energy Use View
struct EnergyUseView: View {
    @State private var lowPowerMode = "Always Off"
    @State private var backgroundUpdates = false
    @State private var significantEnergyApps = "Medium Usage"
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                HStack {
                    Text("Energy Use")
                        .font(Theme.Fonts.header)
                        .foregroundColor(Theme.Colors.textPrimary)
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                
                VStack(spacing: 20) {
                    // Low Power Mode
                    HStack {
                        Image(systemName: "battery.50")
                            .foregroundColor(Theme.Colors.textSecondary)
                        Text("Low Power Mode")
                            .font(Theme.Fonts.body)
                            .fontWeight(.medium)
                            .foregroundColor(Theme.Colors.textPrimary)
                        Image(systemName: "questionmark.circle")
                            .foregroundColor(Theme.Colors.textSecondary)
                            .font(.caption)
                        Spacer()
                        
                        Picker("", selection: $lowPowerMode) {
                            Text("Always Off").tag("Always Off")
                            Text("Always On").tag("Always On")
                            Text("On Battery").tag("On Battery")
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(width: 120)
                    }
                    .padding(Theme.Layout.padding)
                    .cardStyle()
                    
                    // Background Dashboard Updates
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundColor(Theme.Colors.textSecondary)
                        Text("Background Dashboard Updates")
                            .font(Theme.Fonts.body)
                            .fontWeight(.medium)
                            .foregroundColor(Theme.Colors.textPrimary)
                        Image(systemName: "questionmark.circle")
                            .foregroundColor(Theme.Colors.textSecondary)
                            .font(.caption)
                        Spacer()
                        
                        Toggle("", isOn: $backgroundUpdates)
                            .labelsHidden()
                            .toggleStyle(SwitchToggleStyle(tint: Theme.Colors.accent))
                    }
                    .padding(Theme.Layout.padding)
                    .cardStyle()
                    
                    // Apps Using Significant Energy
                    HStack {
                        Image(systemName: "bolt.fill")
                            .foregroundColor(Theme.Colors.textSecondary)
                        Text("Apps Using Significant Energy")
                            .font(Theme.Fonts.body)
                            .fontWeight(.medium)
                            .foregroundColor(Theme.Colors.textPrimary)
                        
                        Image(systemName: "questionmark.circle")
                            .foregroundColor(Theme.Colors.textSecondary)
                            .font(.caption)
                        
                        Spacer()
                        
                        HStack {
                            Text("show above:")
                                .font(.caption)
                                .foregroundColor(Theme.Colors.textSecondary)
                            Picker("", selection: $significantEnergyApps) {
                                Text("Low Usage").tag("Low Usage")
                                Text("Medium Usage").tag("Medium Usage")
                                Text("High Usage").tag("High Usage")
                            }
                            .pickerStyle(MenuPickerStyle())
                            .frame(width: 140)
                        }
                    }
                    .padding(Theme.Layout.padding)
                    .cardStyle()
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - Schedule View
struct ScheduleView: View {
    @State private var startTasksNextOpp = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header & Action
                HStack {
                    Text("Tasks")
                        .font(Theme.Fonts.header)
                        .foregroundColor(Theme.Colors.textPrimary)
                    Image(systemName: "square.and.arrow.up")
                         .foregroundColor(Theme.Colors.textSecondary)
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                
                VStack(spacing: 20) {
                    // Tasks Card
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            // Empty list placeholder
                            Spacer()
                        }
                        .frame(height: 150)
                        .background(Theme.Colors.tertiaryBackground)
                        .cornerRadius(12)
                        
                        HStack {
                            Button(action: {}) {
                                Image(systemName: "plus.circle.fill")
                            }
                            .buttonStyle(PlainButtonStyle())
                            .foregroundColor(Theme.Colors.textSecondary)
                            
                            Spacer()
                            
                            Button(action: {}) {
                                HStack {
                                    Image(systemName: "trash")
                                    Text("Clear All")
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.red.opacity(0.2))
                                .foregroundColor(.red)
                                .cornerRadius(6)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(Theme.Layout.padding)
                    .cardStyle()
                    
                    // Start Tasks at next Opportunity
                    HStack {
                        Text("Start Tasks at next Opportunity:")
                             .font(Theme.Fonts.body)
                             .foregroundColor(Theme.Colors.textPrimary)
                        Spacer()
                        Toggle("", isOn: $startTasksNextOpp)
                            .labelsHidden()
                            .toggleStyle(SwitchToggleStyle(tint: Theme.Colors.accent))
                    }
                    .padding(.horizontal, 24)
                    
                    // Task History Header
                    HStack {
                        Image(systemName: "list.bullet.rectangle")
                            .foregroundColor(Theme.Colors.textSecondary)
                        Text("Task History")
                            .font(Theme.Fonts.subheadline)
                            .foregroundColor(Theme.Colors.textPrimary)
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    
                    // Task History Card
                    VStack(alignment: .leading, spacing: 12) {
                         HStack {
                            // Empty list placeholder
                            Spacer()
                        }
                        .frame(height: 100)
                        .background(Theme.Colors.tertiaryBackground)
                        .cornerRadius(12)
                        
                        Button(action: {}) {
                            HStack {
                                Image(systemName: "trash")
                                Text("Clear All Task History")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.red.opacity(0.2))
                            .foregroundColor(.red)
                            .cornerRadius(6)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(Theme.Layout.padding)
                    .cardStyle()
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - Legacy Views (Settings, Energy)
// Conserved for compatibility
struct WidgetView<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.secondary)
                Text(title)
                    .font(.headline)
                Spacer()
            }
            
            content
        }
        .padding(16)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
}


// MARK: - Charge Control View
// MARK: - Charge Control View
struct ChargeControlView: View {
    @ObservedObject private var presenter = SMCPresenter.shared
    @State private var dischargeEnabled = false // Automatic Discharge (placeholder)
    @State private var sailingModeEnabled: Bool
    @State private var heatProtectionEnabled: Bool
    @State private var calibrationEnabled: Bool
    
    init() {
        _sailingModeEnabled = State(initialValue: PersistanceManager.instance.sailingModeEnabled)
        _heatProtectionEnabled = State(initialValue: PersistanceManager.instance.heatProtectionEnabled)
        _calibrationEnabled = State(initialValue: PersistanceManager.instance.calibrationModeEnabled)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                HStack {
                    Text("Limit Manager")
                        .font(Theme.Fonts.header)
                        .foregroundColor(Theme.Colors.textPrimary)
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                
                VStack(spacing: 20) {
                    // 1. Charge Limit
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "battery.100")
                                .foregroundColor(Theme.Colors.textSecondary)
                            Text("Charge Limit")
                                .font(Theme.Fonts.body)
                                .fontWeight(.medium)
                                .foregroundColor(Theme.Colors.textPrimary)
                            Image(systemName: "questionmark.circle")
                                .foregroundColor(Theme.Colors.textSecondary)
                                .font(.caption)
                            Spacer()
                            
                            HStack(spacing: 4) {
                                TextField("80", text: Binding(
                                    get: { String(Int(presenter.value)) },
                                    set: { newValue in
                                        if let val = Int(newValue), val >= 20 && val <= 100 {
                                            presenter.setValue(value: Float(val))
                                        }
                                    }
                                ))
                                .multilineTextAlignment(.trailing)
                                .font(Theme.Fonts.body)
                                .foregroundColor(Theme.Colors.textPrimary)
                                .frame(width: 30)
                                .textFieldStyle(PlainTextFieldStyle())

                                Text("%")
                                    .font(Theme.Fonts.body)
                                    .foregroundColor(Theme.Colors.textSecondary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Theme.Colors.tertiaryBackground)
                            .cornerRadius(6)
                        }
                        
                        Slider(value: Binding(
                            get: { Float(presenter.value) },
                            set: { newValue in presenter.setValue(value: newValue) }
                        ), in: 20...100, step: 1)
                        .accentColor(Theme.Colors.accent)
                    }
                    .padding(Theme.Layout.padding)
                    .cardStyle()
                    
                    // 1.5 Manual Bypass (New)
                    HStack {
                         Image(systemName: "powerplug.fill")
                             .foregroundColor(Theme.Colors.textSecondary)
                         Text("Manual Bypass")
                              .font(Theme.Fonts.body)
                              .fontWeight(.medium)
                              .foregroundColor(Theme.Colors.textPrimary)
                         
                         Spacer()
                         
                         Toggle("", isOn: Binding(
                             get: { presenter.bypassEnabled },
                             set: { val in presenter.setBypass(enabled: val) }
                         ))
                         .labelsHidden()
                         .toggleStyle(SwitchToggleStyle(tint: Theme.Colors.accent))
                    }
                    .padding(Theme.Layout.padding)
                    .cardStyle()
                    
                    // 2. Automatic Discharge (Unlocked)
                    HStack {
                        Image(systemName: "bolt.badge.automatic.fill")
                            .foregroundColor(Theme.Colors.textSecondary)
                        Text("Automatic Discharge")
                             .font(Theme.Fonts.body)
                             .fontWeight(.medium)
                             .foregroundColor(Theme.Colors.textPrimary)
                        Image(systemName: "questionmark.circle")
                            .foregroundColor(Theme.Colors.textSecondary)
                            .font(.caption)
                        Spacer()
                        
                        Toggle("", isOn: $dischargeEnabled)
                            .labelsHidden()
                            .toggleStyle(SwitchToggleStyle(tint: Theme.Colors.accent))
                    }
                    .padding(Theme.Layout.padding)
                    .cardStyle()
                    
                    // 3. Drift Mode
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Image(systemName: "sailboat.fill")
                                .foregroundColor(Theme.Colors.textSecondary)
                            Text("Drift Mode")
                                .font(Theme.Fonts.body)
                                .fontWeight(.medium)
                                .foregroundColor(Theme.Colors.textPrimary)
                            Image(systemName: "questionmark.circle")
                                .foregroundColor(Theme.Colors.textSecondary)
                                .font(.caption)
                            Spacer()
                            
                            Toggle("", isOn: $sailingModeEnabled)
                                .labelsHidden()
                                .toggleStyle(SwitchToggleStyle(tint: Theme.Colors.accent))
                        }
                        .padding(Theme.Layout.padding)
                        
                        Divider().background(Theme.Colors.tertiaryBackground)
                        
                        // Status/Desc
                        HStack {
                            Text(sailingModeEnabled ? "Drift Mode is active." : "Drift Mode deactivated.")
                                .font(.caption)
                                .foregroundColor(Theme.Colors.textSecondary)
                            Spacer()
                        }
                        .padding(Theme.Layout.padding)
                        .background(Theme.Colors.tertiaryBackground.opacity(0.5))
                    }
                    .cardStyle()
                    
                    // 4. Thermal Guard
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Image(systemName: "flame.fill") // thermometer.sun.fill?
                                .foregroundColor(Theme.Colors.textSecondary)
                            Text("Thermal Guard")
                                .font(Theme.Fonts.body)
                                .fontWeight(.medium)
                                .foregroundColor(Theme.Colors.textPrimary)
                            Image(systemName: "questionmark.circle")
                                .foregroundColor(Theme.Colors.textSecondary)
                                .font(.caption)
                            Spacer()
                            
                            Toggle("", isOn: $heatProtectionEnabled)
                                .labelsHidden()
                                .toggleStyle(SwitchToggleStyle(tint: Theme.Colors.accent))
                        }
                        .padding(Theme.Layout.padding)
                        
                        Divider().background(Theme.Colors.tertiaryBackground)
                        
                        // Status
                        HStack {
                            Text(heatProtectionEnabled ? "Thermal Guard is monitoring." : "Thermal Guard deactivated.")
                                .font(.caption)
                                .foregroundColor(Theme.Colors.textSecondary)
                            Spacer()
                        }
                        .padding(Theme.Layout.padding)
                        .background(Theme.Colors.tertiaryBackground.opacity(0.5))
                    }
                    .cardStyle()
                    
                    // 5. Calibration Mode (Unlocked)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "slider.horizontal.3")
                                .foregroundColor(Theme.Colors.textSecondary)
                            Text("Calibration Mode")
                                 .font(Theme.Fonts.body)
                                 .fontWeight(.medium)
                                 .foregroundColor(Theme.Colors.textPrimary)
                            Image(systemName: "questionmark.circle")
                                .foregroundColor(Theme.Colors.textSecondary)
                                .font(.caption)
                            Spacer()
                            
                            Button(action: {
                                // Start Calibration Logic
                                calibrationEnabled.toggle()
                            }) {
                                HStack {
                                    Image(systemName: "play.fill")
                                        .font(.caption)
                                    Text(calibrationEnabled ? "Stop Calibration" : "Start Calibration")
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                                .background(Theme.Colors.tertiaryBackground)
                                .foregroundColor(Theme.Colors.textSecondary)
                                .cornerRadius(6)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        // Calibration Steps Visualization
                        HStack(spacing: 0) {
                            CalibrationStep(icon: "battery.100", label: "Charge to\n100%", active: true)
                            ArrowView()
                            CalibrationStep(icon: "battery.0", label: "Discharge\nto 10%", active: false)
                            ArrowView()
                            CalibrationStep(icon: "battery.100", label: "Charge to\n100%", active: false)
                            ArrowView()
                            CalibrationStep(icon: "pause.rectangle", label: "Hold for\n1h", active: false)
                            ArrowView()
                            CalibrationStep(icon: "battery.75", label: "Discharge\nto 88%", active: false)
                        }
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(Theme.Colors.tertiaryBackground)
                        .cornerRadius(12)
                        
                        HStack {
                            Spacer()
                            Text("Last Calibration: -")
                                .font(.caption)
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                    }
                    .padding(Theme.Layout.padding)
                    .cardStyle()
                    
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }
}

// Helper Views for Calibration
struct CalibrationStep: View {
    let icon: String
    let label: String
    let active: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(active ? .green : Theme.Colors.textSecondary)
            Text(label)
                .font(.system(size: 10))
                .multilineTextAlignment(.center)
                .foregroundColor(Theme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ArrowView: View {
    var body: some View {
        Image(systemName: "arrow.right")
            .font(.system(size: 10))
            .foregroundColor(Theme.Colors.textSecondary)
            .frame(width: 20)
    }
}


// MARK: - Sailing Mode View
struct SailingModeView: View {
    @State private var sailingModeEnabled: Bool
    @State private var sailingModeTarget: Int
    @StateObject private var batteryInfo = BatteryInfo()
    
    init() {
        PersistanceManager.instance.load()
        _sailingModeEnabled = State(initialValue: PersistanceManager.instance.sailingModeEnabled)
        _sailingModeTarget = State(initialValue: PersistanceManager.instance.sailingModeTarget)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(NSLocalizedString("lblSailingMode", comment: "Drift Mode"))
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                
                VStack(alignment: .leading, spacing: 16) {
                    WidgetView(title: "Drift Mode", icon: "sailboat.fill") {
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle(isOn: Binding(
                                get: { sailingModeEnabled },
                                set: { newValue in
                                    sailingModeEnabled = newValue
                                    PersistanceManager.instance.sailingModeEnabled = newValue
                                    PersistanceManager.instance.save()
                                    if newValue {
                                        // Start drift mode - discharge to target
                                        Helper.instance.disableCharging()
                                    } else {
                                        // Stop drift mode
                                        Helper.instance.enableCharging()
                                    }
                                }
                            )) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(NSLocalizedString("txtEnabled", comment: "Enabled"))
                                        .font(.body)
                                        .fontWeight(.medium)
                                    Text(NSLocalizedString("hlpSailingModeSettings", comment: "Drift Mode help text"))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            if sailingModeEnabled {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("\(NSLocalizedString("lblSailingLevel", comment: "Drift Level")): \(sailingModeTarget)\(NSLocalizedString("txtPercentage", comment: "%"))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Slider(
                                        value: Binding(
                                            get: { Double(sailingModeTarget) },
                                            set: { newValue in
                                                sailingModeTarget = Int(newValue)
                                                PersistanceManager.instance.sailingModeTarget = sailingModeTarget
                                                PersistanceManager.instance.save()
                                            }
                                        ),
                                        in: 20...100
                                    )
                                    
                                    Text("\(NSLocalizedString("txtCurrent", comment: "Current")): \(batteryInfo.currentCapacity)\(NSLocalizedString("txtPercentage", comment: "%"))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    if batteryInfo.currentCapacity > sailingModeTarget {
                                        HStack {
                                            Image(systemName: "arrow.down.circle.fill")
                                                .foregroundColor(.orange)
                                            Text("\(NSLocalizedString("txtDischarge", comment: "Discharge")) \(NSLocalizedString("txtWillSailTo", comment: "Will drift to"))\(sailingModeTarget)\(NSLocalizedString("txtPercentage", comment: "%"))")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    } else if batteryInfo.currentCapacity <= sailingModeTarget {
                                        HStack {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green)
                                            Text(NSLocalizedString("txtSailingModeDeactivated", comment: "Drift Mode deactivated"))
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.windowBackgroundColor))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if Helper.instance.isInitialized {
                    batteryInfo.update()
                }
            }
            Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
                if Helper.instance.isInitialized {
                    batteryInfo.update()
                }
            }
        }
    }
}

// MARK: - Heat Protection View
struct HeatProtectionView: View {
    @State private var heatProtectionEnabled: Bool
    @State private var heatProtectionMaxTemp: Double
    @StateObject private var batteryInfo = BatteryInfo()
    
    init() {
        PersistanceManager.instance.load()
        _heatProtectionEnabled = State(initialValue: PersistanceManager.instance.heatProtectionEnabled)
        _heatProtectionMaxTemp = State(initialValue: PersistanceManager.instance.heatProtectionMaxTemp)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(NSLocalizedString("lblHeatProtection", comment: "Thermal Guard"))
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                
                VStack(alignment: .leading, spacing: 16) {
                    WidgetView(title: "Thermal Guard", icon: "flame.fill") {
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle(isOn: Binding(
                                get: { heatProtectionEnabled },
                                set: { newValue in
                                    heatProtectionEnabled = newValue
                                    PersistanceManager.instance.heatProtectionEnabled = newValue
                                    PersistanceManager.instance.save()
                                }
                            )) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(NSLocalizedString("lblHeatProtection", comment: "Thermal Guard"))
                                        .font(.body)
                                        .fontWeight(.medium)
                                    Text(NSLocalizedString("hlpHeatProtectionSettings", comment: "Thermal Guard help text"))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            if heatProtectionEnabled {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("\(NSLocalizedString("txtMaxTemp", comment: "Max. Temp")): \(Int(heatProtectionMaxTemp))\(NSLocalizedString("txtCelsius", comment: "°C"))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Slider(
                                        value: Binding(
                                            get: { heatProtectionMaxTemp },
                                            set: { newValue in
                                                heatProtectionMaxTemp = newValue
                                                PersistanceManager.instance.heatProtectionMaxTemp = newValue
                                                PersistanceManager.instance.save()
                                            }
                                        ),
                                        in: 30...50
                                    )
                                    
                                    HStack {
                                        Text("\(NSLocalizedString("txtCurrent", comment: "Current")):")
                                            .foregroundColor(.secondary)
                                        Text("\(String(format: "%.1f", batteryInfo.temperature))\(NSLocalizedString("txtCelsius", comment: "°C"))")
                                            .fontWeight(.medium)
                                            .foregroundColor(batteryInfo.temperature > heatProtectionMaxTemp ? .red : .primary)
                                    }
                                    .font(.caption)
                                    
                                    if batteryInfo.temperature > heatProtectionMaxTemp {
                                        HStack {
                                            Image(systemName: "exclamationmark.triangle.fill")
                                                .foregroundColor(.red)
                                            Text("\(NSLocalizedString("hlpHeatProtectionPopover", comment: "Thermal Guard message"))\(String(format: "%.1f", batteryInfo.temperature))\(NSLocalizedString("txtCelsius", comment: "°C"))")
                                                .font(.caption)
                                                .foregroundColor(.red)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.windowBackgroundColor))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if Helper.instance.isInitialized {
                    batteryInfo.update()
                }
            }
            Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
                if Helper.instance.isInitialized {
                    batteryInfo.update()
                }
            }
        }
    }
}

// MARK: - Power Modes View
struct PowerModesView: View {
    @State private var powerMode: String
    
    init() {
        PersistanceManager.instance.load()
        _powerMode = State(initialValue: PersistanceManager.instance.powerMode)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Power Modes")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                
                VStack(alignment: .leading, spacing: 16) {
                    WidgetView(title: "Power Mode", icon: "bolt.circle.fill") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Select Power Mode")
                                .font(.body)
                                .fontWeight(.medium)
                            
                            VStack(spacing: 8) {
                                PowerModeButton(
                                    title: "Normal",
                                    description: "Balanced performance and battery life",
                                    icon: "bolt.fill",
                                    isSelected: powerMode == "normal",
                                    action: {
                                        powerMode = "normal"
                                        PersistanceManager.instance.powerMode = powerMode
                                        PersistanceManager.instance.save()
                                        Helper.instance.toggleLowPowerMode(enabled: false) { success in
                                            if !success {
                                                // Revert if failed?
                                                print("Failed to disable Low Power Mode")
                                            }
                                        }
                                    }
                                )
                                
                                PowerModeButton(
                                    title: "Low Power",
                                    description: "Reduce system performance to save battery",
                                    icon: "battery.25",
                                    isSelected: powerMode == "low",
                                    action: {
                                        powerMode = "low"
                                        PersistanceManager.instance.powerMode = powerMode
                                        PersistanceManager.instance.save()
                                        Helper.instance.toggleLowPowerMode(enabled: true) { success in
                                            if !success {
                                                print("Failed to enable Low Power Mode")
                                            }
                                        }
                                    }
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.windowBackgroundColor))
        .onAppear {
            // Sync with system state
            Helper.instance.checkLowPowerMode { isEnabled in
                self.powerMode = isEnabled ? "low" : "normal"
            }
        }
    }
}

struct PowerModeButton: View {
    let title: String
    let description: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : .secondary)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(isSelected ? .white : .primary)
                    Text(description)
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                }
            }
            .padding(12)
            .background(isSelected ? Color.accentColor : Color(.controlBackgroundColor))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Calibration View
struct CalibrationView: View {
    @State private var calibrationModeEnabled: Bool
    @State private var isCalibrating = false
    @State private var calibrationProgress: Double = 0.0
    
    init() {
        PersistanceManager.instance.load()
        _calibrationModeEnabled = State(initialValue: PersistanceManager.instance.calibrationModeEnabled)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(NSLocalizedString("lblCalibrationMode", comment: "Recalibration"))
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                
                VStack(alignment: .leading, spacing: 16) {
                    WidgetView(title: "Battery Recalibration", icon: "arrow.triangle.2.circlepath") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(NSLocalizedString("hlpCalibration", comment: "Recalibration help text"))
                                .font(.body)
                                .foregroundColor(.secondary)
                            
                            if isCalibrating {
                                VStack(alignment: .leading, spacing: 8) {
                                    ProgressView(value: calibrationProgress)
                                    Text("Recalibration in progress...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            } else {
                                Button(action: {
                                    startCalibration()
                                }) {
                                    HStack {
                                        Image(systemName: "arrow.triangle.2.circlepath")
                                        Text(NSLocalizedString("btnStartCalibration", comment: "Start Recalibration"))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(Color.accentColor)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            
                            Text("Note: Recalibration will discharge and recharge your battery. This process may take several hours.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, 8)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.windowBackgroundColor))
    }
    
    private func startCalibration() {
        isCalibrating = true
        calibrationProgress = 0.0
        PersistanceManager.instance.calibrationModeEnabled = true
        PersistanceManager.instance.save()
        Helper.instance.startCalibration()
        
        // Simulate calibration progress (in real implementation, this would be driven by actual calibration events)
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            calibrationProgress += 0.01
            if calibrationProgress >= 1.0 {
                timer.invalidate()
                isCalibrating = false
                calibrationProgress = 0.0
                PersistanceManager.instance.calibrationModeEnabled = false
                PersistanceManager.instance.save()
            }
        }
    }
}






// MARK: - Sleep Behavior View
struct SleepBehaviorView: View {
    @State private var disableSleepUntilLimit = false
    @State private var stopChargingWhenSleeping = false
    @State private var stopChargingAppClosed = false
    @State private var turnDisplayOff = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                HStack {
                    Text("Sleep Mode")
                        .font(Theme.Fonts.header)
                        .foregroundColor(Theme.Colors.textPrimary)
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                
                VStack(spacing: 20) {
                    // Disable Sleep Card
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "powersleep")
                                .foregroundColor(Theme.Colors.textSecondary)
                            Text("Disable Sleep")
                                .font(Theme.Fonts.body)
                                .fontWeight(.medium)
                                .foregroundColor(Theme.Colors.textPrimary)
                            Spacer()
                        }
                        
                        Text("BatteryPro deactivates Sleep in the following scenarios:")
                            .font(.caption)
                            .foregroundColor(Theme.Colors.textSecondary)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "slider.horizontal.3")
                                    .frame(width: 20)
                                Text("During Calibration Mode (necessary)")
                            }
                            HStack {
                                Image(systemName: "minus.circle")
                                    .frame(width: 20)
                                Text("During Discharge in Clamshell Mode (necessary)")
                            }
                            HStack {
                                Image(systemName: "bed.double.fill")
                                    .frame(width: 20)
                                Text("Disable Sleep until Charge Limit (optional)")
                                Spacer()
                                Toggle("", isOn: $disableSleepUntilLimit)
                                    .labelsHidden()
                                    .toggleStyle(SwitchToggleStyle(tint: Theme.Colors.accent))
                            }
                        }
                        .font(.body)
                        .foregroundColor(Theme.Colors.textPrimary)
                        
                        Divider()
                            .background(Theme.Colors.tertiaryBackground)
                        
                        Text("Lock Screen Settings while BatteryPro disables Sleep")
                            .font(.caption)
                            .foregroundColor(Theme.Colors.textSecondary)
                        
                        HStack {
                            Image(systemName: "display")
                                .foregroundColor(Theme.Colors.textSecondary)
                            Text("Turn display off when inactive")
                                .font(.body)
                                .foregroundColor(Theme.Colors.textPrimary)
                            Spacer()
                            // Mock Picker style
                            Text("Mirror macOS")
                                .font(.body)
                                .foregroundColor(Theme.Colors.textSecondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Theme.Colors.tertiaryBackground)
                                .cornerRadius(6)
                        }
                    }
                    .padding(Theme.Layout.padding)
                    .cardStyle()
                    
                    // Stop Charging When Sleeping
                    HStack {
                        Image(systemName: "moon.fill")
                            .foregroundColor(Theme.Colors.textSecondary)
                        Text("Stop charging when sleeping")
                            .font(Theme.Fonts.body)
                            .fontWeight(.medium)
                            .foregroundColor(Theme.Colors.textPrimary)
                        Image(systemName: "questionmark.circle")
                            .foregroundColor(Theme.Colors.textSecondary)
                            .font(.caption)
                        Spacer()
                        
                        Toggle("", isOn: $stopChargingWhenSleeping)
                            .labelsHidden()
                            .toggleStyle(SwitchToggleStyle(tint: Theme.Colors.accent))
                    }
                    .padding(Theme.Layout.padding)
                    .cardStyle()
                    
                    // Stop Charging When App Closed
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Theme.Colors.textSecondary)
                        Text("Stop charging when app closed")
                            .font(Theme.Fonts.body)
                            .fontWeight(.medium)
                            .foregroundColor(Theme.Colors.textPrimary)
                        Image(systemName: "questionmark.circle")
                            .foregroundColor(Theme.Colors.textSecondary)
                            .font(.caption)
                        Spacer()
                        
                        Toggle("", isOn: $stopChargingAppClosed)
                            .labelsHidden()
                            .toggleStyle(SwitchToggleStyle(tint: Theme.Colors.accent))
                    }
                    .padding(Theme.Layout.padding)
                    .cardStyle()
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - Shortcuts View
struct ShortcutsView: View {
    struct ShortcutItem: Identifiable {
        let id = UUID()
        let name: String
        let description: String
    }
    
    let shortcuts = [
        ShortcutItem(name: "Boost Charge", description: "Sets the charge limit to 100% and starts charging."),
        ShortcutItem(name: "Pause Charging", description: "Pauses charging by setting the charge limit to the current battery percentage."),
        ShortcutItem(name: "Start Discharge", description: "Begins discharging the battery to the set charge limit."),
        ShortcutItem(name: "Start Recalibration", description: "Initiates the recalibration process to recalibrate the battery."),
        ShortcutItem(name: "Set Charge Limit", description: "Sets a specific charge limit percentage."),
        ShortcutItem(name: "Get Battery Percentage", description: "Returns the current battery percentage."),
        ShortcutItem(name: "Get Charge Limit", description: "Returns the current charge limit set in BatteryPro.")
    ]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                HStack {
                    Image(systemName: "square.stack.3d.up.fill")
                        .foregroundColor(Theme.Colors.textSecondary)
                    Text("Available Apple Shortcuts")
                        .font(Theme.Fonts.header)
                        .foregroundColor(Theme.Colors.textPrimary)
                    Image(systemName: "questionmark.circle")
                        .foregroundColor(Theme.Colors.textSecondary)
                        .font(.caption)
                    Spacer()
                    
                    Button(action: {}) {
                        Text("Open Shortcuts App")
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Theme.Colors.tertiaryBackground)
                            .foregroundColor(Theme.Colors.textPrimary)
                            .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                
                // Shortcuts List Card
                VStack(spacing: 0) {
                    ForEach(shortcuts) { shortcut in
                        HStack(alignment: .top, spacing: 16) {
                            Text(shortcut.name)
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundColor(Theme.Colors.textPrimary)
                                .frame(width: 160, alignment: .leading)
                            
                            Text(shortcut.description)
                                .font(.body)
                                .foregroundColor(Theme.Colors.textSecondary)
                            Spacer()
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        
                        if shortcut.id != shortcuts.last?.id {
                            Divider()
                                .background(Theme.Colors.tertiaryBackground)
                        }
                    }
                }
                .background(Theme.Colors.secondaryBackground)
                .cornerRadius(12)
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - Menubar View
struct MenubarView: View {
    @State private var itemSpacing: Double = 0
    @State private var updateInterval: Double = 2
    @State private var rightClickAction = "Like Left Click"
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Selected Items
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "menubar.rectangle")
                            .foregroundColor(Theme.Colors.textSecondary)
                        Text("Selected Menubar Items")
                             .font(Theme.Fonts.subheadline)
                             .foregroundColor(Theme.Colors.textPrimary)
                        Image(systemName: "questionmark.circle")
                             .foregroundColor(Theme.Colors.textSecondary)
                             .font(.caption)
                    }
                    
                    HStack {
                        // Icon placeholder for "Show"
                        Image(systemName: "bolt.ring.closed")
                           .font(.title2)
                           .foregroundColor(Theme.Colors.textPrimary)
                           .padding(12)
                           .background(Theme.Colors.tertiaryBackground)
                           .cornerRadius(8)
                    }
                    .padding(Theme.Layout.padding)
                    .cardStyle()
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                
                // Catalog (Blurred/Locked)
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "book.closed")
                           .foregroundColor(Theme.Colors.textSecondary)
                        Text("Menubar Items Catalog")
                             .font(Theme.Fonts.subheadline)
                             .foregroundColor(Theme.Colors.textPrimary)
                    }
                    
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 50))], spacing: 16) {
                        ForEach(["battery.100", "bolt.fill", "thermometer", "flame", "arrow.triangle.2.circlepath", "drop.fill", "cpu", "fanblades.fill"], id: \.self) { icon in
                            VStack {
                                Image(systemName: icon)
                                    .font(.title2)
                                    .foregroundColor(Theme.Colors.textPrimary)
                                    .frame(width: 44, height: 44)
                                    .background(Theme.Colors.tertiaryBackground)
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(Theme.Layout.padding)
                    .cardStyle()
                    .padding(Theme.Layout.padding)
                    .cardStyle()
                }
                .padding(.horizontal, 24)
                
                // Settings
                VStack(spacing: 20) {
                     // Spacing
                     HStack {
                         Image(systemName: "arrow.left.and.right")
                             .foregroundColor(Theme.Colors.textSecondary)
                         Text("Menubar Items Spacing")
                           .foregroundColor(Theme.Colors.textPrimary)
                         Image(systemName: "questionmark.circle")
                             .foregroundColor(Theme.Colors.textSecondary)
                             .font(.caption)
                         Spacer()
                         Slider(value: $itemSpacing, in: 0...20)
                             .frame(width: 150)
                         Text("\(Int(itemSpacing))")
                             .frame(width: 30)
                     }
                     
                     // Update Interval
                     HStack {
                         Image(systemName: "timer")
                             .foregroundColor(Theme.Colors.textSecondary)
                         Text("Menubar Update Interval")
                           .foregroundColor(Theme.Colors.textPrimary)
                         Image(systemName: "questionmark.circle")
                             .foregroundColor(Theme.Colors.textSecondary)
                             .font(.caption)
                         Spacer()
                         Slider(value: $updateInterval, in: 1...20)
                             .frame(width: 150)
                         Text("\(Int(updateInterval))")
                             .frame(width: 30)
                     }
                     
                     // Right Click
                     HStack {
                         Image(systemName: "macwindow.on.rectangle")
                             .foregroundColor(Theme.Colors.textSecondary)
                         Text("Menubar Right Click")
                           .foregroundColor(Theme.Colors.textPrimary)
                         Image(systemName: "questionmark.circle")
                             .foregroundColor(Theme.Colors.textSecondary)
                             .font(.caption)
                         Spacer()
                         Picker("", selection: $rightClickAction) {
                             Text("Like Left Click").tag("Like Left Click")
                             Text("Show Settings").tag("Show Settings")
                         }
                         .pickerStyle(MenuPickerStyle())
                         .frame(width: 160)
                     }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - Onboarding Components

struct OnboardingStep {
    let title: String
    let description: String
    let section: NavigationSection
}

let onboardingSteps: [OnboardingStep] = [
    OnboardingStep(
        title: "Welcome to BatteryPro",
        description: "Your ultimate tool for MacBook battery health and management. Let's take a quick tour.",
        section: .dashboard
    ),
    OnboardingStep(
        title: "Limit Manager",
        description: "Set a maximum charge limit to extend your battery's lifespan. We recommend 80% for daily use.",
        section: .chargeControl
    ),
    OnboardingStep(
        title: "Energy Monitor",
        description: "Track your real-time power usage and identify apps that are draining your battery.",
        section: .energyUse
    ),
    OnboardingStep(
        title: "Planner",
        description: "Schedule when your battery tasks should run, like calibration or sailing mode.",
        section: .schedule
    ),
    OnboardingStep(
        title: "Mini Control",
        description: "Customize the popover menu for quick access to essential controls from the menu bar.",
        section: .popover
    ),
    OnboardingStep(
        title: "You're All Set!",
        description: "Explore the settings to customize BatteryPro to your liking. Enjoy!",
        section: .dashboard
    )
]

struct OnboardingOverlay: View {
    let step: OnboardingStep
    let totalSteps: Int
    let currentIndex: Int
    let onNext: () -> Void
    let onSkip: () -> Void
    
    var body: some View {
        HStack(spacing: 24) {
            // Icon for the section
            Image(systemName: step.section.icon)
                .font(.system(size: 32))
                .foregroundColor(Theme.Colors.accent)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(step.title)
                    .font(Theme.Fonts.subheadline)
                    .bold()
                    .foregroundColor(Theme.Colors.textPrimary)
                
                Text(step.description)
                    .font(Theme.Fonts.body)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Actions
            HStack(spacing: 16) {
                Button(action: onSkip) {
                    Text("Skip")
                        .fontWeight(.medium)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: onNext) {
                    Text(currentIndex == totalSteps - 1 ? "Finish" : "Next")
                        .fontWeight(.bold)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Theme.Colors.accent)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // Progress Dots (Optional, or integrated)
            // Let's keep them small below or next to buttons? 
            // The user wanted "outside main app container", effectively a banner.
            // Let's just keep the dots simple if needed, or omit for cleaner look.
            // Screenshot shows dots below buttons. Let's put them in a VStack with buttons or just right side.
        }
        .padding(24)
        .background(
            ZStack {
                VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                Theme.Colors.secondaryBackground.opacity(0.9)
            }
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.Colors.accent.opacity(0.3), lineWidth: 1)
        )
        .padding(24) // Float from edges
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom) // Align to bottom
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .zIndex(100)
    }
}
