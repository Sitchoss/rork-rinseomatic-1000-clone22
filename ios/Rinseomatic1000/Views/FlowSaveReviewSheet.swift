import SwiftUI

struct FlowSaveReviewSheet: View {
    let flowName: String
    let review: FlowSaveReview
    let onConfirm: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(flowName)
                            .font(.title3.weight(.semibold))
                        Text(review.summaryText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                if !review.validationErrors.isEmpty {
                    Section("Validation") {
                        ForEach(review.validationErrors, id: \.self) { error in
                            Label(error, systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                        }
                    }
                }

                Section("Change Summary") {
                    ForEach(review.changeItems) { item in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: item.icon)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(tintColor(item.tint))
                                .frame(width: 20)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.title)
                                    .font(.subheadline.weight(.semibold))
                                Text(item.detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }

                Section {
                    Button {
                        onConfirm()
                        dismiss()
                    } label: {
                        Label("Commit Save", systemImage: "square.and.arrow.down.fill")
                            .frame(maxWidth: .infinity)
                            .fontWeight(.semibold)
                    }
                    .disabled(!review.isValid)
                }
            }
            .navigationTitle(review.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func tintColor(_ name: String) -> Color {
        switch name {
        case "green":
            return .green
        case "blue":
            return .blue
        case "cyan":
            return .cyan
        case "purple":
            return .purple
        case "indigo":
            return .indigo
        case "teal":
            return .teal
        case "orange":
            return .orange
        case "mint":
            return .mint
        default:
            return .secondary
        }
    }
}
