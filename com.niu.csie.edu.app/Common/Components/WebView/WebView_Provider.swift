import SwiftUI
import WebKit
import Combine



enum WebViewUserAgent {
    case desktop
    case mobile
    case custom(String)
}

// MARK: - WebView Provider
class WebView_Provider: ObservableObject {
    // 可選單例
    static let shared = WebView_Provider()

    // 對外提供的 webView 實例
    private(set) public var webView: WKWebView

    // 可見性（預設顯示）
    @Published public var isVisible: Bool = true
    public func setVisible(_ visible: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.isVisible = visible
        }
    }
    
    //User Agent
    // MARK: - 預設 UserAgent 設定
    private static let desktopUA =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_5) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"

    private static let mobileUA =
        "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"

    // 事件 callback
    public var onPageFinished: ((String?) -> Void)?
    public var onProgressChanged: ((Double) -> Void)?
    public var onJsAlert: ((String) -> Void)?
    /// 佇列動作全部完成、準備好顯示時呼叫
    public var onPrepared: (() -> Void)?

    private var progressObserver: NSKeyValueObservation?
    private var delegate: WebViewDelegate!

    // --- 動作佇列：用來「先隱藏→做事→再顯示」 ---
    public enum Action {
        case js(String)            // 執行一段 JS
        case navigate(String)      // 跳轉到某個網址（等待下一次 didFinish 才繼續）
        case wait(TimeInterval)    // 純等待（例如等 DOM 變化）
    }
    private var pendingActions: [Action] = []
    private var isPreparing: Bool = false

    // --- 初始化：支援 initialURL ---
    public init(
        config: WKWebViewConfiguration? = nil,
        initialURL: String? = nil,
        userAgent: WebViewUserAgent = .desktop) {
        let usedConfig = config ?? Self.defaultConfiguration()
        self.webView = WKWebView(frame: .zero, configuration: usedConfig)
        self.webView.scrollView.keyboardDismissMode = .onDrag
        
        // 設定 User-Agent
        switch userAgent {
        case .desktop:
            self.webView.customUserAgent = WebView_Provider.desktopUA
        case .mobile:
            self.webView.customUserAgent = WebView_Provider.mobileUA
        case .custom(let ua):
            self.webView.customUserAgent = ua
        }

        // 建議把 inset 調整關掉，避免底部額外留白
        self.webView.scrollView.contentInsetAdjustmentBehavior = .never
        self.webView.scrollView.contentInset = .zero
        self.webView.scrollView.scrollIndicatorInsets = .zero

        self.delegate = WebViewDelegate()
        self.delegate.owner = self
        self.webView.navigationDelegate = self.delegate
        self.webView.uiDelegate = self.delegate

        // 監聽進度
        progressObserver = webView.observe(\.estimatedProgress, options: .new) { [weak self] _, change in
            guard let p = change.newValue else { return }
            DispatchQueue.main.async {
                self?.onProgressChanged?(p)
            }
        }

        // 自動載入 initialURL（若有傳入）
        if let urlStr = initialURL, let url = URL(string: urlStr) {
            self.webView.load(URLRequest(url: url))
        }
    }

    deinit { progressObserver?.invalidate() }

    // MARK: - 預設 configuration
    private static func defaultConfiguration() -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        if #available(iOS 14.0, *) {
            config.defaultWebpagePreferences.allowsContentJavaScript = true
        } else {
            config.preferences.javaScriptEnabled = true
        }
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        config.websiteDataStore = .default()
        return config
    }

    // MARK: - 一般操作
    public func load(url: String) {
        guard let u = URL(string: url) else { return }
        webView.load(URLRequest(url: u))
    }
    
    // 帶 header 的，校務行政子頁面
    public func load(url: String, headers: [String: String]) {
        guard let u = URL(string: url) else { return }
        var req = URLRequest(url: u)
        headers.forEach { k, v in
            req.setValue(v, forHTTPHeaderField: k)
        }
        webView.load(req)
    }
    
    // Post 資訊
    public func loadPost(url: String, orderedBody: [(String, String)]) {
        guard let u = URL(string: url) else { return }

        var components = URLComponents()
        components.queryItems = orderedBody.map { URLQueryItem(name: $0.0, value: $0.1) }
        let bodyString = components.percentEncodedQuery ?? ""
        
        var request = URLRequest(url: u)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyString.data(using: .utf8)
        webView.load(request)
    }



    public func loadHTML(_ html: String, baseURL: URL? = nil) {
        webView.loadHTMLString(html, baseURL: baseURL)
    }

    public func reload() { webView.reload() }
    public func goBack() { if webView.canGoBack { webView.goBack() } }
    public func goForward() { if webView.canGoForward { webView.goForward() } }

    public func evaluateJS(_ script: String, completion: ((String?) -> Void)? = nil) {
        webView.evaluateJavaScript(script) { result, error in
            DispatchQueue.main.async {
                if let err = error as NSError? {
                    var errorMessage = "JS evaluate error:\n"
                    errorMessage += "- localizedDescription: \(err.localizedDescription)\n"
                    errorMessage += "- domain: \(err.domain)\n"
                    errorMessage += "- code: \(err.code)\n"

                    // 嘗試取出 WKError 的類型
                    if err.domain == WKError.errorDomain,
                       let wkCode = WKError.Code(rawValue: err.code) {
                        errorMessage += "- WKError type: \(wkCode)\n"
                    }

                    // userInfo 有時會包含 Exception 資訊（尤其 SyntaxError）
                    if !err.userInfo.isEmpty {
                        errorMessage += "- userInfo:\n"
                        for (key, value) in err.userInfo {
                            errorMessage += "    \(key): \(value)\n"
                        }
                    }

                    print(errorMessage)
                    completion?(nil)
                } else if let val = result {
                    completion?("\(val)")
                } else {
                    completion?(nil)
                }
            }
        }
    }
    
    // MARK: - 清除緩存資訊(會導致登出)
    public func clearCache(completion: (() -> Void)? = nil) {
        // 清除所有類型的網站資料
        let dataStore = WKWebsiteDataStore.default()
        let allTypes = WKWebsiteDataStore.allWebsiteDataTypes()
        let sinceDate = Date(timeIntervalSince1970: 0)

        dataStore.fetchDataRecords(ofTypes: allTypes) { records in
            dataStore.removeData(ofTypes: allTypes, modifiedSince: sinceDate) {
                // 額外清除 cookies
                HTTPCookieStorage.shared.removeCookies(since: sinceDate)
                URLCache.shared.removeAllCachedResponses()

                DispatchQueue.main.async {
                    completion?()
                }
            }
        }
    }


    // MARK: - 準備流程（先隱藏→做事→再顯示）
    /// 直接進入「先隱藏、跑 actions、完成後顯示」的流程
    public func hideUntilReady(actions: [Action], completion: (() -> Void)? = nil) {
        setVisible(false) // 先隱藏
        // 把外部 completion 接到 onPrepared（跑完佇列時觸發）
        if let completion = completion {
            self.onPrepared = { [weak self] in
                completion()
                // 外部 completion 跑完就清掉，以免之後重複呼叫
                self?.onPrepared = nil
            }
        }
        prepare(actions: actions)
    }

    /// 若你已經在別處 load/跳轉了，可隨時呼叫 prepare 讓「下次或當前頁」進入佇列流程
    public func prepare(actions: [Action]) {
        DispatchQueue.main.async {
            self.pendingActions = actions
            self.isPreparing = true
            // 若目前沒在載入，代表現在的 DOM 可直接執行 JS，先從當前頁開始跑
            if !self.webView.isLoading {
                self.executeNextAction()
            }
        }
    }

    /// 由 delegate.didFinish 呼叫
    fileprivate func handleDidFinish() {
        DispatchQueue.main.async {
            if self.isPreparing {
                // 正在準備流程：每次頁面載入完成就接續跑下一個動作
                self.executeNextAction()
            }
            // 保留你原本的 onPageFinished 行為
            self.onPageFinished?(self.webView.url?.absoluteString)
        }
    }

    /// 依序執行佇列中的動作
    private func executeNextAction() {
        guard !pendingActions.isEmpty else {
            // 全部動作跑完，視為已準備完成 → 顯示
            self.isPreparing = false
            self.setVisible(true)
            self.onPrepared?()
            return
        }

        let action = pendingActions.removeFirst()
        switch action {
        case .js(let script):
            webView.evaluateJavaScript(script) { [weak self] _, _ in
                self?.executeNextAction()
            }

        case .wait(let seconds):
            DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { [weak self] in
                self?.executeNextAction()
            }

        case .navigate(let urlStr):
            if let url = URL(string: urlStr) {
                // 導航後不立刻往下執行，等下一次 didFinish 再繼續
                webView.load(URLRequest(url: url))
            } else {
                // URL 無效就跳過
                self.executeNextAction()
            }
        }
    }
}

// MARK: - Delegate
fileprivate class WebViewDelegate: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
    weak var owner: WebView_Provider?

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        owner?.handleDidFinish()
    }
    
    //相當於 Android shouldOverrideUrlLoading
    func webView(_ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        return nil
    }

    func webView(_ webView: WKWebView,
                 runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping () -> Void) {
        owner?.onJsAlert?(message)
        completionHandler()
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {}
}

// MARK: - SwiftUI 包裝
struct WebViewContainer: UIViewRepresentable {
    let webView: WKWebView
    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
