import SwiftUI
import Combine



// 用來在 EUNI1 → EUNI2 之間暫存跳轉參數
struct EUNI2LaunchConfig {
    static var courseName: String = ""
    static var subItemKey: String = ""
    static var url: URL = URL(string: "https://1.1.1.1")!

    static var fullTitle: String {
        let subTitle = NSLocalizedString(subItemKey, comment: "")
        return "\(courseName)-\(subTitle)"
    }
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
    // 移除上方 navBarTop
    var navBarTop = document.querySelector('.navbar.fixed-top.bg-body.navbar-expand.border-bottom.px-2');
    if (navBarTop) {
      navBarTop.style.display = 'none';
      // 移除為 fixed navbar 預留的補位
      document.body.style.paddingTop = '0';
      // 修 secondary navigation 的 top
      var secondaryNav = document.querySelector('.secondary-navigation');
      if (secondaryNav) {
        secondaryNav.style.top = '0';
      }
    }
    // 移除下方 pageFooter
    var pageFooter = document.getElementById('page-footer');
    pageFooter && (pageFooter.style.display = 'none');
    // 移除左上 課程索引
    var drawer_left_toggler = document.querySelector('.drawer-toggler.drawer-left-toggle.open-nav.d-print-none');
    drawer_left_toggler && (drawer_left_toggler.style.display = 'none');
    // 移除左側已展開 drawer
    const drawer = document.getElementById('theme_boost-drawers-courseindex');
    if (drawer) {
        drawer.remove();
    }
    // 移除右上 區塊抽屜 (某些頁面沒有)
    var drawer_right_toggler = document.querySelector('.drawer-toggler.drawer-right-toggle.ms-auto.d-print-none');
    drawer_right_toggler && (drawer_right_toggler.style.display = 'none');
    // 移除右側已展開 drawer
    const drawer_right = document.getElementById('theme_boost-drawers-blocks');
    if (drawer_right) {
        drawer_right.remove();
    }
    // 調整右側主內容填滿剩餘寬度
    const mainWrapper = document.getElementById('page');
    if (mainWrapper) {
        mainWrapper.style.marginLeft = '0';       // 移除左側抽屜預留空間
        mainWrapper.style.width = '100%';         // 填滿全寬
        mainWrapper.style.transition = 'none';    // 避免動畫閃爍
    }
    // 移除可跳轉的 page-navbar 區塊
    var page_navbar = document.getElementById('page-navbar');
    page_navbar && (page_navbar.style.setProperty('display', 'none', 'important'));
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
    
    private let subTitleRules: [(pattern: String, key: String)] = [
        ("mod/forum/view.php", "EUNI_Sub_Item1"),
        ("course/view.php", "EUNI_Sub_Item5"),
        ("grade/report/user/index.php", "EUNI_Sub_Item2"),
        ("user/index.php", "EUNI_Participants"),
        ("course/overview.php", "EUNI_Activities"),
        ("admin/tool/lp/coursecompetencies.php", "EUNI_Competencies"),
        ("course/edit.php", "EUNI_Settings"),
        ("course/modedit.php", "EUNI_Settings"),
        ("grade/grading/manage.php", "EUNI_Advanced_Rating"),
        ("mod/forum/subscribers.php", "EUNI_Subscribe"),
        ("mod/forum/report/summary/index.php", "EUNI_Report")
    ]

    // 新增可注入 URL 初始化
    init() {
        // 初始化 WebView
        self.webProvider = WebView_Provider(
            initialURL: EUNI2LaunchConfig.url.absoluteString,
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
    
    // 依照網址變更子標題
    private func resolveTitleKey(from url: String) -> String {
        for rule in subTitleRules {
            if url.contains(rule.pattern) {
                return rule.key
            }
        }
        return "EUNI_More" // fallback
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
        
        // 即時變更子標題
        let newKey = resolveTitleKey(from: urlString)
        if EUNI2LaunchConfig.subItemKey != newKey {
            EUNI2LaunchConfig.subItemKey = newKey
            objectWillChange.send()
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
