import SwiftUI
import Combine



@MainActor
final class TakeLeaveViewModel: ObservableObject {
    @Published var isOverlayVisible = true
    @Published var overlayText: LocalizedStringKey = "loading"
    @Published var isWebVisible = false
    
    let webProvider: WebView_Provider
    private let jsHideElements = """
    document.getElementById('QTable2').style.display = 'none';
    document.querySelector('a[href="JavaScript:showHideQtable();"]').closest('table').style.display = 'none';
    """
    private let sso = SSOIDSettings.shared
    
    init() {
        let fullURL = "https://ccsys.niu.edu.tw/SSO/" + sso.acade_main
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
        switch url {
        case "https://acade.niu.edu.tw/NIU/MainFrame.aspx":
            let headers = [
                "Referer": "https://acade.niu.edu.tw/NIU/Application/SEC/SEC20/SEC2010_02.aspx"
            ]
            webProvider.load(
                url: "https://acade.niu.edu.tw/NIU/Application/SEC/SEC20/SEC2010_01.aspx",
                headers: headers
            )
        case "https://acade.niu.edu.tw/NIU/Application/SEC/SEC20/SEC2010_01.aspx":
            webProvider.evaluateJS(jsHideElements) { [weak self] _ in
                self?.showPage()
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
