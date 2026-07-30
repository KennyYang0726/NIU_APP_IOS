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
    private let ssoSession = SSOSession.shared
    
    // --- JS：取得期中成績 ---
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
            code: "GRD5131",
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
            await loadGrades()
            showPage()
        }
    }
    
    // 加載成績資訊
    private func loadGrades() async {
        await withCheckedContinuation { continuation in
            webProvider.evaluateJS(getScoreJS) { [weak self] value in
                guard let self = self else {
                    continuation.resume()
                    return
                }
                Task { @MainActor in
                    defer {
                        continuation.resume()
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
