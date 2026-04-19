import Foundation
import Observation
import SwiftUI
@preconcurrency import WebKit

@Observable
@MainActor
final class CCTVCommandCentreViewModel {
    nonisolated enum SlotStatus: Equatable {
        case idle
        case loading
        case running
        case done
        case error(String)
    }

    nonisolated enum NavigationResult: Sendable {
        case finished
        case failed(String)
        case timedOut
    }

    @MainActor
    final class SlotNavigationDelegate: NSObject, WKNavigationDelegate {
        var onFinish: (() -> Void)?
        var onFail: ((String) -> Void)?

        nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            Task { @MainActor in
                onFinish?()
            }
        }

        nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            Task { @MainActor in
                onFail?(error.localizedDescription)
            }
        }

        nonisolated func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            Task { @MainActor in
                onFail?(error.localizedDescription)
            }
        }
    }

    @MainActor
    final class NavigationWaiter {
        var continuation: CheckedContinuation<NavigationResult, Never>?

        func resolve(_ result: NavigationResult) {
            guard let continuation else { return }
            self.continuation = nil
            continuation.resume(returning: result)
        }
    }

    @MainActor
    final class PlaybackWaiter {
        var continuation: CheckedContinuation<Bool, Never>?

        func resolve(_ success: Bool) {
            guard let continuation else { return }
            self.continuation = nil
            continuation.resume(returning: success)
        }
    }

    @Observable
    @MainActor
    final class Slot: Identifiable {
        let id: String = UUID().uuidString
        let entryId: String
        let webView: WKWebView
        let engine: FlowPlaybackEngine
        let navigationDelegate: SlotNavigationDelegate

        var status: SlotStatus = .idle
        var currentStep: Int = 0
        var totalSteps: Int = 0
        var activeCredentialEmail: String = ""
        var credentialIndex: Int = 0
        var credentialCount: Int = 0
        var completedCredentialCount: Int = 0
        var resultMessage: String = ""
        var task: Task<Void, Never>?
        var cancelled: Bool = false
        var encounteredError: Bool = false

        init(entryId: String, webView: WKWebView, engine: FlowPlaybackEngine, navigationDelegate: SlotNavigationDelegate) {
            self.entryId = entryId
            self.webView = webView
            self.engine = engine
            self.navigationDelegate = navigationDelegate
        }
    }

    private let sitchVM = Sitchomatic1000ViewModel.shared
    private let flowPersistence = FlowPersistenceService.shared

    var selectedEntryIds: [String] = []
    var slots: [Slot] = []
    var isRunning: Bool = false

    static let maxSlots: Int = 7

    var selectionCount: Int {
        selectedEntries.count
    }

    var selectableEntries: [Sitchomatic1000Entry] {
        sitchVM.activeEntries
    }

    var selectedEntries: [Sitchomatic1000Entry] {
        selectedEntryIds.compactMap { entryId in
            selectableEntries.first(where: { $0.id == entryId })
        }
    }

    var windowsMissingFlow: [Sitchomatic1000Entry] {
        selectedEntries.filter { !$0.hasFlow }
    }

    var windowsMissingCredentials: [Sitchomatic1000Entry] {
        selectedEntries.filter { !$0.hasCredentials }
    }

    var startBlockers: [String] {
        windowsMissingFlow.map { "\($0.label) — assign a flow" } + windowsMissingCredentials.map { "\($0.label) — add credentials" }
    }

    var canStart: Bool {
        !selectedEntries.isEmpty && startBlockers.isEmpty && !isRunning
    }

    func slotNumber(for entryId: String) -> Int? {
        guard let idx = selectedEntryIds.firstIndex(of: entryId) else { return nil }
        return idx + 1
    }

    func isSelected(_ entryId: String) -> Bool {
        selectedEntryIds.contains(entryId)
    }

    func toggleSelection(_ entryId: String) {
        guard selectableEntries.contains(where: { $0.id == entryId }) else { return }

        if let idx = selectedEntryIds.firstIndex(of: entryId) {
            selectedEntryIds.remove(at: idx)
        } else if selectedEntryIds.count < Self.maxSlots {
            selectedEntryIds.append(entryId)
        }
    }

    func pruneSelection() {
        let activeIds = Set(selectableEntries.map(\.id))
        selectedEntryIds.removeAll { !activeIds.contains($0) }
        if selectedEntryIds.count > Self.maxSlots {
            selectedEntryIds = Array(selectedEntryIds.prefix(Self.maxSlots))
        }
    }

    func startAll() {
        pruneSelection()
        guard canStart else { return }

        tearDownSlots()
        isRunning = true

        let flows = flowPersistence.loadFlows()
        let entries = Array(selectedEntries.prefix(Self.maxSlots))

        slots = entries.map(makeSlot)

        for slot in slots {
            guard let entry = entries.first(where: { $0.id == slot.entryId }) else { continue }
            slot.task = Task { [weak self, weak slot] in
                guard let self, let slot else { return }
                await self.runSlotLoop(slot: slot, entry: entry, flows: flows)
                await self.handleSlotCompletion(slotId: slot.id)
            }
        }
    }

    func stopAll() {
        isRunning = false
        tearDownSlots()
    }

    func resetSession() {
        stopAll()
    }

    func promoteToBig(slotIndex: Int) {
        guard slotIndex > 0, slotIndex < slots.count else { return }
        slots.swapAt(0, slotIndex)
    }

    private func makeSlot(for entry: Sitchomatic1000Entry) -> Slot {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.userContentController = WKUserContentController()
        CookieBannerBlockerScript.addIfEnabled(to: config.userContentController)

        config.websiteDataStore = .nonPersistent()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.processPool = WKProcessPool()

        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 844), configuration: config)
        webView.isInspectable = true
        webView.allowsBackForwardNavigationGestures = false
        webView.scrollView.isScrollEnabled = true

        let profile = PPSRStealthService.shared.nextProfileSync()
        webView.customUserAgent = profile.userAgent

        let navigationDelegate = SlotNavigationDelegate()
        webView.navigationDelegate = navigationDelegate

        return Slot(
            entryId: entry.id,
            webView: webView,
            engine: FlowPlaybackEngine(),
            navigationDelegate: navigationDelegate
        )
    }

    private func tearDownSlots() {
        for slot in slots {
            slot.cancelled = true
            slot.engine.cancel()
            slot.task?.cancel()
            slot.navigationDelegate.onFinish = nil
            slot.navigationDelegate.onFail = nil
            slot.webView.navigationDelegate = nil
            slot.webView.stopLoading()
        }
        slots.removeAll()
    }

    private func handleSlotCompletion(slotId: String) async {
        guard let slot = slots.first(where: { $0.id == slotId }) else { return }
        slot.task = nil

        guard isRunning else { return }
        let hasRunningTasks = slots.contains { $0.task != nil }
        guard !hasRunningTasks else { return }

        isRunning = false
    }

    private func runSlotLoop(slot: Slot, entry: Sitchomatic1000Entry, flows: [RecordedFlow]) async {
        guard let flowId = entry.assignedFlowId,
              let flow = flows.first(where: { $0.id == flowId }) else {
            slot.status = .error("No flow")
            slot.resultMessage = "Assigned flow not found"
            slot.encounteredError = true
            return
        }

        let credentials = entry.credentialList
        guard !credentials.isEmpty else {
            slot.status = .error("No credentials")
            slot.resultMessage = "Add credentials before starting"
            slot.encounteredError = true
            return
        }

        slot.credentialCount = credentials.count
        slot.completedCredentialCount = 0
        slot.encounteredError = false

        for (index, credential) in credentials.enumerated() {
            if slot.cancelled || Task.isCancelled { return }

            slot.credentialIndex = index
            slot.activeCredentialEmail = credential.email

            let success = await runOnce(
                slot: slot,
                flow: flow,
                entry: entry,
                email: credential.email,
                password: credential.password
            )

            if slot.cancelled || Task.isCancelled { return }

            slot.completedCredentialCount = index + 1
            if !success {
                slot.encounteredError = true
            }

            if index < credentials.count - 1 {
                try? await Task.sleep(for: .seconds(1.2))
            }
        }

        guard !slot.cancelled else { return }

        if slot.encounteredError {
            slot.status = .error("Completed with errors")
            slot.resultMessage = "Completed \(slot.completedCredentialCount)/\(slot.credentialCount) credentials with errors"
        } else {
            slot.status = .done
            slot.resultMessage = "Completed all \(slot.credentialCount) credentials"
        }
    }

    private func runOnce(
        slot: Slot,
        flow: RecordedFlow,
        entry: Sitchomatic1000Entry,
        email: String,
        password: String
    ) async -> Bool {
        slot.status = .loading
        slot.currentStep = 0
        slot.totalSteps = flow.actions.count
        slot.resultMessage = "Loading \(entry.label)…"

        guard let url = Self.normalizeURL(entry.url) else {
            slot.status = .error("Invalid URL")
            slot.resultMessage = "Invalid URL: \(entry.url)"
            return false
        }

        let navigationResult = await loadPage(url: url, in: slot)
        switch navigationResult {
        case .finished:
            break
        case .timedOut:
            slot.resultMessage = "Load timeout — continuing"
            try? await Task.sleep(for: .milliseconds(400))
        case .failed(let message):
            slot.status = .error(message)
            slot.resultMessage = message
            return false
        }

        if slot.cancelled || Task.isCancelled { return false }

        slot.status = .running
        slot.resultMessage = "Running \(slot.credentialIndex + 1)/\(slot.credentialCount)"

        let textboxValues: [String: String] = [
            FlowPlaceholderToken.userEmail.templateKey: email,
            FlowPlaceholderToken.userPassword.templateKey: password,
            "Email": email,
            "Password": password
        ]

        let playbackWaiter = PlaybackWaiter()
        let playbackSuccess = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            playbackWaiter.continuation = continuation
            Task { @MainActor in
                await slot.engine.playFlow(
                    flow,
                    in: slot.webView,
                    textboxValues: textboxValues,
                    onProgress: { [weak slot] current, total in
                        guard let slot else { return }
                        slot.currentStep = current
                        slot.totalSteps = total
                    },
                    onComplete: { success in
                        playbackWaiter.resolve(success)
                    }
                )
            }
        }

        if slot.cancelled || Task.isCancelled { return false }

        if playbackSuccess {
            slot.status = .done
            slot.resultMessage = "Credential \(slot.credentialIndex + 1)/\(slot.credentialCount) complete"
        } else {
            slot.status = .error("Playback failed")
            slot.resultMessage = "Credential \(slot.credentialIndex + 1)/\(slot.credentialCount) failed"
        }

        return playbackSuccess
    }

    static func normalizeURL(_ raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let withScheme: String
        if trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://") {
            withScheme = trimmed
        } else {
            withScheme = "https://" + trimmed
        }
        guard let url = URL(string: withScheme), url.host != nil else { return nil }
        return url
    }

    private func loadPage(url: URL, in slot: Slot) async -> NavigationResult {
        let waiter = NavigationWaiter()

        slot.navigationDelegate.onFinish = {
            waiter.resolve(.finished)
        }
        slot.navigationDelegate.onFail = { message in
            waiter.resolve(.failed(message))
        }

        slot.webView.load(URLRequest(url: url))

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(12))
            waiter.resolve(.timedOut)
        }

        let result = await withCheckedContinuation { (continuation: CheckedContinuation<NavigationResult, Never>) in
            waiter.continuation = continuation
        }

        slot.navigationDelegate.onFinish = nil
        slot.navigationDelegate.onFail = nil
        return result
    }
}
