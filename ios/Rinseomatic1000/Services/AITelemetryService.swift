import Foundation
import SwiftUI
import Observation

nonisolated struct AITelemetryDiagnosis: Codable, Sendable, Identifiable {
    var id: String { signature }
    let signature: String
    let summary: String
    let category: String
    let suggestion: String
    let timestamp: Date
}

nonisolated struct AIBatchSummary: Codable, Sendable {
    let headline: String
    let bullets: [String]
    let total: Int
    let successes: Int
    let timestamp: Date
}

nonisolated struct AISessionStealthScore: Codable, Sendable, Identifiable {
    var id: String { sessionId }
    let sessionId: String
    let host: String
    let score: Int
    let reason: String
    let timestamp: Date

    var tier: StealthTier {
        if score >= 70 { return .healthy }
        if score >= 40 { return .warning }
        return .critical
    }

    nonisolated enum StealthTier: String, Sendable {
        case healthy, warning, critical

        var color: Color {
            switch self {
            case .healthy: .green
            case .warning: .orange
            case .critical: .red
            }
        }

        var label: String {
            switch self {
            case .healthy: "Good"
            case .warning: "Watch"
            case .critical: "Low"
            }
        }
    }
}

nonisolated struct AIFingerprintLeakAnalysis: Codable, Sendable {
    let summary: String
    let leaks: [String]
    let score: Int
    let timestamp: Date
}

@Observable
@MainActor
final class AITelemetryService {
    static let shared = AITelemetryService()

    private(set) var diagnoses: [String: AITelemetryDiagnosis] = [:]
    private(set) var currentBatchSummary: AIBatchSummary?
    private(set) var stealthScores: [String: AISessionStealthScore] = [:]
    private(set) var selfHealCount: Int = 0
    private(set) var averageStealthScore: Double = 0
    private(set) var topFailureReasons: [(reason: String, count: Int)] = []
    private(set) var healedSelectors: [String: [String: String]] = [:]
    private(set) var lastFingerprintAnalysis: AIFingerprintLeakAnalysis?

    private let logger = DebugLogger.shared
    private let gemini = GeminiAIService.shared
    private let persistKey = "AITelemetryStore_v1"
    private let selectorKey = "AITelemetryHealedSelectors_v1"
    private let diagnosisKey = "AITelemetryDiagnoses_v1"

    private var pendingDiagnosisSignatures: Set<String> = []
    private var runReasonBuckets: [String: Int] = [:]
    private var lastRunDate: Date?

    private init() {
        load()
    }

    var isEnabled: Bool { GeminiAISetup.isConfigured }

    // MARK: - Failure Diagnosis

    func diagnoseFailure(
        sessionId: String,
        host: String,
        email: String,
        rawOutcome: String,
        pageSnippet: String,
        errorText: String? = nil
    ) {
        guard isEnabled else { return }
        let signature = buildSignature(host: host, outcome: rawOutcome, error: errorText, snippet: pageSnippet)
        runReasonBuckets[signature, default: 0] += 1

        if diagnoses[signature] != nil || pendingDiagnosisSignatures.contains(signature) {
            return
        }
        pendingDiagnosisSignatures.insert(signature)

        Task { [weak self] in
            guard let self else { return }
            await self.performDiagnosis(
                signature: signature,
                host: host,
                email: email,
                rawOutcome: rawOutcome,
                pageSnippet: pageSnippet,
                errorText: errorText
            )
        }
    }

    func diagnosis(for sessionId: String, host: String, outcome: String, pageSnippet: String, errorText: String? = nil) -> AITelemetryDiagnosis? {
        let sig = buildSignature(host: host, outcome: outcome, error: errorText, snippet: pageSnippet)
        return diagnoses[sig]
    }

    private func performDiagnosis(
        signature: String,
        host: String,
        email: String,
        rawOutcome: String,
        pageSnippet: String,
        errorText: String?
    ) async {
        let snippet = String(pageSnippet.prefix(1200))
        let prompt = """
        You are a web automation failure diagnostician. Given the raw outcome, the page content snippet, and error text from a casino/gambling site login attempt, return a concise plain-English diagnosis.

        Host: \(host)
        Raw outcome: \(rawOutcome)
        Error text: \(errorText ?? "none")
        Page snippet: \(snippet)

        Respond ONLY in JSON:
        {
          "summary": "one short sentence, max 12 words",
          "category": "wrongPassword|geoBlock|rateLimit|captcha|layoutChange|accountLocked|networkError|other",
          "suggestion": "one short actionable hint, max 14 words"
        }
        """

        guard let raw = await gemini.generateContent(
            prompt: prompt,
            model: GeminiModel.flashLite.rawValue,
            jsonMode: true,
            temperature: 0.1
        ) else {
            pendingDiagnosisSignatures.remove(signature)
            return
        }

        let cleaned = extractJSON(raw)
        guard let data = cleaned.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            pendingDiagnosisSignatures.remove(signature)
            logger.log("AITelemetry: diagnosis parse failed for \(host)", category: .aiTelemetry, level: .warning)
            return
        }

        let summary = (dict["summary"] as? String) ?? "Unknown failure"
        let category = (dict["category"] as? String) ?? "other"
        let suggestion = (dict["suggestion"] as? String) ?? ""

        let diagnosis = AITelemetryDiagnosis(
            signature: signature,
            summary: summary,
            category: category,
            suggestion: suggestion,
            timestamp: Date()
        )

        diagnoses[signature] = diagnosis
        pendingDiagnosisSignatures.remove(signature)
        recomputeTopReasons()
        save()
        logger.log("AITelemetry: \(host) → \(summary) [\(category)]", category: .aiTelemetry, level: .info)
    }

    // MARK: - Stealth Scoring

    func computeStealthScore(
        sessionId: String,
        host: String,
        profileIndex: Int,
        profileStats: FingerprintProfileStats?,
        validationScore: Int?
    ) -> AISessionStealthScore {
        let detectionRate = profileStats?.detectionRate ?? 0
        let successRate = profileStats?.successRate ?? 0.5
        let useCount = profileStats?.useCount ?? 0
        let hostDetectionRate = profileStats?.detectionRateForHost(host) ?? 0

        var score = 65
        score += Int((1.0 - detectionRate) * 20)
        score += Int(successRate * 15)
        score -= Int(hostDetectionRate * 35)

        if let val = validationScore {
            let penalty = min(30, max(0, val - 3) * 3)
            score -= penalty
        }

        if let stats = profileStats, stats.isCoolingDown {
            score -= 40
        }

        if useCount < 2 { score -= 10 }

        score = max(0, min(100, score))

        var reason = "Clean profile"
        if score < 40 {
            reason = hostDetectionRate > 0.5 ? "High detection on \(host)" : "Fingerprint under pressure"
        } else if score < 70 {
            reason = detectionRate > 0.3 ? "Some detection history" : "Moderate risk profile"
        }

        let result = AISessionStealthScore(
            sessionId: sessionId,
            host: host,
            score: score,
            reason: reason,
            timestamp: Date()
        )
        stealthScores[sessionId] = result
        recomputeAverageStealth()
        return result
    }

    func stealthScore(for sessionId: String) -> AISessionStealthScore? {
        stealthScores[sessionId]
    }

    // MARK: - Self-Healing Selectors

    func recordSelectorHeal(host: String, field: String, newSelector: String) {
        var hostMap = healedSelectors[host] ?? [:]
        hostMap[field] = newSelector
        healedSelectors[host] = hostMap
        selfHealCount += 1
        save()
        logger.log("AITelemetry: self-healed \(field) on \(host) → \(newSelector)", category: .aiTelemetry, level: .success)
    }

    func healedSelector(host: String, field: String) -> String? {
        healedSelectors[host]?[field]
    }

    // MARK: - Batch Summary

    func beginRun() {
        runReasonBuckets.removeAll()
        lastRunDate = Date()
        currentBatchSummary = nil
    }

    func finalizeRunSummary(total: Int, successes: Int, extraContext: String = "") {
        guard isEnabled, total > 0 else {
            currentBatchSummary = nil
            return
        }
        let bucketSnapshot = runReasonBuckets

        Task { [weak self] in
            guard let self else { return }
            await self.buildBatchSummary(total: total, successes: successes, buckets: bucketSnapshot, extra: extraContext)
        }
    }

    private func buildBatchSummary(total: Int, successes: Int, buckets: [String: Int], extra: String) async {
        let bucketLines = buckets
            .sorted { $0.value > $1.value }
            .prefix(6)
            .map { sig -> String in
                let summary = diagnoses[sig.key]?.summary ?? "Unknown"
                return "\(sig.value)× \(summary)"
            }
            .joined(separator: "\n")

        let prompt = """
        Summarize this automation batch in one short human sentence, then list up to 4 bucket bullets. Be factual and concise.

        Total attempts: \(total)
        Successful logins: \(successes)
        Failure buckets:
        \(bucketLines.isEmpty ? "none recorded" : bucketLines)
        Context: \(extra)

        Respond ONLY in JSON:
        { "headline": "one sentence, max 18 words", "bullets": ["short bullet", "short bullet"] }
        """

        guard let raw = await gemini.generateContent(
            prompt: prompt,
            model: GeminiModel.flashLite.rawValue,
            jsonMode: true,
            temperature: 0.2
        ) else { return }

        let cleaned = extractJSON(raw)
        guard let data = cleaned.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        let headline = (dict["headline"] as? String) ?? "\(successes)/\(total) successful"
        let bullets = (dict["bullets"] as? [String]) ?? []

        currentBatchSummary = AIBatchSummary(
            headline: headline,
            bullets: bullets,
            total: total,
            successes: successes,
            timestamp: Date()
        )
        logger.log("AITelemetry: batch summary → \(headline)", category: .aiTelemetry, level: .success)
    }

    // MARK: - Fingerprint Leak Analysis

    func analyzeFingerprintLeaks(host: String, rawSignals: [String: String]) async -> AIFingerprintLeakAnalysis? {
        guard isEnabled else { return nil }

        let signalText = rawSignals.map { "\($0.key)=\($0.value)" }.joined(separator: "\n")
        let prompt = """
        You are a browser fingerprint analyst. Given these raw fingerprint signals captured from amiunique.org for a session, return a plain-English summary of what is leaking and a 0-100 stealth score.

        Host: \(host)
        Signals:
        \(signalText)

        Respond ONLY in JSON:
        {
          "summary": "2-3 short sentences naming the top leaks",
          "leaks": ["canvas hash unique", "webgl vendor iOS", "..."],
          "score": 0
        }
        """

        guard let raw = await gemini.generateContent(
            prompt: prompt,
            model: GeminiModel.flash.rawValue,
            jsonMode: true,
            temperature: 0.2
        ) else { return nil }

        let cleaned = extractJSON(raw)
        guard let data = cleaned.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }

        let analysis = AIFingerprintLeakAnalysis(
            summary: (dict["summary"] as? String) ?? "Unable to parse fingerprint signals",
            leaks: (dict["leaks"] as? [String]) ?? [],
            score: (dict["score"] as? Int) ?? 50,
            timestamp: Date()
        )
        lastFingerprintAnalysis = analysis
        logger.log("AITelemetry: fingerprint analysis \(analysis.score)/100 — \(analysis.leaks.count) leaks", category: .aiTelemetry, level: .info)
        return analysis
    }

    // MARK: - Site Tuning Hints

    func siteTuningHint(for siteLabel: String) async -> String? {
        guard isEnabled else { return nil }
        let stats = AIFingerprintTuningService.shared.allHostPreferences()
        let relevant = stats.filter { $0.host.localizedCaseInsensitiveContains(siteLabel) }
        guard !relevant.isEmpty else { return nil }

        let summary = relevant.prefix(3).map { pref in
            "host=\(pref.host) tests=\(pref.totalTests) preferred=\(pref.preferredProfiles) avoid=\(pref.avoidProfiles)"
        }.joined(separator: "\n")

        let prompt = """
        Given these fingerprint profile stats for \(siteLabel), return ONE short actionable tuning hint (max 16 words). Focus on what profile/viewport/timezone to lean on.

        Stats:
        \(summary)

        Respond with plain text only, no JSON, no quotes.
        """

        return await gemini.generateContent(
            prompt: prompt,
            model: GeminiModel.flashLite.rawValue,
            temperature: 0.3
        )?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Helpers

    private func buildSignature(host: String, outcome: String, error: String?, snippet: String) -> String {
        let errKey = (error ?? "").prefix(60).lowercased()
        let snippetKey = snippet
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .prefix(20)
            .joined(separator: " ")
        return "\(host)|\(outcome)|\(errKey)|\(snippetKey.prefix(120))"
    }

    private func extractJSON(_ raw: String) -> String {
        let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let start = cleaned.range(of: "{"), let end = cleaned.range(of: "}", options: .backwards) {
            return String(cleaned[start.lowerBound...end.upperBound])
        }
        return cleaned
    }

    private func recomputeTopReasons() {
        var counts: [String: Int] = [:]
        for d in diagnoses.values {
            counts[d.summary, default: 0] += 1
        }
        topFailureReasons = counts
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { ($0.key, $0.value) }
    }

    private func recomputeAverageStealth() {
        guard !stealthScores.isEmpty else {
            averageStealthScore = 0
            return
        }
        let total = stealthScores.values.reduce(0) { $0 + $1.score }
        averageStealthScore = Double(total) / Double(stealthScores.count)
    }

    // MARK: - Persistence

    private struct PersistedStore: Codable {
        var selfHealCount: Int
        var topReasons: [String]
    }

    private func save() {
        if let data = try? JSONEncoder().encode(Array(diagnoses.values)) {
            UserDefaults.standard.set(data, forKey: diagnosisKey)
        }
        if let data = try? JSONEncoder().encode(healedSelectors) {
            UserDefaults.standard.set(data, forKey: selectorKey)
        }
        let store = PersistedStore(selfHealCount: selfHealCount, topReasons: topFailureReasons.map(\.reason))
        if let data = try? JSONEncoder().encode(store) {
            UserDefaults.standard.set(data, forKey: persistKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: diagnosisKey),
           let arr = try? JSONDecoder().decode([AITelemetryDiagnosis].self, from: data) {
            for d in arr { diagnoses[d.signature] = d }
            recomputeTopReasons()
        }
        if let data = UserDefaults.standard.data(forKey: selectorKey),
           let map = try? JSONDecoder().decode([String: [String: String]].self, from: data) {
            healedSelectors = map
        }
        if let data = UserDefaults.standard.data(forKey: persistKey),
           let store = try? JSONDecoder().decode(PersistedStore.self, from: data) {
            selfHealCount = store.selfHealCount
        }
    }

    func resetStats() {
        diagnoses.removeAll()
        stealthScores.removeAll()
        healedSelectors.removeAll()
        currentBatchSummary = nil
        lastFingerprintAnalysis = nil
        selfHealCount = 0
        averageStealthScore = 0
        topFailureReasons = []
        save()
    }
}
