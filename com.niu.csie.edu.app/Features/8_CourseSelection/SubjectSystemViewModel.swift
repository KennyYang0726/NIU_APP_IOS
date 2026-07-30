import SwiftUI
import Combine



@MainActor
final class SubjectSystemViewModel: ObservableObject {
    // --- 狀態 ---
    @Published var isOverlayVisible = true
    @Published var overlayText: LocalizedStringKey = "loading"
    @Published var isWebVisible = false
    @Published var isAtSubjectHome = true
    
    // --- WebView 管理 ---
    let webProvider: WebView_Provider
    private let ssoSession = SSOSession.shared
    
    // --- 用於處理全域狀態導向 ---
    weak var appState: AppState?
    
    init(appState: AppState? = nil) {
        let fullURL = "https://acade.niu.edu.tw/NIU/outside.aspx?mainPage=QQBwAHAAbABpAGMAYQB0AGkAbwBuAC8AVABLAEUALwBUAEsARQAyADAALwBUAEsARQAyADAAMQAxAF8ALgBhAHMAcAB4AD8AUAByAG8AZwBjAGQAPQBUAEsARQAyADAAMQAxAA==&GUID=\(ssoSession.guid1)"
        self.webProvider = WebView_Provider(
            initialURL: fullURL,
            userAgent: .desktop
        )
        self.appState = appState
        setupCallbacks()
    }
    
    // --- 綁定 WebView 回呼事件 ---
    private func setupCallbacks() {
        // 註冊 alert handler
        webProvider.onJsAlert = { [weak self] message in
            guard let self = self else { return }
            // print("message: \(message)")
            if message.contains("選課期間") {
                // 導回首頁並顯示提示
                self.appState?.navigate(to: .home, withToast: LocalizedStringKey("currently_not_a_course_selection_time"))
            }
        }
        webProvider.onProgressChanged = { [weak self] progress in
            guard let self = self else { return }
            Task { @MainActor in
                // self.overlayText = LocalizedStringKey("loading")
                // self.webProvider.setVisible(false)
                if progress < 1.0 {
                    self.isWebVisible = false
                    self.isOverlayVisible = true
                } else {
                    self.showPage()
                }
            }
        }
        webProvider.onPageFinished = { [weak self] url in
            guard let self = self else { return }
            Task { @MainActor in
                if url?.contains("mainframe_open.aspx?mainPage=") == true {
                    self.isAtSubjectHome = false
                    // 注射返回的 js 進去返回按鈕
                    let bottomUrl = "https://acade.niu.edu.tw/NIU/outside.aspx?mainPage=QQBwAHAAbABpAGMAYQB0AGkAbwBuAC8AVABLAEUALwBUAEsARQAyADAALwBUAEsARQAyADAAMQAxAF8ALgBhAHMAcAB4AD8AUAByAG8AZwBjAGQAPQBUAEsARQAyADAAMQAxAA=="
                    let js = """
                             (function () {
                                 function tryBind() {
                                     var frame = window.frames['mainFrame'];
                                     if (!frame || !frame.document) return;
                                     var doc = frame.document;
                                     ['BACK_BTN1', 'Button1', 'Button2'].forEach(function (id) {
                                         var btn = doc.getElementById(id);
                                         if (!btn) return;
                                         btn.onclick = function () {
                                             window.location.replace('\(bottomUrl)');
                                         };
                                     });
                                 }
                                 var timer = setInterval(function () {
                                     tryBind();
                                 }, 300);
                             })();
                             """
                    self.webProvider.evaluateJS(js)
                } else {
                    // 選課首頁，不得再返回
                    self.isAtSubjectHome = true
                }
            }
        }
    }
    
    // 回到選課系統頁面
    func reloadSubjectSystemHome() {
        let url = "https://acade.niu.edu.tw/NIU/outside.aspx?mainPage=QQBwAHAAbABpAGMAYQB0AGkAbwBuAC8AVABLAEUALwBUAEsARQAyADAALwBUAEsARQAyADAAMQAxAF8ALgBhAHMAcAB4AD8AUAByAG8AZwBjAGQAPQBUAEsARQAyADAAMQAxAA=="
        webProvider.load(url: url)
    }
    
    // --- 顯示畫面（模仿 Android 的 hideProgressOverlay + setVisibility） ---
    private func showPage() {
        isWebVisible = true
        isOverlayVisible = false
        // print("顯示頁面完成")
    }
}
