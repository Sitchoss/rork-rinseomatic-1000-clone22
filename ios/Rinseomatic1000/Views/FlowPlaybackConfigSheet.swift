import SwiftUI

struct FlowPlaybackConfigSheet: View {
    @Bindable var vm: FlowRecorderViewModel

    var body: some View {
        NavigationStack {
            Form {
                if let flow = vm.selectedFlow {
                    Section("Flow: \(flow.name)") {
                        LabeledContent("Actions", value: "\(flow.actionCount)")
                        LabeledContent("Duration", value: flow.formattedDuration)
                        LabeledContent("URL") {
                            Text(flow.url)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Section(vm.recordAfterPlayback ? "Continue Recording" : "Playback Options") {
                        Stepper(
                            vm.recordAfterPlayback ? "Replace from step: \(vm.playFromStepIndex)" : "Start from step: \(vm.playFromStepIndex)",
                            value: $vm.playFromStepIndex,
                            in: 0...max(0, flow.actions.count - 1)
                        )

                        Toggle("Record after playback", isOn: $vm.recordAfterPlayback)
                            .tint(.red)

                        if vm.recordAfterPlayback {
                            HStack(spacing: 8) {
                                Image(systemName: "record.circle.fill")
                                    .foregroundStyle(.red)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Replay safe prefix, then record a replacement tail")
                                        .font(.caption.weight(.semibold))
                                    Text("Steps before \(vm.playFromStepIndex) play automatically. New actions replace the broken tail from that step onward.")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } else if vm.playFromStepIndex > 0 {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.right.circle.fill")
                                    .foregroundStyle(.orange)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Playback starts from step \(vm.playFromStepIndex)")
                                        .font(.caption.weight(.semibold))
                                    Text("Useful for testing a later section without replaying the whole flow.")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    if !flow.textboxMappings.isEmpty {
                        Section("Fill Text Fields") {
                            ForEach(flow.textboxMappings) { mapping in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(mapping.selector.isEmpty ? mapping.label : mapping.selector)
                                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)

                                    if let token = mapping.assignedToken {
                                        Text(token.displayLabel)
                                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                                            .foregroundStyle(.blue)
                                    }
                                    
                                    let key = mapping.assignedToken?.templateKey ?? mapping.placeholderKey
                                    TextField("Enter value", text: Binding(
                                        get: { vm.textboxValues[key] ?? "" },
                                        set: { vm.textboxValues[key] = $0 }
                                    ))
                                    .font(.system(size: 14))
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    
                                    if !mapping.originalText.isEmpty {
                                        HStack(spacing: 2) {
                                            Text(mapping.assignedToken != nil ? "Token:" : "Original:")
                                            Text(mapping.originalText)
                                                .font(.system(size: 10, design: .monospaced))
                                        }
                                        .font(.system(size: 10))
                                        .foregroundStyle(.tertiary)
                                    }
                                }
                            }
                        }
                    }

                    Section {
                        Button {
                            vm.playSelectedFlow()
                        } label: {
                            HStack {
                                Image(systemName: vm.recordAfterPlayback ? "record.circle.fill" : "play.fill")
                                Text(vm.recordAfterPlayback ? "Replay Then Continue Recording" : "Start Playback")
                            }
                            .frame(maxWidth: .infinity)
                            .fontWeight(.semibold)
                        }
                    }
                }
            }
            .navigationTitle("Playback Config")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        vm.showPlaybackSheet = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationContentInteraction(.scrolls)
    }
}
