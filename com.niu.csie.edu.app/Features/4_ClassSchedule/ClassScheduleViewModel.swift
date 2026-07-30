import SwiftUI
import Combine



@MainActor
final class ClassScheduleViewModel: ObservableObject {
    @Published var isOverlayVisible = true
    @Published var overlayText: LocalizedStringKey = "loading"
    @Published var isWebVisible = false
    @Published var canShareSchedule = false
    
    let userID = LoginRepository().loadCredentials()?.username ?? "B1043019"
    let name = AppSettings().name
    
    let webProvider: WebView_Provider
    private let jsClickElements = "window.frames['mainFrame'].document.querySelector('input#QUERY_BTN3').click();"
    private let queryButtonReadyJS = """
    (function() {
        var doc = window.frames['mainFrame'].document;
        return doc.querySelector('input#QUERY_BTN3') ? 'true' : 'false';
    })();
    """
    
    private var didClickQueryButton = false
    
    private var canContinueQuery = true // 篩選不開放時間，接收到 jsAlert -> false
    
    private let ssoSession = SSOSession.shared
    
    // --- 用於處理全域狀態導向 ---
    weak var appState: AppState?
    
    // --- 紀錄系統是否為深色模式 ---
    var colorScheme: ColorScheme = .light

    
    init() {
        let fullURL = try! AcadeUrlUtil.buildUrl(
            code: "TKE2240",
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
        // 註冊 alert handler
        webProvider.onJsAlert = { [weak self] message in
            guard let self = self else { return }
            if message.contains("不開放") {
                print("onAlert 收到：\(message)")
                self.canContinueQuery = false
                // 導回首頁並顯示提示
                self.appState?.navigate(to: .home, withToast: LocalizedStringKey(message))
            }
        }
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
        canShareSchedule = false
    }
    
    private func handlePageFinished(url: String?) async {
        guard let url else {
            return
        }
        if url.contains("GUID=") && !didClickQueryButton {
            didClickQueryButton = true
            let ready = await webProvider.waitUntilJS(queryButtonReadyJS)
            guard ready else {
                return
            }
            await evaluateQueryButtonClick()
            await waitForTable2()
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

            if !canContinueQuery { // 若不可查詢 -> 中斷
                print("canContinueQuery = false，停止查詢流程")
                return
            }

            try? await Task.sleep(nanoseconds: 300_000_000) // 每 300ms 檢查一次
            guard let html = await evaluateTable2Html(),
                  !html.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                continue
            }

            guard html.contains("星期五") || html.contains("table2") else {
                continue
            }

            let html2 = html
                .replacingOccurrences(of: "&nbsp;", with: " ")
                .replacingOccurrences(of: "&quot;", with: "\"")
                .replacingOccurrences(of: "\\n", with: "\n")
                .replacingOccurrences(of: "\\t", with: "\t")

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
        print("⚠️ 超過最大等待次數，仍未找到 table2")
    }
    
    // MARK: - 抓取 table2 HTML
    private func evaluateTable2Html() async -> String? {
        await withCheckedContinuation { continuation in
            webProvider.evaluateJS("window.frames['mainFrame'].document.getElementById('table2').outerHTML") { result in
                continuation.resume(returning: result)
            }
        }
    }
    
    func shareSchedule() {
        ClassScheduleSnapshotSharer.share(
            webProvider: webProvider,
            studentID: userID,
            name: name,
            isDarkMode: colorScheme == .dark
        )
    }
    
    // --- 顯示畫面（模仿 Android 的 hideProgressOverlay + setVisibility） ---
    private func showPage(table: String) {
        webProvider.loadHTML(table)
        isWebVisible = true
        canShareSchedule = true
        isOverlayVisible = false
        // print("顯示頁面完成")
    }
}
