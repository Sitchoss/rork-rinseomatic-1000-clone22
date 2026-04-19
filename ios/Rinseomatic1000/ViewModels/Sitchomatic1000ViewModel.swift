import Foundation
import Observation
import SwiftUI

@Observable
@MainActor
class Sitchomatic1000ViewModel {
    static let shared = Sitchomatic1000ViewModel()

    var entries: [Sitchomatic1000Entry] = []
    var isRunning: Bool = false

    var showAddURLSheet: Bool = false
    var showCredentialSheet: Bool = false
    var showBulkCredentialSheet: Bool = false
    var editingEntryId: String?

    var newURL: String = ""
    var newLabel: String = ""

    var bulkPasteText: String = ""
    var bulkAssignTarget: BulkAssignTarget = .all
    var bulkAssignEntryId: String?
    var lastBulkImportSummary: String?

    nonisolated enum BulkAssignTarget: Sendable, Equatable {
        case all
        case specific(entryId: String)
    }

    private let storageKey = "sitchomatic1000_entries_v2"
    private let logger = DebugLogger.shared

    init() {
        loadEntries()
    }

    var activeEntries: [Sitchomatic1000Entry] { entries.filter(\.isActive) }

    var editingEntry: Sitchomatic1000Entry? {
        guard let id = editingEntryId else { return nil }
        return entries.first { $0.id == id }
    }

    func addEntry(url: String, label: String, flowId: String? = nil, flowName: String? = nil) {
        var cleanURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanURL.hasPrefix("http://") && !cleanURL.hasPrefix("https://") {
            cleanURL = "https://\(cleanURL)"
        }
        cleanURL = URLNormalizer.normalize(cleanURL)
        let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedLabel = trimmedLabel.isEmpty ? nextCustomURLLabel() : trimmedLabel
        let entry = Sitchomatic1000Entry(
            url: cleanURL,
            label: resolvedLabel,
            assignedFlowId: flowId,
            assignedFlowName: flowName
        )
        entries.append(entry)
        saveEntries()
        logger.log("S1000: Added URL entry '\(entry.label)' — \(cleanURL)", category: .system, level: .info)
    }

    private func nextCustomURLLabel() -> String {
        let base = "custom_url"
        let existingLabels = Set(entries.map { $0.label.lowercased() })
        guard existingLabels.contains(base) else { return base }

        var index = 2
        while existingLabels.contains("\(base)\(index)") {
            index += 1
        }
        return "\(base)\(index)"
    }

    func cloneEntry(id: String) {
        guard let source = entries.first(where: { $0.id == id }) else { return }
        let newLabel = nextCustomURLLabel()
        let clone = Sitchomatic1000Entry(
            url: URLNormalizer.normalize(source.url),
            label: newLabel,
            assignedFlowId: source.assignedFlowId,
            assignedFlowName: source.assignedFlowName,
            credentialList: [],
            isActive: source.isActive
        )
        entries.append(clone)
        saveEntries()
        logger.log("S1000: Cloned '\(source.label)' -> '\(clone.label)' (URL + flow, empty creds)", category: .system, level: .info)
    }

    func removeEntry(id: String) {
        entries.removeAll { $0.id == id }
        saveEntries()
    }

    func removeEntries(at offsets: IndexSet) {
        entries.remove(atOffsets: offsets)
        saveEntries()
    }

    func toggleActive(id: String) {
        guard let idx = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[idx].isActive.toggle()
        saveEntries()
    }

    func assignFlow(entryId: String, flowId: String, flowName: String) {
        guard let idx = entries.firstIndex(where: { $0.id == entryId }) else { return }
        entries[idx].assignedFlowId = flowId
        entries[idx].assignedFlowName = flowName
        saveEntries()
        logger.log("S1000: Assigned flow '\(flowName)' to \(entries[idx].label)", category: .system, level: .info)
    }

    func appendCredentialText(entryId: String, text: String) -> Int {
        let parsed = parseBulkCredentials(text)
        guard !parsed.isEmpty else { return 0 }
        appendCredentialList(entryId: entryId, credentials: parsed)
        return parsed.count
    }

    func appendCredentialTextToAllWindows(_ text: String) -> Int {
        let parsed = parseBulkCredentials(text)
        guard !parsed.isEmpty, !entries.isEmpty else { return 0 }
        for idx in entries.indices {
            entries[idx].credentialList.append(contentsOf: parsed)
        }
        saveEntries()
        logger.log("S1000: Appended \(parsed.count) creds to ALL \(entries.count) windows", category: .system, level: .info)
        return parsed.count
    }

    func appendCredentialList(entryId: String, credentials: [SitchCredentialLine]) {
        guard let idx = entries.firstIndex(where: { $0.id == entryId }), !credentials.isEmpty else { return }
        entries[idx].credentialList.append(contentsOf: credentials)
        saveEntries()
        logger.log("S1000: Appended \(credentials.count) creds to \(entries[idx].label)", category: .system, level: .info)
    }

    func resetNewURLFields() {
        newURL = ""
        newLabel = ""
    }

    func parseBulkCredentials(_ text: String) -> [SitchCredentialLine] {
        let lines = text.components(separatedBy: .newlines)
        var results: [SitchCredentialLine] = []
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let separators: [Character] = [":", ";", ",", "|", "\t"]
            var parts: [String]?
            for sep in separators {
                let split = trimmed.split(separator: sep, maxSplits: 1).map(String.init)
                if split.count == 2 {
                    parts = split
                    break
                }
            }
            guard let p = parts, p.count == 2 else { continue }
            let email = p[0].trimmingCharacters(in: .whitespaces)
            let pass = p[1].trimmingCharacters(in: .whitespaces)
            guard !email.isEmpty, !pass.isEmpty else { continue }
            results.append(SitchCredentialLine(email: email, password: pass))
        }
        return results
    }

    func importBulkCredentials(to target: BulkAssignTarget) {
        let parsed = parseBulkCredentials(bulkPasteText)
        guard !parsed.isEmpty else {
            lastBulkImportSummary = "No valid lines found"
            return
        }

        guard !entries.isEmpty else {
            lastBulkImportSummary = "No CCTV windows available"
            return
        }

        switch target {
        case .all:
            for idx in entries.indices {
                entries[idx].credentialList.append(contentsOf: parsed)
            }
            lastBulkImportSummary = "Appended \(parsed.count) creds to all \(entries.count) windows"
            logger.log("S1000: Appended \(parsed.count) creds to ALL \(entries.count) windows", category: .system, level: .info)

        case .specific(let entryId):
            guard let idx = entries.firstIndex(where: { $0.id == entryId }) else {
                lastBulkImportSummary = "Window not found"
                return
            }
            entries[idx].credentialList.append(contentsOf: parsed)
            lastBulkImportSummary = "Appended \(parsed.count) creds to \(entries[idx].label)"
            logger.log("S1000: Appended \(parsed.count) creds to \(entries[idx].label)", category: .system, level: .info)
        }

        bulkPasteText = ""
        saveEntries()
    }

    func clearCredentialList(entryId: String) {
        guard let idx = entries.firstIndex(where: { $0.id == entryId }) else { return }
        entries[idx].credentialList = []
        saveEntries()
    }

    private func saveEntries() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func loadEntries() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([Sitchomatic1000Entry].self, from: data) else { return }
        var migrated = decoded
        var didChange = false
        for i in migrated.indices {
            let normalized = URLNormalizer.normalize(migrated[i].url)
            if normalized != migrated[i].url {
                migrated[i].url = normalized
                didChange = true
            }
        }
        entries = migrated
        if didChange { saveEntries() }
    }
}
