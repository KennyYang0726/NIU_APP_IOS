import SwiftUI
import Combine
import DeviceKit // 取得裝置型號名稱



@MainActor
final class ContactUs_Tab2_ViewModel: ObservableObject {
    
    @Published var BugType: String = ""
    @Published var BugDescription: String = ""
    // 新增勾選狀態
    @Published var isSendingDeviceInfoChecked: Bool = false
    // 新增 toast 控制
    @Published var showToast: Bool = false
    // --- WebView 相關 ---
    let webProvider: WebView_Provider
    // --- 用於處理全域狀態導向 ---
    weak var appState: AppState?
    
    // 取得 App & Device 資訊
    var appInfo: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        return "App版本：\(version)\\nApp版本號：\(build)"
    }
        
    var deviceInfo: String {
        let device = Device.current
        // `device.description` 會回傳可讀名稱，如 "iPhone 15 Pro Max"
        let deviceName = device.description
        let system = "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
        return "裝置型號：\(deviceName)\\n系統版本：\(system)"
    }
    
    
    init() {
        self.webProvider = WebView_Provider(
            initialURL: "https://forms.gle/VtD6fdu5b2j82uL37",
            userAgent: .desktop
        )
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
    func submitBugReport() {
        guard !(BugType.isEmpty && BugDescription.isEmpty) else {
            showToast = true
            return
        }
        // 這裡處理送出邏輯，例如 API 呼叫
        var jsCode = """
        var textarea = document.getElementsByClassName('KHxj8b tL9Q4c')[0];
        textarea.value = '\(setTextareaValue(text: BugType))';
        textarea.dispatchEvent(new Event('input', { bubbles: true }));
        textarea.dispatchEvent(new Event('change', { bubbles: true }));
        """
        // 步驟
        jsCode += """
        var textarea = document.getElementsByClassName('KHxj8b tL9Q4c')[1];
        textarea.value = '\(setTextareaValue(text: BugDescription))';
        textarea.dispatchEvent(new Event('input', { bubbles: true }));
        textarea.dispatchEvent(new Event('change', { bubbles: true }));
        """
        // 傳送設備資訊
        if isSendingDeviceInfoChecked {
            jsCode += """
            var textarea = document.getElementsByClassName('KHxj8b tL9Q4c')[2];
            textarea.value = '\(deviceInfo)';
            textarea.dispatchEvent(new Event('input', { bubbles: true }));
            textarea.dispatchEvent(new Event('change', { bubbles: true }));
            """
        }
        // app 資訊
        jsCode += """
        var textarea = document.getElementsByClassName('KHxj8b tL9Q4c')[3];
        textarea.value = '\(appInfo)';
        textarea.dispatchEvent(new Event('input', { bubbles: true }));
        textarea.dispatchEvent(new Event('change', { bubbles: true }));
        """
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
