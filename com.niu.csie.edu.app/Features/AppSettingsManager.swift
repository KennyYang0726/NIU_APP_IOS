final class AppSettingsManager {
    static let shared = AppSettingsManager()
    let appSettings = AppSettings()

    func loadSemester() {
        FirebaseDatabaseManager.shared.readData(from: "學年度") { value in
            if let semester = value as? Int {
                self.appSettings.semester = semester
            }
        }
    }
}
