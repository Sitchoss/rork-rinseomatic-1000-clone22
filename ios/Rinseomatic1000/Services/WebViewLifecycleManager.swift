import Foundation
@preconcurrency import WebKit
import UIKit

@MainActor
final class WebViewLifecycleManager {
    static let shared = WebViewLifecycleManager()

    private let logger = DebugLogger.shared

    private let zombieTable = NSHashTable<WKWebView>.weakObjects()
    private var registrationTimestamps: [ObjectIdentifier: Date] = [:]
    private var zombieSweeperTask: Task<Void, Never>?
    private let zombieMaxLifetimeSeconds: TimeInterval = 600
    private let zombieCheckIntervalSeconds: TimeInterval = 300
    private var isPaused: Bool = false

    private init() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.pauseSweeper()
            }
        }

        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.resumeSweeper()
            }
        }
    }

    func startZombieSweeper() {
        guard zombieSweeperTask == nil else { return }
        logger.log("Janitor: zombie sweeper STARTED (interval=\(Int(zombieCheckIntervalSeconds))s, maxLife=\(Int(zombieMaxLifetimeSeconds))s)", category: .system, level: .info)
        zombieSweeperTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(self?.zombieCheckIntervalSeconds ?? 300))
                } catch {
                    return
                }
                guard let self, !self.isPaused else { continue }
                self.sweepZombies()
            }
        }
    }

    func stopZombieSweeper() {
        zombieSweeperTask?.cancel()
        zombieSweeperTask = nil
        logger.log("Janitor: zombie sweeper STOPPED", category: .system, level: .info)
    }

    func registerWebView(_ webView: WKWebView) {
        let id = ObjectIdentifier(webView)
        zombieTable.add(webView)
        registrationTimestamps[id] = Date()
    }

    func unregisterWebView(_ webView: WKWebView) {
        let id = ObjectIdentifier(webView)
        zombieTable.remove(webView)
        registrationTimestamps.removeValue(forKey: id)
    }

    func performDeepClean(on webView: WKWebView) {
        let id = ObjectIdentifier(webView)
        logger.log("Janitor: performDeepClean BEGIN — \(id)", category: .webView, level: .info)

        webView.stopLoading()

        webView.navigationDelegate = nil
        webView.uiDelegate = nil

        let contentController = webView.configuration.userContentController
        contentController.removeAllUserScripts()

        let knownHandlers = ["apexBridge", "hyperflowBridge", "ppsrBridge", "sitchBridge", "logHandler"]
        for handler in knownHandlers {
            try? catchObjC { contentController.removeScriptMessageHandler(forName: handler) }
        }

        webView.removeFromSuperview()

        webView.configuration.websiteDataStore.removeData(
            ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
            modifiedSince: .distantPast
        ) { [weak self] in
            Task { @MainActor [weak self] in
                self?.logger.log("Janitor: XPC data purge COMPLETE — \(id)", category: .webView, level: .debug)
            }
        }

        zombieTable.remove(webView)
        registrationTimestamps.removeValue(forKey: id)

        logger.log("Janitor: performDeepClean DONE — delegates nil, scripts nuked, XPC purge queued", category: .webView, level: .success)
    }

    func performDeepCleanAsync(on webView: WKWebView) async {
        let id = ObjectIdentifier(webView)
        logger.log("Janitor: performDeepCleanAsync BEGIN — \(id)", category: .webView, level: .info)

        webView.stopLoading()
        webView.navigationDelegate = nil
        webView.uiDelegate = nil

        let contentController = webView.configuration.userContentController
        contentController.removeAllUserScripts()

        let knownHandlers = ["apexBridge", "hyperflowBridge", "ppsrBridge", "sitchBridge", "logHandler"]
        for handler in knownHandlers {
            try? catchObjC { contentController.removeScriptMessageHandler(forName: handler) }
        }

        webView.removeFromSuperview()

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            webView.configuration.websiteDataStore.removeData(
                ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
                modifiedSince: .distantPast
            ) {
                continuation.resume()
            }
        }

        zombieTable.remove(webView)
        registrationTimestamps.removeValue(forKey: id)

        logger.log("Janitor: performDeepCleanAsync DONE — \(id)", category: .webView, level: .success)
    }

    private func sweepZombies() {
        let now = Date()
        var zombiesFound = 0
        var zombiesCleaned = 0

        let allWebViews = zombieTable.allObjects
        logger.log("Janitor: sweep — \(allWebViews.count) tracked WebViews", category: .system, level: .trace)

        for webView in allWebViews {
            let id = ObjectIdentifier(webView)
            guard let registeredAt = registrationTimestamps[id] else {
                continue
            }

            let age = now.timeIntervalSince(registeredAt)
            if age > zombieMaxLifetimeSeconds {
                zombiesFound += 1
                logger.log("Janitor: ZOMBIE detected — age \(Int(age))s > \(Int(zombieMaxLifetimeSeconds))s limit — cleaning", category: .webView, level: .warning)
                performDeepClean(on: webView)
                zombiesCleaned += 1
            }
        }

        if zombiesFound > 0 {
            logger.log("Janitor: sweep complete — found \(zombiesFound) zombies, cleaned \(zombiesCleaned)", category: .system, level: .warning)
        }
    }

    private func pauseSweeper() {
        isPaused = true
        logger.log("Janitor: sweeper PAUSED (app backgrounded)", category: .system, level: .debug)
    }

    private func resumeSweeper() {
        isPaused = false
        logger.log("Janitor: sweeper RESUMED (app foregrounded)", category: .system, level: .debug)
    }

    var trackedCount: Int {
        zombieTable.allObjects.count
    }

    var diagnosticSummary: String {
        let tracked = zombieTable.allObjects.count
        let timestamps = registrationTimestamps.count
        return "Tracked: \(tracked) | Timestamps: \(timestamps) | Sweeper: \(zombieSweeperTask != nil ? "ACTIVE" : "STOPPED") | Paused: \(isPaused)"
    }

    private func catchObjC(_ block: () -> Void) throws {
        block()
    }
}
