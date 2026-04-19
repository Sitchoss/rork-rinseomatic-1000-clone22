import Foundation
import WebKit
import Observation

@Observable
class LiveWebViewDebugService {
    static let shared = LiveWebViewDebugService()

    var attachedWebViewID: UUID?
    var attachedWebView: WKWebView?
    var attachedLabel: String = ""
    var attachedSessionIndex: Int = 0
    var attachedStartedAt: Date?
    var attachedSourceTitle: String = ""
    var activeMode: ActiveAppMode?
    var isFullScreen: Bool = false
    var showEndedToast: Bool = false
    var autoObserve: Bool = true
    var isInteractive: Bool = false
    var previewScale: CGFloat = 1
    var currentURL: String = ""
    var currentTitle: String = ""
    var consoleEntries: [LiveConsoleEntry] = []
    var showConsole: Bool = false
    var screenshotToast: Bool = false
    var pendingReviewItems: [LiveResultReviewItem] = []
    var activeReviewItem: LiveResultReviewItem?
    var showResultReview: Bool = false
    var resultReviewEnabled: Bool = true
    var totalReviewsShown: Int = 0
    var totalApprovals: Int = 0
    var totalCorrections: Int = 0

    // MARK: - Paired Site Toggle (Joe/Ignition)

    nonisolated enum LiveSite: String, Sendable {
        case joe = "Joe"
        case ignition = "Ignition"
    }

    var activeSite: LiveSite = .joe
    var isPaired: Bool { pairedJoeWebViewID != nil && pairedIgnitionWebViewID != nil }
    var pairedJoeWebViewID: UUID?
    var pairedJoeWebView: WKWebView?
    var pairedIgnitionWebViewID: UUID?
    var pairedIgnitionWebView: WKWebView?
    var pairedCredentialEmail: String = ""

    var isAttached: Bool { attachedWebView != nil }

    private var urlObservation: NSKeyValueObservation?
    private var titleObservation: NSKeyValueObservation?
    private var toastDismissTask: Task<Void, Never>?

    private init() {
        setupPoolCallbacks()
    }

    func attach(webViewID: UUID, webView: WKWebView, label: String, sessionIndex: Int, startedAt: Date?, sourceTitle: String = "") {
        if attachedWebViewID == webViewID {
            attachedLabel = label
            attachedSessionIndex = sessionIndex
            attachedStartedAt = startedAt ?? attachedStartedAt ?? Date()
            if !sourceTitle.isEmpty {
                attachedSourceTitle = sourceTitle
            }
            currentURL = webView.url?.absoluteString ?? ""
            currentTitle = webView.title ?? ""
            return
        }
        cleanupObservations()
        attachedWebViewID = webViewID
        attachedWebView = webView
        attachedLabel = label
        attachedSessionIndex = sessionIndex
        attachedStartedAt = startedAt ?? Date()
        attachedSourceTitle = sourceTitle
        isFullScreen = false
        showEndedToast = false
        isInteractive = false
        previewScale = 1
        consoleEntries = []
        currentURL = webView.url?.absoluteString ?? ""
        currentTitle = webView.title ?? ""
        setupKVO(for: webView)
        injectConsoleInterceptor(into: webView)
    }

    func detach() {
        cleanupObservations()
        removeConsoleInterceptor()
        attachedWebViewID = nil
        attachedWebView = nil
        attachedLabel = ""
        attachedSessionIndex = 0
        attachedStartedAt = nil
        attachedSourceTitle = ""
        isFullScreen = false
        isInteractive = false
        previewScale = 1
        currentURL = ""
        currentTitle = ""
        clearPairedState()
    }

    // MARK: - Paired WebView Management

    func registerPair(joeWebViewID: UUID, joeWebView: WKWebView, ignWebViewID: UUID, ignWebView: WKWebView, credentialEmail: String, sessionIndex: Int, startedAt: Date?) {
        pairedJoeWebViewID = joeWebViewID
        pairedJoeWebView = joeWebView
        pairedIgnitionWebViewID = ignWebViewID
        pairedIgnitionWebView = ignWebView
        pairedCredentialEmail = credentialEmail
        activeSite = .joe

        attach(
            webViewID: joeWebViewID,
            webView: joeWebView,
            label: credentialEmail,
            sessionIndex: sessionIndex,
            startedAt: startedAt,
            sourceTitle: "Joe"
        )
    }

    func toggleSite() {
        guard isPaired else { return }
        let newSite: LiveSite = activeSite == .joe ? .ignition : .joe
        activeSite = newSite

        switch newSite {
        case .joe:
            if let id = pairedJoeWebViewID, let wv = pairedJoeWebView {
                cleanupObservations()
                removeConsoleInterceptor()
                attachedWebViewID = id
                attachedWebView = wv
                attachedSourceTitle = "Joe"
                currentURL = wv.url?.absoluteString ?? ""
                currentTitle = wv.title ?? ""
                setupKVO(for: wv)
                injectConsoleInterceptor(into: wv)
            }
        case .ignition:
            if let id = pairedIgnitionWebViewID, let wv = pairedIgnitionWebView {
                cleanupObservations()
                removeConsoleInterceptor()
                attachedWebViewID = id
                attachedWebView = wv
                attachedSourceTitle = "Ignition"
                currentURL = wv.url?.absoluteString ?? ""
                currentTitle = wv.title ?? ""
                setupKVO(for: wv)
                injectConsoleInterceptor(into: wv)
            }
        }
    }

    func switchToSite(_ site: LiveSite) {
        guard isPaired, activeSite != site else { return }
        toggleSite()
    }

    private func clearPairedState() {
        pairedJoeWebViewID = nil
        pairedJoeWebView = nil
        pairedIgnitionWebViewID = nil
        pairedIgnitionWebView = nil
        pairedCredentialEmail = ""
        activeSite = .joe
    }

    func unregisterPairedSite(id: UUID) {
        if pairedJoeWebViewID == id {
            pairedJoeWebViewID = nil
            pairedJoeWebView = nil
            if activeSite == .joe, let ignID = pairedIgnitionWebViewID, let ignWV = pairedIgnitionWebView {
                activeSite = .ignition
                cleanupObservations()
                removeConsoleInterceptor()
                attachedWebViewID = ignID
                attachedWebView = ignWV
                attachedSourceTitle = "Ignition"
                currentURL = ignWV.url?.absoluteString ?? ""
                currentTitle = ignWV.title ?? ""
                setupKVO(for: ignWV)
                injectConsoleInterceptor(into: ignWV)
            }
        } else if pairedIgnitionWebViewID == id {
            pairedIgnitionWebViewID = nil
            pairedIgnitionWebView = nil
            if activeSite == .ignition, let joeID = pairedJoeWebViewID, let joeWV = pairedJoeWebView {
                activeSite = .joe
                cleanupObservations()
                removeConsoleInterceptor()
                attachedWebViewID = joeID
                attachedWebView = joeWV
                attachedSourceTitle = "Joe"
                currentURL = joeWV.url?.absoluteString ?? ""
                currentTitle = joeWV.title ?? ""
                setupKVO(for: joeWV)
                injectConsoleInterceptor(into: joeWV)
            }
        }
    }

    var currentModeTitle: String {
        if !attachedSourceTitle.isEmpty {
            return attachedSourceTitle
        }
        switch preferredAutomationMode {
        case .unifiedSession: return "Unified"
        case .dualFind: return "Dual Find"
        case .ppsr: return "Card Testing"
        case .credentialHub: return "Credentials"
        default: return "Live"
        }
    }

    func setActiveMode(_ mode: ActiveAppMode?) {
        activeMode = mode
        syncAutomaticAttachment()
    }

    func attachToNearest() {
        autoObserve = true
        syncAutomaticAttachment()
    }

    func autoFitPreview(to containerSize: CGSize) {
        guard let webView = attachedWebView else { return }
        let script = """
        ({
          width: Math.max(document.documentElement.scrollWidth || 0, document.body.scrollWidth || 0, window.innerWidth || 0),
          height: Math.max(document.documentElement.scrollHeight || 0, document.body.scrollHeight || 0, window.innerHeight || 0)
        })
        """
        Task { @MainActor in
            let result = try? await webView.evaluateJavaScript(script)
            guard let body = result as? [String: Any],
                  let rawWidth = body["width"] as? Double else {
                previewScale = 1
                return
            }
            let contentWidth = max(CGFloat(rawWidth), 1)
            let fitted = min(max(containerSize.width / contentWidth, 0.35), 1)
            previewScale = fitted
        }
    }

    private static let zoomLevels: [CGFloat] = [1.0, 0.75, 0.5, 0.33]

    func cycleZoom() {
        guard let webView = attachedWebView else { return }
        let currentIndex = Self.zoomLevels.firstIndex(where: { abs($0 - previewScale) < 0.01 }) ?? 0
        let nextIndex = (currentIndex + 1) % Self.zoomLevels.count
        previewScale = Self.zoomLevels[nextIndex]
    }

    func captureScreenshot() {
        guard let webView = attachedWebView else { return }
        let config = WKSnapshotConfiguration()
        webView.takeSnapshot(with: config) { [weak self] image, _ in
            guard let self, let image else { return }
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            self.screenshotToast = true
            self.toastDismissTask?.cancel()
            self.toastDismissTask = Task {
                try? await Task.sleep(for: .seconds(2))
                if !Task.isCancelled {
                    self.screenshotToast = false
                }
            }
        }
    }

    func enqueueResultReview(_ item: LiveResultReviewItem) {
        guard resultReviewEnabled && isFullScreen else { return }
        pendingReviewItems.append(item)
        if activeReviewItem == nil {
            presentNextReview()
        }
    }

    func presentNextReview() {
        guard !pendingReviewItems.isEmpty else {
            activeReviewItem = nil
            showResultReview = false
            return
        }
        let item = pendingReviewItems.removeFirst()
        activeReviewItem = item
        showResultReview = true
        totalReviewsShown += 1
    }

    func approveCurrentReview() {
        guard let item = activeReviewItem else { return }
        totalApprovals += 1
        let store = AIResultCorrectionStore.shared
        store.recordApproval(
            credentialEmail: item.credentialEmail,
            sessionId: item.sessionId,
            site: "joe",
            detectedOutcome: item.joeDetectedOutcome,
            confidence: item.joeConfidence,
            ocrText: item.joeOCRText
        )
        store.recordApproval(
            credentialEmail: item.credentialEmail,
            sessionId: item.sessionId,
            site: "ignition",
            detectedOutcome: item.ignitionDetectedOutcome,
            confidence: item.ignitionConfidence,
            ocrText: item.ignitionOCRText
        )
        activeReviewItem = nil
        showResultReview = false
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))
            presentNextReview()
        }
    }

    func correctCurrentReview(
        joeOutcome: LiveResultReviewOutcome,
        ignOutcome: LiveResultReviewOutcome,
        joeHighlights: [HighlightRegion],
        ignHighlights: [HighlightRegion]
    ) {
        guard let item = activeReviewItem else { return }
        totalCorrections += 1
        let store = AIResultCorrectionStore.shared
        let joeImage = item.joeScreenshotData.flatMap { UIImage(data: $0) }
        let ignImage = item.ignitionScreenshotData.flatMap { UIImage(data: $0) }

        if joeOutcome != item.joeDetectedOutcome {
            store.recordCorrection(
                credentialEmail: item.credentialEmail,
                sessionId: item.sessionId,
                site: "joe",
                aiDetectedOutcome: item.joeDetectedOutcome,
                userCorrectedOutcome: joeOutcome,
                aiConfidence: item.joeConfidence,
                highlightRegions: joeHighlights,
                ocrText: item.joeOCRText,
                screenshot: joeImage
            )
        } else {
            store.recordApproval(
                credentialEmail: item.credentialEmail,
                sessionId: item.sessionId,
                site: "joe",
                detectedOutcome: item.joeDetectedOutcome,
                confidence: item.joeConfidence,
                ocrText: item.joeOCRText
            )
        }

        if ignOutcome != item.ignitionDetectedOutcome {
            store.recordCorrection(
                credentialEmail: item.credentialEmail,
                sessionId: item.sessionId,
                site: "ignition",
                aiDetectedOutcome: item.ignitionDetectedOutcome,
                userCorrectedOutcome: ignOutcome,
                aiConfidence: item.ignitionConfidence,
                highlightRegions: ignHighlights,
                ocrText: item.ignitionOCRText,
                screenshot: ignImage
            )
        } else {
            store.recordApproval(
                credentialEmail: item.credentialEmail,
                sessionId: item.sessionId,
                site: "ignition",
                detectedOutcome: item.ignitionDetectedOutcome,
                confidence: item.ignitionConfidence,
                ocrText: item.ignitionOCRText
            )
        }

        if let session = UnifiedSessionViewModel.shared.sessions.first(where: { $0.id == item.sessionId }) {
            if joeOutcome != item.joeDetectedOutcome {
                let correctedSiteResult = SiteResult.fromLoginOutcome(joeOutcome.toLoginOutcome, registeredAttempts: session.joeAttempts.count, maxAttempts: session.maxAttempts)
                UnifiedSessionViewModel.shared.overrideSiteResult(sessionId: item.sessionId, site: "joe", result: correctedSiteResult)
            }
            if ignOutcome != item.ignitionDetectedOutcome {
                let correctedSiteResult = SiteResult.fromLoginOutcome(ignOutcome.toLoginOutcome, registeredAttempts: session.ignitionAttempts.count, maxAttempts: session.maxAttempts)
                UnifiedSessionViewModel.shared.overrideSiteResult(sessionId: item.sessionId, site: "ignition", result: correctedSiteResult)
            }
        }

        activeReviewItem = nil
        showResultReview = false
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))
            presentNextReview()
        }
    }

    func skipCurrentReview() {
        activeReviewItem = nil
        showResultReview = false
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(200))
            presentNextReview()
        }
    }

    func addConsoleEntry(level: LiveConsoleEntry.Level, message: String) {
        let entry = LiveConsoleEntry(level: level, message: message)
        consoleEntries.append(entry)
        if consoleEntries.count > 200 {
            consoleEntries.removeFirst(consoleEntries.count - 200)
        }
    }

    // MARK: - Pool Callbacks (#7 + #9)

    private var preferredAutomationMode: ActiveAppMode? {
        if let activeMode {
            switch activeMode {
            case .unifiedSession where UnifiedSessionViewModel.shared.isRunning:
                return .unifiedSession
            case .dualFind where DualFindViewModel.shared.isRunning:
                return .dualFind
            case .ppsr where PPSRAutomationViewModel.shared.isRunning:
                return .ppsr
            case .credentialHub where LoginViewModel.shared.isRunning:
                return .credentialHub
            default:
                break
            }
        }

        if UnifiedSessionViewModel.shared.isRunning { return .unifiedSession }
        if DualFindViewModel.shared.isRunning { return .dualFind }
        if PPSRAutomationViewModel.shared.isRunning { return .ppsr }
        if LoginViewModel.shared.isRunning { return .credentialHub }
        return nil
    }

    private func syncAutomaticAttachment() {
        let pool = WebViewPool.shared
        guard let target = preferredAttachment(in: pool.activeViews) else {
            if pool.activeViews.isEmpty {
                detach()
            }
            return
        }
        attach(
            webViewID: target.id,
            webView: target.webView,
            label: target.label,
            sessionIndex: target.sessionIndex,
            startedAt: target.startedAt,
            sourceTitle: target.sourceTitle
        )
    }

    private func preferredAttachment(in activeViews: [UUID: WKWebView]) -> (id: UUID, webView: WKWebView, label: String, sessionIndex: Int, startedAt: Date?, sourceTitle: String)? {
        guard let mode = preferredAutomationMode else { return nil }

        switch mode {
        case .credentialHub:
            if let attempt = LoginViewModel.shared.activeAttempts.first,
               let webView = activeViews[attempt.id] {
                return (attempt.id, webView, attempt.credential.username, attempt.sessionIndex, attempt.startedAt, "Credential Hub")
            }
        case .ppsr:
            if let check = PPSRAutomationViewModel.shared.activeChecks.first,
               let webView = activeViews[check.id] {
                return (check.id, webView, "\(check.card.brand.rawValue) •••\(check.card.number.suffix(4))", check.sessionIndex, check.startedAt, "Card Testing")
            }
        case .unifiedSession:
            if let session = UnifiedSessionViewModel.shared.activeSessions.first,
               let sessionID = UUID(uuidString: session.id),
               let webView = activeViews[sessionID] {
                return (sessionID, webView, session.credential.email, session.currentAttempt, session.startTime, "Unified Sessions")
            }
            if let first = activeViews.first {
                return (first.key, first.value, "Unified Session", 1, Date(), "Unified Sessions")
            }
        case .dualFind:
            if let session = DualFindViewModel.shared.sessions.first(where: { $0.isActive }),
               let first = activeViews.first {
                return (first.key, first.value, session.currentEmail.isEmpty ? session.platform : session.currentEmail, session.index + 1, Date(), "Dual Find")
            }
            if let first = activeViews.first {
                return (first.key, first.value, "Dual Find", 1, Date(), "Dual Find")
            }
        default:
            break
        }

        if let first = activeViews.first {
            return (first.key, first.value, currentModeTitle, 1, Date(), currentModeTitle)
        }
        return nil
    }

    private func setupPoolCallbacks() {
        let pool = WebViewPool.shared
        pool.onUnmount = { [weak self] id in
            guard let self else { return }
            if self.isPaired && (self.pairedJoeWebViewID == id || self.pairedIgnitionWebViewID == id) {
                self.unregisterPairedSite(id: id)
                if !self.isPaired && self.attachedWebViewID == id {
                    self.showEndedToast = true
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        if self.attachedWebViewID == id {
                            self.detach()
                            if self.autoObserve {
                                self.syncAutomaticAttachment()
                            }
                        }
                    }
                }
                return
            }
            if self.attachedWebViewID == id {
                self.showEndedToast = true
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    if self.attachedWebViewID == id {
                        self.detach()
                        if self.autoObserve {
                            self.syncAutomaticAttachment()
                        }
                    }
                }
            }
        }
        pool.onMount = { [weak self] id, webView in
            guard let self else { return }
            if self.autoObserve {
                self.syncAutomaticAttachment()
            }
        }
    }

    // MARK: - KVO (#6)

    private func setupKVO(for webView: WKWebView) {
        urlObservation = webView.observe(\.url, options: [.new]) { [weak self] wv, _ in
            Task { @MainActor [weak self] in
                self?.currentURL = wv.url?.absoluteString ?? ""
            }
        }
        titleObservation = webView.observe(\.title, options: [.new]) { [weak self] wv, _ in
            Task { @MainActor [weak self] in
                self?.currentTitle = wv.title ?? ""
            }
        }
    }

    private func cleanupObservations() {
        urlObservation?.invalidate()
        urlObservation = nil
        titleObservation?.invalidate()
        titleObservation = nil
    }

    // MARK: - Console Interception (#3)

    private let consoleHandlerName = "liveDebugConsole"

    private func injectConsoleInterceptor(into webView: WKWebView) {
        let js = """
        (function() {
            if (window.__liveDebugConsoleInjected) return;
            window.__liveDebugConsoleInjected = true;
            var origLog = console.log, origWarn = console.warn, origError = console.error;
            function post(level, args) {
                try {
                    window.webkit.messageHandlers.liveDebugConsole.postMessage({level: level, message: Array.from(args).map(String).join(' ')});
                } catch(e) {}
            }
            console.log = function() { post('log', arguments); origLog.apply(console, arguments); };
            console.warn = function() { post('warn', arguments); origWarn.apply(console, arguments); };
            console.error = function() { post('error', arguments); origError.apply(console, arguments); };
        })();
        """
        let script = WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        webView.configuration.userContentController.addUserScript(script)
        let handler = LiveConsoleMessageHandler(service: self)
        webView.configuration.userContentController.add(handler, name: consoleHandlerName)
    }

    private func removeConsoleInterceptor() {
        attachedWebView?.configuration.userContentController.removeScriptMessageHandler(forName: consoleHandlerName)
    }
}

struct LiveConsoleEntry: Identifiable {
    let id = UUID()
    let timestamp = Date()
    let level: Level
    let message: String

    nonisolated enum Level: String, Sendable {
        case log, warn, error
    }
}

class LiveConsoleMessageHandler: NSObject, WKScriptMessageHandler {
    private weak var service: LiveWebViewDebugService?

    init(service: LiveWebViewDebugService) {
        self.service = service
        super.init()
    }

    nonisolated func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        Task { @MainActor [weak self] in
            guard let self, let service = self.service else { return }
            guard let body = message.body as? [String: String],
                  let levelStr = body["level"],
                  let msg = body["message"] else { return }
            let level: LiveConsoleEntry.Level = switch levelStr {
            case "warn": .warn
            case "error": .error
            default: .log
            }
            service.addConsoleEntry(level: level, message: msg)
        }
    }
}
