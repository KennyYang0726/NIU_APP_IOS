import SwiftUI
import Combine



@MainActor
final class ClassScheduleViewModel: ObservableObject {
    @Published var isOverlayVisible = true
    @Published var overlayText: LocalizedStringKey = "loading"
    @Published var isWebVisible = false
    
    let webProvider: WebView_Provider
    private let jsClickElements = "document.querySelector('input#QUERY_BTN3').click();"
    
    private let sso = SSOIDSettings.shared
    // --- 紀錄系統是否為深色模式 ---
    var colorScheme: ColorScheme = .light

    
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
                await self.handlePageFinished(url: url)
            }
        }
    }
    
    // --- 初始化狀態 ---
    func InitialSettings() {
        isWebVisible = false
    }
    
    private func handlePageFinished(url: String?) async {
        switch url {
        case "https://acade.niu.edu.tw/NIU/MainFrame.aspx":
            // Step 1: 跳轉到課表頁
            let headers = [
                "Referer": "https://acade.niu.edu.tw/NIU/Application/TKE/TKE22/TKE2240_01.aspx"
            ]
            webProvider.load(
                url: "https://acade.niu.edu.tw/NIU/Application/TKE/TKE22/TKE2240_01.aspx",
                headers: headers
            )
        case "https://acade.niu.edu.tw/NIU/Application/TKE/TKE22/TKE2240_01.aspx":
            // Step 2: 點擊查詢按鈕並等待表格載入
            // print("進入課表查詢頁，準備執行查詢...")
            await evaluateQueryButtonClick()
            await waitForTable2()
        default:
            break
        }
    }
    
    // MARK: - 點擊查詢按鈕（async 包裝）
    private func evaluateQueryButtonClick() async {
        await withCheckedContinuation { continuation in
            webProvider.evaluateJS(jsClickElements) { _ in
                continuation.resume()
            }
        }
    }
        
    // MARK: - 等待 table2 出現
    private func waitForTable2() async {
        // print("開始等待 table2...")
        for _ in 0..<100 { // 最多等 100 次（約 30 秒）
            try? await Task.sleep(nanoseconds: 300_000_000) // 每 300ms 檢查一次
            let html = await evaluateTable2Html()
            guard let html = html else { continue }
                
            if html.contains("星期五") {
                    
                let html2 = html
                    .replacingOccurrences(of: "&nbsp;", with: " ")
                    .replacingOccurrences(of: "&quot;", with: "\"")
                    
                // --- 根據模式插入暗黑樣式 ---
                let styleBlock: String
                if self.colorScheme == .dark {
                    // print("啟用暗黑模式（HTML 內嵌樣式）")
                    styleBlock = """
                        <style>
                        html, body { background-color: #121212; color: #e0e0e0; }
                        table { border-collapse: collapse; width: 100%; border: 1px solid #ffffff; }
                        td, th { border: 1px solid #ffffff; padding: 8px; text-align: center; color: #e0e0e0; }
                        a { color: #DFA909; }
                        a:hover { color: #FFC107; }
                        </style>
                    """
                } else {
                    styleBlock = """
                        <style>
                        table { border-collapse: collapse; width: 100%; }
                        td, th { border: 1px solid black; padding: 8px; text-align: center; }
                        </style>
                    """
                }
                    
                // --- 組合完整 HTML ---
                let table2Html = """
                    <html>
                    <head>
                    \(styleBlock)
                    </head>
                    <body>
                    \(html2)
                    </body>
                    </html>
                """
                // print("=== table2Html ===\n\(table2Html)")
                self.showPage(table: table2Html)
                return
            }
        }
        print("⚠️ 超過最大等待次數，仍未找到 table2")
    }
    
    // MARK: - 抓取 table2 HTML
    private func evaluateTable2Html() async -> String? {
        await withCheckedContinuation { continuation in
            webProvider.evaluateJS("document.getElementById('table2').outerHTML") { result in
                continuation.resume(returning: result)
            }
        }
    }
    
    // --- 顯示畫面（模仿 Android 的 hideProgressOverlay + setVisibility） ---
    private func showPage(table: String) {
        webProvider.loadHTML(table)
        isWebVisible = true
        isOverlayVisible = false
        // print("顯示頁面完成")
    }
}
