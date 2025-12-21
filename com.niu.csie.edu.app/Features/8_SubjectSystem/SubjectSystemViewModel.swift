import SwiftUI
import Combine



@MainActor
final class SubjectSystemViewModel: ObservableObject {
    // --- 狀態 ---
    @Published var isOverlayVisible = true
    @Published var overlayText: LocalizedStringKey = "loading"
    @Published var isWebVisible = false
    
    // --- WebView 管理 ---
    let webProvider: WebView_Provider
    
    // --- SSO 設定 ---
    private let sso = SSOIDSettings.shared
    
    // --- 用於處理全域狀態導向 ---
    weak var appState: AppState?
    
    init(appState: AppState? = nil) {
        let fullURL = "https://ccsys.niu.edu.tw/SSO/" + sso.acade_subject_system
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
            if message.contains("選課期間") {
                print("onAlert 收到：\(message)")
                // 導回首頁並顯示提示
                self.appState?.navigate(to: .home, withToast: LocalizedStringKey("currently_not_a_course_selection_time"))
            }
        }
    }
    
    // --- 初始化狀態 ---
    /*
    func InitialSettings() {
        isWebVisible = false
    }*/
    
    // --- 顯示畫面（模仿 Android 的 hideProgressOverlay + setVisibility） ---
    private func showPage() {
        isWebVisible = true
        isOverlayVisible = false
        // print("顯示頁面完成")
    }
}
