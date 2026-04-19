import Foundation
import WebKit

nonisolated enum TripleClickError: Error, Sendable {
    case elementNotFound(selector: String)
    case javaScriptFailed(click: Int, detail: String)
    case cancelled
    case webViewUnavailable
}

@MainActor
final class TripleClickEngine {
    static let shared = TripleClickEngine()

    private let logger = DebugLogger.shared

    private var click1To2DelayMs: Int = 50
    private var click2To3DelayMs: Int = 50
    private var settingsObserver: NSObjectProtocol?

    private init() {
        loadSettings()
        settingsObserver = NotificationCenter.default.addObserver(forName: .automationSettingsDidChange, object: nil, queue: .main) { [weak self] _ in
            self?.loadSettings()
        }
    }

    deinit {
        if let observer = settingsObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func loadSettings() {
        let s = AutomationSettingsPersistence.shared.load()
        click1To2DelayMs = s.tripleClickInterClickDelayMs
        click2To3DelayMs = s.tripleClickInterClickDelayMs
    }

    func executeTripleClickSubmitSequence(
        targetSelector: String,
        in webView: WKWebView,
        sessionId: String = ""
    ) async throws {
        logger.log("TripleClickEngine: BEGIN sequence selector='\(targetSelector)' interClickDelay=\(click1To2DelayMs)ms", category: .automation, level: .info, sessionId: sessionId)

        let scrollJS = buildScrollIntoViewJS(selector: targetSelector)
        let scrollResult = try await evaluateJS(scrollJS, in: webView, clickNumber: 0, sessionId: sessionId)
        if scrollResult == "NOT_FOUND" {
            logger.log("TripleClickEngine: element NOT_FOUND for '\(targetSelector)'", category: .automation, level: .error, sessionId: sessionId)
            throw TripleClickError.elementNotFound(selector: targetSelector)
        }

        guard !Task.isCancelled else { throw TripleClickError.cancelled }

        let click1JS = buildSyntheticClickJS(selector: targetSelector, clickIndex: 1)
        let r1 = try await evaluateJS(click1JS, in: webView, clickNumber: 1, sessionId: sessionId)
        logger.log("TripleClickEngine: click 1/3 → \(r1)", category: .automation, level: .trace, sessionId: sessionId)

        guard !Task.isCancelled else { throw TripleClickError.cancelled }
        logger.log("TripleClickEngine: delay \(click1To2DelayMs)ms (click 1→2)", category: .automation, level: .trace, sessionId: sessionId)
        try await Task.sleep(for: .milliseconds(click1To2DelayMs))
        guard !Task.isCancelled else { throw TripleClickError.cancelled }

        let click2JS = buildSyntheticClickJS(selector: targetSelector, clickIndex: 2)
        let r2 = try await evaluateJS(click2JS, in: webView, clickNumber: 2, sessionId: sessionId)
        logger.log("TripleClickEngine: click 2/3 → \(r2)", category: .automation, level: .trace, sessionId: sessionId)

        guard !Task.isCancelled else { throw TripleClickError.cancelled }
        logger.log("TripleClickEngine: delay \(click2To3DelayMs)ms (click 2→3)", category: .automation, level: .trace, sessionId: sessionId)
        try await Task.sleep(for: .milliseconds(click2To3DelayMs))
        guard !Task.isCancelled else { throw TripleClickError.cancelled }

        let click3JS = buildSyntheticClickJS(selector: targetSelector, clickIndex: 3)
        let r3 = try await evaluateJS(click3JS, in: webView, clickNumber: 3, sessionId: sessionId)
        logger.log("TripleClickEngine: click 3/3 → \(r3)", category: .automation, level: .trace, sessionId: sessionId)

        guard !Task.isCancelled else { throw TripleClickError.cancelled }

        logger.log("TripleClickEngine: COMPLETE — 3/3 clicks dispatched (\(click1To2DelayMs)ms+\(click2To3DelayMs)ms inter-click gaps)", category: .automation, level: .success, sessionId: sessionId)
    }

    func executeTripleClickSubmitSequence(
        targetSelector: String,
        executeJS: @escaping (String) async -> String?,
        sessionId: String = ""
    ) async throws {
        logger.log("TripleClickEngine: BEGIN (closure) selector='\(targetSelector)'", category: .automation, level: .info, sessionId: sessionId)

        let scrollJS = buildScrollIntoViewJS(selector: targetSelector)
        let scrollResult = await executeJS(scrollJS)
        if scrollResult == "NOT_FOUND" || scrollResult == nil {
            logger.log("TripleClickEngine: element NOT_FOUND for '\(targetSelector)'", category: .automation, level: .error, sessionId: sessionId)
            throw TripleClickError.elementNotFound(selector: targetSelector)
        }

        guard !Task.isCancelled else { throw TripleClickError.cancelled }

        let click1JS = buildSyntheticClickJS(selector: targetSelector, clickIndex: 1)
        let r1 = await executeJS(click1JS) ?? "nil"
        logger.log("TripleClickEngine: click 1/3 → \(r1)", category: .automation, level: .trace, sessionId: sessionId)

        guard !Task.isCancelled else { throw TripleClickError.cancelled }
        try await Task.sleep(for: .milliseconds(click1To2DelayMs))
        guard !Task.isCancelled else { throw TripleClickError.cancelled }

        let click2JS = buildSyntheticClickJS(selector: targetSelector, clickIndex: 2)
        let r2 = await executeJS(click2JS) ?? "nil"
        logger.log("TripleClickEngine: click 2/3 → \(r2)", category: .automation, level: .trace, sessionId: sessionId)

        guard !Task.isCancelled else { throw TripleClickError.cancelled }
        try await Task.sleep(for: .milliseconds(click2To3DelayMs))
        guard !Task.isCancelled else { throw TripleClickError.cancelled }

        let click3JS = buildSyntheticClickJS(selector: targetSelector, clickIndex: 3)
        let r3 = await executeJS(click3JS) ?? "nil"
        logger.log("TripleClickEngine: click 3/3 → \(r3)", category: .automation, level: .trace, sessionId: sessionId)

        guard !Task.isCancelled else { throw TripleClickError.cancelled }

        logger.log("TripleClickEngine: COMPLETE — 3/3 clicks dispatched", category: .automation, level: .success, sessionId: sessionId)
    }

    private func buildScrollIntoViewJS(selector: String) -> String {
        let escaped = selector.replacingOccurrences(of: "'", with: "\\'")
        return """
        (function(){
            var el=document.querySelector('\(escaped)');
            if(!el) return 'NOT_FOUND';
            el.scrollIntoView({behavior:'instant',block:'center'});
            return 'SCROLLED';
        })()
        """
    }

    private func buildSyntheticClickJS(selector: String, clickIndex: Int) -> String {
        let escaped = selector.replacingOccurrences(of: "'", with: "\\'")
        return """
        (function(){
            var el=document.querySelector('\(escaped)');
            if(!el) return 'NOT_FOUND_\(clickIndex)';
            var r=el.getBoundingClientRect();
            if(r.width===0&&r.height===0) return 'ZERO_SIZE_\(clickIndex)';
            var cx=r.left+r.width*(0.3+Math.random()*0.4);
            var cy=r.top+r.height*(0.3+Math.random()*0.4);
            el.dispatchEvent(new MouseEvent('mousedown',{bubbles:true,cancelable:true,view:window,clientX:cx,clientY:cy,button:0,buttons:1}));
            el.dispatchEvent(new MouseEvent('mouseup',{bubbles:true,cancelable:true,view:window,clientX:cx,clientY:cy,button:0}));
            el.dispatchEvent(new MouseEvent('click',{bubbles:true,cancelable:true,view:window,clientX:cx,clientY:cy,button:0}));
            return 'CLICKED_\(clickIndex)';
        })()
        """
    }

    @discardableResult
    private func evaluateJS(_ js: String, in webView: WKWebView, clickNumber: Int, sessionId: String) async throws -> String {
        do {
            let result = try await webView.evaluateJavaScript(js)
            if let str = result as? String { return str }
            return String(describing: result ?? "null")
        } catch {
            let detail = error.localizedDescription
            logger.log("TripleClickEngine: JS error on click \(clickNumber) — \(detail)", category: .automation, level: .error, sessionId: sessionId)
            throw TripleClickError.javaScriptFailed(click: clickNumber, detail: detail)
        }
    }
}
