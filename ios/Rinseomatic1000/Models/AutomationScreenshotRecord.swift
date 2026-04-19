import Foundation
import SwiftData

@Model
final class AutomationScreenshotRecord {
    @Attribute(.unique) var screenshotHash: String
    var createdAt: Date
    var sessionId: String
    var credentialEmail: String
    var site: String
    var stepRawValue: String
    var attemptNumber: Int
    var isCrucial: Bool
    var visionConfidence: Double
    var analysisTimeMs: Int

    init(
        screenshotHash: String,
        createdAt: Date = Date(),
        sessionId: String,
        credentialEmail: String,
        site: String,
        stepRawValue: String,
        attemptNumber: Int,
        isCrucial: Bool,
        visionConfidence: Double,
        analysisTimeMs: Int
    ) {
        self.screenshotHash = screenshotHash
        self.createdAt = createdAt
        self.sessionId = sessionId
        self.credentialEmail = credentialEmail
        self.site = site
        self.stepRawValue = stepRawValue
        self.attemptNumber = attemptNumber
        self.isCrucial = isCrucial
        self.visionConfidence = visionConfidence
        self.analysisTimeMs = analysisTimeMs
    }
}
