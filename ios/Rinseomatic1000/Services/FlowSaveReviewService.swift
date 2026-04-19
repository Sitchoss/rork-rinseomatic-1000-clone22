import Foundation

nonisolated struct FlowSaveReview: Identifiable, Sendable {
    let id: String
    let title: String
    let summaryText: String
    let changeItems: [FlowSaveReviewItem]
    let validationErrors: [String]

    var isValid: Bool {
        validationErrors.isEmpty
    }

    var hasMaterialChanges: Bool {
        !changeItems.isEmpty
    }
}

nonisolated struct FlowSaveReviewItem: Identifiable, Sendable {
    let id: String
    let icon: String
    let tint: String
    let title: String
    let detail: String
}

nonisolated enum FlowSaveReviewService {
    static func review(original: RecordedFlow?, updated: RecordedFlow) -> FlowSaveReview {
        let trimmedName = updated.name.trimmingCharacters(in: .whitespacesAndNewlines)
        var validationErrors: [String] = []

        if trimmedName.isEmpty {
            validationErrors.append("Flow name is required.")
        }
        if URL(string: updated.url)?.scheme == nil {
            validationErrors.append("A valid URL with a scheme is required.")
        }
        if updated.actions.isEmpty {
            validationErrors.append("At least one recorded action is required.")
        }
        if updated.actions.contains(where: { $0.deltaFromPreviousMs < 0 }) {
            validationErrors.append("Action timing cannot be negative.")
        }

        guard let original else {
            let item = FlowSaveReviewItem(
                id: "new-flow",
                icon: "plus.circle.fill",
                tint: "green",
                title: "New flow",
                detail: "Save \(updated.actionCount) actions for \(hostLabel(updated.url))."
            )
            return FlowSaveReview(
                id: UUID().uuidString,
                title: "Save New Flow",
                summaryText: "Create a new default flow for \(hostLabel(updated.url)) with \(updated.actionCount) actions.",
                changeItems: [item],
                validationErrors: validationErrors
            )
        }

        var changeItems: [FlowSaveReviewItem] = []

        if original.name != updated.name {
            changeItems.append(
                FlowSaveReviewItem(
                    id: "rename",
                    icon: "character.textbox",
                    tint: "blue",
                    title: "Renamed flow",
                    detail: "\(original.name) → \(updated.name)"
                )
            )
        }

        if original.url != updated.url {
            changeItems.append(
                FlowSaveReviewItem(
                    id: "url",
                    icon: "link",
                    tint: "cyan",
                    title: "Updated target URL",
                    detail: "\(hostLabel(original.url)) → \(hostLabel(updated.url))"
                )
            )
        }

        let addedActions = max(updated.actions.count - original.actions.count, 0)
        let removedActions = max(original.actions.count - updated.actions.count, 0)
        if addedActions > 0 || removedActions > 0 {
            let detailParts = [
                addedActions > 0 ? "+\(addedActions) step\(addedActions == 1 ? "" : "s")" : nil,
                removedActions > 0 ? "−\(removedActions) step\(removedActions == 1 ? "" : "s")" : nil
            ].compactMap { $0 }
            changeItems.append(
                FlowSaveReviewItem(
                    id: "action-count",
                    icon: "list.bullet.rectangle",
                    tint: removedActions > addedActions ? "orange" : "green",
                    title: "Changed action count",
                    detail: detailParts.joined(separator: " • ")
                )
            )
        }

        if original.actions.map(\.id) != updated.actions.map(\.id), Set(original.actions.map(\.id)) == Set(updated.actions.map(\.id)) {
            changeItems.append(
                FlowSaveReviewItem(
                    id: "reordered",
                    icon: "arrow.up.arrow.down",
                    tint: "purple",
                    title: "Reordered timeline",
                    detail: "Step order changed without changing the action set."
                )
            )
        }

        let selectorChanges = selectorChangeCount(original: original, updated: updated)
        if selectorChanges > 0 {
            changeItems.append(
                FlowSaveReviewItem(
                    id: "selectors",
                    icon: "target",
                    tint: "indigo",
                    title: "Adjusted selectors",
                    detail: "\(selectorChanges) step\(selectorChanges == 1 ? "" : "s") now target different DOM elements."
                )
            )
        }

        let textChanges = textChangeCount(original: original, updated: updated)
        if textChanges > 0 {
            changeItems.append(
                FlowSaveReviewItem(
                    id: "text",
                    icon: "text.cursor",
                    tint: "teal",
                    title: "Updated field content",
                    detail: "\(textChanges) input step\(textChanges == 1 ? "" : "s") or mappings were changed."
                )
            )
        }

        let timingDelta = Int((updated.totalDurationMs - original.totalDurationMs).rounded())
        if abs(timingDelta) >= 100 {
            let sign = timingDelta >= 0 ? "+" : "−"
            changeItems.append(
                FlowSaveReviewItem(
                    id: "timing",
                    icon: "clock.arrow.2.circlepath",
                    tint: timingDelta >= 0 ? "orange" : "mint",
                    title: "Retimed flow",
                    detail: "Total duration \(sign)\(abs(timingDelta))ms."
                )
            )
        }

        if changeItems.isEmpty {
            changeItems.append(
                FlowSaveReviewItem(
                    id: "no-changes",
                    icon: "checkmark.circle",
                    tint: "secondary",
                    title: "No material changes",
                    detail: "This save keeps the current structure but updates the latest revision timestamp."
                )
            )
        }

        let summaryText = summaryText(from: changeItems)
        return FlowSaveReview(
            id: UUID().uuidString,
            title: "Review Changes",
            summaryText: summaryText,
            changeItems: changeItems,
            validationErrors: validationErrors
        )
    }

    private static func selectorChangeCount(original: RecordedFlow, updated: RecordedFlow) -> Int {
        let originalByID = Dictionary(uniqueKeysWithValues: original.actions.map { ($0.id, $0) })
        return updated.actions.reduce(into: 0) { count, action in
            guard let originalAction = originalByID[action.id] else { return }
            if originalAction.targetSelector != action.targetSelector || originalAction.targetTagName != action.targetTagName {
                count += 1
            }
        }
    }

    private static func textChangeCount(original: RecordedFlow, updated: RecordedFlow) -> Int {
        let originalByID = Dictionary(uniqueKeysWithValues: original.actions.map { ($0.id, $0) })
        let actionChanges = updated.actions.reduce(into: 0) { count, action in
            guard let originalAction = originalByID[action.id] else { return }
            if originalAction.textContent != action.textContent || originalAction.textboxLabel != action.textboxLabel {
                count += 1
            }
        }

        let mappingChanges = zip(original.textboxMappings, updated.textboxMappings).reduce(into: 0) { count, pair in
            let originalMapping = pair.0
            let updatedMapping = pair.1
            if originalMapping.placeholderKey != updatedMapping.placeholderKey || originalMapping.label != updatedMapping.label {
                count += 1
            }
        }

        return actionChanges + mappingChanges + abs(updated.textboxMappings.count - original.textboxMappings.count)
    }

    private static func summaryText(from items: [FlowSaveReviewItem]) -> String {
        let meaningfulItems = items.filter { $0.id != "no-changes" }
        guard !meaningfulItems.isEmpty else {
            return "No material changes were detected before save."
        }

        let phrases = meaningfulItems.prefix(3).map { $0.title.lowercased() }
        return "This save will commit \(phrases.joined(separator: ", "))."
    }

    private static func hostLabel(_ urlString: String) -> String {
        URL(string: urlString)?.host ?? urlString
    }
}
