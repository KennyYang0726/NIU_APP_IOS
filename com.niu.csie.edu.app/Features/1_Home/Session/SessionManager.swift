import Foundation
import SwiftUI
import Combine



@MainActor
final class SessionManager: ObservableObject {
    
    @Published var ssoDataInvalid: Bool = false // 通知 HomeView 是否登入過期 true 即過期
  
    let webZuvio = WebView_Provider(
        initialURL: "https://irs.zuvio.com.tw/student5/setting/index",
        userAgent: .mobile
    )
    let webSSO = WebView_Provider(
        initialURL: "https://ccsys.niu.edu.tw/SSO/Std002.aspx",
        userAgent: .mobile
    )

    // 可選：給 AppRoot 判斷登入/登出後該顯示哪個根畫面
    @Published var isAuthenticated: Bool = true

    private var isRefreshingSSOID = false
    
    private let loginStreak = LoginStreakManager()
    private let loginStreakBright = LoginStreakManagerBright()

    // MARK: - 在 Home 出現時自動跑 JS，寫入 SSOID suite
    func refreshSSOID() {
        
        guard !isRefreshingSSOID else { return }
        isRefreshingSSOID = true

        // 換成 Provider 的「準備流程」API：
        // 先導到 SSO 頁面 → 等待一段時間（讓 DOM / redirect 穩定）
        webSSO.hideUntilReady(actions: [
            .navigate("https://ccsys.niu.edu.tw/SSO/Std002.aspx"),
            .wait(0.3) // 視實際需要調整
        ]) { [weak self] in
            guard let self else { return }
            // 預備完成後再執行真正的 JS（拿 return value）
            let GetID_JS1 = """
            (function() {
              try {
                var ids = [
                  'ctl00_ContentPlaceHolder1_RadListView1_ctrl0_HyperLink1',  // acade_main
                  'ctl00_ContentPlaceHolder1_RadListView1_ctrl1_HyperLink1',  // acade_subject_system
                  'ctl00_ContentPlaceHolder1_RadListView1_ctrl12_HyperLink1'  // EUNI
                ];
                var hrefs = ids.map(function(id) {
                  var el = document.getElementById(id);
                  return el ? el.getAttribute('href') : null;
                });
                var origin = (document && document.location && document.location.origin) ? document.location.origin : "";
                return JSON.stringify({ hrefs: hrefs, origin: origin });
              } catch (e) {
                return JSON.stringify({ hrefs: [null,null,null], origin: "" });
              }
            })();
            """

            self.webSSO.evaluateJS(GetID_JS1) { raw in
                guard let raw = raw, !raw.isEmpty else { return }

                struct JSResult: Decodable {
                    let hrefs: [String?]
                    let origin: String
                }

                if let data = raw.data(using: .utf8),
                    let result = try? JSONDecoder().decode(JSResult.self, from: data) {

                    // 依序對應四個鍵
                    let acadeMain = result.hrefs.indices.contains(0) ? (result.hrefs[0] ?? "") : ""
                    let acadeSubject = result.hrefs.indices.contains(1) ? (result.hrefs[1] ?? "") : ""
                    let euni = result.hrefs.indices.contains(2) ? (result.hrefs[2] ?? "") : ""
                    
                    // DEBUG
                    print("ACADE_MAIN:\(acadeMain)")
                    print("ACADE_Subject:\(acadeSubject)")
                    print("EUNI:\(euni)")

                    // 直接寫入 SSOIDSettings（會自動存到 suite "SSOID"）
                    SSOIDSettings.shared.bulkUpdate(
                        EUNI: euni,
                        acade_main: acadeMain,
                        acade_subject_system: acadeSubject
                    )
                    
                    // 第 2 段：跳到 Std003.aspx，抓單一 ID 的 href（ccsys）
                    self.webSSO.hideUntilReady(actions: [
                        .navigate("https://ccsys.niu.edu.tw/SSO/Std003.aspx"),
                        .wait(0.4)
                    ]) { [weak self] in
                        guard let self else { return }

                        let GetID_JS2 = """
                                (function() {
                                  try {
                                    var el = document.getElementById('ctl00_ContentPlaceHolder1_RadListView1_ctrl0_HyperLink1');
                                    return el ? el.getAttribute('href') : null;
                                  } catch (e) {
                                    return null;
                                  }
                                })();
                                """

                        self.webSSO.evaluateJS(GetID_JS2) { href in
                            if let href = href, !href.isEmpty {
                                // DEBUG
                                print("CCSYS:\(href)")
                                SSOIDSettings.shared.ccsys = href
                                // 檢查是否為空 → 通知 View 顯示 alert
                                if !href.contains("JumpTo") {
                                    self.ssoDataInvalid = true
                                }
                            }
                            // 兩段都完成才結束 refresh 中的旗標
                            self.isRefreshingSSOID = false
                        }
                    }
                }
            }
        }
    }

    // MARK: - 登出流程（不依賴任何畫面是否在眼前）
    func logout(appState: AppState, appSettings: AppSettings, loginRepo: LoginRepository) {
        let SSO_Logout_JS = """
        (function() {
            var btn = document.querySelector('.btn-logout');
            if (btn) { 
                btn.click(); 
                return 'clicked'; 
            } else { 
                return 'not found'; 
            }
        })();
        """
        let Zuvio_Logout_JS = "setting_logout();"

        // 1) 兩支 WebView 各自執行登出 JS → 清快取
        let group = DispatchGroup()

        group.enter()
        webZuvio.evaluateJS(Zuvio_Logout_JS) { [weak self] _ in
            self?.webZuvio.clearCache {
                group.leave()
            }
        }

        group.enter()
        webSSO.evaluateJS(SSO_Logout_JS) { [weak self] _ in
            self?.webSSO.clearCache {
                group.leave()
            }
        }

        // 2) 立即清本機（帳密/姓名），連續登入紀錄，M園區課程資料
        loginRepo.clearCredentials()
        loginStreak.clearPrefs()
        loginStreakBright.clearPrefs()

        if let EUNI_CourseData = UserDefaults(suiteName: "EUNIcourseData") {
            EUNI_CourseData.removePersistentDomain(forName: "EUNIcourseData")
            EUNI_CourseData.synchronize()
        }
        appSettings.name = ""

        // 3) 統一導回登入頁
        group.notify(queue: .main) {
            self.isAuthenticated = false
            appState.navigate(to: .login, withToast: LocalizedStringKey("logout_success"))
        }
    }
}
