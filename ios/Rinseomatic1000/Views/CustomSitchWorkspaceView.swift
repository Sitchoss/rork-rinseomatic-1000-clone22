import SwiftUI

struct CustomSitchWorkspaceView: View {
    @State private var flowVM = FlowRecorderViewModel()
    @State private var showCustomBuildStub: Bool = false

    nonisolated enum Route: Hashable, Sendable {
        case flowRecorder
        case savedFlows
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Custom Sitch")
                            .font(.headline)
                        Text("Private workspace for recorder-driven experiments and custom build work.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section("Workspace") {
                    NavigationLink(value: Route.flowRecorder) {
                        workspaceRow(icon: "record.circle.fill", title: "Flow Recorder", subtitle: "Open the recorder in the hidden workspace", color: .red)
                    }
                    NavigationLink(value: Route.savedFlows) {
                        workspaceRow(icon: "tray.full.fill", title: "Saved Flows", subtitle: "Review and edit recorded flows", color: .pink)
                    }
                    Button {
                        showCustomBuildStub = true
                    } label: {
                        workspaceRow(icon: "wand.and.stars", title: "Custom Build", subtitle: "Stub entry for future private build actions", color: .purple)
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Custom Sitch")
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .flowRecorder:
                    FlowRecorderView()
                case .savedFlows:
                    SavedFlowsView(vm: flowVM)
                }
            }
            .alert("Custom Build", isPresented: $showCustomBuildStub) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("The private custom build action is wired as a stub and ready for the next pass.")
            }
        }
        .withMainMenuButton()
        .preferredColorScheme(.dark)
    }

    private func workspaceRow(icon: String, title: String, subtitle: String, color: Color) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
