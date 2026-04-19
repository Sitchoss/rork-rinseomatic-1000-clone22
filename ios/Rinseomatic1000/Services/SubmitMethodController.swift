import Foundation
import Combine

@MainActor
final class SubmitMethodController: ObservableObject {
    static let shared = SubmitMethodController()

    private static let joeKey = "crimson_joe_submit_method"
    private static let ignKey = "crimson_ign_submit_method"
    private static let syncKey = "crimson_global_sync_active"

    @Published var joeSubmitMethod: AutomationSettings.SubmitMethod {
        didSet {
            UserDefaults.standard.set(joeSubmitMethod.rawValue, forKey: Self.joeKey)
            if isGlobalSyncActive { syncIgnitionToJoe() }
            pushToAutomationSettings()
        }
    }

    @Published var ignSubmitMethod: AutomationSettings.SubmitMethod {
        didSet {
            UserDefaults.standard.set(ignSubmitMethod.rawValue, forKey: Self.ignKey)
            pushToAutomationSettings()
        }
    }

    @Published var isGlobalSyncActive: Bool {
        didSet {
            UserDefaults.standard.set(isGlobalSyncActive, forKey: Self.syncKey)
            if isGlobalSyncActive { syncIgnitionToJoe() }
        }
    }

    private init() {
        // Boot from AutomationSettings (canonical persisted source).
        // UserDefaults keys are used only as a fast-path session cache and are
        // kept in sync but never treated as the authoritative source.
        let saved = AutomationSettingsPersistence.shared.load()
        let joeMethod = saved.joeSubmitMethod
        let ignMethod = saved.ignSubmitMethod
        let sync = UserDefaults.standard.object(forKey: Self.syncKey) as? Bool ?? true

        self.joeSubmitMethod = joeMethod
        self.ignSubmitMethod = ignMethod
        self.isGlobalSyncActive = sync

        // Seed UserDefaults cache to match canonical values.
        UserDefaults.standard.set(joeMethod.rawValue, forKey: Self.joeKey)
        UserDefaults.standard.set(ignMethod.rawValue, forKey: Self.ignKey)
    }

    private func syncIgnitionToJoe() {
        if ignSubmitMethod != joeSubmitMethod {
            ignSubmitMethod = joeSubmitMethod
        }
    }

    private func pushToAutomationSettings() {
        let persistence = AutomationSettingsPersistence.shared
        var settings = persistence.load()
        settings.joeSubmitMethod = joeSubmitMethod
        settings.ignSubmitMethod = ignSubmitMethod
        let normalized = settings.normalizedTimeouts()
        persistence.save(normalized)
        DebugLogger.logBackground("SubmitMethodController: Joe=\(joeSubmitMethod.rawValue) Ign=\(ignSubmitMethod.rawValue) — saved via NotificationCenter sync", category: .automation, level: .info)
    }

    func method(for site: LoginTargetSite) -> AutomationSettings.SubmitMethod {
        switch site {
        case .joefortune: joeSubmitMethod
        case .ignition: ignSubmitMethod
        }
    }
}
