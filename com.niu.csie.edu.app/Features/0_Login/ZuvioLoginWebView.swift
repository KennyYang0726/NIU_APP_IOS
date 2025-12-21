import SwiftUI
import WebKit


// 小工具：把 [key: value] 轉成 x-www-form-urlencoded
private func formURLEncodedData(_ params: [String: String]) -> Data? {
    var comps = URLComponents()
    comps.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
    return comps.percentEncodedQuery?.data(using: .utf8)
}

struct ZuvioLoginWebView: UIViewRepresentable {
    let account: String
    let password: String
    let onResult: (Bool) -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onResult: onResult)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        // 初始化設定
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true  // iOS 14+ 啟用 JS
        config.websiteDataStore = .default()   // 支援 cookie / localStorage
                
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        // webView.uiDelegate = context.coordinator
        
        // === 組 POST Body（逐欄位編碼，與 Android URLEncoder 行為一致）===
        let encodedPwdB64 = Data(password.utf8).base64EncodedString()
        let params: [String: String] = [
            "email":             account,
            "password":          password,
            "encoded_password":  encodedPwdB64,
            "current_language":  "zh-TW"
        ]
        
        
        guard let body = formURLEncodedData(params) else {
            print("[Zuvio] 無法產生表單資料")
            return webView
        }
                
        // === 建立 POST 請求 ===
        var request = URLRequest(url: URL(string: "https://irs.zuvio.com.tw/irs/submitLogin")!)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        // 模擬瀏覽器更接近的行為
        request.setValue("zh-TW,zh;q=0.9", forHTTPHeaderField: "Accept-Language")
                
        // 送出
        webView.load(request)
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    
    class Coordinator: NSObject, WKNavigationDelegate {
        let onResult: (Bool) -> Void
        
        init(onResult: @escaping (Bool) -> Void) {
            self.onResult = onResult
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            let currentURL = webView.url?.absoluteString ?? ""
            print("[Zuvio] Loaded: \(currentURL)")
            if currentURL.contains("student5/irs/index") {
                onResult(true)
            } else {
                onResult(false)
            }
        }
    }
}

