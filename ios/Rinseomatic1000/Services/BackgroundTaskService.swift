import UIKit

@MainActor
class BackgroundTaskService {
    static let shared = BackgroundTaskService()
    static let batchProcessingIdentifier = "Rinseomatic1000.ios77.batchProcessing"

    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var isInBackground: Bool = false

    func beginExtendedBackgroundExecution(reason: String) {
        guard UIApplication.shared.applicationState != .active else { return }
        performSafeStatePreservation(reason: reason, pausedAutomation: false)
    }

    func endExtendedBackgroundExecution() {
        guard backgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
        DebugLogger.shared.log("Background preservation ended", category: .system, level: .info)
    }

    var isRunningInBackground: Bool {
        backgroundTask != .invalid
    }

    var remainingBackgroundTime: TimeInterval {
        UIApplication.shared.backgroundTimeRemaining
    }

    func handleAppDidEnterBackground() {
        isInBackground = true
        let pausedAutomation = pauseActiveAutomationForBackgroundSafety()
        let reason = pausedAutomation
            ? "App backgrounded — automation paused and state saved"
            : "App backgrounded — state saved"
        performSafeStatePreservation(reason: reason, pausedAutomation: pausedAutomation)
    }

    func handleAppWillEnterForeground() {
        isInBackground = false
        RuntimeSafetyCenter.shared.recordForegroundReturn()
        endExtendedBackgroundExecution()
    }

    func handleBatchStarted() {
        guard isInBackground else { return }
        let pausedAutomation = pauseActiveAutomationForBackgroundSafety()
        let reason = pausedAutomation
            ? "Background batch request paused and saved for later resume"
            : "Background batch request saved for later resume"
        performSafeStatePreservation(reason: reason, pausedAutomation: pausedAutomation)
    }

    func handleBatchEnded() {
        endExtendedBackgroundExecution()
    }

    private func beginBackgroundTaskIfNeeded(reason: String) {
        guard backgroundTask == .invalid else { return }
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: reason) { [weak self] in
            Task { @MainActor [weak self] in
                self?.handleBackgroundTimeExpiring()
            }
        }
    }

    private func handleBackgroundTimeExpiring() {
        PersistentFileStorageService.shared.forceSave()
        DebugLogger.shared.persistLatestLog()
        LoginViewModel.shared.persistCredentialsNow()
        PPSRAutomationViewModel.shared.persistCardsNow()
        UnifiedSessionViewModel.shared.persistSessionsNow()
        RuntimeSafetyCenter.shared.recordSafeSave(reason: "Background time expiring — state saved", pausedAutomation: true)
        endExtendedBackgroundExecution()
    }

    private func performSafeStatePreservation(reason: String, pausedAutomation: Bool) {
        beginBackgroundTaskIfNeeded(reason: reason)
        PersistentFileStorageService.shared.forceSave()
        DebugLogger.shared.persistLatestLog()
        LoginViewModel.shared.persistCredentialsNow()
        PPSRAutomationViewModel.shared.persistCardsNow()
        UnifiedSessionViewModel.shared.persistSessionsNow()
        RuntimeSafetyCenter.shared.recordSafeSave(reason: reason, pausedAutomation: pausedAutomation)
        DebugLogger.shared.log(reason, category: .persistence, level: .info)
        endExtendedBackgroundExecution()
    }

    private func pauseActiveAutomationForBackgroundSafety() -> Bool {
        var pausedAutomation: Bool = false

        let loginVM = LoginViewModel.shared
        if loginVM.isRunning && !loginVM.isPaused {
            loginVM.pauseForBackgroundSafety()
            pausedAutomation = true
        }

        let ppsrVM = PPSRAutomationViewModel.shared
        if ppsrVM.isRunning && !ppsrVM.isPaused {
            ppsrVM.pauseForBackgroundSafety()
            pausedAutomation = true
        }

        let unifiedVM = UnifiedSessionViewModel.shared
        if unifiedVM.isRunning && !unifiedVM.isPaused {
            unifiedVM.pauseForBackgroundSafety()
            pausedAutomation = true
        }

        return pausedAutomation
    }
}
