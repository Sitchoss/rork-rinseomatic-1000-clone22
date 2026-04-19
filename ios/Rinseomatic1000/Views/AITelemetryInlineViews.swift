import SwiftUI

struct AIReasonChip: View {
    let diagnosis: AITelemetryDiagnosis
    @State private var expanded: Bool = false

    var body: some View {
        Button {
            withAnimation(.spring(duration: 0.25)) { expanded.toggle() }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.purple)
                    Text(diagnosis.summary)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(expanded ? nil : 1)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.purple.opacity(0.6))
                }
                if expanded, !diagnosis.suggestion.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.yellow.opacity(0.8))
                        Text(diagnosis.suggestion)
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.6))
                            .multilineTextAlignment(.leading)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(.purple.opacity(0.1))
            .clipShape(.rect(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(.purple.opacity(0.25), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

struct AIStealthDot: View {
    let score: AISessionStealthScore

    var body: some View {
        HStack(spacing: 3) {
            Circle()
                .fill(score.tier.color)
                .frame(width: 6, height: 6)
            Text("\(score.score)")
                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                .foregroundStyle(score.tier.color)
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(score.tier.color.opacity(0.12))
        .clipShape(Capsule())
    }
}

struct AIBatchSummaryCard: View {
    let summary: AIBatchSummary
    @State private var expanded: Bool = false

    var body: some View {
        Button {
            withAnimation(.spring(duration: 0.3)) { expanded.toggle() }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.purple)
                        .symbolEffect(.pulse, options: .nonRepeating)
                    Text("AI Summary")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(.purple)
                    Spacer()
                    Text("\(summary.successes)/\(summary.total)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.4))
                }

                Text(summary.headline)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(expanded ? nil : 2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if expanded {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(summary.bullets, id: \.self) { bullet in
                            HStack(alignment: .top, spacing: 6) {
                                Circle()
                                    .fill(.purple.opacity(0.5))
                                    .frame(width: 3, height: 3)
                                    .padding(.top, 5)
                                Text(bullet)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.white.opacity(0.7))
                                    .multilineTextAlignment(.leading)
                            }
                        }
                    }
                }
            }
            .padding(12)
            .background(
                LinearGradient(
                    colors: [.purple.opacity(0.18), .blue.opacity(0.08)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(.rect(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(.purple.opacity(0.3), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

struct AILowStealthBanner: View {
    let score: AISessionStealthScore

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.shield.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 1) {
                Text("Low Stealth · \(score.score)/100")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.orange)
                Text(score.reason)
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.orange.opacity(0.12))
        .clipShape(.rect(cornerRadius: 8))
    }
}
