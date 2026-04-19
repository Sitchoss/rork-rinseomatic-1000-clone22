import Foundation
import SwiftUI
import WebKit

// MARK: - Isolated Profile Config

nonisolated struct IsolatedWebProfile: Sendable, Identifiable, Hashable {
    let id: Int
    let label: String
    let userAgent: String
    let language: String
    let acceptLanguage: String
    let timezone: String
    let viewportWidth: Int
    let viewportHeight: Int
    let devicePixelRatio: Double
    let platform: String
    let secChUa: String
    let canvasNoiseSeed: Int
    let webglVendor: String
    let webglRenderer: String

    static let all: [IsolatedWebProfile] = [
        IsolatedWebProfile(
            id: 0,
            label: "Profile A",
            userAgent: "Mozilla/5.0 (iPhone; CPU iPhone OS 18_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.2 Mobile/15E148 Safari/604.1",
            language: "en-US",
            acceptLanguage: "en-US,en;q=0.9",
            timezone: "America/New_York",
            viewportWidth: 393,
            viewportHeight: 852,
            devicePixelRatio: 3.0,
            platform: "iPhone",
            secChUa: "\"Not_A Brand\";v=\"99\", \"Safari\";v=\"18\"",
            canvasNoiseSeed: 91711,
            webglVendor: "Apple Inc.",
            webglRenderer: "Apple GPU"
        ),
        IsolatedWebProfile(
            id: 1,
            label: "Profile B",
            userAgent: "Mozilla/5.0 (Linux; Android 14; Pixel 8 Pro) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36",
            language: "en-GB",
            acceptLanguage: "en-GB,en;q=0.9",
            timezone: "Europe/London",
            viewportWidth: 412,
            viewportHeight: 915,
            devicePixelRatio: 2.625,
            platform: "Linux armv8l",
            secChUa: "\"Chromium\";v=\"131\", \"Google Chrome\";v=\"131\", \"Not_A Brand\";v=\"24\"",
            canvasNoiseSeed: 44203,
            webglVendor: "Google Inc. (Qualcomm)",
            webglRenderer: "ANGLE (Qualcomm, Adreno (TM) 740, OpenGL ES 3.2)"
        ),
        IsolatedWebProfile(
            id: 2,
            label: "Profile C",
            userAgent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
            language: "ja-JP",
            acceptLanguage: "ja-JP,ja;q=0.9,en;q=0.7",
            timezone: "Asia/Tokyo",
            viewportWidth: 1920,
            viewportHeight: 1080,
            devicePixelRatio: 1.0,
            platform: "Win32",
            secChUa: "\"Chromium\";v=\"131\", \"Google Chrome\";v=\"131\", \"Not_A Brand\";v=\"24\"",
            canvasNoiseSeed: 77781,
            webglVendor: "Google Inc. (NVIDIA)",
            webglRenderer: "ANGLE (NVIDIA, NVIDIA GeForce RTX 4070 Direct3D11 vs_5_0 ps_5_0, D3D11)"
        ),
        IsolatedWebProfile(
            id: 3,
            label: "Profile D",
            userAgent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 14.6; rv:133.0) Gecko/20100101 Firefox/133.0",
            language: "en-AU",
            acceptLanguage: "en-AU,en;q=0.9",
            timezone: "Australia/Sydney",
            viewportWidth: 1440,
            viewportHeight: 900,
            devicePixelRatio: 2.0,
            platform: "MacIntel",
            secChUa: "",
            canvasNoiseSeed: 12057,
            webglVendor: "Mozilla",
            webglRenderer: "Mozilla"
        )
    ]
}

// MARK: - Nav Delegate

final class IsoWebNavDelegate: NSObject, WKNavigationDelegate {
    var onFinish: (() -> Void)?
    var onFail: ((String) -> Void)?

    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in onFinish?() }
    }

    nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in onFail?(error.localizedDescription) }
    }

    nonisolated func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in onFail?(error.localizedDescription) }
    }
}

// MARK: - Stealth Script Builder

enum StealthScriptBuilder {
    static func script(for profile: IsolatedWebProfile) -> String {
        let seed = profile.canvasNoiseSeed
        return """
        (function() {
            try {
                var seed = \(seed);
                function rand() {
                    seed = (seed * 9301 + 49297) % 233280;
                    return seed / 233280;
                }

                // navigator overrides
                try {
                    Object.defineProperty(navigator, 'language', { get: function() { return '\(profile.language)'; } });
                    Object.defineProperty(navigator, 'languages', { get: function() { return ['\(profile.language)','en']; } });
                    Object.defineProperty(navigator, 'platform', { get: function() { return '\(profile.platform)'; } });
                    Object.defineProperty(navigator, 'hardwareConcurrency', { get: function() { return \(4 + (seed % 5)); } });
                    Object.defineProperty(navigator, 'deviceMemory', { get: function() { return \([2, 4, 8, 16][seed % 4]); } });
                    Object.defineProperty(navigator, 'webdriver', { get: function() { return false; } });
                } catch(e) {}

                // screen overrides
                try {
                    Object.defineProperty(screen, 'width', { get: function() { return \(profile.viewportWidth); } });
                    Object.defineProperty(screen, 'height', { get: function() { return \(profile.viewportHeight); } });
                    Object.defineProperty(screen, 'availWidth', { get: function() { return \(profile.viewportWidth); } });
                    Object.defineProperty(screen, 'availHeight', { get: function() { return \(profile.viewportHeight); } });
                    Object.defineProperty(screen, 'colorDepth', { get: function() { return 24; } });
                    Object.defineProperty(screen, 'pixelDepth', { get: function() { return 24; } });
                    Object.defineProperty(window, 'devicePixelRatio', { get: function() { return \(profile.devicePixelRatio); } });
                } catch(e) {}

                // timezone override
                try {
                    var origDTF = Intl.DateTimeFormat;
                    Intl.DateTimeFormat = function() {
                        var inst = new origDTF(...arguments);
                        var origResolved = inst.resolvedOptions.bind(inst);
                        inst.resolvedOptions = function() {
                            var r = origResolved();
                            r.timeZone = '\(profile.timezone)';
                            return r;
                        };
                        return inst;
                    };
                } catch(e) {}

                // canvas noise
                try {
                    var origToDataURL = HTMLCanvasElement.prototype.toDataURL;
                    HTMLCanvasElement.prototype.toDataURL = function() {
                        var ctx = this.getContext('2d');
                        if (ctx) {
                            try {
                                var data = ctx.getImageData(0, 0, this.width, this.height);
                                for (var i = 0; i < data.data.length; i += 4) {
                                    data.data[i] = data.data[i] ^ (Math.floor(rand() * 3));
                                    data.data[i+1] = data.data[i+1] ^ (Math.floor(rand() * 3));
                                    data.data[i+2] = data.data[i+2] ^ (Math.floor(rand() * 3));
                                }
                                ctx.putImageData(data, 0, 0);
                            } catch(e) {}
                        }
                        return origToDataURL.apply(this, arguments);
                    };

                    var origGetImageData = CanvasRenderingContext2D.prototype.getImageData;
                    CanvasRenderingContext2D.prototype.getImageData = function() {
                        var data = origGetImageData.apply(this, arguments);
                        for (var i = 0; i < data.data.length; i += 97) {
                            data.data[i] = data.data[i] ^ (Math.floor(rand() * 2));
                        }
                        return data;
                    };
                } catch(e) {}

                // webgl vendor/renderer spoof
                try {
                    var specs = { 37445: '\(profile.webglVendor)', 37446: '\(profile.webglRenderer)' };
                    var origGetParam = WebGLRenderingContext.prototype.getParameter;
                    WebGLRenderingContext.prototype.getParameter = function(p) {
                        if (specs[p]) return specs[p];
                        return origGetParam.call(this, p);
                    };
                    if (window.WebGL2RenderingContext) {
                        var origGetParam2 = WebGL2RenderingContext.prototype.getParameter;
                        WebGL2RenderingContext.prototype.getParameter = function(p) {
                            if (specs[p]) return specs[p];
                            return origGetParam2.call(this, p);
                        };
                    }
                } catch(e) {}

                // audio context noise
                try {
                    var origGetChannelData = AudioBuffer.prototype.getChannelData;
                    AudioBuffer.prototype.getChannelData = function() {
                        var data = origGetChannelData.apply(this, arguments);
                        for (var i = 0; i < data.length; i += 500) {
                            data[i] = data[i] + (rand() - 0.5) * 0.0000001;
                        }
                        return data;
                    };
                } catch(e) {}

                // font enumeration trimming (limit via offsetWidth drift)
                try {
                    var origOffsetWidth = Object.getOwnPropertyDescriptor(HTMLElement.prototype, 'offsetWidth');
                    if (origOffsetWidth) {
                        Object.defineProperty(HTMLElement.prototype, 'offsetWidth', {
                            get: function() {
                                var v = origOffsetWidth.get.call(this);
                                if (this.style && this.style.fontFamily) {
                                    v = v + (rand() < 0.1 ? 1 : 0);
                                }
                                return v;
                            }
                        });
                    }
                } catch(e) {}
            } catch(e) {}
        })();
        """
    }
}

// MARK: - Isolated Pane

@MainActor
@Observable
final class IsolatedPane: Identifiable {
    let id: Int
    let profile: IsolatedWebProfile
    var webView: WKWebView
    var isLoading: Bool = true
    var errorMessage: String = ""
    private let delegate = IsoWebNavDelegate()

    init(profile: IsolatedWebProfile) {
        self.id = profile.id
        self.profile = profile

        let config = WKWebViewConfiguration()
        // Fully isolated, non-persistent data store per pane
        config.websiteDataStore = .nonPersistent()
        config.processPool = WKProcessPool()
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        if #available(iOS 15.4, *) {
            config.preferences.isElementFullscreenEnabled = true
        }

        let script = WKUserScript(
            source: StealthScriptBuilder.script(for: profile),
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        config.userContentController.addUserScript(script)

        let wv = WKWebView(
            frame: CGRect(origin: .zero, size: CGSize(width: profile.viewportWidth, height: profile.viewportHeight)),
            configuration: config
        )
        wv.customUserAgent = profile.userAgent
        wv.allowsBackForwardNavigationGestures = true
        wv.isOpaque = true
        self.webView = wv
        wv.navigationDelegate = delegate

        delegate.onFinish = { [weak self] in
            self?.isLoading = false
            self?.errorMessage = ""
        }
        delegate.onFail = { [weak self] err in
            self?.isLoading = false
            self?.errorMessage = err
        }

        reload()
    }

    func reload() {
        guard let url = URL(string: "https://amiunique.org/fingerprint") else { return }
        var req = URLRequest(url: url)
        req.setValue(profile.acceptLanguage, forHTTPHeaderField: "Accept-Language")
        if !profile.secChUa.isEmpty {
            req.setValue(profile.secChUa, forHTTPHeaderField: "Sec-CH-UA")
            req.setValue("?0", forHTTPHeaderField: "Sec-CH-UA-Mobile")
            req.setValue("\"\(profile.platform)\"", forHTTPHeaderField: "Sec-CH-UA-Platform")
        }
        req.setValue("1", forHTTPHeaderField: "DNT")
        isLoading = true
        errorMessage = ""
        webView.load(req)
    }
}

// MARK: - WebView Container

struct IsolatedWebViewContainer: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

// MARK: - Main Test View (Entry Point)

struct FingerprintTestView: View {
    @State private var stage: Stage = .playground
    @State private var aiAnalysis: AIFingerprintLeakAnalysis?
    @State private var isAnalyzing: Bool = false

    enum Stage { case playground, grid }

    var body: some View {
        Group {
            switch stage {
            case .playground:
                PlaygroundIntroView {
                    withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) {
                        stage = .grid
                    }
                }
            case .grid:
                VStack(spacing: 0) {
                    if GeminiAISetup.isConfigured {
                        aiSummaryBar
                    }
                    AmiUniqueGridView()
                }
            }
        }
        .navigationTitle("Fingerprint Test")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: stage) {
            if stage == .grid && aiAnalysis == nil && GeminiAISetup.isConfigured {
                await runAIAnalysis()
            }
        }
    }

    private var aiSummaryBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.purple)
                Text("AI Fingerprint Analysis")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(.purple)
                Spacer()
                if let score = aiAnalysis?.score {
                    Text("\(score)/100")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .foregroundStyle(score >= 70 ? .green : score >= 40 ? .orange : .red)
                }
                if isAnalyzing {
                    ProgressView().controlSize(.mini).tint(.purple)
                } else {
                    Button {
                        Task { await runAIAnalysis() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.purple)
                    }
                }
            }
            if let analysis = aiAnalysis {
                Text(analysis.summary)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.leading)
                if !analysis.leaks.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 5) {
                            ForEach(analysis.leaks.prefix(6), id: \.self) { leak in
                                Text(leak)
                                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(.orange.opacity(0.15))
                                    .foregroundStyle(.orange)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
            } else if isAnalyzing {
                Text("Analyzing fingerprint leaks…")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            } else {
                Text("Tap refresh to analyze current fingerprint exposure.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.purple.opacity(0.08))
    }

    private func runAIAnalysis() async {
        guard !isAnalyzing else { return }
        isAnalyzing = true
        defer { isAnalyzing = false }

        let signals: [String: String] = [
            "userAgent": IsolatedWebProfile.all[0].userAgent,
            "timezone": IsolatedWebProfile.all[0].timezone,
            "platform": IsolatedWebProfile.all[0].platform,
            "webglVendor": IsolatedWebProfile.all[0].webglVendor,
            "webglRenderer": IsolatedWebProfile.all[0].webglRenderer,
            "viewport": "\(IsolatedWebProfile.all[0].viewportWidth)x\(IsolatedWebProfile.all[0].viewportHeight)",
            "language": IsolatedWebProfile.all[0].language
        ]

        aiAnalysis = await AITelemetryService.shared.analyzeFingerprintLeaks(host: "amiunique.org", rawSignals: signals)
    }
}

// MARK: - Playground Intro

private struct PlaygroundIntroView: View {
    let onContinue: () -> Void

    @State private var progress: Double = 0
    @State private var ready: Bool = false
    @State private var pressed: Bool = false

    private let duration: Double = 10

    var body: some View {
        ZStack(alignment: .bottom) {
            PlaygroundWebView()
                .ignoresSafeArea(edges: .bottom)

            continueButton
                .padding(.bottom, 28)
                .padding(.horizontal, 20)
        }
        .task {
            let step = 0.05
            while progress < 1.0 {
                try? await Task.sleep(for: .seconds(step))
                progress = min(1.0, progress + step / duration)
            }
            ready = true
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: pressed)
    }

    private var continueButton: some View {
        Button {
            pressed.toggle()
            onContinue()
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.25), lineWidth: 2)
                        .frame(width: 22, height: 22)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(.white, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .frame(width: 22, height: 22)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.1), value: progress)
                    if ready {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .black))
                            .foregroundStyle(.white)
                    }
                }

                Text(ready ? "Continue" : "Continue")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)

                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .background(
                Capsule().fill(.blue.gradient)
            )
            .overlay(
                Capsule().stroke(.white.opacity(0.25), lineWidth: 0.5)
            )
            .shadow(color: .blue.opacity(0.35), radius: 18, y: 6)
            .scaleEffect(ready ? 1.04 : 1.0)
            .animation(.spring(response: 0.45, dampingFraction: 0.7), value: ready)
        }
        .buttonStyle(.plain)
    }
}

private struct PlaygroundWebView: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.allowsBackForwardNavigationGestures = true
        if let url = URL(string: "https://demo.fingerprint.com/playground") {
            wv.load(URLRequest(url: url))
        }
        return wv
    }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

// MARK: - 2x2 Grid

private struct AmiUniqueGridView: View {
    @State private var panes: [IsolatedPane] = IsolatedWebProfile.all.map { IsolatedPane(profile: $0) }
    @State private var expandedID: Int? = nil
    @Namespace private var ns

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                if let expandedID, let pane = panes.first(where: { $0.id == expandedID }) {
                    expandedView(pane: pane, size: geo.size)
                } else {
                    gridView(size: geo.size)
                }
            }
        }
        .statusBarHidden(expandedID != nil)
    }

    private func gridView(size: CGSize) -> some View {
        let gap: CGFloat = 2
        let cellW = (size.width - gap) / 2
        let cellH = (size.height - gap) / 2

        return VStack(spacing: gap) {
            HStack(spacing: gap) {
                paneCell(panes[0], width: cellW, height: cellH)
                paneCell(panes[1], width: cellW, height: cellH)
            }
            HStack(spacing: gap) {
                paneCell(panes[2], width: cellW, height: cellH)
                paneCell(panes[3], width: cellW, height: cellH)
            }
        }
    }

    private func paneCell(_ pane: IsolatedPane, width: CGFloat, height: CGFloat) -> some View {
        PaneView(pane: pane)
            .frame(width: width, height: height)
            .clipShape(.rect(cornerRadius: 10))
            .matchedGeometryEffect(id: pane.id, in: ns)
            .overlay(alignment: .topLeading) {
                labelChip(pane.profile.label)
                    .padding(8)
            }
            .overlay(alignment: .topTrailing) {
                expandButton(pane: pane)
                    .padding(8)
            }
            .contentShape(.rect)
    }

    private func expandedView(pane: IsolatedPane, size: CGSize) -> some View {
        PaneView(pane: pane)
            .frame(width: size.width, height: size.height)
            .matchedGeometryEffect(id: pane.id, in: ns)
            .overlay(alignment: .topLeading) {
                labelChip(pane.profile.label)
                    .padding(.top, 8)
                    .padding(.leading, 12)
            }
            .overlay(alignment: .topTrailing) {
                Button {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                        expandedID = nil
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .padding(.top, 8)
                .padding(.trailing, 12)
            }
            .ignoresSafeArea()
    }

    private func expandButton(pane: IsolatedPane) -> some View {
        Button {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                expandedID = pane.id
            }
        } label: {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .padding(7)
                .background(.ultraThinMaterial, in: Circle())
        }
        .sensoryFeedback(.impact(weight: .light), trigger: expandedID)
    }

    private func labelChip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.15), lineWidth: 0.5))
    }
}

// MARK: - Pane View

private struct PaneView: View {
    let pane: IsolatedPane

    var body: some View {
        ZStack {
            Color(.systemBackground)

            IsolatedWebViewContainer(webView: pane.webView)

            if pane.isLoading {
                VStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text(pane.profile.timezone)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .background(.ultraThinMaterial, in: .rect(cornerRadius: 8))
            }

            if !pane.errorMessage.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.orange)
                    Text(pane.errorMessage)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                    Button("Retry") { pane.reload() }
                        .font(.system(size: 11, weight: .bold))
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }
                .padding(10)
                .background(.ultraThinMaterial, in: .rect(cornerRadius: 8))
            }
        }
    }
}
