import SwiftUI
import UIKit

struct UnifiedScreenshotFeedView: View {
    @State private var manager = UnifiedScreenshotManager.shared
    @State private var foundationStore = AutomationFoundationStore.shared
    @State private var selectedScreenshot: UnifiedScreenshot?
    @State private var selectedAlbum: UnifiedScreenshotAlbum?
    @State private var filterOption: ScreenshotFilterOption = .all
    @State private var showStats: Bool = false
    @State private var showClearConfirm: Bool = false
    @State private var showFullImage: Bool = false
    @State private var feedDensity: ScreenshotFeedDensity = .twoUp
    @State private var showFlipbook: Bool = false
    @State private var flipbookScreenshots: [UnifiedScreenshot] = []
    @State private var flipbookStartIndex: Int = 0

    nonisolated enum ScreenshotFeedDensity: String, CaseIterable, Identifiable, Sendable {
        case focus = "Focus"
        case twoUp = "2-Up"
        case compact = "Compact"

        var id: String { rawValue }

        var columns: [GridItem] {
            switch self {
            case .focus:
                [GridItem(.flexible())]
            case .twoUp:
                [GridItem(.flexible()), GridItem(.flexible())]
            case .compact:
                [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
            }
        }

        var tileHeight: CGFloat {
            switch self {
            case .focus: return 220
            case .twoUp: return 168
            case .compact: return 122
            }
        }

        var icon: String {
            switch self {
            case .focus: "rectangle"
            case .twoUp: "square.grid.2x2"
            case .compact: "square.grid.3x2"
            }
        }
    }

    nonisolated enum ScreenshotFilterOption: String, CaseIterable, Identifiable, Sendable {
        case all = "All"
        case crucial = "Crucial"
        case success = "Success"
        case permDisabled = "Perm"
        case tempDisabled = "Temp"
        case incorrect = "Incorrect"
        case unknown = "Unknown"
        var id: String { rawValue }

        var color: Color {
            switch self {
            case .all: .primary
            case .crucial: .yellow
            case .success: .green
            case .permDisabled: .red
            case .tempDisabled: .orange
            case .incorrect: .secondary
            case .unknown: .gray
            }
        }

        var icon: String {
            switch self {
            case .all: "photo.stack"
            case .crucial: "exclamationmark.triangle.fill"
            case .success: "checkmark.circle.fill"
            case .permDisabled: "lock.slash.fill"
            case .tempDisabled: "clock.badge.exclamationmark"
            case .incorrect: "xmark.circle.fill"
            case .unknown: "questionmark.circle"
            }
        }
    }

    private var filteredScreenshots: [UnifiedScreenshot] {
        switch filterOption {
        case .all: manager.screenshots
        case .crucial: manager.crucialScreenshots()
        case .success: manager.screenshots.filter { $0.detectedOutcome == .success }
        case .permDisabled: manager.screenshots.filter { $0.detectedOutcome == .permDisabled }
        case .tempDisabled: manager.screenshots.filter { $0.detectedOutcome == .tempDisabled }
        case .incorrect: manager.screenshots.filter { $0.detectedOutcome == .incorrectPassword || $0.detectedOutcome == .noAccount }
        case .unknown: manager.screenshots.filter { $0.detectedOutcome == .unknown }
        }
    }

    private var albums: [UnifiedScreenshotAlbum] {
        let validScreenshots = filteredScreenshots.filter { !$0.credentialEmail.isEmpty }
        let grouped = Dictionary(grouping: validScreenshots) { $0.credentialEmail }
        var result = grouped.map { email, shots in
            UnifiedScreenshotAlbum(
                credentialEmail: email,
                screenshots: shots.sorted { $0.timestamp > $1.timestamp }
            )
        }.sorted { $0.latestTimestamp > $1.latestTimestamp }

        // Include screenshots without a credential email in an "Uncategorized" album
        let uncategorized = filteredScreenshots.filter { $0.credentialEmail.isEmpty }
        if !uncategorized.isEmpty {
            result.append(UnifiedScreenshotAlbum(
                credentialEmail: "Uncategorized",
                screenshots: uncategorized.sorted { $0.timestamp > $1.timestamp }
            ))
        }

        // Sort the entire result array by latest timestamp to ensure uncategorized participates in recency sort
        return result.sorted { $0.latestTimestamp > $1.latestTimestamp }
    }

    private func countFor(_ option: ScreenshotFilterOption) -> Int {
        switch option {
        case .all: manager.screenshots.count
        case .crucial: manager.crucialScreenshots().count
        case .success: manager.screenshots.filter { $0.detectedOutcome == .success }.count
        case .permDisabled: manager.screenshots.filter { $0.detectedOutcome == .permDisabled }.count
        case .tempDisabled: manager.screenshots.filter { $0.detectedOutcome == .tempDisabled }.count
        case .incorrect: manager.screenshots.filter { $0.detectedOutcome == .incorrectPassword || $0.detectedOutcome == .noAccount }.count
        case .unknown: manager.screenshots.filter { $0.detectedOutcome == .unknown }.count
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if !manager.screenshots.isEmpty {
                filterBar
            }

            storageHealthCard

            if showStats {
                analysisStatsCard
            }

            ScrollView {
                if manager.screenshots.isEmpty {
                    emptyState
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                        .padding(.bottom, 24)
                } else if filteredScreenshots.isEmpty {
                    noMatchesState
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                        .padding(.bottom, 24)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(albums) { album in
                            Button { selectedAlbum = album } label: {
                                UnifiedAlbumCard(album: album)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .padding(.bottom, 24)
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Menu("Feed Density") {
                        ForEach(ScreenshotFeedDensity.allCases) { density in
                            Button {
                                withAnimation(.spring(duration: 0.25)) {
                                    feedDensity = density
                                }
                            } label: {
                                Label(density.rawValue, systemImage: density.icon)
                            }
                        }
                    }
                    Button { withAnimation(.snappy) { showStats.toggle() } } label: {
                        Label(showStats ? "Hide AI Stats" : "Show AI Stats", systemImage: "cpu")
                    }
                    if !manager.screenshots.isEmpty {
                        Button(role: .destructive) { showClearConfirm = true } label: {
                            Label("Clear All Screenshots", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "camera.viewfinder")
                        .symbolEffect(.pulse, isActive: !manager.screenshots.isEmpty)
                }
            }
        }
        .sheet(item: $selectedAlbum) { album in
            UnifiedAlbumDetailSheet(album: album, showFullImage: $showFullImage, onOpenFlipbook: { screenshots, index in
                flipbookScreenshots = screenshots
                flipbookStartIndex = index
                showFlipbook = true
            })
        }
        .sheet(item: $selectedScreenshot) { screenshot in
            ScreenshotDetailSheet(screenshot: screenshot, showFullImage: $showFullImage)
        }
        .fullScreenCover(isPresented: $showFlipbook) {
            UnifiedScreenshotFlipbookView(screenshots: flipbookScreenshots, startIndex: flipbookStartIndex)
        }
        .alert("Clear All Screenshots?", isPresented: $showClearConfirm) {
            Button("Clear All", role: .destructive) { manager.clearAll() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove all \(manager.screenshots.count) screenshot(s). This cannot be undone.")
        }
        .onAppear {
            foundationStore.refreshStorageHealth(currentSessionScreenshotCount: manager.screenshots.count)
        }
    }

    private var storageHealthCard: some View {
        let health = foundationStore.storageHealth
        return VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Foundation Storage")
                        .font(.subheadline.bold())
                    Text("Release 1 screenshot density, dedupe, and retention")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 6) {
                    ForEach(ScreenshotFeedDensity.allCases) { density in
                        Button {
                            withAnimation(.spring(duration: 0.25)) {
                                feedDensity = density
                            }
                        } label: {
                            Image(systemName: density.icon)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(feedDensity == density ? .white : .secondary)
                                .frame(width: 30, height: 30)
                                .background(feedDensity == density ? Color.blue : Color(.tertiarySystemGroupedBackground))
                                .clipShape(.circle)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack(spacing: 8) {
                AIStatPill(value: "\(health.currentSessionScreenshotCount)", label: "Live", color: .blue)
                AIStatPill(value: "\(health.screenshotHistoryCount)", label: "Retained", color: .indigo)
                AIStatPill(value: "\(health.deduplicatedScreenshotCount)", label: "Deduped", color: .purple)
                AIStatPill(value: "\(health.screenshotRetentionLimit)", label: "Limit", color: .orange)
            }

            HStack(spacing: 12) {
                metadataHealthRow(icon: "clock.arrow.circlepath", title: "Last Shot", value: health.lastScreenshotAt?.formatted(.relative(presentation: .named)) ?? "—")
                metadataHealthRow(icon: "waveform.path.ecg", title: "Last Log", value: health.lastTelemetryAt?.formatted(.relative(presentation: .named)) ?? "—")
                Spacer()
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 14))
        .padding(.horizontal)
        .padding(.top, 10)
    }

    private func metadataHealthRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 8, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.tertiary)
                Text(value)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(ScreenshotFilterOption.allCases) { option in
                    let count = countFor(option)
                    let isSelected = filterOption == option
                    Button {
                        withAnimation(.spring(duration: 0.25)) { filterOption = option }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: option.icon)
                                .font(.system(size: 9, weight: .bold))
                            Text(option.rawValue)
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                            if count > 0 {
                                Text("\(count)")
                                    .font(.system(size: 8, weight: .heavy, design: .monospaced))
                                    .padding(.horizontal, 4).padding(.vertical, 1)
                                    .background(isSelected ? .white.opacity(0.2) : .primary.opacity(0.08))
                                    .clipShape(Capsule())
                            }
                        }
                        .foregroundStyle(isSelected ? .white : .secondary)
                        .padding(.horizontal, 9).padding(.vertical, 5)
                        .background(isSelected ? option.color.opacity(0.75) : Color(.tertiarySystemGroupedBackground))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
        }
        .sensoryFeedback(.selection, trigger: filterOption)
    }

    private var analysisStatsCard: some View {
        let stats = manager.analysisStats
        return VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "cpu")
                    .font(.subheadline)
                    .foregroundStyle(.indigo)
                Text("Vision AI Analysis")
                    .font(.caption.bold())
                Spacer()
                Button { withAnimation(.snappy) { showStats = false } } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption).foregroundStyle(.tertiary)
                }
            }

            HStack(spacing: 6) {
                AIStatPill(value: "\(stats.totalCaptured)", label: "Captured", color: .blue)
                AIStatPill(value: "\(stats.totalAnalyzed)", label: "Analyzed", color: .indigo)
                AIStatPill(value: "\(stats.duplicatesSkipped)", label: "Deduped", color: .purple)
                AIStatPill(value: "\(stats.crucialDetections)", label: "Crucial", color: .yellow)
                AIStatPill(value: "\(stats.smartCrops)", label: "Cropped", color: .green)
            }

            if !stats.outcomeBreakdown.isEmpty {
                HStack(spacing: 4) {
                    ForEach(stats.outcomeBreakdown.sorted(by: { $0.value > $1.value }), id: \.key) { key, value in
                        HStack(spacing: 2) {
                            Circle()
                                .fill(outcomeColor(key))
                                .frame(width: 5, height: 5)
                            Text("\(key):\(value)")
                                .font(.system(size: 8, weight: .medium, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 12))
        .padding(.horizontal)
        .padding(.top, 4)
    }

    private func outcomeColor(_ key: String) -> Color {
        switch key {
        case "success": .green
        case "permDisabled": .red
        case "tempDisabled": .orange
        case "incorrectPassword": .secondary
        case "smsVerification": .purple
        case "errorBanner": .red
        default: .gray
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 48))
                .foregroundStyle(.secondary.opacity(0.4))
                .symbolEffect(.pulse.byLayer, options: .repeating)
            Text("No Screenshots Yet")
                .font(.title3.bold())
            Text("Screenshots are captured automatically\nduring login testing with AI Vision analysis.\nCrucial response text is detected and cropped.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private var noMatchesState: some View {
        VStack(spacing: 12) {
            Image(systemName: filterOption.icon)
                .font(.system(size: 36))
                .foregroundStyle(filterOption.color.opacity(0.4))
            Text("No \(filterOption.rawValue) Screenshots")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

struct ScreenshotTile: View {
    let screenshot: UnifiedScreenshot
    let imageHeight: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            Color(.secondarySystemBackground)
                .frame(height: imageHeight)
                .overlay {
                    Image(uiImage: screenshot.displayImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .withThumbnailAdjustment(for: screenshot.site, viewport: CGSize(width: 320, height: 160))
                        .allowsHitTesting(false)
                }
                .clipShape(.rect(cornerRadii: .init(topLeading: 12, topTrailing: 12)))
                .overlay(alignment: .topLeading) {
                    HStack(spacing: 4) {
                        Image(systemName: screenshot.site == "joe" ? "suit.spade.fill" : "flame.fill")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(screenshot.site == "joe" ? .green : .orange)
                        Text(screenshot.site.uppercased())
                            .font(.system(size: 8, weight: .heavy, design: .monospaced))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(.black.opacity(0.65))
                    .clipShape(Capsule())
                    .padding(8)
                }
                .overlay(alignment: .topTrailing) {
                    outcomeBadge.padding(8)
                }
                .overlay(alignment: .bottomLeading) {
                    HStack(spacing: 5) {
                        Image(systemName: screenshot.step.icon)
                            .font(.system(size: 8))
                        Text(screenshot.step.displayName)
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                        if screenshot.hasCrop {
                            Image(systemName: "crop")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundStyle(.green)
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(.black.opacity(0.6))
                    .clipShape(Capsule())
                    .padding(8)
                }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(screenshot.credentialEmail)
                        .font(.system(.caption, design: .monospaced, weight: .semibold))
                        .lineLimit(1)
                    Spacer()
                    Text(screenshot.formattedTime)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }

                HStack(spacing: 8) {
                    if screenshot.attemptNumber > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "number").font(.system(size: 8))
                            Text("\(screenshot.attemptNumber)")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                        }
                        .foregroundStyle(.secondary)
                    }

                    if screenshot.isCrucial {
                        HStack(spacing: 2) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 8))
                            Text("CRUCIAL")
                                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                        }
                        .foregroundStyle(.yellow)
                    }

                    if screenshot.visionConfidence > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "cpu").font(.system(size: 8))
                            Text("\(Int(screenshot.visionConfidence * 100))%")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                        }
                        .foregroundStyle(.indigo)
                    }

                    if screenshot.analysisTimeMs > 0 {
                        Text("\(screenshot.analysisTimeMs)ms")
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .foregroundStyle(.quaternary)
                    }

                    Spacer()
                }

                if !screenshot.crucialKeywords.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(screenshot.crucialKeywords, id: \.self) { keyword in
                                Text(keyword)
                                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(screenshot.outcomeColor.opacity(0.75))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
            }
            .padding(10)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(screenshot.isCrucial ? screenshot.outcomeColor.opacity(0.4) : .clear, lineWidth: 1.5)
        )
    }

    private var outcomeBadge: some View {
        Text(screenshot.outcomeLabel)
            .font(.system(size: 8, weight: .heavy, design: .monospaced))
            .foregroundStyle(.white)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(screenshot.outcomeColor.opacity(0.85))
            .clipShape(Capsule())
    }
}

struct ScreenshotDetailSheet: View {
    let screenshot: UnifiedScreenshot
    @Binding var showFullImage: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var showAdjustmentEditor: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    imageSection
                    metadataCard
                    if !screenshot.crucialKeywords.isEmpty {
                        crucialKeywordsCard
                    }
                    if !screenshot.allDetectedText.isEmpty {
                        ocrTextCard
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Screenshot Detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !screenshot.site.isEmpty {
                        Button {
                            showAdjustmentEditor = true
                        } label: {
                            Image(systemName: "crop")
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showAdjustmentEditor) {
            ThumbnailAdjustmentEditorView(url: screenshot.site, title: screenshot.siteLabel)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationContentInteraction(.scrolls)
    }

    private var imageSection: some View {
        VStack(spacing: 8) {
            if screenshot.hasCrop {
                Picker("View", selection: $showFullImage) {
                    Text("AI Crop").tag(false)
                    Text("Full Page").tag(true)
                }
                .pickerStyle(.segmented)
            }

            let displayImage = showFullImage ? screenshot.fullImage : screenshot.displayImage
            Image(uiImage: displayImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .withThumbnailAdjustment(for: screenshot.site, viewport: CGSize(width: 390, height: 640))
                .clipShape(.rect(cornerRadius: 10))
                .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
        }
    }

    private var metadataCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: screenshot.site == "joe" ? "suit.spade.fill" : "flame.fill")
                    .foregroundStyle(screenshot.site == "joe" ? .green : .orange)
                Text(screenshot.site == "joe" ? "JoePoint" : "Ignition Lite")
                    .font(.headline)
                Spacer()
                Text(screenshot.outcomeLabel)
                    .font(.system(.caption2, design: .monospaced, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(screenshot.outcomeColor)
                    .clipShape(Capsule())
            }

            VStack(spacing: 6) {
                metadataRow(icon: "person.fill", label: "Email", value: screenshot.credentialEmail)
                metadataRow(icon: "number", label: "Attempt", value: "\(screenshot.attemptNumber)")
                metadataRow(icon: screenshot.step.icon, label: "Step", value: screenshot.step.displayName)
                metadataRow(icon: "clock", label: "Time", value: screenshot.formattedTime)
                if screenshot.visionConfidence > 0 {
                    metadataRow(icon: "cpu", label: "AI Confidence", value: "\(Int(screenshot.visionConfidence * 100))%")
                }
                if screenshot.analysisTimeMs > 0 {
                    metadataRow(icon: "gauge.with.needle", label: "Analysis Time", value: "\(screenshot.analysisTimeMs)ms")
                }
                if screenshot.hasCrop {
                    metadataRow(icon: "crop", label: "Smart Crop", value: "Active — cropped to response text")
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 12))
    }

    private func metadataRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .frame(width: 16)
            Text(label)
                .font(.system(.caption, design: .monospaced, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .leading)
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.primary)
                .lineLimit(1)
            Spacer()
        }
    }

    private var crucialKeywordsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                Text("Crucial Keywords Detected")
                    .font(.caption.bold())
                Spacer()
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 6) {
                ForEach(screenshot.crucialKeywords, id: \.self) { keyword in
                    Text(keyword)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .frame(maxWidth: .infinity)
                        .background(screenshot.outcomeColor.opacity(0.7))
                        .clipShape(.rect(cornerRadius: 6))
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 12))
    }

    private var ocrTextCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "text.magnifyingglass")
                    .foregroundStyle(.indigo)
                Text("Full OCR Text")
                    .font(.caption.bold())
                Spacer()
                Button {
                    UIPasteboard.general.string = screenshot.allDetectedText
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }

            Text(screenshot.allDetectedText)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(20)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 12))
    }
}

struct AIStatPill: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.caption, design: .monospaced, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 7, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(color.opacity(0.08))
        .clipShape(.rect(cornerRadius: 6))
    }
}

// MARK: - Unified Screenshot Album

struct UnifiedScreenshotAlbum: Identifiable {
    let credentialEmail: String
    let screenshots: [UnifiedScreenshot]

    var id: String { credentialEmail }

    var latestTimestamp: Date {
        screenshots.first?.timestamp ?? .distantPast
    }

    var joeScreenshots: [UnifiedScreenshot] {
        screenshots.filter { $0.site.lowercased().contains("joe") }
    }

    var ignitionScreenshots: [UnifiedScreenshot] {
        screenshots.filter { $0.site.lowercased().contains("ign") }
    }

    var hasBothSites: Bool {
        !joeScreenshots.isEmpty && !ignitionScreenshots.isEmpty
    }

    var joeResult: String {
        let terminal = joeScreenshots.first(where: { $0.detectedOutcome != .unknown })
        return terminal?.outcomeLabel ?? "PENDING"
    }

    var ignitionResult: String {
        let terminal = ignitionScreenshots.first(where: { $0.detectedOutcome != .unknown })
        return terminal?.outcomeLabel ?? "PENDING"
    }

    var joeResultColor: Color {
        joeScreenshots.first(where: { $0.detectedOutcome != .unknown })?.outcomeColor ?? .gray
    }

    var ignitionResultColor: Color {
        ignitionScreenshots.first(where: { $0.detectedOutcome != .unknown })?.outcomeColor ?? .gray
    }

    var pairedResultText: String {
        if hasBothSites {
            return "\(joeResult) / \(ignitionResult)"
        }
        if !joeScreenshots.isEmpty { return joeResult }
        if !ignitionScreenshots.isEmpty { return ignitionResult }
        return "PENDING"
    }

    var highestPriorityColor: Color {
        let jc = joeScreenshots.first(where: { $0.detectedOutcome != .unknown })
        let ic = ignitionScreenshots.first(where: { $0.detectedOutcome != .unknown })
        if let j = jc, j.detectedOutcome == .success { return .green }
        if let i = ic, i.detectedOutcome == .success { return .green }
        if let j = jc, j.detectedOutcome == .permDisabled { return .red }
        if let i = ic, i.detectedOutcome == .permDisabled { return .red }
        return jc?.outcomeColor ?? ic?.outcomeColor ?? .gray
    }
}

// MARK: - Unified Album Card

struct UnifiedAlbumCard: View {
    let album: UnifiedScreenshotAlbum

    var body: some View {
        VStack(spacing: 0) {
            dualSitePreview

            if album.hasBothSites {
                pairedResultBar
            }

            HStack(spacing: 8) {
                Image(systemName: "person.fill").font(.system(size: 10)).foregroundStyle(.secondary)
                Text(album.credentialEmail)
                    .font(.system(.caption, design: .monospaced, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer()
                Text("\(album.screenshots.count)")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.secondary)
                Image(systemName: "photo.stack").font(.system(size: 10)).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(album.highestPriorityColor.opacity(0.25), lineWidth: 1)
        )
    }

    private var dualSitePreview: some View {
        HStack(spacing: 1) {
            albumSitePreview(
                screenshots: album.joeScreenshots,
                label: "JOE",
                icon: "suit.spade.fill",
                color: .green,
                result: album.joeResult,
                resultColor: album.joeResultColor
            )
            albumSitePreview(
                screenshots: album.ignitionScreenshots,
                label: "IGN",
                icon: "flame.fill",
                color: .orange,
                result: album.ignitionResult,
                resultColor: album.ignitionResultColor
            )
        }
        .frame(height: 130)
        .clipShape(.rect(cornerRadii: .init(topLeading: 12, topTrailing: 12)))
    }

    private func albumSitePreview(screenshots: [UnifiedScreenshot], label: String, icon: String, color: Color, result: String, resultColor: Color) -> some View {
        GeometryReader { geo in
            if let shot = screenshots.first {
                Color.clear
                    .overlay {
                        Image(uiImage: shot.displayImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .allowsHitTesting(false)
                    }
                    .clipped()
                    .overlay(alignment: .top) {
                        HStack(spacing: 3) {
                            Image(systemName: icon).font(.system(size: 7, weight: .bold))
                            Text(label).font(.system(size: 8, weight: .heavy, design: .monospaced))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(color.opacity(0.85)).clipShape(Capsule())
                        .padding(.top, 6)
                    }
                    .overlay(alignment: .bottom) {
                        HStack {
                            Spacer()
                            Text(result)
                                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                                .foregroundStyle(.white)
                            Spacer()
                        }
                        .padding(.vertical, 4)
                        .background(resultColor.opacity(0.85))
                    }
            } else {
                Color(.tertiarySystemGroupedBackground)
                    .overlay {
                        VStack(spacing: 4) {
                            Image(systemName: icon).font(.caption).foregroundStyle(color.opacity(0.4))
                            Text(label).font(.system(size: 8, weight: .heavy, design: .monospaced)).foregroundStyle(.tertiary)
                            Text("—").font(.caption2).foregroundStyle(.quaternary)
                        }
                    }
            }
        }
    }

    private var pairedResultBar: some View {
        HStack(spacing: 0) {
            HStack(spacing: 4) {
                Image(systemName: "suit.spade.fill").font(.system(size: 8)).foregroundStyle(.green)
                Text(album.joeResult)
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .foregroundStyle(album.joeResultColor)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)

            Rectangle().fill(.quaternary).frame(width: 1, height: 16)

            HStack(spacing: 4) {
                Image(systemName: "flame.fill").font(.system(size: 8)).foregroundStyle(.orange)
                Text(album.ignitionResult)
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .foregroundStyle(album.ignitionResultColor)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .background(Color(.tertiarySystemGroupedBackground))
    }
}

// MARK: - Unified Album Detail Sheet

struct UnifiedAlbumDetailSheet: View {
    let album: UnifiedScreenshotAlbum
    @Binding var showFullImage: Bool
    var onOpenFlipbook: ([UnifiedScreenshot], Int) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    albumInfoCard
                    if album.hasBothSites { pairedResultsHeader }
                    screenshotsList
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Album").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }

    private var albumInfoCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "photo.stack.fill").foregroundStyle(album.highestPriorityColor)
                Text("Credential Session").font(.headline)
                Spacer()
                Text(album.pairedResultText)
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(album.highestPriorityColor).clipShape(Capsule())
            }
            HStack(spacing: 6) {
                Image(systemName: "person.fill").font(.caption).foregroundStyle(.secondary)
                Text(album.credentialEmail).font(.system(.caption, design: .monospaced, weight: .semibold))
            }
            HStack(spacing: 12) {
                Text("\(album.screenshots.count) screenshots").font(.caption).foregroundStyle(.tertiary)
                if album.hasBothSites {
                    Text("\(album.joeScreenshots.count) Joe · \(album.ignitionScreenshots.count) Ign")
                        .font(.caption2).foregroundStyle(.tertiary)
                }
            }
        }
        .padding().background(Color(.secondarySystemGroupedBackground)).clipShape(.rect(cornerRadius: 12))
    }

    private var pairedResultsHeader: some View {
        HStack(spacing: 0) {
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "suit.spade.fill").font(.system(size: 10, weight: .bold)).foregroundStyle(.green)
                    Text("JOE FORTUNE").font(.system(size: 9, weight: .heavy, design: .monospaced)).foregroundStyle(.secondary)
                }
                Text(album.joeResult)
                    .font(.system(size: 13, weight: .heavy, design: .monospaced))
                    .foregroundStyle(album.joeResultColor)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(album.joeResultColor.opacity(0.06))

            Rectangle().fill(.quaternary).frame(width: 1)

            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill").font(.system(size: 10, weight: .bold)).foregroundStyle(.orange)
                    Text("IGNITION").font(.system(size: 9, weight: .heavy, design: .monospaced)).foregroundStyle(.secondary)
                }
                Text(album.ignitionResult)
                    .font(.system(size: 13, weight: .heavy, design: .monospaced))
                    .foregroundStyle(album.ignitionResultColor)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(album.ignitionResultColor.opacity(0.06))
        }
        .clipShape(.rect(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.quaternary, lineWidth: 0.5))
    }

    private var screenshotsList: some View {
        LazyVStack(spacing: 12) {
            ForEach(Array(album.screenshots.enumerated()), id: \.element.id) { index, screenshot in
                Button {
                    onOpenFlipbook(album.screenshots, index)
                } label: {
                    UnifiedScreenshotListCard(screenshot: screenshot)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Unified Screenshot List Card

struct UnifiedScreenshotListCard: View {
    let screenshot: UnifiedScreenshot

    var body: some View {
        HStack(spacing: 12) {
            Color.clear
                .frame(width: 70, height: 52)
                .overlay {
                    Image(uiImage: screenshot.displayImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .allowsHitTesting(false)
                }
                .clipShape(.rect(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(screenshot.outcomeColor.opacity(0.3), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: screenshot.siteIcon)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(screenshot.siteColor)
                    Text(screenshot.siteLabel)
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.primary)
                    Text("·")
                        .foregroundStyle(.quaternary)
                    Text(screenshot.step.displayName)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                HStack(spacing: 6) {
                    Text(screenshot.formattedTime)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.tertiary)
                    if screenshot.isCrucial {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.yellow)
                    }
                }
            }

            Spacer()

            Text(screenshot.outcomeLabel)
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .foregroundStyle(.white)
                .padding(.horizontal, 6).padding(.vertical, 3)
                .background(screenshot.outcomeColor.opacity(0.85))
                .clipShape(Capsule())

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.quaternary)
        }
        .padding(10)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 12))
    }
}