import SwiftUI
import UIKit

struct SettingsHubRootView: View {
    @State private var proxyService = ProxyRotationService.shared
    @State private var automationOnlyMode: Bool = DebugLogger.shared.automationOnlyMode
    @State private var cookieBannerBlockerEnabled: Bool = CookieBannerBlockerScript.isEnabled
    @State private var showCopiedToast: Bool = false
    @State private var shareFileURL: URL?
    @State private var searchText: String = ""

    nonisolated enum Route: Hashable, Sendable {
        case developerSettings
        case deviceNetwork
        case loginNetwork
        case nordConfig
        case networkRepair
        case urlManagement
        case ppsrSettings
        case importExport
        case vault
        case debugLog
    }

    var body: some View {
        NavigationStack {
            List {
                if matches("Developer Settings", "All 200+ automation parameters timing detection stealth retries concurrency") {
                    automationEngineSection
                }
                networkSectionIfNeeded
                stealthSectionIfNeeded
                urlsSectionIfNeeded
                dataSectionIfNeeded
                diagnosticsSectionIfNeeded
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search settings")
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .developerSettings:
                    DeveloperSettingsView()
                case .deviceNetwork:
                    DeviceNetworkSettingsView()
                case .loginNetwork:
                    LoginNetworkSettingsView(vm: LoginViewModel.shared)
                case .nordConfig:
                    NordLynxConfigView()
                case .networkRepair:
                    NetworkRepairView()
                case .urlManagement:
                    URLManagementView()
                case .ppsrSettings:
                    PPSRSettingsView(vm: PPSRAutomationViewModel.shared)
                case .importExport:
                    ConsolidatedImportExportView()
                case .vault:
                    StorageFileBrowserView()
                case .debugLog:
                    DebugLogView()
                }
            }
            .overlay(alignment: .bottom) {
                if showCopiedToast {
                    Text("Copied to clipboard")
                        .font(.subheadline.bold()).foregroundStyle(.white)
                        .padding(.horizontal, 20).padding(.vertical, 12)
                        .background(.green.gradient, in: Capsule())
                        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 20)
                }
            }
            .sheet(isPresented: Binding(
                get: { shareFileURL != nil },
                set: { if !$0 { shareFileURL = nil } }
            )) {
                if let url = shareFileURL {
                    ShareSheetView(items: [url])
                }
            }
        }
        .withMainMenuButton()
        .preferredColorScheme(.dark)
    }

    // MARK: - Search

    private func matches(_ fields: String...) -> Bool {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return true }
        let needle = q.lowercased()
        for f in fields where f.lowercased().contains(needle) { return true }
        return false
    }

    // MARK: - Automation Engine

    private var automationEngineSection: some View {
        Section {
            NavigationLink(value: Route.developerSettings) {
                settingsRow(
                    icon: "hammer.fill",
                    title: "Developer Settings",
                    subtitle: "All 200+ automation parameters: timing, detection, stealth, retries, concurrency",
                    color: .red
                )
            }
        } header: {
            sectionHeader(icon: "gearshape.2.fill", title: "AUTOMATION ENGINE", color: .red)
        } footer: {
            Text("The full automation tuning panel. Every delay, selector, retry count, and stealth option lives here.")
        }
    }

    // MARK: - Network & Routing

    @ViewBuilder
    private var networkSectionIfNeeded: some View {
        let deviceM = matches("Device Network", "IP routing mode rotation schedule tunnel config \(proxyService.unifiedConnectionMode.label)")
        let loginM = matches("Login Network", "Per-mode network overrides for login sessions")
        let nordM = matches("Nord Config", "Generate and manage WireGuard OpenVPN configs from NordVPN")
        let repairM = matches("Network Repair", "Restart network layers if connections are stuck or failing")
        if deviceM || loginM || nordM || repairM {
            Section {
                if deviceM {
                    NavigationLink(value: Route.deviceNetwork) {
                        settingsRow(
                            icon: "network.badge.shield.half.filled",
                            title: "Device Network",
                            subtitle: "IP routing mode, rotation schedule, and tunnel config \u{2022} \(proxyService.unifiedConnectionMode.label)",
                            color: .blue
                        )
                    }
                }
                if loginM {
                    NavigationLink(value: Route.loginNetwork) {
                        settingsRow(
                            icon: "arrow.triangle.branch",
                            title: "Login Network",
                            subtitle: "Per-mode network overrides for login sessions",
                            color: .cyan
                        )
                    }
                }
                if nordM {
                    NavigationLink(value: Route.nordConfig) {
                        settingsRow(
                            icon: "shield.checkered",
                            title: "Nord Config",
                            subtitle: "Generate and manage WireGuard & OpenVPN configs from NordVPN",
                            color: Color(red: 0.0, green: 0.78, blue: 1.0)
                        )
                    }
                }
                if repairM {
                    NavigationLink(value: Route.networkRepair) {
                        settingsRow(
                            icon: "wrench.and.screwdriver.fill",
                            title: "Network Repair",
                            subtitle: "Restart network layers if connections are stuck or failing",
                            color: .orange
                        )
                    }
                }
            } header: {
                sectionHeader(icon: "network", title: "NETWORK & ROUTING", color: .blue)
            }
        }
    }

    // MARK: - Stealth & Web

    @ViewBuilder
    private var stealthSectionIfNeeded: some View {
        if matches("Block Cookie Consent Banners", "Eliminates CookieInformation banners from every automation webview stealth") {
            Section {
                Toggle(isOn: $cookieBannerBlockerEnabled) {
                    settingsRow(
                        icon: "hand.raised.slash.fill",
                        title: "Block Cookie Consent Banners",
                        subtitle: "Eliminates CookieInformation banners from every automation webview",
                        color: .indigo
                    )
                }
                .tint(.indigo)
                .onChange(of: cookieBannerBlockerEnabled) { _, newValue in
                    CookieBannerBlockerScript.isEnabled = newValue
                }
            } header: {
                sectionHeader(icon: "shield.lefthalf.filled", title: "STEALTH & WEB", color: .indigo)
            } footer: {
                Text("When on, a 4-layer kill script (CSS nuke, DOM removal, MutationObserver, and window.CookieInformation stub) runs in every automation webview. Disable to let pages show their native cookie banners.")
            }
        }
    }

    // MARK: - URLs & Targets

    @ViewBuilder
    private var urlsSectionIfNeeded: some View {
        let urlM = matches("URL Management", "Login endpoints rotation lists custom domains")
        let cardM = matches("Card Testing Settings", "PPSR BPOINT WA REGO automation controls")
        if urlM || cardM {
            Section {
                if urlM {
                    NavigationLink(value: Route.urlManagement) {
                        settingsRow(
                            icon: "link.circle.fill",
                            title: "URL Management",
                            subtitle: "Login endpoints, rotation lists, and custom domains",
                            color: .green
                        )
                    }
                }
                if cardM {
                    NavigationLink(value: Route.ppsrSettings) {
                        settingsRow(
                            icon: "creditcard.fill",
                            title: "Card Testing Settings",
                            subtitle: "PPSR, BPOINT, and WA REGO automation controls",
                            color: .teal
                        )
                    }
                }
            } header: {
                sectionHeader(icon: "link", title: "URLS & TARGETS", color: .green)
            }
        }
    }

    // MARK: - Data

    @ViewBuilder
    private var dataSectionIfNeeded: some View {
        let impM = matches("Import / Export", "Full backup and restore of all app data")
        let vaultM = matches("Vault", "Browse saved files bundles and generated assets")
        if impM || vaultM {
            Section {
                if impM {
                    NavigationLink(value: Route.importExport) {
                        settingsRow(
                            icon: "square.and.arrow.up.on.square.fill",
                            title: "Import / Export",
                            subtitle: "Full backup and restore of all app data",
                            color: .mint
                        )
                    }
                }
                if vaultM {
                    NavigationLink(value: Route.vault) {
                        settingsRow(
                            icon: "externaldrive.fill",
                            title: "Vault",
                            subtitle: "Browse saved files, bundles, and generated assets",
                            color: .purple
                        )
                    }
                }
            } header: {
                sectionHeader(icon: "tray.2.fill", title: "DATA", color: .mint)
            }
        }
    }

    // MARK: - Diagnostics

    @ViewBuilder
    private var diagnosticsSectionIfNeeded: some View {
        let autoM = matches("Automation Events Only", "Only log automation actions silence everything else")
        let debugM = matches("Debug Log", "Full app log stream with filters and search")
        let copyDiagM = matches("Copy Diagnostic Report", "Full system snapshot copied to clipboard for sharing")
        let shareDiagM = matches("Share Diagnostic File", "Export diagnostic report as a shareable txt file")
        let copyAutoM = matches("Copy Automation Diagnostics", "Detailed script report with per-session timelines error chains healing history")
        let shareAutoM = matches("Share Automation Diagnostics File", "Export as txt for pasting back to Rork for script fixes")
        if autoM || debugM || copyDiagM || shareDiagM || copyAutoM || shareAutoM {
            Section {
                if autoM {
                    Toggle(isOn: $automationOnlyMode) {
                        settingsRow(
                            icon: "eye.slash.fill",
                            title: "Automation Events Only",
                            subtitle: "Only log automation actions, silence everything else",
                            color: .red
                        )
                    }
                    .tint(.red)
                    .onChange(of: automationOnlyMode) { _, newValue in
                        DebugLogger.shared.automationOnlyMode = newValue
                    }
                }

                if debugM {
                    NavigationLink(value: Route.debugLog) {
                        settingsRow(
                            icon: "doc.text.magnifyingglass",
                            title: "Debug Log",
                            subtitle: "Full app log stream with filters and search",
                            color: .orange
                        )
                    }
                }

                if copyDiagM {
                    Button {
                        let text = DebugLogger.shared.exportDiagnosticReport(
                            credentials: [],
                            automationSettings: AutomationSettings()
                        )
                        UIPasteboard.general.string = text
                        showToast()
                    } label: {
                        settingsRow(
                            icon: "stethoscope",
                            title: "Copy Diagnostic Report",
                            subtitle: "Full system snapshot copied to clipboard for sharing",
                            color: .indigo
                        )
                    }
                }

                if shareDiagM {
                    Button {
                        shareFileURL = DebugLogger.shared.exportDiagnosticReportToFile(credentials: [], automationSettings: AutomationSettings())
                    } label: {
                        settingsRow(
                            icon: "square.and.arrow.up",
                            title: "Share Diagnostic File",
                            subtitle: "Export diagnostic report as a shareable .txt file",
                            color: .purple
                        )
                    }
                }

                if copyAutoM {
                    Button {
                        let text = AutomationDiagnosticExporter.shared.exportAutomationDiagnostics()
                        UIPasteboard.general.string = text
                        showToast()
                    } label: {
                        settingsRow(
                            icon: "stethoscope.circle.fill",
                            title: "Copy Automation Diagnostics",
                            subtitle: "Detailed script report with per-session timelines, error chains, and healing history",
                            color: .red
                        )
                    }
                }

                if shareAutoM {
                    Button {
                        shareFileURL = AutomationDiagnosticExporter.shared.exportToFile()
                    } label: {
                        settingsRow(
                            icon: "square.and.arrow.up.circle.fill",
                            title: "Share Automation Diagnostics File",
                            subtitle: "Export as .txt for pasting back to Rork for script fixes",
                            color: .red
                        )
                    }
                }
            } header: {
                sectionHeader(icon: "stethoscope", title: "DIAGNOSTICS", color: .orange)
            } footer: {
                Text("Automation diagnostics include settings, selectors, per-session timelines, error chains, pattern logs, and healing history. Designed to paste directly to Rork for script fixes.")
            }
        }
    }

    // MARK: - Helpers

    private func showToast() {
        withAnimation(.spring(duration: 0.3)) { showCopiedToast = true }
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation { showCopiedToast = false }
        }
    }

    private func sectionHeader(icon: String, title: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(color)
            Text(title)
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(color)
        }
    }

    private func settingsRow(icon: String, title: String, subtitle: String, color: Color) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.gradient)
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }
}
