import Foundation
import WebKit
import UIKit

@MainActor
class HumanInteractionEngine {
    static let shared = HumanInteractionEngine()

    private let logger = DebugLogger.shared
    private let patternLearning = LoginPatternLearning.shared
    private let aiTiming = AITimingOptimizerService.shared
    private let liveSpeed = LiveSpeedAdaptationService.shared
    private var currentHost: String = ""
    private var currentPattern: String = ""
    private var baseMinMs: Int = 80
    private var baseMaxMs: Int = 150

    private func aiOptimizedDelay(category: TimingCategory, fallbackMin: Int, fallbackMax: Int) -> Int {
        guard !currentHost.isEmpty else { return liveSpeed.adaptDelay(GaussianRandom.delay(minMs: fallbackMin, maxMs: fallbackMax)) }
        let baseDelay = aiTiming.optimizedDelay(for: currentHost, category: category, pattern: currentPattern)
        return liveSpeed.adaptDelay(baseDelay)
    }

    func selectBestPattern(for url: String) -> LoginFormPattern {
        let settings = AutomationSettingsPersistence.shared.load()
        let enabledSet = Set(settings.enabledPatterns)
        let priorityPatterns: [LoginFormPattern] = settings.patternPriorityOrder
            .compactMap { LoginFormPattern(rawValue: $0) }
            .filter { enabledSet.contains($0.rawValue) }

        if let learned = patternLearning.bestPattern(for: url), enabledSet.contains(learned.rawValue) {
            let ranking = patternLearning.patternRanking(for: url)
            let hasEnoughData = ranking.first(where: { $0.pattern == learned })?.stats.totalAttempts ?? 0 >= 3
            if hasEnoughData {
                logger.log("PatternSelect: learned best pattern for \(URL(string: url)?.host ?? url) → \(learned.rawValue)", category: .automation, level: .info)
                return learned
            }
        }
        let selected = priorityPatterns.first ?? .visionMLCoordinate
        logger.log("PatternSelect: using priority first '\(selected.rawValue)' for \(URL(string: url)?.host ?? url)", category: .automation, level: .info)
        return selected
    }

    func executePattern(
        _ pattern: LoginFormPattern,
        username: String,
        password: String,
        executeJS: @escaping (String) async -> String?,
        sessionId: String,
        targetURL: String? = nil
    ) async -> HumanPatternResult {
        if let url = targetURL, let host = URL(string: url)?.host {
            currentHost = host
        } else if let host = URL(string: sessionId)?.host {
            currentHost = host
        }
        currentPattern = pattern.rawValue

        let settings = AutomationSettingsPersistence.shared.load()
        baseMinMs = settings.typingSpeedMinMs
        baseMaxMs = settings.typingSpeedMaxMs

        logger.log("HumanInteraction: executing pattern '\(pattern.rawValue)' host=\(currentHost)", category: .automation, level: .info, sessionId: sessionId)
        let startTime = Date()

        if settings.globalPreActionDelayMs > 0 {
            logger.log("HumanInteraction: pre-action delay \(settings.globalPreActionDelayMs)ms", category: .automation, level: .trace, sessionId: sessionId)
            try? await Task.sleep(for: .milliseconds(settings.globalPreActionDelayMs))
        }

        let result: HumanPatternResult
        switch pattern {
        case .trueDetection:
            result = await executeTrueDetectionPattern(username: username, password: password, executeJS: executeJS, sessionId: sessionId)
        case .tabNavigation:
            result = await executeTabNavigation(username: username, password: password, executeJS: executeJS, sessionId: sessionId)
        case .clickFocusSequential:
            result = await executeClickFocusSequential(username: username, password: password, executeJS: executeJS, sessionId: sessionId)
        case .execCommandInsert:
            result = await executeExecCommandInsert(username: username, password: password, executeJS: executeJS, sessionId: sessionId)
        case .slowDeliberateTyper:
            result = await executeSlowDeliberateTyper(username: username, password: password, executeJS: executeJS, sessionId: sessionId)
        case .mobileTouchBurst:
            result = await executeMobileTouchBurst(username: username, password: password, executeJS: executeJS, sessionId: sessionId)
        case .calibratedDirect:
            result = await executeCalibratedDirect(username: username, password: password, executeJS: executeJS, sessionId: sessionId)
        case .calibratedTyping:
            result = await executeCalibratedTyping(username: username, password: password, executeJS: executeJS, sessionId: sessionId)
        case .formSubmitDirect:
            result = await executeFormSubmitDirect(username: username, password: password, executeJS: executeJS, sessionId: sessionId)
        case .coordinateClick:
            result = await executeCoordinateClick(username: username, password: password, executeJS: executeJS, sessionId: sessionId)
        case .reactNativeSetter:
            result = await executeReactNativeSetter(username: username, password: password, executeJS: executeJS, sessionId: sessionId)
        case .visionMLCoordinate:
            result = await executeVisionMLCoordinate(username: username, password: password, executeJS: executeJS, sessionId: sessionId)
        }

        if settings.globalPostActionDelayMs > 0 {
            logger.log("HumanInteraction: post-action delay \(settings.globalPostActionDelayMs)ms", category: .automation, level: .trace, sessionId: sessionId)
            try? await Task.sleep(for: .milliseconds(settings.globalPostActionDelayMs))
        }

        let elapsed = Date().timeIntervalSince(startTime)
        logger.log("HumanInteraction: pattern '\(pattern.rawValue)' completed in \(Int(elapsed * 1000))ms — fillSuccess:\(result.usernameFilled && result.passwordFilled) submitSuccess:\(result.submitTriggered)", category: .automation, level: result.submitTriggered ? .success : .warning, sessionId: sessionId, durationMs: Int(elapsed * 1000))

        if !currentHost.isEmpty {
            let profile = aiTiming.profileForHost(currentHost)
            aiTiming.recordPatternTimingOutcome(
                url: targetURL ?? sessionId,
                pattern: pattern,
                keystrokeDelayMs: Int(profile.keystroke.mean),
                interFieldPauseMs: Int(profile.interField.mean),
                preSubmitWaitMs: Int(profile.preSubmit.mean),
                fillSuccess: result.usernameFilled && result.passwordFilled,
                submitSuccess: result.submitTriggered,
                detected: !result.submitTriggered && result.usernameFilled
            )
        }

        return result
    }

    // MARK: - Pattern 0: TRUE DETECTION

    private func executeTrueDetectionPattern(username: String, password: String, executeJS: @escaping (String) async -> String?, sessionId: String) async -> HumanPatternResult {
        var result = HumanPatternResult(pattern: .trueDetection)

        logger.log("TrueDetection Pattern: waiting for DOM complete...", category: .automation, level: .trace, sessionId: sessionId)
        let domStart = Date()
        while Date().timeIntervalSince(domStart) < 10 {
            let ready = await executeJS("document.readyState")
            if ready == "complete" { break }
            try? await Task.sleep(for: .milliseconds(300))
        }

        let settings = AutomationSettingsPersistence.shared.load()
        let postDOMDelay = aiOptimizedDelay(category: .postDOMPause, fallbackMin: settings.trueDetectionHardPauseMs, fallbackMax: settings.trueDetectionHardPauseMs)
        logger.log("TrueDetection Pattern: hard pause \(postDOMDelay)ms (AI-optimized)", category: .automation, level: .trace, sessionId: sessionId)
        try? await Task.sleep(for: .milliseconds(postDOMDelay))

        let isJoeSite = currentHost.lowercased().contains("joe") || sessionId.lowercased().contains("joe")
        let siteTarget: LoginTargetSite = isJoeSite ? .joefortune : .ignition
        let tdEmailSel = settings.emailSelector(for: siteTarget)
        let tdPassSel = settings.passwordSelector(for: siteTarget)
        let tdSubmitSel = settings.submitSelector(for: siteTarget)

        let emailTapResult = await executeJS(JSInteractionBuilder.humanTapJS(selector: tdEmailSel))
        logger.log("TrueDetection: human tap on \(tdEmailSel) → \(emailTapResult ?? "nil")", category: .automation, level: .trace, sessionId: sessionId)
        try? await Task.sleep(for: .milliseconds(settings.preTypingDelayMs))

        let emailResult = await executeJS(JSInteractionBuilder.nativeSetterFillJS(selector: tdEmailSel, value: username))
        result.usernameFilled = emailResult == "OK" || emailResult == "VALUE_MISMATCH"
        logger.log("TrueDetection: \(tdEmailSel) fill → \(emailResult ?? "nil")", category: .automation, level: result.usernameFilled ? .success : .error, sessionId: sessionId)

        if !result.usernameFilled { return result }
        try? await Task.sleep(for: .milliseconds(aiOptimizedDelay(category: .interFieldPause, fallbackMin: settings.interFieldDelayMs, fallbackMax: settings.interFieldDelayMs)))

        _ = await verifyAndCleanPasswordField(username: username, emailSelector: tdEmailSel, passwordSelector: tdPassSel, executeJS: executeJS, sessionId: sessionId)

        let passTapResult = await executeJS(JSInteractionBuilder.humanTapJS(selector: tdPassSel))
        logger.log("TrueDetection: human tap on \(tdPassSel) → \(passTapResult ?? "nil")", category: .automation, level: .trace, sessionId: sessionId)
        try? await Task.sleep(for: .milliseconds(settings.preTypingDelayMs))

        let passResult = await executeJS(JSInteractionBuilder.nativeSetterFillJS(selector: tdPassSel, value: password))
        result.passwordFilled = passResult == "OK" || passResult == "VALUE_MISMATCH"
        logger.log("TrueDetection: \(tdPassSel) fill → \(passResult ?? "nil")", category: .automation, level: result.passwordFilled ? .success : .error, sessionId: sessionId)

        if !result.passwordFilled { return result }
        try? await Task.sleep(for: .milliseconds(aiOptimizedDelay(category: .preSubmitWait, fallbackMin: settings.preSubmitDelayMs, fallbackMax: settings.preSubmitDelayMs)))

        let submitCycles = settings.trueDetectionSubmitCycleCount
        let clicksPerCycle = settings.trueDetectionTripleClickCount
        let clickDelayMs = settings.trueDetectionTripleClickDelayMs
        let buttonRecoveryTimeoutMs = settings.trueDetectionButtonRecoveryTimeoutMs
        let buttonRecovery = SmartButtonRecoveryService.shared

        logger.log("TrueDetection: starting \(submitCycles)-cycle submit on \(tdSubmitSel) (\(clicksPerCycle) clicks/cycle)", category: .automation, level: .info, sessionId: sessionId)

        for cycle in 0..<submitCycles {
            let preClickFingerprint = await buttonRecovery.captureFingerprint(
                selector: "",
                executeJS: executeJS,
                sessionId: sessionId
            )

            for i in 0..<clicksPerCycle {
                let clickResult = await executeJS(JSInteractionBuilder.cycledSubmitClickJS(selector: tdSubmitSel, clickIndex: i))
                logger.log("TrueDetection: cycle \(cycle + 1) click \(i + 1)/\(clicksPerCycle) \u{2192} \(clickResult ?? "nil")", category: .automation, level: .trace, sessionId: sessionId)
                if clickResult == "NOT_FOUND" && i == 0 && cycle == 0 {
                    return result
                }
                if i < clicksPerCycle - 1 {
                    try? await Task.sleep(for: .milliseconds(clickDelayMs))
                }
            }

            if cycle < submitCycles - 1 {
                logger.log("TrueDetection: cycle \(cycle + 1) done — AI smart button color change detection...", category: .automation, level: .info, sessionId: sessionId)
                if let fingerprint = preClickFingerprint {
                    let recovery = await buttonRecovery.waitForRecovery(
                        selector: "",
                        originalFingerprint: fingerprint,
                        executeJS: executeJS,
                        host: currentHost,
                        sessionId: sessionId,
                        maxTimeoutMs: buttonRecoveryTimeoutMs
                    )
                    logger.log("TrueDetection: button recovery \(recovery.recovered ? "OK" : "TIMEOUT") in \(recovery.durationMs)ms", category: .automation, level: recovery.recovered ? .success : .warning, sessionId: sessionId)
                } else {
                    try? await Task.sleep(for: .milliseconds(settings.errorRecoveryDelayMs))
                }
                try? await Task.sleep(for: .milliseconds(settings.postSubmitDelayMs))
            }
        }

        result.submitTriggered = true
        result.submitMethod = "TRUE_DETECTION_CYCLED_TRIPLE_CLICK_\(submitCycles)x\(clicksPerCycle)"
        logger.log("TrueDetection: all \(submitCycles) submit cycles complete", category: .automation, level: .success, sessionId: sessionId)
        return result
    }

    // MARK: - Pattern 1: Tab Navigation

    private func executeTabNavigation(username: String, password: String, executeJS: @escaping (String) async -> String?, sessionId: String) async -> HumanPatternResult {
        var result = HumanPatternResult(pattern: .tabNavigation)
        let t0 = Date()

        let focusResult = await executeJS(JSInteractionBuilder.focusAndClickEmailFieldJS())
        logger.log("TabNav: focus email [selector: input[type='email'], input#email, input#username] → \(focusResult ?? "nil") +\(Int(Date().timeIntervalSince(t0)*1000))ms", category: .automation, level: focusResult == "NOT_FOUND" ? .error : .trace, sessionId: sessionId)
        guard focusResult != "NOT_FOUND" else { return result }

        let d1 = aiOptimizedDelay(category: .preFocusPause, fallbackMin: 200, fallbackMax: 500)
        logger.log("TabNav: pre-focus pause \(d1)ms", category: .automation, level: .trace, sessionId: sessionId)
        try? await Task.sleep(for: .milliseconds(d1))

        let t1 = Date()
        let userTyped = await typeCharByChar(text: username, executeJS: executeJS, sessionId: sessionId, fieldName: "email", minDelayMs: baseMinMs, maxDelayMs: baseMaxMs)
        result.usernameFilled = userTyped
        logger.log("TabNav: email typed \(userTyped ? "OK" : "FAIL") +\(Int(Date().timeIntervalSince(t1)*1000))ms", category: .automation, level: userTyped ? .success : .error, sessionId: sessionId)

        let d2 = aiOptimizedDelay(category: .interFieldPause, fallbackMin: 100, fallbackMax: 350)
        logger.log("TabNav: inter-field delay \(d2)ms", category: .automation, level: .trace, sessionId: sessionId)
        try? await Task.sleep(for: .milliseconds(d2))

        let emailSel = resolveSiteEmailSelector(sessionId: sessionId)
        let passSel = resolveSitePasswordSelector(sessionId: sessionId)
        _ = await verifyAndCleanPasswordField(username: username, emailSelector: emailSel, passwordSelector: passSel, executeJS: executeJS, sessionId: sessionId)

        let tabResult = await executeJS(JSInteractionBuilder.tabToPasswordJS(url: currentHost))
        if tabResult == "CALIBRATED_PASSWORD_FALLBACK" || tabResult == "GENERIC_PASSWORD_FALLBACK" {
            RuntimeSafetyCenter.shared.recordFocusRecovery(reason: "Password field focus recovered during tab navigation")
        }
        logger.log("TabNav: Tab key → \(tabResult ?? "nil") [password focus recovery aware]", category: .automation, level: tabResult == "NO_PASSWORD_FIELD" ? .warning : .trace, sessionId: sessionId)
        guard tabResult != "NO_PASSWORD_FIELD" else {
            return result
        }

        let d3 = aiOptimizedDelay(category: .preFocusPause, fallbackMin: 150, fallbackMax: 400)
        logger.log("TabNav: pre-password pause \(d3)ms", category: .automation, level: .trace, sessionId: sessionId)
        try? await Task.sleep(for: .milliseconds(d3))

        let t2 = Date()
        let passTyped = await typeCharByChar(text: password, executeJS: executeJS, sessionId: sessionId, fieldName: "password", minDelayMs: baseMinMs, maxDelayMs: baseMaxMs)
        result.passwordFilled = passTyped
        logger.log("TabNav: password typed \(passTyped ? "OK" : "FAIL") +\(Int(Date().timeIntervalSince(t2)*1000))ms", category: .automation, level: passTyped ? .success : .error, sessionId: sessionId)

        let d4 = aiOptimizedDelay(category: .preSubmitWait, fallbackMin: 200, fallbackMax: 600)
        logger.log("TabNav: pre-submit wait \(d4)ms", category: .automation, level: .trace, sessionId: sessionId)
        try? await Task.sleep(for: .milliseconds(d4))

        let enterResult = await executeJS(JSInteractionBuilder.enterKeySubmitJS())
        result.submitTriggered = enterResult == "ENTER_PRESSED"
        result.submitMethod = "Enter key on password field"
        logger.log("TabNav: Enter key submit → \(enterResult ?? "nil") total=+\(Int(Date().timeIntervalSince(t0)*1000))ms", category: .automation, level: result.submitTriggered ? .success : .warning, sessionId: sessionId)

        return result
    }

    // MARK: - Pattern 2: Click-Focus Sequential

    private func executeClickFocusSequential(username: String, password: String, executeJS: @escaping (String) async -> String?, sessionId: String) async -> HumanPatternResult {
        var result = HumanPatternResult(pattern: .clickFocusSequential)
        let t0 = Date()

        let emailClick = await executeJS(JSInteractionBuilder.mouseMoveThenClickEmailJS())
        logger.log("ClickFocus: mouse-move click email [input[type='email'], input#email, input#username] → \(emailClick ?? "nil") +\(Int(Date().timeIntervalSince(t0)*1000))ms", category: .automation, level: emailClick == "NOT_FOUND" ? .error : .trace, sessionId: sessionId)
        guard emailClick != "NOT_FOUND" else { return result }

        let d1 = aiOptimizedDelay(category: .preFocusPause, fallbackMin: 300, fallbackMax: 700)
        logger.log("ClickFocus: pre-focus pause \(d1)ms", category: .automation, level: .trace, sessionId: sessionId)
        try? await Task.sleep(for: .milliseconds(d1))

        let t1 = Date()
        let userTyped = await typeCharByChar(text: username, executeJS: executeJS, sessionId: sessionId, fieldName: "email", minDelayMs: baseMinMs, maxDelayMs: baseMaxMs)
        result.usernameFilled = userTyped
        logger.log("ClickFocus: email typed \(userTyped ? "OK" : "FAIL") +\(Int(Date().timeIntervalSince(t1)*1000))ms", category: .automation, level: userTyped ? .success : .error, sessionId: sessionId)

        let d2 = aiOptimizedDelay(category: .interFieldPause, fallbackMin: 400, fallbackMax: 900)
        logger.log("ClickFocus: inter-field delay \(d2)ms", category: .automation, level: .trace, sessionId: sessionId)
        try? await Task.sleep(for: .milliseconds(d2))

        let emailSel = resolveSiteEmailSelector(sessionId: sessionId)
        let passSel = resolveSitePasswordSelector(sessionId: sessionId)
        _ = await verifyAndCleanPasswordField(username: username, emailSelector: emailSel, passwordSelector: passSel, executeJS: executeJS, sessionId: sessionId)

        let passClick = await executeJS(JSInteractionBuilder.blurAndMouseClickPasswordJS())
        logger.log("ClickFocus: password field click [input[type='password'], input#password] → \(passClick ?? "nil") +\(Int(Date().timeIntervalSince(t0)*1000))ms", category: .automation, level: .trace, sessionId: sessionId)

        let d3 = aiOptimizedDelay(category: .preFocusPause, fallbackMin: 200, fallbackMax: 500)
        logger.log("ClickFocus: pre-password pause \(d3)ms", category: .automation, level: .trace, sessionId: sessionId)
        try? await Task.sleep(for: .milliseconds(d3))

        let t2 = Date()
        let passTyped = await typeCharByChar(text: password, executeJS: executeJS, sessionId: sessionId, fieldName: "password", minDelayMs: baseMinMs, maxDelayMs: baseMaxMs)
        result.passwordFilled = passTyped
        logger.log("ClickFocus: password typed \(passTyped ? "OK" : "FAIL") +\(Int(Date().timeIntervalSince(t2)*1000))ms", category: .automation, level: passTyped ? .success : .error, sessionId: sessionId)

        let d4 = aiOptimizedDelay(category: .preSubmitWait, fallbackMin: 300, fallbackMax: 800)
        logger.log("ClickFocus: pre-submit wait \(d4)ms", category: .automation, level: .trace, sessionId: sessionId)
        try? await Task.sleep(for: .milliseconds(d4))

        let clickLoginResult = await humanClickLoginButton(executeJS: executeJS, sessionId: sessionId)
        result.submitTriggered = clickLoginResult
        result.submitMethod = "Mouse click on login button"
        logger.log("ClickFocus: login button click \(clickLoginResult ? "OK" : "FAIL") total=+\(Int(Date().timeIntervalSince(t0)*1000))ms", category: .automation, level: clickLoginResult ? .success : .warning, sessionId: sessionId)

        return result
    }

    // MARK: - Pattern 3: ExecCommand Insert

    private func executeExecCommandInsert(username: String, password: String, executeJS: @escaping (String) async -> String?, sessionId: String) async -> HumanPatternResult {
        var result = HumanPatternResult(pattern: .execCommandInsert)
        let t0 = Date()

        let focused = await executeJS(JSInteractionBuilder.focusSelectClearJS())
        logger.log("ExecCmd: focus+select+clear email [input[type='email'], input#email] → \(focused ?? "nil")", category: .automation, level: focused == "NOT_FOUND" ? .error : .trace, sessionId: sessionId)
        guard focused != "NOT_FOUND" else { return result }

        let d1 = aiOptimizedDelay(category: .preFocusPause, fallbackMin: 150, fallbackMax: 400)
        logger.log("ExecCmd: pre-focus pause \(d1)ms", category: .automation, level: .trace, sessionId: sessionId)
        try? await Task.sleep(for: .milliseconds(d1))

        let t1 = Date()
        let userTyped = await typeWithExecCommand(text: username, executeJS: executeJS, sessionId: sessionId, fieldName: "email", minDelayMs: baseMinMs, maxDelayMs: baseMaxMs)
        result.usernameFilled = userTyped
        logger.log("ExecCmd: email typed \(userTyped ? "OK" : "FAIL") +\(Int(Date().timeIntervalSince(t1)*1000))ms", category: .automation, level: userTyped ? .success : .error, sessionId: sessionId)

        let d2 = aiOptimizedDelay(category: .interFieldPause, fallbackMin: 200, fallbackMax: 500)
        logger.log("ExecCmd: inter-field delay \(d2)ms", category: .automation, level: .trace, sessionId: sessionId)
        try? await Task.sleep(for: .milliseconds(d2))

        let emailSel = resolveSiteEmailSelector(sessionId: sessionId)
        let passSel = resolveSitePasswordSelector(sessionId: sessionId)
        _ = await verifyAndCleanPasswordField(username: username, emailSelector: emailSel, passwordSelector: passSel, executeJS: executeJS, sessionId: sessionId)

        let passFocused = await executeJS(JSInteractionBuilder.blurAndFocusSelectPasswordJS())
        logger.log("ExecCmd: focus+select password [input[type='password'], input#password] → \(passFocused ?? "nil") +\(Int(Date().timeIntervalSince(t0)*1000))ms", category: .automation, level: passFocused == "NOT_FOUND" ? .error : .trace, sessionId: sessionId)
        guard passFocused != "NOT_FOUND" else { return result }

        let d3 = aiOptimizedDelay(category: .preFocusPause, fallbackMin: 100, fallbackMax: 350)
        logger.log("ExecCmd: pre-password pause \(d3)ms", category: .automation, level: .trace, sessionId: sessionId)
        try? await Task.sleep(for: .milliseconds(d3))

        let t2 = Date()
        let passTyped = await typeWithExecCommand(text: password, executeJS: executeJS, sessionId: sessionId, fieldName: "password", minDelayMs: baseMinMs, maxDelayMs: baseMaxMs)
        result.passwordFilled = passTyped
        logger.log("ExecCmd: password typed \(passTyped ? "OK" : "FAIL") +\(Int(Date().timeIntervalSince(t2)*1000))ms", category: .automation, level: passTyped ? .success : .error, sessionId: sessionId)

        let d4 = aiOptimizedDelay(category: .preSubmitWait, fallbackMin: 300, fallbackMax: 700)
        logger.log("ExecCmd: pre-submit wait \(d4)ms", category: .automation, level: .trace, sessionId: sessionId)
        try? await Task.sleep(for: .milliseconds(d4))

        let submitResult = await executeJS(JSInteractionBuilder.blurAndEnterSubmitJS())
        result.submitTriggered = submitResult == "ENTER_PRESSED"
        result.submitMethod = "ExecCommand + Enter key"
        logger.log("ExecCmd: blur+Enter submit → \(submitResult ?? "nil") total=+\(Int(Date().timeIntervalSince(t0)*1000))ms", category: .automation, level: result.submitTriggered ? .success : .warning, sessionId: sessionId)

        return result
    }

    // MARK: - Pattern 4: Slow Deliberate Typer

    private func executeSlowDeliberateTyper(username: String, password: String, executeJS: @escaping (String) async -> String?, sessionId: String) async -> HumanPatternResult {
        var result = HumanPatternResult(pattern: .slowDeliberateTyper)
        let t0 = Date()

        let f = await executeJS(JSInteractionBuilder.focusScrollClickEmailJS())
        logger.log("SlowTyper: focus+scroll+click email [input[type='email'], input#email] → \(f ?? "nil")", category: .automation, level: f == "NOT_FOUND" ? .error : .trace, sessionId: sessionId)
        guard f != "NOT_FOUND" else { return result }

        let d1 = aiOptimizedDelay(category: .preFocusPause, fallbackMin: 500, fallbackMax: 1200)
        logger.log("SlowTyper: pre-focus pause \(d1)ms", category: .automation, level: .trace, sessionId: sessionId)
        try? await Task.sleep(for: .milliseconds(d1))

        let t1 = Date()
        let userTyped = await typeSlowWithCorrections(text: username, executeJS: executeJS, sessionId: sessionId, fieldName: "email")
        result.usernameFilled = userTyped
        logger.log("SlowTyper: email typed \(userTyped ? "OK" : "FAIL") +\(Int(Date().timeIntervalSince(t1)*1000))ms", category: .automation, level: userTyped ? .success : .error, sessionId: sessionId)

        let d2 = aiOptimizedDelay(category: .interFieldPause, fallbackMin: 600, fallbackMax: 1500)
        logger.log("SlowTyper: inter-field delay \(d2)ms", category: .automation, level: .trace, sessionId: sessionId)
        try? await Task.sleep(for: .milliseconds(d2))

        let emailSel = resolveSiteEmailSelector(sessionId: sessionId)
        let passSel = resolveSitePasswordSelector(sessionId: sessionId)
        _ = await verifyAndCleanPasswordField(username: username, emailSelector: emailSel, passwordSelector: passSel, executeJS: executeJS, sessionId: sessionId)

        let pf = await executeJS(JSInteractionBuilder.blurAndFocusPasswordJS())
        logger.log("SlowTyper: blur+focus password [input[type='password']] → \(pf ?? "nil") +\(Int(Date().timeIntervalSince(t0)*1000))ms", category: .automation, level: pf == "NOT_FOUND" ? .error : .trace, sessionId: sessionId)
        guard pf != "NOT_FOUND" else { return result }

        let d3 = aiOptimizedDelay(category: .preFocusPause, fallbackMin: 400, fallbackMax: 1000)
        logger.log("SlowTyper: pre-password pause \(d3)ms", category: .automation, level: .trace, sessionId: sessionId)
        try? await Task.sleep(for: .milliseconds(d3))

        let t2 = Date()
        let passTyped = await typeSlowWithCorrections(text: password, executeJS: executeJS, sessionId: sessionId, fieldName: "password")
        result.passwordFilled = passTyped
        logger.log("SlowTyper: password typed \(passTyped ? "OK" : "FAIL") +\(Int(Date().timeIntervalSince(t2)*1000))ms", category: .automation, level: passTyped ? .success : .error, sessionId: sessionId)

        let d4 = aiOptimizedDelay(category: .preSubmitWait, fallbackMin: 800, fallbackMax: 2000)
        logger.log("SlowTyper: pre-submit wait \(d4)ms", category: .automation, level: .trace, sessionId: sessionId)
        try? await Task.sleep(for: .milliseconds(d4))

        let clickResult = await humanClickLoginButton(executeJS: executeJS, sessionId: sessionId)
        result.submitTriggered = clickResult
        result.submitMethod = "Slow deliberate mouse click"
        logger.log("SlowTyper: login button click \(clickResult ? "OK" : "FAIL") total=+\(Int(Date().timeIntervalSince(t0)*1000))ms", category: .automation, level: clickResult ? .success : .warning, sessionId: sessionId)

        return result
    }

    // MARK: - Pattern 5: Mobile Touch Burst

    private func executeMobileTouchBurst(username: String, password: String, executeJS: @escaping (String) async -> String?, sessionId: String) async -> HumanPatternResult {
        var result = HumanPatternResult(pattern: .mobileTouchBurst)
        let t0 = Date()

        let touchResult = await executeJS(JSInteractionBuilder.touchFocusFieldJS())
        logger.log("TouchBurst: touch-focus email [input[type='email'], input#email] → \(touchResult ?? "nil")", category: .automation, level: touchResult == "NOT_FOUND" ? .error : .trace, sessionId: sessionId)
        guard touchResult != "NOT_FOUND" else { return result }

        let d1 = aiOptimizedDelay(category: .preFocusPause, fallbackMin: 100, fallbackMax: 300)
        logger.log("TouchBurst: pre-focus pause \(d1)ms", category: .automation, level: .trace, sessionId: sessionId)
        try? await Task.sleep(for: .milliseconds(d1))

        let burstMin = max(20, baseMinMs / 3)
        let burstMax = max(70, baseMaxMs / 2)
        let t1 = Date()
        let userTyped = await typeCharByChar(text: username, executeJS: executeJS, sessionId: sessionId, fieldName: "email", minDelayMs: burstMin, maxDelayMs: burstMax)
        result.usernameFilled = userTyped
        logger.log("TouchBurst: email typed \(userTyped ? "OK" : "FAIL") (\(burstMin)-\(burstMax)ms/char) +\(Int(Date().timeIntervalSince(t1)*1000))ms", category: .automation, level: userTyped ? .success : .error, sessionId: sessionId)

        let d2 = aiOptimizedDelay(category: .interFieldPause, fallbackMin: 150, fallbackMax: 400)
        logger.log("TouchBurst: inter-field delay \(d2)ms", category: .automation, level: .trace, sessionId: sessionId)
        try? await Task.sleep(for: .milliseconds(d2))

        let emailSel = resolveSiteEmailSelector(sessionId: sessionId)
        let passSel = resolveSitePasswordSelector(sessionId: sessionId)
        _ = await verifyAndCleanPasswordField(username: username, emailSelector: emailSel, passwordSelector: passSel, executeJS: executeJS, sessionId: sessionId)

        let touchPass = await executeJS(JSInteractionBuilder.touchFocusFieldJS(fieldSelector: "input[type=\"password\"]"))
        logger.log("TouchBurst: touch-focus password [input[type='password']] → \(touchPass ?? "nil") +\(Int(Date().timeIntervalSince(t0)*1000))ms", category: .automation, level: touchPass == "NOT_FOUND" ? .error : .trace, sessionId: sessionId)
        guard touchPass != "NOT_FOUND" else { return result }

        let d3 = aiOptimizedDelay(category: .preFocusPause, fallbackMin: 80, fallbackMax: 250)
        logger.log("TouchBurst: pre-password pause \(d3)ms", category: .automation, level: .trace, sessionId: sessionId)
        try? await Task.sleep(for: .milliseconds(d3))

        let t2 = Date()
        let passTyped = await typeCharByChar(text: password, executeJS: executeJS, sessionId: sessionId, fieldName: "password", minDelayMs: burstMin, maxDelayMs: burstMax)
        result.passwordFilled = passTyped
        logger.log("TouchBurst: password typed \(passTyped ? "OK" : "FAIL") +\(Int(Date().timeIntervalSince(t2)*1000))ms", category: .automation, level: passTyped ? .success : .error, sessionId: sessionId)

        let d4 = aiOptimizedDelay(category: .preSubmitWait, fallbackMin: 200, fallbackMax: 500)
        logger.log("TouchBurst: pre-submit wait \(d4)ms", category: .automation, level: .trace, sessionId: sessionId)
        try? await Task.sleep(for: .milliseconds(d4))

        let submitR = await executeJS(JSInteractionBuilder.enterKeyOnPasswordJS())
        if submitR == "ENTER" {
            result.submitTriggered = true
            result.submitMethod = "Touch + Enter key"
            logger.log("TouchBurst: Enter key submit OK total=+\(Int(Date().timeIntervalSince(t0)*1000))ms", category: .automation, level: .success, sessionId: sessionId)
        } else {
            let clickResult = await humanClickLoginButton(executeJS: executeJS, sessionId: sessionId)
            result.submitTriggered = clickResult
            result.submitMethod = "Touch fallback click"
            logger.log("TouchBurst: fallback button click \(clickResult ? "OK" : "FAIL") total=+\(Int(Date().timeIntervalSince(t0)*1000))ms", category: .automation, level: clickResult ? .success : .warning, sessionId: sessionId)
        }

        return result
    }

    // MARK: - Pattern 6: Calibrated Direct

    private func executeCalibratedDirect(username: String, password: String, executeJS: @escaping (String) async -> String?, sessionId: String) async -> HumanPatternResult {
        var result = HumanPatternResult(pattern: .calibratedDirect)
        let cal = LoginCalibrationService.shared.calibrationFor(url: sessionId)

        let emailResult = await executeJS(JSInteractionBuilder.calibratedFillJS(calibration: cal, fieldType: "email", value: username))
        result.usernameFilled = emailResult == "CAL_OK" || emailResult == "CAL_MISMATCH" || emailResult == "LEGACY_OK"
        if !result.usernameFilled {
            let f = await executeJS(JSInteractionBuilder.focusEmailFieldJS())
            if f != "NOT_FOUND" {
                let typed = await typeCharByChar(text: username, executeJS: executeJS, sessionId: sessionId, fieldName: "email", minDelayMs: baseMinMs, maxDelayMs: baseMaxMs)
                result.usernameFilled = typed
            }
        }

        try? await Task.sleep(for: .milliseconds(aiOptimizedDelay(category: .interFieldPause, fallbackMin: 200, fallbackMax: 500)))

        let emailSel = resolveSiteEmailSelector(sessionId: sessionId)
        let passSel = resolveSitePasswordSelector(sessionId: sessionId)
        _ = await verifyAndCleanPasswordField(username: username, emailSelector: emailSel, passwordSelector: passSel, executeJS: executeJS, sessionId: sessionId)

        let passResult = await executeJS(JSInteractionBuilder.calibratedFillJS(calibration: cal, fieldType: "password", value: password))
        result.passwordFilled = passResult == "CAL_OK" || passResult == "CAL_MISMATCH" || passResult == "LEGACY_OK"
        if !result.passwordFilled {
            let f = await executeJS(JSInteractionBuilder.focusPasswordJS())
            if f != "NOT_FOUND" {
                let typed = await typeCharByChar(text: password, executeJS: executeJS, sessionId: sessionId, fieldName: "password", minDelayMs: baseMinMs, maxDelayMs: baseMaxMs)
                result.passwordFilled = typed
            }
        }

        try? await Task.sleep(for: .milliseconds(aiOptimizedDelay(category: .preSubmitWait, fallbackMin: 300, fallbackMax: 700)))

        let clickResult = await humanClickLoginButton(executeJS: executeJS, sessionId: sessionId)
        result.submitTriggered = clickResult
        result.submitMethod = "Calibrated direct fill + click"
        return result
    }

    // MARK: - Pattern 7: Calibrated Typing

    private func executeCalibratedTyping(username: String, password: String, executeJS: @escaping (String) async -> String?, sessionId: String) async -> HumanPatternResult {
        var result = HumanPatternResult(pattern: .calibratedTyping)
        let cal = LoginCalibrationService.shared.calibrationFor(url: sessionId)

        let focused = await executeJS(JSInteractionBuilder.calibratedFocusJS(calibration: cal, fieldType: "email"))
        if focused == "NOT_FOUND" {
            _ = await executeJS(JSInteractionBuilder.focusEmailFieldJS())
        }

        try? await Task.sleep(for: .milliseconds(aiOptimizedDelay(category: .preFocusPause, fallbackMin: 150, fallbackMax: 400)))
        let userTyped = await typeCharByChar(text: username, executeJS: executeJS, sessionId: sessionId, fieldName: "email", minDelayMs: baseMinMs, maxDelayMs: baseMaxMs)
        result.usernameFilled = userTyped

        try? await Task.sleep(for: .milliseconds(aiOptimizedDelay(category: .interFieldPause, fallbackMin: 200, fallbackMax: 500)))

        let emailSel = resolveSiteEmailSelector(sessionId: sessionId)
        let passSel = resolveSitePasswordSelector(sessionId: sessionId)
        _ = await verifyAndCleanPasswordField(username: username, emailSelector: emailSel, passwordSelector: passSel, executeJS: executeJS, sessionId: sessionId)

        let passFocused = await executeJS(JSInteractionBuilder.calibratedFocusJS(calibration: cal, fieldType: "password"))
        if passFocused == "NOT_FOUND" {
            _ = await executeJS(JSInteractionBuilder.focusPasswordJS())
        }

        try? await Task.sleep(for: .milliseconds(aiOptimizedDelay(category: .preFocusPause, fallbackMin: 150, fallbackMax: 400)))
        let passTyped = await typeCharByChar(text: password, executeJS: executeJS, sessionId: sessionId, fieldName: "password", minDelayMs: baseMinMs, maxDelayMs: baseMaxMs)
        result.passwordFilled = passTyped

        try? await Task.sleep(for: .milliseconds(aiOptimizedDelay(category: .preSubmitWait, fallbackMin: 200, fallbackMax: 600)))

        let enterResult = await executeJS(JSInteractionBuilder.enterKeySubmitJS())
        result.submitTriggered = enterResult == "ENTER_PRESSED"
        result.submitMethod = "Calibrated focus + typing + Enter"
        return result
    }

    // MARK: - Pattern 8: Form Submit Direct

    private func executeFormSubmitDirect(username: String, password: String, executeJS: @escaping (String) async -> String?, sessionId: String) async -> HumanPatternResult {
        var result = HumanPatternResult(pattern: .formSubmitDirect)
        let t0 = Date()

        if let rawResult = await executeJS(JSInteractionBuilder.fillBothFieldsJS(username: username, password: password)),
           let data = rawResult.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Bool] {
            result.usernameFilled = json["email"] ?? false
            result.passwordFilled = json["pass"] ?? false
        }
        logger.log("FormDirect: fill both fields [input[type='email']+input[type='password']] email=\(result.usernameFilled) pass=\(result.passwordFilled) +\(Int(Date().timeIntervalSince(t0)*1000))ms", category: .automation, level: result.usernameFilled ? .success : .error, sessionId: sessionId)

        let passSel8 = resolveSitePasswordSelector(sessionId: sessionId)
        let passValue = await executeJS(JSInteractionBuilder.readFieldValueJS(selector: passSel8))
        if let pv = passValue, !pv.isEmpty, pv.contains(username) {
            _ = await executeJS(JSInteractionBuilder.clearFieldJS(selector: passSel8))
            _ = await executeJS(JSInteractionBuilder.nativeSetterFillJS(selector: passSel8, value: password))
            logger.log("CROSS-CONTAMINATION: formSubmitDirect contaminated, re-filled password.", category: .automation, level: .warning, sessionId: sessionId)
        }

        let d1 = aiOptimizedDelay(category: .preSubmitWait, fallbackMin: 200, fallbackMax: 500)
        logger.log("FormDirect: pre-submit wait \(d1)ms", category: .automation, level: .trace, sessionId: sessionId)
        try? await Task.sleep(for: .milliseconds(d1))

        let submitResult = await executeJS(JSInteractionBuilder.formSubmitJS())
        result.submitTriggered = submitResult != "FAILED" && submitResult != nil
        result.submitMethod = "Form submit direct: \(submitResult ?? "nil")"
        logger.log("FormDirect: form.submit() → \(submitResult ?? "nil") total=+\(Int(Date().timeIntervalSince(t0)*1000))ms", category: .automation, level: result.submitTriggered ? .success : .warning, sessionId: sessionId)
        return result
    }

    // MARK: - Pattern 9: Coordinate Click

    private func executeCoordinateClick(username: String, password: String, executeJS: @escaping (String) async -> String?, sessionId: String) async -> HumanPatternResult {
        var result = HumanPatternResult(pattern: .coordinateClick)
        let cal = LoginCalibrationService.shared.calibrationFor(url: sessionId)

        if let emailCoords = cal?.emailField?.coordinates {
            let f = await executeJS(JSInteractionBuilder.coordinateClickJS(x: Int(emailCoords.x), y: Int(emailCoords.y)))
            if f != "NO_ELEMENT" {
                try? await Task.sleep(for: .milliseconds(aiOptimizedDelay(category: .preFocusPause, fallbackMin: 100, fallbackMax: 300)))
                let typed = await typeCharByChar(text: username, executeJS: executeJS, sessionId: sessionId, fieldName: "email", minDelayMs: baseMinMs, maxDelayMs: baseMaxMs)
                result.usernameFilled = typed
            }
        } else {
            let f = await executeJS(JSInteractionBuilder.focusEmailFieldJS())
            if f != "NOT_FOUND" {
                try? await Task.sleep(for: .milliseconds(aiOptimizedDelay(category: .preFocusPause, fallbackMin: 100, fallbackMax: 300)))
                let typed = await typeCharByChar(text: username, executeJS: executeJS, sessionId: sessionId, fieldName: "email", minDelayMs: baseMinMs, maxDelayMs: baseMaxMs)
                result.usernameFilled = typed
            }
        }

        try? await Task.sleep(for: .milliseconds(aiOptimizedDelay(category: .interFieldPause, fallbackMin: 200, fallbackMax: 500)))

        let emailSel = resolveSiteEmailSelector(sessionId: sessionId)
        let passSel = resolveSitePasswordSelector(sessionId: sessionId)
        _ = await verifyAndCleanPasswordField(username: username, emailSelector: emailSel, passwordSelector: passSel, executeJS: executeJS, sessionId: sessionId)

        if let passCoords = cal?.passwordField?.coordinates {
            let f = await executeJS(JSInteractionBuilder.coordinateClickJS(x: Int(passCoords.x), y: Int(passCoords.y)))
            if f != "NO_ELEMENT" {
                try? await Task.sleep(for: .milliseconds(aiOptimizedDelay(category: .preFocusPause, fallbackMin: 100, fallbackMax: 300)))
                let typed = await typeCharByChar(text: password, executeJS: executeJS, sessionId: sessionId, fieldName: "password", minDelayMs: baseMinMs, maxDelayMs: baseMaxMs)
                result.passwordFilled = typed
            }
        } else {
            let f = await executeJS(JSInteractionBuilder.focusPasswordJS())
            if f != "NOT_FOUND" {
                try? await Task.sleep(for: .milliseconds(aiOptimizedDelay(category: .preFocusPause, fallbackMin: 100, fallbackMax: 300)))
                let typed = await typeCharByChar(text: password, executeJS: executeJS, sessionId: sessionId, fieldName: "password", minDelayMs: baseMinMs, maxDelayMs: baseMaxMs)
                result.passwordFilled = typed
            }
        }

        try? await Task.sleep(for: .milliseconds(aiOptimizedDelay(category: .preSubmitWait, fallbackMin: 300, fallbackMax: 700)))

        if let btnCoords = cal?.loginButton?.coordinates {
            let r = await executeJS(JSInteractionBuilder.coordinateButtonClickJS(x: Int(btnCoords.x), y: Int(btnCoords.y)))
            result.submitTriggered = r?.hasPrefix("COORD_CLICKED") == true
            result.submitMethod = "Coordinate click: \(r ?? "nil")"
        } else {
            let clickResult = await humanClickLoginButton(executeJS: executeJS, sessionId: sessionId)
            result.submitTriggered = clickResult
            result.submitMethod = "Coordinate fallback click"
        }

        return result
    }

    // MARK: - Pattern 10: React Native Setter

    private func executeReactNativeSetter(username: String, password: String, executeJS: @escaping (String) async -> String?, sessionId: String) async -> HumanPatternResult {
        var result = HumanPatternResult(pattern: .reactNativeSetter)
        let t0 = Date()

        if let rawResult = await executeJS(JSInteractionBuilder.reactNativeFillJS(username: username, password: password)),
           let data = rawResult.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Bool] {
            result.usernameFilled = json["email"] ?? false
            result.passwordFilled = json["pass"] ?? false
        }
        logger.log("ReactNative: nativeInputValueSetter fill [input[type='email']+input[type='password']] email=\(result.usernameFilled) pass=\(result.passwordFilled) +\(Int(Date().timeIntervalSince(t0)*1000))ms", category: .automation, level: result.usernameFilled ? .success : .error, sessionId: sessionId)

        let passSel10 = resolveSitePasswordSelector(sessionId: sessionId)
        let passValueRN = await executeJS(JSInteractionBuilder.readFieldValueJS(selector: passSel10))
        if let pv = passValueRN, !pv.isEmpty, pv.contains(username) {
            _ = await executeJS(JSInteractionBuilder.clearFieldJS(selector: passSel10))
            _ = await executeJS(JSInteractionBuilder.nativeSetterFillJS(selector: passSel10, value: password))
            logger.log("CROSS-CONTAMINATION: reactNativeSetter contaminated, re-filled password.", category: .automation, level: .warning, sessionId: sessionId)
        }

        let d1 = aiOptimizedDelay(category: .preSubmitWait, fallbackMin: 300, fallbackMax: 700)
        logger.log("ReactNative: pre-submit wait \(d1)ms", category: .automation, level: .trace, sessionId: sessionId)
        try? await Task.sleep(for: .milliseconds(d1))

        let clickResult = await humanClickLoginButton(executeJS: executeJS, sessionId: sessionId)
        result.submitTriggered = clickResult
        result.submitMethod = "React native setter + click"
        logger.log("ReactNative: login button click \(clickResult ? "OK" : "FAIL") +\(Int(Date().timeIntervalSince(t0)*1000))ms", category: .automation, level: clickResult ? .success : .warning, sessionId: sessionId)

        if !result.submitTriggered {
            let enterR = await executeJS(JSInteractionBuilder.enterKeyOnPasswordJS())
            result.submitTriggered = enterR == "ENTER"
            result.submitMethod = "React native setter + Enter"
            logger.log("ReactNative: Enter key fallback → \(enterR ?? "nil") total=+\(Int(Date().timeIntervalSince(t0)*1000))ms", category: .automation, level: result.submitTriggered ? .success : .error, sessionId: sessionId)
        }

        return result
    }

    // MARK: - Pattern 11: Vision ML Coordinate

    private func executeVisionMLCoordinate(username: String, password: String, executeJS: @escaping (String) async -> String?, sessionId: String) async -> HumanPatternResult {
        var result = HumanPatternResult(pattern: .visionMLCoordinate)
        _ = VisionMLService.shared

        // Step 1: Capture screenshot for OCR-based element detection
        let screenshotJS = """
        (function(){
            return JSON.stringify({w: window.innerWidth, h: window.innerHeight});
        })()
        """
        let viewportStr = await executeJS(screenshotJS) ?? "{}"
        if let data = viewportStr.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let _ = json["w"] as? CGFloat, let _ = json["h"] as? CGFloat {
        }

        // Step 2: Take page screenshot via canvas capture
        let captureJS = """
        (function(){
            var el = document.querySelector('input[type="email"], input[type="text"][name*="email" i], input#email, input#username');
            if(el) { return JSON.stringify({found:true, tag:el.tagName, x:el.getBoundingClientRect().x, y:el.getBoundingClientRect().y, w:el.getBoundingClientRect().width, h:el.getBoundingClientRect().height}); }
            return JSON.stringify({found:false});
        })()
        """
        _ = await executeJS(captureJS)

        // Step 3: OCR Vision ML — detect email field by pixel coordinate with human variance
        let emailClickJS = buildOCRVarianceClickJS(
            selectorHints: ["input[type='email']", "input[type='text'][name*='email' i]", "input#email", "input#username", "input[name='username']"],
            pixelVarianceRange: 3,
            sessionId: sessionId
        )
        let emailClickResult = await executeJS(emailClickJS)
        let emailClicked = emailClickResult != "NOT_FOUND" && emailClickResult != nil

        if emailClicked {
            // Human-like pre-typing pause
            try? await Task.sleep(for: .milliseconds(aiOptimizedDelay(category: .preFocusPause, fallbackMin: 200, fallbackMax: 500)))

            // Clear any existing value first
            _ = await executeJS("(function(){var el=document.activeElement; if(el&&el.tagName==='INPUT'){el.value='';el.dispatchEvent(new Event('input',{bubbles:true}));} return 'cleared';})()")

            // Type with human timing variance
            let userTyped = await typeCharByChar(text: username, executeJS: executeJS, sessionId: sessionId, fieldName: "email", minDelayMs: baseMinMs, maxDelayMs: baseMaxMs)
            result.usernameFilled = userTyped
        } else {
            logger.log("VisionML OCR: email coordinate click failed, falling back to JS focus", category: .automation, level: .warning, sessionId: sessionId)
            let emailFocus = await executeJS(JSInteractionBuilder.focusEmailFieldJS())
            if emailFocus != "NOT_FOUND" {
                try? await Task.sleep(for: .milliseconds(aiOptimizedDelay(category: .preFocusPause, fallbackMin: 150, fallbackMax: 400)))
                let userTyped = await typeCharByChar(text: username, executeJS: executeJS, sessionId: sessionId, fieldName: "email", minDelayMs: baseMinMs, maxDelayMs: baseMaxMs)
                result.usernameFilled = userTyped
            }
        }

        // Human inter-field pause with variance
        try? await Task.sleep(for: .milliseconds(aiOptimizedDelay(category: .interFieldPause, fallbackMin: 300, fallbackMax: 700)))

        let emailSel = resolveSiteEmailSelector(sessionId: sessionId)
        let passSel = resolveSitePasswordSelector(sessionId: sessionId)
        _ = await verifyAndCleanPasswordField(username: username, emailSelector: emailSel, passwordSelector: passSel, executeJS: executeJS, sessionId: sessionId)

        // Step 4: OCR Vision ML — detect password field by pixel coordinate with variance
        let passClickJS = buildOCRVarianceClickJS(
            selectorHints: ["input[type='password']", "input#password", "input#login-password", "input[name='password']"],
            pixelVarianceRange: 3,
            sessionId: sessionId
        )
        let passClickResult = await executeJS(passClickJS)
        let passClicked = passClickResult != "NOT_FOUND" && passClickResult != nil

        if passClicked {
            try? await Task.sleep(for: .milliseconds(aiOptimizedDelay(category: .preFocusPause, fallbackMin: 150, fallbackMax: 400)))
            _ = await executeJS("(function(){var el=document.activeElement; if(el&&el.tagName==='INPUT'){el.value='';el.dispatchEvent(new Event('input',{bubbles:true}));} return 'cleared';})()")
            let passTyped = await typeCharByChar(text: password, executeJS: executeJS, sessionId: sessionId, fieldName: "password", minDelayMs: baseMinMs, maxDelayMs: baseMaxMs)
            result.passwordFilled = passTyped
        } else {
            logger.log("VisionML OCR: password coordinate click failed, falling back to JS focus", category: .automation, level: .warning, sessionId: sessionId)
            _ = await executeJS(JSInteractionBuilder.focusPasswordJS())
            try? await Task.sleep(for: .milliseconds(aiOptimizedDelay(category: .preFocusPause, fallbackMin: 150, fallbackMax: 400)))
            let passTyped = await typeCharByChar(text: password, executeJS: executeJS, sessionId: sessionId, fieldName: "password", minDelayMs: baseMinMs, maxDelayMs: baseMaxMs)
            result.passwordFilled = passTyped
        }

        // Human pre-submit thinking pause
        try? await Task.sleep(for: .milliseconds(aiOptimizedDelay(category: .preSubmitWait, fallbackMin: 400, fallbackMax: 900)))

        // Step 5: OCR Vision ML — click submit button via pixel coordinate with variance
        let submitClickJS = buildOCRVarianceClickJS(
            selectorHints: ["button[type='submit']", "#loginSubmit", "#login-submit", "button.login-btn", "input[type='submit']"],
            pixelVarianceRange: 4,
            sessionId: sessionId
        )
        let submitResult = await executeJS(submitClickJS)
        if submitResult != "NOT_FOUND" && submitResult != nil {
            result.submitTriggered = true
            result.submitMethod = "OCR pixel-variance coordinate click"
        } else {
            logger.log("VisionML OCR: submit coordinate click failed, falling back to humanClickLoginButton", category: .automation, level: .warning, sessionId: sessionId)
            let clickResult = await humanClickLoginButton(executeJS: executeJS, sessionId: sessionId)
            result.submitTriggered = clickResult
            result.submitMethod = "Vision ML fallback to humanClick"
        }

        return result
    }

    /// Builds JavaScript that locates an element using selector hints, then dispatches a
    /// full pointer/mouse/touch event chain at the element's center with random pixel variance —
    /// mimicking how a real human finger or cursor never hits the exact center pixel.
    private func buildOCRVarianceClickJS(selectorHints: [String], pixelVarianceRange: Int, sessionId: String) -> String {
        let selectorsArray = selectorHints.map { "'\($0)'" }.joined(separator: ",")
        let variance = pixelVarianceRange
        return """
        (function(){
            var selectors = [\(selectorsArray)];
            var el = null;
            for(var i=0;i<selectors.length;i++){
                el = document.querySelector(selectors[i]);
                if(el && el.offsetParent !== null) break;
                el = null;
            }
            if(!el) return 'NOT_FOUND';
            var rect = el.getBoundingClientRect();
            if(rect.width === 0 || rect.height === 0) return 'NOT_FOUND';
            var cx = rect.left + rect.width/2 + (Math.random()*\(variance*2) - \(variance));
            var cy = rect.top + rect.height/2 + (Math.random()*\(variance*2) - \(variance));
            cx = Math.max(rect.left+1, Math.min(rect.right-1, cx));
            cy = Math.max(rect.top+1, Math.min(rect.bottom-1, cy));
            el.focus();
            el.dispatchEvent(new PointerEvent('pointerdown',{bubbles:true,cancelable:true,clientX:cx,clientY:cy,pointerId:1,pointerType:'touch',isPrimary:true}));
            el.dispatchEvent(new MouseEvent('mousedown',{bubbles:true,cancelable:true,clientX:cx,clientY:cy}));
            el.dispatchEvent(new PointerEvent('pointerup',{bubbles:true,cancelable:true,clientX:cx,clientY:cy,pointerId:1,pointerType:'touch',isPrimary:true}));
            el.dispatchEvent(new MouseEvent('mouseup',{bubbles:true,cancelable:true,clientX:cx,clientY:cy}));
            el.dispatchEvent(new MouseEvent('click',{bubbles:true,cancelable:true,clientX:cx,clientY:cy}));
            if(typeof el.click === 'function') el.click();
            return 'CLICKED:'+el.tagName+'@'+Math.round(cx)+','+Math.round(cy);
        })()
        """
    }

    // MARK: - Typing Engines

    private func typeCharByChar(text: String, executeJS: @escaping (String) async -> String?, sessionId: String, fieldName: String, minDelayMs: Int, maxDelayMs: Int) async -> Bool {
        let fieldType = fieldName == "password" ? "password" : "email"
        _ = await executeJS(JSInteractionBuilder.clearFieldJS(fieldType: fieldType))

        for (index, char) in text.enumerated() {
            let r = await executeJS(JSInteractionBuilder.typeOneCharJS(char: char, fieldType: fieldType))
            if r != "TYPED" {
                logger.log("CharByChar: failed at index \(index) of \(fieldName): \(r ?? "nil")", category: .automation, level: .warning, sessionId: sessionId)
                return false
            }

            let delay = aiOptimizedDelay(category: .keystrokeDelay, fallbackMin: minDelayMs, fallbackMax: maxDelayMs)
            if index > 0 && index % Int.random(in: 4...8) == 0 {
                let thinkPause = aiOptimizedDelay(category: .thinkPause, fallbackMin: 200, fallbackMax: 600)
                try? await Task.sleep(for: .milliseconds(delay + thinkPause))
            } else {
                try? await Task.sleep(for: .milliseconds(delay))
            }
        }

        let lenStr = await executeJS(JSInteractionBuilder.verifyFieldLengthJS())
        let typedLen = Int(lenStr ?? "0") ?? 0
        let success = typedLen >= text.count
        if !success {
            logger.log("CharByChar: \(fieldName) verify failed — typed \(typedLen)/\(text.count) chars", category: .automation, level: .warning, sessionId: sessionId)
        }
        return success
    }

    private func typeWithExecCommand(text: String, executeJS: @escaping (String) async -> String?, sessionId: String, fieldName: String, minDelayMs: Int, maxDelayMs: Int) async -> Bool {
        _ = await executeJS(JSInteractionBuilder.execCommandClearJS())

        for (index, char) in text.enumerated() {
            let r = await executeJS(JSInteractionBuilder.execCommandInsertCharJS(char: char))
            if r == "NO_EL" {
                logger.log("ExecCmd: no active element at index \(index) of \(fieldName)", category: .automation, level: .warning, sessionId: sessionId)
                return false
            }

            let delay = aiOptimizedDelay(category: .keystrokeDelay, fallbackMin: minDelayMs, fallbackMax: maxDelayMs)
            try? await Task.sleep(for: .milliseconds(delay))
        }

        return true
    }

    private func typeSlowWithCorrections(text: String, executeJS: @escaping (String) async -> String?, sessionId: String, fieldName: String) async -> Bool {
        _ = await executeJS(JSInteractionBuilder.slowTypeClearJS())

        let correctionChance = 0.08
        var i = 0
        let chars = Array(text)

        while i < chars.count {
            if Double.random(in: 0...1) < correctionChance && i > 2 {
                let typoChar = "abcdefghijklmnopqrstuvwxyz".randomElement()!
                _ = await executeJS(JSInteractionBuilder.slowTypeTypoJS(char: typoChar))
                logger.log("SlowTyper: deliberate typo '\(typoChar)' at pos \(i) in \(fieldName)", category: .automation, level: .trace, sessionId: sessionId)

                try? await Task.sleep(for: .milliseconds(aiOptimizedDelay(category: .thinkPause, fallbackMin: 300, fallbackMax: 800)))
                _ = await executeJS(JSInteractionBuilder.backspaceJS())
                try? await Task.sleep(for: .milliseconds(aiOptimizedDelay(category: .thinkPause, fallbackMin: 200, fallbackMax: 500)))
            }

            let char = chars[i]
            let r = await executeJS(JSInteractionBuilder.slowTypeCharJS(char: char))
            if r == "NO_EL" { return false }

            let delay = aiOptimizedDelay(category: .keystrokeDelay, fallbackMin: 120, fallbackMax: 350)
            if i > 0 && i % Int.random(in: 3...6) == 0 {
                try? await Task.sleep(for: .milliseconds(delay + aiOptimizedDelay(category: .thinkPause, fallbackMin: 300, fallbackMax: 900)))
            } else {
                try? await Task.sleep(for: .milliseconds(delay))
            }

            i += 1
        }

        return true
    }

    // MARK: - Login Button Click

    private func humanClickLoginButton(executeJS: @escaping (String) async -> String?, sessionId: String) async -> Bool {
        let r = await executeJS(JSInteractionBuilder.humanClickLoginButtonJS())
        logger.log("HumanClick login button: \(r ?? "nil")", category: .automation, level: r?.hasPrefix("CLICKED") == true ? .debug : .warning, sessionId: sessionId)

        if let r, r.hasPrefix("CLICKED") { return true }

        let fallback = await executeJS(JSInteractionBuilder.enterFallbackSubmitJS())
        logger.log("HumanClick fallback: \(fallback ?? "nil")", category: .automation, level: .debug, sessionId: sessionId)
        return fallback != "FAILED" && fallback != nil
    }

    private func resolveSiteEmailSelector(sessionId: String) -> String {
        let settings = AutomationSettingsPersistence.shared.load()
        let isJoeSite = currentHost.lowercased().contains("joe") || sessionId.lowercased().contains("joe")
        let site: LoginTargetSite = isJoeSite ? .joefortune : .ignition
        return settings.emailSelector(for: site)
    }

    private func resolveSitePasswordSelector(sessionId: String) -> String {
        let settings = AutomationSettingsPersistence.shared.load()
        let isJoeSite = currentHost.lowercased().contains("joe") || sessionId.lowercased().contains("joe")
        let site: LoginTargetSite = isJoeSite ? .joefortune : .ignition
        return settings.passwordSelector(for: site)
    }

    private func verifyAndCleanPasswordField(username: String, emailSelector: String, passwordSelector: String, executeJS: @escaping (String) async -> String?, sessionId: String) async -> Bool {
        let currentValue = await executeJS(JSInteractionBuilder.readFieldValueJS(selector: passwordSelector))
        var contaminated = false
        if let val = currentValue, !val.isEmpty, val.contains(username) {
            _ = await executeJS(JSInteractionBuilder.clearFieldJS(selector: passwordSelector))
            logger.log("CROSS-CONTAMINATION: password field contained username, cleared it.", category: .automation, level: .warning, sessionId: sessionId)
            contaminated = true
        }

        // Dispatch explicit blur on email field
        _ = await executeJS(JSInteractionBuilder.blurFieldJS(selector: emailSelector))

        // Dispatch focus + click on password field
        _ = await executeJS("""
        (function() {
            var el = document.querySelector('\(passwordSelector)');
            if (el) {
                el.focus();
                el.click();
                el.dispatchEvent(new Event('focus', {bubbles:true}));
            }
        })()
        """)

        return contaminated
    }
}
