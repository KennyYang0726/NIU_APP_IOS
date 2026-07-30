import SwiftUI
import Combine



@MainActor
final class TakeLeaveViewModel: ObservableObject {
    @Published var isOverlayVisible = true
    @Published var overlayText: LocalizedStringKey = "loading"
    @Published var isWebVisible = false
    
    let webProvider: WebView_Provider
    private let ssoSession = SSOSession.shared
    
    init() {
        let fullURL = try! AcadeUrlUtil.buildUrl(
            code: "SEC2010",
            guid: ssoSession.guid1
        )
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
                self.handlePageFinished(url: url)
            }
        }
        
        webProvider.onProgressChanged = { [weak self] progress in
            guard let self = self else { return }
            Task { @MainActor in
                // self.overlayText = LocalizedStringKey("loading")
                self.isWebVisible = false
                if progress < 1.0 {
                    self.isOverlayVisible = true
                }
            }
        }
    }
    
    // --- 初始化狀態 ---
    func InitialSettings() {
        isWebVisible = false
    }
    
    private func handlePageFinished(url: String?) {
        guard let url else {
            return
        }
        if url.contains("GUID=") {
            showPage()
        }
    }
    
    // --- 顯示畫面（模仿 Android 的 hideProgressOverlay + setVisibility） ---
    private func showPage() {
        isWebVisible = true
        isOverlayVisible = false
        // print("顯示頁面完成")
    }
}
