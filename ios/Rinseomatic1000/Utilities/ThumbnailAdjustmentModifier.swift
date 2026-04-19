import SwiftUI
import Observation

nonisolated struct ThumbnailAdjustment: Codable, Sendable {
    let scale: Double
    let offsetX: Double
    let offsetY: Double

    static let identity = ThumbnailAdjustment(scale: 1, offsetX: 0, offsetY: 0)
}

@Observable
@MainActor
final class ThumbnailAdjustmentStore {
    static let shared = ThumbnailAdjustmentStore()

    var adjustments: [String: ThumbnailAdjustment] = [:]

    private let defaultsKey: String = "thumbnail_adjustments_v1"

    private init() {
        load()
    }

    func adjustment(for url: String?, viewport: CGSize) -> ThumbnailAdjustment {
        guard let key = storageKey(for: url, viewport: viewport) else { return .identity }
        return adjustments[key] ?? .identity
    }

    func setAdjustment(_ adjustment: ThumbnailAdjustment, for url: String?, viewport: CGSize) {
        guard let key = storageKey(for: url, viewport: viewport) else { return }
        adjustments[key] = adjustment
        persist()
    }

    func resetAdjustment(for url: String?, viewport: CGSize) {
        guard let key = storageKey(for: url, viewport: viewport) else { return }
        adjustments.removeValue(forKey: key)
        persist()
    }

    private func storageKey(for url: String?, viewport: CGSize) -> String? {
        guard let normalized = url?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !normalized.isEmpty else {
            return nil
        }
        return normalized
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([String: ThumbnailAdjustment].self, from: data) else {
            adjustments = [:]
            return
        }
        adjustments = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(adjustments) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }
}

struct ThumbnailAdjustmentModifier: ViewModifier {
    let url: String?
    let viewport: CGSize
    @State private var store = ThumbnailAdjustmentStore.shared

    func body(content: Content) -> some View {
        let adjustment = store.adjustment(for: url, viewport: viewport)
        content
            .scaleEffect(adjustment.scale)
            .offset(
                x: CGFloat(adjustment.offsetX) * viewport.width,
                y: CGFloat(adjustment.offsetY) * viewport.height
            )
            .clipped()
    }
}

extension View {
    func withThumbnailAdjustment(for url: String?, viewport: CGSize) -> some View {
        modifier(ThumbnailAdjustmentModifier(url: url, viewport: viewport))
    }
}

struct ThumbnailAdjustmentEditorView: View {
    let url: String
    let title: String
    @Environment(\.dismiss) private var dismiss
    @State private var store = ThumbnailAdjustmentStore.shared
    @State private var scale: Double
    @State private var offsetX: Double
    @State private var offsetY: Double

    init(url: String, title: String, viewport: CGSize = .zero) {
        self.url = url
        self.title = title
        let saved = ThumbnailAdjustmentStore.shared.adjustment(for: url, viewport: viewport)
        _scale = State(initialValue: saved.scale)
        _offsetX = State(initialValue: saved.offsetX)
        _offsetY = State(initialValue: saved.offsetY)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Target") {
                        Text(title)
                            .font(.system(.caption, design: .monospaced, weight: .bold))
                    }
                }

                Section("Scale") {
                    Slider(value: $scale, in: 0.7...1.5, step: 0.01)
                    Text(scale.formatted(.number.precision(.fractionLength(2))))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                Section("Horizontal Offset") {
                    Slider(value: $offsetX, in: -0.4...0.4, step: 0.01)
                    Text(offsetX.formatted(.number.precision(.fractionLength(2))))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                Section("Vertical Offset") {
                    Slider(value: $offsetY, in: -0.4...0.4, step: 0.01)
                    Text(offsetY.formatted(.number.precision(.fractionLength(2))))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button("Reset", role: .destructive) {
                        store.resetAdjustment(for: url, viewport: .zero)
                        scale = 1
                        offsetX = 0
                        offsetY = 0
                    }
                }
            }
            .navigationTitle("Thumbnail Adjust")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.setAdjustment(
                            ThumbnailAdjustment(scale: scale, offsetX: offsetX, offsetY: offsetY),
                            for: url,
                            viewport: .zero
                        )
                        dismiss()
                    }
                    .bold()
                }
            }
        }
    }
}
