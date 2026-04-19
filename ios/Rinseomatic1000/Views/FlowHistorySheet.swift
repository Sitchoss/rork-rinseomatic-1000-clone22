import SwiftUI

struct FlowHistorySheet: View {
    let flow: RecordedFlow
    let onRestore: (RecordedFlow) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var foundationStore = AutomationFoundationStore.shared

    private var history: [AutomationFlowHistorySnapshot] {
        foundationStore.flowHistory(for: flow.id)
    }

    var body: some View {
        NavigationStack {
            Group {
                if history.isEmpty {
                    ContentUnavailableView(
                        "No Revision History",
                        systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90",
                        description: Text("Save an edited version of this flow to start building history.")
                    )
                } else {
                    List(history) { entry in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Version \(entry.version)")
                                        .font(.subheadline.weight(.semibold))
                                    Text(entry.savedAt.formatted(.relative(presentation: .named)))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("\(entry.actionCount) actions")
                                    .font(.system(.caption, design: .monospaced, weight: .bold))
                                    .foregroundStyle(.secondary)
                            }

                            Text(entry.changeSummary)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Button {
                                if let restoredFlow = foundationStore.restoreFlowRevision(recordID: entry.id) {
                                    onRestore(restoredFlow)
                                    dismiss()
                                }
                            } label: {
                                Label("Load This Revision Into Draft", systemImage: "arrow.counterclockwise")
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.vertical, 4)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Flow History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
