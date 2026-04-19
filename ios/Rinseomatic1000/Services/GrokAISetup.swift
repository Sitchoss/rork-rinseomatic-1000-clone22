import Foundation

/// Legacy compatibility shim — all Grok setup now routes to GeminiAISetup.
@MainActor
enum GrokAISetup {
    @discardableResult
    static func configure(apiKey: String) -> Bool {
        GeminiAISetup.configure(apiKey: apiKey)
    }

    @discardableResult
    static func bootstrapFromEnvironment() -> Bool {
        GeminiAISetup.bootstrapFromEnvironment()
    }

    static var isConfigured: Bool {
        GeminiAISetup.isConfigured
    }

    static func reset() {
        GeminiAISetup.reset()
    }
}
