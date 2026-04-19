import SwiftUI
@preconcurrency import WebKit

struct CCTVSlotWebView: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> WKWebView {
        webView.scrollView.isScrollEnabled = true
        webView.allowsBackForwardNavigationGestures = false
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
