import Foundation
import SwiftUI
import Combine
import FirebaseAuth


// 由於 alert 在 view 只能實例1次，使用 case 區別
enum LoginAlert_Home: Identifiable {
    case emptyFields
    case loginFailed
    var id: Int { hashValue }
}

final class HomeViewModel: ObservableObject {
    
    @Published var isLoggingOut = false
    
    // 標誌位，判斷分別登出 js 是否執行完成
    @Published var SSO_Login = true
    @Published var Zuvio_Login = true
    
    // progress overlay
    @Published var showOverlay: Bool = false
    @Published var overlayText: LocalizedStringKey = "logouting"
    
    // 夜市星人（符合條件）
    @Published var matchedSpot: MatchedSpot? = nil
    @Published var showMatchedSpotToast: Bool = false
    @Published var matchedSpotToastText: String = ""

    private let loginRepo = LoginRepository()
    private let appSettings: AppSettings
    
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
    private let Zuvio_Logout_JS = "setting_logout();"

    init(appSettings: AppSettings) {
        self.appSettings = appSettings
        if Auth.auth().currentUser != nil { // 若匿名登入成功
            FirebaseDatabaseManager.shared.ensureUserNodeExists(for: loginRepo.loadCredentials()!.username, name: appSettings.name)
            }
    }
    
    // 登出主流程
    func logout(zuvioWeb: WebView_Provider, ssoWeb: WebView_Provider) {
        // prog show
        showOverlay = true

        // 執行兩個 WebView 的登出 JS
        zuvioWeb.evaluateJS(Zuvio_Logout_JS) { result in
            zuvioWeb.clearCache()
            self.Zuvio_Login = false
        }
        ssoWeb.evaluateJS(SSO_Logout_JS) { result in
            ssoWeb.clearCache()
            self.SSO_Login = false
        }

        // 清空帳密
        loginRepo.clearCredentials()
        // 清空姓名
        appSettings.name = ""
    }
    
    func CheckIfInNightMarket() {
        SingleLocationManager.shared.requestSingleLocation { coord in
            if let coord = coord {
                // print("經度：\(coord.longitude), 緯度：\(coord.latitude)")
                TimeService.shared.fetchTaipeiWeekdayNumber { weekday in
                    if let weekday = weekday {
                        TimeService.shared.fetchTaipeiClock { [self] timeString in
                            if let timeString = timeString {
                                // self.checkNightMarketLogic(latitude: 24.6349, longitude: 121.7927, timeNow: "18:00:00", dayOfWeek: "6") // 冬山 測試
                                self.checkNightMarketLogic(latitude: coord.latitude, longitude: coord.longitude, timeNow: timeString, dayOfWeek: weekday)
                                // 讀取 Firebase，若觸發到夜市，Toast + 通知修改 Database
                                self.updateAchievementString(index: self.matchedSpot!.index)
                            }
                        }
                    }
                }
                
            }
        }
    }
    
    private func checkNightMarketLogic(latitude: Double, longitude: Double, timeNow: String, dayOfWeek: String) {
        matchedSpot = NightMarketLogic.getMatchedSpot(
            latitude: latitude,
            longitude: longitude,
            timeNow: timeNow,
            dayOfWeek: dayOfWeek
        )
    }
    
    private func updateAchievementString(index: Int) {
        let userID = loginRepo.loadCredentials()?.username ?? "取得學號失敗"
        FirebaseDatabaseManager.shared.readData(from: "users/\(userID)/Achievements/11") { value in
            if var value = value as? String {
                // 若觸發到夜市，檢查對應的 index 值，若為０則發 Toast 並改變
                if self.matchedSpot!.index != -1 {
                    if value.char(at: index) == "0" {
                        value.replaceChar(at: index, with: "1")
                        self.showMatchedSpotToast = true
                        self.matchedSpotToastText = "已解鎖夜市星人：" + self.matchedSpot!.name
                    }
                    // 寫入新的值
                    FirebaseDatabaseManager.shared.writeData(
                        to: "users/\(userID)/Achievements/11",
                        value: value
                    ) { _ in
                        // 寫入完成，檢查是否全滿，發送通知
                        if value == "11111111111111" {
                            AchievementsMethod().sendNotification(title: NSLocalizedString("Achievements_Get", comment: ""), body: NSLocalizedString("Achievements_11_Title", comment: ""))
                        }
                    }
                }
            }
        }
    }
}

// 組合成就：夜市星人０１字串
extension String {
    mutating func replaceChar(at index: Int, with newChar: Character) {
        var chars = Array(self)
        chars[index] = newChar
        self = String(chars)
    }

    func char(at index: Int) -> Character {
        return self[self.index(self.startIndex, offsetBy: index)]
    }
}
