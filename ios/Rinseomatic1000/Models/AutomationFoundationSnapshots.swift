import Foundation

nonisolated struct AutomationFlowMetadataSnapshot: Identifiable, Sendable {
    let id: String
    let flowID: String
    let name: String
    let url: String
    let version: Int
    let repairConfidence: Double
    let lastHealedAt: Date?
    let createdAt: Date
    let updatedAt: Date
    let actionCount: Int
    let totalDurationMs: Double

    var repairConfidencePercentage: Int {
        Int((repairConfidence * 100).rounded())
    }
}

nonisolated struct AutomationTelemetrySnapshot: Identifiable, Sendable {
    let id: String
    let timestamp: Date
    let categoryRawValue: String
    let levelRawValue: String
    let message: String
    let detail: String?
    let sessionId: String?
    let durationMs: Int?
    let deltaMs: Int

    var category: DebugLogCategory {
        DebugLogCategory(rawValue: categoryRawValue) ?? .system
    }

    var level: DebugLogLevel {
        DebugLogLevel(rawValue: levelRawValue) ?? .info
    }
}

nonisolated struct AutomationFlowHistorySnapshot: Identifiable, Sendable {
    let id: String
    let flowID: String
    let version: Int
    let name: String
    let url: String
    let savedAt: Date
    let changeSummary: String
    let actionCount: Int
    let totalDurationMs: Double
}

nonisolated struct AutomationStorageHealthSnapshot: Sendable {
    var flowTemplateCount: Int = 0
    var telemetryCount: Int = 0
    var screenshotHistoryCount: Int = 0
    var screenshotRetentionLimit: Int = 0
    var currentSessionScreenshotCount: Int = 0
    var deduplicatedScreenshotCount: Int = 0
    var lastTelemetryAt: Date? = nil
    var lastScreenshotAt: Date? = nil
}
