import Foundation
import SwiftData

@Model
final class AutomationFlowTemplateRecord {
    @Attribute(.unique) var flowID: String
    var name: String
    var url: String
    var version: Int
    var repairConfidence: Double
    var lastHealedAt: Date?
    var createdAt: Date
    var updatedAt: Date
    var actionCount: Int
    var totalDurationMs: Double

    init(
        flowID: String,
        name: String,
        url: String,
        version: Int = 1,
        repairConfidence: Double = 0,
        lastHealedAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        actionCount: Int,
        totalDurationMs: Double
    ) {
        self.flowID = flowID
        self.name = name
        self.url = url
        self.version = version
        self.repairConfidence = repairConfidence
        self.lastHealedAt = lastHealedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.actionCount = actionCount
        self.totalDurationMs = totalDurationMs
    }
}
