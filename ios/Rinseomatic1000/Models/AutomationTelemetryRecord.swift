import Foundation
import SwiftData

@Model
final class AutomationTelemetryRecord {
    var timestamp: Date
    var categoryRawValue: String
    var levelRawValue: String
    var message: String
    var detail: String?
    var sessionId: String?
    var durationMs: Int?
    var deltaMs: Int

    init(
        timestamp: Date = Date(),
        categoryRawValue: String,
        levelRawValue: String,
        message: String,
        detail: String? = nil,
        sessionId: String? = nil,
        durationMs: Int? = nil,
        deltaMs: Int = 0
    ) {
        self.timestamp = timestamp
        self.categoryRawValue = categoryRawValue
        self.levelRawValue = levelRawValue
        self.message = message
        self.detail = detail
        self.sessionId = sessionId
        self.durationMs = durationMs
        self.deltaMs = deltaMs
    }
}
