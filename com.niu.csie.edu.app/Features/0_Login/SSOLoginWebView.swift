//
//  SSOLoginWebView.swift
//  Features/0_Login
//
//  新版 CCSYS1 SSO POST 登入流程
//
//  設計原則：
//  - 保留 UIViewRepresentable / Coordinator / AppSettings / onResult 架構
//  - 使用 JavaScript 攔截 fetch / XMLHttpRequest response
//  - 擷取 /SSO/API/Captcha/Generate 回應中的 CaptchaId 與 ImageBase64
//  - OCR 成功後，由 Swift 端 POST /SSO/API/Login
//  - 登入 API 成功後先停止 captcha / reload / POST pipeline，並 print Login API 回傳 token
//  - 登入 API 成功不代表整體登入完成；需等 /SSO/API/Authorization/info 回應並擷取 chName 後才回報 success
//  - 使用 activeAttemptID / isLoginCompleted / didReportResult 收斂非同步狀態
//  - 不使用 SweetAlert 作為主要登入結果判斷
//

import SwiftUI
import WebKit
import UIKit

// MARK: - SSO 登入結果

public enum SSOLoginResult {
    case success(name: String?)
    case credentialsFailed(message: String)
    case accountLocked(message: String)
    case passwordExpiring(message: String)
    case passwordExpired(message: String)
    case ssoUnauthorized(message: String)
    case systemError(message: String)
    case generic(title: String, message: String)
}

// MARK: - Captcha Session

private struct CaptchaSession {
    let captchaId: String
    let imageBase64: String
}

// MARK: - Network Response

private struct CapturedWebResponse {
    let url: String
    let body: String
    let method: String
    let status: Int

    var normalizedMethod: String {
        method.uppercased()
    }

    var isSuccessStatus: Bool {
        status >= 200 && status < 300
    }

    var isCaptchaGenerateResponse: Bool {
        url.contains("/SSO/API/Captcha/Generate") ||
        url.contains("SSO/API/Captcha/Generate") ||
        url.contains("Captcha/Generate")
    }

    var isLoginResponse: Bool {
        url.contains("/SSO/API/Login") ||
        url.contains("SSO/API/Login")
    }

    var isAuthorizationInfoResponse: Bool {
        url.contains("/SSO/API/Authorization/info") ||
        url.contains("SSO/API/Authorization/info") ||
        url.contains("Authorization/info")
    }
}

// MARK: - Captcha Response Parser

private enum CaptchaResponseParser {

    static func parse(_ body: String) -> CaptchaSession? {
        guard let data = body.data(using: .utf8) else {
            print("[SSO] Captcha response is not UTF-8")
            return nil
        }

        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                print("[SSO] Captcha response is not JSON object")
                return nil
            }

            guard let captchaId = json["CaptchaId"] as? String,
                  let imageBase64 = json["ImageBase64"] as? String,
                  !captchaId.isEmpty,
                  !imageBase64.isEmpty else {
                print("[SSO] CaptchaId or ImageBase64 missing")
                return nil
            }

            return CaptchaSession(
                captchaId: captchaId,
                imageBase64: imageBase64
            )
        } catch {
            print("[SSO] Captcha JSON parse error:", error.localizedDescription)
            return nil
        }
    }
}

// MARK: - Login API Parser

private enum SSOLoginAPIParser {

    enum ParsedResult {
        case success(token: String, exp: String?)
        case captchaError(message: String)
        case credentialsFailed(message: String)
        case accountLocked(message: String)
        case ssoUnauthorized(message: String)
        case passwordExpiring(message: String)
        case passwordExpired(message: String)
        case generic(title: String, message: String)
        case systemError(message: String)
    }

    static func jsonObject(from body: String) -> [String: Any]? {
        guard let data = body.data(using: .utf8) else {
            return nil
        }

        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    static func stringValue(
        in json: [String: Any],
        keys: [String]
    ) -> String? {
        for key in keys {
            if let value = json[key] as? String, !value.isEmpty {
                return value
            }
        }
        return nil
    }

    static func boolValue(
        in json: [String: Any],
        keys: [String]
    ) -> Bool? {
        for key in keys {
            if let value = json[key] as? Bool {
                return value
            }
        }
        return nil
    }

    static func nestedStringValue(
        in json: [String: Any],
        containerKeys: [String],
        valueKeys: [String]
    ) -> String? {
        for containerKey in containerKeys {
            guard let nested = json[containerKey] as? [String: Any] else {
                continue
            }

            if let value = stringValue(in: nested, keys: valueKeys) {
                return value
            }
        }

        return nil
    }

    static func extractToken(from body: String) -> String? {
        guard let json = jsonObject(from: body) else {
            return nil
        }

        let directKeys = [
            "token",
            "Token",
            "AccessToken",
            "accessToken",
            "access_token",
            "JWT",
            "jwt"
        ]

        if let value = stringValue(in: json, keys: directKeys) {
            return value
        }

        let nestedKeys = ["Data", "data", "Result", "result"]
        return nestedStringValue(
            in: json,
            containerKeys: nestedKeys,
            valueKeys: directKeys
        )
    }

    static func message(from json: [String: Any]) -> String {
        if let error = stringValue(in: json, keys: ["error", "Error"]) {
            return error
        }

        if let message = stringValue(in: json, keys: ["message", "Message", "title", "Title"]) {
            return message
        }

        if let errors = json["errors"] as? [String: Any] {
            let messages = errors.compactMap { _, value -> String? in
                if let list = value as? [String] {
                    return list.joined(separator: "、")
                }

                if let message = value as? String {
                    return message
                }

                return nil
            }

            if !messages.isEmpty {
                return messages.joined(separator: "、")
            }
        }

        return "登入失敗"
    }

    static func parse(statusCode: Int, body: String) -> ParsedResult {
        guard let json = jsonObject(from: body) else {
            if statusCode >= 500 {
                return .systemError(message: "SSO系統發生錯誤，請稍後再試")
            }

            return .generic(title: "登入失敗", message: body.isEmpty ? "登入回應格式無法解析" : body)
        }

        let message = message(from: json)
        let loweredMessage = message.lowercased()
        let loweredBody = body.lowercased()

        if message.contains("驗證碼") || loweredMessage.contains("captcha") || loweredBody.contains("captcha") {
            return .captchaError(message: message)
        }

        if let success = boolValue(in: json, keys: ["success", "Success"]), success == true {
            if let token = extractToken(from: body), !token.isEmpty {
                let exp = stringValue(in: json, keys: ["exp", "Exp"])
                return .success(token: token, exp: exp)
            }

            return .systemError(message: "登入成功但未取得token")
        }

        if message.contains("Unauthorized") ||
            loweredMessage.contains("unauthorized") ||
            message.contains("SSO 連線失敗") ||
            message.contains("SSO連線失敗") {
            return .ssoUnauthorized(message: message)
        }

        if message.contains("由於多次登入失敗") ||
            message.contains("暫時鎖定") ||
            message.contains("15 分鐘後再試") ||
            message.contains("15分鐘後再試") {
            return .accountLocked(message: message)
        }

        if message.contains("帳號或密碼錯誤") ||
            message.contains("帳號錯誤") ||
            message.contains("密碼錯誤") ||
            loweredMessage.contains("credential") {
            return .credentialsFailed(message: message)
        }

        if message.contains("您的密碼即將到期") {
            return .passwordExpiring(message: message)
        }

        if message.contains("密碼已滿180天") ||
            message.contains("密碼已到期") ||
            message.contains("密碼過期") {
            return .passwordExpired(message: message)
        }

        if statusCode >= 500 {
            return .systemError(message: message)
        }

        return .generic(title: "登入失敗", message: message)
    }
}

// MARK: - Authorization Info Parser

private enum AuthorizationInfoParser {

    static func chName(from body: String) -> String? {
        guard let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        if let data = json["data"] as? [String: Any],
           let chName = data["chName"] as? String,
           !chName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return chName.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let chName = json["chName"] as? String,
           !chName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return chName.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return nil
    }
}

// MARK: - JavaScript Factory

private enum SSOResponseInterceptorJS {

    static func source() -> String {
        return """
        (function() {
            if (window.__ssoResponseInterceptorInstalled) {
                return;
            }

            window.__ssoResponseInterceptorInstalled = true;

            function getSSOBearerToken() {
                try {
                    return localStorage.getItem('__ssoBearerToken') ||
                           sessionStorage.getItem('__ssoBearerToken') ||
                           localStorage.getItem('token') ||
                           sessionStorage.getItem('token') ||
                           localStorage.getItem('Token') ||
                           sessionStorage.getItem('Token') ||
                           localStorage.getItem('accessToken') ||
                           sessionStorage.getItem('accessToken') ||
                           localStorage.getItem('AccessToken') ||
                           sessionStorage.getItem('AccessToken') ||
                           '';
                } catch (e) {
                    return '';
                }
            }

            function shouldAttachAuthorization(url) {
                if (!url) return false;

                return url.includes('/SSO/API/') &&
                       !url.includes('/SSO/API/Captcha/Generate') &&
                       !url.includes('/SSO/API/Login');
            }

            function shouldCapture(url) {
                if (!url) return false;

                return url.includes('/SSO/API/Captcha/Generate') ||
                       url.includes('Captcha/Generate') ||
                       url.includes('/SSO/API/Login') ||
                       url.includes('SSO/API/Login') ||
                       url.includes('/SSO/API/Authorization/info') ||
                       url.includes('SSO/API/Authorization/info') ||
                       url.includes('Authorization/info');
            }

            function sendToSwift(url, body, method, status) {
                try {
                    if (!shouldCapture(url)) {
                        return;
                    }

                    window.webkit.messageHandlers.ssoResponseCatcher.postMessage({
                        url: url || '',
                        body: body || '',
                        method: method || '',
                        status: status || 0
                    });
                } catch (e) {}
            }

            const originalFetch = window.fetch;

            if (originalFetch) {
                window.fetch = function(input, init) {
                    const requestUrl =
                        (typeof input === 'string')
                            ? input
                            : (input && input.url ? input.url : '');

                    const requestMethod =
                        init && init.method
                            ? init.method
                            : (
                                input && input.method
                                    ? input.method
                                    : 'GET'
                              );

                    try {
                        const token = getSSOBearerToken();

                        if (token && shouldAttachAuthorization(requestUrl)) {
                            init = init || {};

                            const originalHeaders =
                                init.headers ||
                                (input && input.headers ? input.headers : {});

                            const headers = new Headers(originalHeaders);

                            if (!headers.has('authorization')) {
                                headers.set('Authorization', 'Bearer ' + token);
                            }

                            init.headers = headers;
                        }
                    } catch (e) {}

                    return originalFetch.apply(this, [input, init]).then(function(response) {
                        try {
                            const clonedResponse = response.clone();

                            clonedResponse.text()
                                .then(function(text) {
                                    sendToSwift(
                                        response.url || requestUrl,
                                        text,
                                        requestMethod,
                                        response.status
                                    );
                                })
                                .catch(function(_) {});
                        } catch (e) {}

                        return response;
                    });
                };
            }

            const originalOpen = XMLHttpRequest.prototype.open;
            const originalSend = XMLHttpRequest.prototype.send;

            XMLHttpRequest.prototype.open = function(method, url) {
                this.__ssoRequestMethod = method;
                this.__ssoRequestUrl = url;
                return originalOpen.apply(this, arguments);
            };

            XMLHttpRequest.prototype.send = function() {
                try {
                    const token = getSSOBearerToken();

                    if (token && shouldAttachAuthorization(this.__ssoRequestUrl || '')) {
                        this.setRequestHeader('Authorization', 'Bearer ' + token);
                    }
                } catch (e) {}

                this.addEventListener('load', function() {
                    try {
                        sendToSwift(
                            this.responseURL || this.__ssoRequestUrl || '',
                            this.responseText || '',
                            this.__ssoRequestMethod || '',
                            this.status || 0
                        );
                    } catch (e) {}
                });

                return originalSend.apply(this, arguments);
            };
        })();
        """
    }
}

// MARK: - Weak Script Message Delegate

private final class WeakScriptMessageDelegate: NSObject, WKScriptMessageHandler {

    weak var delegate: WKScriptMessageHandler?

    init(_ delegate: WKScriptMessageHandler) {
        self.delegate = delegate
        super.init()
    }

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        delegate?.userContentController(userContentController, didReceive: message)
    }
}

// MARK: - SSOLoginWebView

public struct SSOLoginWebView: UIViewRepresentable {

    public let account: String
    public let password: String
    public let onResult: (SSOLoginResult) -> Void

    @EnvironmentObject var settings: AppSettings

    public init(
        account: String,
        password: String,
        onResult: @escaping (SSOLoginResult) -> Void
    ) {
        self.account = account
        self.password = password
        self.onResult = onResult
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(settings: settings, parent: self)
    }

    public func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let contentController = WKUserContentController()

        let responseInterceptorScript = WKUserScript(
            source: SSOResponseInterceptorJS.source(),
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )

        contentController.addUserScript(responseInterceptorScript)
        contentController.add(
            WeakScriptMessageDelegate(context.coordinator),
            name: "ssoResponseCatcher"
        )

        config.userContentController = contentController
        config.websiteDataStore = .default()

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator

        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }

        context.coordinator.attach(webView)

        if let url = URL(string: "https://ccsys1.niu.edu.tw/SSO/login") {
            print("[SSO] Initial load:", url.absoluteString)
            webView.load(URLRequest(url: url))
        }

        return webView
    }

    public func updateUIView(_ uiView: WKWebView, context: Context) {}

    // MARK: - Coordinator

    public final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {

        private let settings: AppSettings
        private let parent: SSOLoginWebView
        private weak var webView: WKWebView?

        // 是否正在處理目前 captcha pipeline。
        private var isProcessingCaptcha = false

        // 每次 captcha / login 嘗試都遞增。
        // 所有非同步 callback 回來時都要比對 attemptID，避免舊 callback 汙染新流程。
        private var activeAttemptID: Int = 0

        // 已取得登入 API success/token，等待 Authorization/info 回應取得 chName。
        // 這段期間不重新 OCR、不 reload、不重新 POST。
        private var isWaitingForAuthorizationInfo = false

        // 登入成功或確定失敗後鎖定整個登入流程。
        private var isLoginCompleted = false

        // 避免 onResult 被多路徑重複呼叫。
        private var didReportResult = false

        // 集中管理 retry，避免多個 asyncAfter 疊在一起。
        private var retryWorkItem: DispatchWorkItem?

        // 同一輪 attempt 只允許 POST 一次。
        private var postedAttemptID: Int?

        // 目前 captcha session。
        private var captchaSession: CaptchaSession?

        // 避免 OCR / captcha 錯誤時無限制重試。
        private var captchaRetryCount = 0
        private let maxCaptchaRetryCount = 8

        // 等待 Authorization/info 的輪詢上限。
        // 正常情況會由網站自己發 GET 並被 JS 攔截；若沒有發出，Swift 端會補一個直接 GET。
        private var authorizationInfoCheckCount = 0
        private let maxAuthorizationInfoCheckCount = 20

        // 登入 API 回傳的 token。
        private var loginAPIToken: String?
        private var loginAPIExp: String?

        init(settings: AppSettings, parent: SSOLoginWebView) {
            self.settings = settings
            self.parent = parent
            super.init()
        }

        deinit {
            cleanupForDeinit()
        }

        func attach(_ webView: WKWebView) {
            self.webView = webView
        }

        // MARK: - WKNavigationDelegate

        public func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            let url = navigationAction.request.url?.absoluteString ?? ""
            print("[SSO][NAV]", "type:", navigationAction.navigationType.rawValue, "url:", url)
            decisionHandler(.allow)
        }

        public func webView(
            _ webView: WKWebView,
            didStartProvisionalNavigation navigation: WKNavigation!
        ) {
            print("[SSO] didStart:", webView.url?.absoluteString ?? "")
        }

        public func webView(
            _ webView: WKWebView,
            didCommit navigation: WKNavigation!
        ) {
            print("[SSO] didCommit:", webView.url?.absoluteString ?? "")
        }

        public func webView(
            _ webView: WKWebView,
            didFinish navigation: WKNavigation!
        ) {
            let urlStr = webView.url?.absoluteString ?? ""
            print("[SSO] didFinish:", urlStr)

            if isLoginCompleted {
                print("[SSO] Login completed, ignore didFinish:", urlStr)
                return
            }

            if isWaitingForAuthorizationInfo {
                print("[SSO] Waiting for Authorization/info, ignore didFinish:", urlStr)
                return
            }

            if isSystemErrorURL(urlStr) {
                print("[SSO] System error page detected")
                markLoginCompleted(reason: "system error")
                reportFailureIfNeeded(.systemError(message: "系統發生錯誤，請稍後再試"))
                return
            }

            if isLoginURL(urlStr) {
                if isProcessingCaptcha {
                    print("[SSO] didFinish on login page but captcha pipeline is running, skip re-entry")
                    return
                }

                // 正常情況由網頁自己呼叫 Captcha/Generate，JS 攔截後會進入 handleCaptchaGenerateResponse。
                // 若網頁沒有如預期送出 Captcha/Generate，Swift 端補打一個 POST 取得新 captcha。
                scheduleFreshCaptchaRequest(delay: 0.8, reason: "login page didFinish fallback")
                return
            }
        }

        public func webView(
            _ webView: WKWebView,
            didFail navigation: WKNavigation!,
            withError error: Error
        ) {
            print("[SSO] didFail:", error.localizedDescription)
        }

        public func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            print("[SSO] didFailProvisionalNavigation:", error.localizedDescription)
        }

        // MARK: - WKUIDelegate

        public func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            let url = navigationAction.request.url?.absoluteString ?? ""
            print("[SSO][CREATE_WEBVIEW]", url)

            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
            }

            return nil
        }

        // MARK: - WKScriptMessageHandler

        public func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard message.name == "ssoResponseCatcher" else {
                return
            }

            guard let response = makeCapturedResponse(from: message.body) else {
                return
            }

            routeCapturedResponse(response)
        }

        private func makeCapturedResponse(from body: Any) -> CapturedWebResponse? {
            guard let dict = body as? [String: Any] else {
                return nil
            }

            let url = dict["url"] as? String ?? ""
            let responseBody = dict["body"] as? String ?? ""
            let method = dict["method"] as? String ?? ""
            let status = dict["status"] as? Int ?? 0

            return CapturedWebResponse(
                url: url,
                body: responseBody,
                method: method,
                status: status
            )
        }

        private func routeCapturedResponse(_ response: CapturedWebResponse) {
            print("[SSO][CAPTURED]", response.normalizedMethod, response.status, response.url)

            if isLoginCompleted {
                print("[SSO] Login completed, ignore captured response:", response.url)
                return
            }

            if response.isAuthorizationInfoResponse {
                handleAuthorizationInfoResponse(response.body, statusCode: response.status, source: "captured")
                return
            }

            if isWaitingForAuthorizationInfo {
                print("[SSO] Waiting for Authorization/info, ignore non-info captured response:", response.url)
                return
            }

            if response.isCaptchaGenerateResponse {
                guard response.isSuccessStatus else {
                    print("[SSO] Captcha Generate failed, status:", response.status)
                    handleCaptchaRetry(reason: "captcha generate status \(response.status)", delay: 1.0)
                    return
                }

                handleCaptchaGenerateResponse(response.body, source: "captured")
                return
            }

            // WebView 自己送出的 Login response 只做備援判斷。
            // 主要登入 response 由 Swift URLSession 的 postLoginIfNeeded 處理。
            if response.isLoginResponse {
                print("[SSO] Captured Login response from WebView:", response.body)
                handleLoginAPIResult(
                    statusCode: response.status,
                    body: response.body,
                    attemptID: activeAttemptID,
                    source: "captured"
                )
                return
            }
        }

        // MARK: - Captcha Flow

        private func handleCaptchaGenerateResponse(_ body: String, source: String) {
            guard !isLoginCompleted else {
                print("[SSO] Ignore Captcha/Generate because login completed")
                return
            }

            guard !isWaitingForAuthorizationInfo else {
                print("[SSO] Ignore Captcha/Generate because waiting Authorization/info")
                return
            }

            guard let session = CaptchaResponseParser.parse(body) else {
                handleCaptchaRetry(reason: "captcha parse failed from \(source)", delay: 1.0)
                return
            }

            guard !isProcessingCaptcha else {
                print("[SSO] Captcha response received but captcha pipeline is running, skip")
                return
            }

            retryWorkItem?.cancel()
            retryWorkItem = nil

            activeAttemptID += 1
            let attemptID = activeAttemptID

            captchaSession = session
            postedAttemptID = nil

            print("[SSO] CaptchaSession updated #\(attemptID), source:", source)
            print("[SSO] Internal CaptchaId:", session.captchaId)
            print("[SSO] Internal Base64 length:", session.imageBase64.count)

            continueLoginFlowIfReady(attemptID: attemptID)
        }

        private func continueLoginFlowIfReady(attemptID: Int) {
            guard !isLoginCompleted else {
                print("[SSO] Login completed, skip captcha flow #\(attemptID)")
                return
            }

            guard !isWaitingForAuthorizationInfo else {
                print("[SSO] Waiting Authorization/info, skip captcha flow #\(attemptID)")
                return
            }

            guard !isProcessingCaptcha else {
                print("[SSO] Captcha flow already running, skip #\(attemptID)")
                return
            }

            guard attemptID == activeAttemptID else {
                print("[SSO] Ignore stale continueLoginFlow #\(attemptID)")
                return
            }

            guard let captchaSession else {
                print("[SSO] CaptchaSession not ready #\(attemptID)")
                return
            }

            isProcessingCaptcha = true

            print("[SSO] CaptchaSession ready #\(attemptID)")
            print("[SSO] Ready to continue login flow #\(attemptID)")

            let b64 = stripDataURLPrefix(captchaSession.imageBase64)

            guard let imgData = Data(base64Encoded: b64),
                  let image = UIImage(data: imgData) else {
                print("[SSO] Base64 → UIImage failed #\(attemptID)")
                isProcessingCaptcha = false
                handleCaptchaRetry(reason: "captcha UIImage decode failed", delay: 1.0)
                return
            }

            SSOCaptchaProcessor.shared.recognize(from: image) { [weak self] digits in
                guard let self = self else { return }

                DispatchQueue.main.async {
                    guard attemptID == self.activeAttemptID else {
                        print("[SSO] Ignore stale OCR callback #\(attemptID)")
                        return
                    }

                    guard !self.isLoginCompleted else {
                        print("[SSO] Login completed, ignore OCR callback #\(attemptID)")
                        return
                    }

                    guard !self.isWaitingForAuthorizationInfo else {
                        print("[SSO] Waiting Authorization/info, ignore OCR callback #\(attemptID)")
                        return
                    }

                    self.isProcessingCaptcha = false

                    if let code = digits, code.count == 6 {
                        print("[SSO] OCR OK → \(code) #\(attemptID)")
                        self.postLoginIfNeeded(captchaInput: code, attemptID: attemptID)
                    } else {
                        print("[SSO] OCR FAIL or not 6 digits #\(attemptID)")
                        self.handleCaptchaRetry(reason: "OCR failed", delay: 1.0)
                    }
                }
            }
        }

        // MARK: - Login POST

        private func postLoginIfNeeded(
            captchaInput: String,
            attemptID: Int
        ) {
            guard !isLoginCompleted else {
                print("[SSO] Login completed, skip postLogin #\(attemptID)")
                return
            }

            guard !isWaitingForAuthorizationInfo else {
                print("[SSO] Waiting Authorization/info, skip postLogin #\(attemptID)")
                return
            }

            guard attemptID == activeAttemptID else {
                print("[SSO] Ignore stale postLogin #\(attemptID)")
                return
            }

            guard postedAttemptID != attemptID else {
                print("[SSO] Already posted login for attempt #\(attemptID)")
                return
            }

            guard let captchaSession else {
                print("[SSO] CaptchaSession missing #\(attemptID)")
                handleCaptchaRetry(reason: "captcha session missing", delay: 1.0)
                return
            }

            guard let webView else {
                print("[SSO] WebView missing #\(attemptID)")
                markLoginCompleted(reason: "webView missing")
                reportFailureIfNeeded(.systemError(message: "登入元件初始化失敗"))
                return
            }

            postedAttemptID = attemptID

            guard let url = URL(string: "https://ccsys1.niu.edu.tw/SSO/API/Login") else {
                postedAttemptID = nil
                markLoginCompleted(reason: "login url invalid")
                reportFailureIfNeeded(.systemError(message: "登入網址錯誤"))
                return
            }

            let payload: [String: Any] = [
                "ACNT": parent.account,
                "Password": parent.password,
                "CaptchaId": captchaSession.captchaId,
                "CaptchaInput": captchaInput
            ]

            guard let body = try? JSONSerialization.data(withJSONObject: payload) else {
                postedAttemptID = nil
                markLoginCompleted(reason: "login payload encode failed")
                reportFailureIfNeeded(.systemError(message: "登入資料建立失敗"))
                return
            }

            if let bodyString = String(data: body, encoding: .utf8) {
                print("[SSO] Login payload JSON:", bodyString)
            }

            let store = webView.configuration.websiteDataStore.httpCookieStore

            store.getAllCookies { [weak self] cookies in
                guard let self = self else { return }

                DispatchQueue.main.async {
                    guard attemptID == self.activeAttemptID else {
                        print("[SSO] Ignore stale cookie callback #\(attemptID)")
                        return
                    }

                    guard !self.isLoginCompleted else {
                        print("[SSO] Login completed, ignore cookie callback #\(attemptID)")
                        return
                    }

                    guard !self.isWaitingForAuthorizationInfo else {
                        print("[SSO] Waiting Authorization/info, ignore cookie callback #\(attemptID)")
                        return
                    }

                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.httpBody = body
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
                    request.setValue("https://ccsys1.niu.edu.tw", forHTTPHeaderField: "Origin")
                    request.setValue("https://ccsys1.niu.edu.tw/SSO/login", forHTTPHeaderField: "Referer")

                    let cookieHeader = HTTPCookie.requestHeaderFields(with: cookies)
                    request.allHTTPHeaderFields?.merge(cookieHeader) { _, new in new }

                    print("[SSO] POST /SSO/API/Login #\(attemptID)")

                    URLSession.shared.dataTask(with: request) { data, response, error in
                        DispatchQueue.main.async {
                            guard attemptID == self.activeAttemptID else {
                                print("[SSO] Ignore stale login response #\(attemptID)")
                                return
                            }

                            guard !self.isLoginCompleted else {
                                print("[SSO] Login completed, ignore login response #\(attemptID)")
                                return
                            }

                            guard !self.isWaitingForAuthorizationInfo else {
                                print("[SSO] Already waiting Authorization/info, ignore duplicate login response #\(attemptID)")
                                return
                            }

                            if let error = error {
                                print("[SSO] Login API error:", error.localizedDescription)
                                self.postedAttemptID = nil
                                self.handleCaptchaRetry(reason: "login network error", delay: 1.0)
                                return
                            }

                            guard let http = response as? HTTPURLResponse else {
                                print("[SSO] Login API response is not HTTPURLResponse")
                                self.postedAttemptID = nil
                                self.markLoginCompleted(reason: "login response not HTTP")
                                self.reportFailureIfNeeded(.systemError(message: "登入回應異常"))
                                return
                            }

                            let responseBody = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                            print("[SSO] Login API status:", http.statusCode)
                            print("[SSO] Login API body:", responseBody)

                            self.handleLoginAPIResult(
                                statusCode: http.statusCode,
                                body: responseBody,
                                attemptID: attemptID,
                                source: "swift-urlsession"
                            )
                        }
                    }.resume()
                }
            }
        }

        // MARK: - Login Result Handling

        private func handleLoginAPIResult(
            statusCode: Int,
            body: String,
            attemptID: Int,
            source: String
        ) {
            guard attemptID == activeAttemptID else {
                print("[SSO] Ignore stale handleLoginAPIResult #\(attemptID), source:", source)
                return
            }

            guard !isLoginCompleted else {
                print("[SSO] Login completed, ignore handleLoginAPIResult #\(attemptID)")
                return
            }

            guard !isWaitingForAuthorizationInfo else {
                print("[SSO] Already waiting Authorization/info, ignore handleLoginAPIResult #\(attemptID)")
                return
            }

            let parsed = SSOLoginAPIParser.parse(statusCode: statusCode, body: body)

            switch parsed {
            case .success(let token, let exp):
                handleLoginAPISuccess(token: token, exp: exp, attemptID: attemptID)

            case .captchaError(let message):
                print("[SSO] Captcha error detected from Login API → retry with fresh captcha #\(attemptID):", message)
                postedAttemptID = nil
                isProcessingCaptcha = false
                captchaSession = nil
                handleCaptchaRetry(reason: "captcha error after login", delay: 0.8)

            case .credentialsFailed(let message):
                markLoginCompleted(reason: "credentials failed")
                reportFailureIfNeeded(.credentialsFailed(message: message))

            case .accountLocked(let message):
                markLoginCompleted(reason: "account locked")
                reportFailureIfNeeded(.accountLocked(message: message))

            case .ssoUnauthorized(let message):
                markLoginCompleted(reason: "sso unauthorized")
                reportFailureIfNeeded(.ssoUnauthorized(message: message))

            case .passwordExpiring(let message):
                markLoginCompleted(reason: "password expiring")
                reportFailureIfNeeded(.passwordExpiring(message: message))

            case .passwordExpired(let message):
                markLoginCompleted(reason: "password expired")
                reportFailureIfNeeded(.passwordExpired(message: message))

            case .systemError(let message):
                markLoginCompleted(reason: "system error from login api")
                reportFailureIfNeeded(.systemError(message: message))

            case .generic(let title, let message):
                markLoginCompleted(reason: "generic login api failure")
                reportFailureIfNeeded(.generic(title: title, message: message))
            }
        }

        private func handleLoginAPISuccess(
            token: String,
            exp: String?,
            attemptID: Int
        ) {
            guard attemptID == activeAttemptID else {
                print("[SSO] Ignore stale login API success #\(attemptID)")
                return
            }

            guard !isLoginCompleted else {
                print("[SSO] Login completed, ignore login API success #\(attemptID)")
                return
            }

            loginAPIToken = token
            loginAPIExp = exp

            SSOSession.shared.update(token: token, exp: exp)
            
            print("[SSO] Login API success token:", token)
            if let exp {
                print("[SSO] Login API token exp:", exp)
            }

            // 登入 API 成功後，停止 captcha / reload / POST pipeline。
            // 注意：這裡尚未 report success，需等待 Authorization/info 的 chName。
            isWaitingForAuthorizationInfo = true
            isProcessingCaptcha = false
            postedAttemptID = nil
            captchaSession = nil
            captchaRetryCount = 0
            retryWorkItem?.cancel()
            retryWorkItem = nil
            authorizationInfoCheckCount = 0

            injectLoginTokenAndLoadDashboard(token, attemptID: attemptID)
        }

        // MARK: - Authorization Info

        private func injectLoginTokenAndLoadDashboard(
            _ token: String,
            attemptID: Int
        ) {
            guard attemptID == activeAttemptID else {
                print("[SSO] Ignore stale inject token #\(attemptID)")
                return
            }

            guard let webView else {
                requestAuthorizationInfoDirectly(attemptID: attemptID)
                return
            }

            let escapedToken = escapeForJavaScriptString(token)

            let js = """
            (function() {
                var token = '\(escapedToken)';

                try { localStorage.setItem('__ssoBearerToken', token); } catch (e) {}
                try { sessionStorage.setItem('__ssoBearerToken', token); } catch (e) {}

                try { localStorage.setItem('token', token); } catch (e) {}
                try { sessionStorage.setItem('token', token); } catch (e) {}
                try { localStorage.setItem('Token', token); } catch (e) {}
                try { sessionStorage.setItem('Token', token); } catch (e) {}
                try { localStorage.setItem('accessToken', token); } catch (e) {}
                try { sessionStorage.setItem('accessToken', token); } catch (e) {}
                try { localStorage.setItem('AccessToken', token); } catch (e) {}
                try { sessionStorage.setItem('AccessToken', token); } catch (e) {}
                try { localStorage.setItem('Authorization', 'Bearer ' + token); } catch (e) {}
                try { sessionStorage.setItem('Authorization', 'Bearer ' + token); } catch (e) {}

                window.location.replace('https://ccsys1.niu.edu.tw/SSO/dashboard/student');

                return JSON.stringify({ ok: true, href: location.href });
            })();
            """

            evaluateJS(webView, js, "injectLoginTokenAndLoadDashboard") { [weak self] val in
                guard let self = self else { return }

                guard attemptID == self.activeAttemptID else {
                    print("[SSO] Ignore stale inject token callback #\(attemptID)")
                    return
                }

                guard !self.isLoginCompleted else {
                    print("[SSO] Login completed, ignore inject token callback #\(attemptID)")
                    return
                }

                print("[SSO] token injected → dashboard, result:", val ?? "nil")

                // 等網站自己對 /SSO/API/Authorization/info 發 GET；若沒捕捉到，補打一個直接 GET。
                self.scheduleAuthorizationInfoFallbackCheck(attemptID: attemptID, delay: 0.8)
            }
        }

        private func scheduleAuthorizationInfoFallbackCheck(attemptID: Int, delay: TimeInterval) {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self = self else { return }

                guard attemptID == self.activeAttemptID else {
                    print("[SSO] Ignore stale Authorization/info fallback #\(attemptID)")
                    return
                }

                guard !self.isLoginCompleted else {
                    print("[SSO] Login completed, skip Authorization/info fallback #\(attemptID)")
                    return
                }

                guard self.isWaitingForAuthorizationInfo else {
                    print("[SSO] Not waiting Authorization/info, skip fallback #\(attemptID)")
                    return
                }

                self.authorizationInfoCheckCount += 1
                print("[SSO] Waiting Authorization/info:", self.authorizationInfoCheckCount, "/", self.maxAuthorizationInfoCheckCount)

                if self.authorizationInfoCheckCount == 3 {
                    self.requestAuthorizationInfoDirectly(attemptID: attemptID)
                }

                if self.authorizationInfoCheckCount < self.maxAuthorizationInfoCheckCount {
                    self.scheduleAuthorizationInfoFallbackCheck(attemptID: attemptID, delay: 0.5)
                    return
                }

                self.markLoginCompleted(reason: "Authorization/info timeout")
                self.reportFailureIfNeeded(.generic(
                    title: "登入失敗",
                    message: "已完成登入，但無法取得使用者資料"
                ))
            }
        }

        private func requestAuthorizationInfoDirectly(attemptID: Int) {
            guard attemptID == activeAttemptID else {
                print("[SSO] Ignore stale direct Authorization/info request #\(attemptID)")
                return
            }

            guard !isLoginCompleted else {
                print("[SSO] Login completed, skip direct Authorization/info request #\(attemptID)")
                return
            }

            guard isWaitingForAuthorizationInfo else {
                print("[SSO] Not waiting Authorization/info, skip direct request #\(attemptID)")
                return
            }

            guard let token = loginAPIToken,
                  let url = URL(string: "https://ccsys1.niu.edu.tw/SSO/API/Authorization/info") else {
                print("[SSO] Missing login token or Authorization/info URL")
                return
            }

            guard let webView else {
                print("[SSO] WebView missing for Authorization/info direct request")
                return
            }

            let store = webView.configuration.websiteDataStore.httpCookieStore

            store.getAllCookies { [weak self] cookies in
                guard let self = self else { return }

                DispatchQueue.main.async {
                    guard attemptID == self.activeAttemptID else {
                        print("[SSO] Ignore stale Authorization/info cookie callback #\(attemptID)")
                        return
                    }

                    guard !self.isLoginCompleted else {
                        print("[SSO] Login completed, ignore Authorization/info cookie callback #\(attemptID)")
                        return
                    }

                    var request = URLRequest(url: url)
                    request.httpMethod = "GET"
                    request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
                    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                    request.setValue("https://ccsys1.niu.edu.tw/SSO/dashboard/student", forHTTPHeaderField: "Referer")

                    let cookieHeader = HTTPCookie.requestHeaderFields(with: cookies)
                    request.allHTTPHeaderFields?.merge(cookieHeader) { _, new in new }

                    print("[SSO] Direct GET /SSO/API/Authorization/info #\(attemptID)")

                    URLSession.shared.dataTask(with: request) { data, response, error in
                        DispatchQueue.main.async {
                            guard attemptID == self.activeAttemptID else {
                                print("[SSO] Ignore stale direct Authorization/info response #\(attemptID)")
                                return
                            }

                            guard !self.isLoginCompleted else {
                                print("[SSO] Login completed, ignore direct Authorization/info response #\(attemptID)")
                                return
                            }

                            if let error = error {
                                print("[SSO] Direct Authorization/info error:", error.localizedDescription)
                                return
                            }

                            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                            let responseBody = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""

                            print("[SSO] Direct Authorization/info status:", statusCode)
                            print("[SSO] Direct Authorization/info body:", responseBody)

                            self.handleAuthorizationInfoResponse(
                                responseBody,
                                statusCode: statusCode,
                                source: "swift-urlsession"
                            )
                        }
                    }.resume()
                }
            }
        }

        private func handleAuthorizationInfoResponse(
            _ body: String,
            statusCode: Int,
            source: String
        ) {
            guard !isLoginCompleted else {
                print("[SSO] Login completed, ignore Authorization/info response from", source)
                return
            }

            guard isWaitingForAuthorizationInfo else {
                print("[SSO] Not waiting Authorization/info, ignore response from", source)
                return
            }

            print("[SSO] Authorization/info status:", statusCode, "source:", source)
            print("[SSO] Authorization/info body:", body)

            guard statusCode >= 200 && statusCode < 300 else {
                print("[SSO] Authorization/info status not success:", statusCode)
                return
            }

            guard let name = AuthorizationInfoParser.chName(from: body) else {
                print("[SSO] Authorization/info chName not found")
                return
            }

            print("[SSO] Authorization/info chName:", name)
            settings.name = name

            markLoginCompleted(reason: "Authorization/info chName received")
            reportSuccessIfNeeded(name: name)
        }

        // MARK: - Captcha Retry / Direct Generate

        private func handleCaptchaRetry(reason: String, delay: TimeInterval) {
            guard !isLoginCompleted else {
                print("[SSO] Login completed, skip retry. reason:", reason)
                return
            }

            guard !isWaitingForAuthorizationInfo else {
                print("[SSO] Waiting Authorization/info, skip retry. reason:", reason)
                return
            }

            captchaRetryCount += 1
            print("[SSO] Captcha retry reason: \(reason), count: \(captchaRetryCount)/\(maxCaptchaRetryCount)")

            guard captchaRetryCount <= maxCaptchaRetryCount else {
                print("[SSO] Captcha retry limit reached")
                markLoginCompleted(reason: "captcha retry limit reached")
                reportFailureIfNeeded(.generic(title: "登入失敗", message: "驗證碼辨識失敗，請稍後再試"))
                return
            }

            activeAttemptID += 1
            isProcessingCaptcha = false
            postedAttemptID = nil
            captchaSession = nil

            scheduleFreshCaptchaRequest(delay: delay, reason: reason)
        }

        private func scheduleFreshCaptchaRequest(delay: TimeInterval, reason: String) {
            guard !isLoginCompleted else {
                print("[SSO] Login completed, skip fresh captcha request scheduling")
                return
            }

            guard !isWaitingForAuthorizationInfo else {
                print("[SSO] Waiting Authorization/info, skip fresh captcha request scheduling")
                return
            }

            retryWorkItem?.cancel()

            let work = DispatchWorkItem { [weak self] in
                guard let self = self else { return }

                guard !self.isLoginCompleted else {
                    print("[SSO] Login completed, skip fresh captcha request")
                    return
                }

                guard !self.isWaitingForAuthorizationInfo else {
                    print("[SSO] Waiting Authorization/info, skip fresh captcha request")
                    return
                }

                guard !self.isProcessingCaptcha else {
                    print("[SSO] Captcha pipeline running, skip direct generate")
                    return
                }

                print("[SSO] Request fresh captcha. reason:", reason)
                self.requestCaptchaGenerateByPOST()
            }

            retryWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
        }

        private func requestCaptchaGenerateByPOST() {
            guard !isLoginCompleted else {
                print("[SSO] Login completed, skip Captcha/Generate POST")
                return
            }

            guard !isWaitingForAuthorizationInfo else {
                print("[SSO] Waiting Authorization/info, skip Captcha/Generate POST")
                return
            }

            guard let url = URL(string: "https://ccsys1.niu.edu.tw/SSO/API/Captcha/Generate") else {
                handleCaptchaRetry(reason: "captcha generate url invalid", delay: 1.0)
                return
            }

            guard let webView else {
                handleCaptchaRetry(reason: "webView missing for captcha generate", delay: 1.0)
                return
            }

            let store = webView.configuration.websiteDataStore.httpCookieStore

            store.getAllCookies { [weak self] cookies in
                guard let self = self else { return }

                DispatchQueue.main.async {
                    guard !self.isLoginCompleted else {
                        print("[SSO] Login completed, ignore Captcha/Generate cookie callback")
                        return
                    }

                    guard !self.isWaitingForAuthorizationInfo else {
                        print("[SSO] Waiting Authorization/info, ignore Captcha/Generate cookie callback")
                        return
                    }

                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("https://ccsys1.niu.edu.tw", forHTTPHeaderField: "Origin")
                    request.setValue("https://ccsys1.niu.edu.tw/SSO/login", forHTTPHeaderField: "Referer")

                    let cookieHeader = HTTPCookie.requestHeaderFields(with: cookies)
                    request.allHTTPHeaderFields?.merge(cookieHeader) { _, new in new }

                    print("[SSO] POST /SSO/API/Captcha/Generate")

                    URLSession.shared.dataTask(with: request) { data, response, error in
                        DispatchQueue.main.async {
                            guard !self.isLoginCompleted else {
                                print("[SSO] Login completed, ignore Captcha/Generate response")
                                return
                            }

                            guard !self.isWaitingForAuthorizationInfo else {
                                print("[SSO] Waiting Authorization/info, ignore Captcha/Generate response")
                                return
                            }

                            if let error = error {
                                print("[SSO] Captcha/Generate API error:", error.localizedDescription)
                                self.scheduleReloadLoginPage(delay: 1.0)
                                return
                            }

                            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                            let responseBody = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""

                            print("[SSO] Captcha/Generate status:", statusCode)
                            print("[SSO] Captcha/Generate body:", responseBody)

                            guard statusCode >= 200 && statusCode < 300 else {
                                self.scheduleReloadLoginPage(delay: 1.0)
                                return
                            }

                            self.handleCaptchaGenerateResponse(responseBody, source: "swift-urlsession")
                        }
                    }.resume()
                }
            }
        }

        private func scheduleReloadLoginPage(delay: TimeInterval) {
            guard !isLoginCompleted else {
                print("[SSO] Login completed, skip reload scheduling")
                return
            }

            guard !isWaitingForAuthorizationInfo else {
                print("[SSO] Waiting Authorization/info, skip reload scheduling")
                return
            }

            retryWorkItem?.cancel()

            let work = DispatchWorkItem { [weak self] in
                guard let self = self else { return }

                guard !self.isLoginCompleted else {
                    print("[SSO] Login completed, skip reload")
                    return
                }

                guard !self.isWaitingForAuthorizationInfo else {
                    print("[SSO] Waiting Authorization/info, skip reload")
                    return
                }

                print("[SSO] Reload SSO login page for retry")

                self.activeAttemptID += 1
                self.isProcessingCaptcha = false
                self.postedAttemptID = nil
                self.captchaSession = nil

                if let url = URL(string: "https://ccsys1.niu.edu.tw/SSO/login") {
                    self.webView?.load(URLRequest(url: url))
                }
            }

            retryWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
        }

        // MARK: - Completion State

        private func markLoginCompleted(reason: String) {
            if isLoginCompleted {
                return
            }

            print("[SSO] Mark login completed:", reason)

            isLoginCompleted = true
            isWaitingForAuthorizationInfo = false
            isProcessingCaptcha = false
            postedAttemptID = nil
            captchaSession = nil

            retryWorkItem?.cancel()
            retryWorkItem = nil

            captchaRetryCount = 0
            authorizationInfoCheckCount = 0
        }

        private func reportSuccessIfNeeded(name: String?) {
            guard !didReportResult else {
                print("[SSO] Result already reported, skip duplicate success")
                return
            }

            didReportResult = true
            parent.onResult(.success(name: name))
        }

        private func reportFailureIfNeeded(_ result: SSOLoginResult) {
            guard !didReportResult else {
                print("[SSO] Result already reported, skip duplicate failure")
                return
            }

            didReportResult = true
            parent.onResult(result)
        }

        private func cleanupForDeinit() {
            retryWorkItem?.cancel()
            retryWorkItem = nil

            isLoginCompleted = true
            isWaitingForAuthorizationInfo = false
            isProcessingCaptcha = false
            postedAttemptID = nil
            captchaSession = nil
            activeAttemptID += 1

            webView?.stopLoading()
            webView?.navigationDelegate = nil
            webView?.uiDelegate = nil
            webView?.configuration.userContentController.removeScriptMessageHandler(forName: "ssoResponseCatcher")

            print("[SSO] Coordinator deinit, cleanup completed")
        }

        // MARK: - JS helpers

        private func evaluateJS(
            _ webView: WKWebView,
            _ js: String,
            _ note: String,
            completion: @escaping (Any?) -> Void
        ) {
            DispatchQueue.main.async {
                webView.evaluateJavaScript(js) { result, error in
                    if let error = error {
                        print("[SSO][JS ERR][\(note)]", error.localizedDescription)
                        completion(nil)
                    } else {
                        completion(result)
                    }
                }
            }
        }

        // MARK: - URL Helpers

        private func isLoginURL(_ url: String) -> Bool {
            url.contains("ccsys1.niu.edu.tw/SSO/login") ||
            url.contains("/SSO/login")
        }

        private func isSystemErrorURL(_ url: String) -> Bool {
            url.contains("error.html")
        }

        // MARK: - Misc Helpers

        private func stripDataURLPrefix(_ value: String) -> String {
            if let range = value.range(of: "base64,") {
                return String(value[range.upperBound...])
            }

            if let range = value.range(of: ",") {
                return String(value[range.upperBound...])
            }

            return value
        }

        private func escapeForJavaScriptString(_ value: String) -> String {
            value
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "\\'")
                .replacingOccurrences(of: "\n", with: "\\n")
                .replacingOccurrences(of: "\r", with: "\\r")
                .replacingOccurrences(of: "\u{2028}", with: "\\u2028")
                .replacingOccurrences(of: "\u{2029}", with: "\\u2029")
        }
    }
}

