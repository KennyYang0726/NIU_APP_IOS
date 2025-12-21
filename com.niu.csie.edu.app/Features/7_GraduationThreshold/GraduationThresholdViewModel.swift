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
    
    // --- SSO 設定 ---
    private let sso = SSOIDSettings.shared
    
    private let getInfoJS = """
        (function() {
            // 隱藏按鈕
            document.querySelectorAll('input.btn').forEach(btn => btn.style.display = 'none');
            // 多元時數 (8 numbers)
            var diverseText = document.getElementById('div_B').innerText;
            var diverseMatches = diverseText.match(/\\d+/g) || [];
            // 如果只有 4 個（碩士班），補成 8 個
            if (diverseMatches.length === 4) {
                diverseMatches = [
                    diverseMatches[0], "不計入",   // 服務
                    diverseMatches[1], "不計入",   // 多元
                    diverseMatches[2], "不計入",   // 專業
                    diverseMatches[3], "不計入"    // 綜合
                ];
            }
            // 英文門檻
            var engSpan = document.querySelector('span[ml="PL_外語能力"]');
            var englishAbility = engSpan ? engSpan.closest('tr').querySelector('div').innerText : '';
            // 體適能
            var phySpan = document.querySelector('span[ml="PL_體適能"]');
            var physicalFitness = phySpan ? phySpan.closest('tr').querySelector('div').innerText : '';
            // 畢業最低學分數
            var rows = document.querySelectorAll('tr.tdWhite');
            var creditRequired = [];
            rows.forEach(r => {
                if (r.cells[0] && r.cells[0].innerText.trim() === '畢業最低學分數') {
                    creditRequired.push(r.cells[1].innerText.trim());
                    creditRequired.push(r.cells[2].innerText.trim());
                }
            });
            // 學分學程
            var creditCourse = document.getElementById('CRS_PROG');
            var creditCourseStr = creditCourse ? creditCourse.innerText : '';

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
        let fullURL = "https://ccsys.niu.edu.tw/SSO/" + sso.acade_main
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
        switch url {
        case "https://acade.niu.edu.tw/NIU/MainFrame.aspx":
            // Step 1: 跳轉到畢業門檻
            let headers = [
                "Referer": "https://acade.niu.edu.tw/NIU/Application/ENR/ENRG0/ENRG010_03.aspx"
            ]
            webProvider.load(
                url: "https://acade.niu.edu.tw/NIU/Application/ENR/ENRG0/ENRG010_01.aspx",
                headers: headers
            )
        case "https://acade.niu.edu.tw/NIU/Application/ENR/ENRG0/ENRG010_01.aspx":
            // Step 2: 查詢
            GetValueOfAspx()
        default:
            break
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


