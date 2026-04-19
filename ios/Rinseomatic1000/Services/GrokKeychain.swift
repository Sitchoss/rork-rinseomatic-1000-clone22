import Foundation

/// Legacy compatibility shim — routes to GeminiKeychain.
@MainActor
final class GrokKeychain {
    static let shared = GrokKeychain()

    @discardableResult
    func setAPIKey(_ key: String) -> Bool {
        GeminiKeychain.shared.setAPIKey(key)
    }

    func getAPIKey() -> String? {
        GeminiKeychain.shared.getAPIKey()
    }

    @discardableResult
    func removeAPIKey() -> Bool {
        GeminiKeychain.shared.removeAPIKey()
        return true
    }

    var hasAPIKey: Bool {
        GeminiKeychain.shared.hasAPIKey
    }
}
