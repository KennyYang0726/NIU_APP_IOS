import SwiftUI
import Combine



@MainActor
final class ScoreInquiry_Tab1_ViewModel: ObservableObject {
    // --- 狀態 ---
    @Published var isOverlayVisible = true
    @Published var overlayText: LocalizedStringKey = "loading"
    
    @Published var courseList: [ScoreInquiry_Tab_ListViewModel] = []
    
    // --- WebView 相關 ---
    let webProvider: WebView_Provider
    private let sso = SSOIDSettings.shared
    
    // --- JS：取得期中末成績 ---
    private let getScoreJS = """
    (function() {
        let rows = [];
        for (let i = 2; ; i++) {
            let row = document.querySelector('#DataGrid > tbody > tr:nth-child(' + i + ')');
            if (!row) break;

            let type = row.querySelector('td:nth-child(4)')?.innerText || '';
            let lesson = row.querySelector('td:nth-child(5)')?.innerText || '';
            let score = row.querySelector('td:nth-child(6)')?.innerText || '';

            if (type.length < 2) type = '必修';

            rows.push({
                type: type.trim(),
                lesson: lesson.trim(),
                score: score.trim()
            });
        }
        return JSON.stringify(rows);
    })();
    """

    
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
    
    private func handlePageFinished(url: String?) async {
        switch url {
        case "https://acade.niu.edu.tw/NIU/MainFrame.aspx":
            // Step 1: 跳轉到期中成績查詢頁
            let headers = [
                "Referer": "https://acade.niu.edu.tw/NIU/Application/GRD/GRD51/GRD5131_.aspx?progcd=GRD5131"
            ]
            webProvider.load(
                url: "https://acade.niu.edu.tw/NIU/Application/GRD/GRD51/GRD5131_02.aspx",
                headers: headers
            )
        case "https://acade.niu.edu.tw/NIU/Application/GRD/GRD51/GRD5131_02.aspx":
            // 頁面加載完成，加載資訊
            loadGrades()
            showPage()
        default:
            break
        }
    }
    
    // 加載成績資訊
    private func loadGrades() {
        webProvider.evaluateJS(getScoreJS) { [weak self] value in
            guard let self = self else { return }
            guard let jsonString = value else { return }
            Task { @MainActor in
                do {
                    let data = Data(jsonString.utf8)
                    let items = try JSONDecoder().decode([ScoreItem].self, from: data)
                    self.courseList = items.map {
                        ScoreInquiry_Tab_ListViewModel(
                            name: $0.lesson,
                            score: $0.score,
                            elective: $0.type
                        )
                    }
                    .sorted { $0.sortKey > $1.sortKey }
                } catch {
                    print("JSON decode error:", error)
                }
            }
        }
    }
    
    private struct ScoreItem: Codable {
        let type: String
        let lesson: String
        let score: String
    }
    
    // --- 顯示畫面（模仿 Android 的 hideProgressOverlay + setVisibility） ---
    private func showPage() {
        isOverlayVisible = false
        // print("顯示頁面完成")
    }
}
