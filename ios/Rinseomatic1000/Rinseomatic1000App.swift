import SwiftUI
import UIKit

@main
struct Rinseomatic1000App: App {
    @AppStorage("activeAppMode") private var activeModeRaw: String = ""
    @State private var nordInitialized: Bool = false
    @AppStorage("hasEverOpenedPPSR") private var hasEverOpenedPPSR: Bool = false
    @AppStorage("hasEverOpenedUnified") private var hasEverOpenedUnified: Bool = false
    @State private var showCrashReport: Bool = false
    @State private var pendingCrashReport: CrashReport?
    @State private var showSafeBootAlert: Bool = false
    @State private var liveDebug = LiveWebViewDebugService.shared
    @State private var showGeminiKeyPrompt: Bool = false

    init() {
        Self.performEarlySafeBootCheck()
    }

    private static func performEarlySafeBootCheck() {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let tsFile = docs.appendingPathComponent("launch_timestamps.json")

        var timestamps: [TimeInterval] = []
        if let data = try? Data(contentsOf: tsFile),
           let arr = try? JSONSerialization.jsonObject(with: data) as? [TimeInterval] {
            timestamps = arr
        }

        let now = Date().timeIntervalSince1970
        let recentLaunches = timestamps.filter { now - $0 < 30 }

        if recentLaunches.count >= 3 {
            let proxySettings: [String: Any] = [
                "ipRoutingMode": "App-Wide United IP",
                "interval": "Every Batch",
                "rotateOnBatch": false,
                "rotateOnFingerprint": true,
                "localProxy": false,
                "autoFailover": true,
                "healthCheckInterval": 30.0,
                "maxFailures": 3,
            ]
            UserDefaults.standard.set(proxySettings, forKey: "device_proxy_settings_v2")
            UserDefaults.standard.set("DNS", forKey: "unified_connection_mode_v1")
            let connectionModes: [String: String] = [
                "joe": "DNS",
                "ignition": "DNS",
                "ppsr": "DNS",
            ]
            UserDefaults.standard.set(connectionModes, forKey: "connection_modes_v1")
            UserDefaults.standard.synchronize()
            try? FileManager.default.removeItem(at: tsFile)
            return
        }

        timestamps.append(now)
        timestamps = timestamps.filter { now - $0 < 120 }
        if let data = try? JSONSerialization.data(withJSONObject: timestamps) {
            try? data.write(to: tsFile, options: .atomic)
        }
    }

    private var activeMode: ActiveAppMode? {
        return ActiveAppMode(rawValue: activeModeRaw)
    }

    private var mainMenuBinding: Binding<ActiveAppMode?> {
        Binding(
            get: { activeMode },
            set: { newMode in
                activeModeRaw = newMode?.rawValue ?? ""
            }
        )
    }

    private var showingMenu: Bool {
        activeMode == nil
    }

    private var persistentModes: Set<ActiveAppMode> {
        [.unifiedSession, .ppsr]
    }

    private func restorePersistentFlags(for mode: ActiveAppMode?) {
        if mode == .unifiedSession {
            hasEverOpenedUnified = true
        }
        if mode == .ppsr {
            hasEverOpenedPPSR = true
        }
    }

    private func persistRuntimeState() {
        PersistentFileStorageService.shared.forceSave()
        DebugLogger.shared.persistLatestLog()
        LoginViewModel.shared.persistCredentialsNow()
        PPSRAutomationViewModel.shared.persistCardsNow()
        UnifiedSessionViewModel.shared.persistSessionsNow()
    }

    private func handleTermination() {
        if LoginViewModel.shared.isRunning {
            LoginViewModel.shared.emergencyStop()
        }
        if PPSRAutomationViewModel.shared.isRunning {
            PPSRAutomationViewModel.shared.emergencyStop()
        }
        if UnifiedSessionViewModel.shared.isRunning {
            UnifiedSessionViewModel.shared.emergencyStop()
        }
        persistRuntimeState()
    }

    private func configureMemoryMonitoring() {
        let monitor = MemoryPressureMonitor.shared
        monitor.register()
        monitor.onMemoryWarning {
            DebugLogger.shared.handleMemoryPressure()

            ScreenshotCacheService.shared.setMaxCacheCounts(memory: 10, disk: 200)
            LoginViewModel.shared.handleMemoryPressure()
            LoginViewModel.shared.trimAttemptsIfNeeded()
            PPSRAutomationViewModel.shared.handleMemoryPressure()
            PPSRAutomationViewModel.shared.trimChecksIfNeeded()
            UnifiedSessionViewModel.shared.handleMemoryPressure()
            UnifiedScreenshotManager.shared.handleMemoryPressure()
        }
    }

    private func performInitialLaunchSetup() async {
        guard !nordInitialized else { return }
        nordInitialized = true

        CrashProtectionService.shared.register()
        if CrashProtectionService.shared.didPerformSafeBoot {
            showSafeBootAlert = true
        }
        if let previousCrash = CrashProtectionService.shared.checkForPreviousCrash() {
            DebugLogger.shared.log("Previous crash detected: \(previousCrash.prefix(200))", category: .system, level: .critical)
            if let report = CrashProtectionService.shared.lastCrashReport {
                pendingCrashReport = report
                showCrashReport = true
            }
        }

        AppStabilityCoordinator.shared.start()
        WebViewLifecycleManager.shared.startZombieSweeper()

        Task {
            try? await Task.sleep(for: .seconds(10))
            CrashProtectionService.shared.clearLaunchTimestampsAfterStableLaunch()
        }

        configureMemoryMonitoring()
        _ = LiveResultReviewBridge.shared

        let vault = PersistentFileStorageService.shared
        let didRestore = vault.restoreIfNeeded()
        if didRestore {
            DebugLogger.shared.log("App launched — restored state from vault", category: .persistence, level: .success)
        }

        _ = GeminiAISetup.bootstrapFromEnvironment()
        if !GeminiAISetup.isConfigured {
            showGeminiKeyPrompt = true
        }

        let nord = NordVPNService.shared
        let hasRestoredProfile = await nord.ensureProfileNetworkPoolsReady()
        if !hasRestoredProfile {
            activeModeRaw = ""
        }
        if nord.isTokenExpired {
            nord.lastError = "NordVPN access token needs to be refreshed before fetching a private key."
        }

        vault.saveFullState()
        restorePersistentFlags(for: ActiveAppMode(rawValue: activeModeRaw))

        if nord.hasSelectedProfile {
            await nord.autoPopulateConfigs(forceRefresh: false)
        }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                // HyperFlow: Anchor headless WebViews to prevent iOS Jetsam background termination
                HiddenWebViewAnchor()

                ZStack {
                    if hasEverOpenedUnified {
                        UnifiedSessionFeedView()
                            .opacity(activeMode == .unifiedSession ? 1 : 0)
                            .allowsHitTesting(activeMode == .unifiedSession)
                    }

                    if hasEverOpenedPPSR {
                        ContentView()
                            .opacity(activeMode == .ppsr ? 1 : 0)
                            .allowsHitTesting(activeMode == .ppsr)
                    }

                    if let mode = activeMode, !persistentModes.contains(mode) {
                        nonPersistentModeView(mode)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .trailing).combined(with: .opacity)
                            ))
                    }

                    if showingMenu {
                        MainMenuView(activeMode: mainMenuBinding)
                        .transition(.opacity)
                    }
                }
            }
            .overlay(alignment: .topTrailing) {
                RunCommandPillView()
            }
            .overlay(alignment: .bottomTrailing) {
                LiveWebViewMiniWindow()
                    .padding(.trailing, 12)
                    .padding(.bottom, 90)
            }
            .fullScreenCover(isPresented: $liveDebug.isFullScreen) {
                LiveWebViewFullScreenView()
            }
            .animation(.spring(duration: 0.35, bounce: 0.15), value: activeModeRaw)
            .onChange(of: activeModeRaw) { _, newValue in
                let mode = ActiveAppMode(rawValue: newValue)
                liveDebug.setActiveMode(mode)
                restorePersistentFlags(for: mode)
            }
            .onAppear {
                let restoredMode = ActiveAppMode(rawValue: activeModeRaw)
                liveDebug.setActiveMode(restoredMode)
                restorePersistentFlags(for: restoredMode)
            }
            .task {
                await performInitialLaunchSetup()
            }
            .sheet(isPresented: $showCrashReport) {
                if let report = pendingCrashReport {
                    CrashReportPopupView(
                        report: report,
                        onDismiss: {
                            showCrashReport = false
                            CrashProtectionService.shared.clearPendingCrashReport()
                        },
                        onSend: { reportText in
                            UIPasteboard.general.string = reportText
                            DebugLogger.shared.log("Crash report copied to clipboard for sending to Rork", category: .system, level: .info)
                            showCrashReport = false
                            CrashProtectionService.shared.clearPendingCrashReport()
                        }
                    )
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                persistRuntimeState()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                persistRuntimeState()
                BackgroundTaskService.shared.handleAppDidEnterBackground()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                BackgroundTaskService.shared.handleAppWillEnterForeground()
                AppStabilityCoordinator.shared.handleForegroundReturn()
                restorePersistentFlags(for: ActiveAppMode(rawValue: activeModeRaw))
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
                handleTermination()
            }
            .sheet(isPresented: $showGeminiKeyPrompt) {
                NavigationStack {
                    GrokAIStatusView()
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Done") { showGeminiKeyPrompt = false }
                            }
                        }
                }
                .preferredColorScheme(.dark)
            }
            .alert("Safe Boot Activated", isPresented: $showSafeBootAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("The app detected repeated crashes on launch. Network settings have been reset to DNS-over-HTTPS mode to restore stability. You can change the connection mode again in Network Settings.")
            }
        }
    }

    @ViewBuilder
    private func nonPersistentModeView(_ mode: ActiveAppMode) -> some View {
        switch mode {
        case .superTest:
            SuperTestContainerView()
        case .debugLog:
            NavigationStack {
                DebugLogView()
            }
            .withMainMenuButton()
            .preferredColorScheme(.dark)
        case .flowRecorder:
            NavigationStack {
                FlowRecorderView()
            }
            .withMainMenuButton()
            .preferredColorScheme(.dark)
        case .nordConfig:
            NordLynxConfigView()
        case .vault:
            NavigationStack {
                StorageFileBrowserView()
            }
            .withMainMenuButton()
            .preferredColorScheme(.dark)
        case .ipScoreTest:
            NavigationStack {
                IPScoreTestView()
            }
            .withMainMenuButton()
            .preferredColorScheme(.dark)
        case .dualFind:
            DualFindContainerView()
        case .credentialHub:
            CredentialHubView()
        case .settings:
            SettingsHubRootView()
        case .toolsAndTesting:
            ToolsAndTestingHubView()
        case .customSitch:
            CustomSitchWorkspaceView()
        case .proxyManager:
            NavigationStack {
                ProxyManagerView()
            }
            .withMainMenuButton()
            .preferredColorScheme(.dark)
        case .testDebug:
            NavigationStack {
                TestDebugContainerView()
            }
            .withMainMenuButton()
            .preferredColorScheme(.dark)
        case .sitchomatic1000:
            Sitchomatic1000WorkspaceView()
        default:
            EmptyView()
        }
    }
}
