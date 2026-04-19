import Foundation
import WebKit

@MainActor
class SecureProxyURLSchemeHandler: NSObject, WKURLSchemeHandler {
    private let target: ProxyRotationService.ProxyTarget
    private let networkConfig: ActiveNetworkConfig
    private let credentialId: String?
    
    // Maintain a map of active tasks to URLSessionDataTasks
    private var activeTasks: [Int: URLSessionDataTask] = [:]
    private var activeSchemeTasks: [Int: WKURLSchemeTask] = [:]
    
    private lazy var urlSession: URLSession = {
        let config = NetworkSessionFactory.shared.buildURLSessionProxyConfiguration(
            for: networkConfig,
            target: target,
            credentialId: credentialId
        )
        // Enable pipelining for multiplexing within the SOCKS tunnel
        config.httpShouldUsePipelining = true
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()
    
    init(target: ProxyRotationService.ProxyTarget, networkConfig: ActiveNetworkConfig, credentialId: String? = nil) {
        self.target = target
        self.networkConfig = networkConfig
        self.credentialId = credentialId
        super.init()
    }
    
    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let originalURL = urlSchemeTask.request.url else { return }
        
        // Custom scheme fallback: translate `sitch-https` to `https` 
        // Or if the system allowed overriding `https`, the scheme will already be correct.
        var components = URLComponents(url: originalURL, resolvingAgainstBaseURL: false)
        if components?.scheme == "sitch-https" {
            components?.scheme = "https"
        } else if components?.scheme == "sitch-http" {
            components?.scheme = "http"
        }
        
        guard let finalURL = components?.url, let host = finalURL.host?.lowercased() else { return }
        
        // Global interception for the flow-recorder test domain
        if host == "flow-recorder.local" {
            let html = """
            <!DOCTYPE html>
            <html>
            <head>
                <title>Automation Test Target</title>
                <meta name="viewport" content="width=device-width, initial-scale=1">
                <style>
                    body { font-family: sans-serif; padding: 20px; }
                    input { display: block; margin-bottom: 10px; padding: 8px; width: 100%; max-width: 300px; }
                    button { padding: 10px 20px; background: #007aff; color: white; border: none; border-radius: 4px; }
                    .error-banner { color: white; background: red; padding: 10px; display: none; margin-bottom: 10px; }
                </style>
            </head>
            <body>
                <h1>Local Automation Target</h1>
                <div class="error-banner" id="error-banner"></div>
                <form id="login-form" action="/submit" method="post" onsubmit="event.preventDefault(); document.getElementById('error-banner').style.display='block'; document.getElementById('error-banner').innerText='temporarily disabled';">
                    <input type="text" id="email" name="email" placeholder="Email Address" />
                    <input type="text" id="username" name="username" placeholder="Username" />
                    <input type="password" id="password" name="password" placeholder="Password" />
                    <input type="password" id="login-password" name="login-password" placeholder="Password" />
                    <button type="submit" id="submit" class="submit-btn primary">Log in</button>
                    <button type="submit" id="login-submit" class="login-button">Log In To Account</button>
                </form>
                <div style="height: 2000px; background: linear-gradient(to bottom, #fff, #eee); margin-top: 50px;"></div>
                <div style="position: absolute; top: 1500px;">
                    <input type="text" id="far-field" placeholder="Scroll to me" />
                </div>
            </body>
            </html>
            """
            
            let response = HTTPURLResponse(url: finalURL, statusCode: 200, httpVersion: "1.1", headerFields: ["Content-Type": "text/html; charset=utf-8"])!
            
            urlSchemeTask.didReceive(response)
            urlSchemeTask.didReceive(html.data(using: .utf8)!)
            urlSchemeTask.didFinish()
            return
        }
        
        let blocklist = ["doubleclick.net", "facebook.com", "google-analytics.com", "hotjar.com"]
        let lowerHost = host
        
        if blocklist.contains(where: { lowerHost.contains($0) }) {
            let error = NSError(domain: "ZeroTrustPolicy", code: 403, userInfo: [NSLocalizedDescriptionKey: "Origin blocked by Zero-Trust policy"])
            urlSchemeTask.didFailWithError(error)
            return
        }
        
        var request = urlSchemeTask.request
        request.url = finalURL
        
        let dataTask = urlSession.dataTask(with: request)
        activeTasks[urlSchemeTask.hash] = dataTask
        activeSchemeTasks[dataTask.taskIdentifier] = urlSchemeTask
        
        dataTask.resume()
    }
    
    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        if let dataTask = activeTasks.removeValue(forKey: urlSchemeTask.hash) {
            dataTask.cancel()
            activeSchemeTasks.removeValue(forKey: dataTask.taskIdentifier)
        }
    }
}

extension SecureProxyURLSchemeHandler: URLSessionDataDelegate {
    
    private func getSchemeTask(for task: URLSessionTask) -> WKURLSchemeTask? {
        return activeSchemeTasks[task.taskIdentifier]
    }
    
    nonisolated func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        Task { @MainActor in
            guard let schemeTask = self.getSchemeTask(for: dataTask) else {
                completionHandler(.cancel)
                return
            }
            schemeTask.didReceive(response)
            completionHandler(.allow)
        }
    }
    
    nonisolated func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        Task { @MainActor in
            guard let schemeTask = self.getSchemeTask(for: dataTask) else { return }
            schemeTask.didReceive(data)
        }
    }
    
    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        Task { @MainActor in
            guard let schemeTask = self.getSchemeTask(for: task) else { return }
            self.activeTasks.removeValue(forKey: schemeTask.hash)
            
            if let error = error {
                guard (error as NSError).code != NSURLErrorCancelled else { return }
                schemeTask.didFailWithError(error)
            } else {
                schemeTask.didFinish()
            }
        }
    }
    
    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        Task { @MainActor in
            guard let schemeTask = self.getSchemeTask(for: task) else {
                completionHandler(request)
                return
            }
            // WKURLSchemeTask doesn't have a direct redirection handler, 
            // but we must send the response to trigger WebKit's internal redirection follow.
            schemeTask.didReceive(response)
            completionHandler(request)
        }
    }
}
