import SwiftUI

@Observable
@MainActor
final class GeminiAIStatusViewModel {
    var isTestingConnection: Bool = false
    var testResult: String? = nil
    var testSuccess: Bool = false
    var testLatencyMs: Int = 0
    var pastedKey: String = ""
    var showSaveConfirmation: Bool = false
    var saveMessage: String = ""
    var isSaveSuccess: Bool = false

    func runConnectionTest() async {
        isTestingConnection = true
        testResult = nil
        let result = await GeminiAIService.shared.testConnection()
        isTestingConnection = false
        testSuccess = result.success
        testLatencyMs = result.latencyMs
        testResult = result.success
            ? "Connected — \(result.latencyMs) ms via \(result.model)"
            : "Connection failed — check API key"
    }

    func savePastedKey() async {
        let trimmed = pastedKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            saveMessage = "Paste a key first"
            isSaveSuccess = false
            showSaveConfirmation = true
            return
        }
        let stored = GeminiAISetup.configure(apiKey: trimmed)
        guard stored else {
            saveMessage = "Failed to save key to Keychain"
            isSaveSuccess = false
            showSaveConfirmation = true
            return
        }
        // Live validation
        let result = await GeminiAIService.shared.testConnection()
        if result.success {
            saveMessage = "Saved & validated — \(result.latencyMs) ms"
            isSaveSuccess = true
            pastedKey = ""
        } else {
            saveMessage = "Key saved but validation failed — check the key"
            isSaveSuccess = false
        }
        showSaveConfirmation = true
    }

    func removeKey() {
        GeminiAISetup.reset()
        saveMessage = "API key removed"
        isSaveSuccess = false
        showSaveConfirmation = true
    }
}

struct GrokAIStatusView: View {
    @State private var vm = GeminiAIStatusViewModel()
    @State private var isKeyVisible: Bool = false

    private var stats: GeminiUsageStats { GeminiUsageStats.shared }
    private var isConfigured: Bool { GeminiAISetup.isConfigured }

    var body: some View {
        List {
            pasteKeySection
            statusSection
            telemetrySection
            usageSection
            modelsSection
            testSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Gemini AI Status")
        .navigationBarTitleDisplayMode(.large)
        .preferredColorScheme(.dark)
        .alert("Gemini API Key", isPresented: $vm.showSaveConfirmation) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.saveMessage)
        }
    }

    // MARK: - Paste Key

    private var pasteKeySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "key.fill")
                        .foregroundStyle(.yellow)
                    Text("Gemini API Key")
                        .font(.subheadline.bold())
                    Spacer()
                    if isConfigured {
                        Label("Saved", systemImage: "checkmark.seal.fill")
                            .font(.caption.bold())
                            .foregroundStyle(.green)
                    }
                }

                Group {
                    if isKeyVisible {
                        TextField("Paste your Gemini API key", text: $vm.pastedKey, axis: .vertical)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .lineLimit(1...3)
                    } else {
                        SecureField("Paste your Gemini API key", text: $vm.pastedKey)
                    }
                }
                .font(.system(.footnote, design: .monospaced))
                .padding(10)
                .background(Color.secondary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                HStack(spacing: 10) {
                    Button {
                        if let clip = UIPasteboard.general.string {
                            vm.pastedKey = clip.trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    } label: {
                        Label("Paste", systemImage: "doc.on.clipboard")
                            .font(.caption.bold())
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button {
                        isKeyVisible.toggle()
                    } label: {
                        Label(isKeyVisible ? "Hide" : "Show", systemImage: isKeyVisible ? "eye.slash" : "eye")
                            .font(.caption.bold())
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Spacer()

                    Button {
                        Task { await vm.savePastedKey() }
                    } label: {
                        Label("Save & Validate", systemImage: "checkmark.circle.fill")
                            .font(.caption.bold())
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(vm.pastedKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if isConfigured {
                    Button(role: .destructive) {
                        vm.removeKey()
                    } label: {
                        Label("Remove Saved Key", systemImage: "trash")
                            .font(.caption)
                    }
                }

                Text("Get a key at aistudio.google.com/app/apikey. Stored securely in the iOS Keychain.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        } header: {
            Label("Configure API Key", systemImage: "key.horizontal.fill")
        }
    }

    // MARK: - Status

    private var statusSection: some View {
        Section {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(isConfigured ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: isConfigured ? "sparkles" : "exclamationmark.triangle.fill")
                        .font(.title2)
                        .foregroundStyle(isConfigured ? .green : .red)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(isConfigured ? "Gemini AI Active" : "Gemini AI Not Configured")
                        .font(.headline)
                    Text(isConfigured ? "Key loaded — vision + telemetry live" : "Paste your Gemini API key above")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isConfigured {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                }
            }
            .padding(.vertical, 4)

            if isConfigured {
                statusPill(label: "Reasoning", value: GeminiModel.pro.rawValue, color: .purple)
                statusPill(label: "Vision", value: GeminiModel.flash.rawValue, color: .blue)
                statusPill(label: "Fast Tasks", value: GeminiModel.flashLite.rawValue, color: .mint)
            }
        } header: {
            Label("Connection Status", systemImage: "antenna.radiowaves.left.and.right")
        }
    }

    // MARK: - Telemetry

    private var telemetrySection: some View {
        let t = AITelemetryService.shared
        return Section {
            usageRow(icon: "wrench.and.screwdriver.fill", label: "Self-Heals Performed", value: "\(t.selfHealCount)", color: .mint)
            usageRow(icon: "shield.lefthalf.filled", label: "Avg Stealth Score", value: t.averageStealthScore > 0 ? "\(Int(t.averageStealthScore))/100" : "—", color: t.averageStealthScore >= 70 ? .green : t.averageStealthScore >= 40 ? .orange : .red)
            usageRow(icon: "exclamationmark.bubble.fill", label: "Diagnosed Failures", value: "\(t.diagnoses.count)", color: .purple)

            if !t.topFailureReasons.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Top Failure Reasons")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    ForEach(t.topFailureReasons.prefix(5), id: \.reason) { item in
                        HStack(spacing: 8) {
                            Text("\(item.count)×")
                                .font(.system(.caption2, design: .monospaced, weight: .heavy))
                                .foregroundStyle(.purple)
                                .frame(width: 32, alignment: .leading)
                            Text(item.reason)
                                .font(.caption)
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            Button(role: .destructive) {
                AITelemetryService.shared.resetStats()
            } label: {
                Label("Reset Telemetry", systemImage: "arrow.counterclockwise")
                    .font(.subheadline)
                    .foregroundStyle(.red)
            }
        } header: {
            Label("AI Telemetry", systemImage: "sparkles")
        } footer: {
            Text("Gemini diagnoses failures, scores session stealth, and heals broken selectors automatically during every run.")
        }
    }

    // MARK: - Usage

    private var usageSection: some View {
        Section {
            usageRow(icon: "arrow.up.circle.fill", label: "Total API Calls", value: "\(stats.totalCalls)", color: .blue)
            usageRow(icon: "checkmark.circle.fill", label: "Successful", value: "\(stats.successfulCalls)", color: .green)
            usageRow(icon: "xmark.circle.fill", label: "Failed", value: "\(stats.failedCalls)", color: .red)
            usageRow(
                icon: "percent",
                label: "Success Rate",
                value: stats.totalCalls > 0 ? "\(Int(stats.successRate * 100))%" : "—",
                color: stats.successRate > 0.8 ? .green : stats.successRate > 0.5 ? .orange : .red
            )
            usageRow(icon: "textformat.characters", label: "Tokens Used", value: stats.totalTokensUsed > 0 ? "\(stats.totalTokensUsed.formatted())" : "—", color: .purple)

            if let lastCall = stats.lastCallTime {
                usageRow(icon: "clock.fill", label: "Last Call", value: lastCall.formatted(.relative(presentation: .named)), color: .secondary)
            }

            if let lastError = stats.lastError {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.caption)
                    Text("Last error: \(lastError)")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(3)
                }
                .padding(.vertical, 2)
            }

            Button(role: .destructive) {
                GeminiUsageStats.shared.reset()
            } label: {
                Label("Reset Stats", systemImage: "arrow.counterclockwise")
                    .font(.subheadline)
                    .foregroundStyle(.red)
            }
        } header: {
            Label("Usage Statistics", systemImage: "chart.bar.fill")
        }
    }

    // MARK: - Models

    private var modelsSection: some View {
        Section {
            modelRow(name: GeminiModel.pro.rawValue, usage: "Telemetry reasoning · fingerprint tuning · timing optimization · result evaluation", icon: "brain.head.profile.fill", color: .purple)
            modelRow(name: GeminiModel.flash.rawValue, usage: "Vision screenshot analysis — login result, PPSR outcome, selector self-heal", icon: "eye.fill", color: .blue)
            modelRow(name: GeminiModel.flashLite.rawValue, usage: "OCR field mapping · quick classifications · connection test", icon: "hare.fill", color: .mint)
        } header: {
            Label("Gemini Model Stack", systemImage: "square.stack.3d.up.fill")
        } footer: {
            Text("Gemini 2.5 powers all AI across the app — vision, telemetry, and reasoning.")
        }
    }

    // MARK: - Test

    private var testSection: some View {
        Section {
            Button {
                Task { await vm.runConnectionTest() }
            } label: {
                HStack {
                    Label("Test Connection", systemImage: "network.badge.shield.half.filled")
                        .font(.subheadline.bold())
                    Spacer()
                    if vm.isTestingConnection { ProgressView().controlSize(.small) }
                }
            }
            .disabled(vm.isTestingConnection || !isConfigured)

            if let result = vm.testResult {
                HStack(spacing: 8) {
                    Image(systemName: vm.testSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(vm.testSuccess ? .green : .red)
                    Text(result).font(.subheadline)
                        .foregroundStyle(vm.testSuccess ? Color.primary : Color.red)
                }
            }
        } header: {
            Label("Connection Test", systemImage: "wifi")
        } footer: {
            Text("Sends a minimal test request to verify your Gemini API key is valid.")
        }
    }

    // MARK: - Helpers

    private func statusPill(label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(.caption, design: .monospaced, weight: .semibold))
                .foregroundStyle(color)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(color.opacity(0.12))
                .clipShape(Capsule())
        }
    }

    private func usageRow(icon: String, label: String, value: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(color).frame(width: 20)
            Text(label).font(.subheadline)
            Spacer()
            Text(value).font(.system(.subheadline, design: .monospaced, weight: .semibold))
        }
    }

    private func modelRow(name: String, usage: String, icon: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.12)).frame(width: 34, height: 34)
                Image(systemName: icon).font(.callout).foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.subheadline.bold())
                Text(usage).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
