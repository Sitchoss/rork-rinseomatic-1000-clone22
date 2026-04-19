import SwiftUI
import UIKit

struct AppURLManagerSection: View {
    @Bindable var urlService: LoginURLRotationService
    @State private var viewingIgnition: Bool = false
    @State private var showImportBox: Bool = false
    @State private var importText: String = ""
    @State private var addURLText: String = ""
    @State private var addURLError: Bool = false
    @State private var showDeleteAllConfirm: Bool = false

    private var joeColor: Color { .green }
    private var ignitionColor: Color { .orange }
    private var accentColor: Color { viewingIgnition ? ignitionColor : joeColor }

    var body: some View {
        Section {
            sitePicker
        }

        if showImportBox {
            Section("Bulk Import") {
                importBox
            }
        }

        Section {
            addURLRow
        } header: {
            let list = viewingIgnition ? urlService.ignitionURLs : urlService.joeURLs
            let enabled = list.filter(\.isEnabled).count
            Text("\(viewingIgnition ? "Ignition" : "JoePoint") URLs (\(enabled)/\(list.count) enabled)")
        }

        urlListSection

        Section {
            actionButtons
        } header: {
            Text("Actions")
        }
    }

    private var sitePicker: some View {
        HStack(spacing: 0) {
            Button {
                withAnimation(.spring(duration: 0.3)) { viewingIgnition = false }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "suit.spade.fill")
                    Text("JoePoint").font(.subheadline.bold())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(!viewingIgnition ? joeColor : Color(.tertiarySystemFill))
                .foregroundStyle(!viewingIgnition ? .white : .secondary)
            }
            .clipShape(.rect(cornerRadii: .init(topLeading: 10, bottomLeading: 10)))

            Button {
                withAnimation(.spring(duration: 0.3)) { viewingIgnition = true }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                    Text("Ignition").font(.subheadline.bold())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(viewingIgnition ? ignitionColor : Color(.tertiarySystemFill))
                .foregroundStyle(viewingIgnition ? .white : .secondary)
            }
            .clipShape(.rect(cornerRadii: .init(bottomTrailing: 10, topTrailing: 10)))
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
    }

    private var addURLRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus.circle.fill")
                .foregroundStyle(accentColor)
            TextField("https://domain.com/login", text: $addURLText)
                .font(.system(.subheadline, design: .monospaced))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                .submitLabel(.done)
                .onSubmit { commitAddURL() }
            if addURLError {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.red)
                    .transition(.scale.combined(with: .opacity))
            }
            Button("Add") { commitAddURL() }
                .buttonStyle(.borderedProminent)
                .tint(accentColor)
                .controlSize(.small)
                .disabled(addURLText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private var urlListSection: some View {
        let urlList = viewingIgnition ? urlService.ignitionURLs : urlService.joeURLs
        return ForEach(urlList) { entry in
            HStack(spacing: 10) {
                Circle()
                    .fill(entry.isEnabled ? accentColor : Color.red.opacity(0.5))
                    .frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.host)
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundStyle(entry.isEnabled ? .primary : .secondary)
                        .strikethrough(!entry.isEnabled)
                    HStack(spacing: 6) {
                        if entry.failCount > 0 {
                            Text("\(entry.failCount) fails")
                                .font(.caption2).foregroundStyle(.red)
                        }
                        if entry.totalAttempts > 0 {
                            Text(entry.formattedSuccessRate)
                                .font(.caption2).foregroundStyle(.secondary)
                            Text(entry.formattedAvgResponse)
                                .font(.caption2).foregroundStyle(.tertiary)
                        }
                    }
                }
                Spacer()
                Button {
                    urlService.toggleURL(id: entry.id, enabled: !entry.isEnabled)
                } label: {
                    Image(systemName: entry.isEnabled ? "checkmark.circle.fill" : "xmark.circle")
                        .foregroundStyle(entry.isEnabled ? accentColor : .red.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) {
                    urlService.deleteURL(id: entry.id)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    private var importBox: some View {
        Group {
            TextEditor(text: $importText)
                .font(.system(.callout, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(.rect(cornerRadius: 8))
                .frame(minHeight: 100)
                .overlay(alignment: .topLeading) {
                    if importText.isEmpty {
                        Text("One URL per line...\nhttps://domain.com/login")
                            .font(.system(.callout, design: .monospaced))
                            .foregroundStyle(.quaternary)
                            .padding(.horizontal, 12).padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }
                }

            HStack {
                Button {
                    if let clip = UIPasteboard.general.string { importText = clip }
                } label: {
                    Label("Paste", systemImage: "doc.on.clipboard").font(.caption)
                }
                .buttonStyle(.bordered).controlSize(.small)
                Spacer()
                Button {
                    _ = urlService.bulkImportURLs(importText, forIgnition: viewingIgnition)
                    importText = ""
                    withAnimation(.snappy) { showImportBox = false }
                } label: {
                    Label("Import", systemImage: "arrow.down.doc.fill").font(.caption.bold())
                }
                .buttonStyle(.borderedProminent)
                .tint(accentColor)
                .disabled(importText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private var actionButtons: some View {
        Group {
            Button {
                withAnimation(.snappy) { showImportBox.toggle() }
            } label: {
                Label(showImportBox ? "Hide Bulk Import" : "Bulk Import URLs", systemImage: "plus.circle.fill")
            }

            Button {
                urlService.enableAllURLs()
            } label: {
                Label("Re-enable All URLs", systemImage: "arrow.counterclockwise")
            }

            Button {
                urlService.resetPerformanceStats()
            } label: {
                Label("Reset Stats", systemImage: "chart.bar.xaxis")
            }

            Button {
                urlService.resetToDefaults(forIgnition: viewingIgnition)
            } label: {
                Label("Reset to Defaults", systemImage: "arrow.uturn.backward")
            }

            let urlList = viewingIgnition ? urlService.ignitionURLs : urlService.joeURLs
            if !urlList.isEmpty {
                Button(role: .destructive) {
                    showDeleteAllConfirm = true
                } label: {
                    Label("Delete All \(viewingIgnition ? "Ignition" : "JoePoint") URLs", systemImage: "trash")
                }
                .confirmationDialog(
                    "Delete all \(viewingIgnition ? "Ignition" : "JoePoint") URLs?",
                    isPresented: $showDeleteAllConfirm,
                    titleVisibility: .visible
                ) {
                    Button("Delete All", role: .destructive) {
                        urlService.deleteAllURLs(forIgnition: viewingIgnition)
                    }
                    Button("Cancel", role: .cancel) {}
                }
            }
        }
    }

    private func commitAddURL() {
        let trimmed = addURLText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let success = urlService.addURL(trimmed, forIgnition: viewingIgnition)
        if success {
            addURLText = ""
            addURLError = false
        } else {
            withAnimation(.spring(duration: 0.3)) { addURLError = true }
            Task { @MainActor in try? await Task.sleep(for: .seconds(2)); withAnimation { addURLError = false } }
        }
    }
}
