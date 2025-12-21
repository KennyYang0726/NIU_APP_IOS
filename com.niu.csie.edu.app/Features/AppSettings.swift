import SwiftUI



enum AppTheme: String, CaseIterable {
    case `default`
    case bright
    case dark
}

final class AppSettings: ObservableObject {
    private let infoPrefs = UserDefaults(suiteName: "Infos")!
    private let themePrefs = UserDefaults(suiteName: "AppThemePrefs")!
    
    @Published var theme: AppTheme {
        didSet { AppSettings.save(theme.rawValue, key: "theme", to: themePrefs) }
    }
    
    @Published var semester: Int {
        didSet { AppSettings.save(semester, key: "Semester", to: infoPrefs) }
    }
    
    @Published var name: String {
        didSet { AppSettings.save(name, key: "Name", to: infoPrefs) }
    }
    
    init() {
        // --- 主題 ---
        if let savedTheme = themePrefs.string(forKey: "theme"),
           let loadedTheme = AppTheme(rawValue: savedTheme) {
            self.theme = loadedTheme
        } else {
            self.theme = .default
            AppSettings.save(AppTheme.default.rawValue, key: "theme", to: themePrefs)
        }
        
        // --- 學年度 ---
        if infoPrefs.object(forKey: "Semester") == nil {
            self.semester = 114
            AppSettings.save(114, key: "Semester", to: infoPrefs)
        } else {
            self.semester = infoPrefs.integer(forKey: "Semester")
        }
        
        // --- 名字 ---
        if let storedName = infoPrefs.string(forKey: "Name") {
            self.name = storedName
        } else {
            self.name = "窩不知道"
            AppSettings.save(self.name, key: "Name", to: infoPrefs)
        }
    }
    
    // 改為 static function，不依賴 self
    private static func save<T>(_ value: T, key: String, to prefs: UserDefaults) {
        prefs.set(value, forKey: key)
    }
}
