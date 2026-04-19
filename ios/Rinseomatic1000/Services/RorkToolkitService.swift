import Foundation
import UIKit

// MARK: - Legacy Grok Usage Stats (routes to Gemini stats)

@MainActor
final class GrokUsageStats {
    static let shared = GrokUsageStats()

    var totalCalls: Int { GeminiUsageStats.shared.totalCalls }
    var successfulCalls: Int { GeminiUsageStats.shared.successfulCalls }
    var failedCalls: Int { GeminiUsageStats.shared.failedCalls }
    var totalTokensUsed: Int { GeminiUsageStats.shared.totalTokensUsed }
    var lastError: String? { GeminiUsageStats.shared.lastError }
    var lastCallTime: Date? { GeminiUsageStats.shared.lastCallTime }
    var currentModel: String { GeminiUsageStats.shared.currentModel }
    var successRate: Double { GeminiUsageStats.shared.successRate }

    func reset() { GeminiUsageStats.shared.reset() }
}

// MARK: - Legacy Model Enum

nonisolated enum GrokModel: String, Sendable {
    case standard = "grok-3-fast"
    case mini = "grok-3-mini-fast"
    case vision = "grok-2-vision-latest"

    var gemini: GeminiModel {
        switch self {
        case .standard: return .pro
        case .mini: return .flashLite
        case .vision: return .flash
        }
    }
}

// MARK: - Legacy Vision Result

nonisolated struct GrokVisionAnalysisResult: Sendable {
    let loginSuccessful: Bool
    let hasError: Bool
    let errorText: String
    let accountDisabled: Bool
    let isPermanentBan: Bool
    let isTempLock: Bool
    let captchaDetected: Bool
    let ppsrPassed: Bool
    let ppsrDeclined: Bool
    let rawResponse: String
    let confidence: Int

    init(from g: GeminiVisionAnalysisResult) {
        self.loginSuccessful = g.loginSuccessful
        self.hasError = g.hasError
        self.errorText = g.errorText
        self.accountDisabled = g.accountDisabled
        self.isPermanentBan = g.isPermanentBan
        self.isTempLock = g.isTempLock
        self.captchaDetected = g.captchaDetected
        self.ppsrPassed = g.ppsrPassed
        self.ppsrDeclined = g.ppsrDeclined
        self.rawResponse = g.rawResponse
        self.confidence = g.confidence
    }
}

// MARK: - Compatibility Shim — routes all "Grok" calls to Gemini

@MainActor
final class RorkToolkitService {
    static let shared = RorkToolkitService()

    private let gemini = GeminiAIService.shared

    // MARK: Text Generation

    func generateText(
        systemPrompt: String,
        userPrompt: String,
        model: GrokModel = .standard,
        jsonMode: Bool = false,
        temperature: Double = 0.3
    ) async -> String? {
        await gemini.generateText(
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            model: model.gemini,
            jsonMode: jsonMode,
            temperature: temperature
        )
    }

    func generateFast(systemPrompt: String, userPrompt: String) async -> String? {
        await gemini.generateFast(systemPrompt: systemPrompt, userPrompt: userPrompt)
    }

    // MARK: Vision

    func analyzeScreenshotWithVision(image: UIImage, prompt: String) async -> GrokVisionAnalysisResult? {
        guard let raw = await gemini.analyzeScreenshotWithVision(image: image, prompt: prompt) else { return nil }
        // Parse via Gemini's parser by re-routing through analyzeLoginScreenshot style decode
        let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let jsonStr: String
        if let start = cleaned.range(of: "{"), let end = cleaned.range(of: "}", options: .backwards) {
            jsonStr = String(cleaned[start.lowerBound...end.upperBound])
        } else {
            jsonStr = cleaned
        }
        guard let data = jsonStr.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        let g = GeminiVisionAnalysisResult(
            loginSuccessful: dict["loginSuccessful"] as? Bool ?? false,
            hasError: dict["hasError"] as? Bool ?? false,
            errorText: dict["errorText"] as? String ?? "",
            accountDisabled: dict["accountDisabled"] as? Bool ?? false,
            isPermanentBan: dict["isPermanentBan"] as? Bool ?? false,
            isTempLock: dict["isTempLock"] as? Bool ?? false,
            captchaDetected: dict["captchaDetected"] as? Bool ?? false,
            ppsrPassed: dict["ppsrPassed"] as? Bool ?? false,
            ppsrDeclined: dict["ppsrDeclined"] as? Bool ?? false,
            rawResponse: raw,
            confidence: dict["confidence"] as? Int ?? 50
        )
        return GrokVisionAnalysisResult(from: g)
    }

    func analyzeLoginScreenshot(_ image: UIImage) async -> GrokVisionAnalysisResult? {
        guard let g = await gemini.analyzeLoginScreenshot(image) else { return nil }
        return GrokVisionAnalysisResult(from: g)
    }

    func analyzePPSRScreenshot(_ image: UIImage) async -> GrokVisionAnalysisResult? {
        guard let g = await gemini.analyzePPSRScreenshot(image) else { return nil }
        return GrokVisionAnalysisResult(from: g)
    }

    // MARK: Connection Test

    func testConnection() async -> (success: Bool, latencyMs: Int, model: String) {
        await gemini.testConnection()
    }
}
