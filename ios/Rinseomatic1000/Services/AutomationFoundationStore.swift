import CryptoKit
import Foundation
import Observation
import SwiftData

@Observable
@MainActor
final class AutomationFoundationStore {
    static let shared = AutomationFoundationStore()

    var flowMetadataByID: [String: AutomationFlowMetadataSnapshot] = [:]
    var recentTelemetry: [AutomationTelemetrySnapshot] = []
    var storageHealth: AutomationStorageHealthSnapshot = AutomationStorageHealthSnapshot(
        flowTemplateCount: 0,
        telemetryCount: 0,
        screenshotHistoryCount: 0,
        screenshotRetentionLimit: 600,
        currentSessionScreenshotCount: 0,
        deduplicatedScreenshotCount: 0,
        lastTelemetryAt: nil,
        lastScreenshotAt: nil
    )

    private let screenshotRetentionLimit: Int = 600
    private let telemetryRetentionLimit: Int = 4000
    private let recentTelemetryLimit: Int = 60
    private let container: ModelContainer?
    private var lastTelemetryTimestamp: Date?

    init() {
        container = AutomationFoundationStore.makeContainer()
        refreshAllSnapshots()
    }

    func refreshAllSnapshots() {
        refreshFlowMetadata()
        refreshRecentTelemetry()
        refreshStorageHealth(currentSessionScreenshotCount: storageHealth.currentSessionScreenshotCount)
    }

    func syncFlows(_ flows: [RecordedFlow]) {
        guard let context else {
            flowMetadataByID = [:]
            refreshStorageHealth(currentSessionScreenshotCount: storageHealth.currentSessionScreenshotCount)
            return
        }

        let activeFlowIDs: Set<String> = Set(flows.map(\.id))
        let existingRecords: [AutomationFlowTemplateRecord] = (try? context.fetch(FetchDescriptor<AutomationFlowTemplateRecord>())) ?? []

        for record in existingRecords where !activeFlowIDs.contains(record.flowID) {
            context.delete(record)
        }

        for flow in flows {
            upsertFlowMetadata(flow, in: context)
        }

        try? context.save()
        refreshFlowMetadata()
        refreshStorageHealth(currentSessionScreenshotCount: storageHealth.currentSessionScreenshotCount)
    }

    func syncFlowMetadata(_ flow: RecordedFlow) {
        guard let context else { return }
        upsertFlowMetadata(flow, in: context)
        try? context.save()
        refreshFlowMetadata()
        refreshStorageHealth(currentSessionScreenshotCount: storageHealth.currentSessionScreenshotCount)
    }

    func deleteFlowMetadata(flowID: String) {
        guard let context else { return }
        let descriptor: FetchDescriptor<AutomationFlowTemplateRecord> = fetchDescriptorForFlow(flowID: flowID)
        if let existing = (try? context.fetch(descriptor))?.first {
            context.delete(existing)
        }
        let historyDescriptor: FetchDescriptor<AutomationFlowHistoryRecord> = fetchHistoryDescriptorForFlow(flowID: flowID)
        let historyRecords: [AutomationFlowHistoryRecord] = (try? context.fetch(historyDescriptor)) ?? []
        for record in historyRecords {
            context.delete(record)
        }
        try? context.save()
        flowMetadataByID.removeValue(forKey: flowID)
        refreshStorageHealth(currentSessionScreenshotCount: storageHealth.currentSessionScreenshotCount)
    }

    func clearScreenshotHistory() {
        guard let context else { return }
        let records: [AutomationScreenshotRecord] = (try? context.fetch(FetchDescriptor<AutomationScreenshotRecord>())) ?? []
        for record in records {
            context.delete(record)
        }
        try? context.save()
        refreshStorageHealth(currentSessionScreenshotCount: 0)
    }

    func clearTelemetryHistory() {
        guard let context else { return }
        let records: [AutomationTelemetryRecord] = (try? context.fetch(FetchDescriptor<AutomationTelemetryRecord>())) ?? []
        for record in records {
            context.delete(record)
        }
        try? context.save()
        recentTelemetry = []
        lastTelemetryTimestamp = nil
        refreshStorageHealth(currentSessionScreenshotCount: storageHealth.currentSessionScreenshotCount)
    }

    func recordLoggerEvent(_ entry: DebugLogEntry) {
        guard entry.level >= .info || entry.category == .flowRecorder else { return }
        recordTelemetry(
            categoryRawValue: entry.category.rawValue,
            levelRawValue: entry.level.rawValue,
            message: entry.message,
            detail: entry.detail,
            sessionId: entry.sessionId,
            durationMs: entry.durationMs,
            deltaOverrideMs: nil
        )
    }

    func recordRecordedActions(_ actions: [RecordedAction], url: String) {
        guard !actions.isEmpty else { return }
        for action in actions {
            recordTelemetry(
                categoryRawValue: DebugLogCategory.flowRecorder.rawValue,
                levelRawValue: DebugLogLevel.trace.rawValue,
                message: telemetryMessage(for: action, url: url),
                detail: action.targetSelector,
                sessionId: url,
                durationMs: nil,
                deltaOverrideMs: Int(action.deltaFromPreviousMs.rounded())
            )
        }
    }

    func hashString(for data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    func containsScreenshotHash(_ screenshotHash: String) -> Bool {
        guard let context else { return false }
        let descriptor: FetchDescriptor<AutomationScreenshotRecord> = fetchDescriptorForScreenshot(screenshotHash: screenshotHash)
        return ((try? context.fetch(descriptor))?.isEmpty == false)
    }

    @discardableResult
    func recordScreenshotMetadata(
        screenshotHash: String,
        sessionId: String,
        credentialEmail: String,
        site: String,
        stepRawValue: String,
        attemptNumber: Int,
        isCrucial: Bool,
        visionConfidence: Double,
        analysisTimeMs: Int,
        currentSessionScreenshotCount: Int
    ) -> Bool {
        guard let context else { return false }
        guard !containsScreenshotHash(screenshotHash) else {
            storageHealth.currentSessionScreenshotCount = currentSessionScreenshotCount
            storageHealth.deduplicatedScreenshotCount = ScreenshotDedupService.shared.duplicatesSkipped
            return false
        }

        let record = AutomationScreenshotRecord(
            screenshotHash: screenshotHash,
            sessionId: sessionId,
            credentialEmail: credentialEmail,
            site: site,
            stepRawValue: stepRawValue,
            attemptNumber: attemptNumber,
            isCrucial: isCrucial,
            visionConfidence: visionConfidence,
            analysisTimeMs: analysisTimeMs
        )
        context.insert(record)
        try? context.save()
        pruneScreenshotHistoryIfNeeded(context: context)
        refreshStorageHealth(currentSessionScreenshotCount: currentSessionScreenshotCount)
        return true
    }

    func commitFlowSave(original: RecordedFlow?, updated: RecordedFlow, review: FlowSaveReview) {
        guard let context else { return }

        let descriptor: FetchDescriptor<AutomationFlowTemplateRecord> = fetchDescriptorForFlow(flowID: updated.id)
        let existing: AutomationFlowTemplateRecord? = (try? context.fetch(descriptor))?.first
        let now = Date()
        let shouldArchivePrevious = original.map { hasMaterialDifferences($0, updated) } ?? false

        if let original, let existing, shouldArchivePrevious {
            if let snapshotData = try? JSONEncoder().encode(original) {
                let historyRecord = AutomationFlowHistoryRecord(
                    recordID: UUID().uuidString,
                    flowID: updated.id,
                    version: existing.version,
                    name: original.name,
                    url: original.url,
                    savedAt: now,
                    snapshotData: snapshotData,
                    changeSummary: historySummary(from: review),
                    actionCount: original.actionCount,
                    totalDurationMs: original.totalDurationMs
                )
                context.insert(historyRecord)
            }
        }

        upsertFlowMetadata(updated, in: context)
        if let existing, shouldArchivePrevious {
            existing.version += 1
            existing.updatedAt = now
        }

        try? context.save()
        refreshFlowMetadata()
        refreshStorageHealth(currentSessionScreenshotCount: storageHealth.currentSessionScreenshotCount)
    }

    func flowHistory(for flowID: String) -> [AutomationFlowHistorySnapshot] {
        guard let context else { return [] }
        let descriptor: FetchDescriptor<AutomationFlowHistoryRecord> = fetchHistoryDescriptorForFlow(flowID: flowID)
        let records: [AutomationFlowHistoryRecord] = (try? context.fetch(descriptor)) ?? []
        return records.map { record in
            AutomationFlowHistorySnapshot(
                id: record.recordID,
                flowID: record.flowID,
                version: record.version,
                name: record.name,
                url: record.url,
                savedAt: record.savedAt,
                changeSummary: record.changeSummary,
                actionCount: record.actionCount,
                totalDurationMs: record.totalDurationMs
            )
        }
    }

    func restoreFlowRevision(recordID: String) -> RecordedFlow? {
        guard let context else { return nil }
        let descriptor: FetchDescriptor<AutomationFlowHistoryRecord> = fetchHistoryDescriptor(recordID: recordID)
        guard let record = (try? context.fetch(descriptor))?.first else { return nil }
        return try? JSONDecoder().decode(RecordedFlow.self, from: record.snapshotData)
    }

    func refreshStorageHealth(currentSessionScreenshotCount: Int) {
        guard let context else {
            storageHealth = AutomationStorageHealthSnapshot(
                flowTemplateCount: 0,
                telemetryCount: 0,
                screenshotHistoryCount: 0,
                screenshotRetentionLimit: screenshotRetentionLimit,
                currentSessionScreenshotCount: currentSessionScreenshotCount,
                deduplicatedScreenshotCount: ScreenshotDedupService.shared.duplicatesSkipped,
                lastTelemetryAt: nil,
                lastScreenshotAt: nil
            )
            return
        }

        var screenshotDescriptor: FetchDescriptor<AutomationScreenshotRecord> = FetchDescriptor(sortBy: [SortDescriptor(\AutomationScreenshotRecord.createdAt, order: .reverse)])
        screenshotDescriptor.fetchLimit = 1
        let latestScreenshot: AutomationScreenshotRecord? = (try? context.fetch(screenshotDescriptor))?.first

        var telemetryDescriptor: FetchDescriptor<AutomationTelemetryRecord> = FetchDescriptor(sortBy: [SortDescriptor(\AutomationTelemetryRecord.timestamp, order: .reverse)])
        telemetryDescriptor.fetchLimit = 1
        let latestTelemetry: AutomationTelemetryRecord? = (try? context.fetch(telemetryDescriptor))?.first

        storageHealth = AutomationStorageHealthSnapshot(
            flowTemplateCount: flowRecordCount(context: context),
            telemetryCount: telemetryRecordCount(context: context),
            screenshotHistoryCount: screenshotRecordCount(context: context),
            screenshotRetentionLimit: screenshotRetentionLimit,
            currentSessionScreenshotCount: currentSessionScreenshotCount,
            deduplicatedScreenshotCount: ScreenshotDedupService.shared.duplicatesSkipped,
            lastTelemetryAt: latestTelemetry?.timestamp,
            lastScreenshotAt: latestScreenshot?.createdAt
        )
    }

    private func refreshFlowMetadata() {
        guard let context else {
            flowMetadataByID = [:]
            return
        }

        let descriptor: FetchDescriptor<AutomationFlowTemplateRecord> = FetchDescriptor(sortBy: [SortDescriptor(\AutomationFlowTemplateRecord.updatedAt, order: .reverse)])
        let records: [AutomationFlowTemplateRecord] = (try? context.fetch(descriptor)) ?? []
        flowMetadataByID = Dictionary(uniqueKeysWithValues: records.map { record in
            let snapshot = AutomationFlowMetadataSnapshot(
                id: record.flowID,
                flowID: record.flowID,
                name: record.name,
                url: record.url,
                version: record.version,
                repairConfidence: record.repairConfidence,
                lastHealedAt: record.lastHealedAt,
                createdAt: record.createdAt,
                updatedAt: record.updatedAt,
                actionCount: record.actionCount,
                totalDurationMs: record.totalDurationMs
            )
            return (record.flowID, snapshot)
        })
    }

    private func refreshRecentTelemetry() {
        guard let context else {
            recentTelemetry = []
            return
        }

        var descriptor: FetchDescriptor<AutomationTelemetryRecord> = FetchDescriptor(sortBy: [SortDescriptor(\AutomationTelemetryRecord.timestamp, order: .reverse)])
        descriptor.fetchLimit = recentTelemetryLimit
        let records: [AutomationTelemetryRecord] = (try? context.fetch(descriptor)) ?? []
        recentTelemetry = records.map { record in
            AutomationTelemetrySnapshot(
                id: "\(record.timestamp.timeIntervalSince1970)-\(record.message)-\(record.deltaMs)",
                timestamp: record.timestamp,
                categoryRawValue: record.categoryRawValue,
                levelRawValue: record.levelRawValue,
                message: record.message,
                detail: record.detail,
                sessionId: record.sessionId,
                durationMs: record.durationMs,
                deltaMs: record.deltaMs
            )
        }
        lastTelemetryTimestamp = records.first?.timestamp
    }

    private func recordTelemetry(
        categoryRawValue: String,
        levelRawValue: String,
        message: String,
        detail: String?,
        sessionId: String?,
        durationMs: Int?,
        deltaOverrideMs: Int?
    ) {
        guard let context else { return }

        let now = Date()
        let deltaMs: Int
        if let deltaOverrideMs {
            deltaMs = max(deltaOverrideMs, 0)
            lastTelemetryTimestamp = now
        } else if let lastTelemetryTimestamp {
            deltaMs = max(Int(now.timeIntervalSince(lastTelemetryTimestamp) * 1000), 0)
            self.lastTelemetryTimestamp = now
        } else {
            deltaMs = 0
            lastTelemetryTimestamp = now
        }

        let record = AutomationTelemetryRecord(
            timestamp: now,
            categoryRawValue: categoryRawValue,
            levelRawValue: levelRawValue,
            message: message,
            detail: detail,
            sessionId: sessionId,
            durationMs: durationMs,
            deltaMs: deltaMs
        )
        context.insert(record)
        try? context.save()
        pruneTelemetryIfNeeded(context: context)
        refreshRecentTelemetry()
        storageHealth.telemetryCount = min(max(storageHealth.telemetryCount + 1, recentTelemetry.count), telemetryRetentionLimit)
        storageHealth.lastTelemetryAt = now
        storageHealth.deduplicatedScreenshotCount = ScreenshotDedupService.shared.duplicatesSkipped
    }

    private func pruneTelemetryIfNeeded(context: ModelContext) {
        let descriptor: FetchDescriptor<AutomationTelemetryRecord> = FetchDescriptor(sortBy: [SortDescriptor(\AutomationTelemetryRecord.timestamp, order: .reverse)])
        let records: [AutomationTelemetryRecord] = (try? context.fetch(descriptor)) ?? []
        guard records.count > telemetryRetentionLimit else { return }
        for record in records.suffix(records.count - telemetryRetentionLimit) {
            context.delete(record)
        }
        try? context.save()
        storageHealth.telemetryCount = telemetryRetentionLimit
    }

    private func pruneScreenshotHistoryIfNeeded(context: ModelContext) {
        let descriptor: FetchDescriptor<AutomationScreenshotRecord> = FetchDescriptor(sortBy: [SortDescriptor(\AutomationScreenshotRecord.createdAt, order: .reverse)])
        let records: [AutomationScreenshotRecord] = (try? context.fetch(descriptor)) ?? []
        guard records.count > screenshotRetentionLimit else { return }
        for record in records.suffix(records.count - screenshotRetentionLimit) {
            context.delete(record)
        }
        try? context.save()
    }

    private func upsertFlowMetadata(_ flow: RecordedFlow, in context: ModelContext) {
        let descriptor: FetchDescriptor<AutomationFlowTemplateRecord> = fetchDescriptorForFlow(flowID: flow.id)
        let existing: AutomationFlowTemplateRecord? = (try? context.fetch(descriptor))?.first
        let now = Date()

        if let existing {
            let changed = existing.name != flow.name || existing.url != flow.url || existing.actionCount != flow.actionCount || abs(existing.totalDurationMs - flow.totalDurationMs) > 0.5
            existing.name = flow.name
            existing.url = flow.url
            existing.actionCount = flow.actionCount
            existing.totalDurationMs = flow.totalDurationMs
            if changed {
                existing.updatedAt = now
            }
        } else {
            let record = AutomationFlowTemplateRecord(
                flowID: flow.id,
                name: flow.name,
                url: flow.url,
                version: 1,
                repairConfidence: 0,
                lastHealedAt: nil,
                createdAt: flow.createdAt,
                updatedAt: now,
                actionCount: flow.actionCount,
                totalDurationMs: flow.totalDurationMs
            )
            context.insert(record)
        }
    }

    private var context: ModelContext? {
        container?.mainContext
    }

    private func flowRecordCount(context: ModelContext) -> Int {
        ((try? context.fetch(FetchDescriptor<AutomationFlowTemplateRecord>())) ?? []).count
    }

    private func telemetryRecordCount(context: ModelContext) -> Int {
        ((try? context.fetch(FetchDescriptor<AutomationTelemetryRecord>())) ?? []).count
    }

    private func screenshotRecordCount(context: ModelContext) -> Int {
        ((try? context.fetch(FetchDescriptor<AutomationScreenshotRecord>())) ?? []).count
    }

    private func fetchDescriptorForFlow(flowID: String) -> FetchDescriptor<AutomationFlowTemplateRecord> {
        var descriptor: FetchDescriptor<AutomationFlowTemplateRecord> = FetchDescriptor(predicate: #Predicate { $0.flowID == flowID })
        descriptor.fetchLimit = 1
        return descriptor
    }

    private func fetchDescriptorForScreenshot(screenshotHash: String) -> FetchDescriptor<AutomationScreenshotRecord> {
        var descriptor: FetchDescriptor<AutomationScreenshotRecord> = FetchDescriptor(predicate: #Predicate { $0.screenshotHash == screenshotHash })
        descriptor.fetchLimit = 1
        return descriptor
    }

    private func fetchHistoryDescriptorForFlow(flowID: String) -> FetchDescriptor<AutomationFlowHistoryRecord> {
        FetchDescriptor(
            predicate: #Predicate { $0.flowID == flowID },
            sortBy: [SortDescriptor(\AutomationFlowHistoryRecord.savedAt, order: .reverse)]
        )
    }

    private func fetchHistoryDescriptor(recordID: String) -> FetchDescriptor<AutomationFlowHistoryRecord> {
        var descriptor: FetchDescriptor<AutomationFlowHistoryRecord> = FetchDescriptor(predicate: #Predicate { $0.recordID == recordID })
        descriptor.fetchLimit = 1
        return descriptor
    }

    private func historySummary(from review: FlowSaveReview) -> String {
        let titles = review.changeItems
            .filter { $0.id != "no-changes" }
            .map(\.title)
        if titles.isEmpty {
            return review.summaryText
        }
        return titles.joined(separator: " • ")
    }

    private func hasMaterialDifferences(_ lhs: RecordedFlow, _ rhs: RecordedFlow) -> Bool {
        guard let lhsData = try? JSONEncoder().encode(lhs), let rhsData = try? JSONEncoder().encode(rhs) else {
            return true
        }
        return lhsData != rhsData
    }

    private func telemetryMessage(for action: RecordedAction, url: String) -> String {
        let selector = action.targetSelector ?? action.targetTagName ?? url
        switch action.type {
        case .click:
            return "click → \(selector)"
        case .doubleClick:
            return "doubleClick → \(selector)"
        case .scroll:
            return "scroll → \(Int(action.scrollDeltaY ?? 0))px"
        case .keyDown:
            return "keyDown → \(action.key ?? "?")"
        case .input, .textboxEntry:
            return "input → \(selector)"
        case .pageLoad:
            return "pageLoad → \(url)"
        case .navigationStart:
            return "navigationStart → \(url)"
        case .pause:
            return "pause → \(Int(action.deltaFromPreviousMs.rounded()))ms"
        default:
            return "\(action.type.rawValue) → \(selector)"
        }
    }

    private static func makeContainer() -> ModelContainer? {
        let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        guard let appSupportURL else { return nil }
        try? FileManager.default.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
        let storeURL = appSupportURL.appendingPathComponent("AutomationFoundation.store")
        let configuration = ModelConfiguration(url: storeURL)
        return try? ModelContainer(
            for: AutomationFlowTemplateRecord.self,
            AutomationFlowHistoryRecord.self,
            AutomationTelemetryRecord.self,
            AutomationScreenshotRecord.self,
            configurations: configuration
        )
    }
}
