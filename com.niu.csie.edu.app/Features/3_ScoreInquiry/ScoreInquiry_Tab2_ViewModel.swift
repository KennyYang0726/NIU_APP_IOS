import SwiftUI
import Combine



@MainActor
final class ScoreInquiry_Tab2_ViewModel: ObservableObject {
    // --- 狀態 ---
    @Published var isOverlayVisible = true
    @Published var overlayText: LocalizedStringKey = "loading"
    
    @Published var courseList: [ScoreInquiry_Tab_ListViewModel] = []
    @Published var avgText: String = ""
    @Published var rankText: String = ""
    
    // --- WebView 相關 ---
    let webProvider: WebView_Provider
    private let sso = SSOIDSettings.shared
    
    // --- JS：取得期末成績 ---
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
            // Step 1: 跳轉到期末成績查詢頁
            let headers = [
                "Referer": "https://acade.niu.edu.tw/NIU/Application/GRD/GRD51/GRD5130_.aspx?progcd=GRD5130"
            ]
            webProvider.load(
                url: "https://acade.niu.edu.tw/NIU/Application/GRD/GRD51/GRD5130_02.aspx",
                headers: headers
            )
        case "https://acade.niu.edu.tw/NIU/Application/GRD/GRD51/GRD5130_02.aspx":
            // 頁面加載完成，加載資訊
            loadGrades()
            loadAvgAndRank()
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
    
    // 加載 平均&排名 資訊
    private func loadAvgAndRank() {
        // -------- 1. 讀取平均分數 --------
        let getAvgJS = #"document.querySelector('#Q_CRS_AVG_MARK').innerText"#
        webProvider.evaluateJS(getAvgJS) { [weak self] value in
            guard let self = self else { return }
            Task { @MainActor in

                guard let raw = value else {
                    self.avgText = NSLocalizedString("CanNotCalc", comment: "")
                    return
                }

                let avg = raw.replacingOccurrences(of: "\"", with: "")
                if Double(avg) == nil {
                    // 無法轉 Double → 尚未計算
                    self.avgText = NSLocalizedString("CanNotCalc", comment: "")
                } else {
                    self.avgText = avg
                }
            }
        }

        // -------- 2. 讀取排名 --------
        let getRankJS = #"document.querySelector('#QTable2 > tbody > tr:nth-child(2) > td:nth-child(2) > table > tbody > tr:nth-child(2) > td:nth-child(4)').innerText"#
        webProvider.evaluateJS(getRankJS) { [weak self] value in
            guard let self = self else { return }
            Task { @MainActor in

                guard let raw = value else {
                    self.rankText = NSLocalizedString("CanNotCalc", comment: "")
                    return
                }

                // 只保留數字
                let rankNumber = raw.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
                guard let num = Int(rankNumber) else {
                    self.rankText = NSLocalizedString("CanNotCalc", comment: "")
                    return
                }
                
                // 若為英文 → st / nd / rd / th
                let finalRank: String
                let lang = Locale.current.identifier.lowercased()
                let isChinese = lang.contains("zh")
                if !isChinese {
                    if num % 10 == 1 && num % 100 != 11 {
                        finalRank = "\(num)st"
                    } else if num % 10 == 2 && num % 100 != 12 {
                        finalRank = "\(num)nd"
                    } else if num % 10 == 3 && num % 100 != 13 {
                        finalRank = "\(num)rd"
                    } else {
                        finalRank = "\(num)th"
                    }
                } else {
                    // 中文直接顯示數字
                    finalRank = "\(num)"
                }

                self.rankText = finalRank
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
