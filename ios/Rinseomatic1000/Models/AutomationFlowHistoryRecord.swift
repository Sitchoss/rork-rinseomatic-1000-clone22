import Foundation
import SwiftData

@Model
final class AutomationFlowHistoryRecord {
    @Attribute(.unique) var recordID: String
    var flowID: String
    var version: Int
    var name: String
    var url: String
    var savedAt: Date
    @Attribute(.externalStorage) var snapshotData: Data
    var changeSummary: String
    var actionCount: Int
    var totalDurationMs: Double

    init(
        recordID: String,
        flowID: String,
        version: Int,
        name: String,
        url: String,
        savedAt: Date = Date(),
        snapshotData: Data,
        changeSummary: String,
        actionCount: Int,
        totalDurationMs: Double
    ) {
        self.recordID = recordID
        self.flowID = flowID
        self.version = version
        self.name = name
        self.url = url
        self.savedAt = savedAt
        self.snapshotData = snapshotData
        self.changeSummary = changeSummary
        self.actionCount = actionCount
        self.totalDurationMs = totalDurationMs
    }
}
