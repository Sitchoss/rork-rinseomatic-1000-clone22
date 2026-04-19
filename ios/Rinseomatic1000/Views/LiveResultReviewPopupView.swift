import SwiftUI
import UIKit

struct LiveResultReviewPopupView: View {
    let reviewItem: LiveResultReviewItem
    let onApprove: () -> Void
    let onCorrect: (LiveResultReviewOutcome, LiveResultReviewOutcome, [HighlightRegion], [HighlightRegion]) -> Void
    let onSkip: () -> Void

    @State private var selectedSite: ReviewSite = .both
    @State private var joeCorrection: LiveResultReviewOutcome?
    @State private var ignCorrection: LiveResultReviewOutcome?
    @State private var showJoeHighlight: Bool = false
    @State private var showIgnHighlight: Bool = false
    @State private var joeHighlightRegions: [HighlightRegion] = []
    @State private var ignHighlightRegions: [HighlightRegion] = []
    @State private var currentPhotoIndex: Int = 0
    @State private var showCorrectionPicker: Bool = false
    @State private var correctingSite: CorrectionTarget = .joe

    nonisolated enum ReviewSite: String, CaseIterable, Sendable {
        case both = "Paired"
        case joe = "JoePoint"
        case ignition = "Ignition"
    }

    nonisolated enum CorrectionTarget: Sendable {
        case joe
        case ignition
    }

    private var joeImage: UIImage? {
        reviewItem.joeScreenshotData.flatMap { UIImage(data: $0) }
    }

    private var ignImage: UIImage? {
        reviewItem.ignitionScreenshotData.flatMap { UIImage(data: $0) }
    }

    private var isCorrection: Bool {
        joeCorrection != nil || ignCorrection != nil
    }

    private var effectiveJoeOutcome: LiveResultReviewOutcome {
        joeCorrection ?? reviewItem.joeDetectedOutcome
    }

    private var effectiveIgnOutcome: LiveResultReviewOutcome {
        ignCorrection ?? reviewItem.ignitionDetectedOutcome
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            pairedResultBanner
            Divider().overlay(Color.white.opacity(0.1))
            screenshotCarousel
            Divider().overlay(Color.white.opacity(0.1))
            correctionSection
            Divider().overlay(Color.white.opacity(0.1))
            actionBar
        }
        .background(.black.opacity(0.95))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(
                        colors: [effectiveJoeOutcome.color.opacity(0.6), effectiveIgnOutcome.color.opacity(0.6)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 1.5
                )
        )
        .padding(.horizontal, 8)
        .shadow(color: .black.opacity(0.5), radius: 20, y: 10)
        .fullScreenCover(isPresented: $showJoeHighlight) {
            if let img = joeImage {
                ScreenshotHighlightView(image: img) { regions in
                    joeHighlightRegions = regions
                }
            }
        }
        .fullScreenCover(isPresented: $showIgnHighlight) {
            if let img = ignImage {
                ScreenshotHighlightView(image: img) { regions in
                    ignHighlightRegions = regions
                }
            }
        }
        .sheet(isPresented: $showCorrectionPicker) {
            correctionPickerSheet
        }
    }

    private var headerBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.cyan)
                .symbolEffect(.pulse, options: .repeating.speed(0.5))

            VStack(alignment: .leading, spacing: 2) {
                Text("AI RESULT REVIEW")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.cyan)
                Text(reviewItem.credentialEmail)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(reviewItem.timestamp, style: .time)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    Text("JOE")
                        .font(.system(size: 7, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.green)
                    Text("\(Int(reviewItem.joeConfidence * 100))%")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.6))
                    Text("IGN")
                        .font(.system(size: 7, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.orange)
                    Text("\(Int(reviewItem.ignitionConfidence * 100))%")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }

            Button { onSkip() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var pairedResultBanner: some View {
        HStack(spacing: 0) {
            siteResultPill(
                icon: "suit.spade.fill",
                name: "JOE",
                color: .green,
                outcome: effectiveJoeOutcome,
                isCorrected: joeCorrection != nil,
                confidence: reviewItem.joeConfidence
            )

            Rectangle()
                .fill(.white.opacity(0.15))
                .frame(width: 1)
                .padding(.vertical, 6)

            siteResultPill(
                icon: "flame.fill",
                name: "IGN",
                color: .orange,
                outcome: effectiveIgnOutcome,
                isCorrected: ignCorrection != nil,
                confidence: reviewItem.ignitionConfidence
            )
        }
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.03))
    }

    private func siteResultPill(icon: String, name: String, color: Color, outcome: LiveResultReviewOutcome, isCorrected: Bool, confidence: Double) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(color)
                Text(name)
                    .font(.system(size: 8, weight: .heavy, design: .monospaced))
                    .foregroundStyle(color)
            }
            HStack(spacing: 4) {
                Image(systemName: outcome.icon)
                    .font(.system(size: 10, weight: .bold))
                Text(outcome.shortLabel)
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
            }
            .foregroundStyle(outcome.color)
            if isCorrected {
                Text("CORRECTED")
                    .font(.system(size: 7, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.yellow)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Color.yellow.opacity(0.15))
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var screenshotCarousel: some View {
        VStack(spacing: 6) {
            Picker("Site", selection: $selectedSite) {
                ForEach(ReviewSite.allCases, id: \.rawValue) { site in
                    Text(site.rawValue).tag(site)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            .padding(.top, 8)

            switch selectedSite {
            case .both:
                pairedScreenshotView
            case .joe:
                singleScreenshotView(image: joeImage, site: "joe", label: "JoePoint", color: .green)
            case .ignition:
                singleScreenshotView(image: ignImage, site: "ignition", label: "Ignition", color: .orange)
            }
        }
        .padding(.bottom, 8)
    }

    private var pairedScreenshotView: some View {
        HStack(spacing: 4) {
            screenshotThumbnail(image: joeImage, label: "JOE", icon: "suit.spade.fill", color: .green, outcome: effectiveJoeOutcome, highlightCount: joeHighlightRegions.count)
            screenshotThumbnail(image: ignImage, label: "IGN", icon: "flame.fill", color: .orange, outcome: effectiveIgnOutcome, highlightCount: ignHighlightRegions.count)
        }
        .frame(height: 160)
        .padding(.horizontal, 8)
    }

    private func screenshotThumbnail(image: UIImage?, label: String, icon: String, color: Color, outcome: LiveResultReviewOutcome, highlightCount: Int) -> some View {
        GeometryReader { geo in
            if let img = image {
                Color(.secondarySystemBackground)
                    .overlay {
                        Image(uiImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .allowsHitTesting(false)
                    }
                    .clipShape(.rect(cornerRadius: 8))
                    .overlay(alignment: .top) {
                        HStack(spacing: 3) {
                            Image(systemName: icon).font(.system(size: 7, weight: .bold))
                            Text(label).font(.system(size: 8, weight: .heavy, design: .monospaced))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(color.opacity(0.85)).clipShape(Capsule())
                        .padding(.top, 4)
                    }
                    .overlay(alignment: .bottom) {
                        HStack {
                            Spacer()
                            Text(outcome.shortLabel)
                                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                                .foregroundStyle(.white)
                            Spacer()
                        }
                        .padding(.vertical, 3)
                        .background(outcome.color.opacity(0.85))
                    }
                    .overlay(alignment: .topTrailing) {
                        if highlightCount > 0 {
                            Text("\(highlightCount)")
                                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                                .foregroundStyle(.black)
                                .frame(width: 18, height: 18)
                                .background(.yellow)
                                .clipShape(.circle)
                                .padding(4)
                        }
                    }
            } else {
                Color(.tertiarySystemGroupedBackground)
                    .clipShape(.rect(cornerRadius: 8))
                    .overlay {
                        VStack(spacing: 4) {
                            Image(systemName: icon).font(.caption).foregroundStyle(color.opacity(0.4))
                            Text(label).font(.system(size: 8, weight: .heavy, design: .monospaced)).foregroundStyle(.tertiary)
                            Text("No screenshot").font(.system(size: 7, design: .monospaced)).foregroundStyle(.quaternary)
                        }
                    }
            }
        }
    }

    private func singleScreenshotView(image: UIImage?, site: String, label: String, color: Color) -> some View {
        Group {
            if let img = image {
                Color(.secondarySystemBackground)
                    .frame(height: 200)
                    .overlay {
                        Image(uiImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .allowsHitTesting(false)
                    }
                    .clipShape(.rect(cornerRadius: 10))
                    .overlay(alignment: .topLeading) {
                        HStack(spacing: 4) {
                            Image(systemName: site == "joe" ? "suit.spade.fill" : "flame.fill")
                                .font(.system(size: 9, weight: .bold))
                            Text(label)
                                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(color.opacity(0.85)).clipShape(Capsule())
                        .padding(8)
                    }
                    .padding(.horizontal, 8)
            } else {
                Color(.tertiarySystemGroupedBackground)
                    .frame(height: 120)
                    .clipShape(.rect(cornerRadius: 10))
                    .overlay {
                        Text("No screenshot available")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 8)
            }
        }
    }

    private var correctionSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Button {
                    correctingSite = .joe
                    showCorrectionPicker = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "suit.spade.fill").font(.system(size: 8)).foregroundStyle(.green)
                        Text(joeCorrection == nil ? "Correct Joe" : "Joe: \(joeCorrection!.shortLabel)")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                    }
                    .foregroundStyle(joeCorrection != nil ? .yellow : .white.opacity(0.7))
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .background(joeCorrection != nil ? Color.yellow.opacity(0.12) : Color.white.opacity(0.06))
                    .clipShape(.rect(cornerRadius: 8))
                }

                Button {
                    correctingSite = .ignition
                    showCorrectionPicker = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill").font(.system(size: 8)).foregroundStyle(.orange)
                        Text(ignCorrection == nil ? "Correct Ign" : "Ign: \(ignCorrection!.shortLabel)")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                    }
                    .foregroundStyle(ignCorrection != nil ? .yellow : .white.opacity(0.7))
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .background(ignCorrection != nil ? Color.yellow.opacity(0.12) : Color.white.opacity(0.06))
                    .clipShape(.rect(cornerRadius: 8))
                }

                Spacer()

                if joeCorrection != nil && joeImage != nil {
                    Button {
                        showJoeHighlight = true
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "hand.draw.fill").font(.system(size: 9))
                            Text("JOE").font(.system(size: 8, weight: .heavy, design: .monospaced))
                            if !joeHighlightRegions.isEmpty {
                                Text("\(joeHighlightRegions.count)")
                                    .font(.system(size: 7, weight: .heavy, design: .monospaced))
                                    .foregroundStyle(.black)
                                    .frame(width: 14, height: 14)
                                    .background(.yellow)
                                    .clipShape(.circle)
                            }
                        }
                        .foregroundStyle(.yellow)
                        .padding(.horizontal, 8).padding(.vertical, 6)
                        .background(Color.yellow.opacity(0.1))
                        .clipShape(.rect(cornerRadius: 6))
                    }
                }

                if ignCorrection != nil && ignImage != nil {
                    Button {
                        showIgnHighlight = true
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "hand.draw.fill").font(.system(size: 9))
                            Text("IGN").font(.system(size: 8, weight: .heavy, design: .monospaced))
                            if !ignHighlightRegions.isEmpty {
                                Text("\(ignHighlightRegions.count)")
                                    .font(.system(size: 7, weight: .heavy, design: .monospaced))
                                    .foregroundStyle(.black)
                                    .frame(width: 14, height: 14)
                                    .background(.yellow)
                                    .clipShape(.circle)
                            }
                        }
                        .foregroundStyle(.yellow)
                        .padding(.horizontal, 8).padding(.vertical, 6)
                        .background(Color.yellow.opacity(0.1))
                        .clipShape(.rect(cornerRadius: 6))
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            Button {
                onSkip()
            } label: {
                Text("SKIP")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.05))
                    .clipShape(.rect(cornerRadius: 8))
            }

            if isCorrection {
                Button {
                    onCorrect(
                        joeCorrection ?? reviewItem.joeDetectedOutcome,
                        ignCorrection ?? reviewItem.ignitionDetectedOutcome,
                        joeHighlightRegions,
                        ignHighlightRegions
                    )
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "pencil.and.outline")
                            .font(.system(size: 10, weight: .bold))
                        Text("SUBMIT CORRECTION")
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.yellow)
                    .clipShape(.rect(cornerRadius: 8))
                }
                .sensoryFeedback(.impact(weight: .heavy), trigger: isCorrection)
            } else {
                Button {
                    onApprove()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text("APPROVE RESULTS")
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.green)
                    .clipShape(.rect(cornerRadius: 8))
                }
                .sensoryFeedback(.success, trigger: true)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var correctionPickerSheet: some View {
        NavigationStack {
            List {
                Section {
                    let currentDetected = correctingSite == .joe ? reviewItem.joeDetectedOutcome : reviewItem.ignitionDetectedOutcome
                    HStack(spacing: 8) {
                        Image(systemName: currentDetected.icon)
                            .foregroundStyle(currentDetected.color)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("AI Detected")
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Text(currentDetected.displayLabel)
                                .font(.system(.subheadline, design: .monospaced, weight: .bold))
                                .foregroundStyle(currentDetected.color)
                        }
                        Spacer()
                        Text("\(Int((correctingSite == .joe ? reviewItem.joeConfidence : reviewItem.ignitionConfidence) * 100))%")
                            .font(.system(.caption, design: .monospaced, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Current AI Detection")
                }

                Section {
                    ForEach(LiveResultReviewOutcome.allCases) { outcome in
                        Button {
                            switch correctingSite {
                            case .joe:
                                joeCorrection = outcome == reviewItem.joeDetectedOutcome ? nil : outcome
                            case .ignition:
                                ignCorrection = outcome == reviewItem.ignitionDetectedOutcome ? nil : outcome
                            }
                            showCorrectionPicker = false
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: outcome.icon)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(outcome.color)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(outcome.displayLabel)
                                        .font(.system(.subheadline, design: .monospaced, weight: .bold))
                                        .foregroundStyle(.primary)
                                    Text(outcome.description)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                Spacer()
                                let isCurrent: Bool = {
                                    let detected = correctingSite == .joe ? reviewItem.joeDetectedOutcome : reviewItem.ignitionDetectedOutcome
                                    return outcome == detected
                                }()
                                if isCurrent {
                                    Text("AI")
                                        .font(.system(size: 8, weight: .heavy, design: .monospaced))
                                        .foregroundStyle(.cyan)
                                        .padding(.horizontal, 5).padding(.vertical, 2)
                                        .background(Color.cyan.opacity(0.15))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                } header: {
                    Text("Select Correct Outcome")
                } footer: {
                    Text("After selecting, use the highlight tool to mark the screenshot evidence that indicates this result.")
                }

                if correctingSite == .joe && joeCorrection != nil {
                    Section {
                        Button(role: .destructive) {
                            joeCorrection = nil
                            joeHighlightRegions = []
                            showCorrectionPicker = false
                        } label: {
                            Label("Clear Joe Correction", systemImage: "arrow.uturn.backward")
                        }
                    }
                }

                if correctingSite == .ignition && ignCorrection != nil {
                    Section {
                        Button(role: .destructive) {
                            ignCorrection = nil
                            ignHighlightRegions = []
                            showCorrectionPicker = false
                        } label: {
                            Label("Clear Ignition Correction", systemImage: "arrow.uturn.backward")
                        }
                    }
                }
            }
            .navigationTitle(correctingSite == .joe ? "JoePoint Result" : "Ignition Result")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showCorrectionPicker = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationContentInteraction(.scrolls)
    }
}
