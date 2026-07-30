import SwiftUI



struct GraduationData: Codable { // JS Json Decode
    let diverseHours: [String]   // 8 numbers
    let englishAbility: String
    let physicalFitness: String
    let creditRequired: [String] // 2 values
    let creditCourse: String
}

@MainActor
final class GraduationThresholdViewModel: ObservableObject {
    // --- 狀態 ---
    @Published var isOverlayVisible = true
    @Published var overlayText: LocalizedStringKey = "loading"
    @Published var isWebVisible = false
    @Published var canShowWeb = false // 若還在 prog 要設置為 false
    
    // 存放 JS 回傳結果用的資料
    @Published var graduationData: GraduationData?
    
    var toolbarButtonComputedText: LocalizedStringKey {
        return isWebVisible ? "GraduationThreshold_BackAbstract" : "GraduationThreshold_ShowDetail"
    }
    
    // --- WebView 管理 ---
    let webProvider: WebView_Provider
    private let ssoSession = SSOSession.shared
    
    private let getInfoJS = """
    (function() {
        var doc = window.frames['mainFrame'].document;
        // 隱藏按鈕
        doc.querySelectorAll('input.btn').forEach(function(btn) {
            btn.style.display = 'none';
        });
        // 多元時數
        var diverseElement = doc.getElementById('div_B');
        var diverseText = diverseElement ? diverseElement.innerText : '';
        var diverseMatches = diverseText.match(/\\d+/g) || [];
        // 如果只有 4 個（碩士班），補成 8 個
        if (diverseMatches.length === 4) {
            diverseMatches = [
                diverseMatches[0], "不計入",
                diverseMatches[1], "不計入",
                diverseMatches[2], "不計入",
                diverseMatches[3], "不計入"
            ];
        }
        // 英文門檻
        var engSpan = doc.querySelector('span[ml="PL_外語能力"]');
        var englishAbility = engSpan
            ? engSpan.closest('tr').querySelector('div').innerText.trim()
            : '';
        // 體適能
        var phySpan = doc.querySelector('span[ml="PL_體適能"]');
        var physicalFitness = phySpan
            ? phySpan.closest('tr').querySelector('div').innerText.trim()
            : '';
        // 畢業最低學分數
        var rows = doc.querySelectorAll('tr.tdWhite');
        var creditRequired = [];
        rows.forEach(function(r) {
            if (r.cells[0] && r.cells[0].innerText.trim() === '畢業最低學分數') {
                creditRequired.push(r.cells[1].innerText.trim());
                creditRequired.push(r.cells[2].innerText.trim());
            }
        });
        // 學分學程
        var creditCourse = doc.getElementById('CRS_PROG');
        var creditCourseStr = creditCourse ? creditCourse.innerText.trim() : '';
        return JSON.stringify({
            diverseHours: diverseMatches,
            englishAbility: englishAbility,
            physicalFitness: physicalFitness,
            creditRequired: creditRequired,
            creditCourse: creditCourseStr
        });
    })();
    """
    
    // 文字顏色 parse float < 60 -> 紅色
    func textColor(for ability: String?) -> Color {
        if let ability = ability, ability.contains("未") {
            return .red
        } else {
            return .green
        }
    }
    
    
    init() {
        let userID = LoginRepository().loadCredentials()?.username ?? "R1443017"
        let fullURL = try! AcadeUrlUtil.buildPageUrl(
            code: "ENRG010",
            pageSuffix: "_01",
            guid: ssoSession.guid1,
            params: [
                AcadeUrlUtil.param("ADD_TYPE", "00"),
                AcadeUrlUtil.param("OPEN_MARK", "Y"),
                AcadeUrlUtil.param("STNO", userID)
            ]
        )
        self.webProvider = WebView_Provider(
            initialURL: fullURL,
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
    }
    
    private func handlePageFinished(url: String?) {
        guard let url else {
            return
        }
        if url.contains("GUID=") {
            // 查詢
            GetValueOfAspx()
        }
    }
    
    // 取得數值
    private func GetValueOfAspx() {
        webProvider.evaluateJS(getInfoJS) { [weak self] result in
            guard let self = self else { return }
            guard let jsonString = result,
                  let data = jsonString.data(using: .utf8) else {
                return
            }
            let decoder = JSONDecoder()
            if let obj = try? decoder.decode(GraduationData.self, from: data) {
                self.graduationData = obj
                self.showPage()
            }
        }
    }
    
    
    // --- 顯示畫面（模仿 Android 的 hideProgressOverlay + setVisibility） ---
    private func showPage() {
        isOverlayVisible = false
        canShowWeb = true
        // print("顯示頁面完成")
    }
}


