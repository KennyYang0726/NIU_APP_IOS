//
//  SSOLoginWebView.swift
//  Features/0_Login
//
//  對應 Android: SSO_LoginPart.java
//  說明：
//   - SwiftUI WebView 登入流程仿照 Android 登入邏輯
//   - 使用 Vision OCR（封裝在 SSOCaptchaProcessor）
//   - 判定成功條件：URL 是否包含 “StdMain.aspx”
//   - 其他情況（AccountLock, error.html）均視為登入失敗
//   - iOS 最低版本：16.0
//

import SwiftUI
import WebKit
import UIKit



// MARK: - 小工具：將 Dictionary 轉成 x-www-form-urlencoded
private func sso_percentEncodeForm(_ string: String) -> String {
    // 按 x-www-form-urlencoded 習慣，用一組較「嚴格」的 allowed set
    var allowed = CharacterSet.alphanumerics
    allowed.insert(charactersIn: "-._* ")  // 保留 - . _ * 與空白（稍後把空白換成 '+')
    // 不把 '+' 放在 allowed 裡，確保會被編碼成 %2B

    let encoded = string.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
    return encoded.replacingOccurrences(of: " ", with: "+")
}

// 以「有序」的 (key, value) 陣列，產生 x-www-form-urlencoded Data
private func sso_formURLEncodedDataOrdered(_ items: [(String, String)]) -> Data? {
    let pairs = items.map { key, value in
        "\(sso_percentEncodeForm(key))=\(sso_percentEncodeForm(value))"
    }
    let bodyString = pairs.joined(separator: "&")
    return bodyString.data(using: .utf8)
}

// MARK: - SSO 登入結果
public enum SSOLoginResult {
    case success
    case credentialsFailed(message: String)
    case passwordExpiring(message: String)
    case passwordExpired(message: String)
    case accountLocked(lockTime: String?)
    case systemError
    case generic(title: String, message: String)
}

public struct SSOLoginWebView: UIViewRepresentable {

    public let account: String
    public let password: String
    public let onResult: (SSOLoginResult) -> Void

    @EnvironmentObject var settings: AppSettings // 為了寫入 姓名

    public init(account: String, password: String, onResult: @escaping (SSOLoginResult) -> Void) {
        self.account = account
        self.password = password
        self.onResult = onResult
    }

    public func makeCoordinator() -> Coordinator {
        // 關鍵：把需要的依賴直接注入給 Coordinator
        Coordinator(settings: settings, parent: self)
    }

    public func makeUIView(context: Context) -> WKWebView {
        // 初始化設定
        let config = AppWebViewEnvironment.shared.makeConfiguration()

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator

        // 初始載入登入頁面
        if let url = URL(string: "https://ccsys.niu.edu.tw/SSO/Default.aspx") {
            webView.load(URLRequest(url: url))
        }

        return webView
    }

    public func updateUIView(_ uiView: WKWebView, context: Context) {}

    // MARK: - Coordinator
    public class Coordinator: NSObject, WKNavigationDelegate {
        private let settings: AppSettings
        private let parent: SSOLoginWebView

        // 是否正在處理當前 captcha pipeline
        private var isProcessingCaptcha = false

        // 修正重點：
        // 每次 Login_SSO 啟動時都產生新的 attemptID。
        // 所有非同步 callback 回來時都要先比對 attemptID，
        // 不是最新那一輪的 callback 一律忽略，避免舊流程踩到新流程。
        private var activeAttemptID: Int = 0

        // 紀錄哪一輪 attempt 已經真的送出 POST。
        // 目的不是全域只送一次，而是「同一輪 attempt 只能送一次」。
        private var postedAttemptID: Int? = nil

        // 集中管理 retry，避免多個 asyncAfter 疊在一起。
        private var retryWorkItem: DispatchWorkItem?

        init(settings: AppSettings, parent: SSOLoginWebView) {
            self.settings = settings
            self.parent = parent
        }

        deinit {
            retryWorkItem?.cancel()
        }

        // MARK: - WKNavigationDelegate
        public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            let urlStr = webView.url?.absoluteString ?? ""
            print("[SSO] didFinish: \(urlStr)")

            // === URL 判斷邏輯 ===
            if urlStr.contains("StdMain.aspx") {
                retryWorkItem?.cancel()
                retryWorkItem = nil
                isProcessingCaptcha = false

                print("[SSO] Login success → onResult(.success)")
                // 網頁擷取姓名，再將姓名儲存於 sp
                let GetNameJS = """
                (function() {
                    var span = document.getElementById('Label1');
                    if (!span) return '';
                    var text = span.innerText || span.textContent;
                    var match = text.match(/姓名：([^<]+)/);
                    return match ? match[1].trim() : '';
                })();
                """
                webView.evaluateJavaScript(GetNameJS) { result, error in
                    if let name = result as? String {
                        // 儲存到 UserDefaults (iOS 相當於 Android 的 SharedPreferences)
                        self.settings.name = name
                        // print("Name: \(name)")
                    }
                    self.parent.onResult(.success)
                    return
                }
                return
            }

            if urlStr.contains("AccountLock.aspx") {
                retryWorkItem?.cancel()
                retryWorkItem = nil
                isProcessingCaptcha = false

                print("[SSO] Account locked")
                // 擷取鎖定時間
                evaluateJS(webView, "document.querySelector('#ContentPlaceHolder1_lbl_lockTime').textContent", "getLockTime") { val in
                    let lockTime = val as? String
                    self.parent.onResult(.accountLocked(lockTime: lockTime))
                }
                return
            }

            if urlStr.contains("error.html") {
                retryWorkItem?.cancel()
                retryWorkItem = nil
                isProcessingCaptcha = false

                print("[SSO] System error page detected")
                parent.onResult(.systemError)
                return
            }

            if urlStr.contains("Default.aspx") {
                // 若 captcha pipeline 仍在進行，就不要因為 didFinish 重複進入
                // 否則容易產生重疊流程，導致舊 callback 汙染新流程狀態
                if isProcessingCaptcha {
                    print("[SSO] didFinish on Default.aspx but captcha pipeline is running, skip re-entry")
                    return
                }

                // 登入主頁，依序執行錯誤檢查、SweetAlert 檢查、Captcha 登入
                checkLoginError_SSO(in: webView) { [weak self] errorResult in
                    if let errorResult = errorResult {
                        self?.parent.onResult(errorResult)
                        return
                    }
                    self?.checkLoginDialog_SSO(in: webView) { [weak self] dialogResult in
                        if let dialogResult = dialogResult {
                            self?.parent.onResult(dialogResult)
                            return
                        }
                        self?.Login_SSO(in: webView)
                    }
                }
                return
            }
        }

        // MARK: - JS helpers
        private func evaluateJS(_ webView: WKWebView, _ js: String, _ note: String, completion: @escaping (Any?) -> Void) {
            DispatchQueue.main.async {
                webView.evaluateJavaScript(js) { result, error in
                    if let error = error {
                        print("[SSO][JS ERR][\(note)] \(error.localizedDescription)")
                        completion(nil)
                    } else {
                        completion(result)
                    }
                }
            }
        }

        private func checkLoginError_SSO(in webView: WKWebView, done: @escaping (SSOLoginResult?) -> Void) {
            let js = """
            (function(){
                var el=document.querySelector('#show_failed');
                if(!el) return JSON.stringify({found:false});
                var s=window.getComputedStyle(el);
                var visible=(s.display!=='none' && s.visibility!=='hidden' && el.offsetWidth>0 && el.offsetHeight>0);
                var msg=el.innerText.trim().slice(0, -1);
                return JSON.stringify({found:true,visible:visible,message:msg});
            })()
            """
            evaluateJS(webView, js, "checkLoginError_SSO") { val in
                guard let jsonStr = val as? String,
                      let data = jsonStr.data(using: .utf8),
                      let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    done(nil)
                    return
                }

                if let found = obj["found"] as? Bool, found,
                   let visible = obj["visible"] as? Bool, visible,
                   let message = obj["message"] as? String, !message.isEmpty {
                    print("[SSO] Login error hint: \(message)")
                    done(.credentialsFailed(message: message))
                } else {
                    done(nil)
                }
            }
        }

        private func checkLoginDialog_SSO(in webView: WKWebView, done: @escaping (SSOLoginResult?) -> Void) {
            let js = """
            (function(){
                var modal=document.querySelector('.swal-modal[role="dialog"][aria-modal="true"]');
                if(!modal) return JSON.stringify({found:false});
                var s=window.getComputedStyle(modal);
                var visible=(s.display!=='none' && s.visibility!=='hidden' && modal.offsetWidth>0 && modal.offsetHeight>0);
                var titleEl=modal.querySelector('.swal-title');
                var msgEl=modal.querySelector('.swal-text');
                var title=titleEl ? titleEl.innerText.trim() : '';
                var message=msgEl ? msgEl.innerText.trim() : '';
                var buttons=[...modal.querySelectorAll('.swal-button')].map(b=>b.innerText.trim());
                return JSON.stringify({found:true,visible:visible,title:title,message:message,buttons:buttons});
            })()
            """
            evaluateJS(webView, js, "checkLoginDialog_SSO") { val in
                guard let jsonStr = val as? String,
                      let data = jsonStr.data(using: .utf8),
                      let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    done(nil)
                    return
                }

                if let found = obj["found"] as? Bool, found,
                   let visible = obj["visible"] as? Bool, visible {
                    let title = obj["title"] as? String ?? ""
                    let message = obj["message"] as? String ?? ""

                    print("[SSO] SweetAlert detected: \(title) - \(message)")

                    // 根據訊息內容判斷錯誤類型
                    if message.contains("查無您的系統使用權限") {
                        done(.generic(title: "權限不足", message: message))
                    } else if message.contains("您的密碼即將到期") {
                        // 讓 SSO 去 StdMain 抓姓名，等個 0.1 秒
                        if let url = URL(string: "https://ccsys.niu.edu.tw/SSO/StdMain.aspx") {
                            webView.load(URLRequest(url: url))
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            done(.passwordExpiring(message: message))
                        }
                    } else if message.contains("密碼已滿180天") {
                        done(.passwordExpired(message: message))
                    } else if message.contains("驗證碼輸入錯誤") {
                        // 驗證碼錯誤：不回報給 ViewModel，直接在這裡自動重試
                        self.handleCaptchaErrorAndRetry(in: webView)
                        done(nil)
                    } else {
                        done(.generic(title: title.isEmpty ? "系統訊息" : title, message: message))
                    }
                } else {
                    done(nil)
                }
            }
        }

        // MARK: - 登入流程主體
        private func Login_SSO(in webView: WKWebView) {
            guard !isProcessingCaptcha else { return }

            retryWorkItem?.cancel()
            retryWorkItem = nil

            isProcessingCaptcha = true
            activeAttemptID += 1
            let attemptID = activeAttemptID

            print("[SSO] Login_SSO: begin captcha pipeline #\(attemptID)")

            let jsGetCaptcha = """
            (function(){
                var img=document.getElementById('VaildteCode');
                if(!img)return '';
                var c=document.createElement('canvas');
                c.width=img.naturalWidth||img.width;
                c.height=img.naturalHeight||img.height;
                var g=c.getContext('2d');
                g.drawImage(img,0,0);
                return c.toDataURL('image/png');
            })()
            """

            evaluateJS(webView, jsGetCaptcha, "getCaptchaBase64") { [weak self] val in
                guard let self = self else { return }

                // 舊 callback 回來就直接忽略
                guard attemptID == self.activeAttemptID else {
                    print("[SSO] Ignore stale captcha base64 callback #\(attemptID)")
                    return
                }

                guard let dataURL = val as? String, dataURL.hasPrefix("data:image") else {
                    print("[SSO] Captcha dataURL not found – retry later #\(attemptID)")
                    self.isProcessingCaptcha = false
                    self.scheduleSSOReloadRetry(in: webView, delay: 1.0)
                    return
                }

                let b64 = self.stripDataURLPrefix(dataURL)
                guard let imgData = Data(base64Encoded: b64),
                      let image = UIImage(data: imgData) else {
                    print("[SSO] Base64 → UIImage failed #\(attemptID)")
                    self.isProcessingCaptcha = false
                    self.scheduleSSOReloadRetry(in: webView, delay: 1.0)
                    return
                }

                SSOCaptchaProcessor.shared.recognize(from: image) { [weak self] digits in
                    guard let self = self else { return }

                    DispatchQueue.main.async {
                        // 舊 callback 回來就直接忽略
                        guard attemptID == self.activeAttemptID else {
                            print("[SSO] Ignore stale OCR callback #\(attemptID)")
                            return
                        }

                        if let code = digits, code.count == 6 {
                            print("[SSO] OCR OK → \(code) #\(attemptID)")
                            self.fetchHiddenFieldsAndPost(in: webView, captcha: code, attemptID: attemptID)
                        } else {
                            print("[SSO] OCR FAIL or not 6 digits – retry later #\(attemptID)")
                            self.isProcessingCaptcha = false
                            self.scheduleSSOReloadRetry(in: webView, delay: 1.0)
                        }
                    }
                }
            }
        }

        // MARK: - 取得隱藏欄位與 POST
        private func fetchHiddenFieldsAndPost(in webView: WKWebView, captcha: String, attemptID: Int) {
            let js = """
            (function(){
                function gv(id){ var e = document.getElementById(id); return e ? e.value : ''; }
                function qv(sel){ var e = document.querySelector(sel); return e ? e.value : ''; }
                return JSON.stringify({
                    viewstate: gv('__VIEWSTATE'),
                    vsg: gv('__VIEWSTATEGENERATOR'),
                    ev: gv('__EVENTVALIDATION'),
                    token: qv('input[name="__RequestVerificationToken"]')
                });
            })()
            """

            evaluateJS(webView, js, "fetchHiddenFields") { [weak self] val in
                guard let self = self else { return }

                guard attemptID == self.activeAttemptID else {
                    print("[SSO] Ignore stale hidden-fields callback #\(attemptID)")
                    self.isProcessingCaptcha = false
                    return
                }

                guard let jsonStr = val as? String,
                      let data = jsonStr.data(using: .utf8),
                      let obj = try? JSONSerialization.jsonObject(with: data) as? [String: String] else {
                    print("[SSO] Hidden fields parse failed #\(attemptID)")
                    self.isProcessingCaptcha = false
                    return
                }

                let viewstate = obj["viewstate"] ?? ""
                let vsg = obj["vsg"] ?? ""
                let ev = obj["ev"] ?? ""
                let token = obj["token"] ?? ""

                print("[SSO] Hidden fields ok (VS:\(viewstate.count) EV:\(ev.count)) #\(attemptID)")

                let orderedItems: [(String, String)] = [
                    ("__EVENTTARGET", ""),
                    ("__EVENTARGUMENT", ""),
                    ("__VIEWSTATE", viewstate),
                    ("__VIEWSTATEGENERATOR", vsg),
                    ("__EVENTVALIDATION", ev),
                    ("txt_Account", self.parent.account),
                    ("txt_PWD", self.parent.password),
                    ("txt_validateCode", captcha),
                    ("__RequestVerificationToken", token),
                    ("ButLogin", "登入系統"),
                    ("recaptchaResponse", "")
                ]

                // 產生 body（正確的 x-www-form-urlencoded 編碼）
                guard let body = sso_formURLEncodedDataOrdered(orderedItems),
                      let url = URL(string: "https://ccsys.niu.edu.tw/SSO/Default.aspx") else {
                    print("[SSO] 無法產生 POST body 或 URL #\(attemptID)")
                    self.isProcessingCaptcha = false
                    return
                }

                // 同一輪 attempt 只能 POST 一次；
                // 但新的 attempt 不會被舊 attempt 的狀態卡住。
                if self.postedAttemptID == attemptID {
                    print("[SSO] Already posted for same attempt #\(attemptID), skipping")
                    self.isProcessingCaptcha = false
                    return
                }
                self.postedAttemptID = attemptID

                /*
                // 印出檢查順序與編碼是否正確
                if let bodyString = String(data: body, encoding: .utf8) {
                    print("==========[SSO POST BODY - PREVIEW]==========")
                    print(bodyString)
                    print("=============================================")
                }
                */

                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.httpBody = body
                request.setValue("application/x-www-form-urlencoded; charset=UTF-8", forHTTPHeaderField: "Content-Type")

                print("[SSO] POST /SSO/Default.aspx with captcha(\(captcha)) #\(attemptID)")
                DispatchQueue.main.async {
                    webView.load(request)
                    self.isProcessingCaptcha = false
                }
            }
        }

        private func stripDataURLPrefix(_ dataURL: String) -> String {
            if let range = dataURL.range(of: ",") {
                return String(dataURL[range.upperBound...])
            }
            return dataURL
        }

        // 共用 retry helper：
        // 讓 OCR 失敗 / dataURL 不存在 / base64 失敗等情況統一走這裡，
        // 避免多個 asyncAfter 疊加，造成多輪 didFinish / Login_SSO 互相干擾。
        private func scheduleSSOReloadRetry(in webView: WKWebView, delay: TimeInterval) {
            retryWorkItem?.cancel()

            let work = DispatchWorkItem { [weak self, weak webView] in
                guard let self = self, let webView = webView else { return }
                print("[SSO] Reload Default.aspx for retry")
                if let url = URL(string: "https://ccsys.niu.edu.tw/SSO/Default.aspx") {
                    webView.load(URLRequest(url: url))
                }
            }

            retryWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
        }

        // 驗證碼錯誤，重試機制
        private func handleCaptchaErrorAndRetry(in webView: WKWebView) {
            print("[SSO] Captcha error detected → auto retry")

            retryWorkItem?.cancel()
            retryWorkItem = nil

            // 1) 先把 SweetAlert 關掉（模擬按下確認）
            let closeJS = """
            (function(){
                var btn = document.querySelector('.swal-button--confirm');
                if (btn) { btn.click(); }
            })();
            """
            self.evaluateJS(webView, closeJS, "closeCaptchaErrorDialog") { [weak self] _ in
                guard let self = self else { return }

                DispatchQueue.main.async {
                    // 2) 重設狀態，允許新 attempt 再發一次 POST
                    self.isProcessingCaptcha = false
                    self.postedAttemptID = nil

                    // 3) 等頁面 / 驗證碼更新一下，再重新跑一次 Login_SSO
                    let work = DispatchWorkItem { [weak self, weak webView] in
                        guard let self = self, let webView = webView else { return }
                        print("[SSO] Retry Login_SSO after captcha error")
                        self.Login_SSO(in: webView)
                    }

                    self.retryWorkItem = work
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: work)
                }
            }
        }
    }
}




/*
 .........
// MARK: - 小工具：將 Dictionary 轉成 x-www-form-urlencoded
private func sso_percentEncodeForm(_ string: String) -> String {
    // 按 x-www-form-urlencoded 習慣，用一組較「嚴格」的 allowed set
    var allowed = CharacterSet.alphanumerics
    allowed.insert(charactersIn: "-._* ")  // 保留 - . _ * 與空白（稍後把空白換成 '+')
    // 不把 '+' 放在 allowed 裡，確保會被編碼成 %2B

    let encoded = string.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
    return encoded.replacingOccurrences(of: " ", with: "+")
}

// 以「有序」的 (key, value) 陣列，產生 x-www-form-urlencoded Data
private func sso_formURLEncodedDataOrdered(_ items: [(String, String)]) -> Data? {
    let pairs = items.map { key, value in
        "\(sso_percentEncodeForm(key))=\(sso_percentEncodeForm(value))"
    }
    let bodyString = pairs.joined(separator: "&")
    return bodyString.data(using: .utf8)
}

// MARK: - SSO 登入結果
public enum SSOLoginResult {
    case success
    case credentialsFailed(message: String)
    case passwordExpiring(message: String)
    case passwordExpired(message: String)
    case accountLocked(lockTime: String?)
    case systemError
    case generic(title: String, message: String)
}

public struct SSOLoginWebView: UIViewRepresentable {

    public let account: String
    public let password: String
    public let onResult: (SSOLoginResult) -> Void
    
    @EnvironmentObject var settings: AppSettings // 為了寫入 姓名

    public init(account: String, password: String, onResult: @escaping (SSOLoginResult) -> Void) {
        self.account = account
        self.password = password
        self.onResult = onResult
    }

    public func makeCoordinator() -> Coordinator {
        // 關鍵：把需要的依賴直接注入給 Coordinator
        Coordinator(settings: settings, parent: self)
    }

    public func makeUIView(context: Context) -> WKWebView {
        // 初始化設定
        let config = AppWebViewEnvironment.shared.makeConfiguration()
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator

        // 初始載入登入頁面
        if let url = URL(string: "https://ccsys.niu.edu.tw/SSO/Default.aspx") {
            webView.load(URLRequest(url: url))
        }

        return webView
    }

    public func updateUIView(_ uiView: WKWebView, context: Context) {}

    // MARK: - Coordinator
    public class Coordinator: NSObject, WKNavigationDelegate {
        private let settings: AppSettings
        private let parent: SSOLoginWebView
        private var isProcessingCaptcha = false
        private var getSSOViewState = false

        init(settings: AppSettings, parent: SSOLoginWebView) {
            self.settings = settings
            self.parent = parent
        }

        // MARK: - WKNavigationDelegate
        public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            let urlStr = webView.url?.absoluteString ?? ""
            print("[SSO] didFinish: \(urlStr)")

            // === URL 判斷邏輯 ===
            if urlStr.contains("StdMain.aspx") {
                print("[SSO] Login success → onResult(.success)")
                // 網頁擷取姓名，再將姓名儲存於 sp
                let GetNameJS = """
                (function() {
                    var span = document.getElementById('Label1');
                    if (!span) return '';
                    var text = span.innerText || span.textContent;
                    var match = text.match(/姓名：([^<]+)/);
                    return match ? match[1].trim() : '';
                })();
                """
                webView.evaluateJavaScript(GetNameJS) { result, error in
                    if let name = result as? String {
                        // 儲存到 UserDefaults (iOS 相當於 Android 的 SharedPreferences)
                        self.settings.name = name
                        // print("Name: \(name)")
                    }
                    self.parent.onResult(.success)
                    return
                }
            }

            if urlStr.contains("AccountLock.aspx") {
                print("[SSO] Account locked")
                // 擷取鎖定時間
                evaluateJS(webView, "document.querySelector('#ContentPlaceHolder1_lbl_lockTime').textContent", "getLockTime") { val in
                    let lockTime = val as? String
                    self.parent.onResult(.accountLocked(lockTime: lockTime))
                }
                return
            }

            if urlStr.contains("error.html") {
                print("[SSO] System error page detected")
                parent.onResult(.systemError)
                return
            }

            if urlStr.contains("Default.aspx") {
                // 登入主頁，依序執行錯誤檢查、SweetAlert 檢查、Captcha 登入
                checkLoginError_SSO(in: webView) { [weak self] errorResult in
                    if let errorResult = errorResult {
                        self?.parent.onResult(errorResult)
                        return
                    }
                    self?.checkLoginDialog_SSO(in: webView) { [weak self] dialogResult in
                        if let dialogResult = dialogResult {
                            self?.parent.onResult(dialogResult)
                            return
                        }
                        self?.Login_SSO(in: webView)
                    }
                }
                return
            }
        }

        // MARK: - JS helpers
        private func evaluateJS(_ webView: WKWebView, _ js: String, _ note: String, completion: @escaping (Any?) -> Void) {
            webView.evaluateJavaScript(js) { result, error in
                if let error = error {
                    print("[SSO][JS ERR][\(note)] \(error.localizedDescription)")
                    completion(nil)
                } else {
                    completion(result)
                }
            }
        }

        private func checkLoginError_SSO(in webView: WKWebView, done: @escaping (SSOLoginResult?) -> Void) {
            let js = """
            (function(){
                var el=document.querySelector('#show_failed');
                if(!el) return JSON.stringify({found:false});
                var s=window.getComputedStyle(el);
                var visible=(s.display!=='none' && s.visibility!=='hidden' && el.offsetWidth>0 && el.offsetHeight>0);
                var msg=el.innerText.trim().slice(0, -1);
                return JSON.stringify({found:true,visible:visible,message:msg});
            })()
            """
            evaluateJS(webView, js, "checkLoginError_SSO") { val in
                guard let jsonStr = val as? String,
                      let data = jsonStr.data(using: .utf8),
                      let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    done(nil)
                    return
                }
                
                if let found = obj["found"] as? Bool, found,
                   let visible = obj["visible"] as? Bool, visible,
                   let message = obj["message"] as? String, !message.isEmpty {
                    print("[SSO] Login error hint: \(message)")
                    done(.credentialsFailed(message: message))
                } else {
                    done(nil)
                }
            }
        }

        private func checkLoginDialog_SSO(in webView: WKWebView, done: @escaping (SSOLoginResult?) -> Void) {
            let js = """
            (function(){
                var modal=document.querySelector('.swal-modal[role="dialog"][aria-modal="true"]');
                if(!modal) return JSON.stringify({found:false});
                var s=window.getComputedStyle(modal);
                var visible=(s.display!=='none' && s.visibility!=='hidden' && modal.offsetWidth>0 && modal.offsetHeight>0);
                var titleEl=modal.querySelector('.swal-title');
                var msgEl=modal.querySelector('.swal-text');
                var title=titleEl ? titleEl.innerText.trim() : '';
                var message=msgEl ? msgEl.innerText.trim() : '';
                var buttons=[...modal.querySelectorAll('.swal-button')].map(b=>b.innerText.trim());
                return JSON.stringify({found:true,visible:visible,title:title,message:message,buttons:buttons});
            })()
            """
            evaluateJS(webView, js, "checkLoginDialog_SSO") { val in
                guard let jsonStr = val as? String,
                      let data = jsonStr.data(using: .utf8),
                      let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    done(nil)
                    return
                }
                
                if let found = obj["found"] as? Bool, found,
                   let visible = obj["visible"] as? Bool, visible {
                    let title = obj["title"] as? String ?? ""
                    let message = obj["message"] as? String ?? ""
                    
                    print("[SSO] SweetAlert detected: \(title) - \(message)")
                    
                    // 根據訊息內容判斷錯誤類型
                    if message.contains("查無您的系統使用權限") {
                        done(.generic(title: "權限不足", message: message))
                    } else if message.contains("您的密碼即將到期") {
                        // 讓 SSO 去 StdMain 抓姓名，等個 0.1 秒
                        if let url = URL(string: "https://ccsys.niu.edu.tw/SSO/StdMain.aspx") { webView.load(URLRequest(url: url)) }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            done(.passwordExpiring(message: message))
                        }
                    } else if message.contains("密碼已滿180天") {
                        done(.passwordExpired(message: message))
                    } else if message.contains("驗證碼輸入錯誤") {
                        // 驗證碼錯誤：不回報給 ViewModel，直接在這裡自動重試
                        self.handleCaptchaErrorAndRetry(in: webView)
                        done(nil)
                    } else {
                        done(.generic(title: title.isEmpty ? "系統訊息" : title, message: message))
                    }
                } else {
                    done(nil)
                }
            }
        }

        // MARK: - 登入流程主體
        private func Login_SSO(in webView: WKWebView) {
            guard !isProcessingCaptcha else { return }
            isProcessingCaptcha = true
            print("[SSO] Login_SSO: begin captcha pipeline")

            let jsGetCaptcha = """
            (function(){
                var img=document.getElementById('VaildteCode');
                if(!img)return '';
                var c=document.createElement('canvas');
                c.width=img.naturalWidth||img.width;
                c.height=img.naturalHeight||img.height;
                var g=c.getContext('2d');
                g.drawImage(img,0,0);
                return c.toDataURL('image/png');
            })()
            """

            evaluateJS(webView, jsGetCaptcha, "getCaptchaBase64") { [weak self] val in
                guard let self = self else { return }
                guard let dataURL = val as? String, dataURL.hasPrefix("data:image") else {
                    print("[SSO] Captcha dataURL not found – retry later")
                    self.isProcessingCaptcha = false
                    return
                }

                let b64 = self.stripDataURLPrefix(dataURL)
                guard let imgData = Data(base64Encoded: b64), let image = UIImage(data: imgData) else {
                    print("[SSO] Base64 → UIImage failed")
                    self.isProcessingCaptcha = false
                    return
                }

                // OCR using SwiftyTesseract
                SSOCaptchaProcessor.shared.recognize(from: image) { [weak self] digits in
                    guard let self = self else { return }
                    if let code = digits, code.count == 6 {
                        print("[SSO] OCR OK → \(code)")
                        self.fetchHiddenFieldsAndPost(in: webView, captcha: code)
                    } else {
                        print("[SSO] OCR FAIL or not 6 digits – retry later")
                        self.isProcessingCaptcha = false
                        // 如果 OCR 失敗，重新開始登入流程
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            //self.Login_SSO(in: webView)
                            if let url = URL(string: "https://ccsys.niu.edu.tw/SSO/Default.aspx") {
                                let request = URLRequest(url: url)
                                webView.load(request)
                            }
                        }
                    }
                }
            }
        }

        // MARK: - 取得隱藏欄位與 POST
        private func fetchHiddenFieldsAndPost(in webView: WKWebView, captcha: String) {
            let jsHidden = """
            (function(){
              function gv(id){var e=document.getElementById(id);return e?e.value:'';}
              function qv(sel){var e=document.querySelector(sel);return e?e.value:'';}
              return JSON.stringify({
                viewstate: gv('__VIEWSTATE'),
                vsg: gv('__VIEWSTATEGENERATOR'),
                ev: gv('__EVENTVALIDATION'),
                token: qv('input[name=\"__RequestVerificationToken\"]')
              });
            })()
            """

            evaluateJS(webView, jsHidden, "getHiddenFields") { [weak self] val in
                guard let self = self else { return }
                guard let jsonStr = val as? String,
                      let data = jsonStr.data(using: .utf8),
                      let obj = try? JSONSerialization.jsonObject(with: data) as? [String: String] else {
                    print("[SSO] Hidden field parse failed")
                    self.isProcessingCaptcha = false
                    return
                }

                let viewstate = obj["viewstate"] ?? ""
                let vsg = obj["vsg"] ?? ""
                let ev = obj["ev"] ?? ""
                let token = obj["token"] ?? ""

                print("[SSO] Hidden fields ok (VS:\(viewstate.count) EV:\(ev.count))")
                
                let orderedItems: [(String, String)] = [
                    ("__EVENTTARGET", ""),
                    ("__EVENTARGUMENT", ""),
                    ("__VIEWSTATE", viewstate),
                    ("__VIEWSTATEGENERATOR", vsg),
                    ("__EVENTVALIDATION", ev),
                    ("txt_Account", self.parent.account),
                    ("txt_PWD", self.parent.password),
                    ("txt_validateCode", captcha),
                    ("__RequestVerificationToken", token),
                    ("ButLogin", "登入系統"),
                    ("recaptchaResponse", "")
                ]

                // 產生 body（正確的 x-www-form-urlencoded 編碼）
                guard let body = sso_formURLEncodedDataOrdered(orderedItems),
                      let url = URL(string: "https://ccsys.niu.edu.tw/SSO/Default.aspx") else {
                    print("[SSO] 無法產生 POST body 或 URL")
                    self.isProcessingCaptcha = false
                    return
                }
                
                if self.getSSOViewState {
                    print("[SSO] Already posted once, skipping")
                    self.isProcessingCaptcha = false
                    return
                }
                self.getSSOViewState = true

                /*
                // 印出檢查順序與編碼是否正確
                if let bodyString = String(data: body, encoding: .utf8) {
                    print("==========[SSO POST BODY - PREVIEW]==========")
                    print(bodyString)
                    print("=============================================")
                }*/

                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.httpBody = body
                request.setValue("application/x-www-form-urlencoded; charset=UTF-8", forHTTPHeaderField: "Content-Type")

                print("[SSO] POST /SSO/Default.aspx with captcha(\(captcha))")
                webView.load(request)
                self.isProcessingCaptcha = false
            }
        }

        private func stripDataURLPrefix(_ dataURL: String) -> String {
            if let range = dataURL.range(of: ",") {
                return String(dataURL[range.upperBound...])
            }
            return dataURL
        }
        
        // 驗證碼錯誤，重試機制
        private func handleCaptchaErrorAndRetry(in webView: WKWebView) {
            print("[SSO] Captcha error detected → auto retry")

            // 1) 先把 SweetAlert 關掉（模擬按下確認）
            let closeJS = """
            (function(){
                var btn = document.querySelector('.swal-button--confirm');
                if (btn) { btn.click(); }
            })();
            """
            self.evaluateJS(webView, closeJS, "closeCaptchaErrorDialog") { _ in
                // 2) 重設狀態，允許再發一次 POST
                self.isProcessingCaptcha = false
                self.getSSOViewState = false

                // 3) 等頁面 / 驗證碼更新一下，再重新跑一次 Login_SSO
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    print("[SSO] Retry Login_SSO after captcha error")
                    self.Login_SSO(in: webView)
                }
            }
        }

    }
}
*/
