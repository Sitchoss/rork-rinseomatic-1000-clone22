import SwiftUI

struct DevSettingsEnvironmentKey: EnvironmentKey {
    static let defaultValue: Binding<AutomationSettings>? = nil
}

extension EnvironmentValues {
    var devSettings: Binding<AutomationSettings>? {
        get { self[DevSettingsEnvironmentKey.self] }
        set { self[DevSettingsEnvironmentKey.self] = newValue }
    }
}

struct DevSectionPage<Content: View>: View {
    let title: String
    @Binding var settings: AutomationSettings
    let content: Content
    @State private var savedToast: Bool = false

    init(_ title: String, settings: Binding<AutomationSettings>, @ViewBuilder content: () -> Content) {
        self.title = title
        self._settings = settings
        self.content = content()
    }

    var body: some View {
        List {
            content
        }
        .listStyle(.insetGrouped)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { bottomBar }
        .overlay(alignment: .top) { toastOverlay }
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Button { save() } label: {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.down.fill")
                    Text("Save")
                }
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(.blue.gradient, in: .rect(cornerRadius: 12))
            }
            .sensoryFeedback(.success, trigger: savedToast)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private var toastOverlay: some View {
        Group {
            if savedToast {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Settings Saved")
                }
                .font(.subheadline.bold()).foregroundStyle(.white)
                .padding(.horizontal, 20).padding(.vertical, 12)
                .background(.green.gradient, in: Capsule())
                .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
                .transition(.move(edge: .top).combined(with: .opacity))
                .padding(.top, 8)
            }
        }
    }

    private func save() {
        let normalized = settings.normalizedTimeouts()
        AutomationSettingsPersistence.shared.save(normalized)
        withAnimation(.spring(duration: 0.3)) { savedToast = true }
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation { savedToast = false }
        }
    }
}

func devToggle(_ label: String, _ binding: Binding<Bool>) -> some View {
    Toggle(label, isOn: binding).font(.subheadline).tint(.blue)
}

func devInt(_ label: String, _ binding: Binding<Int>) -> some View {
    HStack {
        Text(label).font(.subheadline).lineLimit(1).minimumScaleFactor(0.7)
        Spacer()
        TextField("", value: binding, format: .number)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.trailing)
            .frame(width: 80)
            .font(.system(.subheadline, design: .monospaced))
            .foregroundStyle(.blue)
    }
}

func devDouble(_ label: String, _ binding: Binding<Double>) -> some View {
    HStack {
        Text(label).font(.subheadline).lineLimit(1).minimumScaleFactor(0.7)
        Spacer()
        TextField("", value: binding, format: .number.precision(.fractionLength(0...3)))
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .frame(width: 80)
            .font(.system(.subheadline, design: .monospaced))
            .foregroundStyle(.blue)
    }
}

func devString(_ label: String, _ binding: Binding<String>) -> some View {
    VStack(alignment: .leading, spacing: 4) {
        Text(label).font(.subheadline)
        TextField(label, text: binding)
            .font(.system(.caption, design: .monospaced))
            .textFieldStyle(.roundedBorder)
    }
}

func devStringArray(_ label: String, _ binding: Binding<[String]>) -> some View {
    VStack(alignment: .leading, spacing: 4) {
        Text(label).font(.subheadline)
        Text(binding.wrappedValue.joined(separator: ", "))
            .font(.system(.caption2, design: .monospaced))
            .foregroundStyle(.secondary)
            .lineLimit(3)
        TextField("Edit (comma-separated)", text: Binding(
            get: { binding.wrappedValue.joined(separator: ", ") },
            set: { newVal in
                binding.wrappedValue = newVal
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
            }
        ))
        .font(.system(.caption, design: .monospaced))
        .textFieldStyle(.roundedBorder)
    }
}

func devValidationWarning(_ message: String) -> some View {
    HStack(spacing: 6) {
        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red).font(.caption2)
        Text(message).font(.caption2).foregroundStyle(.red)
    }
}

func devInfoNote(_ text: String) -> some View {
    HStack(spacing: 6) {
        Image(systemName: "info.circle").foregroundStyle(.blue).font(.caption2)
        Text(text).font(.caption2).foregroundStyle(.secondary)
    }
}

// MARK: - Submit Method Picker ("4th Box")

struct SubmitMethodPickerRow: View {
    let site: LoginTargetSite
    @Binding var settings: AutomationSettings
    @StateObject private var controller = SubmitMethodController.shared

    private var binding: Binding<AutomationSettings.SubmitMethod> {
        switch site {
        case .joefortune:
            Binding(
                get: { settings.joeSubmitMethod },
                set: { newValue in
                    settings.joeSubmitMethod = newValue
                    controller.joeSubmitMethod = newValue
                    if controller.isGlobalSyncActive {
                        settings.ignSubmitMethod = newValue
                    }
                }
            )
        case .ignition:
            Binding(
                get: { settings.ignSubmitMethod },
                set: { newValue in
                    settings.ignSubmitMethod = newValue
                    controller.ignSubmitMethod = newValue
                }
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "bolt.horizontal.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                Text("Submit Method")
                    .font(.subheadline)
            }
            Picker("", selection: binding) {
                ForEach(AutomationSettings.SubmitMethod.allCases) { method in
                    Label(method.rawValue, systemImage: method.icon)
                        .tag(method)
                }
            }
            .pickerStyle(.menu)
            .font(.subheadline)
            .tint(.orange)

            Text(binding.wrappedValue.description)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .disabled(site == .ignition && controller.isGlobalSyncActive)
        .opacity(site == .ignition && controller.isGlobalSyncActive ? 0.4 : 1)
    }
}

struct SubmitMethodGlobalSyncSection: View {
    @Binding var settings: AutomationSettings
    @StateObject private var controller = SubmitMethodController.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: Binding(
                get: { controller.isGlobalSyncActive },
                set: { newValue in
                    controller.isGlobalSyncActive = newValue
                    if newValue {
                        settings.ignSubmitMethod = settings.joeSubmitMethod
                    }
                }
            )) {
                HStack(spacing: 6) {
                    Image(systemName: "link")
                        .font(.caption)
                        .foregroundStyle(.blue)
                    Text("Sync Both Sites")
                        .font(.subheadline)
                }
            }
            .tint(.blue)

            if controller.isGlobalSyncActive {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption2)
                    Text("Both sites use: \(settings.joeSubmitMethod.rawValue)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "suit.spade.fill").font(.caption2).foregroundStyle(.green)
                        Text("Joe: \(settings.joeSubmitMethod.rawValue)").font(.caption2).foregroundStyle(.secondary)
                    }
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill").font(.caption2).foregroundStyle(.orange)
                        Text("Ign: \(settings.ignSubmitMethod.rawValue)").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }

            devInfoNote("When synced, changing Joe Fortune's method automatically updates Ignition. Default: Triple-Click Synced.")
        }
    }
}
