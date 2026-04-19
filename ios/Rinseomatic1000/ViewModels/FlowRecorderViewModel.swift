import Foundation
import Observation
import WebKit

@Observable
class FlowRecorderViewModel {
    var targetURL: String = "https://www.joefortunepokies.eu/login"
    var flowName: String = ""
    var isRecording: Bool = false
    var isPlaying: Bool = false
    var savedFlows: [RecordedFlow] = []
    var currentActions: [RecordedAction] = []
    var recordingDurationMs: Double = 0
    var playbackProgress: Double = 0
    var playbackActionIndex: Int = 0
    var playbackTotalActions: Int = 0
    var showSaveSheet: Bool = false
    var showPlaybackSheet: Bool = false
    var selectedFlow: RecordedFlow?
    var textboxValues: [String: String] = [:]
    var pendingTokenOverrides: [String: FlowPlaceholderToken?] = [:]
    var statusMessage: String = ""
    var fingerprintScore: String = "—"
    var pageTitle: String = ""
    var showExportSheet: Bool = false
    var showImportPicker: Bool = false
    var lastError: String?
    var failedActions: Int = 0
    var healedActions: Int = 0

    var playFromStepIndex: Int = 0
    var showURLDropdown: Bool = false
    var showSettingsFromRecorder: Bool = false
    var isTestingAction: Bool = false
    var testingActionIndex: Int?
    var testingActionMethod: ActionAutomationMethod = .humanClick
    var testActionResults: [ActionTestResult] = []
    var recordAfterPlayback: Bool = false
    var isRecordingAfterPlay: Bool = false

    private let persistence = FlowPersistenceService.shared
    private let playbackEngine = FlowPlaybackEngine.shared
    private let logger = DebugLogger.shared
    private var recordingStartTime: Double = 0
    private var durationTimer: Timer?
    weak var activeWebView: WKWebView?

    var currentActionCount: Int { currentActions.count }
    var mouseMovements: Int { currentActions.filter { $0.type == .mouseMove }.count }
    var clicks: Int { currentActions.filter { $0.type == .click || $0.type == .mouseDown }.count }
    var keystrokes: Int { currentActions.filter { $0.type == .keyDown }.count }
    var scrollEvents: Int { currentActions.filter { $0.type == .scroll }.count }

    var detectedTextboxes: [String] {
        let labels = Set(currentActions.compactMap(\.textboxLabel))
        return labels.sorted()
    }

    var allAvailableURLs: [String] {
        var urls: [String] = []
        let urlService = LoginURLRotationService.shared
        for u in urlService.joeURLs where u.isEnabled {
            urls.append(u.urlString)
        }
        for u in urlService.ignitionURLs where u.isEnabled {
            urls.append(u.urlString)
        }
        let flowURLs = Set(savedFlows.map(\.url))
        for fu in flowURLs {
            if !urls.contains(fu) { urls.append(fu) }
        }
        if !targetURL.isEmpty && !urls.contains(targetURL) {
            urls.insert(targetURL, at: 0)
        }
        return urls
    }

    init(targetURL: String = "https://www.joefortunepokies.eu/login") {
        self.targetURL = URLNormalizer.normalize(targetURL)
        savedFlows = persistence.loadFlows()
        AutomationFoundationStore.shared.syncFlows(savedFlows)
    }

    func startRecording() {
        guard !isRecording else { return }
        currentActions = []
        recordingDurationMs = 0
        recordingStartTime = ProcessInfo.processInfo.systemUptime * 1000
        isRecording = true
        isRecordingAfterPlay = false
        lastError = nil
        statusMessage = "Recording..."

        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self, self.isRecording else { return }
                self.recordingDurationMs = ProcessInfo.processInfo.systemUptime * 1000 - self.recordingStartTime
            }
        }

        logger.startSession("recording", category: .flowRecorder, message: "FlowRecorder: recording started for \(targetURL)")
    }

    func startRecordingFromStep() {
        guard !isRecording else { return }
        recordingDurationMs = 0
        recordingStartTime = ProcessInfo.processInfo.systemUptime * 1000
        isRecording = true
        isRecordingAfterPlay = true
        lastError = nil
        statusMessage = "Recording (continuing from step \(playFromStepIndex))..."

        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self, self.isRecording else { return }
                self.recordingDurationMs = ProcessInfo.processInfo.systemUptime * 1000 - self.recordingStartTime
            }
        }

        logger.startSession("recording_continue", category: .flowRecorder, message: "FlowRecorder: recording continued from step \(playFromStepIndex)")
    }

    func stopRecording() {
        guard isRecording else { return }
        isRecording = false
        durationTimer?.invalidate()
        durationTimer = nil
        statusMessage = "Recording stopped — \(currentActions.count) actions captured"

        logger.endSession("recording", category: .flowRecorder, message: "FlowRecorder: recording stopped — \(currentActions.count) actions", level: currentActions.isEmpty ? .warning : .success)

        if currentActions.isEmpty {
            lastError = "No actions recorded. The page may be blocking the recorder script."
        } else {
            showSaveSheet = true
        }
    }

    func appendActions(_ actions: [RecordedAction]) {
        guard !actions.isEmpty else { return }
        currentActions.append(contentsOf: actions)
        AutomationFoundationStore.shared.recordRecordedActions(actions, url: targetURL)
    }

    func handlePageLoaded(_ title: String) {
        pageTitle = title
        validateFingerprint()
    }

    func handlePageLoadFailed(_ error: String) {
        lastError = error
        statusMessage = "Page load failed: \(error)"
    }

    func saveCurrentFlow() {
        let name = flowName.isEmpty ? "Flow \(savedFlows.count + 1)" : flowName
        var miscIndex = 1
        var finalActions = currentActions
        
        let textboxMappings = detectedTextboxes.map { label in
            let lastInput = currentActions.last(where: { $0.textboxLabel == label && $0.type == .input })
            let selector = lastInput?.targetSelector ?? ""
            let rawText = lastInput?.textContent ?? ""
            let targetType = lastInput?.targetType
            
            var token: FlowPlaceholderToken?
            if let override = pendingTokenOverrides[label] {
                token = override
            } else {
                token = FlowPlaceholderToken.detect(
                    fromLabel: label,
                    targetType: targetType,
                    name: lastInput?.targetName,
                    id: lastInput?.targetId,
                    placeholder: lastInput?.targetPlaceholder,
                    autocomplete: lastInput?.targetAutocomplete,
                    labelText: lastInput?.targetLabelText
                )
                if token == nil {
                    if miscIndex == 1 { token = .miscTextbox1 }
                    else if miscIndex == 2 { token = .miscTextbox2 }
                    else if miscIndex == 3 { token = .miscTextbox3 }
                    miscIndex += 1
                }
            }
            
            let originalText = token?.templateKey ?? rawText
            
            if let token = token {
                for i in 0..<finalActions.count {
                    if finalActions[i].targetSelector == selector || finalActions[i].textboxLabel == label {
                        if finalActions[i].type == .input || finalActions[i].type == .textboxEntry {
                            finalActions[i].textContent = token.templateKey
                        }
                    }
                }
            }
            
            return RecordedFlow.TextboxMapping(
                label: label,
                selector: selector,
                originalText: originalText,
                placeholderKey: label,
                assignedToken: token
            )
        }

        let flow = RecordedFlow(
            name: name,
            url: targetURL,
            actions: finalActions,
            textboxMappings: textboxMappings,
            totalDurationMs: recordingDurationMs,
            actionCount: finalActions.count
        )
        let review = FlowSaveReviewService.review(original: nil, updated: flow)

        savedFlows.insert(flow, at: 0)
        persistence.saveFlows(savedFlows)
        AutomationFoundationStore.shared.commitFlowSave(original: nil, updated: flow, review: review)
        flowName = ""
        pendingTokenOverrides = [:]
        showSaveSheet = false
        statusMessage = "Flow '\(name)' saved — \(flow.actionCount) actions"
    }

    func mergeRecordedActionsIntoFlow(_ flow: RecordedFlow, fromStep: Int) {
        guard !currentActions.isEmpty else { return }
        var updatedFlow = flow
        let keepActions = Array(updatedFlow.actions.prefix(fromStep))
        updatedFlow.actions = keepActions + currentActions
        updatedFlow.actionCount = updatedFlow.actions.count
        updatedFlow.totalDurationMs = updatedFlow.actions.reduce(0) { $0 + $1.deltaFromPreviousMs }
        let review = FlowSaveReviewService.review(original: flow, updated: updatedFlow)

        if let idx = savedFlows.firstIndex(where: { $0.id == flow.id }) {
            savedFlows[idx] = updatedFlow
        }
        persistence.saveFlows(savedFlows)
        AutomationFoundationStore.shared.commitFlowSave(original: flow, updated: updatedFlow, review: review)
        statusMessage = "Flow '\(flow.name)' updated — merged \(currentActions.count) new actions from step \(fromStep)"
        currentActions = []
    }

    func deleteFlow(_ flow: RecordedFlow) {
        savedFlows.removeAll { $0.id == flow.id }
        persistence.saveFlows(savedFlows)
        AutomationFoundationStore.shared.deleteFlowMetadata(flowID: flow.id)
    }

    func selectFlowForPlayback(_ flow: RecordedFlow) {
        selectedFlow = flow
        textboxValues = [:]
        playFromStepIndex = 0
        recordAfterPlayback = false
        for mapping in flow.textboxMappings {
            let key = mapping.assignedToken?.templateKey ?? mapping.placeholderKey
            textboxValues[key] = ""
        }
        showPlaybackSheet = true
    }

    func prepareContinueRecording(_ flow: RecordedFlow, fromStep: Int) {
        selectedFlow = flow
        textboxValues = [:]
        playFromStepIndex = max(0, min(fromStep, max(0, flow.actions.count - 1)))
        recordAfterPlayback = true
        for mapping in flow.textboxMappings {
            let key = mapping.assignedToken?.templateKey ?? mapping.placeholderKey
            textboxValues[key] = ""
        }
        statusMessage = "Prepared continue-from-here playback at step \(playFromStepIndex)"
        showPlaybackSheet = true
    }

    func saveEditedFlow(_ updated: RecordedFlow, review: FlowSaveReview) {
        guard let index = savedFlows.firstIndex(where: { $0.id == updated.id }) else { return }
        let original = savedFlows[index]
        savedFlows[index] = updated
        persistence.saveFlows(savedFlows)
        AutomationFoundationStore.shared.commitFlowSave(original: original, updated: updated, review: review)
        statusMessage = "Flow '\(updated.name)' saved — version updated"
    }

    func duplicateFlow(_ copy: RecordedFlow) {
        savedFlows.insert(copy, at: 0)
        persistence.saveFlows(savedFlows)
        let review = FlowSaveReviewService.review(original: nil, updated: copy)
        AutomationFoundationStore.shared.commitFlowSave(original: nil, updated: copy, review: review)
        statusMessage = "Duplicated '\(copy.name)'"
    }

    func playSelectedFlow() {
        guard let flow = selectedFlow else { return }
        guard let webView = activeWebView else {
            lastError = "WebView not available for playback"
            return
        }

        let playbackStart = recordAfterPlayback ? 0 : playFromStepIndex
        let playbackEnd = recordAfterPlayback ? playFromStepIndex : nil
        let expectedSteps = recordAfterPlayback ? playFromStepIndex : max(flow.actions.count - playFromStepIndex, 0)

        showPlaybackSheet = false
        isPlaying = true
        playbackProgress = 0
        playbackActionIndex = 0
        playbackTotalActions = expectedSteps
        failedActions = 0
        healedActions = 0
        lastError = nil
        statusMessage = recordAfterPlayback
            ? "Replaying safe prefix through step \(playFromStepIndex)..."
            : "Playing '\(flow.name)' from step \(playFromStepIndex)..."

        Task {
            await playbackEngine.playFlow(
                flow,
                in: webView,
                textboxValues: textboxValues,
                startFromStep: playbackStart,
                endBeforeStep: playbackEnd,
                onProgress: { [weak self] current, total in
                    guard let self else { return }
                    self.playbackActionIndex = current
                    self.playbackTotalActions = total
                    self.playbackProgress = Double(current) / Double(max(total, 1))
                },
                onComplete: { [weak self] success in
                    guard let self else { return }
                    self.isPlaying = false
                    self.failedActions = self.playbackEngine.failedActionIndices.count
                    self.healedActions = self.playbackEngine.healedActionCount
                    if success {
                        if self.recordAfterPlayback {
                            self.startRecordingFromStep()
                        } else if self.failedActions > 0 {
                            self.statusMessage = "Playback complete — \(self.failedActions) failed, \(self.healedActions) healed"
                        } else {
                            self.statusMessage = "Playback complete"
                        }
                    } else {
                        self.statusMessage = "Playback cancelled"
                    }
                }
            )
        }
    }

    func cancelPlayback() {
        playbackEngine.cancel()
        isPlaying = false
        statusMessage = "Playback cancelled"
    }

    func testSingleAction(_ action: RecordedAction, method: ActionAutomationMethod) {
        guard let webView = activeWebView else {
            lastError = "WebView not available"
            return
        }
        isTestingAction = true
        statusMessage = "Testing action with \(method.rawValue)..."

        Task {
            let startTime = Date()
            let success = await playbackEngine.testActionWithMethod(action, flow: selectedFlow, method: method, in: webView, textboxValues: textboxValues)
            let elapsed = Int(Date().timeIntervalSince(startTime) * 1000)

            let result = ActionTestResult(
                actionId: action.id,
                method: method,
                success: success,
                durationMs: elapsed
            )
            testActionResults.append(result)
            isTestingAction = false
            statusMessage = success ? "Action test PASSED (\(method.rawValue), \(elapsed)ms)" : "Action test FAILED (\(method.rawValue), \(elapsed)ms)"
        }
    }

    func testAllMethodsForAction(_ action: RecordedAction) {
        guard let webView = activeWebView else {
            lastError = "WebView not available"
            return
        }
        isTestingAction = true
        statusMessage = "Testing all methods..."

        Task {
            for method in ActionAutomationMethod.allCases {
                let startTime = Date()
                let success = await playbackEngine.testActionWithMethod(action, flow: selectedFlow, method: method, in: webView, textboxValues: textboxValues)
                let elapsed = Int(Date().timeIntervalSince(startTime) * 1000)

                let result = ActionTestResult(
                    actionId: action.id,
                    method: method,
                    success: success,
                    durationMs: elapsed
                )
                testActionResults.append(result)

                if success {
                    statusMessage = "Found working method: \(method.rawValue) (\(elapsed)ms)"
                }
                try? await Task.sleep(for: .milliseconds(300))
            }
            isTestingAction = false
        }
    }

    func validateFingerprint() {
        guard let webView = activeWebView else { return }
        Task {
            let profile = await PPSRStealthService.shared.nextProfile()
            let score = await FingerprintValidationService.shared.validate(in: webView, profileSeed: profile.seed)
            fingerprintScore = score.formattedScore
        }
    }

    func exportFlow(_ flow: RecordedFlow) -> Data? {
        persistence.exportFlow(flow)
    }

    func importFlow(from data: Data) {
        if let flow = persistence.importFlow(from: data) {
            savedFlows.insert(flow, at: 0)
            persistence.saveFlows(savedFlows)
            AutomationFoundationStore.shared.syncFlowMetadata(flow)
            statusMessage = "Imported '\(flow.name)'"
        } else {
            lastError = "Failed to import flow — invalid data format"
            statusMessage = "Import failed — invalid data"
        }
    }

    var formattedDuration: String {
        let seconds = recordingDurationMs / 1000.0
        if seconds < 60 {
            return String(format: "%.1fs", seconds)
        }
        let minutes = Int(seconds) / 60
        let remaining = Int(seconds) % 60
        return "\(minutes)m \(remaining)s"
    }

    func assignedMode(for flow: RecordedFlow) -> FlowScriptMode? {
        FlowScriptAssignmentService.shared.assignedMode(for: flow.id)
    }
}

nonisolated enum ActionAutomationMethod: String, Codable, Sendable, CaseIterable {
    case humanClick = "Human Touch Chain"
    case jsClick = "JS Click"
    case pointerDispatch = "Pointer+Touch Dispatch"
    case formSubmit = "Form Submit"
    case enterKey = "Enter Key"
    case ocrTextDetect = "OCR Text Detect"
    case coordinateClick = "Coordinate Click"
    case visionMLDetect = "Vision ML Detect"
    case screenshotCropNav = "Screenshot Crop Nav"
    case focusThenClick = "Focus Then Click"
    case tabNavigation = "Tab Navigation"
    case nativeSetterFill = "Native Setter Fill"
    case execCommandInsert = "ExecCommand Insert"
    case mouseHoverThenClick = "Mouse Hover+Click"
}

nonisolated struct ActionTestResult: Sendable, Identifiable {
    let id: String = UUID().uuidString
    let actionId: String
    let method: ActionAutomationMethod
    let success: Bool
    let durationMs: Int
}
