import SwiftUI

struct FlowScriptModePickerSheet: View {
    let flow: RecordedFlow
    let onDismiss: () -> Void
    
    @State private var assignmentService = FlowScriptAssignmentService.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(FlowScriptMode.allCases) { mode in
                        Button {
                            assignmentService.assign(flowID: flow.id, to: mode)
                            dismiss()
                            onDismiss()
                        } label: {
                            HStack {
                                Label(mode.displayName, systemImage: mode.systemIcon)
                                    .foregroundStyle(.primary)
                                
                                Spacer()
                                
                                if assignmentService.assignedFlowID(for: mode) == flow.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                        .font(.system(size: 14, weight: .bold))
                                }
                            }
                        }
                    }
                } header: {
                    Text("Select Target Site / Engine")
                } footer: {
                    Text("Assigning this flow will cause the selected engine to use this recording instead of its default automation patterns.")
                }
                
                let assignedModes = assignmentService.assignedModes(for: flow.id)
                if !assignedModes.isEmpty {
                    Section {
                        ForEach(assignedModes) { mode in
                            Button(role: .destructive) {
                                assignmentService.unassign(mode)
                                if assignmentService.assignedModes(for: flow.id).isEmpty {
                                    dismiss()
                                    onDismiss()
                                }
                            } label: {
                                Label("Remove \(mode.displayName) Assignment", systemImage: "trash")
                            }
                        }
                        
                        if assignedModes.count > 1 {
                            Button(role: .destructive) {
                                for mode in assignedModes {
                                    assignmentService.unassign(mode)
                                }
                                dismiss()
                                onDismiss()
                            } label: {
                                Label("Remove All Assignments", systemImage: "trash.fill")
                            }
                        }
                    } header: {
                        Text("Active Assignments")
                    }
                }
            }
            .navigationTitle("Apply Flow Script")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                        onDismiss()
                    }
                }
            }
        }
    }
}
