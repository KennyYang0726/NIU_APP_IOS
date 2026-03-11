import SwiftUI
import WebKit



struct MailLoginWebView: UIViewRepresentable {

    let account: String
    let password: String
    let onResult: (Bool) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self, onResult: onResult)
    }

    func makeUIView(context: Context) -> WKWebView {
        // 初始化設定
        let config = AppWebViewEnvironment.shared.makeConfiguration()

        // 註冊 message handler
        config.userContentController.add(context.coordinator, name: "svgHandler")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator

        // 初始載入登入頁面
        if let url = URL(string: "https://mail.niu.edu.tw/NUMail/Login") {
            webView.load(URLRequest(url: url))
        }

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        // 移除 handler，避免 retain cycle
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: "svgHandler")
    }

    // MARK: - Coordinator
    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {

        private let parent: MailLoginWebView
        weak var currentWebView: WKWebView?

        /// 是否正在等待 captcha / 登入狀態
        private var isProcessingCaptcha = false

        /// 是否已經回報過結果（成功或失敗）
        /// 用來保證 onResult 只會被呼叫一次
        private var hasReportedResult = false

        /// 是否已經啟動過 observer（避免重複注入 JS）
        private var hasStartedObserver = false

        /// 是否正在等待 Inbox 完全 ready
        private var isWaitingForInboxReady = false

        /// 真正 Inbox URL
        private let inboxURL = "https://mail.niu.edu.tw/NUMail/Mobile/Box/INBOX"

        let onResult: (Bool) -> Void

        init(parent: MailLoginWebView, onResult: @escaping (Bool) -> Void) {
            self.parent = parent
            self.onResult = onResult
        }

        // MARK: - WKNavigationDelegate
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            currentWebView = webView
            let currentURL = webView.url?.absoluteString ?? ""
            print("[Mail] Loaded: \(currentURL)")

            // - observer 只需要啟動一次
            // - 不論後面怎麼 Login → Inbox → Login redirect，都不再重跑
            if !hasStartedObserver, currentURL.contains("NUMail/Login") {
                hasStartedObserver = true
                Login_Mail(in: webView)
                return
            }

            // 如果正在等待 Inbox ready
            if isWaitingForInboxReady && currentURL.contains("Box/INBOX") {
                waitUntilInboxReady(in: webView)
            }
        }

        // MARK: - JS helpers
        private func evaluateJS(
            _ webView: WKWebView,
            _ js: String,
            _ note: String,
            completion: @escaping (Any?) -> Void
        ) {
            webView.evaluateJavaScript(js) { result, error in
                if let error = error {
                    print("[Mail][JS ERR][\(note)] \(error.localizedDescription)")
                    completion(nil)
                } else {
                    completion(result)
                }
            }
        }

        // MARK: - 登入流程主體（狀態 observer 版本）
        private func Login_Mail(in webView: WKWebView) {
            guard !isProcessingCaptcha else { return }
            isProcessingCaptcha = true

            print("[Mail] Login_Mail: begin state observer")

            let js = """
            (function() {
              function check() {

                if (location.href.includes('INBOX')) {
                  window.webkit.messageHandlers.svgHandler.postMessage('__LOGGED_IN__');
                  return;
                }

                var svg = document.querySelector('div.sc-pbMuv.dlAzQm svg');
                if (svg) {
                  window.webkit.messageHandlers.svgHandler.postMessage(svg.outerHTML);
                }
              }

              check();

              var obs = new MutationObserver(function() {
                check();
              });

              obs.observe(document.documentElement, {
                childList: true,
                subtree: true
              });
            })();
            """

            evaluateJS(webView, js, "mail state observer") { _ in }

            DispatchQueue.main.asyncAfter(deadline: .now() + 7) {
                if self.isProcessingCaptcha {
                    print("[Mail] observer timeout")
                    self.finish(success: false)
                }
            }
        }

        // MARK: - 接收 JS 回傳
        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard message.name == "svgHandler" else { return }
            guard !hasReportedResult else { return }

            if let text = message.body as? String {

                // 已登入（cookie 有效）
                if text == "__LOGGED_IN__" {
                    print("[Mail] already logged in via redirect")
                    beginInboxWarmup(loadInboxIfNeeded: false)
                    return
                }

                // 收到 captcha SVG
                print("[Mail] captcha svg received")
                let captchaText = MailCaptchaProcessor.solveCaptcha(text)
                isProcessingCaptcha = false
                loginRequest(captcha: captchaText)
            }
        }

        // MARK: - 統一完成出口（核心）
        private func finish(success: Bool) {
            guard !hasReportedResult else { return }
            hasReportedResult = true
            isProcessingCaptcha = false
            onResult(success)
        }

        // MARK: - 等價 OkHttp 登入 API
        private func loginRequest(captcha: String) {
            guard let webView = currentWebView else {
                finish(success: false)
                return
            }

            let store = webView.configuration.websiteDataStore.httpCookieStore

            store.getAllCookies { cookies in
                guard let xsrf = cookies.first(where: { $0.name == "XSRF-TOKEN" })?.value else {
                    print("[Mail] 缺少 XSRF-TOKEN")
                    self.finish(success: false)
                    return
                }
                self.performLogin(cookies: cookies, xsrf: xsrf, captcha: captcha)
            }
        }

        private func performLogin(
            cookies: [HTTPCookie],
            xsrf: String,
            captcha: String
        ) {
            guard let url = URL(string: "https://mail.niu.edu.tw/api/auth/login") else {
                finish(success: false)
                return
            }

            let payload: [String: Any] = [
                "username": parent.account,
                "password": Data(parent.password.utf8).base64EncodedString(),
                "captcha": captcha
            ]

            let body = try! JSONSerialization.data(withJSONObject: payload)

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.httpBody = body

            request.setValue("application/json;charset=UTF-8", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
            request.setValue("https://mail.niu.edu.tw", forHTTPHeaderField: "Origin")
            request.setValue("https://mail.niu.edu.tw/NUMail/Login", forHTTPHeaderField: "Referer")
            request.setValue(xsrf, forHTTPHeaderField: "X-XSRF-TOKEN")

            let cookieHeader = HTTPCookie.requestHeaderFields(with: cookies)
            request.allHTTPHeaderFields?.merge(cookieHeader) { _, new in new }

            URLSession.shared.dataTask(with: request) { _, response, error in

                if let error = error {
                    print("[Mail] login error:", error)
                    self.finish(success: false)
                    return
                }

                guard let http = response as? HTTPURLResponse else {
                    self.finish(success: false)
                    return
                }

                if http.statusCode == 200 {
                    print("[Mail] login success")

                    guard
                        let webView = self.currentWebView,
                        let url = response?.url,
                        let headers = http.allHeaderFields as? [String: String]
                    else {
                        self.finish(success: false)
                        return
                    }

                    let newCookies = HTTPCookie.cookies(withResponseHeaderFields: headers, for: url)
                    let store = webView.configuration.websiteDataStore.httpCookieStore
                    let group = DispatchGroup()

                    for cookie in newCookies {
                        group.enter()
                        store.setCookie(cookie) {
                            group.leave()
                        }
                    }

                    group.notify(queue: .main) {
                        print("[Mail] cookies synced → load inbox")
                        self.beginInboxWarmup(loadInboxIfNeeded: true)
                    }
                } else {
                    print("[Mail] login failed:", http.statusCode)
                    self.finish(success: false)
                }

            }.resume()
        }

        // MARK: - 開始等待 Inbox 完整 ready
        private func beginInboxWarmup(loadInboxIfNeeded: Bool) {

            guard !hasReportedResult else { return }
            guard let webView = currentWebView else {
                finish(success: false)
                return
            }

            isWaitingForInboxReady = true

            if loadInboxIfNeeded {
                webView.load(URLRequest(url: URL(string: inboxURL)!))
            } else {
                let currentURL = webView.url?.absoluteString ?? ""
                if currentURL.contains("Box/INBOX") {
                    waitUntilInboxReady(in: webView)
                } else {
                    webView.load(URLRequest(url: URL(string: inboxURL)!))
                }
            }
        }

        // MARK: - 等待 Inbox DOM + session 完整
        private func waitUntilInboxReady(in webView: WKWebView, retry: Int = 0) {

            guard !hasReportedResult else { return }

            verifyMailSession { authOK in

                guard authOK else {
                    self.retryInboxReady(webView: webView, retry: retry)
                    return
                }

                self.verifyInboxDOMReady(in: webView) { domReady in

                    guard domReady else {
                        self.retryInboxReady(webView: webView, retry: retry)
                        return
                    }

                    print("[Mail] inbox fully ready")

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                        self.finish(success: true)
                    }
                }
            }
        }

        // MARK: - 驗證 /api/auth/user
        private func verifyMailSession(completion: @escaping (Bool) -> Void) {

            guard let webView = currentWebView else {
                completion(false)
                return
            }

            let store = webView.configuration.websiteDataStore.httpCookieStore

            store.getAllCookies { cookies in

                guard let url = URL(string: "https://mail.niu.edu.tw/api/auth/user") else {
                    completion(false)
                    return
                }

                var request = URLRequest(url: url)
                request.httpMethod = "GET"

                let cookieHeader = HTTPCookie.requestHeaderFields(with: cookies)
                request.allHTTPHeaderFields = cookieHeader

                if let xsrf = cookies.first(where: { $0.name == "XSRF-TOKEN" })?.value {
                    request.setValue(xsrf, forHTTPHeaderField: "x-xsrf-token")
                }

                URLSession.shared.dataTask(with: request) { _, response, _ in

                    guard let http = response as? HTTPURLResponse else {
                        completion(false)
                        return
                    }

                    completion(http.statusCode == 200)

                }.resume()
            }
        }

        // MARK: - DOM 是否為 Inbox
        private func verifyInboxDOMReady(in webView: WKWebView, completion: @escaping (Bool) -> Void) {

            let js = """
            (function() {
                try {
                    var allTexts = Array.from(document.querySelectorAll('span, li span'))
                        .map(function(el) { return (el.innerText || '').trim(); })
                        .join('|');

                    var hasLogout = allTexts.includes('登出');
                    var hasReturnDesktop = allTexts.includes('返回電腦版');
                    var hasCaptcha = !!document.querySelector('div.sc-pbMuv.dlAzQm svg');
                    var hasPasswordInput = !!document.querySelector('input[type="password"]');
                    var isLoginPage = hasCaptcha || hasPasswordInput || location.href.includes('NUMail/Login');

                    return (!isLoginPage) && (hasLogout || hasReturnDesktop);
                } catch (e) {
                    return false;
                }
            })();
            """

            webView.evaluateJavaScript(js) { result, _ in
                completion((result as? Bool) == true)
            }
        }

        private func retryInboxReady(webView: WKWebView, retry: Int) {

            if retry < 10 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    self.waitUntilInboxReady(in: webView, retry: retry + 1)
                }
            } else {
                print("[Mail] inbox ready timeout")
                self.finish(success: false)
            }
        }
    }
}
