import Foundation



final class LoginStreakManager {

    private let prefs = UserDefaults(suiteName: "StreakLoginPrefs")!

    private let keyLoginDate = "loginDate"
    private let keyLoginCount = "loginCount"
    
    private let achievement = AchievementsMethod()

    func onLogin() {
        let today = Self.todayStart()
        let todayInt = Self.dateToInt(today)

        let lastDateInt = prefs.integer(forKey: keyLoginDate)
        let lastDate = Self.intToDate(lastDateInt)
        var count = prefs.integer(forKey: keyLoginCount)

        if lastDateInt == 0 {
            // 第一次登入
            count = 1

        } else {
            let diff = Self.dayDifference(from: lastDate, to: today)

            if diff == 1 {
                count += 1
            } else if diff > 1 {
                count = 1
            } else {
                // diff == 0，同一天登入不加
            }
        }

        if count == 30 {
            achievement.achievementsGet(index: "09")
        }

        prefs.set(todayInt, forKey: keyLoginDate)
        prefs.set(count, forKey: keyLoginCount)
    }

    func getLoginCount() -> Int {
        prefs.integer(forKey: keyLoginCount)
    }

    // ---- 日期工具 ----
    private static func todayStart() -> Date {
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
        if value == 0 {
            return Date(timeIntervalSince1970: 0)
        }

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
        prefs.set(0, forKey: keyLoginDate)
        prefs.set(0, forKey: keyLoginCount)
    }
}
