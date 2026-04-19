import Foundation
import WebKit

@MainActor
final class SubmitMethodRouter {
    static let shared = SubmitMethodRouter()

    private let tripleClickEngine = TripleClickEngine.shared
    private let logger = DebugLogger.shared

    nonisolated struct SubmitResult: Sendable {
        let success: Bool
        let method: AutomationSettings.SubmitMethod
        let detail: String
    }

    func executeSubmit(
        method: AutomationSettings.SubmitMethod,
        submitSelector: String,
        in webView: WKWebView,
        sessionId: String = ""
    ) async -> SubmitResult {
        logger.log("SubmitMethodRouter: dispatching \(method.rawValue) → selector '\(submitSelector)'", category: .automation, level: .info, sessionId: sessionId)

        switch method {
        case .tripleClickSynced:
            return await executeTripleClickSynced(selector: submitSelector, webView: webView, sessionId: sessionId)
        case .singleJSClick:
            return await executeSingleJSClick(selector: submitSelector, webView: webView, sessionId: sessionId)
        case .formSubmitDirect:
            return await executeFormSubmitDirect(webView: webView, sessionId: sessionId)
        case .pointerEventChain:
            return await executePointerEventChain(selector: submitSelector, webView: webView, sessionId: sessionId)
        case .enterKeySubmit:
            return await executeEnterKeySubmit(webView: webView, sessionId: sessionId)
        }
    }

    func executeSubmit(
        method: AutomationSettings.SubmitMethod,
        submitSelector: String,
        executeJS: @escaping (String) async -> String?,
        sessionId: String = ""
    ) async -> SubmitResult {
        logger.log("SubmitMethodRouter: dispatching (closure) \(method.rawValue) → selector '\(submitSelector)'", category: .automation, level: .info, sessionId: sessionId)

        switch method {
        case .tripleClickSynced:
            return await executeTripleClickSyncedClosure(selector: submitSelector, executeJS: executeJS, sessionId: sessionId)
        case .singleJSClick:
            return await executeSingleJSClickClosure(selector: submitSelector, executeJS: executeJS, sessionId: sessionId)
        case .formSubmitDirect:
            return await executeFormSubmitDirectClosure(executeJS: executeJS, sessionId: sessionId)
        case .pointerEventChain:
            return await executePointerEventChainClosure(selector: submitSelector, executeJS: executeJS, sessionId: sessionId)
        case .enterKeySubmit:
            return await executeEnterKeySubmitClosure(executeJS: executeJS, sessionId: sessionId)
        }
    }

    // MARK: - Triple-Click Synced (Phase 2 Engine)

    private func executeTripleClickSynced(selector: String, webView: WKWebView, sessionId: String) async -> SubmitResult {
        do {
            try await tripleClickEngine.executeTripleClickSubmitSequence(targetSelector: selector, in: webView, sessionId: sessionId)
            return SubmitResult(success: true, method: .tripleClickSynced, detail: "3-click sequence completed (240ms+260ms gaps)")
        } catch let error as TripleClickError {
            let detail: String
            switch error {
            case .elementNotFound(let sel): detail = "Element not found: \(sel)"
            case .javaScriptFailed(let click, let d): detail = "JS failed on click \(click): \(d)"
            case .cancelled: detail = "Cancelled"
            case .webViewUnavailable: detail = "WebView unavailable"
            }
            logger.log("SubmitMethodRouter: tripleClickSynced FAILED — \(detail)", category: .automation, level: .error, sessionId: sessionId)
            return SubmitResult(success: false, method: .tripleClickSynced, detail: detail)
        } catch {
            return SubmitResult(success: false, method: .tripleClickSynced, detail: error.localizedDescription)
        }
    }

    private func executeTripleClickSyncedClosure(selector: String, executeJS: @escaping (String) async -> String?, sessionId: String) async -> SubmitResult {
        do {
            try await tripleClickEngine.executeTripleClickSubmitSequence(targetSelector: selector, executeJS: executeJS, sessionId: sessionId)
            return SubmitResult(success: true, method: .tripleClickSynced, detail: "3-click sequence completed (240ms+260ms gaps)")
        } catch let error as TripleClickError {
            let detail: String
            switch error {
            case .elementNotFound(let sel): detail = "Element not found: \(sel)"
            case .javaScriptFailed(let click, let d): detail = "JS failed on click \(click): \(d)"
            case .cancelled: detail = "Cancelled"
            case .webViewUnavailable: detail = "WebView unavailable"
            }
            logger.log("SubmitMethodRouter: tripleClickSynced FAILED — \(detail)", category: .automation, level: .error, sessionId: sessionId)
            return SubmitResult(success: false, method: .tripleClickSynced, detail: detail)
        } catch {
            return SubmitResult(success: false, method: .tripleClickSynced, detail: error.localizedDescription)
        }
    }

    // MARK: - Single JS Click

    private func executeSingleJSClick(selector: String, webView: WKWebView, sessionId: String) async -> SubmitResult {
        let escaped = selector.replacingOccurrences(of: "'", with: "\\'")
        let js = """
        (function(){
            var el=document.querySelector('\(escaped)');
            if(!el) return 'NOT_FOUND';
            el.click();
            return 'CLICKED';
        })()
        """
        do {
            let result = try await webView.evaluateJavaScript(js)
            let str = (result as? String) ?? "null"
            let ok = str.contains("CLICKED")
            return SubmitResult(success: ok, method: .singleJSClick, detail: str)
        } catch {
            return SubmitResult(success: false, method: .singleJSClick, detail: error.localizedDescription)
        }
    }

    private func executeSingleJSClickClosure(selector: String, executeJS: @escaping (String) async -> String?, sessionId: String) async -> SubmitResult {
        let escaped = selector.replacingOccurrences(of: "'", with: "\\'")
        let js = """
        (function(){
            var el=document.querySelector('\(escaped)');
            if(!el) return 'NOT_FOUND';
            el.click();
            return 'CLICKED';
        })()
        """
        let result = await executeJS(js) ?? "nil"
        return SubmitResult(success: result.contains("CLICKED"), method: .singleJSClick, detail: result)
    }

    // MARK: - Form Submit Direct

    private func executeFormSubmitDirect(webView: WKWebView, sessionId: String) async -> SubmitResult {
        let js = JSInteractionBuilder.formSubmitJS()
        do {
            let result = try await webView.evaluateJavaScript(js)
            let str = (result as? String) ?? "null"
            let ok = str.contains("SUBMIT")
            return SubmitResult(success: ok, method: .formSubmitDirect, detail: str)
        } catch {
            return SubmitResult(success: false, method: .formSubmitDirect, detail: error.localizedDescription)
        }
    }

    private func executeFormSubmitDirectClosure(executeJS: @escaping (String) async -> String?, sessionId: String) async -> SubmitResult {
        let js = JSInteractionBuilder.formSubmitJS()
        let result = await executeJS(js) ?? "nil"
        return SubmitResult(success: result.contains("SUBMIT"), method: .formSubmitDirect, detail: result)
    }

    // MARK: - Pointer Event Chain

    private func executePointerEventChain(selector: String, webView: WKWebView, sessionId: String) async -> SubmitResult {
        let escaped = selector.replacingOccurrences(of: "'", with: "\\'")
        let js = buildPointerEventChainJS(escaped: escaped)
        do {
            let result = try await webView.evaluateJavaScript(js)
            let str = (result as? String) ?? "null"
            let ok = str.contains("POINTER_CLICKED")
            return SubmitResult(success: ok, method: .pointerEventChain, detail: str)
        } catch {
            return SubmitResult(success: false, method: .pointerEventChain, detail: error.localizedDescription)
        }
    }

    private func executePointerEventChainClosure(selector: String, executeJS: @escaping (String) async -> String?, sessionId: String) async -> SubmitResult {
        let escaped = selector.replacingOccurrences(of: "'", with: "\\'")
        let js = buildPointerEventChainJS(escaped: escaped)
        let result = await executeJS(js) ?? "nil"
        return SubmitResult(success: result.contains("POINTER_CLICKED"), method: .pointerEventChain, detail: result)
    }

    private func buildPointerEventChainJS(escaped: String) -> String {
        """
        (function(){
            var el=document.querySelector('\(escaped)');
            if(!el) return 'NOT_FOUND';
            var r=el.getBoundingClientRect();
            var cx=r.left+r.width*(0.3+Math.random()*0.4);
            var cy=r.top+r.height*(0.3+Math.random()*0.4);
            el.dispatchEvent(new PointerEvent('pointerdown',{bubbles:true,cancelable:true,view:window,clientX:cx,clientY:cy,pointerId:1,pointerType:'touch',button:0,buttons:1}));
            el.dispatchEvent(new TouchEvent('touchstart',{bubbles:true,cancelable:true,view:window}));
            el.dispatchEvent(new PointerEvent('pointerup',{bubbles:true,cancelable:true,view:window,clientX:cx,clientY:cy,pointerId:1,pointerType:'touch',button:0}));
            el.dispatchEvent(new TouchEvent('touchend',{bubbles:true,cancelable:true,view:window}));
            el.dispatchEvent(new MouseEvent('click',{bubbles:true,cancelable:true,view:window,clientX:cx,clientY:cy,button:0}));
            el.click();
            return 'POINTER_CLICKED';
        })()
        """
    }

    // MARK: - Enter Key Submit

    private func executeEnterKeySubmit(webView: WKWebView, sessionId: String) async -> SubmitResult {
        let js = JSInteractionBuilder.enterKeyOnPasswordJS()
        do {
            let result = try await webView.evaluateJavaScript(js)
            let str = (result as? String) ?? "null"
            let ok = str.contains("ENTER")
            return SubmitResult(success: ok, method: .enterKeySubmit, detail: str)
        } catch {
            return SubmitResult(success: false, method: .enterKeySubmit, detail: error.localizedDescription)
        }
    }

    private func executeEnterKeySubmitClosure(executeJS: @escaping (String) async -> String?, sessionId: String) async -> SubmitResult {
        let js = JSInteractionBuilder.enterKeyOnPasswordJS()
        let result = await executeJS(js) ?? "nil"
        return SubmitResult(success: result.contains("ENTER"), method: .enterKeySubmit, detail: result)
    }
}
