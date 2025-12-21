import SwiftUI
import Combine



@MainActor
final class ContactUs_Tab1_ViewModel: ObservableObject {
    
    @Published var Content: String = ""
    @Published var ContactInfo: String = ""
    // 新增勾選狀態
    @Published var isRegisteredSendChecked: Bool = false
    // 新增 toast 控制
    @Published var showToast: Bool = false
    // --- WebView 相關 ---
    let webProvider: WebView_Provider
    // --- 全域注射 ---
    private var appSettings: AppSettings?
    private var loginRepo: LoginRepository?
    // --- 用於處理全域狀態導向 ---
    weak var appState: AppState?

    
    init() {
        self.webProvider = WebView_Provider(
            initialURL: "https://forms.gle/VamntNvfUTqyKUb48",
            userAgent: .desktop
        )
    }
    
    // 讓 View 注入 AppSettings 和 LoginRepository
    func configure(appSettings: AppSettings, loginRepo: LoginRepository) {
        self.appSettings = appSettings
        self.loginRepo = loginRepo
    }
    
    // 轉譯
    func setTextareaValue(text: String) -> String {
        // 先把文字做 Escape，避免單引號或換行破壞 JS
        let escapedText = text
            .replacingOccurrences(of: "\\", with: "\\\\")  // 先 escape \
            .replacingOccurrences(of: "\n", with: "\\n")   // 換行
            .replacingOccurrences(of: "'", with: "\\'")    // 單引號
        return escapedText
    }
    
    // 送出
    func submitFeedback() {
        guard !Content.isEmpty else {
            showToast = true   // 觸發 toast
            return
        }
        // 這裡處理送出邏輯，例如 API 呼叫
        var jsCode = """
        var textarea = document.getElementsByClassName('KHxj8b tL9Q4c')[0];
        textarea.value = '\(setTextareaValue(text: Content))';
        textarea.dispatchEvent(new Event('input', { bubbles: true }));
        textarea.dispatchEvent(new Event('change', { bubbles: true }));
        """
        // 聯絡方式
        if ContactInfo.count >= 3 {
            jsCode += """
            var textarea = document.getElementsByClassName('KHxj8b tL9Q4c')[1];
            textarea.value = '\(setTextareaValue(text: ContactInfo))';
            textarea.dispatchEvent(new Event('input', { bubbles: true }));
            textarea.dispatchEvent(new Event('change', { bubbles: true }));
            """
        }
        // 記名
        if isRegisteredSendChecked {
            let username = loginRepo?.loadCredentials()?.username ?? "取得學號失敗"
            let name = appSettings?.name ?? "取得姓名失敗"
            jsCode += """
            var textarea = document.getElementsByClassName('KHxj8b tL9Q4c')[2];
            textarea.value = '\(username)\\n\(name)';
            textarea.dispatchEvent(new Event('input', { bubbles: true }));
            textarea.dispatchEvent(new Event('change', { bubbles: true }));
            """
        }
        jsCode += "document.querySelector('div[aria-label=\"Submit\"]').click();"
        // 提交
        webProvider.evaluateJS(jsCode) { [weak self] _ in
            guard let self = self else { return }
            self.webProvider.onPageFinished = { [weak self] url in
                guard let self = self else { return }
                Task { @MainActor in
                    // 導頁
                    self.appState?.navigate(to: .home, withToast: LocalizedStringKey("Submit_Successful"))
                }
            }
        }
    }
    
}
