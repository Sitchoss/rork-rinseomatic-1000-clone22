import SwiftUI

struct RuntimeSafetyPanelView: View {
    @State private var safety = RuntimeSafetyCenter.shared

    let compact: Bool

    var body: some View {
        Group {
            if safety.hasVisibleState {
                VStack(alignment: .leading, spacing: compact ? 8 : 12) {
                    headerRow

                    if compact {
                        compactMetrics
                    } else {
                        expandedMetrics
                    }

                    if let message = safety.latestStatusMessage, !message.isEmpty {
                        Text(message)
                            .font(compact ? .caption2 : .caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(compact ? 10 : 12)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(.rect(cornerRadius: compact ? 10 : 14))
            }
        }
    }

    private var headerRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: compact ? 12 : 14, weight: .semibold))
                .foregroundStyle(.blue)

            Text("Runtime Safety")
                .font(compact ? .caption.bold() : .subheadline.bold())

            Spacer()

            Text(safety.backgroundPauseActive ? "Resume Needed" : "Tracked")
                .font(.system(compact ? .caption2 : .caption, design: .monospaced, weight: .bold))
                .foregroundStyle(safety.backgroundPauseActive ? .orange : .secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background((safety.backgroundPauseActive ? Color.orange : Color.secondary).opacity(0.12))
                .clipShape(Capsule())
        }
    }

    private var compactMetrics: some View {
        HStack(spacing: 8) {
            metricChip(icon: "square.and.arrow.down", title: "Saved", value: safety.lastSafeSaveAt?.formatted(.relative(presentation: .named)) ?? "—", color: .blue)
            metricChip(icon: "arrow.triangle.branch", title: "Focus", value: "\(safety.focusRecoveryCount)", color: .orange)
            metricChip(icon: "checkmark.shield", title: "Consent", value: "\(safety.consentCleanupCount)", color: .green)
        }
    }

    private var expandedMetrics: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                metricCard(icon: "square.and.arrow.down", title: "Last Safe Save", value: safety.lastSafeSaveAt?.formatted(.relative(presentation: .named)) ?? "—", color: .blue)
                metricCard(icon: "pause.circle", title: "Background State", value: safety.backgroundPauseActive ? "Paused" : "Saved", color: safety.backgroundPauseActive ? .orange : .secondary)
            }

            HStack(spacing: 8) {
                metricCard(icon: "arrow.triangle.branch", title: "Focus Recovery", value: "\(safety.focusRecoveryCount)", color: .orange)
                metricCard(icon: "checkmark.shield", title: "Consent Cleanup", value: "\(safety.consentCleanupCount)", color: .green)
            }
        }
    }

    private func metricChip(icon: String, title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                Text(title)
                    .font(.caption2)
            }
            .foregroundStyle(color)

            Text(value)
                .font(.system(.caption, design: .monospaced, weight: .bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(color.opacity(0.08))
        .clipShape(.rect(cornerRadius: 8))
    }

    private func metricCard(icon: String, title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(title)
                    .font(.caption)
            }
            .foregroundStyle(color)

            Text(value)
                .font(.system(.body, design: .monospaced, weight: .bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(color.opacity(0.08))
        .clipShape(.rect(cornerRadius: 10))
    }
}
