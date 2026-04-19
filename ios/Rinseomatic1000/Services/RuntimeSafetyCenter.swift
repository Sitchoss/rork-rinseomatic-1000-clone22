import Foundation
import Observation

@Observable
@MainActor
final class RuntimeSafetyCenter {
    static let shared = RuntimeSafetyCenter()

    var lastSafeSaveAt: Date?
    var lastSafeSaveReason: String?
    var backgroundPauseActive: Bool = false
    var focusRecoveryCount: Int = 0
    var consentCleanupCount: Int = 0
    var lastFocusRecoveryAt: Date?
    var lastConsentCleanupAt: Date?
    var lastFocusRecoveryReason: String?
    var lastConsentCleanupReason: String?

    var hasVisibleState: Bool {
        lastSafeSaveAt != nil || lastFocusRecoveryAt != nil || lastConsentCleanupAt != nil
    }

    var latestStatusMessage: String? {
        let saveEvent = lastSafeSaveAt.map { ($0, lastSafeSaveReason) }
        let focusEvent = lastFocusRecoveryAt.map { ($0, lastFocusRecoveryReason) }
        let consentEvent = lastConsentCleanupAt.map { ($0, lastConsentCleanupReason) }

        let latestEvent = [saveEvent, focusEvent, consentEvent]
            .compactMap { $0 }
            .sorted { $0.0 > $1.0 }
            .first

        return latestEvent?.1 ?? nil
    }

    func recordSafeSave(reason: String, pausedAutomation: Bool) {
        lastSafeSaveAt = Date()
        lastSafeSaveReason = reason
        backgroundPauseActive = pausedAutomation
    }

    func recordForegroundReturn() {
        backgroundPauseActive = false
    }

    func recordFocusRecovery(reason: String) {
        focusRecoveryCount += 1
        lastFocusRecoveryAt = Date()
        lastFocusRecoveryReason = reason
    }

    func recordConsentCleanup(reason: String) {
        consentCleanupCount += 1
        lastConsentCleanupAt = Date()
        lastConsentCleanupReason = reason
    }
}
