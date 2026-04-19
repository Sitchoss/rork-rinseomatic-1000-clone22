import SwiftUI
import WebKit

struct LiveWebViewFullScreenView: View {
    @State private var debugService = LiveWebViewDebugService.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GeometryReader { geo in
            NavigationStack {
                ZStack(alignment: .bottom) {
                    VStack(spacing: 0) {
                        if let webView = debugService.attachedWebView {
                            urlBar
                            Divider()
                            LiveWebViewContainerView(webView: webView, interactive: debugService.isInteractive)
                                .scaleEffect(debugService.isInteractive ? 1.0 : debugService.previewScale, anchor: .topLeading)
                                .overlay(alignment: .top) {
                                    if debugService.isInteractive {
                                        interactiveBadge
                                    }
                                }
                                .overlay(alignment: .top) {
                                    if debugService.isInteractive {
                                        RoundedRectangle(cornerRadius: 0)
                                            .strokeBorder(Color.orange, lineWidth: 2)
                                            .allowsHitTesting(false)
                                    }
                                }
                                .ignoresSafeArea(edges: .bottom)
                        } else {
                            ContentUnavailableView(
                                "Session Ended",
                                systemImage: "play.slash",
                                description: Text("The WebView session has been torn down.")
                            )
                        }
                    }

                    if debugService.showConsole {
                        consoleOverlay
                    }

                    if debugService.screenshotToast {
                        screenshotToastView
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    if debugService.showResultReview, let reviewItem = debugService.activeReviewItem {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                            .allowsHitTesting(true)
                            .onTapGesture { }
                            .transition(.opacity)

                        LiveResultReviewPopupView(
                            reviewItem: reviewItem,
                            onApprove: {
                                withAnimation(.spring(duration: 0.3)) {
                                    debugService.approveCurrentReview()
                                }
                            },
                            onCorrect: { joeOutcome, ignOutcome, joeHighlights, ignHighlights in
                                withAnimation(.spring(duration: 0.3)) {
                                    debugService.correctCurrentReview(
                                        joeOutcome: joeOutcome,
                                        ignOutcome: ignOutcome,
                                        joeHighlights: joeHighlights,
                                        ignHighlights: ignHighlights
                                    )
                                }
                            },
                            onSkip: {
                                withAnimation(.spring(duration: 0.3)) {
                                    debugService.skipCurrentReview()
                                }
                            }
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 8)
                    }
                }
                .animation(.spring(duration: 0.35), value: debugService.showResultReview)
                .background(.black)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                ToolbarItem(placement: .principal) {
                    sessionInfo
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        debugService.isFullScreen = false
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "pip.enter")
                            Text("Minimize")
                                .font(.caption.weight(.semibold))
                        }
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if debugService.isPaired {
                        Button {
                            withAnimation(.spring(duration: 0.25)) {
                                debugService.toggleSite()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(debugService.activeSite == .joe ? .blue : .orange)
                                    .frame(width: 7, height: 7)
                                Text(debugService.activeSite.rawValue.uppercased())
                                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                                Image(systemName: "arrow.left.arrow.right")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .foregroundStyle(debugService.activeSite == .joe ? .blue : .orange)
                        }
                        .sensoryFeedback(.impact(weight: .light), trigger: debugService.activeSite.rawValue)
                    }

                    Button {
                        debugService.captureScreenshot()
                    } label: {
                        Image(systemName: "camera.fill")
                    }
                    .sensoryFeedback(.impact(weight: .medium), trigger: debugService.screenshotToast)

                    Button {
                        debugService.cycleZoom()
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }

                    Button {
                        withAnimation(.snappy) { debugService.isInteractive.toggle() }
                    } label: {
                        Image(systemName: debugService.isInteractive ? "hand.tap.fill" : "hand.tap")
                            .foregroundStyle(debugService.isInteractive ? .orange : .secondary)
                    }

                    Button {
                        withAnimation(.snappy) { debugService.showConsole.toggle() }
                    } label: {
                        Image(systemName: "terminal.fill")
                            .foregroundStyle(debugService.showConsole ? .green : .secondary)
                    }

                    Menu {
                        Button {
                            debugService.attachToNearest()
                        } label: {
                            Label("Re-Follow Active Session", systemImage: "arrow.triangle.2.circlepath")
                        }
                        Divider()
                        Toggle(isOn: $debugService.resultReviewEnabled) {
                            Label("AI Result Review", systemImage: "brain.head.profile")
                        }
                        if !debugService.pendingReviewItems.isEmpty {
                            Button {
                                debugService.presentNextReview()
                            } label: {
                                Label("Show Next Review (\(debugService.pendingReviewItems.count))", systemImage: "eye.fill")
                            }
                        }
                        if debugService.totalReviewsShown > 0 {
                            let store = AIResultCorrectionStore.shared
                            Section("AI Review Stats") {
                                Text("Reviews: \(debugService.totalReviewsShown)")
                                Text("Approved: \(debugService.totalApprovals)")
                                Text("Corrected: \(debugService.totalCorrections)")
                                Text(store.correctionSummary)
                            }
                        }
                        Divider()
                        Button(role: .destructive) {
                            debugService.detach()
                            dismiss()
                        } label: {
                            Label("Detach", systemImage: "xmark.circle")
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "ellipsis.circle")
                                .foregroundStyle(.secondary)
                            if !debugService.pendingReviewItems.isEmpty {
                                Text("\(debugService.pendingReviewItems.count)")
                                    .font(.system(size: 8, weight: .heavy, design: .monospaced))
                                    .foregroundStyle(.black)
                                    .frame(width: 16, height: 16)
                                    .background(.yellow)
                                    .clipShape(.circle)
                            }
                        }
                    }
                }
            }
                .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            }
        }
    }

    private var sessionInfo: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            HStack(spacing: 6) {
                Circle()
                    .fill(.red)
                    .frame(width: 7, height: 7)
                Text("LIVE")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.red)
                Text(debugService.attachedLabel.prefix(14))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .lineLimit(1)
                Text("S\(debugService.attachedSessionIndex)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color(.tertiarySystemFill))
                    .clipShape(.rect(cornerRadius: 3))
                if let start = debugService.attachedStartedAt {
                    Text(elapsedString(from: start))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Text(debugService.currentModeTitle.uppercased())
                    .font(.system(size: 8, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(.cyan)
                    .clipShape(.rect(cornerRadius: 3))
            }
        }
    }

    private var urlBar: some View {
        VStack(alignment: .leading, spacing: 2) {
            if !debugService.currentTitle.isEmpty {
                Text(debugService.currentTitle)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            if !debugService.currentURL.isEmpty {
                Text(debugService.currentURL)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.05))
    }

    private var interactiveBadge: some View {
        Text("INTERACTIVE")
            .font(.system(size: 9, weight: .heavy, design: .monospaced))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.orange)
            .clipShape(Capsule())
            .padding(.top, 8)
    }

    private var consoleOverlay: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Console")
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.green)
                Spacer()
                Text("\(debugService.consoleEntries.count)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                Button {
                    debugService.consoleEntries.removeAll()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Button {
                    withAnimation(.snappy) { debugService.showConsole = false }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)

            Divider().overlay(Color.green.opacity(0.3))

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(debugService.consoleEntries) { entry in
                            HStack(alignment: .top, spacing: 6) {
                                Text(consoleTimestamp(entry.timestamp))
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.3))
                                Circle()
                                    .fill(consoleLevelColor(entry.level))
                                    .frame(width: 6, height: 6)
                                    .padding(.top, 3)
                                Text(entry.message)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(consoleLevelColor(entry.level))
                                    .lineLimit(4)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 1)
                            .id(entry.id)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onChange(of: debugService.consoleEntries.count) { _, _ in
                    if let last = debugService.consoleEntries.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
        .frame(height: 200)
        .background(.black.opacity(0.85))
        .clipShape(.rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.green.opacity(0.3), lineWidth: 0.5)
        )
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var screenshotToastView: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("Screenshot saved")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .padding(.bottom, 20)
    }

    private func elapsedString(from start: Date) -> String {
        let elapsed = Date().timeIntervalSince(start)
        if elapsed < 60 { return String(format: "%.0fs", elapsed) }
        let m = Int(elapsed) / 60
        let s = Int(elapsed) % 60
        return "\(m)m \(s)s"
    }

    private func consoleTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }

    private func consoleLevelColor(_ level: LiveConsoleEntry.Level) -> Color {
        switch level {
        case .log: .white
        case .warn: .orange
        case .error: .red
        }
    }
}
