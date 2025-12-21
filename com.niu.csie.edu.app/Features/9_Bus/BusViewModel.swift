import SwiftUI
import Combine



@MainActor
final class BusViewModel: ObservableObject {
    // --- 狀態 ---
    @Published var isOverlayVisible = true
    @Published var overlayText: LocalizedStringKey = "loading"
    @Published var isWebVisible = false
    
    // --- WebView 管理 ---
    let webProvider: WebView_Provider
    
    // --- JS：隱藏多餘元素 ---
    let jsHideElements = """
    const selectors = [
        "#topNav",
        "head",
        "#main > div.container > nav",
        "#main > div.container > div.srch-input",
        "#main > div.page-title.page-title-srch",
        "#main > a",
        "#footer > a",
        "#footer > div.footer-info",
        "#btnFPMenuOpen",
        "#MasterPageBodyTag > a",
        "#main > div.bus-header.container-md > div:nth-child(1) > div.bus-title.mb-1.mb-md-3 > div.bus-title__icon > i"
    ];
    selectors.forEach(sel => {
        const el = document.querySelector(sel);
        if (el) el.style.display = 'none';
    });
    const bodyDiv = document.querySelector("#MasterPageBodyTag > div");
    if (bodyDiv) bodyDiv.style.paddingTop = "10px";
    document.querySelector('.footer-sitemap').style.display = 'none';
    """
    
    // --- JS：暗黑模式樣式 ---
    let jsDarkMode = """
    document.lastElementChild.appendChild(document.createElement('style')).textContent = `
      html { filter: invert(0.90) !important; }
      video, img, div.image, div.bus-header-section,
      div.bus-title.mb-1.mb-md-3, i.fas.fa-bus::before, i.fas.fa-wheelchair::before {
          filter: invert(100%) !important;
      }
      #main > div.bus-header.container-md > div:nth-child(1) > div.bus-title.mb-1.mb-md-3 > h2,
      #main > div.bus-header.container-md > div:nth-child(1) > div.bus-title.mb-1.mb-md-3 > div.bus-title__text {
          color: white !important;
      }
      .bus-title__num {
          filter: invert(1) !important;
          color: white !important;
      }
      .bus-title__text {
          filter: invert(1) !important;
          color: white !important;
      }
    `;
    """
    
    // --- 系統是否為深色模式 ---
    var colorScheme: ColorScheme = .light
    
    init() {
        self.webProvider = WebView_Provider(
            initialURL: "https://www.taiwanbus.tw/eBUSPage/Query/RouteQuery.aspx?key=%E5%AE%9C%E8%98%AD%E5%A4%A7%E5%AD%B8&lan=C",
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
                self.webProvider.setVisible(false)
                if progress < 1.0 {
                    self.isOverlayVisible = true
                }
            }
        }
    }
    
    // --- 初始化狀態 ---
    func initializeState() {
        webProvider.setVisible(false)
    }
    
    // --- 頁面載入完成時的邏輯 ---
    private func handlePageFinished(url: String?) {
        guard var url = url else { return }
        
        // --- 語系自動切換 ---
        if url.contains("rno=") { // 僅在詳細頁才切換
            if Locale.current.language.languageCode?.identifier.contains("zh") == true {
                if url.contains("&lan=E") {
                    url = url.replacingOccurrences(of: "&lan=E", with: "&lan=C")
                    webProvider.load(url: url)
                    return
                }
            } else {
                if url.contains("&lan=C") {
                    url = url.replacingOccurrences(of: "&lan=C", with: "&lan=E")
                    webProvider.load(url: url)
                    return
                }
            }
        }
        
        // --- 若為 eBUS 頁面才注入 JS ---
        if url.contains("www.taiwanbus.tw/eBUSPage/") {
            webProvider.evaluateJS(jsHideElements) { [weak self] _ in
                guard let self = self else { return }
                if self.colorScheme == .dark {
                    self.webProvider.evaluateJS(self.jsDarkMode) { _ in
                        self.showPage()
                    }
                } else {
                    self.showPage()
                }
            }
        }
    }
    
    // --- 顯示畫面（模仿 Android 的 hideProgressOverlay + setVisibility） ---
    private func showPage() {
        isWebVisible = true
        isOverlayVisible = false
        // print("顯示頁面完成")
    }
}
