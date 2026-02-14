import SwiftUI
import Combine



@MainActor
final class ScoreInquiry_Tab3_ViewModel: ObservableObject {
    // --- 狀態 ---
    @Published var isOverlayVisible = true
    @Published var overlayText: LocalizedStringKey = "loading"
    @Published var isWebVisible = false
    
    // --- WebView 相關 ---
    let webProvider: WebView_Provider
    private let sso = SSOIDSettings.shared
    
    // --- JS：暗黑模式樣式 ---
    let jsDarkMode = """
    document.lastElementChild.appendChild(document.createElement('style')).textContent = 'html {filter: invert(0.90) !important}';
    """
    
    // --- 紀錄系統是否為深色模式 ---
    var colorScheme: ColorScheme = .light
    
    
    init() {
        let fullURL = "https://ccsys.niu.edu.tw/SSO/" + sso.ccsys
        self.webProvider = WebView_Provider(
            initialURL: fullURL,
            userAgent: .desktop
        )
        setupCallbacks()
    }
    
    // --- 綁定 WebView 回呼事件 ---
    private func setupCallbacks() {
        webProvider.onPageFinished = { [weak self] url in
            guard let self = self else { return }
            Task { @MainActor in
                await self.handlePageFinished(url: url)
            }
        }
    }
    
    private func handlePageFinished(url: String?) async {
        switch url {
        case "https://ccsys.niu.edu.tw/MvcTeam/Act":
            // Step 1: 跳轉到歷年成績查詢頁
            webProvider.load(
                url: "https://ccsys.niu.edu.tw/MvcTeam/Tutor/StudentCourseScore"
            )
        case "https://ccsys.niu.edu.tw/MvcTeam/Tutor/StudentCourseScore":
            // 2. 如果是 Dark Mode，執行反白樣式
            if self.colorScheme == .dark {
                // print("啟用暗黑模式 JS")
                self.webProvider.evaluateJS(self.jsDarkMode) { _ in
                    self.showPage()
                }
            } else {
                self.showPage()
            }
        default:
            break
        }
    }
    
    // --- 顯示畫面（模仿 Android 的 hideProgressOverlay + setVisibility） ---
    private func showPage() {
        isWebVisible = true
        isOverlayVisible = false
        // print("顯示頁面完成")
    }
}
