import Foundation
import Observation
import UIKit
import SwiftUI

@Observable
@MainActor
class UnifiedScreenshotManager {
    static let shared = UnifiedScreenshotManager()

    var screenshots: [UnifiedScreenshot] = []
    var analysisStats: AnalysisStats = AnalysisStats()
    private let maxScreenshots: Int = 200
    private let visionCrop = VisionTextCropService.shared
    private let dedup = ScreenshotDedupService.shared
    private let logger = DebugLogger.shared
    private let foundationStore = AutomationFoundationStore.shared

    struct AnalysisStats {
        var totalCaptured: Int = 0
        var totalAnalyzed: Int = 0
        var duplicatesSkipped: Int = 0
        var crucialDetections: Int = 0
        var smartCrops: Int = 0
        var outcomeBreakdown: [String: Int] = [:]
    }

    func canCapture(credentialEmail: String, site: String, limit: Int) -> Bool {
        guard limit > 0 else { return false }
        let count = screenshots.filter { $0.credentialEmail == credentialEmail && $0.site == site }.count
        return count < limit
    }

    func countForCredentialSite(credentialEmail: String, site: String) -> Int {
        screenshots.filter { $0.credentialEmail == credentialEmail && $0.site == site }.count
    }

    func addScreenshot(
        image: UIImage,
        sessionId: String,
        credentialEmail: String,
        site: String,
        step: ScreenshotStep,
        attemptNumber: Int,
        clickPriority: Int = 0,
        runVisionAnalysis: Bool = true
    ) async {
        analysisStats.totalCaptured += 1

        let result = await ScreenshotCompressor.shared.compressAndHash(image)
        let compressedData = result.data
        let hashValue = result.hash
        let resizedImage = result.resized
        
        if foundationStore.containsScreenshotHash(hashValue) || dedup.isDuplicate(resizedImage) {
            analysisStats.duplicatesSkipped += 1
            logger.log("UnifiedScreenshots: duplicate skipped for \(credentialEmail) step=\(step.rawValue)", category: .screenshot, level: .trace)
            foundationStore.refreshStorageHealth(currentSessionScreenshotCount: screenshots.count)
            return
        }

        let compressedImage = resizedImage

        var analysis: VisionTextCropService.AnalysisResult?
        var croppedData: Data?

        if runVisionAnalysis {
            analysisStats.totalAnalyzed += 1
            let analysisValue = await visionCrop.analyzeScreenshot(compressedImage)
            analysis = analysisValue

            if !analysisValue.crucialMatches.isEmpty {
                analysisStats.crucialDetections += 1
                let crop = await visionCrop.smartCrop(compressedImage, analysis: analysisValue)
                if crop.cropRect != .zero {
                    analysisStats.smartCrops += 1
                    croppedData = crop.croppedImage.jpegData(compressionQuality: 0.4)
                }
            }

            let outcomeKey = analysisValue.detectedOutcome.rawValue
            analysisStats.outcomeBreakdown[outcomeKey, default: 0] += 1
        }

        let screenshot = UnifiedScreenshot(
            sessionId: sessionId,
            credentialEmail: credentialEmail,
            site: site,
            step: step,
            attemptNumber: attemptNumber,
            clickPriority: clickPriority,
            fullImageData: compressedData,
            croppedImageData: croppedData,
            detectedOutcome: analysis?.detectedOutcome ?? .unknown,
            crucialKeywords: analysis?.crucialMatches ?? [],
            allDetectedText: analysis?.allText ?? "",
            visionConfidence: analysis?.confidence ?? 0,
            analysisTimeMs: analysis?.processingTimeMs ?? 0
        )

        screenshots.insert(screenshot, at: 0)

        if screenshots.count > maxScreenshots {
            let overflow = screenshots.count - maxScreenshots
            screenshots.removeLast(overflow)
        }

        _ = foundationStore.recordScreenshotMetadata(
            screenshotHash: hashValue,
            sessionId: sessionId,
            credentialEmail: credentialEmail,
            site: site,
            stepRawValue: step.rawValue,
            attemptNumber: attemptNumber,
            isCrucial: screenshot.isCrucial,
            visionConfidence: screenshot.visionConfidence,
            analysisTimeMs: screenshot.analysisTimeMs,
            currentSessionScreenshotCount: screenshots.count
        )

        let crucialInfo = analysis.flatMap { $0.crucialMatches.isEmpty ? nil : " CRUCIAL:\($0.crucialMatches.joined(separator: ","))" } ?? ""
        logger.log("UnifiedScreenshots: captured \(step.rawValue) for \(credentialEmail) site=\(site) attempt=\(attemptNumber)\(crucialInfo)", category: .screenshot, level: crucialInfo.isEmpty ? .debug : .info)
    }

    func addScreenshotDirect(
        image: UIImage,
        sessionId: String,
        credentialEmail: String,
        site: String,
        step: ScreenshotStep,
        attemptNumber: Int,
        clickPriority: Int = 0,
        runVisionAnalysis: Bool = true
    ) async {
        analysisStats.totalCaptured += 1

        let result = await ScreenshotCompressor.shared.compressAndHash(image)
        let compressedData = result.data
        let hashValue = result.hash
        let resizedImage = result.resized
        
        if foundationStore.containsScreenshotHash(hashValue) || dedup.isDuplicate(resizedImage) {
            analysisStats.duplicatesSkipped += 1
            logger.log("UnifiedScreenshots: duplicate skipped for \(credentialEmail) step=\(step.rawValue)", category: .screenshot, level: .trace)
            foundationStore.refreshStorageHealth(currentSessionScreenshotCount: screenshots.count)
            return
        }

        let compressedImage = resizedImage

        var analysis: VisionTextCropService.AnalysisResult?
        var croppedData: Data?

        if runVisionAnalysis {
            analysisStats.totalAnalyzed += 1
            let analysisValue = await visionCrop.analyzeScreenshot(compressedImage)
            analysis = analysisValue

            if !analysisValue.crucialMatches.isEmpty {
                analysisStats.crucialDetections += 1
                let crop = await visionCrop.smartCrop(compressedImage, analysis: analysisValue)
                if crop.cropRect != .zero {
                    analysisStats.smartCrops += 1
                    croppedData = crop.croppedImage.jpegData(compressionQuality: 0.4)
                }
            }

            let outcomeKey = analysisValue.detectedOutcome.rawValue
            analysisStats.outcomeBreakdown[outcomeKey, default: 0] += 1
        }

        let screenshot = UnifiedScreenshot(
            sessionId: sessionId,
            credentialEmail: credentialEmail,
            site: site,
            step: step,
            attemptNumber: attemptNumber,
            clickPriority: clickPriority,
            fullImageData: compressedData,
            croppedImageData: croppedData,
            detectedOutcome: analysis?.detectedOutcome ?? .unknown,
            crucialKeywords: analysis?.crucialMatches ?? [],
            allDetectedText: analysis?.allText ?? "",
            visionConfidence: analysis?.confidence ?? 0,
            analysisTimeMs: analysis?.processingTimeMs ?? 0
        )

        screenshots.insert(screenshot, at: 0)

        if screenshots.count > maxScreenshots {
            let overflow = screenshots.count - maxScreenshots
            screenshots.removeLast(overflow)
        }

        _ = foundationStore.recordScreenshotMetadata(
            screenshotHash: hashValue,
            sessionId: sessionId,
            credentialEmail: credentialEmail,
            site: site,
            stepRawValue: step.rawValue,
            attemptNumber: attemptNumber,
            isCrucial: screenshot.isCrucial,
            visionConfidence: screenshot.visionConfidence,
            analysisTimeMs: screenshot.analysisTimeMs,
            currentSessionScreenshotCount: screenshots.count
        )

        let crucialInfo = analysis.flatMap { $0.crucialMatches.isEmpty ? nil : " CRUCIAL:\($0.crucialMatches.joined(separator: ","))" } ?? ""
        logger.log("UnifiedScreenshots: direct captured \(step.rawValue) for \(credentialEmail) site=\(site) attempt=\(attemptNumber)\(crucialInfo)", category: .screenshot, level: crucialInfo.isEmpty ? .debug : .info)
    }

    func screenshotsForSession(_ sessionId: String) -> [UnifiedScreenshot] {
        screenshots.filter { $0.sessionId == sessionId }
    }

    func screenshotsForCredential(_ email: String) -> [UnifiedScreenshot] {
        screenshots.filter { $0.credentialEmail == email }
    }

    func crucialScreenshots() -> [UnifiedScreenshot] {
        screenshots.filter { !$0.crucialKeywords.isEmpty }
    }

    func screenshotsBySite(_ site: String) -> [UnifiedScreenshot] {
        screenshots.filter { $0.site == site }
    }

    func clearAll() {
        let count = screenshots.count
        screenshots.removeAll()
        dedup.resetAll()
        analysisStats = AnalysisStats()
        foundationStore.clearScreenshotHistory()
        logger.log("UnifiedScreenshots: cleared \(count) screenshots", category: .screenshot, level: .info)
    }

    func clearForSession(_ sessionId: String) {
        screenshots.removeAll { $0.sessionId == sessionId }
        foundationStore.refreshStorageHealth(currentSessionScreenshotCount: screenshots.count)
    }

    func smartReduceForClearResult(sessionId: String) {
        let sessionShots = screenshots.filter { $0.sessionId == sessionId }
        guard sessionShots.count > 2 else { return }

        let terminalSteps: Set<ScreenshotStep> = [.terminalState, .successDetected, .crucialResponse, .errorBanner, .smsDetected, .finalState]
        let terminalShots = sessionShots.filter { terminalSteps.contains($0.step) }

        var kept: [UnifiedScreenshot] = []
        let joeFinal = terminalShots.first(where: { $0.site == "joe" }) ?? sessionShots.filter({ $0.site == "joe" }).last
        let ignFinal = terminalShots.first(where: { $0.site == "ignition" }) ?? sessionShots.filter({ $0.site == "ignition" }).last
        if let j = joeFinal { kept.append(j) }
        if let i = ignFinal { kept.append(i) }

        let keepIds = Set(kept.map(\.id))
        let before = screenshots.count
        screenshots.removeAll { $0.sessionId == sessionId && !keepIds.contains($0.id) }
        let removed = before - screenshots.count
        if removed > 0 {
            logger.log("UnifiedScreenshots: smart-reduced to \(kept.count) screenshots (1/site) for clear result — purged \(removed)", category: .screenshot, level: .info)
            foundationStore.refreshStorageHealth(currentSessionScreenshotCount: screenshots.count)
        }
    }

    func clearNonDisabledForSession(_ sessionId: String) {
        let disabledSteps: Set<ScreenshotStep> = [.terminalState, .crucialResponse]
        let hasDisabled = screenshots.contains { $0.sessionId == sessionId && disabledSteps.contains($0.step) }
        guard hasDisabled else { return }
        let before = screenshots.count
        screenshots.removeAll { $0.sessionId == sessionId && !disabledSteps.contains($0.step) }
        let removed = before - screenshots.count
        if removed > 0 {
            logger.log("UnifiedScreenshots: disabled override — purged \(removed) non-critical screenshots for session", category: .screenshot, level: .info)
            foundationStore.refreshStorageHealth(currentSessionScreenshotCount: screenshots.count)
        }
    }

    func pruneByPriority(sessionId: String, limit: Int) {
        let sessionShots = screenshots.filter { $0.sessionId == sessionId }
        guard sessionShots.count > limit, limit > 0 else { return }

        let sorted = sessionShots.sorted { $0.clickPriority < $1.clickPriority }
        let toKeepIds = Set(sorted.prefix(limit).map(\.id))
        let before = screenshots.count
        screenshots.removeAll { $0.sessionId == sessionId && !toKeepIds.contains($0.id) }
        let removed = before - screenshots.count
        if removed > 0 {
            logger.log("UnifiedScreenshots: priority pruned \(removed) screenshots (kept \(limit)) for session", category: .screenshot, level: .debug)
            foundationStore.refreshStorageHealth(currentSessionScreenshotCount: screenshots.count)
        }
    }

    func handleMemoryPressure() {
        let keep = min(screenshots.count, 100)
        if screenshots.count > keep {
            screenshots = Array(screenshots.prefix(keep))
        }
        ScreenshotImageCache.shared.clearAll()
        foundationStore.refreshStorageHealth(currentSessionScreenshotCount: screenshots.count)
    }

    private func compressToData(_ image: UIImage) -> Data {
        image.jpegData(compressionQuality: 0.4) ?? Data()
    }
}

@Observable
class UnifiedScreenshot: Identifiable {
    let id: String
    let timestamp: Date
    let sessionId: String
    let credentialEmail: String
    let site: String
    let step: ScreenshotStep
    let attemptNumber: Int
    let fullImageData: Data
    let croppedImageData: Data?
    let detectedOutcome: VisionTextCropService.DetectedOutcome
    let crucialKeywords: [String]
    let allDetectedText: String
    let visionConfidence: Double
    let analysisTimeMs: Int
    let clickPriority: Int
    var userOverride: UserResultOverride = .none

    var fullImage: UIImage {
        ScreenshotImageCache.shared.image(forKey: "\(id)_full", data: fullImageData)
    }

    var croppedImage: UIImage? {
        guard let data = croppedImageData else { return nil }
        return ScreenshotImageCache.shared.image(forKey: "\(id)_crop", data: data)
    }

    var displayImage: UIImage {
        croppedImage ?? fullImage
    }

    var hasCrop: Bool {
        croppedImageData != nil
    }

    var siteLabel: String {
        let normalized = site.lowercased()
        if normalized.contains("joe") { return "JoePoint" }
        if normalized.contains("ign") { return "Ignition Lite" }
        return normalized.isEmpty ? "Unknown" : site
    }

    var siteIcon: String {
        let normalized = site.lowercased()
        if normalized.contains("joe") { return "suit.spade.fill" }
        if normalized.contains("ign") { return "flame.fill" }
        return "globe"
    }

    var siteColor: SwiftUI.Color {
        let normalized = site.lowercased()
        if normalized.contains("joe") { return .green }
        if normalized.contains("ign") { return .orange }
        return .gray
    }

    var isCrucial: Bool {
        !crucialKeywords.isEmpty
    }

    var outcomeColor: SwiftUI.Color {
        switch detectedOutcome {
        case .success: .green
        case .incorrectPassword, .noAccount: .secondary
        case .permDisabled: .red
        case .tempDisabled: .orange
        case .smsVerification: .purple
        case .errorBanner: .red
        case .unknown: .gray
        }
    }

    var outcomeLabel: String {
        switch detectedOutcome {
        case .success: "SUCCESS"
        case .incorrectPassword: "INCORRECT"
        case .noAccount: "NO ACC"
        case .permDisabled: "PERM DISABLED"
        case .tempDisabled: "TEMP DISABLED"
        case .smsVerification: "SMS"
        case .errorBanner: "ERROR"
        case .unknown: "UNKNOWN"
        }
    }

    var formattedTime: String {
        DateFormatters.timeOnly.string(from: timestamp)
    }

    init(
        sessionId: String,
        credentialEmail: String,
        site: String,
        step: ScreenshotStep,
        attemptNumber: Int,
        clickPriority: Int = 0,
        fullImageData: Data,
        croppedImageData: Data?,
        detectedOutcome: VisionTextCropService.DetectedOutcome,
        crucialKeywords: [String],
        allDetectedText: String,
        visionConfidence: Double,
        analysisTimeMs: Int
    ) {
        self.id = UUID().uuidString
        self.timestamp = Date()
        self.sessionId = sessionId
        self.credentialEmail = credentialEmail
        self.site = site
        self.step = step
        self.attemptNumber = attemptNumber
        self.clickPriority = clickPriority
        self.fullImageData = fullImageData
        self.croppedImageData = croppedImageData
        self.detectedOutcome = detectedOutcome
        self.crucialKeywords = crucialKeywords
        self.allDetectedText = allDetectedText
        self.visionConfidence = visionConfidence
        self.analysisTimeMs = analysisTimeMs
    }
}

nonisolated enum ScreenshotStep: String, Sendable {
    case pageLoad = "page_load"
    case fieldsDetected = "fields_detected"
    case preTyping = "pre_typing"
    case postTyping = "post_typing"
    case preClick = "pre_click"
    case postClick = "post_click"
    case loadingState = "loading_state"
    case settlementWait = "settlement_wait"
    case responseDetected = "response_detected"
    case crucialResponse = "crucial_response"
    case terminalState = "terminal_state"
    case successDetected = "success_detected"
    case errorBanner = "error_banner"
    case smsDetected = "sms_detected"
    case postAttempt = "post_attempt"
    case finalState = "final_state"
    case recoveryAttempt = "recovery_attempt"
    case blankPage = "blank_page"

    var displayName: String {
        rawValue.replacingOccurrences(of: "_", with: " ").uppercased()
    }

    var icon: String {
        switch self {
        case .pageLoad: "globe"
        case .fieldsDetected: "text.cursor"
        case .preTyping: "keyboard"
        case .postTyping: "checkmark.rectangle"
        case .preClick: "hand.tap"
        case .postClick: "hand.tap.fill"
        case .loadingState: "hourglass"
        case .settlementWait: "clock.arrow.circlepath"
        case .responseDetected: "text.magnifyingglass"
        case .crucialResponse: "exclamationmark.triangle.fill"
        case .terminalState: "stop.circle.fill"
        case .successDetected: "checkmark.circle.fill"
        case .errorBanner: "exclamationmark.octagon.fill"
        case .smsDetected: "message.fill"
        case .postAttempt: "arrow.clockwise"
        case .finalState: "flag.checkered"
        case .recoveryAttempt: "arrow.triangle.2.circlepath"
        case .blankPage: "rectangle.dashed"
        }
    }

    var isCritical: Bool {
        switch self {
        case .crucialResponse, .terminalState, .successDetected, .errorBanner, .smsDetected: true
        default: false
        }
    }
}
