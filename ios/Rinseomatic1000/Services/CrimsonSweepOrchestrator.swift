import Foundation
import WebKit

@MainActor
final class CrimsonSweepOrchestrator {
    static let shared = CrimsonSweepOrchestrator()

    private let logger = DebugLogger.shared
    private let submitRouter = SubmitMethodRouter.shared
    private let thickRedDetect = ThickRedDetectEngine.shared
    private let janitor = WebViewLifecycleManager.shared
    private let submitController = SubmitMethodController.shared

    nonisolated struct CrimsonResult: Sendable {
        let submitSuccess: Bool
        let submitDetail: String
        let redBannerDetected: Bool
        let redDetectDetail: String
        let cleanupPerformed: Bool
    }

    func executeCrimsonPipeline(
        webView: WKWebView,
        site: LoginTargetSite,
        sessionId: String = "",
        shouldDeepClean: Bool = false
    ) async -> CrimsonResult {
        janitor.registerWebView(webView)

        var submitSuccess = false
        var submitDetail = ""
        var redDetected = false
        var redDetail = "not_run"
        var cleaned = false

        let settings = AutomationSettingsPersistence.shared.load()
        let method = settings.submitMethod(for: site)
        let submitSelector = settings.submitSelector(for: site)

        logger.log("CrimsonSweep: BEGIN — site=\(site) method=\(method.rawValue) selector='\(submitSelector)'", category: .automation, level: .info, sessionId: sessionId)

        do {
            defer {
                if shouldDeepClean {
                    janitor.performDeepClean(on: webView)
                    cleaned = true
                    logger.log("CrimsonSweep: defer cleanup EXECUTED", category: .webView, level: .info, sessionId: sessionId)
                } else {
                    janitor.unregisterWebView(webView)
                }
            }

            let submitResult = await submitRouter.executeSubmit(
                method: method,
                submitSelector: submitSelector,
                in: webView,
                sessionId: sessionId
            )
            submitSuccess = submitResult.success
            submitDetail = submitResult.detail

            if !submitSuccess {
                logger.log("CrimsonSweep: submit FAILED — \(submitDetail)", category: .automation, level: .error, sessionId: sessionId)
                redDetail = "submit_failed_skipped"
                return CrimsonResult(
                    submitSuccess: false,
                    submitDetail: submitDetail,
                    redBannerDetected: false,
                    redDetectDetail: redDetail,
                    cleanupPerformed: cleaned
                )
            }

            logger.log("CrimsonSweep: submit OK — launching ThickRedDetect race", category: .automation, level: .info, sessionId: sessionId)

            guard !Task.isCancelled else {
                redDetail = "cancelled_before_detection"
                return CrimsonResult(submitSuccess: true, submitDetail: submitDetail, redBannerDetected: false, redDetectDetail: redDetail, cleanupPerformed: cleaned)
            }

            let detectionResult = await thickRedDetect.executeDetectionRace(webView: webView, sessionId: sessionId)

            switch detectionResult {
            case .crimsonHit(let pollCount, let elapsedMs):
                redDetected = true
                redDetail = "CRIMSON_HIT poll#\(pollCount) at \(elapsedMs)ms"
                logger.log("CrimsonSweep: RED BANNER DETECTED — \(redDetail)", category: .evaluation, level: .critical, sessionId: sessionId)

            case .noRedDetected:
                redDetail = "no_red_3s_timeout"
                logger.log("CrimsonSweep: no red — success path", category: .evaluation, level: .success, sessionId: sessionId)

            case .snapshotFailed(let reason):
                redDetail = "snapshot_failed: \(reason)"
                logger.log("CrimsonSweep: snapshot failed — defaulting to success path — \(reason)", category: .evaluation, level: .warning, sessionId: sessionId)

            case .cancelled:
                redDetail = "detection_cancelled"
                logger.log("CrimsonSweep: detection cancelled", category: .evaluation, level: .warning, sessionId: sessionId)
            }

        } catch {
            logger.log("CrimsonSweep: PIPELINE ERROR — \(error.localizedDescription)", category: .automation, level: .error, sessionId: sessionId)
            submitDetail = "pipeline_error: \(error.localizedDescription)"
        }

        logger.log("CrimsonSweep: COMPLETE — submit=\(submitSuccess) red=\(redDetected) clean=\(cleaned)", category: .automation, level: .info, sessionId: sessionId)

        return CrimsonResult(
            submitSuccess: submitSuccess,
            submitDetail: submitDetail,
            redBannerDetected: redDetected,
            redDetectDetail: redDetail,
            cleanupPerformed: cleaned
        )
    }

    func executeCrimsonPipelineClosure(
        executeJS: @escaping (String) async -> String?,
        webView: WKWebView?,
        site: LoginTargetSite,
        sessionId: String = "",
        shouldDeepClean: Bool = false
    ) async -> CrimsonResult {
        if let wv = webView {
            janitor.registerWebView(wv)
        }

        var submitSuccess = false
        var submitDetail = ""
        var redDetected = false
        var redDetail = "not_run"
        var cleaned = false

        let settings = AutomationSettingsPersistence.shared.load()
        let method = settings.submitMethod(for: site)
        let submitSelector = settings.submitSelector(for: site)

        logger.log("CrimsonSweep(closure): BEGIN — site=\(site) method=\(method.rawValue) selector='\(submitSelector)'", category: .automation, level: .info, sessionId: sessionId)

        do {
            defer {
                if shouldDeepClean, let wv = webView {
                    janitor.performDeepClean(on: wv)
                    cleaned = true
                } else if let wv = webView {
                    janitor.unregisterWebView(wv)
                }
            }

            let submitResult = await submitRouter.executeSubmit(
                method: method,
                submitSelector: submitSelector,
                executeJS: executeJS,
                sessionId: sessionId
            )
            submitSuccess = submitResult.success
            submitDetail = submitResult.detail

            if !submitSuccess {
                logger.log("CrimsonSweep(closure): submit FAILED — \(submitDetail)", category: .automation, level: .error, sessionId: sessionId)
                redDetail = "submit_failed_skipped"
                return CrimsonResult(submitSuccess: false, submitDetail: submitDetail, redBannerDetected: false, redDetectDetail: redDetail, cleanupPerformed: cleaned)
            }

            guard let wv = webView else {
                logger.log("CrimsonSweep(closure): no webView for pixel sniper — skipping ThickRedDetect", category: .evaluation, level: .warning, sessionId: sessionId)
                redDetail = "no_webview_skipped"
                return CrimsonResult(submitSuccess: true, submitDetail: submitDetail, redBannerDetected: false, redDetectDetail: redDetail, cleanupPerformed: cleaned)
            }

            guard !Task.isCancelled else {
                redDetail = "cancelled"
                return CrimsonResult(submitSuccess: true, submitDetail: submitDetail, redBannerDetected: false, redDetectDetail: redDetail, cleanupPerformed: cleaned)
            }

            let detectionResult = await thickRedDetect.executeDetectionRace(webView: wv, sessionId: sessionId)

            switch detectionResult {
            case .crimsonHit(let pollCount, let elapsedMs):
                redDetected = true
                redDetail = "CRIMSON_HIT poll#\(pollCount) at \(elapsedMs)ms"
                logger.log("CrimsonSweep(closure): RED BANNER — \(redDetail)", category: .evaluation, level: .critical, sessionId: sessionId)
            case .noRedDetected:
                redDetail = "no_red_3s_timeout"
            case .snapshotFailed(let reason):
                redDetail = "snapshot_failed: \(reason)"
            case .cancelled:
                redDetail = "detection_cancelled"
            }

        } catch {
            logger.log("CrimsonSweep(closure): PIPELINE ERROR — \(error.localizedDescription)", category: .automation, level: .error, sessionId: sessionId)
        }

        return CrimsonResult(submitSuccess: submitSuccess, submitDetail: submitDetail, redBannerDetected: redDetected, redDetectDetail: redDetail, cleanupPerformed: cleaned)
    }
}
