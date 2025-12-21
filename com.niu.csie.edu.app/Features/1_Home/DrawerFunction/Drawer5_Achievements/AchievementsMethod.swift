import SwiftUI



final class AchievementsMethod {
    
    private let loginPrefs = UserDefaults(suiteName: "LoginPrefs")!
    
    // 檢查時間日期成就
    func checkTimeBasedAchievements() {
        TimeService.shared.fetchTaipeiDate { dateString in
            guard let dateString = dateString else { return }
            if dateString.contains("-04-01") { self.achievementsGet(index: "04") }
            else if dateString.contains("-08-26") { self.achievementsGet(index: "05") }
            else if dateString.contains("-12-25") { self.achievementsGet(index: "06") }
        }
        TimeService.shared.fetchTaipeiClock { timeString in
            guard let timeString = timeString else { return }
            if timeString.contains("03:00:") {
                self.achievementsGet(index: "03")
            }
        }
    }
    
    // 檢查相伴 100, 365 天成就
    func checkAnniversaryAchievements(dateAttempt: String) {
        TimeService.shared.fetchTaipeiDate { dateString in
            guard let dateString = dateString else { return }
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.locale = Locale(identifier: "en_US_POSIX")
            guard let date1 = formatter.date(from: dateString),
                  let date2 = formatter.date(from: dateAttempt) else {
                return
            }
            let diff = Calendar.current.dateComponents([.day], from: date1, to: date2)
            if abs(diff.day!) >= 100 {
                self.achievementsGet(index: "07")
            }
            if abs(diff.day!) >= 365 {
                self.achievementsGet(index: "08")
            }
        }
    }
    
    // 獲得成就，自帶檢查是否已獲得 (不包含夜市星人)
    func achievementsGet(index: String) {
        let userID = LoginRepository().loadCredentials()?.username ?? "取得學號失敗"
        FirebaseDatabaseManager.shared.readData(from: "users/\(userID)/Achievements") { value in
            guard let dict = value as? [String: Any] else {
                print("資料格式不符")
                return
            }
                
            // 我只在乎 02~10，01 在創建時就 true 了
            if let raw = dict[index] {
                // 可能是 Int 或字串，所以做一次轉換
                let intValue: Int
                if let val = raw as? Int {
                    intValue = val
                } else if let str = raw as? String, let val = Int(str) {
                    intValue = val
                } else {
                    // 值不是可轉換的整數
                    return
                }
                    
                // 檢查是否為 0 (false)
                if intValue == 0 {
                    FirebaseDatabaseManager.shared.writeData(
                        to: "users/\(userID)/Achievements/\(index)",
                        value: true
                    ) { _ in
                        self.sendNotification(title: NSLocalizedString("Achievements_Get", comment: ""), body: NSLocalizedString("Achievements_\(index)_Title", comment: ""))
                    }
                }
            }
        }
    }
    
    func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req)
    }
    
}
