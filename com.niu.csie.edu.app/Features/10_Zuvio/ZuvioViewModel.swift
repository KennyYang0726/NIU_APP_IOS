import SwiftUI
import Combine



@MainActor
final class ZuvioViewModel: ObservableObject {
    // --- 狀態 ---
    @Published var isOverlayVisible = true
    @Published var overlayText: LocalizedStringKey = "loading"
    @Published var isWebVisible = false
    
    // --- WebView 相關 ---
    let webProvider: WebView_Provider
    
    // --- JS：隱藏多餘元素 ---
    let jsHideElements = """
    ['forum', 'zook', 'direno', 'match', 'setting'].forEach(function(type) {
        document.querySelectorAll('.g-f-button-box[data-type="' + type + '"]').forEach(function(el) {
            el.style.display = 'none';
        });
    });
    document.querySelector('.i-m-p-wisdomhall-area').style.display = 'none';
    document.querySelectorAll('.i-m-p-c-a-c-l-course-box[data-course-id="399868"]').forEach(function(el) {
        el.style.display = 'none';
    });
    """
    
    // --- JS：暗黑模式樣式 ---
    let jsDarkMode = """
    document.lastElementChild.appendChild(document.createElement('style')).textContent = 'html {filter: invert(0.90) !important}';
    document.lastElementChild.appendChild(document.createElement('style')).textContent = 'video, img, div.image, div.s-i-t-b-wrapper, div.i-c-l-reload-button, div.g-f-button-box, div.i-a-c-q-t-q-b-top-box, div.button, div.i-r-reload-button, div.i-f-f-f-a-post-feedback-button, div.i-m-p-c-a-c-l-c-b-green-block, div.i-m-p-c-a-c-l-c-b-t-star, div.s-i-top-box, div.s-i-t-b-i-b-icon, div.p-m-c-icon-box, div.user-icon-switch, div.c-pm-c-chat-wrapper.message-box, div.c-pm-c-send-message, div.c-pm-c-receive-message, div.c-pm-c-r-text, div.c-pm-c-s-text, div.c-pm-c-r-icon, div.c-pm-c-r-redirect, div.c-pm-c-chat-topic-card-list, div.i-h-r-rollcall-row.i-h-r-r-r-nonarrival, div.i-h-r-rollcall-row.i-h-r-r-r-punctual {filter: invert(100%) !important;}';
    """
    
    // --- 紀錄系統是否為深色模式 ---
    var colorScheme: ColorScheme = .light
    
    init() {
        self.webProvider = WebView_Provider(
            initialURL: "https://irs.zuvio.com.tw/student5/irs/index",
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
                // self.webProvider.setVisible(false)
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
        isWebVisible = true
        isOverlayVisible = false
        // print("顯示頁面完成")
    }
}
