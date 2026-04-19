import Foundation

nonisolated struct AutomationSettings: Codable, Sendable {
    // MARK: - TRUE DETECTION (Primary Protocol)
    var trueDetectionEnabled: Bool = true
    var trueDetectionPriority: Bool = true
    var trueDetectionHardPauseMs: Int = 1120
    var trueDetectionTripleClickCount: Int = 4
    var trueDetectionTripleClickDelayMs: Int = 168
    var tripleClickInterClickDelayMs: Int = 168
    var trueDetectionSubmitCycleCount: Int = 4
    var trueDetectionButtonRecoveryTimeoutMs: Int = 4200
    var trueDetectionMaxAttempts: Int = 4
    var trueDetectionPostClickWaitMs: Int = 2100
    var trueDetectionCooldownMinutes: Int = 15

    var joeEmailSelector: String = "#username"
    var joePasswordSelector: String = "#password"
    var joeSubmitSelector: String = "#loginSubmit"
    var ignEmailSelector: String = "#email"
    var ignPasswordSelector: String = "#login-password"
    var ignSubmitSelector: String = "#login-submit"

    func emailSelector(for site: LoginTargetSite) -> String {
        switch site {
        case .joefortune: joeEmailSelector
        case .ignition: ignEmailSelector
        }
    }

    func passwordSelector(for site: LoginTargetSite) -> String {
        switch site {
        case .joefortune: joePasswordSelector
        case .ignition: ignPasswordSelector
        }
    }

    func submitSelector(for site: LoginTargetSite) -> String {
        switch site {
        case .joefortune: joeSubmitSelector
        case .ignition: ignSubmitSelector
        }
    }
    var trueDetectionSuccessMarkers: [String] = ["balance", "wallet", "my account", "logout"]
    var trueDetectionTerminalKeywords: [String] = ["temporarily disabled"]
    var trueDetectionErrorBannerSelectors: [String] = [".error-banner", ".alert-danger", ".alert-error", ".login-error", ".notification-error", "[role='alert']"]
    var trueDetectionNoProxyRotation: Bool = false
    var trueDetectionStrictWaits: Bool = true
    var trueDetectionIgnorePlaceholders: Bool = true
    var trueDetectionIgnoreXPaths: Bool = true
    var trueDetectionIgnoreClassNames: Bool = true

    // MARK: - Page Loading
    var pageLoadTimeout: TimeInterval = 180
    var pageLoadRetries: Int = 3
    var retryBackoffMultiplier: Double = 2.0
    var waitForJSRenderMs: Int = 700
    var fullSessionResetOnFinalRetry: Bool = true

    // MARK: - Field Detection
    var fieldVerificationEnabled: Bool = true
    var fieldVerificationTimeout: TimeInterval = 180
    var autoCalibrationEnabled: Bool = true
    var visionMLCalibrationFallback: Bool = true
    var calibrationConfidenceThreshold: Double = 0.6

    // MARK: - Credential Entry
    var typingSpeedMinMs: Int = 50
    var typingSpeedMaxMs: Int = 50
    var typingJitterEnabled: Bool = true
    var occasionalBackspaceEnabled: Bool = true
    var backspaceProbability: Double = 0.04
    var fieldFocusDelayMs: Int = 50
    var interFieldDelayMs: Int = 50
    var preFillPauseMinMs: Int = 50
    var preFillPauseMaxMs: Int = 50

    // MARK: - Pattern Strategy
    var maxSubmitCycles: Int = 5
    var enabledPatterns: [String] = LoginFormPatternList.allNames
    var patternPriorityOrder: [String] = LoginFormPatternList.defaultPriorityOrder
    var preferCalibratedPatternsFirst: Bool = true
    var patternLearningEnabled: Bool = true

    // MARK: - Fallback Chain (Anti-Bot)
    var fallbackToLegacyFill: Bool = false
    var fallbackToOCRClick: Bool = true
    var fallbackToVisionMLClick: Bool = true
    var fallbackToCoordinateClick: Bool = true

    // MARK: - Submit Behavior
    var submitRetryCount: Int = 5
    var submitRetryDelayMs: Int = 50
    var waitForResponseSeconds: Double = 180.0
    var rapidPollEnabled: Bool = true
    var rapidPollIntervalMs: Int = 50

    // MARK: - Post-Submit Evaluation
    var redirectDetection: Bool = true
    var contentChangeDetection: Bool = true
    var evaluationStrictness: EvaluationStrictness = .strict
    var capturePageContent: Bool = true
    var minimumPageContentLength: Int = 80

    // MARK: - Retry / Requeue
    var requeueOnTimeout: Bool = true
    var requeueOnConnectionFailure: Bool = true
    var requeueOnRedBanner: Bool = true
    var maxRequeueCount: Int = 3
    var minAttemptsBeforeNoAcc: Int = 4
    var cyclePauseMinMs: Int = 1120  // Gap between submit cycles within a single credential attempt
    var cyclePauseMaxMs: Int = 2100

    // MARK: - Stealth
    var stealthJSInjection: Bool = true
    var fingerprintValidationEnabled: Bool = false
    var hostFingerprintLearningEnabled: Bool = false
    var fingerprintSpoofing: Bool = true
    var userAgentRotation: Bool = true
    var viewportRandomization: Bool = true
    var webGLNoise: Bool = true
    var canvasNoise: Bool = false
    var audioContextNoise: Bool = false
    var timezoneSpoof: Bool = true
    var languageSpoof: Bool = true

    // MARK: - Screenshot / Debug
    var slowDebugMode: Bool = false
    var screenshotOnEveryEval: Bool = true
    var screenshotOnFailure: Bool = true
    var screenshotOnSuccess: Bool = true
    var maxScreenshotRetention: Int = 500
    var screenshotsPerAttempt: ScreenshotsPerAttempt = .three
    var unifiedScreenshotsPerAttempt: UnifiedScreenshotCount = .five
    var unifiedScreenshotPostClickDelayMs: Int = 50
    var postSubmitScreenshotTimings: String = "0.5, 1.5, 2.0, 2.7, 3.6"
    var postSubmitScreenshotsOnly: Bool = true

    var parsedPostSubmitTimings: [Double] {
        postSubmitScreenshotTimings
            .split(separator: ",")
            .compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
            .filter { $0 >= 0 && $0 <= 30 }
            .sorted()
    }

    // MARK: - Concurrency
    var maxConcurrency: Int = 7
    var concurrencyStrategy: ConcurrencyStrategy = .rorkAISmart
    var fixedPairCount: Int = 3
    var liveUserPairCount: Int = 4
    var batchDelayBetweenStartsMs: Int = 50
    var connectionTestBeforeBatch: Bool = true

    // MARK: - Network Per-Mode
    var useAssignedNetworkForTests: Bool = true
    var proxyRotateOnDisabled: Bool = false
    var proxyRotateOnFailure: Bool = true
    var dnsRotatePerRequest: Bool = true
    var vpnConfigRotation: Bool = true

    // MARK: - URL Rotation
    var urlRotationEnabled: Bool = true
    var disableURLAfterConsecutiveFailures: Int = 2
    var reEnableURLAfterSeconds: TimeInterval = 120
    var preferFastestURL: Bool = false
    var smartURLSelection: Bool = true

    // MARK: - Blacklist / Auto-Actions
    var autoBlacklistNoAcc: Bool = true
    var autoBlacklistPermDisabled: Bool = true
    var autoExcludeBlacklist: Bool = true

    // MARK: - Human Simulation
    var humanMouseMovement: Bool = true
    var humanScrollJitter: Bool = true
    var randomPreActionPause: Bool = true
    var preActionPauseMinMs: Int = 50
    var preActionPauseMaxMs: Int = 50
    var gaussianTimingDistribution: Bool = true

    // MARK: - Login Button (Fallback modes only)
    var loginButtonDetectionMode: ButtonDetectionMode = .trueDetection
    var loginButtonTextMatches: [String] = ["LOGIN", "Sign in", "Sign In", "Submit", "Continue", "Next", "Go", "Enter", "Login", "Lo gin"]
    var loginButtonCustomSelector: String = ""
    var loginButtonClickMethod: ButtonClickMethod = .humanClick
    var loginButtonPreClickDelayMs: Int = 50
    var loginButtonPostClickDelayMs: Int = 50
    var loginButtonDoubleClickGuard: Bool = true
    var loginButtonDoubleClickWindowMs: Int = 50
    var loginButtonScrollIntoView: Bool = false
    var loginButtonWaitForEnabled: Bool = true
    var loginButtonWaitForEnabledTimeoutMs: Int = 90_000 // Intentionally 90s — distinct from 50ms defaults; gives button time to become interactive after page load
    var pageLoadExtraDelayMs: Int = 50
    var submitButtonWaitDelayMs: Int = 50
    var loginButtonVisibilityCheck: Bool = true
    var loginButtonFocusBeforeClick: Bool = false
    var loginButtonHoverBeforeClick: Bool = true
    var loginButtonClickOffsetJitter: Bool = true
    // Stored as canonical keys so that existing persisted JSON round-trips correctly.
    // v42HoverDwellMs / v42ClickJitterPx are computed aliases kept for API compatibility.
    var loginButtonHoverDurationMs: Int = 50
    var loginButtonClickOffsetMaxPx: Int = 3
    var loginButtonMinSizePx: Int = 20
    var loginButtonMaxCandidates: Int = 5
    var loginButtonConfidenceThreshold: Double = 0.5

    // MARK: - Time Delays
    var globalPreActionDelayMs: Int = 50
    var globalPostActionDelayMs: Int = 50
    var preNavigationDelayMs: Int = 50
    var postNavigationDelayMs: Int = 50
    var preTypingDelayMs: Int = 50
    var postTypingDelayMs: Int = 50
    var preSubmitDelayMs: Int = 50
    var postSubmitDelayMs: Int = 50
    var betweenAttemptsDelayMs: Int = 1680    // DualFind inter-attempt gap
    var betweenCredentialsDelayMs: Int = 50 // DualFind gap between credential rotations
    var pageStabilizationDelayMs: Int = 560
    var ajaxSettleDelayMs: Int = 840
    var domMutationSettleMs: Int = 420
    var animationSettleDelayMs: Int = 560
    var redirectFollowDelayMs: Int = 50
    var captchaDetectionDelayMs: Int = 50
    var errorRecoveryDelayMs: Int = 50
    var sessionCooldownDelayMs: Int = 50
    var proxyRotationDelayMs: Int = 50
    var vpnReconnectDelayMs: Int = 50
    var autoFallbackWGtoOVPN: Bool = true
    var autoFallbackOVPNtoSOCKS5: Bool = true
    var delayRandomizationEnabled: Bool = true
    var delayRandomizationPercent: Int = 25

    // MARK: - SMS Detection (actively read by StrictLoginDetectionEngine + DualSiteWorkerService)
    var smsNotificationKeywords: [String] = ["sms", "text message", "verification code", "verify your phone", "send code", "sent a code", "enter the code", "phone verification", "mobile verification", "confirm your number", "we sent", "code sent", "enter code", "security code sent", "check your phone"]
    var smsDetectionEnabled: Bool = true
    var smsBurnSession: Bool = true

    // MARK: - Session Management
    var sessionIsolation: SessionIsolationMode = .full
    var clearCookiesBetweenAttempts: Bool = true
    var clearLocalStorageBetweenAttempts: Bool = true
    var clearSessionStorageBetweenAttempts: Bool = true
    var clearCacheBetweenAttempts: Bool = false
    var clearIndexedDBBetweenAttempts: Bool = false
    var freshWebViewPerAttempt: Bool = false

    var webViewMemoryLimitMB: Int = 2048
    var webViewJSEnabled: Bool = true
    var webViewImageLoadingEnabled: Bool = true
    var webViewPluginsEnabled: Bool = false

    // MARK: - Blank Page Recovery
    var blankPageRecoveryEnabled: Bool = true
    var blankPageTimeoutSeconds: Int = 20
    var blankPageWaitThresholdSeconds: Int = 90
    var blankPageFallback1_WaitAndRecheck: Bool = true
    var blankPageFallback2_ChangeURL: Bool = true
    var blankPageFallback3_ChangeDNS: Bool = true
    var blankPageFallback4_ChangeFingerprint: Bool = true
    var blankPageFallback5_FullSessionReset: Bool = true
    var blankPageMaxFallbackAttempts: Int = 5
    var blankPageRecheckIntervalMs: Int = 700

    // MARK: - Error Classification
    var networkErrorAutoRetry: Bool = true
    var sslErrorAutoRetry: Bool = true
    var http403MarkAsBlocked: Bool = true
    var http429RetryAfterSeconds: Int = 180
    var http5xxAutoRetry: Bool = true
    var connectionResetAutoRetry: Bool = true
    var dnsFailureAutoRetry: Bool = true
    // MARK: - Form Interaction Advanced
    var clearFieldsBeforeTyping: Bool = true
    var clearFieldMethod: FieldClearMethod = .tripleClickDelete
    var tabBetweenFields: Bool = false
    var clickFieldBeforeTyping: Bool = true
    var verifyFieldValueAfterTyping: Bool = true
    var retypeOnVerificationFailure: Bool = true
    var maxRetypeAttempts: Int = 2
    var passwordFieldUnmaskCheck: Bool = false
    var autoDetectRememberMe: Bool = false
    var uncheckRememberMe: Bool = true
    var dismissAutofillSuggestions: Bool = true
    var handlePasswordManagers: Bool = true

    // MARK: - Viewport & Window
    var viewportWidth: Int = 390
    var viewportHeight: Int = 844
    var smartFingerprintReuse: Bool = true
    var viewportSizeVariancePx: Int = 50
    var mobileViewportEmulation: Bool = true
    var deviceScaleFactor: Double = 2.0

    // MARK: - V4.2 Settlement Gate
    var v42SettlementGateEnabled: Bool = true
    var v42SettlementMaxTimeoutMs: Int = 15000
    var v42ButtonStabilityMs: Int = 50
    // Computed aliases: stored as loginButtonHoverDurationMs / loginButtonClickOffsetMaxPx for JSON backwards compatibility
    var v42HoverDwellMs: Int {
        get { loginButtonHoverDurationMs }
        set { loginButtonHoverDurationMs = newValue }
    }
    var v42ClickJitterPx: Int {
        get { loginButtonClickOffsetMaxPx }
        set { loginButtonClickOffsetMaxPx = newValue }
    }
    var v42InterAttemptDelayMinSec: Double = 2.3
    var v42InterAttemptDelayMaxSec: Double = 2.3
    var v42HumanVarianceMinMs: Int = 112
    var v42HumanVarianceMaxMs: Int = 280
    var v42StrictClassification: Bool = true
    var v42CoordinateInteractionOnly: Bool = true
    // MARK: - AI Telemetry
    var aiTelemetryEnabled: Bool = true

    // MARK: - Recorded Flow Override
    var urlFlowAssignments: [URLFlowAssignment] = []

    static let minimumTimeoutSeconds: TimeInterval = 180
    static let minimumTimeoutMilliseconds: Int = 180_000

    func normalizedTimeouts() -> AutomationSettings {
        var normalized = self
        // slowDebugMode is now a plain Bool, no normalization needed
        normalized.pageLoadTimeout = max(normalized.pageLoadTimeout, Self.minimumTimeoutSeconds)
        normalized.fieldVerificationTimeout = max(normalized.fieldVerificationTimeout, Self.minimumTimeoutSeconds)
        normalized.waitForResponseSeconds = max(normalized.waitForResponseSeconds, Self.minimumTimeoutSeconds)
        normalized.loginButtonWaitForEnabledTimeoutMs = max(normalized.loginButtonWaitForEnabledTimeoutMs, Self.minimumTimeoutMilliseconds)
        normalized.blankPageWaitThresholdSeconds = max(normalized.blankPageWaitThresholdSeconds, 30)
        normalized.http429RetryAfterSeconds = max(normalized.http429RetryAfterSeconds, Int(Self.minimumTimeoutSeconds))
        // Probability/percent/threshold clamping
        normalized.backspaceProbability = max(0.0, min(1.0, normalized.backspaceProbability))
        normalized.calibrationConfidenceThreshold = max(0.01, min(1.0, normalized.calibrationConfidenceThreshold))
        normalized.loginButtonConfidenceThreshold = max(0.01, min(1.0, normalized.loginButtonConfidenceThreshold))
        normalized.delayRandomizationPercent = max(0, min(100, normalized.delayRandomizationPercent))
        // Minimum value guards
        normalized.maxSubmitCycles = max(1, normalized.maxSubmitCycles)
        normalized.submitRetryCount = max(1, normalized.submitRetryCount)
        normalized.blankPageMaxFallbackAttempts = max(1, normalized.blankPageMaxFallbackAttempts)
        // Post-submit timing safety: if parsedPostSubmitTimings resolves empty, restore default
        if normalized.parsedPostSubmitTimings.isEmpty {
            normalized.postSubmitScreenshotTimings = "0.5, 1.5, 2.0, 2.7, 3.6"
        }
        return normalized
    }

    // MARK: - Enums

    nonisolated enum SubmitMethod: String, Codable, CaseIterable, Sendable, Identifiable {
        case tripleClickSynced = "Triple-Click Synced"
        case singleJSClick = "Single JS Click"
        case formSubmitDirect = "Form Submit Direct"
        case pointerEventChain = "Pointer Event Chain"
        case enterKeySubmit = "Enter Key Submit"

        var id: String { rawValue }

        var description: String {
            switch self {
            case .tripleClickSynced: "3-click synthetic MouseEvent sequence with settings-controlled temporal gaps (Phase 2 engine — see True Detection › Inter-Click Delay)"
            case .singleJSClick: "Single element.click() call — fastest but most detectable"
            case .formSubmitDirect: "form.submit() bypass — skips button interaction entirely"
            case .pointerEventChain: "Full pointer down/up/click chain with touch events"
            case .enterKeySubmit: "Dispatches Enter keypress on the password field"
            }
        }

        var icon: String {
            switch self {
            case .tripleClickSynced: "3.circle.fill"
            case .singleJSClick: "cursorarrow.click"
            case .formSubmitDirect: "doc.plaintext.fill"
            case .pointerEventChain: "hand.point.up.fill"
            case .enterKeySubmit: "return"
            }
        }
    }

    var joeSubmitMethod: SubmitMethod = .tripleClickSynced
    var ignSubmitMethod: SubmitMethod = .tripleClickSynced

    func submitMethod(for site: LoginTargetSite) -> SubmitMethod {
        switch site {
        case .joefortune: joeSubmitMethod
        case .ignition: ignSubmitMethod
        }
    }

    nonisolated enum UnifiedScreenshotCount: Int, Codable, CaseIterable, Sendable {
        case zero = 0
        case two = 2
        case three = 3
        case five = 5
        case eight = 8
        case ten = 10

        var limit: Int { rawValue }

        var perCredentialPerSiteLimit: Int { rawValue }

        var clearResultLimit: Int { 2 }

        var label: String {
            switch self {
            case .zero: "Off"
            case .two: "2/site"
            case .three: "3/site"
            case .five: "5/site"
            case .eight: "8/site"
            case .ten: "10/site"
            }
        }

        static func priorityOrder(forClickIndex clickIndex: Int, totalClicks: Int) -> Int {
            if clickIndex == 0 { return 0 }
            if clickIndex == totalClicks - 1 { return 1 }
            if clickIndex == 1 { return 2 }
            return 3
        }
    }

    nonisolated enum ScreenshotsPerAttempt: String, Codable, CaseIterable, Sendable {
        case none = "None"
        case one = "1"
        case three = "3"
        case five = "5"

        var limit: Int {
            switch self {
            case .none: 0
            case .one: 1
            case .three: 3
            case .five: 5
            }
        }
    }

    nonisolated enum EvaluationStrictness: String, Codable, CaseIterable, Sendable {
        case lenient = "Lenient"
        case normal = "Normal"
        case strict = "Strict"
    }

    nonisolated enum ButtonDetectionMode: String, Codable, CaseIterable, Sendable {
        case trueDetection = "TRUE DETECTION"
        case textMatch = "Text Match"
        case visionML = "Vision ML"
        case coordinateOnly = "Coordinate Only"
    }

    nonisolated enum ButtonClickMethod: String, Codable, CaseIterable, Sendable {
        case humanClick = "Human Touch Chain"
        case jsClick = "JS Click"
        case dispatchEvent = "Pointer+Touch Dispatch"
        case formSubmit = "Form Submit"
        case enterKey = "Enter Key"
    }

    nonisolated enum SessionIsolationMode: String, Codable, CaseIterable, Sendable {
        case none = "None"
        case cookies = "Cookies Only"
        case storage = "Storage Only"
        case full = "Full Isolation"
    }

    nonisolated enum FieldClearMethod: String, Codable, CaseIterable, Sendable {
        case selectAllDelete = "Select All + Delete"
        case tripleClickDelete = "Triple Click + Delete"
        case jsValueClear = "JS Value Clear"
        case backspaceLoop = "Backspace Loop"
    }
}

nonisolated struct URLFlowAssignment: Codable, Sendable, Identifiable {
    var id: String = UUID().uuidString
    var urlPattern: String
    var flowId: String
    var flowName: String
    var overridePatternStrategy: Bool = true
    var overrideTypingSpeed: Bool = false
    var overrideStealthSettings: Bool = false
    var overrideSubmitBehavior: Bool = false
    var assignedAt: Date = Date()
}

// NOTE: AutomationSettingsPersistence is @MainActor. Calls to .shared.load() from
// nonisolated or background contexts cross actor boundaries. This is safe in practice
// because load() is a synchronous read from UserDefaults, but be explicit if Swift
// strict concurrency warnings appear — wrap in Task { @MainActor in ... }.

// NOTE: All strings in LoginFormPatternList.allNames and defaultPriorityOrder must
// exactly match LoginFormPattern.rawValue cases. Mismatches silently produce no-ops
// when patterns are looked up by string in LoginAutomationEngine.
nonisolated enum LoginFormPatternList {
    static let allNames: [String] = [
        "TRUE DETECTION",
        "Tab Navigation",
        "Click-Focus Sequential",
        "ExecCommand Insert",
        "Slow Deliberate Typer",
        "Mobile Touch Burst",
        "Calibrated Direct",
        "Calibrated Typing",
        "Form Submit Direct",
        "Coordinate Click",
        "React Native Setter",
        "Vision ML Coordinate",
    ]

    static let defaultPriorityOrder: [String] = [
        "TRUE DETECTION",
        "Calibrated Typing",
        "Calibrated Direct",
        "Tab Navigation",
        "React Native Setter",
        "Form Submit Direct",
        "Coordinate Click",
        "Vision ML Coordinate",
        "Click-Focus Sequential",
        "ExecCommand Insert",
        "Slow Deliberate Typer",
        "Mobile Touch Burst",
    ]
}
