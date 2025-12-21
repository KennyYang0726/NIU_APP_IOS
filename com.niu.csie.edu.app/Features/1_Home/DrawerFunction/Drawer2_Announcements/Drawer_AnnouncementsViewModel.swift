import SwiftUI
import Combine
import SwiftSoup


@MainActor
final class Drawer_AnnouncementsViewModel: ObservableObject {
    
    // --- 狀態 ---
    @Published var isListVisible: Bool = false
    @Published var isOverlayVisible = true
    @Published var overlayText: LocalizedStringKey = "loading"
    
    @Published var announcements: [AnnouncementsData] = []
        
    @Published var showDialog: Bool = false
    // 選中的 公告 資訊
    @Published var selectedAnnouncementsDetail: AnnouncementsData?
    
    // --- WebView 相關 ---
    let webProvider: WebView_Provider
    
    // --- JS ---
    private let jsGetData: String = """
        (function() { 
            //var data = [];
            //var count = document.querySelector('.listTB.table').length;
            //for(let i=0; i<count; i++) {
                //title = 
                //data[i] = {title, date, href};
            //}
            return document.querySelector('.listTB.table').outerHTML;
        })();
        """
    
    
    
    init() {
        // 初始化 WebView
        self.webProvider = WebView_Provider(
            initialURL: "https://www.niu.edu.tw/p/422-1000-1019.php",
            userAgent: .mobile
        )
        setupCallbacks()
    }
    
    // --- 綁定 WebView 回呼事件 ---
    private func setupCallbacks() {
        webProvider.onPageFinished = { [weak self] url in
            guard let self = self else { return }
            Task { @MainActor in
                self.webProvider.evaluateJS(self.jsGetData) { [weak self] result in
                    guard let self = self else { return }
                    if let html = result, !html.isEmpty {
                        do {
                            let doc: Document = try SwiftSoup.parse(html)
                            let rows: Elements = try doc.select("tbody tr")
                            var items: [AnnouncementsData] = []

                            for row in rows {
                                let date = try row.select("td[data-th=日期] .d-txt").text().trimmingCharacters(in: .whitespacesAndNewlines)
                                if let titleElement = try row.select("td[data-th=標題] .d-txt .mtitle a").first() {
                                    let title = try titleElement.text().trimmingCharacters(in: .whitespacesAndNewlines)
                                    let href = try titleElement.attr("href").trimmingCharacters(in: .whitespacesAndNewlines)
                                    if !date.isEmpty && !title.isEmpty && !href.isEmpty {
                                        let item = AnnouncementsData(title: title, date: date, href_link: href)
                                        items.append(item)
                                    }
                                }
                            }
                            
                            DispatchQueue.main.async {
                                self.announcements = items
                                self.showPage()
                            }

                        } catch {
                            print("HTML 解析失敗: \(error)")
                        }
                    }
                }
            }
        }
        
        webProvider.onProgressChanged = { [weak self] progress in
            guard let self = self else { return }
            Task { @MainActor in
                // self.overlayText = LocalizedStringKey("loading")
                self.isListVisible = false
                if progress < 1.0 {
                    self.isOverlayVisible = true
                }
            }
        }
    }
    
    func onItemTapped(_ item: AnnouncementsData) {
        selectedAnnouncementsDetail = item
        showDialog = true
    }
    
    // --- 顯示畫面（模仿 Android 的 hideProgressOverlay + setVisibility） ---
    private func showPage() {
        isListVisible = true
        isOverlayVisible = false
        // print("顯示頁面完成")
    }
}
