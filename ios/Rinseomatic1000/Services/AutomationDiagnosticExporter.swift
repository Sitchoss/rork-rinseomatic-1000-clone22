import Foundation
import UIKit

@MainActor
class AutomationDiagnosticExporter {
    static let shared = AutomationDiagnosticExporter()

    private let logger = DebugLogger.shared
    private let calibrationService = LoginCalibrationService.shared
    private let debugButtonService = DebugLoginButtonService.shared
    private let settingsPersistence = AutomationSettingsPersistence.shared

    func exportAutomationDiagnostics() -> String {
        let settings = settingsPersistence.load()
        let allEntries = logger.entries
        let automationEntries = allEntries.filter { $0.category.isAutomationRelevant }
        let now = DateFormatters.fullTimestamp.string(from: Date())

        var report = ""

        report += sectionBanner("AUTOMATION SCRIPT DIAGNOSTIC REPORT")
        report += "Generated: \(now)\n"
        report += "iOS: \(UIDevice.current.systemVersion) | Device: \(UIDevice.current.model)\n"
        report += "Total Log Entries: \(allEntries.count) | Automation Entries: \(automationEntries.count)\n"
        report += "Errors: \(logger.errorCount) | Warnings: \(logger.warningCount) | Critical: \(logger.criticalCount)\n"
        report += "Healing Events: \(logger.errorHealingLog.count) (success rate: \(String(format: "%.0f%%", logger.healingSuccessRate * 100)))\n"
        report += "\n"

        report += buildSettingsSnapshot(settings)
        report += buildSelectorAudit(settings)
        report += buildCalibrationState()
        report += buildDebugButtonState()
        report += buildSessionBreakdown(automationEntries)
        report += buildScriptTimeline(automationEntries)
        report += buildErrorChainAnalysis(allEntries, automationEntries: automationEntries)
        report += buildPatternExecutionLog(automationEntries)
        report += buildWebViewLifecycleLog(allEntries)
        report += buildHealingRetryHistory()
        report += buildTimingBreakdown(automationEntries)
        report += buildNetworkConfigPerSession(allEntries)
        report += buildCategoryBreakdown(automationEntries)
        report += buildLevelBreakdown(automationEntries)
        report += buildFullAutomationLog(automationEntries)

        report += sectionBanner("END OF AUTOMATION DIAGNOSTIC REPORT")

        return report
    }

    func exportToFile() -> URL? {
        let content = exportAutomationDiagnostics()
        let fileName = "automation_diagnostics_\(DateFormatters.fileTimestamp.string(from: Date())).txt"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try content.write(to: tempURL, atomically: true, encoding: .utf8)
            return tempURL
        } catch {
            logger.logError("AutomationDiagnosticExporter: failed to write file", error: error, category: .system)
            return nil
        }
    }

    // MARK: - Section Builders

    private func buildSettingsSnapshot(_ s: AutomationSettings) -> String {
        var out = sectionBanner("AUTOMATION SETTINGS SNAPSHOT")
        out += "=== True Detection ===\n"
        out += "  enabled: \(s.trueDetectionEnabled) | priority: \(s.trueDetectionPriority)\n"
        out += "  hardPauseMs: \(s.trueDetectionHardPauseMs) | tripleClickCount: \(s.trueDetectionTripleClickCount)\n"
        out += "  tripleClickDelayMs: \(s.trueDetectionTripleClickDelayMs) | interClickDelayMs: \(s.tripleClickInterClickDelayMs)\n"
        out += "  submitCycleCount: \(s.trueDetectionSubmitCycleCount) | buttonRecoveryTimeoutMs: \(s.trueDetectionButtonRecoveryTimeoutMs)\n"
        out += "  maxAttempts: \(s.trueDetectionMaxAttempts) | postClickWaitMs: \(s.trueDetectionPostClickWaitMs)\n"
        out += "  cooldownMinutes: \(s.trueDetectionCooldownMinutes)\n"
        out += "  successMarkers: \(s.trueDetectionSuccessMarkers.joined(separator: ", "))\n"
        out += "  terminalKeywords: \(s.trueDetectionTerminalKeywords.joined(separator: ", "))\n"
        out += "  errorBannerSelectors: \(s.trueDetectionErrorBannerSelectors.joined(separator: ", "))\n"
        out += "  noProxyRotation: \(s.trueDetectionNoProxyRotation) | strictWaits: \(s.trueDetectionStrictWaits)\n"
        out += "\n=== Page Loading ===\n"
        out += "  pageLoadTimeout: \(Int(s.pageLoadTimeout))s | retries: \(s.pageLoadRetries) | backoffMultiplier: \(s.retryBackoffMultiplier)\n"
        out += "  waitForJSRenderMs: \(s.waitForJSRenderMs) | fullSessionResetOnFinalRetry: \(s.fullSessionResetOnFinalRetry)\n"
        out += "\n=== Field Detection ===\n"
        out += "  fieldVerification: \(s.fieldVerificationEnabled) | timeout: \(Int(s.fieldVerificationTimeout))s\n"
        out += "  autoCalibration: \(s.autoCalibrationEnabled) | visionMLFallback: \(s.visionMLCalibrationFallback)\n"
        out += "  calibrationConfidence: \(String(format: "%.2f", s.calibrationConfidenceThreshold))\n"
        out += "\n=== Credential Entry ===\n"
        out += "  typingSpeed: \(s.typingSpeedMinMs)-\(s.typingSpeedMaxMs)ms | jitter: \(s.typingJitterEnabled)\n"
        out += "  backspace: \(s.occasionalBackspaceEnabled) prob=\(s.backspaceProbability)\n"
        out += "  fieldFocusDelay: \(s.fieldFocusDelayMs)ms | interFieldDelay: \(s.interFieldDelayMs)ms\n"
        out += "  preFillPause: \(s.preFillPauseMinMs)-\(s.preFillPauseMaxMs)ms\n"
        out += "  clearBefore: \(s.clearFieldsBeforeTyping) method=\(s.clearFieldMethod.rawValue)\n"
        out += "  verifyAfterTyping: \(s.verifyFieldValueAfterTyping) | retypeOnFail: \(s.retypeOnVerificationFailure) max=\(s.maxRetypeAttempts)\n"
        out += "\n=== Pattern Strategy ===\n"
        out += "  maxSubmitCycles: \(s.maxSubmitCycles)\n"
        out += "  enabledPatterns: \(s.enabledPatterns.joined(separator: ", "))\n"
        out += "  priorityOrder: \(s.patternPriorityOrder.joined(separator: " → "))\n"
        out += "  preferCalibrated: \(s.preferCalibratedPatternsFirst) | patternLearning: \(s.patternLearningEnabled)\n"
        out += "\n=== Fallback Chain ===\n"
        out += "  legacyFill: \(s.fallbackToLegacyFill) | OCR: \(s.fallbackToOCRClick)\n"
        out += "  visionML: \(s.fallbackToVisionMLClick) | coordinate: \(s.fallbackToCoordinateClick)\n"
        out += "\n=== Submit Behavior ===\n"
        out += "  submitRetryCount: \(s.submitRetryCount) | retryDelayMs: \(s.submitRetryDelayMs)\n"
        out += "  waitForResponse: \(Int(s.waitForResponseSeconds))s | rapidPoll: \(s.rapidPollEnabled) interval=\(s.rapidPollIntervalMs)ms\n"
        out += "  joeSubmitMethod: \(s.joeSubmitMethod.rawValue) | ignSubmitMethod: \(s.ignSubmitMethod.rawValue)\n"
        out += "\n=== Login Button ===\n"
        out += "  detectionMode: \(s.loginButtonDetectionMode.rawValue) | clickMethod: \(s.loginButtonClickMethod.rawValue)\n"
        out += "  preClickDelay: \(s.loginButtonPreClickDelayMs)ms | postClickDelay: \(s.loginButtonPostClickDelayMs)ms\n"
        out += "  doubleClickGuard: \(s.loginButtonDoubleClickGuard) window=\(s.loginButtonDoubleClickWindowMs)ms\n"
        out += "  scrollIntoView: \(s.loginButtonScrollIntoView) | waitForEnabled: \(s.loginButtonWaitForEnabled) timeout=\(s.loginButtonWaitForEnabledTimeoutMs)ms\n"
        out += "  hoverBeforeClick: \(s.loginButtonHoverBeforeClick) dwell=\(s.loginButtonHoverDurationMs)ms\n"
        out += "  clickOffsetJitter: \(s.loginButtonClickOffsetJitter) maxPx=\(s.loginButtonClickOffsetMaxPx)\n"
        out += "  textMatches: \(s.loginButtonTextMatches.joined(separator: ", "))\n"
        if !s.loginButtonCustomSelector.isEmpty {
            out += "  customSelector: \(s.loginButtonCustomSelector)\n"
        }
        out += "\n=== Post-Submit Evaluation ===\n"
        out += "  redirectDetection: \(s.redirectDetection) | contentChange: \(s.contentChangeDetection)\n"
        out += "  strictness: \(s.evaluationStrictness.rawValue) | captureContent: \(s.capturePageContent) minLen=\(s.minimumPageContentLength)\n"
        out += "\n=== Retry / Requeue ===\n"
        out += "  requeueOnTimeout: \(s.requeueOnTimeout) | requeueOnConnFail: \(s.requeueOnConnectionFailure)\n"
        out += "  requeueOnRedBanner: \(s.requeueOnRedBanner) | maxRequeue: \(s.maxRequeueCount)\n"
        out += "  minAttemptsBeforeNoAcc: \(s.minAttemptsBeforeNoAcc)\n"
        out += "  cyclePause: \(s.cyclePauseMinMs)-\(s.cyclePauseMaxMs)ms\n"
        out += "\n=== Stealth ===\n"
        out += "  stealthJS: \(s.stealthJSInjection) | fingerprint: \(s.fingerprintSpoofing)\n"
        out += "  userAgentRotation: \(s.userAgentRotation) | viewportRandom: \(s.viewportRandomization)\n"
        out += "  webGLNoise: \(s.webGLNoise) | canvasNoise: \(s.canvasNoise) | audioNoise: \(s.audioContextNoise)\n"
        out += "  timezoneSpoof: \(s.timezoneSpoof) | languageSpoof: \(s.languageSpoof)\n"
        out += "  fingerprintValidation: \(s.fingerprintValidationEnabled) | hostLearning: \(s.hostFingerprintLearningEnabled)\n"
        out += "\n=== Concurrency ===\n"
        out += "  maxConcurrency: \(s.maxConcurrency) | strategy: \(s.concurrencyStrategy.rawValue)\n"
        out += "  fixedPairs: \(s.fixedPairCount) | livePairs: \(s.liveUserPairCount)\n"
        out += "  batchDelay: \(s.batchDelayBetweenStartsMs)ms | connectionTestBefore: \(s.connectionTestBeforeBatch)\n"
        out += "\n=== Session Isolation ===\n"
        out += "  mode: \(s.sessionIsolation.rawValue)\n"
        out += "  clearCookies: \(s.clearCookiesBetweenAttempts) | localStorage: \(s.clearLocalStorageBetweenAttempts)\n"
        out += "  sessionStorage: \(s.clearSessionStorageBetweenAttempts) | cache: \(s.clearCacheBetweenAttempts)\n"
        out += "  indexedDB: \(s.clearIndexedDBBetweenAttempts) | freshWebView: \(s.freshWebViewPerAttempt)\n"
        out += "\n=== V4.2 Settlement Gate ===\n"
        out += "  enabled: \(s.v42SettlementGateEnabled) | maxTimeout: \(s.v42SettlementMaxTimeoutMs)ms\n"
        out += "  buttonStability: \(s.v42ButtonStabilityMs)ms | hoverDwell: \(s.v42HoverDwellMs)ms\n"
        out += "  interAttemptDelay: \(s.v42InterAttemptDelayMinSec)-\(s.v42InterAttemptDelayMaxSec)s\n"
        out += "  humanVariance: \(s.v42HumanVarianceMinMs)-\(s.v42HumanVarianceMaxMs)ms\n"
        out += "  strictClassification: \(s.v42StrictClassification) | coordinateOnly: \(s.v42CoordinateInteractionOnly)\n"
        out += "\n=== Time Delays ===\n"
        out += "  globalPre: \(s.globalPreActionDelayMs)ms | globalPost: \(s.globalPostActionDelayMs)ms\n"
        out += "  preNav: \(s.preNavigationDelayMs)ms | postNav: \(s.postNavigationDelayMs)ms\n"
        out += "  preTyping: \(s.preTypingDelayMs)ms | postTyping: \(s.postTypingDelayMs)ms\n"
        out += "  preSubmit: \(s.preSubmitDelayMs)ms | postSubmit: \(s.postSubmitDelayMs)ms\n"
        out += "  betweenAttempts: \(s.betweenAttemptsDelayMs)ms | betweenCredentials: \(s.betweenCredentialsDelayMs)ms\n"
        out += "  pageStabilization: \(s.pageStabilizationDelayMs)ms | ajaxSettle: \(s.ajaxSettleDelayMs)ms\n"
        out += "  domMutation: \(s.domMutationSettleMs)ms | animationSettle: \(s.animationSettleDelayMs)ms\n"
        out += "  redirectFollow: \(s.redirectFollowDelayMs)ms | errorRecovery: \(s.errorRecoveryDelayMs)ms\n"
        out += "  delayRandomization: \(s.delayRandomizationEnabled) percent=\(s.delayRandomizationPercent)%\n"
        out += "\n=== Blank Page Recovery ===\n"
        out += "  enabled: \(s.blankPageRecoveryEnabled) | timeout: \(s.blankPageTimeoutSeconds)s | waitThreshold: \(s.blankPageWaitThresholdSeconds)s\n"
        out += "  fallbacks: wait=\(s.blankPageFallback1_WaitAndRecheck) url=\(s.blankPageFallback2_ChangeURL) dns=\(s.blankPageFallback3_ChangeDNS) fp=\(s.blankPageFallback4_ChangeFingerprint) reset=\(s.blankPageFallback5_FullSessionReset)\n"
        out += "  maxFallbackAttempts: \(s.blankPageMaxFallbackAttempts) | recheckInterval: \(s.blankPageRecheckIntervalMs)ms\n"
        out += "\n=== SMS Detection ===\n"
        out += "  enabled: \(s.smsDetectionEnabled) | burnSession: \(s.smsBurnSession)\n"
        out += "  keywords: \(s.smsNotificationKeywords.prefix(5).joined(separator: ", "))...\n"
        out += "\n=== Screenshot / Debug ===\n"
        out += "  slowDebug: \(s.slowDebugMode) | screenshotOnEveryEval: \(s.screenshotOnEveryEval)\n"
        out += "  onFailure: \(s.screenshotOnFailure) | onSuccess: \(s.screenshotOnSuccess)\n"
        out += "  perAttempt: \(s.screenshotsPerAttempt.rawValue) | unifiedPerAttempt: \(s.unifiedScreenshotsPerAttempt.label)\n"
        out += "  postSubmitTimings: \(s.postSubmitScreenshotTimings)\n"
        out += "\n=== URL Flow Assignments ===\n"
        if s.urlFlowAssignments.isEmpty {
            out += "  (none)\n"
        } else {
            for a in s.urlFlowAssignments {
                out += "  \(a.urlPattern) → flow '\(a.flowName)' (id=\(a.flowId)) overridePattern=\(a.overridePatternStrategy)\n"
            }
        }
        out += "\n=== Human Simulation ===\n"
        out += "  mouseMovement: \(s.humanMouseMovement) | scrollJitter: \(s.humanScrollJitter)\n"
        out += "  randomPrePause: \(s.randomPreActionPause) range=\(s.preActionPauseMinMs)-\(s.preActionPauseMaxMs)ms\n"
        out += "  gaussian: \(s.gaussianTimingDistribution)\n"
        out += "\n=== Error Classification ===\n"
        out += "  networkAutoRetry: \(s.networkErrorAutoRetry) | sslAutoRetry: \(s.sslErrorAutoRetry)\n"
        out += "  http403Block: \(s.http403MarkAsBlocked) | http429Wait: \(s.http429RetryAfterSeconds)s | http5xxRetry: \(s.http5xxAutoRetry)\n"
        out += "  connResetRetry: \(s.connectionResetAutoRetry) | dnsFailRetry: \(s.dnsFailureAutoRetry)\n"
        out += "\n"
        return out
    }

    private func buildSelectorAudit(_ s: AutomationSettings) -> String {
        var out = sectionBanner("SELECTOR AUDIT (per site)")
        out += "Joe Fortune:\n"
        out += "  email: \(s.joeEmailSelector)\n"
        out += "  password: \(s.joePasswordSelector)\n"
        out += "  submit: \(s.joeSubmitSelector)\n"
        out += "  submitMethod: \(s.joeSubmitMethod.rawValue)\n"
        out += "Ignition:\n"
        out += "  email: \(s.ignEmailSelector)\n"
        out += "  password: \(s.ignPasswordSelector)\n"
        out += "  submit: \(s.ignSubmitSelector)\n"
        out += "  submitMethod: \(s.ignSubmitMethod.rawValue)\n\n"
        return out
    }

    private func buildCalibrationState() -> String {
        var out = sectionBanner("CALIBRATION DATA")
        let cals = calibrationService.calibrations
        if cals.isEmpty {
            out += "  (no calibration data)\n\n"
            return out
        }
        for (host, cal) in cals.sorted(by: { $0.key < $1.key }) {
            out += "[\(host)]\n"
            out += "  email: \(cal.emailField?.cssSelector ?? "none") fallbacks=\(cal.emailField?.fallbackSelectors.joined(separator: ",") ?? "none")\n"
            out += "  password: \(cal.passwordField?.cssSelector ?? "none") fallbacks=\(cal.passwordField?.fallbackSelectors.joined(separator: ",") ?? "none")\n"
            out += "  loginBtn: \(cal.loginButton?.cssSelector ?? "none") fallbacks=\(cal.loginButton?.fallbackSelectors.joined(separator: ",") ?? "none")\n"
            out += "  confidence: \(String(format: "%.0f%%", cal.confidence * 100)) success=\(cal.successCount) fail=\(cal.failCount)\n"
            if let fp = cal.domFingerprint { out += "  domFingerprint: \(fp.prefix(60))\n" }
            if let hash = cal.pageStructureHash { out += "  pageStructureHash: \(hash.prefix(40))\n" }
            if let fid = cal.linkedFlowId { out += "  linkedFlowId: \(fid)\n" }
            out += "\n"
        }
        return out
    }

    private func buildDebugButtonState() -> String {
        var out = sectionBanner("DEBUG LOGIN BUTTON CONFIGS")
        let configs = debugButtonService.configs
        if configs.isEmpty {
            out += "  (no saved configs)\n\n"
            return out
        }
        for (host, config) in configs.sorted(by: { $0.key < $1.key }) {
            let method = config.successfulMethod?.methodName ?? "none"
            let confirmed = config.userConfirmed ? "USER-CONFIRMED" : "AUTO-DETECTED"
            out += "[\(host)] method=\(method) [\(confirmed)] attempts=\(config.totalAttempts)\n"
        }
        out += "\n"
        return out
    }

    private func buildSessionBreakdown(_ entries: [DebugLogEntry]) -> String {
        var out = sectionBanner("PER-SESSION BREAKDOWN")
        let sessionIds = Set(entries.compactMap(\.sessionId)).sorted()
        if sessionIds.isEmpty {
            out += "  (no sessions recorded)\n\n"
            return out
        }
        for sid in sessionIds {
            let sessionEntries = entries.filter { $0.sessionId == sid }.sorted { $0.timestamp < $1.timestamp }
            let errors = sessionEntries.filter { $0.level >= .error }.count
            let warnings = sessionEntries.filter { $0.level == .warning }.count
            let successes = sessionEntries.filter { $0.level == .success }.count
            let firstTs = sessionEntries.first?.formattedTime ?? "?"
            let lastTs = sessionEntries.last?.formattedTime ?? "?"
            let totalMs: String
            if let first = sessionEntries.first?.timestamp, let last = sessionEntries.last?.timestamp {
                totalMs = "\(Int(last.timeIntervalSince(first) * 1000))ms"
            } else {
                totalMs = "?"
            }

            out += "── SESSION: \(sid) ──\n"
            out += "  \(sessionEntries.count) entries | \(errors) err | \(warnings) warn | \(successes) ok | \(firstTs) → \(lastTs) (\(totalMs))\n"

            for entry in sessionEntries {
                let dur = entry.durationMs.map { " [\($0)ms]" } ?? ""
                let det = entry.detail.map { " | \($0)" } ?? ""
                let meta = entry.metadata.map { dict in
                    " {" + dict.map { "\($0.key)=\($0.value)" }.joined(separator: ", ") + "}"
                } ?? ""
                out += "  [\(entry.formattedTime)] [\(entry.level.rawValue)] [\(entry.category.rawValue)]\(dur) \(entry.message)\(det)\(meta)\n"
            }
            out += "\n"
        }
        return out
    }

    private func buildScriptTimeline(_ entries: [DebugLogEntry]) -> String {
        var out = sectionBanner("SCRIPT EXECUTION TIMELINE (chronological)")
        let sorted = entries.sorted { $0.timestamp < $1.timestamp }
        let recent = sorted.suffix(1000)
        out += "  (showing last \(recent.count) of \(sorted.count) automation entries)\n\n"
        for entry in recent {
            let dur = entry.durationMs.map { " [\($0)ms]" } ?? ""
            let sess = entry.sessionId.map { " <\($0)>" } ?? ""
            let det = entry.detail.map { "\n    DETAIL: \($0)" } ?? ""
            let meta = entry.metadata.map { dict in
                "\n    META: {" + dict.map { "\($0.key)=\($0.value)" }.joined(separator: ", ") + "}"
            } ?? ""
            out += "[\(entry.fullTimestamp)] [\(entry.level.rawValue)] [\(entry.category.rawValue)]\(sess)\(dur) \(entry.message)\(det)\(meta)\n"
        }
        out += "\n"
        return out
    }

    private func buildErrorChainAnalysis(_ allEntries: [DebugLogEntry], automationEntries: [DebugLogEntry]) -> String {
        var out = sectionBanner("ERROR CHAIN ANALYSIS (5 entries before & after each error)")
        let errors = automationEntries.filter { $0.level >= .error }
        if errors.isEmpty {
            out += "  (no automation errors recorded)\n\n"
            return out
        }
        let allSorted = allEntries.sorted { $0.timestamp < $1.timestamp }
        for (idx, error) in errors.prefix(30).enumerated() {
            out += "── ERROR #\(idx + 1): \(error.message) ──\n"
            out += "  at \(error.fullTimestamp) [\(error.category.rawValue)] session=\(error.sessionId ?? "none")\n"
            if let detail = error.detail { out += "  DETAIL: \(detail)\n" }
            if let meta = error.metadata, !meta.isEmpty {
                out += "  META: {" + meta.map { "\($0.key)=\($0.value)" }.joined(separator: ", ") + "}\n"
            }

            if let errorIndex = allSorted.firstIndex(where: { $0.id == error.id }) {
                let beforeStart = max(0, errorIndex - 5)
                let afterEnd = min(allSorted.count, errorIndex + 6)
                out += "  --- BEFORE ---\n"
                for i in beforeStart..<errorIndex {
                    let e = allSorted[i]
                    out += "    [\(e.formattedTime)] [\(e.level.rawValue)] [\(e.category.rawValue)] \(e.message)\n"
                }
                out += "  >>> ERROR <<<\n"
                out += "    [\(error.formattedTime)] [\(error.level.rawValue)] [\(error.category.rawValue)] \(error.message)\n"
                out += "  --- AFTER ---\n"
                for i in (errorIndex + 1)..<afterEnd {
                    let e = allSorted[i]
                    out += "    [\(e.formattedTime)] [\(e.level.rawValue)] [\(e.category.rawValue)] \(e.message)\n"
                }
            }
            out += "\n"
        }
        if errors.count > 30 {
            out += "  ... and \(errors.count - 30) more errors (truncated)\n\n"
        }
        return out
    }

    private func buildPatternExecutionLog(_ entries: [DebugLogEntry]) -> String {
        var out = sectionBanner("PATTERN EXECUTION LOG")
        let patternEntries = entries.filter {
            $0.message.contains("Pattern") || $0.message.contains("pattern") ||
            $0.message.contains("TRUE DETECTION") || $0.message.contains("Calibrated") ||
            $0.message.contains("Tab Navigation") || $0.message.contains("Click-Focus") ||
            $0.message.contains("ExecCommand") || $0.message.contains("Slow Deliberate") ||
            $0.message.contains("Mobile Touch") || $0.message.contains("Form Submit") ||
            $0.message.contains("Coordinate Click") || $0.message.contains("Vision ML") ||
            $0.message.contains("React Native") || $0.message.contains("TripleClick") ||
            $0.message.contains("HumanClick") || $0.message.contains("SubmitMethod") ||
            $0.message.contains("Settlement") || $0.message.contains("ButtonRecovery") ||
            $0.message.contains("CharByChar") || $0.message.contains("ExecCmd") ||
            $0.message.contains("SlowTyper")
        }.sorted { $0.timestamp < $1.timestamp }
        if patternEntries.isEmpty {
            out += "  (no pattern execution entries)\n\n"
            return out
        }
        for entry in patternEntries.suffix(200) {
            let sess = entry.sessionId.map { " <\($0.prefix(20))>" } ?? ""
            let dur = entry.durationMs.map { " [\($0)ms]" } ?? ""
            out += "[\(entry.formattedTime)] [\(entry.level.rawValue)]\(sess)\(dur) \(entry.message)\n"
        }
        out += "\n"
        return out
    }

    private func buildWebViewLifecycleLog(_ allEntries: [DebugLogEntry]) -> String {
        var out = sectionBanner("WEBVIEW LIFECYCLE EVENTS")
        let wvEntries = allEntries.filter {
            $0.category == .webView ||
            $0.message.contains("WebView") || $0.message.contains("webView") ||
            $0.message.contains("BLANK PAGE") || $0.message.contains("blank page") ||
            $0.message.contains("page load") || $0.message.contains("Page load") ||
            $0.message.contains("redirect") || $0.message.contains("Redirect") ||
            $0.message.contains("crash") || $0.message.contains("terminated") ||
            $0.message.contains("tearDown") || $0.message.contains("setUp")
        }.sorted { $0.timestamp < $1.timestamp }
        if wvEntries.isEmpty {
            out += "  (no webview lifecycle entries)\n\n"
            return out
        }
        for entry in wvEntries.suffix(200) {
            let sess = entry.sessionId.map { " <\($0.prefix(20))>" } ?? ""
            let dur = entry.durationMs.map { " [\($0)ms]" } ?? ""
            let det = entry.detail.map { " | \($0)" } ?? ""
            out += "[\(entry.formattedTime)] [\(entry.level.rawValue)]\(sess)\(dur) \(entry.message)\(det)\n"
        }
        out += "\n"
        return out
    }

    private func buildHealingRetryHistory() -> String {
        var out = sectionBanner("HEALING & RETRY HISTORY")
        let events = logger.errorHealingLog
        if events.isEmpty {
            out += "  (no healing events)\n\n"
            return out
        }
        out += "Total: \(events.count) | Success Rate: \(String(format: "%.0f%%", logger.healingSuccessRate * 100))\n\n"
        for event in events.prefix(100) {
            let status = event.succeeded ? "OK" : "FAIL"
            let dur = event.durationMs.map { " [\($0)ms]" } ?? ""
            let ts = DateFormatters.timeWithMillis.string(from: event.timestamp)
            out += "[\(ts)] [\(status)] [\(event.category.rawValue)] #\(event.attemptNumber)\(dur)\n"
            out += "  action: \(event.healingAction)\n"
            out += "  error:  \(event.originalError)\n"
        }
        if events.count > 100 {
            out += "\n  ... and \(events.count - 100) more healing events (truncated)\n"
        }
        out += "\n"
        return out
    }

    private func buildTimingBreakdown(_ entries: [DebugLogEntry]) -> String {
        var out = sectionBanner("TIMING BREAKDOWN")
        let timedEntries = entries.filter { $0.durationMs != nil }.sorted { $0.timestamp < $1.timestamp }
        if timedEntries.isEmpty {
            out += "  (no timed entries)\n\n"
            return out
        }
        var phaseTimings: [String: [Int]] = [:]
        for entry in timedEntries {
            guard let ms = entry.durationMs else { continue }
            let phase: String
            let msg = entry.message.lowercased()
            if msg.contains("page load") || msg.contains("pageload") || msg.contains("loaded page") { phase = "Page Load" }
            else if msg.contains("field") || msg.contains("readiness") || msg.contains("verification") { phase = "Field Detection" }
            else if msg.contains("typing") || msg.contains("charbychar") || msg.contains("fill") { phase = "Credential Entry" }
            else if msg.contains("submit") || msg.contains("click") { phase = "Submit/Click" }
            else if msg.contains("settlement") || msg.contains("settle") { phase = "Settlement" }
            else if msg.contains("recovery") || msg.contains("heal") { phase = "Healing/Recovery" }
            else if msg.contains("evaluation") || msg.contains("eval") { phase = "Evaluation" }
            else { phase = "Other" }
            phaseTimings[phase, default: []].append(ms)
        }
        out += "Phase Summary:\n"
        for (phase, timings) in phaseTimings.sorted(by: { $0.key < $1.key }) {
            let avg = timings.reduce(0, +) / max(1, timings.count)
            let minT = timings.min() ?? 0
            let maxT = timings.max() ?? 0
            out += "  \(phase): count=\(timings.count) avg=\(avg)ms min=\(minT)ms max=\(maxT)ms\n"
        }
        out += "\nDetailed Timed Events (last 150):\n"
        for entry in timedEntries.suffix(150) {
            let sess = entry.sessionId.map { " <\($0.prefix(16))>" } ?? ""
            out += "  [\(entry.formattedTime)] \(entry.durationMs ?? 0)ms\(sess) [\(entry.category.rawValue)] \(entry.message.prefix(120))\n"
        }
        out += "\n"
        return out
    }

    private func buildNetworkConfigPerSession(_ allEntries: [DebugLogEntry]) -> String {
        var out = sectionBanner("NETWORK CONFIG PER SESSION")
        let netEntries = allEntries.filter {
            ($0.category == .network || $0.category == .proxy || $0.category == .vpn || $0.category == .dns) &&
            $0.sessionId != nil
        }.sorted { $0.timestamp < $1.timestamp }
        if netEntries.isEmpty {
            out += "  (no per-session network entries)\n\n"
            return out
        }
        let grouped = Dictionary(grouping: netEntries) { $0.sessionId ?? "unknown" }
        for (sid, entries) in grouped.sorted(by: { $0.key < $1.key }) {
            out += "── \(sid) ──\n"
            for entry in entries.prefix(10) {
                out += "  [\(entry.formattedTime)] [\(entry.category.rawValue)] \(entry.message)\n"
            }
            if entries.count > 10 {
                out += "  ... +\(entries.count - 10) more\n"
            }
            out += "\n"
        }
        return out
    }

    private func buildCategoryBreakdown(_ entries: [DebugLogEntry]) -> String {
        var out = sectionBanner("AUTOMATION CATEGORY BREAKDOWN")
        var counts: [DebugLogCategory: Int] = [:]
        for entry in entries { counts[entry.category, default: 0] += 1 }
        for (cat, count) in counts.sorted(by: { $0.value > $1.value }) {
            out += "  \(cat.rawValue): \(count)\n"
        }
        out += "\n"
        return out
    }

    private func buildLevelBreakdown(_ entries: [DebugLogEntry]) -> String {
        var out = sectionBanner("AUTOMATION LEVEL BREAKDOWN")
        var counts: [DebugLogLevel: Int] = [:]
        for entry in entries { counts[entry.level, default: 0] += 1 }
        for (level, count) in counts.sorted(by: { $0.key < $1.key }) {
            out += "  \(level.emoji) \(level.rawValue): \(count)\n"
        }
        out += "\n"
        return out
    }

    private func buildFullAutomationLog(_ entries: [DebugLogEntry]) -> String {
        var out = sectionBanner("FULL AUTOMATION LOG (last 500)")
        let recent = entries.sorted { $0.timestamp > $1.timestamp }.prefix(500)
        for entry in recent {
            out += entry.exportLine + "\n"
        }
        out += "\n"
        return out
    }

    // MARK: - Helpers

    private func sectionBanner(_ title: String) -> String {
        let line = String(repeating: "=", count: 60)
        return "\(line)\n\(title)\n\(line)\n"
    }
}

extension DateFormatters {
    nonisolated(unsafe) static let fileTimestamp: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd_HHmmss"
        return f
    }()
}
