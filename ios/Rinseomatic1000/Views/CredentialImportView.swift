import SwiftUI
import UIKit

struct CredentialImportView: View {
    let vm: LoginViewModel
    @State private var importText: String = ""
    @State private var lastImportSummary: String?

    private var lineCount: Int {
        importText
            .components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                heroCard
                formatsCard
                importEditorCard
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Import")
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "square.and.arrow.down.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Import Credentials")
                        .font(.headline)
                    Text("Paste or import login lines and send them straight into the credential hub.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            HStack(spacing: 12) {
                statPill(title: "Saved", value: "\(vm.credentials.count)")
                statPill(title: "Working", value: "\(vm.workingCredentials.count)")
                statPill(title: "No Acc", value: "\(vm.noAccCredentials.count)")
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 18))
    }

    private var formatsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Accepted Formats")
                .font(.subheadline.bold())

            HStack(spacing: 8) {
                formatChip("user:pass")
                formatChip("user;pass")
                formatChip("user,pass")
            }

            Text("One credential per line. Smart import will normalize common separators automatically.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 18))
    }

    private var importEditorCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Paste Area")
                    .font(.subheadline.bold())
                Spacer()
                if let lastImportSummary {
                    Text(lastImportSummary)
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                }
            }

            TextEditor(text: $importText)
                .font(.system(.callout, design: .monospaced))
                .frame(minHeight: 200)
                .padding(12)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(.rect(cornerRadius: 14))
                .overlay(alignment: .topLeading) {
                    if importText.isEmpty {
                        Text("Paste credentials here…\n\nexample@email.com:password")
                            .font(.system(.callout, design: .monospaced))
                            .foregroundStyle(.quaternary)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 20)
                            .allowsHitTesting(false)
                    }
                }

            HStack {
                Text("\(lineCount) line\(lineCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    if let clipboard = UIPasteboard.general.string, !clipboard.isEmpty {
                        importText = clipboard
                    }
                } label: {
                    Label("Paste", systemImage: "doc.on.clipboard")
                }
                .buttonStyle(.bordered)

                Button {
                    let before = vm.credentials.count
                    vm.smartImportCredentials(importText)
                    let added = vm.credentials.count - before
                    lastImportSummary = "\(added) added"
                    importText = ""
                } label: {
                    Label("Import", systemImage: "arrow.down.doc.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(importText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 18))
    }

    private func statPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(.headline, design: .monospaced, weight: .bold))
                .foregroundStyle(.green)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.green.opacity(0.08))
        .clipShape(.rect(cornerRadius: 12))
    }

    private func formatChip(_ text: String) -> some View {
        Text(text)
            .font(.system(.caption, design: .monospaced, weight: .bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(Capsule())
    }
}
