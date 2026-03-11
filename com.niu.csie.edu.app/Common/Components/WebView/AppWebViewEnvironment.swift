import WebKit


// 唯一 WebView 設定來源，避免 session 建在另一個 process
final class AppWebViewEnvironment {
    static let shared = AppWebViewEnvironment()

    /// iOS 15+：用來做「一致性收斂」，不是隔離
    let processPool = WKProcessPool()

    private init() {}

    func makeConfiguration() -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()

        if #available(iOS 14.0, *) {
            config.defaultWebpagePreferences.allowsContentJavaScript = true
        } else {
            config.preferences.javaScriptEnabled = true
        }

        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        config.websiteDataStore = .default()
        config.processPool = processPool

        return config
    }
}
