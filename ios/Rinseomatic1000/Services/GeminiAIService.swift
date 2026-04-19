import Foundation
import UIKit

// MARK: - Usage Stats (shared across Gemini + legacy Grok call sites)

@MainActor
final class GeminiUsageStats {
    static let shared = GeminiUsageStats()

    private(set) var totalCalls: Int = 0
    private(set) var successfulCalls: Int = 0
    private(set) var failedCalls: Int = 0
    private(set) var totalTokensUsed: Int = 0
    private(set) var lastError: String?
    private(set) var lastCallTime: Date?
    private(set) var currentModel: String = GeminiModel.pro.rawValue

    var successRate: Double {
        guard totalCalls > 0 else { return 0 }
        return Double(successfulCalls) / Double(totalCalls)
    }

    func recordSuccess(tokens: Int, model: String) {
        totalCalls += 1
        successfulCalls += 1
        totalTokensUsed += tokens
        lastCallTime = Date()
        currentModel = model
    }

    func recordFailure(error: String) {
        totalCalls += 1
        failedCalls += 1
        lastError = error
        lastCallTime = Date()
    }

    func reset() {
        totalCalls = 0
        successfulCalls = 0
        failedCalls = 0
        totalTokensUsed = 0
        lastError = nil
        lastCallTime = nil
    }
}

// MARK: - Models

nonisolated enum GeminiModel: String, Sendable {
    case pro = "gemini-2.5-pro"
    case flash = "gemini-2.5-flash"
    case flashLite = "gemini-2.5-flash-lite"
}

// MARK: - Service

@MainActor
final class GeminiAIService {
    static let shared = GeminiAIService()

    private let logger = DebugLogger.shared
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models/"
    private let maxRetries = 3
    private let visionMaxBytes = 4_000_000

    private var apiKey: String? {
        GeminiKeychain.shared.getAPIKey()
    }

    // MARK: - Core Execution

    func generateContent(
        prompt: String,
        images: [UIImage] = [],
        model: String = GeminiModel.pro.rawValue,
        jsonMode: Bool = false,
        temperature: Double = 0.2
    ) async -> String? {
        guard let key = apiKey, !key.isEmpty else {
            logger.log("GeminiAI: no API key — configure it in Gemini AI Status screen", category: .automation, level: .error)
            return nil
        }

        var parts: [[String: Any]] = [["text": prompt]]
        for image in images {
            if let base64 = encodeImage(image) {
                parts.append([
                    "inline_data": [
                        "mime_type": "image/jpeg",
                        "data": base64
                    ]
                ])
            }
        }

        var generationConfig: [String: Any] = ["temperature": temperature]
        if jsonMode {
            generationConfig["response_mime_type"] = "application/json"
        }

        let body: [String: Any] = [
            "contents": [["parts": parts]],
            "generationConfig": generationConfig
        ]

        return await callWithRetry(endpoint: "\(model):generateContent", body: body, key: key, model: model)
    }

    // MARK: - Text Generation (OpenAI-style API used by AI* services)

    func generateText(
        systemPrompt: String,
        userPrompt: String,
        model: GeminiModel = .pro,
        jsonMode: Bool = false,
        temperature: Double = 0.3
    ) async -> String? {
        let combined = "\(systemPrompt)\n\n\(userPrompt)"
        return await generateContent(
            prompt: combined,
            model: model.rawValue,
            jsonMode: jsonMode,
            temperature: temperature
        )
    }

    func generateFast(systemPrompt: String, userPrompt: String) async -> String? {
        await generateText(systemPrompt: systemPrompt, userPrompt: userPrompt, model: .flashLite, temperature: 0.1)
    }

    // MARK: - Generic JSON Extraction

    func extractJSON<T: Decodable>(
        prompt: String,
        images: [UIImage] = [],
        model: String = GeminiModel.flash.rawValue,
        type: T.Type
    ) async -> T? {
        guard let responseStr = await generateContent(prompt: prompt, images: images, model: model, jsonMode: true),
              let data = responseStr.data(using: .utf8) else {
            return nil
        }
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(T.self, from: data)
        } catch {
            logger.log("GeminiAI: JSON decode failed for \(T.self) — \(error.localizedDescription)", category: .automation, level: .error)
            return nil
        }
    }

    // MARK: - Vision Analysis

    func analyzeScreenshotWithVision(image: UIImage, prompt: String) async -> String? {
        return await generateContent(
            prompt: prompt,
            images: [image],
            model: GeminiModel.flash.rawValue,
            jsonMode: true,
            temperature: 0.1
        )
    }

    func analyzeLoginScreenshot(_ image: UIImage) async -> GeminiVisionAnalysisResult? {
        let prompt = """
        Analyze this casino/gambling website login page screenshot. Determine the exact result.

        Answer ONLY with JSON in this exact format:
        {
          "loginSuccessful": false,
          "hasError": false,
          "errorText": "",
          "accountDisabled": false,
          "isPermanentBan": false,
          "isTempLock": false,
          "captchaDetected": false,
          "confidence": 90
        }

        Rules:
        - loginSuccessful = true if you see a lobby, dashboard, game grid, or user balance — NOT the login form
        - accountDisabled = true if you see "has been disabled", "temporarily disabled", "account suspended", "contact support"
        - isPermanentBan = true ONLY if text says "has been disabled" (permanent)
        - isTempLock = true ONLY if text says "temporarily disabled"
        - hasError = true if there is a red banner, error message, or "incorrect password"
        - captchaDetected = true if there is a CAPTCHA or "I am not a robot" prompt
        - errorText = the exact error message text visible, empty string if none
        - confidence = 0–100 how confident you are
        """
        guard let raw = await analyzeScreenshotWithVision(image: image, prompt: prompt) else { return nil }
        return parseVisionResponse(raw)
    }

    func analyzePPSRScreenshot(_ image: UIImage) async -> GeminiVisionAnalysisResult? {
        let prompt = """
        Analyze this Australian PPSR vehicle check payment page screenshot.

        Answer ONLY with JSON:
        {
          "ppsrPassed": false,
          "ppsrDeclined": false,
          "hasError": false,
          "errorText": "",
          "confidence": 90
        }

        Rules:
        - ppsrPassed = true if you see a PPSR certificate, success message, or confirmation page
        - ppsrDeclined = true if you see "declined by your institution", "payment failed", "card declined", "insufficient funds"
        - hasError = true for any other visible error or failure message
        - errorText = exact error text or empty string
        """
        guard let raw = await analyzeScreenshotWithVision(image: image, prompt: prompt) else { return nil }
        return parseVisionResponse(raw)
    }

    func validateNavigationViaFlash(beforeImage: UIImage, afterImage: UIImage) async -> Bool {
        struct TransitionResult: Decodable { let transitioned: Bool }
        let prompt = """
        Two screenshots: first is BEFORE a click, second is AFTER.
        Did the UI completely transition (modal closed or page loaded)?
        Respond with JSON: {"transitioned": true|false}
        """
        let result = await extractJSON(prompt: prompt, images: [beforeImage, afterImage], type: TransitionResult.self)
        return result?.transitioned ?? false
    }

    // MARK: - Connection Test

    func testConnection() async -> (success: Bool, latencyMs: Int, model: String) {
        guard let key = apiKey, !key.isEmpty else {
            return (false, 0, "")
        }
        let start = Date()
        let result = await generateText(
            systemPrompt: "You are a test assistant.",
            userPrompt: "Reply with exactly: OK",
            model: .flashLite,
            temperature: 0.0
        )
        let latency = Int(Date().timeIntervalSince(start) * 1000)
        let ok = result?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased().contains("OK") == true
        _ = key
        return (ok, latency, GeminiModel.flashLite.rawValue)
    }

    // MARK: - Network

    private func callWithRetry(endpoint: String, body: [String: Any], key: String, model: String) async -> String? {
        var lastError = ""
        for attempt in 0..<maxRetries {
            if attempt > 0 {
                let delay = pow(2.0, Double(attempt - 1)) * 0.5
                try? await Task.sleep(for: .seconds(delay))
            }

            guard let url = URL(string: "\(baseURL)\(endpoint)?key=\(key)") else {
                GeminiUsageStats.shared.recordFailure(error: "Invalid URL")
                return nil
            }

            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.timeoutInterval = 45

            guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else {
                GeminiUsageStats.shared.recordFailure(error: "Serialization failed")
                return nil
            }
            req.httpBody = httpBody

            do {
                let (data, response) = try await URLSession.shared.data(for: req)
                guard let http = response as? HTTPURLResponse else { continue }

                if http.statusCode == 429 || http.statusCode >= 500 {
                    lastError = "HTTP \(http.statusCode)"
                    logger.log("GeminiAI: \(lastError) on attempt \(attempt + 1), retrying…", category: .automation, level: .warning)
                    continue
                }

                if http.statusCode != 200 {
                    let bodyStr = String(data: data, encoding: .utf8) ?? ""
                    lastError = "HTTP \(http.statusCode): \(bodyStr.prefix(200))"
                    GeminiUsageStats.shared.recordFailure(error: lastError)
                    logger.log("GeminiAI: \(lastError)", category: .automation, level: .error)
                    return nil
                }

                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let candidates = json["candidates"] as? [[String: Any]],
                   let first = candidates.first,
                   let content = first["content"] as? [String: Any],
                   let parts = content["parts"] as? [[String: Any]],
                   let firstPart = parts.first,
                   let text = firstPart["text"] as? String {
                    let usage = json["usageMetadata"] as? [String: Any]
                    let tokens = (usage?["totalTokenCount"] as? Int) ?? 0
                    GeminiUsageStats.shared.recordSuccess(tokens: tokens, model: model)
                    return text
                }
            } catch {
                lastError = error.localizedDescription
                logger.log("GeminiAI: request error on attempt \(attempt + 1) — \(lastError)", category: .automation, level: .warning)
            }
        }

        GeminiUsageStats.shared.recordFailure(error: lastError)
        logger.log("GeminiAI: all \(maxRetries) attempts failed — \(lastError)", category: .automation, level: .error)
        return nil
    }

    // MARK: - Utilities

    private func encodeImage(_ image: UIImage) -> String? {
        let targetSize = CGSize(width: 1280, height: 960)
        let scale = min(targetSize.width / image.size.width, targetSize.height / image.size.height, 1.0)
        let resized: UIImage
        if scale < 1.0 {
            let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let renderer = UIGraphicsImageRenderer(size: newSize)
            resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
        } else {
            resized = image
        }
        var quality: CGFloat = 0.8
        var data = resized.jpegData(compressionQuality: quality)
        while let d = data, d.count > visionMaxBytes, quality > 0.3 {
            quality -= 0.15
            data = resized.jpegData(compressionQuality: quality)
        }
        return data?.base64EncodedString()
    }

    private func parseVisionResponse(_ raw: String) -> GeminiVisionAnalysisResult {
        let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let jsonStr: String
        if let start = cleaned.range(of: "{"), let end = cleaned.range(of: "}", options: .backwards) {
            jsonStr = String(cleaned[start.lowerBound...end.upperBound])
        } else {
            jsonStr = cleaned
        }

        if let data = jsonStr.data(using: .utf8),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return GeminiVisionAnalysisResult(
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
        }

        let lower = raw.lowercased()
        return GeminiVisionAnalysisResult(
            loginSuccessful: lower.contains("lobby") || lower.contains("dashboard"),
            hasError: lower.contains("incorrect") || lower.contains("error"),
            errorText: "",
            accountDisabled: lower.contains("disabled") || lower.contains("suspended"),
            isPermanentBan: lower.contains("has been disabled"),
            isTempLock: lower.contains("temporarily disabled"),
            captchaDetected: lower.contains("captcha"),
            ppsrPassed: lower.contains("certificate"),
            ppsrDeclined: lower.contains("declined"),
            rawResponse: raw,
            confidence: 30
        )
    }
}

// MARK: - Vision Result Type

nonisolated struct GeminiVisionAnalysisResult: Sendable {
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
}
