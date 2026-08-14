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
    private let ssoSession = SSOSession.shared
    
    // --- JS：取得期末成績 ---
    private let getScoreJS = """
    (function() {
        var doc = window.frames['viewFrame'].document;
        var rows = [];
        for (var i = 2; ; i++) {
            var row = doc.querySelector('#DataGrid > tbody > tr:nth-child(' + i + ')');
            if (!row) break;
            var type = row.querySelector('td:nth-child(4)')?.innerText || '';
            var lesson = row.querySelector('td:nth-child(5)')?.innerText || '';
            var score = row.querySelector('td:nth-child(6)')?.innerText || '';
            type = type.trim();
            lesson = lesson.trim();
            score = score.trim();
            if (type.length < 2) {
                type = '必修';
            }
            rows.push({
                type: type,
                lesson: lesson,
                score: score
            });
        }
        return JSON.stringify(rows);
    })();
    """
    // --- JS：取得平均成績 ---
    private let getAvgJS = """
    (function() {
        var doc = window.frames['viewFrame'].document;
        var el = doc.querySelector('#Q_CRS_AVG_MARK');
        return el ? el.innerText.trim() : '';
    })();
    """
    // --- JS：取得排名 ---
    private let getRankJS = """
    (function() {
        var doc = window.frames['viewFrame'].document;
        var el = doc.querySelector('#Q_CLASS_RANK');
        return el ? el.innerText.trim() : '';
    })();
    """
    private let scorePageReadyJS = """
    (function() {
        var frame = window.frames['viewFrame'];
        if (!frame || !frame.document) {
            return 'false';
        }
        var doc = frame.document;
        return doc.querySelector('#DataGrid > tbody > tr:nth-child(2)') ? 'true' : 'false';
    })();
    """
    private var didLoadScore = false
    
    
    init() {
        let fullURL = try! AcadeUrlUtil.buildUrl(
            code: "GRD5130",
            guid: ssoSession.guid2
        )
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
        guard let url else {
            return
        }
        if url.contains("GUID=") && !didLoadScore {
            didLoadScore = true
            let ready = await webProvider.waitUntilJS(scorePageReadyJS)
            guard ready else {
                showPage()
                return
            }
            // 頁面加載完成，加載資訊
            async let gradesTask: Void = loadGrades()
            async let avgRankTask: Void = loadAvgAndRank()
            await gradesTask
            await avgRankTask
            showPage()
        }
    }
    
    // 加載成績資訊
    private func loadGrades() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            webProvider.evaluateJS(getScoreJS) { [weak self] value in
                Task { @MainActor in
                    defer {
                        continuation.resume()
                    }
                    guard let self = self else {
                        return
                    }
                    guard let jsonString = value else {
                        return
                    }
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
    }
    
    // 加載 平均&排名 資訊
    private func loadAvgAndRank() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            // -------- 1. 讀取平均分數 --------
            webProvider.evaluateJS(getAvgJS) { [weak self] avgValue in
                Task { @MainActor in
                    
                    guard let self = self else {
                        continuation.resume()
                        return
                    }

                    let rawAvg = avgValue?.replacingOccurrences(of: "\"", with: "") ?? ""
                    if Double(rawAvg) == nil {
                        // 無法轉 Double → 尚未計算
                        self.avgText = AppLocalization.localized("CanNotCalc", comment: "")
                    } else {
                        self.avgText = rawAvg
                    }

                    // -------- 2. 讀取排名 --------
                    self.webProvider.evaluateJS(self.getRankJS) { [weak self] rankValue in
                        Task { @MainActor in
                            defer {
                                continuation.resume()
                            }
                            guard let self = self else {
                                return
                            }
                            let rawRank = rankValue?.replacingOccurrences(of: "\"", with: "") ?? ""
                            // 只保留數字
                            let rankNumber = rawRank.replacingOccurrences(
                                of: "[^0-9]",
                                with: "",
                                options: .regularExpression
                            )
                            guard let num = Int(rankNumber) else {
                                self.rankText = AppLocalization.localized("CanNotCalc", comment: "")
                                return
                            }
                            let appLanguage = AppLocalization.resolvedLanguage(
                                for: AppLocalization.savedLanguage
                            )

                            // English 使用 st / nd / rd / th；繁中與日本語交由 localized format 顯示。
                            if appLanguage == .english {
                                if num % 10 == 1 && num % 100 != 11 {
                                    self.rankText = "\(num)st"
                                } else if num % 10 == 2 && num % 100 != 12 {
                                    self.rankText = "\(num)nd"
                                } else if num % 10 == 3 && num % 100 != 13 {
                                    self.rankText = "\(num)rd"
                                } else {
                                    self.rankText = "\(num)th"
                                }
                            } else {
                                self.rankText = "\(num)"
                            }
                        }
                    }
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
