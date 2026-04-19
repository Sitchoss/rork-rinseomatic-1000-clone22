import SwiftUI

struct ToolsAndTestingHubView: View {
    nonisolated enum Route: Hashable, Sendable {
        case flowRecorder
        case superTest
        case testDebug
        case ipScore
        case fingerprint
        case grokStatus
        case debugLog
        case nordConfig
        case networkRepair
        case proxyManager
        case appWideFeed
    }

    var body: some View {
        NavigationStack {
            List {
                automationSection
                validationSection
                diagnosticsSection
                networkSection
                feedSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Tools & Testing")
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .flowRecorder:
                    FlowRecorderView()
                case .superTest:
                    SuperTestView()
                case .testDebug:
                    TestDebugContainerView()
                case .ipScore:
                    IPScoreTestView()
                case .fingerprint:
                    FingerprintTestView()
                case .grokStatus:
                    GrokAIStatusView()
                case .debugLog:
                    DebugLogView()
                case .nordConfig:
                    NordLynxConfigView()
                case .networkRepair:
                    NetworkRepairView()
                case .proxyManager:
                    ProxyManagerView()
                case .appWideFeed:
                    UnifiedScreenshotFeedView()
                        .navigationTitle("App-Wide Feed")
                }
            }
        }
        .withMainMenuButton()
        .preferredColorScheme(.dark)
    }

    private var automationSection: some View {
        Section {
            NavigationLink(value: Route.flowRecorder) {
                hubRow(icon: "record.circle.fill", title: "Flow Recorder", subtitle: "Record and replay browser automation flows", color: .red)
            }
        } header: {
            Label("Automation", systemImage: "record.circle")
        }
    }

    private var validationSection: some View {
        Section {
            NavigationLink(value: Route.superTest) {
                hubRow(icon: "bolt.horizontal.circle.fill", title: "Super Test", subtitle: "Full infrastructure validation", color: .purple)
            }
            NavigationLink(value: Route.testDebug) {
                hubRow(icon: "flask.fill", title: "Test & Debug", subtitle: "Known account optimizer and multi-session test tools", color: .mint)
            }
            NavigationLink(value: Route.ipScore) {
                hubRow(icon: "network.badge.shield.half.filled", title: "IP Score Test", subtitle: "Concurrent IP quality analysis", color: .indigo)
            }
            NavigationLink(value: Route.fingerprint) {
                hubRow(icon: "touchid", title: "Fingerprint Test", subtitle: "Browser fingerprint detection analysis", color: .teal)
            }
        } header: {
            Label("Validation", systemImage: "checklist.checked")
        }
    }

    private var diagnosticsSection: some View {
        Section {
            NavigationLink(value: Route.grokStatus) {
                hubRow(icon: "sparkles", title: "Gemini AI Status", subtitle: GeminiAISetup.isConfigured ? "Connected — vision + telemetry active" : "Not configured — paste API key", color: GeminiAISetup.isConfigured ? .green : .orange)
            }
            NavigationLink(value: Route.debugLog) {
                hubRow(icon: "doc.text.magnifyingglass", title: "Debug Log", subtitle: "Review app diagnostics and system logs", color: .orange)
            }
        } header: {
            Label("Diagnostics & AI", systemImage: "waveform.path.ecg")
        }
    }

    private var networkSection: some View {
        Section {
            NavigationLink(value: Route.nordConfig) {
                hubRow(icon: "shield.checkered", title: "Nord Config", subtitle: "WireGuard and OpenVPN generation", color: Color(red: 0.0, green: 0.78, blue: 1.0))
            }
            NavigationLink(value: Route.networkRepair) {
                hubRow(icon: "wrench.and.screwdriver.fill", title: "Repair Network", subtitle: "Restart network layers and repair routing", color: .orange)
            }
            NavigationLink(value: Route.proxyManager) {
                hubRow(icon: "arrow.triangle.branch", title: "Proxy Manager", subtitle: "Inspect and manage proxy pools", color: .blue)
            }
        } header: {
            Label("Network", systemImage: "network")
        }
    }

    private var feedSection: some View {
        Section {
            NavigationLink(value: Route.appWideFeed) {
                hubRow(icon: "photo.stack.fill", title: "App-Wide Feed", subtitle: "Shared screenshot feed across the app", color: .cyan)
            }
        } header: {
            Label("Feed", systemImage: "photo.stack")
        }
    }

    private func hubRow(icon: String, title: String, subtitle: String, color: Color) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
