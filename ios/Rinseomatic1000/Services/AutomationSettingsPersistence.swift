import Foundation

extension Notification.Name {
    static let automationSettingsDidChange = Notification.Name("automationSettingsDidChange")
}

// Schema versioning: key is "automation_settings_v2".
// AutomationSettings uses Codable; adding new properties with defaults means
// old stored blobs decode cleanly — missing keys use their declared defaults.
// No migration code required unless a property is renamed or removed.
@MainActor
class AutomationSettingsPersistence {
    static let shared = AutomationSettingsPersistence()
    private let key = "automation_settings_v2"

    func save(_ settings: AutomationSettings) {
        guard let data = try? JSONEncoder().encode(settings) else {
            DebugLogger.logBackground("AutomationSettingsPersistence: encode failed — settings NOT saved", category: .automation, level: .critical)
            return
        }
        UserDefaults.standard.set(data, forKey: key)
        NotificationCenter.default.post(name: .automationSettingsDidChange, object: settings)
    }

    func load() -> AutomationSettings {
        guard let data = UserDefaults.standard.data(forKey: key),
              let settings = try? JSONDecoder().decode(AutomationSettings.self, from: data) else {
            return AutomationSettings().normalizedTimeouts()
        }
        return settings.normalizedTimeouts()
    }

    func reset() {
        UserDefaults.standard.removeObject(forKey: key)
        let defaults = AutomationSettings().normalizedTimeouts()
        NotificationCenter.default.post(name: .automationSettingsDidChange, object: defaults)
    }
}
