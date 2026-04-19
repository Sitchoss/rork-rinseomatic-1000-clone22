import SwiftUI
import WidgetKit

struct SitchomaticWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family

    let entry: SitchomaticWidgetEntry

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                smallLayout
            case .systemMedium:
                mediumLayout
            default:
                mediumLayout
            }
        }
        .containerBackground(for: .widget) {
            ZStack {
                LinearGradient(
                    colors: [Color.black.opacity(0.94), accentColor.opacity(0.38)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                LinearGradient(
                    colors: [.clear, accentColor.opacity(0.20), Color.black.opacity(0.36)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
    }

    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                iconBadge
                Spacer(minLength: 8)
                Text("READY")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .foregroundStyle(accentColor)
            }

            Spacer(minLength: 0)

            Text(entry.headline)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(2)

            Text(entry.subheadline)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.78))
                .lineLimit(2)
        }
        .padding(14)
    }

    private var mediumLayout: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    iconBadge
                    Text("COMMAND CENTER")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .foregroundStyle(accentColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.headline)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(entry.subheadline)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.82))
                        .lineLimit(1)
                    Text(entry.detail)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.62))
                        .lineLimit(1)
                }

                HStack(spacing: 6) {
                    Label("Open app", systemImage: "arrow.up.forward.app.fill")
                    Text(entry.date, style: .time)
                }
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.72))
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 12) {
                Image(systemName: entry.symbolName)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(accentColor)
                    .shadow(color: accentColor.opacity(0.45), radius: 8)

                Text("READY")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(accentColor.opacity(0.24))
                    .clipShape(Capsule())
            }
        }
        .padding(16)
    }

    private var iconBadge: some View {
        ZStack {
            Circle()
                .fill(accentColor.opacity(0.22))
                .frame(width: 28, height: 28)
            Image(systemName: entry.symbolName)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(accentColor)
        }
    }

    private var accentColor: Color {
        switch entry.accent {
        case .blue:
            Color(red: 0.22, green: 0.72, blue: 1.0)
        case .teal:
            .teal
        case .orange:
            .orange
        case .green:
            .green
        }
    }
}
