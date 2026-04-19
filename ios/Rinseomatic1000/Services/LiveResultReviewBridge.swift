import Foundation
import UIKit

@MainActor
class LiveResultReviewBridge {
    static let shared = LiveResultReviewBridge()

    private let logger = DebugLogger.shared
    private let screenshotManager = UnifiedScreenshotManager.shared

    private init() {
        setupSessionObserver()
    }

    private func setupSessionObserver() {
        NotificationCenter.default.addObserver(
            forName: .unifiedSessionCompleted,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            guard let info = notification.userInfo,
                  let sessionId = info["sessionId"] as? String else { return }
            Task { @MainActor in
                self.handleSessionCompleted(sessionId: sessionId)
            }
        }
    }

    func handleSessionCompleted(sessionId: String) {
        let debugService = LiveWebViewDebugService.shared
        guard debugService.isFullScreen && debugService.resultReviewEnabled else { return }

        let vm = UnifiedSessionViewModel.shared
        guard let session = vm.sessions.first(where: { $0.id == sessionId }),
              session.isTerminal else { return }

        let screenshots = screenshotManager.screenshotsForSession(sessionId)

        let joeShot = screenshots.first(where: {
            $0.site.lowercased().contains("joe") && $0.step.isCritical
        }) ?? screenshots.first(where: { $0.site.lowercased().contains("joe") })

        let ignShot = screenshots.first(where: {
            $0.site.lowercased().contains("ign") && $0.step.isCritical
        }) ?? screenshots.first(where: { $0.site.lowercased().contains("ign") })

        let joeOutcome = LiveResultReviewOutcome.fromSiteResult(session.joeSiteResult)
        let ignOutcome = LiveResultReviewOutcome.fromSiteResult(session.ignitionSiteResult)

        let joeConfidence = session.joeOCRMetadata?.confidence ?? 0.5
        let ignConfidence = session.ignitionOCRMetadata?.confidence ?? 0.5

        let item = LiveResultReviewItem(
            credentialEmail: session.credential.email,
            credentialPassword: session.credential.maskedPassword,
            sessionId: sessionId,
            joeDetectedOutcome: joeOutcome,
            ignitionDetectedOutcome: ignOutcome,
            joeScreenshotData: joeShot?.fullImageData,
            ignitionScreenshotData: ignShot?.fullImageData,
            joeConfidence: joeConfidence,
            ignitionConfidence: ignConfidence,
            joeOCRText: joeShot?.allDetectedText ?? session.joeOCRMetadata?.fullText ?? "",
            ignitionOCRText: ignShot?.allDetectedText ?? session.ignitionOCRMetadata?.fullText ?? ""
        )

        debugService.enqueueResultReview(item)

        logger.log("LiveReviewBridge: enqueued review for \(session.credential.email) — \(joeOutcome.shortLabel) / \(ignOutcome.shortLabel)", category: .evaluation, level: .info)
    }

    func manuallyEnqueueSession(_ session: DualSiteSession) {
        handleSessionCompleted(sessionId: session.id)
    }
}

extension Notification.Name {
    static let unifiedSessionCompleted = Notification.Name("unifiedSessionCompleted")
}
