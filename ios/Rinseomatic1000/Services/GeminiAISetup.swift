import Foundation

@MainActor
enum GeminiAISetup {

    @discardableResult
    static func configure(apiKey: String) -> Bool {
        guard !apiKey.isEmpty else {
            DebugLogger.shared.log("GeminiAISetup: empty API key rejected", category: .automation, level: .error)
            return false
        }
        let stored = GeminiKeychain.shared.setAPIKey(apiKey)
        if stored {
            DebugLogger.shared.log("GeminiAISetup: API key configured ✓", category: .automation, level: .success)
        } else {
            DebugLogger.shared.log("GeminiAISetup: failed to store API key in Keychain", category: .automation, level: .error)
        }
        return stored
    }

    @discardableResult
    static func bootstrapFromEnvironment() -> Bool {
        let envKey = Config.allValues["EXPO_PUBLIC_GEMINI_API_KEY"] ?? ""
        guard !envKey.isEmpty else {
            DebugLogger.shared.log("GeminiAISetup: no public Gemini API key exposed to this build", category: .automation, level: .warning)
            return GeminiKeychain.shared.hasAPIKey
        }
        let stored = GeminiKeychain.shared.setAPIKey(envKey)
        if stored {
            DebugLogger.shared.log("GeminiAISetup: bootstrapped API key from Config ✓", category: .automation, level: .success)
        }
        return stored
    }

    static var isConfigured: Bool {
        GeminiKeychain.shared.hasAPIKey
    }

    static func reset() {
        GeminiKeychain.shared.removeAPIKey()
        DebugLogger.shared.log("GeminiAISetup: API key removed", category: .automation, level: .info)
    }
}

// MARK: - Dedicated Keychain Manager for Gemini
@MainActor
final class GeminiKeychain {
    static let shared = GeminiKeychain()
    private let keyIdentifier = "com.sitchomatic.gemini.apikey"
    private var cachedKey: String?
    
    var hasAPIKey: Bool {
        getAPIKey() != nil
    }
    
    @discardableResult
    func setAPIKey(_ key: String) -> Bool {
        cachedKey = key
        guard let data = key.data(using: .utf8) else { return false }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keyIdentifier
        ]
        
        SecItemDelete(query as CFDictionary)
        
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keyIdentifier,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    func getAPIKey() -> String? {
        if let cached = cachedKey { return cached }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keyIdentifier,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess, let data = dataTypeRef as? Data {
            let key = String(data: data, encoding: .utf8)
            cachedKey = key
            return key
        }
        return nil
    }
    
    func removeAPIKey() {
        cachedKey = nil
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keyIdentifier
        ]
        SecItemDelete(query as CFDictionary)
    }
}
