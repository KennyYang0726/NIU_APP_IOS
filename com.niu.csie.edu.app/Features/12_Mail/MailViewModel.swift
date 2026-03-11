import SwiftUI
import Combine



@MainActor
final class MailViewModel: ObservableObject {
    @Published var isOverlayVisible = true
    @Published var overlayText: LocalizedStringKey = "loading"
    @Published var isWebVisible = false
    
    // --- WebView 管理 ---
    let webProvider: WebView_Provider
    
    // --- JS：隱藏多餘元素 ---
    private let jsHideElements = """
    (function(){
      function hideElements(){
        var targets = document.querySelectorAll('li span');
        var found = false;
        targets.forEach(function(el){
          if (el.innerText.includes('登出') || el.innerText.includes('返回電腦版')){
            el.closest('ul').style.display = 'none';
            found = true;
          }
          document.querySelector('.sc-qQXoI.XBhvs')
            ?.style.setProperty('display', 'none', 'important');
        });
        if (!found) setTimeout(hideElements, 200);
      }
      hideElements();
    })();
    """

    // --- JS：暗黑模式樣式 ---
    let jsDarkMode = """
    document.lastElementChild.appendChild(document.createElement('style')).textContent = 'html {filter: invert(0.90) !important}';
    document.lastElementChild.appendChild(document.createElement('style')).textContent = 'video {filter: invert(100%);}';
    document.lastElementChild.appendChild(document.createElement('style')).textContent = 'img {filter: invert(100%);}';
    document.lastElementChild.appendChild(document.createElement('style')).textContent = 'div.image {filter: invert(100%);}';
    """
    
    // --- 紀錄系統是否為深色模式 ---
    var colorScheme: ColorScheme = .light
    
    init() {
        // 在這邊額外加檢測，確認是否正確登入
        // Android 不會發生此問題，此現象僅偶發在 iOS
        let fullURL = "https://mail.niu.edu.tw/api/auth/user"
        self.webProvider = WebView_Provider(
            initialURL: fullURL,
            userAgent: .mobile
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
        // print("頁面載入完成: \(url ?? "未知網址")")
        switch url {
        case "https://mail.niu.edu.tw/api/auth/user":
            // 檢查是否存在 username
            webProvider.evaluateJS("document.body.innerText") { result in
                if (result!).contains("username") {
                    // print("登入成功")
                    self.webProvider.load(url: "https://mail.niu.edu.tw/NUMail/Mobile/Box/INBOX")
                } else {
                    // print("未登入")
                    self.overlayText = LocalizedStringKey("logining")
                    self.startMailLoginProcess = true
                }
            }
        case "https://mail.niu.edu.tw/NUMail/Mobile/Box/INBOX":
            webProvider.evaluateJS(jsHideElements) { [weak self] _ in
                guard let self = self else { return }
                // 如果是 Dark Mode，執行反白樣式
                if self.colorScheme == .dark {
                    // print("啟用暗黑模式 JS")
                    self.webProvider.evaluateJS(self.jsDarkMode) { _ in
                        self.showPage()
                    }
                } else {
                    self.showPage()
                }
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
    
    // --------  Mail 重新登入區塊  --------
    // MARK: - 登入狀態與流程
    @Published var startMailLoginProcess = false
    private let repository = LoginRepository().loadCredentials()
    var loginAccount: String {
        guard let repository else {
            fatalError("Credentials not found")
        }
        return repository.username
    }
    var password: String {
        guard let repository else {
            fatalError("Credentials not found")
        }
        return repository.password
    }
    
    func handleMailLoginResult(_ success: Bool) {
        startMailLoginProcess = false
        webProvider.load(url: "https://mail.niu.edu.tw/NUMail/Mobile/Box/INBOX")
    }
}
