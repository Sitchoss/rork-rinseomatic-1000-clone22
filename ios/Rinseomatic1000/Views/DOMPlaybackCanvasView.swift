import SwiftUI
import WebKit

struct DOMPlaybackCanvasView: UIViewRepresentable {
    let htmlContent: String
    let baseURL: URL?
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.isScrollEnabled = true
        webView.isOpaque = false
        webView.backgroundColor = .clear
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        if htmlContent.isEmpty {
            uiView.loadHTMLString("<html><body><h3 style='color: gray; font-family: sans-serif; text-align: center; margin-top: 40px;'>No DOM Snapshot</h3></body></html>", baseURL: nil)
        } else {
            uiView.loadHTMLString(htmlContent, baseURL: baseURL)
        }
    }
}

// Sub-component wrapper that we can attach to the ReplayTimelineView or use as a standalone presentation sheet
struct HeuristicFailurePlaybackViewer: View {
    let replay: EnrichedSessionReplay
    @State private var currentStepIndex: Int = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Live DOM Canvas
            let currentHTML = safeHTML(for: currentStepIndex)
            DOMPlaybackCanvasView(htmlContent: currentHTML, baseURL: URL(string: replay.targetURL))
                .background(Color.white) // Web pages assume white background
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Scrubbing Controls
            VStack(spacing: 12) {
                Text(replay.steps[currentStepIndex].action)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Slider(value: Binding(
                    get: { Double(currentStepIndex) },
                    set: { currentStepIndex = Int($0) }
                ), in: 0...Double(max(0, replay.steps.count - 1)), step: 1.0)
                .padding(.horizontal)
                
                Text(replay.steps[currentStepIndex].detail)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(2)
            }
            .padding()
            .background(Color(.darkGray))
        }
        .navigationTitle("Heuristic DOM Playback")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func safeHTML(for index: Int) -> String {
        guard index >= 0 && index < replay.steps.count else { return "" }
        let step = replay.steps[index]
        if let html = step.htmlSnapshot, !html.isEmpty {
            return html
        }
        
        // Scan backwards to find the last known HTML snapshot if the current step doesn't have one
        var backIndex = index - 1
        while backIndex >= 0 {
            if let html = replay.steps[backIndex].htmlSnapshot, !html.isEmpty {
                return html
            }
            backIndex -= 1
        }
        return ""
    }
}
