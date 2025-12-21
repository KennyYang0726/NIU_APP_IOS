import SwiftUI
import Combine



// 用來在 EUNI1 → EUNI2 之間暫存跳轉參數
struct EUNI2LaunchConfig {
    static var fullTitle: String = "EUNI"
    static var url: URL = URL(string: "https://1.1.1.1")!
}


@MainActor
final class EUNI2ViewModel: ObservableObject {
    // --- 狀態 ---
    @Published var isWebVisible = false
    @Published var showNone = false // 顯示這裡啥都沒有
    @Published var isOverlayVisible = true
    @Published var overlayText: LocalizedStringKey = "loading"
    
    // --- WebView 管理 ---
    let webProvider: WebView_Provider
    
    // --- JS：隱藏多餘元素 ---
    let jsHideElements = """
    document.getElementById('above-header').style.display = 'none';
    document.getElementById('block-region-side-post').style.display = 'none';
    document.getElementById('showsidebaricon').style.display = 'none';
    // document.getElementById('page-footer').style.display = 'none';
    document.getElementById('page-footer').style.setProperty('display', 'none', 'important');
    var jumpnav = document.querySelector('.jumpnav');
    if (jumpnav) {
        jumpnav.style.display = 'none';
    }
    var activity_footer = document.querySelector('.activity_footer.activity-navigation');
    if (activity_footer) {
        activity_footer.style.display = 'none';
    }
    // ipad 會是電腦版樣式(判定是因為螢幕寬度 不是UserAgent)
    document.getElementById('adaptable-page-header-wrapper').style.display = 'none';
    document.getElementById('page-second-header').style.setProperty('display', 'none', 'important');
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

    // 新增可注入 URL 初始化
    init() {
        // 初始化 WebView
        self.webProvider = WebView_Provider(
            initialURL: EUNI2LaunchConfig.url.absoluteString,
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
                if progress < 1.0 {
                    self.isWebVisible = false
                    self.isOverlayVisible = true
                }
            }
        }
    }
    
    // --- 初始化狀態 ---
    func initializeState() {
        webProvider.setVisible(false)
    }
    
    // --- 頁面載入完成時的處理邏輯 ---
    private func handlePageFinished(url: String?) {
        // print("頁面載入完成: \(url ?? "未知網址")")
        // 若連結類非自家euni，自動跳轉外部應用
        // 無需像 Android 指定需要開啟的應用包名，系統會自己判定
        // 若無可以開啟的對應應用，fallback為預設瀏覽器
        guard
            let urlString = url?.trimmingCharacters(in: .whitespacesAndNewlines),
                let link = URL(string: urlString)
        else { return }
        if !urlString.contains("euni.niu.edu.tw") {
            UIApplication.shared.open(link)
            webProvider.goBack()
        }
        
        webProvider.evaluateJS(jsHideElements) { [weak self] _ in
            guard let self = self else { return }
            // 2. 如果是 Dark Mode，執行反白樣式
            if self.colorScheme == .dark {
                // print("啟用暗黑模式 JS")
                self.webProvider.evaluateJS(self.jsDarkMode) { _ in
                    self.showPage()
                }
            } else {
                self.showPage()
            }
        }
    }
    
    // --- 顯示畫面（模仿 Android 的 hideProgressOverlay + setVisibility） ---
    private func showPage() {
        let js = """
                (function() {
                    var bodyText = document.body.innerText;
                    var introExists = document.getElementById('intro') !== null;
                    return bodyText.includes('此課程沒有') || (bodyText.includes('目前還沒有') && bodyText.includes('一般消息與公告')) || (bodyText.includes('目前還沒有') && !introExists);
                })();
                """
        webProvider.evaluateJS(js) { [weak self] result in
            guard let self = self else { return }
            Task { @MainActor in
                let raw = result ?? "0"
                // JS 回傳會是 "1" 或 "0"
                if raw.contains("1") {
                    self.showNone = true
                    self.isWebVisible = false
                    self.isOverlayVisible = false
                } else {
                    self.showNone = false
                    self.isWebVisible = true
                    self.isOverlayVisible = false
                }
            }
        }
        // print("顯示頁面完成")
    }
}
