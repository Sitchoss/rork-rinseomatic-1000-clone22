import SwiftUI

struct CredentialHubView: View {
    @State private var vm = LoginViewModel.shared
    @State private var selectedTab: CredentialHubTab = .dashboard
    @State private var urlService = LoginURLRotationService.shared

    nonisolated enum CredentialHubTab: String, Sendable {
        case dashboard
        case importCredentials
        case saved
        case working
        case sessions
    }

    private var hubAccent: Color { urlService.isIgnitionMode ? .orange : .green }

    var body: some View {
        VStack(spacing: 0) {
            ignitionModeBar

            TabView(selection: $selectedTab) {
                Tab("Dashboard", systemImage: "rectangle.grid.2x2.fill", value: .dashboard) {
                    NavigationStack {
                        LoginDashboardContentView(vm: vm)
                    }
                }

                Tab("Import", systemImage: "square.and.arrow.down.fill", value: .importCredentials) {
                    NavigationStack {
                        CredentialImportView(vm: vm)
                    }
                }

                Tab("Saved", systemImage: "tray.full.fill", value: .saved) {
                    NavigationStack {
                        LoginCredentialsListView(vm: vm)
                    }
                }

                Tab("Working", systemImage: "checkmark.shield.fill", value: .working) {
                    NavigationStack {
                        LoginWorkingListView(vm: vm)
                    }
                }

                Tab("Sessions", systemImage: "rectangle.stack.fill", value: .sessions) {
                    NavigationStack {
                        LoginSessionMonitorContentView(vm: vm)
                    }
                }
            }
            .tint(hubAccent)
        }
        .animation(.easeInOut(duration: 0.3), value: urlService.isIgnitionMode)
        .preferredColorScheme(vm.appearanceMode.colorScheme)
        .withMainMenuButton()
        .sensoryFeedback(.impact(weight: .medium), trigger: urlService.isIgnitionMode)
    }

    private var ignitionModeBar: some View {
        HStack(spacing: 10) {
            Image(systemName: urlService.isIgnitionMode ? "flame.fill" : "suit.spade.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(hubAccent)
                .contentTransition(.symbolEffect(.replace))

            VStack(alignment: .leading, spacing: 1) {
                Text(urlService.isIgnitionMode ? "Ignition Lite" : "JoePoint")
                    .font(.system(.subheadline, design: .monospaced, weight: .bold))
                    .contentTransition(.numericText())
                Text(urlService.isIgnitionMode ? "ignitioncasino.ooo/login" : "joefortunepokies.eu/login")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Toggle(isOn: Binding(
                get: { urlService.isIgnitionMode },
                set: { urlService.isIgnitionMode = $0 }
            )) {
                EmptyView()
            }
            .toggleStyle(.switch)
            .tint(.orange)
            .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(hubAccent.opacity(0.08))
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}
