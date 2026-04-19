import Foundation

/// Bypasses WKWebView and executes headless data extraction directly via URLSession,
/// preserving stealth headers and routing through the active WireProxy tunneled NetworkSessionFactory.
@MainActor
final class HeadlessAPIClient {
    static let shared = HeadlessAPIClient()

    private let logger = DebugLogger.shared

    private init() {}

    func executeDataExtraction(
        url: URL,
        proxyTarget: ProxyRotationService.ProxyTarget,
        networkConfig: ActiveNetworkConfig = .direct,
        credentialId: String? = nil
    ) async throws -> Data {
        
        // Use the synchronized network session factory to inherit the correct VPN/WireProxy tunnel
        guard let session = NetworkSessionFactory.shared.createDataSession(
            config: networkConfig,
            target: proxyTarget,
            credentialId: credentialId
        ) else {
            throw URLError(.cannotConnectToHost)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        // Inject stealth headers from the holistic profile
        let stealth = PPSRStealthService.shared
        let host = url.host ?? ""
        let (profile, _) = await stealth.nextProfileForHost(host)
        
        request.setValue(profile.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(profile.language, forHTTPHeaderField: "Accept-Language")
        
        logger.log("HeadlessAPI: Fetching \(url.host ?? "") natively bypassing WKWebView.", category: .network, level: .info)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard (200...499).contains(httpResponse.statusCode) else {
            logger.log("HeadlessAPI: HTTP \(httpResponse.statusCode)", category: .network, level: .error)
            throw URLError(.badServerResponse)
        }
        
        return data
    }
}
