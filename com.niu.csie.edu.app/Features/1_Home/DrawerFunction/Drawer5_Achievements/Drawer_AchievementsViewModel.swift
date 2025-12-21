import SwiftUI
import Combine
import CoreLocation



@MainActor
final class Drawer_AchievementsViewModel: ObservableObject {
    
    // 新增 toast 控制
    @Published var showToast: Bool = false
    @Published var toastMessage: LocalizedStringKey = ""
    // 新增 Dialog 控制
    @Published var showDialog: Bool = false
    //
    @Published var features: [AchievementsFeature] = []
    //
    @Published var nightMarketParts: [AlertMessagePart] = []
    
    private let isPad = UIDevice.current.userInterfaceIdiom == .pad
    private let achievement = AchievementsMethod()
    
    private let loginStreak = LoginStreakManager() // 顯示達成天數
    private let loginStreakBright = LoginStreakManagerBright() // 顯示達成天數
    
    private let nightMarketList: [LocalizedStringKey] = [
        "NightMarket_01", "NightMarket_02", "NightMarket_03",
        "NightMarket_04", "NightMarket_05", "NightMarket_06",
        "NightMarket_07", "NightMarket_08", "NightMarket_09",
        "NightMarket_10", "NightMarket_11", "NightMarket_12",
        "NightMarket_13", "NightMarket_14"
    ]

    
    func loadAchievements(from dict: [String: Any]) {
        let lang = Locale.current.languageCode ?? "en"
        let langSuffix = (lang == "zh") ? "zh_tw" : "en"

        var newFeatures: [AchievementsFeature] = []

        // 01 ~ 10：Bool
        for index in 1...10 {
            let key = String(format: "%02d", index)
            let raw = dict[key]

            var isCompleted = false

            if let val = raw as? Int {
                isCompleted = (val == 1)
            }
            if let str = raw as? String, let intVal = Int(str) {
                isCompleted = (intVal == 1)
            }
            
            var subtitle = NSLocalizedString("Achievements_\(key)_Description", comment: "")
            // 只有 index 9、10 需要加進度
            if index == 9 {
                subtitle += "\n\(NSLocalizedString("Achievements_Prog_Description", comment: ""))\(loginStreak.getLoginCount())/30"
            } else if index == 10 {
                subtitle += "\n\(NSLocalizedString("Achievements_Prog_Description", comment: ""))\(loginStreakBright.getBrightLoginCount())/74"
            }
            newFeatures.append(
                AchievementsFeature(
                    iconName: "Achievement_\(key)_Icon",
                    title: NSLocalizedString("Achievements_\(key)_Title", comment: ""),
                    subtitle: subtitle,
                    status: isCompleted ? "completed_\(langSuffix)" : "uncompleted_\(langSuffix)"
                )
            )
        }

        // 成就 11：字串 14 位
        if let raw11 = dict["11"] as? String {
            let isDone = raw11 == "11111111111111"
            newFeatures.append(
                AchievementsFeature(
                    iconName: "Achievement_11_Icon",
                    title: NSLocalizedString("Achievements_11_Title", comment: ""),
                    subtitle: NSLocalizedString("Achievements_11_Description", comment: ""),
                    status: isDone ? "completed_\(langSuffix)" : "uncompleted_\(langSuffix)"
                )
            )
        }
        self.features = newFeatures
    }

    
    func fetchAchievementStates() {
        let userID = LoginRepository().loadCredentials()?.username ?? "取得學號失敗"
        FirebaseDatabaseManager.shared.readData(from: "users/\(userID)/Achievements") { value in
            guard let dict = value as? [String: Any] else { return }
            Task { @MainActor in
                self.loadAchievements(from: dict)
            }
        }
    }
    
    func buildNightMarketParts(from state: String) -> [AlertMessagePart] {
        var parts: [AlertMessagePart] = []
        // 顯示一小段提示字
        parts.append(.textKey("Achievements_11_Dialog_Message"))
        for (i, char) in state.enumerated() {
            guard i < nightMarketList.count else { break }

            let key = nightMarketList[i]
            let color = (char == "1") ? Color.green : Color.red

            parts.append(.textKeyColor(key, color))

            if i < nightMarketList.count - 1 {
                parts.append(.text("\n"))
            }
        }
        return parts
    }
    
    func NightMarketGuyClicked() {
        let userID = LoginRepository().loadCredentials()?.username ?? "取得學號失敗"
        FirebaseDatabaseManager.shared.readData(from: "users/\(userID)/Achievements/11") { value in
            guard let state = value as? String else { return }
            // 完成狀態
            if state == "11111111111111" {
                self.toastMessage = "Achievements_11_showMessage1"
                self.showToast = true
                return
            }
            // 未完成 → 檢查定位授權
            let status = CLLocationManager().authorizationStatus
            if status == .authorizedAlways || status == .authorizedWhenInUse {
                // 動態產生夜市清單顏色
                let result = self.buildNightMarketParts(from: state)
                DispatchQueue.main.async {
                    self.nightMarketParts = result
                    self.showDialog = true
                }
            } else {
                self.toastMessage = "Achievements_11_showMessage2"
                self.showToast = true
            }
        }
    }
    
}
