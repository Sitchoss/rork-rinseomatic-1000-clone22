import WebKit

extension WKWebView {

    /// Safely evaluate JavaScript and return the result as a String, or nil on failure.
    func safeEvalJS(_ js: String) async -> String? {
        do {
            let result = try await evaluateJavaScript(js)
            if let str = result as? String { return str }
            if let num = result as? NSNumber { return "\(num)" }
            return nil
        } catch {
            return nil
        }
    }
}
