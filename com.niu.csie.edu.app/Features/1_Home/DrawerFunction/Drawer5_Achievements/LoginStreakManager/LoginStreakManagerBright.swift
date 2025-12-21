import Foundation
import UIKit



final class LoginStreakManagerBright {

    private let prefs = UserDefaults(suiteName: "StreakLoginManagerBright")!

    private let keyDate = "brightLoginDate"
    private let keyCount = "brightLoginCount"
    
    private let achievement = AchievementsMethod()

    func onLogin() {
        let todayDate = Self.getTodayDate()      // Date
        let todayInt = Self.dateToInt(todayDate) // Int: yyyyMMdd

        let lastDateInt = prefs.integer(forKey: keyDate)
        let lastDate = Self.intToDate(lastDateInt)
        var count = prefs.integer(forKey: keyCount)

        // ---- 暗色模式：直接重置，但不更新 lastDate ----
        if !isLightMode() {
            prefs.set(0, forKey: keyCount)
            prefs.set(0, forKey: keyDate)   // 清掉 lastDate，避免下一次亮色被視為「同一天」
            return
        }

        // ---- 亮色模式：正常 streak 邏輯 ----
        if lastDateInt == 0 {
            // 暗色剛重置、或從未登入過亮色模式
            count = 1

        } else {
            let diff = Self.dayDifference(from: lastDate, to: todayDate)

            if diff == 1 {
                count += 1
            } else if diff > 1 {
                count = 1
            } else {
                // diff == 0，同一天登入，不累積
            }
        }

        // streak 達標成就
        if count == 74 {
            achievement.achievementsGet(index: "10")
        }

        // 更新資料
        prefs.set(todayInt, forKey: keyDate)
        prefs.set(count, forKey: keyCount)
    }

    func getBrightLoginCount() -> Int {
        prefs.integer(forKey: keyCount)
    }

    private func isLightMode() -> Bool {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else {
            return true
        }
        return window.traitCollection.userInterfaceStyle == .light
    }

    // ---- 日期工具 ----
    private static func getTodayDate() -> Date {
        Calendar.current.startOfDay(for: Date())
    }

    private static func dateToInt(_ date: Date) -> Int {
        let c = Calendar.current
        let y = c.component(.year, from: date)
        let m = c.component(.month, from: date)
        let d = c.component(.day, from: date)
        return y * 10000 + m * 100 + d
    }

    private static func intToDate(_ value: Int) -> Date {
        if value == 0 { return Date(timeIntervalSince1970: 0) }

        let year = value / 10000
        let month = (value % 10000) / 100
        let day = value % 100

        let c = Calendar.current
        return c.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private static func dayDifference(from: Date, to: Date) -> Int {
        let c = Calendar.current
        return c.dateComponents([.day], from: from, to: to).day ?? 0
    }
    
    func clearPrefs() {
        prefs.set(0, forKey: keyDate)
        prefs.set(0, forKey: keyCount)
    }
}
