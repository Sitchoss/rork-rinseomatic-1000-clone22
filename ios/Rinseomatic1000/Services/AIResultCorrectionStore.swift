import Foundation
import UIKit

@MainActor
class AIResultCorrectionStore {
    static let shared = AIResultCorrectionStore()

    private let persistenceKey = "AIResultCorrectionStoreV1"
    private let maxCorrectionHistory = 500
    private let logger = DebugLogger.shared
    private(set) var corrections: [ResultCorrectionRecord] = []
    private(set) var weightAdjustments: [AIWeightAdjustment] = []
    private var outcomeKeywordWeights: [String: Double] = [:]
    private var outcomeCorrectionCounts: [String: Int] = [:]
    private var totalCorrections: Int = 0
    private var totalApprovals: Int = 0
    private var settingsModifications: Int = 0

    private init() {
        load()
    }

    var accuracyRate: Double {
        let total = totalCorrections + totalApprovals
        guard total > 0 else { return 1.0 }
        return Double(totalApprovals) / Double(total)
    }

    var correctionSummary: String {
        let total = totalCorrections + totalApprovals
        guard total > 0 else { return "No reviews yet" }
        return "\(totalApprovals)/\(total) correct (\(Int(accuracyRate * 100))%) · \(totalCorrections) corrected · \(settingsModifications) auto-adjustments"
    }

    func recordApproval(
        credentialEmail: String,
        sessionId: String,
        site: String,
        detectedOutcome: LiveResultReviewOutcome,
        confidence: Double,
        ocrText: String
    ) {
        totalApprovals += 1
        let host = site.lowercased().contains("joe") ? "joefortune" : "ignition"
        AIConfidenceAnalyzerService.shared.recordFeedback(
            host: host,
            predictedOutcome: detectedOutcome.rawValue,
            actualOutcome: detectedOutcome.rawValue,
            confidence: confidence,
            pageContent: ocrText
        )
        logger.log("AICorrection: APPROVED \(detectedOutcome.shortLabel) for \(credentialEmail) on \(site) (\(Int(confidence * 100))%)", category: .evaluation, level: .success)
        save()
    }

    func recordCorrection(
        credentialEmail: String,
        sessionId: String,
        site: String,
        aiDetectedOutcome: LiveResultReviewOutcome,
        userCorrectedOutcome: LiveResultReviewOutcome,
        aiConfidence: Double,
        highlightRegions: [HighlightRegion],
        ocrText: String,
        screenshot: UIImage?
    ) {
        totalCorrections += 1
        outcomeCorrectionCounts[aiDetectedOutcome.rawValue, default: 0] += 1

        let record = ResultCorrectionRecord(
            id: UUID().uuidString,
            credentialEmail: credentialEmail,
            sessionId: sessionId,
            site: site,
            aiDetectedOutcome: aiDetectedOutcome.rawValue,
            userCorrectedOutcome: userCorrectedOutcome.rawValue,
            aiConfidence: aiConfidence,
            highlightRegions: highlightRegions,
            ocrTextAtCorrection: String(ocrText.prefix(2000)),
            timestamp: Date(),
            settingsSnapshotJSON: nil
        )
        corrections.append(record)
        if corrections.count > maxCorrectionHistory {
            corrections.removeFirst(corrections.count - maxCorrectionHistory)
        }

        let host = site.lowercased().contains("joe") ? "joefortune" : "ignition"
        AIConfidenceAnalyzerService.shared.recordFeedback(
            host: host,
            predictedOutcome: aiDetectedOutcome.rawValue,
            actualOutcome: userCorrectedOutcome.rawValue,
            confidence: aiConfidence,
            pageContent: ocrText
        )

        applyWeightAdjustment(
            site: site,
            wrongOutcome: aiDetectedOutcome,
            correctOutcome: userCorrectedOutcome,
            ocrText: ocrText,
            highlightRegions: highlightRegions
        )

        evaluateSettingsAdjustment(
            site: site,
            wrongOutcome: aiDetectedOutcome,
            correctOutcome: userCorrectedOutcome
        )

        logger.log("AICorrection: CORRECTED \(aiDetectedOutcome.shortLabel) → \(userCorrectedOutcome.shortLabel) for \(credentialEmail) on \(site) · \(highlightRegions.count) highlight(s)", category: .evaluation, level: .warning)
        save()
    }

    private func applyWeightAdjustment(
        site: String,
        wrongOutcome: LiveResultReviewOutcome,
        correctOutcome: LiveResultReviewOutcome,
        ocrText: String,
        highlightRegions: [HighlightRegion]
    ) {
        let words = extractKeyPhrases(from: ocrText)
        var adjustments: [String: Double] = [:]

        for word in words {
            let wrongKey = "\(wrongOutcome.rawValue)_\(word)"
            let correctKey = "\(correctOutcome.rawValue)_\(word)"
            outcomeKeywordWeights[wrongKey, default: 0] -= 0.1
            outcomeKeywordWeights[correctKey, default: 0] += 0.15
            adjustments[word] = 0.15
        }

        for region in highlightRegions {
            if !region.label.isEmpty {
                let correctKey = "\(correctOutcome.rawValue)_\(region.label.lowercased())"
                outcomeKeywordWeights[correctKey, default: 0] += 0.25
                adjustments[region.label] = 0.25
            }
        }

        let adjustment = AIWeightAdjustment(
            outcome: correctOutcome.rawValue,
            keywordAdjustments: adjustments,
            confidenceShift: 0.1,
            appliedAt: Date(),
            reason: "User corrected \(wrongOutcome.shortLabel) → \(correctOutcome.shortLabel) on \(site)"
        )
        weightAdjustments.append(adjustment)

        logger.log("AICorrection: weight adjustment applied — \(adjustments.count) keywords boosted for \(correctOutcome.shortLabel)", category: .evaluation, level: .info)
    }

    private func evaluateSettingsAdjustment(
        site: String,
        wrongOutcome: LiveResultReviewOutcome,
        correctOutcome: LiveResultReviewOutcome
    ) {
        let recentCorrectionsForSameError = corrections.suffix(20).filter {
            $0.aiDetectedOutcome == wrongOutcome.rawValue &&
            $0.userCorrectedOutcome == correctOutcome.rawValue
        }

        guard recentCorrectionsForSameError.count >= 3 else { return }

        var settings = AutomationSettingsPersistence.shared.load()
        var modified = false

        if wrongOutcome == .noresultyet && correctOutcome != .noresultyet {
            let currentWait = settings.trueDetectionPostClickWaitMs
            let newWait = min(currentWait + 500, 8000)
            if newWait != currentWait {
                settings.trueDetectionPostClickWaitMs = newWait
                modified = true
                logger.log("AICorrection: AUTO-ADJUSTED postClickWait \(currentWait)ms → \(newWait)ms (repeated noresultyet corrections)", category: .evaluation, level: .warning)
            }
        }

        if wrongOutcome == .connectionFailure && correctOutcome != .connectionFailure {
            let currentTimeout = settings.pageLoadTimeout
            let newTimeout = min(currentTimeout + 30, 300)
            if newTimeout != currentTimeout {
                settings.pageLoadTimeout = newTimeout
                modified = true
                logger.log("AICorrection: AUTO-ADJUSTED pageLoadTimeout \(Int(currentTimeout))s → \(Int(newTimeout))s (repeated connectionFailure corrections)", category: .evaluation, level: .warning)
            }
        }

        if wrongOutcome == .noAcc && correctOutcome == .success {
            let currentStrictness = settings.evaluationStrictness
            if currentStrictness == .strict {
                settings.evaluationStrictness = .normal
                modified = true
                logger.log("AICorrection: AUTO-ADJUSTED evaluationStrictness strict → normal (repeated noAcc→success corrections)", category: .evaluation, level: .warning)
            }
        }

        if wrongOutcome == .redBannerError && correctOutcome == .noAcc {
            let currentRequeue = settings.requeueOnRedBanner
            if currentRequeue {
                settings.requeueOnRedBanner = false
                modified = true
                logger.log("AICorrection: AUTO-ADJUSTED requeueOnRedBanner → false (repeated redBanner→noAcc corrections)", category: .evaluation, level: .warning)
            }
        }

        if wrongOutcome == .noresultyet && correctOutcome == .success {
            let currentSettlement = settings.v42SettlementMaxTimeoutMs
            let newSettlement = min(currentSettlement + 2000, 30000)
            if newSettlement != currentSettlement {
                settings.v42SettlementMaxTimeoutMs = newSettlement
                modified = true
                logger.log("AICorrection: AUTO-ADJUSTED settlementTimeout \(currentSettlement)ms → \(newSettlement)ms (noresultyet→success corrections)", category: .evaluation, level: .warning)
            }
        }

        if modified {
            settingsModifications += 1
            AutomationSettingsPersistence.shared.save(settings)
            NotificationCenter.default.post(name: .automationSettingsDidChange, object: settings)
            logger.log("AICorrection: settings auto-modified (\(settingsModifications) total adjustments)", category: .evaluation, level: .warning)
        }
    }

    func learnedBoostForOutcome(_ outcome: LiveResultReviewOutcome, ocrText: String) -> Double {
        let words = extractKeyPhrases(from: ocrText)
        var totalBoost = 0.0
        for word in words {
            let key = "\(outcome.rawValue)_\(word)"
            totalBoost += outcomeKeywordWeights[key, default: 0]
        }
        return max(-0.3, min(0.3, totalBoost))
    }

    func mostCorrectedOutcome() -> (outcome: String, count: Int)? {
        outcomeCorrectionCounts.max(by: { $0.value < $1.value }).map { ($0.key, $0.value) }
    }

    func correctionCountForOutcome(_ outcome: LiveResultReviewOutcome) -> Int {
        outcomeCorrectionCounts[outcome.rawValue, default: 0]
    }

    func resetAll() {
        corrections.removeAll()
        weightAdjustments.removeAll()
        outcomeKeywordWeights.removeAll()
        outcomeCorrectionCounts.removeAll()
        totalCorrections = 0
        totalApprovals = 0
        settingsModifications = 0
        save()
    }

    private func extractKeyPhrases(from text: String) -> [String] {
        let phrases = [
            "incorrect password", "invalid credentials", "wrong password",
            "has been disabled", "account has been suspended",
            "temporarily locked", "too many attempts", "try again later",
            "balance", "wallet", "my account", "logout", "dashboard",
            "account not found", "login failed", "authentication failed",
            "permanently banned", "self-excluded", "account is closed",
            "temporarily disabled", "sms verification", "verification code",
            "phone verification", "error", "unable to", "something went wrong",
            "login button", "sign in", "loading", "please wait"
        ]
        let lower = text.lowercased()
        return phrases.filter { lower.contains($0) }
    }

    private nonisolated struct PersistenceData: Codable, Sendable {
        var corrections: [ResultCorrectionRecord]
        var outcomeKeywordWeights: [String: Double]
        var outcomeCorrectionCounts: [String: Int]
        var totalCorrections: Int
        var totalApprovals: Int
        var settingsModifications: Int
    }

    private func save() {
        let data = PersistenceData(
            corrections: corrections,
            outcomeKeywordWeights: outcomeKeywordWeights,
            outcomeCorrectionCounts: outcomeCorrectionCounts,
            totalCorrections: totalCorrections,
            totalApprovals: totalApprovals,
            settingsModifications: settingsModifications
        )
        if let encoded = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(encoded, forKey: persistenceKey)
        }
    }

    private func load() {
        guard let saved = UserDefaults.standard.data(forKey: persistenceKey),
              let decoded = try? JSONDecoder().decode(PersistenceData.self, from: saved) else { return }
        corrections = decoded.corrections
        outcomeKeywordWeights = decoded.outcomeKeywordWeights
        outcomeCorrectionCounts = decoded.outcomeCorrectionCounts
        totalCorrections = decoded.totalCorrections
        totalApprovals = decoded.totalApprovals
        settingsModifications = decoded.settingsModifications
    }
}
